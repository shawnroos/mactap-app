import Foundation
import AppKit
import QuartzCore

// mactap-midi — knock the MacBook chassis, get a MIDI note.
//
// Reuses SensorManager + TapDetector from the app, runs the detector in
// musical mode, and publishes a virtual CoreMIDI source named "MacTap"
// plus (optionally) OSC for a Max for Live [udpreceive].

struct Options {
    var channel: UInt8 = 0
    var noteLeft: UInt8 = 36      // C1 — Live Drum Rack pad 1
    var noteRight: UInt8 = 38     // D1 — pad 3
    var gateMs: Double = 30
    var sensitivity: Double = 0.9
    var refractoryMs: Double = 45
    var classifySides = true
    var invertSides = false
    var sideHoldMs: Double = 32
    var magFloor: Double = 0.012
    var magCeil: Double = 0.09
    var curve: Double = 0.6       // <1 lifts soft hits; 1 is linear
    var midi = true
    var osc: (host: String, port: UInt16)? = nil
    var calibrate = false
    var selfTest = false
    var controlPort: UInt16 = 7401
    var learnSpec: String? = nil
    var learnCount = 10
    var zonesPath: String? = nil

    static func parse(_ args: [String]) -> Options {
        var o = Options()
        var i = 0
        func next() -> String? { i += 1; return i < args.count ? args[i] : nil }
        while i < args.count {
            switch args[i] {
            case "--channel":     o.channel = UInt8((Int(next() ?? "1") ?? 1) - 1)
            case "--note":        o.noteLeft = UInt8(next() ?? "36") ?? 36
            case "--note-right":  o.noteRight = UInt8(next() ?? "38") ?? 38
            case "--gate":        o.gateMs = Double(next() ?? "30") ?? 30
            case "--sensitivity": o.sensitivity = Double(next() ?? "0.9") ?? 0.9
            case "--refractory":  o.refractoryMs = Double(next() ?? "45") ?? 45
            case "--sides":       o.classifySides = true
            case "--no-sides":    o.classifySides = false
            case "--invert":      o.invertSides = true
            case "--side-hold":   o.sideHoldMs = Double(next() ?? "32") ?? 32
            case "--floor":       o.magFloor = Double(next() ?? "0.012") ?? 0.012
            case "--ceil":        o.magCeil = Double(next() ?? "0.09") ?? 0.09
            case "--curve":       o.curve = Double(next() ?? "0.6") ?? 0.6
            case "--no-midi":     o.midi = false
            case "--calibrate":   o.calibrate = true
            case "--test":        o.selfTest = true
            case "--control":     o.controlPort = UInt16(next() ?? "7401") ?? 7401
            case "--learn":       o.learnSpec = next() ?? "front-left:36,front-right:38,back:42"
            case "--learn-count": o.learnCount = max(3, Int(next() ?? "10") ?? 10)
            case "--zones":
                // optional path: "--zones" alone uses the default file
                if i + 1 < args.count, !args[i + 1].hasPrefix("--") {
                    o.zonesPath = args[i + 1]; i += 1
                } else {
                    o.zonesPath = ZoneModel.defaultPath.path
                }
            case "--osc":
                let spec = next() ?? "127.0.0.1:7400"
                let parts = spec.split(separator: ":")
                let host = parts.count == 2 ? String(parts[0]) : "127.0.0.1"
                let port = UInt16(parts.last ?? "7400") ?? 7400
                o.osc = (host, port)
            case "-h", "--help":
                print("""
                mactap-midi [options]
                  --note N          MIDI note for a hit (default 36 = C1)
                  --note-right N    note for right-side hits with --sides (default 38)
                  --sides           left/right → --note / --note-right (default on)
                  --no-sides        one pad: every hit is --note, ~7 ms instead of ~33 ms
                  --invert          swap left and right
                  --side-hold MS    how long a hit is held to read its side with --sides (default 32; 16 misreads)
                  --channel C       MIDI channel 1-16 (default 1)
                  --gate MS         note length in ms (default 30)
                  --sensitivity S   0..1 detector sensitivity (default 0.9)
                  --refractory MS   min gap between hits (default 45 → ~22 hits/s)
                  --floor G         peak magnitude mapped to velocity 1 (default 0.012)
                  --ceil G          peak magnitude mapped to velocity 127 (default 0.09)
                  --curve X         velocity curve exponent (default 0.6; 1 = linear)
                  --osc HOST:PORT   also send OSC /mactap/hit (default 127.0.0.1:7400)
                  --no-midi         skip the CoreMIDI source
                  --calibrate       print every hit's peak, latency and sample rate
                  --test            fire one synthetic hit at startup (checks MIDI/OSC plumbing)
                  --control PORT    listen for OSC settings on this port (default 7401; 0 = off)
                  --learn SPEC      learn chassis zones: "front-left:36,front-right:38,back:42"
                                    knock each zone in turn; saves ~/.mactap-zones.json, then goes live
                  --learn-count N   knocks per zone while learning (default 10)
                  --zones [FILE]    use learned zones (default ~/.mactap-zones.json); implies --sides
                """)
                exit(0)
            default:
                FileHandle.standardError.write("unknown option \(args[i])\n".data(using: .utf8)!)
                exit(2)
            }
            i += 1
        }
        return o
    }
}

let opts = Options.parse(Array(CommandLine.arguments.dropFirst()))
// Dials in the Max device change these while running. Written only on the
// detector queue (via detector.update), read there by onHit.
var live = opts

let midi: MIDIOut? = opts.midi ? MIDIOut(name: "MacTap") : nil
if opts.midi && midi == nil {
    FileHandle.standardError.write("could not create the MacTap MIDI source\n".data(using: .utf8)!)
    exit(1)
}
let osc: OSCOut? = opts.osc.flatMap { OSCOut(host: $0.host, port: $0.port) }

// Colour only when a person is watching; logs stay plain.
let tty = isatty(STDOUT_FILENO) == 1

let sensor = SensorManager()
let detector = TapDetector(sensor: sensor)
detector.musicalMode = true
detector.sensitivity = opts.sensitivity
detector.refractoryPeriod = opts.refractoryMs / 1000
detector.classifySides = opts.classifySides
detector.invertSides = opts.invertSides
detector.sideCaptureTime = opts.sideHoldMs / 1000

// Zones need the 32 ms attack window the side read uses.
var zoneModel: ZoneModel? = nil
var learning: (zone: Int, since: Double)? = nil
let zoneFile = URL(fileURLWithPath: opts.zonesPath ?? ZoneModel.defaultPath.path)
if let spec = opts.learnSpec {
    let zones = parseZoneSpec(spec)
    guard zones.count >= 2 else {
        FileHandle.standardError.write("--learn needs at least two zones\n".data(using: .utf8)!)
        exit(2)
    }
    zoneModel = ZoneModel(zones: zones)
    detector.classifySides = true
} else if opts.zonesPath != nil {
    guard let model = ZoneModel.load(from: zoneFile), model.isFitted else {
        FileHandle.standardError.write("no learned zones at \(zoneFile.path) — run with --learn first\n".data(using: .utf8)!)
        exit(1)
    }
    model.fit()
    zoneModel = model
    detector.classifySides = true
}

func zoneColour(_ i: Int) -> String {
    guard tty else { return "" }
    return ["\u{1B}[1;36m", "\u{1B}[1;35m", "\u{1B}[1;33m", "\u{1B}[1;32m", "\u{1B}[1;34m"][i % 5]
}
func zoneLabel(_ i: Int, _ name: String, unsure: Bool) -> String {
    tty ? "\(zoneColour(i))\(name)\(unsure ? "?" : "")\u{1B}[0m" : name + (unsure ? "?" : "")
}
func learnPrompt(_ i: Int) {
    guard let model = zoneModel else { return }
    print("\n>> knock \(zoneLabel(i, model.zones[i].name, unsure: false)) \(opts.learnCount) times")
    fflush(stdout)
}
detector.ignoreWhileTyping = false

func velocity(for magnitude: Double) -> UInt8 {
    let span = max(live.magCeil - live.magFloor, 1e-6)
    let t = min(max((magnitude - live.magFloor) / span, 0), 1)
    let shaped = pow(t, live.curve)
    return UInt8(max(1, min(127, Int((shaped * 126).rounded()) + 1)))
}


func number(_ args: [Any]) -> Double? {
    guard let a = args.first else { return nil }
    if let f = a as? Float { return Double(f) }
    if let i = a as? Int32 { return Double(i) }
    return nil
}

let control: OSCIn? = opts.controlPort == 0 ? nil : OSCIn(port: opts.controlPort) { address, args in
    guard let v = number(args) else { return }
    detector.update { d in
        switch address {
        case "/mactap/sensitivity": d.sensitivity = min(max(v, 0), 1); live.sensitivity = d.sensitivity
        case "/mactap/refractory":  d.refractoryPeriod = max(v, 5) / 1000; live.refractoryMs = max(v, 5)
        case "/mactap/sides":       d.classifySides = v >= 0.5; live.classifySides = d.classifySides
        case "/mactap/invert":      d.invertSides = v >= 0.5; live.invertSides = d.invertSides
        case "/mactap/side-hold":   d.sideCaptureTime = min(max(v, 4), 60) / 1000; live.sideHoldMs = d.sideCaptureTime * 1000
        case "/mactap/floor":       live.magFloor = max(v, 0)
        case "/mactap/ceil":        live.magCeil = max(v, 0.001)
        case "/mactap/curve":       live.curve = min(max(v, 0.1), 4)
        case "/mactap/gate":        live.gateMs = min(max(v, 1), 2000)
        case "/mactap/note":        live.noteLeft = UInt8(min(max(v, 0), 127))
        case "/mactap/note-right":  live.noteRight = UInt8(min(max(v, 0), 127))
        default: return
        }
        print(String(format: "set %@ %.3f", address.dropFirst("/mactap/".count) as NSString, v))
        fflush(stdout)
    }
}
if opts.controlPort != 0 && control == nil {
    // One bridge per machine: a second would publish a second MIDI source and
    // double every knock over OSC.
    FileHandle.standardError.write("another mactap-midi is already running (control port \(opts.controlPort) is taken)\n".data(using: .utf8)!)
    exit(3)
}

// Launched from a Max for Live device, stdin is a pipe from Node; when the
// device unloads or Live quits the pipe closes and the bridge must go too,
// or it lingers as an orphan holding the sensor and the ports.
if isatty(STDIN_FILENO) == 0 {
    let watcher = Thread {
        var buf = [UInt8](repeating: 0, count: 64)
        while true {
            let n = read(STDIN_FILENO, &buf, buf.count)
            if n <= 0 { break }
        }
        print("parent closed — stopping")
        fflush(stdout)
        sensor.stop()
        exit(0)
    }
    watcher.name = "MacTap.parent-watch"
    watcher.start()
}

var hitCount = 0
var lastHitHost: Double = 0

func sideLabel(_ side: TapSide) -> String {
    switch (side, tty) {
    case (.left, true):  return "\u{1B}[1;36mL\u{1B}[0m"
    case (.right, true): return "\u{1B}[1;35mR\u{1B}[0m"
    case (.left, false): return "L"
    case (.right, false): return "R"
    }
}

detector.onHit = { hit in
    var note = hit.side == .right ? live.noteRight : live.noteLeft
    let vel = velocity(for: hit.peakMagnitude)
    var label = sideLabel(hit.side)

    if let l = learning, let model = zoneModel {
        // Knocks in the first 1.5 s after a prompt are the hand moving over.
        if hit.hostTime - l.since < 1.5 { return }
        model.zones[l.zone].samples.append(ZoneFeatures(hit: hit).vector)
        model.zones[l.zone].peaks.append(hit.peakMagnitude)
        let n = model.zones[l.zone].samples.count
        print(String(format: "   %@ %d/%d   %.3f g", zoneLabel(l.zone, model.zones[l.zone].name, unsure: false) as NSString, n, opts.learnCount, hit.peakMagnitude))
        fflush(stdout)
        if n >= opts.learnCount {
            if l.zone + 1 < model.zones.count {
                learning = (l.zone + 1, hit.hostTime)
                learnPrompt(l.zone + 1)
            } else {
                learning = nil
                model.fit()
                print("\n" + model.confusionReport())
                do {
                    try model.save(to: zoneFile)
                    print("saved \(zoneFile.path)\nzones live — knock away\n")
                } catch {
                    print("could not save \(zoneFile.path): \(error)")
                }
                fflush(stdout)
            }
        }
        return
    }
    if let model = zoneModel, let m = model.classify(ZoneFeatures(hit: hit)) {
        note = m.zone.note
        label = zoneLabel(m.index, m.zone.name, unsure: m.margin < 0.2)
    }

    midi?.noteOn(channel: opts.channel, note: note, velocity: vel)
    if let midi {
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + live.gateMs / 1000) {
            midi.noteOff(channel: opts.channel, note: note)
        }
    }
    osc?.send(address: "/mactap/hit", args: [
        Int32(hit.side == .right ? 1 : 0),
        Int32(vel),
        Float(hit.peakMagnitude),
        Float(hit.latency * 1000),
    ])

    hitCount += 1
    let gapMs = lastHitHost > 0 ? (hit.hostTime - lastHitHost) * 1000 : 0
    lastHitHost = hit.hostTime
    // 0 means no rate estimate yet (first ~20 samples), not a parked sensor.
    let parked = hit.sampleRateHz > 0 && hit.sampleRateHz < 450 ? "  PARKED" : ""
    if opts.calibrate {
        print(String(format: "hit %4d  %@  peak %.4f g  vel %3d  snr %5.1f  lat %5.1f ms  gap %7.1f ms  %4.0f Hz%@",
                     hitCount, label, hit.peakMagnitude, Int(vel),
                     hit.snr, hit.latency * 1000, gapMs, hit.sampleRateHz, parked))
        if live.classifySides || zoneModel != nil {
            // Tilt direction: 0° = pure +Y roll (left), ±180° = right, +90° = +X pitch.
            let angle = atan2(hit.attackGY, hit.attackGX) * 180 / .pi
            let tilt = hypot(hit.attackGX, hit.attackGY)
            let f = ZoneFeatures(hit: hit)
            print(String(format: "           x %+.4f  px %+.4f  z %+.4f   gyro x %+7.3f  y %+7.3f  z %+7.3f   tilt %5.2f @ %+4.0f°   per-g gy %+6.1f gx %+6.1f z %+5.2f",
                         hit.attackX, hit.peakX, hit.attackZ, hit.attackGX, hit.attackGY, hit.attackGZ, tilt, angle, f.gyPerG, f.gxPerG, f.zPerG))
        }
    } else {
        print(String(format: "hit  %@  vel %3d  %4.0f Hz%@", label, Int(vel), hit.sampleRateHz, parked))
    }
    fflush(stdout)
}

guard sensor.hasChassisIMU else {
    FileHandle.standardError.write("no SPU accelerometer on this Mac\n".data(using: .utf8)!)
    exit(1)
}
guard sensor.start() else {
    FileHandle.standardError.write("sensor present but would not open (\(sensor.lastError ?? "unknown"))\n".data(using: .utf8)!)
    exit(1)
}

print("mactap-midi: streaming from SPU IMU")
if let midi { print("  MIDI source: \"\(midi.name)\"  note \(opts.noteLeft)\(opts.classifySides ? "/\(opts.noteRight)" : "")  ch \(opts.channel + 1)  gate \(Int(opts.gateMs)) ms") }
if let osc { print("  OSC: \(osc.host):\(osc.port)  /mactap/hit <side:int> <vel:int> <peak:float> <lat_ms:float>") }
if let control { print("  control: udp \(control.port)  /mactap/sensitivity|floor|ceil|curve|gate|note|note-right|refractory|sides|invert|side-hold <float>") }
print("  velocity: floor \(opts.magFloor) g → 1, ceil \(opts.magCeil) g → 127, curve \(opts.curve)")
if opts.calibrate { print("  calibrate: tap soft / medium / hard; watch peak, lat and Hz. Ctrl-C to stop.") }
if let model = zoneModel, learning == nil {
    print("  zones: " + model.zones.enumerated().map { "\(zoneLabel($0, $1.name, unsure: false)) → \($1.note)" }.joined(separator: "  "))
}
fflush(stdout)
if opts.learnSpec != nil {
    learning = (0, CACurrentMediaTime())
    learnPrompt(0)
}

if opts.selfTest {
    // 1.5 s: the sensor's first rate estimate lands at ~1 s, so the test hit
    // reports a real Hz figure instead of 0.
    DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 1.5) {
        let t = CACurrentMediaTime()
        detector.onHit?(MusicalHit(
            onsetTimestamp: t - 0.010, emitTimestamp: t, hostTime: t,
            side: .left, peakMagnitude: 0.2, peakX: 0.01,
            attackX: 0.01, attackZ: 0.02, attackGX: 0, attackGY: 0, attackGZ: 0,
            noiseFloor: 0.006, snr: 30, sampleRateHz: sensor.sampleRateHz
        ))
    }
}

// Sample-rate watchdog: one line at start, then only on park/recover.
var lastReportedHz: Double = -1
let watchdog = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
watchdog.schedule(deadline: .now() + 1, repeating: 1)
watchdog.setEventHandler {
    let hz = sensor.sampleRateHz
    let parked = hz < 450
    // Every hit line already carries the rate, so the watchdog speaks only
    // when the sensor parks or recovers.
    if lastReportedHz < 0 || parked != (lastReportedHz < 450) {
        print(String(format: "rate %4.0f Hz%@", hz, parked ? "  PARKED" : ""))
        fflush(stdout)
    }
    lastReportedHz = hz
}
watchdog.resume()

// A plain signal() handler that prints deadlocks against the watchdog's
// stdout lock; a dispatch source runs on a normal thread instead.
signal(SIGINT, SIG_IGN)
let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigint.setEventHandler {
    print("\nstopping")
    sensor.stop()
    exit(0)
}
sigint.resume()

// SensorManager schedules its HID run loop on its own thread; this run loop
// only has to keep the process alive.
RunLoop.main.run()

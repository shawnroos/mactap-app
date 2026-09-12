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
    var classifySides = false
    var invertSides = false
    var sideHoldMs: Double = 16
    var magFloor: Double = 0.012
    var magCeil: Double = 0.09
    var curve: Double = 0.6       // <1 lifts soft hits; 1 is linear
    var midi = true
    var osc: (host: String, port: UInt16)? = nil
    var calibrate = false
    var selfTest = false
    var controlPort: UInt16 = 7401

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
            case "--invert":      o.invertSides = true
            case "--side-hold":   o.sideHoldMs = Double(next() ?? "16") ?? 16
            case "--floor":       o.magFloor = Double(next() ?? "0.012") ?? 0.012
            case "--ceil":        o.magCeil = Double(next() ?? "0.09") ?? 0.09
            case "--curve":       o.curve = Double(next() ?? "0.6") ?? 0.6
            case "--no-midi":     o.midi = false
            case "--calibrate":   o.calibrate = true
            case "--test":        o.selfTest = true
            case "--control":     o.controlPort = UInt16(next() ?? "7401") ?? 7401
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
                  --sides           classify left/right (off: every hit is --note)
                  --invert          swap left and right
                  --side-hold MS    how long a hit is held to read its side with --sides (default 16)
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

let sensor = SensorManager()
let detector = TapDetector(sensor: sensor)
detector.musicalMode = true
detector.sensitivity = opts.sensitivity
detector.refractoryPeriod = opts.refractoryMs / 1000
detector.classifySides = opts.classifySides
detector.invertSides = opts.invertSides
detector.sideCaptureTime = opts.sideHoldMs / 1000
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
    FileHandle.standardError.write("could not bind control port \(opts.controlPort) (another bridge running?)\n".data(using: .utf8)!)
}

var hitCount = 0
var lastHitHost: Double = 0

// Colour only when a person is watching; logs stay plain.
let tty = isatty(STDOUT_FILENO) == 1
func sideLabel(_ side: TapSide) -> String {
    switch (side, tty) {
    case (.left, true):  return "\u{1B}[1;36mL\u{1B}[0m"
    case (.right, true): return "\u{1B}[1;35mR\u{1B}[0m"
    case (.left, false): return "L"
    case (.right, false): return "R"
    }
}

detector.onHit = { hit in
    let note = hit.side == .right ? live.noteRight : live.noteLeft
    let vel = velocity(for: hit.peakMagnitude)

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
                     hitCount, sideLabel(hit.side), hit.peakMagnitude, Int(vel),
                     hit.snr, hit.latency * 1000, gapMs, hit.sampleRateHz, parked))
        if live.classifySides {
            print(String(format: "           x %+.4f  px %+.4f  z %+.4f   gyro x %+7.3f  y %+7.3f  z %+7.3f",
                         hit.attackX, hit.peakX, hit.attackZ, hit.attackGX, hit.attackGY, hit.attackGZ))
        }
    } else {
        print(String(format: "hit  %@  vel %3d  %4.0f Hz%@", sideLabel(hit.side), Int(vel), hit.sampleRateHz, parked))
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
fflush(stdout)

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

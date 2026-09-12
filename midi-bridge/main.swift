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
    var magFloor: Double = 0.012
    var magCeil: Double = 0.055
    var curve: Double = 0.6       // <1 lifts soft hits; 1 is linear
    var midi = true
    var osc: (host: String, port: UInt16)? = nil
    var calibrate = false
    var selfTest = false

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
            case "--floor":       o.magFloor = Double(next() ?? "0.012") ?? 0.012
            case "--ceil":        o.magCeil = Double(next() ?? "0.055") ?? 0.055
            case "--curve":       o.curve = Double(next() ?? "0.6") ?? 0.6
            case "--no-midi":     o.midi = false
            case "--calibrate":   o.calibrate = true
            case "--test":        o.selfTest = true
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
                  --channel C       MIDI channel 1-16 (default 1)
                  --gate MS         note length in ms (default 30)
                  --sensitivity S   0..1 detector sensitivity (default 0.9)
                  --refractory MS   min gap between hits (default 45 → ~22 hits/s)
                  --floor G         peak magnitude mapped to velocity 1 (default 0.012)
                  --ceil G          peak magnitude mapped to velocity 127 (default 0.055)
                  --curve X         velocity curve exponent (default 0.6; 1 = linear)
                  --osc HOST:PORT   also send OSC /mactap/hit (default 127.0.0.1:7400)
                  --no-midi         skip the CoreMIDI source
                  --calibrate       print every hit's peak, latency and sample rate
                  --test            fire one synthetic hit at startup (checks MIDI/OSC plumbing)
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
detector.ignoreWhileTyping = false

func velocity(for magnitude: Double) -> UInt8 {
    let span = max(opts.magCeil - opts.magFloor, 1e-6)
    let t = min(max((magnitude - opts.magFloor) / span, 0), 1)
    let shaped = pow(t, opts.curve)
    return UInt8(max(1, min(127, Int((shaped * 126).rounded()) + 1)))
}

var hitCount = 0
var lastHitHost: Double = 0

detector.onHit = { hit in
    let note = hit.side == .right ? opts.noteRight : opts.noteLeft
    let vel = velocity(for: hit.peakMagnitude)

    midi?.noteOn(channel: opts.channel, note: note, velocity: vel)
    if let midi {
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + opts.gateMs / 1000) {
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
                     hitCount, hit.side == .right ? "R" : "L", hit.peakMagnitude, Int(vel),
                     hit.snr, hit.latency * 1000, gapMs, hit.sampleRateHz, parked))
    } else {
        print(String(format: "hit  %@  vel %3d  %4.0f Hz%@", hit.side == .right ? "R" : "L", Int(vel), hit.sampleRateHz, parked))
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
            noiseFloor: 0.006, snr: 30, sampleRateHz: sensor.sampleRateHz
        ))
    }
}

// Sample-rate watchdog: prints once a second so parking is visible even
// between hits. Silent when the rate is healthy unless calibrating.
var lastReportedHz: Double = -1
let watchdog = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
watchdog.schedule(deadline: .now() + 1, repeating: 1)
watchdog.setEventHandler {
    let hz = sensor.sampleRateHz
    let parked = hz < 450
    if opts.calibrate || parked != (lastReportedHz < 450) {
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

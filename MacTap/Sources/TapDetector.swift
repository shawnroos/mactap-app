import Foundation
import Combine
import QuartzCore

struct DetectedGesture: Sendable, Equatable {
    let side: TapSide
    let tapCount: Int
    let timestamp: Double
    let peakMagnitude: Double
    let peakX: Double
    var isSimulated: Bool = false

    var tapWord: String {
        switch tapCount {
        case 1: return "Single"
        case 2: return "Double"
        default: return "Triple"
        }
    }
}

/// One impulse in percussion mode.
struct MusicalHit: Sendable {
    /// Sensor clock at the first sample of the attack — the true note onset.
    let onsetTimestamp: Double
    /// Sensor clock when the capture closed and this hit was emitted.
    let emitTimestamp: Double
    /// `CACurrentMediaTime()` at emit, for measuring end-to-end latency.
    let hostTime: Double
    let side: TapSide
    let peakMagnitude: Double
    let peakX: Double
    /// Energy-weighted mean of each axis over the first ~34 ms. X is the
    /// lateral accel the side vote uses; gx/gy/gz are the gyro, unused so far.
    let attackX: Double
    let attackZ: Double
    let attackGX: Double
    let attackGY: Double
    let attackGZ: Double
    let noiseFloor: Double
    let snr: Double
    /// Accelerometer rate at the moment of the hit. Well under ~800 means the
    /// SPU had parked and the attack peak is probably under-sampled.
    let sampleRateHz: Double

    var latency: Double { emitTimestamp - onsetTimestamp }
}

/// Chassis-tap classifier on the undocumented SPU IMU (~800 Hz accel + gyro).
///
/// Onset follows Bonk (EMA delta, no minimum width). Side follows Knocker, but
/// at native 800 Hz we can do better: only the attack (~30 ms) counts, the
/// pre-tap X baseline is subtracted so gravity leak cannot pin every tap to
/// one edge, and bounce after ~35 ms is ignored.
final class TapDetector: ObservableObject {

    @Published private(set) var lastDetectedGesture: DetectedGesture?
    @Published private(set) var rawTapPulse: Double = 0
    @Published private(set) var pendingTapCount: Int = 0
    @Published private(set) var currentMagnitude: Double = 0
    @Published private(set) var noiseFloor: Double = 0.02
    @Published private(set) var lastRejectReason: String = ""

    var sensitivity: Double = 0.7
    var groupingWindow: Double = 0.32
    var invertSides = false
    var sideBias: Double = 0
    var ignoreWhileTyping = true
    var classifySides = false

    /// Percussion mode. Each impulse fires `onHit` the moment its capture closes
    /// (~8-15 ms), instead of waiting `groupingWindow` to see if a second tap
    /// makes it a double. Also drops the typing and burst lockouts, which a fast
    /// roll trips as a matter of course. `onGesture` never fires in this mode.
    var musicalMode = false

    /// Fired from `queue`, not the main queue — a main-queue hop adds run-loop
    /// jitter that is audible as timing slop.
    var onHit: ((MusicalHit) -> Void)?

    private var cancellables = Set<AnyCancellable>()
    private weak var sensor: SensorManager?
    private let queue = DispatchQueue(label: "app.mactap.detector", qos: .userInteractive)

    /// 0.07 caps the roll at ~14 hits/s, which 16ths above 200 bpm exceed.
    var refractoryPeriod: Double = 0.07
    private let maxPulseWidth: Double = 0.12
    private let minCaptureTime: Double = 0.032
    private let attackWindow: Double = 0.034
    private let attackTau: Double = 0.011
    private let typingBurstWindow: Double = 0.42
    private let typingLockout: Double = 0.28

    private var adaptiveNoise: Double = 0.006
    private var emaMag: Double = 0
    private var emaRaw: Double = 1.0
    private var lastTapTime: Double = -1
    private var lastTapPeak: Double = 0
    private var currentTapCount: Int = 0
    private var currentSide: TapSide = .left
    private var groupDeadline: Double = 0
    private var groupPeakMag: Double = 0
    private var groupPeakX: Double = 0

    private var capturing = false
    private var captureStart: Double = 0
    private var capturePeakMag: Double = 0
    private var captureSamples: Int = 0
    private var baselineX: Double = 0
    private var weightedX: Double = 0
    private var weightSum: Double = 0
    private var attackPeakX: Double = 0
    private var attackAbsX: Double = 0
    private var attackSumZ: Double = 0
    private var attackSumGX: Double = 0
    private var attackSumGY: Double = 0
    private var attackSumGZ: Double = 0
    private var captureSimulated = false
    private var groupSimulated = false

    private var histX: [Double] = []
    private var histT: [Double] = []
    private let histMax = 96

    private var impulseTimes: [Double] = []
    private var typingUntil: Double = -1
    private var lastUIPublish: Double = 0
    private var lastKeyTime: Double = -10

    /// Own rate estimate, counted on this queue. Reading SensorManager's
    /// published rate would be a cross-thread read of a main-queue property.
    private var rateTick: Double = 0
    private var emaDt: Double = 0
    private var localHz: Double = 0

    private var tapThreshold: Double {
        let minT = 0.012
        let maxT = 0.050
        return maxT - sensitivity * (maxT - minT)
    }

    private var snrMultiplier: Double {
        3.0 - sensitivity * 1.2
    }

    init(sensor: SensorManager) {
        self.sensor = sensor
        histX.reserveCapacity(histMax)
        histT.reserveCapacity(histMax)
        bind()
    }

    private func bind() {
        sensor?.sampleStream
            .receive(on: queue)
            .sink { [weak self] sample in
                self?.process(sample)
            }
            .store(in: &cancellables)

        sensor?.typingActivity
            .receive(on: queue)
            .sink { [weak self] in
                self?.lastKeyTime = CACurrentMediaTime()
            }
            .store(in: &cancellables)
    }

    /// Settings are read on the detector queue; write them there too.
    func update(_ block: @escaping (TapDetector) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            block(self)
        }
    }

    func notifyTyping() {
        queue.async { [weak self] in
            self?.lastKeyTime = CACurrentMediaTime()
        }
    }

    private func process(_ sample: SensorSample) {
        let mag = sample.magnitude
        let now = sample.timestamp

        // EMA of the inter-sample interval, not a per-second bucket: it must
        // still read "parked" on the first hit after an idle, before the
        // keep-alive re-wake has had a chance to land.
        if rateTick > 0 {
            let dt = now - rateTick
            if dt > 0 {
                emaDt = emaDt > 0 ? 0.05 * dt + 0.95 * emaDt : dt
                localHz = 1.0 / emaDt
            }
        }
        rateTick = now

        pushHistory(x: sample.x, t: now)

        emaMag = 0.02 * mag + 0.98 * emaMag
        let delta = mag - emaMag
        emaRaw = 0.02 * sample.rawMagnitude + 0.98 * emaRaw
        let rawDelta = abs(sample.rawMagnitude - emaRaw)

        if mag < tapThreshold * 0.9 {
            adaptiveNoise = 0.02 * mag + 0.98 * adaptiveNoise
        }
        adaptiveNoise = min(max(adaptiveNoise, 0.0035), 0.030)

        let threshold = max(tapThreshold * 0.88, adaptiveNoise * snrMultiplier)
        let keyedRecently = ignoreWhileTyping && (CACurrentMediaTime() - lastKeyTime) < 0.18
        let inTypingLockout = now < typingUntil || keyedRecently
        let inRefractory = (now - lastTapTime) < refractoryPeriod
        // The 0.022 g raw floor exists to ignore desk bumps while typing. Measured
        // soft knocks peak at ~0.022 g, so in musical mode it would cut them.
        let rawFloor = musicalMode ? threshold * 0.5 : max(0.022, threshold * 0.65)
        let onset = (mag > threshold || delta > threshold) && rawDelta > rawFloor

        if capturing {
            absorb(sample)
            let elapsed = now - captureStart
            let quiet = mag < capturePeakMag * 0.35 && elapsed >= (classifySides ? minCaptureTime : 0.006)
            if quiet || elapsed > maxPulseWidth || captureSamples > 100 {
                finalizeCapture(now: now, inTypingLockout: inTypingLockout, keyedRecently: keyedRecently)
            }
        } else if !inRefractory && onset {
            startCapture(sample)
        }

        if currentTapCount > 0 && now >= groupDeadline {
            emitGesture(now: now)
        }

        if now - lastUIPublish > 0.05 {
            lastUIPublish = now
            let noise = adaptiveNoise
            let pending = currentTapCount
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.currentMagnitude = mag
                self.rawTapPulse = mag
                self.noiseFloor = noise
                self.pendingTapCount = pending
            }
        }
    }

    private func pushHistory(x: Double, t: Double) {
        histX.append(x)
        histT.append(t)
        let overflow = histX.count - histMax
        if overflow > 0 {
            histX.removeFirst(overflow)
            histT.removeFirst(overflow)
        }
    }

    /// Mean X from 15–90 ms before onset. Residual gravity on HP X is a DC
    /// offset; integrating it makes every tap look like the same side.
    private func preTapBaseline(at now: Double) -> Double {
        var sum = 0.0
        var n = 0
        for i in histX.indices {
            let age = now - histT[i]
            if age > 0.012 && age < 0.10 {
                sum += histX[i]
                n += 1
            }
        }
        guard n >= 4 else { return 0 }
        return sum / Double(n)
    }

    private func startCapture(_ sample: SensorSample) {
        capturing = true
        captureStart = sample.timestamp
        capturePeakMag = sample.magnitude
        captureSamples = 1
        baselineX = preTapBaseline(at: sample.timestamp)
        weightedX = 0
        weightSum = 0
        attackPeakX = 0
        attackAbsX = 0
        attackSumZ = 0
        attackSumGX = 0
        attackSumGY = 0
        attackSumGZ = 0
        captureSimulated = sample.isSimulated
        accumulateAttack(sample)
    }

    private func absorb(_ sample: SensorSample) {
        captureSamples += 1
        if sample.magnitude > capturePeakMag {
            capturePeakMag = sample.magnitude
        }
        if sample.isSimulated { captureSimulated = true }
        accumulateAttack(sample)
    }

    private func accumulateAttack(_ sample: SensorSample) {
        let t = sample.timestamp - captureStart
        guard t <= attackWindow else { return }
        let w = exp(-t / attackTau)
        let dx = sample.x - baselineX
        weightedX += dx * w
        weightSum += w
        attackSumZ += sample.z * w
        attackSumGX += sample.gx * w
        attackSumGY += sample.gy * w
        attackSumGZ += sample.gz * w
        if abs(dx) > attackAbsX {
            attackAbsX = abs(dx)
            attackPeakX = dx
        }
    }

    private func finalizeCapture(now: Double, inTypingLockout: Bool, keyedRecently: Bool) {
        capturing = false
        let peak = capturePeakMag
        let width = now - captureStart
        let snr = adaptiveNoise > 0 ? peak / adaptiveNoise : 99
        let meanAttackX = weightSum > 1e-9 ? weightedX / weightSum : attackPeakX
        let meanAttackZ = weightSum > 1e-9 ? attackSumZ / weightSum : 0

        defer { resetCapture() }

        if width > 0.16 {
            publishReject("slow pulse")
            return
        }
        // A hard knock rings the chassis for ~150 ms at ~20% of its peak;
        // real roll hits measured 58-76% of the previous one.
        if musicalMode && now - lastTapTime < 0.25 && peak < lastTapPeak * 0.35 {
            publishReject("echo")
            return
        }
        if snr < 1.6 {
            publishReject("low SNR")
            return
        }
        if !musicalMode {
            if keyedRecently && abs(meanAttackZ) > abs(meanAttackX) * 3.8 && attackAbsX < 0.006 {
                publishReject("vertical (typing)")
                return
            }
            if inTypingLockout {
                publishReject("typing lockout")
                return
            }

            impulseTimes.append(now)
            impulseTimes = impulseTimes.filter { now - $0 < typingBurstWindow }
            if impulseTimes.count >= 6 {
                typingUntil = now + typingLockout
                impulseTimes.removeAll()
                publishReject("burst lockout")
                return
            }
        }

        let meanAttackGY = weightSum > 1e-9 ? attackSumGY / weightSum : 0
        let side: TapSide
        if !classifySides {
            side = .left
        } else if musicalMode && abs(meanAttackGY) >= 0.1 {
            // Measured on 20 labelled knocks: a knock tilts the chassis, and
            // gyro Y read the side 19/20 (one near zero) where lateral X read
            // 17/20. Sign convention is per machine; invertSides flips it.
            let left = meanAttackGY > 0
            side = (left != invertSides) ? .left : .right
        } else {
            side = classifySide(meanX: meanAttackX, peakX: attackPeakX)
        }
        let reportX = meanAttackX

        lastTapTime = now
        lastTapPeak = peak

        if musicalMode {
            onHit?(MusicalHit(
                onsetTimestamp: captureStart,
                emitTimestamp: now,
                hostTime: CACurrentMediaTime(),
                side: side,
                peakMagnitude: peak,
                peakX: attackPeakX,
                attackX: meanAttackX,
                attackZ: meanAttackZ,
                attackGX: weightSum > 1e-9 ? attackSumGX / weightSum : 0,
                attackGY: weightSum > 1e-9 ? attackSumGY / weightSum : 0,
                attackGZ: weightSum > 1e-9 ? attackSumGZ / weightSum : 0,
                noiseFloor: adaptiveNoise,
                snr: snr,
                sampleRateHz: localHz
            ))
            return
        }

        currentTapCount += 1
        groupPeakMag = max(groupPeakMag, peak)
        groupPeakX = abs(reportX) > abs(groupPeakX) ? reportX : groupPeakX
        groupSimulated = groupSimulated || captureSimulated

        if currentTapCount == 1 {
            currentSide = side
            groupDeadline = now + groupingWindow
            groupSimulated = captureSimulated
        } else if side != currentSide && attackAbsX > 0.008 {
            emitGesture(now: now)
            currentTapCount = 1
            currentSide = side
            groupPeakMag = peak
            groupPeakX = reportX
            groupSimulated = captureSimulated
            groupDeadline = now + groupingWindow
        }

        if currentTapCount >= 3 {
            emitGesture(now: now)
        }
    }

    /// Two votes from the attack only: energy-weighted mean X, and X at max |X|.
    /// Knocker default: +X = right. Bounce after ~35 ms is never consulted.
    private func classifySide(meanX: Double, peakX: Double) -> TapSide {
        var a = meanX + sideBias
        var p = peakX + sideBias
        if invertSides {
            a = -a
            p = -p
        }

        var right = 0
        var left = 0
        func vote(_ v: Double, floor: Double) {
            guard abs(v) >= floor else { return }
            if v > 0 { right += 1 } else { left += 1 }
        }
        vote(a, floor: 0.0024)
        vote(p, floor: 0.0040)

        if right > left { return .right }
        if left > right { return .left }
        // Tie or both weak: trust the weighted mean (less bounce).
        return a >= 0 ? .right : .left
    }

    private func resetCapture() {
        capturePeakMag = 0
        captureSamples = 0
        baselineX = 0
        weightedX = 0
        weightSum = 0
        attackPeakX = 0
        attackAbsX = 0
        attackSumZ = 0
        attackSumGX = 0
        attackSumGY = 0
        attackSumGZ = 0
        captureSimulated = false
    }

    private func emitGesture(now: Double) {
        guard currentTapCount > 0 else { return }

        let gesture = DetectedGesture(
            side: currentSide,
            tapCount: currentTapCount,
            timestamp: now,
            peakMagnitude: groupPeakMag,
            peakX: groupPeakX,
            isSimulated: groupSimulated
        )

        currentTapCount = 0
        groupPeakMag = 0
        groupPeakX = 0
        groupSimulated = false
        capturing = false
        resetCapture()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lastDetectedGesture = gesture
            self.pendingTapCount = 0
            self.onGesture?(gesture)
        }
    }

    private func publishReject(_ reason: String) {
        DispatchQueue.main.async { [weak self] in
            self?.lastRejectReason = reason
        }
    }

    var onGesture: ((DetectedGesture) -> Void)?

    static var sideHeuristicDescription: String {
        "Left/right uses the first ~30 ms of lateral X after subtracting the pre-tap baseline — the same impulse idea as Knocker, but bounce and gravity leak are ignored. Invert if your chassis is mirrored."
    }
}

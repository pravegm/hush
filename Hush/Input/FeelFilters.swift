import Foundation

// Smoothing building blocks for the hinge → lid pipeline. Ported from Swoop's `Input/FeelFilters.swift` (itself from
// Brim and Squish, all battle-tested on a real Duo). Pure value types with explicit times, so every one of them is
// unit-testable without a device.

/// Small pure helpers for the Input and Feedback modules.
enum FeelMath {
    static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    /// 0…1, NaN → 0.
    static func clamp01(_ value: Double) -> Double {
        value.isFinite ? min(max(value, 0), 1) : 0
    }

    /// Hermite smoothstep of `x` clamped to 0…1: 3x² − 2x³ (zero slope at both ends).
    static func smoothstep(_ x: Double) -> Double {
        let u = clamp01(x)
        return u * u * (3 - 2 * u)
    }

    /// A finite, non-negative value (NaN and negatives → 0, +∞ → `cap`).
    static func positive(_ value: Double, cap: Double = 1_000) -> Double {
        guard !value.isNaN else { return 0 }
        return min(max(value, 0), cap)
    }
}

/// One-Euro filter (Casiez et al., CHI 2012): heavy smoothing while the input is slow, low lag while it moves fast.
/// Squish's tuning for the Duo hinge: minCutoff 2.0, β 0.12, dCutoff 1.5; dt clamped to 1/240…0.2 s.
struct OneEuroSmoother {
    var minCutoff: Double
    var beta: Double
    var dCutoff: Double

    private(set) var value: Double?
    /// Filtered derivative of the input (units per second).
    private(set) var derivative: Double = 0
    private var lastTime: Double?

    init(minCutoff: Double = 2.0, beta: Double = 0.12, dCutoff: Double = 1.5) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }

    mutating func reset() {
        value = nil
        derivative = 0
        lastTime = nil
    }

    mutating func filter(_ x: Double, at time: Double) -> Double {
        guard x.isFinite else { return value ?? 0 }
        guard let previous = value, let previousTime = lastTime else {
            value = x
            lastTime = time
            derivative = 0
            return x
        }
        let dt = min(max(time - previousTime, 1.0 / 240.0), 0.2)
        let rawDerivative = (x - previous) / dt
        derivative += (rawDerivative - derivative) * Self.alpha(cutoff: dCutoff, dt: dt)
        let cutoff = minCutoff + beta * abs(derivative)
        let filtered = previous + (x - previous) * Self.alpha(cutoff: cutoff, dt: dt)
        value = filtered
        lastTime = time
        return filtered
    }

    private static func alpha(cutoff: Double, dt: Double) -> Double {
        let r = 2 * Double.pi * cutoff * dt
        return r / (r + 1)
    }
}

/// The hinge at display rate (Squish `HingeTracker`, copied from Swoop unchanged). The Duo reports 25–30 Hz while
/// moving and nothing while still, so the picture must move continuously *between* reports and never hold, then jump.
///
/// An alpha-beta tracker on the raw samples: between samples it extrapolates at the tracked velocity for about one
/// sample interval, then eases to a stop; each correction is blended in over ~40 ms; once reports stop it glides onto
/// the last raw reading. Jumps larger than `snapDegrees` snap.
struct HingePredictor {
    static let alpha = 0.75
    static let beta = 0.35
    static let maxSpeed = 900.0
    static let coast = 1.0
    static let ease = 0.3
    static let horizonMin = 0.03
    static let horizonMax = 0.2
    static let snapDegrees = 90.0
    static let restGlide = 0.05

    /// The tracked (alpha-beta) angle as of the last report.
    private(set) var estimate: Double?
    /// °/s, positive while the angle grows (opening).
    private(set) var velocity = 0.0
    private(set) var lastSampleTime = 0.0
    /// Smoothed time between samples (s).
    private(set) var interval = 1.0 / 30
    private var offset = 0.0
    private var offsetTime = 0.0
    private var lastReading = 180.0

    init() {}

    mutating func reset() {
        estimate = nil
        velocity = 0
        offset = 0
    }

    mutating func sample(_ angle: Double, at time: Double) {
        lastReading = angle
        guard estimate != nil else {
            estimate = angle
            velocity = 0
            lastSampleTime = time
            offset = 0
            offsetTime = time
            return
        }
        let shown = self.angle(at: time)
        let dt = min(max(time - lastSampleTime, 1.0 / 240), 0.5)
        let predicted = raw(at: time)
        let tau = max(0.03, Self.ease * interval)
        let prior = velocity * exp(-max(0, (time - lastSampleTime) - 2 * horizon) / tau)
        interval += (min(dt, 0.25) - interval) * 0.3
        let surprise = angle - predicted
        if abs(surprise) > Self.snapDegrees {
            estimate = angle
            velocity = 0
            lastSampleTime = time
            offset = 0
            offsetTime = time
            return
        }
        estimate = predicted + Self.alpha * surprise
        velocity = FeelMath.clamp(prior + Self.beta / dt * surprise, -Self.maxSpeed, Self.maxSpeed)
        lastSampleTime = time
        offset = shown - raw(at: time)
        offsetTime = time
    }

    var horizon: Double { FeelMath.clamp(Self.coast * interval, Self.horizonMin, Self.horizonMax) }

    private func extrapolation(at time: Double) -> Double {
        let age = max(time - lastSampleTime, 0)
        if age <= horizon { return age }
        let tau = max(0.03, Self.ease * interval)
        return horizon + tau * (1 - exp(-(age - horizon) / tau))
    }

    private func raw(at time: Double) -> Double {
        (estimate ?? 180) + velocity * extrapolation(at: time)
    }

    /// The hinge angle to use at `time` (degrees, 0…180).
    func angle(at time: Double) -> Double {
        guard estimate != nil else { return 180 }
        let blend = exp(-max(time - offsetTime, 0) / max(0.04, 0.35 * interval))
        let moving = FeelMath.clamp(raw(at: time) + offset * blend, 0, 180)
        let rest = horizon + 3 * max(0.03, Self.ease * interval)
        let age = max(time - lastSampleTime, 0)
        guard age > rest else { return moving }
        let k = 1 - exp(-(age - rest) / Self.restGlide)
        return moving + (lastReading - moving) * k
    }

    /// Reports per second, from the smoothed interval.
    var rate: Double { 1 / max(interval, 1e-3) }
}

/// Lid speed (°/s, ≥ 0) from irregular position samples: the hinge's 25–30 Hz reports, or the lid slider's touches
/// (ARCHITECTURE "Speed"). This is the number the whole game is judged on, so it has to be robust to the Duo's habits.
///
/// - **One-Euro on the angle**, per sample (minCutoff 2 Hz, β 0.12), so ±1° report jitter doesn't read as motion.
/// - **Smoothed over 0.25 s**: per sample, the speed over the last `window` s of filtered samples is the mean of the
///   net speed (|end − start| / elapsed) and the path speed (Σ|step| / elapsed). A steady move reads exactly; a fast
///   wiggle still counts (half its path), so shaking the lid isn't a loophole; uneven report spacing cancels out.
/// - **Gap-aware**: elapsed times are real times, never a nominal 1/30 s, and no derivative is ever taken across a
///   silence longer than `restartGap`: the sample after a gap restarts the filter as a new base, contributing no
///   speed, so a report after a long still (the Duo sends nothing while still) never makes a spike.
/// - **Decay**: with no sample for more than `hold` s the speed decays towards 0 (time constant `decayTau`).
/// - At display rate the reported speed follows the per-sample estimate with a `followTau` one-pole, so it never
///   steps at the report rate (the creak audio and haptics read it every frame).
struct FeelSpeedEstimator {
    /// The smoothing window (s).
    static let window = 0.25
    /// No sample for longer than this (s) and the speed starts to decay.
    static let hold = 0.12
    /// Decay time constant (s) once samples have stopped.
    static let decayTau = 0.15
    /// Display-rate follow time constant (s) while samples arrive.
    static let followTau = 0.04
    /// A silence longer than this (s) restarts the filter: no derivative across it.
    static let restartGap = 0.25
    /// The smallest elapsed time a speed is ever divided by (two reports in one frame can't make a spike).
    static let minElapsed = 1.0 / 60
    /// Samples kept (≥ window × the fastest touch rate of 120 Hz).
    static let capacity = 40
    /// No lid moves faster than this (°/s); a sanity cap.
    static let maxSpeed = 720.0

    private var smoother: OneEuroSmoother
    private var times: [Double] = []
    private var values: [Double] = []
    /// The per-sample estimate as of the last sample (°/s).
    private(set) var sampleSpeed: Double = 0
    /// The display-rate speed as of the last `speed(at:)` (°/s).
    private(set) var speed: Double = 0
    private(set) var lastSampleTime: Double?
    private var lastFrame: Double?

    init(smoother: OneEuroSmoother = OneEuroSmoother(minCutoff: 2.0, beta: 0.12, dCutoff: 1.5)) {
        self.smoother = smoother
        times.reserveCapacity(Self.capacity + 1)
        values.reserveCapacity(Self.capacity + 1)
    }

    /// Forget everything (the next sample is a fresh base).
    mutating func reset() {
        smoother.reset()
        times.removeAll(keepingCapacity: true)
        values.removeAll(keepingCapacity: true)
        sampleSpeed = 0
        speed = 0
        lastSampleTime = nil
        lastFrame = nil
    }

    /// The One-Euro-filtered position as of the last sample.
    var filteredValue: Double? { values.last }

    /// A position sample (degrees) at `time` (s). Samples that go back in time are stamped at the last sample's time.
    mutating func sample(_ x: Double, at time: Double) {
        guard x.isFinite, time.isFinite else { return }
        let stamp = max(time, lastSampleTime ?? time)
        if let last = lastSampleTime, stamp - last <= Self.restartGap {
            let filtered = smoother.filter(x, at: stamp)
            times.append(stamp)
            values.append(filtered)
            if times.count > Self.capacity {
                times.removeFirst(times.count - Self.capacity)
                values.removeFirst(values.count - Self.capacity)
            }
            lastSampleTime = stamp
            sampleSpeed = windowSpeed()
        } else {
            // First sample, or the first after a silence: a new base. If no frame decayed the speed through the
            // silence (frames stopped), decay it here so the next frame can't start from a stale value.
            if let last = lastSampleTime {
                let quiet = max(stamp - last - Self.hold, 0)
                speed = min(speed, sampleSpeed * exp(-quiet / Self.decayTau))
            }
            smoother.reset()
            let filtered = smoother.filter(x, at: stamp)
            times.removeAll(keepingCapacity: true)
            values.removeAll(keepingCapacity: true)
            times.append(stamp)
            values.append(filtered)
            lastSampleTime = stamp
            sampleSpeed = 0
        }
    }

    /// The speed over the window ending at the newest sample.
    private func windowSpeed() -> Double {
        let count = times.count
        guard count >= 2 else { return 0 }
        let newest = times[count - 1]
        let start = newest - Self.window
        var base = 0
        var index = count - 2
        while index >= 0 {
            if times[index] <= start {
                base = index
                break
            }
            index -= 1
        }
        var path = 0.0
        var k = base + 1
        while k < count {
            path += abs(values[k] - values[k - 1])
            k += 1
        }
        let net = abs(values[count - 1] - values[base])
        let elapsed = max(newest - times[base], Self.minElapsed)
        return FeelMath.positive(0.5 * (net + path) / elapsed, cap: Self.maxSpeed)
    }

    /// The speed at display time `time` (°/s, ≥ 0). Call once per frame; asking again for the same (or an older) time
    /// returns the same answer without advancing.
    mutating func speed(at time: Double) -> Double {
        guard let last = lastSampleTime, time.isFinite else { return 0 }
        if let previous = lastFrame, time <= previous { return speed }
        let dt = lastFrame.map { time - $0 } ?? 0
        lastFrame = time
        let age = time - last
        if age <= Self.hold {
            let k = 1 - exp(-min(dt, 0.1) / Self.followTau)
            speed += (sampleSpeed - speed) * k
        } else {
            let decayTime = min(dt, age - Self.hold)
            speed *= exp(-max(decayTime, 0) / Self.decayTau)
            if speed < 1e-4 { speed = 0 }
        }
        speed = FeelMath.positive(speed, cap: Self.maxSpeed)
        return speed
    }

    /// The speed at `time` judged without advancing anything (°/s, ≥ 0): the larger of the per-sample and display
    /// estimates, decaying like `speed(at:)` once samples stop. Never below what a frame would read, so "held still"
    /// judged from it is conservative. Works with no frames at all (the game paused).
    func peekSpeed(at time: Double) -> Double {
        guard let last = lastSampleTime, time.isFinite else { return 0 }
        let level = max(speed, sampleSpeed)
        let age = time - last
        guard age > Self.hold else { return FeelMath.positive(level, cap: Self.maxSpeed) }
        return FeelMath.positive(level * exp(-(age - Self.hold) / Self.decayTau), cap: Self.maxSpeed)
    }
}

/// The "lid is closing" gate (GAME-DESIGN §3): closed when the angle stays under `closingAngle` (70°) for
/// `Tuning.closingDwell` (0.4 s); it opens again above `closingAngle + reopenMargin` (78°), so ±1° jitter at 70° can't
/// flicker the pause card. Pure, with explicit times; `isClosing(at:)` lets the dwell mature with time alone.
///
/// R2 (REVIEW-1-duo P1-4): the line is **70°** (R1's 85° sat inside the natural upright 90° rest, within the Duo's ±5°
/// accuracy) and it unlatches above **78°**. Unlatching is not resuming: the run resumes only on
/// `HingeLidSource.canResume` (≥ 95°, held still).
struct FeelClosingGate {
    /// θ under this for `dwell` s pauses the game (`Tuning.closingAngle`, 70° from R2).
    static var closingAngle: Double { Tuning.closingAngle }
    static let reopenMargin = 8.0

    static var closeBelow: Double { closingAngle }
    static var dwell: Double { Tuning.closingDwell }
    static var reopenAbove: Double { closingAngle + reopenMargin }

    /// Latched closed (until above `reopenAbove`).
    private(set) var latched = false
    /// When the angle went under `closeBelow` (the dwell running), if it has.
    private(set) var belowSince: Double?

    init() {}

    /// Closed at `time`: latched, or under the closing angle for the whole dwell.
    func isClosing(at time: Double) -> Bool {
        if latched { return true }
        guard let since = belowSince, time.isFinite else { return false }
        return time - since >= Self.dwell
    }

    /// Feed an angle at `time`.
    mutating func update(angle: Double, at time: Double) {
        guard angle.isFinite, time.isFinite else { return }
        if isClosing(at: time) {
            latched = true
            belowSince = nil
        }
        if latched {
            if angle > Self.reopenAbove { latched = false }
            return
        }
        if angle < Self.closeBelow {
            if belowSince == nil { belowSince = time }
        } else {
            belowSince = nil
        }
    }

    mutating func reset() {
        latched = false
        belowSince = nil
    }
}

/// `HUSH-T …` demo/timing lines for CI, only in DEBUG builds launched with the `-hushDemo` argument (Release carries
/// neither the check nor the string). Flushed at once.
enum FeelDemoLog {
    #if DEBUG
    static let isEnabled: Bool = ProcessInfo.processInfo.arguments.contains("-hushDemo")
    #else
    static let isEnabled: Bool = false
    #endif

    /// Prints `s` (which should start with `HUSH-`) when enabled.
    static func line(_ s: String) {
        guard isEnabled else { return }
        print(s)
        fflush(stdout)
    }

    /// Same as `line(_:)` (Swoop's name, for copied code).
    static func emit(_ s: String) {
        line(s)
    }
}

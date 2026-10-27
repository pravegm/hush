import Foundation
import QuartzCore

/// The chest lid on the iPhone Duo (GAME-DESIGN §3): hinge samples in (from `HingeReader`), `LidInput` out at display
/// rate.
///
/// Two pipelines read the same raw reports (25–30 Hz while moving, none while still, about ±5° accuracy):
/// - **Angle** (openness, shut zone, too wide, closing): `HingePredictor` (alpha-beta, predicts between reports) sampled
///   every frame → One-Euro (minCutoff 2.0, β 0.12). Continuous between reports, so the light never steps.
/// - **Speed** (the skill): `FeelSpeedEstimator` on the raw reports: One-Euro per report, net/path speed over 0.25 s,
///   gap-aware, decaying to 0 (τ 0.15 s) once reports stop for 0.12 s. It never looks at the predictor, so the
///   predictor's extrapolation can't invent motion.
///   R2 (REVIEW-1-duo P1-5): the speedometer sees the angle **clamped to 97…168°** (`speedAngleRange`), so hinge motion
///   outside the play range (folding the phone shut, a detent snap near flat) makes no noise. A slam through 150 → 100
///   still counts in full.
///
/// R2 resume rule (REVIEW-1-duo P0-2): the closing pause starts under 70° for 0.4 s (`isClosing`), but the run resumes
/// only on `canResume`: θ ≥ 95° **and** the hinge's real motion (unclamped) under 6°/s, held for 0.3 s. Call `reset()`
/// at the moment of resume (and on becoming active).
///
/// Never use the hinge's `status` (it reads `.closed` at ~85° on hardware); everything here is the angle.
@MainActor
final class HingeLidSource: LidSource {
    /// The angle range the speedometer sees (degrees): `Tuning.shutAngle − 3` … `Tuning.wideAngle + 3` (97…168°).
    nonisolated static var speedAngleRange: ClosedRange<Double> { (Tuning.shutAngle - 3)...(Tuning.wideAngle + 3) }
    /// Resume needs the lid at least this open (degrees) …
    static let resumeAngle = 95.0
    /// … moving slower than this (°/s, the unclamped hinge motion) …
    static let resumeSpeed = 6.0
    /// … for this long (s).
    static let resumeHold = 0.3

    private var predictor = HingePredictor()
    private var smoother = OneEuroSmoother(minCutoff: 2.0, beta: 0.12, dCutoff: 1.5)
    /// The game's speed (noise): fed the angle clamped to `speedAngleRange`.
    private var speedometer = FeelSpeedEstimator()
    /// The hinge's real motion at any angle (the resume rule's "held still"): fed the raw angle.
    private var motionMeter = FeelSpeedEstimator()
    private var gate = FeelClosingGate()
    /// Since when the resume condition (θ ≥ 95°, motion < 6°/s) has held without a break, if it holds.
    private var resumeSince: TimeInterval?

    /// True once any real hinge sample has arrived (never goes back to false).
    private(set) var hasHinge = false
    /// The filtered hinge angle (180 = flat); nil before any sample.
    private(set) var angle: Double?
    /// The last raw reading and when it arrived (diagnostics, `HUSH-T lid` lines).
    private(set) var lastRawAngle: Double?
    private(set) var lastSampleTime: TimeInterval?
    /// The lid speed (°/s) returned by the last `lid(at:)`.
    private(set) var speed: Double = 0
    /// The value returned by the last `lid(at:)`.
    private(set) var lastLid = LidInput()

    /// The clock `isClosing` and `canResume` judge their dwells against (the hinge samples' clock). Tests set their own.
    var clock: () -> TimeInterval = { CACurrentMediaTime() }

    private var lastQuery: TimeInterval?

    init() {}

    /// The latest time anything has told us about: the clock, the last frame, the last report.
    private var now: TimeInterval {
        max(clock(), lastQuery ?? -Double.infinity, lastSampleTime ?? -Double.infinity)
    }

    /// True while the lid is closing (GAME-DESIGN §3, R2): the filtered angle stayed under 70° (`FeelClosingGate`) for
    /// `Tuning.closingDwell` (0.4 s). It clears above 78° (8° of hysteresis). While frames run it judges the display
    /// angle; while they don't (the game paused) it judges the tracked reports. The dwell matures with the clock even
    /// when no frame or report arrives (the Duo sends nothing while still). Clearing is not resuming: see `canResume`.
    var isClosing: Bool {
        closing(at: now)
    }

    /// `isClosing` judged at `time`.
    func closing(at time: TimeInterval) -> Bool {
        hasHinge && gate.isClosing(at: time)
    }

    /// R2 (REVIEW-1-duo P0-2): a paused run (closing pause, cover display, book pose) may resume. True once the lid is
    /// at least 95° open and the hinge has moved slower than 6°/s for 0.3 s without a break. Works with or without
    /// frames (it judges the reports and lets the hold mature on the clock), so poll it every frame while paused. A
    /// reopening hand never resumes mid-motion; call `reset()` when you resume.
    var canResume: Bool {
        resumable(at: now)
    }

    /// `canResume` judged at `time`.
    func resumable(at time: TimeInterval) -> Bool {
        guard hasHinge, time.isFinite else { return false }
        observeResume(angle: angle ?? lastRawAngle, at: time)
        guard let since = resumeSince else { return false }
        return time - since >= Self.resumeHold
    }

    /// The hinge's real motion (°/s) at any angle, unclamped (diagnostics and the resume rule).
    var motionSpeed: Double {
        motionMeter.peekSpeed(at: now)
    }

    /// One hinge report: degrees (180 = flat), stamped on receipt with `CACurrentMediaTime()`.
    func ingest(angleDegrees: Double, at time: TimeInterval) {
        guard angleDegrees.isFinite, time.isFinite else { return }
        let raw = FeelMath.clamp(angleDegrees, 0, 180)
        // Never let a sample go back in time (it would make the filters' dt negative).
        let stamp = max(time, lastSampleTime ?? time)
        hasHinge = true
        lastRawAngle = raw
        lastSampleTime = stamp
        predictor.sample(raw, at: stamp)
        speedometer.sample(Self.speedAngle(raw), at: stamp)
        motionMeter.sample(raw, at: stamp)
        // Keep `angle` (and the closing gate) fresh while no frame asks: the pause card, menus. Frames take over at once.
        let framesLive = stamp - (lastQuery ?? -Double.infinity) <= 0.1
        if angle == nil || !framesLive {
            let tracked = predictor.estimate ?? raw
            angle = tracked
            gate.update(angle: tracked, at: stamp)
            observeResume(angle: tracked, at: stamp)
        }
    }

    /// The lid for the frame at `time` (`CACurrentMediaTime()` clock). No hinge yet: a shut, still lid.
    func lid(at time: TimeInterval) -> LidInput {
        guard hasHinge, time.isFinite else { return LidInput() }
        // Asked twice for the same frame (or an older one): same answer, and the filters don't advance.
        if let previous = lastQuery, time <= previous { return lastLid }
        lastQuery = time
        let predicted = predictor.angle(at: time)
        let smoothed = smoother.filter(predicted, at: time)
        angle = smoothed
        gate.update(angle: smoothed, at: time)
        observeResume(angle: smoothed, at: time)
        speed = speedometer.speed(at: time)
        let lid = Self.lidInput(angle: smoothed, speed: speed)
        lastLid = lid
        return lid
    }

    /// Forget the motion history (keeps `hasHinge`, the last reading and the closing latch). Call it when a paused run
    /// resumes and when the app becomes active, so a stale speed or a stale glide can't leak into the first frames.
    /// The resume hold starts again from nothing.
    func reset() {
        predictor.reset()
        smoother.reset()
        speedometer.reset()
        motionMeter.reset()
        lastQuery = nil
        speed = 0
        lastLid = LidInput(openness: lastLid.openness, speed: 0, inShutZone: lastLid.inShutZone,
                           tooWide: lastLid.tooWide)
        resumeSince = nil
        if let raw = lastRawAngle, let stamp = lastSampleTime {
            predictor.sample(raw, at: stamp)
            speedometer.sample(Self.speedAngle(raw), at: stamp)
            motionMeter.sample(raw, at: stamp)
        }
    }

    /// Track the resume condition at `time`: it must hold without a break for `resumeHold`.
    private func observeResume(angle: Double?, at time: TimeInterval) {
        guard let angle, angle.isFinite, time.isFinite else {
            resumeSince = nil
            return
        }
        let still = motionMeter.peekSpeed(at: time) < Self.resumeSpeed
        if angle >= Self.resumeAngle && still {
            if resumeSince == nil { resumeSince = time }
        } else {
            resumeSince = nil
        }
    }

    /// The angle the speedometer sees: clamped to the play range, so motion outside it is silent.
    nonisolated static func speedAngle(_ raw: Double) -> Double {
        let range = speedAngleRange
        return FeelMath.clamp(raw, range.lowerBound, range.upperBound)
    }

    /// The game's view of a filtered angle and speed (GAME-DESIGN §3): openness over 100…165°, shut zone ≤ 110°,
    /// too wide > 172°. Pure.
    nonisolated static func lidInput(angle: Double, speed: Double) -> LidInput {
        guard angle.isFinite else { return LidInput(speed: FeelMath.positive(speed)) }
        return LidInput(openness: FeelMath.clamp01(Lid.openness(angle: angle)),
                        speed: FeelMath.positive(speed),
                        inShutZone: angle <= Tuning.shutZoneAngle,
                        tooWide: angle > Tuning.tooWideAngle)
    }
}

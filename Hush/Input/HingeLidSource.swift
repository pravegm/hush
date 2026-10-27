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
///
/// Never use the hinge's `status` (it reads `.closed` at ~85° on hardware); everything here is the angle.
@MainActor
final class HingeLidSource: LidSource {
    private var predictor = HingePredictor()
    private var smoother = OneEuroSmoother(minCutoff: 2.0, beta: 0.12, dCutoff: 1.5)
    private var speedometer = FeelSpeedEstimator()
    private var gate = FeelClosingGate()

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

    /// The clock `isClosing` judges the dwell against (the hinge samples' clock). Tests set their own.
    var clock: () -> TimeInterval = { CACurrentMediaTime() }

    private var lastQuery: TimeInterval?

    init() {}

    /// True while the lid is closing (GAME-DESIGN §3): the filtered angle stayed under `Tuning.closingAngle` (85°) for
    /// `Tuning.closingDwell` (0.4 s). It clears above 88° (3° of hysteresis). While frames run it judges the display
    /// angle; while they don't (the game paused) it judges the tracked reports, so reopening always resumes. The dwell
    /// matures with the clock even when no frame or report arrives (the Duo sends nothing while still).
    var isClosing: Bool {
        closing(at: max(clock(), lastQuery ?? -Double.infinity, lastSampleTime ?? -Double.infinity))
    }

    /// `isClosing` judged at `time`.
    func closing(at time: TimeInterval) -> Bool {
        hasHinge && gate.isClosing(at: time)
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
        speedometer.sample(raw, at: stamp)
        // Keep `angle` (and the closing gate) fresh while no frame asks: the pause card, menus. Frames take over at once.
        let framesLive = stamp - (lastQuery ?? -Double.infinity) <= 0.1
        if angle == nil || !framesLive {
            let tracked = predictor.estimate ?? raw
            angle = tracked
            gate.update(angle: tracked, at: stamp)
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
        speed = speedometer.speed(at: time)
        let lid = Self.lidInput(angle: smoothed, speed: speed)
        lastLid = lid
        return lid
    }

    /// Forget the motion history (keeps `hasHinge`, the last reading and the closing latch): e.g. after the app returns
    /// from the background, so a stale speed or a stale glide can't leak into the first frames.
    func reset() {
        predictor.reset()
        smoother.reset()
        speedometer.reset()
        lastQuery = nil
        speed = 0
        if let raw = lastRawAngle, let stamp = lastSampleTime {
            predictor.sample(raw, at: stamp)
            speedometer.sample(raw, at: stamp)
        }
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

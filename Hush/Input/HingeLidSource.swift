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
///   R2 (REVIEW-1-duo P1-5): the speedometer sees the angle **clamped to 97…168°** (R7: 97…162°; `speedAngleRange`),
///   so hinge motion outside the play range (folding the phone shut, a detent snap near flat) makes no noise. A slam
///   through 150 → 100 still counts in full.
///
/// R2 resume rule (REVIEW-1-duo P0-2): the closing pause starts under 70° for 0.4 s (`isClosing`), but the run resumes
/// only on `canResume`: θ ≥ 95° (R7: 92° with hysteresis; R3: `requiredResumeAngle`, which the App may lower after a
/// cover trip) **and** the hinge's real motion (unclamped) under 6°/s, held for 0.3 s. Call `reset()` at the moment
/// of resume (and on becoming active).
///
/// R3 (REVIEW-2-duo P1-4): the first report ever is safe on this side. It is a fresh base for both speed meters (no
/// speed), the predictor and the smoother start on it, and it can't jump the noise. The App still guards the first
/// sample of a live run (hold the pause, then `reset()`), since the run may have been played on the lever until then.
///
/// Never use the hinge's `status` (it reads `.closed` at ~85° on hardware); everything here is the angle.
///
/// R7 "real hands" (ROUND-7 Feel, DEVICE-RISKS-1 items 2, 7, 10, D2, D4):
/// - Both speed meters use `FeelSpeedHygiene.hinge`: a 0.10 s breakaway floor after a silence and a 0.4° deadband, so
///   a careful hand on a sticky hinge isn't read as a fast one. A real slam still reads loud.
/// - A single report that jumps more than 8° with both ends at or above 150° is a **snap** (the hinge settling near
///   flat): it credits no speed to either meter. The speedometer's range tops out at **162°** (relics need ≤ 161°).
/// - Resume has **hysteresis**: the lid is "lifted" from `requiredResumeAngle` (now 92°) and stays lifted until it
///   falls 4° below it (88°). `effectiveResumeAngle` reports the line in force, so a card comparing against it can't
///   flicker either. Above 100° "still" means under 10°/s (a hand resting on the lid), else under 6°/s.
/// - The last 10 s of raw reports are kept for Diagnostics (`traceText()`).
@MainActor
final class HingeLidSource: LidSource {
    /// The angle range the speedometer sees (degrees): `Tuning.shutAngle − 3` … R7 `min(Tuning.wideAngle + 3, 162)`
    /// (97…162°; DEVICE-RISKS-1 item 10: the last degrees towards flat may snap, and relics need ≤ 161°).
    /// R13: the phone's play range, `Tuning.hingeShutAngle`…`hingeWideAngle + 3` (0…153°): the whole close counts.
    nonisolated static var speedAngleRange: ClosedRange<Double> {
        max(Tuning.hingeShutAngle - 3, 0)...min(Tuning.hingeWideAngle + 3, 162)
    }
    /// Resume needs the lid at least this open (degrees; R7: 92, was 95; R13: 18, just out of the shut zone, since
    /// the chest opens with the phone from 0°) …
    static let resumeAngle = 18.0
    /// … moving slower than this (°/s, the unclamped hinge motion; R7: 10°/s at or above `resumeWideAngle`) …
    static let resumeSpeed = 6.0
    /// … for this long (s).
    static let resumeHold = 0.3
    /// R3 (REVIEW-2-duo P1-3): the lowest angle the App may set `requiredResumeAngle` to, and the highest.
    static let resumeAngleFloor = 16.0
    static let resumeAngleCeiling = 150.0
    /// R7 hysteresis: once lifted, the lid stays lifted until it is this far under the resume angle (R13: 18 → 15°).
    private static let resumeLeaveMargin = 3.0
    /// R7: at or above this angle the hand may rest on the lid: "still" is under `resumeWideSpeed`.
    private static let resumeWideAngle = 100.0
    private static let resumeWideSpeed = 10.0
    /// R7 snap: a single-report jump larger than this (degrees) …
    private static let snapDegrees = 8.0
    /// … with both readings at or above this angle.
    private static let snapAbove = 150.0

    /// R3 (REVIEW-2-duo P1-3): the angle `canResume` needs, 92° (`resumeAngle`, R7) unless the App changes it. After a
    /// cover-display trip, if the inner display relit below it, set it to `coverResumeAngle(relight:)` so the
    /// player isn't asked to open past the angle they can already see; set it back to `resumeAngle` when the run
    /// resumes (and for the inner closing card). Clamped to 90…150°; NaN reads as 92. `reset()` leaves it alone.
    /// Changing it restarts the hold and the hysteresis.
    var requiredResumeAngle: Double = 18.0 { // = `resumeAngle` (a literal: a plain default value)
        didSet {
            resumeSince = nil
            resumeLifted = false
        }
    }

    /// The resume line in force (degrees): `requiredResumeAngle` sanitised (90…150°) while the lid isn't lifted, and
    /// 4° under it once it is (R7 hysteresis: "Hold still…" from 92°, back to "Lift…" only under 88°). Compare the
    /// filtered `angle` with it for the closing card.
    var effectiveResumeAngle: Double {
        let enter = resumeEnterAngle
        return resumeLifted ? enter - Self.resumeLeaveMargin : enter
    }

    /// `requiredResumeAngle`, sanitised.
    private var resumeEnterAngle: Double {
        let a = requiredResumeAngle
        guard a.isFinite else { return Self.resumeAngle }
        return FeelMath.clamp(a, Self.resumeAngleFloor, Self.resumeAngleCeiling)
    }

    /// The resume angle after a cover-display trip whose inner display relit at `relight` degrees (REVIEW-2-duo
    /// P1-3): `max(90, relight + 3)`, never above the usual `resumeAngle` (92°). Unknown or NaN: `resumeAngle`.
    static func coverResumeAngle(relight: Double?) -> Double {
        guard let relight, relight.isFinite else { return resumeAngle }
        return min(resumeAngle, max(resumeAngleFloor, relight + 3))
    }

    private var predictor = HingePredictor()
    private var smoother = OneEuroSmoother(minCutoff: 2.0, beta: 0.12, dCutoff: 1.5)
    /// The game's speed (noise): fed the angle clamped to `speedAngleRange`.
    private var speedometer = FeelSpeedEstimator(hygiene: .hinge)
    /// The hinge's real motion at any angle (the resume rule's "held still"): fed the raw angle.
    private var motionMeter = FeelSpeedEstimator(hygiene: .hinge)
    private var gate = FeelClosingGate()
    /// Since when the resume condition (lifted, still) has held without a break, if it holds.
    private var resumeSince: TimeInterval?
    /// R7 hysteresis: the lid has reached the resume angle and not yet fallen 4° under it.
    private var resumeLifted = false
    /// R7: the raw-report flight recorder and how many snaps it has seen.
    private var trace = FeelHingeTrace()
    private var snaps = 0

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
    /// lifted (R7: reached `requiredResumeAngle`, 92°, and not since fallen under 88°) and the hinge has moved slower
    /// than 6°/s (10°/s at or above 100°) for 0.3 s without a break. Works with or without
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

    /// R7 (DEVICE-RISKS-1 D4): the last 10 s of raw hinge reports as a compact text block for the Diagnostics Copy log:
    /// a summary (count, rate, gaps, step sizes, snaps), then `ms:angle` pairs from the oldest kept report.
    func traceText() -> String {
        trace.text(now: hasHinge ? now : nil, snaps: snaps)
    }

    /// One hinge report: degrees (180 = flat), stamped on receipt with `CACurrentMediaTime()`.
    func ingest(angleDegrees: Double, at time: TimeInterval) {
        guard angleDegrees.isFinite, time.isFinite else { return }
        let raw = FeelMath.clamp(angleDegrees, 0, 180)
        // Never let a sample go back in time (it would make the filters' dt negative).
        let stamp = max(time, lastSampleTime ?? time)
        trace.record(angle: angleDegrees, at: stamp)
        let snapped = Self.isSnap(from: lastRawAngle, to: raw)
        hasHinge = true
        lastRawAngle = raw
        lastSampleTime = stamp
        predictor.sample(raw, at: stamp)
        if snapped {
            // R7: the hinge settling near flat, not a hand: no speed for either meter.
            snaps += 1
            speedometer.rebase(Self.speedAngle(raw), at: stamp)
            motionMeter.rebase(raw, at: stamp)
            #if DEBUG
            FeelDemoLog.line(String(format: "HUSH-T hinge snap %.1f", raw))
            #endif
        } else {
            speedometer.sample(Self.speedAngle(raw), at: stamp)
            motionMeter.sample(raw, at: stamp)
        }
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

    /// Track the resume condition at `time`: lifted (hysteresis) and still, without a break for `resumeHold`.
    private func observeResume(angle: Double?, at time: TimeInterval) {
        guard let angle, angle.isFinite, time.isFinite else {
            resumeSince = nil
            return
        }
        let enter = resumeEnterAngle
        if angle >= enter {
            resumeLifted = true
        } else if angle < enter - Self.resumeLeaveMargin {
            resumeLifted = false
        }
        let limit = angle >= Self.resumeWideAngle ? Self.resumeWideSpeed : Self.resumeSpeed
        let still = motionMeter.peekSpeed(at: time) < limit
        if resumeLifted && still {
            if resumeSince == nil { resumeSince = time }
        } else {
            resumeSince = nil
        }
    }

    /// R7 (DEVICE-RISKS-1 item 10): one report jumping more than 8° with both readings at or above 150° is the hinge
    /// settling (a snap or detent near flat), not a hand.
    private static func isSnap(from previous: Double?, to raw: Double) -> Bool {
        guard let previous, previous.isFinite, raw.isFinite else { return false }
        return abs(raw - previous) > snapDegrees && min(previous, raw) >= snapAbove
    }

    /// The angle the speedometer sees: clamped to the play range, so motion outside it is silent.
    nonisolated static func speedAngle(_ raw: Double) -> Double {
        let range = speedAngleRange
        return FeelMath.clamp(raw, range.lowerBound, range.upperBound)
    }

    /// The game's view of a filtered angle and speed (GAME-DESIGN §3). R13 (the phone is the chest): openness over
    /// 0…150° of the phone, shut zone ≤ 15°, too wide > 172°, and the hinge's °/s scaled onto the lid's 65° travel
    /// (`Tuning.hingeSpeedScale`), so the noise rules are unchanged per unit of openness. Pure.
    nonisolated static func lidInput(angle: Double, speed: Double) -> LidInput {
        let lidSpeed = FeelMath.positive(speed) * Tuning.hingeSpeedScale
        guard angle.isFinite else { return LidInput(speed: lidSpeed) }
        return LidInput(openness: FeelMath.clamp01(Lid.hingeOpenness(angle: angle)),
                        speed: lidSpeed,
                        inShutZone: angle <= Tuning.hingeShutZoneAngle,
                        tooWide: angle > Tuning.hingeTooWideAngle)
    }
}

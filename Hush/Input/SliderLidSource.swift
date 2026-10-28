import Foundation

/// The no-hinge fallback (GAME-DESIGN §9): a vertical slider on the lid half. Drag up to open, down to shut.
///
/// - The drag is **relative**: a finger may land anywhere on the strip and the lid doesn't jump to it (a jump would be
///   a slam, and noise). The lid moves by however far the finger moves, and re-anchors at the ends (pull past
///   "shut", then up again, and the lid opens at once).
/// - **Speed** (ARCHITECTURE): |d openness/dt| × `degreesPerFraction` (the lid's travel, 65°), through the same
///   `FeelSpeedEstimator` as the hinge, so a finger held still decays to 0 exactly like a still hinge, and the noise
///   rules feel the same on every phone.
/// - Shut zone: openness ≤ 0.06 (R13: was 0.15). Never too wide.
/// - R13 (founder: "closed means closed"; phone QA P1-6): let go in the shut zone, the lever settles to shut (0)
///   silently, so the chest is drawn shut, not left ajar over the next one.
@MainActor
final class SliderLidSource: LidSource {
    /// Openness at or under which the slider is in the shut zone. R13: 0.15 → 0.06, so a lever a little way up is
    /// a chest a little way open (the founder's "even 1 degree open … means chest is opening").
    static let shutZoneOpenness = 0.06

    /// Degrees of lid per full slider stroke: the lid's travel, `Tuning.wideAngle − Tuning.shutAngle` (65°).
    var degreesPerFraction: Double = Tuning.wideAngle - Tuning.shutAngle

    /// 0 (shut) … 1 (wide).
    private(set) var openness: Double = 0
    /// True between a `began` and an `ended`.
    private(set) var isTouching = false
    /// The lid speed (°/s) returned by the last `lid(at:)`.
    private(set) var speed: Double = 0

    private var anchorFraction: Double = 0
    private var anchorOpenness: Double = 0
    private var speedometer = FeelSpeedEstimator()
    private var lastQuery: TimeInterval?
    private var lastLid = LidInput()

    init() {}

    /// A slider touch: `began` (finger down), neither (moved), `ended` (up or cancelled). `fraction` is the finger's
    /// position, 0 at the fold … 1 at the lid's far edge. Times are `UITouch.timestamp` (the frames' clock).
    func touch(began: Bool, ended: Bool, fraction: Double, time: TimeInterval) {
        guard time.isFinite else { return }
        let finger = fraction.isFinite ? FeelMath.clamp01(fraction) : anchorFraction
        if began || !isTouching {
            anchorFraction = finger
            anchorOpenness = openness
            isTouching = true
        }
        var next = anchorOpenness + (finger - anchorFraction)
        if next < 0 || next > 1 {
            next = FeelMath.clamp01(next)
            anchorFraction = finger
            anchorOpenness = next
        }
        openness = next
        speedometer.sample(openness * degreesPerFraction, at: time)
        if ended {
            isTouching = false
            // R13: the shut detent (no speed: it is the lever settling, not the thumb).
            if openness > 0 && openness <= Self.shutZoneOpenness {
                openness = 0
                speedometer.rebase(0, at: time)
            }
        }
    }

    /// Put the lid somewhere without a touch (a new chest, a restart): no speed.
    func reset(openness newOpenness: Double = 0) {
        openness = FeelMath.clamp01(newOpenness)
        isTouching = false
        speedometer.reset()
        speed = 0
        lastQuery = nil
        lastLid = LidInput(openness: openness, speed: 0, inShutZone: openness <= Self.shutZoneOpenness, tooWide: false)
    }

    func lid(at time: TimeInterval) -> LidInput {
        guard time.isFinite else { return lastLid }
        if let previous = lastQuery, time <= previous { return lastLid }
        lastQuery = time
        speed = speedometer.speed(at: time)
        let lid = LidInput(openness: openness, speed: speed, inShutZone: openness <= Self.shutZoneOpenness,
                           tooWide: false)
        lastLid = lid
        return lid
    }
}

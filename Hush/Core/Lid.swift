import Foundation

// MARK: - Hinge angle ↔ lid openness (GAME-DESIGN §3)

enum Lid {

    /// θ → openness 0…1 (clamped): 100° is shut, 165° is wide.
    static func openness(angle: Double) -> Double {
        guard angle.isFinite else { return 0 }
        return min(max((angle - Tuning.shutAngle) / Tuning.lidTravel, 0), 1)
    }

    /// openness → θ (the input is clamped to 0…1).
    static func angle(openness: Double) -> Double {
        let o: Double = openness.isFinite ? min(max(openness, 0), 1) : 0
        return Tuning.shutAngle + o * Tuning.lidTravel
    }

    /// A LidInput for a hinge angle and a filtered speed (°/s).
    static func input(angle: Double, speed: Double) -> LidInput {
        return LidInput(openness: openness(angle: angle), speed: max(0, speed.isFinite ? speed : 0),
                        inShutZone: angle <= Tuning.shutZoneAngle, tooWide: angle > Tuning.tooWideAngle)
    }

    /// R13: the Duo's physical hinge angle → openness 0…1 (clamped): 0° (the phone shut) … 150° (wide).
    static func hingeOpenness(angle: Double) -> Double {
        guard angle.isFinite else { return 0 }
        return min(max((angle - Tuning.hingeShutAngle) / Tuning.hingeTravel, 0), 1)
    }

    /// R13: openness → the physical hinge angle (the input is clamped to 0…1).
    static func hingeAngle(openness: Double) -> Double {
        let o: Double = openness.isFinite ? min(max(openness, 0), 1) : 0
        return Tuning.hingeShutAngle + o * Tuning.hingeTravel
    }

    /// A LidInput for an openness (pilot, slider: the shut zone and "too wide" follow from the matching angle).
    static func input(openness: Double, speed: Double) -> LidInput {
        let o: Double = openness.isFinite ? min(max(openness, 0), 1) : 0
        let a: Double = angle(openness: o)
        return LidInput(openness: o, speed: max(0, speed.isFinite ? speed : 0),
                        inShutZone: a <= Tuning.shutZoneAngle, tooWide: a > Tuning.tooWideAngle)
    }
}

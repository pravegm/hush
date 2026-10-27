import Foundation

// MARK: - Noise rules (GAME-DESIGN §5)

enum Noise {

    /// Noise added per second by the lid moving at `speed` °/s (before the mimic multiplier). 0 at or below the quiet
    /// line (`Tuning.quietSpeed` 12, or `Tuning.closeQuietSpeed` 18 while `closing`); opening 20°/s → 0.09/s,
    /// 40°/s → 0.55/s.
    static func lidRate(speed: Double, closing: Bool = false) -> Double {
        let quiet: Double = quietSpeed(closing: closing)
        guard speed.isFinite, speed > quiet else { return 0 }
        let x: Double = speed - quiet
        return Tuning.lidRateLinear * x + Tuning.lidRateQuadratic * x * x
    }

    /// The lid's silent line (°/s): `Tuning.closeQuietSpeed` while the lid is closing, else `Tuning.quietSpeed`.
    static func quietSpeed(closing: Bool) -> Double {
        return closing ? Tuning.closeQuietSpeed : Tuning.quietSpeed
    }

    /// R2 bag jingle: the level noise can't decay below with `items` in the bag (`multiplier` = the chest's noise
    /// multiplier). 0.035 per item × multiplier, capped at 0.30.
    static func jingleFloor(items: Int, multiplier: Double) -> Double {
        guard items > 0, multiplier.isFinite else { return 0 }
        return min(Tuning.jingleMax, Tuning.jinglePerItem * Double(items) * multiplier)
    }

    /// R2 Hush Chain: what a Hushed bank pays with a chain of `chain` (counting that bank): 1 + 0.1·min(chain, 5).
    static func chainMultiplier(_ chain: Int) -> Double {
        return 1 + Tuning.chainStep * Double(min(max(chain, 0), Tuning.chainMax))
    }

    /// Noise added per second by dragging an item at `speed` pt/s. 1000 pt/s → 0.39/s.
    static func dragRate(speed: Double) -> Double {
        guard speed.isFinite, speed > Tuning.dragQuietSpeed else { return 0 }
        return Tuning.dragRatePerPoint * (speed - Tuning.dragQuietSpeed)
    }

    /// The noise level at which `stage` begins (asleep 0, stirring 0.35, waking 0.70, biting 1.0).
    static func threshold(_ stage: MimicStage) -> Double {
        switch stage {
        case .asleep: return 0
        case .stirring: return Tuning.stirringNoise
        case .waking: return Tuning.wakingNoise
        case .biting: return Tuning.biteNoise
        }
    }

    /// The stage for a noise level, with hysteresis from the previous stage: a stage is entered at its line and only
    /// left (downwards) once the noise is `Tuning.stageHysteresis` below it.
    static func stage(for noise: Double, previous: MimicStage) -> MimicStage {
        let n: Double = noise.isFinite ? noise : 0
        var s: MimicStage = previous
        while let up = MimicStage(rawValue: s.rawValue + 1), n >= threshold(up) {
            s = up
        }
        while s != .asleep, n < threshold(s) - Tuning.stageHysteresis, let down = MimicStage(rawValue: s.rawValue - 1) {
            s = down
        }
        return s
    }

    /// The personality's noise multiplier.
    static func multiplier(for kind: MimicKind) -> Double {
        switch kind {
        case .snorer: return Tuning.snorerNoise
        case .lightSleeper: return Tuning.lightSleeperNoise
        case .heavySleeper: return Tuning.heavySleeperNoise
        case .dreamer: return Tuning.dreamerNoise
        }
    }
}

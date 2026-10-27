import Foundation

// MARK: - Noise rules (GAME-DESIGN §5)

enum Noise {

    /// Noise added per second by the lid moving at `speed` °/s (GAME-DESIGN §5 table, before the mimic multiplier).
    /// 0 at or below `Tuning.quietSpeed`; 20°/s → 0.12/s; 40°/s → 0.55/s.
    static func lidRate(speed: Double) -> Double {
        guard speed.isFinite, speed > Tuning.quietSpeed else { return 0 }
        let x: Double = speed - Tuning.quietSpeed
        return Tuning.lidRateLinear * x + Tuning.lidRateQuadratic * x * x
    }

    /// Noise added per second by dragging an item at `speed` pt/s. 1000 pt/s → 0.45/s.
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

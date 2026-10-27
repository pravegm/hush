import CoreGraphics
import Foundation

// MARK: - Every game number in one place (GAME-DESIGN §3–§6)
//
// Nothing in Core (or elsewhere) hard-codes a rule number: it reads it from here. tools/balance-sim.js mirrors the
// values that matter for balance (keep the two in sync). Round 1 kept every GAME-DESIGN starting value: the sim hit
// all the ROUND-1 balance targets with them (design/notes/core-R1.md has the table).

enum Tuning {

    // MARK: Lid angles (GAME-DESIGN §3). θ is the hinge angle, 180° = flat.

    /// θ where openness = 0 (the lid is shut).
    static let shutAngle: Double = 100
    /// θ where openness = 1 (wide open).
    static let wideAngle: Double = 165
    /// The lid's travel from shut to wide, in degrees (65°). The slider maps its 0…1 fraction onto this.
    static let lidTravel: Double = wideAngle - shutAngle
    /// θ ≤ this is the shut zone: a chest starts here and banking happens here.
    static let shutZoneAngle: Double = 110
    /// θ > this shows "That's wide enough" (no penalty; keeps players off flat).
    static let tooWideAngle: Double = 172
    /// θ below this for `closingDwell` s pauses the game ("Lift the lid a little").
    static let closingAngle: Double = 85
    /// How long θ must stay below `closingAngle` before the pause (s).
    static let closingDwell: Double = 0.4
    /// The slider's shut zone (openness ≤ this), the slider's version of θ ≤ `shutZoneAngle`.
    static let sliderShutZoneOpenness: Double = 0.15
    /// Lid slider: 1 pt/s of finger travel ≈ 0.25 °/s of lid speed (GAME-DESIGN §9).
    static let sliderDegreesPerPoint: Double = 0.25

    // MARK: Noise from the lid (GAME-DESIGN §5)

    /// Below this lid speed (°/s) the hinge is silent. The creak starts here.
    static let quietSpeed: Double = 8
    /// Above this lid speed (°/s) the hint says "Slower…" (and the lesson's mimic grumbles).
    static let loudSpeed: Double = 30
    /// lidRate = lidRateLinear·(ω−8) + lidRateQuadratic·(ω−8)² per second, for ω > quietSpeed.
    /// 20°/s → 0.12/s, 40°/s → 0.55/s, a 120°/s slam for 0.4 s → +2.0 (a bite).
    static let lidRateLinear: Double = 0.006
    static let lidRateQuadratic: Double = 0.00035

    // MARK: Noise from the loot (GAME-DESIGN §5)

    /// Dragging slower than this (pt/s) is silent.
    static let dragQuietSpeed: Double = 250
    /// dragRate = dragRatePerPoint·(v − 250) per second: 1000 pt/s → 0.45/s.
    static let dragRatePerPoint: Double = 0.0006
    /// One-off noise when an item is picked up.
    static let pickNoise: Double = 0.02
    /// One-off noise when an item drops into the bag.
    static let bagNoise: Double = 0.03
    /// One-off noise when an item is let go outside the bag (it clunks back into the chest).
    static let dropNoise: Double = 0.08

    // MARK: Drag speed measurement (from successive touch positions and times)

    /// Smoothing time constant of the measured drag speed (s): each touch move blends in by min(1, Δt / this).
    static let dragSmoothing: Double = 0.06
    /// Touch moves closer together than this (s) only move the item; the speed waits for the next one.
    static let dragMinInterval: Double = 0.0001
    /// A held item that gets no touch move for this long (s) is still: its drag speed decays …
    static let dragStillAfter: Double = 0.06
    /// … with this time constant (s).
    static let dragStillDecay: Double = 0.10

    // MARK: Decay, restlessness, stages (GAME-DESIGN §5)

    /// Noise only decays after this long (s) with no source above `quietRateThreshold`.
    static let decayGrace: Double = 0.4
    /// A total source rate (per second, after the multipliers) at or below this counts as quiet.
    static let quietRateThreshold: Double = 0.01
    /// Restlessness: decay × max(restlessFloor, 1 − restlessPerSecond · t in this chest).
    static let restlessPerSecond: Double = 0.02
    static let restlessFloor: Double = 0.5
    /// Stage lines: Asleep < 0.35 ≤ Stirring < 0.70 ≤ Waking < 1.0 ≤ Bite.
    static let stirringNoise: Double = 0.35
    static let wakingNoise: Double = 0.70
    static let biteNoise: Double = 1.0
    /// A stage only drops back once the noise is this far below its line.
    static let stageHysteresis: Double = 0.04
    /// With bites off (attract, lesson) or before the chest is opened, noise caps here.
    static let noBiteCap: Double = 0.99

    // MARK: Mimic personalities (GAME-DESIGN §5)

    static let snorerNoise: Double = 1.0
    static let lightSleeperNoise: Double = 1.35
    static let heavySleeperNoise: Double = 0.7
    static let dreamerNoise: Double = 1.0
    /// A Dreamer's harmless fake twitch comes every 4–9 s (seeded).
    static let dreamTwitchMin: Double = 4
    static let dreamTwitchMax: Double = 9
    /// How often each personality is dealt (normalised). Chest #1 is never a Light sleeper (it deals a Snorer).
    static let snorerWeight: Double = 0.35
    static let lightSleeperWeight: Double = 0.25
    static let heavySleeperWeight: Double = 0.20
    static let dreamerWeight: Double = 0.20
    /// "Heavy sleeper: less loot": one item fewer (never below `minItems`).
    static let heavySleeperItemPenalty: Int = 1
    static let minItems: Int = 3

    // MARK: Chest tiers (GAME-DESIGN §6). Index is 0-based: chests 1–2 wooden, 3–4 iron, 5–6 gilded, 7+ royal.

    static let ironFromIndex: Int = 2
    static let gildedFromIndex: Int = 4
    static let royalFromIndex: Int = 6
    static let woodenMultiplier: Double = 1
    static let ironMultiplier: Double = 1.5
    static let gildedMultiplier: Double = 2
    static let royalMultiplier: Double = 3
    /// Noise decay per second while quiet.
    static let woodenDecay: Double = 0.14
    static let ironDecay: Double = 0.12
    static let gildedDecay: Double = 0.10
    static let royalDecay: Double = 0.085
    static let woodenItems: ClosedRange<Int> = 5...6
    static let ironItems: ClosedRange<Int> = 6...7
    static let gildedItems: ClosedRange<Int> = 7...8
    static let royalItems: ClosedRange<Int> = 8...9

    // MARK: Loot (GAME-DESIGN §6). Values are gold before the chest multiplier.

    static let copperValue: ClosedRange<Int> = 5...10
    static let copperDepth: ClosedRange<Double> = 0.00...0.45
    static let copperCount: ClosedRange<Int> = 2...3
    static let silverValue: ClosedRange<Int> = 20...35
    static let silverDepth: ClosedRange<Double> = 0.20...0.60
    static let gemValue: ClosedRange<Int> = 60...110
    static let gemDepth: ClosedRange<Double> = 0.45...0.80
    static let gemCount: ClosedRange<Int> = 1...2
    static let relicValue: ClosedRange<Int> = 250...450
    static let relicDepth: ClosedRange<Double> = 0.84...0.92
    /// Chance an Iron-bound-or-better chest holds a relic.
    static let relicChance: Double = 0.35
    static let oilDepth: ClosedRange<Double> = 0.25...0.55
    /// Chance a chest holds torch oil ("about 1 per 3 chests").
    static let oilChance: Double = 0.33

    /// Touch and art radii (pt).
    static let copperRadius: CGFloat = 22
    static let silverRadius: CGFloat = 24
    static let gemRadius: CGFloat = 26
    static let relicRadius: CGFloat = 34
    static let oilRadius: CGFloat = 24

    // MARK: Placement (ROUND-1: no overlap, inside FloorSpace.interior, deeper items further back on average)

    /// Minimum gap between two items' edges (pt).
    static let lootGap: Double = 6
    /// ± how far (pt) an item may sit from its depth's row; it widens on each retry.
    static let placementJitterY: Double = 60
    /// Random placement tries before a deterministic grid scan.
    static let placementTries: Int = 60
    static let placementGridStep: Double = 12
    /// Cosmetic rotation range (radians, ±).
    static let lootRotation: Double = 0.5

    // MARK: The bag (FloorSpace.bagRect): bagged items lie in a row

    static let bagSlotFirstX: CGFloat = 110
    static let bagSlotSpacing: CGFloat = 50
    static let bagSlotsPerRow: Int = 10
    /// Row centre, measured down from `FloorSpace.bagMinY` (the bag is 110 pt deep).
    static let bagSlotInset: CGFloat = 55
    static let bagSlotRowStep: CGFloat = 28

    // MARK: Light (ARCHITECTURE: light = clamp((openness − depth) / lightRamp, 0, 1))

    static let lightRamp: Double = 0.10
    /// `itemRevealed` fires once light reaches this (a glint at openness ≥ depth + 0.04).
    static let revealLight: Double = 0.4
    /// Grabbable at light ≥ this (openness ≥ depth + 0.06, so a 0.92-deep relic needs openness 0.98 ≈ 164°).
    static let grabLight: Double = 0.6
    /// `.looting` starts once the lid has been in the shut zone and openness passes this.
    static let lootingStartOpenness: Double = 0.02
    /// `lidCracked` fires the first time openness passes this in a chest.
    static let lidCrackedOpenness: Double = 0.05
    /// A touch picks an item within radius + this (pt).
    static let grabSlop: Double = 14

    // MARK: Torch, bank, bite, moments (GAME-DESIGN §4)

    static let torchSeconds: Double = 100
    static let oilSeconds: Double = 8
    static let biteTorchPenalty: Double = 15
    /// `torchLow` fires once when this many seconds are left.
    static let torchLowSeconds: Double = 15
    /// Hold the lid in the shut zone this long (s) with loot in the bag to bank.
    static let shutHoldSeconds: Double = 0.35
    static let bankMomentSeconds: Double = 1.4
    static let biteMomentSeconds: Double = 1.8
    static let torchOutSeconds: Double = 2.0

    // MARK: Simulation

    /// HeistSession sub-steps at most this long (s).
    static let maxSubstep: Double = 1.0 / 120.0
    /// The First Chest lesson's noise scale.
    static let lessonNoiseScale: Double = 0.6

    // MARK: Lesson (GAME-DESIGN §8)

    /// Pose step: 95° ≤ θ ≤ 125° held for 0.5 s.
    static let lessonPoseMinAngle: Double = 95
    static let lessonPoseMaxAngle: Double = 125
    static let lessonPoseHold: Double = 0.5
    /// The scripted stir level (`nudgeNoise(to:)`) and how long to hold still.
    static let lessonStirNoise: Double = 0.55
    static let lessonFreezeHold: Double = 1.5
}

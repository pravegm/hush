import Foundation

/// Tiny deterministic RNG for sound variation (main thread). Named to avoid clashing with Core's `SeededRandom`.
struct FeelDice {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in 0…1.
    mutating func unit() -> Double {
        Double(next() >> 11) / Double(UInt64(1) << 53)
    }

    /// Uniform in lower…upper.
    mutating func range(_ lower: Double, _ upper: Double) -> Double {
        lower + (upper - lower) * unit()
    }

    /// Uniform in lower…upper, as a Float.
    mutating func float(_ lower: Float, _ upper: Float) -> Float {
        Float(range(Double(lower), Double(upper)))
    }

    mutating func seed32() -> UInt32 {
        UInt32(truncatingIfNeeded: next()) | 1
    }
}

/// Hush's sound design (GAME-DESIGN §10, ROUND-1 "Feel engineer"), as pure data: every recipe returns synth commands
/// and the continuous bed is a pure function of the telemetry, so it is all unit-tested and nothing here touches
/// audio hardware.
///
/// Mix intent: a candlelit hush. The dungeon (a soft drone, drips, the torch) and the sleeping mimic's snore are the
/// bed, quiet enough to hear a pin drop; the tiptoe pizzicato sneaks along on top while you're safe. The **creak** is
/// the one continuous sound that can get loud, and it does so only because of you. The coins are bright and small; the
/// bank thunk and the CHOMP are the only big moments, and the master limiter keeps every pile-up clean.
enum FeelSoundBook {
    // MARK: The creak (the hero)

    /// Speeds (°/s) of the creak curve: silent at or below `Tuning.quietSpeed` (8), soft up to `softTop` (20), loud
    /// from `Tuning.loudSpeed` (30), full at `fullSpeed`. The squeal partial fades in from `squealStart` (25).
    static var quietSpeed: Double { Tuning.quietSpeed }
    static var loudSpeed: Double { Tuning.loudSpeed }
    static let softTop = 20.0
    static let fullSpeed = 50.0
    static let squealStart = 25.0
    static let squealFull = 45.0
    /// The creak's level at `softTop` and at `loudSpeed` (0…1 of full).
    static let softLevel = 0.4
    static let loudLevel = 0.8
    /// The groan's pitch range (Hz) and the speed at which it tops out: real stick-slip runs faster the faster the
    /// wood slides.
    static let groanLowHz = 140.0
    static let groanHighHz = 420.0
    static let groanTopSpeed = 60.0
    /// Friction grains per second at the quiet speed and the extra at `groanTopSpeed`.
    static let grainBase = 12.0
    static let grainSpan = 240.0

    /// 0…1 creak level for a lid speed: 0 at ≤ 8°/s; a soft ease-in to 0.4 at 20; up to 0.8 at 30; 1.0 at 50.
    /// Continuous and monotonic, so the creak swells and fades with the hand and never switches on with a click.
    static func creakLevel(speed: Double) -> Double {
        guard speed.isFinite, speed > quietSpeed else { return 0 }
        if speed <= softTop {
            let u = (speed - quietSpeed) / (softTop - quietSpeed)
            return softLevel * pow(u, 1.1)
        }
        if speed <= loudSpeed {
            let v = (speed - softTop) / (loudSpeed - softTop)
            return softLevel + (loudLevel - softLevel) * v
        }
        return loudLevel + (1 - loudLevel) * smoothstep((speed - loudSpeed) / (fullSpeed - loudSpeed))
    }

    /// 0…1 squeal level: nothing up to 25°/s, a smoothstep to full at 45.
    static func squealLevel(speed: Double) -> Double {
        guard speed.isFinite else { return 0 }
        return smoothstep((speed - squealStart) / (squealFull - squealStart))
    }

    /// The groan's stick-slip pitch (Hz): 140 at the quiet speed rising to 420 at 60°/s.
    static func groanHz(speed: Double) -> Double {
        let u = clamp01((speed - quietSpeed) / (groanTopSpeed - quietSpeed))
        return groanLowHz + (groanHighHz - groanLowHz) * pow(u, 0.8)
    }

    /// Friction grains per second.
    static func grainRate(speed: Double) -> Double {
        grainBase + grainSpan * clamp01((speed - quietSpeed) / (groanTopSpeed - quietSpeed))
    }

    /// Fill the creak layers of `bed` for a lid speed, scaled by `share`.
    static func applyCreak(to bed: inout FeelBed, speed: Double, share: Double = 1) {
        let s = speed.isFinite ? max(speed, 0) : 0
        let level = creakLevel(speed: s) * clamp01(share)
        bed.creak = Float(level)
        bed.creakHz = Float(groanHz(speed: s))
        bed.grainRate = level > 0 ? Float(grainRate(speed: s)) : 0
        bed.creakBright = Float(0.1 + 0.85 * clamp01((s - quietSpeed) / 45))
        bed.squeal = Float(squealLevel(speed: s) * clamp01(share))
        bed.squealHz = Float(1700 + 900 * clamp01((s - squealStart) / 35))
    }

    // MARK: The bed (everything continuous)

    /// Glide (s) of the frame-by-frame bed, and of a fade to quiet (pause, menus).
    static let frameGlide: Float = 0.05
    static let fadeGlide: Float = 0.35
    /// The creak's share while the game isn't stepping (result moments): it still follows the hinge, a little softer.
    static let restingCreakShare = 0.8
    /// The Home chest's creak share.
    static let homeCreakShare = 0.85
    /// The snore: muffled by a shut lid (this share at openness 0), lighter as the noise rises.
    static let snoreShutShare = 0.55
    static let snorePeriod: Float = 4.25
    /// Noise levels (GAME-DESIGN §5) where the mimic stirs and wakes.
    static let stirNoise = 0.35
    static let wakeNoise = 0.7
    /// Torch crackle: the share in normal play, and when it's low (the last `torchLowSeconds`).
    static let crackleBase = 0.4
    static let torchLowSeconds = 15.0
    /// Drips per second at full ambience.
    static let dripRate = 0.5
    /// Dragging faster than this (pt/s) rattles the loot (GAME-DESIGN §5: the drag noise starts here too).
    static let rattleSpeed = 250.0
    static let rattleFullSpeed = 1000.0

    /// No continuous layers, master kept: menus, pause cards and one-shots stay audible.
    static func idleBed(master: Float, glide: Float = fadeGlide) -> FeelBed {
        var bed = FeelBed()
        bed.master = master
        bed.glide = glide
        bed.snorePeriod = snorePeriod
        return bed
    }

    /// The Home screen's live creak: the title chest follows the hinge (or the slider). Creak only.
    static func homeBed(speed: Double, openness: Double, master: Float) -> FeelBed {
        var bed = idleBed(master: master, glide: frameGlide)
        applyCreak(to: &bed, speed: speed, share: homeCreakShare)
        return bed
    }

    /// The continuous layers for one game frame. `ambience` (0…1) is the dungeon's level: the App's frames keep it up
    /// through the result moments and let it fade in menus (the director decides).
    static func heistBed(telemetry: HeistTelemetry, master: Float, ambience: Double) -> FeelBed {
        var bed = idleBed(master: master, glide: frameGlide)
        let playing = telemetry.playing
        applyCreak(to: &bed, speed: telemetry.lidSpeed, share: playing ? 1 : restingCreakShare)

        let noise = clamp01(telemetry.noise)
        let openness = clamp01(telemetry.openness)
        if playing {
            switch telemetry.stage {
            case .asleep:
                let lighter = clamp01(noise / stirNoise)
                bed.snore = Float((snoreShutShare + (1 - snoreShutShare) * openness) * (1 - 0.45 * lighter))
                bed.motif = 1
                bed.motifDensity = Float(1 - 0.45 * lighter)
            case .stirring:
                // The snore stops; the tiptoe thins to its strongest beats and the heartbeat (a one-shot) takes over.
                bed.motif = 0.7
                bed.motifDensity = 0.3
            case .waking, .biting:
                bed.growl = Float(0.45 + 0.55 * clamp01((noise - wakeNoise) / (1 - wakeNoise)))
            }
            let drag = telemetry.dragSpeed.isFinite ? telemetry.dragSpeed : 0
            if drag > rattleSpeed {
                let level = clamp01((drag - rattleSpeed) / (rattleFullSpeed - rattleSpeed))
                bed.rattle = Float(0.35 + 0.65 * level)
                bed.rattleRate = Float(12 + 38 * level)
            }
        }

        let air = clamp01(ambience)
        if air > 0 {
            bed.drone = Float(air)
            bed.dripRate = Float(dripRate * air)
            let torch = telemetry.torchRemaining
            if torch.isFinite && torch > 0 {
                let low = clamp01(1 - torch / torchLowSeconds)
                bed.crackle = Float((crackleBase + (1 - crackleBase) * low) * air)
                bed.crackleRate = Float(4 + 14 * low)
            }
        }
        return bed
    }

    // MARK: The mimic's moments

    /// The heartbeat (a soft double thump, "lub-dub"). Slow (60 bpm) at Stirring, fast (110) at Waking.
    static let slowHeartBPM = 60.0
    static let fastHeartBPM = 110.0

    /// Seconds between beats for a stage, or nil when there is no heartbeat.
    static func heartInterval(stage: MimicStage) -> Double? {
        switch stage {
        case .stirring: return 60 / slowHeartBPM
        case .waking: return 60 / fastHeartBPM
        case .asleep, .biting: return nil
        }
    }

    /// One heartbeat. The body sits at 120 → 62 Hz with harmonics, so a phone speaker carries it.
    static func heartbeat(fast: Bool) -> [FeelSynthCommand] {
        let k: Float = fast ? 1 : 0.75
        let gap: Float = fast ? 0.14 : 0.18
        return [
            .tone(FeelToneSpec(start: 120, end: 62, glide: 0.06, duration: 0.16, attack: 0.004, decay: 0.05,
                               gain: 0.2 * k, harmonics: 4)),
            .noise(FeelNoiseSpec(.lowPass, cutoff: 260, q: 0.9, attack: 0.002, decay: 0.03, gain: 0.1 * k)),
            .tone(FeelToneSpec(start: 110, end: 60, glide: 0.06, duration: 0.14, attack: 0.004, decay: 0.045,
                               gain: 0.13 * k, harmonics: 4, delay: gap)),
            .noise(FeelNoiseSpec(.lowPass, cutoff: 240, q: 0.9, attack: 0.002, decay: 0.025, gain: 0.06 * k,
                                 delay: gap)),
        ]
    }

    /// The mimic stirs: the snore catches in a snort ("snrk!").
    static func snort(dice: inout FeelDice) -> [FeelSynthCommand] {
        [
            .noise(FeelNoiseSpec(.bandPass, cutoff: dice.float(330, 400), q: 2, attack: 0.01, decay: 0.07,
                                 gain: 0.16)),
            .tone(FeelToneSpec(start: 115, end: 88, glide: 0.12, duration: 0.16, attack: 0.008, decay: 0.06,
                               gain: 0.12, harmonics: 5, vibratoRate: 26, vibratoDepth: 0.05)),
            .noise(FeelNoiseSpec(.bandPass, cutoff: 700, q: 1, attack: 0.03, decay: 0.08, gain: 0.04, delay: 0.14)),
        ]
    }

    /// The mimic wakes: a growl swells in under a low, sour two-note sting.
    static func wakeSting() -> [FeelSynthCommand] {
        [
            .tone(FeelToneSpec(start: 72, end: 86, glide: 0.5, duration: 0.8, attack: 0.08, decay: 0.3, gain: 0.16,
                               harmonics: 6, vibratoRate: 21, vibratoDepth: 0.05)),
            .noise(FeelNoiseSpec(.lowPass, cutoff: 200, to: 420, sweep: 0.5, q: 2.5, attack: 0.1, decay: 0.25,
                                 gain: 0.18)),
            .tone(FeelToneSpec(start: 146.83, duration: 0.7, attack: 0.02, decay: 0.3, gain: 0.05, harmonics: 3)),
            .tone(FeelToneSpec(start: 155.56, duration: 0.7, attack: 0.02, decay: 0.3, gain: 0.05, harmonics: 3)),
        ]
    }

    /// The mimic settles back (a stage down): a long relieved sigh and a sleepy "mmm".
    static func sigh() -> [FeelSynthCommand] {
        [
            .noise(FeelNoiseSpec(.bandPass, cutoff: 900, to: 380, sweep: 0.7, q: 0.9, attack: 0.12, decay: 0.3,
                                 gain: 0.06)),
            .tone(FeelToneSpec(start: 130, end: 110, glide: 0.5, duration: 0.6, attack: 0.1, decay: 0.25, gain: 0.04,
                               harmonics: 3, delay: 0.1)),
        ]
    }

    /// CHOMP (the bite): a low thump, a wooden crack, the teeth clack, then a burp-y growl. The biggest sound.
    static func chomp(dice: inout FeelDice) -> [FeelSynthCommand] {
        [
            // Thump.
            .tone(FeelToneSpec(start: 150, end: 48, glide: 0.12, duration: 0.3, attack: 0.002, decay: 0.09,
                               gain: 0.36, harmonics: 6)),
            .noise(FeelNoiseSpec(.lowPass, cutoff: 520, to: 180, sweep: 0.1, q: 1.1, attack: 0.001, decay: 0.07,
                                 gain: 0.34)),
            // Wooden crack.
            .noise(FeelNoiseSpec(.highPass, cutoff: 1800, q: 0.7, attack: 0.0005, decay: 0.02, gain: 0.26)),
            .ring(FeelRingSpec(.wood, fundamental: 340, partials: 4, decay: 0.05, brightness: 0.5, gain: 0.26,
                               seed: dice.seed32())),
            // Teeth clack.
            .ring(FeelRingSpec(.wood, fundamental: 1850, partials: 3, decay: 0.012, brightness: 0.5, gain: 0.2,
                               delay: 0.035, seed: dice.seed32())),
            .ring(FeelRingSpec(.wood, fundamental: 2400, partials: 3, decay: 0.01, brightness: 0.5, gain: 0.17,
                               delay: 0.06, seed: dice.seed32())),
            // Burp-y growl.
            .tone(FeelToneSpec(start: 95, end: 70, glide: 0.4, duration: 0.55, attack: 0.04, decay: 0.2, gain: 0.2,
                               harmonics: 7, vibratoRate: 22, vibratoDepth: 0.07, delay: 0.16)),
            .noise(FeelNoiseSpec(.lowPass, cutoff: 380, to: 160, sweep: 0.4, q: 2.5, attack: 0.05, decay: 0.18,
                                 gain: 0.18, delay: 0.16)),
        ]
    }

    // MARK: Loot

    /// Copper coins: 2–3 inharmonic FM partials, bright and short, then a second smaller knock.
    static func coinClink(dice: inout FeelDice, scale: Float = 1, delay: Float = 0) -> [FeelSynthCommand] {
        let d = dice.float(0.97, 1.03)
        return [
            .fm(FeelFMSpec(carrier: 2300 * d, ratio: 1.41, index: 1.6, indexDecay: 0.02, decay: 0.07,
                           gain: 0.09 * scale, delay: delay)),
            .fm(FeelFMSpec(carrier: 3650 * d, ratio: 2.17, index: 0.9, indexDecay: 0.015, decay: 0.05,
                           gain: 0.06 * scale, delay: delay + 0.002)),
            .fm(FeelFMSpec(carrier: 5200 * d, ratio: 1.13, index: 0.5, indexDecay: 0.01, decay: 0.035,
                           gain: 0.035 * scale, delay: delay + 0.004)),
            .fm(FeelFMSpec(carrier: 2650 * d, ratio: 1.41, index: 1.0, indexDecay: 0.015, decay: 0.045,
                           gain: 0.045 * scale, delay: delay + dice.float(0.03, 0.05))),
        ]
    }

    /// Silver: a higher, longer ting.
    static func silverTing(dice: inout FeelDice, scale: Float = 1, delay: Float = 0) -> [FeelSynthCommand] {
        [
            .ring(FeelRingSpec(.glass, fundamental: dice.float(2060, 2120), partials: 3, decay: 0.35,
                               brightness: 0.35, gain: 0.08 * scale, delay: delay, seed: dice.seed32())),
            .fm(FeelFMSpec(carrier: 4186, ratio: 1.5, index: 0.8, indexDecay: 0.03, decay: 0.12, gain: 0.04 * scale,
                           delay: delay)),
        ]
    }

    /// The gem bell's pitch by colour: ruby C6, emerald D6, sapphire E6, amethyst G6.
    static func gemHz(_ color: GemColor) -> Float {
        switch color {
        case .ruby: return 1046.5
        case .emerald: return 1174.66
        case .sapphire: return 1318.51
        case .amethyst: return 1567.98
        }
    }

    /// A gem: a bell pitched by its colour, with a glass sparkle an octave up.
    static func gemChime(_ color: GemColor, dice: inout FeelDice, scale: Float = 1,
                         delay: Float = 0) -> [FeelSynthCommand] {
        let f = gemHz(color)
        return [
            .ring(FeelRingSpec(.bell, fundamental: f, partials: 6, decay: 1.1, brightness: 0.5, gain: 0.11 * scale,
                               delay: delay, seed: dice.seed32())),
            .ring(FeelRingSpec(.glass, fundamental: f * 2, partials: 2, decay: 0.2, brightness: 0.3,
                               gain: 0.035 * scale, delay: delay + 0.02, seed: dice.seed32())),
        ]
    }

    /// A relic: a warm D major choir swell (it fires with the bank, after the ka-ching).
    static func relicChoir(delay: Float = 0) -> [FeelSynthCommand] {
        let chord: [Float] = [293.66, 369.99, 440.0, 587.33]
        var commands: [FeelSynthCommand] = []
        for (index, f) in chord.enumerated() {
            commands.append(.tone(FeelToneSpec(start: f, duration: 2.4, attack: 0.4, decay: 0.9, gain: 0.045,
                                               harmonics: 4, vibratoRate: 4.6 + 0.35 * Float(index),
                                               vibratoDepth: 0.006, delay: delay + 0.05 * Float(index))))
        }
        // The "aah": breath through a vowel-ish band.
        commands.append(.noise(FeelNoiseSpec(.bandPass, cutoff: 800, q: 1.5, attack: 0.45, decay: 0.5, gain: 0.035,
                                             delay: delay)))
        commands.append(.ring(FeelRingSpec(.glass, fundamental: 2349.3, partials: 2, decay: 0.4, brightness: 0.3,
                                           gain: 0.035, delay: delay + 0.5)))
        return commands
    }

    /// Torch oil: a low glug and a breath of flame.
    static func oilGlug() -> [FeelSynthCommand] {
        [
            .drop(FeelDropSpec(frequency: 380, chirp: 1.8, decay: 0.04, gain: 0.12)),
            .drop(FeelDropSpec(frequency: 300, chirp: 1.9, decay: 0.05, gain: 0.1, delay: 0.09)),
            .noise(FeelNoiseSpec(.bandPass, cutoff: 600, to: 2200, sweep: 0.3, q: 0.8, attack: 0.05, decay: 0.12,
                                 gain: 0.05, delay: 0.12)),
        ]
    }

    /// The loot's own voice (clink, ting, chime, glug), at `scale`.
    static func lootVoice(_ kind: LootKind, dice: inout FeelDice, scale: Float = 1,
                          delay: Float = 0) -> [FeelSynthCommand] {
        switch kind {
        case .copper: return coinClink(dice: &dice, scale: scale, delay: delay)
        case .silver: return silverTing(dice: &dice, scale: scale, delay: delay)
        case .gem(let color): return gemChime(color, dice: &dice, scale: scale, delay: delay)
        case .relic:
            return [
                .ring(FeelRingSpec(.bell, fundamental: 587.33, partials: 6, decay: 1.2, brightness: 0.45,
                                   gain: 0.1 * scale, delay: delay, seed: dice.seed32())),
                .ring(FeelRingSpec(.glass, fundamental: 1760, partials: 2, decay: 0.3, brightness: 0.3,
                                   gain: 0.04 * scale, delay: delay + 0.03, seed: dice.seed32())),
            ]
        case .oil:
            var glug = oilGlug()
            if delay > 0 {
                glug = glug.map { (command: FeelSynthCommand) -> FeelSynthCommand in
                    switch command {
                    case .drop(var spec):
                        spec.delay += delay
                        return .drop(spec)
                    case .noise(var spec):
                        spec.delay += delay
                        return .noise(spec)
                    default:
                        return command
                    }
                }
            }
            return glug
        }
    }

    /// A finger takes an item: a soft lift, and the item's voice, very small.
    static func itemPicked(_ kind: LootKind, dice: inout FeelDice) -> [FeelSynthCommand] {
        var commands: [FeelSynthCommand] = [
            .ring(FeelRingSpec(.wood, fundamental: dice.float(1050, 1200), partials: 2, decay: 0.008,
                               brightness: 0.3, gain: 0.05)),
        ]
        commands.append(contentsOf: lootVoice(kind, dice: &dice, scale: 0.35, delay: 0.01))
        return commands
    }

    /// Dropped outside the bag, back into the chest: a clunk (it's noise, and it should sound like a mistake).
    static func itemDropped(dice: inout FeelDice) -> [FeelSynthCommand] {
        [
            .ring(FeelRingSpec(.wood, fundamental: dice.float(240, 290), partials: 3, decay: 0.05, brightness: 0.45,
                               gain: 0.18, seed: dice.seed32())),
            .noise(FeelNoiseSpec(.lowPass, cutoff: 600, q: 0.9, attack: 0.001, decay: 0.03, gain: 0.16)),
            .tone(FeelToneSpec(start: 140, end: 90, glide: 0.06, duration: 0.11, attack: 0.002, decay: 0.035,
                               gain: 0.12, harmonics: 3)),
        ]
    }

    /// Into the bag: a soft leather thump, then the item's clink.
    static func itemBagged(_ kind: LootKind, dice: inout FeelDice) -> [FeelSynthCommand] {
        var commands: [FeelSynthCommand] = [
            .noise(FeelNoiseSpec(.lowPass, cutoff: 380, to: 160, sweep: 0.06, q: 0.9, attack: 0.002, decay: 0.045,
                                 gain: 0.18)),
            .tone(FeelToneSpec(start: 150, end: 95, glide: 0.05, duration: 0.12, attack: 0.003, decay: 0.04,
                               gain: 0.12, harmonics: 3)),
        ]
        commands.append(contentsOf: lootVoice(kind, dice: &dice, scale: 0.85, delay: 0.03))
        return commands
    }

    /// The light reaches an item: a glint (gold), a brighter one (gems), a low shimmer (relics). Soft.
    static func itemRevealed(_ kind: LootKind, dice: inout FeelDice, delay: Float = 0) -> [FeelSynthCommand] {
        switch kind {
        case .copper, .silver, .oil:
            return [.ring(FeelRingSpec(.glass, fundamental: dice.float(2637, 3520), partials: 2, decay: 0.12,
                                       brightness: 0.3, gain: 0.032, delay: delay, seed: dice.seed32()))]
        case .gem(let color):
            return [.ring(FeelRingSpec(.glass, fundamental: gemHz(color) * 2, partials: 3, decay: 0.2,
                                       brightness: 0.35, gain: 0.045, delay: delay, seed: dice.seed32()))]
        case .relic:
            return [
                .ring(FeelRingSpec(.glass, fundamental: 1174.66, partials: 3, decay: 0.5, brightness: 0.3,
                                   gain: 0.04, delay: delay, seed: dice.seed32())),
                .ring(FeelRingSpec(.glass, fundamental: 1760, partials: 2, decay: 0.45, brightness: 0.3,
                                   gain: 0.035, delay: delay + 0.09, seed: dice.seed32())),
                .tone(FeelToneSpec(start: 293.66, duration: 0.9, attack: 0.25, decay: 0.35, gain: 0.025,
                                   harmonics: 3, delay: delay)),
            ]
        }
    }

    /// The lid first cracks open: light spills in (an airy rise and a faint glint).
    static func lidCracked() -> [FeelSynthCommand] {
        [
            .noise(FeelNoiseSpec(.bandPass, cutoff: 800, to: 2400, sweep: 0.5, q: 0.8, attack: 0.15, decay: 0.2,
                                 gain: 0.03)),
            .ring(FeelRingSpec(.glass, fundamental: 1760, partials: 2, decay: 0.4, brightness: 0.3, gain: 0.03,
                               delay: 0.1)),
        ]
    }

    /// A chest slides in from the front and lands: a dusty slide, then a thunk (iron and better add a metal ring).
    static func chestArrived(tier: ChestTier, dice: inout FeelDice) -> [FeelSynthCommand] {
        var commands: [FeelSynthCommand] = [
            .noise(FeelNoiseSpec(.lowPass, cutoff: 250, to: 700, sweep: 0.35, q: 0.8, attack: 0.12, decay: 0.12,
                                 gain: 0.1)),
            .ring(FeelRingSpec(.wood, fundamental: dice.float(170, 190), partials: 4, decay: 0.06, brightness: 0.45,
                               gain: 0.15, delay: 0.38, seed: dice.seed32())),
            .tone(FeelToneSpec(start: 110, end: 70, glide: 0.08, duration: 0.15, attack: 0.003, decay: 0.05,
                               gain: 0.1, harmonics: 4, delay: 0.38)),
        ]
        let metal: Float
        switch tier {
        case .wooden: metal = 0
        case .iron: metal = 440
        case .gilded: metal = 523.25
        case .royal: metal = 587.33
        }
        if metal > 0 {
            commands.append(.ring(FeelRingSpec(.bell, fundamental: metal, partials: 5, decay: 0.5, brightness: 0.45,
                                               gain: 0.05, delay: 0.39, seed: dice.seed32())))
        }
        if tier == .royal {
            commands.append(.ring(FeelRingSpec(.glass, fundamental: 2349.3, partials: 2, decay: 0.3, brightness: 0.3,
                                               gain: 0.035, delay: 0.5, seed: dice.seed32())))
        }
        return commands
    }

    // MARK: Banking

    /// Clinks in the bank cascade for a haul's value: 6 (small) … 14 (big), one more per doubling over 50 gold.
    static func cascadeCount(value: Int) -> Int {
        guard value > 50 else { return 6 }
        let doublings = Int(log2(Double(value) / 50))
        return min(max(6 + doublings + 1, 6), 14)
    }

    /// When each cascade clink lands (s after the thunk): from 0.12 s, spread over 0.8 s, quick at first and slowing
    /// like the last coins settling, with a small fixed jitter so it never sounds mechanical. Shared by the sound and
    /// the haptic rattle, so they land together.
    static func cascadeTimes(count: Int) -> [Double] {
        let n = min(max(count, 1), 16)
        var times: [Double] = []
        for k in 0..<n {
            let x = n == 1 ? 0 : Double(k) / Double(n - 1)
            let jitter = 0.012 * sin(Double(k) * 2.3 + 0.7)
            times.append(max(0.12 + 0.8 * pow(x, 1.35) + jitter, 0.1))
        }
        return times
    }

    /// The bank's ka-ching lands here (s).
    static let kaChingAt: Float = 1.0

    /// Banking (GAME-DESIGN §4): a heavy lid thunk, a cascade of clinks over 0.8 s (more for a bigger haul), then a
    /// low "ka-ching" chord. A hushed bank (the mimic never stirred) adds a tiny proud sparkle.
    static func bank(value: Int, hushed: Bool, dice: inout FeelDice) -> [FeelSynthCommand] {
        var commands: [FeelSynthCommand] = [
            // The lid thunk: wood, weight, a knock.
            .tone(FeelToneSpec(start: 140, end: 58, glide: 0.1, duration: 0.26, attack: 0.002, decay: 0.08,
                               gain: 0.3, harmonics: 5)),
            .noise(FeelNoiseSpec(.lowPass, cutoff: 480, to: 200, sweep: 0.08, q: 1, attack: 0.001, decay: 0.06,
                                 gain: 0.26)),
            .ring(FeelRingSpec(.wood, fundamental: 210, partials: 4, decay: 0.06, brightness: 0.45, gain: 0.2,
                               seed: dice.seed32())),
        ]
        let times = cascadeTimes(count: cascadeCount(value: value))
        for (index, time) in times.enumerated() {
            let fade = Float(1 - 0.4 * Double(index) / Double(max(times.count - 1, 1)))
            commands.append(contentsOf: coinClink(dice: &dice, scale: 0.7 * fade, delay: Float(time)))
        }
        // Ka-ching: a short metal "ka", then a low bell chord.
        commands.append(.noise(FeelNoiseSpec(.highPass, cutoff: 2500, q: 0.7, attack: 0.0005, decay: 0.012,
                                             gain: 0.1, delay: kaChingAt)))
        let chord: [Float] = [293.66, 369.99, 440.0]
        for (index, f) in chord.enumerated() {
            commands.append(.ring(FeelRingSpec(.bell, fundamental: f, partials: 5, decay: 0.9, brightness: 0.45,
                                               gain: 0.075, delay: kaChingAt + 0.03 + 0.012 * Float(index),
                                               seed: dice.seed32())))
        }
        commands.append(.ring(FeelRingSpec(.glass, fundamental: 2349.3, partials: 2, decay: 0.35, brightness: 0.3,
                                           gain: 0.04, delay: kaChingAt + 0.06, seed: dice.seed32())))
        if hushed {
            commands.append(.ring(FeelRingSpec(.chime, fundamental: 1174.66, partials: 3, decay: 0.6,
                                               brightness: 0.3, gain: 0.05, delay: kaChingAt + 0.3,
                                               seed: dice.seed32())))
            commands.append(.ring(FeelRingSpec(.chime, fundamental: 1760, partials: 3, decay: 0.7, brightness: 0.3,
                                               gain: 0.045, delay: kaChingAt + 0.42, seed: dice.seed32())))
        }
        return commands
    }

    // MARK: The torch

    /// 15 s left: the flame gutters and a low bell warns.
    static func torchLow() -> [FeelSynthCommand] {
        [
            .noise(FeelNoiseSpec(.bandPass, cutoff: 900, to: 300, sweep: 0.4, q: 0.9, attack: 0.02, decay: 0.15,
                                 gain: 0.07)),
            .ring(FeelRingSpec(.bell, fundamental: 220, partials: 5, decay: 0.8, brightness: 0.4, gain: 0.07,
                               delay: 0.1)),
        ]
    }

    /// Each whole second in the last 15: a dry clock tick.
    static func torchTick() -> [FeelSynthCommand] {
        [.ring(FeelRingSpec(.wood, fundamental: 2400, partials: 2, decay: 0.008, brightness: 0.35, gain: 0.05))]
    }

    /// The torch goes out: a snuff, a sinking tone and one low bell.
    static func torchOut() -> [FeelSynthCommand] {
        [
            .noise(FeelNoiseSpec(.bandPass, cutoff: 1500, to: 200, sweep: 0.6, q: 0.8, attack: 0.005, decay: 0.25,
                                 gain: 0.12)),
            .tone(FeelToneSpec(start: 110, end: 55, glide: 1.0, duration: 1.2, attack: 0.02, decay: 0.5, gain: 0.12,
                               harmonics: 4)),
            .ring(FeelRingSpec(.bell, fundamental: 146.83, partials: 5, decay: 1.6, brightness: 0.4, gain: 0.08,
                               delay: 0.2)),
        ]
    }

    // MARK: Celebration and UI

    /// Passing the personal best: a bright rising four-note chime with a glint.
    static func newBest(delay: Float = 0) -> [FeelSynthCommand] {
        let notes: [Float] = [1174.66, 1479.98, 1760.0, 2349.3]
        var commands: [FeelSynthCommand] = []
        for (index, f) in notes.enumerated() {
            let last = index == notes.count - 1
            commands.append(.ring(FeelRingSpec(.chime, fundamental: f, partials: 4, decay: last ? 0.9 : 0.5,
                                               brightness: 0.35, gain: last ? 0.1 : 0.08,
                                               delay: delay + 0.085 * Float(index), seed: UInt32(index + 3))))
        }
        return commands
    }

    /// A soft wooden click.
    static func uiTap() -> [FeelSynthCommand] {
        [
            .ring(FeelRingSpec(.wood, fundamental: 1500, partials: 3, decay: 0.012, brightness: 0.4, gain: 0.12)),
            .noise(FeelNoiseSpec(.highPass, cutoff: 3000, q: 0.7, attack: 0.0005, decay: 0.003, gain: 0.05)),
        ]
    }

    /// Two wooden clicks, the second higher.
    static func uiConfirm() -> [FeelSynthCommand] {
        var commands = uiTap()
        commands.append(.ring(FeelRingSpec(.wood, fundamental: 2000, partials: 3, decay: 0.014, brightness: 0.4,
                                           gain: 0.12, delay: 0.06)))
        return commands
    }

    /// Rank up, a new relic page: a rising D major arpeggio of chimes over a soft chord and a coin shower.
    static func celebrate(dice: inout FeelDice) -> [FeelSynthCommand] {
        let semitones: [Double] = [0, 4, 7, 12, 16]
        var commands: [FeelSynthCommand] = []
        for index in 0..<semitones.count {
            let last = index == semitones.count - 1
            let frequency = Float(587.33 * pow(2.0, semitones[index] / 12))
            commands.append(.ring(FeelRingSpec(.chime, fundamental: frequency, partials: 4, decay: last ? 0.9 : 0.4,
                                               brightness: 0.35, gain: last ? 0.11 : 0.085,
                                               delay: 0.09 * Float(index) + (last ? 0.02 : 0),
                                               seed: UInt32(index + 7))))
        }
        let chord: [Float] = [293.66, 369.99, 440.0]
        for f in chord {
            commands.append(.tone(FeelToneSpec(start: f, duration: 1.2, attack: 0.05, decay: 0.5, gain: 0.03,
                                               harmonics: 2)))
        }
        for k in 0..<4 {
            commands.append(contentsOf: coinClink(dice: &dice, scale: 0.45, delay: 0.1 + 0.11 * Float(k)))
        }
        return commands
    }

    // MARK: Helpers

    static func clamp01(_ value: Double) -> Double {
        FeelMath.clamp01(value)
    }

    static func smoothstep(_ x: Double) -> Double {
        FeelMath.smoothstep(x)
    }
}

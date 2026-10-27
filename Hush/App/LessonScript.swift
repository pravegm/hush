import CoreGraphics
import Foundation

/// The First Chest's fixed chest (GAME-DESIGN §8, ROUND-1 App): 2 copper, 1 silver, 1 gem, a Heavy sleeper. The coin
/// nearest the light is the first thing the lid reveals, and nothing sits behind the lesson card's band.
/// R2 (QA-1 P2-1): the first coin lies deeper (0.20, lit well clear of the shut zone), so a gentle opener who bags it at
/// "Look: gold!" can't bank by accident before the Freeze step is taught.
enum LessonChest {
    static let mimicName = "Dozy Doris"

    static var spec: ChestSpec {
        let items: [LootItem] = [
            LootItem(id: 1, kind: .copper, value: 8, depth: 0.20, position: CGPoint(x: 250, y: 150), radius: 22,
                     rotation: 0.3),
            LootItem(id: 2, kind: .copper, value: 6, depth: 0.26, position: CGPoint(x: 420, y: 120), radius: 22,
                     rotation: -0.5),
            LootItem(id: 3, kind: .silver, value: 24, depth: 0.36, position: CGPoint(x: 335, y: 95), radius: 24,
                     rotation: 0.1),
            LootItem(id: 4, kind: .gem(.ruby), value: 70, depth: 0.50, position: CGPoint(x: 180, y: 85), radius: 26,
                     rotation: 0.6),
        ]
        return ChestSpec(index: 0, tier: .wooden, mimic: .heavySleeper, mimicName: mimicName, multiplier: 1,
                         decay: 0.14, items: items)
    }

    /// No candle, no bites, 0.6× noise, this chest on repeat (ARCHITECTURE SessionOptions).
    static var options: SessionOptions {
        SessionOptions(torch: false, bites: false, noiseScale: 0.6, fixedChest: spec)
    }
}

/// What the lesson card shows (published by GameController).
struct LessonDisplay: Equatable {
    var step: Int
    var line: String
    /// A short "well done" beat between steps.
    var praise: Bool
    /// Red/amber: "Slower…", "Freeze!".
    var warning: Bool
    var canSkip: Bool
    /// The pose step: glow the lid half ("Lift this half") or point at the lever ("Slide this up… slowly").
    var marksLid: Bool
    /// Step 6: the closing card (the stakes: candle, bite, bank).
    var isFinal: Bool
    var usesSlider: Bool
    /// R2: the open step points at the noise meter ("Watch the noise").
    var pointsAtMeter: Bool = false
}

/// The First Chest lesson's script (GAME-DESIGN §8): one sentence per step, passed by doing. Pure; tested.
/// The App feeds it every frame and applies its actions (the scripted stir via `nudgeNoise(to:)`).
struct LessonScript: Equatable {
    enum Step: Int, CaseIterable, Equatable {
        case pose = 1, open, grab, freeze, bank, done
    }

    struct Input: Equatable {
        var time: Double
        /// The filtered hinge angle (nil without a hinge).
        var angle: Double?
        /// The lid comes from the hinge (else the slider).
        var hasHinge: Bool
        var openness: Double
        var lidSpeed: Double
        var dragSpeed: Double
        var anyGrabbable: Bool
        var bagCount: Int
        var noise: Double
        var hint: HeistHint?
        var events: [HeistEvent]

        init(time: Double, angle: Double? = nil, hasHinge: Bool = true, openness: Double = 0, lidSpeed: Double = 0,
             dragSpeed: Double = 0, anyGrabbable: Bool = false, bagCount: Int = 0, noise: Double = 0,
             hint: HeistHint? = nil, events: [HeistEvent] = []) {
            self.time = time; self.angle = angle; self.hasHinge = hasHinge; self.openness = openness
            self.lidSpeed = lidSpeed; self.dragSpeed = dragSpeed; self.anyGrabbable = anyGrabbable
            self.bagCount = bagCount; self.noise = noise; self.hint = hint; self.events = events
        }
    }

    enum Action: Equatable {
        case nudgeNoise(Double)
    }

    // GAME-DESIGN §8 gates. R2 (REVIEW-1-duo P1-6): 90…112°, so the pose step never passes where the chest still says
    // "Ease the lid down first" (looting starts at θ ≤ 110°).
    static let poseMin: Double = 90
    static let poseMax: Double = 112
    static let poseHold: Double = 0.5
    /// The slider's "pose" step passes once the lid has been slid up this far.
    static let sliderStart: Double = 0.04
    static let stirDelay: Double = 0.8
    static let stirLevel: Double = 0.55
    static let stillNeeded: Double = 1.5
    static let calmLevel: Double = 0.1
    static let stillDragSpeed: Double = 60
    static let praiseSeconds: Double = 1.0
    static let slowerSeconds: Double = 1.5
    /// After "Slower…", a calm lid makes the grumble fall back to this.
    static let grumbleFallback: Double = 0.15

    private(set) var step: Step
    let replay: Bool
    private(set) var time: Double = 0
    private(set) var praiseLine: String?
    private var praiseUntil: Double?
    private var next: Step?
    private var stepStartedAt: Double?
    private var poseSince: Double?
    private(set) var stirred = false
    private var stillSince: Double?
    private(set) var movedDuringFreeze = false
    private var slowerUntil: Double = -100
    private var calmPending = false
    /// R2 (QA-1 P2-1): banks made before the Freeze step was taught. The first sends the lesson round once more.
    private(set) var earlyBanks = 0

    init(start: Step = .pose, replay: Bool = false) {
        self.step = start
        self.replay = replay
    }

    /// Skip is offered after step 2 (or any time on a replay).
    var canSkip: Bool { replay || step.rawValue >= Step.grab.rawValue }
    var isPraising: Bool { praiseUntil != nil }
    var isSlower: Bool { time < slowerUntil }

    mutating func update(_ i: Input) -> [Action] {
        time = i.time
        var actions: [Action] = []
        if stepStartedAt == nil { stepStartedAt = i.time }
        let banked = i.events.contains { e in
            if case .banked = e { return true }
            return false
        }
        let bagged = i.events.contains { e in
            if case .itemBagged = e { return true }
            return false
        }
        // Banked in the bank step: the lesson is learnt. Banked early (grab or freeze: the lid shut while the bag had
        // the coin) the Freeze was never taught, so the lesson goes round once more; a second early bank ends it.
        let current = next ?? step
        if banked && (current == .bank || (current == .freeze && stirred && next == nil)) {
            pass(to: .done, praise: "Banked! Gently does it.", at: i.time)
            return actions
        }
        if banked && (current == .grab || current == .freeze) {
            earlyBanks += 1
            if earlyBanks >= 2 {
                pass(to: .done, praise: "Banked! Gently does it.", at: i.time)
            } else {
                pass(to: .open, praise: "Banked! Once more, slowly.", at: i.time)
            }
            return actions
        }
        if let until = praiseUntil {
            guard i.time >= until else { return actions }
            praiseUntil = nil
            praiseLine = nil
            if let n = next {
                next = nil
                enter(n, at: i.time)
            }
        }
        // A loud lid: "Slower…", and once it's calm the grumble falls back (never in the freeze step).
        if step == .open || step == .grab || step == .bank {
            if i.lidSpeed > Tuning.loudSpeed {
                slowerUntil = i.time + Self.slowerSeconds
                calmPending = true
            } else if calmPending && i.lidSpeed < Tuning.quietSpeed {
                calmPending = false
                if i.noise > Self.grumbleFallback { actions.append(.nudgeNoise(Self.grumbleFallback)) }
            }
        }
        switch step {
        case .pose:
            if i.hasHinge {
                if let a = i.angle, a >= Self.poseMin, a <= Self.poseMax {
                    let since = poseSince ?? i.time
                    poseSince = since
                    if i.time - since >= Self.poseHold { pass(to: .open, praise: "That's it.", at: i.time) }
                } else {
                    poseSince = nil
                }
            } else if i.openness >= Self.sliderStart {
                pass(to: .open, praise: "That's it.", at: i.time)
            }
        case .open:
            if i.anyGrabbable { pass(to: .grab, praise: "Look: gold!", at: i.time) }
        case .grab:
            if bagged || i.bagCount > 0 { pass(to: .freeze, praise: "In the bag!", at: i.time) }
        case .freeze:
            let started = stepStartedAt ?? i.time
            if !stirred {
                if i.time - started >= Self.stirDelay {
                    stirred = true
                    stillSince = nil
                    actions.append(.nudgeNoise(Self.stirLevel))
                }
            } else {
                let still = i.lidSpeed < Tuning.quietSpeed && i.dragSpeed < Self.stillDragSpeed
                if still {
                    let since = stillSince ?? i.time
                    stillSince = since
                    if i.time - since >= Self.stillNeeded {
                        actions.append(.nudgeNoise(Self.calmLevel))
                        pass(to: .bank, praise: "Phew. Snoring again.", at: i.time)
                    }
                } else {
                    stillSince = nil
                    movedDuringFreeze = true
                }
            }
        case .bank:
            break   // passes on `banked` (above)
        case .done:
            break
        }
        return actions
    }

    private mutating func pass(to step: Step, praise: String, at time: Double) {
        praiseLine = praise
        praiseUntil = time + Self.praiseSeconds
        next = step
    }

    private mutating func enter(_ newStep: Step, at time: Double) {
        step = newStep
        stepStartedAt = time
        poseSince = nil
        stillSince = nil
        if newStep == .freeze {
            stirred = false
            movedDuringFreeze = false
        }
    }

    /// The card's one line (GAME-DESIGN §8), in the slider's words without a hinge. R2: "candle", the lever by name,
    /// and the open step points at the noise meter (UX P0-2).
    func line(slider: Bool, angle: Double?, hint: HeistHint?) -> String {
        if let praiseLine { return praiseLine }
        if isSlower { return "Slower… it's grumbling." }
        switch step {
        case .pose:
            if slider { return "Slide the lever up… slowly." }
            if let a = angle {
                if a >= 168 { return "Stand it up: lift this half." }
                if a > Self.poseMax { return "Close it a little, nearly upright…" }
                if a < Self.poseMin { return "Lift this half a little more…" }
            }
            return "Stand your Duo like a little laptop. Lift this half."
        case .open:
            if hint == .easeLidDown {
                return slider ? "Slide the lever all the way down first." : "Ease the lid down first."
            }
            return slider ? "Slide the lever up… slowly. Watch the noise." : "Open the lid… slowly. Watch the noise."
        case .grab:
            return "Drag the coin into your bag."
        case .freeze:
            if !stirred { return "Shh… did you hear that?" }
            return movedDuringFreeze ? "Freeze! Not a twitch." : "It's stirring. Freeze!"
        case .bank:
            return slider ? "Slide the lever down to keep it." : "Ease the lid shut to keep it."
        case .done:
            return "Candle out = run over"
        }
    }

    func display(slider: Bool, angle: Double?, hint: HeistHint?) -> LessonDisplay {
        let warning = praiseLine == nil && (isSlower || (step == .freeze && stirred))
        return LessonDisplay(step: step.rawValue, line: line(slider: slider, angle: angle, hint: hint),
                             praise: praiseLine != nil, warning: warning, canSkip: canSkip,
                             marksLid: step == .pose && praiseLine == nil, isFinal: step == .done && praiseLine == nil,
                             usesSlider: slider,
                             pointsAtMeter: praiseLine == nil && (step == .open || (step == .freeze && stirred)))
    }
}

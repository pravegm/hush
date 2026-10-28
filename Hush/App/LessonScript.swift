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
    /// R3 (UX P0-1): the lid marker's cue in the pose step, from the SAME angle branch as the line (nil: no lid marker,
    /// e.g. the lever on a phone).
    var liftCue: LessonScript.LiftCue? = nil
    /// R11 (UX P1-2): the first lesson was skipped: the stakes card is "the gist", not "Lovely work…".
    var gist: Bool = false

    /// The final card's title for this display. Pure; tested.
    var finalCardTitle: String { gist ? AppRules.gistTitle : LessonDisplay.finalTitle }

    /// R4 (QA-3 P2, UX P2-9): what VoiceOver hears when the lesson moves on: a new step, a praise beat, a warning, the
    /// final card. Nil when nothing new is said (the pose step's line following the angle isn't re-read). Pure; tested.
    static func announcement(from old: LessonDisplay?, to new: LessonDisplay) -> String? {
        if new.isFinal { return old?.isFinal == true ? nil : new.finalCardTitle }
        guard let old else { return new.line }
        if old.step != new.step || old.praise != new.praise || old.warning != new.warning || old.isFinal {
            return new.line
        }
        return nil
    }

    /// The final card's title.
    static let finalTitle = "Lovely work, little thief."
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
        /// R7 (DEVICE-RISKS-1 item 11): where each HELD item is now (item id → floor point). The Freeze step judges
        /// these by displacement, never by drag speed (a resting finger's tremor reads 60+ pt/s).
        var held: [Int: CGPoint]

        init(time: Double, angle: Double? = nil, hasHinge: Bool = true, openness: Double = 0, lidSpeed: Double = 0,
             dragSpeed: Double = 0, anyGrabbable: Bool = false, bagCount: Int = 0, noise: Double = 0,
             hint: HeistHint? = nil, events: [HeistEvent] = [], held: [Int: CGPoint] = [:]) {
            self.time = time; self.angle = angle; self.hasHinge = hasHinge; self.openness = openness
            self.lidSpeed = lidSpeed; self.dragSpeed = dragSpeed; self.anyGrabbable = anyGrabbable
            self.bagCount = bagCount; self.noise = noise; self.hint = hint; self.events = events
            self.held = held
        }
    }

    /// R7 (DEVICE-RISKS-1 item 11): "still" for the Freeze step means every held item moved less than
    /// `stillDisplacement` pt within the last `stillWindow` s. Pure; tested.
    struct HeldStillness: Equatable {
        private struct Sample: Equatable {
            var time: Double
            var id: Int
            var point: CGPoint
        }

        private var samples: [Sample] = []

        init() {}

        /// Records this frame's held items; true while each one has stayed within `stillDisplacement` of every
        /// position it had in the last `stillWindow` seconds. Nothing held is still. A newly grabbed item starts its
        /// own history (the grab itself isn't a twitch).
        mutating func update(time: Double, held: [Int: CGPoint]) -> Bool {
            let oldest = time - LessonScript.stillWindow
            samples.removeAll { s in s.time < oldest || s.time > time || held[s.id] == nil }
            var still = true
            for (id, now) in held {
                for s in samples where s.id == id {
                    let dx = Double(now.x - s.point.x)
                    let dy = Double(now.y - s.point.y)
                    if (dx * dx + dy * dy).squareRoot() >= LessonScript.stillDisplacement { still = false }
                }
            }
            for (id, now) in held { samples.append(Sample(time: time, id: id, point: now)) }
            return still
        }

        mutating func reset() { samples.removeAll() }
    }

    enum Action: Equatable {
        case nudgeNoise(Double)
    }

    // GAME-DESIGN §8 gates. R2 (REVIEW-1-duo P1-6): 90…112°, so the pose step never passes where the chest still says
    // "Ease the lid down first" (looting starts at θ ≤ 110°).
    static let poseMin: Double = 90
    static let poseMax: Double = 112
    static let poseHold: Double = 0.5
    /// R7 (ROUND-7 App 3, DEVICE-RISKS-1 item 8): the pose step also passes after `looseHold` s anywhere in
    /// `looseMin…looseMax` ("That'll do."), against the hinge's ±5° and a laptop rest of 105–125°.
    static let looseMin: Double = 80
    static let looseMax: Double = 125
    static let looseHold: Double = 4
    static let loosePraise = "That'll do."
    /// R7: Skip is offered from step 1 once the lesson has run this long (s); on a replay, from the start.
    static let skipAfter: Double = 20
    /// The slider's "pose" step passes once the lid has been slid up this far.
    static let sliderStart: Double = 0.04
    static let stirDelay: Double = 0.8
    static let stirLevel: Double = 0.55
    static let stillNeeded: Double = 1.5
    static let calmLevel: Double = 0.1
    /// R7 (DEVICE-RISKS-1 item 11): the Freeze step's "still" is displacement: every held item under 8 pt within 0.3 s
    /// (it was a drag speed under 60 pt/s, which a resting finger's tremor could fail).
    static let stillDisplacement: Double = 8
    static let stillWindow: Double = 0.3
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
    /// R7: since when the lid has been in the loose window (80…125°).
    private var looseSince: Double?
    /// R7: when the lesson started (its first update), for "Skip after 20 s".
    private var startedAt: Double?
    private var heldStillness = HeldStillness()
    private(set) var stirred = false
    private var stillSince: Double?
    private(set) var movedDuringFreeze = false
    private var slowerUntil: Double = -100
    private var calmPending = false
    /// R2 (QA-1 P2-1): banks made before the Freeze step was taught. The first sends the lesson round once more.
    private(set) var earlyBanks = 0
    /// R11 (UX P1-2): a first lesson's Skip jumped straight to the stakes card.
    private(set) var skippedToGist = false

    init(start: Step = .pose, replay: Bool = false) {
        self.step = start
        self.replay = replay
    }

    /// R11 (UX P1-2): Skip on a FIRST lesson lands on the stakes card ("Here's the gist, little thief."), so a player
    /// stuck at step 1 still learns the candle, the bite and the bank before the first run. No praise beat.
    mutating func skipToStakes() {
        praiseLine = nil
        praiseUntil = nil
        next = nil
        skippedToGist = true
        enter(.done, at: time)
    }

    /// Skip is offered after step 2 (or any time on a replay). R7 (ROUND-7 App 3): also from step 1 once the lesson
    /// has run `skipAfter` (20) s.
    var canSkip: Bool {
        if replay || step.rawValue >= Step.grab.rawValue { return true }
        guard let startedAt else { return false }
        return time - startedAt >= Self.skipAfter
    }
    /// R4 (QA-3 P2-3): the lesson is banked: its praise beat or the final card (the closing pause stays away).
    var isFinishing: Bool { step == .done || next == .done }
    var isPraising: Bool { praiseUntil != nil }
    var isSlower: Bool { time < slowerUntil }

    mutating func update(_ i: Input) -> [Action] {
        time = i.time
        var actions: [Action] = []
        if stepStartedAt == nil { stepStartedAt = i.time }
        if startedAt == nil { startedAt = i.time }
        // R7: every frame's held items feed the Freeze step's displacement rule (so its window is full when needed).
        let heldStill = heldStillness.update(time: i.time, held: i.held)
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
                // R7 (ROUND-7 App 3): 0.5 s in 90…112°, or 4 s anywhere in 80…125° ("That'll do.").
                let a = i.angle.flatMap { $0.isFinite ? $0 : nil }
                if let a, a >= Self.poseMin, a <= Self.poseMax {
                    let since = poseSince ?? i.time
                    poseSince = since
                } else {
                    poseSince = nil
                }
                if let a, a >= Self.looseMin, a <= Self.looseMax {
                    let since = looseSince ?? i.time
                    looseSince = since
                } else {
                    looseSince = nil
                }
                if let since = poseSince, i.time - since >= Self.poseHold {
                    pass(to: .open, praise: "That's it.", at: i.time)
                } else if let since = looseSince, i.time - since >= Self.looseHold {
                    pass(to: .open, praise: Self.loosePraise, at: i.time)
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
                // R7 (DEVICE-RISKS-1 item 11): held items judged by displacement, not drag speed.
                let still = i.lidSpeed < Tuning.quietSpeed && heldStill
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
        looseSince = nil
        stillSince = nil
        if newStep == .freeze {
            stirred = false
            movedDuringFreeze = false
        }
    }

    /// R3 (UX P0-1): which way the pose step's lid marker points. The marker and the line come from this one branch,
    /// so they can never disagree (R2 said "Close it a little" under a "↑ Lift this half" marker).
    enum LiftCue: Equatable {
        /// Flat (≥ 168°) or no angle yet: "↑ Lift this half".
        case lift
        /// Open past the window (> 112°): "↓ Close the lid a little" (R12; was "Lower this half a little").
        case lower
        /// Under the window (< 90°): "↑ Lift this half".
        case liftMore
        /// In the 90…112° window: "Hold it there…" (a tick).
        case hold

        /// The marker's words on the lid. Pure; tested.
        var label: String {
            switch self {
            case .lift, .liftMore: return "Lift this half"
            // R12 rule 7: chest words.
            case .lower: return "Close the lid a little"
            case .hold: return "Hold it there…"
            }
        }

        /// The arrow: up, down, or none (a tick). Pure; tested.
        var pointsUp: Bool? {
            switch self {
            case .lift, .liftMore: return true
            case .lower: return false
            case .hold: return nil
            }
        }
    }

    /// Pure; tested.
    static func liftCue(angle: Double?) -> LiftCue {
        guard let a = angle, a.isFinite else { return .lift }
        if a >= 168 { return .lift }
        if a > poseMax { return .lower }
        if a < poseMin { return .liftMore }
        return .hold
    }

    /// The card's one line (GAME-DESIGN §8). R3 (decision 4): `slider` is the LAYOUT's words (no fold: the lever;
    /// a fold: the lid), never the input's. R3 (decision 3): one verb, "bank".
    /// R12 rule 7: the same order (close it, then open it slowly) in chest words, and never "open" while the lid is
    /// open: `openness` (the session's, nil = unknown) past `AppRules.lidOpenLine` swaps the open step's words.
    func line(slider: Bool, angle: Double?, hint: HeistHint?, openness: Double? = nil) -> String {
        if let praiseLine { return praiseLine }
        if isSlower { return "Slower… it's grumbling." }
        let lidOpen = openness.map { AppRules.lidReadsOpen($0) } ?? false
        switch step {
        case .pose:
            if slider { return "Slide the lever up… slowly." }
            switch Self.liftCue(angle: angle) {
            case .lift: return "Stand your Duo like a little laptop."
            // R12 rule 7: the lid is open at step 1, so the step asks to close it first.
            case .lower: return Self.closeToStart
            case .liftMore: return "Lift it a little more…"
            case .hold: return "Hold it there…"
            }
        case .open:
            // R12: the lesson's chest still waits for a closed lid (Core keeps its gate there): chest words.
            if hint == .easeLidDown {
                return slider ? "Slide the lever all the way down first." : "Close the lid a little first."
            }
            if slider { return "Slide the lever up… slowly. Watch the noise." }
            // R12 rule 7: "Now open it… slowly." while it is closed; once it is up, only "keep going".
            return lidOpen ? "Keep going… slowly. Watch the noise." : "Now open it… slowly. Watch the noise."
        case .grab:
            // R4 (tester 7): several coins show, so any of them will do.
            return "Drag a coin into your bag."
        case .freeze:
            if !stirred { return "Shh… did you hear that?" }
            return movedDuringFreeze ? "Freeze! Not a twitch." : "It's stirring. Freeze!"
        case .bank:
            // R7 (DEVICE-RISKS-1 item 3): never "shut". R12 rule 3 (founder): bank = close the lid.
            return slider ? "Slide the lever down to bank it." : "Close the lid to bank it."
        case .done:
            return "Candle out = run over"
        }
    }

    /// R12 rule 7: step 1 with the lid open.
    static let closeToStart = "Close the lid to start"

    func display(slider: Bool, angle: Double?, hint: HeistHint?, openness: Double? = nil) -> LessonDisplay {
        let warning = praiseLine == nil && (isSlower || (step == .freeze && stirred))
        let marks = step == .pose && praiseLine == nil
        return LessonDisplay(step: step.rawValue,
                             line: line(slider: slider, angle: angle, hint: hint, openness: openness),
                             praise: praiseLine != nil, warning: warning, canSkip: canSkip,
                             marksLid: marks, isFinal: step == .done && praiseLine == nil,
                             usesSlider: slider,
                             pointsAtMeter: praiseLine == nil && (step == .open || (step == .freeze && stirred)),
                             liftCue: marks && !slider && !isSlower ? Self.liftCue(angle: angle) : nil,
                             gist: skippedToGist)
    }
}

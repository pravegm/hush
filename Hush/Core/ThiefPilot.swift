import CoreGraphics
import Foundation

// MARK: - The simulated thief (attract mode, CI frames, balance tests)
//
// It only sees what a player sees (the snapshot) and drives the lid and the touches. Deterministic with its seed.
// Per chest it rolls an opening speed, a closing speed and (novice) whether it slams, then:
//   settle (ease the lid into the shut zone if a chest arrives with it open) → open (to just past the deepest item it
//   wants) → collect (drag the lit items to the bag one by one) → close (ease it shut; the session banks).
// - Expert and perfect use two hands: they drag lit items while the lid is still opening, take the highest value
//   first, reach for relics and bank early when the torch would go out first.
// - Novice and casual open first and then collect, front items first, and never reach for a relic (unless nothing
//   else is left in an empty-bagged chest, so they never get stuck).
// - Freezing: when the stage reaches its freeze stage it stops the lid and the finger (novice obeys half the time;
//   a slam in progress is never stopped) and carries on once the noise has fallen below its unfreeze level, or the
//   bag jingle floor + 0.04 if that is higher (R2: without it the noise can never get there and the pilot hangs).
// - R2 (REVIEW-1-feel caveats): expert and perfect play to the thresholds: opening speed × quietSpeed/8, closing at
//   0.75–1.0 × closeQuietSpeed (perfect 0.95 ×), drags × dragQuietSpeed/250; with the bag jingle on they leave the
//   copper while anything better is left and bank once the jingle floor reaches 0.20 (perfect 0.22).
// - R2 relic glimmer: in each chest the novice (50 %) and casual (60 %) pilot may be lured by a relic and reach for it.
// - R7 "real hands" (ROUND-7 Core item 4): novice and casual move like a person. Casual opens at 10–25°/s and closes at
//   20–40°/s, novice opens at 12–40°/s and closes at 30–60°/s (its slams stay), and every stroke from still starts with
//   a stick-slip jump of 0.5–2° in one frame (drawn from its own stream, so every other draw is unchanged). Expert and
//   perfect still play to the R2–R6 lines (12 / 18 °/s), not to R7's forgiving 14 / 28: the forgiveness is for real
//   hands on unknown hardware, not a free speed-up for the skill ceiling.
// - R12 (design/ROUND-12.md rule 4): when the robbed chest waits for the lid (`hint == .closeForNext`) it closes the lid
//   at that chest's closing speed (no new draws but the stick-slip); the next chest then arrives in the shut zone and
//   the settle step takes the lid the rest of the way down before opening it.
// Keep in sync with ThiefPilot in tools/balance-sim.js (same draw order).

enum PilotSkill: String, CaseIterable, Sendable {
    case novice, casual, expert, perfect
}

struct PilotTouch: Equatable {
    enum Phase { case began, moved, ended }
    var phase: Phase
    var id: Int
    var point: CGPoint
}

struct PilotOutput: Equatable {
    var lid: LidInput
    var touches: [PilotTouch]
}

/// Per-skill behaviour (ROUND-1 "ThiefPilot").
struct PilotProfile {
    /// Lid opening speed per chest (°/s).
    var open: ClosedRange<Double>
    /// Lid closing speed per chest (°/s): R1 "eases shut at 6–15°/s"; R7 real hands close at 20–60°/s.
    var close: ClosedRange<Double>
    /// Chance per chest of slamming the lid shut instead, and the slam speed (°/s).
    var slamChance: Double
    var slam: ClosedRange<Double>
    /// Drag speed per item (pt/s). Tuning.dragQuietSpeed (R2: 350) is the silent limit.
    var drag: ClosedRange<Double>
    /// Pause after each drag (s).
    var reaction: Double
    /// Freezes once the stage reaches this …
    var freezeStage: MimicStage
    /// … with this probability per episode …
    var freezeObey: Double
    /// … until the noise is below this.
    var unfreeze: Double
    /// Drags while the lid is still opening (two hands).
    var concurrent: Bool
    /// Deepest item it wants (relics sit at 0.80–0.88).
    var reach: Double
    /// Chance a drag is let go short of the bag (a clunk).
    var drop: Double
    /// Banks early when the torch would go out first.
    var torchAware: Bool
    /// Takes the front item first (else the most valuable).
    var frontFirst: Bool
    /// R2 relic glimmer: chance per chest of being lured into reaching for a relic (0 = never rolled).
    var lure: Double = 0
    /// R2 bag jingle: leaves the copper while anything better is wanted.
    var skipCheap: Bool = false
    /// R2 bag jingle: banks once the jingle floor reaches this (0 = never).
    var greed: Double = 0
    /// R7 stick-slip: a lid stroke from still breaks away with a jump of this many degrees in one step (0...0 = none).
    var slip: ClosedRange<Double> = 0...0

    /// The R1 behaviour table (speeds in R1 terms: quiet 8 °/s, silent drags 250 pt/s).
    static func base(_ skill: PilotSkill) -> PilotProfile {
        switch skill {
        case .novice:
            return PilotProfile(open: 10...35, close: 10...15, slamChance: 0.3, slam: 70...120, drag: 700...1200,
                                reaction: 0.6, freezeStage: .waking, freezeObey: 0.5, unfreeze: 0.5,
                                concurrent: false, reach: 0.62, drop: 0.15, torchAware: false, frontFirst: true,
                                lure: 0.5)
        case .casual:
            return PilotProfile(open: 8...16, close: 8...15, slamChance: 0, slam: 0...0, drag: 450...800,
                                reaction: 0.55, freezeStage: .waking, freezeObey: 1, unfreeze: 0.5,
                                concurrent: false, reach: 0.80, drop: 0.05, torchAware: false, frontFirst: true,
                                lure: 0.6)
        case .expert:
            return PilotProfile(open: 5...9, close: 8...12, slamChance: 0, slam: 0...0, drag: 200...320,
                                reaction: 0.25, freezeStage: .stirring, freezeObey: 1, unfreeze: 0.25,
                                concurrent: true, reach: 1, drop: 0, torchAware: true, frontFirst: false)
        case .perfect:
            return PilotProfile(open: 6...6, close: 15...15, slamChance: 0, slam: 0...0, drag: 240...240,
                                reaction: 0.12, freezeStage: .stirring, freezeObey: 1, unfreeze: 0.25,
                                concurrent: true, reach: 1, drop: 0, torchAware: true, frontFirst: false)
        }
    }

    /// The pilot actually used: novice and casual with R7's real hands (else as in R1); expert and perfect adapted to
    /// the R2–R6 thresholds (`masterQuietSpeed`, `masterCloseQuietSpeed`).
    static func profile(_ skill: PilotSkill) -> PilotProfile {
        var p: PilotProfile = base(skill)
        switch skill {
        case .novice:
            p.open = handsNoviceOpen
            p.close = handsNoviceClose
            p.slip = handsSlip
            return p
        case .casual:
            p.open = handsCasualOpen
            p.close = handsCasualClose
            p.slip = handsSlip
            return p
        case .expert, .perfect:
            let kl: Double = masterQuietSpeed / r1QuietSpeed
            let kd: Double = Tuning.dragQuietSpeed / r1DragQuietSpeed
            let cq: Double = masterCloseQuietSpeed
            p.open = (p.open.lowerBound * kl)...(p.open.upperBound * kl)
            let perfectClose: ClosedRange<Double> = (0.95 * cq)...(0.95 * cq)
            let expertClose: ClosedRange<Double> = (0.75 * cq)...cq
            p.close = skill == .perfect ? perfectClose : expertClose
            p.drag = (p.drag.lowerBound * kd)...(p.drag.upperBound * kd)
            let jingle: Bool = Tuning.jinglePerItem > 0
            p.skipCheap = jingle
            p.greed = jingle ? (skill == .expert ? greedExpert : greedPerfect) : 0
            return p
        }
    }

    /// R1 quiet lines the base table was written for.
    static let r1QuietSpeed: Double = 8
    static let r1DragQuietSpeed: Double = 250
    /// R7: the lid lines expert and perfect play to (R2–R6's `Tuning.quietSpeed` / `closeQuietSpeed`).
    static let masterQuietSpeed: Double = 12
    static let masterCloseQuietSpeed: Double = 18
    /// R7 real hands (DEVICE-RISKS-1 item 1, REVIEW-1-feel): a natural slow close is 20–40°/s; the novice is faster.
    static let handsCasualOpen: ClosedRange<Double> = 10...25
    static let handsCasualClose: ClosedRange<Double> = 20...40
    static let handsNoviceOpen: ClosedRange<Double> = 12...40
    static let handsNoviceClose: ClosedRange<Double> = 30...60
    /// R7 stick-slip breakaway (degrees in one step) at the start of every stroke from still.
    static let handsSlip: ClosedRange<Double> = 0.5...2
    /// The stick-slip stream (seed ^ this), separate so every other draw is unchanged.
    static let slipSalt: UInt64 = 0x5715B11
    /// Bag-jingle floors at which the adapted pilots bank.
    static let greedExpert: Double = 0.20
    static let greedPerfect: Double = 0.22
    /// Unfreezes at max(unfreeze, the jingle floor + this).
    static let floorUnfreezeMargin: Double = 0.04
    /// The glimmer lure stream (one per skill, shared by every run, as in the sim).
    static let lureSeed: UInt64 = 0x6117AE5

    /// Where the pilot rests the lid when shut (openness; θ ≈ 104°, inside the shut zone).
    static let shutTarget: Double = 0.06
    /// Opens this far past the deepest wanted item's grab line.
    static let openMargin: Double = 0.015
    /// Drag targets: the bag row, and the "let go too early" row inside the chest.
    static let bagY: Double = 400
    static let dropY: Double = 302
    static let bagJitter: Double = 40
    static let bagMinX: Double = 60
    static let bagMaxX: Double = 610
    /// Extra seconds of torch it keeps in hand when deciding to bank early.
    static let torchMargin: Double = 1.0
    /// Pilot touch ids start here (well away from small ids a test might use).
    static let firstTouchID: Int = 900_001
}

struct ThiefPilot {

    private enum Mode { case settle, open, collect, close }

    private struct Drag {
        var touchID: Int
        var itemID: Int
        var x: Double
        var y: Double
        var tx: Double
        var ty: Double
        var speed: Double
    }

    let skill: PilotSkill
    private let profile: PilotProfile
    private var rng: SeededRandom
    /// The lid as the pilot holds it (openness 0…1).
    private(set) var openness: Double = PilotProfile.shutTarget
    private var speed: Double = 0
    private var lastChest: Int = -1
    private var mode: Mode = .open
    private var openSpeed: Double = 6
    private var closeSpeed: Double = 10
    private var slams: Bool = false
    private var slamSpeed: Double = 0
    private var frozen: Bool = false
    private var freezeDecided: Bool = false
    private var obey: Bool = true
    private var reactionLeft: Double = 0
    private var drag: Drag? = nil
    private var nextTouchID: Int = PilotProfile.firstTouchID
    private var lureRng: SeededRandom
    private var lured: Bool = false
    /// R7 stick-slip: its own stream, and whether the lid was still in the previous step (a new stroke).
    private var slipRng: SeededRandom
    private var stillBefore: Bool = true

    init(skill: PilotSkill, seed: UInt64) {
        self.skill = skill
        self.profile = PilotProfile.profile(skill)
        self.rng = SeededRandom(seed: seed)
        self.lureRng = SeededRandom(seed: PilotProfile.lureSeed ^ UInt64(skill.rawValue.count))
        self.slipRng = SeededRandom(seed: seed ^ PilotProfile.slipSalt)
    }

    private var lidOutput: LidInput {
        return Lid.input(openness: openness, speed: speed)
    }

    private mutating func rollChest() {
        openSpeed = rng.range(profile.open)
        closeSpeed = rng.range(profile.close)
        slams = rng.unit() < profile.slamChance
        slamSpeed = rng.range(profile.slam)
    }

    /// Moves the lid towards `target` at `degreesPerSecond`; true once there. R7: a stroke from still first breaks
    /// away with a stick-slip jump (`profile.slip` degrees in this step, if that's more than the normal step).
    private mutating func moveLid(to target: Double, degreesPerSecond: Double, dt: Double) -> Bool {
        var stepLen: Double = degreesPerSecond / Tuning.lidTravel * dt
        if stillBefore && profile.slip.upperBound > 0 && abs(target - openness) > 1e-9 {
            let jump: Double = slipRng.range(profile.slip) / Tuning.lidTravel
            stepLen = max(stepLen, jump)
        }
        stillBefore = false
        let before: Double = openness
        if abs(target - openness) <= stepLen {
            openness = target
        } else {
            openness += (target > openness ? 1 : -1) * stepLen
        }
        speed = dt > 0 ? abs(openness - before) * Tuning.lidTravel / dt : 0
        return openness == target
    }

    private func wanted(_ snap: HeistSnapshot) -> [LootState] {
        let inChest: [LootState] = snap.loot.filter { (s: LootState) -> Bool in s.place == .inChest }
        var reach: Double = profile.reach
        if lured && inChest.contains(where: { (s: LootState) -> Bool in ThiefPilot.isRelic(s) }) { reach = 1 }
        var w: [LootState] = inChest.filter { (s: LootState) -> Bool in s.item.depth <= reach }
        if profile.skipCheap {
            let rich: [LootState] = w.filter { (s: LootState) -> Bool in s.item.kind != .copper }
            if !rich.isEmpty { w = rich }
        }
        if !w.isEmpty { return w }
        let inHand: Bool = snap.loot.contains { (s: LootState) -> Bool in
            if s.place == .inBag { return true }
            if case .held = s.place { return true }
            return false
        }
        return inHand ? [] : inChest
    }

    private func openTarget(_ snap: HeistSnapshot) -> Double? {
        let w: [LootState] = wanted(snap)
        if w.isEmpty { return nil }
        var d: Double = 0
        for s in w { d = max(d, s.item.depth) }
        return min(1, d + Tuning.grabLight * Tuning.lightRamp + PilotProfile.openMargin)
    }

    private static func isRelic(_ s: LootState) -> Bool {
        if case .relic = s.item.kind { return true }
        return false
    }

    private static func worth(_ s: LootState) -> Double {
        if s.item.kind == .oil { return 60 }
        return Double(s.item.value)
    }

    private static func torchBurns(_ mode: RunMode) -> Bool {
        switch mode {
        case .attract, .lesson: return false
        case .run, .daily: return true
        }
    }

    private func touch(_ phase: PilotTouch.Phase, _ d: Drag) -> PilotTouch {
        return PilotTouch(phase: phase, id: d.touchID, point: CGPoint(x: CGFloat(d.x), y: CGFloat(d.y)))
    }

    mutating func step(dt: Double, snapshot snap: HeistSnapshot) -> PilotOutput {
        var touches: [PilotTouch] = []
        stillBefore = !(speed > 0)
        speed = 0
        let active: Bool
        switch snap.phase {
        case .ready, .looting: active = true
        case .banked, .bitten, .torchOut, .finished: active = false
        }
        if !active {
            if let d = drag {
                touches.append(touch(.ended, d))
                drag = nil
            }
            frozen = false
            freezeDecided = false
            return PilotOutput(lid: lidOutput, touches: touches)
        }

        // R12 rule 4: the robbed chest waits, open and empty, for the lid ("Close the phone for the next chest"). Close
        // it at this chest's closing speed; the next chest is dealt in the shut zone and rolls its own speeds.
        if snap.hint == .closeForNext {
            if let d = drag {
                touches.append(touch(.ended, d))
                drag = nil
            }
            frozen = false
            freezeDecided = false
            _ = moveLid(to: PilotProfile.shutTarget, degreesPerSecond: closeSpeed, dt: dt)
            return PilotOutput(lid: lidOutput, touches: touches)
        }

        let idx: Int = snap.chest?.index ?? -1
        if idx != lastChest {
            if profile.lure > 0 { lured = lureRng.unit() < profile.lure }
            lastChest = idx
            rollChest()
            mode = openness > PilotProfile.shutTarget + 0.04 ? .settle : .open
            reactionLeft = 0
        }

        // Freeze.
        let slamming: Bool = mode == .close && slams
        if !frozen {
            if snap.stage >= profile.freezeStage {
                if !freezeDecided {
                    freezeDecided = true
                    obey = rng.unit() < profile.freezeObey
                }
                if obey && !slamming { frozen = true }
            } else {
                freezeDecided = false
            }
        } else if snap.noise < max(profile.unfreeze, snap.noiseFloor + PilotProfile.floorUnfreezeMargin) {
            frozen = false
            freezeDecided = false
            reactionLeft = profile.reaction
        }
        if frozen { return PilotOutput(lid: lidOutput, touches: touches) }
        if reactionLeft > 0 { reactionLeft -= dt }

        // The held drag.
        if var d = drag {
            let held: LootState? = snap.loot.first { (s: LootState) -> Bool in s.item.id == d.itemID }
            let stillHeld: Bool = held.map { (s: LootState) -> Bool in s.place == .held(touchID: d.touchID) } ?? false
            if !stillHeld {
                touches.append(touch(.ended, d))
                drag = nil
            } else {
                let dx: Double = d.tx - d.x
                let dy: Double = d.ty - d.y
                let dist: Double = (dx * dx + dy * dy).squareRoot()
                let stepLen: Double = d.speed * dt
                if dist <= stepLen {
                    d.x = d.tx
                    d.y = d.ty
                    touches.append(touch(.moved, d))
                    touches.append(touch(.ended, d))
                    drag = nil
                    reactionLeft = profile.reaction
                } else {
                    d.x += dx / dist * stepLen
                    d.y += dy / dist * stepLen
                    touches.append(touch(.moved, d))
                    drag = d
                }
            }
        }

        let bagHas: Bool = snap.loot.contains { (s: LootState) -> Bool in s.place == .inBag }

        // R2: bank once the bag jingles too loudly (the master's push-your-luck call).
        if profile.greed > 0 && bagHas && drag == nil && mode != .close && mode != .settle
            && snap.noiseFloor >= profile.greed {
            mode = .close
        }

        // Bank what's in hand before the torch goes out.
        if profile.torchAware && ThiefPilot.torchBurns(snap.mode) && bagHas && mode != .close && mode != .settle {
            let need: Double = openness * Tuning.lidTravel / max(closeSpeed, 1) + Tuning.shutHoldSeconds
                + PilotProfile.torchMargin
            if snap.torchRemaining < need && drag == nil { mode = .close }
        }

        // The lid.
        switch mode {
        case .settle:
            if moveLid(to: PilotProfile.shutTarget, degreesPerSecond: closeSpeed, dt: dt) { mode = .open }
        case .open:
            if let target = openTarget(snap), openness < target - 1e-9 {
                if profile.concurrent || drag == nil {
                    _ = moveLid(to: target, degreesPerSecond: openSpeed, dt: dt)
                }
            } else {
                mode = .collect
            }
        case .collect:
            let w: [LootState] = wanted(snap)
            let anyGrab: Bool = w.contains { (s: LootState) -> Bool in s.grabbable }
            if !anyGrab && drag == nil {
                if !w.isEmpty {
                    mode = .open
                } else if bagHas && reactionLeft <= 0 {
                    mode = .close
                } else if !bagHas {
                    mode = .open
                }
            }
        case .close:
            if !bagHas && drag == nil {
                mode = .open
            } else {
                _ = moveLid(to: PilotProfile.shutTarget, degreesPerSecond: slams ? slamSpeed : closeSpeed, dt: dt)
            }
        }

        // Start a drag.
        if drag == nil && reactionLeft <= 0 && (mode == .collect || (mode == .open && profile.concurrent)) {
            let cands: [LootState] = wanted(snap).filter { (s: LootState) -> Bool in s.grabbable }
            if var best = cands.first {
                for s in cands {
                    let better: Bool = profile.frontFirst ? s.position.y > best.position.y
                        : ThiefPilot.worth(s) > ThiefPilot.worth(best)
                    if better { best = s }
                }
                let v: Double = rng.range(profile.drag)
                let drops: Bool = rng.unit() < profile.drop
                let jitter: Double = rng.range(-PilotProfile.bagJitter...PilotProfile.bagJitter)
                let bx: Double = Double(best.position.x)
                let by: Double = Double(best.position.y)
                let tx: Double = drops ? bx : min(max(bx + jitter, PilotProfile.bagMinX), PilotProfile.bagMaxX)
                let ty: Double = drops ? PilotProfile.dropY : PilotProfile.bagY
                let d = Drag(touchID: nextTouchID, itemID: best.item.id, x: bx, y: by, tx: tx, ty: ty, speed: v)
                nextTouchID += 1
                drag = d
                touches.append(touch(.began, d))
            }
        }

        return PilotOutput(lid: lidOutput, touches: touches)
    }
}

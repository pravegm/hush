import CoreGraphics
import Foundation

// MARK: - Lid sensitivity (R7, ROUND-7 Core item 3)

/// Settings › Lid sensitivity: a whole-session noise scale for a stiff, jerky or unknown hinge (forgiving 0.75,
/// normal 1, careful 1.2). The scored Daily always plays `.normal` (`effective(_:for:)`), so everyone's counted try
/// is the same game. The App stores the choice and passes it to `SessionOptions.for(_:sensitivity:)`.
enum LidSensitivity: String, Codable, CaseIterable, Sendable {
    case forgiving, normal, careful

    /// Multiplies every noise source (the lid, drags and the one-off sounds).
    var noiseScale: Double {
        switch self {
        case .forgiving: return Tuning.forgivingNoiseScale
        case .normal: return Tuning.normalNoiseScale
        case .careful: return Tuning.carefulNoiseScale
        }
    }

    /// The sensitivity `mode` actually plays at: `.normal` for the scored Daily, else `chosen`.
    static func effective(_ chosen: LidSensitivity, for mode: RunMode) -> LidSensitivity {
        if case .daily(_, let scored) = mode, scored { return .normal }
        return chosen
    }
}

// MARK: - Session options per mode

struct SessionOptions: Equatable {
    /// false: the torch never burns down (attract, lesson).
    var torch: Bool = true
    /// false: noise caps at Tuning.noBiteCap (attract, lesson).
    var bites: Bool = true
    /// Scales every noise source (the lesson uses Tuning.lessonNoiseScale, 0.6). R7: the sensitivity's scale is
    /// already folded in (`init` multiplies the two).
    var noiseScale: Double = 1
    /// The lesson's scripted chest (repeats after each bank).
    var fixedChest: ChestSpec? = nil
    /// R7: the lid sensitivity this session plays at (its scale is in `noiseScale`).
    private(set) var sensitivity: LidSensitivity = .normal

    init(torch: Bool = true, bites: Bool = true, noiseScale: Double = 1, fixedChest: ChestSpec? = nil,
         sensitivity: LidSensitivity = .normal) {
        self.torch = torch
        self.bites = bites
        self.noiseScale = noiseScale * sensitivity.noiseScale
        self.fixedChest = fixedChest
        self.sensitivity = sensitivity
    }

    /// The options for `mode`. R7: `sensitivity` (the player's Settings choice) applies to runs and the unscored
    /// Daily; the scored Daily is forced to `.normal` (`LidSensitivity.effective`); attract and the lesson ignore it.
    static func `for`(_ mode: RunMode, sensitivity: LidSensitivity = .normal) -> SessionOptions {
        switch mode {
        case .run, .daily:
            return SessionOptions(sensitivity: LidSensitivity.effective(sensitivity, for: mode))
        case .attract:
            return SessionOptions(torch: false, bites: false)
        case .lesson:
            return SessionOptions(torch: false, bites: false, noiseScale: Tuning.lessonNoiseScale,
                                  fixedChest: ChestFactory.lessonChest())
        }
    }
}

// MARK: - One run (GAME-DESIGN §4–§6, ARCHITECTURE "HeistSession behaviour", ROUND-2 Core)
//
// Deterministic: the same seed, inputs and touch calls give the same run. `step` sub-steps at ≤ Tuning.maxSubstep.
// Phases: ready → looting → banked | bitten → (next chest) ready …; the torch going out → torchOut → finished.
// - Noise can only bite in .looting; elsewhere it caps at Tuning.noBiteCap.
// - The touch calls come between steps. Their one-off noise applies at once (and can bite at once); the drag speed
//   they measure feeds the noise rate from the next step on.
// - Light is 0 in .ready (the chest is closed).
// - R12 (design/ROUND-12.md, "the lid IS the chest"; the lesson keeps the old shut-first gate, `shutGate`):
//   - rules 1–2: there is no hidden gate. A chest is `.ready` only while its lid is closed: it becomes `.looting` as
//     soon as the openness passes Tuning.lootingStartOpenness and the lid isn't still coming down onto it. So a run
//     started with the lid up is looting on its first step.
//   - A `.ready` chest is closed, so the lid makes no noise there (and `.slower` doesn't show). Drags can't happen.
//   - rule 4: the next chest arrives only under a closed lid. When the bite moment ends with the lid out of
//     the shut zone, the robbed chest stays, open and empty (`awaitingClose`, `.ready`, no loot, the mimic back
//     to Asleep, noise 0), with the hint `.closeForNext`; the candle burns on. The next chest is dealt
//     (`chestArrived`) the step the lid enters the shut zone (or on `noteLidShut()`), already "seen shut".
//     After a BANK (founder refinement) the next chest is always dealt at the end of the 1.4 s moment, "seen shut",
//     whatever the lid is doing: the lid was closed to bank, so a quick reopen simply opens it (never `.closeForNext`).
//   - `.easeLidDown` is only produced by the lesson.
// - R14 (design/ROUND-14.md, founder: "playing starts with the chest closed right? so ask the user to close the phone
//   if it is not to start playing, then the chest should open as the phone opens"): EVERY chest starts closed. The
//   first one waits for the lid to be seen shut (`sawShut`; the hint `.easeLidDown`, "Close the phone to start", while
//   it is open), and the candle doesn't burn until it is opened. Every later chest is dealt under a closed lid (after
//   a bank, or after a bite once the lid comes down). `noteLidShut()` counts as seen shut. No mode is special
//   (R1–R12's lesson-only `shutGate` is gone).
// - R2: the lid is "closing" in a step when its openness fell since the previous step; it is then silent below
//   Tuning.closeQuietSpeed instead of Tuning.quietSpeed.
// - R2 Hush Chain: a Hushed bank adds 1 and pays ×Noise.chainMultiplier(chain). The chain breaks (to 0) the moment the
//   mimic leaves Asleep in a chest (a stir, or a bite straight from Asleep): that chest can no longer be Hushed.
// - R2 bag jingle: while loot is in the bag, decay stops at Noise.jingleFloor (it never pushes noise up).
// - R3 pause (ROUND-3 decision 2): a pause is simply no stepping, so the noise, the stage, the candle and the clock
//   all stay frozen. `resumeGrace(seconds:)` on resume (slow lid noise ignored; a sustained loud lid ends it, QA-2
//   P2-9). `rest(dt:)` (decay only) stays in the API but the App no longer calls it for pauses.
// - R7 loud onset (ROUND-7 Core item 1): lid noise only counts once the lid has been above its quiet line for
//   Tuning.loudOnsetSeconds (Noise.onsetShare), so a stick-slip blip is free: it adds nothing and doesn't stop the decay.
// - R7 fresh chest (item 2): `isFreshChest` (.ready, openness never past Tuning.freshChestOpenness, empty bag) lets the
//   App resume an untouched chest without the stillness wait. R12: outside the lesson, any `.ready` chest except the
//   one awaiting the close (a `.ready` chest is closed and silent).
// Mirrored by HeistSession in tools/balance-sim.js (minus hints, rest/resumeGrace and cosmetic snapshot fields).

final class HeistSession {

    let mode: RunMode
    let seed: UInt64
    let options: SessionOptions
    let bestRun: Int

    private struct TouchTrack {
        var id: Int
        var lootIndex: Int
        var lastPoint: CGPoint
        var lastTime: Double
        /// Smoothed drag speed (pt/s).
        var speed: Double
        /// Session seconds since the last touch move.
        var stillFor: Double
    }

    private var phase: RunPhase = .ready
    private var time: Double = 0
    private var chestIndex: Int = 0
    private var chest: ChestSpec
    private var loot: [LootState]
    private var found: Set<RelicID>
    private var lid: LidInput = LidInput()
    /// The lid's openness fell since the previous step (R2 closeQuietSpeed).
    private var closing: Bool = false
    /// Seconds of lid noise still ignored after a resume (`resumeGrace`).
    private var lidGrace: Double = 0
    /// R3 (QA-2 P2-9): seconds of this grace spent with the lid above `Tuning.loudSpeed`.
    private var graceLoudFor: Double = 0
    /// R7: seconds the lid has been above its quiet line without a break (the loud onset).
    private var loudFor: Double = 0
    /// R7: the widest openness played in this chest (`isFreshChest`).
    private var peakOpenness: Double = 0

    private var noise: Double = 0
    private var stage: MimicStage = .asleep
    private var quietFor: Double = 0
    /// Seconds of .looting in this chest (restlessness).
    private var chestTime: Double = 0

    private var torch: Double = Tuning.torchSeconds
    private var torchTotal: Double = Tuning.torchSeconds
    private var torchLowSent: Bool = false
    private var newBestSent: Bool = false

    private var banked: Int = 0
    private var chestsBanked: Int = 0
    private var hushed: Int = 0
    private var bites: Int = 0
    private var chestsOpened: Int = 0
    private var lostToBites: Int = 0
    private var itemsBagged: Int = 0
    private var relicsBanked: [RelicID] = []
    private var bestChestValue: Int = 0
    private var highestTier: ChestTier
    private var chain: Int = 0
    private var bestChain: Int = 0
    private var goldenBanked: Int = 0
    private var chestLog: [ChestOutcome] = []

    /// Held fingers (at most a few; an array so the per-step loops never allocate).
    private var touches: [TouchTrack] = []
    private var pending: [HeistEvent] = []

    /// R14: the lid has been seen shut over the current chest (false only for a run's first chest, until it is).
    private var sawShut: Bool = false
    /// R12 rule 4 (ROUND-12 Core): the bite moment ended with the lid open, so the robbed chest waits,
    /// open and empty (`.ready`, no loot, `hint == .closeForNext`), until the lid enters the shut zone; then the next
    /// chest is dealt. Never true in the lesson.
    private(set) var awaitingClose: Bool = false
    private var cracked: Bool = false
    private var shutHold: Double = 0
    private var bagCount: Int = 0
    private var bagValue: Int = 0
    private var leftAsleep: Bool = false
    private var revealed: Set<Int> = []
    private var twitchRng: SeededRandom
    private var twitchIn: Double

    private(set) var result: RunResult? = nil

    init(mode: RunMode, seed: UInt64, bestRun: Int, foundRelics: Set<RelicID>, options: SessionOptions) {
        self.mode = mode
        self.seed = seed
        self.bestRun = bestRun
        self.options = options
        self.found = foundRelics
        // R14: play starts with the chest closed: the first chest waits for the lid to be seen shut.
        self.sawShut = false
        let first: ChestSpec = HeistSession.makeChest(seed: seed, index: 0, found: foundRelics, options: options)
        self.chest = first
        self.loot = HeistSession.lootStates(for: first)
        self.highestTier = first.tier
        var tr = SeededRandom(seed: HeistSession.twitchSeed(seed: seed, index: 0))
        self.twitchIn = tr.range(Tuning.dreamTwitchMin...Tuning.dreamTwitchMax)
        self.twitchRng = tr
        touches.reserveCapacity(4)
        pending.append(.chestArrived(index: first.index, tier: first.tier, mimic: first.mimic, name: first.mimicName))
    }

    // MARK: Public state

    var isFinished: Bool {
        if case .finished = phase { return true }
        return false
    }

    /// R7 (ROUND-7 Core item 2): the chest is `.ready` and untouched: its openness has never passed
    /// `Tuning.freshChestOpenness` (0.05) and nothing is in the bag. Nothing is lit or revealed and the lid is silent
    /// below the speedometer, so reopening it is no resume hazard: the App skips the stillness wait for it.
    /// R12: outside the lesson a `.ready` chest is always closed and has never been heard (the lid is silent there), so
    /// any `.ready` chest is fresh, except the one awaiting the close (it has been played). The lesson keeps R7's rule.
    /// R13 (App/Core review): the chest opens from ~3° of the phone now, so a hand settling a closing phone at 3–12°
    /// (before the closing pause's dwell) starts it looting. Opened no further than `freshChestOpenness` with nothing
    /// revealed or bagged, it is still untouched and still fresh.
    var isFreshChest: Bool {
        guard !awaitingClose, bagCount == 0 else { return false }
        if phase == .looting {
            return revealed.isEmpty && touches.isEmpty && peakOpenness <= Tuning.freshChestOpenness
        }
        // R14: a `.ready` chest is closed and untouched (the lid is silent there).
        return phase == .ready
    }

    /// Fastest held-item drag speed right now (pt/s), for telemetry.
    var dragSpeed: Double {
        var best: Double = 0
        for t in touches where t.speed > best { best = t.speed }
        return best
    }

    var snapshot: HeistSnapshot {
        return HeistSnapshot(phase: phase, mode: mode, time: time, chest: chest, loot: loot,
                             openness: lid.openness, lidSpeed: lid.speed, noise: noise, stage: stage,
                             torchRemaining: torch, torchTotal: torchTotal, bagValue: bagValue, banked: banked,
                             bestRun: bestRun, chestsBanked: chestsBanked, hushed: hushed, bites: bites,
                             shutHold: shutHold, hint: currentHint(), chain: chain,
                             chainMultiplier: nextChainMultiplier, noiseFloor: isPlaying ? noiseFloor : 0)
    }

    /// The result so far (QA-1 P1-3: for an abandoned run). Once finished, exactly `result`. Otherwise the counters
    /// now; a chest being looted counts as opened and goes in `chestLog` with value 0 (its bag was never banked).
    func partialResult() -> RunResult {
        if let r = result { return r }
        var log: [ChestOutcome] = chestLog
        if isLooting {
            log.append(ChestOutcome(tier: chest.tier, golden: chest.golden, value: 0, hushed: false, bitten: false))
        }
        return makeResult(chestLog: log)
    }

    // MARK: Stepping

    /// One frame. Returns this step's events in order.
    func step(dt: Double, lid input: LidInput) -> [HeistEvent] {
        if isFinished { return [] }
        var ev: [HeistEvent] = pending
        pending = []
        let d: Double = dt.isFinite ? max(0, dt) : 0
        var l: LidInput = input
        l.openness = l.openness.isFinite ? min(max(l.openness, 0), 1) : 0
        l.speed = l.speed.isFinite ? max(0, l.speed) : 0
        closing = l.openness < lid.openness - 1e-9
        lid = l
        let n: Int = max(1, Int((d / Tuning.maxSubstep - 1e-9).rounded(.up)))
        let h: Double = d / Double(n)
        var i: Int = 0
        while i < n {
            tick(h, &ev)
            if isFinished { break }
            i += 1
        }
        return ev
    }

    /// Lets the mimic settle without play time passing: noise decays (to the bag jingle floor, after the usual grace)
    /// and nothing else happens: no candle, no bites, no moments, no light; the lid reads still (`lidSpeed` 0). The
    /// only events are `stageChanged` (the mimic settling). Only in .ready / .looting.
    ///
    /// R3 (ROUND-3 decision 2): **not for pauses.** Noise is frozen while paused: the App simply stops calling `step`
    /// (and doesn't call this), so closing the lid is no free way to calm the mimic (REVIEW-2-duo P2-5). Kept for
    /// tools and tests, and for a future "the mimic dozes off" rule.
    @discardableResult
    func rest(dt: Double) -> [HeistEvent] {
        guard isPlaying else { return [] }
        let d: Double = dt.isFinite ? max(0, dt) : 0
        lid.speed = 0
        loudFor = 0
        guard d > 0 else { return [] }
        var ev: [HeistEvent] = []
        let n: Int = max(1, Int((d / Tuning.maxSubstep - 1e-9).rounded(.up)))
        let h: Double = d / Double(n)
        var i: Int = 0
        while i < n {
            settleTouches(h)
            quietFor += h
            if quietFor >= Tuning.decayGrace { decayNoise(h) }
            settleNoise(&ev, allowBite: false)
            i += 1
        }
        return ev
    }

    /// R2: on resume, lid motion makes no noise for `seconds` of play (the lift back into play is free; REVIEW-1-duo
    /// P0-2). Drags and one-off sounds still count. A longer pending grace is kept.
    /// R3 (QA-2 P2-9): once the lid has spent more than `Tuning.resumeGraceLoudLimit` of the grace above
    /// `Tuning.loudSpeed`, the grace ends and the lid counts again, so a pause can't buy a silent fling. A short
    /// filter blip is still forgiven.
    func resumeGrace(seconds: Double) {
        let s: Double = seconds.isFinite ? max(0, seconds) : 0
        if lidGrace <= 0 { graceLoudFor = 0 }
        lidGrace = max(lidGrace, s)
    }

    /// R12 rule 4: the App saw the lid shut without a step in the shut zone (e.g. a fast fold straight into the closing
    /// pause). If the chest is awaiting the close, the next chest is dealt now; its `chestArrived` comes with the next
    /// step. Otherwise nothing.
    /// R12b (CI BANK-CLOSE-FULL): with loot in the bag (`canBankOnShut`), a lid seen shut banks it: the cover display
    /// can take over before the shut-zone hold finishes (the Duo simulator does at ~120°), and the closing pause stops
    /// stepping. "The chest closed means the lid closed", so the bag is banked and the next chest dealt at once (the
    /// lid is shut; nobody sees the bank moment). Those events are returned for the App to deliver now, so the
    /// ka-ching plays as the lid shuts; the robbed chest's `chestArrived` still comes with the next step.
    @discardableResult
    func noteLidShut() -> [HeistEvent] {
        guard !isFinished else { return [] }
        // R14: the first chest's close (the cover display took over, or the closing pause): it now opens with the phone.
        if phase == .ready && !sawShut { sawShut = true }
        var ev: [HeistEvent] = []
        if awaitingClose {
            nextChest(&ev)
            pending.append(contentsOf: ev)
            return []
        }
        // R14 (UX audit change D): closing the phone always ends the chest. Opened and closed with nothing in the
        // bag, it goes in the log with nothing banked and the next chest is dealt, closed (never "carry on").
        if endsEmptyOnShut {
            touches.removeAll(keepingCapacity: true)
            chestLog.append(ChestOutcome(tier: chest.tier, golden: chest.golden, value: 0, hushed: false,
                                         bitten: false))
            nextChest(&ev)
            pending.append(contentsOf: ev)
            return []
        }
        guard canBankOnShut else { return [] }
        bank(&ev)
        nextChest(&ev)
        return ev
    }

    /// R12b: a chest being looted with loot in the bag: `noteLidShut()` would bank it. (R13: the lesson too; its
    /// script hears the `.banked` through the App's `deliver`.)
    var canBankOnShut: Bool { !isFinished && isLooting && bagCount > 0 }

    /// R14: the run's first chest still waits for the phone to be seen shut ("Close the phone to start").
    var awaitsFirstShut: Bool { !isFinished && phase == .ready && !sawShut }

    /// R14 (UX audit D): a chest opened past the shut zone (so it was really opened, not a hand settling the phone)
    /// with an empty bag: `noteLidShut()` ends it and deals the next. Never in the lesson (its script is one chest).
    var endsEmptyOnShut: Bool {
        !isFinished && mode != .lesson && isLooting && bagCount == 0 && peakOpenness > Tuning.emptyShutOpenness
    }

    private func tick(_ h: Double, _ ev: inout [HeistEvent]) {
        time += h
        switch phase {
        case .banked(let e):
            let ne: Double = e + h
            // R12 (founder): the lid was closed to bank, so the next chest is always dealt "seen shut", whatever the
            // lid does in the moment; reopened quickly, it simply opens.
            if ne >= Tuning.bankMomentSeconds { nextChest(&ev) } else { phase = .banked(elapsed: ne) }
        case .bitten(let e):
            let ne: Double = e + h
            if ne >= Tuning.biteMomentSeconds {
                if options.torch && torch <= 0 { startTorchOut(&ev) } else { dealOrAwaitClose(&ev) }
            } else {
                phase = .bitten(elapsed: ne)
            }
        case .torchOut(let e):
            let ne: Double = e + h
            if ne >= Tuning.torchOutSeconds { finish(&ev) } else { phase = .torchOut(elapsed: ne) }
        case .finished:
            return
        case .ready, .looting:
            play(h, &ev)
        }
    }

    private var isLooting: Bool { return phase == .looting }
    private var isPlaying: Bool { return phase == .ready || phase == .looting }

    private func play(_ h: Double, _ ev: inout [HeistEvent]) {
        // R12 rule 4: the robbed chest waits, open and empty, until the lid comes down; the candle burns on.
        if awaitingClose {
            if lid.inShutZone {
                nextChest(&ev)
            } else {
                _ = burnTorch(h, &ev)
            }
            return
        }
        let o: Double = lid.openness
        peakOpenness = max(peakOpenness, o)
        if phase == .ready {
            if lid.inShutZone { sawShut = true }
            // R12 rules 1–2: the chest opens with the phone; outside the lesson, not while the lid is still coming down
            // onto a chest just dealt in the shut zone (that lid is closing it, not opening it).
            if sawShut && o > Tuning.lootingStartOpenness && !closing {
                phase = .looting
                chestsOpened += 1
                chestTime = 0
            }
        }
        if isLooting {
            chestTime += h
            if !cracked && o > Tuning.lidCrackedOpenness {
                cracked = true
                ev.append(.lidCracked)
            }
        }
        updateLight(&ev)
        settleTouches(h)

        // Noise. R7: the lid's loud onset (a blip shorter than Tuning.loudOnsetSeconds is free).
        let loudBefore: Double = loudFor
        if lid.speed > Noise.quietSpeed(closing: closing) { loudFor += h } else { loudFor = 0 }
        let lidShare: Double = Noise.onsetShare(loudBefore: loudBefore, loudAfter: loudFor, step: h)
        var raw: Double = 0
        var lidHeard: Bool = lidGrace <= 0
        if !lidHeard {
            if lid.speed > Tuning.loudSpeed { graceLoudFor += h }
            if graceLoudFor > Tuning.resumeGraceLoudLimit + 1e-9 {
                lidGrace = 0
                lidHeard = true
            } else {
                lidGrace = max(0, lidGrace - h)
            }
        }
        // R12: a closed (`.ready`) chest doesn't hear the lid, except in the lesson (R1–R11: easing down is heard).
        if lidHeard && lidCounts { raw = Noise.lidRate(speed: lid.speed, closing: closing) * lidShare }
        for t in touches { raw += Noise.dragRate(speed: t.speed) }
        let rate: Double = raw * noiseMultiplier
        noise += rate * h
        if rate > Tuning.quietRateThreshold { quietFor = 0 } else { quietFor += h }
        if quietFor >= Tuning.decayGrace { decayNoise(h) }
        settleNoise(&ev, allowBite: true)
        if !isPlaying { return }

        // Bank: hold the lid in the shut zone with loot in the bag.
        if isLooting && bagCount > 0 && lid.inShutZone {
            shutHold = min(1, shutHold + h / Tuning.shutHoldSeconds)
            if shutHold >= 1 {
                bank(&ev)
                return
            }
        } else {
            shutHold = 0
        }

        // Torch. R14: not while the run's first chest still waits to be opened ("Your candle waits").
        if !(phase == .ready && chestsOpened == 0) && burnTorch(h, &ev) { return }

        // The Dreamer's harmless fake twitches.
        if chest.mimic == .dreamer {
            twitchIn -= h
            if twitchIn <= 0 {
                ev.append(.dreamTwitch)
                twitchIn = twitchRng.range(Tuning.dreamTwitchMin...Tuning.dreamTwitchMax)
            }
        }
    }

    /// The candle burns `h` s (when the mode has one): `torchLow` once, and the torch going out. True if it went out.
    private func burnTorch(_ h: Double, _ ev: inout [HeistEvent]) -> Bool {
        guard options.torch else { return false }
        torch -= h
        if !torchLowSent && torch <= Tuning.torchLowSeconds {
            torchLowSent = true
            ev.append(.torchLow)
        }
        if torch <= 0 {
            torch = 0
            startTorchOut(&ev)
            return true
        }
        return false
    }

    /// R12: the lid makes noise in `.looting` only (R14: in every mode).
    private var lidCounts: Bool { return isLooting }

    /// A held item that gets no touch moves is still: its speed decays.
    private func settleTouches(_ h: Double) {
        var k: Int = 0
        while k < touches.count {
            touches[k].stillFor += h
            if touches[k].stillFor > Tuning.dragStillAfter { touches[k].speed *= exp(-h / Tuning.dragStillDecay) }
            k += 1
        }
    }

    private func updateLight(_ ev: inout [HeistEvent]) {
        let looting: Bool = isLooting
        let o: Double = lid.openness
        for k in loot.indices {
            switch loot[k].place {
            case .inChest:
                let light: Double = looting ? min(max((o - loot[k].item.depth) / Tuning.lightRamp, 0), 1) : 0
                loot[k].light = light
                loot[k].grabbable = looting && light >= Tuning.grabLight
                let id: Int = loot[k].item.id
                if light >= Tuning.revealLight && !revealed.contains(id) {
                    revealed.insert(id)
                    ev.append(.itemRevealed(id: id, kind: loot[k].item.kind))
                }
            case .held, .inBag:
                loot[k].light = 1
                loot[k].grabbable = false
            case .lost:
                loot[k].grabbable = false
            }
        }
    }

    // MARK: Noise

    /// Personality × golden × the mode's noise scale; applies to every source.
    private var noiseMultiplier: Double {
        return Noise.multiplier(for: chest.mimic) * (chest.golden ? Tuning.goldenNoiseMultiplier : 1)
            * options.noiseScale
    }

    /// R2 bag jingle: decay stops here while loot is in the bag.
    private var noiseFloor: Double {
        return Noise.jingleFloor(items: bagCount, multiplier: noiseMultiplier)
    }

    /// What the next bank pays for the Hush Chain: ×1 once this chest has stirred, else the extended chain's rate.
    private var nextChainMultiplier: Double {
        if isPlaying && leftAsleep && !awaitingClose { return 1 }
        return Noise.chainMultiplier(chain + 1)
    }

    private var canBite: Bool { return options.bites && isLooting }

    /// Quiet decay for `h` s (restlessness applies), never below the bag jingle floor (it never raises the noise).
    private func decayNoise(_ h: Double) {
        let restless: Double = max(Tuning.restlessFloor, 1 - Tuning.restlessPerSecond * chestTime)
        let floor: Double = noiseFloor
        let before: Double = noise
        noise -= chest.decay * restless * h
        if noise < floor { noise = min(before, floor) }
    }

    /// Clamp, bite if due (and allowed), else move the stage (with hysteresis).
    private func settleNoise(_ ev: inout [HeistEvent], allowBite: Bool) {
        let bite: Bool = allowBite && canBite
        let cap: Double = bite ? 1 : Tuning.noBiteCap
        noise = noise.isFinite ? min(max(noise, 0), cap) : 0
        if bite && noise >= Tuning.biteNoise {
            biteNow(&ev)
            return
        }
        let ns: MimicStage = Noise.stage(for: noise, previous: stage)
        if ns != stage {
            ev.append(.stageChanged(from: stage, to: ns))
            stage = ns
            if ns > .asleep { markStirred(&ev) }
        }
    }

    /// The mimic has left Asleep in this chest: it can't be Hushed, so the Hush Chain breaks now.
    private func markStirred(_ ev: inout [HeistEvent]) {
        if leftAsleep { return }
        leftAsleep = true
        breakChain(&ev)
    }

    private func breakChain(_ ev: inout [HeistEvent]) {
        if chain >= 2 { ev.append(.chainBroken(count: chain)) }
        chain = 0
    }

    private func addOneOff(_ amount: Double, _ ev: inout [HeistEvent]) {
        noise += amount * noiseMultiplier
        quietFor = 0
        settleNoise(&ev, allowBite: true)
    }

    /// Adds noise directly (the lesson's scripted stir): sets the level; stage events come with the next step.
    func nudgeNoise(to level: Double) {
        noise = level.isFinite ? level : 0
        quietFor = 0
        var ev: [HeistEvent] = []
        settleNoise(&ev, allowBite: true)
        pending.append(contentsOf: ev)
    }

    // MARK: Moments

    private func scaled(_ value: Int) -> Int {
        return Int((Double(value) * chest.multiplier).rounded())
    }

    private func inHandValue() -> Int {
        var v: Int = bagValue
        for s in loot {
            if case .held = s.place { v += scaled(s.item.value) }
        }
        return v
    }

    /// Bag and held loot → lost.
    private func loseInHand() {
        for k in loot.indices {
            switch loot[k].place {
            case .held, .inBag: loot[k].place = .lost
            case .inChest, .lost: break
            }
        }
        touches.removeAll(keepingCapacity: true)
        bagValue = 0
        bagCount = 0
    }

    private func biteNow(_ ev: inout [HeistEvent]) {
        let lost: Int = inHandValue()
        let torchBefore: Double = torch
        loseInHand()
        ev.append(.stageChanged(from: stage, to: .biting))
        stage = .biting
        ev.append(.bitten(lostValue: lost))
        bites += 1
        lostToBites += lost
        if options.torch { torch = max(0, torch - Tuning.biteTorchPenalty) }
        ev.append(.biteCost(lostValue: lost, seconds: torchBefore - torch))
        chestLog.append(ChestOutcome(tier: chest.tier, golden: chest.golden, value: 0, hushed: false, bitten: true))
        leftAsleep = true
        breakChain(&ev)
        phase = .bitten(elapsed: 0)
        shutHold = 0
        noise = 1
    }

    private func bank(_ ev: inout [HeistEvent]) {
        let items: Int = bagCount
        let hushedNow: Bool = !leftAsleep
        if hushedNow { chain += 1 } else { chain = 0 }
        bestChain = max(bestChain, chain)
        let chainMult: Double = hushedNow ? Noise.chainMultiplier(chain) : 1
        let value: Int = hushedNow ? Int((Double(bagValue) * chainMult).rounded()) : bagValue
        banked += value
        chestsBanked += 1
        if hushedNow { hushed += 1 }
        if chest.golden { goldenBanked += 1 }
        bestChestValue = max(bestChestValue, value)
        chestLog.append(ChestOutcome(tier: chest.tier, golden: chest.golden, value: value, hushed: hushedNow,
                                     bitten: false))
        var relicsHere: [RelicID] = []
        for k in loot.indices {
            switch loot[k].place {
            case .inBag:
                if case .relic(let rid) = loot[k].item.kind {
                    relicsHere.append(rid)
                    relicsBanked.append(rid)
                    found.insert(rid)
                }
            case .held:
                // Still in a finger when the lid shut: it stays behind in the chest.
                loot[k].place = .inChest
            case .inChest, .lost:
                break
            }
        }
        touches.removeAll(keepingCapacity: true)
        ev.append(.banked(value: value, items: items, hushed: hushedNow))
        if hushedNow { ev.append(.chainUp(count: chain, multiplier: chainMult)) }
        for rid in relicsHere { ev.append(.relicFound(rid)) }
        if !newBestSent && bestRun > 0 && banked > bestRun {
            newBestSent = true
            ev.append(.newBest)
        }
        bagValue = 0
        phase = .banked(elapsed: 0)
        shutHold = 1
    }

    /// After the bite moment. R12 rule 4: the next chest arrives only under a closed lid, so with the lid out of the
    /// shut zone the robbed chest waits for the close (the lesson deals at once, as in R1–R11). A bank always deals at
    /// once (the lid was closed to bank).
    private func dealOrAwaitClose(_ ev: inout [HeistEvent]) {
        if lid.inShutZone {
            nextChest(&ev)
        } else {
            awaitClose(&ev)
        }
    }

    /// R12 rule 4: the robbed chest stays, open and empty: no loot, nothing held or bagged, the mimic back to
    /// Asleep (noise 0). `currentHint()` says `.closeForNext`; `play` deals the next chest once the lid is shut.
    private func awaitClose(_ ev: inout [HeistEvent]) {
        awaitingClose = true
        phase = .ready
        if stage != .asleep {
            ev.append(.stageChanged(from: stage, to: .asleep))
            stage = .asleep
        }
        loot = []
        touches.removeAll(keepingCapacity: true)
        bagCount = 0
        bagValue = 0
        shutHold = 0
        noise = 0
        quietFor = 0
        loudFor = 0
    }

    private func nextChest(_ ev: inout [HeistEvent]) {
        awaitingClose = false
        chestIndex += 1
        if stage != .asleep {
            ev.append(.stageChanged(from: stage, to: .asleep))
            stage = .asleep
        }
        let spec: ChestSpec = HeistSession.makeChest(seed: seed, index: chestIndex, found: found, options: options)
        chest = spec
        loot = HeistSession.lootStates(for: spec)
        if ChestFactory.rank(spec.tier) > ChestFactory.rank(highestTier) { highestTier = spec.tier }
        phase = .ready
        // R12/R14: every later chest arrives "seen shut" (it is dealt under a closed lid).
        sawShut = true
        cracked = false
        chestTime = 0
        shutHold = 0
        bagCount = 0
        bagValue = 0
        leftAsleep = false
        revealed = []
        touches.removeAll(keepingCapacity: true)
        noise = 0
        quietFor = 0
        loudFor = 0
        peakOpenness = lid.openness
        twitchRng = SeededRandom(seed: HeistSession.twitchSeed(seed: seed, index: chestIndex))
        twitchIn = twitchRng.range(Tuning.dreamTwitchMin...Tuning.dreamTwitchMax)
        ev.append(.chestArrived(index: spec.index, tier: spec.tier, mimic: spec.mimic, name: spec.mimicName))
    }

    private func startTorchOut(_ ev: inout [HeistEvent]) {
        // A chest the candle went out on (it was being looted) goes in the log with nothing banked.
        if isLooting {
            chestLog.append(ChestOutcome(tier: chest.tier, golden: chest.golden, value: 0, hushed: false,
                                         bitten: false))
        }
        loseInHand()
        shutHold = 0
        awaitingClose = false
        phase = .torchOut(elapsed: 0)
        ev.append(.torchOut)
    }

    private func finish(_ ev: inout [HeistEvent]) {
        phase = .finished
        result = makeResult(chestLog: chestLog)
        ev.append(.finished)
    }

    private func makeResult(chestLog log: [ChestOutcome]) -> RunResult {
        return RunResult(mode: mode, seed: seed, gold: banked, seconds: time, chestsOpened: chestsOpened,
                         chestsBanked: chestsBanked, hushed: hushed, bites: bites, relics: relicsBanked,
                         bestChestValue: bestChestValue, itemsBagged: itemsBagged, highestTier: highestTier,
                         lostToBites: lostToBites, bestChain: bestChain, goldenBanked: goldenBanked, chestLog: log)
    }

    // MARK: Touches (floor space; between steps)

    private func touchIndex(_ id: Int) -> Int? {
        var k: Int = 0
        while k < touches.count {
            if touches[k].id == id { return k }
            k += 1
        }
        return nil
    }

    func touchBegan(id: Int, at point: CGPoint, time: Double) -> [HeistEvent] {
        guard isLooting, touchIndex(id) == nil else { return [] }
        var best: Int = -1
        var bestD: Double = Double.greatestFiniteMagnitude
        for k in loot.indices {
            let s: LootState = loot[k]
            guard s.place == .inChest, s.grabbable else { continue }
            let d: Double = HeistSession.distance(s.position, point)
            if d <= Double(s.item.radius) + Tuning.grabSlop && d < bestD {
                best = k
                bestD = d
            }
        }
        guard best >= 0 else { return [] }
        var ev: [HeistEvent] = []
        loot[best].place = .held(touchID: id)
        loot[best].position = HeistSession.clampToFloor(point)
        loot[best].light = 1
        loot[best].grabbable = false
        touches.append(TouchTrack(id: id, lootIndex: best, lastPoint: point, lastTime: time, speed: 0, stillFor: 0))
        ev.append(.itemPicked(id: loot[best].item.id, kind: loot[best].item.kind))
        addOneOff(Tuning.pickNoise, &ev)
        return ev
    }

    func touchMoved(id: Int, to point: CGPoint, time: Double) -> [HeistEvent] {
        guard let ti = touchIndex(id) else { return [] }
        var t: TouchTrack = touches[ti]
        let dtt: Double = time - t.lastTime
        if dtt > Tuning.dragMinInterval {
            let inst: Double = HeistSession.distance(point, t.lastPoint) / dtt
            let a: Double = min(1, dtt / Tuning.dragSmoothing)
            t.speed += (inst - t.speed) * a
            if !t.speed.isFinite { t.speed = 0 }
            t.lastPoint = point
            t.lastTime = time
        }
        t.stillFor = 0
        touches[ti] = t
        if t.lootIndex >= 0 && t.lootIndex < loot.count {
            loot[t.lootIndex].position = HeistSession.clampToFloor(point)
        }
        return []
    }

    func touchEnded(id: Int, at point: CGPoint, time: Double) -> [HeistEvent] {
        guard let ti = touchIndex(id) else { return [] }
        let t: TouchTrack = touches.remove(at: ti)
        let k: Int = t.lootIndex
        guard k >= 0, k < loot.count, loot[k].place == .held(touchID: id) else { return [] }
        var ev: [HeistEvent] = []
        if point.y >= FloorSpace.bagMinY {
            bagItem(k, &ev)
        } else {
            dropItem(k, at: point, &ev)
        }
        return ev
    }

    private func bagItem(_ k: Int, _ ev: inout [HeistEvent]) {
        loot[k].place = .inBag
        loot[k].position = HeistSession.bagSlot(bagCount)
        loot[k].light = 1
        loot[k].grabbable = false
        let v: Int = scaled(loot[k].item.value)
        bagCount += 1
        bagValue += v
        itemsBagged += 1
        ev.append(.itemBagged(id: loot[k].item.id, kind: loot[k].item.kind, value: v))
        if loot[k].item.kind == .oil {
            torch += Tuning.oilSeconds
            torchTotal += Tuning.oilSeconds
            ev.append(.oilAdded(seconds: Tuning.oilSeconds))
        }
        addOneOff(Tuning.bagNoise, &ev)
    }

    private func dropItem(_ k: Int, at point: CGPoint, _ ev: inout [HeistEvent]) {
        loot[k].place = .inChest
        loot[k].position = HeistSession.nearestInInterior(point, radius: loot[k].item.radius)
        ev.append(.itemDropped(id: loot[k].item.id))
        addOneOff(Tuning.dropNoise, &ev)
    }

    // MARK: Hints (priority: closeForNext > freeze > slower > candleLow > tooWide > easeLidDown (lesson only)
    //        > shutToBank > dragToBag > relicDeeper > openSlowly)

    private func currentHint() -> HeistHint? {
        guard isPlaying else { return nil }
        // R12 rule 4: the only prompt while the played chest waits for the lid to come down.
        if awaitingClose { return .closeForNext }
        if stage >= .waking { return .freeze }
        // During a resume grace the lid makes no noise, so it isn't "too fast" either; nor at a closed chest (R12).
        if lidGrace <= 0 && lidCounts && lid.speed > Tuning.loudSpeed { return .slower }
        // R14 (UX audit E): a fast drag makes noise too, so it says "Slower…" (bites never feel random).
        if touches.contains(where: { $0.speed > Tuning.dragQuietSpeed }) { return .slower }
        if options.torch && isLooting && bagCount > 0 && torch <= Tuning.torchLowSeconds { return .candleLow }
        // R14: the run's first chest waits for a closed lid: "Close the phone to start" (before "too wide": a flat
        // phone at the start is asked to close, nothing else).
        if phase == .ready && !sawShut && !lid.inShutZone { return .easeLidDown }
        if lid.tooWide { return .tooWide }
        if isLooting && bagCount > 0 { return .shutToBank }
        var anyGrabbable: Bool = false
        var glimmer: Bool = false
        for s in loot where s.place == .inChest {
            if s.grabbable { anyGrabbable = true }
            if case .relic = s.item.kind, HeistSession.relicGlimmers(depth: s.item.depth, openness: lid.openness) {
                glimmer = true
            }
        }
        if isLooting && anyGrabbable { return .dragToBag }
        if isLooting && glimmer { return .relicDeeper }
        if phase == .ready { return .openSlowly }
        if isLooting && revealed.isEmpty && touches.isEmpty { return .openSlowly }
        return nil
    }

    /// R2 relic glimmer: a relic at `depth` (still in the chest) glimmers while the openness is within
    /// Tuning.relicGlimmerRange of its glint line (depth + revealLight·lightRamp) but hasn't reached it. The scene's
    /// twinkle and `HeistHint.relicDeeper` both use this.
    static func relicGlimmers(depth: Double, openness: Double) -> Bool {
        guard depth.isFinite, openness.isFinite else { return false }
        let glintAt: Double = depth + Tuning.revealLight * Tuning.lightRamp
        return openness >= glintAt - Tuning.relicGlimmerRange && openness < glintAt
    }

    // MARK: Geometry helpers

    static func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        let dx: Double = Double(a.x - b.x)
        let dy: Double = Double(a.y - b.y)
        return (dx * dx + dy * dy).squareRoot()
    }

    static func clampToFloor(_ p: CGPoint) -> CGPoint {
        let x: CGFloat = p.x.isFinite ? min(max(p.x, 0), FloorSpace.width) : FloorSpace.width / 2
        let y: CGFloat = p.y.isFinite ? min(max(p.y, 0), FloorSpace.height) : FloorSpace.height / 2
        return CGPoint(x: x, y: y)
    }

    /// The nearest point inside FloorSpace.interior where an item of `radius` lies fully inside.
    static func nearestInInterior(_ p: CGPoint, radius: CGFloat) -> CGPoint {
        let box: CGRect = FloorSpace.interior
        let q: CGPoint = clampToFloor(p)
        let x: CGFloat = min(max(q.x, box.minX + radius), box.maxX - radius)
        let y: CGFloat = min(max(q.y, box.minY + radius), box.maxY - radius)
        return CGPoint(x: x, y: y)
    }

    /// Bag slot `k`: a row along FloorSpace.bagRect (wraps after Tuning.bagSlotsPerRow).
    static func bagSlot(_ k: Int) -> CGPoint {
        let perRow: Int = max(1, Tuning.bagSlotsPerRow)
        let col: Int = max(0, k) % perRow
        let row: Int = max(0, k) / perRow
        let x: CGFloat = Tuning.bagSlotFirstX + CGFloat(col) * Tuning.bagSlotSpacing
        let rawY: CGFloat = FloorSpace.bagMinY + Tuning.bagSlotInset + CGFloat(row) * Tuning.bagSlotRowStep
        let y: CGFloat = min(rawY, FloorSpace.height - 8)
        return CGPoint(x: x, y: y)
    }

    // MARK: Dealing

    static func makeChest(seed: UInt64, index: Int, found: Set<RelicID>, options: SessionOptions) -> ChestSpec {
        if var fixed = options.fixedChest {
            fixed.index = index
            return fixed
        }
        return ChestFactory.chest(seed: seed, index: index, found: found)
    }

    static func lootStates(for spec: ChestSpec) -> [LootState] {
        return spec.items.map { (it: LootItem) -> LootState in
            LootState(item: it, position: it.position, place: .inChest, light: 0, grabbable: false)
        }
    }

    static func twitchSeed(seed: UInt64, index: Int) -> UInt64 {
        return ChestFactory.chestSeed(seed: seed, index: index) ^ 0x7417C4
    }
}

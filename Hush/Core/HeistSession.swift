import CoreGraphics
import Foundation

// MARK: - Session options per mode

struct SessionOptions: Equatable {
    /// false: the torch never burns down (attract, lesson).
    var torch: Bool = true
    /// false: noise caps at Tuning.noBiteCap (attract, lesson).
    var bites: Bool = true
    /// Scales every noise source (the lesson uses Tuning.lessonNoiseScale, 0.6).
    var noiseScale: Double = 1
    /// The lesson's scripted chest (repeats after each bank).
    var fixedChest: ChestSpec? = nil

    init(torch: Bool = true, bites: Bool = true, noiseScale: Double = 1, fixedChest: ChestSpec? = nil) {
        self.torch = torch
        self.bites = bites
        self.noiseScale = noiseScale
        self.fixedChest = fixedChest
    }

    static func `for`(_ mode: RunMode) -> SessionOptions {
        switch mode {
        case .run, .daily:
            return SessionOptions()
        case .attract:
            return SessionOptions(torch: false, bites: false)
        case .lesson:
            return SessionOptions(torch: false, bites: false, noiseScale: Tuning.lessonNoiseScale,
                                  fixedChest: ChestFactory.lessonChest())
        }
    }
}

// MARK: - One run (GAME-DESIGN §4–§6, ARCHITECTURE "HeistSession behaviour")
//
// Deterministic: the same seed, inputs and touch calls give the same run. `step` sub-steps at ≤ Tuning.maxSubstep.
// Phases: ready → looting → banked | bitten → (next chest) ready …; the torch going out → torchOut → finished.
// - Noise integrates in .ready and .looting (the mimic hears the lid being eased down too), but it can only bite in
//   .looting; elsewhere it caps at Tuning.noBiteCap.
// - The touch calls come between steps. Their one-off noise applies at once (and can bite at once); the drag speed
//   they measure feeds the noise rate from the next step on.
// - Light is 0 in .ready (the chest waits until the lid has been eased into the shut zone).
// Mirrored by HeistSession in tools/balance-sim.js (minus hints and cosmetic snapshot fields).

final class HeistSession {

    let mode: RunMode
    let seed: UInt64
    let options: SessionOptions
    let bestRun: Int

    private struct TouchTrack {
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

    private var touches: [Int: TouchTrack] = [:]
    private var pending: [HeistEvent] = []

    private var sawShut: Bool = false
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
        let first: ChestSpec = HeistSession.makeChest(seed: seed, index: 0, found: foundRelics, options: options)
        self.chest = first
        self.loot = HeistSession.lootStates(for: first)
        self.highestTier = first.tier
        var tr = SeededRandom(seed: HeistSession.twitchSeed(seed: seed, index: 0))
        self.twitchIn = tr.range(Tuning.dreamTwitchMin...Tuning.dreamTwitchMax)
        self.twitchRng = tr
        pending.append(.chestArrived(index: first.index, tier: first.tier, mimic: first.mimic, name: first.mimicName))
    }

    // MARK: Public state

    var isFinished: Bool {
        if case .finished = phase { return true }
        return false
    }

    /// Fastest held-item drag speed right now (pt/s), for telemetry.
    var dragSpeed: Double {
        var best: Double = 0
        for t in touches.values where t.speed > best { best = t.speed }
        return best
    }

    var snapshot: HeistSnapshot {
        return HeistSnapshot(phase: phase, mode: mode, time: time, chest: chest, loot: loot,
                             openness: lid.openness, lidSpeed: lid.speed, noise: noise, stage: stage,
                             torchRemaining: torch, torchTotal: torchTotal, bagValue: bagValue, banked: banked,
                             bestRun: bestRun, chestsBanked: chestsBanked, hushed: hushed, bites: bites,
                             shutHold: shutHold, hint: currentHint())
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

    private func tick(_ h: Double, _ ev: inout [HeistEvent]) {
        time += h
        switch phase {
        case .banked(let e):
            let ne: Double = e + h
            if ne >= Tuning.bankMomentSeconds { nextChest(&ev) } else { phase = .banked(elapsed: ne) }
        case .bitten(let e):
            let ne: Double = e + h
            if ne >= Tuning.biteMomentSeconds {
                if options.torch && torch <= 0 { startTorchOut(&ev) } else { nextChest(&ev) }
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
        let o: Double = lid.openness
        if phase == .ready {
            if lid.inShutZone { sawShut = true }
            if sawShut && o > Tuning.lootingStartOpenness {
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

        // A held item that gets no touch moves is still: its speed decays.
        for key in Array(touches.keys) {
            guard var t = touches[key] else { continue }
            t.stillFor += h
            if t.stillFor > Tuning.dragStillAfter { t.speed *= exp(-h / Tuning.dragStillDecay) }
            touches[key] = t
        }

        // Noise.
        var raw: Double = Noise.lidRate(speed: lid.speed)
        for t in touches.values { raw += Noise.dragRate(speed: t.speed) }
        let rate: Double = raw * noiseMultiplier
        noise += rate * h
        if rate > Tuning.quietRateThreshold { quietFor = 0 } else { quietFor += h }
        if quietFor >= Tuning.decayGrace {
            let restless: Double = max(Tuning.restlessFloor, 1 - Tuning.restlessPerSecond * chestTime)
            noise -= chest.decay * restless * h
        }
        settleNoise(&ev)
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

        // Torch.
        if options.torch {
            torch -= h
            if !torchLowSent && torch <= Tuning.torchLowSeconds {
                torchLowSent = true
                ev.append(.torchLow)
            }
            if torch <= 0 {
                torch = 0
                startTorchOut(&ev)
                return
            }
        }

        // The Dreamer's harmless fake twitches.
        if chest.mimic == .dreamer {
            twitchIn -= h
            if twitchIn <= 0 {
                ev.append(.dreamTwitch)
                twitchIn = twitchRng.range(Tuning.dreamTwitchMin...Tuning.dreamTwitchMax)
            }
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

    private var noiseMultiplier: Double {
        return Noise.multiplier(for: chest.mimic) * options.noiseScale
    }

    private var canBite: Bool { return options.bites && isLooting }

    /// Clamp, bite if due, else move the stage (with hysteresis).
    private func settleNoise(_ ev: inout [HeistEvent]) {
        let bite: Bool = canBite
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
            if ns > .asleep { leftAsleep = true }
        }
    }

    private func addOneOff(_ amount: Double, _ ev: inout [HeistEvent]) {
        noise += amount * noiseMultiplier
        quietFor = 0
        settleNoise(&ev)
    }

    /// Adds noise directly (the lesson's scripted stir): sets the level; stage events come with the next step.
    func nudgeNoise(to level: Double) {
        noise = level.isFinite ? level : 0
        quietFor = 0
        var ev: [HeistEvent] = []
        settleNoise(&ev)
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
        touches.removeAll()
        bagValue = 0
        bagCount = 0
    }

    private func biteNow(_ ev: inout [HeistEvent]) {
        let lost: Int = inHandValue()
        loseInHand()
        ev.append(.stageChanged(from: stage, to: .biting))
        stage = .biting
        leftAsleep = true
        ev.append(.bitten(lostValue: lost))
        bites += 1
        lostToBites += lost
        if options.torch { torch = max(0, torch - Tuning.biteTorchPenalty) }
        phase = .bitten(elapsed: 0)
        shutHold = 0
        noise = 1
    }

    private func bank(_ ev: inout [HeistEvent]) {
        let value: Int = bagValue
        let items: Int = bagCount
        let hushedNow: Bool = !leftAsleep
        banked += value
        chestsBanked += 1
        if hushedNow { hushed += 1 }
        bestChestValue = max(bestChestValue, value)
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
        touches.removeAll()
        ev.append(.banked(value: value, items: items, hushed: hushedNow))
        for rid in relicsHere { ev.append(.relicFound(rid)) }
        if !newBestSent && bestRun > 0 && banked > bestRun {
            newBestSent = true
            ev.append(.newBest)
        }
        bagValue = 0
        phase = .banked(elapsed: 0)
        shutHold = 1
    }

    private func nextChest(_ ev: inout [HeistEvent]) {
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
        sawShut = false
        cracked = false
        chestTime = 0
        shutHold = 0
        bagCount = 0
        bagValue = 0
        leftAsleep = false
        revealed = []
        touches.removeAll()
        noise = 0
        quietFor = 0
        twitchRng = SeededRandom(seed: HeistSession.twitchSeed(seed: seed, index: chestIndex))
        twitchIn = twitchRng.range(Tuning.dreamTwitchMin...Tuning.dreamTwitchMax)
        ev.append(.chestArrived(index: spec.index, tier: spec.tier, mimic: spec.mimic, name: spec.mimicName))
    }

    private func startTorchOut(_ ev: inout [HeistEvent]) {
        loseInHand()
        shutHold = 0
        phase = .torchOut(elapsed: 0)
        ev.append(.torchOut)
    }

    private func finish(_ ev: inout [HeistEvent]) {
        phase = .finished
        result = RunResult(mode: mode, seed: seed, gold: banked, seconds: time, chestsOpened: chestsOpened,
                           chestsBanked: chestsBanked, hushed: hushed, bites: bites, relics: relicsBanked,
                           bestChestValue: bestChestValue, itemsBagged: itemsBagged, highestTier: highestTier,
                           lostToBites: lostToBites)
        ev.append(.finished)
    }

    // MARK: Touches (floor space; between steps)

    func touchBegan(id: Int, at point: CGPoint, time: Double) -> [HeistEvent] {
        guard isLooting, touches[id] == nil else { return [] }
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
        touches[id] = TouchTrack(lootIndex: best, lastPoint: point, lastTime: time, speed: 0, stillFor: 0)
        ev.append(.itemPicked(id: loot[best].item.id, kind: loot[best].item.kind))
        addOneOff(Tuning.pickNoise, &ev)
        return ev
    }

    func touchMoved(id: Int, to point: CGPoint, time: Double) -> [HeistEvent] {
        guard var t = touches[id] else { return [] }
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
        touches[id] = t
        if t.lootIndex >= 0 && t.lootIndex < loot.count {
            loot[t.lootIndex].position = HeistSession.clampToFloor(point)
        }
        return []
    }

    func touchEnded(id: Int, at point: CGPoint, time: Double) -> [HeistEvent] {
        guard let t = touches.removeValue(forKey: id) else { return [] }
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

    // MARK: Hints (priority: freeze > slower > tooWide > easeLidDown > shutToBank > dragToBag > openSlowly)

    private func currentHint() -> HeistHint? {
        guard isPlaying else { return nil }
        if stage >= .waking { return .freeze }
        if lid.speed > Tuning.loudSpeed { return .slower }
        if lid.tooWide { return .tooWide }
        if phase == .ready && !lid.inShutZone { return .easeLidDown }
        if isLooting && bagCount > 0 { return .shutToBank }
        let anyGrabbable: Bool = loot.contains { (s: LootState) -> Bool in s.place == .inChest && s.grabbable }
        if isLooting && anyGrabbable { return .dragToBag }
        if phase == .ready { return .openSlowly }
        let anyHeld: Bool = !touches.isEmpty
        if isLooting && revealed.isEmpty && !anyHeld { return .openSlowly }
        return nil
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

import CoreGraphics
import Foundation
import Testing
@testable import Hush

// MARK: - Core rules (Round 1, updated for Round 2: R2 tuning, Hush Chain, golden mimic, relic glimmer, bag jingle,
// rest / resumeGrace / partialResult, biteCost, chestLog, candleLow / relicDeeper hints; and Round 3: noise frozen
// across a pause, the resume grace ends on a sustained loud lid)

struct CoreTests {

    // MARK: Helpers

    private func lidAt(_ o: Double, speed: Double = 0) -> LidInput {
        return Lid.input(openness: o, speed: speed)
    }

    private func newSession(seed: UInt64 = 7, mode: RunMode = .run, best: Int = 0,
                            options: SessionOptions? = nil) -> HeistSession {
        return HeistSession(mode: mode, seed: seed, bestRun: best, foundRelics: [],
                            options: options ?? SessionOptions.for(mode))
    }

    /// A session already looting (one tiny step with the lid in the shut zone).
    private func lootingSession(seed: UInt64 = 7, mode: RunMode = .run, best: Int = 0,
                                options: SessionOptions? = nil) -> (HeistSession, [HeistEvent]) {
        let s: HeistSession = newSession(seed: seed, mode: mode, best: best, options: options)
        let ev: [HeistEvent] = s.step(dt: 1.0 / 120.0, lid: lidAt(0.06))
        return (s, ev)
    }

    /// Steps at `dt` for `seconds` with a fixed lid; returns every event.
    @discardableResult
    private func run(_ s: HeistSession, seconds: Double, dt: Double = 1.0 / 60.0, lid: LidInput) -> [HeistEvent] {
        var out: [HeistEvent] = []
        var t: Double = 0
        while t < seconds - 1e-9 && !s.isFinished {
            out.append(contentsOf: s.step(dt: dt, lid: lid))
            t += dt
        }
        return out
    }

    private func count(_ events: [HeistEvent], _ match: (HeistEvent) -> Bool) -> Int {
        var n: Int = 0
        for e in events where match(e) { n += 1 }
        return n
    }

    private func isBanked(_ e: HeistEvent) -> Bool { if case .banked = e { return true }; return false }
    private func isBitten(_ e: HeistEvent) -> Bool { if case .bitten = e { return true }; return false }
    private func isArrived(_ e: HeistEvent) -> Bool { if case .chestArrived = e { return true }; return false }
    private func isTorchLow(_ e: HeistEvent) -> Bool { if case .torchLow = e { return true }; return false }
    private func isTorchOut(_ e: HeistEvent) -> Bool { if case .torchOut = e { return true }; return false }
    private func isFinishedEvent(_ e: HeistEvent) -> Bool { if case .finished = e { return true }; return false }
    private func isTwitch(_ e: HeistEvent) -> Bool { if case .dreamTwitch = e { return true }; return false }
    private func isCracked(_ e: HeistEvent) -> Bool { if case .lidCracked = e { return true }; return false }

    /// The index of the shallowest item.
    private func shallowest(_ snap: HeistSnapshot) -> Int? {
        var best: Int? = nil
        for k in snap.loot.indices {
            if let b = best {
                if snap.loot[k].item.depth < snap.loot[b].item.depth { best = k }
            } else {
                best = k
            }
        }
        return best
    }

    private func isOil(_ kind: LootKind) -> Bool { if case .oil = kind { return true }; return false }
    private func isRelic(_ kind: LootKind) -> Bool { if case .relic = kind { return true }; return false }

    /// Opens to light item `k` fully (speed 0: silent), then drags it into the bag. Returns the touch events.
    private func bagItem(_ s: HeistSession, _ k: Int, touchID: Int = 1) -> [HeistEvent] {
        let item: LootItem = s.snapshot.loot[k].item
        _ = s.step(dt: 1.0 / 120.0, lid: lidAt(min(1, item.depth + 0.08)))
        let p: CGPoint = s.snapshot.loot[k].position
        var ev: [HeistEvent] = s.touchBegan(id: touchID, at: p, time: 10)
        ev.append(contentsOf: s.touchMoved(id: touchID, to: CGPoint(x: p.x, y: 380), time: 12))
        ev.append(contentsOf: s.touchEnded(id: touchID, at: CGPoint(x: p.x, y: 400), time: 12.5))
        return ev
    }

    /// Bags the shallowest item of the current (looting) chest, then eases the lid shut until it banks.
    /// Returns the bag value just before the bank and every event.
    private func bankOne(_ s: HeistSession) -> (Int, [HeistEvent]) {
        guard let k = shallowest(s.snapshot) else { return (0, []) }
        var ev: [HeistEvent] = bagItem(s, k)
        let v: Int = s.snapshot.bagValue
        ev.append(contentsOf: run(s, seconds: 0.5, dt: 1.0 / 120.0, lid: lidAt(0.06)))
        return (v, ev)
    }

    /// After a bank or a bite: waits out the moment; the next chest arrives with the lid shut and starts looting.
    private func nextChestLooting(_ s: HeistSession) {
        run(s, seconds: 2.0, lid: lidAt(0.06))
    }

    private func bankedValue(_ events: [HeistEvent]) -> Int? {
        for e in events {
            if case .banked(let value, _, _) = e { return value }
        }
        return nil
    }

    private func isChainBroken(_ e: HeistEvent) -> Bool { if case .chainBroken = e { return true }; return false }
    private func isChainUp(_ e: HeistEvent) -> Bool { if case .chainUp = e { return true }; return false }

    private func firstSeed(where match: (ChestSpec) -> Bool) -> UInt64? {
        var seed: UInt64 = 1
        while seed < 3000 {
            if match(ChestFactory.chest(seed: seed, index: 0, found: [])) { return seed }
            seed += 1
        }
        return nil
    }

    // MARK: SeededRandom

    @Test func seededRandomIsDeterministicAndInRange() {
        var a = SeededRandom(seed: 42)
        var b = SeededRandom(seed: 42)
        var c = SeededRandom(seed: 43)
        var same: Bool = true
        var differs: Bool = false
        var inRange: Bool = true
        var i: Int = 0
        while i < 2000 {
            let x: UInt64 = a.next()
            if x != b.next() { same = false }
            if x != c.next() { differs = true }
            let u: Double = a.unit()
            _ = b.unit()
            if u < 0 || u >= 1 { inRange = false }
            let n: Int = a.int(2...5)
            _ = b.int(2...5)
            if n < 2 || n > 5 { inRange = false }
            let r: Double = a.range(-3...4)
            _ = b.range(-3...4)
            if r < -3 || r > 4 { inRange = false }
            i += 1
        }
        #expect(same)
        #expect(differs)
        #expect(inRange)
        var d = SeededRandom(seed: 1)
        let single: Int = d.int(7...7)
        #expect(single == 7)
    }

    // MARK: Noise

    @Test func lidRateMatchesTheR2Curve() {
        // R2 (REVIEW-1-feel #1): quiet up to 12 °/s, 0.008·x + 0.0004·x².
        #expect(Noise.lidRate(speed: 0) == 0)
        #expect(Noise.lidRate(speed: 10) == 0)
        #expect(Noise.lidRate(speed: 12) == 0)
        #expect(Noise.lidRate(speed: 12.5) > 0)
        #expect(abs(Noise.lidRate(speed: 20) - 0.0896) < 1e-9)
        #expect(abs(Noise.lidRate(speed: 40) - 0.5376) < 1e-9)   // 0.008·28 + 0.0004·784
        // A 45 °/s full open (65° in 1.44 s) bites a Snorer; 40 °/s doesn't.
        #expect(Noise.lidRate(speed: 45) * (Tuning.lidTravel / 45) >= 1)
        #expect(Noise.lidRate(speed: 40) * (Tuning.lidTravel / 40) < 1)
        let slam: Double = Noise.lidRate(speed: 120) * 0.4
        #expect(slam >= 2.2 && slam < 2.25)
        #expect(Noise.lidRate(speed: 30) > Noise.lidRate(speed: 20))
        #expect(Noise.lidRate(speed: Double.nan) == 0)
        #expect(Noise.lidRate(speed: Double.nan, closing: true) == 0)
    }

    @Test func closingIsQuieterThanOpening() {
        // R2 (REVIEW-1-feel #2): closing is silent below 18 °/s.
        #expect(Noise.quietSpeed(closing: false) == Tuning.quietSpeed)
        #expect(Noise.quietSpeed(closing: true) == Tuning.closeQuietSpeed)
        #expect(Noise.lidRate(speed: 16) > 0)
        #expect(Noise.lidRate(speed: 16, closing: true) == 0)
        #expect(Noise.lidRate(speed: 18, closing: true) == 0)
        #expect(Noise.lidRate(speed: 25, closing: true) > 0)
        #expect(Noise.lidRate(speed: 25, closing: true) < Noise.lidRate(speed: 25))
        // In a session the direction comes from the openness: opening at 16 °/s is heard, closing at 16 °/s isn't.
        let (a, _) = lootingSession(seed: 161)
        var o: Double = 0.06
        for _ in 0..<60 {
            o += 16.0 / Tuning.lidTravel / 60.0
            _ = a.step(dt: 1.0 / 60.0, lid: lidAt(o, speed: 16))
        }
        #expect(a.snapshot.noise > 0.02)
        let (b, _) = lootingSession(seed: 161)
        _ = b.step(dt: 1.0 / 120.0, lid: lidAt(0.9))
        var p: Double = 0.9
        for _ in 0..<60 {
            p -= 16.0 / Tuning.lidTravel / 60.0
            _ = b.step(dt: 1.0 / 60.0, lid: lidAt(p, speed: 16))
        }
        #expect(b.snapshot.noise == 0)
    }

    @Test func dragRateMatchesTheR2Line() {
        #expect(Noise.dragRate(speed: 0) == 0)
        #expect(Noise.dragRate(speed: 350) == 0)
        #expect(abs(Noise.dragRate(speed: 1000) - 0.39) < 1e-9)
        #expect(Noise.dragRate(speed: 500) > 0)
    }

    @Test func jingleFloorAndChainMultiplier() {
        #expect(Noise.jingleFloor(items: 0, multiplier: 1) == 0)
        #expect(abs(Noise.jingleFloor(items: 2, multiplier: 1) - 0.07) < 1e-12)
        #expect(abs(Noise.jingleFloor(items: 3, multiplier: 0.7) - 0.0735) < 1e-12)
        // Capped under Stirring: a full bag never stirs the mimic by itself.
        #expect(Noise.jingleFloor(items: 9, multiplier: 1.35 * 1.25) == Tuning.jingleMax)
        #expect(Tuning.jingleMax < Tuning.stirringNoise)
        #expect(Noise.chainMultiplier(0) == 1)
        #expect(abs(Noise.chainMultiplier(1) - 1.1) < 1e-12)
        #expect(abs(Noise.chainMultiplier(3) - 1.3) < 1e-12)
        #expect(abs(Noise.chainMultiplier(5) - 1.5) < 1e-12)
        #expect(Noise.chainMultiplier(9) == Noise.chainMultiplier(5))
        #expect(Noise.chainMultiplier(-2) == 1)
    }

    @Test func stagesHaveHysteresis() {
        #expect(Noise.stage(for: 0.2, previous: .asleep) == .asleep)
        #expect(Noise.stage(for: 0.36, previous: .asleep) == .stirring)
        #expect(Noise.stage(for: 0.33, previous: .stirring) == .stirring)
        #expect(Noise.stage(for: 0.30, previous: .stirring) == .asleep)
        #expect(Noise.stage(for: 0.33, previous: .asleep) == .asleep)
        #expect(Noise.stage(for: 0.72, previous: .asleep) == .waking)
        #expect(Noise.stage(for: 0.68, previous: .waking) == .waking)
        #expect(Noise.stage(for: 0.64, previous: .waking) == .stirring)
        #expect(Noise.stage(for: 0.10, previous: .waking) == .asleep)
        #expect(Noise.stage(for: 1.0, previous: .waking) == .biting)
        #expect(Noise.stage(for: 0.5, previous: .biting) == .stirring)
    }

    @Test func mimicMultipliers() {
        #expect(Noise.multiplier(for: .snorer) == 1.0)
        #expect(Noise.multiplier(for: .lightSleeper) == 1.35)
        #expect(Noise.multiplier(for: .heavySleeper) == 0.7)
        #expect(Noise.multiplier(for: .dreamer) == 1.0)
    }

    // MARK: Lid

    @Test func opennessMapping() {
        #expect(Lid.openness(angle: 100) == 0)
        #expect(Lid.openness(angle: 165) == 1)
        #expect(abs(Lid.openness(angle: 132.5) - 0.5) < 1e-12)
        #expect(Lid.openness(angle: 80) == 0)
        #expect(Lid.openness(angle: 180) == 1)
        #expect(abs(Lid.angle(openness: 0.5) - 132.5) < 1e-12)
        #expect(Lid.angle(openness: 2) == 165)
        var a: Double = 100
        var worst: Double = 0
        while a <= 165 {
            worst = max(worst, abs(Lid.angle(openness: Lid.openness(angle: a)) - a))
            a += 0.5
        }
        #expect(worst < 1e-9)
        #expect(Tuning.lidTravel == 65)
    }

    @Test func lidInputZones() {
        #expect(Lid.input(angle: 110, speed: 0).inShutZone)
        #expect(!Lid.input(angle: 111, speed: 0).inShutZone)
        #expect(Lid.input(angle: 173, speed: 0).tooWide)
        #expect(!Lid.input(angle: 165, speed: 0).tooWide)
        #expect(Lid.input(openness: 0.06, speed: 0).inShutZone)
        #expect(!Lid.input(openness: 0.5, speed: 0).inShutZone)
        #expect(Lid.input(angle: 130, speed: -5).speed == 0)
    }

    // MARK: Catalogues

    @Test func relicCatalogHas24NamedRelics() {
        let all: [Relic] = RelicCatalog.all
        #expect(all.count == 24)
        var ids: Set<RelicID> = []
        var i: Int = 1
        while i <= 24 {
            let raw: String = i < 10 ? "relic0\(i)" : "relic\(i)"
            ids.insert(RelicID(raw))
            i += 1
        }
        let gotIDs: Set<RelicID> = Set(all.map { (r: Relic) -> RelicID in r.id })
        #expect(gotIDs == ids)
        // R2: 24 shapes, one relic each, and no two relics share a tint.
        #expect(RelicShape.allCases.count == 24)
        for shape in RelicShape.allCases {
            let n: Int = all.filter { (r: Relic) -> Bool in r.shape == shape }.count
            #expect(n == 1, "\(shape.rawValue) used \(n) times")
        }
        let tintCount: Int = Set(all.map { (r: Relic) -> RGBA in r.tint }).count
        #expect(tintCount == 24)
        for r in all {
            #expect(!r.name.isEmpty && !r.blurb.isEmpty)
        }
        let nameCount: Int = Set(all.map { (r: Relic) -> String in r.name }).count
        #expect(nameCount == 24)
        #expect(RelicCatalog.relic(RelicID("relic05")).name == all[4].name)
        #expect(RelicCatalog.relic(RelicID("nope")).id == RelicID("nope"))
    }

    @Test func mimicNamesPerKind() {
        for kind in MimicKind.allCases {
            let names: [String] = MimicNames.names(for: kind)
            #expect(names.count >= 8)
            #expect(Set(names).count == names.count)
            #expect(MimicNames.name(for: kind, seed: 12345) == MimicNames.name(for: kind, seed: 12345))
            #expect(names.contains(MimicNames.name(for: kind, seed: 99)))
        }
        #expect(MimicNames.names(for: .snorer).contains("Snoring Sam"))
        #expect(MimicNames.names(for: .lightSleeper).contains("Twitchy Tess"))
        // R2: golden mimics have gold names whatever their personality.
        let gold: [String] = MimicNames.goldenNames
        #expect(gold.count >= 8 && Set(gold).count == gold.count)
        #expect(gold.contains("Midas Mo"))
        for kind in MimicKind.allCases {
            #expect(gold.contains(MimicNames.name(for: kind, seed: 77, golden: true)))
            #expect(MimicNames.name(for: kind, seed: 77) == MimicNames.name(for: kind, seed: 77, golden: false))
        }
    }

    // MARK: ChestFactory

    @Test func tiersByIndex() {
        #expect(ChestFactory.tier(forIndex: 0) == .wooden)
        #expect(ChestFactory.tier(forIndex: 1) == .wooden)
        #expect(ChestFactory.tier(forIndex: 2) == .iron)
        #expect(ChestFactory.tier(forIndex: 3) == .iron)
        #expect(ChestFactory.tier(forIndex: 4) == .gilded)
        #expect(ChestFactory.tier(forIndex: 5) == .gilded)
        #expect(ChestFactory.tier(forIndex: 6) == .royal)
        #expect(ChestFactory.tier(forIndex: 40) == .royal)
        #expect(ChestFactory.multiplier(for: .royal) == 3)
        // R2 decays.
        #expect(ChestFactory.decay(for: .wooden) == 0.16)
        #expect(ChestFactory.decay(for: .iron) == 0.14)
        #expect(ChestFactory.decay(for: .gilded) == 0.12)
        #expect(ChestFactory.decay(for: .royal) == 0.10)
    }

    @Test func r2TuningNumbers() {
        #expect(Tuning.quietSpeed == 12 && Tuning.closeQuietSpeed == 18)
        #expect(Tuning.lidRateLinear == 0.008 && Tuning.lidRateQuadratic == 0.0004)
        #expect(Tuning.decayGrace == 0.3)
        #expect(Tuning.dragQuietSpeed == 350)
        #expect(Tuning.biteTorchPenalty == 10 && Tuning.oilSeconds == 6)
        #expect(Tuning.relicChance == 0.25)
        // REVIEW-1-duo P1-9: relics need at most about 161°, well short of "too wide".
        #expect(Tuning.relicDepth.lowerBound == 0.80 && Tuning.relicDepth.upperBound == 0.88)
        let deepestGrab: Double = Lid.angle(openness: Tuning.relicDepth.upperBound + Tuning.grabLight * Tuning.lightRamp)
        #expect(deepestGrab < 161.5 && deepestGrab < Tuning.tooWideAngle)
        #expect(Tuning.chainStep == 0.10 && Tuning.chainMax == 5)
        #expect(Tuning.goldenChance == 0.06 && Tuning.goldenFromIndex == 2)
        #expect(Tuning.jinglePerItem == 0.035 && Tuning.jingleMax == 0.30)
        #expect(Tuning.closingAngle == 70)
    }

    @Test func chestsAreDeterministic() {
        let a: ChestSpec = ChestFactory.chest(seed: 99, index: 3, found: [])
        let b: ChestSpec = ChestFactory.chest(seed: 99, index: 3, found: [])
        let c: ChestSpec = ChestFactory.chest(seed: 100, index: 3, found: [])
        #expect(a == b)
        #expect(a != c)
    }

    @Test func chestsAreDealtByTheRules() {
        var seed: UInt64 = 1
        var overlaps: Int = 0
        var outside: Int = 0
        var badCount: Int = 0
        var badValue: Int = 0
        var woodenRelics: Int = 0
        var relicChests: Int = 0
        var ironPlus: Int = 0
        var deepY: Double = 0
        var deepN: Double = 0
        var shallowY: Double = 0
        var shallowN: Double = 0
        let box: CGRect = FloorSpace.interior
        while seed <= 60 {
            var index: Int = 0
            while index <= 8 {
                let c: ChestSpec = ChestFactory.chest(seed: seed, index: index, found: [])
                #expect(c.tier == ChestFactory.tier(forIndex: index))
                let goldenMult: Double = c.golden ? Tuning.goldenValueMultiplier : 1
                #expect(c.multiplier == ChestFactory.multiplier(for: c.tier) * goldenMult)
                #expect(c.decay == ChestFactory.decay(for: c.tier))
                #expect(!c.mimicName.isEmpty)
                let range: ClosedRange<Int> = ChestFactory.itemCount(for: c.tier)
                let lo: Int = c.mimic == .heavySleeper ? range.lowerBound - 1 : range.lowerBound
                let hi: Int = c.mimic == .heavySleeper ? range.upperBound - 1 : range.upperBound
                if c.items.count < lo || c.items.count > hi { badCount += 1 }
                if index == 0 && c.mimic == .lightSleeper { badCount += 1 }
                let uniqueIDs: Int = Set(c.items.map { (it: LootItem) -> Int in it.id }).count
                #expect(uniqueIDs == c.items.count)
                if c.tier != .wooden { ironPlus += 1 }
                var hasRelic: Bool = false
                for it in c.items {
                    #expect(it.radius == ChestFactory.radius(for: it.kind))
                    let x: CGFloat = it.position.x
                    let y: CGFloat = it.position.y
                    if x - it.radius < box.minX - 0.001 || x + it.radius > box.maxX + 0.001
                        || y - it.radius < box.minY - 0.001 || y + it.radius > box.maxY + 0.001 { outside += 1 }
                    switch it.kind {
                    case .copper:
                        if !Tuning.copperValue.contains(it.value) || !Tuning.copperDepth.contains(it.depth) { badValue += 1 }
                    case .silver:
                        if !Tuning.silverValue.contains(it.value) || !Tuning.silverDepth.contains(it.depth) { badValue += 1 }
                    case .gem:
                        if !Tuning.gemValue.contains(it.value) || !Tuning.gemDepth.contains(it.depth) { badValue += 1 }
                    case .relic:
                        hasRelic = true
                        if !Tuning.relicValue.contains(it.value) || !Tuning.relicDepth.contains(it.depth) { badValue += 1 }
                    case .oil:
                        if it.value != 0 || !Tuning.oilDepth.contains(it.depth) { badValue += 1 }
                    }
                    if it.depth > 0.55 { deepY += Double(y); deepN += 1 }
                    if it.depth < 0.30 { shallowY += Double(y); shallowN += 1 }
                }
                if hasRelic {
                    relicChests += 1
                    if c.tier == .wooden { woodenRelics += 1 }
                }
                var i: Int = 0
                while i < c.items.count {
                    var j: Int = i + 1
                    while j < c.items.count {
                        let d: Double = HeistSession.distance(c.items[i].position, c.items[j].position)
                        let need: Double = Double(c.items[i].radius + c.items[j].radius) + Tuning.lootGap
                        if d < need - 0.001 { overlaps += 1 }
                        j += 1
                    }
                    i += 1
                }
                index += 1
            }
            seed += 1
        }
        #expect(overlaps == 0)
        #expect(outside == 0)
        #expect(badCount == 0)
        #expect(badValue == 0)
        #expect(woodenRelics == 0)
        // About 25 % of Iron-bound-or-better chests hold a relic (R2).
        let share: Double = Double(relicChests) / Double(max(ironPlus, 1))
        #expect(share > 0.15 && share < 0.36, "relic share \(share)")
        // Deeper items sit further back (smaller y) on average.
        #expect(deepN > 0 && shallowN > 0)
        #expect(deepY / max(deepN, 1) < shallowY / max(shallowN, 1))
    }

    @Test func relicChestsPreferUnfoundRelics() {
        // A seed whose chest #3 (Iron-bound) holds a relic.
        var seed: UInt64 = 1
        var found: UInt64? = nil
        while seed < 3000 && found == nil {
            let c: ChestSpec = ChestFactory.chest(seed: seed, index: 3, found: [])
            if c.items.contains(where: { (it: LootItem) -> Bool in isRelic(it.kind) }) { found = seed }
            seed += 1
        }
        guard let s = found else {
            Issue.record("no relic chest found")
            return
        }
        let ids: [RelicID] = RelicCatalog.ids
        let onlyMissing: RelicID = ids[17]
        var have: Set<RelicID> = Set(ids)
        have.remove(onlyMissing)
        let c: ChestSpec = ChestFactory.chest(seed: s, index: 3, found: have)
        var got: RelicID? = nil
        for it in c.items {
            if case .relic(let rid) = it.kind { got = rid }
        }
        #expect(got == onlyMissing)
        // The values and positions don't depend on what was found.
        let plain: ChestSpec = ChestFactory.chest(seed: s, index: 3, found: [])
        let plainValues: [Int] = plain.items.map { (it: LootItem) -> Int in it.value }
        let cValues: [Int] = c.items.map { (it: LootItem) -> Int in it.value }
        #expect(plainValues == cValues)
        let plainPositions: [CGPoint] = plain.items.map { (it: LootItem) -> CGPoint in it.position }
        let cPositions: [CGPoint] = c.items.map { (it: LootItem) -> CGPoint in it.position }
        #expect(plainPositions == cPositions)
        // Everything found: any relic is fine.
        let all: ChestSpec = ChestFactory.chest(seed: s, index: 3, found: Set(ids))
        let anyRelic: Bool = all.items.contains(where: { (it: LootItem) -> Bool in isRelic(it.kind) })
        #expect(anyRelic)
    }

    // MARK: Session: the chest loop

    @Test func chestArrivesAndLootingStartsFromTheShutZone() {
        let s: HeistSession = newSession()
        #expect(s.snapshot.phase == .ready)
        #expect(s.snapshot.chest?.index == 0)
        // Lid open at the start: the chest waits.
        let ev: [HeistEvent] = s.step(dt: 1.0 / 60.0, lid: lidAt(0.5))
        #expect(count(ev, isArrived) == 1)
        #expect(s.snapshot.phase == .ready)
        #expect(s.snapshot.hint == HeistHint.easeLidDown)
        // Light stays off while it waits.
        let allDark: Bool = s.snapshot.loot.allSatisfy { (l: LootState) -> Bool in l.light == 0 && !l.grabbable }
        #expect(allDark)
        // Ease it down (silently), then open.
        _ = s.step(dt: 1.0 / 60.0, lid: lidAt(0.0))
        #expect(s.snapshot.phase == .ready)
        #expect(s.snapshot.hint == HeistHint.openSlowly)
        let ev2: [HeistEvent] = s.step(dt: 1.0 / 60.0, lid: lidAt(0.10))
        #expect(s.snapshot.phase == .looting)
        #expect(count(ev2, isCracked) == 1)
        let ev3: [HeistEvent] = s.step(dt: 1.0 / 60.0, lid: lidAt(0.2))
        #expect(count(ev3, isCracked) == 0)
    }

    @Test func lightRevealAndGrabbableFollowDepth() {
        let (s, _) = lootingSession(seed: 11)
        // An item not yet lit at the looting step's openness (0.06): silver or deeper.
        guard let k = s.snapshot.loot.firstIndex(where: { (l: LootState) -> Bool in
            l.item.depth >= 0.2 && l.item.depth <= 0.8
        }) else {
            Issue.record("no mid-depth item")
            return
        }
        let item: LootItem = s.snapshot.loot[k].item
        // Openness depth + 0.05 → light 0.5: revealed, not yet grabbable.
        let ev: [HeistEvent] = s.step(dt: 1.0 / 120.0, lid: lidAt(item.depth + 0.05))
        let l: LootState = s.snapshot.loot[k]
        #expect(abs(l.light - 0.5) < 1e-6)
        #expect(!l.grabbable)
        let revealed: Int = count(ev) { (e: HeistEvent) -> Bool in
            if case .itemRevealed(let id, _) = e { return id == item.id }
            return false
        }
        #expect(revealed == 1)
        // Depth + 0.07 → light 0.7: grabbable. No second reveal.
        let ev2: [HeistEvent] = s.step(dt: 1.0 / 120.0, lid: lidAt(item.depth + 0.07))
        #expect(s.snapshot.loot[k].grabbable)
        let again: Int = count(ev2) { (e: HeistEvent) -> Bool in
            if case .itemRevealed(let id, _) = e { return id == item.id }
            return false
        }
        #expect(again == 0)
        #expect(s.snapshot.hint == HeistHint.dragToBag)
    }

    @Test func pickDragAndBag() {
        let (s, _) = lootingSession(seed: 21)
        guard let k = shallowest(s.snapshot), let chest = s.snapshot.chest else {
            Issue.record("empty chest")
            return
        }
        let item: LootItem = s.snapshot.loot[k].item
        let mult: Double = Noise.multiplier(for: chest.mimic)
        _ = s.step(dt: 1.0 / 120.0, lid: lidAt(min(1, item.depth + 0.08)))
        let p: CGPoint = s.snapshot.loot[k].position
        // Too far away (radius + 20): nothing, when no other item is in reach of that point.
        let missPoint: CGPoint = CGPoint(x: p.x + item.radius + 20, y: p.y)
        let clear: Bool = s.snapshot.loot.allSatisfy { (o: LootState) -> Bool in
            HeistSession.distance(o.position, missPoint) > Double(o.item.radius) + Tuning.grabSlop
        }
        if clear {
            let miss: [HeistEvent] = s.touchBegan(id: 5, at: missPoint, time: 1)
            #expect(miss.isEmpty)
        }
        let n0: Double = s.snapshot.noise
        // Inside the radius (and nearer than any other item): picked.
        let picked: [HeistEvent] = s.touchBegan(id: 1, at: CGPoint(x: p.x + 10, y: p.y), time: 2)
        #expect(picked.first == HeistEvent.itemPicked(id: item.id, kind: item.kind))
        #expect(s.snapshot.loot[k].place == LootPlace.held(touchID: 1))
        #expect(abs(s.snapshot.noise - (n0 + Tuning.pickNoise * mult)) < 1e-9)
        // A second finger on the same item does nothing (it's held).
        let second: [HeistEvent] = s.touchBegan(id: 2, at: p, time: 2.1)
        let secondPick: Int = count(second) { (e: HeistEvent) -> Bool in
            if case .itemPicked(let id, _) = e { return id == item.id }
            return false
        }
        #expect(secondPick == 0)
        // It follows the finger.
        _ = s.touchMoved(id: 1, to: CGPoint(x: 300, y: 330), time: 3)
        #expect(abs(s.snapshot.loot[k].position.x - CGFloat(300)) < CGFloat(0.001))
        #expect(abs(s.snapshot.loot[k].position.y - CGFloat(330)) < CGFloat(0.001))
        // Let go in the bag.
        let n1: Double = s.snapshot.noise
        let bagged: [HeistEvent] = s.touchEnded(id: 1, at: CGPoint(x: 300, y: 410), time: 4)
        let v: Int = Int((Double(item.value) * chest.multiplier).rounded())
        #expect(bagged.first == HeistEvent.itemBagged(id: item.id, kind: item.kind, value: v))
        let snap: HeistSnapshot = s.snapshot
        #expect(snap.loot[k].place == .inBag)
        #expect(FloorSpace.bagRect.contains(snap.loot[k].position))
        #expect(snap.bagValue == v)
        #expect(abs(snap.noise - (n1 + Tuning.bagNoise * mult)) < 1e-9)
        #expect(snap.hint == HeistHint.shutToBank)
    }

    @Test func droppingOutsideTheBagPutsItBack() {
        let (s, _) = lootingSession(seed: 23)
        guard let k = shallowest(s.snapshot), let chest = s.snapshot.chest else {
            Issue.record("empty chest")
            return
        }
        let item: LootItem = s.snapshot.loot[k].item
        _ = s.step(dt: 1.0 / 120.0, lid: lidAt(min(1, item.depth + 0.08)))
        _ = s.touchBegan(id: 3, at: s.snapshot.loot[k].position, time: 1)
        let n0: Double = s.snapshot.noise
        // Let go on the wall (outside the interior, above the bag).
        let ev: [HeistEvent] = s.touchEnded(id: 3, at: CGPoint(x: 20, y: 340), time: 1.5)
        #expect(ev.first == HeistEvent.itemDropped(id: item.id))
        let l: LootState = s.snapshot.loot[k]
        #expect(l.place == .inChest)
        let box: CGRect = FloorSpace.interior
        #expect(l.position.x >= box.minX + item.radius - 0.001 && l.position.x <= box.maxX - item.radius + 0.001)
        #expect(l.position.y >= box.minY + item.radius - 0.001 && l.position.y <= box.maxY - item.radius + 0.001)
        #expect(abs(s.snapshot.noise - (n0 + Tuning.dropNoise * Noise.multiplier(for: chest.mimic))) < 1e-9)
        #expect(s.snapshot.bagValue == 0)
    }

    @Test func notGrabbableMeansNoPick() {
        let (s, _) = lootingSession(seed: 31)
        _ = s.step(dt: 1.0 / 120.0, lid: lidAt(0))
        // The lid shut (still looting): nothing is lit.
        var deepest: Int = 0
        for k in s.snapshot.loot.indices where s.snapshot.loot[k].item.depth > s.snapshot.loot[deepest].item.depth {
            deepest = k
        }
        let p: CGPoint = s.snapshot.loot[deepest].position
        let ev: [HeistEvent] = s.touchBegan(id: 1, at: p, time: 0)
        #expect(ev.isEmpty)
        #expect(s.snapshot.loot[deepest].place == .inChest)
        // Not looting (ready): nothing either.
        let r: HeistSession = newSession()
        let ev2: [HeistEvent] = r.touchBegan(id: 1, at: r.snapshot.loot[0].position, time: 0)
        #expect(ev2.isEmpty)
    }

    @Test func dragSpeedFeedsNoiseOnTheNextStep() {
        let (s, _) = lootingSession(seed: 41)
        guard let k = shallowest(s.snapshot), let chest = s.snapshot.chest else {
            Issue.record("empty chest")
            return
        }
        let item: LootItem = s.snapshot.loot[k].item
        _ = s.step(dt: 1.0 / 120.0, lid: lidAt(min(1, item.depth + 0.08)))
        let open: LidInput = lidAt(min(1, item.depth + 0.08))
        let start: CGPoint = s.snapshot.loot[k].position
        var t: Double = 0
        _ = s.touchBegan(id: 1, at: start, time: t)
        // 1000 pt/s sideways (x only) for 0.3 s at 60 Hz, stepping between moves.
        var x: Double = Double(start.x)
        var dir: Double = 1
        var i: Int = 0
        while i < 18 {
            t += 1.0 / 60.0
            x += dir * 1000.0 / 60.0
            if x > 560 || x < 110 { dir = -dir; x += 2 * dir * 1000.0 / 60.0 }
            _ = s.touchMoved(id: 1, to: CGPoint(x: CGFloat(x), y: start.y), time: t)
            _ = s.step(dt: 1.0 / 60.0, lid: open)
            i += 1
        }
        #expect(abs(s.dragSpeed - 1000) < 40, "drag speed \(s.dragSpeed)")
        let n0: Double = s.snapshot.noise
        t += 1.0 / 60.0
        x += dir * 1000.0 / 60.0
        _ = s.touchMoved(id: 1, to: CGPoint(x: CGFloat(x), y: start.y), time: t)
        _ = s.step(dt: 1.0 / 60.0, lid: open)
        let expected: Double = Noise.dragRate(speed: 1000) * Noise.multiplier(for: chest.mimic) / 60.0
        #expect(abs((s.snapshot.noise - n0) - expected) < expected * 0.15, "rise \(s.snapshot.noise - n0)")
        // Still finger: the speed decays.
        _ = run(s, seconds: 0.5, lid: open)
        #expect(s.dragSpeed < 50)
    }

    @Test func noiseDecaysOnlyAfterTheGrace() {
        let (s, _) = lootingSession(seed: 51)
        s.nudgeNoise(to: 0.3)
        let still: LidInput = lidAt(0.3)
        // R2 grace 0.3 s: still nothing after 0.2 s.
        _ = s.step(dt: 0.2, lid: still)
        #expect(abs(s.snapshot.noise - 0.3) < 1e-9)
        _ = s.step(dt: 0.5, lid: still)
        #expect(s.snapshot.noise < 0.3)
        // A loud lid stops the decay and adds noise.
        let before: Double = s.snapshot.noise
        _ = s.step(dt: 0.1, lid: lidAt(0.4, speed: 20))
        #expect(s.snapshot.noise > before)
    }

    @Test func bankingNeedsLootAndAShutHold() {
        let (s, _) = lootingSession(seed: 61)
        guard let k = shallowest(s.snapshot) else {
            Issue.record("empty chest")
            return
        }
        // Shutting with an empty bag does nothing.
        let empty: [HeistEvent] = run(s, seconds: 1.0, lid: lidAt(0.06))
        #expect(count(empty, isBanked) == 0)
        #expect(s.snapshot.phase == .looting)
        let ev: [HeistEvent] = bagItem(s, k)
        guard case .itemBagged(_, _, let v)? = ev.first(where: { (e: HeistEvent) -> Bool in
            if case .itemBagged = e { return true }
            return false
        }) else {
            Issue.record("not bagged")
            return
        }
        // 0.2 s in the shut zone: not yet.
        let early: [HeistEvent] = run(s, seconds: 0.2, dt: 1.0 / 120.0, lid: lidAt(0.06))
        #expect(count(early, isBanked) == 0)
        #expect(s.snapshot.shutHold > 0.4 && s.snapshot.shutHold < 1)
        let later: [HeistEvent] = run(s, seconds: 0.2, dt: 1.0 / 120.0, lid: lidAt(0.06))
        // Hushed: the first link of the Hush Chain pays ×1.1.
        let paid: Int = Int((Double(v) * Noise.chainMultiplier(1)).rounded())
        #expect(later.contains(HeistEvent.banked(value: paid, items: 1, hushed: true)))
        #expect(later.contains(HeistEvent.chainUp(count: 1, multiplier: Noise.chainMultiplier(1))))
        #expect(s.snapshot.banked == paid)
        #expect(s.snapshot.chestsBanked == 1)
        #expect(s.snapshot.hushed == 1)
        // The torch doesn't burn in the bank moment; the next chest comes after 1.4 s.
        let torch: Double = s.snapshot.torchRemaining
        let moment: [HeistEvent] = run(s, seconds: 1.2, lid: lidAt(0.06))
        #expect(abs(s.snapshot.torchRemaining - torch) < 1e-9)
        #expect(count(moment, isArrived) == 0)
        let next: [HeistEvent] = run(s, seconds: 0.4, lid: lidAt(0.06))
        let c1: ChestSpec = ChestFactory.chest(seed: 61, index: 1, found: [])
        let arrival: HeistEvent = .chestArrived(index: 1, tier: .wooden, mimic: c1.mimic, name: c1.mimicName)
        #expect(next.contains(arrival))
        #expect(s.snapshot.chest?.index == 1)
    }

    @Test func leavingTheLidOutOfTheShutZoneResetsTheHold() {
        let (s, _) = lootingSession(seed: 62)
        guard let k = shallowest(s.snapshot) else {
            Issue.record("empty chest")
            return
        }
        _ = bagItem(s, k)
        _ = run(s, seconds: 0.25, dt: 1.0 / 120.0, lid: lidAt(0.06))
        _ = s.step(dt: 1.0 / 120.0, lid: lidAt(0.5))
        #expect(s.snapshot.shutHold == 0)
        let ev: [HeistEvent] = run(s, seconds: 0.25, dt: 1.0 / 120.0, lid: lidAt(0.06))
        #expect(count(ev, isBanked) == 0)
    }

    @Test func aSlamBitesAndCostsTheHaulAndTorch() {
        let (s, _) = lootingSession(seed: 71)
        guard let k = shallowest(s.snapshot) else {
            Issue.record("empty chest")
            return
        }
        _ = bagItem(s, k)
        let inHand: Int = s.snapshot.bagValue
        #expect(inHand > 0)
        let torch0: Double = s.snapshot.torchRemaining
        var ev: [HeistEvent] = []
        var t: Double = 0
        while t < 1.0 && count(ev, isBitten) == 0 {
            ev.append(contentsOf: s.step(dt: 1.0 / 60.0, lid: lidAt(0.5, speed: 150)))
            t += 1.0 / 60.0
        }
        #expect(ev.contains(HeistEvent.bitten(lostValue: inHand)))
        // R2: the cost comes right after the bite.
        if let bi = ev.firstIndex(of: HeistEvent.bitten(lostValue: inHand)), bi + 1 < ev.count,
           case .biteCost(let lostValue, let seconds) = ev[bi + 1] {
            #expect(lostValue == inHand)
            #expect(abs(seconds - Tuning.biteTorchPenalty) < 1e-9)
        } else {
            Issue.record("no biteCost after bitten: \(ev)")
        }
        let toBiting: Bool = ev.contains { (e: HeistEvent) -> Bool in
            if case .stageChanged(_, let to) = e { return to == .biting }
            return false
        }
        #expect(toBiting)
        let snap: HeistSnapshot = s.snapshot
        #expect(snap.bites == 1)
        #expect(snap.bagValue == 0)
        #expect(snap.loot[k].place == .lost)
        let expectedTorch: Double = torch0 - t - Tuning.biteTorchPenalty
        #expect(abs(snap.torchRemaining - expectedTorch) < 0.05, "torch \(snap.torchRemaining) vs \(expectedTorch)")
        if case .bitten = snap.phase {} else { Issue.record("phase \(snap.phase)") }
        // After the bite moment, the next chest, asleep again.
        let next: [HeistEvent] = run(s, seconds: 2.0, lid: lidAt(0.5))
        #expect(count(next, isArrived) == 1)
        #expect(next.contains(HeistEvent.stageChanged(from: .biting, to: .asleep)))
        #expect(s.snapshot.noise == 0)
        #expect(s.snapshot.stage == .asleep)
    }

    @Test func attractNeverBitesAndTheTorchNeverBurns() {
        let (s, _) = lootingSession(mode: .attract)
        let ev: [HeistEvent] = run(s, seconds: 30, lid: lidAt(0.5, speed: 150))
        #expect(count(ev, isBitten) == 0)
        #expect(s.snapshot.noise <= Tuning.noBiteCap + 1e-12)
        #expect(s.snapshot.stage == .waking)
        #expect(s.snapshot.torchRemaining == Tuning.torchSeconds)
        #expect(s.snapshot.hint == HeistHint.freeze)
        #expect(!s.isFinished)
    }

    @Test func optionsPerMode() {
        #expect(SessionOptions.for(.run) == SessionOptions())
        #expect(SessionOptions.for(.daily(day: 3, scored: true)) == SessionOptions())
        let a: SessionOptions = SessionOptions.for(.attract)
        #expect(!a.torch && !a.bites && a.noiseScale == 1 && a.fixedChest == nil)
        let l: SessionOptions = SessionOptions.for(.lesson)
        #expect(!l.torch && !l.bites)
        #expect(abs(l.noiseScale - 0.6) < 1e-12)
        guard let chest = l.fixedChest else {
            Issue.record("no lesson chest")
            return
        }
        #expect(chest.mimic == .heavySleeper)
        #expect(chest.items.count == 4)
        let coppers: Int = chest.items.filter { (it: LootItem) -> Bool in it.kind == .copper }.count
        let silvers: Int = chest.items.filter { (it: LootItem) -> Bool in it.kind == .silver }.count
        #expect(coppers == 2 && silvers == 1)
        // The lesson session deals it, and deals it again after a bank.
        let (s, _) = lootingSession(mode: .lesson)
        #expect(s.snapshot.chest?.items == chest.items)
        guard let k = shallowest(s.snapshot) else { return }
        // Its noise is scaled: a pick adds 0.02 × 0.7 × 0.6.
        _ = s.step(dt: 1.0 / 120.0, lid: lidAt(s.snapshot.loot[k].item.depth + 0.08))
        let ev: [HeistEvent] = s.touchBegan(id: 1, at: s.snapshot.loot[k].position, time: 0)
        #expect(!ev.isEmpty)
        #expect(abs(s.snapshot.noise - Tuning.pickNoise * 0.7 * 0.6) < 1e-9)
        _ = s.touchEnded(id: 1, at: CGPoint(x: 300, y: 400), time: 0.5)
        _ = run(s, seconds: 2.5, lid: lidAt(0.06))
        #expect(s.snapshot.chest?.index == 1)
        #expect(s.snapshot.chest?.items == chest.items)
    }

    @Test func torchBurnsOutAndTheRunFinishes() {
        let (s, _) = lootingSession(seed: 81)
        let ev: [HeistEvent] = run(s, seconds: 99, dt: 1.0 / 30.0, lid: lidAt(0.5))
        #expect(count(ev, isTorchLow) == 1)
        #expect(count(ev, isTorchOut) == 0)
        let ev2: [HeistEvent] = run(s, seconds: 2, dt: 1.0 / 30.0, lid: lidAt(0.5))
        #expect(count(ev2, isTorchOut) == 1)
        #expect(!s.isFinished)
        #expect(s.result == nil)
        let ev3: [HeistEvent] = run(s, seconds: 2.5, dt: 1.0 / 30.0, lid: lidAt(0.5))
        #expect(count(ev3, isFinishedEvent) == 1)
        #expect(s.isFinished)
        guard let r = s.result else {
            Issue.record("no result")
            return
        }
        #expect(r.gold == 0)
        #expect(r.chestsOpened == 1)
        // The chest the candle went out on is logged with nothing banked.
        #expect(r.chestLog == [ChestOutcome(tier: .wooden, golden: false, value: 0, hushed: false, bitten: false)])
        #expect(r.seed == 81)
        #expect(r.seconds > 100 && r.seconds < 104)
        #expect(s.step(dt: 1.0 / 60.0, lid: lidAt(0.5)).isEmpty)
    }

    @Test func torchOutLosesTheBag() {
        let (s, _) = lootingSession(seed: 82)
        guard let k = shallowest(s.snapshot) else { return }
        _ = bagItem(s, k)
        #expect(s.snapshot.bagValue > 0)
        _ = run(s, seconds: 104, dt: 1.0 / 30.0, lid: lidAt(0.5))
        #expect(s.isFinished)
        #expect(s.result?.gold == 0)
        #expect(s.result?.itemsBagged == 1)
    }

    @Test func oilAddsTorchWhenBagged() {
        guard let seed = firstSeed(where: { (c: ChestSpec) -> Bool in
            c.items.contains { (it: LootItem) -> Bool in it.kind == .oil }
        }) else {
            Issue.record("no oil chest")
            return
        }
        let (s, _) = lootingSession(seed: seed)
        guard let k = s.snapshot.loot.firstIndex(where: { (l: LootState) -> Bool in l.item.kind == .oil }) else { return }
        let torch0: Double = s.snapshot.torchRemaining
        let total0: Double = s.snapshot.torchTotal
        let ev: [HeistEvent] = bagItem(s, k)
        #expect(ev.contains(HeistEvent.oilAdded(seconds: Tuning.oilSeconds)))
        #expect(ev.contains(HeistEvent.itemBagged(id: s.snapshot.loot[k].item.id, kind: LootKind.oil, value: 0)))
        // bagItem stepped once (1/120 s) before the drag.
        #expect(abs(s.snapshot.torchRemaining - (torch0 - 1.0 / 120.0 + Tuning.oilSeconds)) < 1e-9)
        #expect(abs(s.snapshot.torchTotal - (total0 + Tuning.oilSeconds)) < 1e-9)
    }

    @Test func dreamersTwitchAndOthersDont() {
        guard let dreamSeed = firstSeed(where: { (c: ChestSpec) -> Bool in c.mimic == .dreamer }),
              let snoreSeed = firstSeed(where: { (c: ChestSpec) -> Bool in c.mimic == .snorer }) else {
            Issue.record("no seeds")
            return
        }
        let d: HeistSession = newSession(seed: dreamSeed)
        let ev: [HeistEvent] = run(d, seconds: 20, lid: lidAt(0))
        let n: Int = count(ev, isTwitch)
        #expect(n >= 2 && n <= 5, "twitches \(n)")
        #expect(d.snapshot.noise == 0)
        let s: HeistSession = newSession(seed: snoreSeed)
        let ev2: [HeistEvent] = run(s, seconds: 20, lid: lidAt(0))
        #expect(count(ev2, isTwitch) == 0)
    }

    @Test func firstChestIsNeverALightSleeper() {
        let lightSeed: UInt64? = firstSeed(where: { (c: ChestSpec) -> Bool in c.mimic == .lightSleeper })
        #expect(lightSeed == nil)
        // Later chests do deal them.
        var seen: Bool = false
        var seed: UInt64 = 1
        while seed < 200 && !seen {
            if ChestFactory.chest(seed: seed, index: 1, found: []).mimic == .lightSleeper { seen = true }
            seed += 1
        }
        #expect(seen)
    }

    @Test func personalitiesScaleTheNoise() {
        for kind in [MimicKind.heavySleeper, MimicKind.snorer, MimicKind.dreamer] {
            guard let seed = firstSeed(where: { (c: ChestSpec) -> Bool in c.mimic == kind }) else {
                Issue.record("no \(kind.rawValue) chest")
                continue
            }
            let (s, _) = lootingSession(seed: seed)
            guard let k = shallowest(s.snapshot) else { continue }
            _ = s.step(dt: 1.0 / 120.0, lid: lidAt(min(1, s.snapshot.loot[k].item.depth + 0.08)))
            _ = s.touchBegan(id: 1, at: s.snapshot.loot[k].position, time: 0)
            let expected: Double = Tuning.pickNoise * Noise.multiplier(for: kind)
            #expect(abs(s.snapshot.noise - expected) < 1e-9, "\(kind.rawValue)")
        }
    }

    @Test func newBestFiresOnceWhenPassed() {
        let (s, _) = lootingSession(seed: 91, best: 1)
        guard let k = shallowest(s.snapshot) else { return }
        _ = bagItem(s, k)
        let ev: [HeistEvent] = run(s, seconds: 0.5, dt: 1.0 / 120.0, lid: lidAt(0.06))
        #expect(ev.contains(HeistEvent.newBest))
        // No best yet (0): never.
        let (f, _) = lootingSession(seed: 91, best: 0)
        guard let k2 = shallowest(f.snapshot) else { return }
        _ = bagItem(f, k2)
        let ev2: [HeistEvent] = run(f, seconds: 0.5, dt: 1.0 / 120.0, lid: lidAt(0.06))
        #expect(!ev2.contains(HeistEvent.newBest))
        #expect(count(ev2, isBanked) == 1)
    }

    @Test func nudgeNoiseChangesTheStageOnTheNextStep() {
        let (s, _) = lootingSession(seed: 101)
        s.nudgeNoise(to: Tuning.lessonStirNoise)
        #expect(s.snapshot.stage == .stirring)
        let ev: [HeistEvent] = s.step(dt: 1.0 / 120.0, lid: lidAt(0.06))
        #expect(ev.contains(HeistEvent.stageChanged(from: .asleep, to: .stirring)))
    }

    @Test func hintPriority() {
        // tooWide beats easeLidDown; slower beats tooWide; freeze beats slower.
        let s: HeistSession = newSession(seed: 111)
        _ = s.step(dt: 1.0 / 120.0, lid: LidInput(openness: 1, speed: 0, inShutZone: false, tooWide: true))
        #expect(s.snapshot.hint == HeistHint.tooWide)
        _ = s.step(dt: 1.0 / 120.0, lid: LidInput(openness: 1, speed: 40, inShutZone: false, tooWide: true))
        #expect(s.snapshot.hint == HeistHint.slower)
        s.nudgeNoise(to: 0.8)
        _ = s.step(dt: 1.0 / 120.0, lid: LidInput(openness: 1, speed: 40, inShutZone: false, tooWide: true))
        #expect(s.snapshot.stage == .waking)
        #expect(s.snapshot.hint == HeistHint.freeze)
        // In the bank and bite moments: no hint.
        let (b, _) = lootingSession(seed: 112)
        guard let k = shallowest(b.snapshot) else { return }
        _ = bagItem(b, k)
        #expect(b.snapshot.hint == HeistHint.shutToBank)
        _ = run(b, seconds: 0.5, dt: 1.0 / 120.0, lid: lidAt(0.06))
        #expect(b.snapshot.hint == nil)
    }

    @Test func bigStepsSubStep() {
        let (s, _) = lootingSession(seed: 121)
        let t0: Double = s.snapshot.torchRemaining
        _ = s.step(dt: 0.5, lid: lidAt(0.3))
        #expect(abs(s.snapshot.torchRemaining - (t0 - 0.5)) < 1e-9)
        #expect(abs(s.snapshot.time - (0.5 + 1.0 / 120.0)) < 1e-9)
        _ = s.step(dt: -1, lid: lidAt(0.3))
        _ = s.step(dt: Double.nan, lid: lidAt(0.3))
        #expect(abs(s.snapshot.torchRemaining - (t0 - 0.5)) < 1e-9)
    }

    @Test func sessionsAreDeterministic() {
        func play(_ seed: UInt64) -> (RunResult?, Int) {
            let s = HeistSession(mode: .run, seed: seed, bestRun: 0, foundRelics: [], options: SessionOptions.for(.run))
            var pilot = ThiefPilot(skill: .casual, seed: seed &+ 3)
            var events: Int = 0
            var t: Double = 0
            var frames: Int = 0
            while !s.isFinished && frames < 60 * 400 {
                let out: PilotOutput = pilot.step(dt: 1.0 / 60.0, snapshot: s.snapshot)
                for touch in out.touches {
                    switch touch.phase {
                    case .began: events += s.touchBegan(id: touch.id, at: touch.point, time: t).count
                    case .moved: events += s.touchMoved(id: touch.id, to: touch.point, time: t).count
                    case .ended: events += s.touchEnded(id: touch.id, at: touch.point, time: t).count
                    }
                }
                events += s.step(dt: 1.0 / 60.0, lid: out.lid).count
                t += 1.0 / 60.0
                frames += 1
            }
            return (s.result, events)
        }
        let a = play(4242)
        let b = play(4242)
        #expect(a.0 != nil)
        #expect(a.0 == b.0)
        #expect(a.1 == b.1)
        #expect((a.0?.chestsBanked ?? 0) >= 1)
    }

    @Test func pilotPlaysAttractForever() {
        let s = HeistSession(mode: .attract, seed: 7, bestRun: 0, foundRelics: [], options: SessionOptions.for(.attract))
        var pilot = ThiefPilot(skill: .expert, seed: 7)
        var t: Double = 0
        var bitten: Int = 0
        while t < 120 {
            let out: PilotOutput = pilot.step(dt: 1.0 / 60.0, snapshot: s.snapshot)
            for touch in out.touches {
                switch touch.phase {
                case .began: _ = s.touchBegan(id: touch.id, at: touch.point, time: t)
                case .moved: _ = s.touchMoved(id: touch.id, to: touch.point, time: t)
                case .ended: _ = s.touchEnded(id: touch.id, at: touch.point, time: t)
                }
            }
            let ev: [HeistEvent] = s.step(dt: 1.0 / 60.0, lid: out.lid)
            bitten += count(ev, isBitten)
            t += 1.0 / 60.0
        }
        #expect(bitten == 0)
        #expect(!s.isFinished)
        #expect(s.snapshot.chestsBanked >= 4)
        #expect(s.snapshot.torchRemaining >= Tuning.torchSeconds)
    }

    // MARK: DailySeed

    @Test func dailySeed() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone.current
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 1
        comps.day = 1
        comps.hour = 9
        guard let d0 = cal.date(from: comps) else {
            Issue.record("no date")
            return
        }
        #expect(DailySeed.dayNumber(for: d0, calendar: cal) == 0)
        #expect(DailySeed.dayNumber(for: d0.addingTimeInterval(86_400), calendar: cal) == 1)
        #expect(DailySeed.dayNumber(for: d0.addingTimeInterval(86_400 * 300), calendar: cal) == 300)
        #expect(DailySeed.dayNumber(for: d0.addingTimeInterval(-86_400), calendar: cal) == -1)
        #expect(DailySeed.seed(day: 300) == DailySeed.seed(day: 300))
        #expect(DailySeed.seed(day: 300) != DailySeed.seed(day: 301))
    }

    // MARK: Ranks and achievements

    @Test func thiefRanks() {
        #expect(ThiefRanks.count == 12)
        #expect(ThiefRanks.rank(forLifetimeGold: 0) == 0)
        #expect(ThiefRanks.rank(forLifetimeGold: -5) == 0)
        #expect(ThiefRanks.title(0) == "Pickpocket")
        #expect(ThiefRanks.title(11) == "Mimic Whisperer")
        #expect(ThiefRanks.title(99) == "Mimic Whisperer")
        #expect(ThiefRanks.rank(forLifetimeGold: 10_000_000) == 11)
        var r: Int = 1
        while r < ThiefRanks.count {
            let th: Int = ThiefRanks.threshold(r)
            #expect(th > ThiefRanks.threshold(r - 1))
            #expect(ThiefRanks.rank(forLifetimeGold: th) == r)
            #expect(ThiefRanks.rank(forLifetimeGold: th - 1) == r - 1)
            r += 1
        }
        #expect(Set(ThiefRanks.titles).count == 12)
        // R2 thresholds (about one rank per run in a first session).
        #expect(ThiefRanks.thresholds == [0, 1_000, 3_000, 7_000, 14_000, 25_000, 42_000, 66_000, 100_000, 150_000,
                                          220_000, 320_000])
        #expect(ThiefRanks.rank(forLifetimeGold: 1_635) == 1)
        #expect(ThiefRanks.rank(forLifetimeGold: 1_635 + 2_500 + 3_945) == 3)
    }

    @Test func achievements() {
        #expect(Achievements.all.count == 12)
        let achIDs: Int = Set(Achievements.all.map { (a: AchievementDef) -> String in a.id }).count
        #expect(achIDs == 12)
        let prefixed: Bool = Achievements.all.allSatisfy { (a: AchievementDef) -> Bool in a.id.hasPrefix("hush.ach.") }
        #expect(prefixed)
        // The R2 swaps keep their Game Center ids (and Achievements.all order, which the badges use).
        #expect(Achievements.midasTouch.id == "hush.ach.royal" && Achievements.midasTouch.title == "Midas Touch")
        #expect(Achievements.hushChain.id == "hush.ach.hushhush" && Achievements.hushChain.title == "Hush Chain")
        #expect(Achievements.all[4] == Achievements.midasTouch && Achievements.all[8] == Achievements.hushChain)
        // A Royal chest and 3 Hushed chests no longer earn anything by themselves; 2,400 gold isn't a Heavy Bag now.
        let run = RunResult(mode: .run, seed: 1, gold: 2_400, seconds: 120, chestsOpened: 6, chestsBanked: 5,
                            hushed: 3, bites: 0, relics: [RelicID("relic01")], bestChestValue: 800, itemsBagged: 30,
                            highestTier: .royal, lostToBites: 0, bestChain: 4, goldenBanked: 0)
        let got: [AchievementDef] = Achievements.earned(after: run, lifetimeGold: 2_400, relicsFound: 1,
                                                        alreadyEarned: [])
        let ids: Set<String> = Set(got.map { (a: AchievementDef) -> String in a.id })
        let expected: Set<String> = [Achievements.firstHaul.id, Achievements.notAPeep.id, Achievements.firstRelic.id,
                                     Achievements.fiveChests.id, Achievements.untouchable.id]
        #expect(ids == expected)
        let again: [AchievementDef] = Achievements.earned(after: run, lifetimeGold: 2_400, relicsFound: 1,
                                                          alreadyEarned: ids)
        #expect(again.isEmpty)
        // R2 thresholds and the new two.
        var big: RunResult = run
        big.gold = 8_000
        big.goldenBanked = 1
        big.bestChain = Tuning.chainMax
        let bigIDs: Set<String> = Set(Achievements.earned(after: big, lifetimeGold: 8_000, relicsFound: 1,
                                                          alreadyEarned: ids).map { (a: AchievementDef) -> String in a.id })
        let expectedBig: Set<String> = [Achievements.heavyBag.id, Achievements.hoard.id, Achievements.midasTouch.id,
                                        Achievements.hushChain.id]
        #expect(bigIDs == expectedBig)
        var justUnder: RunResult = run
        justUnder.gold = 2_999
        let underIDs: Set<String> = Set(Achievements.earned(after: justUnder, lifetimeGold: 49_999, relicsFound: 11,
                                                            alreadyEarned: ids).map { (a: AchievementDef) -> String in a.id })
        #expect(underIDs.isEmpty)
        var attract: RunResult = big
        attract.mode = .attract
        #expect(Achievements.earned(after: attract, lifetimeGold: 99_999, relicsFound: 24, alreadyEarned: []).isEmpty)
        let late: [AchievementDef] = Achievements.earned(after: run, lifetimeGold: 50_000, relicsFound: 24,
                                                         alreadyEarned: ids)
        let lateIDs: Set<String> = Set(late.map { (a: AchievementDef) -> String in a.id })
        let expectedLate: Set<String> = [Achievements.curator.id, Achievements.fullCodex.id, Achievements.fortune.id]
        #expect(lateIDs == expectedLate)
    }

    // MARK: R2 rules

    @Test func hushChainPaysAndBreaksTheMomentTheMimicStirs() {
        let (s, _) = lootingSession(seed: 131)
        #expect(s.snapshot.chain == 0)
        #expect(abs(s.snapshot.chainMultiplier - Noise.chainMultiplier(1)) < 1e-12)
        // Two Hushed banks: ×1.1, then ×1.2.
        let (v1, ev1) = bankOne(s)
        #expect(ev1.contains(HeistEvent.banked(value: Int((Double(v1) * Noise.chainMultiplier(1)).rounded()), items: 1,
                                               hushed: true)))
        #expect(ev1.contains(HeistEvent.chainUp(count: 1, multiplier: Noise.chainMultiplier(1))))
        // chainUp comes right after banked.
        if let bi = ev1.firstIndex(where: isBanked), bi + 1 < ev1.count {
            #expect(isChainUp(ev1[bi + 1]))
        } else {
            Issue.record("no bank: \(ev1)")
        }
        #expect(s.snapshot.chain == 1)
        nextChestLooting(s)
        #expect(abs(s.snapshot.chainMultiplier - Noise.chainMultiplier(2)) < 1e-12)
        let (v2, ev2) = bankOne(s)
        #expect(ev2.contains(HeistEvent.banked(value: Int((Double(v2) * Noise.chainMultiplier(2)).rounded()), items: 1,
                                               hushed: true)))
        #expect(ev2.contains(HeistEvent.chainUp(count: 2, multiplier: Noise.chainMultiplier(2))))
        #expect(s.snapshot.chain == 2)
        nextChestLooting(s)
        // A stir breaks it at once (the event comes with the next step), and this chest pays ×1.
        s.nudgeNoise(to: 0.4)
        #expect(s.snapshot.chain == 0)
        #expect(s.snapshot.chainMultiplier == 1)
        let ev3: [HeistEvent] = s.step(dt: 1.0 / 120.0, lid: lidAt(0.06))
        #expect(ev3.contains(HeistEvent.chainBroken(count: 2)))
        let (v3, ev4) = bankOne(s)
        #expect(ev4.contains(HeistEvent.banked(value: v3, items: 1, hushed: false)))
        #expect(count(ev4, isChainUp) == 0)
        #expect(count(ev4, isChainBroken) == 0)
        let r: RunResult = s.partialResult()
        #expect(r.bestChain == 2)
        #expect(r.hushed == 2)
        #expect(r.chestsBanked == 3)
        // A chain of 1 breaks silently.
        nextChestLooting(s)
        _ = bankOne(s)
        nextChestLooting(s)
        #expect(s.snapshot.chain == 1)
        s.nudgeNoise(to: 0.4)
        let ev5: [HeistEvent] = s.step(dt: 1.0 / 120.0, lid: lidAt(0.06))
        #expect(count(ev5, isChainBroken) == 0)
        #expect(s.snapshot.chain == 0)
    }

    @Test func aBiteBreaksTheChainAndIsLogged() {
        let (s, _) = lootingSession(seed: 141)
        _ = bankOne(s)
        nextChestLooting(s)
        _ = bankOne(s)
        nextChestLooting(s)
        #expect(s.snapshot.chain == 2)
        guard let k = shallowest(s.snapshot), let chest = s.snapshot.chest else {
            Issue.record("empty chest")
            return
        }
        _ = bagItem(s, k)
        let inHand: Int = s.snapshot.bagValue
        var ev: [HeistEvent] = []
        var t: Double = 0
        while t < 1.0 && count(ev, isBitten) == 0 {
            ev.append(contentsOf: s.step(dt: 1.0 / 60.0, lid: lidAt(0.5, speed: 150)))
            t += 1.0 / 60.0
        }
        #expect(ev.contains(HeistEvent.bitten(lostValue: inHand)))
        #expect(ev.contains(HeistEvent.chainBroken(count: 2)))
        #expect(s.snapshot.chain == 0)
        let r: RunResult = s.partialResult()
        #expect(r.chestLog.count == 3)
        #expect(r.chestLog.last == ChestOutcome(tier: chest.tier, golden: chest.golden, value: 0, hushed: false,
                                                bitten: true))
        #expect(r.bestChain == 2)
        #expect(r.lostToBites == inHand)
    }

    @Test func bagJingleFloorsTheDecay() {
        let (s, _) = lootingSession(seed: 151)
        guard let chest = s.snapshot.chest else {
            Issue.record("no chest")
            return
        }
        let dealt: [LootState] = s.snapshot.loot
        let order: [Int] = dealt.indices.sorted { (a: Int, b: Int) -> Bool in dealt[a].item.depth < dealt[b].item.depth }
        guard order.count >= 2 else {
            Issue.record("too few items")
            return
        }
        #expect(s.snapshot.noiseFloor == 0)
        _ = bagItem(s, order[0], touchID: 1)
        _ = bagItem(s, order[1], touchID: 2)
        let open: LidInput = lidAt(0.5)
        _ = s.step(dt: 1.0 / 120.0, lid: open)
        let floor: Double = Noise.jingleFloor(items: 2, multiplier: Noise.multiplier(for: chest.mimic))
        #expect(floor > 0)
        #expect(abs(s.snapshot.noiseFloor - floor) < 1e-12)
        // Decay stops at the floor …
        s.nudgeNoise(to: 0.25)
        _ = run(s, seconds: 6, lid: open)
        #expect(abs(s.snapshot.noise - floor) < 1e-9, "noise \(s.snapshot.noise) floor \(floor)")
        #expect(s.snapshot.stage == .asleep)
        // … and never pushes the noise up to it.
        s.nudgeNoise(to: floor / 2)
        _ = run(s, seconds: 1, lid: open)
        #expect(abs(s.snapshot.noise - floor / 2) < 1e-9)
        // Outside play the snapshot reports no floor.
        _ = run(s, seconds: 0.5, dt: 1.0 / 120.0, lid: lidAt(0.06))
        if case .banked = s.snapshot.phase {
            #expect(s.snapshot.noiseFloor == 0)
        } else {
            Issue.record("not banked: \(s.snapshot.phase)")
        }
    }

    @Test func goldenMimicsAreRareLateAndRich() {
        var golden: Int = 0
        var late: Int = 0
        var early: Int = 0
        var bad: Int = 0
        var goldenSpec: ChestSpec? = nil
        var seed: UInt64 = 1
        while seed <= 300 {
            var index: Int = 0
            while index <= 9 {
                let c: ChestSpec = ChestFactory.chest(seed: seed, index: index, found: [])
                if c.golden != ChestFactory.isGolden(seed: seed, index: index) { bad += 1 }
                if index >= Tuning.goldenFromIndex { late += 1 }
                if c.golden {
                    golden += 1
                    if index < Tuning.goldenFromIndex { early += 1 }
                    if c.multiplier != ChestFactory.multiplier(for: c.tier) * Tuning.goldenValueMultiplier { bad += 1 }
                    if !MimicNames.goldenNames.contains(c.mimicName) { bad += 1 }
                    if goldenSpec == nil { goldenSpec = c }
                } else if c.multiplier != ChestFactory.multiplier(for: c.tier) {
                    bad += 1
                }
                index += 1
            }
            seed += 1
        }
        #expect(bad == 0)
        #expect(early == 0)
        let rate: Double = Double(golden) / Double(max(late, 1))
        #expect(rate > 0.035 && rate < 0.09, "golden rate \(rate)")
        // Its noise is ×1.25 and its loot ×2.
        guard let spec = goldenSpec else {
            Issue.record("no golden chest")
            return
        }
        let (s, _) = lootingSession(seed: 5, options: SessionOptions(fixedChest: spec))
        #expect(s.snapshot.chest?.golden == true)
        guard let k = shallowest(s.snapshot) else { return }
        let item: LootItem = s.snapshot.loot[k].item
        _ = s.step(dt: 1.0 / 120.0, lid: lidAt(min(1, item.depth + 0.08)))
        _ = s.touchBegan(id: 1, at: s.snapshot.loot[k].position, time: 0)
        let expected: Double = Tuning.pickNoise * Noise.multiplier(for: spec.mimic) * Tuning.goldenNoiseMultiplier
        #expect(abs(s.snapshot.noise - expected) < 1e-9)
        let ev: [HeistEvent] = s.touchEnded(id: 1, at: CGPoint(x: 300, y: 400), time: 0.5)
        let v: Int = Int((Double(item.value) * spec.multiplier).rounded())
        #expect(ev.first == HeistEvent.itemBagged(id: item.id, kind: item.kind, value: v))
        _ = run(s, seconds: 0.5, dt: 1.0 / 120.0, lid: lidAt(0.06))
        #expect(s.partialResult().goldenBanked == 1)
        #expect(s.partialResult().chestLog.first?.golden == true)
    }

    @Test func relicGlimmerHintsAtADeepRelic() {
        #expect(HeistSession.relicGlimmers(depth: 0.84, openness: 0.70))
        #expect(HeistSession.relicGlimmers(depth: 0.84, openness: 0.64))
        #expect(!HeistSession.relicGlimmers(depth: 0.84, openness: 0.60))
        #expect(!HeistSession.relicGlimmers(depth: 0.84, openness: 0.89))
        #expect(!HeistSession.relicGlimmers(depth: Double.nan, openness: 0.7))
        let relic = LootItem(id: 0, kind: .relic(RelicID("relic03")), value: 300, depth: 0.84,
                             position: CGPoint(x: 335, y: 80), radius: Tuning.relicRadius, rotation: 0)
        let spec = ChestSpec(index: 0, tier: .iron, mimic: .snorer, mimicName: "Snoring Sam",
                             multiplier: Tuning.ironMultiplier, decay: Tuning.ironDecay, items: [relic])
        let (s, _) = lootingSession(options: SessionOptions(fixedChest: spec))
        _ = s.step(dt: 1.0 / 120.0, lid: lidAt(0.5))
        #expect(s.snapshot.hint == HeistHint.openSlowly)
        _ = s.step(dt: 1.0 / 120.0, lid: lidAt(0.7))
        #expect(s.snapshot.hint == HeistHint.relicDeeper)
        _ = s.step(dt: 1.0 / 120.0, lid: lidAt(0.96))
        #expect(s.snapshot.hint == HeistHint.dragToBag)
        // A relic deeper than R2's 0.88 isn't dealt any more.
        var deepest: Double = 0
        var seed: UInt64 = 1
        while seed <= 80 {
            var index: Int = 2
            while index <= 8 {
                for it in ChestFactory.chest(seed: seed, index: index, found: []).items {
                    if case .relic = it.kind { deepest = max(deepest, it.depth) }
                }
                index += 1
            }
            seed += 1
        }
        #expect(deepest > 0.8 && deepest <= 0.88)
    }

    @Test func candleLowHintWithLootInTheBag() {
        let (s, _) = lootingSession(seed: 191)
        guard let k = shallowest(s.snapshot) else { return }
        _ = bagItem(s, k)
        let open: LidInput = lidAt(0.5)
        run(s, seconds: s.snapshot.torchRemaining - Tuning.torchLowSeconds - 1, dt: 1.0 / 30.0, lid: open)
        #expect(s.snapshot.hint == HeistHint.shutToBank)
        run(s, seconds: 2, dt: 1.0 / 30.0, lid: open)
        #expect(s.snapshot.torchRemaining <= Tuning.torchLowSeconds)
        #expect(s.snapshot.hint == HeistHint.candleLow)
        // Slower and Freeze still come first.
        _ = s.step(dt: 1.0 / 120.0, lid: lidAt(0.5, speed: 40))
        #expect(s.snapshot.hint == HeistHint.slower)
        // An empty bag: no candleLow.
        let (e, _) = lootingSession(seed: 191)
        run(e, seconds: 87, dt: 1.0 / 30.0, lid: open)
        #expect(e.snapshot.torchRemaining <= Tuning.torchLowSeconds)
        #expect(e.snapshot.hint != HeistHint.candleLow)
    }

    @Test func restOnlyLetsTheMimicSettle() {
        let (s, _) = lootingSession(seed: 171)
        s.nudgeNoise(to: 0.6)
        _ = s.step(dt: 1.0 / 120.0, lid: lidAt(0.3, speed: 20))
        let before: HeistSnapshot = s.snapshot
        #expect(before.stage == .stirring)
        #expect(before.lidSpeed == 20)
        let ev: [HeistEvent] = s.rest(dt: 10)
        let snap: HeistSnapshot = s.snapshot
        #expect(ev == [HeistEvent.stageChanged(from: .stirring, to: .asleep)])
        #expect(snap.noise < 0.05)
        #expect(snap.stage == .asleep)
        #expect(snap.torchRemaining == before.torchRemaining)
        #expect(snap.time == before.time)
        #expect(snap.lidSpeed == 0)
        #expect(snap.phase == .looting)
        #expect(s.rest(dt: -1).isEmpty)
        #expect(s.rest(dt: Double.nan).isEmpty)
        // It stops at the bag jingle floor too.
        guard let k = shallowest(s.snapshot), let chest = s.snapshot.chest else { return }
        _ = bagItem(s, k)
        _ = s.step(dt: 1.0 / 120.0, lid: lidAt(0.5))
        s.nudgeNoise(to: 0.3)
        s.rest(dt: 8)
        let floor: Double = Noise.jingleFloor(items: 1, multiplier: Noise.multiplier(for: chest.mimic))
        #expect(abs(s.snapshot.noise - floor) < 1e-9)
        // Nothing happens in a moment: the bank moment doesn't advance.
        _ = run(s, seconds: 0.5, dt: 1.0 / 120.0, lid: lidAt(0.06))
        let moment: RunPhase = s.snapshot.phase
        if case .banked = moment {} else { Issue.record("phase \(moment)") }
        #expect(s.rest(dt: 5).isEmpty)
        #expect(s.snapshot.phase == moment)
        // Even a very loud mimic only settles: no bite while resting.
        let (b, _) = lootingSession(seed: 172)
        b.nudgeNoise(to: 0.95)
        let restEvents: [HeistEvent] = b.rest(dt: 3)
        #expect(count(restEvents, isBitten) == 0)
        let onlyStages: Bool = restEvents.allSatisfy { (e: HeistEvent) -> Bool in
            if case .stageChanged = e { return true }
            return false
        }
        #expect(onlyStages)
        #expect(b.snapshot.bites == 0)
    }

    @Test func resumeGraceIgnoresTheLidForAMoment() {
        // 25 °/s is above the quiet line (noisy in play) but under loudSpeed: the grace forgives it.
        let (s, _) = lootingSession(seed: 181)
        s.resumeGrace(seconds: 0.5)
        _ = s.step(dt: 0.4, lid: lidAt(0.5, speed: 25))
        #expect(s.snapshot.noise == 0)
        #expect(s.snapshot.hint != HeistHint.slower)
        _ = s.step(dt: 0.3, lid: lidAt(0.5, speed: 40))
        #expect(s.snapshot.noise > 0)
        #expect(s.snapshot.hint == HeistHint.slower)
        // Bad values are ignored; a shorter grace doesn't cut a longer one.
        s.resumeGrace(seconds: Double.nan)
        s.resumeGrace(seconds: -3)
        let n0: Double = s.snapshot.noise
        _ = s.step(dt: 0.1, lid: lidAt(0.5, speed: 40))
        #expect(s.snapshot.noise > n0)
        s.resumeGrace(seconds: 1)
        s.resumeGrace(seconds: 0.1)
        let n1: Double = s.snapshot.noise
        _ = s.step(dt: 0.5, lid: lidAt(0.5, speed: 25))
        #expect(s.snapshot.noise <= n1)
    }

    /// R3 (QA-2 P2-9): a pause can't buy a silent fling. A short loud blip is still forgiven, but once the lid has
    /// been above loudSpeed for more than `Tuning.resumeGraceLoudLimit` of the grace, the grace ends.
    @Test func resumeGraceEndsOnASustainedLoudLid() {
        #expect(Tuning.resumeGraceLoudLimit == 0.15)
        // A 0.1 s blip at 120 °/s, then still: forgiven, and the grace runs on.
        let (b, _) = lootingSession(seed: 181)
        b.resumeGrace(seconds: 0.5)
        _ = b.step(dt: 0.1, lid: lidAt(0.5, speed: 120))
        _ = b.step(dt: 0.2, lid: lidAt(0.5))
        #expect(b.snapshot.noise == 0)
        _ = b.step(dt: 0.1, lid: lidAt(0.5, speed: 25))
        #expect(b.snapshot.noise == 0)
        // A fling at 40 °/s: free for 0.1 s, then the grace ends and the lid counts (and "Slower…" shows).
        let (f, _) = lootingSession(seed: 181)
        f.resumeGrace(seconds: 0.5)
        _ = f.step(dt: 0.1, lid: lidAt(0.5, speed: 40))
        #expect(f.snapshot.noise == 0)
        #expect(f.snapshot.hint != HeistHint.slower)
        _ = f.step(dt: 0.15, lid: lidAt(0.5, speed: 40))
        #expect(f.snapshot.noise > 0)
        #expect(f.snapshot.hint == HeistHint.slower)
        // Once ended it stays ended: slow motion is heard again before the 0.5 s are up.
        let n0: Double = f.snapshot.noise
        _ = f.step(dt: 0.1, lid: lidAt(0.5, speed: 25))
        #expect(f.snapshot.noise > n0)
        // A fresh grace starts its loud count from zero.
        let (g, _) = lootingSession(seed: 181)
        g.resumeGrace(seconds: 0.5)
        _ = g.step(dt: 0.1, lid: lidAt(0.5, speed: 40))
        _ = g.step(dt: 0.5, lid: lidAt(0.5))
        g.resumeGrace(seconds: 0.5)
        _ = g.step(dt: 0.1, lid: lidAt(0.5, speed: 40))
        #expect(g.snapshot.noise == 0)
    }

    /// R3 (ROUND-3 decision 2): a pause is no stepping, and noise is frozen across it. However long the pause, the
    /// noise, the stage, the candle and the clock are exactly where they were, and play carries on from there
    /// exactly as if there had been no pause. Closing the lid is no free way to calm the mimic (REVIEW-2-duo P2-5).
    @Test func noiseIsFrozenAcrossAPause() {
        let (s, _) = lootingSession(seed: 171)
        let (twin, _) = lootingSession(seed: 171)
        s.nudgeNoise(to: 0.6)
        twin.nudgeNoise(to: 0.6)
        _ = s.step(dt: 1.0 / 120.0, lid: lidAt(0.3))
        _ = twin.step(dt: 1.0 / 120.0, lid: lidAt(0.3))
        let before: HeistSnapshot = s.snapshot
        #expect(before.stage == .stirring)
        #expect(abs(before.noise - 0.6) < 1e-9)
        // The pause: N seconds (here 30) in which the App neither steps nor rests the session. Nothing moves.
        let pauseSeconds: Double = 30
        let after: HeistSnapshot = s.snapshot
        #expect(after == before)
        #expect(after.noise == before.noise)
        #expect(after.stage == .stirring)
        #expect(after.torchRemaining == before.torchRemaining)
        #expect(after.time == before.time)
        // Resume (the App's grace) and carry on with a still lid: identical to the twin that never paused.
        s.resumeGrace(seconds: 0.5)
        _ = run(s, seconds: 1, dt: 1.0 / 120.0, lid: lidAt(0.3))
        _ = run(twin, seconds: 1, dt: 1.0 / 120.0, lid: lidAt(0.3))
        #expect(s.snapshot == twin.snapshot)
        // Only that 1 s of play decayed it (0.3 s grace, then ≈ 0.7 s × 0.16/s).
        #expect(s.snapshot.noise > 0.45)
        #expect(s.snapshot.stage == .stirring)
        // What resting through the same pause would have done instead (why the App no longer calls `rest`).
        let (r, _) = lootingSession(seed: 171)
        r.nudgeNoise(to: 0.6)
        _ = r.step(dt: 1.0 / 120.0, lid: lidAt(0.3))
        r.rest(dt: pauseSeconds)
        #expect(r.snapshot.noise < Tuning.stirringNoise)
        #expect(r.snapshot.stage == .asleep)
    }

    @Test func chestLogAndPartialResult() {
        let (s, _) = lootingSession(seed: 201)
        let (_, ev) = bankOne(s)
        guard let paid = bankedValue(ev) else {
            Issue.record("no bank")
            return
        }
        nextChestLooting(s)
        #expect(s.result == nil)
        let p: RunResult = s.partialResult()
        #expect(p.chestsOpened == 2)
        #expect(p.chestsBanked == 1)
        #expect(p.gold == paid)
        #expect(p.bestChain == 1)
        #expect(p.chestLog.count == 2)
        #expect(p.chestLog.first == ChestOutcome(tier: .wooden, golden: false, value: paid, hushed: true, bitten: false))
        #expect(p.chestLog.last?.value == 0)
        #expect(p.chestLog.last?.bitten == false)
        // Play out: the candle goes out on the open chest.
        run(s, seconds: 110, dt: 1.0 / 30.0, lid: lidAt(0.5))
        #expect(s.isFinished)
        guard let r = s.result else {
            Issue.record("no result")
            return
        }
        #expect(r.chestLog.count == r.chestsOpened)
        #expect(r.chestLog.last?.value == 0)
        let logged: Int = r.chestLog.reduce(0) { (a: Int, c: ChestOutcome) -> Int in a + c.value }
        #expect(logged == r.gold)
        #expect(s.partialResult() == r)
    }

    /// R4: no loot is dealt under the phone's pause coin (Tuning.lootKeepOut, plus the item's radius and the gap),
    /// in any chest; the lesson's fixed chest is clear of it too.
    @Test func lootStaysOutOfThePauseCoinCorner() {
        let keep: CGRect = Tuning.lootKeepOut
        #expect(keep == CGRect(x: 540, y: 0, width: 130, height: 112))
        func clearance(_ it: LootItem) -> Double {
            let x: Double = Double(it.position.x)
            let y: Double = Double(it.position.y)
            let dx: Double = x - min(max(x, Double(keep.minX)), Double(keep.maxX))
            let dy: Double = y - min(max(y, Double(keep.minY)), Double(keep.maxY))
            return (dx * dx + dy * dy).squareRoot() - Double(it.radius) - Tuning.lootGap
        }
        var inside: Int = 0
        var items: Int = 0
        var seed: UInt64 = 1
        while seed <= 120 {
            var index: Int = 0
            while index <= 10 {
                for it in ChestFactory.chest(seed: seed, index: index, found: []).items {
                    items += 1
                    if clearance(it) < -0.001 { inside += 1 }
                }
                index += 1
            }
            seed += 1
        }
        #expect(items > 5_000)
        #expect(inside == 0)
        let lessonClear: Bool = ChestFactory.lessonChest().items.allSatisfy { (it: LootItem) -> Bool in
            clearance(it) >= 0
        }
        #expect(lessonClear)
    }
}

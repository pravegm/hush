import CoreGraphics
import Foundation
import Testing
@testable import Hush

// MARK: - Core rules (Round 1, updated for Round 2: R2 tuning, Hush Chain, golden mimic, relic glimmer, bag jingle,
// rest / resumeGrace / partialResult, biteCost, chestLog, candleLow / relicDeeper hints; and Round 3: noise frozen
// across a pause, the resume grace ends on a sustained loud lid; and Round 7 "real hands": quiet 14 / close 28, the
// loud onset, the fresh chest, LidSensitivity)

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
        // R2 (REVIEW-1-feel #1): 0.008·x + 0.0004·x² above the quiet line; R7: the line is 14 °/s (R2: 12).
        #expect(Noise.lidRate(speed: 0) == 0)
        #expect(Noise.lidRate(speed: 10) == 0)
        #expect(Noise.lidRate(speed: 12) == 0)
        #expect(Noise.lidRate(speed: 14) == 0)
        #expect(Noise.lidRate(speed: 14.5) > 0)
        #expect(abs(Noise.lidRate(speed: 20) - 0.0624) < 1e-9)   // 0.008·6 + 0.0004·36
        #expect(abs(Noise.lidRate(speed: 40) - 0.4784) < 1e-9)   // 0.008·26 + 0.0004·676
        // R7: a 50 °/s full open (65° in 1.3 s) bites a Snorer; 45 °/s no longer does (R2: it did).
        #expect(Noise.lidRate(speed: 50) * (Tuning.lidTravel / 50) >= 1)
        #expect(Noise.lidRate(speed: 45) * (Tuning.lidTravel / 45) < 1)
        let slam: Double = Noise.lidRate(speed: 120) * 0.4
        #expect(slam >= 2.1 && slam < 2.15)
        #expect(Noise.lidRate(speed: 30) > Noise.lidRate(speed: 20))
        #expect(Noise.lidRate(speed: Double.nan) == 0)
        #expect(Noise.lidRate(speed: Double.nan, closing: true) == 0)
    }

    @Test func closingIsQuieterThanOpening() {
        // R2 (REVIEW-1-feel #2): closing has its own, higher quiet line. R7: 28 °/s (R2: 18), since a real slow close
        // runs at 25–60 °/s (DEVICE-RISKS-1 item 1).
        #expect(Noise.quietSpeed(closing: false) == Tuning.quietSpeed)
        #expect(Noise.quietSpeed(closing: true) == Tuning.closeQuietSpeed)
        #expect(Noise.lidRate(speed: 20) > 0)
        #expect(Noise.lidRate(speed: 20, closing: true) == 0)
        #expect(Noise.lidRate(speed: 28, closing: true) == 0)
        #expect(Noise.lidRate(speed: 35, closing: true) > 0)
        #expect(Noise.lidRate(speed: 35, closing: true) < Noise.lidRate(speed: 35))
        // In a session the direction comes from the openness: opening at 20 °/s is heard, closing at 20 °/s isn't.
        let (a, _) = lootingSession(seed: 161)
        var o: Double = 0.06
        for _ in 0..<60 {
            o += 20.0 / Tuning.lidTravel / 60.0
            _ = a.step(dt: 1.0 / 60.0, lid: lidAt(o, speed: 20))
        }
        #expect(a.snapshot.noise > 0.02)
        let (b, _) = lootingSession(seed: 161)
        _ = b.step(dt: 1.0 / 120.0, lid: lidAt(0.9))
        var p: Double = 0.9
        for _ in 0..<60 {
            p -= 20.0 / Tuning.lidTravel / 60.0
            _ = b.step(dt: 1.0 / 60.0, lid: lidAt(p, speed: 20))
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
        // R7 (ROUND-7 Core item 1): 12 → 14 and 18 → 28, with a 0.08 s loud onset.
        #expect(Tuning.quietSpeed == 14 && Tuning.closeQuietSpeed == 28)
        #expect(Tuning.loudOnsetSeconds == 0.08)
        #expect(Tuning.loudSpeed == 30)
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
        // R13 (the phone is the chest): the closing pause is the phone shut, 12° (was 70°), inside the hinge's 15° shut
        // zone; the game's own lid scale (100…165°, shut zone 110°) is unchanged, and the hinge's °/s maps onto it.
        #expect(Tuning.closingAngle == 12)
        #expect(Tuning.hingeShutAngle == 0 && Tuning.hingeWideAngle == 150 && Tuning.hingeTravel == 150)
        #expect(Tuning.hingeShutZoneAngle == 15 && Tuning.closingAngle < Tuning.hingeShutZoneAngle)
        #expect(Tuning.hingeTooWideAngle == Tuning.tooWideAngle)
        #expect(abs(Tuning.hingeSpeedScale - 65.0 / 150.0) < 1e-12)
        #expect(Tuning.shutAngle == 100 && Tuning.wideAngle == 165 && Tuning.shutZoneAngle == 110)
        #expect(Lid.hingeOpenness(angle: 0) == 0 && Lid.hingeOpenness(angle: 75) == 0.5)
        #expect(Lid.hingeOpenness(angle: 150) == 1 && Lid.hingeOpenness(angle: 170) == 1)
        #expect(Lid.hingeOpenness(angle: .nan) == 0 && abs(Lid.hingeAngle(openness: 0.1) - 15) < 1e-9)
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

    /// R12: only the lesson kept the shut-first gate. R13 (founder: "open means open and closed means closed"): the gate
    /// is gone. R14 (founder: "playing starts with the chest closed"): every first chest starts closed, the lesson's
    /// like a run's: open at the start it waits for the shut zone ("Close the phone to start"), dark and silent, then
    /// opens with the phone; from shut it opens on the first opening.
    @Test func theLessonChestStartsClosedThenOpensWithTheLid() {
        let s: HeistSession = newSession(mode: .lesson)
        #expect(s.snapshot.phase == .ready)
        #expect(s.snapshot.chest?.index == 0)
        #expect(s.awaitsFirstShut)
        // Lid open at the start: the lesson's chest waits, closed, for the close.
        let ev: [HeistEvent] = s.step(dt: 1.0 / 60.0, lid: lidAt(0.5))
        #expect(count(ev, isArrived) == 1)
        #expect(s.snapshot.phase == .ready)
        #expect(count(ev, isCracked) == 0)
        #expect(s.snapshot.hint == HeistHint.easeLidDown)
        #expect(s.awaitsFirstShut)
        #expect(s.snapshot.loot.allSatisfy { (l: LootState) -> Bool in l.light == 0 && !l.grabbable })
        // Moving the open lid makes no noise before the chest is opened.
        _ = run(s, seconds: 0.5, lid: lidAt(0.6, speed: 60))
        #expect(s.snapshot.noise < 0.001)
        #expect(s.snapshot.phase == .ready)
        // Closed to the shut zone, then reopened: it opens with the phone.
        _ = run(s, seconds: 0.2, lid: lidAt(0.0))
        #expect(!s.awaitsFirstShut)
        #expect(s.snapshot.hint != HeistHint.easeLidDown)
        let ev1: [HeistEvent] = s.step(dt: 1.0 / 60.0, lid: lidAt(0.1))
        #expect(s.snapshot.phase == .looting)
        #expect(count(ev1, isCracked) == 1)
        let ev1b: [HeistEvent] = s.step(dt: 1.0 / 60.0, lid: lidAt(0.15))
        #expect(count(ev1b, isCracked) == 0)
        // Lid shut at the start: closed and dark, "Open the phone… slowly", then it opens with the phone.
        let t: HeistSession = newSession(mode: .lesson)
        _ = t.step(dt: 1.0 / 60.0, lid: lidAt(0.0))
        #expect(t.snapshot.phase == .ready)
        #expect(t.snapshot.hint == HeistHint.openSlowly)
        let allDark: Bool = t.snapshot.loot.allSatisfy { (l: LootState) -> Bool in l.light == 0 && !l.grabbable }
        #expect(allDark)
        let ev2: [HeistEvent] = t.step(dt: 1.0 / 60.0, lid: lidAt(0.10))
        #expect(t.snapshot.phase == .looting)
        #expect(count(ev2, isCracked) == 1)
        let ev3: [HeistEvent] = t.step(dt: 1.0 / 60.0, lid: lidAt(0.2))
        #expect(count(ev3, isCracked) == 0)
        // R14: "Close the phone to start" exactly while the first chest is open before it was seen shut.
        for o in [0.0, 0.1, 0.3, 0.9] {
            let u: HeistSession = newSession(mode: .lesson)
            _ = u.step(dt: 1.0 / 60.0, lid: lidAt(o))
            let shutZone: Bool = Lid.input(openness: o, speed: 0).inShutZone
            #expect((u.snapshot.hint == HeistHint.easeLidDown) == !shutZone, "\(o)")
        }
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
        // A loud lid stops the decay and adds noise (R7: once past its 0.08 s onset).
        let before: Double = s.snapshot.noise
        _ = s.step(dt: 0.3, lid: lidAt(0.4, speed: 30))
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
        // After the bite moment (R12): the lid is open, so the robbed chest waits, asleep again; closing deals the next.
        let after: [HeistEvent] = run(s, seconds: 2.0, lid: lidAt(0.5))
        #expect(count(after, isArrived) == 0)
        #expect(after.contains(HeistEvent.stageChanged(from: .biting, to: .asleep)))
        #expect(s.snapshot.noise == 0)
        #expect(s.snapshot.stage == .asleep)
        #expect(s.awaitingClose)
        let next: [HeistEvent] = s.step(dt: 1.0 / 60.0, lid: lidAt(0.06))
        #expect(count(next, isArrived) == 1)
        #expect(!s.awaitingClose)
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
        // R14: the run's first chest waits for the close with the lid up: "Close the phone to start" beats tooWide
        // (and a fast lid there is silent, so it beats slower too).
        let s: HeistSession = newSession(seed: 111)
        _ = s.step(dt: 1.0 / 120.0, lid: LidInput(openness: 1, speed: 0, inShutZone: false, tooWide: true))
        #expect(s.snapshot.hint == HeistHint.easeLidDown)
        _ = s.step(dt: 1.0 / 120.0, lid: LidInput(openness: 1, speed: 40, inShutZone: false, tooWide: true))
        #expect(s.snapshot.hint == HeistHint.easeLidDown)
        #expect(s.snapshot.phase == .ready)
        // Seen shut, then reopened wide: looting. Slower beats tooWide; freeze beats slower.
        _ = s.step(dt: 1.0 / 120.0, lid: LidInput(openness: 0, speed: 0, inShutZone: true, tooWide: false))
        _ = s.step(dt: 1.0 / 120.0, lid: LidInput(openness: 1, speed: 0, inShutZone: false, tooWide: true))
        #expect(s.snapshot.phase == .looting)
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

    // MARK: R7 "real hands" (design/ROUND-7.md Core items 1–3)

    @Test func onsetShareCountsOnlyPastTheOnset() {
        #expect(Tuning.loudOnsetSeconds == 0.08)
        #expect(Noise.onsetShare(loudBefore: 0, loudAfter: 0.05, step: 0.05) == 0)
        #expect(Noise.onsetShare(loudBefore: 0.05, loudAfter: 0.08, step: 0.03) == 0)
        #expect(abs(Noise.onsetShare(loudBefore: 0.06, loudAfter: 0.1, step: 0.04) - 0.5) < 1e-9)
        #expect(abs(Noise.onsetShare(loudBefore: 0.2, loudAfter: 0.21, step: 0.01) - 1) < 1e-9)
        #expect(Noise.onsetShare(loudBefore: 0, loudAfter: 0, step: 0.01) == 0)
        #expect(Noise.onsetShare(loudBefore: 0, loudAfter: 0.01, step: 0) == 0)
        #expect(Noise.onsetShare(loudBefore: Double.nan, loudAfter: 0.2, step: 0.01) == 0)
        #expect(Noise.onsetShare(loudBefore: 0.1, loudAfter: 0.2, step: Double.infinity) == 0)
    }

    /// R7 (DEVICE-RISKS-1 item 2): a stick-slip blip shorter than the 0.08 s onset makes no noise and doesn't stop the
    /// decay, so a slow, jerky open is exactly as quiet as a still lid.
    @Test func loudOnsetForgivesAStickSlipBlip() {
        let (s, _) = lootingSession(seed: 211)
        _ = s.step(dt: 1.0 / 120.0, lid: lidAt(0.3))
        // A 0.07 s breakaway at 120 °/s: nothing.
        _ = s.step(dt: 0.07, lid: lidAt(0.4, speed: 120))
        #expect(s.snapshot.noise == 0)
        #expect(s.snapshot.stage == .asleep)
        // Stick-slip: a 1° slip in one 60 Hz frame (60 °/s), then 0.3 s stuck, for 4 s, against a twin whose lid
        // moves the same way but reads still. The noise decays identically.
        let (slip, _) = lootingSession(seed: 211)
        let (still, _) = lootingSession(seed: 211)
        slip.nudgeNoise(to: 0.8)
        still.nudgeNoise(to: 0.8)
        var o: Double = 0.3
        var t: Double = 0
        while t < 4 {
            o += 1.0 / Tuning.lidTravel
            _ = slip.step(dt: 1.0 / 60.0, lid: lidAt(o, speed: 60))
            _ = still.step(dt: 1.0 / 60.0, lid: lidAt(o))
            var k: Int = 0
            while k < 18 {
                _ = slip.step(dt: 1.0 / 60.0, lid: lidAt(o))
                _ = still.step(dt: 1.0 / 60.0, lid: lidAt(o))
                k += 1
            }
            t += 19.0 / 60.0
        }
        let slipNoise: Double = slip.snapshot.noise
        let stillNoise: Double = still.snapshot.noise
        #expect(slipNoise == stillNoise)
        #expect(slipNoise > 0 && slipNoise < 0.8)
        #expect(slip.snapshot.bites == 0)
    }

    /// R7: the onset is time-based, not frame-based: 0.5 s at 40 °/s from still counts exactly its last 0.42 s at any
    /// step size.
    @Test func loudOnsetIsTheSameAtAnyFrameRate() {
        let (ref, _) = lootingSession(seed: 221)
        guard let chest = ref.snapshot.chest else {
            Issue.record("no chest")
            return
        }
        let expected: Double = Noise.lidRate(speed: 40) * Noise.multiplier(for: chest.mimic)
            * (0.5 - Tuning.loudOnsetSeconds)
        for dt in [1.0 / 120.0, 1.0 / 90.0, 1.0 / 50.0, 0.5] {
            let (s, _) = lootingSession(seed: 221)
            _ = s.step(dt: 1.0 / 120.0, lid: lidAt(0.5))
            run(s, seconds: 0.5, dt: dt, lid: lidAt(0.5, speed: 40))
            let n: Double = s.snapshot.noise
            #expect(abs(n - expected) < 1e-9, "dt \(dt): noise \(n), expected \(expected)")
        }
    }

    /// R7: the onset only forgives blips. A real slam from still (150° → 100° in 0.25 s) still bites before it banks;
    /// a careful real close (25 °/s, under the R7 closing line) is silent all the way down and banks Hushed.
    @Test func aRealSlamStillBitesThroughTheOnset() {
        let (s, _) = lootingSession(seed: 71)
        guard let k = shallowest(s.snapshot) else {
            Issue.record("empty chest")
            return
        }
        _ = bagItem(s, k)
        _ = s.step(dt: 1.0 / 120.0, lid: lidAt(0.77))
        var o: Double = 0.77
        var ev: [HeistEvent] = []
        var i: Int = 0
        while i < 15 && count(ev, isBitten) == 0 {
            o = max(0, o - 200.0 / Tuning.lidTravel / 60.0)
            ev.append(contentsOf: s.step(dt: 1.0 / 60.0, lid: lidAt(o, speed: 200)))
            i += 1
        }
        #expect(count(ev, isBitten) == 1)
        #expect(count(ev, isBanked) == 0)
        let (c, _) = lootingSession(seed: 71)
        guard let kc = shallowest(c.snapshot) else { return }
        _ = bagItem(c, kc)
        _ = c.step(dt: 1.0 / 120.0, lid: lidAt(0.77))
        let n0: Double = c.snapshot.noise
        var p: Double = 0.77
        var evc: [HeistEvent] = []
        var j: Int = 0
        while j < 240 && count(evc, isBanked) == 0 {
            p = max(0.06, p - 25.0 / Tuning.lidTravel / 60.0)
            let v: Double = p > 0.06 ? 25 : 0
            evc.append(contentsOf: c.step(dt: 1.0 / 60.0, lid: lidAt(p, speed: v)))
            j += 1
        }
        #expect(count(evc, isBanked) == 1)
        let hushedBank: Bool = evc.contains { (e: HeistEvent) -> Bool in
            if case .banked(_, _, let hushed) = e { return hushed }
            return false
        }
        #expect(hushedBank)
        let rose: Int = count(evc) { (e: HeistEvent) -> Bool in
            if case .stageChanged(_, let to) = e { return to > .asleep }
            return false
        }
        #expect(rose == 0, "noise before the close \(n0)")
    }

    /// R7 (ROUND-7 Core item 2): `isFreshChest` is a `.ready` chest whose openness never passed 0.05, with nothing in
    /// the bag: after a bank with the lid carried on down to shut, the App may reopen it without the stillness wait.
    @Test func aFreshChestIsReadyAndUntouched() {
        #expect(Tuning.freshChestOpenness == 0.05)
        // The run's first chest, lid shut: fresh.
        let s: HeistSession = newSession(seed: 231)
        #expect(s.isFreshChest)
        _ = s.step(dt: 1.0 / 60.0, lid: lidAt(0))
        #expect(s.snapshot.phase == .ready)
        #expect(s.isFreshChest)
        // Cracked open, it's looting: not fresh, and not again once shut.
        _ = s.step(dt: 1.0 / 60.0, lid: lidAt(0.1))
        #expect(s.snapshot.phase == .looting)
        #expect(!s.isFreshChest)
        _ = s.step(dt: 1.0 / 60.0, lid: lidAt(0))
        #expect(!s.isFreshChest)
        // Bank, then carry the lid on down to shut (the Duo folded): the next chest arrives fresh.
        let (b, _) = lootingSession(seed: 231)
        _ = bankOne(b)
        #expect(!b.isFreshChest)
        let ev: [HeistEvent] = run(b, seconds: 2.0, lid: lidAt(0))
        #expect(count(ev, isArrived) == 1)
        #expect(b.snapshot.phase == .ready)
        #expect(b.snapshot.bagValue == 0)
        #expect(b.isFreshChest)
        // A hair of lid below the looting line keeps it fresh; opening it starts the chest.
        _ = b.step(dt: 1.0 / 60.0, lid: lidAt(0.015))
        #expect(b.isFreshChest)
        // R13: a crack (≤ 0.05, nothing revealed) while the hand settles the phone shut is still fresh; past it, not.
        _ = b.step(dt: 1.0 / 60.0, lid: lidAt(0.04))
        #expect(b.snapshot.phase == .looting)
        _ = b.step(dt: 1.0 / 60.0, lid: lidAt(0.08))
        #expect(!b.isFreshChest)
        // The next chest arriving with the lid still resting in the shut zone (0.06) is looted at once: not fresh.
        let (c, _) = lootingSession(seed: 231)
        _ = bankOne(c)
        nextChestLooting(c)
        #expect(c.snapshot.phase == .looting)
        #expect(!c.isFreshChest)
        // R12 (founder): reopened during the bank moment, the next chest is dealt "seen shut" and simply opens:
        // looting, so not fresh, and not again once shut.
        let (d, _) = lootingSession(seed: 231)
        _ = bankOne(d)
        run(d, seconds: 2.0, lid: lidAt(0.5))
        #expect(d.snapshot.phase == .looting)
        #expect(!d.isFreshChest)
        _ = d.step(dt: 1.0 / 60.0, lid: lidAt(0))
        #expect(d.snapshot.phase == .looting)
        #expect(!d.isFreshChest)
        // R13: the lesson lost its gate, so it is no different: reopened during the bank moment, the next chest simply
        // opens (looting, not fresh); and banked then carried on down to shut, the next chest arrives fresh.
        let (e, _) = lootingSession(mode: .lesson)
        _ = bankOne(e)
        run(e, seconds: 2.0, lid: lidAt(0.5))
        #expect(e.snapshot.phase == .looting)
        #expect(!e.isFreshChest)
        _ = e.step(dt: 1.0 / 60.0, lid: lidAt(0))
        #expect(e.snapshot.phase == .looting)
        #expect(!e.isFreshChest)
        let (f, _) = lootingSession(mode: .lesson)
        _ = bankOne(f)
        let fev: [HeistEvent] = run(f, seconds: 2.0, lid: lidAt(0))
        #expect(count(fev, isArrived) == 1)
        #expect(f.snapshot.phase == .ready)
        #expect(f.isFreshChest)
    }

    /// R7 (ROUND-7 Core item 3): Lid sensitivity scales every noise source (forgiving 0.75, normal 1, careful 1.2), in
    /// runs and the unscored Daily. The scored Daily is always Normal; attract and the lesson ignore it.
    @Test func lidSensitivityScalesTheNoiseButNotTheScoredDaily() throws {
        #expect(LidSensitivity.allCases == [.forgiving, .normal, .careful])
        #expect(LidSensitivity.forgiving.rawValue == "forgiving")
        #expect(LidSensitivity.normal.rawValue == "normal")
        #expect(LidSensitivity.careful.rawValue == "careful")
        #expect(LidSensitivity.forgiving.noiseScale == 0.75)
        #expect(LidSensitivity.normal.noiseScale == 1)
        #expect(LidSensitivity.careful.noiseScale == 1.2)
        let data: Data = try JSONEncoder().encode(LidSensitivity.allCases)
        let back: [LidSensitivity] = try JSONDecoder().decode([LidSensitivity].self, from: data)
        #expect(back == LidSensitivity.allCases)
        let json: Data = Data(#"["careful","forgiving"]"#.utf8)
        let raw: [LidSensitivity] = try JSONDecoder().decode([LidSensitivity].self, from: json)
        #expect(raw == [.careful, .forgiving])
        // SessionOptions(sensitivity:).
        let f: SessionOptions = SessionOptions(sensitivity: .forgiving)
        #expect(f.noiseScale == 0.75)
        #expect(f.sensitivity == .forgiving)
        #expect(f.torch && f.bites && f.fixedChest == nil)
        #expect(SessionOptions(sensitivity: .normal) == SessionOptions())
        #expect(SessionOptions().sensitivity == .normal)
        #expect(abs(SessionOptions(sensitivity: .careful).noiseScale - 1.2) < 1e-12)
        // Per mode.
        let runOptions: SessionOptions = SessionOptions.for(.run, sensitivity: .careful)
        #expect(runOptions == SessionOptions(sensitivity: .careful))
        let practice: SessionOptions = SessionOptions.for(.daily(day: 3, scored: false), sensitivity: .forgiving)
        #expect(practice.noiseScale == 0.75)
        let scored: SessionOptions = SessionOptions.for(.daily(day: 3, scored: true), sensitivity: .forgiving)
        #expect(scored == SessionOptions())
        #expect(scored.sensitivity == .normal)
        #expect(LidSensitivity.effective(.careful, for: .daily(day: 9, scored: true)) == .normal)
        #expect(LidSensitivity.effective(.careful, for: .daily(day: 9, scored: false)) == .careful)
        #expect(LidSensitivity.effective(.forgiving, for: .run) == .forgiving)
        #expect(SessionOptions.for(.attract, sensitivity: .careful) == SessionOptions.for(.attract))
        #expect(SessionOptions.for(.lesson, sensitivity: .forgiving) == SessionOptions.for(.lesson))
        // In a session every source is scaled: a pick adds pickNoise × the mimic × the sensitivity.
        for sens in LidSensitivity.allCases {
            let (s, _) = lootingSession(seed: 21, options: SessionOptions(sensitivity: sens))
            guard let k = shallowest(s.snapshot), let chest = s.snapshot.chest else {
                Issue.record("empty chest")
                continue
            }
            _ = s.step(dt: 1.0 / 120.0, lid: lidAt(min(1, s.snapshot.loot[k].item.depth + 0.08)))
            let picked: [HeistEvent] = s.touchBegan(id: 1, at: s.snapshot.loot[k].position, time: 0)
            #expect(!picked.isEmpty)
            let expected: Double = Tuning.pickNoise * Noise.multiplier(for: chest.mimic) * sens.noiseScale
            #expect(abs(s.snapshot.noise - expected) < 1e-9, "\(sens.rawValue)")
        }
        // The scored Daily plays the same whatever the setting (everyone's counted try is the same game).
        let day: RunMode = .daily(day: 300, scored: true)
        let a = HeistSession(mode: day, seed: DailySeed.seed(day: 300), bestRun: 0, foundRelics: [],
                             options: SessionOptions.for(day, sensitivity: .forgiving))
        let b = HeistSession(mode: day, seed: DailySeed.seed(day: 300), bestRun: 0, foundRelics: [],
                             options: SessionOptions.for(day, sensitivity: .careful))
        var pa = ThiefPilot(skill: .casual, seed: 5)
        var pb = ThiefPilot(skill: .casual, seed: 5)
        var t: Double = 0
        var frames: Int = 0
        while frames < 60 * 30 {
            let oa: PilotOutput = pa.step(dt: 1.0 / 60.0, snapshot: a.snapshot)
            let ob: PilotOutput = pb.step(dt: 1.0 / 60.0, snapshot: b.snapshot)
            for touch in oa.touches {
                switch touch.phase {
                case .began: _ = a.touchBegan(id: touch.id, at: touch.point, time: t)
                case .moved: _ = a.touchMoved(id: touch.id, to: touch.point, time: t)
                case .ended: _ = a.touchEnded(id: touch.id, at: touch.point, time: t)
                }
            }
            for touch in ob.touches {
                switch touch.phase {
                case .began: _ = b.touchBegan(id: touch.id, at: touch.point, time: t)
                case .moved: _ = b.touchMoved(id: touch.id, to: touch.point, time: t)
                case .ended: _ = b.touchEnded(id: touch.id, at: touch.point, time: t)
                }
            }
            _ = a.step(dt: 1.0 / 60.0, lid: oa.lid)
            _ = b.step(dt: 1.0 / 60.0, lid: ob.lid)
            t += 1.0 / 60.0
            frames += 1
        }
        let sa: HeistSnapshot = a.snapshot
        let sb: HeistSnapshot = b.snapshot
        #expect(sa == sb)
        let ra: RunResult = a.partialResult()
        let rb: RunResult = b.partialResult()
        #expect(ra == rb)
    }

    // MARK: R12 "the lid IS the chest" (design/ROUND-12.md rules 1–4)

    /// Bags the shallowest item, then flings the lid at 150 °/s at openness 0.5 until the mimic bites (≤ 1 s).
    private func biteWithTheLidOpen(_ s: HeistSession) -> [HeistEvent] {
        guard let k = shallowest(s.snapshot) else { return [] }
        var ev: [HeistEvent] = bagItem(s, k)
        var t: Double = 0
        while t < 1.0 && count(ev, isBitten) == 0 {
            ev.append(contentsOf: s.step(dt: 1.0 / 60.0, lid: lidAt(0.5, speed: 150)))
            t += 1.0 / 60.0
        }
        return ev
    }

    private func isCloseForNext(_ s: HeistSession) -> Bool { return s.snapshot.hint == HeistHint.closeForNext }

    /// R14 (founder: "playing starts with the chest closed right? so ask the user to close the phone if it is not to
    /// start playing, then the chest should open as the phone opens"), inverting R12 rule 2 ("a run started with the
    /// lid up opens at once"): in every mode the first chest started with the lid up stays closed (`.ready`, dark, no
    /// crack, "Close the phone to start", the candle unburnt) until the lid is seen shut; then it opens with the phone,
    /// lit at the current openness. With the lid shut it arrives closed and opens with the phone.
    @Test func r14FirstChestWithTheLidUpWaitsForTheClose() {
        for mode in [RunMode.run, RunMode.daily(day: 300, scored: true), RunMode.attract, RunMode.lesson] {
            let s: HeistSession = newSession(seed: 7, mode: mode)
            #expect(s.snapshot.phase == .ready)
            #expect(s.awaitsFirstShut)
            let ev0: [HeistEvent] = s.step(dt: 1.0 / 60.0, lid: lidAt(0.8))
            #expect(count(ev0, isArrived) == 1)
            #expect(count(ev0, isCracked) == 0)
            let torch0: Double = s.snapshot.torchRemaining
            let held: [HeistEvent] = run(s, seconds: 3.0, lid: lidAt(0.8))
            #expect(count(held, isCracked) == 0)
            #expect(s.snapshot.phase == .ready)
            #expect(s.snapshot.hint == HeistHint.easeLidDown)
            #expect(s.snapshot.torchRemaining == torch0)
            #expect(s.snapshot.loot.allSatisfy { (l: LootState) -> Bool in l.light == 0 && !l.grabbable })
            #expect(s.isFreshChest)
            #expect(!s.awaitingClose)
            #expect(!s.canBankOnShut)
            #expect(!s.endsEmptyOnShut)
            // Seen shut, then reopened to 0.8 (one step: not closing): it opens with the phone.
            _ = s.step(dt: 1.0 / 60.0, lid: lidAt(0))
            #expect(!s.awaitsFirstShut)
            #expect(s.snapshot.phase == .ready)
            let ev: [HeistEvent] = s.step(dt: 1.0 / 60.0, lid: lidAt(0.8))
            #expect(count(ev, isCracked) == 1)
            #expect(s.snapshot.phase == .looting)
            #expect(s.snapshot.hint != HeistHint.easeLidDown)
            #expect(s.snapshot.hint != HeistHint.closeForNext)
            #expect(!s.awaitingClose)
            // Every item at depth ≤ 0.7 is fully lit at 0.8.
            let lit: Bool = s.snapshot.loot.allSatisfy { (l: LootState) -> Bool in
                l.item.depth > 0.7 || l.light == 1
            }
            #expect(lit)
            #expect(s.snapshot.loot.contains { (l: LootState) -> Bool in l.grabbable })
        }
        // Lid shut at the start: the chest arrives closed (dark, "Open the phone… slowly"), then opens with the phone.
        let c: HeistSession = newSession(seed: 7)
        _ = c.step(dt: 1.0 / 60.0, lid: lidAt(0))
        #expect(c.snapshot.phase == .ready)
        #expect(c.snapshot.hint == HeistHint.openSlowly)
        #expect(c.snapshot.loot.allSatisfy { (l: LootState) -> Bool in l.light == 0 && !l.grabbable })
        let ev2: [HeistEvent] = c.step(dt: 1.0 / 60.0, lid: lidAt(0.1))
        #expect(c.snapshot.phase == .looting)
        #expect(count(ev2, isCracked) == 1)
        // R13: the lesson's chest is the same: shut, it arrives closed and opens with the phone.
        let l: HeistSession = newSession(mode: .lesson)
        _ = l.step(dt: 1.0 / 60.0, lid: lidAt(0))
        #expect(l.snapshot.phase == .ready)
        #expect(l.snapshot.hint == HeistHint.openSlowly)
        let ev3: [HeistEvent] = l.step(dt: 1.0 / 60.0, lid: lidAt(0.1))
        #expect(l.snapshot.phase == .looting)
        #expect(count(ev3, isCracked) == 1)
    }

    /// R14: `noteLidShut()` (the cover display took over, or the closing pause) counts as the first chest seen shut:
    /// it deals nothing, returns nothing, and the chest then opens with the phone.
    @Test func r14NoteLidShutIsTheFirstClose() {
        let s: HeistSession = newSession(seed: 7)
        _ = s.step(dt: 1.0 / 60.0, lid: lidAt(0.8))
        #expect(s.awaitsFirstShut)
        let shutEvents: [HeistEvent] = s.noteLidShut()
        #expect(shutEvents.isEmpty)
        #expect(!s.awaitsFirstShut)
        #expect(s.snapshot.chest?.index == 0)
        #expect(s.snapshot.phase == .ready)
        let ev: [HeistEvent] = s.step(dt: 1.0 / 60.0, lid: lidAt(0.9))   // opening, not closing
        #expect(count(ev, isArrived) == 0)
        #expect(count(ev, isCracked) == 1)
        #expect(s.snapshot.phase == .looting)
    }

    /// R14: "Your candle waits": the candle doesn't burn while the run's first chest is still closed (shut or open
    /// before the close), and burns from the moment it opens.
    @Test func r14TheCandleWaitsForTheFirstChest() {
        let s: HeistSession = newSession(seed: 7)
        _ = s.step(dt: 1.0 / 60.0, lid: lidAt(0.6))
        let t0: Double = s.snapshot.torchRemaining
        #expect(t0 > 0)
        run(s, seconds: 2.0, lid: lidAt(0.6))
        #expect(s.snapshot.torchRemaining == t0)
        // Seen shut, still closed: it waits.
        run(s, seconds: 2.0, lid: lidAt(0))
        #expect(s.snapshot.phase == .ready)
        #expect(s.snapshot.torchRemaining == t0)
        // Opened: it burns.
        run(s, seconds: 1.0, lid: lidAt(0.3))
        #expect(s.snapshot.phase == .looting)
        #expect(s.snapshot.torchRemaining < t0 - 0.9)
        #expect(s.snapshot.torchRemaining > t0 - 1.1)
    }

    /// R14 (UX audit D): closing the phone always ends the chest. Opened past 0.2 (≈ 30° of the phone) and closed with
    /// an empty bag, `noteLidShut()` logs it (value 0, not bitten), deals the next chest (its `chestArrived` with the
    /// next step) and returns nothing; the next chest is dealt closed and opens with the phone. Not under the 0.2 peak
    /// (a hand settling the phone), not with loot in the bag (that banks), never in the lesson.
    @Test func r14AnEmptyChestClosedEnds() {
        #expect(Tuning.emptyShutOpenness == 0.2)
        let s: HeistSession = newSession(seed: 7)
        _ = s.step(dt: 1.0 / 60.0, lid: lidAt(0))
        _ = s.step(dt: 1.0 / 60.0, lid: lidAt(0.3))
        #expect(s.snapshot.phase == .looting)
        #expect(s.snapshot.bagValue == 0)
        #expect(s.endsEmptyOnShut)
        #expect(!s.canBankOnShut)
        _ = s.step(dt: 1.0 / 60.0, lid: lidAt(0))
        let log0: Int = s.partialResult().chestLog.count
        let shut: [HeistEvent] = s.noteLidShut()
        #expect(shut.isEmpty)
        #expect(!s.endsEmptyOnShut)
        #expect(s.snapshot.chest?.index == 1)
        #expect(s.snapshot.phase == .ready)
        #expect(!s.awaitsFirstShut)
        #expect(!s.awaitingClose)
        let log: [ChestOutcome] = s.partialResult().chestLog
        #expect(log.count == log0)
        #expect(log.count == 1)
        #expect(log.first?.value == 0)
        #expect(log.first?.bitten == false)
        #expect(s.partialResult().chestsBanked == 0)
        #expect(s.partialResult().chestsOpened == 1)
        let next: [HeistEvent] = s.step(dt: 1.0 / 60.0, lid: lidAt(0))
        #expect(count(next, isArrived) == 1)
        #expect(count(next, isCracked) == 0)
        let open: [HeistEvent] = s.step(dt: 1.0 / 60.0, lid: lidAt(0.3))
        #expect(count(open, isCracked) == 1)
        #expect(s.snapshot.phase == .looting)

        // Opened no further than 0.2: not ended, nothing dealt.
        let low: HeistSession = newSession(seed: 7)
        _ = low.step(dt: 1.0 / 60.0, lid: lidAt(0))
        _ = low.step(dt: 1.0 / 60.0, lid: lidAt(0.15))
        #expect(low.snapshot.phase == .looting)
        #expect(!low.endsEmptyOnShut)
        _ = low.step(dt: 1.0 / 60.0, lid: lidAt(0))
        let lowShut: [HeistEvent] = low.noteLidShut()
        #expect(lowShut.isEmpty)
        #expect(low.snapshot.chest?.index == 0)
        #expect(low.snapshot.phase == .looting)
        #expect(low.partialResult().chestLog.count == 1)   // only the open chest, counted as it stands

        // Loot in the bag: it banks instead.
        let (b, _) = lootingSession(seed: 7)
        guard let k = shallowest(b.snapshot) else {
            Issue.record("no item")
            return
        }
        _ = bagItem(b, k)
        _ = b.step(dt: 1.0 / 60.0, lid: lidAt(0.5))
        // (The shallowest item may be worth nothing, oil: the bag counts it all the same.)
        #expect(!b.endsEmptyOnShut)
        #expect(b.canBankOnShut)

        // The lesson (one chest): never.
        let l: HeistSession = newSession(mode: .lesson)
        _ = l.step(dt: 1.0 / 60.0, lid: lidAt(0))
        _ = l.step(dt: 1.0 / 60.0, lid: lidAt(0.5))
        #expect(l.snapshot.phase == .looting)
        #expect(!l.endsEmptyOnShut)
        _ = l.noteLidShut()
        #expect(l.snapshot.chest?.index == 0)
    }

    /// R14 (suspected app bug, reported to the App/Core owner): `peakOpenness` also grows while the run's first chest
    /// waits `.ready` for the close, so a first chest started with the phone open, closed, then barely reopened (0.1,
    /// under the 0.2 line) already counts as opened wide and `endsEmptyOnShut` ends it on the next close. Expected: the
    /// peak counts from the moment the chest opens. When Core is fixed this known issue stops recording: drop the
    /// `withKnownIssue` wrapper.
    @Test func r14ThePeakCountsFromTheOpening() {
        let s: HeistSession = newSession(seed: 7)
        _ = s.step(dt: 1.0 / 60.0, lid: lidAt(0.8))
        _ = s.step(dt: 1.0 / 60.0, lid: lidAt(0))
        _ = s.step(dt: 1.0 / 60.0, lid: lidAt(0.1))
        #expect(s.snapshot.phase == .looting)
        withKnownIssue("HeistSession.play: peakOpenness isn't reset when the first chest opens") {
            #expect(!s.endsEmptyOnShut)
        }
    }

    /// R14 (UX audit E): a fast drag makes noise, so it says "Slower…" (bites never feel random); a slow one doesn't.
    @Test func r14AFastDragSaysSlower() {
        let (s, _) = lootingSession(seed: 7)
        guard let k = shallowest(s.snapshot) else {
            Issue.record("no item")
            return
        }
        let item: LootItem = s.snapshot.loot[k].item
        _ = s.step(dt: 1.0 / 120.0, lid: lidAt(min(1, item.depth + 0.08)))
        let p: CGPoint = s.snapshot.loot[k].position
        _ = s.touchBegan(id: 1, at: p, time: 10)
        // 20 pt in 0.5 s: 40 pt/s, far under the 350 pt/s quiet line.
        _ = s.touchMoved(id: 1, to: CGPoint(x: p.x, y: p.y + 20), time: 10.5)
        #expect(s.snapshot.hint != HeistHint.slower)
        // 200 pt in 0.1 s: 2000 pt/s.
        _ = s.touchMoved(id: 1, to: CGPoint(x: p.x, y: p.y + 220), time: 10.6)
        #expect(Tuning.dragQuietSpeed == 350)
        #expect(s.snapshot.hint == HeistHint.slower)
    }

    /// Rule 4, after a bite: the robbed chest stays open and empty with only "Close the phone for the next chest" (the
    /// candle burning on), however long the lid stays up; the next chest is dealt the step the lid enters the shut zone.
    @Test func r12AfterABiteTheRobbedChestWaitsForTheClose() {
        let (s, _) = lootingSession(seed: 71)
        let bite: [HeistEvent] = biteWithTheLidOpen(s)
        #expect(count(bite, isBitten) == 1)
        #expect(!s.awaitingClose)
        let torch0: Double = s.snapshot.torchRemaining
        let wait: [HeistEvent] = run(s, seconds: 5.0, lid: lidAt(0.5))
        #expect(count(wait, isArrived) == 0)
        #expect(s.awaitingClose)
        let snap: HeistSnapshot = s.snapshot
        #expect(snap.phase == .ready)
        #expect(snap.loot.isEmpty)
        #expect(snap.hint == HeistHint.closeForNext)
        #expect(snap.chest?.index == 0)
        #expect(snap.stage == .asleep)
        #expect(snap.noise == 0)
        #expect(snap.bagValue == 0)
        #expect(snap.bites == 1)
        // The candle burns while you close (5 s minus what was left of the 1.8 s bite moment).
        #expect(snap.torchRemaining < torch0 - 3)
        #expect(!s.isFreshChest)
        // Nothing to touch, and no other prompt (not even "Slower…" or "That's wide enough").
        let poke: [HeistEvent] = s.touchBegan(id: 9, at: CGPoint(x: 300, y: 200), time: 50)
        #expect(poke.isEmpty)
        _ = s.step(dt: 1.0 / 60.0, lid: LidInput(openness: 1, speed: 60, inShutZone: false, tooWide: true))
        #expect(isCloseForNext(s))
        #expect(s.snapshot.noise == 0)
        // The partial result counts the robbed chest once (as bitten), not as a chest being looted.
        let p: RunResult = s.partialResult()
        #expect(p.chestLog.count == 1)
        #expect(p.chestLog.first?.bitten == true)
        // The lid enters the shut zone (0.12 = 107.8°) on its way down: the next chest arrives, closed.
        let deal: [HeistEvent] = s.step(dt: 1.0 / 60.0, lid: lidAt(0.12, speed: 150))
        let c1: ChestSpec = ChestFactory.chest(seed: 71, index: 1, found: [])
        #expect(deal.contains(HeistEvent.chestArrived(index: 1, tier: c1.tier, mimic: c1.mimic, name: c1.mimicName)))
        #expect(!s.awaitingClose)
        #expect(s.snapshot.chest?.index == 1)
        #expect(s.snapshot.loot.count == c1.items.count)
        #expect(s.snapshot.phase == .ready)
        #expect(!isCloseForNext(s))
        // The rest of the slam is the lid closing it: still .ready, silent, the new mimic asleep, and fresh.
        _ = s.step(dt: 1.0 / 60.0, lid: lidAt(0.05, speed: 150))
        let tail: [HeistEvent] = run(s, seconds: 0.5, lid: lidAt(0, speed: 150))
        #expect(s.snapshot.phase == .ready)
        #expect(s.snapshot.noise == 0)
        #expect(s.snapshot.stage == .asleep)
        #expect(s.snapshot.hint != HeistHint.slower)
        let stirred: Int = count(tail) { (e: HeistEvent) -> Bool in
            if case .stageChanged = e { return true }
            return false
        }
        #expect(stirred == 0)
        #expect(s.isFreshChest)
        // Open it to play.
        let open: [HeistEvent] = s.step(dt: 1.0 / 60.0, lid: lidAt(0.1))
        #expect(s.snapshot.phase == .looting)
        #expect(count(open, isCracked) == 1)
        #expect(s.partialResult().chestsOpened == 2)
    }

    /// Rule 4: a chest dealt with the lid resting in the shut zone is looted at once (as after a bank at 0.06); a bite
    /// whose moment ends with the lid already shut deals at once; `noteLidShut()` deals one awaiting the close.
    @Test func r12TheNextChestArrivesOnlyUnderAClosedLid() {
        let (r, _) = lootingSession(seed: 71)
        _ = biteWithTheLidOpen(r)
        run(r, seconds: 2.0, lid: lidAt(0.5))
        #expect(r.awaitingClose)
        let dealt: [HeistEvent] = r.step(dt: 1.0 / 60.0, lid: lidAt(0.12))
        #expect(count(dealt, isArrived) == 1)
        #expect(r.snapshot.phase == .ready)
        _ = r.step(dt: 1.0 / 60.0, lid: lidAt(0.12))
        #expect(r.snapshot.phase == .looting)
        // Shut during the bite moment: dealt when it ends, never awaiting.
        let (q, _) = lootingSession(seed: 71)
        _ = biteWithTheLidOpen(q)
        let moment: [HeistEvent] = run(q, seconds: 2.0, lid: lidAt(0.06))
        #expect(count(moment, isArrived) == 1)
        #expect(!q.awaitingClose)
        #expect(q.snapshot.phase == .looting)
        // The App saw the lid shut (a fast fold into the closing pause): dealt now, the event with the next step (the
        // lid lifted again on the resume).
        let (n, _) = lootingSession(seed: 71)
        _ = biteWithTheLidOpen(n)
        run(n, seconds: 2.0, lid: lidAt(0.5))
        #expect(n.awaitingClose)
        n.noteLidShut()
        #expect(!n.awaitingClose)
        #expect(n.snapshot.chest?.index == 1)
        #expect(n.isFreshChest)
        let resumed: [HeistEvent] = n.step(dt: 1.0 / 60.0, lid: lidAt(0.6))
        #expect(count(resumed, isArrived) == 1)
        #expect(n.snapshot.phase == .looting)
        // R14 (closing the phone always ends the chest): without a chest awaiting, this one, opened to 0.6 with an
        // empty bag, is logged and the next is dealt. (Over a chest barely opened, noteLidShut does nothing:
        // `r14AnEmptyChestClosedEnds`.)
        let idx: Int = n.snapshot.chest?.index ?? -1
        #expect(n.endsEmptyOnShut)
        n.noteLidShut()
        #expect(n.snapshot.chest?.index == idx + 1)
        #expect(n.snapshot.phase == .ready)
        #expect(!n.awaitingClose)
        // The candle can go out while the robbed chest waits: the run ends as usual, and nothing is awaiting.
        let (o, _) = lootingSession(seed: 71)
        _ = biteWithTheLidOpen(o)
        let end: [HeistEvent] = run(o, seconds: 110, dt: 1.0 / 30.0, lid: lidAt(0.5))
        #expect(count(end, isTorchOut) == 1)
        #expect(count(end, isArrived) == 0)
        #expect(o.isFinished)
        #expect(!o.awaitingClose)
        #expect(o.result?.chestLog.count == o.result?.chestsOpened)
    }

    /// R12b (CI BANK-CLOSE-FULL): the lid seen shut with loot in the bag banks it, at once, and deals the next chest
    /// (closed, fresh); the events come back from `noteLidShut()` itself. An empty bag and a finished run bank
    /// nothing. R13: the lesson banks too (its gate is gone; its script hears the `.banked` through the App).
    @Test func r12bTheLidSeenShutBanksTheBag() {
        let (s, _) = lootingSession(seed: 71)
        guard let k = shallowest(s.snapshot) else { Issue.record("no loot"); return }
        _ = bagItem(s, k)
        let bag: Int = s.snapshot.bagValue
        #expect(bag > 0)
        #expect(s.canBankOnShut)
        let ev: [HeistEvent] = s.noteLidShut()
        #expect(count(ev, isBanked) == 1)
        #expect(count(ev, isArrived) == 1)
        #expect(s.snapshot.banked >= bag)
        #expect(s.snapshot.chestsBanked == 1)
        #expect(s.snapshot.chest?.index == 1)
        #expect(s.snapshot.phase == .ready)
        #expect(s.snapshot.bagValue == 0)
        #expect(s.isFreshChest)
        #expect(!s.canBankOnShut)
        // Nothing is left pending: the next step brings no second bank or arrival, and the lid lifting opens it.
        let open: [HeistEvent] = s.step(dt: 1.0 / 60.0, lid: lidAt(0.6))
        #expect(count(open, isBanked) == 0)
        #expect(count(open, isArrived) == 0)
        #expect(s.snapshot.phase == .looting)
        // An empty bag: nothing.
        let (e, _) = lootingSession(seed: 71)
        #expect(!e.canBankOnShut)
        #expect(e.noteLidShut().isEmpty)
        #expect(e.snapshot.chest?.index == 0)
        // R13: the lesson banks on shut like a run (it used to wait for its own bank moment).
        let (l, _) = lootingSession(seed: 71, mode: .lesson)
        guard let j = shallowest(l.snapshot) else { Issue.record("no lesson loot"); return }
        _ = bagItem(l, j)
        let lessonBag: Int = l.snapshot.bagValue
        #expect(lessonBag > 0)
        #expect(l.canBankOnShut)
        let lev: [HeistEvent] = l.noteLidShut()
        #expect(count(lev, isBanked) == 1)
        #expect(count(lev, isArrived) == 1)
        #expect(l.snapshot.banked >= lessonBag)
        #expect(l.snapshot.phase == .ready)
        #expect(l.isFreshChest)
        #expect(!l.canBankOnShut)
    }

    /// Founder refinement: the chest dealt after a BANK always counts as "seen shut". Bank in the shut zone, reopen to
    /// 150° before the 1.4 s bank moment ends: the next chest loots at once, never `.closeForNext`.
    @Test func r12ABankAlwaysDealsTheNextChestSeenShut() {
        let (s, _) = lootingSession(seed: 231)
        guard let k = shallowest(s.snapshot) else {
            Issue.record("empty chest")
            return
        }
        _ = bagItem(s, k)
        let banked: [HeistEvent] = run(s, seconds: 0.5, dt: 1.0 / 120.0, lid: lidAt(0.06))
        #expect(count(banked, isBanked) == 1)
        if case .banked = s.snapshot.phase {} else { Issue.record("not in the bank moment: \(s.snapshot.phase)") }
        let wide: LidInput = Lid.input(angle: 150, speed: 0)
        #expect(!wide.inShutZone)
        var ev: [HeistEvent] = []
        var waited: Bool = false
        var hinted: Bool = false
        var t: Double = 0
        while t < 1.5 {
            ev.append(contentsOf: s.step(dt: 1.0 / 60.0, lid: wide))
            if s.awaitingClose { waited = true }
            if isCloseForNext(s) { hinted = true }
            t += 1.0 / 60.0
        }
        #expect(count(ev, isArrived) == 1)
        #expect(count(ev, isCracked) == 1)
        #expect(!waited)
        #expect(!hinted)
        #expect(s.snapshot.phase == .looting)
        #expect(s.snapshot.chest?.index == 1)
        #expect(s.snapshot.loot.contains { (l: LootState) -> Bool in l.grabbable })
    }

    /// Rules 1–4 under pilots on three Dailies: `.easeLidDown` never shows in a run, `.closeForNext` shows exactly while
    /// awaiting the close (then the floor is empty), every chest after the first arrives with the lid in the shut zone,
    /// and the deal order is the Daily's (index by index, as ChestFactory deals it).
    @Test func r12PilotsPlayTheLidAsTheChest() {
        var awaited: Int = 0
        for day in 300...302 {
            let seed: UInt64 = DailySeed.seed(day: day)
            let mode: RunMode = .daily(day: day, scored: true)
            for skill in [PilotSkill.novice, PilotSkill.casual] {
                let s = HeistSession(mode: mode, seed: seed, bestRun: 0, foundRelics: [],
                                     options: SessionOptions.for(mode))
                var pilot = ThiefPilot(skill: skill, seed: 5)
                var found: Set<RelicID> = []
                var arrivals: Int = 0
                var openDeals: Int = 0
                var outOfOrder: Int = 0
                var easeHints: Int = 0
                var badAwait: Int = 0
                var t: Double = 0
                var frames: Int = 0
                while !s.isFinished && frames < 60 * 600 {
                    let out: PilotOutput = pilot.step(dt: 1.0 / 60.0, snapshot: s.snapshot)
                    for touch in out.touches {
                        switch touch.phase {
                        case .began: _ = s.touchBegan(id: touch.id, at: touch.point, time: t)
                        case .moved: _ = s.touchMoved(id: touch.id, to: touch.point, time: t)
                        case .ended: _ = s.touchEnded(id: touch.id, at: touch.point, time: t)
                        }
                    }
                    let ev: [HeistEvent] = s.step(dt: 1.0 / 60.0, lid: out.lid)
                    for e in ev {
                        if case .relicFound(let rid) = e { found.insert(rid) }
                        if case .chestArrived(let index, let tier, let mimic, let name) = e {
                            let want: ChestSpec = ChestFactory.chest(seed: seed, index: index, found: found)
                            if index != arrivals || tier != want.tier || mimic != want.mimic || name != want.mimicName {
                                outOfOrder += 1
                            }
                            if index > 0 && !out.lid.inShutZone { openDeals += 1 }
                            arrivals += 1
                        }
                    }
                    let snap: HeistSnapshot = s.snapshot
                    if snap.hint == HeistHint.easeLidDown { easeHints += 1 }
                    if (snap.hint == HeistHint.closeForNext) != s.awaitingClose { badAwait += 1 }
                    if s.awaitingClose {
                        awaited += 1
                        if !snap.loot.isEmpty || snap.phase != .ready { badAwait += 1 }
                    }
                    t += 1.0 / 60.0
                    frames += 1
                }
                let tag: String = "day \(day) \(skill.rawValue)"
                #expect(s.isFinished, "\(tag)")
                #expect(arrivals >= 5, "\(tag) arrivals \(arrivals)")
                #expect(outOfOrder == 0, "\(tag)")
                #expect(openDeals == 0, "\(tag)")
                #expect(easeHints == 0, "\(tag)")
                #expect(badAwait == 0, "\(tag)")
            }
        }
        // The novices are bitten with the lid up and wait for the close (the JS port: 45 + 7 + 70 frames).
        #expect(awaited > 0)
    }
}

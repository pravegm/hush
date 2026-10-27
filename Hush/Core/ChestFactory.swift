import CoreGraphics
import Foundation

// MARK: - Dealing chests (GAME-DESIGN §6)
//
// Deterministic from (run seed, chest index, relics already found). `found` only changes WHICH relic a relic chest
// holds (it prefers unfound ones); every value, depth and position is drawn the same way regardless, so the Daily
// Dungeon scores the same for everyone. Mirrored by `chest()` in tools/balance-sim.js (same draw order).

enum ChestFactory {

    static func tier(forIndex index: Int) -> ChestTier {
        if index >= Tuning.royalFromIndex { return .royal }
        if index >= Tuning.gildedFromIndex { return .gilded }
        if index >= Tuning.ironFromIndex { return .iron }
        return .wooden
    }

    static func multiplier(for tier: ChestTier) -> Double {
        switch tier {
        case .wooden: return Tuning.woodenMultiplier
        case .iron: return Tuning.ironMultiplier
        case .gilded: return Tuning.gildedMultiplier
        case .royal: return Tuning.royalMultiplier
        }
    }

    static func decay(for tier: ChestTier) -> Double {
        switch tier {
        case .wooden: return Tuning.woodenDecay
        case .iron: return Tuning.ironDecay
        case .gilded: return Tuning.gildedDecay
        case .royal: return Tuning.royalDecay
        }
    }

    static func itemCount(for tier: ChestTier) -> ClosedRange<Int> {
        switch tier {
        case .wooden: return Tuning.woodenItems
        case .iron: return Tuning.ironItems
        case .gilded: return Tuning.gildedItems
        case .royal: return Tuning.royalItems
        }
    }

    /// 0 wooden … 3 royal (ChestTier is not Comparable).
    static func rank(_ tier: ChestTier) -> Int {
        switch tier {
        case .wooden: return 0
        case .iron: return 1
        case .gilded: return 2
        case .royal: return 3
        }
    }

    static func radius(for kind: LootKind) -> CGFloat {
        switch kind {
        case .copper: return Tuning.copperRadius
        case .silver: return Tuning.silverRadius
        case .gem: return Tuning.gemRadius
        case .relic: return Tuning.relicRadius
        case .oil: return Tuning.oilRadius
        }
    }

    /// The per-chest seed (also seeds the session's Dreamer twitches).
    static func chestSeed(seed: UInt64, index: Int) -> UInt64 {
        let i: UInt64 = UInt64(max(0, index)) &+ 1
        var r = SeededRandom(seed: seed ^ (i &* 0x9E37_79B9_7F4A_7C15))
        return r.next()
    }

    private enum Slot { case copper, silver, gem, relic, oil }

    /// Deterministic: the same (seed, index, found) gives the same chest. Relic chests prefer relics not in `found`.
    static func chest(seed: UInt64, index: Int, found: Set<RelicID>) -> ChestSpec {
        var rng = SeededRandom(seed: chestSeed(seed: seed, index: index))
        let tier: ChestTier = ChestFactory.tier(forIndex: index)

        // The personality.
        let u: Double = rng.unit()
        let kinds: [MimicKind] = [.snorer, .lightSleeper, .heavySleeper, .dreamer]
        let weights: [Double] = [Tuning.snorerWeight, Tuning.lightSleeperWeight, Tuning.heavySleeperWeight,
                                 Tuning.dreamerWeight]
        let total: Double = weights.reduce(0, +)
        var mimic: MimicKind = .dreamer
        var acc: Double = 0
        var k: Int = 0
        while k < kinds.count {
            acc += weights[k] / total
            if u < acc { mimic = kinds[k]; break }
            k += 1
        }
        if index == 0 && mimic == .lightSleeper { mimic = .snorer }
        let nameRoll: UInt64 = rng.next()

        // How many of what.
        var n: Int = rng.int(itemCount(for: tier))
        if mimic == .heavySleeper { n = max(Tuning.minItems, n - Tuning.heavySleeperItemPenalty) }
        let hasRelic: Bool = tier != .wooden && rng.unit() < Tuning.relicChance
        var oil: Int = rng.unit() < Tuning.oilChance ? 1 : 0
        var gems: Int = rng.int(Tuning.gemCount)
        var coppers: Int = rng.int(Tuning.copperCount)
        let relics: Int = hasRelic ? 1 : 0
        var silver: Int = n - relics - oil - gems - coppers
        while silver < 0 {
            if coppers > 1 { coppers -= 1 } else if gems > 1 { gems -= 1 } else if oil > 0 { oil = 0 } else { break }
            silver += 1
        }
        silver = max(0, silver)

        var slots: [Slot] = []
        slots.append(contentsOf: Array(repeating: Slot.relic, count: relics))
        slots.append(contentsOf: Array(repeating: Slot.gem, count: gems))
        slots.append(contentsOf: Array(repeating: Slot.oil, count: oil))
        slots.append(contentsOf: Array(repeating: Slot.silver, count: silver))
        slots.append(contentsOf: Array(repeating: Slot.copper, count: coppers))

        // Deal each item: value, depth, (colour / which relic), position, rotation.
        var items: [LootItem] = []
        var id: Int = 0
        for slot in slots {
            let kind: LootKind
            let value: Int
            let depth: Double
            switch slot {
            case .copper:
                value = rng.int(Tuning.copperValue)
                depth = rng.range(Tuning.copperDepth)
                kind = .copper
            case .silver:
                value = rng.int(Tuning.silverValue)
                depth = rng.range(Tuning.silverDepth)
                kind = .silver
            case .gem:
                value = rng.int(Tuning.gemValue)
                depth = rng.range(Tuning.gemDepth)
                let colors: [GemColor] = GemColor.allCases
                kind = .gem(colors[rng.int(0...(colors.count - 1))])
            case .relic:
                value = rng.int(Tuning.relicValue)
                depth = rng.range(Tuning.relicDepth)
                let pick: Double = rng.unit()
                let all: [RelicID] = RelicCatalog.ids
                let unfound: [RelicID] = all.filter { (r: RelicID) -> Bool in !found.contains(r) }
                let pool: [RelicID] = unfound.isEmpty ? all : unfound
                let at: Int = min(pool.count - 1, Int(pick * Double(pool.count)))
                kind = .relic(pool[max(0, at)])
            case .oil:
                value = 0
                depth = rng.range(Tuning.oilDepth)
                kind = .oil
            }
            let r: CGFloat = radius(for: kind)
            let pos: CGPoint = place(&rng, depth: depth, radius: r, among: items)
            let rotation: Double = rng.range(-Tuning.lootRotation...Tuning.lootRotation)
            items.append(LootItem(id: id, kind: kind, value: value, depth: depth, position: pos, radius: r,
                                  rotation: rotation))
            id += 1
        }

        return ChestSpec(index: index, tier: tier, mimic: mimic,
                         mimicName: MimicNames.name(for: mimic, seed: nameRoll),
                         multiplier: multiplier(for: tier), decay: decay(for: tier), items: items)
    }

    /// A free spot inside FloorSpace.interior: deeper items sit further back (smaller y) on average, with jitter.
    /// Never overlaps (≥ radius sum + Tuning.lootGap).
    static func place(_ rng: inout SeededRandom, depth: Double, radius: CGFloat, among items: [LootItem]) -> CGPoint {
        let box: CGRect = FloorSpace.interior
        let r: Double = Double(radius)
        let minX: Double = Double(box.minX) + r
        let maxX: Double = Double(box.maxX) - r
        let minY: Double = Double(box.minY) + r
        let maxY: Double = Double(box.maxY) - r
        func isFree(_ x: Double, _ y: Double) -> Bool {
            for o in items {
                let dx: Double = Double(o.position.x) - x
                let dy: Double = Double(o.position.y) - y
                let need: Double = Double(o.radius) + r + Tuning.lootGap
                if (dx * dx + dy * dy).squareRoot() < need { return false }
            }
            return true
        }
        let baseY: Double = maxY - depth * (maxY - minY)
        var t: Int = 0
        while t < Tuning.placementTries {
            let x: Double = rng.range(minX...maxX)
            let spread: Double = Tuning.placementJitterY * (1 + Double(t) / 15)
            let y: Double = min(max(baseY + rng.range(-spread...spread), minY), maxY)
            if isFree(x, y) { return CGPoint(x: CGFloat(x), y: CGFloat(y)) }
            t += 1
        }
        var y: Double = minY
        while y <= maxY {
            var x: Double = minX
            while x <= maxX {
                if isFree(x, y) { return CGPoint(x: CGFloat(x), y: CGFloat(y)) }
                x += Tuning.placementGridStep
            }
            y += Tuning.placementGridStep
        }
        return CGPoint(x: CGFloat((minX + maxX) / 2), y: CGFloat((minY + maxY) / 2))
    }

    /// The First Chest lesson's scripted chest (ROUND-1: 2 copper, 1 silver, 1 gem; a Heavy sleeper).
    static func lessonChest() -> ChestSpec {
        let items: [LootItem] = [
            LootItem(id: 0, kind: .copper, value: 6, depth: 0.05, position: CGPoint(x: 250, y: 280),
                     radius: Tuning.copperRadius, rotation: 0.2),
            LootItem(id: 1, kind: .copper, value: 8, depth: 0.12, position: CGPoint(x: 420, y: 268),
                     radius: Tuning.copperRadius, rotation: -0.3),
            LootItem(id: 2, kind: .silver, value: 25, depth: 0.28, position: CGPoint(x: 335, y: 196),
                     radius: Tuning.silverRadius, rotation: 0.1),
            LootItem(id: 3, kind: .gem(.ruby), value: 80, depth: 0.45, position: CGPoint(x: 300, y: 104),
                     radius: Tuning.gemRadius, rotation: 0),
        ]
        return ChestSpec(index: 0, tier: .wooden, mimic: .heavySleeper,
                         mimicName: MimicNames.names(for: .heavySleeper)[0],
                         multiplier: Tuning.woodenMultiplier, decay: Tuning.woodenDecay, items: items)
    }
}

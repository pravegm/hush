import SpriteKit
import UIKit

/// One drawn item: contact shadow, the warm pool of light it sits in, a relic's golden ray, the art, and a glint.
@MainActor
final class SceneLootSlot {
    let node: SKNode
    let shadow: SKSpriteNode
    let halo: SKSpriteNode
    let ray: SKSpriteNode
    let art: SKSpriteNode
    let sparkle: SKSpriteNode
    var key = ""
    var id = -1
    var radius: CGFloat = 20
    var bounceAge: Double = 10
    var revealAge: Double = 10
    var lostAge: Double?
    var lostFrom: CGPoint = .zero
    var lostSpin: CGFloat = 1
    /// Seconds since it went into the bag (nil = not bagged), and where it jumped from.
    var bagAge: Double?
    var bagFrom: CGPoint = .zero
    var glints = true
    var isRelic = false
    var phase: CGFloat = 0

    init() {
        let n = SKNode()
        let sh = SKSpriteNode(texture: SceneTextures.shadow)
        sh.color = ScenePaint.ui(ChestArt.palette.dungeonDeep)
        sh.colorBlendFactor = 1
        sh.zPosition = 0
        let h = SKSpriteNode(texture: SceneTextures.glow)
        h.blendMode = .add
        h.colorBlendFactor = 1
        h.color = ScenePaint.ui(ChestArt.palette.candle)
        h.zPosition = 0.5
        let r = SKSpriteNode(texture: SceneTextures.rays)
        r.blendMode = .add
        r.colorBlendFactor = 1
        r.color = ScenePaint.ui(ChestArt.palette.gold)
        r.zPosition = 0.4
        r.isHidden = true
        let a = SKSpriteNode()
        a.zPosition = 1
        let sp = SKSpriteNode(texture: SceneTextures.sparkle)
        sp.blendMode = .add
        sp.colorBlendFactor = 1
        sp.color = UIColor(red: 1, green: 0.97, blue: 0.85, alpha: 1)
        sp.zPosition = 2
        sp.alpha = 0
        for c in [sh, r, h, a, sp] { n.addChild(c) }
        node = n
        shadow = sh
        halo = h
        ray = r
        art = a
        sparkle = sp
    }

    func configure(_ item: LootItem) {
        let r = max(item.radius, 6)
        let k = "\(SceneTextures.lootKey(item.kind))-\(Int(r.rounded()))"
        guard k != key else { return }
        key = k
        radius = r
        art.texture = SceneTextures.loot(item.kind, radius: r)
        let side = SceneTextures.lootSide(r)
        art.size = CGSize(width: side, height: side)
        shadow.size = CGSize(width: r * 2.3, height: r * 1.1)
        halo.size = CGSize(width: r * 3.6, height: r * 3.6)
        ray.size = CGSize(width: r * 7, height: r * 7)
        sparkle.size = CGSize(width: r * 1.3, height: r * 1.3)
        sparkle.position = CGPoint(x: -r * 0.36, y: r * 0.42)
        isRelic = false
        glints = true
        switch item.kind {
        case .relic:
            isRelic = true
            halo.color = ScenePaint.ui(ChestArt.palette.gold)
        case .gem:
            halo.color = ScenePaint.ui(ChestArt.lootColors(item.kind).fill.mixed(with: ChestArt.palette.candle, 0.5))
        case .oil:
            glints = false
            halo.color = ScenePaint.ui(ChestArt.palette.amber)
        case .copper, .silver:
            halo.color = ScenePaint.ui(ChestArt.palette.candle)
        }
    }
}

/// The loot as the snapshot has it (floor space → canvas), with the cosmetic touches: reveal pops, glints, drops and
/// bags bouncing, the bitten loot flying into the mouth. It never moves an item itself except for the bite flight.
@MainActor
final class SceneLootView {
    let root: SKNode
    private var free: [SceneLootSlot] = []
    private var live: [Int: SceneLootSlot] = [:]
    private var states: [Int: LootState] = [:]
    private var time: Double = 0
    /// Items drawn this frame (tests).
    private(set) var visibleCount = 0
    /// The first held item's canvas point (the eye watches it).
    private(set) var heldPoint: CGPoint?

    static let lostFlightTime: Double = 0.45

    init() {
        root = SKNode()
    }

    func clearAll() {
        for (_, s) in live {
            s.node.isHidden = true
            free.append(s)
        }
        live = [:]
        states = [:]
        heldPoint = nil
        visibleCount = 0
    }

    func bounce(_ id: Int) { live[id]?.bounceAge = 0 }
    func revealed(_ id: Int) { live[id]?.revealAge = 0 }

    /// An item's canvas point as last drawn.
    func canvasPoint(_ id: Int) -> CGPoint? {
        guard let s = live[id] else { return nil }
        return CGPoint(x: s.node.position.x + root.position.x, y: s.node.position.y + root.position.y)
    }

    /// The bagged items as last drawn (the bank's flyers start from here).
    func bagged() -> [(kind: LootKind, radius: CGFloat, point: CGPoint)] {
        var out: [(kind: LootKind, radius: CGFloat, point: CGPoint)] = []
        for st in states.values.sorted(by: { $0.id < $1.id }) where st.place == .inBag {
            let p = canvasPoint(st.id) ?? ChestLayout.canvas(fromFloor: st.position)
            out.append((st.item.kind, max(st.item.radius, 6), p))
        }
        return out
    }

    private func acquire() -> SceneLootSlot {
        let s = free.popLast() ?? SceneLootSlot()
        if s.node.parent == nil { root.addChild(s.node) }
        s.node.isHidden = false
        s.bounceAge = 10
        s.revealAge = 10
        s.lostAge = nil
        s.bagAge = nil
        s.node.alpha = 1
        return s
    }

    private static func smooth(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = min(max((x - a) / max(b - a, 0.0001), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Where bagged item number `k` sits in the satchel's mouth (canvas): a pile of two staggered rows between the
    /// in-hand and gold panels, so the numbers stay clear. Core's own bag slots are not drawn (the whole strip is the
    /// drop target; bagged loot isn't touchable).
    static func pilePoint(_ k: Int) -> CGPoint {
        let i = max(k, 0) % 10
        let row = i / 5
        let col = i % 5
        return CGPoint(x: 283 + CGFloat(col) * 26 + (row == 1 ? 13 : 0), y: row == 0 ? 60 : 82)
    }

    static let pileScale: CGFloat = 0.66

    func update(dt: Double, loot: [LootState], hideBagged: Bool, light: CGFloat) {
        time += dt
        var seen = Set<Int>()
        var visible = 0
        var held: CGPoint?
        let mouth = CGPoint(x: ChestLayout.mouthPoint.x - root.position.x, y: ChestLayout.mouthPoint.y - root.position.y)
        // Bag order: Core fills its slots row by row, so sorting by (y, x) keeps the order they went in.
        let inBag = loot.filter { $0.place == .inBag }.sorted {
            $0.position.y != $1.position.y ? $0.position.y < $1.position.y : $0.position.x < $1.position.x
        }
        var bagIndex: [Int: Int] = [:]
        for (k, st) in inBag.enumerated() { bagIndex[st.id] = k }
        for st in loot {
            seen.insert(st.id)
            let slot: SceneLootSlot
            if let s = live[st.id] {
                slot = s
            } else {
                slot = acquire()
                slot.id = st.id
                slot.phase = SceneRNG.hash(st.id, 0x61_17)
                slot.lostSpin = slot.phase < 0.5 ? -1 : 1
                live[st.id] = slot
            }
            states[st.id] = st
            slot.configure(st.item)
            let r = slot.radius
            let p = ChestLayout.canvas(fromFloor: st.position)
            let l = CGFloat(min(max(st.light.isFinite ? st.light : 0, 0), 1))
            slot.bounceAge += dt
            slot.revealAge += dt
            let b = slot.bounceAge < 0.3 ? 1 + 0.2 * CGFloat(sin(slot.bounceAge / 0.3 * Double.pi)) : 1
            let tw = pow(max(0, sin(CGFloat(time) * 2.3 + slot.phase * 6.283)), 14)
            slot.art.zRotation = CGFloat(st.item.rotation)
            slot.sparkle.zRotation = CGFloat(time) * 0.8
            if case .lost = st.place {
                // Bitten: fly into the mouth, shrinking and spinning.
                if slot.lostAge == nil {
                    slot.lostAge = 0
                    slot.lostFrom = slot.node.isHidden ? p : slot.node.position
                }
                let age = (slot.lostAge ?? 0) + dt
                slot.lostAge = age
                let t = CGFloat(min(age / SceneLootView.lostFlightTime, 1))
                let a = slot.lostFrom
                let c = CGPoint(x: (a.x + mouth.x) / 2, y: max(a.y, mouth.y) + 90)
                let u = 1 - t
                slot.node.position = CGPoint(x: u * u * a.x + 2 * u * t * c.x + t * t * mouth.x,
                                             y: u * u * a.y + 2 * u * t * c.y + t * t * mouth.y)
                slot.node.setScale(1 - 0.7 * t)
                slot.node.zPosition = 30
                slot.art.zRotation = CGFloat(st.item.rotation) + slot.lostSpin * t * 7
                slot.art.alpha = 1
                slot.art.colorBlendFactor = 0
                slot.node.alpha = 1 - SceneLootView.smooth(0.75, 1, t)
                slot.node.isHidden = t >= 1
                slot.halo.alpha = 0
                slot.ray.isHidden = true
                slot.shadow.alpha = 0
                slot.sparkle.alpha = 0
                if t < 1 { visible += 1 }
                continue
            }
            slot.lostAge = nil
            slot.node.alpha = 1
            if st.place == .inBag {
                // Pop from where it was dropped into its place in the pile.
                if slot.bagAge == nil {
                    slot.bagAge = 0
                    slot.bagFrom = slot.node.isHidden ? p : slot.node.position
                }
                let age = (slot.bagAge ?? 0) + dt
                slot.bagAge = age
                let pile = SceneLootView.pilePoint(bagIndex[st.id] ?? 0)
                let target = CGPoint(x: pile.x - root.position.x, y: pile.y - root.position.y)
                let k = SceneLootView.smooth(0, 1, CGFloat(min(age / 0.18, 1)))
                slot.node.position = CGPoint(x: slot.bagFrom.x + (target.x - slot.bagFrom.x) * k,
                                             y: slot.bagFrom.y + (target.y - slot.bagFrom.y) * k)
            } else {
                slot.bagAge = nil
                slot.node.position = p
            }
            switch st.place {
            case .inChest:
                let vis = SceneLootView.smooth(0, 0.4, l)
                slot.node.isHidden = vis <= 0.002
                slot.node.zPosition = 0
                slot.node.setScale(b)
                slot.art.alpha = vis
                slot.art.color = .black
                slot.art.colorBlendFactor = (1 - l) * 0.72
                let pop: CGFloat = slot.revealAge < 0.5 ? 1 + 0.9 * CGFloat(1 - slot.revealAge / 0.5) : 1
                slot.halo.alpha = min(1, 0.5 * l * light * pop)
                slot.halo.setScale(pop)
                slot.shadow.alpha = 0.45 * vis
                slot.shadow.position = CGPoint(x: 2, y: -r * 0.38)
                slot.sparkle.alpha = slot.glints && l >= 0.6 ? tw * light : 0
                if slot.isRelic && l >= 0.4 {
                    slot.ray.isHidden = false
                    slot.ray.alpha = 0.6 * SceneLootView.smooth(0.4, 1, l) * light
                    slot.ray.zRotation = CGFloat(time) * 0.35
                    slot.ray.setScale(1 + 0.04 * CGFloat(sin(time * 2)))
                } else {
                    slot.ray.isHidden = true
                }
            case .held:
                slot.node.isHidden = false
                slot.node.zPosition = 20
                slot.node.setScale(1.15 * b)
                slot.art.alpha = 1
                slot.art.colorBlendFactor = 0
                slot.halo.alpha = 0.35 * light
                slot.halo.setScale(1)
                slot.shadow.alpha = 0.5
                slot.shadow.position = CGPoint(x: 8, y: -r * 0.7)
                slot.sparkle.alpha = slot.glints ? tw : 0
                slot.ray.isHidden = true
                if held == nil { held = CGPoint(x: p.x + root.position.x, y: p.y + root.position.y) }
            case .inBag:
                slot.node.isHidden = hideBagged
                // Under the HUD (z 30) so the in-hand value and the counter stay readable over bagged loot.
                slot.node.zPosition = (bagIndex[st.id] ?? 0) < 5 ? 1.2 : 1
                slot.node.setScale(SceneLootView.pileScale * b)
                slot.art.alpha = 1
                slot.art.colorBlendFactor = 0
                slot.halo.alpha = 0
                slot.shadow.alpha = 0.35
                slot.shadow.position = CGPoint(x: 2, y: -r * 0.4)
                slot.sparkle.alpha = slot.glints ? tw * 0.6 : 0
                slot.ray.isHidden = true
            case .lost:
                break
            }
            if !slot.node.isHidden { visible += 1 }
        }
        var gone: [Int] = []
        for id in live.keys where !seen.contains(id) { gone.append(id) }
        for id in gone {
            if let s = live[id] {
                s.node.isHidden = true
                free.append(s)
            }
            live[id] = nil
            states[id] = nil
        }
        visibleCount = visible
        heldPoint = held
    }
}

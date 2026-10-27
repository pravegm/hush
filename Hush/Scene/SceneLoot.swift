import SpriteKit
import UIKit

/// One drawn item: contact shadow, the warm pool of light it sits in, a relic's golden ray, the art, a glint, and
/// (R2) a relic's glimmer while it is almost lit.
@MainActor
final class SceneLootSlot {
    let node: SKNode
    let shadow: SKSpriteNode
    let halo: SKSpriteNode
    let ray: SKSpriteNode
    let art: SKSpriteNode
    let sparkle: SKSpriteNode
    let glimmer: SKSpriteNode
    /// The item this slot is dressed for (configured only when it changes: no per-frame work).
    var item: LootItem?
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
    var bagIndex = 0
    var stamp = 0
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
        let gl = SKSpriteNode(texture: SceneTextures.sparkle)
        gl.blendMode = .add
        gl.colorBlendFactor = 1
        gl.color = ScenePaint.ui(ChestArt.palette.gold)
        gl.zPosition = 3
        gl.alpha = 0
        gl.isHidden = true
        for c in [sh, r, h, a, sp, gl] { n.addChild(c) }
        node = n
        shadow = sh
        halo = h
        ray = r
        art = a
        sparkle = sp
        glimmer = gl
    }

    func configure(_ it: LootItem) {
        guard item != it else { return }
        item = it
        let r = max(it.radius, 6)
        radius = r
        art.texture = SceneTextures.loot(it.kind, radius: r, value: it.value)
        let side = SceneTextures.lootSide(r)
        art.size = CGSize(width: side, height: side)
        shadow.size = CGSize(width: r * 2.3, height: r * 1.1)
        halo.size = CGSize(width: r * 3.6, height: r * 3.6)
        ray.size = CGSize(width: r * 7, height: r * 7)
        sparkle.size = CGSize(width: r * 1.3, height: r * 1.3)
        sparkle.position = CGPoint(x: -r * 0.36, y: r * 0.42)
        glimmer.size = CGSize(width: r * 1.9, height: r * 1.9)
        isRelic = false
        glints = true
        switch it.kind {
        case .relic:
            isRelic = true
            halo.color = ScenePaint.ui(ChestArt.palette.gold)
        case .gem:
            halo.color = ScenePaint.ui(ChestArt.lootColors(it.kind).fill.mixed(with: ChestArt.palette.candle, 0.5))
        case .oil:
            glints = false
            halo.color = ScenePaint.ui(ChestArt.palette.amber)
        case .copper, .silver:
            halo.color = ScenePaint.ui(ChestArt.palette.candle)
        }
    }
}

/// The loot as the snapshot has it (floor space → canvas), with the cosmetic touches: reveal pops, glints, drops and
/// bags bouncing, the bitten loot flying into the mouth, a relic's glimmer when it is nearly lit. It never moves an
/// item itself except for the bite flight and the hop into the pouch. Per frame it allocates nothing (scratch buffers
/// are reused).
@MainActor
final class SceneLootView {
    let root: SKNode
    private var free: [SceneLootSlot] = []
    private var live: [Int: SceneLootSlot] = [:]
    private var states: [Int: LootState] = [:]
    private var time: Double = 0
    private var frameStamp = 0
    private var bagScratch: [(id: Int, y: CGFloat, x: CGFloat)] = []
    private var goneScratch: [Int] = []
    /// Items drawn this frame (tests).
    private(set) var visibleCount = 0
    /// Relics glimmering this frame (tests).
    private(set) var glimmerCount = 0
    /// The first held item's canvas point (the eye watches it).
    private(set) var heldPoint: CGPoint?

    static let lostFlightTime: Double = 0.45

    init() {
        root = SKNode()
        bagScratch.reserveCapacity(16)
        goneScratch.reserveCapacity(16)
    }

    func clearAll() {
        for (_, s) in live {
            s.node.isHidden = true
            free.append(s)
        }
        live.removeAll(keepingCapacity: true)
        states.removeAll(keepingCapacity: true)
        heldPoint = nil
        visibleCount = 0
        glimmerCount = 0
    }

    func bounce(_ id: Int) { live[id]?.bounceAge = 0 }
    func revealed(_ id: Int) { live[id]?.revealAge = 0 }

    /// An item's canvas point as last drawn.
    func canvasPoint(_ id: Int) -> CGPoint? {
        guard let s = live[id] else { return nil }
        return CGPoint(x: s.node.position.x + root.position.x, y: s.node.position.y + root.position.y)
    }

    /// The bagged items as last drawn (the bank's flyers start from here).
    func bagged() -> [(kind: LootKind, radius: CGFloat, value: Int, point: CGPoint)] {
        var out: [(kind: LootKind, radius: CGFloat, value: Int, point: CGPoint)] = []
        for st in states.values.sorted(by: { $0.id < $1.id }) where st.place == .inBag {
            let p = canvasPoint(st.id) ?? ChestLayout.canvas(fromFloor: st.position)
            out.append((st.item.kind, max(st.item.radius, 6), st.item.value, p))
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
        s.item = nil
        s.node.alpha = 1
        return s
    }

    private static func smooth(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = min(max((x - a) / max(b - a, 0.0001), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Where bagged item number `k` sits in the pouch's mouth (canvas): a back row and a front row, half hidden by the
    /// pouch's front lip so the loot sits IN the pouch (not at the buckles, not under the numbers). Core's own bag
    /// slots are not drawn (the whole strip is the drop target; bagged loot isn't touchable).
    static func pilePoint(_ k: Int) -> CGPoint {
        let i = max(k, 0) % 10
        let row = i / 5
        let col = i % 5
        let m = ChestLayout.pouchMouth
        return CGPoint(x: m.x - 36 + CGFloat(col) * 18 + (row == 1 ? 9 : 0), y: row == 0 ? m.y + 4 : m.y - 4)
    }

    static let pileScale: CGFloat = 0.66

    /// How strongly a relic glimmers (0 … 1): it is within 0.25 of being lit and not yet revealed.
    /// R3 (QA-2 P2-6): on exactly when Core's hint and sound are (`HeistSession.relicGlimmers`), brightening toward
    /// the glint line.
    static func glimmer(depth: Double, openness: Double, light: Double) -> CGFloat {
        guard depth.isFinite, openness.isFinite, HeistSession.relicGlimmers(depth: depth, openness: openness) else {
            return 0
        }
        let glintAt = depth + Tuning.revealLight * Tuning.lightRamp
        let range = max(Tuning.relicGlimmerRange, 0.01)
        let ramp = CGFloat(min(max((openness - (glintAt - range)) / range, 0), 1))
        let near = 0.35 + 0.65 * ramp
        let l = CGFloat(min(max(light.isFinite ? light : 0, 0), 1))
        return near * (1 - smooth(0.15, 0.45, l))
    }

    func update(dt: Double, loot: [LootState], hideBagged: Bool, light: CGFloat, openness: Double = 0) {
        time += dt
        frameStamp &+= 1
        var visible = 0
        var glimmering = 0
        var held: CGPoint?
        let mouth = CGPoint(x: ChestLayout.mouthPoint.x - root.position.x, y: ChestLayout.mouthPoint.y - root.position.y)

        // Pass 1: a slot per item; collect the bag's order (Core fills its slots row by row, so (y, x) keeps the
        // order they went in).
        bagScratch.removeAll(keepingCapacity: true)
        for st in loot {
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
            slot.stamp = frameStamp
            states[st.id] = st
            slot.configure(st.item)
            if st.place == .inBag { bagScratch.append((st.id, st.position.y, st.position.x)) }
        }
        // A tiny insertion sort (no allocation).
        if bagScratch.count > 1 {
            for i in 1..<bagScratch.count {
                let v = bagScratch[i]
                var j = i - 1
                while j >= 0 && (bagScratch[j].y > v.y || (bagScratch[j].y == v.y && bagScratch[j].x > v.x)) {
                    bagScratch[j + 1] = bagScratch[j]
                    j -= 1
                }
                bagScratch[j + 1] = v
            }
        }
        for (k, e) in bagScratch.enumerated() { live[e.id]?.bagIndex = k }

        // Pass 2: draw.
        for st in loot {
            guard let slot = live[st.id] else { continue }
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
                slot.glimmer.isHidden = true
                if t < 1 { visible += 1 }
                continue
            }
            slot.lostAge = nil
            slot.node.alpha = 1
            if st.place == .inBag {
                // Hop from where it was dropped into its place in the pouch.
                if slot.bagAge == nil {
                    slot.bagAge = 0
                    slot.bagFrom = slot.node.isHidden ? p : slot.node.position
                }
                let age = (slot.bagAge ?? 0) + dt
                slot.bagAge = age
                let pile = SceneLootView.pilePoint(slot.bagIndex)
                let target = CGPoint(x: pile.x - root.position.x, y: pile.y - root.position.y)
                let k = SceneLootView.smooth(0, 1, CGFloat(min(age / 0.18, 1)))
                let hop = 26 * CGFloat(sin(Double(k) * Double.pi))
                slot.node.position = CGPoint(x: slot.bagFrom.x + (target.x - slot.bagFrom.x) * k,
                                             y: slot.bagFrom.y + (target.y - slot.bagFrom.y) * k + hop)
            } else {
                slot.bagAge = nil
                slot.node.position = p
            }
            slot.glimmer.isHidden = true
            switch st.place {
            case .inChest:
                let vis = SceneLootView.smooth(0, 0.4, l)
                var gl: CGFloat = 0
                if slot.isRelic {
                    gl = SceneLootView.glimmer(depth: st.item.depth, openness: openness, light: Double(l))
                }
                slot.node.isHidden = vis <= 0.002 && gl <= 0.002
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
                if gl > 0.002 {
                    // A faint pulsing sparkle at the relic's spot ("Something glints deeper…").
                    let pulse = 0.5 + 0.5 * sin(time * 4.2 + Double(slot.phase) * 6.283)
                    slot.glimmer.isHidden = false
                    slot.glimmer.alpha = gl * CGFloat(0.25 + 0.55 * pulse)
                    slot.glimmer.zRotation = CGFloat(time) * 0.6
                    slot.glimmer.setScale(0.7 + 0.35 * CGFloat(pulse))
                    glimmering += 1
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
                // In the pouch: the back row under the front row, all under the pouch's front lip (HUD z 30).
                slot.node.zPosition = slot.bagIndex % 10 < 5 ? 1 : 1.2
                slot.node.setScale(SceneLootView.pileScale * b)
                slot.art.alpha = 1
                slot.art.colorBlendFactor = 0
                slot.halo.alpha = 0
                slot.shadow.alpha = 0
                slot.sparkle.alpha = slot.glints ? tw * 0.6 : 0
                slot.ray.isHidden = true
            case .lost:
                break
            }
            if !slot.node.isHidden && slot.art.alpha > 0.002 { visible += 1 }
        }
        goneScratch.removeAll(keepingCapacity: true)
        for (id, s) in live where s.stamp != frameStamp { goneScratch.append(id) }
        for id in goneScratch {
            if let s = live[id] {
                s.node.isHidden = true
                free.append(s)
            }
            live[id] = nil
            states[id] = nil
        }
        visibleCount = visible
        glimmerCount = glimmering
        heldPoint = held
    }
}

import SpriteKit
import UIKit

/// One cosmetic particle (dust, coin sparks, smoke). Simulated by the scene, never by Core.
struct SceneParticle {
    var position: CGPoint = .zero
    var velocity: CGVector = CGVector(dx: 0, dy: 0)
    var life: CGFloat = 0
    var maxLife: CGFloat = 1
    var gravity: CGFloat = 0
    var drag: CGFloat = 0
    var spin: CGFloat = 0
    var shrink: Bool = true
    /// Grows by this factor over its life (dust billowing, smoke).
    var growth: CGFloat = 0
    /// Peak opacity.
    var alphaScale: CGFloat = 1
    var active: Bool = false
}

/// A fixed pool of sprites (one blend mode; textures swapped per spawn). Nothing is allocated per frame.
@MainActor
final class SceneParticlePool {
    let root: SKNode
    private var sprites: [SKSpriteNode] = []
    private var parts: [SceneParticle] = []
    private var cursor = 0
    /// Spawns are scaled by this (1 normally; fewer with Reduce Motion).
    var density: CGFloat = 1

    init(capacity: Int, texture: SKTexture, blend: SKBlendMode) {
        root = SKNode()
        for _ in 0..<max(capacity, 1) {
            let s = SKSpriteNode(texture: texture, size: CGSize(width: 6, height: 6))
            s.colorBlendFactor = 1
            s.blendMode = blend
            s.isHidden = true
            root.addChild(s)
            sprites.append(s)
            parts.append(SceneParticle())
        }
    }

    var activeCount: Int {
        var n = 0
        for p in parts where p.active { n += 1 }
        return n
    }

    func clear() {
        for i in 0..<parts.count {
            parts[i].active = false
            sprites[i].isHidden = true
        }
    }

    func update(_ dt: CGFloat) {
        guard dt > 0 else { return }
        for i in 0..<parts.count where parts[i].active {
            var p = parts[i]
            p.life -= dt
            p.velocity.dy -= p.gravity * dt
            if p.drag > 0 {
                let k = max(0, 1 - p.drag * dt)
                p.velocity.dx *= k
                p.velocity.dy *= k
            }
            p.position.x += p.velocity.dx * dt
            p.position.y += p.velocity.dy * dt
            let s = sprites[i]
            if p.life <= 0 {
                p.active = false
                s.isHidden = true
                parts[i] = p
                continue
            }
            let k = max(0, min(1, p.life / max(p.maxLife, 0.001)))
            s.position = p.position
            s.alpha = min(1, k * 3) * p.alphaScale
            var scale: CGFloat = p.shrink ? (0.35 + 0.65 * k) : 1
            if p.growth > 0 { scale *= 1 + p.growth * (1 - k) }
            s.zRotation += p.spin * dt
            s.setScale(scale)
            parts[i] = p
        }
    }

    func spawn(_ p: SceneParticle, size: CGFloat, color: UIColor, texture: SKTexture? = nil) {
        let n = parts.count
        guard n > 0 else { return }
        var slot = -1
        for k in 0..<n {
            let idx = (cursor + k) % n
            if !parts[idx].active {
                slot = idx
                break
            }
        }
        if slot < 0 { slot = cursor }
        cursor = (slot + 1) % n
        var q = p
        q.active = true
        q.maxLife = max(q.life, 0.01)
        parts[slot] = q
        let s = sprites[slot]
        if let t = texture, s.texture !== t { s.texture = t }
        s.size = CGSize(width: size, height: size)
        s.color = color
        s.colorBlendFactor = 1
        s.position = q.position
        s.zRotation = 0
        s.setScale(1)
        s.alpha = q.alphaScale
        s.isHidden = false
    }
}

/// The scene's particle effects: one normal pool (dust, smoke) and one additive pool (sparks, glints, coin bursts).
@MainActor
final class SceneEffects {
    let root: SKNode
    let dust: SceneParticlePool
    let sparks: SceneParticlePool
    var reduceMotion = false {
        didSet {
            dust.density = reduceMotion ? 0.4 : 1
            sparks.density = reduceMotion ? 0.4 : 1
        }
    }
    private var rng = SceneRNG(seed: 0xD0_57)
    private let sparkTexture: SKTexture
    private let dotTexture: SKTexture

    init() {
        root = SKNode()
        sparkTexture = SceneTextures.sparkle
        dotTexture = SceneTextures.dot
        dust = SceneParticlePool(capacity: 20, texture: SceneTextures.soft, blend: .alpha)
        sparks = SceneParticlePool(capacity: 28, texture: SceneTextures.sparkle, blend: .add)
        dust.root.zPosition = 0
        sparks.root.zPosition = 1
        root.addChild(dust.root)
        root.addChild(sparks.root)
    }

    func update(_ dt: CGFloat) {
        dust.update(dt)
        sparks.update(dt)
    }

    func clear() {
        dust.clear()
        sparks.clear()
    }

    private func count(_ n: Int, _ pool: SceneParticlePool) -> Int { max(1, Int((CGFloat(n) * pool.density).rounded())) }

    /// A puff of dust along a line (a chest landing, a dropped item).
    func dustPuff(from a: CGPoint, to b: CGPoint, count n: Int, color: UIColor, size: CGFloat = 40) {
        for _ in 0..<count(n, dust) {
            let t = rng.unit()
            let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            var q = SceneParticle()
            q.position = p
            q.velocity = CGVector(dx: rng.range(-60, 60), dy: rng.range(10, 70))
            q.life = rng.range(0.5, 0.9)
            q.drag = 2.4
            q.growth = 1.4
            q.shrink = false
            q.alphaScale = rng.range(0.35, 0.6)
            dust.spawn(q, size: size * rng.range(0.7, 1.2), color: color)
        }
    }

    /// Sparks bursting out of a point (coins clinking, reveals, the bank).
    func sparkBurst(at p: CGPoint, count n: Int, color: UIColor, speed: CGFloat = 180, size: CGFloat = 22) {
        for _ in 0..<count(n, sparks) {
            let a = rng.range(0, 2 * .pi)
            let v = rng.range(0.4, 1) * speed
            var q = SceneParticle()
            q.position = p
            q.velocity = CGVector(dx: cos(a) * v, dy: sin(a) * v)
            q.life = rng.range(0.35, 0.7)
            q.drag = 3
            q.gravity = 60
            q.spin = rng.range(-6, 6)
            q.alphaScale = 1
            sparks.spawn(q, size: size * rng.range(0.6, 1.2), color: color, texture: sparkTexture)
        }
    }

    /// A curl of smoke rising (the torch going out).
    func smoke(at p: CGPoint, count n: Int) {
        for i in 0..<count(n, dust) {
            var q = SceneParticle()
            q.position = CGPoint(x: p.x + rng.range(-4, 4), y: p.y + CGFloat(i) * 3)
            q.velocity = CGVector(dx: rng.range(-12, 12), dy: rng.range(30, 60))
            q.life = rng.range(0.9, 1.5)
            q.drag = 0.6
            q.growth = 2.2
            q.shrink = false
            q.alphaScale = 0.5
            dust.spawn(q, size: 18, color: UIColor(white: 0.55, alpha: 1))
        }
    }

    /// One drifting mote of dust in the light (ambience).
    func mote(in r: CGRect, color: UIColor) {
        var q = SceneParticle()
        q.position = CGPoint(x: rng.range(r.minX, r.maxX), y: rng.range(r.minY, r.maxY))
        q.velocity = CGVector(dx: rng.range(-8, 8), dy: rng.range(-10, 6))
        q.life = rng.range(1.6, 2.6)
        q.shrink = false
        q.alphaScale = rng.range(0.25, 0.55)
        sparks.spawn(q, size: rng.range(5, 9), color: color, texture: dotTexture)
    }
}

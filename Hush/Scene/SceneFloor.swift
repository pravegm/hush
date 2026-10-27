import SpriteKit
import UIKit

/// The floor half's chest (the SHARP half): walls and bed, the mimic's velvet tongue (the main tell), the darkness
/// over the interior and the warm wash that spreads from the opening (the fold) as the lid rises. R2: below the floor
/// (on screens taller than the canvas) the chest's front wall with a big brass lock, then the tabletop.
///
/// `chestRoot` slides as a whole (arrival, the hop after a bite, the exit after a bank) and carries the front wall;
/// the satchel and the tabletop stay.
@MainActor
final class SceneFloor {
    let root: SKNode
    let chestRoot: SKNode
    private let satchel: SKSpriteNode
    private let frame: SKSpriteNode
    private let tongue: SKSpriteNode
    private let curl: SKSpriteNode
    private let darkness: SKSpriteNode
    private let frontDark: SKSpriteNode
    private let wash: SKSpriteNode
    private let gloom: SKSpriteNode
    private let wall: SKSpriteNode
    private let lock: SKSpriteNode
    private let table: SKSpriteNode
    private let washHeight: CGFloat = 300

    private(set) var dress: ChestDress = .tier(.wooden)
    private(set) var tier: ChestTier = .wooden
    /// The tongue's curl now (0 flat … 1 curled; tests).
    private(set) var curlLevel: CGFloat = 0
    /// The darkness over the interior now (tests).
    private(set) var darknessAlpha: CGFloat = 0
    /// The candle-low gloom now (tests).
    private(set) var gloomAlpha: CGFloat = 0
    /// The extension drawn below the canvas (pt).
    private(set) var bottomExtension: CGFloat = 0
    private var breathTime: Double = 0
    private var twitchAge: Double = 10
    private var twitchSign: CGFloat = 1
    private var nextTwitch: Double = 1.2
    private var rng = SceneRNG(seed: 0x70_46_E1)
    private var redness: CGFloat = 0

    init() {
        let pal = ChestArt.palette
        let fr = ChestLayout.frameRect
        let frameNode = SKSpriteNode(texture: SceneTextures.chestFrame(.tier(.wooden)), size: fr.size)
        frameNode.position = CGPoint(x: fr.midX, y: fr.midY)
        frameNode.zPosition = 0
        let ts = SceneTextures.tongueSize
        let tongueNode = SKSpriteNode(texture: SceneTextures.tongue, size: ts)
        tongueNode.anchorPoint = CGPoint(x: 0.5, y: 1)
        tongueNode.position = CGPoint(x: ChestLayout.interior.midX, y: ChestLayout.interior.maxY + 6)
        tongueNode.zPosition = 1
        tongueNode.color = UIColor(red: 0.55, green: 0.02, blue: 0.1, alpha: 1)
        tongueNode.colorBlendFactor = 0
        let curlNode = SKSpriteNode(texture: SceneTextures.tongueCurl, size: ts)
        curlNode.anchorPoint = CGPoint(x: 0.5, y: 1)
        curlNode.zPosition = 0.5
        curlNode.alpha = 0
        curlNode.position = .zero
        tongueNode.addChild(curlNode)

        let cover = ChestLayout.rimInner
        let dark = SKSpriteNode(color: ScenePaint.ui(pal.dungeonDeep), size: cover.size)
        dark.position = CGPoint(x: cover.midX, y: cover.midY)
        dark.zPosition = 3
        let front = SKSpriteNode(texture: SceneTextures.vertical("front-dark", [1, 0.55, 0], [0, 0.45, 1]),
                                 size: cover.size)
        front.color = ScenePaint.ui(pal.dungeonDeep)
        front.colorBlendFactor = 1
        front.position = dark.position
        front.zPosition = 3.1
        let washNode = SKSpriteNode(texture: SceneTextures.vertical("wash", [0, 0.35, 1], [0, 0.6, 1]),
                                    size: CGSize(width: cover.width + 30, height: 300))
        washNode.anchorPoint = CGPoint(x: 0.5, y: 1)
        washNode.position = CGPoint(x: cover.midX, y: cover.maxY)
        washNode.color = ScenePaint.ui(pal.candle)
        washNode.colorBlendFactor = 1
        washNode.blendMode = .add
        washNode.zPosition = 4
        // The candle guttering: the floor's edges sink into gloom in the last seconds.
        let gloomNode = SKSpriteNode(texture: SceneTextures.vignette,
                                     size: CGSize(width: ChestLayout.canvas.width, height: ChestLayout.floorTop))
        gloomNode.anchorPoint = .zero
        gloomNode.color = ScenePaint.ui(pal.dungeonDeep)
        gloomNode.colorBlendFactor = 1
        gloomNode.alpha = 0
        gloomNode.isHidden = true
        gloomNode.zPosition = 4.5

        let bag = ChestLayout.bagStrip
        let satchelNode = SKSpriteNode(texture: SceneTextures.satchel,
                                       size: CGSize(width: bag.width, height: bag.height + 2))
        satchelNode.position = CGPoint(x: bag.midX, y: (bag.height + 2) / 2)
        satchelNode.zPosition = 6

        // The extension below the canvas (hidden until a layout asks for it).
        let wallH = ChestLayout.frontWallTop + ChestLayout.frontWallMax
        let wallNode = SKSpriteNode(texture: SceneTextures.frontWall(.tier(.wooden)),
                                    size: CGSize(width: ChestLayout.canvas.width, height: wallH))
        wallNode.anchorPoint = CGPoint(x: 0, y: 1)
        wallNode.position = CGPoint(x: 0, y: ChestLayout.frontWallTop)
        wallNode.zPosition = -1
        wallNode.isHidden = true
        let lockNode = SKSpriteNode(texture: SceneTextures.bigLock, size: CGSize(width: 150, height: 170))
        lockNode.zPosition = -0.5
        lockNode.isHidden = true
        let tableNode = SKSpriteNode(texture: SceneTextures.tabletop,
                                     size: CGSize(width: ChestLayout.canvas.width, height: 160))
        tableNode.anchorPoint = CGPoint(x: 0, y: 1)
        tableNode.zPosition = 5
        tableNode.isHidden = true

        let rootNode = SKNode()
        let chest = SKNode()
        chest.zPosition = 2
        rootNode.addChild(chest)
        for n in [wallNode, lockNode, frameNode, tongueNode, dark, front, washNode, gloomNode] { chest.addChild(n) }
        rootNode.addChild(satchelNode)
        rootNode.addChild(tableNode)

        root = rootNode
        chestRoot = chest
        frame = frameNode
        tongue = tongueNode
        curl = curlNode
        darkness = dark
        frontDark = front
        wash = washNode
        gloom = gloomNode
        satchel = satchelNode
        wall = wallNode
        lock = lockNode
        table = tableNode
    }

    /// R2: the front wall, the lock and the tabletop fill `bottom` points below the canvas (0 on the Duo).
    func applyExtension(bottom: CGFloat) {
        let ext = max(bottom.rounded(), 0)
        bottomExtension = ext
        let wallH = ChestLayout.frontWallHeight(extension: ext)
        wall.isHidden = ext < 1
        let lockScale = min(1, max(wallH - 20, 0) / 170)
        lock.isHidden = lockScale < 0.3
        lock.setScale(max(lockScale, 0.01))
        lock.position = CGPoint(x: ChestLayout.canvas.width / 2, y: -wallH / 2 + 6)
        let tableH = ext - wallH
        table.isHidden = tableH < 1
        table.size = CGSize(width: ChestLayout.canvas.width, height: max(160, tableH + 8))
        table.position = CGPoint(x: 0, y: -wallH)
    }

    func setDress(_ d: ChestDress, tier t: ChestTier) {
        tier = t
        guard d != dress else { return }
        dress = d
        frame.texture = SceneTextures.chestFrame(d)
        wall.texture = SceneTextures.frontWall(d)
    }

    func setTier(_ t: ChestTier) { setDress(.tier(t), tier: t) }

    func reset() {
        chestRoot.position = .zero
        twitchAge = 10
        curlLevel = 0
        redness = 0
    }

    /// The interior's darkness for an openness: a uniform dark (lightest when wide) plus a front-heavy ramp.
    static func darknessLevels(openness o: Double) -> (uniform: CGFloat, front: CGFloat) {
        let k = CGFloat(min(max(o.isFinite ? o : 0, 0), 1))
        return (0.06 + 0.66 * pow(1 - k, 1.3), 0.14 + 0.36 * (1 - k))
    }

    /// How far down the interior the warm wash reaches (fraction of its height).
    static func washReach(openness o: Double) -> CGFloat {
        let k = CGFloat(min(max(o.isFinite ? o : 0, 0), 1))
        return 0.12 + 0.88 * k
    }

    /// The candle-low gloom (0 … 0.55) for the seconds left (0 above `Tuning.torchLowSeconds`).
    static func gloomLevel(remaining: Double, total: Double) -> CGFloat {
        guard total > 0, remaining.isFinite, remaining > 0 else { return 0 }
        let low = Tuning.torchLowSeconds
        guard remaining < low, low > 0 else { return 0 }
        return CGFloat(0.55 * (1 - remaining / low))
    }

    /// One frame. `light` is the candle flicker (≈ 1; lower = dimmer).
    func update(dt: Double, snapshot s: HeistSnapshot, light: CGFloat, reduceMotion: Bool) {
        let o = s.openness
        let d = SceneFloor.darknessLevels(openness: o)
        let flick = 1 + (1 - light) * 0.6
        darknessAlpha = min(0.97, d.uniform * flick)
        darkness.alpha = darknessAlpha
        frontDark.alpha = min(1, d.front * flick)
        let reach = SceneFloor.washReach(openness: o)
        wash.yScale = max(reach * ChestLayout.rimInner.height / washHeight, 0.05)
        wash.alpha = (0.12 + 0.36 * CGFloat(min(max(o, 0), 1))) * light
        gloomAlpha = SceneFloor.gloomLevel(remaining: s.torchRemaining, total: s.torchTotal)
        gloom.isHidden = gloomAlpha <= 0.005
        gloom.alpha = gloomAlpha * (reduceMotion ? 1 : (0.85 + 0.15 * (2 - light - 0.6)))

        // The tongue: the tell. It breathes and sways a little, asymmetrically.
        breathTime += dt
        let stage = s.stage
        let noise = CGFloat(min(max(s.noise, 0), 1))
        let breath = CGFloat(sin(breathTime * 2 * Double.pi / 4.2))
        let swayK: CGFloat = reduceMotion ? 0.4 : 1
        let sway = swayK * CGFloat(0.026 * sin(breathTime * 2 * Double.pi / 3.0) + 0.008 * sin(breathTime * 5.3))
        var curlTarget: CGFloat = 0
        var ys: CGFloat = 1
        var xs: CGFloat = 1
        var rot: CGFloat = 0
        var dx: CGFloat = 0
        let amp: CGFloat = reduceMotion ? 0.5 : 1
        switch stage {
        case .asleep:
            ys = 1 + 0.03 * breath
            xs = 1 + 0.012 * breath
            rot = sway
        case .stirring:
            ys = 1 + 0.015 * breath
            xs = 1 + 0.006 * breath
            rot = sway * 0.5
            curlTarget = 0.18
            nextTwitch -= dt
            if nextTwitch <= 0 {
                twitchAge = 0
                twitchSign = rng.sign()
                nextTwitch = Double(rng.range(0.7, 2.0))
            }
        case .waking:
            curlTarget = 1
            ys = 0.93
            xs = 0.96
            let quiver = CGFloat(sin(breathTime * 47)) * 0.008 * amp
            ys += quiver
            xs -= quiver * 0.5
        case .biting:
            curlTarget = 1
            ys = 0.86
            xs = 0.94
        }
        twitchAge += dt
        if twitchAge < 0.6 {
            let a = CGFloat(twitchAge)
            let tw = twitchSign * exp(-a * 8) * sin(a * 42) * amp
            xs += 0.05 * tw
            rot += 0.03 * tw
            dx = 6 * tw
        }
        let k = CGFloat(min(dt * 6, 1))
        curlLevel += (curlTarget - curlLevel) * k
        curl.alpha = curlLevel
        tongue.xScale = xs
        tongue.yScale = ys
        tongue.zRotation = rot
        tongue.position.x = ChestLayout.interior.midX + dx
        let redTarget = max(0, (noise - 0.3) / 0.7) * 0.5
        redness += (redTarget - redness) * k
        tongue.colorBlendFactor = redness
    }
}

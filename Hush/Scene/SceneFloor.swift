import SpriteKit
import UIKit

/// The floor half's chest (the SHARP half): walls and bed, the mimic's velvet tongue (the main tell), the darkness
/// over the interior and the warm wash that spreads from the opening (the fold) as the lid rises.
///
/// `chestRoot` slides as a whole (arrival, the hop after a bite, the exit after a bank); the satchel stays.
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
    private let washHeight: CGFloat = 300

    private(set) var tier: ChestTier = .wooden
    /// The tongue's curl now (0 flat … 1 curled; tests).
    private(set) var curlLevel: CGFloat = 0
    /// The darkness over the interior now (tests).
    private(set) var darknessAlpha: CGFloat = 0
    private var breathTime: Double = 0
    private var twitchAge: Double = 10
    private var twitchSign: CGFloat = 1
    private var nextTwitch: Double = 1.2
    private var rng = SceneRNG(seed: 0x70_46_E1)
    private var redness: CGFloat = 0

    init() {
        let pal = ChestArt.palette
        let fr = ChestLayout.frameRect
        let frameNode = SKSpriteNode(texture: SceneTextures.chestFrame(.wooden), size: fr.size)
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

        let bag = ChestLayout.bagStrip
        let satchelNode = SKSpriteNode(texture: SceneTextures.satchel,
                                       size: CGSize(width: bag.width, height: bag.height + 2))
        satchelNode.position = CGPoint(x: bag.midX, y: (bag.height + 2) / 2)
        satchelNode.zPosition = 6

        let rootNode = SKNode()
        let chest = SKNode()
        chest.zPosition = 2
        rootNode.addChild(chest)
        for n in [frameNode, tongueNode, dark, front, washNode] { chest.addChild(n) }
        rootNode.addChild(satchelNode)

        root = rootNode
        chestRoot = chest
        frame = frameNode
        tongue = tongueNode
        curl = curlNode
        darkness = dark
        frontDark = front
        wash = washNode
        satchel = satchelNode
    }

    func setTier(_ t: ChestTier) {
        guard t != tier else { return }
        tier = t
        frame.texture = SceneTextures.chestFrame(t)
    }

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

    /// One frame. `light` is the torch flicker (≈ 1; lower = dimmer), `dim` extra darkness (torch out, the bank's
    /// lid shadow handled elsewhere).
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

        // The tongue: the tell.
        breathTime += dt
        let stage = s.stage
        let noise = CGFloat(min(max(s.noise, 0), 1))
        let breath = CGFloat(sin(breathTime * 2 * Double.pi / 4.2))
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
        case .stirring:
            ys = 1 + 0.015 * breath
            xs = 1 + 0.006 * breath
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
            rot = 0.03 * tw
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

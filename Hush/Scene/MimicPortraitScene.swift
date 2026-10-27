import Foundation
import SpriteKit
import UIKit

extension SceneTextures {
    // MARK: The portrait (front view of the closed chest; design units, see MimicPortraitScene)

    /// The chest's front body (320 × 180 units): planks, bands or brackets by dress, a dark outline.
    static func portraitBody(_ dress: ChestDress) -> SKTexture {
        make("pt-body-\(dress.key)", width: 320, height: 180, scale: 3) { ctx, s in
            let st = TierStyle.of(dress)
            let body = Painter.roundRect(CGRect(x: 6, y: 6, width: s.width - 12, height: s.height - 12), 22)
            Painter.stroke(ctx, body, ScenePaint.outline, width: 9, 0.95)
            Painter.gradient(ctx, body, [ScenePaint.lighter(st.wood, 0.16), st.wood, ScenePaint.darker(st.wood, 0.32)],
                             [0, 0.45, 1], from: CGPoint(x: 0, y: s.height), to: CGPoint(x: s.width * 0.3, y: 0))
            ctx.saveGState()
            ctx.addPath(body)
            ctx.clip()
            for y in [CGFloat(62), 116] {
                let r = CGRect(x: 0, y: y - 54, width: s.width, height: 54)
                Painter.grain(ctx, r, alongX: true, st.woodDark, seed: UInt64(y), count: 3)
                Painter.stroke(ctx, Painter.rect(CGRect(x: 0, y: y, width: s.width, height: 0.01)), st.woodDark,
                               width: 3, 0.85)
            }
            if st.leaf { goldLeaf(ctx, CGRect(origin: .zero, size: s), seed: 71) }
            // The rim along the top (where the lid closes).
            let rim = CGRect(x: 0, y: s.height - 28, width: s.width, height: 22)
            Painter.gradient(ctx, Painter.rect(rim), [ScenePaint.darker(st.wood, 0.1), ScenePaint.darker(st.wood, 0.4)],
                             [0, 1], from: CGPoint(x: 0, y: rim.maxY), to: CGPoint(x: 0, y: rim.minY))
            Painter.stroke(ctx, Painter.rect(CGRect(x: 0, y: rim.minY, width: s.width, height: 0.01)), ScenePaint.outline,
                           width: 3, 0.8)
            // A soft shade low on the right.
            Painter.linear(ctx, [RGBA(0, 0, 0, 0), RGBA(0, 0, 0, 0.28)], [0, 1], from: CGPoint(x: s.width * 0.5, y: s.height),
                           to: CGPoint(x: s.width, y: 0))
            ctx.restoreGState()
            if st.bands {
                for x in [CGFloat(72), 248] {
                    strap(ctx, CGRect(x: x - 15, y: 8, width: 30, height: s.height - 16), st)
                }
            }
            let metal = st.gilt ? st.band : RGBA(hex: 0x6A747F)
            // Corner brackets.
            for (cx, sx) in [(CGFloat(6), CGFloat(1)), (s.width - 6, -1)] {
                for (cy, sy) in [(CGFloat(6), CGFloat(1)), (s.height - 6, -1)] {
                    let a = CGRect(x: sx > 0 ? cx : cx - 44, y: sy > 0 ? cy : cy - 16, width: 44, height: 16)
                    let b = CGRect(x: sx > 0 ? cx : cx - 16, y: sy > 0 ? cy : cy - 44, width: 16, height: 44)
                    bracket(ctx, a, metal)
                    bracket(ctx, b, metal)
                    Painter.rivet(ctx, CGPoint(x: cx + sx * 8, y: cy + sy * 8), 3.6, st.stud)
                }
            }
            if st.gilt {
                Painter.stroke(ctx, Painter.roundRect(CGRect(x: 16, y: 16, width: s.width - 32, height: s.height - 44), 14),
                               st.band, width: 3, 0.9)
            }
            if st.gems {
                gemStud(ctx, CGPoint(x: 72, y: 60), RGBA(hex: 0xEC3352), size: 10)
                gemStud(ctx, CGPoint(x: 248, y: 60), RGBA(hex: 0x3C7CEE), size: 10)
            }
        }
    }

    /// The lid seen from the front (330 × 112 units): a dome with planks, bands and a front lip.
    static func portraitLid(_ dress: ChestDress) -> SKTexture {
        make("pt-lid-\(dress.key)", width: 330, height: 112, scale: 3) { ctx, s in
            let st = TierStyle.of(dress)
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 8, y: 8))
            p.addLine(to: CGPoint(x: s.width - 8, y: 8))
            p.addLine(to: CGPoint(x: s.width - 8, y: 58))
            p.addCurve(to: CGPoint(x: 8, y: 58), control1: CGPoint(x: s.width - 20, y: s.height + 6),
                       control2: CGPoint(x: 20, y: s.height + 6))
            p.closeSubpath()
            Painter.stroke(ctx, p, ScenePaint.outline, width: 9, 0.95)
            Painter.gradient(ctx, p, [ScenePaint.lighter(st.wood, 0.22), st.wood, ScenePaint.darker(st.wood, 0.28)],
                             [0, 0.5, 1], from: CGPoint(x: 0, y: s.height), to: CGPoint(x: s.width * 0.4, y: 0))
            ctx.saveGState()
            ctx.addPath(p)
            ctx.clip()
            Painter.grain(ctx, CGRect(x: 0, y: 30, width: s.width, height: 70), alongX: true, st.woodDark, seed: 5,
                          count: 3)
            Painter.stroke(ctx, Painter.rect(CGRect(x: 0, y: 62, width: s.width, height: 0.01)), st.woodDark, width: 3, 0.8)
            if st.leaf { goldLeaf(ctx, CGRect(origin: .zero, size: s), seed: 73) }
            if st.bands {
                for x in [CGFloat(77), 253] {
                    strap(ctx, CGRect(x: x - 15, y: 0, width: 30, height: s.height), st)
                }
            }
            // The front lip (the lid's bottom edge).
            let lip = CGRect(x: 0, y: 8, width: s.width, height: 18)
            Painter.gradient(ctx, Painter.rect(lip), [ScenePaint.darker(st.wood, 0.05), ScenePaint.darker(st.wood, 0.45)],
                             [0, 1], from: CGPoint(x: 0, y: lip.maxY), to: CGPoint(x: 0, y: lip.minY))
            Painter.stroke(ctx, Painter.rect(CGRect(x: 0, y: lip.maxY, width: s.width, height: 0.01)), ScenePaint.outline,
                           width: 3, 0.8)
            ctx.restoreGState()
            let metal = st.gilt ? st.band : RGBA(hex: 0x6A747F)
            for (cx, sx) in [(CGFloat(8), CGFloat(1)), (s.width - 8, -1)] {
                bracket(ctx, CGRect(x: sx > 0 ? cx : cx - 40, y: 8, width: 40, height: 16), metal)
                bracket(ctx, CGRect(x: sx > 0 ? cx : cx - 16, y: 8, width: 16, height: 40), metal)
                Painter.rivet(ctx, CGPoint(x: cx + sx * 8, y: 16), 3.4, st.stud)
            }
            if st.gems {
                gemStud(ctx, CGPoint(x: s.width / 2, y: 80), RGBA(hex: 0xEC3352), size: 11)
            } else if st.gilt {
                gemStud(ctx, CGPoint(x: s.width / 2, y: 80), RGBA(hex: 0x2CC67C), size: 9)
            }
            // A highlight along the dome.
            let hl = CGMutablePath()
            hl.move(to: CGPoint(x: 40, y: 78))
            hl.addQuadCurve(to: CGPoint(x: 150, y: 100), control: CGPoint(x: 80, y: 100))
            Painter.stroke(ctx, hl, RGBA(1, 1, 1), width: 5, 0.22)
        }
    }

    /// The portrait's upper fangs (280 × 40 units, roots at the top): the same fang row as the game.
    static var portraitFangs: SKTexture {
        make("pt-fangs", width: 280, height: 40, scale: 3) { ctx, s in
            var t = CGAffineTransform(translationX: 0, y: s.height - 2)
            let row = ChestArt.teethRow(width: s.width, height: 34, count: 8, pointingDown: true)
            let p = row.copy(using: &t) ?? row
            drawTeeth(ctx, p, rootY: s.height, tipY: 0, count: 8, width: s.width)
        }
    }
}

/// The mimic's portrait (R2: one art style everywhere): the closed chest seen from the front in the in-game
/// textures, the lid cracked, fangs and one big eye peeking out of a warm glow, breathing slowly. The app icon is the
/// reference. The App shows it on Home (its openness follows the hinge or slider), on the cover card (asleep) and on
/// Results (smug if bitten, asleep if hushed).
///
/// Use it in `SpriteView(scene:options: [.allowsTransparency])`: the background is clear (set `showsBackdrop` for a
/// dark glow behind it on its own). The art is laid out in a 400 × 400 box scaled to fit the scene, centred.
@MainActor
final class MimicPortraitScene: SKScene {
    /// How far the lid is cracked, 0 (a sliver: shut but peeking) … 1 (a wide grin).
    var openness: Double = 0.2 {
        didSet { openness = MimicPortraitScene.clamp(openness) }
    }
    /// The eye, 0 (asleep, lashes down) … 1 (wide awake).
    var wake: Double = 0 {
        didSet { wake = MimicPortraitScene.clamp(wake) }
    }
    var tier: ChestTier = .wooden {
        didSet { if tier != oldValue { redress() } }
    }
    var golden: Bool = false {
        didSet { if golden != oldValue { redress() } }
    }
    /// No breathing bob, no drifting Zzz, no blinks.
    var reduceMotion: Bool = false
    /// A soft dark glow behind the chest (for use without a backdrop of its own).
    var showsBackdrop: Bool = false {
        didSet { backdrop.isHidden = !showsBackdrop }
    }
    /// R3 (juror P1-11, the cover): every ~5 s the sleeping mimic's amber eye glints open through the seam for a
    /// moment (the lid lifts a touch, the tooth tips show), then it settles back to its slow breath. Off under Reduce
    /// Motion.
    var idlePeek: Bool = false
    /// R3: how big the art is drawn (1 = the 400-unit box fits the scene's short side). The cover uses ~1.2 so the
    /// chest fills its card; above 1 the art is also centred on its body (not its box).
    var artScale: CGFloat = 1 {
        didSet {
            artScale = min(max(artScale.isFinite ? artScale : 1, 0.5), 2)
            relayout()
        }
    }

    /// The cover card's look: asleep, cracked a sliver, peeking every ~5 s, filling the card.
    func applyCoverStyle() {
        openness = 0.12
        wake = 0
        idlePeek = true
        artScale = 1.2
    }

    /// How far into a peek it is (0 none … 1 fully peeking; tests).
    private(set) var peekLevel: CGFloat = 0
    private var peekClock: Double = 3.0

    // MARK: Read-outs (tests)

    /// The lid's gap as drawn (units).
    private(set) var gap: CGFloat = 0
    /// The eye's openness as drawn.
    private(set) var shownWake: Double = 0
    var dress: ChestDress { ChestDress.of(tier: tier, golden: golden) }

    static let box: CGFloat = 400
    /// The eye's geometry space (`ChestArt.mimicEye` in a 150 × 150 box: radius 30, centre (75, 84)).
    private static let eyeSpace = CGSize(width: 150, height: 150)

    private let root = SKNode()
    private let backdrop: SKSpriteNode
    private let shadow: SKSpriteNode
    private let glowBack: SKSpriteNode
    private let mouth: SKSpriteNode
    private let mouthGlow: SKSpriteNode
    private let coins: [SKSpriteNode]
    private let eye: SKNode
    private let mask: SKShapeNode
    private let white: SKShapeNode
    private let iris: SKSpriteNode
    private let rim: SKShapeNode
    private let lidTop: SKShapeNode
    private let lashes: SKShapeNode
    private let body: SKSpriteNode
    private let lock: SKSpriteNode
    private let lidNode: SKNode
    private let lidFace: SKSpriteNode
    private let fangs: SKSpriteNode
    private let zzz: [SceneLabel]
    private let sparkles: [SKSpriteNode]

    private var time: Double = 0
    private var lastTime: TimeInterval?
    private var wakeStep = -1
    private var blinkAge: Double = 10
    private var nextBlink: Double = 3
    private var sparkPhase: [Double] = [1, 1, 1]
    private var rng = SceneRNG(seed: 0x9047)

    private static func clamp(_ v: Double) -> Double { min(max(v.isFinite ? v : 0, 0), 1) }

    override init(size: CGSize) {
        let pal = ChestArt.palette
        let backdropN = SKSpriteNode(texture: SceneTextures.glow, size: CGSize(width: 520, height: 520))
        backdropN.color = ScenePaint.ui(pal.dungeon)
        backdropN.colorBlendFactor = 1
        backdropN.alpha = 0.9
        backdropN.zPosition = -10
        backdropN.isHidden = true
        let shadowN = SKSpriteNode(texture: SceneTextures.shadow, size: CGSize(width: 360, height: 56))
        shadowN.color = .black
        shadowN.colorBlendFactor = 1
        shadowN.alpha = 0.6
        shadowN.position = CGPoint(x: 0, y: -166)
        shadowN.zPosition = -5
        let glowBackN = SKSpriteNode(texture: SceneTextures.glow, size: CGSize(width: 440, height: 260))
        glowBackN.color = ScenePaint.ui(pal.candle)
        glowBackN.colorBlendFactor = 1
        glowBackN.blendMode = .add
        glowBackN.position = CGPoint(x: 0, y: 24)
        glowBackN.zPosition = -4
        let mouthN = SKSpriteNode(color: ScenePaint.ui(ScenePaint.throat), size: CGSize(width: 292, height: 20))
        mouthN.anchorPoint = CGPoint(x: 0.5, y: 0)
        mouthN.position = CGPoint(x: 0, y: 0)
        mouthN.zPosition = 1
        let mouthGlowN = SKSpriteNode(texture: SceneTextures.glow, size: CGSize(width: 300, height: 90))
        mouthGlowN.color = ScenePaint.ui(pal.candle)
        mouthGlowN.colorBlendFactor = 1
        mouthGlowN.blendMode = .add
        mouthGlowN.zPosition = 1.5
        var cs: [SKSpriteNode] = []
        for (i, x) in [CGFloat(-112), 108].enumerated() {
            let c = SKSpriteNode(texture: SceneTextures.loot(.copper, radius: 16, value: i == 0 ? 10 : 6),
                                 size: CGSize(width: SceneTextures.lootSide(16), height: SceneTextures.lootSide(16)))
            c.position = CGPoint(x: x, y: 14)
            c.zPosition = 2
            cs.append(c)
        }
        coins = cs

        // The eye (the in-game eye's shapes in a 150-unit box). Every node is built as a local first (nothing may
        // touch `self` before super.init), then assigned.
        let eyeN = SKNode()
        let lidNodeN = SKNode()
        let paths = ChestArt.mimicEye(wake: 0, size: MimicPortraitScene.eyeSpace)
        let maskN = SKShapeNode(path: paths.white)
        maskN.fillColor = .white
        maskN.strokeColor = .clear
        let crop = SKCropNode()
        crop.maskNode = maskN
        let whiteN = SKShapeNode(path: paths.white)
        whiteN.fillColor = ScenePaint.ui(ScenePaint.eyeWhite)
        whiteN.strokeColor = .clear
        let k = ChestArt.mimicEyeRadius(size: MimicPortraitScene.eyeSpace) / ChestLayout.eyeRadius
        let side = SceneTextures.irisSide * k
        let irisN = SKSpriteNode(texture: SceneTextures.iris, size: CGSize(width: side, height: side))
        irisN.zPosition = 1
        let pupil = SKSpriteNode(texture: SceneTextures.pupil, size: CGSize(width: 26 * k, height: 76 * k))
        pupil.xScale = 0.55
        pupil.zPosition = 0.5
        irisN.addChild(pupil)
        let catchN = SKSpriteNode(texture: SceneTextures.dot, size: CGSize(width: 18 * k, height: 14 * k))
        catchN.position = CGPoint(x: -side * 0.15, y: side * 0.17)
        catchN.color = .white
        catchN.colorBlendFactor = 1
        catchN.alpha = 0.9
        catchN.zPosition = 1
        irisN.addChild(catchN)
        crop.addChild(whiteN)
        crop.addChild(irisN)
        let rimN = SKShapeNode(path: paths.white)
        rimN.fillColor = .clear
        rimN.strokeColor = ScenePaint.ui(ScenePaint.outline)
        rimN.lineWidth = 2.2
        rimN.zPosition = 1
        let lidTopN = SKShapeNode(path: paths.lidTop)
        lidTopN.fillColor = ScenePaint.ui(ChestArt.flesh)
        lidTopN.strokeColor = ScenePaint.ui(ScenePaint.outline)
        lidTopN.lineWidth = 2
        lidTopN.zPosition = 2
        let lashesN = SKShapeNode(path: ChestArt.mimicLashes(size: MimicPortraitScene.eyeSpace))
        lashesN.fillColor = .clear
        lashesN.strokeColor = ScenePaint.ui(ScenePaint.outline)
        lashesN.lineWidth = 2.8
        lashesN.lineCap = .round
        lashesN.zPosition = 3
        for n in [crop, rimN, lidTopN, lashesN] as [SKNode] { eyeN.addChild(n) }
        eyeN.zPosition = 3

        let bodyN = SKSpriteNode(texture: SceneTextures.portraitBody(.tier(.wooden)), size: CGSize(width: 320, height: 180))
        bodyN.anchorPoint = CGPoint(x: 0.5, y: 1)
        bodyN.position = CGPoint(x: 0, y: 16)
        bodyN.zPosition = 6
        let lockN = SKSpriteNode(texture: SceneTextures.bigLock, size: CGSize(width: 62, height: 70))
        lockN.position = CGPoint(x: 0, y: -26)
        lockN.zPosition = 6.5
        let lidFaceN = SKSpriteNode(texture: SceneTextures.portraitLid(.tier(.wooden)), size: CGSize(width: 330, height: 112))
        lidFaceN.anchorPoint = CGPoint(x: 0.5, y: 0)
        lidFaceN.position = CGPoint(x: 0, y: -8)
        lidFaceN.zPosition = 1
        let fangsN = SKSpriteNode(texture: SceneTextures.portraitFangs, size: CGSize(width: 280, height: 40))
        fangsN.anchorPoint = CGPoint(x: 0.5, y: 1)
        fangsN.position = CGPoint(x: 0, y: 2)
        fangsN.zPosition = -0.5
        lidNodeN.addChild(fangsN)
        lidNodeN.addChild(lidFaceN)
        lidNodeN.zPosition = 5

        var zs: [SceneLabel] = []
        for (i, sz) in [CGFloat(18), 24, 30].enumerated() {
            let z = SceneLabel(size: sz, color: ScenePaint.ui(pal.candle), minimumSize: 12)
            z.set(i == 0 ? "z" : "Z")
            z.node.zPosition = 10
            zs.append(z)
        }
        zzz = zs
        var sp: [SKSpriteNode] = []
        for _ in 0..<3 {
            let s = SKSpriteNode(texture: SceneTextures.sparkle, size: CGSize(width: 26, height: 26))
            s.blendMode = .add
            s.color = UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 1)
            s.colorBlendFactor = 1
            s.alpha = 0
            s.isHidden = true
            s.zPosition = 9
            sp.append(s)
        }
        sparkles = sp
        backdrop = backdropN
        shadow = shadowN
        glowBack = glowBackN
        mouth = mouthN
        mouthGlow = mouthGlowN
        mask = maskN
        white = whiteN
        iris = irisN
        rim = rimN
        lidTop = lidTopN
        lashes = lashesN
        eye = eyeN
        body = bodyN
        lock = lockN
        lidNode = lidNodeN
        lidFace = lidFaceN
        fangs = fangsN

        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = .zero
        addChild(root)
        for n in [backdrop, shadow, glowBack, mouth, mouthGlow] as [SKNode] { root.addChild(n) }
        for c in coins { root.addChild(c) }
        for n in [eye, body, lock, lidNode] as [SKNode] { root.addChild(n) }
        for z in zzz { root.addChild(z.node) }
        for s in sparkles { root.addChild(s) }
        relayout()
        rebuildEye(step: 0)
        pose(dt: 0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("MimicPortraitScene is created in code with init(size:)")
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        relayout()
    }

    private func relayout() {
        let k = max(min(size.width, size.height), 1) / MimicPortraitScene.box * artScale
        root.setScale(k)
        // The art's own middle sits ~22 units below its box centre: centre it when it is drawn big.
        let lift: CGFloat = artScale > 1.001 ? 22 * k : 0
        root.position = CGPoint(x: size.width / 2, y: size.height / 2 + lift)
    }

    private func redress() {
        let d = dress
        body.texture = SceneTextures.portraitBody(d)
        lidFace.texture = SceneTextures.portraitLid(d)
    }

    private func rebuildEye(step: Int) {
        wakeStep = step
        let p = ChestArt.mimicEye(wake: Double(step) / 25, size: MimicPortraitScene.eyeSpace)
        mask.path = p.white
        white.path = p.white
        rim.path = p.white
        lidTop.path = p.lidTop
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        var dt = 1.0 / 60.0
        if let last = lastTime { dt = min(max(currentTime - last, 0), 1.0 / 20.0) }
        lastTime = currentTime
        pose(dt: dt)
    }

    /// One frame of the idle: breath, blinks, Zzz, the golden sparkle.
    private func pose(dt: Double) {
        time += dt
        let breath = reduceMotion ? 0 : sin(time * 2 * Double.pi / 2.4)
        // The cover's peek: a 1.3 s glint every ~5 s.
        var peek: CGFloat = 0
        if idlePeek && !reduceMotion {
            peekClock -= dt
            if peekClock <= -1.3 { peekClock = 3.7 }
            if peekClock <= 0 { peek = CGFloat(sin(min(-peekClock / 1.3, 1) * Double.pi)) }
        }
        peekLevel = peek
        gap = 12 + 62 * (CGFloat(openness) + 0.16 * peek) + 1.6 * CGFloat(breath)
        let lidBase: CGFloat = 10 + gap
        lidNode.position = CGPoint(x: 0, y: lidBase)
        lidNode.zRotation = -0.05 * CGFloat(openness) - 0.012
        lidNode.yScale = 1 + 0.015 * CGFloat(breath)
        mouth.size = CGSize(width: 292, height: max(lidBase + 12, 1))
        let o = CGFloat(openness)
        glowBack.alpha = 0.18 + 0.5 * o
        mouthGlow.position = CGPoint(x: 0, y: 10 + gap * 0.5)
        mouthGlow.alpha = 0.25 + 0.5 * o
        for c in coins { c.isHidden = gap < 16 }

        // The eye peeks between the rim and the fangs.
        blinkAge += dt
        nextBlink -= dt
        if nextBlink <= 0 && !reduceMotion && wake > 0.2 {
            blinkAge = 0
            nextBlink = Double(rng.range(2.6, 5.2))
        }
        var w = max(wake, 0.5 * Double(peek))
        if blinkAge < 0.16 { w *= 0.1 }
        shownWake += (w - shownWake) * min(dt * 12, 1)
        if dt == 0 { shownWake = w }
        let step = Int((shownWake * 25).rounded())
        if step != wakeStep { rebuildEye(step: step) }
        let eyeY = 12 + gap * 0.42
        eye.position = CGPoint(x: -75, y: eyeY - 84)
        let g = EyeGeometry(wake: Double(step) / 25, size: MimicPortraitScene.eyeSpace)
        let wander = reduceMotion ? 0 : CGFloat(sin(time * 0.7)) * 3
        iris.position = CGPoint(x: g.irisCenter.x + wander, y: g.irisCenter.y)
        lashes.alpha = max(0, 1 - CGFloat(shownWake) * 5)

        // Zzz while it sleeps.
        let sleepy: CGFloat = wake < 0.08 && peek < 0.15 ? 1 : 0
        for (i, z) in zzz.enumerated() {
            let ph = reduceMotion ? 0.5 : (time / 3.2 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
            let k = CGFloat(ph)
            z.node.position = CGPoint(x: 118 + 22 * k + CGFloat(i) * 16, y: lidBase + 96 + 70 * k + CGFloat(i) * 14)
            z.node.alpha = reduceMotion ? sleepy * 0.85 : sleepy * min(k * 4, 1) * (1 - k) * 1.4
        }

        // The golden mimic sparkles.
        for (i, s) in sparkles.enumerated() {
            s.isHidden = !golden
            guard golden else { continue }
            let ph = (time / 1.6 + Double(i) * 0.33).truncatingRemainder(dividingBy: 1)
            if ph < sparkPhase[i] {
                s.position = CGPoint(x: rng.range(-140, 140), y: rng.range(-150, lidBase + 80))
            }
            sparkPhase[i] = ph
            s.alpha = CGFloat(sin(ph * Double.pi))
            s.setScale(reduceMotion ? 0.9 : CGFloat(0.6 + 0.6 * sin(ph * Double.pi)))
        }
    }
}

import SpriteKit
import UIKit

/// The lid half (it may blur for 1–2 s when a fold starts, so ambience only): the underside of the lid, which is the
/// mimic's upper jaw. Planks and studs by tier, a row of big rounded teeth along the fold edge (tucked when asleep,
/// bared as it wakes), one big sleepy eye, the name on a brass plate, Zzz, and the warm glow of the loot below.
/// The brass lever slider is drawn only when the game uses it (no hinge).
///
/// `root` sits at the lid half's origin (canvas y 496); its children use lid-local points (`ChestLayout`).
@MainActor
final class SceneLid {
    let root: SKNode
    /// The gum and teeth (the bite slams this down across the fold).
    let jaw: SKNode
    private let base: SKSpriteNode
    private let dim: SKSpriteNode
    private let glow: SKSpriteNode
    private let gum: SKSpriteNode
    private let teeth: SKSpriteNode

    private let mask: SKShapeNode
    private let crop: SKCropNode
    private let white: SKShapeNode
    private let shade: SKSpriteNode
    private let iris: SKSpriteNode
    private let pupil: SKSpriteNode
    private let catchlight: SKSpriteNode
    private let whiteRim: SKShapeNode
    private let lidTop: SKShapeNode
    private let lashes: SKShapeNode
    private let zzz: [SceneLabel]
    private let plate: SKSpriteNode
    private let nameLabel: SceneLabel
    private let sliderRoot: SKNode
    private let knob: SKSpriteNode

    private(set) var tier: ChestTier = .wooden
    private(set) var name: String = ""
    /// The eye's openness as drawn, 0 … 1 (tests).
    private(set) var wake: Double = 0
    /// How far the teeth are bared, 0 … 1 (tests).
    private(set) var teethShown: CGFloat = 0
    /// Eye path rebuilds so far (tests: only when the quantised wake changes).
    private(set) var eyeRebuilds = 0
    private var wakeStep = -1
    private var look: CGPoint = .zero
    private var time: Double = 0
    private var blinkAge: Double = 10
    private var blinkLength: Double = 0.2
    private var blinkOpen: Double = 0.3
    private var nextBlink: Double = 1
    private var twitchAge: Double = 10
    private var arriveAge: Double = 10
    private var rng = SceneRNG(seed: 0x1D_E7E)

    static let wakeSteps = 25

    init() {
        let pal = ChestArt.palette
        let ls = ChestLayout.lidSize
        let rootN = SKNode()
        rootN.position = CGPoint(x: 0, y: ChestLayout.lidBottom)

        let baseN = SKSpriteNode(texture: SceneTextures.lid(.wooden), size: ls)
        baseN.anchorPoint = .zero
        baseN.zPosition = 0
        let dimN = SKSpriteNode(color: ScenePaint.ui(pal.dungeonDeep), size: ls)
        dimN.anchorPoint = .zero
        dimN.zPosition = 7
        let glowN = SKSpriteNode(texture: SceneTextures.vertical("lid-glow", [1, 0.4, 0], [0, 0.35, 1]),
                                 size: CGSize(width: ls.width, height: 320))
        glowN.anchorPoint = CGPoint(x: 0.5, y: 0)
        glowN.position = CGPoint(x: ls.width / 2, y: 0)
        glowN.color = ScenePaint.ui(pal.candle)
        glowN.colorBlendFactor = 1
        glowN.blendMode = .add
        glowN.zPosition = 8

        // The jaw: the gum with the teeth hanging below it.
        let jawN = SKNode()
        jawN.zPosition = 50
        let gumN = SKSpriteNode(texture: SceneTextures.gum, size: CGSize(width: ls.width, height: 30))
        gumN.anchorPoint = CGPoint(x: 0.5, y: 0)
        gumN.position = CGPoint(x: ls.width / 2, y: ChestLayout.gumY - 4)
        gumN.zPosition = 2
        let teethN = SKSpriteNode(texture: SceneTextures.teeth, size: CGSize(width: ls.width, height: 64))
        teethN.anchorPoint = CGPoint(x: 0.5, y: 1)
        teethN.position = CGPoint(x: ls.width / 2, y: ChestLayout.gumY + 2)
        teethN.zPosition = 1
        jawN.addChild(teethN)
        jawN.addChild(gumN)

        // The eye: the white (clipped), iris and pupil inside a crop; the lid skin and lashes over it.
        let eyeRoot = SKNode()
        eyeRoot.zPosition = 2
        let paths = ChestArt.mimicEye(wake: 0, size: ls)
        let maskN = SKShapeNode(path: paths.white)
        maskN.fillColor = .white
        maskN.strokeColor = .clear
        let cropN = SKCropNode()
        cropN.maskNode = maskN
        cropN.zPosition = 0
        let whiteN = SKShapeNode(path: paths.white)
        whiteN.fillColor = ScenePaint.ui(ScenePaint.eyeWhite)
        whiteN.strokeColor = .clear
        whiteN.zPosition = 0
        let er = ChestLayout.eyeRadius
        let ec = ChestLayout.eyeCenter
        let shadeN = SKSpriteNode(texture: SceneTextures.vertical("eye-shade", [0, 0, 0.55], [0, 0.55, 1]),
                                  size: CGSize(width: er * 2.6, height: er * 2.4))
        shadeN.position = CGPoint(x: ec.x, y: ec.y + er * 0.1)
        shadeN.color = ScenePaint.ui(RGBA(hex: 0x5A3012))
        shadeN.colorBlendFactor = 1
        shadeN.zPosition = 3
        let irisSide = ceil(er * 0.6) * 2 + 4
        let irisN = SKSpriteNode(texture: SceneTextures.iris, size: CGSize(width: irisSide, height: irisSide))
        irisN.zPosition = 1
        let pupilN = SKSpriteNode(texture: SceneTextures.pupil, size: CGSize(width: 26, height: 76))
        pupilN.zPosition = 0.5
        irisN.addChild(pupilN)
        let catchN = SKSpriteNode(texture: SceneTextures.dot, size: CGSize(width: 18, height: 14))
        catchN.position = CGPoint(x: -er * 0.2, y: er * 0.22)
        catchN.color = .white
        catchN.colorBlendFactor = 1
        catchN.alpha = 0.9
        catchN.zPosition = 1
        irisN.addChild(catchN)
        cropN.addChild(whiteN)
        cropN.addChild(irisN)
        cropN.addChild(shadeN)
        let rimN = SKShapeNode(path: paths.white)
        rimN.fillColor = .clear
        rimN.strokeColor = ScenePaint.ui(ScenePaint.outline)
        rimN.lineWidth = 5
        rimN.zPosition = 1
        let lidSkin = ScenePaint.darker(TierStyle.of(.wooden).wood, 0.12)
        let lidTopN = SKShapeNode(path: paths.lidTop)
        lidTopN.fillColor = ScenePaint.ui(lidSkin)
        lidTopN.strokeColor = ScenePaint.ui(ScenePaint.outline)
        lidTopN.lineWidth = 4
        lidTopN.zPosition = 2
        let lashN = SKShapeNode(path: ChestArt.mimicLashes(size: ls))
        lashN.fillColor = .clear
        lashN.strokeColor = ScenePaint.ui(ScenePaint.outline)
        lashN.lineWidth = 6
        lashN.lineCap = .round
        lashN.zPosition = 3
        for n in [cropN, rimN, lidTopN, lashN] as [SKNode] { eyeRoot.addChild(n) }

        var zs: [SceneLabel] = []
        for (i, size) in [CGFloat(24), 30, 38].enumerated() {
            let z = SceneLabel(size: size, color: ScenePaint.ui(pal.candle))
            z.set(i == 0 ? "z" : "Z")
            z.node.zPosition = 10
            zs.append(z)
        }

        let plateN = SKSpriteNode(texture: SceneTextures.plate, size: ChestLayout.plateSize)
        plateN.position = ChestLayout.plateCenter
        plateN.zPosition = 9
        let nameN = SceneLabel(size: 26, color: ScenePaint.ui(RGBA(hex: 0x2E1606)), outline: nil)
        nameN.maxWidth = ChestLayout.plateSize.width - 60
        nameN.node.position = CGPoint(x: 0, y: -1)
        plateN.addChild(nameN.node)

        let sliderN = SKNode()
        sliderN.zPosition = 12
        sliderN.isHidden = true
        let trackH = ChestLayout.sliderMaxY - ChestLayout.sliderMinY + 40
        let trackN = SKSpriteNode(texture: SceneTextures.sliderTrack, size: CGSize(width: 56, height: trackH))
        trackN.position = CGPoint(x: ChestLayout.sliderX, y: (ChestLayout.sliderMinY + ChestLayout.sliderMaxY) / 2)
        let knobN = SKSpriteNode(texture: SceneTextures.sliderKnob, size: CGSize(width: 96, height: 56))
        knobN.position = CGPoint(x: ChestLayout.sliderX, y: ChestLayout.sliderMinY)
        knobN.zPosition = 1
        sliderN.addChild(trackN)
        sliderN.addChild(knobN)

        for n in [baseN, eyeRoot, dimN, glowN, plateN, jawN, sliderN] as [SKNode] { rootN.addChild(n) }
        for z in zs { rootN.addChild(z.node) }

        root = rootN
        jaw = jawN
        base = baseN
        dim = dimN
        glow = glowN
        gum = gumN
        teeth = teethN
        mask = maskN
        crop = cropN
        white = whiteN
        shade = shadeN
        iris = irisN
        pupil = pupilN
        catchlight = catchN
        whiteRim = rimN
        lidTop = lidTopN
        lashes = lashN
        zzz = zs
        plate = plateN
        nameLabel = nameN
        sliderRoot = sliderN
        knob = knobN
        rebuildEye(step: 0)
    }

    func setTier(_ t: ChestTier, animated: Bool) {
        guard t != tier else { return }
        tier = t
        base.texture = SceneTextures.lid(t)
        lidTop.fillColor = ScenePaint.ui(ScenePaint.darker(TierStyle.of(t).wood, 0.12))
        if animated { arriveAge = 0 }
    }

    func setName(_ s: String) {
        guard s != name else { return }
        name = s
        nameLabel.set(s)
    }

    func twitch() { twitchAge = 0 }

    func reset() {
        twitchAge = 10
        blinkAge = 10
        arriveAge = 10
        jaw.position = .zero
        root.position = CGPoint(x: 0, y: ChestLayout.lidBottom)
    }

    private func rebuildEye(step: Int) {
        wakeStep = step
        eyeRebuilds += 1
        let w = Double(step) / Double(SceneLid.wakeSteps)
        let p = ChestArt.mimicEye(wake: w, size: ChestLayout.lidSize)
        mask.path = p.white
        white.path = p.white
        whiteRim.path = p.white
        lidTop.path = p.lidTop
    }

    /// The eye's resting openness for a stage and noise (before blinks, twitches and moments).
    static func wakeTarget(stage: MimicStage, noise: Double) -> Double {
        switch stage {
        case .asleep: return 0
        case .stirring: return 0.1
        case .waking: return 0.5 + 0.3 * min(max((noise - 0.7) / 0.3, 0), 1)
        case .biting: return 1
        }
    }

    /// How far the teeth are bared for a stage and noise.
    static func teethTarget(stage: MimicStage, noise: Double) -> CGFloat {
        switch stage {
        case .asleep: return 0
        case .stirring: return 0.3
        case .waking: return CGFloat(0.7 + 0.3 * min(max((noise - 0.7) / 0.3, 0), 1))
        case .biting: return 1
        }
    }

    /// One frame. `wakeOverride` / `teethOverride` come from the moments (the bite); `lookAt` is a canvas point the
    /// eye watches (a finger or a held item) when awake.
    func update(dt: Double, snapshot s: HeistSnapshot, light: CGFloat, wakeOverride: Double?, teethOverride: CGFloat?,
                lookAt: CGPoint?, usesSlider: Bool, reduceMotion: Bool) {
        time += dt
        let o = CGFloat(min(max(s.openness.isFinite ? s.openness : 0, 0), 1))
        dim.alpha = 0.32 * (1 - o)
        glow.alpha = (0.1 + 0.42 * o) * light

        // Arrival: the new lid drops in.
        arriveAge += dt
        if arriveAge < 0.5 && !reduceMotion {
            let t = CGFloat(arriveAge / 0.5)
            root.position = CGPoint(x: 0, y: ChestLayout.lidBottom + 70 * (1 - t) * (1 - t))
        } else {
            root.position = CGPoint(x: 0, y: ChestLayout.lidBottom)
        }

        // The eye.
        var target = wakeOverride ?? SceneLid.wakeTarget(stage: s.stage, noise: s.noise)
        if wakeOverride == nil {
            if s.stage == .stirring {
                nextBlink -= dt
                if nextBlink <= 0 {
                    blinkAge = 0
                    blinkLength = Double(rng.range(0.12, 0.3))
                    blinkOpen = Double(rng.range(0.22, 0.4))
                    nextBlink = Double(rng.range(0.8, 2.2))
                }
            }
            blinkAge += dt
            if blinkAge < blinkLength { target = max(target, blinkOpen) }
            twitchAge += dt
            if twitchAge < 0.35 { target = max(target, 0.3) }
        }
        let rate = target > wake ? 14.0 : 5.0
        wake += (target - wake) * min(dt * rate, 1)
        wake = min(max(wake, 0), 1)
        let step = Int((wake * Double(SceneLid.wakeSteps)).rounded())
        if step != wakeStep { rebuildEye(step: step) }
        let g = EyeGeometry(wake: Double(step) / Double(SceneLid.wakeSteps), size: ChestLayout.lidSize)
        // The iris watches the finger when awake.
        var lookTarget = CGPoint.zero
        if let p = lookAt, wake > 0.3 {
            let lp = CGPoint(x: p.x - root.position.x, y: p.y - root.position.y)
            let dx = lp.x - g.irisCenter.x, dy = lp.y - g.irisCenter.y
            let d = max(hypot(dx, dy), 1)
            let m = min(d * 0.12, g.r * 0.3)
            lookTarget = CGPoint(x: dx / d * m, y: dy / d * m)
        }
        let lk = CGFloat(min(dt * 8, 1))
        look = CGPoint(x: look.x + (lookTarget.x - look.x) * lk, y: look.y + (lookTarget.y - look.y) * lk)
        iris.position = CGPoint(x: g.irisCenter.x + look.x, y: g.irisCenter.y + look.y)
        let wk = CGFloat(wake)
        pupil.xScale = max(1.15 - 0.75 * wk, 0.3)
        pupil.yScale = 0.9 + 0.15 * wk
        lashes.alpha = max(0, 1 - wk * 5)

        // The teeth.
        var tt = teethOverride ?? SceneLid.teethTarget(stage: s.stage, noise: s.noise)
        if teethOverride == nil && twitchAge < 0.35 { tt = max(tt, 0.35) }
        teethShown += (tt - teethShown) * CGFloat(min(dt * 10, 1))
        teeth.yScale = 0.32 + 0.68 * teethShown

        // Zzz while asleep.
        let sleepy: CGFloat = s.stage == .asleep && wake < 0.08 ? 1 : 0
        let ec = ChestLayout.eyeCenter
        for (i, z) in zzz.enumerated() {
            let ph = (time / 3.2 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
            let k = CGFloat(ph)
            z.node.position = CGPoint(x: ec.x + 150 + 26 * k + CGFloat(i) * 8, y: ec.y + 60 + 90 * k)
            z.node.alpha = sleepy * min(k * 4, 1) * (1 - k) * 1.4
        }

        // The slider.
        sliderRoot.isHidden = !usesSlider
        if usesSlider {
            knob.position = CGPoint(x: ChestLayout.sliderX,
                                    y: ChestLayout.sliderMinY + (ChestLayout.sliderMaxY - ChestLayout.sliderMinY) * o)
        }
    }
}

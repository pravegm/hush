import SpriteKit
import UIKit

/// The words on the lid's name plate (R2: the arrival tag lives here, never over the loot).
enum ChestCopy {
    static func trait(_ m: MimicKind) -> String {
        switch m {
        case .snorer: return "Snorer"
        case .lightSleeper: return "Light sleeper"
        case .heavySleeper: return "Heavy sleeper"
        case .dreamer: return "Dreamer · fake twitches"
        }
    }

    static func tierShort(_ t: ChestTier) -> String {
        switch t {
        case .wooden: return "Wooden"
        case .iron: return "Iron-bound"
        case .gilded: return "Gilded"
        case .royal: return "Royal"
        }
    }

    static func multiplier(_ m: Double) -> String {
        guard m.isFinite, m > 0 else { return "×1" }
        if abs(m - m.rounded()) < 0.001 { return "×\(Int(m.rounded()))" }
        return String(format: "×%.1f", m)
    }

    /// "Light sleeper · Iron-bound · gold ×1.5" (no multiplier at ×1); golden: "GOLDEN · gold ×2 · light sleeper".
    static func plateSubline(_ c: ChestSpec) -> String {
        let kind = ChestCopy.trait(c.mimic)
        if c.golden { return "GOLDEN · gold ×2 · \(kind.lowercased())" }
        var s = "\(kind) · \(ChestCopy.tierShort(c.tier))"
        if c.multiplier.isFinite && c.multiplier > 1.001 { s += " · gold \(ChestCopy.multiplier(c.multiplier))" }
        return s
    }
}

extension SceneTextures {
    /// The brow plate's centre ornament: a rivet, a set gem, the royal crown, or the golden mimic's big gem.
    static func browKnob(_ dress: ChestDress) -> SKTexture {
        make("brow-knob-\(dress.key)", width: 52, height: 52) { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            switch dress {
            case .tier(.wooden), .tier(.iron):
                Painter.rivet(ctx, c, 10, ScenePaint.brassLight)
            case .tier(.gilded):
                gemStud(ctx, c, RGBA(hex: 0xEC3352), size: 13)
            case .tier(.royal):
                let crown = ChestArt.relicArt(.crown, radius: 22)
                ctx.saveGState()
                ctx.translateBy(x: c.x, y: c.y + 2)
                ChestArt.drawArt(ctx, crown, (RGBA(hex: 0xFFC94A), ScenePaint.brassDark, ScenePaint.brassLight),
                                 radius: 22)
                ctx.restoreGState()
            case .golden:
                gemStud(ctx, c, RGBA(hex: 0x2CC67C), size: 15)
            }
        }
    }
}

/// The lid half (it may blur for 1–2 s when a fold starts, so ambience only): the underside of the lid, which is the
/// mimic's upper jaw. Planks and studs by dress, pointed fangs along the fold edge (tucked behind a fleshy lip when
/// asleep, bared as it wakes), one big eye in a fleshy eyelid under a brass brow that tilts angry, the name plate
/// (name, trait and tier), Zzz, and the warm glow of the loot below. The brass lever slider shows only when the game
/// uses it (no hinge). R2: the planks, iron and corner brackets continue up into the extension above the canvas.
///
/// `root` sits at the lid half's origin (canvas y 496); its children use lid-local points (`ChestLayout`).
@MainActor
final class SceneLid {
    let root: SKNode
    /// The lip and fangs (the bite slams this down across the fold).
    let jaw: SKNode
    private let base: SKSpriteNode
    private let extRoot: SKNode
    private var tiles: [SKSpriteNode] = []
    private let cap: SKSpriteNode
    private let vignette: SKSpriteNode
    private let dim: SKSpriteNode
    private let glow: SKSpriteNode
    private let lip: SKSpriteNode
    private let teeth: SKSpriteNode
    private let drool: SKSpriteNode

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
    private let browLeft: SKSpriteNode
    private let browRight: SKSpriteNode
    private let browKnob: SKSpriteNode
    private let zzz: [SceneLabel]
    private let plate: SKSpriteNode
    private let nameLabel: SceneLabel
    private let subLabel: SceneLabel
    private let sliderRoot: SKNode
    private let knob: SKSpriteNode
    private let chevron: SKSpriteNode
    private let sparkles: [SKSpriteNode]

    private(set) var dress: ChestDress = .tier(.wooden)
    var tier: ChestTier {
        if case .tier(let t) = dress { return t }
        return shownTier
    }
    private var shownTier: ChestTier = .wooden
    private(set) var name: String = ""
    private(set) var subline: String = ""
    /// The eye's openness as drawn, 0 … 1 (tests).
    private(set) var wake: Double = 0
    /// How far the fangs are bared, 0 … 1 (tests).
    private(set) var teethShown: CGFloat = 0
    /// The brow's tilt now (radians; > 0 is angry).
    private(set) var browTilt: CGFloat = 0
    /// Eye path rebuilds so far (tests: only when the quantised wake changes).
    private(set) var eyeRebuilds = 0
    /// The extension drawn above the canvas lid (pt).
    private(set) var topExtension: CGFloat = 0
    private var wakeStep = -1
    private var look: CGPoint = .zero
    private var time: Double = 0
    private var blinkAge: Double = 10
    private var blinkLength: Double = 0.2
    private var blinkOpen: Double = 0.3
    private var nextBlink: Double = 1
    private var twitchAge: Double = 10
    private var arriveAge: Double = 10
    private var plateAge: Double = 10
    private var squashAge: Double = 10
    private var sparkPhase: [Double] = [1, 1, 1, 1]
    private var rng = SceneRNG(seed: 0x1D_E7E)

    static let wakeSteps = 25

    init() {
        let pal = ChestArt.palette
        let ls = ChestLayout.lidSize
        let rootN = SKNode()
        rootN.position = CGPoint(x: 0, y: ChestLayout.lidBottom)

        let baseN = SKSpriteNode(texture: SceneTextures.lid(.tier(.wooden)), size: ls)
        baseN.anchorPoint = .zero
        baseN.zPosition = 0
        let extN = SKNode()
        extN.zPosition = 0.2
        let capN = SKSpriteNode(texture: SceneTextures.lidCap(.tier(.wooden)),
                                size: CGSize(width: ls.width, height: ChestLayout.lidCapHeight))
        capN.anchorPoint = CGPoint(x: 0, y: 1)
        capN.position = CGPoint(x: 0, y: ls.height)
        capN.zPosition = 0.3
        let vigN = SKSpriteNode(texture: SceneTextures.vignette, size: ls)
        vigN.anchorPoint = .zero
        vigN.color = .black
        vigN.colorBlendFactor = 1
        vigN.alpha = 0.42
        vigN.zPosition = 6
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

        // The jaw: the fangs tucked up behind the fleshy lip.
        let jawN = SKNode()
        jawN.zPosition = 50
        let lipN = SKSpriteNode(texture: SceneTextures.lip, size: CGSize(width: ls.width, height: ChestLayout.lipHeight))
        lipN.anchorPoint = CGPoint(x: 0.5, y: 0)
        lipN.position = CGPoint(x: ls.width / 2, y: ChestLayout.lipBottom)
        lipN.zPosition = 2
        let teethN = SKSpriteNode(texture: SceneTextures.teeth, size: CGSize(width: ls.width, height: 64))
        teethN.anchorPoint = CGPoint(x: 0.5, y: 1)
        teethN.position = CGPoint(x: ls.width / 2, y: ChestLayout.gumY + 2)
        teethN.zPosition = 1
        let droolN = SKSpriteNode(texture: SceneTextures.dot, size: CGSize(width: 9, height: 14))
        droolN.anchorPoint = CGPoint(x: 0.5, y: 1)
        droolN.position = CGPoint(x: ls.width / 9 * 1.5, y: ChestLayout.lipBottom + 6)
        droolN.color = UIColor(red: 0.85, green: 0.93, blue: 1, alpha: 1)
        droolN.colorBlendFactor = 1
        droolN.alpha = 0
        droolN.zPosition = 3
        jawN.addChild(teethN)
        jawN.addChild(lipN)
        jawN.addChild(droolN)

        // The eye: the white (clipped), iris and pupil inside a crop; the fleshy lid skin and lashes over it.
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
        shadeN.color = ScenePaint.ui(ChestArt.fleshDark)
        shadeN.colorBlendFactor = 1
        shadeN.zPosition = 3
        let irisSide = SceneTextures.irisSide
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
        let lidTopN = SKShapeNode(path: paths.lidTop)
        lidTopN.fillColor = ScenePaint.ui(ChestArt.flesh)
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

        // The brass brow plate: two halves meeting over the eye (a "V" when angry).
        let bh = ChestLayout.browHalf
        let bc = ChestLayout.browCenter
        let browL = SKSpriteNode(texture: SceneTextures.browHalf, size: CGSize(width: bh.width + 6, height: bh.height + 6))
        browL.anchorPoint = CGPoint(x: 1, y: 0.5)
        browL.position = CGPoint(x: bc.x - 2, y: bc.y)
        browL.zPosition = 3
        let browR = SKSpriteNode(texture: SceneTextures.browHalf, size: browL.size)
        browR.anchorPoint = CGPoint(x: 1, y: 0.5)
        browR.xScale = -1
        browR.position = CGPoint(x: bc.x + 2, y: bc.y)
        browR.zPosition = 3
        let knobN = SKSpriteNode(texture: SceneTextures.browKnob(.tier(.wooden)), size: CGSize(width: 52, height: 52))
        knobN.position = CGPoint(x: bc.x, y: bc.y + 2)
        knobN.zPosition = 3.5

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
        let nameN = SceneLabel(size: 24, color: ScenePaint.ui(RGBA(hex: 0x2E1606)), outline: nil)
        nameN.maxWidth = ChestLayout.plateSize.width - 80
        nameN.node.position = CGPoint(x: 0, y: 14)
        plateN.addChild(nameN.node)
        let subN = SceneLabel(size: 16, color: ScenePaint.ui(RGBA(hex: 0x4A2408)), outline: nil, minimumSize: 13)
        subN.maxWidth = ChestLayout.plateSize.width - 70
        subN.node.position = CGPoint(x: 0, y: -15)
        plateN.addChild(subN.node)

        let sliderN = SKNode()
        sliderN.zPosition = 12
        sliderN.isHidden = true
        let trackH = ChestLayout.sliderMaxY - ChestLayout.sliderMinY + 40
        let trackN = SKSpriteNode(texture: SceneTextures.sliderTrack, size: CGSize(width: 56, height: trackH))
        trackN.position = CGPoint(x: ChestLayout.sliderX, y: (ChestLayout.sliderMinY + ChestLayout.sliderMaxY) / 2)
        let knobS = SKSpriteNode(texture: SceneTextures.sliderKnob, size: CGSize(width: 96, height: 56))
        knobS.position = CGPoint(x: ChestLayout.sliderX, y: ChestLayout.sliderMinY)
        knobS.zPosition = 1
        let chevN = SKSpriteNode(texture: SceneTextures.chevron, size: CGSize(width: 40, height: 26))
        chevN.zPosition = 2
        chevN.alpha = 0
        sliderN.addChild(trackN)
        sliderN.addChild(knobS)
        sliderN.addChild(chevN)

        var sp: [SKSpriteNode] = []
        for _ in 0..<4 {
            let s = SKSpriteNode(texture: SceneTextures.sparkle, size: CGSize(width: 30, height: 30))
            s.blendMode = .add
            s.color = UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 1)
            s.colorBlendFactor = 1
            s.alpha = 0
            s.isHidden = true
            s.zPosition = 9.5
            sp.append(s)
        }

        let all: [SKNode] = [baseN, extN, capN, vigN, eyeRoot, browL, browR, knobN, dimN, glowN, plateN, jawN, sliderN]
        for n in all { rootN.addChild(n) }
        for z in zs { rootN.addChild(z.node) }
        for s in sp { rootN.addChild(s) }

        root = rootN
        jaw = jawN
        base = baseN
        extRoot = extN
        cap = capN
        vignette = vigN
        dim = dimN
        glow = glowN
        lip = lipN
        teeth = teethN
        drool = droolN
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
        browLeft = browL
        browRight = browR
        browKnob = knobN
        zzz = zs
        plate = plateN
        nameLabel = nameN
        subLabel = subN
        sliderRoot = sliderN
        knob = knobS
        chevron = chevN
        sparkles = sp
        rebuildEye(step: 0)
    }

    /// R2: grow the lid up into `top` points of extension above the canvas (planks, iron, the far border and
    /// brackets at the very top). 0 on the Duo.
    func applyExtension(top: CGFloat) {
        let t = max(top.rounded(), 0)
        topExtension = t
        let ls = ChestLayout.lidSize
        let need = t > 0 ? Int(ceil(t / ChestLayout.lidTileHeight)) : 0
        while tiles.count < need {
            let s = SKSpriteNode(texture: SceneTextures.lidTile(dress),
                                 size: CGSize(width: ls.width, height: ChestLayout.lidTileHeight))
            s.anchorPoint = .zero
            extRoot.addChild(s)
            tiles.append(s)
        }
        for (k, s) in tiles.enumerated() {
            s.isHidden = k >= need
            s.position = CGPoint(x: 0, y: ls.height + CGFloat(k) * ChestLayout.lidTileHeight)
        }
        cap.position = CGPoint(x: 0, y: ls.height + t)
        let full = CGSize(width: ls.width, height: ls.height + t)
        vignette.size = full
        dim.size = full
    }

    func setDress(_ d: ChestDress, tier t: ChestTier, animated: Bool) {
        shownTier = t
        guard d != dress else { return }
        dress = d
        base.texture = SceneTextures.lid(d)
        cap.texture = SceneTextures.lidCap(d)
        let tileTex = SceneTextures.lidTile(d)
        for s in tiles { s.texture = tileTex }
        browKnob.texture = SceneTextures.browKnob(d)
        if animated { arriveAge = 0 }
    }

    func setTier(_ t: ChestTier, animated: Bool) { setDress(.tier(t), tier: t, animated: animated) }

    /// The name plate: the mimic's name and its trait / tier line. A new name slides the plate in.
    func setPlate(name s: String, subline sub: String) {
        if s != name {
            name = s
            nameLabel.set(s)
            plateAge = 0
        }
        if sub != subline {
            subline = sub
            subLabel.set(sub)
        }
    }

    func setName(_ s: String) { setPlate(name: s, subline: subline) }

    func twitch() { twitchAge = 0 }

    /// The bite's squash on the lid (a few frames).
    func squash() { squashAge = 0 }

    func reset() {
        twitchAge = 10
        blinkAge = 10
        arriveAge = 10
        plateAge = 10
        squashAge = 10
        jaw.position = .zero
        root.position = CGPoint(x: 0, y: ChestLayout.lidBottom)
        root.yScale = 1
        plate.position = ChestLayout.plateCenter
        plate.alpha = 1
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

    /// How far the fangs are bared for a stage and noise.
    static func teethTarget(stage: MimicStage, noise: Double) -> CGFloat {
        switch stage {
        case .asleep: return 0
        case .stirring: return 0.3
        case .waking: return CGFloat(0.7 + 0.3 * min(max((noise - 0.7) / 0.3, 0), 1))
        case .biting: return 1
        }
    }

    /// The brow's tilt for a stage (radians; the outer ends rise into an angry "V").
    static func browTarget(stage: MimicStage) -> CGFloat {
        switch stage {
        case .asleep: return -0.03
        case .stirring: return 0.09
        case .waking: return 0.21
        case .biting: return 0.28
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

        // Arrival: the new lid drops in; the bite squashes it.
        arriveAge += dt
        squashAge += dt
        if arriveAge < 0.5 && !reduceMotion {
            let t = CGFloat(arriveAge / 0.5)
            root.position = CGPoint(x: 0, y: ChestLayout.lidBottom + 70 * (1 - t) * (1 - t))
        } else {
            root.position = CGPoint(x: 0, y: ChestLayout.lidBottom)
        }
        root.yScale = squashAge < 0.24 && !reduceMotion ? 1 - 0.05 * CGFloat(sin(squashAge / 0.24 * Double.pi)) : 1

        // The plate slides in with a new name (fades under Reduce Motion).
        plateAge += dt
        if plateAge < 0.45 {
            let t = CGFloat(plateAge / 0.45)
            if reduceMotion {
                plate.position = ChestLayout.plateCenter
                plate.alpha = t
            } else {
                let e = 1 - (1 - t) * (1 - t) * (1 - t)
                plate.position = CGPoint(x: ChestLayout.plateCenter.x + 520 * (1 - e), y: ChestLayout.plateCenter.y)
                plate.alpha = 1
            }
        } else {
            plate.position = ChestLayout.plateCenter
            plate.alpha = 1
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

        // The brow tilts angry as it wakes (the bite pins it).
        let bt = wakeOverride != nil && (wakeOverride ?? 0) > 0.9 ? SceneLid.browTarget(stage: .biting)
            : SceneLid.browTarget(stage: s.stage)
        browTilt += (bt - browTilt) * CGFloat(min(dt * 9, 1))
        browLeft.zRotation = -browTilt
        browRight.zRotation = browTilt
        let lift = max(browTilt, 0) * 30
        browLeft.position.y = ChestLayout.browCenter.y - lift * 0.3
        browRight.position.y = browLeft.position.y
        browKnob.position.y = browLeft.position.y + 2

        // The fangs slide down from behind the lip as it wakes.
        var tt = teethOverride ?? SceneLid.teethTarget(stage: s.stage, noise: s.noise)
        if teethOverride == nil && twitchAge < 0.35 { tt = max(tt, 0.35) }
        teethShown += (tt - teethShown) * CGFloat(min(dt * 10, 1))
        let tuck = 1 - min(max(teethShown, 0), 1)
        teeth.position.y = ChestLayout.gumY + 2 + 34 * tuck
        teeth.yScale = 0.72 + 0.28 * (1 - tuck)
        // A drool glint at a canine while it sleeps.
        let sleepy: CGFloat = s.stage == .asleep && wake < 0.08 ? 1 : 0
        let dr = (time / 2.6).truncatingRemainder(dividingBy: 1)
        drool.alpha = sleepy * CGFloat(0.55 * min(dr * 5, 1) * (1 - SceneLid.smooth((dr - 0.8) / 0.2)))
        drool.yScale = reduceMotion ? 1 : CGFloat(1 + 0.7 * dr)

        // Zzz while asleep.
        let ec = ChestLayout.eyeCenter
        for (i, z) in zzz.enumerated() {
            let ph = (time / 3.2 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
            let k = CGFloat(ph)
            z.node.position = CGPoint(x: ec.x + 190 + 26 * k + CGFloat(i) * 8, y: ec.y + 30 + 90 * k)
            z.node.alpha = sleepy * min(k * 4, 1) * (1 - k) * 1.4
        }

        // The golden mimic's sparkle.
        let golden = dress == .golden
        for (i, sp) in sparkles.enumerated() {
            sp.isHidden = !golden
            guard golden else { continue }
            let ph = (time / 1.7 + Double(i) * 0.27).truncatingRemainder(dividingBy: 1)
            if ph < sparkPhase[i] {
                // A new twinkle: somewhere else on the lid.
                sp.position = CGPoint(x: rng.range(60, ChestLayout.lidSize.width - 60),
                                      y: rng.range(190, ChestLayout.lidSize.height + topExtension - 40))
            }
            sparkPhase[i] = ph
            sp.alpha = CGFloat(sin(ph * Double.pi)) * 0.9
            sp.zRotation = CGFloat(ph) * 1.4
            sp.setScale(reduceMotion ? 0.9 : CGFloat(0.6 + 0.6 * sin(ph * Double.pi)))
        }

        // The slider, with an up-chevron while it's shut and the bag is empty.
        sliderRoot.isHidden = !usesSlider
        if usesSlider {
            let ky = ChestLayout.sliderMinY + (ChestLayout.sliderMaxY - ChestLayout.sliderMinY) * o
            knob.position = CGPoint(x: ChestLayout.sliderX, y: ky)
            let invite = o < 0.05 && s.bagValue == 0 && (s.phase == .ready || s.phase == .looting)
            let bob = reduceMotion ? 0 : CGFloat(sin(time * 4)) * 6
            chevron.position = CGPoint(x: ChestLayout.sliderX, y: ky + 52 + bob)
            let ca: CGFloat = invite ? 0.9 : 0
            chevron.alpha += (ca - chevron.alpha) * CGFloat(min(dt * 6, 1))
        }
    }

    private static func smooth(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }
}

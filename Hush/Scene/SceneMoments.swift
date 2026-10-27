import SpriteKit
import UIKit

/// What the moments ask of the rest of the scene this frame.
struct SceneMomentFrame {
    /// The jaw's drop (lid-local points, ≤ 0: the fangs slam down across the fold).
    var jawDrop: CGFloat = 0
    /// R3: the chest's small hop (floor points, 0 … 8: the arrival bump, the bite's hops). The chest never leaves.
    var chestOffset: CGFloat = 0
    var wakeOverride: Double?
    var teethOverride: CGFloat?
    /// Bagged loot is hidden while its flyers are in the air (the bank).
    var hideBagged = false
    /// R4: how far the between-chests shadow is down (0 … 1). The floor lifts its own lid-shut darkness by this much,
    /// so the interior reads DIMMED (about 40 % of its light), never black (UX P2-4, tester 8).
    var interiorCover: CGFloat = 0
}

/// The big beats, all cosmetic, timed on the scene's FX clock from the events that start them:
/// - **Bite** (`bitten` + `biteCost`): the jaw slams down across the fold to meet a row of lower fangs rising from
///   the back wall (0.09 s), the lid squashes, the canvas shakes and flashes red, "CHOMP!" pops (cream, thick dark-red
///   edge), then "Too loud!" and what it cost ("−164" over the pouch, "−10s" off the candle); the eye goes wide; the
///   loot in hand flies into the mouth (`SceneLootView`). The jaw chews twice, lifts at 0.55–0.85 s, the chest hops
///   twice, then the interior goes dark (1.45–1.8 s).
/// - **Bank** (`banked`): the lid's shadow sweeps over the INTERIOR from the fold to the front (0.35 s) and stays
///   (R3, juror P0-1: the frame, front wall and lock stay lit at full alpha, every tier); the bagged loot flies out of
///   the pouch in arcs and dives into the BANKED coin stack UNDER the plate's label (it never covers "BANKED"); one
///   centred stack pops: "Hushed!" over "BANKED +179" over "Hush Chain ×1.3" (`chainUp`).
/// - **Arrival** (`chestArrived`): the interior's shadow lifts (0.5 s), the new dress fades in over the old one, the
///   chest bumps and dust flies. Its name, trait and tier are on the lid's name plate (never over the loot).
/// - **Relic found** (`relicFound`, after the bank's stack): a big parchment card on the floor ("RELIC FOUND!", the
///   relic, its name) over a golden sunburst, fully shown for ≥ 1.2 s.
/// - **Creak** (`ChestScene.showCreak()`, R3): "CREAK!" jolts in under the hint band, the lid twitches, the canvas
///   bumps (the HUD flashes the meter red). The App calls it from Feel's creak accent (never a rule on noise here).
/// - **Candle out**: darkness closes in from the edges over 1.4 s, then everything goes black.
/// - **Waking**: a slow red pulse round the floor half's edges (steady under Reduce Motion).
/// Reduce Motion: no shake, no red flash; everything else plays.
@MainActor
final class SceneMoments {
    /// In the floor half, over the loot and under the HUD: the interior's shutter, the throat, the lower fangs, the
    /// bank's flyers (under the plates' labels).
    let floorRoot: SKNode
    /// Over the floor and lid (shaken with them): CHOMP, callouts, the relic card, popups.
    let fxRoot: SKNode
    /// Over everything (never shaken): the red flash, the danger pulse, candle-out darkness.
    let overlayRoot: SKNode
    var reduceMotion = false

    private let shutter: SKSpriteNode
    private let throat: SKSpriteNode
    private let lowerTeeth: SKSpriteNode
    private let chomp: SceneLabel
    private let tooLoud: SceneLabel
    private let biteLoss: SceneLabel
    private let bankEyebrow: SceneLabel
    private let bankValue: SceneLabel
    private let bankSub: SceneLabel
    private let creakLabel: SceneLabel
    /// R4 (UX P2-4): "Next chest…" in the dimmed interior between chests.
    private let nextLabel: SceneLabel
    private var nextLevel: CGFloat = 0
    private let bannerRays: SKSpriteNode
    private let relicCard: SKNode
    private let bannerArt: SKSpriteNode
    private let bannerTag: SceneLabel
    private let bannerName: SceneLabel
    private let flash: SKSpriteNode
    private let danger: SKSpriteNode
    private let closeIn: SKSpriteNode
    private let black: SKSpriteNode
    private var flyers: [SKSpriteNode] = []
    private var popups: [SceneLabel] = []

    private var biteAge: Double = 99
    private var bankAge: Double = 99
    private var arriveAge: Double = 99
    private var creakAge: Double = 99
    private var torchAge: Double?
    private var exited = false
    private var flashAge: Double = 99
    private var shakeAmp: CGFloat = 0
    private(set) var shake: CGPoint = .zero
    private var dangerLevel: CGFloat = 0
    private var time: Double = 0
    private var rng = SceneRNG(seed: 0xC0_40)
    private var biteLost = 0
    private var bankHushed = false
    private var bankChain = false
    /// Set when the lid should squash this frame (the slam).
    private(set) var slammedThisFrame = false
    /// Set when the lid should twitch this frame (a creak).
    private(set) var creakedThisFrame = false
    /// How dark the interior's shutter is now (0 open … 1 the lid's shadow over the whole interior; tests).
    private(set) var shutLevel: CGFloat = 0
    /// Creaks drawn so far (tests).
    private(set) var creakCount = 0

    private struct Flyer {
        var from: CGPoint
        var delay: Double
        var landed = false
    }
    private var flights: [Flyer] = []
    private var relicQueue: [RelicID] = []
    private var bannerAge: Double = 99
    private var popupAge: [Double] = []
    private var popupFrom: [CGPoint] = []
    private var popupRise: [CGFloat] = []
    private var popupCursor = 0

    static let bannerTime: Double = 1.9
    /// The bank group shows for this long; the relic card waits for it.
    static let bankGroupEnd: Double = 1.15
    /// The shutter's darkness when the lid's shadow is down. R4 (UX P2-4): 0.9 → 0.6, and the floor's own lid-shut
    /// darkness lifts under it (`SceneMomentFrame.interiorCover`): the interior keeps about 40 % of its light.
    static let shutAlpha: CGFloat = 0.6
    /// R4: "Next chest…" shows from this far into a bank (under the stack), until the next chest's shadow lifts.
    static let nextChestFrom: Double = 0.8

    /// Moment flags (tests and the App's CI freezes).
    var biteActive: Bool { biteAge < 1.8 }
    var bankActive: Bool { bankAge < 1.4 }
    var arrivalActive: Bool { arriveAge < 0.8 }
    var bannerShowing: Bool { bannerAge < SceneMoments.bannerTime }
    /// The relic card is fully up (a still frame shows the relic and its name).
    var relicCardFullyShown: Bool { bannerAge >= 0.12 && bannerAge < 1.5 }
    var creakShowing: Bool { creakAge < 0.7 }
    var torchOutLevel: CGFloat { torchAge.map { CGFloat(min($0 / 2, 1)) } ?? 0 }
    /// The bite callout's text as showing ("Too loud!" / "−164"), for tests.
    var biteCalloutShowing: Bool { !tooLoud.node.isHidden && tooLoud.node.alpha > 0.05 }
    var biteLossText: String { biteLoss.text }
    /// The bank stack's third line ("Hush Chain ×1.3"; tests).
    var bankSubText: String { bankSub.text }
    /// R4: "Next chest…" is up (tests; the App hides its hint meanwhile), and the bank stack's chain line is drawn.
    var nextChestShowing: Bool { !nextLabel.node.isHidden && nextLabel.node.alpha > 0.3 }
    var bankSubShowing: Bool { !bankSub.node.isHidden }
    /// R4: the share of the interior's light the between-chests shadow lets through (1 open … ≈ 0.4 shut).
    private(set) var interiorLight: CGFloat = 1

    init() {
        let pal = ChestArt.palette
        let canvas = ChestLayout.canvas
        let floorN = SKNode()
        floorN.zPosition = 27
        let fxN = SKNode()
        fxN.zPosition = 60
        let overN = SKNode()
        overN.zPosition = 100

        // The lid's shadow over the INTERIOR only (the rims, front wall and lock stay lit).
        let rim = ChestLayout.rimInner
        let shutN = SKSpriteNode(texture: SceneTextures.vertical("shutter", [0.82, 0.96, 1], [0, 0.3, 1]),
                                 size: rim.size)
        shutN.anchorPoint = CGPoint(x: 0.5, y: 1)
        shutN.position = CGPoint(x: rim.midX, y: rim.maxY)
        shutN.color = ScenePaint.ui(pal.dungeonDeep)
        shutN.colorBlendFactor = 1
        shutN.isHidden = true
        shutN.zPosition = 0
        let throatN = SKSpriteNode(texture: SceneTextures.vertical("throat", [0, 0.9], [0, 1]),
                                   size: CGSize(width: canvas.width, height: 90))
        throatN.anchorPoint = CGPoint(x: 0.5, y: 1)
        throatN.position = CGPoint(x: canvas.width / 2, y: ChestLayout.floorTop)
        throatN.color = ScenePaint.ui(ScenePaint.throat)
        throatN.colorBlendFactor = 1
        throatN.alpha = 0
        throatN.zPosition = 1
        let lowerN = SKSpriteNode(texture: SceneTextures.lowerTeeth, size: CGSize(width: canvas.width, height: 72))
        lowerN.anchorPoint = CGPoint(x: 0.5, y: 0)
        lowerN.position = CGPoint(x: canvas.width / 2, y: ChestLayout.interior.maxY - 16)
        lowerN.isHidden = true
        lowerN.zPosition = 2
        for n in [shutN, throatN, lowerN] { floorN.addChild(n) }

        let darkRed = ScenePaint.ui(RGBA(hex: 0x6E0A14))
        let chompN = SceneLabel(size: 72, color: ScenePaint.ui(pal.text), outline: darkRed, strokeWidth: -8)
        chompN.set("CHOMP!")
        chompN.node.position = CGPoint(x: canvas.width / 2, y: ChestLayout.titlePoint.y)
        chompN.node.isHidden = true
        let loudN = SceneLabel(size: 36, color: ScenePaint.ui(pal.danger), outline: ScenePaint.ui(pal.text),
                               strokeWidth: -4)
        loudN.set("Too loud!")
        loudN.node.position = CGPoint(x: canvas.width / 2, y: ChestLayout.titlePoint.y - 66)
        loudN.node.isHidden = true
        let lossN = SceneLabel(size: 34, color: ScenePaint.ui(pal.gold), outline: darkRed, strokeWidth: -6)
        lossN.node.position = CGPoint(x: ChestLayout.pouchMouth.x, y: 168)
        lossN.node.isHidden = true

        // R3: the bank's one centred stack, in the brass / cream palette (no green).
        let eyebrowN = SceneLabel(size: 26, color: ScenePaint.ui(pal.candle))
        eyebrowN.set("Hushed!")
        eyebrowN.node.position = CGPoint(x: canvas.width / 2, y: ChestLayout.bankEyebrowY)
        eyebrowN.node.isHidden = true
        let valueN = SceneLabel(size: 36, color: ScenePaint.ui(pal.gold))
        valueN.maxWidth = ChestLayout.interior.width - 20
        valueN.node.position = CGPoint(x: canvas.width / 2, y: ChestLayout.bankTitleY)
        valueN.node.isHidden = true
        let subN = SceneLabel(size: 24, color: ScenePaint.ui(pal.amber))
        subN.maxWidth = ChestLayout.interior.width - 40
        subN.node.position = CGPoint(x: canvas.width / 2, y: ChestLayout.bankSubY)
        subN.node.isHidden = true

        // R3: "CREAK!" (a slam that didn't bite): cream with a thick brown edge, tilted.
        let creakN = SceneLabel(size: 46, color: ScenePaint.ui(pal.text), outline: ScenePaint.ui(RGBA(hex: 0x5A1E08)),
                                strokeWidth: -8)
        creakN.set("CREAK!")
        creakN.node.position = ChestLayout.creakPoint
        creakN.node.zRotation = -0.08
        creakN.node.isHidden = true

        let nextN = SceneLabel(size: 22, color: ScenePaint.ui(pal.candle, alpha: 0.92))
        nextN.set("Next chest…")
        nextN.node.position = ChestLayout.nextChestPoint
        nextN.node.isHidden = true

        // R3: the relic card: a parchment plate with the relic and its name, over a sunburst.
        let bp = ChestLayout.relicBannerPoint
        let cardSize = ChestLayout.relicCardSize
        let raysN = SKSpriteNode(texture: SceneTextures.rays, size: CGSize(width: 460, height: 460))
        raysN.position = bp
        raysN.blendMode = .add
        raysN.color = ScenePaint.ui(pal.gold)
        raysN.colorBlendFactor = 1
        raysN.isHidden = true
        let cardN = SKNode()
        cardN.position = bp
        cardN.isHidden = true
        let plateN = SKSpriteNode(texture: SceneTextures.plateTexture(size: cardSize, style: .parchment), size: cardSize)
        plateN.zPosition = 0
        cardN.addChild(plateN)
        let ink = ChestArt.plateColors(.parchment)
        let artN = SKSpriteNode()
        artN.position = CGPoint(x: 0, y: 6)
        artN.zPosition = 1
        cardN.addChild(artN)
        let tagN = SceneLabel(size: 20, color: ScenePaint.ui(ink.accent), outline: nil, kern: 1.6)
        tagN.set("RELIC FOUND!")
        tagN.node.position = CGPoint(x: 0, y: cardSize.height / 2 - 30)
        tagN.node.zPosition = 1
        cardN.addChild(tagN.node)
        let bnameN = SceneLabel(size: 26, color: ScenePaint.ui(ink.text), outline: nil)
        bnameN.maxWidth = cardSize.width - 60
        bnameN.node.position = CGPoint(x: 0, y: -cardSize.height / 2 + 32)
        bnameN.node.zPosition = 1
        cardN.addChild(bnameN.node)

        var fl: [SKSpriteNode] = []
        for _ in 0..<10 {
            let s = SKSpriteNode()
            s.isHidden = true
            // Under the HUD's labels (HUD z 30 > floorRoot z 27 + 0.5): they dive INTO the BANKED plate.
            s.zPosition = 0.5
            fl.append(s)
        }
        var pops: [SceneLabel] = []
        for _ in 0..<8 {
            let l = SceneLabel(size: 26, color: ScenePaint.ui(pal.gold))
            l.maxWidth = 230
            l.node.isHidden = true
            l.node.zPosition = 6
            pops.append(l)
        }
        let fxNodes: [SKNode] = [raysN, cardN, eyebrowN.node, valueN.node, subN.node, chompN.node, loudN.node,
                                 lossN.node, creakN.node, nextN.node]
        for n in fxNodes { fxN.addChild(n) }
        for s in fl { floorN.addChild(s) }
        for l in pops { fxN.addChild(l.node) }

        let flashN = SKSpriteNode(color: ScenePaint.ui(pal.danger), size: canvas)
        flashN.anchorPoint = .zero
        flashN.alpha = 0
        flashN.isHidden = true
        let dangerN = SKSpriteNode(texture: SceneTextures.vignette,
                                   size: CGSize(width: canvas.width, height: ChestLayout.floorTop))
        dangerN.anchorPoint = .zero
        dangerN.color = ScenePaint.ui(pal.danger)
        dangerN.colorBlendFactor = 1
        dangerN.alpha = 0
        dangerN.isHidden = true
        let closeN = SKSpriteNode(texture: SceneTextures.vignette, size: canvas)
        closeN.position = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
        closeN.color = ScenePaint.ui(pal.dungeonDeep)
        closeN.colorBlendFactor = 1
        closeN.isHidden = true
        let blackN = SKSpriteNode(color: ScenePaint.ui(pal.dungeonDeep), size: canvas)
        blackN.anchorPoint = .zero
        blackN.alpha = 0
        blackN.isHidden = true
        for n in [dangerN, flashN, closeN, blackN] { overN.addChild(n) }

        floorRoot = floorN
        fxRoot = fxN
        overlayRoot = overN
        shutter = shutN
        throat = throatN
        lowerTeeth = lowerN
        chomp = chompN
        tooLoud = loudN
        biteLoss = lossN
        bankEyebrow = eyebrowN
        bankValue = valueN
        bankSub = subN
        creakLabel = creakN
        nextLabel = nextN
        bannerRays = raysN
        relicCard = cardN
        bannerArt = artN
        bannerTag = tagN
        bannerName = bnameN
        flash = flashN
        danger = dangerN
        closeIn = closeN
        black = blackN
        flyers = fl
        popups = pops
        popupAge = Array(repeating: 99, count: pops.count)
        popupFrom = Array(repeating: .zero, count: pops.count)
        popupRise = Array(repeating: 56, count: pops.count)
    }

    /// R2: the overlays cover the whole scene (the extension above and below the canvas too).
    func applyExtension(top: CGFloat, bottom: CGFloat) {
        let c = ChestLayout.canvas
        let t = max(top, 0), b = max(bottom, 0)
        let full = CGSize(width: c.width, height: c.height + t + b)
        flash.size = full
        flash.position = CGPoint(x: 0, y: -b)
        black.size = full
        black.position = CGPoint(x: 0, y: -b)
        closeIn.size = full
        closeIn.position = CGPoint(x: c.width / 2, y: -b + full.height / 2)
        danger.size = CGSize(width: c.width, height: ChestLayout.floorTop + b)
        danger.position = CGPoint(x: 0, y: -b)
    }

    // MARK: Triggers

    func clear() {
        biteAge = 99
        bankAge = 99
        arriveAge = 99
        creakAge = 99
        torchAge = nil
        exited = false
        flashAge = 99
        shakeAmp = 0
        shake = .zero
        dangerLevel = 0
        shutLevel = 0
        flights = []
        relicQueue = []
        bannerAge = 99
        for i in 0..<popupAge.count { popupAge[i] = 99 }
        for s in flyers { s.isHidden = true }
        for l in popups { l.node.isHidden = true }
        for n in [shutter, lowerTeeth, chomp.node, tooLoud.node, biteLoss.node, bankEyebrow.node, bankValue.node,
                  bankSub.node, creakLabel.node, nextLabel.node, bannerRays, relicCard, flash, danger, closeIn,
                  black] as [SKNode] {
            n.isHidden = true
        }
        nextLevel = 0
        interiorLight = 1
        throat.alpha = 0
    }

    static func tierName(_ t: ChestTier) -> String {
        switch t {
        case .wooden: return "Wooden chest"
        case .iron: return "Iron-bound chest"
        case .gilded: return "Gilded chest"
        case .royal: return "Royal chest"
        }
    }

    static func multiplierText(_ m: Double) -> String { ChestCopy.multiplier(m) }

    /// A new chest: the interior's shadow lifts (its name, trait and tier go on the lid's plate, not here).
    func arrive() {
        arriveAge = 0
        exited = false
        biteAge = 99
        bankAge = 99
        torchAge = nil
        flights = []
        for s in flyers { s.isHidden = true }
    }

    /// The bite starts (`lostValue` from `bitten`; a `biteCost` in the same frame, before or after, refines it).
    func bite(lostValue: Int = 0) {
        biteAge = 0
        bankAge = 99
        if lostValue > 0 && biteLost == 0 {
            biteLost = lostValue
            biteLoss.set("−\(SceneNumber.gold(lostValue))")
        }
    }

    /// What the bite cost (R2 `biteCost`): "−164" over the pouch and "−10s" flying off the candle.
    func biteCost(lostValue: Int, seconds: Double, candle: CGPoint) {
        biteLost = max(lostValue, 0)
        biteLoss.set(biteLost > 0 ? "−\(SceneNumber.gold(biteLost))" : "")
        if seconds.isFinite && seconds > 0 {
            popup("−\(Int(seconds.rounded()))s", at: CGPoint(x: candle.x + 56, y: min(candle.y + 10, 336)),
                  color: ScenePaint.ui(ChestArt.palette.danger), delay: 0.2, rise: 46)
        }
    }

    func bank(items: [(kind: LootKind, radius: CGFloat, value: Int, point: CGPoint)], value: Int, hushed: Bool) {
        bankAge = 0
        biteAge = 99
        flights = []
        bankHushed = hushed
        bankChain = false
        bankValue.set(value > 0 ? "BANKED +\(SceneNumber.gold(value))" : "BANKED")
        for (i, s) in flyers.enumerated() {
            guard i < items.count else {
                s.isHidden = true
                continue
            }
            let it = items[i]
            s.texture = SceneTextures.loot(it.kind, radius: it.radius, value: it.value)
            let side = SceneTextures.lootSide(it.radius)
            s.size = CGSize(width: side, height: side)
            s.position = it.point
            s.setScale(0.66)
            s.isHidden = true
            flights.append(Flyer(from: it.point, delay: 0.12 + Double(i) * 0.07))
        }
    }

    /// The Hush Chain grew: "Hush Chain ×1.3" as the bank stack's third line (centred under "BANKED +n").
    func chainUp(multiplier: Double) {
        let tenths = Int((multiplier.isFinite ? multiplier * 10 : 10).rounded())
        bankSub.set("Hush Chain ×\(tenths / 10).\(tenths % 10)")
        bankChain = true
    }

    func queueRelic(_ id: RelicID) {
        relicQueue.append(id)
    }

    func torchOut() {
        if torchAge == nil { torchAge = 0 }
    }

    /// R3: a slam that didn't bite ("CREAK!"). Not during a bite (the bite says it louder).
    func creak() {
        guard !biteActive else { return }
        creakAge = 0
        creakCount += 1
        creakedThisFrame = true
        bump(7)
    }

    func bump(_ amount: CGFloat) {
        guard !reduceMotion else { return }
        shakeAmp = max(shakeAmp, amount)
    }

    /// A short rising label ("+35", "+6s", "×2", "New best!").
    func popup(_ text: String, at p: CGPoint, color: UIColor, delay: Double = 0, rise: CGFloat = 56) {
        guard !popups.isEmpty else { return }
        let i = popupCursor % popups.count
        popupCursor += 1
        let l = popups[i]
        l.set(text)
        l.setColor(color)
        popupAge[i] = -delay
        popupFrom[i] = p
        popupRise[i] = rise
        l.node.isHidden = true
    }

    // MARK: Frame

    private static func smooth(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// R4: a bank flyer's point at `t` (0 … 1) on its way from the pouch to the BANKED coin stack: a low arc
    /// (20 pt over the higher end) that stays inside the bag strip, under the meter. Pure; tested.
    static func flightPoint(from a: CGPoint, t: CGFloat) -> CGPoint {
        let to = ChestLayout.counterCoin
        let k = min(max(t, 0), 1)
        let c = CGPoint(x: (a.x + to.x) / 2 + 30, y: max(a.y, to.y) + 20)
        let u = 1 - k
        return CGPoint(x: u * u * a.x + 2 * u * k * c.x + k * k * to.x, y: u * u * a.y + 2 * u * k * c.y + k * k * to.y)
    }

    private static func popScale(_ age: Double) -> CGFloat {
        if age < 0.12 { return CGFloat(0.3 + (1.2 - 0.3) * age / 0.12) }
        if age < 0.24 { return CGFloat(1.2 - 0.2 * (age - 0.12) / 0.12) }
        return 1
    }

    /// Shows `l` popping in at `start` s and fading by `end` s on a moment's clock `a`.
    private static func beat(_ l: SceneLabel, _ a: Double, start: Double, end: Double, show: Bool = true) {
        let t = a - start
        guard show, t >= 0, a < end else {
            l.node.isHidden = true
            return
        }
        l.node.isHidden = false
        l.node.setScale(popScale(t))
        l.node.alpha = CGFloat(1 - smooth((a - (end - 0.3)) / 0.3))
    }

    func update(dt: Double, snapshot s: HeistSnapshot, effects: SceneEffects, hud: SceneFloorHUD,
                lid: SceneLid) -> SceneMomentFrame {
        time += dt
        slammedThisFrame = false
        let creakedNow = creakedThisFrame
        creakedThisFrame = false
        var f = SceneMomentFrame()
        let pal = ChestArt.palette
        let w = ChestLayout.canvas.width

        // The interior's shutter: down while the chest is "between chests"; the moments below move it.
        var cover: CGFloat = exited ? 1 : 0
        var coverAlpha: CGFloat = SceneMoments.shutAlpha
        var offset: CGFloat = 0

        // Arrival: the shadow lifts, the chest bumps.
        let prevArrive = arriveAge
        arriveAge += dt
        if arriveAge < 0.8 {
            let a = arriveAge
            if a < 0.5 {
                cover = 1
                coverAlpha = SceneMoments.shutAlpha * CGFloat(1 - SceneMoments.smooth(a / 0.5))
            } else {
                offset = 6 * CGFloat(sin((a - 0.5) / 0.3 * Double.pi))
            }
            if prevArrive < 0.5 && arriveAge >= 0.5 {
                let dust = UIColor(red: 0.72, green: 0.6, blue: 0.47, alpha: 1)
                effects.dustPuff(from: CGPoint(x: 60, y: 140), to: CGPoint(x: w - 60, y: 140), count: 12, color: dust)
                effects.dustPuff(from: CGPoint(x: 70, y: 150), to: CGPoint(x: 70, y: 410), count: 4, color: dust)
                effects.dustPuff(from: CGPoint(x: w - 70, y: 150), to: CGPoint(x: w - 70, y: 400), count: 4, color: dust)
                bump(5)
            }
        }

        // The bite.
        let prevBite = biteAge
        biteAge += dt
        var jawK: CGFloat = 0
        if biteAge < 2 {
            let a = biteAge
            let slam = 0.09
            if a < slam {
                jawK = CGFloat((a / slam) * (a / slam))
            } else if a < 0.55 {
                jawK = 1 - 0.08 * CGFloat(abs(sin((a - slam) * 14)))
            } else if a < 0.85 {
                jawK = 1 - CGFloat(SceneMoments.smooth((a - 0.55) / 0.3))
            }
            if prevBite < slam && a >= slam {
                bump(18)
                slammedThisFrame = true
                if !reduceMotion { flashAge = 0 }
                effects.sparkBurst(at: ChestLayout.mouthPoint, count: 10, color: ScenePaint.ui(pal.candle), speed: 260)
                effects.dustPuff(from: CGPoint(x: 60, y: 430), to: CGPoint(x: w - 60, y: 430), count: 10,
                                 color: UIColor(white: 0.6, alpha: 1))
            }
            f.teethOverride = a < 1.0 ? 1 : nil
            f.wakeOverride = a < 0.9 ? 1 : 0.35
            // CHOMP!, then the cost.
            SceneMoments.beat(chomp, a, start: slam, end: 1.4)
            SceneMoments.beat(tooLoud, a, start: 0.3, end: 1.75)
            SceneMoments.beat(biteLoss, a, start: 0.42, end: 1.75, show: biteLost > 0)
            // Hop twice (a few points: the frame never leaves the satchel), then the interior goes dark.
            if a >= 1.1 && a < 1.45 {
                offset = 8 * CGFloat(abs(sin((a - 1.1) / 0.35 * 2 * Double.pi)))
            } else if a >= 1.45 && a < 1.8 {
                cover = CGFloat(SceneMoments.smooth((a - 1.45) / 0.35))
            } else if a >= 1.8 {
                exited = true
                cover = 1
            }
        } else {
            chomp.node.isHidden = true
            tooLoud.node.isHidden = true
            biteLoss.node.isHidden = true
            if biteLost != 0 {
                biteLost = 0
                biteLoss.set("")
            }
        }
        f.jawDrop = -96 * jawK
        lowerTeeth.isHidden = jawK < 0.01
        lowerTeeth.yScale = max(jawK, 0.01)
        throat.alpha = 0.85 * jawK

        // A creak: "CREAK!" jolts in and wobbles.
        creakAge += dt
        if creakAge < 0.7 {
            let a = creakAge
            creakLabel.node.isHidden = false
            let wob = reduceMotion ? 0 : CGFloat(sin(a * 38) * 0.06 * max(0, 1 - a / 0.4))
            creakLabel.node.zRotation = -0.08 + wob
            creakLabel.node.setScale(SceneMoments.popScale(a))
            creakLabel.node.alpha = CGFloat(1 - SceneMoments.smooth((a - 0.45) / 0.25))
            if creakedNow && !reduceMotion {
                effects.dustPuff(from: CGPoint(x: 120, y: 448), to: CGPoint(x: w - 120, y: 448), count: 6,
                                 color: UIColor(white: 0.6, alpha: 1))
            }
        } else {
            creakLabel.node.isHidden = true
        }

        // The flash and the shake.
        flashAge += dt
        if flashAge < 0.35 {
            flash.isHidden = false
            flash.alpha = CGFloat(0.45 * (1 - flashAge / 0.35))
        } else {
            flash.isHidden = true
        }
        if reduceMotion {
            shakeAmp = 0
            shake = .zero
        } else {
            shakeAmp *= CGFloat(exp(-dt * 7))
            if shakeAmp < 0.3 { shakeAmp = 0 }
            shake = CGPoint(x: (rng.unit() * 2 - 1) * shakeAmp, y: (rng.unit() * 2 - 1) * shakeAmp * 0.7)
        }

        // The bank.
        bankAge += dt
        if bankAge < 2 {
            let a = bankAge
            // The lid's shadow sweeps over the interior, fold → front, and stays down.
            cover = max(cover, CGFloat(SceneMoments.smooth(a / 0.35)))
            f.hideBagged = true
            for i in 0..<flights.count where i < flyers.count {
                let fl = flights[i]
                let node = flyers[i]
                let t = (a - fl.delay) / 0.55
                if t < 0 || fl.landed {
                    node.isHidden = true
                    continue
                }
                let k = CGFloat(min(t, 1))
                // Out of the pouch, over, and down INTO the coin stack (under the "BANKED" label). R4 (juror P2):
                // a LOW arc inside the bag strip, under the meter and the plates' labels, never over them.
                let to = ChestLayout.counterCoin
                node.isHidden = false
                node.position = SceneMoments.flightPoint(from: fl.from, t: k)
                node.setScale(0.66 - 0.3 * k)
                node.zRotation = k * 4
                if t >= 1 {
                    flights[i].landed = true
                    node.isHidden = true
                    effects.sparkBurst(at: CGPoint(x: to.x, y: to.y + 18), count: 5, color: ScenePaint.ui(pal.gold),
                                       speed: 160, size: 18)
                    hud.popCounter()
                }
            }
            // One centred stack: "Hushed!" over "BANKED +179" over "Hush Chain ×1.3".
            SceneMoments.beat(bankValue, a, start: 0.15, end: SceneMoments.bankGroupEnd)
            SceneMoments.beat(bankEyebrow, a, start: 0.3, end: SceneMoments.bankGroupEnd, show: bankHushed)
            // R4 (UX P2-8): no chain line in the First Chest lesson (the run's first chain gets the tip).
            SceneMoments.beat(bankSub, a, start: 0.45, end: SceneMoments.bankGroupEnd,
                              show: bankChain && s.mode != .lesson)
            if a >= 1.4 { exited = true }
        } else {
            bankValue.node.isHidden = true
            bankEyebrow.node.isHidden = true
            bankSub.node.isHidden = true
            for n in flyers { n.isHidden = true }
        }
        f.chestOffset = min(max(offset, 0), 8)
        f.interiorCover = min(max(cover * coverAlpha / SceneMoments.shutAlpha, 0), 1)
        interiorLight = 1 - SceneMoments.shutAlpha * f.interiorCover
        shutLevel = cover * coverAlpha / SceneMoments.shutAlpha
        shutter.isHidden = cover <= 0.005 || coverAlpha <= 0.005
        shutter.yScale = max(cover, 0.01)
        shutter.alpha = coverAlpha

        // The relic card (after the bank's stack has had its moment).
        bannerAge += dt
        if bannerAge >= SceneMoments.bannerTime, !relicQueue.isEmpty, bankAge >= SceneMoments.bankGroupEnd {
            let id = relicQueue.removeFirst()
            let relic = RelicCatalog.all.first(where: { $0.id == id })
            bannerName.set(relic?.name ?? "A relic")
            bannerArt.texture = SceneTextures.loot(.relic(id), radius: 60)
            let side = SceneTextures.lootSide(60)
            bannerArt.size = CGSize(width: side, height: side)
            bannerAge = 0
            effects.sparkBurst(at: ChestLayout.relicBannerPoint, count: 14, color: ScenePaint.ui(pal.gold), speed: 240)
        }
        if bannerAge < SceneMoments.bannerTime {
            let a = bannerAge
            let fade = CGFloat(1 - SceneMoments.smooth((a - 1.5) / 0.4))
            bannerRays.isHidden = false
            relicCard.isHidden = false
            bannerRays.alpha = fade * 0.85
            relicCard.alpha = fade
            bannerRays.zRotation = reduceMotion ? 0 : CGFloat(a) * 0.6
            bannerRays.setScale(SceneMoments.popScale(a) * (1 + 0.05 * CGFloat(sin(a * 3))))
            relicCard.setScale(reduceMotion ? 1 : SceneMoments.popScale(a))
            bannerArt.zRotation = reduceMotion ? 0 : 0.1 * CGFloat(sin(a * 2.4))
        } else {
            bannerRays.isHidden = true
            relicCard.isHidden = true
        }

        // R4 (UX P2-4): "Next chest…" between chests (not in the lesson, not over the relic card, not at the end).
        var between = exited || (bankAge >= SceneMoments.nextChestFrom && bankAge < 2)
        if s.mode == .lesson || torchAge != nil || bannerAge < SceneMoments.bannerTime || !relicQueue.isEmpty {
            between = false
        }
        switch s.phase {
        case .finished, .torchOut: between = false
        default: break
        }
        let nextTarget: CGFloat = between ? 1 : 0
        nextLevel += (nextTarget - nextLevel) * CGFloat(min(dt * 10, 1))
        if nextLevel > 0.01 {
            nextLabel.node.isHidden = false
            nextLabel.node.alpha = nextLevel
        } else {
            nextLevel = 0
            nextLabel.node.isHidden = true
        }

        // Popups.
        for i in 0..<popups.count {
            popupAge[i] += dt
            let a = popupAge[i]
            let l = popups[i]
            if a < 0 || a > 1.0 {
                l.node.isHidden = true
                continue
            }
            l.node.isHidden = false
            let p = popupFrom[i]
            l.node.position = CGPoint(x: p.x, y: p.y + popupRise[i] * CGFloat(SceneMoments.smooth(a / 0.8)))
            l.node.alpha = CGFloat(SceneMoments.smooth(a / 0.1) * (1 - SceneMoments.smooth((a - 0.7) / 0.3)))
        }

        // Waking: the red pulse round the floor half.
        let dangerTarget: CGFloat = s.stage >= .waking && !biteActive ? 1 : 0
        dangerLevel += (dangerTarget - dangerLevel) * CGFloat(min(dt * 5, 1))
        if dangerLevel > 0.01 {
            danger.isHidden = false
            let pulse: CGFloat = reduceMotion ? 1 : 0.75 + 0.25 * CGFloat(sin(time * 7))
            danger.alpha = 0.42 * dangerLevel * pulse
        } else {
            danger.isHidden = true
        }

        // Candle out: the dark closes in.
        if torchAge == nil, case .torchOut(let e) = s.phase { torchAge = e }
        if torchAge == nil, case .finished = s.phase, s.torchTotal > 0, s.torchRemaining <= 0 { torchAge = 2 }
        if let a0 = torchAge {
            let a = a0 + dt
            torchAge = a
            closeIn.isHidden = false
            closeIn.setScale(CGFloat(2.4 - 1.4 * SceneMoments.smooth(a / 1.4)))
            closeIn.alpha = CGFloat(SceneMoments.smooth(a / 0.5))
            black.isHidden = false
            black.alpha = CGFloat(0.92 * SceneMoments.smooth((a - 0.8) / 1.2))
        } else {
            closeIn.isHidden = true
            black.isHidden = true
        }
        _ = lid
        return f
    }
}

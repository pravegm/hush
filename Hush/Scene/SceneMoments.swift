import SpriteKit
import UIKit

/// What the moments ask of the rest of the scene this frame.
struct SceneMomentFrame {
    /// The jaw's drop (lid-local points, ≤ 0: the teeth slam down across the fold).
    var jawDrop: CGFloat = 0
    /// The chest's slide (floor points; −420 = gone off the front).
    var chestOffset: CGFloat = 0
    var wakeOverride: Double?
    var teethOverride: CGFloat?
    /// Bagged loot is hidden while its flyers are in the air (the bank).
    var hideBagged = false
}

/// The big beats, all cosmetic, timed on the scene's FX clock from the events that start them:
/// - **Bite** (`bitten`): the jaw slams down across the fold to meet a row of lower teeth rising from the back wall
///   (0.09 s), the canvas shakes and flashes red, "CHOMP!" pops, the eye goes wide; the loot in hand flies into the
///   mouth (`SceneLootView`). The jaw chews twice, lifts at 0.55–0.85 s, the chest hops twice and leaves off the front.
/// - **Bank** (`banked`): the lid's shadow sweeps from the fold to the front over 0.35 s, the bagged loot flies in arcs
///   to the gold counter (which rolls up), "+gold" and "Hushed!" pop; the chest leaves off the front at 1.05–1.4 s.
/// - **Arrival** (`chestArrived`): the chest slides in from the front (0.5 s, ease-out), lands with dust and a bump,
///   and its mimic's name and tier show for 1.6 s.
/// - **Relic found** (`relicFound`, with the bank): a golden sunburst, the relic, "Relic found!" and its name.
/// - **Torch out**: darkness closes in from the edges over 1.4 s, then the canvas goes black.
/// - **Waking**: a slow red pulse round the floor half's edges (steady under Reduce Motion).
/// Reduce Motion: no shake, no red flash; everything else plays.
@MainActor
final class SceneMoments {
    /// In the floor half, over the loot and under the HUD: the lid shadow, the throat, the lower teeth.
    let floorRoot: SKNode
    /// Over the floor and lid (shaken with them): titles, CHOMP, the relic banner, flyers, popups.
    let fxRoot: SKNode
    /// Over everything (never shaken): the red flash, the danger pulse, torch-out darkness.
    let overlayRoot: SKNode
    var reduceMotion = false

    private let sweep: SKSpriteNode
    private let throat: SKSpriteNode
    private let lowerTeeth: SKSpriteNode
    private let chomp: SceneLabel
    private let titleName: SceneLabel
    private let titleTier: SceneLabel
    private let bannerRays: SKSpriteNode
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
    private var titleAge: Double = 99
    private var titleStart: Double = 0.45
    private var torchAge: Double?
    private var exited = false
    private var flashAge: Double = 99
    private var shakeAmp: CGFloat = 0
    private(set) var shake: CGPoint = .zero
    private var dangerLevel: CGFloat = 0
    private var time: Double = 0
    private var rng = SceneRNG(seed: 0xC0_40)

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

    static let exitOffset: CGFloat = -420
    static let bannerTime: Double = 1.9

    /// Moment flags (tests and the App's CI freezes).
    var biteActive: Bool { biteAge < 1.8 }
    var bankActive: Bool { bankAge < 1.4 }
    var arrivalActive: Bool { arriveAge < 0.8 }
    var bannerShowing: Bool { bannerAge < SceneMoments.bannerTime }
    var torchOutLevel: CGFloat { torchAge.map { CGFloat(min($0 / 2, 1)) } ?? 0 }

    init() {
        let pal = ChestArt.palette
        let canvas = ChestLayout.canvas
        let floorN = SKNode()
        floorN.zPosition = 27
        let fxN = SKNode()
        fxN.zPosition = 60
        let overN = SKNode()
        overN.zPosition = 100

        let sweepN = SKSpriteNode(texture: SceneTextures.vertical("sweep", [0.65, 0.9, 0.95], [0, 0.25, 1]),
                                  size: CGSize(width: canvas.width, height: ChestLayout.floorTop - 110))
        sweepN.anchorPoint = CGPoint(x: 0.5, y: 1)
        sweepN.position = CGPoint(x: canvas.width / 2, y: ChestLayout.floorTop)
        sweepN.color = ScenePaint.ui(pal.dungeonDeep)
        sweepN.colorBlendFactor = 1
        sweepN.isHidden = true
        sweepN.zPosition = 0
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
        for n in [sweepN, throatN, lowerN] { floorN.addChild(n) }

        let chompN = SceneLabel(size: 72, color: ScenePaint.ui(pal.danger))
        chompN.set("CHOMP!")
        chompN.node.position = CGPoint(x: canvas.width / 2, y: 300)
        chompN.node.isHidden = true
        let nameN = SceneLabel(size: 32, color: ScenePaint.ui(pal.text))
        nameN.maxWidth = ChestLayout.interior.width - 20
        nameN.node.position = CGPoint(x: ChestLayout.titlePoint.x, y: ChestLayout.titlePoint.y + 22)
        nameN.node.isHidden = true
        let tierN = SceneLabel(size: 24, color: ScenePaint.ui(pal.gold))
        tierN.maxWidth = ChestLayout.interior.width - 20
        tierN.node.position = CGPoint(x: ChestLayout.titlePoint.x, y: ChestLayout.titlePoint.y - 20)
        tierN.node.isHidden = true

        let bp = ChestLayout.relicBannerPoint
        let raysN = SKSpriteNode(texture: SceneTextures.rays, size: CGSize(width: 360, height: 360))
        raysN.position = bp
        raysN.blendMode = .add
        raysN.color = ScenePaint.ui(pal.gold)
        raysN.colorBlendFactor = 1
        raysN.isHidden = true
        let artN = SKSpriteNode()
        artN.position = bp
        artN.isHidden = true
        let tagN = SceneLabel(size: 24, color: ScenePaint.ui(pal.candle))
        tagN.set("Relic found!")
        tagN.node.position = CGPoint(x: bp.x, y: bp.y + 82)
        tagN.node.isHidden = true
        let bnameN = SceneLabel(size: 30, color: ScenePaint.ui(pal.gold))
        bnameN.maxWidth = ChestLayout.interior.width - 10
        bnameN.node.position = CGPoint(x: bp.x, y: bp.y - 70)
        bnameN.node.isHidden = true

        var fl: [SKSpriteNode] = []
        for _ in 0..<10 {
            let s = SKSpriteNode()
            s.isHidden = true
            s.zPosition = 5
            fl.append(s)
        }
        var pops: [SceneLabel] = []
        for _ in 0..<5 {
            let l = SceneLabel(size: 28, color: ScenePaint.ui(pal.gold))
            l.node.isHidden = true
            l.node.zPosition = 6
            pops.append(l)
        }
        let fxNodes: [SKNode] = [raysN, artN, tagN.node, bnameN.node, nameN.node, tierN.node, chompN.node]
        for n in fxNodes { fxN.addChild(n) }
        for s in fl { fxN.addChild(s) }
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
        sweep = sweepN
        throat = throatN
        lowerTeeth = lowerN
        chomp = chompN
        titleName = nameN
        titleTier = tierN
        bannerRays = raysN
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

    // MARK: Triggers

    func clear() {
        biteAge = 99
        bankAge = 99
        arriveAge = 99
        titleAge = 99
        torchAge = nil
        exited = false
        flashAge = 99
        shakeAmp = 0
        shake = .zero
        dangerLevel = 0
        flights = []
        relicQueue = []
        bannerAge = 99
        for i in 0..<popupAge.count { popupAge[i] = 99 }
        for s in flyers { s.isHidden = true }
        for l in popups { l.node.isHidden = true }
        for n in [sweep, lowerTeeth, chomp.node, titleName.node, titleTier.node, bannerRays, bannerArt, bannerTag.node,
                  bannerName.node, flash, danger, closeIn, black] as [SKNode] {
            n.isHidden = true
        }
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

    static func multiplierText(_ m: Double) -> String {
        guard m.isFinite, m > 0 else { return "×1" }
        if abs(m - m.rounded()) < 0.001 { return "×\(Int(m.rounded()))" }
        return String(format: "×%.1f", m)
    }

    func arrive(name: String, tier: ChestTier, multiplier: Double) {
        arriveAge = 0
        exited = false
        biteAge = 99
        bankAge = 99
        torchAge = nil
        flights = []
        for s in flyers { s.isHidden = true }
        titleName.set(name)
        titleTier.set("\(SceneMoments.tierName(tier))  \(SceneMoments.multiplierText(multiplier))")
        titleAge = 0
        let bannerLeft = bannerShowing ? SceneMoments.bannerTime - bannerAge : 0
        let queued = Double(relicQueue.count) * SceneMoments.bannerTime
        titleStart = max(0.45, bannerLeft + queued + 0.1)
    }

    func bite() {
        biteAge = 0
        bankAge = 99
    }

    func bank(items: [(kind: LootKind, radius: CGFloat, point: CGPoint)], value: Int, hushed: Bool) {
        bankAge = 0
        biteAge = 99
        flights = []
        for (i, s) in flyers.enumerated() {
            guard i < items.count else {
                s.isHidden = true
                continue
            }
            let it = items[i]
            s.texture = SceneTextures.loot(it.kind, radius: it.radius)
            let side = SceneTextures.lootSide(it.radius)
            s.size = CGSize(width: side, height: side)
            s.position = it.point
            s.setScale(0.8)
            s.isHidden = true
            flights.append(Flyer(from: it.point, delay: 0.12 + Double(i) * 0.07))
        }
        if value > 0 {
            popup("+\(SceneNumber.gold(value))", at: CGPoint(x: 500, y: 388), color: ScenePaint.ui(ChestArt.palette.gold),
                  delay: 0.3, rise: 36)
        }
        if hushed {
            popup("Hushed!", at: CGPoint(x: 170, y: 388),
                  color: ScenePaint.ui(ScenePaint.meterGreen), delay: 0.45, rise: 36)
        }
    }

    func queueRelic(_ id: RelicID) {
        relicQueue.append(id)
    }

    func torchOut() {
        if torchAge == nil { torchAge = 0 }
    }

    func bump(_ amount: CGFloat) {
        guard !reduceMotion else { return }
        shakeAmp = max(shakeAmp, amount)
    }

    /// A short rising label ("+35", "+8s", "New best!").
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

    private static func popScale(_ age: Double) -> CGFloat {
        if age < 0.12 { return CGFloat(0.3 + (1.2 - 0.3) * age / 0.12) }
        if age < 0.24 { return CGFloat(1.2 - 0.2 * (age - 0.12) / 0.12) }
        return 1
    }

    func update(dt: Double, snapshot s: HeistSnapshot, effects: SceneEffects, hud: SceneFloorHUD,
                lid: SceneLid) -> SceneMomentFrame {
        time += dt
        var f = SceneMomentFrame()
        let pal = ChestArt.palette
        let w = ChestLayout.canvas.width

        // Arrival.
        let prevArrive = arriveAge
        arriveAge += dt
        var offset: CGFloat = exited ? SceneMoments.exitOffset : 0
        if arriveAge < 0.8 {
            let a = arriveAge
            if a < 0.5 {
                let t = a / 0.5
                offset = SceneMoments.exitOffset * CGFloat(pow(1 - t, 3))
            } else {
                offset = 7 * CGFloat(sin((a - 0.5) / 0.3 * Double.pi))
            }
            if prevArrive < 0.5 && arriveAge >= 0.5 {
                let dust = UIColor(red: 0.72, green: 0.6, blue: 0.47, alpha: 1)
                effects.dustPuff(from: CGPoint(x: 10, y: 112), to: CGPoint(x: w - 10, y: 112), count: 14, color: dust)
                effects.dustPuff(from: CGPoint(x: 20, y: 130), to: CGPoint(x: 20, y: 420), count: 5, color: dust)
                effects.dustPuff(from: CGPoint(x: w - 20, y: 130), to: CGPoint(x: w - 20, y: 420), count: 5, color: dust)
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
                if !reduceMotion { flashAge = 0 }
                effects.sparkBurst(at: ChestLayout.mouthPoint, count: 10, color: ScenePaint.ui(pal.candle), speed: 260)
                effects.dustPuff(from: CGPoint(x: 60, y: 430), to: CGPoint(x: w - 60, y: 430), count: 10,
                                 color: UIColor(white: 0.6, alpha: 1))
            }
            f.teethOverride = a < 1.0 ? 1 : nil
            f.wakeOverride = a < 0.9 ? 1 : 0.35
            // CHOMP!
            if a >= slam && a < 1.4 {
                chomp.node.isHidden = false
                chomp.node.setScale(SceneMoments.popScale(a - slam))
                chomp.node.alpha = CGFloat(1 - SceneMoments.smooth((a - 1.1) / 0.3))
            } else {
                chomp.node.isHidden = true
            }
            // Hop twice, then leave off the front.
            if a >= 1.1 && a < 1.45 {
                offset = 22 * CGFloat(abs(sin((a - 1.1) / 0.35 * 2 * Double.pi)))
            } else if a >= 1.45 && a < 1.8 {
                let t = (a - 1.45) / 0.35
                offset = SceneMoments.exitOffset * CGFloat(t * t)
            } else if a >= 1.8 {
                exited = true
                offset = SceneMoments.exitOffset
            }
        } else {
            chomp.node.isHidden = true
        }
        f.jawDrop = -96 * jawK
        lowerTeeth.isHidden = jawK < 0.01
        lowerTeeth.yScale = max(jawK, 0.01)
        throat.alpha = 0.85 * jawK

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
            sweep.isHidden = false
            sweep.yScale = CGFloat(max(SceneMoments.smooth(a / 0.35), 0.01))
            sweep.alpha = 0.8
            f.hideBagged = true
            for i in 0..<flights.count where i < flyers.count {
                let fl = flights[i]
                let node = flyers[i]
                let t = (a - fl.delay) / 0.5
                if t < 0 || fl.landed {
                    node.isHidden = true
                    continue
                }
                let k = CGFloat(min(t, 1))
                let to = ChestLayout.counterCoin
                let c = CGPoint(x: (fl.from.x + to.x) / 2, y: max(fl.from.y, to.y) + 130)
                let u = 1 - k
                node.isHidden = false
                node.position = CGPoint(x: u * u * fl.from.x + 2 * u * k * c.x + k * k * to.x,
                                        y: u * u * fl.from.y + 2 * u * k * c.y + k * k * to.y)
                node.setScale(0.8 - 0.4 * k)
                node.zRotation = k * 4
                if t >= 1 {
                    flights[i].landed = true
                    node.isHidden = true
                    effects.sparkBurst(at: to, count: 5, color: ScenePaint.ui(pal.gold), speed: 160, size: 18)
                    hud.popCounter()
                }
            }
            if a >= 1.05 && a < 1.4 {
                let t = (a - 1.05) / 0.35
                offset = SceneMoments.exitOffset * CGFloat(t * t)
            } else if a >= 1.4 {
                exited = true
                offset = SceneMoments.exitOffset
            }
        } else {
            sweep.isHidden = true
            for n in flyers { n.isHidden = true }
        }
        f.chestOffset = offset
        sweep.position = CGPoint(x: w / 2, y: ChestLayout.floorTop + offset)

        // The relic banner (after the bank's sweep has landed).
        bannerAge += dt
        if bannerAge >= SceneMoments.bannerTime, !relicQueue.isEmpty, bankAge >= 0.35 {
            let id = relicQueue.removeFirst()
            let relic = RelicCatalog.all.first(where: { $0.id == id })
            bannerName.set(relic?.name ?? "A relic")
            bannerArt.texture = SceneTextures.loot(.relic(id), radius: 50)
            let side = SceneTextures.lootSide(50)
            bannerArt.size = CGSize(width: side, height: side)
            bannerAge = 0
            effects.sparkBurst(at: ChestLayout.relicBannerPoint, count: 14, color: ScenePaint.ui(pal.gold), speed: 240)
        }
        if bannerAge < SceneMoments.bannerTime {
            let a = bannerAge
            let fade = CGFloat(1 - SceneMoments.smooth((a - 1.5) / 0.4))
            for n in [bannerRays, bannerArt, bannerTag.node, bannerName.node] as [SKNode] {
                n.isHidden = false
                n.alpha = fade
            }
            bannerRays.zRotation = CGFloat(a) * 0.6
            bannerRays.setScale(SceneMoments.popScale(a) * (1 + 0.05 * CGFloat(sin(a * 3))))
            bannerArt.setScale(SceneMoments.popScale(a))
            bannerArt.zRotation = 0.12 * CGFloat(sin(a * 2.4))
            bannerName.node.alpha = fade * CGFloat(SceneMoments.smooth((a - 0.15) / 0.2))
            bannerTag.node.alpha = fade * CGFloat(SceneMoments.smooth(a / 0.2))
        } else {
            for n in [bannerRays, bannerArt, bannerTag.node, bannerName.node] as [SKNode] { n.isHidden = true }
        }

        // The arrival title (after any relic banner).
        titleAge += dt
        let ta = titleAge - titleStart
        if ta >= 0 && ta < 1.6 && !bannerShowing {
            let alpha = CGFloat(SceneMoments.smooth(ta / 0.2) * (1 - SceneMoments.smooth((ta - 1.2) / 0.4)))
            titleName.node.isHidden = false
            titleTier.node.isHidden = false
            titleName.node.alpha = alpha
            titleTier.node.alpha = alpha
            let rise = CGFloat(8 * (1 - SceneMoments.smooth(ta / 0.3)))
            titleName.node.position = CGPoint(x: ChestLayout.titlePoint.x, y: ChestLayout.titlePoint.y + 22 - rise)
            titleTier.node.position = CGPoint(x: ChestLayout.titlePoint.x, y: ChestLayout.titlePoint.y - 20 - rise)
        } else {
            titleName.node.isHidden = true
            titleTier.node.isHidden = true
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

        // Torch out: the dark closes in.
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

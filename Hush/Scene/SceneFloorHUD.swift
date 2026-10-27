import SpriteKit
import UIKit

/// The floor half's HUD (all time-critical, so all on the sharp half): the snore-o-meter on the front rim, the torch
/// gauge (a candle burning down) on the left rim, the in-hand value with the shut-hold ring on the satchel's left, and
/// the gold counter on its right. Positions: `ChestLayout`.
@MainActor
final class SceneFloorHUD {
    let root: SKNode

    // Snore-o-meter.
    private let meter: SKNode
    private let segments: [SKSpriteNode]
    private let segmentColors: [UIColor]
    private let unlitColor: UIColor

    // Torch.
    private let track: SKSpriteNode
    private let dish: SKSpriteNode
    private let wax: SKSpriteNode
    private let flame: SKSpriteNode
    private let flameGlow: SKSpriteNode
    private var lowFlash: Double = 10
    private var flareAge: Double = 10

    // In hand.
    private let clasp: SKSpriteNode
    private let ringTrack: SKShapeNode
    private let ring: SKShapeNode
    private let ringGlow: SKSpriteNode
    private let valueHolder: SKNode
    private let valueLabel: SceneLabel
    private var shownRingStep = -1
    private var lastBagValue = 0
    private var valuePop: Double = 10

    // Banked.
    private let coin: SKSpriteNode
    private let counterHolder: SKNode
    private let counterLabel: SceneLabel
    private var counterPop: Double = 10
    /// The counter as drawn (it rolls up during a bank).
    private(set) var shownBanked: Int = 0
    private var rollFrom: Double = 0
    private var rollTo: Double = 0
    private var rollAge: Double = 10
    private var rollDelay: Double = 0
    private var rollDuration: Double = 0.9
    private var rolling = false

    /// The meter's shake offset now (tests).
    private(set) var meterShake: CGPoint = .zero
    /// The torch fraction drawn (tests).
    private(set) var torchFraction: CGFloat = 1
    private var time: Double = 0

    init() {
        let pal = ChestArt.palette
        let unlit = UIColor(white: 0.1, alpha: 1)

        let meterN = SKNode()
        let m = ChestLayout.meterRect
        meterN.position = CGPoint(x: m.midX, y: m.midY)
        meterN.zPosition = 0
        let plate = SKSpriteNode(texture: SceneTextures.meterPlate, size: m.size)
        plate.zPosition = 0
        meterN.addChild(plate)
        let well = ChestLayout.meterWell
        let count = ChestLayout.meterSegments
        let segW = well.width / CGFloat(count)
        var colors: [UIColor] = []
        var segs: [SKSpriteNode] = []
        let segTex = SceneTextures.segment
        for i in 0..<count {
            let f = (Double(i) + 1) / Double(count)
            let c: RGBA = f <= 0.35 + 1e-9 ? ScenePaint.meterGreen : (f <= 0.70 + 1e-9 ? pal.amber : pal.danger)
            colors.append(ScenePaint.ui(c))
            let s = SKSpriteNode(texture: segTex, size: CGSize(width: segW - 3.5, height: well.height - 4))
            s.position = CGPoint(x: well.minX + segW * (CGFloat(i) + 0.5) - m.midX, y: well.midY - m.midY)
            s.colorBlendFactor = 1
            s.color = unlit
            s.zPosition = 1
            meterN.addChild(s)
            segs.append(s)
        }

        let tr = ChestLayout.torchRect
        let trackN = SKSpriteNode(texture: SceneTextures.torchTrack, size: tr.size)
        trackN.position = CGPoint(x: tr.midX, y: tr.midY)
        trackN.colorBlendFactor = 0
        trackN.color = ScenePaint.ui(pal.danger)
        trackN.zPosition = 0
        let dishN = SKSpriteNode(texture: SceneTextures.candleDish, size: CGSize(width: 44, height: 22))
        dishN.position = CGPoint(x: ChestLayout.candleX, y: ChestLayout.candleBaseY - 4)
        dishN.zPosition = 2
        let waxN = SKSpriteNode(texture: SceneTextures.wax, size: CGSize(width: 24, height: ChestLayout.candleMaxHeight))
        waxN.anchorPoint = CGPoint(x: 0.5, y: 0)
        waxN.position = CGPoint(x: ChestLayout.candleX, y: ChestLayout.candleBaseY)
        waxN.zPosition = 1
        let flameN = SKSpriteNode(texture: SceneTextures.flame, size: CGSize(width: 30, height: 48))
        flameN.anchorPoint = CGPoint(x: 0.5, y: 0.06)
        flameN.blendMode = .add
        flameN.zPosition = 3
        let glowN = SKSpriteNode(texture: SceneTextures.glow, size: CGSize(width: 120, height: 120))
        glowN.blendMode = .add
        glowN.color = ScenePaint.ui(pal.candle)
        glowN.colorBlendFactor = 1
        glowN.alpha = 0.45
        glowN.zPosition = -0.5
        flameN.addChild(glowN)

        let claspN = SKSpriteNode(texture: SceneTextures.clasp, size: CGSize(width: 68, height: 68))
        claspN.position = ChestLayout.claspCenter
        claspN.zPosition = 1
        let trackRing = SKShapeNode(circleOfRadius: ChestLayout.ringRadius)
        trackRing.position = ChestLayout.claspCenter
        trackRing.fillColor = .clear
        trackRing.strokeColor = UIColor(white: 0, alpha: 0.55)
        trackRing.lineWidth = 7
        trackRing.zPosition = 0.5
        let ringN = SKShapeNode()
        ringN.position = ChestLayout.claspCenter
        ringN.fillColor = .clear
        ringN.strokeColor = ScenePaint.ui(pal.gold)
        ringN.lineWidth = 7
        ringN.lineCap = .round
        ringN.zPosition = 2
        let ringGlowN = SKSpriteNode(texture: SceneTextures.glow, size: CGSize(width: 130, height: 130))
        ringGlowN.position = ChestLayout.claspCenter
        ringGlowN.blendMode = .add
        ringGlowN.color = ScenePaint.ui(pal.gold)
        ringGlowN.colorBlendFactor = 1
        ringGlowN.alpha = 0
        ringGlowN.zPosition = -0.5
        let valueH = SKNode()
        valueH.position = CGPoint(x: ChestLayout.bagValueLeft, y: ChestLayout.claspCenter.y)
        valueH.zPosition = 2
        let valueL = SceneLabel(size: 36, color: ScenePaint.ui(pal.text), align: .left)
        valueL.maxWidth = ChestLayout.bagValueRect.maxX - ChestLayout.bagValueLeft - 10
        valueH.addChild(valueL.node)
        valueL.set("0")

        let coinN = SKSpriteNode(texture: SceneTextures.coinStack, size: CGSize(width: 48, height: 48))
        coinN.position = ChestLayout.counterCoin
        coinN.zPosition = 1
        let counterH = SKNode()
        counterH.position = CGPoint(x: ChestLayout.counterRight, y: ChestLayout.counterCoin.y)
        counterH.zPosition = 2
        let counterL = SceneLabel(size: 36, color: ScenePaint.ui(pal.gold), align: .right)
        counterL.maxWidth = ChestLayout.counterRight - ChestLayout.counterRect.minX - 12
        counterH.addChild(counterL.node)
        counterL.set("0")

        let rootN = SKNode()
        let all: [SKNode] = [meterN, trackN, dishN, waxN, claspN, trackRing, ringN, ringGlowN, valueH, coinN, counterH,
                             flameN]
        for node in all { rootN.addChild(node) }

        root = rootN
        meter = meterN
        segments = segs
        segmentColors = colors
        unlitColor = unlit
        track = trackN
        dish = dishN
        wax = waxN
        flame = flameN
        flameGlow = glowN
        clasp = claspN
        ringTrack = trackRing
        ring = ringN
        ringGlow = ringGlowN
        valueHolder = valueH
        valueLabel = valueL
        coin = coinN
        counterHolder = counterH
        counterLabel = counterL
    }

    // MARK: Hooks from the scene's events

    /// The bank: roll the counter up to `to` after `delay` s over `duration` s.
    func roll(to value: Int, delay: Double, duration: Double) {
        rollFrom = Double(shownBanked)
        rollTo = Double(value)
        rollAge = 0
        rollDelay = delay
        rollDuration = max(duration, 0.05)
        rolling = true
    }

    func popCounter() { counterPop = 0 }
    func torchLow() { lowFlash = 0 }
    func flare() { flareAge = 0 }

    /// Jump straight to a value (a new session).
    func snap(banked: Int) {
        rolling = false
        shownBanked = banked
        counterLabel.set(SceneNumber.gold(banked))
    }

    /// Where the candle flame sits now (for smoke and the "+8s").
    var flamePoint: CGPoint { flame.position }

    // MARK: Frame

    func update(dt: Double, snapshot s: HeistSnapshot, light: CGFloat, reduceMotion: Bool) {
        time += dt

        // Snore-o-meter.
        let noise = min(max(s.noise.isFinite ? s.noise : 0, 0), 1)
        let n = segments.count
        let level = noise * Double(n)
        let pulse = 0.75 + 0.25 * sin(time * 9)
        for i in 0..<n {
            let fill = min(max(level - Double(i), 0), 1)
            let seg = segments[i]
            if fill > 0 {
                seg.color = segmentColors[i]
                var a = 0.35 + 0.65 * fill
                if s.stage >= .waking && Double(i + 1) / Double(n) > 0.70 { a *= pulse }
                seg.alpha = CGFloat(a)
            } else {
                seg.color = unlitColor
                seg.alpha = 0.9
            }
        }
        if noise > 0.85 && !reduceMotion {
            let k = CGFloat((noise - 0.85) / 0.15) * 3
            meterShake = CGPoint(x: CGFloat(sin(time * 61)) * k, y: CGFloat(sin(time * 47 + 1)) * k * 0.6)
        } else {
            meterShake = .zero
        }
        let m = ChestLayout.meterRect
        meter.position = CGPoint(x: m.midX + meterShake.x, y: m.midY + meterShake.y)

        // Torch.
        let total = s.torchTotal
        var frac: Double = 1
        if total > 0 { frac = min(max(s.torchRemaining / total, 0), 1) }
        torchFraction = CGFloat(frac)
        wax.yScale = max(CGFloat(frac), 0.02)
        let out = total > 0 && s.torchRemaining <= 0
        let low = total > 0 && !out && s.torchRemaining < 15
        flame.isHidden = out
        let top = ChestLayout.candleBaseY + ChestLayout.candleMaxHeight * CGFloat(frac) - 3
        flame.position = CGPoint(x: ChestLayout.candleX, y: top)
        let fAmp: Double = (low ? 0.22 : 0.06) * (reduceMotion ? 0.5 : 1)
        let f1 = sin(time * 13.0) * sin(time * 5.3 + 0.7)
        let f2 = sin(time * 21.0 + 1.9)
        flareAge += dt
        let flareK = flareAge < 0.6 ? 1 + 0.6 * (1 - flareAge / 0.6) : 1
        flame.yScale = CGFloat((1 + fAmp * f1) * flareK)
        flame.xScale = CGFloat((1 + fAmp * 0.6 * f2) * flareK)
        flame.zRotation = CGFloat(fAmp * 0.6 * f2)
        flameGlow.alpha = 0.45 * light
        lowFlash += dt
        if low {
            let p = 0.5 + 0.5 * sin(time * 6)
            track.colorBlendFactor = CGFloat(0.25 + 0.45 * p)
        } else {
            track.colorBlendFactor = 0
        }
        if lowFlash < 0.8 && !reduceMotion {
            track.colorBlendFactor = max(track.colorBlendFactor, CGFloat(1 - lowFlash / 0.8))
        }

        // In hand + the shut-hold ring.
        let bag = s.bagValue
        if bag != lastBagValue {
            if bag > lastBagValue { valuePop = 0 }
            lastBagValue = bag
        }
        valueLabel.set(SceneNumber.gold(bag))
        valueHolder.alpha = bag > 0 ? 1 : 0.45
        valuePop += dt
        valueHolder.setScale(pop(valuePop))
        ringTrack.alpha = bag > 0 ? 1 : 0.35
        let hold = min(max(s.shutHold.isFinite ? s.shutHold : 0, 0), 1)
        let step = Int((hold * 64).rounded())
        if step != shownRingStep {
            shownRingStep = step
            if step <= 0 {
                ring.path = nil
            } else {
                let p = CGMutablePath()
                let a0 = CGFloat.pi / 2
                p.addArc(center: .zero, radius: ChestLayout.ringRadius, startAngle: a0,
                         endAngle: a0 - 2 * .pi * CGFloat(step) / 64, clockwise: true)
                ring.path = p
            }
        }
        ringGlow.alpha = CGFloat(hold) * 0.7 * (0.8 + 0.2 * CGFloat(sin(time * 10)))
        clasp.setScale(1 + 0.08 * CGFloat(hold))

        // The counter (rolls during a bank; otherwise follows the snapshot).
        if rolling {
            rollAge += dt
            let t = min(max((rollAge - rollDelay) / rollDuration, 0), 1)
            let e = 1 - pow(1 - t, 3)
            shownBanked = Int((rollFrom + (rollTo - rollFrom) * e).rounded())
            if t >= 1 { rolling = false }
        } else if shownBanked != s.banked {
            shownBanked = s.banked
        }
        counterLabel.set(SceneNumber.gold(shownBanked))
        counterPop += dt
        counterHolder.setScale(pop(counterPop))
        coin.setScale(pop(counterPop))

    }

    private func pop(_ age: Double) -> CGFloat {
        guard age < 0.3 else { return 1 }
        return CGFloat(1 + 0.22 * sin(age / 0.3 * Double.pi))
    }
}

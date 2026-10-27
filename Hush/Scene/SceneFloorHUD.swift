import SpriteKit
import UIKit

/// The floor half's HUD (all time-critical, so all on the sharp half). R2, labelled:
/// - the **NOISE** meter on the front rim with the teeth at its full end (`meterRoot`: the scene puts it over
///   everything) and a tick at the bag's jingle floor;
/// - the **candle** on the left rim, with a big "0:12" countdown in the last 15 s;
/// - **IN BAG** (left plate: clasp, shut-hold ring, the value) and **BANKED** (right plate: the gold counter, which
///   rolls during a bank), never swapped;
/// - the leather **pouch** between them, glowing as a drop target while an item is held (its front is drawn over the
///   bagged loot so the loot sits in it);
/// - the **Hush Chain** medallion on the right rim above BANKED ("×1.3"), popping on `chainUp`, cracking on
///   `chainBroken`.
/// Positions: `ChestLayout`.
@MainActor
final class SceneFloorHUD {
    let root: SKNode
    /// The noise meter (the scene parents it above everything else on the floor).
    let meterRoot: SKNode

    // Noise meter.
    private let segments: [SKSpriteNode]
    private let segmentColors: [UIColor]
    private let unlitColor: UIColor
    private let noiseLabel: SceneLabel
    private let floorTick: SKSpriteNode

    // Candle.
    private let track: SKSpriteNode
    private let dish: SKSpriteNode
    private let wax: SKSpriteNode
    private let flame: SKSpriteNode
    private let flameGlow: SKSpriteNode
    private let countdown: SKNode
    private let countdownLabel: SceneLabel
    private var shownSeconds = -1
    private var countdownUrgent = false
    private var lowFlash: Double = 10
    private var flareAge: Double = 10

    // In bag.
    private let clasp: SKSpriteNode
    private let ringTrack: SKShapeNode
    private let ring: SKShapeNode
    private let ringGlow: SKSpriteNode
    private let valueHolder: SKNode
    private let valueLabel: SceneLabel
    private let bagTag: SceneLabel
    private var shownRingStep = -1
    private var lastBagValue = 0
    private var shownBagValue = -1
    private var valuePop: Double = 10
    private var bagTagWarm = false

    // The pouch.
    private let pouchFront: SKSpriteNode
    private let pouchGlow: SKSpriteNode
    private var pouchLevel: CGFloat = 0
    /// How brightly the pouch glows as a drop target now (0 … 1; tests).
    var pouchGlowLevel: CGFloat { pouchLevel }

    // Banked.
    private let coin: SKSpriteNode
    private let counterHolder: SKNode
    private let counterLabel: SceneLabel
    private let bankTag: SceneLabel
    private var counterPop: Double = 10
    /// The counter as drawn (it rolls up during a bank).
    private(set) var shownBanked: Int = 0
    private var labelBanked = -1
    private var rollFrom: Double = 0
    private var rollTo: Double = 0
    private var rollAge: Double = 10
    private var rollDelay: Double = 0
    private var rollDuration: Double = 0.9
    private var rolling = false

    // The Hush Chain.
    private let chainRoot: SKNode
    private let medal: SKSpriteNode
    private let chainValue: SceneLabel
    private let chainCaption: SceneLabel
    private let crack: SKSpriteNode
    private var chainPopAge: Double = 10
    private var crackAge: Double = 10
    private var chainLevel: CGFloat = 0
    private var shownChainTenths = -1
    /// Whether the chain badge is showing (tests).
    var chainShowing: Bool { !chainRoot.isHidden && chainRoot.alpha > 0.05 }
    var chainCracking: Bool { crackAge < 0.8 }

    /// The meter's shake offset now (tests).
    private(set) var meterShake: CGPoint = .zero
    /// The candle fraction drawn (tests).
    private(set) var torchFraction: CGFloat = 1
    /// The countdown showing ("0:12"), or nil.
    private(set) var countdownText: String?
    private var time: Double = 0

    init() {
        let pal = ChestArt.palette
        let unlit = UIColor(white: 0.1, alpha: 1)

        // The noise meter.
        let meterN = SKNode()
        let m = ChestLayout.meterRect
        meterN.position = CGPoint(x: m.midX, y: m.midY)
        let plate = SKSpriteNode(texture: SceneTextures.meterPlate, size: m.size)
        plate.zPosition = 0
        meterN.addChild(plate)
        let noiseL = SceneLabel(size: 15, color: ScenePaint.ui(RGBA(hex: 0x2E1606)), outline: nil, minimumSize: 14,
                                kern: 1.6)
        noiseL.set("NOISE")
        noiseL.node.position = CGPoint(x: ChestLayout.meterLabelCenter.x - m.midX, y: ChestLayout.meterLabelCenter.y - m.midY)
        noiseL.node.zPosition = 2
        meterN.addChild(noiseL.node)
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
        let tick = SKSpriteNode(color: ScenePaint.ui(pal.text), size: CGSize(width: 3, height: well.height + 6))
        tick.alpha = 0.85
        tick.zPosition = 3
        tick.isHidden = true
        meterN.addChild(tick)

        // The candle.
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
        let cdN = SKNode()
        let cr = ChestLayout.countdownRect
        cdN.position = CGPoint(x: cr.midX, y: cr.midY)
        cdN.zPosition = 4
        cdN.isHidden = true
        let pill = SKSpriteNode(texture: SceneTextures.countdownPill, size: cr.size)
        cdN.addChild(pill)
        let cdL = SceneLabel(size: 30, color: ScenePaint.ui(pal.candle))
        cdL.node.zPosition = 1
        cdL.node.position = CGPoint(x: 0, y: 1)
        cdN.addChild(cdL.node)

        // In bag.
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
        valueH.position = CGPoint(x: ChestLayout.bagValueLeft, y: ChestLayout.plateNumberY)
        valueH.zPosition = 2
        let valueL = SceneLabel(size: 34, color: ScenePaint.ui(pal.text), align: .left)
        valueL.maxWidth = ChestLayout.bagValueRect.maxX - ChestLayout.bagValueLeft - 10
        valueH.addChild(valueL.node)
        valueL.set("0")
        let bagT = SceneLabel(size: 15, color: ScenePaint.ui(pal.text, alpha: 0.82), outline: nil, align: .left,
                              minimumSize: 14, kern: 1.8)
        bagT.set("IN BAG")
        bagT.node.position = CGPoint(x: ChestLayout.bagValueLeft + 2, y: ChestLayout.plateLabelY)
        bagT.node.zPosition = 2

        // The pouch.
        let pr = ChestLayout.pouchRect
        let pouchN = SKSpriteNode(texture: SceneTextures.pouchFront, size: pr.size)
        pouchN.position = CGPoint(x: pr.midX, y: pr.midY)
        pouchN.zPosition = -1
        let pGlow = SKSpriteNode(texture: SceneTextures.glow, size: CGSize(width: 260, height: 170))
        pGlow.position = ChestLayout.pouchMouth
        pGlow.blendMode = .add
        pGlow.color = ScenePaint.ui(pal.gold)
        pGlow.colorBlendFactor = 1
        pGlow.alpha = 0
        pGlow.zPosition = -0.5

        // Banked.
        let coinN = SKSpriteNode(texture: SceneTextures.coinStack, size: CGSize(width: 52, height: 52))
        coinN.position = ChestLayout.counterCoin
        coinN.zPosition = 1
        let counterH = SKNode()
        counterH.position = CGPoint(x: ChestLayout.counterRight, y: ChestLayout.plateNumberY)
        counterH.zPosition = 2
        let counterL = SceneLabel(size: 34, color: ScenePaint.ui(pal.gold), align: .right)
        counterL.maxWidth = ChestLayout.counterRight - ChestLayout.counterRect.minX - 12
        counterH.addChild(counterL.node)
        counterL.set("0")
        let bankT = SceneLabel(size: 15, color: ScenePaint.ui(pal.gold), outline: nil, align: .right,
                               minimumSize: 14, kern: 1.8)
        bankT.set("BANKED")
        bankT.node.position = CGPoint(x: ChestLayout.counterRight - 2, y: ChestLayout.plateLabelY)
        bankT.node.zPosition = 2

        // The Hush Chain.
        let chainN = SKNode()
        chainN.position = ChestLayout.chainCenter
        chainN.zPosition = 3
        chainN.isHidden = true
        chainN.alpha = 0
        let medalN = SKSpriteNode(texture: SceneTextures.chainMedallion, size: CGSize(width: 64, height: 64))
        chainN.addChild(medalN)
        let cv = SceneLabel(size: 20, color: ScenePaint.ui(pal.text))
        cv.node.position = CGPoint(x: 0, y: 0)
        cv.node.zPosition = 1
        cv.maxWidth = 40
        chainN.addChild(cv.node)
        let cap = SceneLabel(size: 14, color: ScenePaint.ui(ScenePaint.meterGreen), minimumSize: 14, strokeWidth: -4,
                             kern: 1.4)
        cap.set("CHAIN")
        cap.node.position = CGPoint(x: 0, y: ChestLayout.chainCaptionY - ChestLayout.chainCenter.y)
        cap.node.zPosition = 1
        chainN.addChild(cap.node)
        let crackN = SKSpriteNode(texture: SceneTextures.chainCrack, size: CGSize(width: 64, height: 64))
        crackN.zPosition = 2
        crackN.isHidden = true
        chainN.addChild(crackN)

        let rootN = SKNode()
        let all: [SKNode] = [trackN, dishN, waxN, cdN, claspN, trackRing, ringN, ringGlowN, valueH, bagT.node, pGlow,
                             pouchN, coinN, counterH, bankT.node, chainN, flameN]
        for node in all { rootN.addChild(node) }

        root = rootN
        meterRoot = meterN
        segments = segs
        segmentColors = colors
        unlitColor = unlit
        noiseLabel = noiseL
        floorTick = tick
        track = trackN
        dish = dishN
        wax = waxN
        flame = flameN
        flameGlow = glowN
        countdown = cdN
        countdownLabel = cdL
        clasp = claspN
        ringTrack = trackRing
        ring = ringN
        ringGlow = ringGlowN
        valueHolder = valueH
        valueLabel = valueL
        bagTag = bagT
        pouchFront = pouchN
        pouchGlow = pGlow
        coin = coinN
        counterHolder = counterH
        counterLabel = counterL
        bankTag = bankT
        chainRoot = chainN
        medal = medalN
        chainValue = cv
        chainCaption = cap
        crack = crackN
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
    func chainUp() {
        chainPopAge = 0
        crackAge = 10
    }

    func chainBroken() { crackAge = 0 }

    /// Jump straight to a value (a new session).
    func snap(banked: Int) {
        rolling = false
        shownBanked = banked
        labelBanked = banked
        counterLabel.set(SceneNumber.gold(banked))
        crackAge = 10
        chainPopAge = 10
    }

    /// Where the candle flame sits now (for smoke, "+6s" and "−10s").
    var flamePoint: CGPoint { flame.position }

    /// The countdown's text for the seconds left ("0:12"), or nil above `Tuning.torchLowSeconds`.
    static func countdownText(remaining: Double, total: Double) -> String? {
        guard total > 0, remaining.isFinite, remaining > 0, remaining <= Tuning.torchLowSeconds else { return nil }
        let secs = Int(remaining.rounded(.up))
        return String(format: "%d:%02d", secs / 60, secs % 60)
    }

    // MARK: Frame

    func update(dt: Double, snapshot s: HeistSnapshot, light: CGFloat, reduceMotion: Bool) {
        time += dt
        let pal = ChestArt.palette

        // The noise meter.
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
        let nf = min(max(s.noiseFloor.isFinite ? s.noiseFloor : 0, 0), 1)
        floorTick.isHidden = nf < 0.01
        if nf >= 0.01 {
            let well = ChestLayout.meterWell
            let m = ChestLayout.meterRect
            floorTick.position = CGPoint(x: well.minX + well.width * CGFloat(nf) - m.midX, y: well.midY - m.midY)
        }
        if noise > 0.85 && !reduceMotion {
            let k = CGFloat((noise - 0.85) / 0.15) * 3
            meterShake = CGPoint(x: CGFloat(sin(time * 61)) * k, y: CGFloat(sin(time * 47 + 1)) * k * 0.6)
        } else {
            meterShake = .zero
        }
        let m = ChestLayout.meterRect
        meterRoot.position = CGPoint(x: m.midX + meterShake.x, y: m.midY + meterShake.y)

        // The candle.
        let total = s.torchTotal
        var frac: Double = 1
        if total > 0 { frac = min(max(s.torchRemaining / total, 0), 1) }
        torchFraction = CGFloat(frac)
        wax.yScale = max(CGFloat(frac), 0.02)
        let out = total > 0 && s.torchRemaining <= 0
        let low = total > 0 && !out && s.torchRemaining < Tuning.torchLowSeconds
        flame.isHidden = out
        let top = ChestLayout.candleBaseY + ChestLayout.candleMaxHeight * CGFloat(frac) - 3
        flame.position = CGPoint(x: ChestLayout.candleX, y: top)
        // In the last seconds the flame gutters: bigger flicker, and it dips.
        var fAmp: Double = (low ? 0.24 : 0.06) * (reduceMotion ? 0.5 : 1)
        if low && sin(time * 3.7) > 0.9 { fAmp *= 1.6 }
        let f1 = sin(time * 13.0) * sin(time * 5.3 + 0.7)
        let f2 = sin(time * 21.0 + 1.9)
        flareAge += dt
        let flareK = flareAge < 0.6 ? 1 + 0.6 * (1 - flareAge / 0.6) : 1
        let gutter = low ? 0.82 + 0.18 * (s.torchRemaining / Tuning.torchLowSeconds) : 1
        flame.yScale = CGFloat((1 + fAmp * f1) * flareK * gutter)
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
        // The countdown (the text is rebuilt only when the second changes).
        let ended: Bool
        switch s.phase {
        case .finished, .torchOut: ended = true
        default: ended = false
        }
        let secs = ended || !low ? -1 : Int(s.torchRemaining.rounded(.up))
        if secs != shownSeconds {
            shownSeconds = secs
            countdownText = secs < 0 ? nil : SceneFloorHUD.countdownText(remaining: Double(secs), total: max(total, 1))
            if let t = countdownText { countdownLabel.set(t) }
        }
        countdown.isHidden = countdownText == nil
        if countdownText != nil {
            let urgent = s.torchRemaining <= 5
            let beat = reduceMotion ? 0 : CGFloat(max(0, sin(time * (urgent ? 12.6 : 6.3))))
            if urgent != countdownUrgent {
                countdownUrgent = urgent
                countdownLabel.setColor(ScenePaint.ui(urgent ? pal.danger : pal.candle))
            }
            countdown.setScale(1 + (urgent ? 0.08 : 0.04) * beat)
        }

        // In bag + the shut-hold ring.
        let bag = s.bagValue
        if bag != lastBagValue {
            if bag > lastBagValue { valuePop = 0 }
            lastBagValue = bag
        }
        if bag != shownBagValue {
            shownBagValue = bag
            valueLabel.set(SceneNumber.gold(bag))
        }
        valueHolder.alpha = bag > 0 ? 1 : 0.45
        valuePop += dt
        valueHolder.setScale(pop(valuePop))
        // The label warms to amber while the loot in the bag is at risk (it's awake-ish).
        let warm = bag > 0 && s.stage >= .stirring
        if warm != bagTagWarm {
            bagTagWarm = warm
            bagTag.setColor(warm ? ScenePaint.ui(pal.amber) : ScenePaint.ui(pal.text, alpha: 0.82))
        }
        bagTag.node.alpha = warm && !reduceMotion ? CGFloat(0.7 + 0.3 * sin(time * 8)) : 1
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

        // The pouch glows while something is held (brighter when it's over the bag).
        var held = false
        var over = false
        for st in s.loot {
            if case .held = st.place {
                held = true
                if st.position.y >= FloorSpace.bagMinY - 10 { over = true }
            }
        }
        let pTarget: CGFloat = over ? 1 : (held ? 0.6 : 0)
        pouchLevel += (pTarget - pouchLevel) * CGFloat(min(dt * 10, 1))
        let pPulse: CGFloat = reduceMotion ? 1 : 0.82 + 0.18 * CGFloat(sin(time * 7))
        pouchGlow.alpha = pouchLevel * 0.75 * pPulse
        pouchGlow.setScale(1 + 0.06 * pouchLevel)
        pouchFront.setScale(1 + 0.03 * pouchLevel)

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
        if shownBanked != labelBanked {
            labelBanked = shownBanked
            counterLabel.set(SceneNumber.gold(shownBanked))
        }
        counterPop += dt
        counterHolder.setScale(pop(counterPop))
        coin.setScale(pop(counterPop))

        // The Hush Chain medallion.
        let active = s.chain >= 1 && s.chainMultiplier.isFinite && s.chainMultiplier > 1.001
        if active {
            let tenths = Int((s.chainMultiplier * 10).rounded())
            if tenths != shownChainTenths {
                shownChainTenths = tenths
                chainValue.set("×\(tenths / 10).\(tenths % 10)")
            }
        }
        chainPopAge += dt
        crackAge += dt
        let cracking = crackAge < 0.8
        let cTarget: CGFloat = active || cracking ? 1 : 0
        chainLevel += (cTarget - chainLevel) * CGFloat(min(dt * 8, 1))
        var alpha = chainLevel
        crack.isHidden = !cracking
        var shakeX: CGFloat = 0
        if cracking {
            let a = crackAge
            alpha = CGFloat(1 - SceneFloorHUD.smooth((a - 0.35) / 0.45))
            if !reduceMotion { shakeX = CGFloat(sin(a * 70) * 4 * max(0, 1 - a / 0.4)) }
            crack.alpha = 1
            // Follow the fade, so it doesn't flash back when the crack ends.
            if !active { chainLevel = alpha }
        }
        chainRoot.alpha = alpha
        chainRoot.isHidden = alpha < 0.01
        chainRoot.position = CGPoint(x: ChestLayout.chainCenter.x + shakeX, y: ChestLayout.chainCenter.y)
        let popK: CGFloat = chainPopAge < 0.35 ? 1 + 0.35 * CGFloat(sin(chainPopAge / 0.35 * Double.pi)) : 1
        medal.setScale(popK)
        chainValue.node.setScale(popK)
        _ = chainCaption
        _ = noiseLabel
    }

    private static func smooth(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }

    private func pop(_ age: Double) -> CGFloat {
        guard age < 0.3 else { return 1 }
        return CGFloat(1 + 0.22 * sin(age / 0.3 * Double.pi))
    }
}

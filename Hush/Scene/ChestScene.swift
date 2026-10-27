import Foundation
import QuartzCore
import SpriteKit
import UIKit

/// The SpriteKit view of the heist (ARCHITECTURE "Scene API"). It draws only from `driver.advance` snapshots and
/// events and owns the cosmetic state (glints, coin bursts, the bite slam, dust, the shake). It never changes game
/// state; it forwards touches to the driver.
///
/// Composition (R2). The scene is `layout.size` (670 wide, ≥ 952 tall). Everything lives under one **`world`** node
/// whose own coordinates ARE the 670 × 952 canvas (origin bottom-left, y up; positions in `ChestLayout`); the canvas
/// sits `layout.contentOffsetY` above the scene's bottom, and the extension art fills the rest (the lid continues
/// above y 952; the chest's front wall, its lock and the tabletop lie below y 0). `turned` rotates `world` by π about
/// the scene centre; every touch is read with `touch.location(in: world)`, so it is right by construction.
/// - world
///   - shaker (shaken):
///     - the lid half (`SceneLid`, z 0, at y 496): planks, the eye, brow, plate, the jaw (z 50 inside it);
///     - the hinge strip (z 5, y 456…496);
///     - the floor half (`SceneFloor`, z 0): the satchel; the chest (R3: hops, never leaves) with the front wall, bed, tongue,
///       darkness, wash; then the loot (z 25), the moments' floor layer (z 27), the HUD (z 30);
///     - FX: particles (z 55), the moments' callouts, banners, flyers, popups (z 60);
///     - the NOISE meter (z 90: on top of everything).
///   - overlay (z 100, never shaken): the red flash, the Waking pulse, candle-out darkness.
///
/// **Clocks.** FX run on the session's clock (snapshot time), so a pause freezes them; when the session stops
/// stepping (a pause, a CI freeze) they run on for `stallWindow` s of wall time so a moment reaches its peak.
@MainActor
final class ChestScene: SKScene {
    weak var driver: SceneDriver?

    /// Reduce Motion: no shakes, no red flash, gentler tongue twitches and candle flicker.
    var reduceMotion: Bool = false {
        didSet {
            fx.reduceMotion = reduceMotion
            moments.reduceMotion = reduceMotion
        }
    }

    var layout: ScreenLayout {
        didSet {
            if layout != oldValue { applyLayout() }
        }
    }

    /// R2: turned round (the blurred-half rule, GAME-DESIGN §3): the whole world is rotated by π about the scene
    /// centre. Touches stay right (they are read in `world`).
    var turned: Bool = false {
        didSet {
            if turned != oldValue { placeWorld() }
        }
    }

    /// FX keep running this long (wall time) after the session stops stepping.
    static let stallWindow: Double = 0.4

    // MARK: Read-outs (tests, the App)

    /// Frames drawn since the scene was made.
    private(set) var drawnFrames = 0
    /// The snapshot drawn last.
    private(set) var snapshot = HeistSnapshot()
    /// The shake offset applied this frame (zero under Reduce Motion).
    var shakeOffset: CGPoint { shaker.position }
    /// The eye's openness (0…1) and the fangs (0…1) as drawn.
    var eyeWake: Double { lid.wake }
    var teethShown: CGFloat { lid.teethShown }
    var browTilt: CGFloat { lid.browTilt }
    /// The gold counter as drawn (it rolls during a bank).
    var shownBanked: Int { hud.shownBanked }
    /// The chest's hop this frame (R3: 0 … 8 pt; the chest never slides away).
    var chestOffset: CGFloat { floor.chestRoot.position.y }
    /// R3: how dark the interior's shutter is (1 = between chests: the lid's shadow over the interior only).
    var interiorShut: CGFloat { moments.shutLevel }
    /// R3 (juror P0-1): the chest's frame, front wall and lock are whole and at full alpha.
    var chestShellIsWhole: Bool { floor.shellIsWhole }
    /// R3: the slam callout ("CREAK!") and the meter's red flash.
    var creakShowing: Bool { moments.creakShowing }
    var creakCount: Int { moments.creakCount }
    var meterFlash: CGFloat { hud.meterFlashLevel }
    /// R3: the chain tab's words (R5: "CHAIN ×1.2"), the bank stack's third line, the relic card fully up.
    var chainTabText: String { hud.chainValueText }
    var bankSubline: String { moments.bankSubText }
    var relicCardFullyShown: Bool { moments.relicCardFullyShown }
    /// R3: the name plate's multiplier seal ("×1.5"; nil at ×1) and the tongue groove (0 when dim).
    var plateSeal: String? { lid.sealText }
    var tongueCrease: CGFloat { floor.creaseAlpha }
    /// R3 (decision 3): "not safe yet" under IN BAG while it holds loot (the App may turn it off after the first runs).
    var showsBagSublabel: Bool {
        get { hud.showsBagSublabel }
        set { hud.showsBagSublabel = newValue }
    }
    var bagSublabelShowing: Bool { hud.bagSublabelShowing }
    /// R3: the lever is drawn (never on a fold layout, decision 4; R4: turned or not).
    var leverShowing: Bool { ChestScene.showsLever(hasFold: layout.hasFold, usesSlider: usesSlider) }

    /// R4 (founder, CI frame 32): the ONE rule for the lever: only without a fold, and only when the driver uses the
    /// slider. `turned` plays no part.
    static func showsLever(hasFold: Bool, usesSlider: Bool) -> Bool { !hasFold && usesSlider }
    /// Items drawn this frame, and relics glimmering.
    var visibleLoot: Int { lootView.visibleCount }
    var glimmeringRelics: Int { lootView.glimmerCount }
    /// The tongue's curl (0…1) and the interior darkness.
    var tongueCurl: CGFloat { floor.curlLevel }
    var interiorDarkness: CGFloat { floor.darknessAlpha }
    var torchFraction: CGFloat { hud.torchFraction }
    var candleCountdown: String? { hud.countdownText }
    var pouchGlow: CGFloat { hud.pouchGlowLevel }
    var chainBadgeShowing: Bool { hud.chainShowing }
    var chainCracking: Bool { hud.chainCracking }
    var torchOutLevel: CGFloat { moments.torchOutLevel }
    var biteActive: Bool { moments.biteActive }
    var biteCalloutShowing: Bool { moments.biteCalloutShowing }
    var biteLossText: String { moments.biteLossText }
    var bankActive: Bool { moments.bankActive }
    var relicBannerShowing: Bool { moments.bannerShowing }
    var floorTier: ChestTier { floor.tier }
    var dress: ChestDress { floor.dress }
    var mimicName: String { lid.name }
    var plateSubline: String { lid.subline }
    var eyeRebuilds: Int { lid.eyeRebuilds }
    /// The extension drawn above the lid and below the floor (pt).
    var extensionTop: CGFloat { lid.topExtension }
    var extensionBottom: CGFloat { floor.bottomExtension }
    /// Every node under the scene (budget: ≈ 150 typical).
    var nodeCount: Int { countNodes(self) }
    /// Nodes actually drawn this frame (not hidden, not transparent).
    var drawnNodeCount: Int { countNodes(self, visibleOnly: true) }
    /// The node whose coordinates are the canvas (tests convert through it).
    var worldNode: SKNode { world }

    /// The App's hint band and pause coin area (canvas points, y up).
    static var hintBandRect: CGRect { ChestLayout.hintBand }
    static var pauseButtonRect: CGRect { ChestLayout.pauseArea }

    // MARK: R4 read-outs

    /// View points per canvas point (from the SKView; tests may set it). The pause seat follows it.
    var viewScale: CGFloat {
        get { hud.viewScale }
        set { hud.viewScale = newValue }
    }
    /// The pause coin's brass seat as drawn (canvas).
    var pauseSeatRect: CGRect { hud.seatRect }
    /// The meter's stage word ("NOISE" / "STIRRING" / "WAKING!") and its drawn width.
    var meterWord: String { hud.meterWordText }
    var meterWordWidth: CGFloat { hud.meterWordWidth }
    /// The chain tab's line's drawn width (R5: one line, "CHAIN ×1.2").
    var chainTextWidths: [CGFloat] { hud.chainTextWidths }

    // MARK: R5 read-outs

    /// The chain tab's type size as drawn (canvas pt).
    var chainDrawnFontSize: CGFloat { hud.chainDrawnFontSize }
    /// The "IN BAG" and "BANKED" labels as drawn (canvas).
    var plateLabelFrames: [CGRect] { hud.plateLabelFrames }
    /// The pause seat's alpha (0.3 during the bite).
    var pauseSeatAlpha: CGFloat { hud.seatAlpha }
    /// Every bank flyer drawn this frame is clear of the plates' labels (it fades out before it reaches them).
    var flyersClearOfLabels: Bool { moments.flyersClearOfLabels }
    /// The bank flyers drawn (alpha > 0.01) this frame.
    var visibleFlyers: Int { moments.visibleFlyers }
    /// The first held item's alpha (it fades as it nears a plate's label; nil when nothing is held).
    var heldItemAlpha: CGFloat? { lootView.heldAlpha }
    /// The bank stack's chain line is drawn (never in the First Chest lesson).
    var bankSublineShowing: Bool { moments.bankSubShowing }
    /// "Next chest…" in the dimmed interior between chests (the App hides its hint while `bankActive || nextChestShowing`).
    var nextChestShowing: Bool { moments.nextChestShowing }
    /// How much of the interior's light the between-chests shadow lets through (1 = none of it: open).
    var interiorLight: CGFloat { moments.interiorLight }
    /// The carved plaque above the lid on phones ("Iron-bound · Chest 4").
    var plaqueText: String { lid.plaqueText }
    var plaqueShowing: Bool { lid.plaqueShowing }
    /// The last golden "×n" popped over a revealed item ("" before any).
    private(set) var lastGoldenPop = ""

    private let world: SKNode
    private let shaker: SKNode
    private let overlay: SKNode
    private let lid: SceneLid
    private let hinge: SKSpriteNode
    private let floor: SceneFloor
    private let lootView: SceneLootView
    private let hud: SceneFloorHUD
    private let fx: SceneEffects
    private let moments: SceneMoments

    private var hasSnapshot = false
    private var lastUpdate: TimeInterval?
    private var stall: Double = 0
    private var animTime: Double = 0
    private var usesSlider = false
    /// Which half each live touch began on (true = floor).
    private var touchHalves: [Int: Bool] = [:]
    private var floorTouchPoints: [Int: CGPoint] = [:]
    private var moteClock: Double = 0
    private var lastDressed: ChestSpec?

    init(layout: ScreenLayout) {
        let worldN = SKNode()
        let shakerN = SKNode()
        let overlayN = SKNode()
        let lidV = SceneLid()
        let hingeN = SKSpriteNode(texture: SceneTextures.hinge,
                                  size: CGSize(width: ChestLayout.canvas.width,
                                               height: ChestLayout.lidBottom - ChestLayout.floorTop))
        let floorV = SceneFloor()
        let lootV = SceneLootView()
        let hudV = SceneFloorHUD()
        let fxV = SceneEffects()
        let momentsV = SceneMoments()
        self.layout = layout
        world = worldN
        shaker = shakerN
        overlay = overlayN
        lid = lidV
        hinge = hingeN
        floor = floorV
        lootView = lootV
        hud = hudV
        fx = fxV
        moments = momentsV
        super.init(size: layout.size)
        setUp()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("ChestScene is created in code with init(layout:)")
    }

    private func setUp() {
        scaleMode = .aspectFill
        anchorPoint = .zero
        backgroundColor = ScenePaint.ui(ChestArt.palette.dungeonDeep)

        world.zPosition = 0
        addChild(world)
        shaker.zPosition = 0
        world.addChild(shaker)
        overlay.zPosition = 100
        world.addChild(overlay)

        lid.root.zPosition = 0
        shaker.addChild(lid.root)
        hinge.position = CGPoint(x: ChestLayout.canvas.width / 2, y: (ChestLayout.floorTop + ChestLayout.lidBottom) / 2)
        hinge.zPosition = 5
        shaker.addChild(hinge)
        floor.root.zPosition = 0
        shaker.addChild(floor.root)
        lootView.root.zPosition = 25
        floor.root.addChild(lootView.root)
        floor.root.addChild(moments.floorRoot)
        hud.root.zPosition = 30
        floor.root.addChild(hud.root)
        fx.root.zPosition = 55
        shaker.addChild(fx.root)
        shaker.addChild(moments.fxRoot)
        hud.meterRoot.zPosition = 90
        shaker.addChild(hud.meterRoot)
        overlay.addChild(moments.overlayRoot)

        // Warm every dress's big textures now (not mid-run).
        for d in ChestDress.all {
            _ = SceneTextures.chestFrame(d)
            _ = SceneTextures.lid(d)
            _ = SceneTextures.lidCap(d)
            _ = SceneTextures.lidTile(d)
            _ = SceneTextures.frontWall(d)
            _ = SceneTextures.browKnob(d)
        }
        _ = SceneTextures.plateGolden
        _ = SceneTextures.plateSeal(golden: true)
        applyLayout()
    }

    private func applyLayout() {
        if size != layout.size { size = layout.size }
        lid.applyExtension(top: ChestLayout.topExtension(layout))
        floor.applyExtension(bottom: ChestLayout.bottomExtension(layout))
        moments.applyExtension(top: ChestLayout.topExtension(layout), bottom: ChestLayout.bottomExtension(layout))
        placeWorld()
    }

    /// The world's transform: canvas → scene. Unturned the canvas sits `contentOffsetY` up; turned it is rotated by π
    /// about the scene centre.
    private func placeWorld() {
        let off = layout.contentOffsetY
        if turned {
            world.zRotation = .pi
            world.position = CGPoint(x: size.width, y: size.height - off)
        } else {
            world.zRotation = 0
            world.position = CGPoint(x: 0, y: off)
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        placeWorld()
        syncViewScale()
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        view.isMultipleTouchEnabled = true
        syncViewScale()
    }

    /// A new session: clear every effect and moment.
    func reset() {
        moments.clear()
        fx.clear()
        lootView.clearAll()
        lid.reset()
        floor.reset()
        hud.snap(banked: 0)
        shaker.position = .zero
        lootView.root.position = .zero
        // Live touches are kept, so their ends still reach the driver (nothing stays "held").
        hasSnapshot = false
        stall = 0
    }

    // MARK: Frame loop

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        var dt: Double = 1.0 / 120.0
        if let last = lastUpdate { dt = min(max(currentTime - last, 0), 1.0 / 30.0) }
        lastUpdate = currentTime
        drawnFrames += 1
        // (Cheap: a compare; the seat only moves when the scale really changes.)
        syncViewScale()

        var events: [HeistEvent] = []
        var fxDt = dt
        if let d = driver {
            let out = d.advance(dt: dt, now: CACurrentMediaTime())
            // Decision 4: a fold layout never draws or uses the lever (R4: re-checked against the CURRENT layout at
            // every draw and touch too, whatever `turned` is).
            usesSlider = ChestScene.showsLever(hasFold: layout.hasFold, usesSlider: d.usesSlider)
            var simDt: Double = 0
            if hasSnapshot {
                if out.0.time + 0.25 < snapshot.time {
                    // The clock went backwards: a new session the App didn't announce.
                    reset()
                } else {
                    simDt = min(max(out.0.time - snapshot.time, 0), 1.0 / 30.0)
                }
            }
            snapshot = out.0
            hasSnapshot = true
            events = out.1
            if simDt > 0 {
                stall = 0
                fxDt = simDt
            } else {
                stall += dt
                fxDt = stall <= ChestScene.stallWindow ? dt : 0
            }
        }
        render(dt: fxDt, events: events)
    }

    /// Draws one frame from `snapshot` and `events` with `dt` seconds of FX time (tests call it directly).
    func render(dt: Double, events: [HeistEvent]) {
        animTime += dt
        let s = snapshot
        handle(events, snapshot: s)

        // Keep the chest's dress and plate in step with the snapshot even without an arrival event.
        if let c = s.chest { dressChest(c, animated: false) }

        let light = torchLight(s)
        let mf = moments.update(dt: dt, snapshot: s, effects: fx, hud: hud, lid: lid)
        if moments.slammedThisFrame { lid.squash() }
        floor.chestRoot.position = CGPoint(x: 0, y: mf.chestOffset)
        lootView.root.position = CGPoint(x: 0, y: mf.chestOffset)
        lid.jaw.position = CGPoint(x: 0, y: mf.jawDrop)
        floor.update(dt: dt, snapshot: s, light: light, reduceMotion: reduceMotion, cover: mf.interiorCover)
        lootView.update(dt: dt, loot: s.loot, hideBagged: mf.hideBagged, light: light, openness: s.openness)
        hud.update(dt: dt, snapshot: s, light: light, reduceMotion: reduceMotion)
        hud.dimSeat(moments.biteActive, dt: dt)
        lid.update(dt: dt, snapshot: s, light: light, wakeOverride: mf.wakeOverride, teethOverride: mf.teethOverride,
                   lookAt: lookTarget(), usesSlider: leverShowing, reduceMotion: reduceMotion)
        fx.update(CGFloat(dt))
        shaker.position = reduceMotion ? .zero : moments.shake

        // Ambience: a few motes drift in the light once the lid is open.
        moteClock += dt
        if s.openness > 0.25 && moteClock > 0.35 {
            moteClock = 0
            let r = ChestLayout.interior
            fx.mote(in: CGRect(x: r.minX, y: r.maxY - r.height * CGFloat(s.openness), width: r.width,
                               height: r.height * CGFloat(s.openness)),
                    color: ScenePaint.ui(ChestArt.palette.candle))
        }
    }

    /// Dress the floor and lid for a chest (tier or golden) and fill the name plate.
    private func dressChest(_ c: ChestSpec, animated: Bool) {
        // Cheap when nothing changed (the snapshot shares the chest's storage frame to frame).
        if let last = lastDressed, last == c { return }
        lastDressed = c
        let d = ChestDress.of(tier: c.tier, golden: c.golden)
        floor.setDress(d, tier: c.tier, animated: animated)
        lid.setDress(d, tier: c.tier, animated: animated)
        lid.setPlate(name: c.mimicName, subline: ChestCopy.plateSubline(c), seal: ChestCopy.plateSeal(c),
                     golden: c.golden)
        lid.setPlaque(ChestCopy.extensionPlaque(c))
    }

    /// R4: view points per canvas point, the App's `CanvasFit.scale` rule (aspect-fill in portrait, aspect-fit in
    /// landscape). 1 without a view (tests set it).
    static func scaleFor(view: CGSize, scene: CGSize) -> CGFloat {
        guard view.width > 0, view.height > 0, scene.width > 0, scene.height > 0 else { return 1 }
        let sx = view.width / scene.width, sy = view.height / scene.height
        return view.width > view.height ? min(sx, sy) : max(sx, sy)
    }

    private func syncViewScale() {
        guard let v = view else { return }
        hud.viewScale = ChestScene.scaleFor(view: v.bounds.size, scene: size)
    }

    /// The candle's flicker on the light (1 steady; lower is dimmer). It gutters in the last 15 s.
    private func torchLight(_ s: HeistSnapshot) -> CGFloat {
        let t = animTime
        let low = s.torchTotal > 0 && s.torchRemaining > 0 && s.torchRemaining < Tuning.torchLowSeconds
        var amp: Double = low ? 0.28 : 0.05
        if reduceMotion { amp *= 0.4 }
        let n = 0.5 + 0.5 * sin(t * 17.0) * sin(t * 6.1 + 1.3)
        var k = 1 - amp * n
        if low && sin(t * 3.7) > 0.93 { k -= amp }
        return CGFloat(max(k, 0.4))
    }

    /// R3: a slam that didn't bite: "CREAK!" jolts in under the hint band, the meter flashes red and shakes, the lid
    /// twitches, the canvas bumps (no shake under Reduce Motion; the meter's flash still shows). The App calls this
    /// from Feel's `FeedbackDirector.onCreakAccent` (noise up > 0.25 in 0.3 s with the lid moving > 30°/s or a fast
    /// drag, never on a bite frame). The scene has no noise rule of its own (the lesson's scripted stir jumps the
    /// noise with the lid still, and must not creak). Ignored during a bite.
    func showCreak() {
        guard !moments.biteActive else { return }
        moments.creak()
        hud.creak()
        lid.twitch()
    }

    private func lookTarget() -> CGPoint? {
        if let p = floorTouchPoints.values.first { return p }
        return lootView.heldPoint
    }

    // MARK: Events

    private func handle(_ events: [HeistEvent], snapshot s: HeistSnapshot) {
        let pal = ChestArt.palette
        for e in events {
            switch e {
            case .chestArrived(_, let tier, _, let name):
                lootView.clearAll()
                if let c = s.chest {
                    // The plate is re-dressed from the snapshot's chest (trait, tier, golden).
                    lastDressed = nil
                    dressChest(c, animated: true)
                } else {
                    floor.setTier(tier, animated: true)
                    lid.setTier(tier, animated: true)
                    lid.setName(name)
                }
                moments.arrive()
            case .lidCracked:
                let r = ChestLayout.interior
                fx.dustPuff(from: CGPoint(x: r.minX + 20, y: r.maxY - 6), to: CGPoint(x: r.maxX - 20, y: r.maxY - 6),
                            count: 6, color: ScenePaint.ui(pal.candle), size: 30)
            case .itemRevealed(let id, let kind):
                lootView.revealed(id)
                if let p = point(of: id, in: s) {
                    var big = false
                    if case .relic = kind { big = true }
                    if case .gem = kind { big = true }
                    fx.sparkBurst(at: p, count: big ? 10 : 4, color: ScenePaint.ui(big ? pal.gold : pal.candle),
                                  speed: big ? 200 : 120, size: big ? 26 : 18)
                    // The golden mimic. R4 (UX P2-3): the pop is the chest's real total, the seal's own number.
                    if let c = s.chest, c.golden, kind != .oil {
                        let text = ChestCopy.goldenPop(c)
                        lastGoldenPop = text
                        // (Kept under the App's hint band at the back edge.)
                        // R5: 372 → 356, so it also stays under a hint plate kept 20 pt clear of the fold.
                        moments.popup(text, at: CGPoint(x: p.x, y: min(p.y + 30, 356)), color: ScenePaint.ui(pal.gold),
                                      rise: 14)
                    }
                }
            case .itemPicked(let id, _):
                lootView.bounce(id)
            case .itemDropped(let id):
                lootView.bounce(id)
                if let p = point(of: id, in: s) {
                    fx.dustPuff(from: CGPoint(x: p.x - 14, y: p.y - 8), to: CGPoint(x: p.x + 14, y: p.y - 8), count: 4,
                                color: UIColor(white: 0.55, alpha: 1), size: 26)
                }
            case .itemBagged(let id, _, let value):
                lootView.bounce(id)
                fx.sparkBurst(at: ChestLayout.pouchMouth, count: 5, color: ScenePaint.ui(pal.gold), speed: 140, size: 18)
                if value > 0 {
                    // Beside the IN BAG number (under the meter's row, clear of the hint band).
                    moments.popup("+\(SceneNumber.gold(value))",
                                  at: CGPoint(x: ChestLayout.bagValueRect.maxX - 30, y: ChestLayout.plateNumberY + 8),
                                  color: ScenePaint.ui(pal.gold), rise: 22)
                }
            case .oilAdded(let seconds):
                hud.flare()
                let fp = hud.flamePoint
                moments.popup("+\(Int(seconds.rounded()))s", at: CGPoint(x: fp.x + 56, y: min(fp.y + 20, 330)),
                              color: ScenePaint.ui(pal.amber), rise: 40)
                fx.sparkBurst(at: fp, count: 6, color: ScenePaint.ui(pal.amber), speed: 120, size: 18)
            case .stageChanged:
                break
            case .dreamTwitch:
                lid.twitch()
            case .bitten(let lostValue):
                moments.bite(lostValue: lostValue)
            case .biteCost(let lostValue, let seconds):
                moments.biteCost(lostValue: lostValue, seconds: seconds, candle: hud.flamePoint)
            case .banked(let value, _, let hushed):
                moments.bank(items: lootView.bagged(), value: value, hushed: hushed)
                // R4 (testers 7 and 8: "+119 next to 115"): the counter has finished rolling by the time the stack
                // is fully up (0.7 s), so a still frame never shows two different numbers for long.
                hud.roll(to: s.banked, delay: 0.15, duration: 0.55)
            case .chainUp(_, let multiplier):
                hud.chainUp(multiplier: multiplier)
                moments.chainUp(multiplier: multiplier)
                fx.sparkBurst(at: ChestLayout.chainCenter, count: 8, color: ScenePaint.ui(pal.gold), speed: 150,
                              size: 18)
            case .chainBroken:
                hud.chainBroken()
            case .relicFound(let id):
                moments.queueRelic(id)
            case .torchLow:
                hud.torchLow()
                fx.smoke(at: hud.flamePoint, count: 3)
            case .torchOut:
                moments.torchOut()
                fx.smoke(at: hud.flamePoint, count: 6)
            case .newBest:
                moments.popup("New best!", at: CGPoint(x: 500, y: 156), color: ScenePaint.ui(pal.candle), rise: 18)
                fx.sparkBurst(at: ChestLayout.counterCoin, count: 10, color: ScenePaint.ui(pal.gold), speed: 200)
            case .finished:
                break
            }
        }
    }

    /// An item's canvas point: as drawn, else from the snapshot.
    private func point(of id: Int, in s: HeistSnapshot) -> CGPoint? {
        if let p = lootView.canvasPoint(id) { return p }
        guard let st = s.loot.first(where: { $0.id == id }) else { return nil }
        let p = ChestLayout.canvas(fromFloor: st.position)
        return CGPoint(x: p.x, y: p.y + floor.chestRoot.position.y)
    }

    private func countNodes(_ n: SKNode, visibleOnly: Bool = false) -> Int {
        if visibleOnly && (n.isHidden || n.alpha <= 0.001) { return 0 }
        var c = 1
        for k in n.children { c += countNodes(k, visibleOnly: visibleOnly) }
        return c
    }

    // MARK: Touches (read in `world`, i.e. canvas coordinates, so turning round needs nothing more)

    /// A scene point (e.g. a touch's `location(in: scene)`) in canvas coordinates.
    func canvasPoint(fromScene p: CGPoint) -> CGPoint { world.convert(p, from: self) }

    /// A canvas point where it is drawn in the scene.
    func scenePoint(fromCanvas p: CGPoint) -> CGPoint { convert(p, from: world) }

    /// The floor-space point a touch at canvas `p` reports (the extension below the floor counts as the bag).
    func floorPoint(forCanvas p: CGPoint) -> CGPoint { ChestLayout.floorTouchPoint(fromCanvas: p) }

    private func sliderFraction(_ p: CGPoint) -> Double {
        ChestLayout.lidFraction(canvasY: p.y, topExtension: ChestLayout.topExtension(layout))
    }

    /// One touch beginning at canvas point `p` (UITouch path and tests).
    func beginTouch(_ id: Int, canvas p: CGPoint, time: TimeInterval) {
        guard let d = driver else { return }
        let lever = ChestScene.showsLever(hasFold: layout.hasFold, usesSlider: d.usesSlider)
        if ChestLayout.startsOnFloor(p) {
            touchHalves[id] = true
            floorTouchPoints[id] = p
            d.floorTouchBegan(id, at: floorPoint(forCanvas: p), time: time)
        } else if lever {
            touchHalves[id] = false
            d.sliderTouch(began: true, ended: false, fraction: sliderFraction(p), time: time)
        }
    }

    func moveTouch(_ id: Int, canvas p: CGPoint, time: TimeInterval) {
        guard let d = driver, let onFloor = touchHalves[id] else { return }
        if onFloor {
            floorTouchPoints[id] = p
            d.floorTouchMoved(id, to: floorPoint(forCanvas: p), time: time)
        } else {
            d.sliderTouch(began: false, ended: false, fraction: sliderFraction(p), time: time)
        }
    }

    func endTouch(_ id: Int, canvas p: CGPoint, time: TimeInterval) {
        guard let onFloor = touchHalves.removeValue(forKey: id) else { return }
        let d = driver
        if onFloor {
            floorTouchPoints[id] = nil
            d?.floorTouchEnded(id, at: floorPoint(forCanvas: p), time: time)
        } else {
            d?.sliderTouch(began: false, ended: true, fraction: sliderFraction(p), time: time)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { beginTouch(ObjectIdentifier(t).hashValue, canvas: t.location(in: world), time: t.timestamp) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { moveTouch(ObjectIdentifier(t).hashValue, canvas: t.location(in: world), time: t.timestamp) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { endTouch(ObjectIdentifier(t).hashValue, canvas: t.location(in: world), time: t.timestamp) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { endTouch(ObjectIdentifier(t).hashValue, canvas: t.location(in: world), time: t.timestamp) }
    }
}

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
/// above y 952; the chest's front wall, its lock and the tabletop lie below y 0). R6: `quarterTurns` (k) turns `world`
/// k clockwise quarter turns about the scene centre (`turned` is k == 2); for odd k the scene is landscape. Every touch
/// is read with `touch.location(in: world)`, and every detail (text, glints, the eye's gaze, the shake, particle
/// gravity, the keyhole) lives in the world's frame, so all four k look the same to the player by construction.
/// - world
///   - shaker (shaken):
///     - the lid half (`SceneLid`, z 0, at y 496): planks, the eye, brow, plate, the jaw (z 50 inside it);
///     - the hinge strip (z 5, y 456…496);
///     - the floor half (`SceneFloor`, z 0): the satchel; the chest (R3: hops, never leaves) with the front wall, bed, tongue,
///       darkness, wash; then the loot (z 25), the moments' floor layer (z 27), R12: the closed chest's cover (z 27.8:
///       the outside of the lid from above, drawn while the lid is shut and lifting back towards the hinge as it
///       opens), the HUD (z 30);
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

    /// R6 ("any way up"): how many CLOCKWISE screen quarter turns the portrait canvas is drawn with (0…3; any Int is
    /// taken mod 4). `world.zRotation = −k·π/2` about the scene centre. For odd k the scene's size is LANDSCAPE: the
    /// App keeps handing the scene the PORTRAIT-equivalent `layout` (`ScreenLayout.make(hasFold:viewSize:)` with the
    /// window's w and h swapped), and the scene sizes itself to `ChestScene.sceneSize(layout:quarterTurns:)` (w and h
    /// swapped when k is odd), so the portrait canvas with its extensions fills it exactly. Touches stay
    /// `touch.location(in: world)`, so they are right for every k by construction. ROUND-6 table: portrait 2 (turn round
    /// on) / 0 (off); landscapeRight 1 / 3; landscapeLeft 3 / 1; upside down 0 / 2; no fold: always 0.
    var quarterTurns: Int {
        get { turns }
        set {
            let k = ChestScene.normalisedTurns(newValue)
            guard k != turns else { return }
            turns = k
            applyTurns()
        }
    }

    /// R2: turned round (the blurred-half rule, GAME-DESIGN §3). R6: a computed alias for `quarterTurns == 2`
    /// (setting it true gives k = 2, false gives k = 0).
    var turned: Bool {
        get { turns == 2 }
        set { quarterTurns = newValue ? 2 : 0 }
    }

    /// R6: any Int → 0…3.
    nonisolated static func normalisedTurns(_ k: Int) -> Int { ((k % 4) + 4) % 4 }

    /// R6: the scene's size for `layout` drawn with `k` quarter turns: `layout.size` (portrait) for even k, its width
    /// and height swapped for odd k.
    nonisolated static func sceneSize(layout: ScreenLayout, quarterTurns k: Int) -> CGSize {
        let s = layout.size
        return normalisedTurns(k) % 2 == 1 ? CGSize(width: s.height, height: s.width) : s
    }

    /// R6: the exact (cos, sin) of the world's rotation −k·π/2 (no floating-point fuzz in the placement maths).
    nonisolated static func turnCosSin(_ k: Int) -> (CGFloat, CGFloat) {
        switch normalisedTurns(k) {
        case 1: return (0, -1)
        case 2: return (-1, 0)
        case 3: return (0, 1)
        default: return (1, 0)
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
    /// R10 (VISUAL-REGRESSION-R9 R1): where the App's coin's centre is, in canvas points (`AppCanvas
    /// .pauseSeatCanvasCenter`, the one source of truth, safe-area clamp included, every k). The seat is drawn there;
    /// nil falls back on `ChestLayout.pauseCenter(viewScale:)`.
    var pauseSeatCanvasCenter: CGPoint? {
        get { hud.seatCanvasCenter }
        set { hud.seatCanvasCenter = newValue }
    }
    /// R10 (R5): the App's coin is hidden (pause menu, closing card, the lesson's final card): the seat fades out.
    var pauseSeatHidden: Bool {
        get { hud.seatHidden }
        set { if hud.seatHidden != newValue { hud.seatHidden = newValue } }
    }
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
    /// The pause seat's alpha (R10: 0 whenever the App's coin is hidden: the bite, a card).
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

    // MARK: R11 (juror P2-1, tester 11: callouts never touch the App's plate)

    /// FOR THE APP: a scene callout is on screen ("CREAK!", the bank stack, the bite, the relic card, "Next chest…").
    /// Hide the hint plate while it is true (one prompt at a time). Either way the scene keeps its callouts
    /// `ChestLayout.calloutGap` (12) view points under the plate.
    var calloutActive: Bool { moments.calloutActive }
    /// Optional, FOR THE APP: the hint plate as drawn (canvas rect, y up), or nil (the scene then assumes the tallest
    /// plate, `ChestLayout.hintPlateViewHeight` view points, centred at `ChestLayout.hintPlateMidY`). A given rect can
    /// only lower the callouts, never raise them into the estimate.
    var hintPlateCanvasRect: CGRect?
    /// The highest a callout's top may reach this frame (canvas y), and the callouts' tops as placed (tests).
    var calloutCeiling: CGFloat { ChestLayout.calloutCeiling(viewScale: hud.viewScale, plate: hintPlateCanvasRect) }
    var creakCalloutTop: CGFloat { moments.creakTop }
    var bankStackTop: CGFloat { moments.bankStackTop }
    var creakCenterY: CGFloat { moments.creakCenterY }
    var bankEyebrowCenterY: CGFloat { moments.bankEyebrowCenterY }
    var nextChestCenterY: CGFloat { moments.nextChestCenterY }
    /// R11: in-chest items drawn under the relic card this frame (always 0), and the card as drawn.
    var lootUnderRelicCard: Int { lootView.underCardVisible }
    var relicCardRect: CGRect { moments.relicCardRect }
    /// R11: the chain tab's furthest-right drawn edge so far (canvas x), "not safe yet" as drawn, the IN BAG number.
    var chainTabDrawnMaxX: CGFloat { hud.chainDrawnMaxX }
    var bagSublabelFrame: CGRect { hud.bagSublabelFrame }
    var bagSublabelFontSize: CGFloat { hud.bagSublabelFontSize }
    var bagNumberCenter: CGPoint { hud.bagNumberCenter }
    var bagNumberScale: CGFloat { hud.bagNumberScale }

    // MARK: R12 (founder, real Duo: "the chest closed means lid closed, chest open means lid open")

    /// The robbed chest: after a bite the run waits for the lid to close before the next chest (Core keeps the bitten
    /// chest, no loot, hint `.closeForNext`). It is drawn OPEN and EMPTY (no cover while the lid is open, no
    /// between-chests shadow, no "Next chest…"), the tongue curled tight and the eye glaring on the lid.
    nonisolated static func isRobbed(_ s: HeistSnapshot) -> Bool {
        s.hint == .closeForNext && s.loot.allSatisfy { $0.place == .lost }
    }
    /// The robbed chest is being drawn this frame.
    var robbedChestShowing: Bool { robbedShowing }
    private var robbedShowing = false
    /// The closed chest's cover (the outside of the lid from above) is drawn this frame, how opaque, how far its
    /// front edge has slid back towards the hinge (canvas pt), its height as drawn, and the arrival settle.
    var closedCoverShowing: Bool { floor.coverShowing }
    var closedCoverAlpha: CGFloat { floor.coverAlpha }
    var closedCoverSlide: CGFloat { floor.coverShowing ? floor.coverPose.slide : 0 }
    var closedCoverYScale: CGFloat { floor.coverPose.yScale }
    var closedCoverArrivalOffset: CGFloat { floor.coverArrivalOffset }
    /// The dress on the cover (the chest's tier, or golden), and the outgoing cover still fading out (an arrival).
    var closedCoverDress: ChestDress { floor.coverDress }
    var closedCoverOldShowing: Bool { floor.coverOldShowing }
    /// The cover's sprite as drawn, in canvas points (world coordinates; y up).
    var closedCoverCanvasFrame: CGRect {
        let n = floor.coverNode
        guard let parent = n.parent else { return .null }
        let f = n.frame
        let ps = [CGPoint(x: f.minX, y: f.minY), CGPoint(x: f.maxX, y: f.minY), CGPoint(x: f.minX, y: f.maxY),
                  CGPoint(x: f.maxX, y: f.maxY)].map { world.convert($0, from: parent) }
        let xs = ps.map(\.x), ys = ps.map(\.y)
        let minX = xs.min() ?? 0, minY = ys.min() ?? 0
        return CGRect(x: minX, y: minY, width: (xs.max() ?? 0) - minX, height: (ys.max() ?? 0) - minY)
    }
    /// The cover lives under `world` (so every quarter turn draws it with the rest of the chest).
    var closedCoverInWorld: Bool { floor.coverNode.inParentHierarchy(world) }
    /// The cover's total z (its own plus its ancestors'), and the lowest total z of anything in the HUD or the meter
    /// (the meter, IN BAG / BANKED, the candle, the chain tab and the pause seat all draw over the cover).
    var closedCoverGlobalZ: CGFloat { globalZ(floor.coverNode) }
    var hudLowestGlobalZ: CGFloat { min(lowestZ(hud.root), lowestZ(hud.meterRoot)) }
    /// The highest total z of an in-chest item's art (under the cover's).
    var lootInChestGlobalZ: CGFloat { globalZ(lootView.root) }

    private func globalZ(_ n: SKNode) -> CGFloat {
        var z: CGFloat = 0
        var p: SKNode? = n
        while let q = p {
            z += q.zPosition
            p = q.parent
        }
        return z
    }

    private func lowestZ(_ n: SKNode) -> CGFloat {
        var lo = globalZ(n)
        var stack: [SKNode] = n.children
        while let c = stack.popLast() {
            lo = min(lo, globalZ(c))
            stack.append(contentsOf: c.children)
        }
        return lo
    }

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

    /// R6: the quarter turns (0…3), behind `quarterTurns`.
    private var turns = 0
    /// R6: the world's uniform scale (1 when the scene has its own size, `sceneSize(layout:quarterTurns:)`; otherwise
    /// the aspect-fill scale that makes the portrait canvas and its extensions cover the scene).
    private(set) var worldScale: CGFloat = 1

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
            _ = SceneTextures.closedCover(d)
        }
        _ = SceneTextures.plateGolden
        _ = SceneTextures.plateSeal(golden: true)
        applyLayout()
    }

    private func applyLayout() {
        let want = ChestScene.sceneSize(layout: layout, quarterTurns: turns)
        if size != want { size = want }
        lid.applyExtension(top: ChestLayout.topExtension(layout))
        floor.applyExtension(bottom: ChestLayout.bottomExtension(layout))
        moments.applyExtension(top: ChestLayout.topExtension(layout), bottom: ChestLayout.bottomExtension(layout))
        placeWorld()
    }

    /// R6: a new k: the scene takes its (possibly landscape) size and the world turns.
    private func applyTurns() {
        let want = ChestScene.sceneSize(layout: layout, quarterTurns: turns)
        if size != want { size = want }
        placeWorld()
        syncViewScale()
    }

    /// The world's transform: canvas → scene. R6: the whole portrait scene (the canvas plus its extensions: world x
    /// 0…670, y −contentOffsetY … layout height − contentOffsetY) is turned k quarter turns clockwise
    /// (`zRotation = −k·π/2`) and its centre put on the scene's centre, scaled to fill the scene exactly (scale 1 at
    /// the scene's own size). k = 0 gives position (0, offset); k = 2 gives (W, H − offset), as R2's `turned`.
    private func placeWorld() {
        let k = turns
        let portrait = layout.size
        let extent = ChestScene.sceneSize(layout: layout, quarterTurns: k)
        var s: CGFloat = 1
        if extent.width > 0, extent.height > 0, size.width > 0, size.height > 0,
           abs(size.width - extent.width) > 0.001 || abs(size.height - extent.height) > 0.001 {
            s = max(size.width / extent.width, size.height / extent.height)
        }
        worldScale = s
        // The portrait scene's centre in world (canvas) coordinates.
        let pc = CGPoint(x: portrait.width / 2, y: portrait.height / 2 - layout.contentOffsetY)
        let (c, sn) = ChestScene.turnCosSin(k)
        let rotated = CGPoint(x: (c * pc.x - sn * pc.y) * s, y: (sn * pc.x + c * pc.y) * s)
        world.setScale(s)
        world.zRotation = -CGFloat(k) * .pi / 2
        world.position = CGPoint(x: size.width / 2 - rotated.x, y: size.height / 2 - rotated.y)
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
        // R11: the callouts' ceiling under the App's plate at this view scale (before the events place any popup).
        moments.calloutCeiling = calloutCeiling
        handle(events, snapshot: s)

        // Keep the chest's dress and plate in step with the snapshot even without an arrival event.
        if let c = s.chest { dressChest(c, animated: false) }

        let light = torchLight(s)
        // R12: the lid's openness IS the chest's: the closed chest's cover follows it, and the robbed chest (after a
        // bite, waiting for the lid to close) is drawn open, empty and glaring.
        let pose = ChestLayout.coverPose(openness: s.openness, reduceMotion: reduceMotion)
        let robbed = ChestScene.isRobbed(s)
        robbedShowing = robbed
        moments.robbed = robbed
        moments.lidCover = pose.alpha
        let mf = moments.update(dt: dt, snapshot: s, effects: fx, hud: hud, lid: lid)
        if moments.slammedThisFrame { lid.squash() }
        floor.chestRoot.position = CGPoint(x: 0, y: mf.chestOffset)
        lootView.root.position = CGPoint(x: 0, y: mf.chestOffset)
        lid.jaw.position = CGPoint(x: 0, y: mf.jawDrop)
        floor.update(dt: dt, snapshot: s, light: light, reduceMotion: reduceMotion, cover: mf.interiorCover,
                     closedCover: pose, robbed: robbed)
        lootView.update(dt: dt, loot: s.loot, hideBagged: mf.hideBagged, light: light, openness: s.openness,
                        cardRect: moments.relicCardRect, cardLevel: moments.relicCardLevel, lidCover: pose)
        hud.update(dt: dt, snapshot: s, light: light, reduceMotion: reduceMotion)
        hud.dimSeat(moments.biteActive, dt: dt)
        lid.update(dt: dt, snapshot: s, light: light, wakeOverride: mf.wakeOverride, teethOverride: mf.teethOverride,
                   lookAt: lookTarget(), usesSlider: leverShowing, reduceMotion: reduceMotion, angry: robbed)
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

    /// R6: view points per scene point for the scene's own `scaleMode` (what SpriteKit really draws). With a
    /// quarter-turned (landscape) scene in a landscape view this is the same number as the portrait rule above.
    static func scaleFor(view: CGSize, scene: CGSize, mode: SKSceneScaleMode) -> CGFloat {
        guard view.width > 0, view.height > 0, scene.width > 0, scene.height > 0 else { return 1 }
        let sx = view.width / scene.width, sy = view.height / scene.height
        switch mode {
        case .aspectFill: return max(sx, sy)
        case .aspectFit: return min(sx, sy)
        case .fill: return min(sx, sy)
        case .resizeFill: return 1
        @unknown default: return scaleFor(view: view, scene: scene)
        }
    }

    private func syncViewScale() {
        guard let v = view else { return }
        // R6: per CANVAS point, so the world's own scale (1 at the scene's own size) counts too.
        hud.viewScale = ChestScene.scaleFor(view: v.bounds.size, scene: size, mode: scaleMode) * worldScale
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
                // R12: under a shut lid the next chest arrives already covered (its cover settles over the old one).
                floor.arrive()
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
                        // R11: and 12 view pt under the plate as a phone draws it (taller in canvas points).
                        let y = min(p.y + 30, 356, moments.popupCeiling(rise: 14))
                        moments.popup(text, at: CGPoint(x: p.x, y: y), color: ScenePaint.ui(pal.gold), rise: 14)
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
                moments.popup("+\(Int(seconds.rounded()))s",
                              at: CGPoint(x: fp.x + 56, y: min(fp.y + 20, 330, moments.popupCeiling(rise: 40))),
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

    // MARK: Touches (read in `world`, i.e. canvas coordinates, so any quarter turn needs nothing more)

    /// A scene point (e.g. a touch's `location(in: scene)`) in canvas coordinates.
    func canvasPoint(fromScene p: CGPoint) -> CGPoint { world.convert(p, from: self) }

    /// A canvas point where it is drawn in the scene.
    func scenePoint(fromCanvas p: CGPoint) -> CGPoint { convert(p, from: world) }

    /// R6: where a canvas rect is drawn in the scene (scene points, y up): the bounding box of its turned corners.
    func sceneRect(fromCanvas r: CGRect) -> CGRect {
        let ps = [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.minX, y: r.maxY),
                  CGPoint(x: r.maxX, y: r.maxY)].map { scenePoint(fromCanvas: $0) }
        let xs = ps.map(\.x), ys = ps.map(\.y)
        let minX = xs.min() ?? 0, maxX = xs.max() ?? 0, minY = ys.min() ?? 0, maxY = ys.max() ?? 0
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// R6: the whole portrait scene (the canvas plus its extensions, world x 0…670, y −offset … height − offset), as
    /// drawn in the scene. It covers the scene exactly (it may overhang by under a point when the scene was given a
    /// size other than its own).
    var drawnWorldRect: CGRect {
        let off = layout.contentOffsetY
        return sceneRect(fromCanvas: CGRect(x: 0, y: -off, width: layout.size.width, height: layout.size.height))
    }

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
        } else if lever && !touchHalves.values.contains(false) {
            // R13 (phone QA P1-4): only the first lid-half finger owns the lever. A second one re-anchored the
            // relative drag, so the first finger's next move snapped the lid by the gap between them (a slam).
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

    /// R9b diagnostics (CI's Duo drag: `touches=0/0/0`): every touch the scene receives, wherever it lands, and where
    /// (canvas points, plus the raw view point). Read by the App's demo-only `debug.state`.
    /// R11 (QA-6 P2-1): DEBUG builds only. Release does no per-touch work for them (no second `location(in:)`, no
    /// string); the properties still compile there and read 0 / "-".
    #if DEBUG
    private(set) var rawTouchesBegan = 0
    private(set) var lastRawTouch = "none"
    #else
    var rawTouchesBegan: Int { 0 }
    var lastRawTouch: String { "-" }
    #endif

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let c = t.location(in: world)
            #if DEBUG
            rawTouchesBegan += 1
            let v = view.map { t.location(in: $0) } ?? .zero
            lastRawTouch = "canvas(\(Int(c.x)),\(Int(c.y)))view(\(Int(v.x)),\(Int(v.y)))"
            #endif
            beginTouch(ObjectIdentifier(t).hashValue, canvas: c, time: t.timestamp)
        }
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

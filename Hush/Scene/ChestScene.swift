import Foundation
import QuartzCore
import SpriteKit
import UIKit

/// The SpriteKit view of the heist (ARCHITECTURE "Scene API"). It draws only from `driver.advance` snapshots and
/// events and owns the cosmetic state (glints, coin bursts, the bite slam, dust, the shake). It never changes game
/// state; it forwards touches to the driver.
///
/// Composition (canvas 670 × 952, origin bottom-left, y up; positions in `ChestLayout`):
/// - **world** (shaken):
///   - the lid half (`SceneLid`, z 0, at y 496): planks, the eye, the plate, the jaw (z 50 inside it: it slams
///     down across the fold);
///   - the hinge strip (z 5, y 456…496);
///   - the floor half (`SceneFloor`, z 0): the satchel; the chest (slides) with the bed, the tongue, the darkness and
///     the warm wash; then the loot (z 25, follows the chest), the moments' floor layer (z 27: the lid shadow, the
///     throat, the lower teeth), the HUD (z 30);
///   - FX: particles (z 55), the moments' titles, CHOMP, banners, flyers and popups (z 60).
/// - **overlay** (z 100, never shaken): the red flash, the Waking pulse, torch-out darkness.
///
/// **Clocks.** FX run on the session's clock (snapshot time), so a pause freezes them; when the session stops
/// stepping (a pause, a CI freeze) they run on for `stallWindow` s of wall time so a moment reaches its peak.
@MainActor
final class ChestScene: SKScene {
    weak var driver: SceneDriver?

    /// Reduce Motion: no shakes, no red flash, gentler tongue twitches and torch flicker.
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

    /// FX keep running this long (wall time) after the session stops stepping.
    static let stallWindow: Double = 0.4

    // MARK: Read-outs (tests, the App)

    /// Frames drawn since the scene was made.
    private(set) var drawnFrames = 0
    /// The snapshot drawn last.
    private(set) var snapshot = HeistSnapshot()
    /// The shake offset applied this frame (zero under Reduce Motion).
    var shakeOffset: CGPoint { world.position }
    /// The eye's openness (0…1) and the teeth (0…1) as drawn.
    var eyeWake: Double { lid.wake }
    var teethShown: CGFloat { lid.teethShown }
    /// The gold counter as drawn (it rolls during a bank).
    var shownBanked: Int { hud.shownBanked }
    /// The chest's slide offset this frame.
    var chestOffset: CGFloat { floor.chestRoot.position.y }
    /// Items drawn this frame.
    var visibleLoot: Int { lootView.visibleCount }
    /// The tongue's curl (0…1) and the interior darkness.
    var tongueCurl: CGFloat { floor.curlLevel }
    var interiorDarkness: CGFloat { floor.darknessAlpha }
    var torchFraction: CGFloat { hud.torchFraction }
    var torchOutLevel: CGFloat { moments.torchOutLevel }
    var biteActive: Bool { moments.biteActive }
    var bankActive: Bool { moments.bankActive }
    var relicBannerShowing: Bool { moments.bannerShowing }
    var floorTier: ChestTier { floor.tier }
    var mimicName: String { lid.name }
    var eyeRebuilds: Int { lid.eyeRebuilds }
    /// Every node under the scene (budget: ≈ 150 typical).
    var nodeCount: Int { countNodes(self) }
    /// Nodes actually drawn this frame (not hidden, not transparent).
    var drawnNodeCount: Int { countNodes(self, visibleOnly: true) }

    /// The App's hint band and pause button area (canvas points, y up).
    static var hintBandRect: CGRect { ChestLayout.hintBand }
    static var pauseButtonRect: CGRect { ChestLayout.pauseArea }

    private let world: SKNode
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

    init(layout: ScreenLayout) {
        let worldN = SKNode()
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
        scaleMode = .aspectFit
        anchorPoint = .zero
        backgroundColor = ScenePaint.ui(ChestArt.palette.dungeonDeep)

        world.zPosition = 0
        addChild(world)
        overlay.zPosition = 100
        addChild(overlay)

        lid.root.zPosition = 0
        world.addChild(lid.root)
        hinge.position = CGPoint(x: ChestLayout.canvas.width / 2, y: (ChestLayout.floorTop + ChestLayout.lidBottom) / 2)
        hinge.zPosition = 5
        world.addChild(hinge)
        floor.root.zPosition = 0
        world.addChild(floor.root)
        lootView.root.zPosition = 25
        floor.root.addChild(lootView.root)
        floor.root.addChild(moments.floorRoot)
        hud.root.zPosition = 30
        floor.root.addChild(hud.root)
        fx.root.zPosition = 55
        world.addChild(fx.root)
        world.addChild(moments.fxRoot)
        overlay.addChild(moments.overlayRoot)

        // Warm every tier's big textures now (not mid-run).
        for t in ChestTier.allCases {
            _ = SceneTextures.chestFrame(t)
            _ = SceneTextures.lid(t)
        }
        applyLayout()
    }

    private func applyLayout() {
        if size != layout.size { size = layout.size }
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        view.isMultipleTouchEnabled = true
    }

    /// A new session: clear every effect and moment.
    func reset() {
        moments.clear()
        fx.clear()
        lootView.clearAll()
        lid.reset()
        floor.reset()
        hud.snap(banked: 0)
        world.position = .zero
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

        var events: [HeistEvent] = []
        var fxDt = dt
        if let d = driver {
            let out = d.advance(dt: dt, now: CACurrentMediaTime())
            usesSlider = d.usesSlider
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

        // Keep the chest's dress in step with the snapshot even without an arrival event (a mid-session start).
        if let c = s.chest {
            if c.tier != floor.tier { floor.setTier(c.tier) }
            if c.tier != lid.tier { lid.setTier(c.tier, animated: false) }
            if c.mimicName != lid.name { lid.setName(c.mimicName) }
        }

        let light = torchLight(s)
        let mf = moments.update(dt: dt, snapshot: s, effects: fx, hud: hud, lid: lid)
        floor.chestRoot.position = CGPoint(x: 0, y: mf.chestOffset)
        lootView.root.position = CGPoint(x: 0, y: mf.chestOffset)
        lid.jaw.position = CGPoint(x: 0, y: mf.jawDrop)
        floor.update(dt: dt, snapshot: s, light: light, reduceMotion: reduceMotion)
        lootView.update(dt: dt, loot: s.loot, hideBagged: mf.hideBagged, light: light)
        hud.update(dt: dt, snapshot: s, light: light, reduceMotion: reduceMotion)
        lid.update(dt: dt, snapshot: s, light: light, wakeOverride: mf.wakeOverride, teethOverride: mf.teethOverride,
                   lookAt: lookTarget(), usesSlider: usesSlider, reduceMotion: reduceMotion)
        fx.update(CGFloat(dt))
        world.position = reduceMotion ? .zero : moments.shake

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

    /// The torch's flicker on the light (1 steady; lower is dimmer). It gutters in the last 15 s.
    private func torchLight(_ s: HeistSnapshot) -> CGFloat {
        let t = animTime
        let low = s.torchTotal > 0 && s.torchRemaining > 0 && s.torchRemaining < 15
        var amp: Double = low ? 0.28 : 0.05
        if reduceMotion { amp *= 0.4 }
        let n = 0.5 + 0.5 * sin(t * 17.0) * sin(t * 6.1 + 1.3)
        var k = 1 - amp * n
        if low && sin(t * 3.7) > 0.93 { k -= amp }
        return CGFloat(max(k, 0.4))
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
                floor.setTier(tier)
                lid.setTier(tier, animated: true)
                lid.setName(name)
                moments.arrive(name: name, tier: tier, multiplier: s.chest?.multiplier ?? 1)
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
                if let p = point(of: id, in: s) {
                    fx.sparkBurst(at: p, count: 5, color: ScenePaint.ui(pal.gold), speed: 140, size: 18)
                    if value > 0 {
                        // Over the in-hand value, rising only a little (the hint band sits above the meter).
                        moments.popup("+\(SceneNumber.gold(value))",
                                      at: CGPoint(x: ChestLayout.bagValueLeft + 70, y: ChestLayout.claspCenter.y + 30),
                                      color: ScenePaint.ui(pal.gold), rise: 20)
                    }
                }
            case .oilAdded(let seconds):
                hud.flare()
                let fp = hud.flamePoint
                moments.popup("+\(Int(seconds.rounded()))s", at: CGPoint(x: fp.x + 46, y: min(fp.y + 20, 400)),
                              color: ScenePaint.ui(pal.amber))
                fx.sparkBurst(at: fp, count: 6, color: ScenePaint.ui(pal.amber), speed: 120, size: 18)
            case .stageChanged:
                break
            case .dreamTwitch:
                lid.twitch()
            case .bitten:
                moments.bite()
            case .banked(let value, _, let hushed):
                moments.bank(items: lootView.bagged(), value: value, hushed: hushed)
                hud.roll(to: s.banked, delay: 0.3, duration: 0.9)
            case .relicFound(let id):
                moments.queueRelic(id)
            case .torchLow:
                hud.torchLow()
                fx.smoke(at: hud.flamePoint, count: 3)
            case .torchOut:
                moments.torchOut()
                fx.smoke(at: hud.flamePoint, count: 6)
            case .newBest:
                let c = ChestLayout.counterRect
                moments.popup("New best!", at: CGPoint(x: c.midX, y: c.maxY + 6), color: ScenePaint.ui(pal.candle),
                              rise: 14)
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

    // MARK: Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let d = driver else { return }
        for t in touches {
            let p = t.location(in: self)
            let id = ObjectIdentifier(t).hashValue
            if ChestLayout.startsOnFloor(p) {
                touchHalves[id] = true
                floorTouchPoints[id] = p
                d.floorTouchBegan(id, at: layout.floorPoint(fromCanvas: p), time: t.timestamp)
            } else if d.usesSlider {
                touchHalves[id] = false
                d.sliderTouch(began: true, ended: false, fraction: layout.lidFraction(fromCanvas: p), time: t.timestamp)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let d = driver else { return }
        for t in touches {
            let p = t.location(in: self)
            let id = ObjectIdentifier(t).hashValue
            guard let onFloor = touchHalves[id] else { continue }
            if onFloor {
                floorTouchPoints[id] = p
                d.floorTouchMoved(id, to: layout.floorPoint(fromCanvas: p), time: t.timestamp)
            } else {
                d.sliderTouch(began: false, ended: false, fraction: layout.lidFraction(fromCanvas: p),
                              time: t.timestamp)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(touches)
    }

    private func finish(_ touches: Set<UITouch>) {
        let d = driver
        for t in touches {
            let p = t.location(in: self)
            let id = ObjectIdentifier(t).hashValue
            guard let onFloor = touchHalves.removeValue(forKey: id) else { continue }
            if onFloor {
                floorTouchPoints[id] = nil
                d?.floorTouchEnded(id, at: layout.floorPoint(fromCanvas: p), time: t.timestamp)
            } else {
                d?.sliderTouch(began: false, ended: true, fraction: layout.lidFraction(fromCanvas: p),
                               time: t.timestamp)
            }
        }
    }
}

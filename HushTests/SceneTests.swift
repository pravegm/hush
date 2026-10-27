import CoreGraphics
import Foundation
import SpriteKit
import Testing
@testable import Hush

/// Scene module tests: geometry and HUD layout (pure), palette contrast, the art paths (pure CoreGraphics), the light
/// model, and a smoke run of the scene through every moment with a scripted driver.
@MainActor
struct SceneTests {
    // MARK: Geometry

    @Test func floorCanvasMappingRoundTrips() {
        let layout = ScreenLayout(hasFold: true)
        let pts = [CGPoint(x: 0, y: 0), CGPoint(x: 335, y: 228), CGPoint(x: 670, y: 456), CGPoint(x: 120, y: -40)]
        for p in pts {
            let c = ChestLayout.canvas(fromFloor: p)
            let back = ChestLayout.floor(fromCanvas: c)
            #expect(abs(back.x - p.x) < CGFloat(0.001) && abs(back.y - p.y) < CGFloat(0.001))
            let viaLayout = layout.canvasPoint(fromFloor: p)
            #expect(abs(viaLayout.x - c.x) < CGFloat(0.001) && abs(viaLayout.y - c.y) < CGFloat(0.001))
            let f = layout.floorPoint(fromCanvas: c)
            #expect(abs(f.y - p.y) < CGFloat(0.001))
        }
        // The hinge edge of the floor is the top of the floor half; the front edge is the canvas bottom.
        #expect(abs(ChestLayout.canvas(fromFloor: .zero).y - ScreenLayout.foldMinY) < CGFloat(0.001))
    }

    @Test func bagStripAndInteriorMatchFloorSpace() {
        let bag = ChestLayout.bagStrip
        #expect(abs(bag.minY) < CGFloat(0.001))
        #expect(abs(bag.maxY - (FloorSpace.height - FloorSpace.bagMinY)) < CGFloat(0.001))
        let inner = ChestLayout.interior
        let corner = ChestLayout.canvas(fromFloor: CGPoint(x: FloorSpace.interior.minX, y: FloorSpace.interior.minY))
        #expect(abs(inner.maxY - corner.y) < CGFloat(0.001))
        #expect(abs(inner.minX - corner.x) < CGFloat(0.001))
        #expect(inner.minY > bag.maxY)
        #expect(inner.maxY < ScreenLayout.foldMinY)
    }

    @Test func touchesSplitAtTheFoldBand() {
        #expect(ChestLayout.startsOnFloor(CGPoint(x: 300, y: 100)))
        #expect(ChestLayout.startsOnFloor(CGPoint(x: 300, y: 470)))
        #expect(!ChestLayout.startsOnFloor(CGPoint(x: 300, y: 480)))
        #expect(!ChestLayout.startsOnFloor(CGPoint(x: 300, y: 800)))
        let layout = ScreenLayout(hasFold: false)
        let low = layout.lidFraction(fromCanvas: CGPoint(x: 600, y: ScreenLayout.foldMaxY))
        let high = layout.lidFraction(fromCanvas: CGPoint(x: 600, y: ScreenLayout.canvasHeight))
        #expect(low < 0.01 && high > 0.99)
    }

    /// The App's hint band sits just above the meter, the pause corner is free, and every HUD piece is on the sharp
    /// (floor) half.
    @Test func hudLeavesTheHintBandAndPauseCornerFree() {
        let hint = ChestLayout.hintBand
        let pause = ChestLayout.pauseArea
        let floor = CGRect(x: 0, y: 0, width: ScreenLayout.canvasWidth, height: ScreenLayout.foldMinY)
        #expect(hint.height >= CGFloat(56))
        #expect(hint.minY >= ChestLayout.meterRect.maxY)
        #expect(hint.minY - ChestLayout.meterRect.maxY <= CGFloat(8))
        #expect(floor.contains(hint) && floor.contains(pause))
        #expect(abs(pause.maxX - ScreenLayout.canvasWidth) < CGFloat(0.001))
        #expect(abs(pause.maxY - ScreenLayout.foldMinY) < CGFloat(0.001))
        #expect(pause.width >= CGFloat(70) && pause.height >= CGFloat(70))
        for r in ChestLayout.hudRects {
            #expect(floor.contains(r))
            #expect(!r.intersects(hint))
            #expect(!r.intersects(pause))
        }
        // The view-space (y down) version flips about the canvas height.
        let v = ChestLayout.viewRect(hint)
        #expect(abs(v.minY - (ScreenLayout.canvasHeight - hint.maxY)) < CGFloat(0.001))
    }

    // MARK: Palette

    @Test func paletteHasCandlelitContrast() {
        let p = ChestArt.palette
        #expect(ScenePaint.contrast(p.text, p.dungeon) >= 7)
        #expect(ScenePaint.contrast(p.text, p.dungeonDeep) >= 7)
        #expect(ScenePaint.contrast(p.gold, p.dungeonDeep) >= 7)
        #expect(ScenePaint.contrast(p.candle, p.dungeonDeep) >= 7)
        #expect(ScenePaint.contrast(p.amber, p.dungeonDeep) >= 4.5)
        #expect(ScenePaint.contrast(p.danger, p.dungeonDeep) >= 4.5)
        // The name plate's dark letters on brass.
        #expect(ScenePaint.contrast(RGBA(hex: 0x2E1606), ScenePaint.brass) >= 4.5)
        // Gold reads against the satchel's dark leather panel.
        #expect(ScenePaint.contrast(p.gold, ScenePaint.leatherDark) >= 4.5)
        #expect(ScenePaint.contrast(p.text, ScenePaint.leatherDark) >= 7)
        // The meter's three zones are distinct and visible on its dark well.
        let well = RGBA(hex: 0x120A06)
        for c in [ScenePaint.meterGreen, p.amber, p.danger] { #expect(ScenePaint.contrast(c, well) >= 3) }
        for c in [p.wood, p.woodDark, p.iron, p.gold, p.velvet, p.tongue, p.dungeon, p.dungeonDeep, p.candle, p.danger,
                  p.amber, p.text] {
            #expect(c.a > 0.99)
            #expect(c.r >= 0 && c.r <= 1 && c.g >= 0 && c.g <= 1 && c.b >= 0 && c.b <= 1)
        }
    }

    @Test func labelsAreNeverSmall() {
        let l = SceneLabelProbe.make(size: 10)
        #expect(l >= SceneLabel.minimumSize)
    }

    // MARK: Art

    static var everyKind: [LootKind] {
        var k: [LootKind] = [.copper, .silver, .oil]
        for g in GemColor.allCases { k.append(.gem(g)) }
        for r in RelicCatalog.all { k.append(.relic(r.id)) }
        k.append(.relic(RelicID("not-a-relic")))
        return k
    }

    private func within(_ path: CGPath, _ r: CGFloat) -> Bool {
        let b = path.boundingBoxOfPath
        let lim = r * 1.02 + 0.5
        return b.minX >= -lim && b.maxX <= lim && b.minY >= -lim && b.maxY <= lim
    }

    @Test func lootPathsAreNonEmptyAndFitTheirRadius() {
        for kind in SceneTests.everyKind {
            for r in [CGFloat(22), 34] {
                let p = ChestArt.lootPath(kind, radius: r)
                #expect(!p.isEmpty)
                let b = p.boundingBoxOfPath
                #expect(b.width > r * 0.5 && b.height > r * 0.5)
                #expect(within(p, r))
                let art = ChestArt.lootArt(kind, radius: r)
                #expect(!art.parts.isEmpty)
                #expect(!art.detail.isEmpty)
                #expect(art.outlineWidth > 0 && art.detailWidth > 0)
                let c = ChestArt.lootColors(kind)
                #expect(c.fill.a > 0.99 && c.rim.a > 0.99 && c.glint.a > 0.99)
                // The rim is darker than the fill, the glint lighter.
                #expect(ScenePaint.luminance(c.rim) <= ScenePaint.luminance(c.fill))
                #expect(ScenePaint.luminance(c.glint) >= ScenePaint.luminance(c.fill))
            }
        }
    }

    @Test func everyRelicShapeIsDrawn() {
        var boxes: [CGRect] = []
        for shape in RelicShape.allCases {
            let p = ChestArt.relicPath(shape, radius: 40)
            #expect(!p.isEmpty)
            #expect(within(p, 40))
            let b = p.boundingBoxOfPath
            #expect(b.width > 20 && b.height > 20)
            boxes.append(b)
        }
        // Not all the same silhouette.
        let distinct = Set(boxes.map { "\(Int($0.width))x\(Int($0.height))" })
        #expect(distinct.count >= 6)
    }

    @Test func mimicEyeOpensWithWake() {
        let size = ChestLayout.lidSize
        var last: CGFloat = -1
        for w in [0.0, 0.25, 0.5, 0.75, 1.0] {
            let e = ChestArt.mimicEye(wake: w, size: size)
            #expect(!e.white.isEmpty && !e.iris.isEmpty && !e.lidTop.isEmpty)
            let h = e.white.boundingBoxOfPath.height
            #expect(h > last)
            last = h
            let all = CGRect(origin: .zero, size: size)
            #expect(all.contains(e.white.boundingBoxOfPath))
            #expect(all.contains(e.lidTop.boundingBoxOfPath))
            // The lid skin always covers the top of the opening.
            #expect(e.lidTop.boundingBoxOfPath.maxY >= e.white.boundingBoxOfPath.maxY)
        }
        // Asleep it is a sliver; biting, wide open.
        let shut = ChestArt.mimicEye(wake: 0, size: size).white.boundingBoxOfPath.height
        let wide = ChestArt.mimicEye(wake: 1, size: size).white.boundingBoxOfPath.height
        #expect(shut < ChestLayout.eyeRadius * 0.3)
        #expect(wide > ChestLayout.eyeRadius * 1.4)
        #expect(!ChestArt.mimicLashes(size: size).isEmpty)
        // Garbage in, a valid eye out.
        #expect(!ChestArt.mimicEye(wake: .nan, size: size).white.isEmpty)
    }

    @Test func teethRowsSpanTheirWidth() {
        let down = ChestArt.teethRow(width: 670, height: 58, count: 9, pointingDown: true).boundingBoxOfPath
        #expect(down.minX >= 0 && down.maxX <= 670)
        #expect(down.minY < -40 && down.maxY <= 5)
        let up = ChestArt.teethRow(width: 670, height: 50, count: 8, pointingDown: false).boundingBoxOfPath
        #expect(up.maxY > 35 && up.minY >= -5)
        #expect(!ChestArt.teethRow(width: 100, height: 10, count: 0, pointingDown: true).isEmpty)
    }

    // MARK: Light and the tells

    @Test func lightReachesDeeperAsTheLidOpens() {
        var lastDark = CGFloat(2), lastReach = CGFloat(-1)
        for o in stride(from: 0.0, through: 1.0, by: 0.1) {
            let d = SceneFloor.darknessLevels(openness: o)
            #expect(d.uniform < lastDark)
            lastDark = d.uniform
            let r = SceneFloor.washReach(openness: o)
            #expect(r > lastReach)
            lastReach = r
        }
        #expect(SceneFloor.darknessLevels(openness: 0).uniform > CGFloat(0.6))
        #expect(SceneFloor.darknessLevels(openness: 1).uniform < CGFloat(0.12))
        #expect(SceneFloor.washReach(openness: 1) > CGFloat(0.99))
    }

    @Test func eyeAndTeethFollowTheStage() {
        let stages: [MimicStage] = [.asleep, .stirring, .waking, .biting]
        var w = -1.0
        var t = CGFloat(-1)
        for s in stages {
            let nw = SceneLid.wakeTarget(stage: s, noise: s == .waking ? 0.8 : 0.2)
            let nt = SceneLid.teethTarget(stage: s, noise: s == .waking ? 0.8 : 0.2)
            #expect(nw > w)
            #expect(nt > t)
            w = nw
            t = nt
        }
        #expect(SceneLid.wakeTarget(stage: .asleep, noise: 0) < 0.01)
        #expect(SceneLid.wakeTarget(stage: .biting, noise: 1) > 0.99)
    }

    @Test func titlesReadWell() {
        #expect(SceneMoments.multiplierText(1) == "×1")
        #expect(SceneMoments.multiplierText(1.5) == "×1.5")
        #expect(SceneMoments.multiplierText(2) == "×2")
        #expect(SceneMoments.multiplierText(3) == "×3")
        #expect(SceneMoments.multiplierText(.nan) == "×1")
        let names = Set(ChestTier.allCases.map { SceneMoments.tierName($0) })
        #expect(names.count == ChestTier.allCases.count)
    }

    // MARK: The scene

    @Test @MainActor func sceneBuildsWithinBudget() {
        let scene = ChestScene(layout: ScreenLayout(hasFold: true))
        #expect(abs(scene.size.width - ScreenLayout.canvasWidth) < CGFloat(0.001))
        #expect(abs(scene.size.height - ScreenLayout.canvasHeight) < CGFloat(0.001))
        #expect(scene.scaleMode == .aspectFit)
        let driver = SceneFakeDriver()
        scene.driver = driver
        driver.startChest(SceneFakeDriver.chest(tier: .wooden, index: 0))
        var clock = 100.0
        SceneFakeDriver.run(scene, frames: 90, clock: &clock)
        driver.openTo(0.95)
        SceneFakeDriver.run(scene, frames: 60, clock: &clock)
        #expect(scene.visibleLoot >= 4)
        #expect(scene.drawnNodeCount <= 160)
        #expect(scene.nodeCount <= 260)
    }

    @Test @MainActor func steadyFramesBuildNoTexturesAndFewEyePaths() {
        let scene = ChestScene(layout: ScreenLayout(hasFold: true))
        let driver = SceneFakeDriver()
        scene.driver = driver
        driver.startChest(SceneFakeDriver.chest(tier: .iron, index: 2))
        var clock = 10.0
        driver.openTo(0.6)
        SceneFakeDriver.run(scene, frames: 120, clock: &clock)
        let textures = SceneTextures.count
        let rebuilds = scene.eyeRebuilds
        SceneFakeDriver.run(scene, frames: 240, clock: &clock)
        #expect(SceneTextures.count == textures)
        // Asleep and still: the eye's paths are not rebuilt.
        #expect(scene.eyeRebuilds <= rebuilds + 1)
    }

    @Test @MainActor func darknessLiftsAndTheTongueCurlsWhenWaking() {
        let scene = ChestScene(layout: ScreenLayout(hasFold: true))
        let driver = SceneFakeDriver()
        scene.driver = driver
        driver.startChest(SceneFakeDriver.chest(tier: .wooden, index: 0))
        var clock = 0.0
        SceneFakeDriver.run(scene, frames: 30, clock: &clock)
        let dark = scene.interiorDarkness
        driver.openTo(1)
        SceneFakeDriver.run(scene, frames: 30, clock: &clock)
        #expect(scene.interiorDarkness < dark)
        #expect(scene.tongueCurl < CGFloat(0.05))
        driver.snap.noise = 0.85
        driver.snap.stage = .waking
        SceneFakeDriver.run(scene, frames: 120, clock: &clock)
        #expect(scene.tongueCurl > CGFloat(0.8))
        #expect(scene.eyeWake > 0.45)
        #expect(scene.teethShown > CGFloat(0.6))
    }

    @Test @MainActor func biteSlamsShakesAndEatsTheLootInHand() {
        for reduce in [false, true] {
            let scene = ChestScene(layout: ScreenLayout(hasFold: true))
            scene.reduceMotion = reduce
            let driver = SceneFakeDriver()
            scene.driver = driver
            driver.startChest(SceneFakeDriver.chest(tier: .wooden, index: 0))
            var clock = 0.0
            driver.openTo(0.9)
            driver.bag([0, 1])
            SceneFakeDriver.run(scene, frames: 60, clock: &clock)
            driver.loseBag()
            driver.snap.phase = .bitten(elapsed: 0)
            driver.snap.stage = .biting
            driver.snap.noise = 1
            driver.pending = [.stageChanged(from: .waking, to: .biting), .bitten(lostValue: 38)]
            var maxShake: CGFloat = 0
            for _ in 0..<40 {
                SceneFakeDriver.run(scene, frames: 1, clock: &clock)
                maxShake = max(maxShake, abs(scene.shakeOffset.x) + abs(scene.shakeOffset.y))
            }
            #expect(scene.biteActive)
            #expect(scene.eyeWake > 0.8)
            #expect(scene.teethShown > CGFloat(0.8))
            if reduce {
                #expect(maxShake < CGFloat(0.001))
            } else {
                #expect(maxShake > CGFloat(2))
            }
            // The lost loot flies into the mouth and is gone.
            SceneFakeDriver.run(scene, frames: 60, clock: &clock)
            #expect(scene.visibleLoot <= 3)
            // The chest hops and leaves off the front.
            SceneFakeDriver.run(scene, frames: 120, clock: &clock)
            #expect(scene.chestOffset < CGFloat(-300))
        }
    }

    @Test @MainActor func bankRollsTheCounterAndShowsTheRelic() {
        let scene = ChestScene(layout: ScreenLayout(hasFold: true))
        let driver = SceneFakeDriver()
        scene.driver = driver
        let spec = SceneFakeDriver.chest(tier: .gilded, index: 4)
        driver.startChest(spec)
        var clock = 0.0
        driver.openTo(0.95)
        driver.bag([0, 1, 2, 4])
        driver.snap.bagValue = 640
        SceneFakeDriver.run(scene, frames: 60, clock: &clock)
        driver.openTo(0.05)
        driver.snap.shutHold = 1
        driver.snap.phase = .banked(elapsed: 0)
        driver.snap.banked = 640
        driver.snap.bagValue = 0
        var events: [HeistEvent] = [.banked(value: 640, items: 4, hushed: true)]
        if let r = RelicCatalog.all.first { events.append(.relicFound(r.id)) }
        driver.pending = events
        SceneFakeDriver.run(scene, frames: 2, clock: &clock)
        #expect(scene.bankActive)
        #expect(scene.shownBanked < 640)
        SceneFakeDriver.run(scene, frames: 60, clock: &clock)
        if !RelicCatalog.all.isEmpty { #expect(scene.relicBannerShowing) }
        SceneFakeDriver.run(scene, frames: 150, clock: &clock)
        #expect(scene.shownBanked == 640)
        #expect(scene.chestOffset < CGFloat(-300))
    }

    @Test @MainActor func arrivalSlidesInAndDressesTheChest() {
        let scene = ChestScene(layout: ScreenLayout(hasFold: true))
        let driver = SceneFakeDriver()
        scene.driver = driver
        var clock = 0.0
        driver.startChest(SceneFakeDriver.chest(tier: .royal, index: 7, name: "Dozy Dora"))
        SceneFakeDriver.run(scene, frames: 6, clock: &clock)
        #expect(scene.chestOffset < CGFloat(-100))
        SceneFakeDriver.run(scene, frames: 120, clock: &clock)
        #expect(abs(scene.chestOffset) < CGFloat(1))
        #expect(scene.floorTier == .royal)
        #expect(scene.mimicName == "Dozy Dora")
    }

    @Test @MainActor func torchBurnsDownThenTheDarkClosesIn() {
        let scene = ChestScene(layout: ScreenLayout(hasFold: true))
        let driver = SceneFakeDriver()
        scene.driver = driver
        driver.startChest(SceneFakeDriver.chest(tier: .wooden, index: 0))
        var clock = 0.0
        driver.snap.torchTotal = 100
        driver.snap.torchRemaining = 50
        SceneFakeDriver.run(scene, frames: 10, clock: &clock)
        #expect(abs(scene.torchFraction - CGFloat(0.5)) < CGFloat(0.01))
        driver.snap.torchRemaining = 12
        driver.pending = [.torchLow]
        SceneFakeDriver.run(scene, frames: 30, clock: &clock)
        driver.snap.torchRemaining = 0
        driver.snap.phase = .torchOut(elapsed: 0)
        driver.pending = [.torchOut]
        SceneFakeDriver.run(scene, frames: 280, clock: &clock)
        #expect(scene.torchOutLevel > CGFloat(0.99))
        // A new session clears it.
        scene.reset()
        driver.snap = HeistSnapshot()
        SceneFakeDriver.run(scene, frames: 2, clock: &clock)
        #expect(scene.torchOutLevel < CGFloat(0.01))
    }

    @Test @MainActor func everyEventIsDrawnWithoutADriverHiccup() {
        let scene = ChestScene(layout: ScreenLayout(hasFold: false))
        let driver = SceneFakeDriver()
        driver.usesSlider = true
        scene.driver = driver
        let spec = SceneFakeDriver.chest(tier: .iron, index: 3)
        driver.startChest(spec)
        var clock = 0.0
        driver.openTo(0.95)
        SceneFakeDriver.run(scene, frames: 30, clock: &clock)
        let relic = RelicCatalog.all.first?.id ?? RelicID("relic01")
        let all: [HeistEvent] = [
            .lidCracked, .itemRevealed(id: 0, kind: .copper), .itemRevealed(id: 4, kind: .relic(relic)),
            .itemPicked(id: 1, kind: .silver), .itemDropped(id: 1), .itemBagged(id: 2, kind: .gem(.ruby), value: 135),
            .oilAdded(seconds: 8), .stageChanged(from: .asleep, to: .stirring), .dreamTwitch, .newBest, .torchLow,
            .relicFound(relic), .finished,
        ]
        for e in all {
            driver.pending = [e]
            SceneFakeDriver.run(scene, frames: 8, clock: &clock)
        }
        // A held item and a pause (the session stops stepping): FX run on briefly, then freeze.
        driver.hold(1)
        driver.frozen = true
        SceneFakeDriver.run(scene, frames: 120, clock: &clock)
        driver.frozen = false
        // The clock going backwards is a new session.
        driver.snap.time = 0
        SceneFakeDriver.run(scene, frames: 5, clock: &clock)
        #expect(scene.drawnFrames > 200)
    }
}

/// Reads a `SceneLabel`'s clamped size (it must be made on the main actor).
enum SceneLabelProbe {
    @MainActor static func make(size: CGFloat) -> CGFloat {
        SceneLabel(size: size, color: .white).size
    }
}

/// A scripted stand-in for the App's GameController.
@MainActor
final class SceneFakeDriver: SceneDriver {
    var snap = HeistSnapshot()
    var pending: [HeistEvent] = []
    var usesSlider = false
    /// When true the session doesn't step (a pause / a CI freeze).
    var frozen = false
    private(set) var floorTouches = 0

    func advance(dt: TimeInterval, now: TimeInterval) -> (HeistSnapshot, [HeistEvent]) {
        if !frozen { snap.time += dt }
        let e = pending
        pending = []
        return (snap, e)
    }

    func floorTouchBegan(_ id: Int, at point: CGPoint, time: TimeInterval) { floorTouches += 1 }
    func floorTouchMoved(_ id: Int, to point: CGPoint, time: TimeInterval) { floorTouches += 1 }
    func floorTouchEnded(_ id: Int, at point: CGPoint, time: TimeInterval) { floorTouches += 1 }
    func sliderTouch(began: Bool, ended: Bool, fraction: Double, time: TimeInterval) {}

    static func chest(tier: ChestTier, index: Int, name: String = "Snoring Sam") -> ChestSpec {
        var items: [LootItem] = [
            LootItem(id: 0, kind: .copper, value: 8, depth: 0.1, position: CGPoint(x: 200, y: 250), radius: 22,
                     rotation: 0.2),
            LootItem(id: 1, kind: .silver, value: 30, depth: 0.3, position: CGPoint(x: 330, y: 200), radius: 24,
                     rotation: 0),
            LootItem(id: 2, kind: .gem(.ruby), value: 90, depth: 0.6, position: CGPoint(x: 460, y: 150), radius: 26,
                     rotation: 0.4),
            LootItem(id: 3, kind: .oil, value: 0, depth: 0.4, position: CGPoint(x: 150, y: 120), radius: 24,
                     rotation: 0),
        ]
        let relic = RelicCatalog.all.first?.id ?? RelicID("relic01")
        items.append(LootItem(id: 4, kind: .relic(relic), value: 300, depth: 0.85, position: CGPoint(x: 335, y: 80),
                              radius: 34, rotation: 0))
        return ChestSpec(index: index, tier: tier, mimic: .snorer, mimicName: name, multiplier: 1.5, decay: 0.12,
                         items: items)
    }

    func startChest(_ spec: ChestSpec) {
        snap.chest = spec
        snap.phase = .ready
        snap.openness = 0
        snap.stage = .asleep
        snap.noise = 0
        snap.loot = spec.items.map {
            LootState(item: $0, position: $0.position, place: .inChest, light: 0, grabbable: false)
        }
        pending.append(.chestArrived(index: spec.index, tier: spec.tier, mimic: spec.mimic, name: spec.mimicName))
    }

    func openTo(_ o: Double) {
        snap.openness = o
        snap.phase = o > 0.02 ? .looting : .ready
        for i in 0..<snap.loot.count where snap.loot[i].place == .inChest {
            let l = min(max((o - snap.loot[i].item.depth) / 0.1, 0), 1)
            snap.loot[i].light = l
            snap.loot[i].grabbable = l >= 0.6
        }
    }

    func bag(_ ids: [Int]) {
        for (k, id) in ids.enumerated() {
            guard let i = snap.loot.firstIndex(where: { $0.id == id }) else { continue }
            snap.loot[i].place = .inBag
            snap.loot[i].position = CGPoint(x: 290 + CGFloat(k) * 40, y: 400)
            snap.loot[i].light = 1
        }
    }

    func hold(_ id: Int) {
        guard let i = snap.loot.firstIndex(where: { $0.id == id }) else { return }
        snap.loot[i].place = .held(touchID: 7)
        snap.loot[i].position = CGPoint(x: 300, y: 330)
        snap.loot[i].light = 1
    }

    func loseBag() {
        for i in 0..<snap.loot.count where snap.loot[i].place == .inBag { snap.loot[i].place = .lost }
    }

    static func run(_ scene: ChestScene, frames: Int, clock: inout Double) {
        for _ in 0..<max(frames, 0) {
            scene.update(clock)
            clock += 1.0 / 120.0
        }
    }
}

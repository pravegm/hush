import CoreGraphics
import Foundation
import SpriteKit
import Testing
@testable import Hush

/// Scene module tests: geometry and HUD layout (pure), the turned-round world and touch mapping, the extension that
/// fills tall screens, palette contrast, the art (pure CoreGraphics: 24 distinct relics, coin stacks, rendered images
/// shared with SwiftUI), the light model, the portrait, and a smoke run of the scene through every moment with a
/// scripted driver.
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
        #expect(ChestLayout.startsOnFloor(CGPoint(x: 300, y: -200)))
        #expect(!ChestLayout.startsOnFloor(CGPoint(x: 300, y: 480)))
        #expect(!ChestLayout.startsOnFloor(CGPoint(x: 300, y: 1100)))
        // The slider fraction spans the whole visible lid (the canvas lid plus the extension above it).
        #expect(ChestLayout.lidFraction(canvasY: ScreenLayout.foldMaxY, topExtension: 0) < 0.01)
        #expect(ChestLayout.lidFraction(canvasY: ScreenLayout.canvasHeight, topExtension: 0) > 0.99)
        let mid = ChestLayout.lidFraction(canvasY: ScreenLayout.canvasHeight, topExtension: 250)
        #expect(mid > 0.6 && mid < 0.7)
        #expect(ChestLayout.lidFraction(canvasY: ScreenLayout.canvasHeight + 250, topExtension: 250) > 0.99)
        #expect(ChestLayout.lidFraction(canvasY: 5000, topExtension: 250) <= 1)
        // A drag that overshoots into the front wall / table below the canvas still lands in the bag.
        let below = ChestLayout.floorTouchPoint(fromCanvas: CGPoint(x: 335, y: -120))
        #expect(FloorSpace.bagRect.contains(below))
        let onLid = ChestLayout.floorTouchPoint(fromCanvas: CGPoint(x: 335, y: 520))
        #expect(onLid.y < 0)
    }

    /// R2: the App's hint band is at the floor's back edge by the fold (canvas y 404…452), the pause coin area is
    /// inset ≥ 16 pt from every edge, and no scene HUD covers either.
    @Test func hudLeavesTheHintBandAndPauseCoinFree() {
        let hint = ChestLayout.hintBand
        let pause = ChestLayout.pauseArea
        let floor = CGRect(x: 0, y: 0, width: ScreenLayout.canvasWidth, height: ScreenLayout.foldMinY)
        #expect(abs(hint.minY - 404) < CGFloat(0.001) && abs(hint.maxY - 452) < CGFloat(0.001))
        #expect(floor.contains(hint) && floor.contains(pause))
        #expect(!hint.intersects(pause))
        #expect(pause.minX >= 16 && pause.maxX <= ScreenLayout.canvasWidth - 16)
        #expect(pause.minY >= 16 && pause.maxY <= ScreenLayout.foldMinY - 16)
        #expect(pause.width >= CGFloat(44) && pause.height >= CGFloat(44))
        for r in ChestLayout.hudRects {
            #expect(floor.contains(r))
            #expect(!r.intersects(hint))
            #expect(!r.intersects(pause))
        }
        // R3: the chain tab sits on the front rim beside the meter, inside the frame, never under BANKED's row.
        #expect(ChestLayout.chainRect.minX > ChestLayout.meterRect.maxX)
        #expect(ChestLayout.chainRect.minY > ChestLayout.counterRect.maxY)
        #expect(!ChestLayout.chainRect.intersects(ChestLayout.counterRect))
        // R3: nothing touches a screen edge (≥ 16 pt inset at the sides), the pause coin included.
        let inset = ChestLayout.edgeInset
        for r in ChestLayout.hudRects + [pause] {
            #expect(r.minX >= inset - 0.001 && r.maxX <= ScreenLayout.canvasWidth - inset + 0.001)
        }
        #expect(ChestLayout.counterCoin.x + 26 <= ScreenLayout.canvasWidth - inset)
        // The countdown hangs beside the candle, not over it.
        #expect(ChestLayout.countdownRect.minX > ChestLayout.torchRect.maxX)
        // The pause coin sits in its socket (the frame draws no corner bracket there).
        #expect(pause.width / 2 <= ChestLayout.pauseSocketRadius - 8)
        // IN BAG on the left, BANKED on the right, always.
        #expect(ChestLayout.bagValueRect.maxX < ChestLayout.pouchRect.minX)
        #expect(ChestLayout.counterRect.minX > ChestLayout.pouchRect.maxX)
        // The view-space (y down) version flips about the canvas height.
        let v = ChestLayout.viewRect(hint)
        #expect(abs(v.minY - (ScreenLayout.canvasHeight - hint.maxY)) < CGFloat(0.001))
    }

    // MARK: Turned round and filling the screen

    static var phone: ScreenLayout { ScreenLayout.make(hasFold: false, viewSize: CGSize(width: 393, height: 852)) }

    /// A turned touch at the VISUAL position of an item maps to that item's floor point (and an unturned one too).
    @Test @MainActor func turnedTouchMapsToTheItemsFloorPoint() {
        let layout = SceneTests.phone
        let scene = ChestScene(layout: layout)
        let driver = SceneFakeDriver()
        scene.driver = driver
        let item = CGPoint(x: 200, y: 250)   // floor space
        let c = ChestLayout.canvas(fromFloor: item)
        let h = layout.size.height
        let off = layout.contentOffsetY

        // Unturned: the canvas sits `contentOffsetY` above the scene's bottom.
        let flat = scene.scenePoint(fromCanvas: c)
        #expect(abs(flat.x - c.x) < CGFloat(0.01) && abs(flat.y - (c.y + off)) < CGFloat(0.01))

        // Turned: rotated by π about the scene centre.
        scene.turned = true
        let seen = scene.scenePoint(fromCanvas: c)
        #expect(abs(seen.x - (ScreenLayout.canvasWidth - c.x)) < CGFloat(0.01))
        #expect(abs(seen.y - (h - off - c.y)) < CGFloat(0.01))
        #expect(abs(seen.x - flat.x) > CGFloat(50))
        // A finger at that visual point (what `touch.location(in: world)` gives) is the item's floor point.
        let back = scene.canvasPoint(fromScene: seen)
        #expect(abs(back.x - c.x) < CGFloat(0.01) && abs(back.y - c.y) < CGFloat(0.01))
        scene.beginTouch(1, canvas: back, time: 1)
        let f = driver.lastBegan ?? CGPoint(x: -999, y: -999)
        #expect(abs(f.x - item.x) < CGFloat(0.01) && abs(f.y - item.y) < CGFloat(0.01))
        scene.endTouch(1, canvas: back, time: 1.1)
        #expect(driver.ended == 1)
        // Turning back restores the plain placement.
        scene.turned = false
        let again = scene.scenePoint(fromCanvas: c)
        #expect(abs(again.x - flat.x) < CGFloat(0.01) && abs(again.y - flat.y) < CGFloat(0.01))
    }

    @Test @MainActor func phonesGetExtensionArtAndTheDuoNone() {
        let phone = ChestScene(layout: SceneTests.phone)
        let h = SceneTests.phone.size.height
        #expect(h > ScreenLayout.canvasHeight + 400)
        #expect(abs(phone.size.height - h) < CGFloat(0.001))
        #expect(abs(phone.extensionTop + phone.extensionBottom - (h - ScreenLayout.canvasHeight)) < CGFloat(1.01))
        #expect(abs(phone.extensionBottom - SceneTests.phone.contentOffsetY) < CGFloat(0.51))
        #expect(phone.scaleMode == .aspectFill)
        let duo = ChestScene(layout: ScreenLayout(hasFold: true))
        #expect(duo.extensionTop < CGFloat(1) && duo.extensionBottom < CGFloat(1))
        // Re-laying out a live scene follows the new size.
        duo.layout = SceneTests.phone
        #expect(duo.extensionTop > CGFloat(200))
        #expect(ChestLayout.frontWallHeight(extension: 0) == 0)
        #expect(ChestLayout.frontWallHeight(extension: 250) <= ChestLayout.frontWallMax)
        #expect(ChestLayout.frontWallHeight(extension: 250) < 250)
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
        // The name plate's dark letters and the meter's "NOISE" on brass.
        #expect(ScenePaint.contrast(RGBA(hex: 0x2E1606), ScenePaint.brass) >= 4.5)
        #expect(ScenePaint.contrast(RGBA(hex: 0x4A2408), ScenePaint.brass) >= 3)
        // Gold and cream read against the satchel's dark leather plates.
        #expect(ScenePaint.contrast(p.gold, ScenePaint.leatherDark) >= 4.5)
        #expect(ScenePaint.contrast(p.text, ScenePaint.leatherDark) >= 7)
        #expect(ScenePaint.contrast(p.amber, ScenePaint.leatherDark) >= 4.5)
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
        #expect(SceneLabelProbe.make(size: 10) >= SceneLabel.minimumSize)
        // Small-caps labels may go to 14 pt, never below.
        #expect(SceneLabelProbe.make(size: 10, minimum: 14) >= 14)
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

    /// R2: coins are gold discs; higher values are a stack of 2–3 coins, each drawn with its own rim.
    @Test func coinsStackByValue() {
        var last = 0
        for v in [5, 6, 7, 8, 9, 10] {
            let n = ChestArt.coinCount(.copper, value: v)
            #expect(n >= last && n >= 1 && n <= 3)
            last = n
            let art = ChestArt.lootArt(.copper, radius: 22, value: v)
            #expect(art.parts.count == n)
            #expect(art.layerDetail?.count == n)
            #expect(within(art.silhouette, 22))
        }
        #expect(ChestArt.coinCount(.copper, value: 5) == 1)
        #expect(ChestArt.coinCount(.copper, value: 10) == 3)
        #expect(ChestArt.coinCount(.gem(.ruby), value: 999) == 1)
        // The oil flask carries its "+Ns" tag.
        let oil = ChestArt.lootArt(.oil, radius: 24)
        #expect(oil.tag?.text.hasPrefix("+") == true && oil.tag?.text.hasSuffix("s") == true)
    }

    /// R2: 24 relics, 24 different silhouettes (sampled on a grid, every one distinct).
    @Test func twentyFourDistinctRelicSilhouettes() {
        #expect(RelicShape.allCases.count == 24)
        var signatures = Set<String>()
        for shape in RelicShape.allCases {
            let r: CGFloat = 40
            let p = ChestArt.relicPath(shape, radius: r)
            #expect(!p.isEmpty)
            #expect(within(p, r))
            let b = p.boundingBoxOfPath
            #expect(b.width > 20 && b.height > 20)
            let art = ChestArt.relicArt(shape, radius: r)
            #expect(!art.detail.isEmpty)
            var bits = ""
            var filled = 0
            for j in 0..<14 {
                for i in 0..<14 {
                    let pt = CGPoint(x: -r + (CGFloat(i) + 0.5) * (2 * r / 14), y: -r + (CGFloat(j) + 0.5) * (2 * r / 14))
                    let hit = p.contains(pt)
                    bits += hit ? "1" : "0"
                    if hit { filled += 1 }
                }
            }
            #expect(filled > 12)
            signatures.insert(bits)
        }
        #expect(signatures.count == RelicShape.allCases.count)
    }

    /// One art source: SwiftUI and SpriteKit get the same rendered images (cached).
    @Test func lootAndRelicImagesRender() {
        let side = ChestArt.artSide(radius: 34)
        for kind in SceneTests.everyKind {
            let img = ChestArt.lootImage(kind, value: 9, radius: 34, scale: 2)
            #expect(img != nil)
            if let img { #expect(abs(CGFloat(img.width) - (side * 2).rounded(.up)) <= 1) }
        }
        if let relic = RelicCatalog.all.first {
            let found = ChestArt.relicImage(relic, found: true, radius: 40, scale: 2)
            let locked = ChestArt.relicImage(relic, found: false, radius: 40, scale: 2)
            #expect(found != nil && locked != nil)
            #expect(found !== locked)
            // Cached: the same image object comes back.
            #expect(ChestArt.relicImage(relic, found: true, radius: 40, scale: 2) === found)
        }
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
        // The fleshy eye bed holds the wide-open eye, below the brow.
        let bed = ChestArt.mimicEyeBed(size: size).boundingBoxOfPath
        #expect(bed.contains(ChestArt.mimicEye(wake: 1, size: size).white.boundingBoxOfPath))
        #expect(bed.maxY < ChestLayout.browCenter.y)
        #expect(bed.minY > ChestLayout.plateCenter.y + ChestLayout.plateSize.height / 2 - 8)
        // Garbage in, a valid eye out.
        #expect(!ChestArt.mimicEye(wake: .nan, size: size).white.isEmpty)
    }

    @Test func fangRowsArePointedAndSpanTheirWidth() {
        let down = ChestArt.teethRow(width: 670, height: 58, count: 9, pointingDown: true).boundingBoxOfPath
        #expect(down.minX >= 0 && down.maxX <= 670)
        #expect(down.minY < -40 && down.maxY <= 5)
        let up = ChestArt.teethRow(width: 670, height: 50, count: 8, pointingDown: false).boundingBoxOfPath
        #expect(up.maxY > 35 && up.minY >= -5)
        #expect(!ChestArt.teethRow(width: 100, height: 10, count: 0, pointingDown: true).isEmpty)
        // Pointed: a fang is much narrower near its tip than at its root.
        let one = ChestArt.teethRow(width: 100, height: 60, count: 1, pointingDown: true)
        let tip = one.boundingBoxOfPath.minY
        #expect(!one.contains(CGPoint(x: 20, y: tip * 0.85)))
        #expect(one.contains(CGPoint(x: 50, y: tip * 0.7)))
        #expect(one.contains(CGPoint(x: 20, y: -2)))
    }

    // MARK: Words on the lid

    @Test func namePlateCarriesTraitAndTier() {
        var c = SceneFakeDriver.chest(tier: .iron, index: 2)
        c.mimic = .lightSleeper
        c.multiplier = 1.5
        // R3: two tokens on the line; the multiplier is the seal.
        #expect(ChestCopy.plateSubline(c) == "Light sleeper · Iron-bound")
        #expect(ChestCopy.plateSeal(c) == "×1.5")
        c.tier = .wooden
        c.multiplier = 1
        c.mimic = .heavySleeper
        #expect(ChestCopy.plateSubline(c) == "Heavy sleeper · Wooden")
        #expect(ChestCopy.plateSeal(c) == nil)
        c.mimic = .dreamer
        #expect(ChestCopy.plateSubline(c) == "Dreamer · Wooden")
        c.mimic = .lightSleeper
        c.golden = true
        c.multiplier = 3
        // The golden plate says GOLDEN, and the seal shows the real payout (QA-2 P2-8: tier × 2).
        #expect(ChestCopy.plateSubline(c) == "GOLDEN MIMIC · Light sleeper")
        #expect(ChestCopy.plateSeal(c) == "×3")
        #expect(SceneMoments.multiplierText(1.5) == "×1.5")
        #expect(SceneMoments.multiplierText(2) == "×2")
        #expect(SceneMoments.multiplierText(.nan) == "×1")
        let names = Set(ChestTier.allCases.map { ChestCopy.tierShort($0) })
        #expect(names.count == ChestTier.allCases.count)
        let traits = Set(MimicKind.allCases.map { ChestCopy.trait($0) })
        #expect(traits.count == MimicKind.allCases.count)
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
        // The candle-low gloom grows as the last seconds run out.
        #expect(SceneFloor.gloomLevel(remaining: 50, total: 100) == 0)
        #expect(SceneFloor.gloomLevel(remaining: 2, total: 100) > SceneFloor.gloomLevel(remaining: 10, total: 100))
    }

    @Test func eyeTeethAndBrowFollowTheStage() {
        let stages: [MimicStage] = [.asleep, .stirring, .waking, .biting]
        var w = -1.0
        var t = CGFloat(-1)
        var b = CGFloat(-1)
        for s in stages {
            let nw = SceneLid.wakeTarget(stage: s, noise: s == .waking ? 0.8 : 0.2)
            let nt = SceneLid.teethTarget(stage: s, noise: s == .waking ? 0.8 : 0.2)
            let nb = SceneLid.browTarget(stage: s)
            #expect(nw > w)
            #expect(nt > t)
            #expect(nb > b)
            w = nw
            t = nt
            b = nb
        }
        #expect(SceneLid.wakeTarget(stage: .asleep, noise: 0) < 0.01)
        // R3: asleep, the mouth still shows its tooth tips (5–7 fangs, every one peeking; the canines about half).
        #expect(SceneLid.teethTarget(stage: .asleep, noise: 0) >= ChestLayout.teethAsleep)
        #expect(SceneTextures.fangSpec.count >= 5 && SceneTextures.fangSpec.count <= 7)
        let tuck = ChestLayout.teethTuck * (1 - ChestLayout.teethAsleep)
        for fang in SceneTextures.fangSpec { #expect(fang.len - 2 - tuck > CGFloat(8)) }
        #expect(SceneLid.canineShowing(shown: 0) > CGFloat(20))
        #expect(SceneLid.canineShowing(shown: 1) > SceneLid.canineShowing(shown: 0.4))
        // Tucked, no root ever rises above the lip (it would show over the plate).
        let corner = SceneTextures.gumEdge(SceneTextures.fangSpec[0].x)
        let topRoot = SceneLid.teethTop(shown: 0) - 72 + (72 - ChestLayout.gumRise - 6 + corner + 2) + 4
        #expect(topRoot < ChestLayout.lipBottom + ChestLayout.lipHeight)
        // The gum is a curve: lowest at the centre.
        #expect(SceneTextures.gumEdge(335) < SceneTextures.gumEdge(40))
        #expect(SceneLid.wakeTarget(stage: .biting, noise: 1) > 0.99)
        // The brow tilts angry: about 5° stirring, 12° waking.
        #expect(abs(SceneLid.browTarget(stage: .stirring) - 0.09) < 0.02)
        #expect(abs(SceneLid.browTarget(stage: .waking) - 0.21) < 0.02)
    }

    @Test func relicGlimmersOnlyWhenAlmostLit() {
        #expect(SceneLootView.glimmer(depth: 0.85, openness: 0.4, light: 0) == 0)
        #expect(SceneLootView.glimmer(depth: 0.85, openness: 0.7, light: 0) > 0.3)
        #expect(SceneLootView.glimmer(depth: 0.85, openness: 0.84, light: 0) >
                SceneLootView.glimmer(depth: 0.85, openness: 0.7, light: 0))
        // Once it is lit (revealed), the glimmer gives way to the real glint.
        #expect(SceneLootView.glimmer(depth: 0.85, openness: 0.95, light: 1) < 0.01)
        #expect(SceneLootView.glimmer(depth: .nan, openness: 0.5, light: 0) == 0)
    }

    @Test func candleCountdownReadsMinutesAndSeconds() {
        #expect(SceneFloorHUD.countdownText(remaining: 12, total: 100) == "0:12")
        #expect(SceneFloorHUD.countdownText(remaining: 4.2, total: 100) == "0:05")
        #expect(SceneFloorHUD.countdownText(remaining: Tuning.torchLowSeconds + 1, total: 100) == nil)
        #expect(SceneFloorHUD.countdownText(remaining: 0, total: 100) == nil)
        #expect(SceneFloorHUD.countdownText(remaining: 5, total: 0) == nil)
    }

    // MARK: The portrait

    @Test @MainActor func portraitFollowsItsInputs() {
        let p = MimicPortraitScene(size: CGSize(width: 300, height: 260))
        p.reduceMotion = true
        p.openness = 0
        p.wake = 0
        p.update(1)
        p.update(1.1)
        let shut = p.gap
        p.openness = 1
        p.update(1.2)
        #expect(p.gap > shut + 40)
        p.openness = 7
        #expect(p.openness <= 1)
        p.wake = 1
        for i in 0..<60 { p.update(1.3 + Double(i) / 60) }
        #expect(p.shownWake > 0.8)
        p.wake = .nan
        #expect(p.wake == 0)
        p.tier = .royal
        #expect(p.dress == .tier(.royal))
        p.golden = true
        #expect(p.dress == .golden)
        p.showsBackdrop = true
        p.size = CGSize(width: 120, height: 400)
        p.update(3)
        #expect(p.backgroundColor.cgColor.alpha < 0.01)
    }

    // MARK: The scene

    @Test @MainActor func sceneBuildsWithinBudget() {
        let scene = ChestScene(layout: ScreenLayout(hasFold: true))
        #expect(abs(scene.size.width - ScreenLayout.canvasWidth) < CGFloat(0.001))
        #expect(abs(scene.size.height - ScreenLayout.canvasHeight) < CGFloat(0.001))
        let driver = SceneFakeDriver()
        scene.driver = driver
        driver.startChest(SceneFakeDriver.chest(tier: .wooden, index: 0))
        var clock = 100.0
        SceneFakeDriver.run(scene, frames: 90, clock: &clock)
        driver.openTo(0.95)
        SceneFakeDriver.run(scene, frames: 60, clock: &clock)
        #expect(scene.visibleLoot >= 4)
        #expect(scene.drawnNodeCount <= 185)
        // R3: +16 mostly-hidden nodes (dress cross-fade, seal, chain tab, creak, relic card, rim sparkles).
        #expect(scene.nodeCount <= 350)
        #expect(scene.mimicName == "Snoring Sam")
        #expect(scene.plateSubline == "Snorer · Wooden")
        #expect(scene.plateSeal == "×1.5")
        #expect(scene.chestShellIsWhole)
    }

    @Test @MainActor func steadyFramesBuildNoTexturesAndFewEyePaths() {
        let scene = ChestScene(layout: SceneTests.phone)
        let driver = SceneFakeDriver()
        scene.driver = driver
        driver.startChest(SceneFakeDriver.chest(tier: .iron, index: 2))
        var clock = 10.0
        driver.openTo(0.6)
        driver.snap.torchTotal = 100
        driver.snap.torchRemaining = 12
        driver.hold(1)
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
        #expect(scene.browTilt > CGFloat(0.15))
    }

    @Test @MainActor func biteSlamsShakesEatsTheLootAndSaysWhatItCost() {
        for reduce in [false, true] {
            let scene = ChestScene(layout: ScreenLayout(hasFold: true))
            scene.reduceMotion = reduce
            let driver = SceneFakeDriver()
            scene.driver = driver
            driver.startChest(SceneFakeDriver.chest(tier: .wooden, index: 0))
            var clock = 0.0
            driver.openTo(0.9)
            driver.bag([0, 1])
            driver.snap.torchTotal = 100
            driver.snap.torchRemaining = 60
            SceneFakeDriver.run(scene, frames: 60, clock: &clock)
            driver.loseBag()
            driver.snap.phase = .bitten(elapsed: 0)
            driver.snap.stage = .biting
            driver.snap.noise = 1
            // biteCost may come before or after bitten in the frame.
            driver.pending = reduce
                ? [.stageChanged(from: .waking, to: .biting), .biteCost(lostValue: 164, seconds: 10),
                   .bitten(lostValue: 164)]
                : [.stageChanged(from: .waking, to: .biting), .bitten(lostValue: 164),
                   .biteCost(lostValue: 164, seconds: 10)]
            var maxShake: CGFloat = 0
            for _ in 0..<70 {
                SceneFakeDriver.run(scene, frames: 1, clock: &clock)
                maxShake = max(maxShake, abs(scene.shakeOffset.x) + abs(scene.shakeOffset.y))
            }
            #expect(scene.biteActive)
            #expect(scene.biteCalloutShowing)
            #expect(scene.biteLossText == "−164")
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
            // The chest hops, then only its interior goes dark (R3: it never leaves; the frame stays whole).
            SceneFakeDriver.run(scene, frames: 120, clock: &clock)
            #expect(scene.interiorShut > CGFloat(0.95))
            #expect(scene.chestShellIsWhole)
            #expect(!scene.biteCalloutShowing)
        }
    }

    @Test @MainActor func bankRollsTheCounterShowsTheRelicAndGrowsTheChain() {
        let scene = ChestScene(layout: SceneTests.phone)
        let driver = SceneFakeDriver()
        scene.driver = driver
        let spec = SceneFakeDriver.chest(tier: .gilded, index: 4)
        driver.startChest(spec)
        var clock = 0.0
        driver.openTo(0.95)
        driver.bag([0, 1, 2, 4])
        driver.snap.bagValue = 640
        SceneFakeDriver.run(scene, frames: 60, clock: &clock)
        #expect(!scene.chainBadgeShowing)
        driver.openTo(0.05)
        driver.snap.shutHold = 1
        driver.snap.phase = .banked(elapsed: 0)
        driver.snap.banked = 640
        driver.snap.bagValue = 0
        driver.snap.chain = 2
        driver.snap.chainMultiplier = 1.2
        var events: [HeistEvent] = [.banked(value: 640, items: 4, hushed: true), .chainUp(count: 2, multiplier: 1.2)]
        if let r = RelicCatalog.all.first { events.append(.relicFound(r.id)) }
        driver.pending = events
        SceneFakeDriver.run(scene, frames: 2, clock: &clock)
        #expect(scene.bankActive)
        #expect(scene.shownBanked < 640)
        // The stack's third line, centred: the chain.
        #expect(scene.bankSubline == "Hush Chain ×1.2")
        SceneFakeDriver.run(scene, frames: 200, clock: &clock)
        if !RelicCatalog.all.isEmpty {
            #expect(scene.relicBannerShowing)
            #expect(scene.relicCardFullyShown)
        }
        #expect(scene.chainBadgeShowing)
        #expect(scene.chainTabText == "GOLD ×1.2")
        SceneFakeDriver.run(scene, frames: 150, clock: &clock)
        #expect(scene.shownBanked == 640)
        // R3 (P0-1): between chests only the interior is dark; the frame, front wall and lock stay.
        #expect(scene.interiorShut > CGFloat(0.95))
        #expect(scene.chestShellIsWhole)
        #expect(abs(scene.chestOffset) < CGFloat(0.5))
        // A stir breaks the chain: it cracks, then goes.
        driver.snap.chain = 0
        driver.snap.chainMultiplier = 1
        driver.pending = [.chainBroken(count: 2)]
        SceneFakeDriver.run(scene, frames: 3, clock: &clock)
        #expect(scene.chainCracking)
        SceneFakeDriver.run(scene, frames: 150, clock: &clock)
        #expect(!scene.chainBadgeShowing)
    }

    @Test @MainActor func arrivalSlidesInAndDressesTheChestAndPlate() {
        let scene = ChestScene(layout: ScreenLayout(hasFold: true))
        let driver = SceneFakeDriver()
        scene.driver = driver
        var clock = 0.0
        driver.startChest(SceneFakeDriver.chest(tier: .royal, index: 7, name: "Dozy Dora"))
        SceneFakeDriver.run(scene, frames: 6, clock: &clock)
        // R3: the chest is there at once; its interior's shadow lifts.
        #expect(scene.interiorShut > CGFloat(0.5))
        #expect(scene.chestShellIsWhole)
        SceneFakeDriver.run(scene, frames: 120, clock: &clock)
        #expect(abs(scene.chestOffset) < CGFloat(1))
        #expect(scene.interiorShut < CGFloat(0.01))
        #expect(scene.floorTier == .royal)
        #expect(scene.mimicName == "Dozy Dora")
        #expect(scene.plateSubline.contains("Royal"))
        // A golden mimic is dressed in gold leaf.
        var gold = SceneFakeDriver.chest(tier: .iron, index: 8, name: "Wary Wendell")
        gold.golden = true
        gold.mimic = .lightSleeper
        driver.startChest(gold)
        SceneFakeDriver.run(scene, frames: 30, clock: &clock)
        #expect(scene.dress == .golden)
        #expect(scene.plateSubline == "GOLDEN MIMIC · Light sleeper")
        #expect(scene.plateSeal == "×1.5")
        #expect(scene.chestShellIsWhole)
    }

    @Test @MainActor func relicGlimmersAndThePouchGlowsWhileHolding() {
        let scene = ChestScene(layout: ScreenLayout(hasFold: true))
        let driver = SceneFakeDriver()
        scene.driver = driver
        driver.startChest(SceneFakeDriver.chest(tier: .iron, index: 3))
        var clock = 0.0
        driver.openTo(0.3)
        SceneFakeDriver.run(scene, frames: 20, clock: &clock)
        #expect(scene.glimmeringRelics == 0)
        driver.openTo(0.72)
        SceneFakeDriver.run(scene, frames: 20, clock: &clock)
        #expect(scene.glimmeringRelics >= 1)
        #expect(scene.pouchGlow < CGFloat(0.05))
        driver.hold(1)
        SceneFakeDriver.run(scene, frames: 40, clock: &clock)
        #expect(scene.pouchGlow > CGFloat(0.4))
    }

    @Test @MainActor func candleBurnsDownCountsDownThenTheDarkClosesIn() {
        let scene = ChestScene(layout: SceneTests.phone)
        let driver = SceneFakeDriver()
        scene.driver = driver
        driver.startChest(SceneFakeDriver.chest(tier: .wooden, index: 0))
        var clock = 0.0
        driver.snap.torchTotal = 100
        driver.snap.torchRemaining = 50
        SceneFakeDriver.run(scene, frames: 10, clock: &clock)
        #expect(abs(scene.torchFraction - CGFloat(0.5)) < CGFloat(0.01))
        #expect(scene.candleCountdown == nil)
        driver.snap.torchRemaining = 12
        driver.pending = [.torchLow, .oilAdded(seconds: 6)]
        SceneFakeDriver.run(scene, frames: 30, clock: &clock)
        #expect(scene.candleCountdown == "0:12")
        driver.snap.torchRemaining = 0
        driver.snap.phase = .torchOut(elapsed: 0)
        driver.pending = [.torchOut]
        SceneFakeDriver.run(scene, frames: 280, clock: &clock)
        #expect(scene.torchOutLevel > CGFloat(0.99))
        #expect(scene.candleCountdown == nil)
        // A new session clears it.
        scene.reset()
        driver.snap = HeistSnapshot()
        SceneFakeDriver.run(scene, frames: 2, clock: &clock)
        #expect(scene.torchOutLevel < CGFloat(0.01))
    }

    @Test @MainActor func everyEventIsDrawnWithoutADriverHiccup() {
        let scene = ChestScene(layout: SceneTests.phone)
        scene.turned = true
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
            .oilAdded(seconds: 6), .stageChanged(from: .asleep, to: .stirring), .dreamTwitch, .newBest, .torchLow,
            .relicFound(relic), .chainUp(count: 1, multiplier: 1.1), .chainBroken(count: 3),
            .biteCost(lostValue: 0, seconds: 10), .finished,
        ]
        for e in all {
            driver.pending = [e]
            SceneFakeDriver.run(scene, frames: 8, clock: &clock)
        }
        // The slider on the lid (and in the extension above it) reaches the driver.
        scene.beginTouch(9, canvas: CGPoint(x: 606, y: 700), time: 1)
        scene.moveTouch(9, canvas: CGPoint(x: 606, y: 1000), time: 1.1)
        scene.endTouch(9, canvas: CGPoint(x: 606, y: 1000), time: 1.2)
        #expect(driver.sliderTouches == 3)
        #expect(driver.lastFraction > 0.6)
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

    // MARK: R3

    /// Juror P0-1: the bank never blacks out the floor. On every tier (and the golden mimic), on the Duo and on a
    /// phone, through the bank, the empty beat after it and the next arrival, the frame, front wall and lock are whole.
    @Test @MainActor func bankDarkensOnlyTheInteriorOnEveryTier() {
        var dresses: [(ChestTier, Bool)] = []
        for t in ChestTier.allCases { dresses.append((t, false)) }
        dresses.append((.iron, true))
        for layout in [ScreenLayout(hasFold: true), SceneTests.phone] {
            for (tier, golden) in dresses {
                let scene = ChestScene(layout: layout)
                let driver = SceneFakeDriver()
                scene.driver = driver
                var spec = SceneFakeDriver.chest(tier: tier, index: 3)
                spec.golden = golden
                driver.startChest(spec)
                var clock = 0.0
                driver.openTo(0.9)
                driver.bag([0, 1])
                driver.snap.bagValue = 50
                SceneFakeDriver.run(scene, frames: 60, clock: &clock)
                driver.openTo(0)
                driver.snap.phase = .banked(elapsed: 0)
                driver.snap.banked = 50
                driver.snap.bagValue = 0
                driver.pending = [.banked(value: 50, items: 2, hushed: true)]
                var whole = true
                for _ in 0..<260 {
                    SceneFakeDriver.run(scene, frames: 1, clock: &clock)
                    whole = whole && scene.chestShellIsWhole
                }
                #expect(whole)
                #expect(scene.interiorShut > CGFloat(0.95))
                // The next chest (another tier): the dress cross-fades, the interior lights again.
                let next = SceneFakeDriver.chest(tier: tier == .royal ? .wooden : .royal, index: 4, name: "Next Ned")
                driver.startChest(next)
                for _ in 0..<120 {
                    SceneFakeDriver.run(scene, frames: 1, clock: &clock)
                    whole = whole && scene.chestShellIsWhole
                }
                #expect(whole)
                #expect(scene.interiorShut < CGFloat(0.01))
            }
        }
    }

    /// The founder's CREAK rule: the scene draws it only when the App calls `showCreak()` (Feel's accent), never from
    /// the noise alone; it shakes (not under Reduce Motion) and flashes the meter red; a bite overrides it.
    @Test @MainActor func creakShowsOnlyWhenAskedAndRespectsReduceMotion() {
        for reduce in [false, true] {
            let scene = ChestScene(layout: ScreenLayout(hasFold: true))
            scene.reduceMotion = reduce
            let driver = SceneFakeDriver()
            scene.driver = driver
            driver.startChest(SceneFakeDriver.chest(tier: .wooden, index: 0))
            var clock = 0.0
            driver.openTo(0.5)
            SceneFakeDriver.run(scene, frames: 30, clock: &clock)
            // A scripted noise jump with the lid still (the lesson's stir) draws no creak.
            driver.snap.noise = 0.6
            driver.snap.stage = .stirring
            SceneFakeDriver.run(scene, frames: 20, clock: &clock)
            #expect(scene.creakCount == 0)
            #expect(!scene.creakShowing)
            scene.showCreak()
            var maxShake: CGFloat = 0
            var flash: CGFloat = 0
            for _ in 0..<20 {
                SceneFakeDriver.run(scene, frames: 1, clock: &clock)
                maxShake = max(maxShake, abs(scene.shakeOffset.x) + abs(scene.shakeOffset.y))
                flash = max(flash, scene.meterFlash)
            }
            #expect(scene.creakShowing)
            #expect(scene.creakCount == 1)
            #expect(flash > CGFloat(0.3))
            if reduce { #expect(maxShake < CGFloat(0.001)) } else { #expect(maxShake > CGFloat(1)) }
            SceneFakeDriver.run(scene, frames: 120, clock: &clock)
            #expect(!scene.creakShowing)
            #expect(scene.meterFlash < CGFloat(0.01))
            // During a bite, the bite speaks.
            driver.snap.phase = .bitten(elapsed: 0)
            driver.pending = [.bitten(lostValue: 10)]
            SceneFakeDriver.run(scene, frames: 2, clock: &clock)
            scene.showCreak()
            SceneFakeDriver.run(scene, frames: 2, clock: &clock)
            #expect(scene.creakCount == 1)
        }
    }

    /// Decision 4 and the lid collisions: a fold layout never draws or uses the lever; on a phone the lever is in the
    /// lid's right edge band, above the lip and teeth, clear of the plate, and the teaching slot is above the brow.
    @Test @MainActor func leverStaysOffTheFoldAndClearOfTheFace() {
        let duo = ChestScene(layout: ScreenLayout(hasFold: true))
        let d1 = SceneFakeDriver()
        d1.usesSlider = true
        duo.driver = d1
        d1.startChest(SceneFakeDriver.chest(tier: .wooden, index: 0))
        var clock = 0.0
        SceneFakeDriver.run(duo, frames: 5, clock: &clock)
        #expect(!duo.leverShowing)
        duo.beginTouch(3, canvas: CGPoint(x: ChestLayout.sliderX, y: 700), time: 1)
        duo.endTouch(3, canvas: CGPoint(x: ChestLayout.sliderX, y: 800), time: 1.1)
        #expect(d1.sliderTouches == 0)
        let phone = ChestScene(layout: SceneTests.phone)
        let d2 = SceneFakeDriver()
        d2.usesSlider = true
        phone.driver = d2
        SceneFakeDriver.run(phone, frames: 5, clock: &clock)
        #expect(phone.leverShowing)
        // Geometry (canvas): above the lip, right of the plate, inside the edge inset.
        let track = ChestLayout.leverTrack
        let lipTop = ChestLayout.lidBottom + ChestLayout.lipBottom + ChestLayout.lipHeight
        #expect(track.minY > lipTop)
        let plateRight = ChestLayout.plateCenter.x + ChestLayout.plateSize.width / 2
        #expect(ChestLayout.sliderX - ChestLayout.sliderKnobSize.width / 2 > plateRight)
        #expect(ChestLayout.sliderX + ChestLayout.sliderKnobSize.width / 2 <= ScreenLayout.canvasWidth - 16)
        #expect(ChestLayout.sliderMaxY - ChestLayout.sliderMinY < CGFloat(300))
        // The teaching slot sits above the brow plate, inside the canvas.
        let slot = ChestLayout.lidLabelSlot
        #expect(slot.minY - ChestLayout.lidBottom > ChestLayout.browCenter.y + ChestLayout.browHalf.height / 2)
        #expect(slot.maxY <= ScreenLayout.canvasHeight)
        #expect(slot.minX >= 16 && slot.maxX <= ScreenLayout.canvasWidth - 16)
    }

    /// The tongue keeps its fill and loses its groove in the dark (no dome with a seam, no hollow U).
    @Test @MainActor func tongueGrooveOnlyWhenLit() {
        let scene = ChestScene(layout: ScreenLayout(hasFold: true))
        let driver = SceneFakeDriver()
        scene.driver = driver
        driver.startChest(SceneFakeDriver.chest(tier: .wooden, index: 0))
        var clock = 0.0
        SceneFakeDriver.run(scene, frames: 30, clock: &clock)
        #expect(scene.tongueCrease < CGFloat(0.01))
        driver.openTo(1)
        SceneFakeDriver.run(scene, frames: 30, clock: &clock)
        #expect(scene.tongueCrease > CGFloat(0.3))
        driver.snap.stage = .waking
        driver.snap.noise = 0.85
        SceneFakeDriver.run(scene, frames: 120, clock: &clock)
        #expect(scene.tongueCurl > CGFloat(0.8))
        #expect(scene.tongueCrease < CGFloat(0.2))
        // The tongue tapers to a point at the bag end.
        let p = SceneTextures.tonguePath(SceneTextures.tongueSize)
        let s = SceneTextures.tongueSize
        #expect(p.contains(CGPoint(x: s.width / 2, y: s.height * 0.05)))
        #expect(!p.contains(CGPoint(x: s.width * 0.4, y: s.height * 0.05)))
        #expect(p.contains(CGPoint(x: s.width * 0.2, y: s.height * 0.9)))
    }

    /// Decision 5: one in-world plate style for every card (parchment / leather / urgent), legible ink, nine-slice
    /// insets, and drawn glyphs instead of SF Symbols.
    @Test func platesAndGlyphsRender() {
        for style in PlateStyle.allCases {
            let size = CGSize(width: 300, height: 60)
            let img = ChestArt.plateImage(size: size, style: style, scale: 2)
            #expect(img != nil)
            if let img { #expect(img.width == 600 && img.height == 120) }
            #expect(ChestArt.plateImage(size: size, style: style, scale: 2) === img)
            let path = ChestArt.platePath(size: size)
            #expect(!path.isEmpty)
            #expect(CGRect(origin: .zero, size: size).contains(path.boundingBoxOfPath))
            let c = ChestArt.plateColors(style)
            #expect(ScenePaint.contrast(c.text, c.fill) >= 4.5)
            #expect(ScenePaint.contrast(c.text, c.fillDark) >= 4.5)
            #expect(ScenePaint.contrast(c.accent, c.fill) >= 3)
            let ins = ChestArt.plateInsets(style)
            #expect(ins.left + ins.right < 120 && ins.top + ins.bottom < 56)
            #expect(ChestArt.plateSliceImage(style: style) != nil)
        }
        for g in PlateGlyph.allCases {
            let img = ChestArt.glyphImage(g, side: 40, scale: 2)
            #expect(img != nil)
            if let img { #expect(SceneTests.opaqueFraction(img) > 0.08) }
        }
    }

    /// Decision 6: the icon is opaque (no alpha channel), in the game's style, and reads at 60 px: a bright warm eye
    /// against a dark dungeon corner.
    @Test func appIconIsOpaqueAndReadsSmall() {
        let big = ChestArt.appIcon(size: 1024)
        #expect(big.width == 1024 && big.height == 1024)
        let opaqueKinds: [CGImageAlphaInfo] = [.none, .noneSkipLast, .noneSkipFirst]
        #expect(opaqueKinds.contains(big.alphaInfo))
        for side in [60, 120] {
            let img = ChestArt.appIcon(size: CGFloat(side))
            #expect(img.width == side && img.height == side)
            #expect(opaqueKinds.contains(img.alphaInfo))
            let px = SceneTests.pixels(img)
            // The iris (art units 536, 572 → pixels; rows count from the top).
            let k = Double(side) / 1024
            let ex = Int(536 * k), ey = side - 1 - Int(572 * k)
            let eye = px.rgb(ex, ey)
            let corner = px.rgb(2, 2)
            let le = ScenePaint.luminance(RGBA(eye.0, eye.1, eye.2))
            let lc = ScenePaint.luminance(RGBA(corner.0, corner.1, corner.2))
            #expect((le + 0.05) / (lc + 0.05) >= 3)
            #expect(eye.0 > eye.2)
            // Not a flat image: plenty of tonal range.
            #expect(px.lumaSpread > 0.3)
        }
    }

    /// Juror P1-11: the cover portrait peeks every few seconds (not under Reduce Motion) and draws bigger.
    @Test @MainActor func coverPortraitPeeks() {
        for reduce in [false, true] {
            let p = MimicPortraitScene(size: CGSize(width: 300, height: 300))
            p.reduceMotion = reduce
            p.applyCoverStyle()
            #expect(p.idlePeek)
            #expect(p.artScale > CGFloat(1.1))
            var peak: CGFloat = 0
            for i in 0..<(60 * 8) {
                p.update(Double(i) / 60)
                peak = max(peak, p.peekLevel)
            }
            if reduce { #expect(peak < CGFloat(0.01)) } else { #expect(peak > CGFloat(0.5)) }
        }
    }

    // MARK: Pixel helpers

    struct Pixels {
        let width: Int
        let height: Int
        let data: [UInt8]
        /// (r, g, b) 0…1 at (x, y), y counted from the top.
        func rgb(_ x: Int, _ y: Int) -> (Double, Double, Double) {
            let cx = min(max(x, 0), width - 1), cy = min(max(y, 0), height - 1)
            let i = (cy * width + cx) * 4
            return (Double(data[i]) / 255, Double(data[i + 1]) / 255, Double(data[i + 2]) / 255)
        }
        var lumaSpread: Double {
            var lo = 1.0, hi = 0.0
            for y in stride(from: 0, to: height, by: 2) {
                for x in stride(from: 0, to: width, by: 2) {
                    let c = rgb(x, y)
                    let l = 0.2126 * c.0 + 0.7152 * c.1 + 0.0722 * c.2
                    lo = min(lo, l)
                    hi = max(hi, l)
                }
            }
            return hi - lo
        }
    }

    static func pixels(_ img: CGImage) -> Pixels {
        let w = img.width, h = img.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        data.withUnsafeMutableBytes { buf in
            if let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                   space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
            }
        }
        return Pixels(width: w, height: h, data: data)
    }

    /// The share of pixels with alpha > 0.5.
    static func opaqueFraction(_ img: CGImage) -> Double {
        let px = pixels(img)
        var n = 0
        for i in stride(from: 3, to: px.data.count, by: 4) where px.data[i] > 128 { n += 1 }
        return Double(n) / Double(max(px.width * px.height, 1))
    }
}

/// Reads a `SceneLabel`'s clamped size (it must be made on the main actor).
enum SceneLabelProbe {
    @MainActor static func make(size: CGFloat, minimum: CGFloat? = nil) -> CGFloat {
        if let m = minimum { return SceneLabel(size: size, color: .white, minimumSize: m).size }
        return SceneLabel(size: size, color: .white).size
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
    private(set) var lastBegan: CGPoint?
    private(set) var ended = 0
    private(set) var sliderTouches = 0
    private(set) var lastFraction: Double = 0

    func advance(dt: TimeInterval, now: TimeInterval) -> (HeistSnapshot, [HeistEvent]) {
        if !frozen { snap.time += dt }
        let e = pending
        pending = []
        return (snap, e)
    }

    func floorTouchBegan(_ id: Int, at point: CGPoint, time: TimeInterval) {
        floorTouches += 1
        lastBegan = point
    }

    func floorTouchMoved(_ id: Int, to point: CGPoint, time: TimeInterval) { floorTouches += 1 }

    func floorTouchEnded(_ id: Int, at point: CGPoint, time: TimeInterval) {
        floorTouches += 1
        ended += 1
    }

    func sliderTouch(began: Bool, ended: Bool, fraction: Double, time: TimeInterval) {
        sliderTouches += 1
        lastFraction = fraction
    }

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

    static func run(_ scene: SKScene, frames: Int, clock: inout Double) {
        for _ in 0..<max(frames, 0) {
            scene.update(clock)
            clock += 1.0 / 120.0
        }
    }
}

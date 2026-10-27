import CoreGraphics
import Foundation
import SpriteKit
import UIKit
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
        // The pause coin sits in its seat (the frame draws no corner bracket there; R4: a round seat, coin + 4 pt).
        #expect(pause.width / 2 <= ChestLayout.pauseSocketRadius)
        #expect(ChestLayout.pauseSocketRadius - ChestLayout.pauseCoinViewDiameter / 2 >= CGFloat(3.9))
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
        // The golden plate says Golden (R4: one casing), and the seal shows the real payout (QA-2 P2-8: tier × 2);
        // the pop over its loot is the same number (R4, UX P2-3).
        #expect(ChestCopy.plateSubline(c) == "Golden · Light sleeper")
        #expect(ChestCopy.plateSeal(c) == "×3")
        #expect(ChestCopy.goldenPop(c) == "×3")
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
        let th = ChestLayout.teethTextureHeight
        let topRoot = SceneLid.teethTop(shown: 0) - th + (th - ChestLayout.gumRise - 6 + corner + 2) + 4
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
        // R3: +16 mostly-hidden nodes (dress cross-fade, seal, chain tab, creak, relic card, rim sparkles). R4: +4
        // (the pause seat, "Next chest…", the extension plaque and its words).
        #expect(scene.nodeCount <= 360)
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
        #expect(scene.chainTabText == "CHAIN ×1.2")
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
        #expect(scene.plateSubline == "Golden · Light sleeper")
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

    // MARK: R4

    /// Item 1 (juror P0-1, UX P1-1): plate text lies inside the stitched border and ≥ 8 pt clear of both brass
    /// end-caps, for drawn plates of every size and for stretched slices; the slice insets cover a cap + 8 pt; the
    /// longest hint fits the hint band's plate on one line at ≥ 0.7 scale.
    @Test func plateTextStaysInsideTheStitchAndClearOfTheCaps() {
        let sizes = [CGSize(width: 464, height: 48), CGSize(width: 300, height: 60), CGSize(width: 120, height: 44),
                     CGSize(width: 380, height: 250), CGSize(width: 220, height: 34), CGSize(width: 560, height: 96),
                     CGSize(width: 120, height: 56)]
        for style in PlateStyle.allCases {
            for size in sizes {
                let t = ChestArt.plateTextRect(in: size, style: style)
                #expect(t.width > CGFloat(10) && t.height > CGFloat(8))
                // Symmetric (so y-up and y-down agree).
                #expect(abs(t.midX - size.width / 2) < CGFloat(0.01))
                #expect(abs(t.midY - size.height / 2) < CGFloat(0.01))
                // Inside the stitch line (half its 1.6 pt width plus room to spare).
                let stitch = ChestArt.plateStitchRect(size: size).insetBy(dx: 2.8, dy: 1.5)
                #expect(stitch.contains(t))
                // ≥ 8 pt clear of each cap as drawn, and of a stretched slice's 16 pt cap.
                for cap in ChestArt.plateCapRects(size: size) {
                    #expect(!cap.insetBy(dx: -8, dy: 0).intersects(t))
                }
                if size.height >= 34 {
                    #expect(t.minX >= CGFloat(1 + 16 + 8) - 0.001)
                    #expect(t.maxX <= size.width - CGFloat(1 + 16 + 8) + 0.001)
                }
            }
            // The nine-slice insets cover the slice's brass cap (x 1…17) plus 8 pt.
            let ins = ChestArt.plateInsets(style)
            let capW = ChestArt.plateCapWidth(CGSize(width: 120, height: 56))
            #expect(ins.left >= 1 + capW + 8 && ins.right >= 1 + capW + 8)
        }
        // A degenerate size never makes an empty or inverted rect.
        let tiny = ChestArt.plateTextRect(in: CGSize(width: 10, height: 6), style: .parchment)
        #expect(tiny.width >= 1 && tiny.height >= 1)
        let odd = ChestArt.plateTextRect(in: CGSize(width: CGFloat.nan, height: 40), style: .leather)
        #expect(odd.width >= 1 && odd.minX.isFinite)
        // The longest hints fit the hint band's plate on one line (font ≈ 80 % of the text height, scale ≥ 0.7).
        let text = ChestArt.plateTextRect(in: ChestLayout.hintBand.size, style: .parchment)
        let font = UIFont.systemFont(ofSize: text.height * 0.8, weight: .heavy)
        for hint in ["Hush Chain! Sleepy banks pay more", "Slide the lever down to bank", "Drag the loot into your bag",
                     "Something glints deeper…"] {
            let w = (hint as NSString).size(withAttributes: [.font: font]).width
            #expect(w * 0.7 <= text.width)
        }
    }

    /// Item 3 (juror P1-2): the pause coin's seat sits under the App's coin at every device scale, ≥ 16 screen pt
    /// from the edge, on no bracket, and never touches the hint band, the meter or the HUD.
    @Test @MainActor func pauseSeatIsClearOfEverything() {
        let hint = ChestLayout.hintBand
        let scales: [CGFloat] = [ChestLayout.minViewScale, 0.56, 0.587, 0.6, 0.657, 1.0]
        for s in scales {
            let seat = ChestLayout.pauseSeat(viewScale: s)
            let c = ChestLayout.pauseCenter(viewScale: s)
            // The App's coin: 55 pt; its 56 pt tap frame keeps 16 pt from the screen edge.
            let coinR = ChestLayout.pauseCoinViewDiameter / 2 / s
            #expect((ScreenLayout.canvasWidth - c.x - ChestLayout.pauseTapViewSide / 2 / s) * s >= CGFloat(15.99))
            #expect((ScreenLayout.canvasWidth - c.x - coinR) * s >= CGFloat(15.99))
            #expect(seat.width / 2 > coinR)
            // Never touching the hint plate's band (≥ 8 pt), the meter, the HUD, the chain tab.
            #expect(seat.minX - hint.maxX >= CGFloat(7.99))
            #expect(!seat.intersects(ChestLayout.meterRect))
            for r in ChestLayout.hudRects { #expect(!seat.intersects(r)) }
            // Inside the floor half (at the smallest phone scale it may kiss the fold strip's edge, by < 2 pt).
            #expect(seat.minY > ChestLayout.counterRect.maxY)
            #expect(seat.maxY <= ScreenLayout.foldMinY + 2)
            // Not on the front-right bracket (the back-right corner has none).
            #expect(!seat.intersects(CGRect(x: ChestLayout.frontRightBracketMinX, y: 104, width: 76, height: 76)))
        }
        // On the Duo the coin is right of the loot and exactly on the pause area.
        let duo = ChestLayout.pauseCenter(viewScale: 1)
        #expect(duo.x - ChestLayout.pauseCoinViewDiameter / 2 >= FloorSpace.interior.maxX)
        #expect(abs(duo.x - ChestLayout.pauseArea.midX) < CGFloat(0.01))
        // The scene draws the seat where the layout says, at the scale it is shown at.
        let scene = ChestScene(layout: SceneTests.phone)
        scene.viewScale = 0.6
        let want = ChestLayout.pauseSeat(viewScale: 0.6)
        #expect(abs(scene.pauseSeatRect.midX - want.midX) < CGFloat(0.5))
        #expect(abs(scene.pauseSeatRect.width - want.width) < CGFloat(0.5))
        scene.viewScale = .nan
        #expect(abs(scene.viewScale - 1) < CGFloat(0.001))
        let k = ChestScene.scaleFor(view: CGSize(width: 402, height: 874), scene: CGSize(width: 670, height: 1457))
        #expect(abs(k - CGFloat(0.6)) < CGFloat(0.01))
    }

    /// Item 2 (UX P1-2, testers 7 and 8): the chain tab fits its text column, sits left of the bracket with ≥ 16 screen
    /// pt to the edge, and shows the LAST bank's multiplier (the bank stack's number) from that bank's frame. Not in
    /// the lesson. R5: one line, "CHAIN ×1.1".
    @Test @MainActor func chainTabShowsTheLastBanksMultiplierInsideTheFrame() {
        let tab = ChestLayout.chainRect
        #expect(tab.maxX <= ChestLayout.frontRightBracketMinX)
        #expect((ScreenLayout.canvasWidth - tab.maxX) * ChestLayout.minViewScale >= 16)
        #expect(tab.minX > ChestLayout.meterRect.maxX)
        #expect(tab.contains(ChestLayout.chainTextRect))
        #expect(ChestLayout.chainTextRect.minX >= ChestLayout.chainCenter.x + ChestLayout.chainRadius)
        let inPlate = ChestArt.plateTextRect(in: tab.size, style: .leather)
        #expect(ChestLayout.chainTextRect.maxX <= tab.minX + inPlate.maxX + 0.001)
        #expect(SceneFloorHUD.chainText(1.2) == "CHAIN ×1.2")
        #expect(SceneFloorHUD.chainShown(chain: 0, lastBank: 1.4) == nil)
        let derived = SceneFloorHUD.chainShown(chain: 3, lastBank: nil) ?? 0
        #expect(abs(derived - Noise.chainMultiplier(3)) < 0.001)

        for lesson in [false, true] {
            let scene = ChestScene(layout: SceneTests.phone)
            let driver = SceneFakeDriver()
            scene.driver = driver
            driver.snap.mode = lesson ? .lesson : .run
            driver.startChest(SceneFakeDriver.chest(tier: .wooden, index: 0))
            var clock = 0.0
            driver.openTo(0.9)
            driver.bag([0, 1])
            driver.snap.bagValue = 100
            SceneFakeDriver.run(scene, frames: 30, clock: &clock)
            // The first Hushed bank pays ×1.1; the snapshot already says the NEXT bank would pay ×1.2.
            driver.openTo(0)
            driver.snap.phase = .banked(elapsed: 0)
            driver.snap.banked = 110
            driver.snap.bagValue = 0
            driver.snap.chain = 1
            driver.snap.chainMultiplier = 1.2
            driver.pending = [.banked(value: 110, items: 2, hushed: true), .chainUp(count: 1, multiplier: 1.1)]
            SceneFakeDriver.run(scene, frames: 1, clock: &clock)
            if lesson {
                SceneFakeDriver.run(scene, frames: 90, clock: &clock)
                #expect(!scene.chainBadgeShowing)
                #expect(!scene.bankSublineShowing)
                continue
            }
            #expect(scene.chainTabText == "CHAIN ×1.1")
            SceneFakeDriver.run(scene, frames: 70, clock: &clock)
            #expect(scene.bankSublineShowing)
            #expect(scene.bankSubline == "Hush Chain ×1.1")
            #expect(scene.chainTabText == "CHAIN ×1.1")
            #expect(scene.chainBadgeShowing)
            let widths = scene.chainTextWidths
            #expect(widths.count == 1)
            for w in widths { #expect(w <= ChestLayout.chainTextRect.width + 0.5) }
            // The next bank: ×1.2, in the same frame for both.
            driver.snap.chain = 2
            driver.snap.chainMultiplier = 1.3
            driver.pending = [.banked(value: 60, items: 1, hushed: true), .chainUp(count: 2, multiplier: 1.2)]
            SceneFakeDriver.run(scene, frames: 1, clock: &clock)
            #expect(scene.chainTabText == "CHAIN ×1.2")
            #expect(scene.bankSubline == "Hush Chain ×1.2")
        }
    }

    /// Item 6 (UX P2-6): the meter's word follows the stage and fits its recess.
    @Test @MainActor func meterWordFollowsTheStage() {
        #expect(ChestCopy.meterWord(.asleep) == "NOISE")
        #expect(ChestCopy.meterWord(.stirring) == "STIRRING")
        #expect(ChestCopy.meterWord(.waking) == "WAKING!")
        #expect(ChestCopy.meterWord(.biting) == "WAKING!")
        let scene = ChestScene(layout: ScreenLayout(hasFold: true))
        let driver = SceneFakeDriver()
        scene.driver = driver
        driver.startChest(SceneFakeDriver.chest(tier: .wooden, index: 0))
        var clock = 0.0
        let steps: [(MimicStage, String)] = [(.asleep, "NOISE"), (.stirring, "STIRRING"), (.waking, "WAKING!"),
                                             (.asleep, "NOISE")]
        for (stage, word) in steps {
            driver.snap.stage = stage
            SceneFakeDriver.run(scene, frames: 2, clock: &clock)
            #expect(scene.meterWord == word)
            #expect(scene.meterWordWidth <= ChestLayout.meterLabelWidth + 0.5)
        }
        // The shorter meter still ends in its teeth, clear of the well.
        #expect(ChestLayout.meterTeethCenter.x + 20 <= ChestLayout.meterRect.maxX)
        #expect(ChestLayout.meterWell.maxX < ChestLayout.meterTeethCenter.x - 20)
    }

    /// Item 4 (UX P2-4, tester 8): the bank beat dims the interior to about 40 % (never black) and says "Next chest…",
    /// on every tier and the golden mimic, on the Duo and a phone; not in the lesson.
    @Test @MainActor func bankBeatDimsTheInteriorAndSaysNextChest() {
        var dresses: [(ChestTier, Bool)] = ChestTier.allCases.map { ($0, false) }
        dresses.append((.gilded, true))
        for layout in [ScreenLayout(hasFold: true), SceneTests.phone] {
            for (tier, golden) in dresses {
                let lessons: [Bool] = tier == .wooden && !golden ? [false, true] : [false]
                for lesson in lessons {
                    let scene = ChestScene(layout: layout)
                    let driver = SceneFakeDriver()
                    scene.driver = driver
                    driver.snap.mode = lesson ? .lesson : .run
                    var spec = SceneFakeDriver.chest(tier: tier, index: 2)
                    spec.golden = golden
                    driver.startChest(spec)
                    var clock = 0.0
                    driver.openTo(0.9)
                    driver.bag([0])
                    driver.snap.bagValue = 20
                    SceneFakeDriver.run(scene, frames: 60, clock: &clock)
                    driver.openTo(0)
                    driver.snap.phase = .banked(elapsed: 0)
                    driver.snap.banked = 20
                    driver.snap.bagValue = 0
                    driver.pending = [.banked(value: 20, items: 1, hushed: false)]
                    var sawNext = false
                    var minLight: CGFloat = 1
                    for _ in 0..<200 {
                        SceneFakeDriver.run(scene, frames: 1, clock: &clock)
                        sawNext = sawNext || scene.nextChestShowing
                        minLight = min(minLight, scene.interiorLight)
                    }
                    // About 40 % of the light stays; the floor's own lid-shut darkness is lifted under the shadow.
                    #expect(minLight > CGFloat(0.3) && minLight < CGFloat(0.5))
                    #expect(scene.interiorDarkness < CGFloat(0.05))
                    #expect(scene.interiorShut > CGFloat(0.95))
                    #expect(sawNext == !lesson)
                    #expect(scene.chestShellIsWhole)
                    // The next chest: the shadow lifts and the words go.
                    driver.startChest(SceneFakeDriver.chest(tier: .iron, index: 3))
                    SceneFakeDriver.run(scene, frames: 120, clock: &clock)
                    #expect(!scene.nextChestShowing)
                    #expect(scene.interiorLight > CGFloat(0.99))
                }
            }
        }
    }

    /// Item 5 (juror): the gum is a curved lip at every stage: the lower edge dips ≥ 10 pt at the centre, the top
    /// edge sags too, the band stays thick, no fang root ever shows above the lip, and every fang fits its texture.
    @Test func gumIsACurvedLipAtEveryStage() {
        #expect(SceneTextures.gumEdge(0) - SceneTextures.gumEdge(335) >= CGFloat(10))
        let h = ChestLayout.lipHeight + 4
        #expect(SceneTextures.lipTopEdge(0, height: h) - SceneTextures.lipTopEdge(335, height: h) >= CGFloat(4))
        #expect(abs(SceneTextures.lipTopEdge(0, height: h) - h) < CGFloat(0.001))
        for x in stride(from: CGFloat(0), through: 670, by: 10) {
            #expect(SceneTextures.lipTopEdge(x, height: h) - (4 + SceneTextures.gumEdge(x)) >= CGFloat(24))
        }
        let stages: [MimicStage] = [.asleep, .stirring, .waking, .biting]
        for stage in stages {
            let top = SceneLid.teethTop(shown: SceneLid.teethTarget(stage: stage, noise: 0.8))
            for f in SceneTextures.fangSpec {
                // The fang's base corners (+4) and outline (+3), lid-local, under the lip's top at both corners.
                let root = top - ChestLayout.gumRise - 4 + SceneTextures.gumEdge(f.x) + 7
                for x in [f.x - f.half, f.x + f.half] {
                    let lipTop = ChestLayout.lipBottom - 4 + SceneTextures.lipTopEdge(x, height: h)
                    #expect(root < lipTop)
                }
                // Fully bared, the tip still lies inside the fangs texture.
                let texRoot = ChestLayout.teethTextureHeight - ChestLayout.gumRise - 6 + SceneTextures.gumEdge(f.x) + 2
                #expect(texRoot - f.len >= CGFloat(0))
            }
        }
    }

    /// Item 7 (UX P2-3): a golden chest shows one number: the seal's total, popped over its loot as "×<same>".
    @Test @MainActor func goldenChestShowsOneNumber() {
        let scene = ChestScene(layout: ScreenLayout(hasFold: true))
        let driver = SceneFakeDriver()
        scene.driver = driver
        var spec = SceneFakeDriver.chest(tier: .gilded, index: 5)
        spec.golden = true
        spec.multiplier = 4
        driver.startChest(spec)
        var clock = 0.0
        driver.openTo(0.9)
        SceneFakeDriver.run(scene, frames: 30, clock: &clock)
        driver.pending = [.itemRevealed(id: 0, kind: .copper)]
        SceneFakeDriver.run(scene, frames: 4, clock: &clock)
        #expect(scene.plateSeal == "×4")
        #expect(scene.lastGoldenPop == "×4")
        #expect(scene.plateSubline == "Golden · Snorer")
        #expect(!scene.plateSubline.contains(where: { $0.isNumber }))
    }

    /// Item 8 (tester 8): the phone's extension above the lid carries a carved plaque with the tier and the chest
    /// number, clear of the teaching slot below and the safe-area top above; the Duo (no extension) has none.
    @Test @MainActor func phoneExtensionCarriesThePlaque() {
        let phone = ChestScene(layout: SceneTests.phone)
        let d1 = SceneFakeDriver()
        phone.driver = d1
        d1.startChest(SceneFakeDriver.chest(tier: .iron, index: 3))
        var clock = 0.0
        SceneFakeDriver.run(phone, frames: 5, clock: &clock)
        #expect(phone.plaqueText == "Iron-bound · Chest 4")
        #expect(phone.plaqueShowing)
        var g = SceneFakeDriver.chest(tier: .wooden, index: 0)
        g.golden = true
        #expect(ChestCopy.extensionPlaque(g) == "Golden · Chest 1")
        let t = phone.extensionTop
        #expect(t >= ChestLayout.plaqueMinExtension)
        let cy = ChestLayout.plaqueCenterY(topExtension: t)
        let half = ChestLayout.plaqueSize.height / 2
        let slotTop = ChestLayout.lidLabelSlot.maxY - ChestLayout.lidBottom
        #expect(cy - half >= slotTop + 8)
        #expect(cy + half <= ChestLayout.lidSize.height + t - 60)
        let duo = ChestScene(layout: ScreenLayout(hasFold: true))
        let d2 = SceneFakeDriver()
        duo.driver = d2
        d2.startChest(SceneFakeDriver.chest(tier: .iron, index: 3))
        SceneFakeDriver.run(duo, frames: 5, clock: &clock)
        #expect(!duo.plaqueShowing)
    }

    /// Item 9 (juror P2): loot in flight never covers the strip's labels: a held item draws under the HUD and the
    /// pouch's lip, and the bank flyers' arc stays under the meter.
    @Test @MainActor func flyingLootStaysUnderTheLabels() {
        #expect(CGFloat(25) + SceneLootView.heldZ < CGFloat(29))
        for k in 0..<10 {
            let from = SceneLootView.pilePoint(k)
            var peak: CGFloat = 0
            for i in 0...20 { peak = max(peak, SceneMoments.flightPoint(from: from, t: CGFloat(i) / 20).y) }
            #expect(peak + 8 < ChestLayout.meterRect.minY)
            let end = SceneMoments.flightPoint(from: from, t: 1)
            #expect(abs(end.x - ChestLayout.counterCoin.x) < CGFloat(0.01))
        }
    }

    /// Item 9 (juror P1-3): the cover fills its view (no letterbox hairlines), its Zzz never pass the top edge, and
    /// the amber eye shows: a warm shine always, a glint at each peek (not under Reduce Motion).
    @Test @MainActor func coverFillsItsCardKeepsTheZzzInAndGlints() {
        for reduce in [false, true] {
            let p = MimicPortraitScene(size: CGSize(width: 600, height: 480))
            p.scaleMode = .aspectFit
            p.reduceMotion = reduce
            p.applyCoverStyle()
            #expect(p.fillsView)
            #expect(p.scaleMode == .resizeFill)
            var glint: CGFloat = 0
            var shine: CGFloat = 1
            var top: CGFloat = 0
            for i in 0..<(60 * 8) {
                p.update(Double(i) / 60)
                glint = max(glint, p.glintLevel)
                shine = min(shine, p.eyeShineLevel)
                top = max(top, p.zzzTop)
            }
            #expect(shine >= CGFloat(0.4))
            if reduce { #expect(glint < CGFloat(0.01)) } else { #expect(glint > CGFloat(0.5)) }
            #expect(top > 0)
            #expect(top <= p.size.height - 4)
            // The real card (≈ 328 × 262 pt) keeps every Z inside too.
            p.size = CGSize(width: 328, height: 262)
            var top2: CGFloat = 0
            for i in 0..<(60 * 4) {
                p.update(10 + Double(i) / 60)
                top2 = max(top2, p.zzzTop)
            }
            #expect(top2 <= p.size.height - 4)
        }
    }

    /// Item 10 (tester 8: "an unreadable grey blob"): the Relic Hunter badge's lantern reads by its silhouette: a
    /// carrying ring, two see-through panes either side of the candle post, a flared foot.
    @Test func relicHunterLanternReadsBySilhouette() {
        #expect(BadgePainter.motif(index: 2) == .lantern)
        let r: CGFloat = 50
        let art = ChestArt.relicArt(.lantern, radius: r)
        #expect(!art.holes.isEmpty)
        let sil = art.silhouette
        #expect(!sil.contains(CGPoint(x: -0.26 * r, y: -0.07 * r)))
        #expect(!sil.contains(CGPoint(x: 0.26 * r, y: -0.07 * r)))
        #expect(sil.contains(CGPoint(x: 0, y: -0.07 * r)))
        #expect(!sil.contains(CGPoint(x: 0, y: 0.8 * r)))
        #expect(sil.contains(CGPoint(x: 0.2, y: 0.92 * r)))
        #expect(sil.contains(CGPoint(x: 0.62 * r, y: -0.8 * r)))
        let box = sil.boundingBoxOfPath
        #expect(box.minX >= -r - 0.01 && box.maxX <= r + 0.01 && box.minY >= -r - 0.01 && box.maxY <= r + 0.01)
    }

    /// Item 11 (tester 8): every loose coin and sparkle on the icon stays inside the iOS mask's safe circle.
    @Test func iconBitsStayInsideTheMask() {
        #expect(ChestArt.iconLooseBits.count >= 4)
        let c = CGPoint(x: 512, y: 512)
        for bit in ChestArt.iconLooseBits {
            let d = hypot(bit.center.x - c.x, bit.center.y - c.y)
            #expect(d + bit.reach <= ChestArt.iconSafeRadius)
        }
    }

    /// Founder (CI frame 32): a fold layout never draws or uses the lever, turned or not; a phone without a fold does.
    @Test @MainActor func foldLayoutsNeverShowTheLeverTurnedOrNot() {
        #expect(!ChestScene.showsLever(hasFold: true, usesSlider: true))
        #expect(!ChestScene.showsLever(hasFold: false, usesSlider: false))
        #expect(ChestScene.showsLever(hasFold: false, usesSlider: true))
        for turned in [false, true] {
            let fold = ScreenLayout.make(hasFold: true, viewSize: CGSize(width: 393, height: 852))
            let scene = ChestScene(layout: fold)
            scene.turned = turned
            let driver = SceneFakeDriver()
            driver.usesSlider = true
            scene.driver = driver
            driver.startChest(SceneFakeDriver.chest(tier: .wooden, index: 0))
            var clock = 0.0
            SceneFakeDriver.run(scene, frames: 5, clock: &clock)
            #expect(!scene.leverShowing)
            scene.beginTouch(4, canvas: CGPoint(x: ChestLayout.sliderX, y: 700), time: 1)
            scene.endTouch(4, canvas: CGPoint(x: ChestLayout.sliderX, y: 800), time: 1.1)
            #expect(driver.sliderTouches == 0)
            // The same scene moved to a no-fold layout draws it; back on the fold it is gone at once.
            scene.layout = SceneTests.phone
            SceneFakeDriver.run(scene, frames: 2, clock: &clock)
            #expect(scene.leverShowing)
            scene.layout = fold
            #expect(!scene.leverShowing)
        }
    }

    /// Founder: the front padlock's keyhole reads as a keyhole either way up: one piece with no neck (the slot meets
    /// the round top wider than its radius), tapering out to a flat foot.
    @Test func keyholeHasNoNeck() {
        let c = CGPoint(x: 75, y: 74)
        let r: CGFloat = 11
        let p = SceneTextures.keyholePath(center: c, radius: r)
        #expect(p.contains(c))
        #expect(p.contains(CGPoint(x: c.x - 0.6 * r, y: c.y - 0.8 * r)))
        #expect(p.contains(CGPoint(x: c.x + 0.6 * r, y: c.y - 0.8 * r)))
        #expect(p.contains(CGPoint(x: c.x - 0.6 * r, y: c.y - 1.1 * r)))
        #expect(p.contains(CGPoint(x: c.x + 0.6 * r, y: c.y - 1.1 * r)))
        #expect(p.contains(CGPoint(x: c.x - 0.8 * r, y: c.y - 2.6 * r)))
        #expect(!p.contains(CGPoint(x: c.x, y: c.y - 3.0 * r)))
        #expect(!p.contains(CGPoint(x: c.x, y: c.y + 1.1 * r)))
    }

    // MARK: R5

    /// Item 3: the chest's centre line, for the App's hint plates: the eye, brow, plate, pouch, mouth and lid all share it.
    @Test func chestCenterXIsTheChestsAxis() {
        let cx = ChestLayout.chestCenterX
        #expect(abs(cx - ScreenLayout.canvasWidth / 2) < CGFloat(0.001))
        for x in [ChestLayout.plateCenter.x, ChestLayout.browCenter.x, ChestLayout.eyeCenter.x, ChestLayout.mouthPoint.x,
                  ChestLayout.pouchMouth.x, ChestLayout.pouchRect.midX, ChestLayout.titlePoint.x,
                  ChestLayout.relicBannerPoint.x, ChestLayout.lidLabelSlot.midX] {
            #expect(abs(x - cx) < CGFloat(0.5))
        }
        // A hint plate centred on it still fits left of the pause seat (≥ 8 pt) at every scale, ≥ 300 pt wide.
        for s in [CGFloat(0.55), 0.6, 0.8, 1] {
            let half = min(cx - ChestLayout.hintBand.minX, ChestLayout.pauseSeat(viewScale: s).minX - 8 - cx)
            #expect(half * 2 >= CGFloat(300))
        }
    }

    /// Item 1 (UX P2-4, testers 9 and 10): the chain tab is one line, "CHAIN ×1.5" (no "GOLD"), at ≥ 11 screen pt on a
    /// phone, inside the tab's text column; the shorter meter keeps its 20 segments and ends in its teeth.
    @Test @MainActor func chainTabIsOneLineAtElevenPoints() {
        #expect(SceneFloorHUD.chainText(1.5) == "CHAIN ×1.5")
        #expect(!SceneFloorHUD.chainText(1.1).contains("GOLD"))
        #expect(ChestLayout.chainFontSize * ChestLayout.minViewScale >= CGFloat(11))
        #expect(ChestLayout.chainMinFontSize * (390 / ScreenLayout.canvasWidth) >= CGFloat(11))
        let tab = ChestLayout.chainRect
        #expect(tab.minX >= ChestLayout.meterRect.maxX + 8)
        #expect(ChestLayout.chainCenter.x - ChestLayout.chainRadius - 2 >= ChestLayout.meterRect.maxX)
        #expect(tab.maxX <= ChestLayout.frontRightBracketMinX)
        let inPlate = ChestArt.plateTextRect(in: tab.size, style: .leather)
        #expect(ChestLayout.chainTextRect.maxX <= tab.minX + inPlate.maxX + 0.001)
        #expect(ChestLayout.chainTextRect.minX >= ChestLayout.chainCenter.x + ChestLayout.chainRadius)
        #expect(ChestLayout.meterWell.width / CGFloat(ChestLayout.meterSegments) >= CGFloat(10))
        #expect(ChestLayout.meterWell.minX > ChestLayout.meterLabelCenter.x + ChestLayout.meterLabelWidth / 2)

        let scene = ChestScene(layout: SceneTests.phone)
        let driver = SceneFakeDriver()
        scene.driver = driver
        driver.startChest(SceneFakeDriver.chest(tier: .iron, index: 4))
        var clock = 0.0
        driver.openTo(0.9)
        driver.bag([0, 1])
        driver.snap.bagValue = 100
        SceneFakeDriver.run(scene, frames: 30, clock: &clock)
        driver.openTo(0)
        driver.snap.phase = .banked(elapsed: 0)
        driver.snap.banked = 150
        driver.snap.bagValue = 0
        driver.snap.chain = 5
        driver.snap.chainMultiplier = 1.5
        driver.pending = [.banked(value: 150, items: 2, hushed: true), .chainUp(count: 5, multiplier: 1.5)]
        SceneFakeDriver.run(scene, frames: 60, clock: &clock)
        #expect(scene.chainTabText == "CHAIN ×1.5")
        #expect(scene.chainBadgeShowing)
        let widths = scene.chainTextWidths
        #expect(widths.count == 1)
        for w in widths { #expect(w <= ChestLayout.chainTextRect.width + 0.5) }
        // ≥ 11 screen pt on the CI phone (402 pt: scale 0.6) and every 390 pt phone.
        let drawn = scene.chainDrawnFontSize
        #expect(drawn >= ChestLayout.chainMinFontSize - 0.01)
        #expect(drawn * 0.582 >= CGFloat(11))
    }

    /// Item 2 (UX P2-8, testers 9 and 10, frames 07 and 14): loot moving over the bag strip never sits on "IN BAG" or
    /// "BANKED": the bank flyers fade out before they touch a label; a held item fades to 0.3 over one.
    @Test @MainActor func flyingLootNeverCoversThePlateLabels() {
        // The label rects hold the labels as drawn.
        let scene0 = ChestScene(layout: ScreenLayout(hasFold: true))
        let frames = scene0.plateLabelFrames
        let rects = ChestLayout.plateLabelRects
        #expect(frames.count == 2 && rects.count == 2)
        for (f, r) in zip(frames, rects) {
            #expect(f.width > CGFloat(20))
            #expect(r.contains(f))
        }
        // Pure: the fade never leaves anything visible that touches a label.
        #expect(SceneLootView.labelClearAlpha(at: CGPoint(x: 335, y: 84), radius: 20, minAlpha: 0) > CGFloat(0.99))
        let onBag = CGPoint(x: ChestLayout.bagLabelRect.midX, y: ChestLayout.bagLabelRect.midY)
        #expect(SceneLootView.labelClearAlpha(at: onBag, radius: 10, minAlpha: 0) < CGFloat(0.001))
        #expect(abs(SceneLootView.labelClearAlpha(at: onBag, radius: 10, minAlpha: 0.3) - 0.3) < CGFloat(0.001))
        for k in 0..<10 {
            let from = SceneLootView.pilePoint(k)
            for radius in [CGFloat(18), 24, 34] {
                // Leaving the pouch it is fully drawn.
                let r0 = SceneLootView.drawnRadius(radius) * SceneMoments.flyerScale(0)
                #expect(SceneLootView.labelClearAlpha(at: from, radius: r0, minAlpha: 0) > CGFloat(0.99))
                for step in 0...50 {
                    let t = CGFloat(step) / 50
                    let p = SceneMoments.flightPoint(from: from, t: t)
                    let vr = SceneLootView.drawnRadius(radius) * SceneMoments.flyerScale(t)
                    let a = SceneLootView.labelClearAlpha(at: p, radius: vr, minAlpha: 0)
                    if a > 0.01 {
                        for r in rects { #expect(!SceneMoments.circle(p, vr, touches: r)) }
                    }
                }
            }
        }

        // The scene: a bank's flyers are drawn, and never over a label in any frame.
        for layout in [ScreenLayout(hasFold: true), SceneTests.phone] {
            let scene = ChestScene(layout: layout)
            let driver = SceneFakeDriver()
            scene.driver = driver
            driver.startChest(SceneFakeDriver.chest(tier: .wooden, index: 1))
            var clock = 0.0
            driver.openTo(0.95)
            driver.bag([0, 1, 2, 4])
            driver.snap.bagValue = 428
            SceneFakeDriver.run(scene, frames: 60, clock: &clock)
            driver.openTo(0)
            driver.snap.phase = .banked(elapsed: 0)
            driver.snap.banked = 428
            driver.snap.bagValue = 0
            driver.pending = [.banked(value: 428, items: 4, hushed: true)]
            var maxFlyers = 0
            var clear = true
            for _ in 0..<160 {
                SceneFakeDriver.run(scene, frames: 1, clock: &clock)
                maxFlyers = max(maxFlyers, scene.visibleFlyers)
                if !scene.flyersClearOfLabels { clear = false }
            }
            #expect(maxFlyers >= 1)
            #expect(clear)
        }

        // A held item over "IN BAG" is drawn faint (the word reads); back over the loot it is whole.
        let scene = ChestScene(layout: SceneTests.phone)
        let driver = SceneFakeDriver()
        scene.driver = driver
        driver.startChest(SceneFakeDriver.chest(tier: .wooden, index: 0))
        var clock = 0.0
        driver.openTo(0.95)
        driver.hold(2)
        SceneFakeDriver.run(scene, frames: 10, clock: &clock)
        #expect((scene.heldItemAlpha ?? 0) > CGFloat(0.99))
        if let i = driver.snap.loot.firstIndex(where: { $0.id == 2 }) {
            driver.snap.loot[i].position = ChestLayout.floor(fromCanvas: onBag)
        }
        SceneFakeDriver.run(scene, frames: 4, clock: &clock)
        #expect((scene.heldItemAlpha ?? 1) <= SceneLootView.heldOverLabelAlpha + 0.01)
    }

    /// Item 4 (juror P2, tester 10): the Zzz drift in the velvet lane between the lid's left border and its left band,
    /// so none crosses an iron or gilt band.
    @Test @MainActor func zzzStayBetweenTheBorderAndTheBand() {
        let lane = ChestLayout.zzzLane
        #expect(lane.lowerBound >= SceneTextures.lidBorder + 4)
        #expect(lane.upperBound <= ChestLayout.lidBandXs[0] - ChestLayout.lidBandHalfWidth - 4 + 0.001)
        let eye = ChestLayout.eyeCenter
        for (i, size) in SceneLid.zzzSizes.enumerated() {
            for step in 0...20 {
                let p = SceneLid.zzzPoint(index: i, phase: CGFloat(step) / 20, eye: eye)
                let half = size * 0.45
                #expect(p.x - half >= lane.lowerBound - 0.001)
                #expect(p.x + half <= lane.upperBound + 0.001)
                // Above the name plate and its seal, below the lid's top.
                #expect(p.y - size / 2 > ChestLayout.plateCenter.y + ChestLayout.plateSize.height / 2)
                #expect(p.y + size / 2 < ChestLayout.lidSize.height)
            }
        }
    }

    /// App item 5 (juror P2-3, frame 13): the pause seat dims during the bite and comes back after it.
    @Test @MainActor func pauseSeatDimsDuringTheBite() {
        let scene = ChestScene(layout: SceneTests.phone)
        let driver = SceneFakeDriver()
        scene.driver = driver
        driver.startChest(SceneFakeDriver.chest(tier: .wooden, index: 0))
        var clock = 0.0
        SceneFakeDriver.run(scene, frames: 30, clock: &clock)
        #expect(scene.pauseSeatAlpha > CGFloat(0.99))
        driver.snap.phase = .bitten(elapsed: 0)
        driver.snap.stage = .biting
        driver.pending = [.bitten(lostValue: 40)]
        SceneFakeDriver.run(scene, frames: 60, clock: &clock)
        #expect(scene.biteActive)
        #expect(scene.pauseSeatAlpha < CGFloat(0.4))
        driver.snap.phase = .ready
        driver.snap.stage = .asleep
        SceneFakeDriver.run(scene, frames: 360, clock: &clock)
        #expect(!scene.biteActive)
        #expect(scene.pauseSeatAlpha > CGFloat(0.95))
    }

    // MARK: R6

    /// The window sizes of ROUND-6 item 3 (landscape and portrait), plus the Duo canvas and a phone.
    static var r6ViewSizes: [CGSize] {
        [CGSize(width: 951, height: 669), CGSize(width: 669, height: 951), CGSize(width: 670, height: 952),
         CGSize(width: 393, height: 852)]
    }

    /// Where a portrait-scene point `q` (canvas + contentOffsetY, in a W × H portrait scene) lands after `k`
    /// clockwise quarter turns, worked out by hand (independent of the scene's own transform maths).
    static func turnedByHand(_ q: CGPoint, k: Int, width w: CGFloat, height h: CGFloat) -> CGPoint {
        switch k {
        case 1: return CGPoint(x: q.y, y: w - q.x)
        case 2: return CGPoint(x: w - q.x, y: h - q.y)
        case 3: return CGPoint(x: h - q.y, y: q.x)
        default: return q
        }
    }

    /// Item 1: `quarterTurns` is 0…3 (any Int mod 4), `turned` is k == 2 (get and set), the world turns by −k·π/2,
    /// and the scene takes the landscape size for odd k.
    @Test @MainActor func quarterTurnsNormaliseAndTurnedIsKTwo() {
        #expect(ChestScene.normalisedTurns(5) == 1)
        #expect(ChestScene.normalisedTurns(-1) == 3)
        #expect(ChestScene.normalisedTurns(8) == 0)
        let layout = ScreenLayout.make(hasFold: true, viewSize: CGSize(width: 951, height: 669))
        #expect(abs(layout.size.width - 670) < CGFloat(0.001) && abs(layout.size.height - 952) < CGFloat(0.001))
        let scene = ChestScene(layout: layout)
        #expect(scene.quarterTurns == 0 && !scene.turned)
        scene.turned = true
        #expect(scene.quarterTurns == 2 && scene.turned)
        scene.turned = false
        #expect(scene.quarterTurns == 0)
        scene.quarterTurns = 7
        #expect(scene.quarterTurns == 3 && !scene.turned)
        scene.quarterTurns = -2
        #expect(scene.quarterTurns == 2 && scene.turned)
        for k in 0...3 {
            scene.quarterTurns = k
            let want = ChestScene.sceneSize(layout: layout, quarterTurns: k)
            let odd = k % 2 == 1
            #expect(abs(want.width - (odd ? layout.size.height : layout.size.width)) < CGFloat(0.001))
            #expect(abs(want.height - (odd ? layout.size.width : layout.size.height)) < CGFloat(0.001))
            #expect(abs(scene.size.width - want.width) < CGFloat(0.001))
            #expect(abs(scene.size.height - want.height) < CGFloat(0.001))
            #expect(abs(scene.worldScale - 1) < CGFloat(0.0001))
            let rot = scene.worldNode.zRotation
            let want0 = -CGFloat(k) * .pi / 2
            #expect(abs(cos(rot) - cos(want0)) < CGFloat(0.0001) && abs(sin(rot) - sin(want0)) < CGFloat(0.0001))
            // A new layout keeps the turn (the App sets the layout and k in either order).
            scene.layout = SceneTests.phone
            let phoneWant = ChestScene.sceneSize(layout: SceneTests.phone, quarterTurns: k)
            #expect(abs(scene.size.width - phoneWant.width) < CGFloat(0.001))
            #expect(abs(scene.size.height - phoneWant.height) < CGFloat(0.001))
            scene.layout = layout
        }
        // k = 0 and k = 2 are R2's placements exactly.
        scene.quarterTurns = 0
        #expect(abs(scene.worldNode.position.x) < CGFloat(0.01))
        #expect(abs(scene.worldNode.position.y - layout.contentOffsetY) < CGFloat(0.01))
        scene.quarterTurns = 2
        #expect(abs(scene.worldNode.position.x - layout.size.width) < CGFloat(0.01))
        #expect(abs(scene.worldNode.position.y - (layout.size.height - layout.contentOffsetY)) < CGFloat(0.01))
    }

    /// Item 3: for every k and every size, a touch at an item's on-screen position maps to that item's floor point,
    /// and the on-screen position is where a hand-worked quarter turn puts it, inside the scene.
    @Test @MainActor func everyQuarterTurnMapsATouchToTheItemsFloorPoint() {
        let items = SceneFakeDriver.chest(tier: .wooden, index: 0).items.map(\.position)
            + [CGPoint(x: 30, y: 400), CGPoint(x: 640, y: 20)]
        for v in SceneTests.r6ViewSizes {
            let layout = ScreenLayout.make(hasFold: true, viewSize: v)
            let w = layout.size.width, h = layout.size.height, off = layout.contentOffsetY
            for k in 0...3 {
                let scene = ChestScene(layout: layout)
                let driver = SceneFakeDriver()
                scene.driver = driver
                scene.quarterTurns = k
                // The portrait canvas with its extensions fills the scene exactly.
                let drawn = scene.drawnWorldRect
                #expect(abs(drawn.minX) < CGFloat(0.01) && abs(drawn.minY) < CGFloat(0.01))
                #expect(abs(drawn.maxX - scene.size.width) < CGFloat(0.01))
                #expect(abs(drawn.maxY - scene.size.height) < CGFloat(0.01))
                for (n, item) in items.enumerated() {
                    let c = ChestLayout.canvas(fromFloor: item)
                    let seen = scene.scenePoint(fromCanvas: c)
                    let hand = SceneTests.turnedByHand(CGPoint(x: c.x, y: c.y + off), k: k, width: w, height: h)
                    #expect(abs(seen.x - hand.x) < CGFloat(0.01) && abs(seen.y - hand.y) < CGFloat(0.01))
                    #expect(seen.x >= -0.01 && seen.x <= scene.size.width + 0.01)
                    #expect(seen.y >= -0.01 && seen.y <= scene.size.height + 0.01)
                    // A finger there (`touch.location(in: world)`) is the item's floor point.
                    let back = scene.canvasPoint(fromScene: seen)
                    #expect(abs(back.x - c.x) < CGFloat(0.01) && abs(back.y - c.y) < CGFloat(0.01))
                    scene.beginTouch(n + 1, canvas: back, time: 1)
                    let f = driver.lastBegan ?? CGPoint(x: -999, y: -999)
                    let want = ChestLayout.floorTouchPoint(fromCanvas: c)
                    #expect(abs(f.x - want.x) < CGFloat(0.01) && abs(f.y - want.y) < CGFloat(0.01))
                    #expect(abs(f.x - item.x) < CGFloat(0.01) && abs(f.y - item.y) < CGFloat(0.01))
                    scene.endTouch(n + 1, canvas: back, time: 1.1)
                }
                #expect(driver.ended == items.count)
            }
        }
    }

    /// Item 3: the lid half is drawn on the expected screen side for every k (0 top, 1 right, 2 bottom, 3 left: the
    /// canvas top turned k quarter turns clockwise), with the floor on the opposite side and the fold at the centre.
    @Test @MainActor func lidHalfIsOnTheExpectedSideForEveryQuarterTurn() {
        let lidRect = CGRect(x: 0, y: ChestLayout.lidBottom, width: ScreenLayout.canvasWidth,
                             height: ScreenLayout.canvasHeight - ChestLayout.lidBottom)
        let floorRect = CGRect(x: 0, y: 0, width: ScreenLayout.canvasWidth, height: ChestLayout.floorTop)
        for v in SceneTests.r6ViewSizes {
            let layout = ScreenLayout.make(hasFold: true, viewSize: v)
            for k in 0...3 {
                let scene = ChestScene(layout: layout)
                scene.quarterTurns = k
                let lid = scene.sceneRect(fromCanvas: lidRect)
                let floor = scene.sceneRect(fromCanvas: floorRect)
                let mx = scene.size.width / 2, my = scene.size.height / 2
                switch k {
                case 0:
                    #expect(lid.minY > my && floor.maxY < my)
                case 1:
                    #expect(lid.minX > mx && floor.maxX < mx)
                case 2:
                    #expect(lid.maxY < my && floor.minY > my)
                default:
                    #expect(lid.maxX < mx && floor.minX > mx)
                }
                // The lid spans the scene's short (odd k: height) or long side across the fold, never sideways.
                let across = k % 2 == 1 ? lid.height : lid.width
                #expect(abs(across - ScreenLayout.canvasWidth) < CGFloat(0.01))
                // The fold's middle is at the scene's centre (within the extension's rounding).
                let fold = scene.scenePoint(fromCanvas: CGPoint(x: ChestLayout.chestCenterX,
                                                                y: (ChestLayout.floorTop + ChestLayout.lidBottom) / 2))
                #expect(abs(fold.x - mx) < CGFloat(1.01) && abs(fold.y - my) < CGFloat(1.01))
            }
        }
    }

    /// Item 1 + 3: when the scene is given the window's own size (951 × 669 landscape for odd k, 669 × 951 portrait for
    /// even k) instead of its own, the world scales to cover it exactly (≤ 1 pt overhang), touches still map back,
    /// and the lid is still on the right side. The view-scale rule follows the scene's scale mode.
    @Test @MainActor func windowSizedScenesStillFillAndMapTouches() {
        let layout = ScreenLayout.make(hasFold: true, viewSize: CGSize(width: 669, height: 951))
        let lidMid = CGPoint(x: ChestLayout.chestCenterX, y: (ChestLayout.lidBottom + ScreenLayout.canvasHeight) / 2)
        for k in 0...3 {
            let scene = ChestScene(layout: layout)
            let driver = SceneFakeDriver()
            scene.driver = driver
            scene.quarterTurns = k
            let window = k % 2 == 1 ? CGSize(width: 951, height: 669) : CGSize(width: 669, height: 951)
            scene.size = window
            #expect(scene.worldScale > CGFloat(0.99) && scene.worldScale < CGFloat(1.01))
            let drawn = scene.drawnWorldRect
            #expect(drawn.minX <= 0.01 && drawn.minY <= 0.01)
            #expect(drawn.maxX >= window.width - 0.01 && drawn.maxY >= window.height - 0.01)
            #expect(drawn.width - window.width <= CGFloat(1.5) && drawn.height - window.height <= CGFloat(1.5))
            let item = CGPoint(x: 460, y: 150)
            let c = ChestLayout.canvas(fromFloor: item)
            let seen = scene.scenePoint(fromCanvas: c)
            let back = scene.canvasPoint(fromScene: seen)
            #expect(abs(back.x - c.x) < CGFloat(0.01) && abs(back.y - c.y) < CGFloat(0.01))
            scene.beginTouch(1, canvas: back, time: 1)
            let f = driver.lastBegan ?? CGPoint(x: -999, y: -999)
            #expect(abs(f.x - item.x) < CGFloat(0.01) && abs(f.y - item.y) < CGFloat(0.01))
            let lid = scene.scenePoint(fromCanvas: lidMid)
            let mx = window.width / 2, my = window.height / 2
            switch k {
            case 0: #expect(lid.y > my)
            case 1: #expect(lid.x > mx)
            case 2: #expect(lid.y < my)
            default: #expect(lid.x < mx)
            }
        }
        // The seat's view scale: the scene's own mode decides; a turned landscape scene gives the portrait number.
        let land = ChestScene.scaleFor(view: CGSize(width: 951, height: 669), scene: CGSize(width: 952, height: 670),
                                       mode: .aspectFit)
        let port = ChestScene.scaleFor(view: CGSize(width: 669, height: 951), scene: CGSize(width: 670, height: 952))
        #expect(abs(land - port) < CGFloat(0.002))
        let fill = ChestScene.scaleFor(view: CGSize(width: 951, height: 669), scene: CGSize(width: 952, height: 670),
                                       mode: .aspectFill)
        #expect(abs(fill - land) < CGFloat(0.002))
        #expect(abs(ChestScene.scaleFor(view: CGSize(width: 402, height: 874), scene: CGSize(width: 670, height: 1457),
                                        mode: .aspectFill) - CGFloat(0.6)) < CGFloat(0.01))
        #expect(abs(ChestScene.scaleFor(view: CGSize(width: 951, height: 669), scene: CGSize(width: 952, height: 670),
                                        mode: .resizeFill) - 1) < CGFloat(0.001))
    }

    /// Item 2: every moment draws at every quarter turn (the shake, particles, text and the eye's gaze live in the
    /// world's frame), the world stays turned through the shake, and a held item's gaze target is a canvas point.
    @Test @MainActor func everyQuarterTurnDrawsEveryMoment() {
        let relic = RelicCatalog.all.first?.id ?? RelicID("relic01")
        for k in [1, 3] {
            let scene = ChestScene(layout: ScreenLayout.make(hasFold: true, viewSize: CGSize(width: 951, height: 669)))
            scene.quarterTurns = k
            let driver = SceneFakeDriver()
            scene.driver = driver
            driver.startChest(SceneFakeDriver.chest(tier: .iron, index: 2))
            var clock = 0.0
            driver.openTo(0.95)
            SceneFakeDriver.run(scene, frames: 30, clock: &clock)
            let all: [HeistEvent] = [
                .lidCracked, .itemRevealed(id: 0, kind: .copper), .itemRevealed(id: 4, kind: .relic(relic)),
                .itemBagged(id: 2, kind: .gem(.ruby), value: 135), .oilAdded(seconds: 6), .dreamTwitch, .torchLow,
                .chainUp(count: 1, multiplier: 1.1),
            ]
            for e in all {
                driver.pending = [e]
                SceneFakeDriver.run(scene, frames: 8, clock: &clock)
            }
            driver.snap.phase = .bitten(elapsed: 0)
            driver.snap.stage = .biting
            driver.pending = [.bitten(lostValue: 40)]
            SceneFakeDriver.run(scene, frames: 40, clock: &clock)
            #expect(scene.biteActive)
            #expect(scene.drawnFrames > 100)
            // The shake moves the shaker inside the world; the world itself keeps its turn and its place.
            let rot = scene.worldNode.zRotation
            let want = -CGFloat(k) * .pi / 2
            #expect(abs(cos(rot) - cos(want)) < CGFloat(0.0001) && abs(sin(rot) - sin(want)) < CGFloat(0.0001))
            let drawn = scene.drawnWorldRect
            #expect(abs(drawn.maxX - scene.size.width) < CGFloat(0.01) && abs(drawn.minY) < CGFloat(0.01))
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

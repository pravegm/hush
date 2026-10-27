import CoreGraphics
import Foundation

/// Where everything sits on the 670 × 952 canvas (SpriteKit points, origin bottom-left, **y up**). Pure values, shared
/// by the scene, its tests and the App (the hint band and the pause button area are the App's to fill).
///
/// Floor half (y 0…456, the SHARP half: the time-critical HUD lives here):
/// - the bag strip y 0…110 (`FloorSpace.bagRect` on the canvas): IN BAG (left: clasp, shut-hold ring, the value),
///   the leather pouch (middle: the drop target, bagged loot piles in it), BANKED (right: the gold counter);
/// - the noise meter ("NOISE", teeth at the full end) on the chest's front rim, y 104…136;
/// - the chest interior y 134…420 (`FloorSpace.interior`), the candle on the left rim, the Hush Chain medallion on
///   the right rim;
/// - R2: the App's hint band at the floor's BACK edge by the fold, y 404…452 (no scene HUD there);
/// - the pause coin area, the top-right corner inset from the edges, in its own brass socket (no scene HUD there);
/// - R3: the Hush Chain tab on the front rim right of the meter; nothing within 16 pt of the side edges.
/// Fold band y 456…496 (the brass hinge strip). Lid half y 496…952 (may blur): ambience and the name plate.
/// R2: the scene may be taller than the canvas; the extension art lies below y 0 and above y 952 (`ScreenLayout`).
enum ChestLayout {
    static let canvas = CGSize(width: ScreenLayout.canvasWidth, height: ScreenLayout.canvasHeight)
    static let floorTop: CGFloat = ScreenLayout.foldMinY
    static let lidBottom: CGFloat = ScreenLayout.foldMaxY
    static let lidSize = CGSize(width: ScreenLayout.canvasWidth,
                                height: ScreenLayout.canvasHeight - ScreenLayout.foldMaxY)

    // MARK: Floor

    /// The bag strip on the canvas (the drop target).
    static var bagStrip: CGRect {
        CGRect(x: 0, y: 0, width: FloorSpace.width, height: FloorSpace.height - FloorSpace.bagMinY)
    }

    /// `FloorSpace.interior` on the canvas (y 134…420).
    static var interior: CGRect {
        let r = FloorSpace.interior
        return CGRect(x: r.minX, y: floorTop - r.maxY, width: r.width, height: r.height)
    }

    /// The chest's walls and bed texture (from just under the satchel's lip to the fold).
    static let frameRect = CGRect(x: 0, y: 104, width: 670, height: 352)
    /// The rims' inner edge (the walls' inner faces lie between this and the interior).
    static let rimInner = CGRect(x: 50, y: 134, width: 570, height: 310)

    /// R3: every HUD piece keeps at least this far from the canvas edges (the canvas edges ARE the screen edges).
    static let edgeInset: CGFloat = 16

    /// R5: the chest's centre line (canvas x): the eye, the brow, the name plate, the lock, the pouch and the mouth all
    /// sit on it. The App centres its hint plates on it (not on the hint band's own middle).
    static let chestCenterX: CGFloat = ScreenLayout.canvasWidth / 2

    /// The noise meter plate on the front rim (the stage word at the left, the teeth at the full end), its segment
    /// well, and the segment count. Drawn over everything on the floor. R3: shortened so the Hush Chain tab sits on
    /// the same rim. R4 (UX P1-2): shortened again (it ends at x 460, was 520) so the tab sits LEFT of the front-right
    /// bracket, ≥ 16 screen pt from the edge on a phone. R5 (UX P2-4, testers 9 and 10): 46 pt shorter again (ends at
    /// x 414) so the tab can read "CHAIN ×1.2" on one line at ≥ 11 screen pt; the well keeps its 20 segments.
    static let meterRect = CGRect(x: 56, y: 104, width: 358, height: 32)
    static let meterWell = CGRect(x: 142, y: 109, width: 224, height: 22)
    static let meterSegments = 20
    static let meterLabelCenter = CGPoint(x: 99, y: 120)
    static let meterTeethCenter = CGPoint(x: 390, y: 120)
    /// R4 (UX P2-6): the meter's word follows the stage, so it never relies on colour alone (`ChestCopy.meterWord`).
    static let meterLabelWidth: CGFloat = 72

    /// R2: the App's hint line at the floor's back edge by the fold, between the lid and the loot (canvas y 404…452).
    /// The scene keeps its HUD out of it. R4 (juror P1-2): shortened on the right (x 60…524, was 72…572) so the plate
    /// keeps ≥ 8 pt from the pause stud's seat at every phone scale (`pauseSeat(viewScale: minViewScale)` starts at
    /// x ≈ 533; on the Duo at x ≈ 590). Its left end stays right of the candle (x ≤ 50).
    static let hintBand = CGRect(x: 60, y: 404, width: 464, height: 48)
    /// The pause coin's area on the Duo (view scale 1): 56 × 56 in the floor's top-right, right of the interior
    /// (x ≥ 594 > the loot's 592), 20 pt from the edge, 28 pt from the fold. R4: there is NO corner bracket there (the
    /// frame leaves that corner plain wood) and no square boss plate any more: the scene draws a round brass seat
    /// (`SceneFloorHUD`) centred on `pauseCenter(viewScale:)`, sized to the App's coin at that scale.
    static let pauseArea = CGRect(x: 594, y: 372, width: 56, height: 56)
    static var pauseCenter: CGPoint { CGPoint(x: pauseArea.midX, y: pauseArea.midY) }
    /// R4: the App's brass coin (`BrassCoinButton`: 50 pt + its 5 pt outline) and its tap frame, in VIEW points, and
    /// the inset the App keeps from the safe edge (`AppCanvas.pauseInset`). The seat mirrors the App's clamp.
    static let pauseCoinViewDiameter: CGFloat = 55
    static let pauseTapViewSide: CGFloat = 56
    static let pauseViewInset: CGFloat = 16
    /// The brass ring round the coin (view points).
    static let pauseSeatViewRing: CGFloat = 4
    /// The smallest canvas-to-view scale the game runs at (a 375 pt wide phone: 375 / 670 ≈ 0.56).
    static let minViewScale: CGFloat = 0.55

    /// R4: where the coin's centre lands at `viewScale` (view points per canvas point: 1 on the Duo, ≈ 0.6 on a
    /// phone). The App pulls its coin in so its 56 pt tap frame keeps 16 pt from the screen edge
    /// (`AppCanvas.pauseCenter`); this is the same clamp on the canvas, so the seat is always under the coin.
    static func pauseCenter(viewScale: CGFloat) -> CGPoint {
        let s = viewScale.isFinite && viewScale > 0.05 ? viewScale : 1
        let maxX = canvas.width - (pauseViewInset + pauseTapViewSide / 2) / s
        return CGPoint(x: min(pauseCenter.x, maxX), y: pauseCenter.y)
    }

    /// R4: the seat's outer radius (canvas points) at `viewScale`: the coin's radius plus a 4 pt brass ring.
    static func pauseSeatRadius(viewScale: CGFloat) -> CGFloat {
        let s = viewScale.isFinite && viewScale > 0.05 ? viewScale : 1
        return (pauseCoinViewDiameter / 2 + pauseSeatViewRing) / s
    }

    /// R4: the seat's bounding square on the canvas at `viewScale` (the hint band never touches it).
    static func pauseSeat(viewScale: CGFloat) -> CGRect {
        let c = pauseCenter(viewScale: viewScale)
        let r = pauseSeatRadius(viewScale: viewScale)
        return CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
    }

    /// The Duo seat's radius (kept for the old name).
    static var pauseSocketRadius: CGFloat { pauseSeatRadius(viewScale: 1) }

    /// The candle on the left rim (R3: 16 pt from the edge).
    static let torchRect = CGRect(x: 16, y: 150, width: 34, height: 262)
    static let candleBaseY: CGFloat = 166
    static let candleMaxHeight: CGFloat = 214
    static var candleX: CGFloat { torchRect.midX }
    /// R3: the candle-low countdown ("0:12") hangs BESIDE the candle's brass dish, never over the candle.
    static let countdownRect = CGRect(x: 58, y: 146, width: 78, height: 40)

    /// R3: the Hush Chain tab on the front rim, right of the meter, inside the frame. R4: LEFT of the front-right
    /// bracket (x ≤ 590 < 594): 80 canvas pt (≈ 48 screen pt on a phone) from the edge. R5 (UX P2-4, testers 9 and
    /// 10): ONE line, "CHAIN ×1.2" (no "GOLD": it never reads as a second gold multiplier beside the plate's seal), at
    /// `chainFontSize`; the tab grew leftwards (x 424…590) into the room the shorter meter left. The linked-rings
    /// medallion sits over the tab's left clasp.
    static let chainRect = CGRect(x: 424, y: 98, width: 166, height: 44)
    /// The medallion (over the tab's left clasp).
    static let chainCenter = CGPoint(x: 433, y: 120)
    static let chainRadius: CGFloat = 15
    /// The tab's text column (between the medallion and the right clasp + 8 pt) and its one line.
    static let chainTextRect = CGRect(x: 451, y: 106, width: 112, height: 30)
    static var chainTextX: CGFloat { chainTextRect.midX }
    static let chainTextY: CGFloat = 120
    /// R5: the tab's type (canvas pt): 20 pt is ≥ 11 screen pt at the smallest phone scale (0.55); it may shrink to
    /// `chainMinFontSize` (≥ 11 screen pt on every phone 390 pt wide and up) only if a line would overflow.
    static let chainFontSize: CGFloat = 20
    static let chainMinFontSize: CGFloat = 19
    /// The front-right corner bracket's arm along the front rim starts here (frame art).
    static let frontRightBracketMinX: CGFloat = 594

    /// IN BAG (left plate): the brass clasp (with the shut-hold ring round it), the label and the number.
    static let bagValueRect = CGRect(x: 16, y: 12, width: 240, height: 80)
    static let claspCenter = CGPoint(x: 60, y: 52)
    static let claspRadius: CGFloat = 30
    static let ringRadius: CGFloat = 37
    static let bagValueLeft: CGFloat = 104
    static let plateLabelY: CGFloat = 78
    static let plateNumberY: CGFloat = 44
    /// R3 (decision 3): "not safe yet" under the IN BAG number while the bag holds loot.
    static let bagSublabelY: CGFloat = 21

    /// BANKED (right plate): the number right-aligned beside a coin stack, the label above it.
    static let counterRect = CGRect(x: 424, y: 12, width: 230, height: 80)
    static let counterCoin = CGPoint(x: 626, y: 46)
    static let counterRight: CGFloat = 596

    /// R5 (UX P2-8, testers 9 and 10, frames 07 and 14): where the plates' small-caps labels are drawn ("IN BAG" from
    /// x 106, "BANKED" right-aligned at x 594, both centred on y 78), with a little room round them. Loot moving over
    /// the strip fades out before it reaches these (`SceneLootView.labelClearAlpha`), so the words always read.
    static let bagLabelRect = CGRect(x: 100, y: 64, width: 100, height: 28)
    static let bankLabelRect = CGRect(x: 494, y: 64, width: 106, height: 28)
    static var plateLabelRects: [CGRect] { [bagLabelRect, bankLabelRect] }

    /// R2: the leather pouch between the plates (the drop target; bagged loot piles in its mouth).
    static let pouchRect = CGRect(x: 264, y: 4, width: 142, height: 104)
    static let pouchMouth = CGPoint(x: 335, y: 84)

    /// Where bitten loot flies (the mimic's mouth, the middle of the fold).
    static let mouthPoint = CGPoint(x: 335, y: 476)
    /// The middle of the interior (moments' callouts stack here, under the hint band).
    static let titlePoint = CGPoint(x: 335, y: 300)
    static let relicBannerPoint = CGPoint(x: 335, y: 272)
    /// R3: the relic-found card (parchment plate: "RELIC FOUND!", the relic, its name), centred on the floor.
    static let relicCardSize = CGSize(width: 380, height: 250)
    /// R3: the bank's one centred stack: eyebrow ("Hushed!"), title ("BANKED +1,407"), sub ("Hush Chain ×1.5").
    static let bankEyebrowY: CGFloat = 372
    static let bankTitleY: CGFloat = 332
    static let bankSubY: CGFloat = 292
    /// R3: "CREAK!" (a slam) pops here, under the hint band.
    static let creakPoint = CGPoint(x: 335, y: 356)
    /// R4 (UX P2-4): "Next chest…" in the dimmed interior between chests (under the bank stack's lowest line).
    static let nextChestPoint = CGPoint(x: 335, y: 236)

    // MARK: Lid (local to the lid half: origin at the fold edge's left end, y up)

    /// Teeth roots (the gum's lower edge) and full tooth length.
    static let gumY: CGFloat = 60
    static let teethLength: CGFloat = 58
    /// The fleshy lip over the teeth roots (the teeth tuck behind it while the mimic sleeps): bottom and height.
    static let lipBottom: CGFloat = 50
    static let lipHeight: CGFloat = 46
    /// R3: the gum's lower edge is a lip curve, not a ruler: lowest at the centre (`lipBottom`), rising this much at
    /// the corners. R4 (juror: "still a straight bar"): 10 → 14, and the lip's TOP edge curves too (`lipSag`), so the
    /// upper jaw reads as a lip at every stage.
    static let gumRise: CGFloat = 14
    /// R4: the lip's top edge dips this much at the centre (level at the corners): the band is thickest mid-mouth.
    static let lipSag: CGFloat = 5
    /// R3: how far the fangs slide up behind the lip when tucked, and how far they stay out while it sleeps (5–7 tips
    /// always show: the canines about half, the rest about a third). R4: 44 → 40 (the sagging lip top).
    static let teethTuck: CGFloat = 40
    static let teethAsleep: CGFloat = 0.4
    /// R4: the fangs texture's height (taller: the deeper lip curve).
    static let teethTextureHeight: CGFloat = 80
    /// The brass name plate between the lip and the eye: the name, and a sub-line with the trait and the tier.
    static let plateCenter = CGPoint(x: 335, y: 131)
    static let plateSize = CGSize(width: 460, height: 70)
    /// R3: the gold-multiplier seal over the plate's left end ("GOLD ×1.5"), clear of the name.
    static let sealCenter = CGPoint(x: 112, y: 131)
    static let sealRadius: CGFloat = 31
    /// R5 (juror P2, tester 10): the lid's iron / gilt bands (iron-bound tier and up): their centre lines and half
    /// width (lid art), and the Zzz's lane: the velvet between the lid's left border (x 34) and the left band, so a Z
    /// never crosses a band.
    static let lidBandXs: [CGFloat] = [140, 530]
    static let lidBandHalfWidth: CGFloat = 15
    static let zzzLane: ClosedRange<CGFloat> = 38...121
    /// The brass brow plate over the eye (it tilts angry as the mimic wakes).
    static let browCenter = CGPoint(x: 335, y: 384)
    static let browHalf = CGSize(width: 132, height: 26)
    /// The lid slider (no hinge; never on a fold layout). R3: a short lever in the lid's right edge band, clear of
    /// the lip and teeth (the track starts above the lip), the plate (x ≤ 565) and the Zzz (now upper-left).
    static let sliderX: CGFloat = 620
    static let sliderMinY: CGFloat = 132
    static let sliderMaxY: CGFloat = 360
    static let sliderTrackWidth: CGFloat = 36
    static let sliderKnobSize = CGSize(width: 60, height: 46)

    /// R3: where the App's lid-half teaching words go ("Slide this up… slowly", "Lift this half"): a fixed slot
    /// ABOVE the brow plate, never over the eye or its lashes. Canvas coordinates (y up).
    static let lidLabelSlot = CGRect(x: 110, y: 902, width: 450, height: 44)
    /// The lever's track on the canvas (for the App's lever highlight).
    static var leverTrack: CGRect {
        CGRect(x: sliderX - sliderTrackWidth / 2, y: lidBottom + sliderMinY - 20, width: sliderTrackWidth,
               height: sliderMaxY - sliderMinY + 40)
    }

    static var eyeCenter: CGPoint { ChestArt.mimicEyeCenter(size: lidSize) }
    static var eyeRadius: CGFloat { ChestArt.mimicEyeRadius(size: lidSize) }

    // MARK: Extension (R2: scenes taller than the canvas)

    /// The canvas lid's far border and corner brackets (drawn at the top of the visible lid).
    static let lidCapHeight: CGFloat = 90
    /// The repeating band of lid planks above the canvas lid (two planks).
    static let lidTileHeight: CGFloat = 120
    /// R4 (tester 8: "empty wood panel"): the carved plaque in the extension above the lid on phones ("Iron-bound ·
    /// Chest 4"). Shown when the extension is at least `plaqueMinExtension` tall; centred `plaqueLift` above the
    /// canvas lid's top edge (lid-local y 456), clear of the App's teaching slot (below) and the Daily marker (above,
    /// at the safe-area top).
    static let plaqueSize = CGSize(width: 360, height: 50)
    static let plaqueMinExtension: CGFloat = 100
    static func plaqueCenterY(topExtension t: CGFloat) -> CGFloat {
        lidSize.height + min(max(t * 0.18, plaqueSize.height / 2 + 12), 56)
    }
    /// Below the floor: the chest's front wall (behind the satchel from y 104 down), then the tabletop.
    static let frontWallTop: CGFloat = 104
    static let frontWallMax: CGFloat = 210

    /// The front wall's visible height under the satchel for an extension of `ext` (the rest is tabletop).
    static func frontWallHeight(extension ext: CGFloat) -> CGFloat {
        guard ext > 0 else { return 0 }
        return ext >= 120 ? min(ext - 44, frontWallMax) : ext
    }

    /// Extension above the lid (the rest of the scene height after the bottom extension).
    static func topExtension(_ layout: ScreenLayout) -> CGFloat {
        max(layout.size.height - canvas.height - layout.contentOffsetY, 0)
    }

    static func bottomExtension(_ layout: ScreenLayout) -> CGFloat { max(layout.contentOffsetY, 0) }

    // MARK: Mapping

    /// A floor-space point on the canvas (the same as `ScreenLayout.canvasPoint(fromFloor:)`).
    static func canvas(fromFloor p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: floorTop - p.y) }
    static func floor(fromCanvas p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: floorTop - p.y) }

    /// Which half a touch that starts at canvas `p` belongs to: the floor up to the middle of the fold band (the
    /// extension below the floor counts as floor, above the lid as lid).
    static func startsOnFloor(_ p: CGPoint) -> Bool { p.y < (floorTop + lidBottom) / 2 }

    /// A touch on the floor in floor space: below the canvas (the front wall and table) clamps into the bag strip,
    /// so an overshooting drag still lands in the bag. y may be < 0 (the finger slid onto the lid).
    static func floorTouchPoint(fromCanvas p: CGPoint) -> CGPoint {
        let f = floor(fromCanvas: p)
        return CGPoint(x: min(max(f.x, 0), canvas.width), y: min(f.y, FloorSpace.height - 0.5))
    }

    /// The lid slider's fraction: 0 at the fold … 1 at the top of the visible lid (`topExtension` above the canvas).
    static func lidFraction(canvasY y: CGFloat, topExtension ext: CGFloat) -> Double {
        let h = max(canvas.height - lidBottom + max(ext, 0), 1)
        return Double(min(max((y - lidBottom) / h, 0), 1))
    }

    /// The scene's HUD rects on the floor half (tests: none overlap the hint band or the pause area).
    static var hudRects: [CGRect] {
        [meterRect, torchRect, bagValueRect, counterRect, countdownRect, chainRect, pouchRect]
    }

    /// The same rects in view points (y down, origin top-left of the canvas) for SwiftUI overlays.
    static func viewRect(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX, y: canvas.height - r.maxY, width: r.width, height: r.height)
    }
}

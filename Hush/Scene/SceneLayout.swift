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
/// - the pause coin area, the top-right corner inset from the edges (no scene HUD there).
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

    /// The noise meter plate on the front rim ("NOISE" at the left, the teeth at the full end), its segment well,
    /// and the segment count. Drawn over everything on the floor.
    static let meterRect = CGRect(x: 56, y: 104, width: 558, height: 32)
    static let meterWell = CGRect(x: 142, y: 109, width: 420, height: 22)
    static let meterSegments = 20
    static let meterLabelCenter = CGPoint(x: 99, y: 120)
    static let meterTeethCenter = CGPoint(x: 588, y: 120)

    /// R2: the App's hint line at the floor's back edge by the fold, between the lid and the loot (canvas y 404…452).
    /// The scene keeps its HUD out of it.
    static let hintBand = CGRect(x: 72, y: 404, width: 500, height: 48)
    /// R2: the App's pause coin: the floor half's top-right corner, inset 24 pt from the right edge and 20 pt from the
    /// fold (≥ 16 pt from every canvas edge).
    static let pauseArea = CGRect(x: 582, y: 372, width: 64, height: 64)

    /// The candle on the left rim.
    static let torchRect = CGRect(x: 7, y: 150, width: 38, height: 262)
    static let candleBaseY: CGFloat = 166
    static let candleMaxHeight: CGFloat = 214
    static var candleX: CGFloat { torchRect.midX }
    /// R2: the candle-low countdown ("0:12"), by the candle (over the empty top of its track in the last 15 s).
    static let countdownRect = CGRect(x: 4, y: 300, width: 80, height: 44)

    /// R2: the Hush Chain medallion on the right rim, just above the BANKED plate.
    static let chainCenter = CGPoint(x: 638, y: 176)
    static let chainRadius: CGFloat = 28
    /// The "CHAIN" caption sits just above the medallion.
    static var chainCaptionY: CGFloat { chainCenter.y + chainRadius + 12 }
    static var chainRect: CGRect {
        CGRect(x: chainCenter.x - 32, y: chainCenter.y - chainRadius - 2, width: 64, height: 2 * chainRadius + 24)
    }

    /// IN BAG (left plate): the brass clasp (with the shut-hold ring round it), the label and the number.
    static let bagValueRect = CGRect(x: 12, y: 12, width: 244, height: 80)
    static let claspCenter = CGPoint(x: 56, y: 52)
    static let claspRadius: CGFloat = 30
    static let ringRadius: CGFloat = 37
    static let bagValueLeft: CGFloat = 100
    static let plateLabelY: CGFloat = 78
    static let plateNumberY: CGFloat = 42

    /// BANKED (right plate): the number right-aligned beside a coin stack, the label above it.
    static let counterRect = CGRect(x: 424, y: 12, width: 234, height: 80)
    static let counterCoin = CGPoint(x: 628, y: 46)
    static let counterRight: CGFloat = 600

    /// R2: the leather pouch between the plates (the drop target; bagged loot piles in its mouth).
    static let pouchRect = CGRect(x: 264, y: 4, width: 142, height: 104)
    static let pouchMouth = CGPoint(x: 335, y: 84)

    /// Where bitten loot flies (the mimic's mouth, the middle of the fold).
    static let mouthPoint = CGPoint(x: 335, y: 476)
    /// The middle of the interior (moments' callouts stack here, under the hint band).
    static let titlePoint = CGPoint(x: 335, y: 300)
    static let relicBannerPoint = CGPoint(x: 335, y: 280)

    // MARK: Lid (local to the lid half: origin at the fold edge's left end, y up)

    /// Teeth roots (the gum's lower edge) and full tooth length.
    static let gumY: CGFloat = 60
    static let teethLength: CGFloat = 58
    /// The fleshy lip over the teeth roots (the teeth tuck behind it while the mimic sleeps): bottom and height.
    static let lipBottom: CGFloat = 50
    static let lipHeight: CGFloat = 46
    /// The brass name plate between the lip and the eye: the name, and a sub-line with the trait and the tier.
    static let plateCenter = CGPoint(x: 335, y: 131)
    static let plateSize = CGSize(width: 460, height: 70)
    /// The brass brow plate over the eye (it tilts angry as the mimic wakes).
    static let browCenter = CGPoint(x: 335, y: 384)
    static let browHalf = CGSize(width: 132, height: 26)
    /// The lid slider (no hinge): the lever's track on the right of the lid half.
    static let sliderX: CGFloat = 606
    static let sliderMinY: CGFloat = 40
    static let sliderMaxY: CGFloat = 420

    static var eyeCenter: CGPoint { ChestArt.mimicEyeCenter(size: lidSize) }
    static var eyeRadius: CGFloat { ChestArt.mimicEyeRadius(size: lidSize) }

    // MARK: Extension (R2: scenes taller than the canvas)

    /// The canvas lid's far border and corner brackets (drawn at the top of the visible lid).
    static let lidCapHeight: CGFloat = 90
    /// The repeating band of lid planks above the canvas lid (two planks).
    static let lidTileHeight: CGFloat = 120
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

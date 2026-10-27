import CoreGraphics
import Foundation

/// Where everything sits on the 670 × 952 canvas (SpriteKit points, origin bottom-left, **y up**). Pure values, shared
/// by the scene, its tests and the App (the hint band and the pause button area are the App's to fill).
///
/// Floor half (y 0…456, the SHARP half: the time-critical HUD lives here):
/// - the bag strip y 0…110 (`FloorSpace.bagRect` on the canvas): the satchel, the in-hand value with the shut-hold
///   ring (left), bagged loot (middle), the gold counter (right);
/// - the snore-o-meter on the chest's front rim, y 106…134;
/// - the App's hint band y 138…198 (keep it clear of scene HUD);
/// - the chest interior y 134…420 (`FloorSpace.interior`), the torch gauge on the left rim;
/// - the pause button area, the top-right 70 × 70 (x 600…670, y 386…456): no scene HUD there.
/// Fold band y 456…496 (the brass hinge strip). Lid half y 496…952 (may blur): ambience only.
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

    /// The snore-o-meter plate on the front rim, its segment well, and the segment count.
    static let meterRect = CGRect(x: 88, y: 106, width: 494, height: 28)
    static let meterWell = CGRect(x: 122, y: 110, width: 450, height: 20)
    static let meterSegments = 20

    /// The App's hint line: one line of text just above the meter. The scene keeps its HUD out of it.
    static let hintBand = CGRect(x: 80, y: 138, width: 510, height: 60)
    /// The App's pause button: the floor half's top-right corner.
    static let pauseArea = CGRect(x: 600, y: 386, width: 70, height: 70)

    /// The torch gauge (a candle burning down) on the left rim.
    static let torchRect = CGRect(x: 7, y: 150, width: 38, height: 262)
    static let candleBaseY: CGFloat = 166
    static let candleMaxHeight: CGFloat = 214
    static var candleX: CGFloat { torchRect.midX }

    /// The in-hand value: the brass clasp (with the shut-hold ring round it) and the number beside it.
    static let bagValueRect = CGRect(x: 12, y: 12, width: 244, height: 80)
    static let claspCenter = CGPoint(x: 56, y: 52)
    static let claspRadius: CGFloat = 30
    static let ringRadius: CGFloat = 37
    static let bagValueLeft: CGFloat = 100

    /// The gold counter (banked): the number right-aligned beside a coin stack.
    static let counterRect = CGRect(x: 424, y: 12, width: 234, height: 80)
    static let counterCoin = CGPoint(x: 626, y: 52)
    static let counterRight: CGFloat = 598

    /// Where bitten loot flies (the mimic's mouth, the middle of the fold).
    static let mouthPoint = CGPoint(x: 335, y: 476)
    /// The middle of the interior (moments' titles sit above the hint band).
    static let titlePoint = CGPoint(x: 335, y: 330)
    static let relicBannerPoint = CGPoint(x: 335, y: 300)

    // MARK: Lid (local to the lid half: origin at the fold edge's left end, y up)

    /// Teeth roots (the gum's lower edge) and full tooth length.
    static let gumY: CGFloat = 60
    static let teethLength: CGFloat = 58
    /// The brass name plate under the eye.
    static let plateCenter = CGPoint(x: 335, y: 114)
    static let plateSize = CGSize(width: 340, height: 56)
    /// The lid slider (no hinge): the lever's track on the right of the lid half.
    static let sliderX: CGFloat = 606
    static let sliderMinY: CGFloat = 40
    static let sliderMaxY: CGFloat = 420

    static var eyeCenter: CGPoint { ChestArt.mimicEyeCenter(size: lidSize) }
    static var eyeRadius: CGFloat { ChestArt.mimicEyeRadius(size: lidSize) }

    // MARK: Mapping

    /// A floor-space point on the canvas (the same as `ScreenLayout.canvasPoint(fromFloor:)`).
    static func canvas(fromFloor p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: floorTop - p.y) }
    static func floor(fromCanvas p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: floorTop - p.y) }

    /// Which half a touch that starts at canvas `p` belongs to: the floor up to the middle of the fold band.
    static func startsOnFloor(_ p: CGPoint) -> Bool { p.y < (floorTop + lidBottom) / 2 }

    /// The scene's HUD rects on the floor half (tests: none overlap the hint band or the pause area).
    static var hudRects: [CGRect] { [meterRect, torchRect, bagValueRect, counterRect] }

    /// The same rects in view points (y down, origin top-left of the canvas) for SwiftUI overlays.
    static func viewRect(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX, y: canvas.height - r.maxY, width: r.width, height: r.height)
    }
}

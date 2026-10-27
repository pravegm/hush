import SwiftUI

/// Where the play canvas lands on screen and how canvas rects (SpriteKit: origin bottom-left, y up) map to SwiftUI
/// points (y down). R2 (UX P1-11, juror P0-4): the scene FILLS the screen. Its size is `ScreenLayout.make(hasFold:
/// viewSize:)` (670 wide, taller than 952 on screens narrower than the Duo's), shown aspect-fill, with the 670 × 952
/// canvas at `contentOffsetY` inside it and extension art above the lid and below the floor: no bars. The SpriteView
/// is the whole screen, so the scene and the SwiftUI HUD share this one geometry. Pure; tested.
///
/// Turned round, the scene turns its own world about its centre and the App turns its overlays about the screen's
/// centre: the same point, so these unturned rects stay right after both turns.
struct CanvasFit: Equatable {
    let viewSize: CGSize
    /// The scene's size (canvas points).
    let sceneSize: CGSize
    /// Where canvas y = 0 sits in the scene.
    let contentOffsetY: CGFloat
    /// The scene's rect in view points (it may overhang the view by a fraction of a point: aspect-fill).
    let rect: CGRect
    let scale: CGFloat

    init(viewSize: CGSize, layout: ScreenLayout? = nil) {
        self.viewSize = viewSize
        let l = layout ?? ScreenLayout.make(hasFold: false, viewSize: viewSize)
        sceneSize = l.size
        contentOffsetY = l.contentOffsetY
        let valid = viewSize.width > 0 && viewSize.height > 0 && l.size.width > 0 && l.size.height > 0
        // Aspect-fill in portrait (no bars). R3: a LANDSCAPE view ("Play anyway" on the book-pose card) shows the whole
        // portrait canvas (aspect-fit, the scene does the same), never a crop.
        let sx = valid ? viewSize.width / l.size.width : 1
        let sy = valid ? viewSize.height / l.size.height : 1
        let s = viewSize.width > viewSize.height ? min(sx, sy) : max(sx, sy)
        scale = s
        rect = CGRect(x: (viewSize.width - l.size.width * s) / 2, y: (viewSize.height - l.size.height * s) / 2,
                      width: l.size.width * s, height: l.size.height * s)
    }

    /// A canvas rect (y up) → view points (y down).
    func viewRect(canvas r: CGRect) -> CGRect {
        CGRect(x: rect.minX + r.minX * scale,
               y: rect.minY + (sceneSize.height - contentOffsetY - r.maxY) * scale,
               width: r.width * scale, height: r.height * scale)
    }

    func viewPoint(canvas p: CGPoint) -> CGPoint {
        CGPoint(x: rect.minX + p.x * scale, y: rect.minY + (sceneSize.height - contentOffsetY - p.y) * scale)
    }

    /// The 670 × 952 canvas, the lid half (drawn upper) and the floor half (drawn lower), in view points.
    var canvasRect: CGRect {
        viewRect(canvas: CGRect(x: 0, y: 0, width: ScreenLayout.canvasWidth, height: ScreenLayout.canvasHeight))
    }
    var lidRect: CGRect {
        viewRect(canvas: CGRect(x: 0, y: ScreenLayout.foldMaxY, width: ScreenLayout.canvasWidth,
                                height: ScreenLayout.canvasHeight - ScreenLayout.foldMaxY))
    }
    var floorRect: CGRect {
        viewRect(canvas: CGRect(x: 0, y: 0, width: ScreenLayout.canvasWidth, height: ScreenLayout.foldMinY))
    }

    /// Type over the chest scales with the canvas, never below 0.72 nor above 1 (QA-1 P2-10/11: phone overflow).
    var textScale: CGFloat { min(max(scale, 0.72), 1) }
}

/// The HUD's rects on the play canvas (canvas points, SpriteKit y up), derived from Contracts' ScreenLayout and
/// FloorSpace and the Scene's ChestLayout:
/// - the bag strip is canvas y 0…110 (floor y ≥ FloorSpace.bagMinY); the scene's noise meter sits on the front rim
///   just above it (ChestLayout.meterRect, about y 106…134);
/// - R2 (UX P0-10): SwiftUI's one-line hint lives in `hintBand`, the floor's back edge by the fold (ChestLayout.hintBand,
///   y 404…452): never over the loot or the drag path, right under the mimic's eye;
/// - the pause button is placed from `pauseRect` (ChestLayout.pauseArea) and kept ≥ 16 pt inside the safe area
///   (`AppCanvas.pauseCenter`);
/// - R2 (UX P0-2): the First Chest card sits in `lessonBand`, canvas y 146…262: 12 pt clear of the meter, below the
///   lesson chest's loot (floor y ≤ 150, canvas y ≥ 284 with its radius), so it never covers the meter or the coin.
enum HUDLayout {
    /// The bag strip's top edge (canvas y).
    static var bagTop: CGFloat { ScreenLayout.foldMinY - FloorSpace.bagMinY }
    /// The top of Scene's noise meter.
    static var meterTop: CGFloat { ChestLayout.meterRect.maxY }
    static let pauseSide: CGFloat = 70
    /// The lesson card's clearance over the meter.
    static let meterClearance: CGFloat = 12

    /// Scene's ChestLayout.hintBand.
    static var hintBand: CGRect { ChestLayout.hintBand }

    /// Scene's ChestLayout.pauseArea.
    static var pauseRect: CGRect { ChestLayout.pauseArea }

    /// The IN BAG pouch (the drop target; `hud.bag`'s frame).
    static var bagRect: CGRect { ChestLayout.pouchRect }

    static var lessonBand: CGRect {
        let bottom = max(meterTop, 134) + meterClearance
        return CGRect(x: 50, y: bottom, width: 570, height: 116)
    }

    /// The floor half's whole rect (canvas).
    static var floor: CGRect { CGRect(x: 0, y: 0, width: ScreenLayout.canvasWidth, height: ScreenLayout.foldMinY) }
    static var lid: CGRect {
        CGRect(x: 0, y: ScreenLayout.foldMaxY, width: ScreenLayout.canvasWidth,
               height: ScreenLayout.canvasHeight - ScreenLayout.foldMaxY)
    }

    /// The lid lever's track (no fold), on the canvas: the Scene's own rect (R3: the short lever in the lid's right band).
    static var leverTrack: CGRect { ChestLayout.leverTrack }

    /// R3 (juror P1-6): the lid half's teaching words ("Lift this half", "Lower this half a little") go in the Scene's
    /// fixed slot ABOVE the brow plate, never over the eye or its lashes.
    static var lidLabelBand: CGRect { ChestLayout.lidLabelSlot }

    /// R3: the floor's card area (the closing card), between the noise meter and the fold: it never covers the meter.
    static var cardArea: CGRect {
        let bottom = meterTop + 8
        return CGRect(x: 40, y: bottom, width: ScreenLayout.canvasWidth - 80, height: ScreenLayout.foldMinY - 6 - bottom)
    }
}

/// The screen as the SwiftUI pages see it: size, safe-area insets (already turned round if the canvas is), and the
/// Duo's two halves. On a Duo the main buttons go on the FLOOR half (drawn lower: the sharp, reachable half).
struct AppCanvas: Equatable {
    var size: CGSize
    var insets: EdgeInsets
    var hasFold: Bool
    var turned: Bool

    /// The fold band's half-height either side of the middle (Contracts: 40 pt band).
    static let foldHalf: CGFloat = 22
    /// R2 (juror P1-10): the pause coin stays this far inside the safe area on every side.
    static let pauseInset: CGFloat = 16

    var isCompact: Bool { size.height < 720 }
    var fit: CanvasFit { CanvasFit(viewSize: size) }

    /// The drawn upper half (the lid on a Duo), inside the safe area.
    var lidHalf: CGRect {
        let top = max(insets.top, 8)
        let bottom = hasFold ? size.height / 2 - Self.foldHalf : size.height * 0.5
        return CGRect(x: insets.leading, y: top, width: size.width - insets.leading - insets.trailing,
                      height: max(bottom - top, 0))
    }

    /// The drawn lower half (the floor on a Duo), inside the safe area.
    var floorHalf: CGRect {
        let top = hasFold ? size.height / 2 + Self.foldHalf : size.height * 0.5
        let bottom = size.height - max(insets.bottom, 12)
        return CGRect(x: insets.leading, y: top, width: size.width - insets.leading - insets.trailing,
                      height: max(bottom - top, 0))
    }

    /// The safe area as a rect.
    var safeRect: CGRect {
        CGRect(x: insets.leading, y: insets.top, width: max(size.width - insets.leading - insets.trailing, 0),
               height: max(size.height - insets.top - insets.bottom, 0))
    }

    /// Nothing tappable may overlap the fold band. Pure; tested.
    func isFoldClear(_ r: CGRect) -> Bool {
        guard hasFold else { return true }
        let band = CGRect(x: 0, y: size.height / 2 - Self.foldHalf, width: size.width, height: Self.foldHalf * 2)
        return !r.intersects(band)
    }

    /// The pause coin's centre: the scene's pause area, pulled in so a `side`-pt button keeps `pauseInset` from every
    /// safe edge (it was clipped by the screen edge in R1). Pure; tested.
    func pauseCenter(side: CGFloat = HushTheme.minTap) -> CGPoint {
        let want = fit.viewRect(canvas: HUDLayout.pauseRect)
        let r = safeRect.insetBy(dx: Self.pauseInset + side / 2, dy: Self.pauseInset + side / 2)
        guard r.width > 0, r.height > 0 else { return CGPoint(x: want.midX, y: want.midY) }
        return CGPoint(x: min(max(want.midX, r.minX), r.maxX), y: min(max(want.midY, r.minY), r.maxY))
    }

    /// A readable column width.
    var columnWidth: CGFloat { min(size.width - 40, 520) }
}

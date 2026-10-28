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

    /// R10: the inverse of `viewPoint(canvas:)`: a view point (y down) → canvas points (y up). Pure; tested.
    func canvasPoint(view v: CGPoint) -> CGPoint {
        let s = scale.isFinite && scale > 0 ? scale : 1
        return CGPoint(x: (v.x - rect.minX) / s, y: sceneSize.height - contentOffsetY - (v.y - rect.minY) / s)
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

    /// R4 (UX P1-1, juror P1-2): the gap kept between the hint plate and the pause stud.
    static let pauseGap: CGFloat = 16

    /// R4: where the hint plate may go: the hint band, kept `pauseGap` clear of the pause stud (centred while it can
    /// be). The plate hugs its text inside this rect. R5 (juror P2, tester 9): and kept `foldClearance` clear of the
    /// floor's fold edge (the crease can distort the band right next to the hinge).
    static var hintPlateRect: CGRect { clearOfFold(hintPlateRect(band: hintBand, pause: pauseRect)) }

    /// R5 (juror P2-1, Scene R5 note): the plate's band at the scene's `viewScale` (view points per canvas point): from
    /// the hint band's left end to `pauseGap` short of the pause seat AS DRAWN at that scale (≈ 574 on the Duo, ≈ 528
    /// on a 402 pt phone), and clear of the fold. Wide enough to centre most lines on the chest's axis. Pure; tested.
    static func hintPlateRect(viewScale: CGFloat) -> CGRect {
        hintPlateRect(seat: ChestLayout.pauseSeat(viewScale: viewScale))
    }

    /// R10 (VISUAL-REGRESSION-R9 R1): the same band measured against the seat where it is really drawn
    /// (`AppCanvas.pauseSeatCanvasRect`: the coin's own centre, safe-area clamp included), so a coin pulled in by an
    /// inset (the Duo at k = 1) still keeps `pauseGap` from the plate. Pure; tested.
    static func hintPlateRect(seat: CGRect) -> CGRect {
        let band = hintBand
        let maxX = seat.minX - pauseGap
        guard maxX.isFinite, maxX > band.minX + 100 else { return hintPlateRect }
        return clearOfFold(CGRect(x: band.minX, y: band.minY, width: maxX - band.minX, height: band.height))
    }

    /// R5: canvas points kept between a plate and the floor half's fold edge (`ScreenLayout.foldMinY`).
    static let foldClearance: CGFloat = 20

    /// R5: `r` moved down (canvas y up: away from the fold) until it keeps `foldClearance` from the fold edge. Pure;
    /// tested.
    static func clearOfFold(_ r: CGRect) -> CGRect {
        let maxY = ScreenLayout.foldMinY - foldClearance
        guard r.maxY > maxY else { return r }
        return r.offsetBy(dx: 0, dy: maxY - r.maxY)
    }

    /// R5 (juror P2-1): the chest's centre line (the eye, the name plate and the lock share it), from the Scene.
    static var chestAxisX: CGFloat { ChestLayout.chestCenterX }

    /// R5: where a plate `width` wide starts in `band`: centred on `axis` while it fits, else pushed in just far enough
    /// to stay inside the band (so a long line keeps its size and only the short ones are truly centred). Any units,
    /// as long as they agree. Pure; tested.
    static func plateMinX(width: CGFloat, axis: CGFloat, band: CGRect) -> CGFloat {
        let w = min(max(width.isFinite ? width : 0, 0), band.width)
        return min(max(axis - w / 2, band.minX), band.maxX - w)
    }

    /// R5 (juror P2-2, UX P2-8, frame 26): the Daily marker's centre (view points): on the chest's axis at the lid's far
    /// end, inside the safe area, and at least `markerGap` above the phone's carved plaque ("Wooden · Chest 1") when
    /// the scene draws one. `markerHeight` is the marker plate's height. Pure; tested.
    static let markerGap: CGFloat = 12

    /// The marker may reach this far into the top inset (the Dynamic Island ends well above the safe edge; turned
    /// round, that edge is the home indicator's).
    static let markerInsetAllowance: CGFloat = 6

    static func dailyMarkerCenter(_ info: AppCanvas, markerHeight: CGFloat = 36) -> CGPoint {
        let layout = ScreenLayout.make(hasFold: info.hasFold, viewSize: info.size)
        let fit = CanvasFit(viewSize: info.size, layout: layout)
        let x = fit.viewPoint(canvas: CGPoint(x: chestAxisX, y: 0)).x
        let safe = info.safeRect
        let half = markerHeight / 2
        let preferred = safe.minY + AppCanvas.pauseInset + 16
        let lowest = safe.minY + half - markerInsetAllowance
        let t = ChestLayout.topExtension(layout)
        guard t >= ChestLayout.plaqueMinExtension else { return CGPoint(x: x, y: max(preferred, lowest)) }
        let plaqueTop = ChestLayout.lidBottom + ChestLayout.plaqueCenterY(topExtension: t)
            + ChestLayout.plaqueSize.height / 2
        let plaqueTopView = fit.viewPoint(canvas: CGPoint(x: chestAxisX, y: plaqueTop)).y
        return CGPoint(x: x, y: max(min(preferred, plaqueTopView - markerGap - half), lowest))
    }

    /// Pure; tested.
    static func hintPlateRect(band: CGRect, pause: CGRect, gap: CGFloat = pauseGap) -> CGRect {
        let keepOut = pause.insetBy(dx: -gap, dy: -gap)
        guard band.intersects(keepOut) else { return band }
        let cx = band.midX
        let onRight = keepOut.midX >= cx
        // Shrink symmetrically about the band's centre while that keeps 60 % of it, else cut the stud's side only.
        let half = min(max(onRight ? keepOut.minX - cx : cx - keepOut.maxX, 0), band.width / 2)
        if half * 2 >= band.width * 0.6 {
            return CGRect(x: cx - half, y: band.minY, width: half * 2, height: band.height)
        }
        if onRight {
            return CGRect(x: band.minX, y: band.minY, width: max(keepOut.minX - band.minX, 0), height: band.height)
        }
        let minX = min(keepOut.maxX, band.maxX)
        return CGRect(x: minX, y: band.minY, width: max(band.maxX - minX, 0), height: band.height)
    }

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

    /// R10 (VISUAL-REGRESSION-R9 R1, the Duo at k = 1): the ONE source of truth for the pause coin's place. The coin's
    /// centre (`pauseCenter`, safe-area clamp included) in CANVAS points (y up): the App hands it to the scene
    /// (`ChestScene.pauseSeatCanvasCenter`), which draws its brass seat exactly there, for every k and every inset.
    /// Pure; tested.
    func pauseSeatCanvasCenter(side: CGFloat = HushTheme.minTap) -> CGPoint {
        fit.canvasPoint(view: pauseCenter(side: side))
    }

    /// R10: the seat's bounding square on the canvas (the coin's radius plus the brass ring, at this canvas's scale).
    /// Pure; tested.
    func pauseSeatCanvasRect(side: CGFloat = HushTheme.minTap) -> CGRect {
        let c = pauseSeatCanvasCenter(side: side)
        let r = ChestLayout.pauseSeatRadius(viewScale: fit.scale)
        return CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
    }

    /// A readable column width.
    var columnWidth: CGFloat { min(size.width - 40, 520) }

    /// R5 (UX P1-1, juror P1-1, frames 30 and 39): a fold whose floor half is short (a phone emulating the fold: ~345 pt
    /// on a 393 pt phone, turned round) lays Home and the lesson's final card out with compact metrics, so the plain
    /// (non-scrolling) version fits at the default text size. The Duo's own floor half (~440 pt) keeps the full ones.
    static let tightFloorBelow: CGFloat = 420
    var tightFloor: Bool { hasFold && floorHalf.height < Self.tightFloorBelow }
}

/// R5 (juror P2-1): lays its child (a hugging plate) centred on `axisX` (its own coordinates, 0 = its left edge) while
/// the plate fits, else pushed in just far enough to stay inside (`HUDLayout.plateMinX`). It fills the frame it is
/// given, so the plate's vertical placement is unchanged.
struct AxisCentredLayout: Layout {
    var axisX: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let h = proposal.height ?? subviews.map { $0.sizeThatFits(ProposedViewSize(width: w, height: nil)).height }
            .max() ?? 0
        return CGSize(width: w.isFinite ? w : 0, height: h.isFinite ? h : 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for child in subviews {
            let size = child.sizeThatFits(ProposedViewSize(width: bounds.width, height: bounds.height))
            let w = min(size.width.isFinite ? size.width : bounds.width, bounds.width)
            let x = HUDLayout.plateMinX(width: w, axis: bounds.minX + axisX, band: bounds)
            child.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading,
                        proposal: ProposedViewSize(width: w, height: bounds.height))
        }
    }
}

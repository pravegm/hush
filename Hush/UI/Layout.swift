import SwiftUI

/// Where the 670 × 952 play canvas lands on screen (aspect-fit, centred) and how canvas rects (SpriteKit: origin
/// bottom-left, y up) map to SwiftUI points (y down). The SpriteView is framed to `rect` exactly, so the scene and the
/// SwiftUI HUD share one geometry and the bars around it are SwiftUI's dungeon colour. Pure; tested.
struct CanvasFit: Equatable {
    let viewSize: CGSize
    let rect: CGRect
    let scale: CGFloat

    init(viewSize: CGSize) {
        self.viewSize = viewSize
        let w = ScreenLayout.canvasWidth
        let h = ScreenLayout.canvasHeight
        let s = viewSize.width > 0 && viewSize.height > 0 ? min(viewSize.width / w, viewSize.height / h) : 1
        scale = s
        rect = CGRect(x: (viewSize.width - w * s) / 2, y: (viewSize.height - h * s) / 2, width: w * s, height: h * s)
    }

    /// A canvas rect (y up) → view points (y down).
    func viewRect(canvas r: CGRect) -> CGRect {
        CGRect(x: rect.minX + r.minX * scale, y: rect.minY + (ScreenLayout.canvasHeight - r.maxY) * scale,
               width: r.width * scale, height: r.height * scale)
    }

    func viewPoint(canvas p: CGPoint) -> CGPoint {
        CGPoint(x: rect.minX + p.x * scale, y: rect.minY + (ScreenLayout.canvasHeight - p.y) * scale)
    }

    /// The lid half (drawn upper) and the floor half (drawn lower), in view points.
    var lidRect: CGRect { viewRect(canvas: ScreenLayout(hasFold: true).lidRect) }
    var floorRect: CGRect { viewRect(canvas: ScreenLayout(hasFold: true).floorRect) }
}

/// The HUD's rects on the play canvas (canvas points, SpriteKit y up), derived from Contracts' ScreenLayout and
/// FloorSpace. Agreed with the Scene engineer (design/NEEDS.md, App R1):
/// - the bag strip is canvas y 0…110 (floor y ≥ FloorSpace.bagMinY);
/// - the scene's noise meter sits on the front rim just above it (ChestLayout.meterRect, canvas y 106…134);
/// - SwiftUI's one-line hint lives in `hintBand`, the 60 pt just above the meter (ChestLayout.hintBand, y 138…198);
/// - the pause button is the floor half's top-right 70 × 70 (`pauseRect`, at the fold, outside the chest interior);
/// - the First Chest card sits in `lessonBand` (canvas y 138…254); the lesson chest's loot lies behind it (floor y
///   ≤ 160, canvas y ≥ 296), so the card never covers what it asks you to grab.
enum HUDLayout {
    /// The bag strip's top edge (canvas y).
    static var bagTop: CGFloat { ScreenLayout.foldMinY - FloorSpace.bagMinY }
    /// The top of Scene's snore-o-meter (ChestLayout.meterRect, y 106…134).
    static var meterTop: CGFloat { ChestLayout.meterRect.maxY }
    static let hintHeight: CGFloat = 60
    static let pauseSide: CGFloat = 70

    /// Scene's ChestLayout.hintBand (x 80…590, y 138…198).
    static var hintBand: CGRect { ChestLayout.hintBand }

    /// Scene's ChestLayout.pauseArea (x 600…670, y 386…456).
    static var pauseRect: CGRect { ChestLayout.pauseArea }

    static var lessonBand: CGRect {
        CGRect(x: 50, y: hintBand.minY, width: 570, height: 116)
    }

    /// The floor half's whole rect (canvas).
    static var floor: CGRect { ScreenLayout(hasFold: true).floorRect }
    static var lid: CGRect { ScreenLayout(hasFold: true).lidRect }
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

    /// Nothing tappable may overlap the fold band. Pure; tested.
    func isFoldClear(_ r: CGRect) -> Bool {
        guard hasFold else { return true }
        let band = CGRect(x: 0, y: size.height / 2 - Self.foldHalf, width: size.width, height: Self.foldHalf * 2)
        return !r.intersects(band)
    }

    /// A readable column width.
    var columnWidth: CGFloat { min(size.width - 40, 520) }
}

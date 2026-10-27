import CoreGraphics
import Foundation

/// The game's colours (ARCHITECTURE "Scene API"): a candlelit dungeon, warm golds against deep teal-black.
struct HushPalette: Equatable, Sendable {
    let wood: RGBA
    let woodDark: RGBA
    let iron: RGBA
    let gold: RGBA
    let velvet: RGBA
    let tongue: RGBA
    let dungeon: RGBA
    let dungeonDeep: RGBA
    let candle: RGBA
    let danger: RGBA
    let amber: RGBA
    let text: RGBA
}

/// One loot item's art, centred at the origin, **y up** (SpriteKit / maths). For SwiftUI (y down) flip it with
/// `ChestArt.flippedVertically(_:)`.
///
/// Draw it in this order: stroke `parts` thick in a dark outline (`ChestArt.outline`, width `outlineWidth`), fill
/// `parts` (or `silhouette`) with `fill`, stroke `detail` with `rim` at `detailWidth`, fill `shine` with `glint`, then
/// cut `holes` (or fill them with the background). Stroking every part before filling any keeps the outline on the
/// union's edge only.
struct LootArt {
    var silhouette: CGPath
    var parts: [CGPath]
    var detail: CGPath
    var shine: CGPath
    var holes: CGPath
    var detailWidth: CGFloat
    var outlineWidth: CGFloat
}

/// The chest, mimic and loot drawn with CoreGraphics paths, so SwiftUI (Home, Codex, icon) and SpriteKit share one
/// art source. Pure functions: no UIKit, no SpriteKit, no actor isolation (safe inside `Shape.path(in:)`).
///
/// Conventions: loot and relic paths are centred at the origin, y up, fitting inside a circle of `radius` (the
/// silhouette; strokes may reach `outlineWidth / 2` further). Every closed sub-path winds counter-clockwise (y up), so
/// the non-zero fill of a combined path is the union of its parts.
enum ChestArt {
    static let palette = HushPalette(
        wood: RGBA(hex: 0x8A5A33),
        woodDark: RGBA(hex: 0x4A2C18),
        iron: RGBA(hex: 0x58626D),
        gold: RGBA(hex: 0xFFC94A),
        velvet: RGBA(hex: 0x5C1A33),
        tongue: RGBA(hex: 0xE45A72),
        dungeon: RGBA(hex: 0x12282C),
        dungeonDeep: RGBA(hex: 0x071315),
        candle: RGBA(hex: 0xFFD98A),
        danger: RGBA(hex: 0xFF4A3D),
        amber: RGBA(hex: 0xFFAA33),
        text: RGBA(hex: 0xFFF4DC))

    /// The chunky cartoon outline colour (a warm near-black).
    static let outline = RGBA(hex: 0x1C100A)

    // MARK: Public API (ARCHITECTURE)

    static func lootPath(_ kind: LootKind, radius: CGFloat) -> CGPath {
        lootArt(kind, radius: radius).silhouette
    }

    static func lootColors(_ kind: LootKind) -> (fill: RGBA, rim: RGBA, glint: RGBA) {
        switch kind {
        case .copper:
            return (RGBA(hex: 0xDC8442), RGBA(hex: 0x7A3A14), RGBA(hex: 0xFFE2B4))
        case .silver:
            return (RGBA(hex: 0xD2DCE6), RGBA(hex: 0x56626F), RGBA(hex: 0xFFFFFF))
        case .gem(let c):
            switch c {
            case .ruby: return (RGBA(hex: 0xEC3352), RGBA(hex: 0x6E0E22), RGBA(hex: 0xFFC8D2))
            case .emerald: return (RGBA(hex: 0x2CC67C), RGBA(hex: 0x0D5232), RGBA(hex: 0xCCFFE4))
            case .sapphire: return (RGBA(hex: 0x3C7CEE), RGBA(hex: 0x12306E), RGBA(hex: 0xD2E2FF))
            case .amethyst: return (RGBA(hex: 0xA95CE4), RGBA(hex: 0x4A1D6E), RGBA(hex: 0xEED8FF))
            }
        case .relic(let id):
            let t = relicTint(id)
            return (t, t.mixed(with: RGBA(0, 0, 0), 0.55), t.mixed(with: RGBA(1, 1, 1), 0.75))
        case .oil:
            return (RGBA(hex: 0xF4AA38), RGBA(hex: 0x6E3A0E), RGBA(hex: 0xFFF2CC))
        }
    }

    static func relicPath(_ shape: RelicShape, radius: CGFloat) -> CGPath {
        relicArt(shape, radius: radius).silhouette
    }

    /// The mimic's eye on the lid half, `wake` 0 (asleep: a closed lid) … 1 (biting: wide open). `size` is the lid
    /// half's size; the paths are in its coordinates (origin bottom-left, y up), the eye at `mimicEyeCenter(size:)`.
    /// - `white`: the visible eyeball between the lids (a thin sliver when asleep, never empty).
    /// - `iris`: the iris disc, centred where it looks straight ahead (offset it to track; clip it to `white`).
    /// - `lidTop`: the upper eyelid skin, from the lash line up over the eyeball (draw it over the iris).
    static func mimicEye(wake: Double, size: CGSize) -> (white: CGPath, iris: CGPath, lidTop: CGPath) {
        let g = EyeGeometry(wake: wake, size: size)
        let white = CGMutablePath()
        white.move(to: CGPoint(x: g.c.x + g.a, y: g.cornerY))
        white.addQuadCurve(to: CGPoint(x: g.c.x - g.a, y: g.cornerY),
                           control: CGPoint(x: g.c.x, y: 2 * g.topMid - g.cornerY))
        white.addQuadCurve(to: CGPoint(x: g.c.x + g.a, y: g.cornerY),
                           control: CGPoint(x: g.c.x, y: 2 * g.botMid - g.cornerY))
        white.closeSubpath()

        let iris = CGMutablePath()
        ArtPrim.oval(iris, CGRect(x: g.irisCenter.x - g.irisRadius, y: g.irisCenter.y - g.irisRadius,
                                  width: 2 * g.irisRadius, height: 2 * g.irisRadius))

        let lid = CGMutablePath()
        let pad = g.r * 0.12
        lid.move(to: CGPoint(x: g.c.x - g.a - pad, y: g.cornerY - pad * 0.3))
        lid.addLine(to: CGPoint(x: g.c.x - g.a, y: g.cornerY))
        lid.addQuadCurve(to: CGPoint(x: g.c.x + g.a, y: g.cornerY),
                         control: CGPoint(x: g.c.x, y: 2 * g.topMid - g.cornerY))
        lid.addLine(to: CGPoint(x: g.c.x + g.a + pad, y: g.cornerY - pad * 0.3))
        lid.addCurve(to: CGPoint(x: g.c.x - g.a - pad, y: g.cornerY - pad * 0.3),
                     control1: CGPoint(x: g.c.x + g.a * 1.15, y: g.cornerY + g.r * 1.75),
                     control2: CGPoint(x: g.c.x - g.a * 1.15, y: g.cornerY + g.r * 1.75))
        lid.closeSubpath()
        return (white, iris, lid)
    }

    // MARK: Extras for the scene and SwiftUI

    /// The eye's centre and radius in the lid half (`mimicEye` coordinates).
    static func mimicEyeCenter(size: CGSize) -> CGPoint { CGPoint(x: size.width * 0.5, y: size.height * 0.56) }
    static func mimicEyeRadius(size: CGSize) -> CGFloat { min(size.width, size.height) * 0.2 }

    /// The sleeping eye's lash line (the shut lid's edge) with five drooping lashes, a path to stroke, in `mimicEye`
    /// coordinates.
    static func mimicLashes(size: CGSize) -> CGPath {
        let g = EyeGeometry(wake: 0, size: size)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: g.c.x - g.a, y: g.cornerY))
        p.addQuadCurve(to: CGPoint(x: g.c.x + g.a, y: g.cornerY),
                       control: CGPoint(x: g.c.x, y: 2 * g.topMid - g.cornerY))
        for i in 0..<5 {
            let t = 0.18 + CGFloat(i) * 0.16
            // A point on the curve (quadratic Bézier).
            let u = 1 - t
            let x = u * u * (g.c.x - g.a) + 2 * u * t * g.c.x + t * t * (g.c.x + g.a)
            let y = u * u * g.cornerY + 2 * u * t * (2 * g.topMid - g.cornerY) + t * t * g.cornerY
            let lean = (t - 0.5) * g.r * 0.5
            p.move(to: CGPoint(x: x, y: y))
            p.addLine(to: CGPoint(x: x + lean, y: y - g.r * 0.26))
        }
        return p
    }

    /// A row of `count` chunky rounded teeth across `width`, roots on a line at y = 0 and tips at y = −height
    /// (`pointingDown`) or +height. Canines (the 2nd and the 2nd-last) are 25 % longer. Closed, counter-clockwise.
    static func teethRow(width: CGFloat, height: CGFloat, count: Int, pointingDown: Bool) -> CGPath {
        let n = max(count, 1)
        let p = CGMutablePath()
        let slot = width / CGFloat(n)
        for i in 0..<n {
            let canine = (i == 1 || i == n - 2) && n >= 4
            let len = height * (canine ? 1.0 : 0.8)
            let left = CGFloat(i) * slot + slot * 0.06
            let right = CGFloat(i + 1) * slot - slot * 0.06
            let mid = (left + right) / 2
            let s: CGFloat = pointingDown ? -1 : 1
            // Down-pointing teeth run left → tip → right; up-pointing ones right → tip → left (both counter-clockwise).
            let x0 = pointingDown ? left : right
            let x1 = pointingDown ? right : left
            let k: CGFloat = pointingDown ? 1 : -1
            // Root a little past the line so neighbours overlap the gum; a fat rounded tip.
            p.move(to: CGPoint(x: x0, y: -s * 4))
            p.addCurve(to: CGPoint(x: mid, y: s * len),
                       control1: CGPoint(x: x0, y: s * len * 0.55),
                       control2: CGPoint(x: mid - k * slot * 0.32, y: s * len))
            p.addCurve(to: CGPoint(x: x1, y: -s * 4),
                       control1: CGPoint(x: mid + k * slot * 0.32, y: s * len),
                       control2: CGPoint(x: x1, y: s * len * 0.55))
            p.closeSubpath()
        }
        return p
    }

    /// The full art for a loot item (see `LootArt`).
    static func lootArt(_ kind: LootKind, radius: CGFloat) -> LootArt {
        let r = max(radius, 1)
        switch kind {
        case .copper: return coinPile(r)
        case .silver: return ingot(r)
        case .gem: return gem(r)
        case .relic(let id): return relicArt(relicShape(id), radius: r)
        case .oil: return flask(r)
        }
    }

    /// The full art for a relic silhouette.
    static func relicArt(_ shape: RelicShape, radius: CGFloat) -> LootArt {
        let r = max(radius, 1)
        var s = ArtSketch(r)
        switch shape {
        case .crown:
            s.poly([(-0.86, -0.62), (0.86, -0.62), (0.86, 0.5), (0.44, 0.06), (0, 0.72), (-0.44, 0.06), (-0.86, 0.5)])
            s.oval(-0.84, 0.56, 0.13, 0.13)
            s.oval(0, 0.8, 0.14, 0.14)
            s.oval(0.84, 0.56, 0.13, 0.13)
            s.line([(-0.86, -0.22), (0.86, -0.22)])
            s.detailOval(-0.48, -0.42, 0.1, 0.1)
            s.detailOval(0, -0.42, 0.12, 0.12)
            s.detailOval(0.48, -0.42, 0.1, 0.1)
            s.shineOval(-0.5, 0.12, 0.08, 0.2)
            s.shineOval(0.12, 0.4, 0.06, 0.12)
        case .goblet:
            let bowl = CGMutablePath()
            bowl.move(to: s.p(-0.66, 0.82))
            bowl.addCurve(to: s.p(0, 0.02), control1: s.p(-0.66, 0.3), control2: s.p(-0.36, 0.02))
            bowl.addCurve(to: s.p(0.66, 0.82), control1: s.p(0.36, 0.02), control2: s.p(0.66, 0.3))
            bowl.closeSubpath()
            s.part(bowl)
            s.rrect(-0.11, -0.64, 0.22, 0.72, 0.05)
            s.oval(0, -0.24, 0.18, 0.1)
            s.oval(0, -0.74, 0.56, 0.18)
            s.detailOval(0, 0.82, 0.62, 0.09)
            s.line([(-0.58, 0.52), (0.58, 0.52)])
            s.detailOval(0, 0.32, 0.1, 0.1)
            s.shineOval(-0.38, 0.5, 0.08, 0.2)
        case .teacup:
            let cup = CGMutablePath()
            cup.move(to: s.p(-0.72, 0.5))
            cup.addCurve(to: s.p(0, -0.42), control1: s.p(-0.72, -0.1), control2: s.p(-0.4, -0.42))
            cup.addCurve(to: s.p(0.72, 0.5), control1: s.p(0.4, -0.42), control2: s.p(0.72, -0.1))
            cup.closeSubpath()
            s.part(cup)
            s.oval(0.74, 0.12, 0.26, 0.24)
            s.oval(0, -0.52, 0.92, 0.2)
            s.holeOval(0.78, 0.12, 0.12, 0.11)
            s.detailOval(0, 0.5, 0.7, 0.1)
            let steam = CGMutablePath()
            steam.move(to: s.p(-0.18, 0.66))
            steam.addCurve(to: s.p(-0.14, 0.96), control1: s.p(-0.32, 0.76), control2: s.p(0.0, 0.86))
            steam.move(to: s.p(0.16, 0.66))
            steam.addCurve(to: s.p(0.2, 0.94), control1: s.p(0.02, 0.76), control2: s.p(0.34, 0.84))
            s.detail.addPath(steam)
            s.shineOval(-0.42, 0.16, 0.08, 0.18)
        case .key:
            s.oval(-0.5, 0, 0.4, 0.4)
            s.rrect(-0.2, -0.12, 1.08, 0.24, 0.06)
            s.rrect(0.5, -0.42, 0.14, 0.34, 0.03)
            s.rrect(0.72, -0.34, 0.14, 0.26, 0.03)
            s.holeOval(-0.5, 0, 0.17, 0.17)
            s.detailOval(-0.5, 0, 0.29, 0.29)
            s.line([(-0.1, -0.14), (-0.1, 0.14)])
            s.shineOval(-0.66, 0.2, 0.07, 0.1)
            s.shineOval(0.32, 0.05, 0.24, 0.035)
        case .ring:
            s.oval(0, -0.12, 0.66, 0.66)
            s.oval(0, 0.6, 0.3, 0.26)
            s.holeOval(0, -0.12, 0.42, 0.42)
            s.detailOval(0, 0.6, 0.17, 0.14)
            s.shineOval(-0.44, 0.1, 0.07, 0.14)
            s.shineOval(-0.08, 0.68, 0.06, 0.05)
        case .amulet:
            s.oval(0, -0.18, 0.56, 0.66)
            s.oval(0, 0.56, 0.16, 0.16)
            let chain = CGMutablePath()
            chain.move(to: s.p(-0.8, 0.92))
            chain.addQuadCurve(to: s.p(0, 0.6), control: s.p(-0.5, 0.62))
            chain.addQuadCurve(to: s.p(0.8, 0.92), control: s.p(0.5, 0.62))
            s.detail.addPath(chain)
            s.detailOval(0, -0.18, 0.28, 0.34)
            s.detailOval(0, -0.18, 0.44, 0.52)
            s.shineOval(-0.1, -0.02, 0.07, 0.12)
        case .skull:
            s.oval(0, 0.16, 0.74, 0.68)
            s.rrect(-0.44, -0.8, 0.88, 0.62, 0.16)
            s.holeOval(-0.3, 0.06, 0.2, 0.2)
            s.holeOval(0.3, 0.06, 0.2, 0.2)
            s.holePoly([(0, -0.08), (-0.09, -0.27), (0.09, -0.27)])
            s.line([(-0.36, -0.5), (0.36, -0.5)])
            s.line([(-0.2, -0.5), (-0.2, -0.76)])
            s.line([(0, -0.5), (0, -0.78)])
            s.line([(0.2, -0.5), (0.2, -0.76)])
            s.line([(0.1, 0.82), (0.18, 0.62), (0.08, 0.5)])
            s.shineOval(-0.36, 0.5, 0.14, 0.08)
        case .egg:
            let egg = CGMutablePath()
            egg.move(to: s.p(0.66, -0.1))
            egg.addCurve(to: s.p(0, 0.9), control1: s.p(0.66, 0.45), control2: s.p(0.36, 0.9))
            egg.addCurve(to: s.p(-0.66, -0.1), control1: s.p(-0.36, 0.9), control2: s.p(-0.66, 0.45))
            egg.addCurve(to: s.p(0, -0.88), control1: s.p(-0.66, -0.55), control2: s.p(-0.36, -0.88))
            egg.addCurve(to: s.p(0.66, -0.1), control1: s.p(0.36, -0.88), control2: s.p(0.66, -0.55))
            egg.closeSubpath()
            s.part(egg)
            s.detailOval(0.2, 0.3, 0.06, 0.05)
            s.detailOval(-0.25, -0.12, 0.07, 0.06)
            s.detailOval(0.3, -0.42, 0.05, 0.05)
            s.detailOval(-0.1, 0.56, 0.05, 0.04)
            s.line([(-0.6, 0.05), (-0.3, 0.16), (-0.1, -0.02), (0.15, 0.14), (0.4, 0.0), (0.62, 0.1)])
            s.shineOval(-0.3, 0.42, 0.1, 0.18)
        case .mirror:
            s.oval(0, 0.26, 0.6, 0.66)
            s.rrect(-0.13, -0.96, 0.26, 0.66, 0.1)
            s.oval(0, -0.42, 0.2, 0.12)
            s.detailOval(0, 0.26, 0.44, 0.5)
            s.shinePoly([(-0.24, 0.5), (-0.1, 0.62), (0.18, 0.1), (0.04, -0.02)])
        case .horn:
            let horn = CGMutablePath()
            horn.move(to: s.p(-0.84, 0.62))
            horn.addCurve(to: s.p(0.6, -0.42), control1: s.p(-0.9, -0.1), control2: s.p(-0.2, -0.56))
            horn.addLine(to: s.p(0.72, 0.22))
            horn.addCurve(to: s.p(-0.74, 0.66), control1: s.p(-0.1, 0.0), control2: s.p(-0.66, 0.2))
            horn.closeSubpath()
            s.part(horn)
            s.oval(0.68, -0.1, 0.2, 0.4)
            s.detailOval(0.7, -0.1, 0.1, 0.28)
            s.line([(-0.74, 0.16), (-0.58, 0.32)])
            s.line([(-0.32, -0.28), (-0.2, -0.04)])
            s.line([(0.18, -0.46), (0.26, -0.1)])
            s.shineOval(-0.42, -0.1, 0.16, 0.05)
        case .dice:
            var rot = CGAffineTransform(rotationAngle: 0.22)
            let die = CGMutablePath()
            ArtPrim.roundedRect(die, CGRect(x: -0.62 * r, y: -0.62 * r, width: 1.24 * r, height: 1.24 * r),
                                corner: 0.22 * r)
            s.part(die.copy(using: &rot) ?? die)
            let pips: [(CGFloat, CGFloat)] = [(-0.32, 0.32), (0, 0), (0.32, -0.32), (0.32, 0.32), (-0.32, -0.32)]
            for q in pips {
                let pt = CGPoint(x: q.0 * r, y: q.1 * r).applying(rot)
                ArtPrim.oval(s.detail, CGRect(x: pt.x - 0.07 * r, y: pt.y - 0.07 * r, width: 0.14 * r,
                                              height: 0.14 * r))
            }
            s.shineOval(-0.34, 0.44, 0.14, 0.05)
        case .compass:
            s.oval(0, -0.06, 0.84, 0.84)
            s.oval(0, 0.84, 0.14, 0.12)
            s.detailOval(0, -0.06, 0.64, 0.64)
            s.closedLine([(0, 0.5), (0.12, -0.06), (0, -0.62), (-0.12, -0.06)])
            s.line([(0.64, -0.06), (0.52, -0.06)])
            s.line([(-0.64, -0.06), (-0.52, -0.06)])
            s.line([(0, -0.7), (0, -0.6)])
            s.shineOval(-0.4, 0.3, 0.12, 0.06)
        }
        return s.build()
    }

    /// Flips a y-up path into SwiftUI's y-down space (about y = 0; translate after if needed).
    static func flippedVertically(_ path: CGPath) -> CGPath {
        var t = CGAffineTransform(scaleX: 1, y: -1)
        return path.copy(using: &t) ?? path
    }

    /// The relic's catalogue silhouette and tint (a crown in gold for an id the catalogue doesn't know).
    static func relicShape(_ id: RelicID) -> RelicShape {
        RelicCatalog.all.first(where: { $0.id == id })?.shape ?? .crown
    }

    static func relicTint(_ id: RelicID) -> RGBA {
        RelicCatalog.all.first(where: { $0.id == id })?.tint ?? palette.gold
    }

    // MARK: Loot silhouettes

    private static func coinPile(_ r: CGFloat) -> LootArt {
        var s = ArtSketch(r)
        s.oval(-0.42, -0.26, 0.52, 0.44)
        s.oval(0.42, -0.22, 0.52, 0.44)
        s.oval(0, 0.2, 0.56, 0.48)
        s.detailOval(0, 0.2, 0.56, 0.48)
        s.detailOval(0, 0.2, 0.34, 0.28)
        s.closedLine([(0, 0.34), (0.1, 0.2), (0, 0.06), (-0.1, 0.2)])
        s.line([(-0.86, -0.32), (-0.7, -0.58)])
        s.line([(0.86, -0.28), (0.7, -0.54)])
        s.shineOval(-0.2, 0.44, 0.16, 0.07)
        s.shineOval(-0.62, -0.12, 0.1, 0.05)
        s.shineOval(0.6, -0.08, 0.1, 0.05)
        return s.build()
    }

    private static func ingot(_ r: CGFloat) -> LootArt {
        var s = ArtSketch(r)
        s.rrect(-0.92, -0.58, 1.84, 1.16, 0.22)
        let inner = CGMutablePath()
        ArtPrim.roundedRect(inner, CGRect(x: -0.58 * r, y: -0.28 * r, width: 1.16 * r, height: 0.56 * r),
                            corner: 0.1 * r)
        s.detail.addPath(inner)
        s.line([(-0.58, 0.28), (-0.82, 0.48)])
        s.line([(0.58, 0.28), (0.82, 0.48)])
        s.line([(-0.58, -0.28), (-0.82, -0.48)])
        s.line([(0.58, -0.28), (0.82, -0.48)])
        s.shinePoly([(-0.44, 0.2), (-0.26, 0.2), (-0.36, -0.2), (-0.54, -0.2)])
        s.shineOval(0.6, 0.4, 0.08, 0.05)
        return s.build()
    }

    private static func gem(_ r: CGFloat) -> LootArt {
        var s = ArtSketch(r)
        s.poly([(-0.55, 0.5), (0.55, 0.5), (0.95, 0.12), (0, -0.92), (-0.95, 0.12)])
        s.line([(-0.95, 0.12), (0.95, 0.12)])
        s.line([(-0.55, 0.5), (-0.3, 0.12), (0, 0.5), (0.3, 0.12), (0.55, 0.5)])
        s.line([(-0.3, 0.12), (0, -0.92)])
        s.line([(0.3, 0.12), (0, -0.92)])
        s.shinePoly([(-0.5, 0.44), (-0.12, 0.44), (-0.3, 0.18)])
        s.shineOval(0.42, -0.06, 0.06, 0.1)
        return s.build()
    }

    private static func flask(_ r: CGFloat) -> LootArt {
        var s = ArtSketch(r)
        s.oval(0, -0.25, 0.68, 0.64)
        s.rrect(-0.2, 0.25, 0.4, 0.42, 0.06)
        s.rrect(-0.27, 0.6, 0.54, 0.32, 0.12)
        s.line([(-0.22, 0.38), (0.22, 0.38)])
        let level = CGMutablePath()
        level.move(to: s.p(-0.6, -0.1))
        level.addCurve(to: s.p(0.6, -0.1), control1: s.p(-0.2, 0.02), control2: s.p(0.2, -0.22))
        s.detail.addPath(level)
        let flame = CGMutablePath()
        flame.move(to: s.p(0, -0.24))
        flame.addCurve(to: s.p(0, -0.72), control1: s.p(0.24, -0.4), control2: s.p(0.2, -0.72))
        flame.addCurve(to: s.p(0, -0.24), control1: s.p(-0.2, -0.72), control2: s.p(-0.24, -0.4))
        s.detail.addPath(flame)
        s.shineOval(-0.36, -0.04, 0.1, 0.2)
        return s.build()
    }
}

// MARK: - Geometry helpers

/// The eye's measurements for a wake level (shared by `mimicEye` and `mimicLashes`).
struct EyeGeometry {
    let c: CGPoint
    let r: CGFloat
    let a: CGFloat
    let open: CGFloat
    let cornerY: CGFloat
    let topMid: CGFloat
    let botMid: CGFloat
    let irisCenter: CGPoint
    let irisRadius: CGFloat

    init(wake: Double, size: CGSize) {
        let w = CGFloat(min(max(wake.isFinite ? wake : 0, 0), 1))
        c = ChestArt.mimicEyeCenter(size: size)
        r = max(ChestArt.mimicEyeRadius(size: size), 1)
        a = r * 1.25
        open = 0.04 + 0.96 * w
        cornerY = c.y - r * 0.1
        // Shut, the lid droops into a sleepy "︶"; it lifts and arches as the eye opens.
        topMid = cornerY + r * (1.05 * open - 0.3 * (1 - open) * (1 - open))
        botMid = cornerY - r * 0.72 * open
        irisCenter = CGPoint(x: c.x, y: cornerY + r * 0.16 * open)
        irisRadius = r * 0.6
    }
}

/// Path primitives that always wind counter-clockwise (y up).
enum ArtPrim {
    static func oval(_ p: CGMutablePath, _ rect: CGRect) {
        let k: CGFloat = 0.552_284_75
        let cx = rect.midX, cy = rect.midY, rx = rect.width / 2, ry = rect.height / 2
        p.move(to: CGPoint(x: cx + rx, y: cy))
        p.addCurve(to: CGPoint(x: cx, y: cy + ry), control1: CGPoint(x: cx + rx, y: cy + ry * k),
                   control2: CGPoint(x: cx + rx * k, y: cy + ry))
        p.addCurve(to: CGPoint(x: cx - rx, y: cy), control1: CGPoint(x: cx - rx * k, y: cy + ry),
                   control2: CGPoint(x: cx - rx, y: cy + ry * k))
        p.addCurve(to: CGPoint(x: cx, y: cy - ry), control1: CGPoint(x: cx - rx, y: cy - ry * k),
                   control2: CGPoint(x: cx - rx * k, y: cy - ry))
        p.addCurve(to: CGPoint(x: cx + rx, y: cy), control1: CGPoint(x: cx + rx * k, y: cy - ry),
                   control2: CGPoint(x: cx + rx, y: cy - ry * k))
        p.closeSubpath()
    }

    static func roundedRect(_ p: CGMutablePath, _ rect: CGRect, corner: CGFloat) {
        let c = max(0, min(corner, rect.width / 2, rect.height / 2))
        p.move(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.midX, y: rect.maxY),
                 radius: c)
        p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.midY),
                 radius: c)
        p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.midX, y: rect.minY),
                 radius: c)
        p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.midY),
                 radius: c)
        p.closeSubpath()
    }

    /// A closed polygon, reversed if needed so it winds counter-clockwise.
    static func polygon(_ p: CGMutablePath, _ pts: [CGPoint]) {
        guard pts.count >= 3 else { return }
        var area: CGFloat = 0
        for i in 0..<pts.count {
            let a = pts[i], b = pts[(i + 1) % pts.count]
            area += a.x * b.y - b.x * a.y
        }
        let ordered = area < 0 ? Array(pts.reversed()) : pts
        p.move(to: ordered[0])
        for q in ordered.dropFirst() { p.addLine(to: q) }
        p.closeSubpath()
    }
}

/// Builds a `LootArt` in units of the radius.
struct ArtSketch {
    let r: CGFloat
    var parts: [CGPath] = []
    let detail = CGMutablePath()
    let shine = CGMutablePath()
    let holes = CGMutablePath()

    init(_ r: CGFloat) { self.r = r }

    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * r, y: y * r) }

    private func rect(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> CGRect {
        CGRect(x: (cx - rx) * r, y: (cy - ry) * r, width: 2 * rx * r, height: 2 * ry * r)
    }

    mutating func part(_ path: CGPath) { parts.append(path) }

    mutating func oval(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) {
        let q = CGMutablePath()
        ArtPrim.oval(q, rect(cx, cy, rx, ry))
        parts.append(q)
    }

    mutating func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: CGFloat) {
        let q = CGMutablePath()
        ArtPrim.roundedRect(q, CGRect(x: x * r, y: y * r, width: w * r, height: h * r), corner: c * r)
        parts.append(q)
    }

    mutating func poly(_ pts: [(CGFloat, CGFloat)]) {
        let q = CGMutablePath()
        ArtPrim.polygon(q, pts.map { p($0.0, $0.1) })
        parts.append(q)
    }

    func line(_ pts: [(CGFloat, CGFloat)]) {
        guard let f = pts.first else { return }
        detail.move(to: p(f.0, f.1))
        for q in pts.dropFirst() { detail.addLine(to: p(q.0, q.1)) }
    }

    func closedLine(_ pts: [(CGFloat, CGFloat)]) {
        line(pts)
        detail.closeSubpath()
    }

    func detailOval(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) {
        ArtPrim.oval(detail, rect(cx, cy, rx, ry))
    }

    func shineOval(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) {
        ArtPrim.oval(shine, rect(cx, cy, rx, ry))
    }

    func shinePoly(_ pts: [(CGFloat, CGFloat)]) {
        ArtPrim.polygon(shine, pts.map { p($0.0, $0.1) })
    }

    func holeOval(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) {
        ArtPrim.oval(holes, rect(cx, cy, rx, ry))
    }

    func holePoly(_ pts: [(CGFloat, CGFloat)]) {
        ArtPrim.polygon(holes, pts.map { p($0.0, $0.1) })
    }

    func build() -> LootArt {
        let all = CGMutablePath()
        for q in parts { all.addPath(q) }
        return LootArt(silhouette: all, parts: parts, detail: detail, shine: shine, holes: holes,
                       detailWidth: max(r * 0.09, 1), outlineWidth: max(r * 0.16, 1.5))
    }
}

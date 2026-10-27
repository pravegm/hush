import CoreGraphics
import CoreText
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

/// A small parchment tag with text on an item (the oil flask's "+6s"), in the art's coordinates (points, y up).
struct LootTag {
    var text: String
    var center: CGPoint
    var size: CGSize
}

/// One loot item's art, centred at the origin, **y up** (SpriteKit / maths). For SwiftUI (y down) flip it with
/// `ChestArt.flippedVertically(_:)`, or better, use the rendered images (`ChestArt.lootImage`, `relicImage`): they
/// are the exact pixels the scene uses (one art source).
///
/// Draw order (`ChestArt.drawArt`): stroke `parts` thick in a dark outline (`ChestArt.outline`, `outlineWidth`), fill
/// them with `fill`; if `layerDetail` is set the parts are drawn back to front one by one, each with its own outline
/// and rim detail (coin stacks). Then `shade` (rim colour, 35 %), `detail` (rim colour, `detailWidth`), `shine`
/// (glint), cut `holes`, and the `tag`.
struct LootArt {
    var silhouette: CGPath
    var parts: [CGPath]
    var detail: CGPath
    var shine: CGPath
    var holes: CGPath
    var detailWidth: CGFloat
    var outlineWidth: CGFloat
    var shade: CGPath
    var layerDetail: [CGPath]?
    var tag: LootTag?
}

/// The chest, mimic and loot drawn with CoreGraphics, so SwiftUI (Home, Codex, Results, badges) and SpriteKit share
/// one art source. Pure functions: no UIKit, no SpriteKit, no actor isolation (safe inside `Shape.path(in:)` and off
/// the main thread).
///
/// Conventions: loot and relic paths are centred at the origin, y up, fitting inside a square of half-side `radius`
/// (the silhouette; strokes may reach `outlineWidth` further).
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

    /// The mimic's flesh (eyelid, gums): one colour family everywhere (game, portrait, icon).
    static let flesh = RGBA(hex: 0xB9566C)
    static let fleshDark = RGBA(hex: 0x6E2238)

    // MARK: Public API (ARCHITECTURE)

    static func lootPath(_ kind: LootKind, radius: CGFloat) -> CGPath {
        lootArt(kind, radius: radius).silhouette
    }

    static func lootColors(_ kind: LootKind) -> (fill: RGBA, rim: RGBA, glint: RGBA) {
        switch kind {
        case .copper:
            // R2: clear gold discs (the juror's #F5C542 face, #B8862B rim).
            return (RGBA(hex: 0xF5C542), RGBA(hex: 0x8E6217), RGBA(hex: 0xFFF3C4))
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
            return relicColors(relicTint(id))
        case .oil:
            return (RGBA(hex: 0xF4AA38), RGBA(hex: 0x6E3A0E), RGBA(hex: 0xFFF2CC))
        }
    }

    static func relicColors(_ t: RGBA) -> (fill: RGBA, rim: RGBA, glint: RGBA) {
        (t, t.mixed(with: RGBA(0, 0, 0), 0.55), t.mixed(with: RGBA(1, 1, 1), 0.75))
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

    /// The fleshy bed the eye sits in (R2: an eyelid, not a porthole): the wide-open eye's outline, puffed out.
    static func mimicEyeBed(size: CGSize) -> CGPath {
        let g = EyeGeometry(wake: 1, size: size)
        let p = CGMutablePath()
        let a = g.a * 1.3
        let top = g.cornerY + (g.topMid - g.cornerY) * 1.25 + g.r * 0.1
        let bot = g.cornerY - (g.cornerY - g.botMid) * 1.2 - g.r * 0.04
        p.move(to: CGPoint(x: g.c.x + a, y: g.cornerY))
        p.addCurve(to: CGPoint(x: g.c.x - a, y: g.cornerY),
                   control1: CGPoint(x: g.c.x + a * 0.8, y: top + (top - g.cornerY) * 0.3),
                   control2: CGPoint(x: g.c.x - a * 0.8, y: top + (top - g.cornerY) * 0.3))
        p.addCurve(to: CGPoint(x: g.c.x + a, y: g.cornerY),
                   control1: CGPoint(x: g.c.x - a * 0.75, y: bot - (g.cornerY - bot) * 0.25),
                   control2: CGPoint(x: g.c.x + a * 0.75, y: bot - (g.cornerY - bot) * 0.25))
        p.closeSubpath()
        return p
    }

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

    /// R2: a row of `count` pointed fangs with rounded tips (the app icon's teeth: cute-scary) across `width`, roots on
    /// a line at y = 0 and tips at y = −height (`pointingDown`) or +height. The 2nd and the 2nd-last are long canines;
    /// lengths vary a little and one tooth is chipped. One closed sub-path per tooth.
    static func teethRow(width: CGFloat, height: CGFloat, count: Int, pointingDown: Bool) -> CGPath {
        let n = max(count, 1)
        let p = CGMutablePath()
        let slot = width / CGFloat(n)
        let s: CGFloat = pointingDown ? -1 : 1
        let chipped = n >= 6 ? n / 2 + 1 : -1
        for i in 0..<n {
            let canine = (i == 1 || i == n - 2) && n >= 4
            var len = height * (canine ? 1.0 : 0.7 + 0.06 * CGFloat(sin(Double(i) * 2.3)))
            if !canine && (i == 0 || i == n - 1) { len *= 0.85 }
            let inset = slot * (canine ? 0.04 : 0.08)
            let left = CGFloat(i) * slot + inset
            let right = CGFloat(i + 1) * slot - inset
            let mid = (left + right) / 2
            let half = (right - left) / 2
            // Root a little past the line so neighbours overlap the gum.
            p.move(to: CGPoint(x: left, y: -s * 4))
            if i == chipped {
                let cut = len * 0.74
                p.addCurve(to: CGPoint(x: mid - half * 0.22, y: s * cut),
                           control1: CGPoint(x: left, y: s * cut * 0.4),
                           control2: CGPoint(x: mid - half * 0.5, y: s * cut * 0.9))
                p.addLine(to: CGPoint(x: mid + half * 0.3, y: s * cut * 0.86))
                p.addCurve(to: CGPoint(x: right, y: -s * 4),
                           control1: CGPoint(x: mid + half * 0.6, y: s * cut * 0.7),
                           control2: CGPoint(x: right, y: s * cut * 0.4))
            } else {
                p.addCurve(to: CGPoint(x: mid - half * 0.14, y: s * len * 0.95),
                           control1: CGPoint(x: left, y: s * len * 0.38),
                           control2: CGPoint(x: mid - half * 0.3, y: s * len * 0.82))
                p.addQuadCurve(to: CGPoint(x: mid + half * 0.14, y: s * len * 0.95),
                               control: CGPoint(x: mid, y: s * len * 1.05))
                p.addCurve(to: CGPoint(x: right, y: -s * 4),
                           control1: CGPoint(x: mid + half * 0.3, y: s * len * 0.82),
                           control2: CGPoint(x: right, y: s * len * 0.38))
            }
            p.closeSubpath()
        }
        return p
    }

    /// How many coins an item of this value is drawn as (R2: higher values are a stack of 2–3).
    static func coinCount(_ kind: LootKind, value: Int) -> Int {
        switch kind {
        case .copper: return value >= 9 ? 3 : (value >= 7 ? 2 : 1)
        case .silver: return value >= 30 ? 2 : 1
        case .gem, .relic, .oil: return 1
        }
    }

    /// The full art for a loot item (see `LootArt`). `value` picks the coin stack.
    static func lootArt(_ kind: LootKind, radius: CGFloat, value: Int = 0) -> LootArt {
        let r = max(radius, 1)
        switch kind {
        case .copper: return coins(r, count: coinCount(kind, value: value), silver: false)
        case .silver: return coins(r, count: coinCount(kind, value: value), silver: true)
        case .gem: return gem(r)
        case .relic(let id): return relicArt(relicShape(id), radius: r)
        case .oil: return flask(r)
        }
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

    // MARK: Rendering (the one art source for SpriteKit textures and SwiftUI images)

    /// The square side, in points, of an item image of `radius` (art plus outline room).
    static func artSide(radius: CGFloat) -> CGFloat {
        let r = max(radius.rounded(), 4)
        return ceil(2 * r + 2 * (max(r * 0.16, 1.5) + 4))
    }

    /// Draws a `LootArt` centred at the context's origin (y up).
    static func drawArt(_ ctx: CGContext, _ art: LootArt, _ col: (fill: RGBA, rim: RGBA, glint: RGBA), radius r: CGFloat) {
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        let lightFrom = CGPoint(x: -r * 0.6, y: r * 0.85)
        let lightTo = CGPoint(x: r * 0.6, y: -r * 0.9)
        let body = [ScenePaint.lighter(col.fill, 0.35), col.fill, ScenePaint.darker(col.fill, 0.3)]
        if let layers = art.layerDetail, layers.count == art.parts.count {
            // Back to front, each with its own outline (coin stacks read as separate coins).
            for (i, p) in art.parts.enumerated() {
                Painter.stroke(ctx, p, ScenePaint.outline, width: art.outlineWidth * 2, 0.92)
                Painter.gradient(ctx, p, body, [0, 0.5, 1], from: lightFrom, to: lightTo)
                Painter.stroke(ctx, layers[i], col.rim, width: art.detailWidth, 0.85)
            }
        } else {
            // Every part stroked before any is filled, so only the union's edge shows.
            for p in art.parts {
                Painter.stroke(ctx, p, ScenePaint.outline, width: art.outlineWidth * 2, 0.92)
            }
            for p in art.parts {
                Painter.gradient(ctx, p, body, [0, 0.5, 1], from: lightFrom, to: lightTo)
            }
        }
        if !art.shade.isEmpty { Painter.fill(ctx, art.shade, col.rim, 0.35) }
        Painter.stroke(ctx, art.detail, col.rim, width: art.detailWidth, 0.9)
        Painter.fill(ctx, art.shine, col.glint, 0.85)
        if !art.holes.isEmpty {
            ctx.saveGState()
            ctx.setBlendMode(.clear)
            ctx.addPath(art.holes)
            ctx.fillPath()
            ctx.restoreGState()
            Painter.stroke(ctx, art.holes, ScenePaint.outline, width: art.detailWidth * 1.2, 0.9)
        }
        if let tag = art.tag { drawTag(ctx, tag) }
    }

    /// A relic not yet found: a simplified dark silhouette (no detail, so the shape is hinted, not given away).
    static func drawLocked(_ ctx: CGContext, _ art: LootArt, fill: RGBA, edge: RGBA) {
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        for p in art.parts { Painter.stroke(ctx, p, edge, width: art.outlineWidth * 1.6, 1) }
        for p in art.parts { Painter.fill(ctx, p, fill) }
        if !art.holes.isEmpty {
            ctx.saveGState()
            ctx.setBlendMode(.clear)
            ctx.addPath(art.holes)
            ctx.fillPath()
            ctx.restoreGState()
        }
    }

    private static func drawTag(_ ctx: CGContext, _ tag: LootTag) {
        let r = CGRect(x: tag.center.x - tag.size.width / 2, y: tag.center.y - tag.size.height / 2,
                       width: tag.size.width, height: tag.size.height)
        let p = Painter.roundRect(r, tag.size.height * 0.3)
        Painter.stroke(ctx, p, outline, width: max(tag.size.height * 0.16, 1.2), 0.95)
        Painter.fill(ctx, p, RGBA(hex: 0xF6E7C1))
        let fontSize = tag.size.height * 0.72
        let font = CTFontCreateUIFontForLanguage(.emphasizedSystem, fontSize, nil)
            ?? CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): ScenePaint.cg(RGBA(hex: 0x4A1E06)),
        ]
        let str = NSAttributedString(string: tag.text, attributes: attrs)
        let line = CTLineCreateWithAttributedString(str as CFAttributedString)
        let b = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        ctx.saveGState()
        ctx.textMatrix = .identity
        ctx.textPosition = CGPoint(x: r.midX - b.width / 2 - b.minX, y: r.midY - b.height / 2 - b.minY)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    /// Renders `draw` (y up, origin at the image centre, in points) into a square image `side` points across.
    static func renderImage(side: CGFloat, scale: CGFloat, draw: (CGContext) -> Void) -> CGImage? {
        let px = Int((max(side, 1) * max(scale, 0.25)).rounded(.up))
        guard px > 0 else { return nil }
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let k = CGFloat(px) / max(side, 1)
        ctx.scaleBy(x: k, y: k)
        ctx.translateBy(x: side / 2, y: side / 2)
        draw(ctx)
        return ctx.makeImage()
    }

    /// The item exactly as the scene draws it (SwiftUI: `Image(decorative: img, scale: scale)` is
    /// `artSide(radius:)` points square). Cached.
    static func lootImage(_ kind: LootKind, value: Int = 0, radius: CGFloat, scale: CGFloat = 3) -> CGImage? {
        let r = max(radius.rounded(), 4)
        let n = coinCount(kind, value: value)
        let key = "loot|\(lootKeyName(kind))|\(Int(r))|\(n)|\(Int(scale * 100))"
        return ArtImageCache.shared.image(key) {
            renderImage(side: artSide(radius: r), scale: scale) { ctx in
                drawArt(ctx, lootArt(kind, radius: r, value: value), lootColors(kind), radius: r)
            }
        }
    }

    /// A relic for the Codex, Results, badges and the in-game reveal: found (its art in its tint) or not yet (a dark,
    /// simplified silhouette). `artSide(radius:)` points square. Cached.
    static func relicImage(_ relic: Relic, found: Bool, radius: CGFloat, scale: CGFloat = 3) -> CGImage? {
        let r = max(radius.rounded(), 4)
        let t = relic.tint
        let key = "relic|\(relic.shape.rawValue)|\(found)|\(Int(r))|\(Int(scale * 100))|"
            + "\(Int(t.r * 255)),\(Int(t.g * 255)),\(Int(t.b * 255))"
        return ArtImageCache.shared.image(key) {
            renderImage(side: artSide(radius: r), scale: scale) { ctx in
                let art = relicArt(relic.shape, radius: r)
                if found {
                    drawArt(ctx, art, relicColors(t), radius: r)
                } else {
                    drawLocked(ctx, art, fill: RGBA(hex: 0x16262A), edge: RGBA(hex: 0x3D5A52))
                }
            }
        }
    }

    static func lootKeyName(_ kind: LootKind) -> String {
        switch kind {
        case .copper: return "copper"
        case .silver: return "silver"
        case .gem(let c): return "gem-\(c.rawValue)"
        case .relic(let id): return "relic-\(id.rawValue)"
        case .oil: return "oil"
        }
    }

    // MARK: Loot

    /// Gold (or silver) discs seen from above: rim, embossed star (gold) or keyhole (silver), a crescent shine.
    private static func coins(_ r: CGFloat, count: Int, silver: Bool) -> LootArt {
        var s = ArtSketch(r)
        let spots: [(CGFloat, CGFloat, CGFloat)]
        switch count {
        case 3: spots = [(0.26, -0.3, 0.66), (-0.3, -0.16, 0.66), (0.0, 0.24, 0.7)]
        case 2: spots = [(0.2, -0.2, 0.74), (-0.16, 0.14, 0.78)]
        default: spots = [(0, 0, 0.88)]
        }
        var layers: [CGPath] = []
        for q in spots {
            s.oval(q.0, q.1, q.2, q.2)
            let ring = CGMutablePath()
            ArtPrim.oval(ring, CGRect(x: (q.0 - q.2 * 0.78) * r, y: (q.1 - q.2 * 0.78) * r, width: q.2 * 1.56 * r,
                                      height: q.2 * 1.56 * r))
            layers.append(ring)
        }
        s.layered(layers)
        guard let top = spots.last else { return s.build() }
        let (cx, cy, cr) = top
        if silver {
            // A keyhole emboss.
            s.detailOval(cx, cy + cr * 0.12, cr * 0.16, cr * 0.16)
            s.closedLine([(cx - cr * 0.06, cy + cr * 0.0), (cx + cr * 0.06, cy + cr * 0.0), (cx + cr * 0.12, cy - cr * 0.3),
                          (cx - cr * 0.12, cy - cr * 0.3)])
            s.shadeOval(cx, cy + cr * 0.12, cr * 0.1, cr * 0.1)
        } else {
            // A five-point star emboss.
            var star: [(CGFloat, CGFloat)] = []
            for k in 0..<10 {
                let a = CGFloat.pi / 2 + CGFloat(k) * .pi / 5
                let rr = (k % 2 == 0 ? 0.36 : 0.15) * cr
                star.append((cx + cos(a) * rr, cy + sin(a) * rr))
            }
            s.closedLine(star)
            s.shadePoly(star)
        }
        // A crescent shine at the top-left.
        let a = CGMutablePath()
        ArtPrim.oval(a, CGRect(x: (cx - cr * 0.12 - cr * 0.72) * r, y: (cy + cr * 0.12 - cr * 0.72) * r,
                               width: cr * 1.44 * r, height: cr * 1.44 * r))
        let b = CGMutablePath()
        ArtPrim.oval(b, CGRect(x: (cx - cr * 0.0 - cr * 0.72) * r, y: (cy + cr * 0.0 - cr * 0.72) * r,
                               width: cr * 1.44 * r, height: cr * 1.44 * r))
        let crescent = a.subtracting(b)
        let clip = CGMutablePath()
        ArtPrim.oval(clip, CGRect(x: (cx - cr * 0.86) * r, y: cy * r - cr * 0.86 * r, width: cr * 1.72 * r,
                                  height: cr * 1.72 * r))
        let upper = CGMutablePath()
        ArtPrim.polygon(upper, [s.p(cx - cr, cy - cr * 0.1), s.p(cx + cr * 0.1, cy + cr), s.p(cx - cr, cy + cr)])
        s.shine.addPath(crescent.intersection(clip).intersection(upper))
        s.shineOval(cx + cr * 0.42, cy - cr * 0.42, cr * 0.07, cr * 0.07)
        return s.build()
    }

    private static func gem(_ r: CGFloat) -> LootArt {
        var s = ArtSketch(r)
        s.poly([(-0.55, 0.5), (0.55, 0.5), (0.95, 0.12), (0, -0.92), (-0.95, 0.12)])
        s.line([(-0.95, 0.12), (0.95, 0.12)])
        s.line([(-0.55, 0.5), (-0.3, 0.12), (0, 0.5), (0.3, 0.12), (0.55, 0.5)])
        s.line([(-0.3, 0.12), (0, -0.92)])
        s.line([(0.3, 0.12), (0, -0.92)])
        s.line([(-0.62, 0.12), (-0.2, -0.5)])
        s.line([(0.62, 0.12), (0.2, -0.5)])
        s.shadePoly([(0.3, 0.12), (0.95, 0.12), (0, -0.92)])
        s.shadePoly([(0.0, 0.5), (0.55, 0.5), (0.3, 0.12)])
        s.shinePoly([(-0.5, 0.44), (-0.12, 0.44), (-0.3, 0.18)])
        s.shinePoly([(-0.86, 0.1), (-0.36, 0.1), (-0.12, -0.5)])
        s.shineOval(0.42, -0.06, 0.06, 0.1)
        return s.build()
    }

    /// Candle oil: a corked amber flask with a little "+6s" tag (the seconds it gives).
    private static func flask(_ r: CGFloat) -> LootArt {
        var s = ArtSketch(r)
        s.oval(-0.1, -0.24, 0.66, 0.62)
        s.rrect(-0.29, 0.26, 0.38, 0.38, 0.06)
        s.rrect(-0.36, 0.58, 0.52, 0.34, 0.12)
        s.line([(-0.32, 0.4), (0.12, 0.4)])
        let level = CGMutablePath()
        level.move(to: s.p(-0.66, -0.12))
        level.addCurve(to: s.p(0.46, -0.12), control1: s.p(-0.3, 0.0), control2: s.p(0.1, -0.24))
        s.detail.addPath(level)
        let flame = CGMutablePath()
        flame.move(to: s.p(-0.1, -0.26))
        flame.addCurve(to: s.p(-0.1, -0.7), control1: s.p(0.12, -0.4), control2: s.p(0.1, -0.7))
        flame.addCurve(to: s.p(-0.1, -0.26), control1: s.p(-0.3, -0.7), control2: s.p(-0.32, -0.4))
        s.detail.addPath(flame)
        s.line([(0.1, 0.44), (0.5, 0.2)])
        s.shadeOval(0.12, -0.48, 0.34, 0.26)
        s.shineOval(-0.46, -0.04, 0.1, 0.2)
        let secs = Int(Tuning.oilSeconds.rounded())
        s.tag = LootTag(text: "+\(secs)s", center: s.p(0.5, 0.02), size: CGSize(width: r * 0.98, height: r * 0.58))
        return s.build()
    }

    // MARK: Relics (24 silhouettes, one per RelicShape)

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
            s.shadePoly([(0.4, -0.62), (0.86, -0.62), (0.86, -0.22), (0.4, -0.22)])
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
            s.shadeOval(0.36, 0.42, 0.14, 0.26)
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
            s.detailOval(0, 0.04, 0.12, 0.12)
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
            // A band in three-quarter view under a big faceted stone in a claw setting.
            s.oval(0, -0.3, 0.76, 0.5)
            s.holeOval(0, -0.3, 0.52, 0.3)
            s.poly([(-0.3, 0.16), (0.3, 0.16), (0.2, 0.0), (-0.2, 0.0)])
            s.poly([(-0.44, 0.44), (-0.22, 0.74), (0.22, 0.74), (0.44, 0.44), (0, 0.06)])
            s.line([(-0.44, 0.44), (0.44, 0.44)])
            s.line([(-0.22, 0.74), (-0.12, 0.44), (0, 0.06)])
            s.line([(0.22, 0.74), (0.12, 0.44), (0, 0.06)])
            s.detailOval(0, -0.3, 0.64, 0.4)
            s.shadePoly([(0.0, 0.06), (0.44, 0.44), (0.12, 0.44)])
            s.shinePoly([(-0.34, 0.46), (-0.18, 0.66), (-0.1, 0.46)])
            s.shineOval(-0.56, -0.14, 0.06, 0.14)
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
            s.shadeOval(0.08, -0.26, 0.2, 0.26)
            s.shineOval(-0.1, -0.02, 0.07, 0.12)
        case .skull:
            // Wide cranium, cheekbones, a narrower jaw: a skull, not a light bulb.
            s.oval(0, 0.22, 0.8, 0.68)
            s.rrect(-0.62, -0.5, 1.24, 0.5, 0.2)
            s.rrect(-0.38, -0.92, 0.76, 0.52, 0.14)
            s.holeOval(-0.32, 0.02, 0.22, 0.2)
            s.holeOval(0.32, 0.02, 0.22, 0.2)
            s.holePoly([(0, -0.14), (-0.1, -0.34), (0.1, -0.34)])
            s.line([(-0.3, -0.66), (0.3, -0.66)])
            s.line([(-0.15, -0.5), (-0.15, -0.84)])
            s.line([(0, -0.5), (0, -0.86)])
            s.line([(0.15, -0.5), (0.15, -0.84)])
            s.line([(0.12, 0.88), (0.2, 0.66), (0.08, 0.52)])
            s.shadeOval(0.5, 0.32, 0.14, 0.28)
            s.shineOval(-0.38, 0.56, 0.16, 0.09)
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
            s.shadeOval(0.32, -0.3, 0.2, 0.4)
            s.shineOval(-0.3, 0.42, 0.1, 0.18)
        case .mirror:
            // A hand mirror with side curls, a crest and a short ringed handle (not a paddle).
            s.oval(0, 0.3, 0.56, 0.6)
            s.oval(-0.58, 0.3, 0.13, 0.13)
            s.oval(0.58, 0.3, 0.13, 0.13)
            s.poly([(-0.18, 0.84), (0, 1.0), (0.18, 0.84)])
            s.rrect(-0.1, -0.5, 0.2, 0.24, 0.04)
            s.rrect(-0.15, -0.96, 0.3, 0.48, 0.12)
            s.oval(0, -0.48, 0.2, 0.07)
            s.detailOval(0, 0.3, 0.42, 0.46)
            s.line([(-0.15, -0.72), (0.15, -0.72)])
            s.detailOval(0, 0.92, 0.04, 0.04)
            s.shinePoly([(-0.26, 0.5), (-0.12, 0.64), (0.14, 0.1), (0.0, -0.02)])
            s.shinePoly([(0.12, 0.62), (0.2, 0.68), (0.3, 0.44), (0.22, 0.4)])
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
                ArtPrim.oval(s.shade, CGRect(x: pt.x - 0.06 * r, y: pt.y - 0.06 * r, width: 0.12 * r,
                                             height: 0.12 * r))
            }
            s.shineOval(-0.34, 0.44, 0.14, 0.05)
        case .compass:
            s.oval(0, -0.06, 0.84, 0.84)
            s.oval(0, 0.84, 0.14, 0.12)
            s.detailOval(0, -0.06, 0.64, 0.64)
            s.closedLine([(0, 0.5), (0.12, -0.06), (0, -0.62), (-0.12, -0.06)])
            s.shadePoly([(0, 0.5), (0.12, -0.06), (-0.12, -0.06)])
            s.line([(0.64, -0.06), (0.52, -0.06)])
            s.line([(-0.64, -0.06), (-0.52, -0.06)])
            s.line([(0, -0.7), (0, -0.6)])
            s.shineOval(-0.4, 0.3, 0.12, 0.06)
        case .candlestick:
            s.oval(0, -0.8, 0.72, 0.16)
            s.rrect(-0.12, -0.72, 0.24, 0.38, 0.06)
            s.oval(0, -0.34, 0.36, 0.1)
            s.rrect(-0.2, -0.32, 0.4, 0.8, 0.08)
            let fl = CGMutablePath()
            fl.move(to: s.p(0, 0.54))
            fl.addCurve(to: s.p(0, 0.98), control1: s.p(0.24, 0.58), control2: s.p(0.14, 0.82))
            fl.addCurve(to: s.p(0, 0.54), control1: s.p(-0.14, 0.82), control2: s.p(-0.24, 0.58))
            fl.closeSubpath()
            s.part(fl)
            s.oval(0.72, -0.7, 0.2, 0.16)
            s.holeOval(0.72, -0.7, 0.1, 0.07)
            s.line([(-0.12, 0.48), (-0.12, 0.22)])
            s.line([(0.08, 0.48), (0.08, 0.32)])
            s.detailOval(0, -0.8, 0.5, 0.08)
            s.shineOval(0, 0.68, 0.06, 0.1)
            s.shineOval(-0.1, 0.06, 0.05, 0.25)
        case .hourglass:
            s.rrect(-0.72, 0.7, 1.44, 0.2, 0.06)
            s.rrect(-0.72, -0.9, 1.44, 0.2, 0.06)
            let g = CGMutablePath()
            g.move(to: s.p(-0.5, 0.7))
            g.addCurve(to: s.p(-0.08, 0), control1: s.p(-0.56, 0.3), control2: s.p(-0.1, 0.18))
            g.addCurve(to: s.p(-0.5, -0.7), control1: s.p(-0.1, -0.18), control2: s.p(-0.56, -0.3))
            g.addLine(to: s.p(0.5, -0.7))
            g.addCurve(to: s.p(0.08, 0), control1: s.p(0.56, -0.3), control2: s.p(0.1, -0.18))
            g.addCurve(to: s.p(0.5, 0.7), control1: s.p(0.1, 0.18), control2: s.p(0.56, 0.3))
            g.closeSubpath()
            s.part(g)
            s.rrect(-0.68, -0.7, 0.1, 1.4, 0.04)
            s.rrect(0.58, -0.7, 0.1, 1.4, 0.04)
            s.shadePoly([(-0.42, -0.7), (0.42, -0.7), (0.12, -0.36), (-0.12, -0.36)])
            s.shadePoly([(-0.26, 0.34), (0.26, 0.34), (0, 0.08)])
            s.line([(0, 0.04), (0, -0.36)])
            s.line([(-0.6, 0.8), (0.6, 0.8)])
            s.line([(-0.6, -0.8), (0.6, -0.8)])
            s.shineOval(-0.3, 0.42, 0.05, 0.16)
        case .bell:
            let b = CGMutablePath()
            b.move(to: s.p(-0.78, -0.6))
            b.addLine(to: s.p(0.78, -0.6))
            b.addCurve(to: s.p(0.46, -0.3), control1: s.p(0.72, -0.5), control2: s.p(0.5, -0.44))
            b.addCurve(to: s.p(0, 0.72), control1: s.p(0.44, 0.4), control2: s.p(0.36, 0.72))
            b.addCurve(to: s.p(-0.46, -0.3), control1: s.p(-0.36, 0.72), control2: s.p(-0.44, 0.4))
            b.addCurve(to: s.p(-0.78, -0.6), control1: s.p(-0.5, -0.44), control2: s.p(-0.72, -0.5))
            b.closeSubpath()
            s.part(b)
            s.rrect(-0.84, -0.72, 1.68, 0.16, 0.08)
            s.oval(0, -0.84, 0.16, 0.13)
            s.oval(0, 0.84, 0.17, 0.14)
            s.holeOval(0, 0.84, 0.08, 0.06)
            s.line([(-0.5, -0.38), (0.5, -0.38)])
            s.line([(-0.38, 0.1), (0.38, 0.1)])
            s.shadePoly([(0.2, 0.5), (0.4, -0.3), (0.7, -0.58), (0.36, -0.58)])
            s.shinePoly([(-0.3, 0.4), (-0.16, 0.56), (-0.28, -0.2), (-0.42, -0.26)])
        case .lantern:
            s.oval(0, 0.86, 0.17, 0.12)
            s.holeOval(0, 0.86, 0.08, 0.05)
            s.poly([(-0.48, 0.56), (0.48, 0.56), (0.24, 0.78), (-0.24, 0.78)])
            s.rrect(-0.4, -0.62, 0.8, 1.2, 0.08)
            s.rrect(-0.54, -0.88, 1.08, 0.28, 0.08)
            s.line([(-0.14, 0.56), (-0.14, -0.6)])
            s.line([(0.14, 0.56), (0.14, -0.6)])
            s.line([(-0.4, -0.14), (0.4, -0.14)])
            s.line([(-0.5, -0.74), (0.5, -0.74)])
            s.shinePoly([(0, 0.3), (0.1, 0.04), (0, -0.22), (-0.1, 0.04)])
            s.shineOval(-0.3, 0.24, 0.04, 0.2)
            s.shadePoly([(0.14, 0.56), (0.4, 0.56), (0.4, -0.6), (0.14, -0.6)])
        case .pocketWatch:
            s.oval(0, -0.14, 0.78, 0.78)
            s.rrect(-0.1, 0.6, 0.2, 0.18, 0.04)
            s.oval(0, 0.86, 0.21, 0.13)
            s.holeOval(0, 0.86, 0.1, 0.055)
            s.detailOval(0, -0.14, 0.6, 0.6)
            s.line([(0, 0.4), (0, 0.32)])
            s.line([(0.54, -0.14), (0.46, -0.14)])
            s.line([(0, -0.68), (0, -0.6)])
            s.line([(-0.54, -0.14), (-0.46, -0.14)])
            s.line([(0, -0.14), (0, 0.24)])
            s.line([(0, -0.14), (0.26, -0.28)])
            s.shadeOval(0.0, -0.14, 0.05, 0.05)
            s.shineOval(-0.42, 0.14, 0.1, 0.18)
        case .spyglass:
            s.xf = CGAffineTransform(rotationAngle: 0.6)
            s.rrect(0.18, -0.26, 0.7, 0.52, 0.08)
            s.rrect(0.84, -0.31, 0.14, 0.62, 0.05)
            s.rrect(-0.4, -0.2, 0.62, 0.4, 0.06)
            s.rrect(-0.9, -0.14, 0.54, 0.28, 0.06)
            s.line([(0.2, -0.26), (0.2, 0.26)])
            s.line([(-0.38, -0.2), (-0.38, 0.2)])
            s.line([(0.5, -0.26), (0.5, 0.26)])
            s.shadePoly([(-0.9, -0.14), (0.88, -0.14), (0.88, -0.26), (-0.9, -0.26)])
            s.shinePoly([(-0.8, 0.06), (0.8, 0.12), (0.8, 0.18), (-0.8, 0.1)])
            s.xf = .identity
        case .scroll:
            s.rrect(-0.64, -0.56, 1.28, 1.12, 0.04)
            s.rrect(-0.9, -0.72, 0.28, 1.44, 0.14)
            s.rrect(0.62, -0.72, 0.28, 1.44, 0.14)
            s.oval(0.26, -0.5, 0.18, 0.18)
            s.line([(-0.46, 0.32), (0.42, 0.32)])
            s.line([(-0.46, 0.12), (0.3, 0.12)])
            s.line([(-0.46, -0.08), (0.4, -0.08)])
            s.line([(-0.46, -0.28), (0.0, -0.28)])
            s.line([(-0.76, -0.62), (-0.76, 0.62)])
            s.line([(0.76, -0.62), (0.76, 0.62)])
            s.shadeOval(0.26, -0.5, 0.1, 0.1)
            s.shineOval(-0.84, 0.3, 0.035, 0.24)
        case .potion:
            s.oval(0, -0.36, 0.6, 0.58)
            s.rrect(-0.17, 0.1, 0.34, 0.56, 0.05)
            s.rrect(-0.26, 0.6, 0.52, 0.12, 0.06)
            s.rrect(-0.14, 0.7, 0.28, 0.26, 0.06)
            let level = CGMutablePath()
            level.move(to: s.p(-0.56, -0.22))
            level.addCurve(to: s.p(0.56, -0.22), control1: s.p(-0.2, -0.1), control2: s.p(0.2, -0.34))
            s.detail.addPath(level)
            s.detailOval(-0.16, -0.52, 0.06, 0.06)
            s.detailOval(0.18, -0.34, 0.05, 0.05)
            s.detailOval(0.05, -0.68, 0.04, 0.04)
            s.shadeOval(0.0, -0.52, 0.46, 0.34)
            s.shineOval(-0.32, -0.2, 0.08, 0.2)
            s.shineOval(-0.08, 0.38, 0.03, 0.14)
        case .shell:
            let f = CGMutablePath()
            f.move(to: s.p(-0.12, -0.62))
            f.addCurve(to: s.p(-0.9, 0.18), control1: s.p(-0.5, -0.5), control2: s.p(-0.92, -0.2))
            f.addCurve(to: s.p(0, 0.84), control1: s.p(-0.86, 0.6), control2: s.p(-0.4, 0.84))
            f.addCurve(to: s.p(0.9, 0.18), control1: s.p(0.4, 0.84), control2: s.p(0.86, 0.6))
            f.addCurve(to: s.p(0.12, -0.62), control1: s.p(0.92, -0.2), control2: s.p(0.5, -0.5))
            f.closeSubpath()
            s.part(f)
            s.poly([(-0.44, -0.6), (0.44, -0.6), (0.3, -0.9), (-0.3, -0.9)])
            for q: (CGFloat, CGFloat) in [(-0.72, 0.3), (-0.46, 0.64), (0, 0.8), (0.46, 0.64), (0.72, 0.3)] {
                s.line([(0, -0.56), q])
            }
            s.line([(-0.3, -0.75), (0.3, -0.75)])
            s.shadePoly([(0, -0.56), (0.46, 0.64), (0.72, 0.3)])
            s.shineOval(-0.42, 0.38, 0.08, 0.14)
        case .feather:
            s.xf = CGAffineTransform(rotationAngle: -0.62)
            let v = CGMutablePath()
            v.move(to: s.p(0, -0.46))
            v.addCurve(to: s.p(0.04, 0.98), control1: s.p(0.42, -0.2), control2: s.p(0.34, 0.7))
            v.addCurve(to: s.p(0, -0.46), control1: s.p(-0.36, 0.66), control2: s.p(-0.38, -0.2))
            v.closeSubpath()
            s.part(v)
            s.rrect(-0.04, -0.98, 0.08, 0.6, 0.03)
            s.line([(0, -0.46), (0.02, 0.92)])
            s.line([(0, -0.2), (0.26, -0.02)])
            s.line([(0, 0.1), (0.27, 0.3)])
            s.line([(0.01, 0.42), (0.21, 0.62)])
            s.line([(0, -0.1), (-0.26, 0.08)])
            s.line([(0, 0.22), (-0.26, 0.42)])
            s.line([(0.01, 0.52), (-0.17, 0.7)])
            s.shadePoly([(0.02, -0.4), (0.3, -0.1), (0.3, 0.5), (0.03, 0.9)])
            s.shinePoly([(-0.06, -0.3), (-0.2, 0.1), (-0.16, 0.4), (-0.04, 0.1)])
            s.xf = .identity
        case .musicBox:
            s.rrect(-0.84, -0.72, 1.38, 0.92, 0.08)
            s.poly([(-0.84, 0.22), (0.54, 0.22), (0.4, 0.6), (-0.9, 0.44)])
            s.oval(-0.68, -0.8, 0.11, 0.07)
            s.oval(0.38, -0.8, 0.11, 0.07)
            s.rrect(0.54, -0.34, 0.22, 0.1, 0.03)
            s.rrect(0.7, -0.52, 0.08, 0.3, 0.03)
            s.oval(0.74, -0.58, 0.08, 0.06)
            s.oval(0.56, 0.66, 0.1, 0.08)
            s.oval(0.86, 0.58, 0.1, 0.08)
            s.rrect(0.61, 0.66, 0.05, 0.28, 0.02)
            s.rrect(0.91, 0.58, 0.05, 0.3, 0.02)
            s.poly([(0.61, 0.96), (0.96, 0.9), (0.96, 0.82), (0.61, 0.88)])
            s.detailOval(-0.15, -0.22, 0.07, 0.07)
            s.line([(-0.15, -0.28), (-0.15, -0.42)])
            s.line([(-0.84, -0.06), (0.54, -0.06)])
            s.line([(-0.84, 0.22), (0.54, 0.22)])
            s.shadePoly([(0.2, 0.2), (0.54, 0.2), (0.54, -0.72), (0.2, -0.72)])
            s.shinePoly([(-0.74, 0.1), (-0.56, 0.1), (-0.64, -0.6), (-0.76, -0.6)])
        case .idol:
            s.oval(0, 0.5, 0.42, 0.38)
            s.poly([(-0.5, 0.62), (-0.32, 0.98), (0.32, 0.98), (0.5, 0.62), (0, 0.78)])
            s.poly([(-0.46, 0.16), (0.46, 0.16), (0.6, -0.62), (-0.6, -0.62)])
            s.oval(-0.58, -0.1, 0.16, 0.26)
            s.oval(0.58, -0.1, 0.16, 0.26)
            s.rrect(-0.78, -0.92, 1.56, 0.32, 0.06)
            s.detailOval(-0.16, 0.5, 0.08, 0.06)
            s.detailOval(0.16, 0.5, 0.08, 0.06)
            s.line([(-0.14, 0.3), (0, 0.24), (0.14, 0.3)])
            s.detailOval(0, -0.24, 0.12, 0.12)
            s.line([(-0.78, -0.76), (0.78, -0.76)])
            s.shadePoly([(0.2, 0.16), (0.46, 0.16), (0.6, -0.62), (0.3, -0.62)])
            s.shineOval(-0.2, 0.7, 0.1, 0.06)
        }
        return s.build()
    }
}

/// A thread-safe cache of rendered art (SwiftUI may ask from any context).
final class ArtImageCache: @unchecked Sendable {
    static let shared = ArtImageCache()
    private let lock = NSLock()
    private var images: [String: CGImage] = [:]

    func image(_ key: String, make: () -> CGImage?) -> CGImage? {
        lock.lock()
        let hit = images[key]
        lock.unlock()
        if let hit { return hit }
        guard let img = make() else { return nil }
        lock.lock()
        images[key] = img
        lock.unlock()
        return img
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

/// Builds a `LootArt` in units of the radius. `xf` (in units) transforms everything added while it is set (the
/// spyglass and the feather are drawn straight, then tilted).
struct ArtSketch {
    let r: CGFloat
    var parts: [CGPath] = []
    let detail = CGMutablePath()
    let shine = CGMutablePath()
    let holes = CGMutablePath()
    let shade = CGMutablePath()
    var layers: [CGPath]?
    var tag: LootTag?
    var xf: CGAffineTransform = .identity

    init(_ r: CGFloat) { self.r = r }

    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * r, y: y * r).applying(xf) }

    private func rect(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> CGRect {
        CGRect(x: (cx - rx) * r, y: (cy - ry) * r, width: 2 * rx * r, height: 2 * ry * r)
    }

    /// `q` moved by `xf` (identity is a no-op).
    private func placed(_ q: CGPath) -> CGPath {
        if xf.isIdentity { return q }
        var t = xf
        return q.copy(using: &t) ?? q
    }

    /// A custom part built with `p(_:_:)` (already transformed).
    mutating func part(_ path: CGPath) { parts.append(path) }

    mutating func layered(_ l: [CGPath]) { layers = l }

    mutating func oval(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) {
        let q = CGMutablePath()
        ArtPrim.oval(q, rect(cx, cy, rx, ry))
        parts.append(placed(q))
    }

    mutating func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: CGFloat) {
        let q = CGMutablePath()
        ArtPrim.roundedRect(q, CGRect(x: x * r, y: y * r, width: w * r, height: h * r), corner: c * r)
        parts.append(placed(q))
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
        let q = CGMutablePath()
        ArtPrim.oval(q, rect(cx, cy, rx, ry))
        detail.addPath(placed(q))
    }

    func shineOval(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) {
        let q = CGMutablePath()
        ArtPrim.oval(q, rect(cx, cy, rx, ry))
        shine.addPath(placed(q))
    }

    func shinePoly(_ pts: [(CGFloat, CGFloat)]) {
        ArtPrim.polygon(shine, pts.map { p($0.0, $0.1) })
    }

    func shadeOval(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) {
        let q = CGMutablePath()
        ArtPrim.oval(q, rect(cx, cy, rx, ry))
        shade.addPath(placed(q))
    }

    func shadePoly(_ pts: [(CGFloat, CGFloat)]) {
        ArtPrim.polygon(shade, pts.map { p($0.0, $0.1) })
    }

    func holeOval(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) {
        let q = CGMutablePath()
        ArtPrim.oval(q, rect(cx, cy, rx, ry))
        holes.addPath(placed(q))
    }

    func holePoly(_ pts: [(CGFloat, CGFloat)]) {
        ArtPrim.polygon(holes, pts.map { p($0.0, $0.1) })
    }

    func build() -> LootArt {
        // The silhouette is the true union of the parts minus the holes (robust whatever way a part winds).
        var sil: CGPath = parts.first ?? CGMutablePath()
        for q in parts.dropFirst() { sil = sil.union(q) }
        if !holes.isEmpty { sil = sil.subtracting(holes) }
        return LootArt(silhouette: sil, parts: parts, detail: detail, shine: shine, holes: holes,
                       detailWidth: max(r * 0.09, 1), outlineWidth: max(r * 0.16, 1.5), shade: shade,
                       layerDetail: layers, tag: tag)
    }
}

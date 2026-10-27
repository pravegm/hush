import CoreGraphics
import Foundation

/// R3 (founder decision 5): the ONE in-world message plate for every card inside the chest: the hint line, the
/// lesson card, the pause / resume / closing cards and the toasts. No black pills, no teal app cards.
/// - `.parchment`: hints, lesson steps, toasts, the relic card (dark brown ink).
/// - `.leather`: the pause, resume and closing cards, the chain tab (cream ink; matches the bag strip).
/// - `.urgent`: "Freeze!" and other danger lines (oxblood leather, cream ink, red-orange stitching).
enum PlateStyle: String, CaseIterable, Sendable {
    case parchment, leather, urgent
}

/// A plate's colours (for the SwiftUI text and icons drawn on it).
struct PlateColors: Equatable, Sendable {
    /// The plate's body (top and bottom of its gradient).
    let fill: RGBA
    let fillDark: RGBA
    /// Stitching, and the burnt edge / grain.
    let stitch: RGBA
    let edge: RGBA
    /// Body text, and the eyebrow / emphasis colour.
    let text: RGBA
    let accent: RGBA
    /// A soft secondary line (sub-labels, "Skip").
    let muted: RGBA
}

/// Nine-slice insets (points) for `ChestArt.plateSliceImage`: SwiftUI `resizable(capInsets:)` keeps the end-caps
/// and the stitched corners crisp.
struct PlateInsets: Equatable, Sendable {
    let top: CGFloat
    let left: CGFloat
    let bottom: CGFloat
    let right: CGFloat
}

/// The little drawn icons that go on plates instead of SF Symbols (decision 5): the lesson's final card, hints,
/// the pause card.
enum PlateGlyph: String, CaseIterable, Sendable {
    case candle, fang, lock, coin, bag, arrowUp, arrowDown, pause, tick, chain, eye
}

extension ChestArt {
    // MARK: Plates

    static func plateColors(_ style: PlateStyle) -> PlateColors {
        switch style {
        case .parchment:
            return PlateColors(fill: RGBA(hex: 0xF6E8C6), fillDark: RGBA(hex: 0xE2C690), stitch: RGBA(hex: 0x8A5A2E),
                               edge: RGBA(hex: 0xB98A4E), text: RGBA(hex: 0x3A1F0A), accent: RGBA(hex: 0x8A2A12),
                               muted: RGBA(hex: 0x6E4A26))
        case .leather:
            return PlateColors(fill: RGBA(hex: 0x6E4024), fillDark: RGBA(hex: 0x3E2212), stitch: RGBA(hex: 0xE8C48A),
                               edge: RGBA(hex: 0x2A160B), text: palette.text, accent: palette.gold,
                               muted: RGBA(hex: 0xD9BE92))
        case .urgent:
            return PlateColors(fill: RGBA(hex: 0x7A1A1C), fillDark: RGBA(hex: 0x3E0A0C), stitch: RGBA(hex: 0xFF9A72),
                               edge: RGBA(hex: 0x2A0606), text: palette.text, accent: RGBA(hex: 0xFFD98A),
                               muted: RGBA(hex: 0xF2B9A6))
        }
    }

    /// The plate's corner radius for a size (the same rule everywhere).
    static func plateCorner(_ size: CGSize) -> CGFloat { min(max(size.height * 0.3, 8), 18) }

    /// The width of the brass end-caps.
    static func plateCapWidth(_ size: CGSize) -> CGFloat { min(max(size.height * 0.3, 10), 16) }

    /// The plate's outline (rounded rect, inset 2 pt for the dark outline), in a `size` box. Symmetric, so it is the
    /// same in y-up and y-down spaces (SwiftUI: `Path(ChestArt.platePath(size:))`).
    static func platePath(size: CGSize) -> CGPath {
        let r = CGRect(x: 2, y: 2, width: max(size.width - 4, 1), height: max(size.height - 4, 1))
        let p = CGMutablePath()
        ArtPrim.roundedRect(p, r, corner: plateCorner(size))
        return p
    }

    /// Insets for stretching `plateSliceImage` (keep the caps and the stitched corners). R4 (juror P0-1, UX P1-1): the
    /// left / right insets cover the brass end-cap (x 1…17 in the 56 pt slice) plus 8 pt, and the stitched border.
    /// They are NOT the text padding: lay text out in `plateTextRect(in:style:)`.
    static func plateInsets(_ style: PlateStyle) -> PlateInsets {
        PlateInsets(top: 20, left: 30, bottom: 20, right: 30)
    }

    /// R4: the brass end-caps' rects in a plate of `size` (y up; symmetric, so y-down is the same).
    static func plateCapRects(size: CGSize) -> [CGRect] {
        let cap = plateCapWidth(size)
        let capH = max(min(size.height * 0.62, size.height - 10), 6)
        let y = (size.height - capH) / 2
        return [CGRect(x: 1, y: y, width: cap, height: capH),
                CGRect(x: size.width - cap - 1, y: y, width: cap, height: capH)]
    }

    /// R4: the stitched (dashed) border's rect in a plate of `size` (its line is 1.6 pt wide, centred on this rect).
    static func plateStitchRect(size: CGSize) -> CGRect {
        let inner = CGRect(x: 2, y: 2, width: max(size.width - 4, 1), height: max(size.height - 4, 1))
        let faceR = inner.insetBy(dx: 1.6, dy: 1.6)
        let cap = plateCapWidth(size)
        return faceR.insetBy(dx: min(cap + 3, faceR.width / 3), dy: min(5.5, faceR.height / 4))
    }

    /// R4 (juror P0-1, UX P1-1): where a plate's TEXT goes, in a plate of `size` points. Inside the stitched border
    /// with 3 pt to spare, and ≥ 8 pt clear of both brass end-caps, for `plateImage(size:)` plates and for stretched
    /// `plateSliceImage` plates alike (a slice's caps keep the 56 pt slice's 16 pt width, so the side inset never uses
    /// less). Symmetric (y-up = y-down). Lay the text out in this rect, on one line with `minimumScaleFactor(0.7)`
    /// (lesson cards may wrap to 2 lines and grow the plate). Never empty: at least 1 × 1 at the plate's centre.
    static func plateTextRect(in size: CGSize, style: PlateStyle) -> CGRect {
        _ = style
        let w = max(size.width.isFinite ? size.width : 0, 0)
        let h = max(size.height.isFinite ? size.height : 0, 0)
        let ins = plateTextInsets(size: CGSize(width: w, height: h))
        let tw = max(w - ins.left - ins.right, 1)
        let th = max(h - ins.top - ins.bottom, 1)
        return CGRect(x: (w - tw) / 2, y: (h - th) / 2, width: tw, height: th)
    }

    /// R4: the text insets behind `plateTextRect` (the same on both sides; top = bottom).
    static func plateTextInsets(size: CGSize) -> PlateInsets {
        // The widest cap either way the plate is drawn (its own size, or a stretched 56 pt slice).
        let cap = max(plateCapWidth(size), size.height >= 34 ? 16 : 0)
        let stitch = min(cap + 3, max(size.width - 7.2, 1) / 3) + 3.6
        // Clear of the cap (+ 8) and inside the stitch line (+ 0.8 line + 3).
        let side = max(1 + cap + 8, stitch + 3.8).rounded(.up)
        let vStitch = 3.6 + min(5.5, max(size.height - 7.2, 1) / 4)
        let top = min(max(vStitch + 2.4, 4), max(size.height * 0.3, 2)).rounded(.up)
        return PlateInsets(top: top, left: side, bottom: top, right: side)
    }

    /// Draws a plate filling `size` (y up, origin bottom-left).
    static func drawPlate(_ ctx: CGContext, size: CGSize, style: PlateStyle) {
        let col = plateColors(style)
        let body = platePath(size: size)
        let inner = CGRect(x: 2, y: 2, width: max(size.width - 4, 1), height: max(size.height - 4, 1))
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        // A soft drop shadow under the plate (inside the image: down 2 pt).
        var down = CGAffineTransform(translationX: 0, y: -1.5)
        if let sh = body.copy(using: &down) { Painter.fill(ctx, sh, RGBA(0, 0, 0), 0.35) }
        Painter.fill(ctx, body, outline)
        let faceR = inner.insetBy(dx: 1.6, dy: 1.6)
        let facePath = CGMutablePath()
        ArtPrim.roundedRect(facePath, faceR, corner: max(plateCorner(size) - 1.6, 2))
        Painter.gradient(ctx, facePath, [ScenePaint.lighter(col.fill, 0.06), col.fill, col.fillDark], [0, 0.45, 1],
                         from: CGPoint(x: 0, y: faceR.maxY), to: CGPoint(x: 0, y: faceR.minY))
        ctx.saveGState()
        ctx.addPath(facePath)
        ctx.clip()
        switch style {
        case .parchment:
            // Fibres and foxing, then a burnt edge.
            var rng = SceneRNG(seed: UInt64(max(Int(size.width * 7 + size.height), 1)))
            let n = max(Int(size.width * size.height / 260), 6)
            for _ in 0..<n {
                let p = CGPoint(x: rng.range(faceR.minX, faceR.maxX), y: rng.range(faceR.minY, faceR.maxY))
                Painter.fill(ctx, Painter.circle(p, rng.range(0.6, 1.8)), col.edge, Double(rng.range(0.08, 0.2)))
            }
            Painter.stroke(ctx, facePath, col.edge, width: 9, 0.45)
            Painter.stroke(ctx, facePath, col.edge, width: 4, 0.4)
        case .leather, .urgent:
            Painter.grain(ctx, faceR, alongX: true, col.edge, seed: UInt64(max(Int(size.width), 1)), count: 3)
            Painter.stroke(ctx, facePath, col.edge, width: 7, 0.5)
            // A top sheen.
            Painter.linear(ctx, [RGBA(1, 1, 1, 0), RGBA(1, 1, 1, 0.08)], [0, 1],
                           from: CGPoint(x: 0, y: faceR.midY), to: CGPoint(x: 0, y: faceR.maxY))
        }
        ctx.restoreGState()
        // The stitched edge.
        let stitchR = plateStitchRect(size: size)
        if stitchR.width > 4 && stitchR.height > 4 {
            let st = CGMutablePath()
            ArtPrim.roundedRect(st, stitchR, corner: max(plateCorner(size) - 5, 2))
            ctx.saveGState()
            ctx.setLineDash(phase: 0, lengths: [6, 5])
            Painter.stroke(ctx, st, col.stitch, width: 1.6, 0.75)
            ctx.restoreGState()
        }
        // Brass end-caps (clasps half over the edge) with a rivet each.
        let cap = plateCapWidth(size)
        for r in plateCapRects(size: size) {
            let p = Painter.roundRect(r, min(cap * 0.38, 6))
            Painter.chunky(ctx, p, ScenePaint.brass, outline: 1.3, light: 0.45, shade: 0.4,
                           from: CGPoint(x: r.minX, y: r.maxY), to: CGPoint(x: r.maxX, y: r.minY))
            Painter.rivet(ctx, CGPoint(x: r.midX, y: r.midY), max(cap * 0.2, 2), ScenePaint.brassLight)
        }
    }

    /// A plate rendered at exactly `size` points (cached per size and style): the SwiftUI cards use
    /// `Image(decorative: img, scale: scale)` in a frame of that size. Opaque edges, transparent corners.
    static func plateImage(size: CGSize, style: PlateStyle, scale: CGFloat = 3) -> CGImage? {
        let w = max(size.width.rounded(), 8), h = max(size.height.rounded(), 8)
        let key = "plate|\(style.rawValue)|\(Int(w))|\(Int(h))|\(Int(scale * 100))"
        return ArtImageCache.shared.image(key) {
            renderImage(width: w, height: h, scale: scale) { ctx in
                drawPlate(ctx, size: CGSize(width: w, height: h), style: style)
            }
        }
    }

    /// A small plate (120 × 56 pt) to stretch with `plateInsets` (`resizable(capInsets:)`), for cards whose size
    /// changes every frame. Prefer `plateImage(size:style:)` for fixed sizes.
    static func plateSliceImage(style: PlateStyle, scale: CGFloat = 3) -> CGImage? {
        plateImage(size: CGSize(width: 120, height: 56), style: style, scale: scale)
    }

    /// Renders `draw` (y up, origin bottom-left, in points) into a `width × height` pt image (transparent).
    static func renderImage(width: CGFloat, height: CGFloat, scale: CGFloat, draw: (CGContext) -> Void) -> CGImage? {
        let k = max(scale, 0.25)
        let pw = Int((max(width, 1) * k).rounded(.up)), ph = Int((max(height, 1) * k).rounded(.up))
        guard pw > 0, ph > 0 else { return nil }
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.scaleBy(x: CGFloat(pw) / max(width, 1), y: CGFloat(ph) / max(height, 1))
        draw(ctx)
        return ctx.makeImage()
    }

    // MARK: Glyphs (drawn icons for plates)

    /// A drawn icon `side` points square, in the in-game style (outlined, lit from the top-left). Cached.
    static func glyphImage(_ glyph: PlateGlyph, side: CGFloat, scale: CGFloat = 3) -> CGImage? {
        let s = max(side.rounded(), 8)
        let key = "glyph|\(glyph.rawValue)|\(Int(s))|\(Int(scale * 100))"
        return ArtImageCache.shared.image(key) {
            renderImage(width: s, height: s, scale: scale) { ctx in drawGlyph(ctx, glyph, side: s) }
        }
    }

    /// Draws `glyph` in a `side` box (y up, origin bottom-left).
    static func drawGlyph(_ ctx: CGContext, _ glyph: PlateGlyph, side s: CGFloat) {
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        let o = max(s * 0.05, 1)
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
        func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: x * s, y: y * s, width: w * s, height: h * s)
        }
        switch glyph {
        case .candle:
            let dish = Painter.oval(box(0.2, 0.06, 0.6, 0.16))
            Painter.chunky(ctx, dish, ScenePaint.brass, outline: o, from: pt(0.2, 0.22), to: pt(0.8, 0.06))
            let wax = Painter.roundRect(box(0.37, 0.14, 0.26, 0.5), s * 0.05)
            Painter.chunky(ctx, wax, RGBA(hex: 0xF4E6C4), outline: o, light: 0.2, shade: 0.25, from: pt(0.37, 0.6),
                           to: pt(0.63, 0.14))
            let flame = CGMutablePath()
            flame.move(to: pt(0.5, 0.66))
            flame.addCurve(to: pt(0.5, 0.96), control1: pt(0.68, 0.66), control2: pt(0.54, 0.84))
            flame.addCurve(to: pt(0.5, 0.66), control1: pt(0.46, 0.84), control2: pt(0.32, 0.66))
            flame.closeSubpath()
            Painter.stroke(ctx, flame, outline, width: o * 1.6, 0.9)
            Painter.fill(ctx, flame, RGBA(hex: 0xFF9A2E))
            Painter.fill(ctx, Painter.oval(box(0.45, 0.68, 0.1, 0.14)), RGBA(hex: 0xFFF2C4))
        case .fang:
            let gum = Painter.roundRect(box(0.1, 0.78, 0.8, 0.16), s * 0.07)
            var t = CGAffineTransform(translationX: s * 0.24, y: s * 0.82)
            let row = teethRow(width: s * 0.52, height: s * 0.9, count: 1, pointingDown: true)
            let tooth = row.copy(using: &t) ?? row
            Painter.stroke(ctx, tooth, outline, width: o * 2, 0.95)
            Painter.gradient(ctx, tooth, [RGBA(hex: 0xD9C7A0), ScenePaint.ivory, RGBA(hex: 0xFFFDF4)], [0, 0.55, 1],
                             from: pt(0.5, 0.82), to: pt(0.5, 0.1))
            Painter.chunky(ctx, gum, flesh, outline: o, light: 0.25, shade: 0.35, from: pt(0.1, 0.94), to: pt(0.9, 0.78))
        case .lock:
            let hasp = Painter.roundRect(box(0.36, 0.6, 0.28, 0.34), s * 0.1)
            Painter.chunky(ctx, hasp, ScenePaint.brass, outline: o, from: pt(0.36, 0.94), to: pt(0.64, 0.6))
            let shield = CGMutablePath()
            shield.move(to: pt(0.16, 0.68))
            shield.addLine(to: pt(0.84, 0.68))
            shield.addCurve(to: pt(0.5, 0.04), control1: pt(0.86, 0.32), control2: pt(0.68, 0.1))
            shield.addCurve(to: pt(0.16, 0.68), control1: pt(0.32, 0.1), control2: pt(0.14, 0.32))
            shield.closeSubpath()
            Painter.chunky(ctx, shield, ScenePaint.brass, outline: o, light: 0.5, shade: 0.45, from: pt(0.16, 0.68),
                           to: pt(0.84, 0.1))
            let hole = CGMutablePath()
            ArtPrim.oval(hole, box(0.42, 0.38, 0.16, 0.16))
            ArtPrim.polygon(hole, [pt(0.46, 0.42), pt(0.54, 0.42), pt(0.57, 0.2), pt(0.43, 0.2)])
            Painter.fill(ctx, hole, RGBA(hex: 0x140804))
        case .coin:
            ctx.saveGState()
            ctx.translateBy(x: s / 2, y: s / 2)
            let r = s * 0.36
            drawArt(ctx, lootArt(.copper, radius: r, value: 5), lootColors(.copper), radius: r)
            ctx.restoreGState()
        case .bag:
            let sack = CGMutablePath()
            sack.move(to: pt(0.36, 0.7))
            sack.addCurve(to: pt(0.5, 0.06), control1: pt(0.0, 0.5), control2: pt(0.08, 0.06))
            sack.addCurve(to: pt(0.64, 0.7), control1: pt(0.92, 0.06), control2: pt(1.0, 0.5))
            sack.closeSubpath()
            Painter.chunky(ctx, sack, ScenePaint.leather, outline: o, light: 0.3, shade: 0.35, from: pt(0.2, 0.7),
                           to: pt(0.8, 0.06))
            let neck = Painter.polygon([pt(0.32, 0.86), pt(0.68, 0.86), pt(0.6, 0.7), pt(0.4, 0.7)])
            Painter.chunky(ctx, neck, ScenePaint.leather, outline: o, from: pt(0.5, 0.86), to: pt(0.5, 0.7))
            let cord = Painter.rect(box(0.36, 0.7, 0.28, 0.035))
            Painter.fill(ctx, cord, RGBA(hex: 0xD9B07A))
            Painter.fill(ctx, Painter.circle(pt(0.5, 0.36), s * 0.08), palette.gold)
        case .arrowUp, .arrowDown:
            let p = CGMutablePath()
            ArtPrim.polygon(p, [pt(0.5, 0.94), pt(0.88, 0.5), pt(0.64, 0.5), pt(0.64, 0.08), pt(0.36, 0.08),
                                pt(0.36, 0.5), pt(0.12, 0.5)])
            var flip = CGAffineTransform(translationX: 0, y: s).scaledBy(x: 1, y: -1)
            let up: CGPath = p
            var path: CGPath = up
            if glyph == .arrowDown, let f = up.copy(using: &flip) { path = f }
            Painter.chunky(ctx, path, palette.candle, outline: o, light: 0.3, shade: 0.25, from: pt(0.2, 0.9),
                           to: pt(0.8, 0.1))
        case .pause:
            let c = Painter.circle(pt(0.5, 0.5), s * 0.42)
            Painter.chunky(ctx, c, ScenePaint.brass, outline: o, light: 0.45, shade: 0.4, from: pt(0.1, 0.9),
                           to: pt(0.9, 0.1))
            for x in [CGFloat(0.37), 0.55] {
                Painter.fill(ctx, Painter.roundRect(box(x, 0.3, 0.09, 0.4), s * 0.03), RGBA(hex: 0x3A2206))
            }
        case .tick:
            let p = CGMutablePath()
            p.move(to: pt(0.16, 0.5))
            p.addLine(to: pt(0.4, 0.24))
            p.addLine(to: pt(0.86, 0.8))
            Painter.stroke(ctx, p, outline, width: s * 0.22, 0.95)
            Painter.stroke(ctx, p, palette.gold, width: s * 0.12, 1)
        case .chain:
            for (cx, a) in [(CGFloat(0.36), CGFloat(0.5)), (0.64, -0.5)] {
                let ring = CGMutablePath()
                ArtPrim.oval(ring, CGRect(x: -s * 0.22, y: -s * 0.14, width: s * 0.44, height: s * 0.28))
                var t = CGAffineTransform(translationX: cx * s, y: s * 0.5).rotated(by: a)
                let placed = ring.copy(using: &t) ?? ring
                Painter.stroke(ctx, placed, outline, width: s * 0.15, 0.95)
                Painter.stroke(ctx, placed, ScenePaint.brass, width: s * 0.08, 1)
            }
        case .eye:
            let space = CGSize(width: 150, height: 150)
            // The game's eye (a 150-unit eye box, its centre moved to the middle of a 90-unit view).
            let k = s / 90
            ctx.saveGState()
            ctx.scaleBy(x: k, y: k)
            ctx.translateBy(x: -30, y: -39)
            let e = mimicEye(wake: 0.8, size: space)
            Painter.stroke(ctx, e.white, outline, width: 10, 0.95)
            Painter.fill(ctx, e.white, ScenePaint.eyeWhite)
            ctx.saveGState()
            ctx.addPath(e.white)
            ctx.clip()
            let g = EyeGeometry(wake: 0.8, size: space)
            Painter.radial(ctx, [RGBA(hex: 0xFFE98A), RGBA(hex: 0xF0B02E), RGBA(hex: 0xB86A14)], [0, 0.45, 1],
                           center: g.irisCenter, radius: g.irisRadius)
            Painter.fill(ctx, Painter.oval(CGRect(x: g.irisCenter.x - 4, y: g.irisCenter.y - g.irisRadius * 0.8,
                                                  width: 8, height: g.irisRadius * 1.6)), RGBA(hex: 0x120604))
            ctx.restoreGState()
            ctx.restoreGState()
        }
    }
}

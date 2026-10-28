import CoreGraphics
import Foundation

/// R3 (founder decision 6, juror P0-2): the app icon, redrawn in the game's own language: chunky dark outlines,
/// top-left light, the slit amber eye with an iris starburst (the in-game `mimicEye`), the shield lock with a keyhole,
/// irregular pointed fangs with two long canines (the same fang curve as the lid), star-stamped gold coins (the loot's
/// own art) spilling from the seam, iron bands that line up from lid to body. The tilted-lid composition is kept (the
/// best mimic read at 60 px). OPAQUE: no alpha channel at all (the App writes it as an RGB PNG).
extension ChestArt {
    /// The icon at `size` × `size` pixels, opaque (`CGImageAlphaInfo.noneSkipLast`). `AppIconArt` shows / exports it.
    static func appIcon(size: CGFloat) -> CGImage {
        if let img = appIconImage(size: size) { return img }
        return appIconFallback()
    }

    /// The icon, or nil if CoreGraphics can't make the context (never in practice).
    static func appIconImage(size: CGFloat) -> CGImage? {
        let px = max(Int(size.isFinite ? size.rounded() : 1024), 16)
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.setShouldAntialias(true)
        let k = CGFloat(px) / 1024
        ctx.scaleBy(x: k, y: k)
        drawAppIcon(ctx)
        return ctx.makeImage()
    }

    /// A 1 × 1 opaque dungeon-teal pixel (only if a context can't be made).
    private static func appIconFallback() -> CGImage {
        let space = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        ctx?.setFillColor(ScenePaint.cg(palette.dungeon))
        ctx?.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        // `makeImage` on a 1 × 1 RGB context does not fail; the force is the documented last resort.
        return ctx!.makeImage()!
    }

    /// Draws the icon in a 1024 × 1024 unit space (y up).
    static func drawAppIcon(_ ctx: CGContext) {
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        let ol: CGFloat = 16          // outline half-width (the "3–4 pt" outline at icon scale)
        let full = CGRect(x: 0, y: 0, width: 1024, height: 1024)
        let wood = RGBA(hex: 0x95602F), woodDark = RGBA(hex: 0x4A2C18)
        let iron = RGBA(hex: 0x7C8894), stud = RGBA(hex: 0xD2D9E0)

        // The dungeon: deep teal-black, warm candlelight behind the chest.
        Painter.fill(ctx, rect: full, RGBA(hex: 0x081517))
        Painter.radial(ctx, [RGBA(hex: 0x3A3322), RGBA(hex: 0x173130), RGBA(hex: 0x081517)], [0, 0.42, 1],
                       center: CGPoint(x: 512, y: 600), radius: 720, extend: true)
        Painter.radial(ctx, [RGBA(1, 0.85, 0.54, 0.34), RGBA(1, 0.85, 0.54, 0)], [0, 1],
                       center: CGPoint(x: 512, y: 600), radius: 430)
        // The contact shadow.
        ctx.saveGState()
        ctx.translateBy(x: 512, y: 152)
        ctx.scaleBy(x: 1, y: 0.13)
        Painter.radial(ctx, [RGBA(0, 0, 0, 0.7), RGBA(0, 0, 0, 0.7), RGBA(0, 0, 0, 0)], [0, 0.55, 1], center: .zero,
                       radius: 420)
        ctx.restoreGState()

        // The seam: the dark mouth between body and lid, glowing with the loot inside.
        let throat = Painter.polygon([CGPoint(x: 186, y: 520), CGPoint(x: 838, y: 520), CGPoint(x: 846, y: 640),
                                      CGPoint(x: 178, y: 606)])
        Painter.fill(ctx, throat, ScenePaint.throat)
        ctx.saveGState()
        ctx.addPath(throat)
        ctx.clip()
        Painter.radial(ctx, [RGBA(1, 0.78, 0.4, 0.55), RGBA(0.9, 0.4, 0.2, 0.12), RGBA(0, 0, 0, 0)], [0, 0.5, 1],
                       center: CGPoint(x: 512, y: 548), radius: 330)
        ctx.restoreGState()

        // The eye: the game's own slit amber eye, wide-ish, peeking over the rim.
        drawIconEye(ctx, center: CGPoint(x: 512, y: 586), scale: 2.5)

        // The body.
        let bodyR = CGRect(x: 176, y: 156, width: 672, height: 380)
        let body = Painter.roundRect(bodyR, 58)
        Painter.stroke(ctx, body, outline, width: ol * 2, 1)
        Painter.gradient(ctx, body, [ScenePaint.lighter(wood, 0.16), wood, ScenePaint.darker(wood, 0.36)], [0, 0.45, 1],
                         from: CGPoint(x: bodyR.minX, y: bodyR.maxY), to: CGPoint(x: bodyR.maxX, y: bodyR.minY))
        ctx.saveGState()
        ctx.addPath(body)
        ctx.clip()
        for y in [CGFloat(288), 412] {
            Painter.stroke(ctx, Painter.rect(CGRect(x: bodyR.minX, y: y, width: bodyR.width, height: 0.01)), woodDark,
                           width: 9, 0.85)
        }
        // The rim where the lid closes.
        let rim = CGRect(x: bodyR.minX, y: bodyR.maxY - 44, width: bodyR.width, height: 44)
        Painter.gradient(ctx, Painter.rect(rim), [ScenePaint.darker(wood, 0.05), ScenePaint.darker(wood, 0.42)], [0, 1],
                         from: CGPoint(x: 0, y: rim.maxY), to: CGPoint(x: 0, y: rim.minY))
        Painter.stroke(ctx, Painter.rect(CGRect(x: rim.minX, y: rim.minY, width: rim.width, height: 0.01)), outline,
                       width: 8, 0.9)
        // A shade low on the right, a sheen top-left.
        Painter.linear(ctx, [RGBA(0, 0, 0, 0), RGBA(0, 0, 0, 0.3)], [0, 1], from: CGPoint(x: 500, y: 520),
                       to: CGPoint(x: 848, y: 156))
        // Iron bands (they line up with the lid's).
        for x in [CGFloat(296), 728] {
            let band = CGRect(x: x - 36, y: bodyR.minY - 4, width: 72, height: bodyR.height + 8)
            Painter.gradient(ctx, Painter.rect(band), [ScenePaint.lighter(iron, 0.3), iron, ScenePaint.darker(iron, 0.3)],
                             [0, 0.5, 1], from: CGPoint(x: band.minX, y: 0), to: CGPoint(x: band.maxX, y: 0))
            for bx in [band.minX, band.maxX] {
                Painter.stroke(ctx, Painter.rect(CGRect(x: bx, y: band.minY, width: 0.01, height: band.height)),
                               outline, width: 8, 0.9)
            }
            for y in [CGFloat(226), 346, 452] { Painter.rivet(ctx, CGPoint(x: x, y: y), 12, stud) }
        }
        ctx.restoreGState()

        // The shield lock with its keyhole.
        let hasp = Painter.roundRect(CGRect(x: 474, y: 392, width: 76, height: 110), 20)
        Painter.chunky(ctx, hasp, ScenePaint.brass, outline: 10, light: 0.45, shade: 0.4,
                       from: CGPoint(x: 474, y: 502), to: CGPoint(x: 550, y: 392))
        Painter.rivet(ctx, CGPoint(x: 512, y: 468), 11, ScenePaint.brassLight)
        let shield = CGMutablePath()
        shield.move(to: CGPoint(x: 408, y: 414))
        shield.addLine(to: CGPoint(x: 616, y: 414))
        shield.addCurve(to: CGPoint(x: 512, y: 190), control1: CGPoint(x: 622, y: 296), control2: CGPoint(x: 572, y: 220))
        shield.addCurve(to: CGPoint(x: 408, y: 414), control1: CGPoint(x: 452, y: 220), control2: CGPoint(x: 402, y: 296))
        shield.closeSubpath()
        Painter.chunky(ctx, shield, ScenePaint.brass, outline: 12, light: 0.55, shade: 0.45,
                       from: CGPoint(x: 408, y: 414), to: CGPoint(x: 616, y: 200))
        var inset = CGAffineTransform(translationX: 512, y: 300).scaledBy(x: 0.78, y: 0.78).translatedBy(x: -512, y: -300)
        if let inner = shield.copy(using: &inset) { Painter.stroke(ctx, inner, ScenePaint.brassDark, width: 7, 0.8) }
        let hole = CGMutablePath()
        ArtPrim.oval(hole, CGRect(x: 488, y: 312, width: 48, height: 48))
        ArtPrim.polygon(hole, [CGPoint(x: 500, y: 320), CGPoint(x: 524, y: 320), CGPoint(x: 532, y: 252),
                               CGPoint(x: 492, y: 252)])
        Painter.fill(ctx, hole, RGBA(hex: 0x140804))
        Painter.fill(ctx, Painter.oval(CGRect(x: 432, y: 352, width: 26, height: 44)), RGBA(1, 1, 1), 0.45)

        // The lid, tilted up on the right, its fangs over the eye.
        ctx.saveGState()
        ctx.translateBy(x: 512, y: 618)
        ctx.rotate(by: 0.05)
        drawIconFangs(ctx)
        drawIconLid(ctx, wood: wood, woodDark: woodDark, iron: iron, stud: stud, outlineHalf: ol)
        ctx.restoreGState()

        // Star coins spilling from the seam, and one leaning on the chest's front. R4 (tester 8): every coin and
        // sparkle sits inside the iOS mask's safe area (`iconLooseBits`, tested).
        for bit in iconLooseBits {
            switch bit.kind {
            case .coin(let v, let rot):
                ctx.saveGState()
                ctx.translateBy(x: bit.center.x, y: bit.center.y)
                ctx.rotate(by: rot)
                drawArt(ctx, lootArt(.copper, radius: bit.radius, value: v), lootColors(.copper), radius: bit.radius)
                ctx.restoreGState()
            case .sparkle:
                drawIconSparkle(ctx, at: bit.center, radius: bit.radius)
            }
        }
    }

    /// R4: the icon's loose coins and sparkles (1024-unit space, y up) and how far each reaches (its art radius plus
    /// its outline, or the sparkle's glow).
    enum IconBitKind: Equatable {
        case coin(value: Int, rotation: CGFloat)
        case sparkle
    }

    struct IconBit: Equatable {
        let center: CGPoint
        let radius: CGFloat
        let kind: IconBitKind
        /// The farthest the drawn bit reaches from its centre.
        var reach: CGFloat {
            switch kind {
            case .coin: return radius * 1.16 + 4
            case .sparkle: return radius * 1.2
            }
        }
    }

    /// The safe circle the loose bits stay inside: 80 % of the icon, centred (inside the iOS squircle mask with room
    /// to spare).
    static let iconSafeRadius: CGFloat = 1024 * 0.4

    static let iconLooseBits: [IconBit] = [
        IconBit(center: CGPoint(x: 252, y: 556), radius: 50, kind: .coin(value: 10, rotation: 0.12)),
        IconBit(center: CGPoint(x: 796, y: 560), radius: 44, kind: .coin(value: 5, rotation: -0.2)),
        // Was (884, 196): the iOS mask could clip it. Now it leans on the chest's front, right of the lock.
        IconBit(center: CGPoint(x: 694, y: 236), radius: 38, kind: .coin(value: 5, rotation: 0.5)),
        IconBit(center: CGPoint(x: 818, y: 664), radius: 28, kind: .sparkle),
        IconBit(center: CGPoint(x: 184, y: 640), radius: 18, kind: .sparkle),
    ]

    private static func drawIconEye(_ ctx: CGContext, center: CGPoint, scale k: CGFloat) {
        let space = CGSize(width: 150, height: 150)
        let wake = 0.72
        let e = mimicEye(wake: wake, size: space)
        let g = EyeGeometry(wake: wake, size: space)
        ctx.saveGState()
        ctx.translateBy(x: center.x - g.c.x * k, y: center.y - g.c.y * k)
        ctx.scaleBy(x: k, y: k)
        Painter.fill(ctx, e.white, ScenePaint.eyeWhite)
        ctx.saveGState()
        ctx.addPath(e.white)
        ctx.clip()
        let ir = g.irisRadius * 1.05
        let ic = g.irisCenter
        Painter.radial(ctx, [RGBA(hex: 0xFFEE96), RGBA(hex: 0xF5B22C), RGBA(hex: 0xC06C12), RGBA(hex: 0x5A3008)],
                       [0, 0.4, 0.8, 1], center: ic, radius: ir)
        for i in 0..<24 {
            let a = CGFloat(i) / 24 * 2 * .pi
            let p = CGMutablePath()
            p.move(to: CGPoint(x: ic.x + cos(a) * ir * 0.3, y: ic.y + sin(a) * ir * 0.3))
            p.addLine(to: CGPoint(x: ic.x + cos(a + 0.06) * ir * 0.92, y: ic.y + sin(a + 0.06) * ir * 0.92))
            Painter.stroke(ctx, p, RGBA(hex: 0x7A4A0C), width: 1.3, 0.5)
        }
        Painter.stroke(ctx, Painter.circle(ic, ir - 0.6), outline, width: 2.4, 0.9)
        // The slit pupil.
        let slit = CGMutablePath()
        slit.move(to: CGPoint(x: ic.x, y: ic.y - ir * 0.92))
        slit.addCurve(to: CGPoint(x: ic.x, y: ic.y + ir * 0.92), control1: CGPoint(x: ic.x + ir * 0.3, y: ic.y - ir * 0.3),
                      control2: CGPoint(x: ic.x + ir * 0.3, y: ic.y + ir * 0.3))
        slit.addCurve(to: CGPoint(x: ic.x, y: ic.y - ir * 0.92), control1: CGPoint(x: ic.x - ir * 0.3, y: ic.y + ir * 0.3),
                      control2: CGPoint(x: ic.x - ir * 0.3, y: ic.y - ir * 0.3))
        slit.closeSubpath()
        Painter.fill(ctx, slit, RGBA(hex: 0x120604))
        Painter.fill(ctx, Painter.oval(CGRect(x: ic.x - ir * 0.62, y: ic.y + ir * 0.18, width: ir * 0.36, height: ir * 0.26)),
                     RGBA(1, 1, 1), 0.9)
        // The upper lid's shadow on the eyeball.
        Painter.linear(ctx, [RGBA(0.43, 0.13, 0.22, 0), RGBA(0.43, 0.13, 0.22, 0.45)], [0, 1],
                       from: CGPoint(x: 0, y: g.cornerY), to: CGPoint(x: 0, y: g.topMid))
        ctx.restoreGState()
        Painter.stroke(ctx, e.white, outline, width: 4, 0.95)
        Painter.stroke(ctx, e.lidTop, outline, width: 4, 0.95)
        Painter.gradient(ctx, e.lidTop, [ScenePaint.lighter(flesh, 0.15), flesh, fleshDark], [0, 0.5, 1],
                         from: CGPoint(x: 0, y: g.topMid + g.r), to: CGPoint(x: 0, y: g.cornerY))
        ctx.restoreGState()
    }

    /// The lid's fangs in the lid's local space (origin at the middle of its bottom edge, y up): irregular, two long
    /// canines, the middle ones short so the eye shows between them.
    private static func drawIconFangs(_ ctx: CGContext) {
        let spec: [(x: CGFloat, w: CGFloat, len: CGFloat)] = [
            (-292, 64, 50), (-212, 82, 104), (-136, 66, 58), (-78, 48, 36),
            (78, 48, 40), (136, 66, 46), (212, 82, 108), (292, 64, 52),
        ]
        let p = CGMutablePath()
        for t in spec {
            let left = t.x - t.w / 2, right = t.x + t.w / 2, mid = t.x, half = t.w / 2, len = t.len
            p.move(to: CGPoint(x: left, y: 8))
            p.addCurve(to: CGPoint(x: mid - half * 0.14, y: -len * 0.95), control1: CGPoint(x: left, y: -len * 0.38),
                       control2: CGPoint(x: mid - half * 0.3, y: -len * 0.82))
            p.addQuadCurve(to: CGPoint(x: mid + half * 0.14, y: -len * 0.95), control: CGPoint(x: mid, y: -len * 1.05))
            p.addCurve(to: CGPoint(x: right, y: 8), control1: CGPoint(x: mid + half * 0.3, y: -len * 0.82),
                       control2: CGPoint(x: right, y: -len * 0.38))
            p.closeSubpath()
        }
        Painter.stroke(ctx, p, outline, width: 14, 1)
        Painter.gradient(ctx, p, [RGBA(hex: 0xD9C7A0), ScenePaint.ivory, RGBA(hex: 0xFFFDF4)], [0, 0.5, 1],
                         from: CGPoint(x: 0, y: 8), to: CGPoint(x: 0, y: -100))
        ctx.saveGState()
        ctx.addPath(p)
        ctx.clip()
        for t in spec {
            Painter.fill(ctx, Painter.oval(CGRect(x: t.x - t.w * 0.26, y: -t.len * 0.7, width: t.w * 0.14,
                                                  height: t.len * 0.5)), RGBA(1, 1, 1), 0.55)
        }
        ctx.restoreGState()
    }

    private static func drawIconLid(_ ctx: CGContext, wood: RGBA, woodDark: RGBA, iron: RGBA, stud: RGBA,
                                    outlineHalf ol: CGFloat) {
        let lid = CGMutablePath()
        lid.move(to: CGPoint(x: -352, y: 0))
        lid.addLine(to: CGPoint(x: 352, y: 0))
        lid.addLine(to: CGPoint(x: 352, y: 128))
        lid.addCurve(to: CGPoint(x: -352, y: 128), control1: CGPoint(x: 330, y: 306), control2: CGPoint(x: -330, y: 306))
        lid.closeSubpath()
        Painter.stroke(ctx, lid, outline, width: ol * 2, 1)
        Painter.gradient(ctx, lid, [ScenePaint.lighter(wood, 0.22), wood, ScenePaint.darker(wood, 0.3)], [0, 0.5, 1],
                         from: CGPoint(x: -300, y: 260), to: CGPoint(x: 260, y: 0))
        ctx.saveGState()
        ctx.addPath(lid)
        ctx.clip()
        Painter.stroke(ctx, Painter.rect(CGRect(x: -352, y: 132, width: 704, height: 0.01)), woodDark, width: 9, 0.85)
        // The front lip.
        let lip = CGRect(x: -352, y: 0, width: 704, height: 44)
        Painter.gradient(ctx, Painter.rect(lip), [ScenePaint.darker(wood, 0.05), ScenePaint.darker(wood, 0.45)], [0, 1],
                         from: CGPoint(x: 0, y: lip.maxY), to: CGPoint(x: 0, y: 0))
        Painter.stroke(ctx, Painter.rect(CGRect(x: -352, y: lip.maxY, width: 704, height: 0.01)), outline, width: 8, 0.9)
        // Bands in line with the body's.
        for x in [CGFloat(-216), 216] {
            let band = CGRect(x: x - 36, y: -4, width: 72, height: 320)
            Painter.gradient(ctx, Painter.rect(band), [ScenePaint.lighter(iron, 0.3), iron, ScenePaint.darker(iron, 0.3)],
                             [0, 0.5, 1], from: CGPoint(x: band.minX, y: 0), to: CGPoint(x: band.maxX, y: 0))
            for bx in [band.minX, band.maxX] {
                Painter.stroke(ctx, Painter.rect(CGRect(x: bx, y: band.minY, width: 0.01, height: band.height)),
                               outline, width: 8, 0.9)
            }
            for y in [CGFloat(84), 196] { Painter.rivet(ctx, CGPoint(x: x, y: y), 12, stud) }
        }
        // The dome's highlight.
        let hl = CGMutablePath()
        hl.move(to: CGPoint(x: -290, y: 168))
        hl.addQuadCurve(to: CGPoint(x: -70, y: 252), control: CGPoint(x: -210, y: 246))
        Painter.stroke(ctx, hl, RGBA(1, 1, 1), width: 16, 0.24)
        ctx.restoreGState()
        Painter.stroke(ctx, lid, outline, width: 7, 0.6)
    }

    private static func drawIconSparkle(_ ctx: CGContext, at c: CGPoint, radius r: CGFloat) {
        let k = r * 0.16
        let p = CGMutablePath()
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
        p.closeSubpath()
        Painter.radial(ctx, [RGBA(1, 0.95, 0.75, 0.5), RGBA(1, 0.95, 0.75, 0)], [0, 1], center: c, radius: r * 1.2)
        Painter.fill(ctx, p, RGBA(hex: 0xFFF6DA))
    }
}

// MARK: - R11: the praise ink, and the Game Center badges (juror P2-7, tester 11, frame 40)

/// A badge's bezel metal (the App's `BadgePainter.Tier`, by name): four badges each, first steps to the big ones.
enum BadgeMetal: String, CaseIterable, Sendable {
    case bronze, silver, gold
}

/// What a badge shows in its velvet: one of the game's relics, or (R11, Heavy Bag) a tied sack of gold.
enum BadgeGlyph: Equatable, Sendable {
    case relic(RelicShape)
    case sack
}

extension ChestArt {
    /// R11 (juror P2-7, R4 carry-over: "Cream instead of green for 'Banked! Gently does it.'"): the ink for praise on a
    /// plate. A burnished gold-brown on parchment (≥ 4.5 : 1 on both ends of its gradient; never green), the game's gold
    /// on leather, the urgent plate's own light gold. FOR THE APP: `PlateArt.calm` can become
    /// `Color(hush: ChestArt.praiseInk(.parchment))`.
    static func praiseInk(_ style: PlateStyle) -> RGBA {
        switch style {
        case .parchment: return RGBA(hex: 0x7A4300)
        case .leather: return palette.gold
        case .urgent: return plateColors(.urgent).accent
        }
    }

    /// R11 (juror P2-7, tester 11: "the Heavy Bag icon looks like a little person or statue"): the badge's glyph for a
    /// motif. The idol is Heavy Bag's (its motif is unique in `BadgePainter.motifs`), so it becomes a sack of gold;
    /// the Codex's "Idol of the Sleepy God" relic keeps its idol.
    static func badgeGlyph(_ motif: RelicShape) -> BadgeGlyph { motif == .idol ? .sack : .relic(motif) }

    /// The glyph's art (y up, centred, in the relic art's units). FOR THE APP: in `BadgePainter.paint`,
    /// `ChestArt.badgeGlyphArt(motif, radius: 50)` replaces `ChestArt.relicArt(motif, radius: 50)`.
    static func badgeGlyphArt(_ motif: RelicShape, radius: CGFloat) -> LootArt {
        switch badgeGlyph(motif) {
        case .sack: return sackArt(radius: radius)
        case .relic(let shape): return relicArt(shape, radius: radius)
        }
    }

    /// A plump sack of gold, its neck tied with a cord, coins peeking over the ruffle, a stamped coin on its belly.
    /// Wider at the bottom than the neck (a bag, not a figure: no head, no shoulders). Pure; tested.
    static func sackArt(radius: CGFloat) -> LootArt {
        let r = max(radius, 1)
        var s = ArtSketch(r)
        // The body: a teardrop sack, narrow at the tie, round and heavy at the foot.
        let body = CGMutablePath()
        body.move(to: s.p(-0.26, 0.4))
        body.addCurve(to: s.p(-0.9, -0.42), control1: s.p(-0.5, 0.22), control2: s.p(-0.92, 0.02))
        body.addCurve(to: s.p(0, -0.94), control1: s.p(-0.88, -0.8), control2: s.p(-0.5, -0.94))
        body.addCurve(to: s.p(0.9, -0.42), control1: s.p(0.5, -0.94), control2: s.p(0.88, -0.8))
        body.addCurve(to: s.p(0.26, 0.4), control1: s.p(0.92, 0.02), control2: s.p(0.5, 0.22))
        body.closeSubpath()
        s.part(body)
        // The ruffled mouth above the tie.
        s.poly([(-0.3, 0.46), (-0.56, 0.78), (-0.24, 0.66), (0, 0.84), (0.24, 0.66), (0.56, 0.78), (0.3, 0.46)])
        // Two coins peeking out of it.
        s.oval(-0.14, 0.8, 0.17, 0.12)
        s.oval(0.16, 0.86, 0.15, 0.11)
        // The cord round the neck, its knot and two loose ends.
        s.rrect(-0.36, 0.36, 0.72, 0.14, 0.06)
        s.oval(0.3, 0.43, 0.1, 0.1)
        s.line([(0.34, 0.36), (0.5, 0.08)])
        s.line([(0.3, 0.35), (0.38, 0.04)])
        // The cord's twist, the ruffle's folds and the sack's two creases.
        s.line([(-0.22, 0.36), (-0.16, 0.5)])
        s.line([(-0.02, 0.36), (0.04, 0.5)])
        s.line([(-0.24, 0.66), (-0.3, 0.48)])
        s.line([(0.24, 0.66), (0.3, 0.48)])
        let crease = CGMutablePath()
        crease.move(to: s.p(-0.5, 0.06))
        crease.addQuadCurve(to: s.p(-0.62, -0.5), control: s.p(-0.7, -0.2))
        crease.move(to: s.p(0.42, 0.08))
        crease.addQuadCurve(to: s.p(0.6, -0.36), control: s.p(0.64, -0.1))
        s.detail.addPath(crease)
        // The stamped coin: a ring with a star, and the peeking coins' rims.
        s.detailOval(0, -0.38, 0.27, 0.27)
        var star: [(CGFloat, CGFloat)] = []
        for k in 0..<10 {
            let a = CGFloat.pi / 2 + CGFloat(k) * .pi / 5
            let rr: CGFloat = k % 2 == 0 ? 0.17 : 0.07
            star.append((cos(a) * rr, -0.38 + sin(a) * rr))
        }
        s.closedLine(star)
        s.detailOval(-0.14, 0.8, 0.1, 0.06)
        s.detailOval(0.16, 0.86, 0.09, 0.055)
        // Shade on the right flank, a shine on the left.
        let shadeP = CGMutablePath()
        shadeP.move(to: s.p(0.3, 0.3))
        shadeP.addCurve(to: s.p(0.9, -0.42), control1: s.p(0.6, 0.12), control2: s.p(0.92, 0.0))
        shadeP.addCurve(to: s.p(0.2, -0.92), control1: s.p(0.88, -0.8), control2: s.p(0.56, -0.93))
        shadeP.addCurve(to: s.p(0.3, 0.3), control1: s.p(0.62, -0.5), control2: s.p(0.56, -0.04))
        shadeP.closeSubpath()
        s.shade.addPath(shadeP)
        s.shineOval(-0.54, -0.18, 0.1, 0.24)
        s.shineOval(-0.2, 0.84, 0.05, 0.03)
        return s.build()
    }

    // MARK: Badge medallion

    /// The bezel's metal ramp (light, mid, dark) for a tier; a dull pewter when the badge isn't earned yet.
    static func badgeMetalColors(_ metal: BadgeMetal, earned: Bool) -> (light: RGBA, mid: RGBA, dark: RGBA) {
        guard earned else { return (RGBA(hex: 0x9AA6A3), RGBA(hex: 0x6E7A77), RGBA(hex: 0x3E4846)) }
        switch metal {
        case .bronze: return (RGBA(hex: 0xF4B678), RGBA(hex: 0xC27A3E), RGBA(hex: 0x6E3614))
        case .silver: return (RGBA(hex: 0xF4F8F6), RGBA(hex: 0xB4C0BE), RGBA(hex: 0x66726F))
        case .gold: return (RGBA(hex: 0xFFE7A6), RGBA(hex: 0xE0A63A), RGBA(hex: 0x8E5A12))
        }
    }

    /// The glyph's palette per tier (the App's own, kept): bronze, silver or gold.
    static func badgeGlyphColors(_ metal: BadgeMetal) -> (fill: RGBA, rim: RGBA, glint: RGBA) {
        switch metal {
        case .bronze: return (RGBA(hex: 0xE59A55), RGBA(hex: 0x6A3412), RGBA(hex: 0xFFE2B4))
        case .silver: return (RGBA(hex: 0xD8E2EA), RGBA(hex: 0x56626F), RGBA(hex: 0xFFFFFF))
        case .gold: return (RGBA(hex: 0xFFC94A), RGBA(hex: 0x8A5A12), RGBA(hex: 0xFFF4CC))
        }
    }

    /// The bezel's radii in the badge's 1024-unit space: the milled edge's tooth tips and roots, the raised ring's
    /// outer and inner edges, the sunk lip round the velvet, and the number of milled teeth.
    static let badgeMillOuter: CGFloat = 408
    static let badgeMillInner: CGFloat = 388
    static let badgeRingOuter: CGFloat = 392
    static let badgeRingInner: CGFloat = 322
    static let badgeVelvetRadius: CGFloat = 304
    static let badgeMillTeeth = 60

    /// R11 (juror P2-7 "milled rims instead of porthole rings", tester 11 frame 40): a Game Center badge, `side` points
    /// square: the dungeon ground with candlelight, a struck-metal bezel (a milled edge, a raised ring lit from the
    /// top-left with a laurel in relief and a star at its crown, a sunk lip), the velvet, and the glyph in the tier's
    /// palette (a cream silhouette until earned). No rivets, no porthole. Cached. FOR THE APP: `AchievementBadge` can
    /// draw `Image(decorative: ChestArt.badgeImage(...), scale: 1)` in its frame instead of `BadgePainter.paint`.
    static func badgeImage(motif: RelicShape, metal: BadgeMetal, earned: Bool, side: CGFloat = 1024,
                           scale: CGFloat = 1) -> CGImage? {
        let w = max(side.isFinite ? side.rounded() : 1024, 16)
        let key = "badge|\(motif.rawValue)|\(metal.rawValue)|\(earned)|\(Int(w))|\(Int(scale * 100))"
        return ArtImageCache.shared.image(key) {
            renderImage(width: w, height: w, scale: scale) { ctx in
                ctx.scaleBy(x: w / 1024, y: w / 1024)
                drawBadge(ctx, glyph: badgeGlyph(motif), metal: metal, earned: earned)
            }
        }
    }

    /// The badge in a 1024 × 1024 unit space (y up).
    static func drawBadge(_ ctx: CGContext, glyph: BadgeGlyph, metal: BadgeMetal, earned: Bool) {
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        let c = CGPoint(x: 512, y: 512)
        let full = CGRect(x: 0, y: 0, width: 1024, height: 1024)
        // The ground: the badge page's dungeon, warm candlelight behind the medal.
        Painter.gradient(ctx, Painter.rect(full), [RGBA(hex: 0x061012), RGBA(hex: 0x10292C)], [0, 1],
                         from: CGPoint(x: 512, y: 0), to: CGPoint(x: 512, y: 1024))
        let glow = earned ? 0.3 : 0.08
        Painter.radial(ctx, [RGBA(hex: 0xFFB45E, alpha: glow), RGBA(hex: 0xFFB45E, alpha: 0)], [0, 1],
                       center: CGPoint(x: 512, y: 554), radius: 560)
        // A soft drop shadow under the medal.
        Painter.radial(ctx, [RGBA(0, 0, 0, 0.6), RGBA(0, 0, 0, 0.6), RGBA(0, 0, 0, 0)], [0, 0.82, 1],
                       center: CGPoint(x: 512, y: 494), radius: 450)
        let m = badgeMetalColors(metal, earned: earned)
        drawBadgeMilling(ctx, center: c, metal: m)
        drawBadgeRing(ctx, center: c, metal: m)
        drawBadgeLaurel(ctx, center: c, metal: m)
        // The sunk lip and the velvet.
        let lip = Painter.circle(c, badgeRingInner)
        Painter.fill(ctx, lip, m.dark)
        Painter.stroke(ctx, lip, outline, width: 8, 0.9)
        let velvet = Painter.circle(c, badgeVelvetRadius)
        let v = earned ? [RGBA(hex: 0x7A2848), palette.velvet, RGBA(hex: 0x2E0A1A)]
            : [RGBA(hex: 0x2A3436), RGBA(hex: 0x1A2224), RGBA(hex: 0x0E1416)]
        ctx.saveGState()
        ctx.addPath(velvet)
        ctx.clip()
        Painter.radial(ctx, v, [0, 0.55, 1], center: CGPoint(x: 470, y: 604), radius: 400, extend: true)
        // Its depth: the lip's shadow falls on the velvet's top edge.
        Painter.stroke(ctx, Painter.circle(CGPoint(x: 516, y: 500), badgeVelvetRadius + 4), RGBA(0, 0, 0), width: 26,
                       0.35)
        ctx.restoreGState()
        Painter.stroke(ctx, velvet, outline, width: 10, 0.95)
        // The glyph, 66 % of the velvet, never over the bezel.
        drawBadgeGlyph(ctx, glyph, metal: metal, earned: earned, box: CGRect(x: 300, y: 300, width: 424, height: 424))
    }

    /// The milled edge: square teeth round the rim, struck in the darker metal, each tooth catching the light.
    private static func drawBadgeMilling(_ ctx: CGContext, center c: CGPoint,
                                         metal m: (light: RGBA, mid: RGBA, dark: RGBA)) {
        let p = badgeMillingPath(center: c)
        Painter.stroke(ctx, p, outline, width: 10, 0.95)
        Painter.gradient(ctx, p, [m.light, m.mid, m.dark], [0, 0.45, 1], from: CGPoint(x: c.x - 300, y: c.y + 330),
                         to: CGPoint(x: c.x + 300, y: c.y - 330))
        Painter.stroke(ctx, Painter.circle(c, badgeMillInner - 2), outline, width: 4, 0.5)
    }

    /// The milled edge's outline: `badgeMillTeeth` square teeth between `badgeMillInner` and `badgeMillOuter`.
    /// Pure; tested.
    static func badgeMillingPath(center c: CGPoint) -> CGPath {
        let n = badgeMillTeeth
        var pts: [CGPoint] = []
        pts.reserveCapacity(n * 4)
        for i in 0..<n {
            let a0 = CGFloat(i) / CGFloat(n) * 2 * .pi
            let step = 2 * CGFloat.pi / CGFloat(n)
            let profile: [(CGFloat, CGFloat)] = [(0, badgeMillInner), (0.1, badgeMillOuter), (0.52, badgeMillOuter),
                                                 (0.62, badgeMillInner)]
            for (t, rr) in profile {
                let a = a0 + step * t
                pts.append(CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr))
            }
        }
        return Painter.polygon(pts)
    }

    /// The raised ring: lit from the top-left, a bright bevel on its outer top-left edge and a dark one bottom-right,
    /// reversed on its inner edge (it steps down to the velvet).
    private static func drawBadgeRing(_ ctx: CGContext, center c: CGPoint,
                                      metal m: (light: RGBA, mid: RGBA, dark: RGBA)) {
        let outer = Painter.circle(c, badgeRingOuter)
        Painter.stroke(ctx, outer, outline, width: 10, 0.95)
        Painter.gradient(ctx, outer, [ScenePaint.lighter(m.light, 0.2), m.light, m.mid, m.dark], [0, 0.3, 0.62, 1],
                         from: CGPoint(x: c.x - 280, y: c.y + 300), to: CGPoint(x: c.x + 280, y: c.y - 300))
        let topLeft = Painter.polygon([CGPoint(x: c.x - 520, y: c.y - 120), CGPoint(x: c.x + 120, y: c.y + 520),
                                       CGPoint(x: c.x - 520, y: c.y + 520)])
        let bottomRight = Painter.polygon([CGPoint(x: c.x - 120, y: c.y - 520), CGPoint(x: c.x + 520, y: c.y + 120),
                                           CGPoint(x: c.x + 520, y: c.y - 520)])
        let bevels: [(CGPath, CGFloat, RGBA, Double)] = [(topLeft, badgeRingOuter - 9, RGBA(1, 1, 1), 0.45),
                                                          (bottomRight, badgeRingOuter - 9, RGBA(0, 0, 0), 0.35),
                                                          (topLeft, badgeRingInner + 9, RGBA(0, 0, 0), 0.35),
                                                          (bottomRight, badgeRingInner + 9, RGBA(1, 1, 1), 0.3)]
        for (clip, edgeR, color, a) in bevels {
            ctx.saveGState()
            ctx.addPath(clip)
            ctx.clip()
            Painter.stroke(ctx, Painter.circle(c, edgeR), color, width: 9, a)
            ctx.restoreGState()
        }
    }

    /// The laurel in relief round the ring: two branches of leaves rising from a tie at the foot to a star at the
    /// crown. Each piece is struck: a dark shadow down-right, a light edge up-left, then the metal.
    private static func drawBadgeLaurel(_ ctx: CGContext, center c: CGPoint,
                                        metal m: (light: RGBA, mid: RGBA, dark: RGBA)) {
        let mid = (badgeRingOuter + badgeRingInner) / 2
        let leaves = CGMutablePath()
        for side in [CGFloat(-1), 1] {
            for k in 0..<9 {
                // From the foot (−90°) up the side to just short of the crown (+90°).
                let deg = -72 + CGFloat(k) * 17
                let a = (side < 0 ? 180 - deg : deg) * .pi / 180
                let out: CGFloat = k % 2 == 0 ? 9 : -9
                let p = CGPoint(x: c.x + cos(a) * (mid + out), y: c.y + sin(a) * (mid + out))
                // Along the ring (pointing up the branch), tilted outward or inward.
                let tangent = a + side * .pi / 2
                let tilt: CGFloat = (k % 2 == 0 ? 0.42 : -0.42) * side
                let t = CGAffineTransform(translationX: p.x, y: p.y).rotated(by: tangent + tilt)
                leaves.addEllipse(in: CGRect(x: -22, y: -8.5, width: 44, height: 17), transform: t)
            }
        }
        // The crown's star and the foot's tie.
        var star: [CGPoint] = []
        let top = CGPoint(x: c.x, y: c.y + mid)
        for k in 0..<10 {
            let a = CGFloat.pi / 2 + CGFloat(k) * .pi / 5
            let rr: CGFloat = k % 2 == 0 ? 24 : 10
            star.append(CGPoint(x: top.x + cos(a) * rr, y: top.y + sin(a) * rr))
        }
        let foot = CGPoint(x: c.x, y: c.y - mid)
        let tie = CGMutablePath()
        ArtPrim.polygon(tie, [CGPoint(x: foot.x, y: foot.y), CGPoint(x: foot.x - 26, y: foot.y + 14),
                              CGPoint(x: foot.x - 26, y: foot.y - 14)])
        ArtPrim.polygon(tie, [CGPoint(x: foot.x, y: foot.y), CGPoint(x: foot.x + 26, y: foot.y - 14),
                              CGPoint(x: foot.x + 26, y: foot.y + 14)])
        leaves.addPath(Painter.polygon(star))
        leaves.addPath(tie)
        leaves.addPath(Painter.circle(foot, 7))
        // Struck: shadow, light edge, metal, a fine outline.
        let strikes: [(CGFloat, CGFloat, RGBA, Double)] = [(4, -4, m.dark, 0.95),
                                                            (-2.5, 2.5, ScenePaint.lighter(m.light, 0.3), 1)]
        for (dx, dy, color, a) in strikes {
            var shift = CGAffineTransform(translationX: dx, y: dy)
            if let moved = leaves.copy(using: &shift) { Painter.fill(ctx, moved, color, a) }
        }
        Painter.fill(ctx, leaves, m.mid)
        Painter.stroke(ctx, leaves, outline, width: 2.4, 0.45)
    }

    /// The glyph in `box` (y up): the tier's palette, rim detail, shine and velvet holes; or a cream silhouette until
    /// earned (the App's R3 rule).
    private static func drawBadgeGlyph(_ ctx: CGContext, _ glyph: BadgeGlyph, metal: BadgeMetal, earned: Bool,
                                       box: CGRect) {
        let art: LootArt
        switch glyph {
        case .sack: art = sackArt(radius: 50)
        case .relic(let shape): art = relicArt(shape, radius: 50)
        }
        let bb = art.silhouette.boundingBoxOfPath
        guard bb.width > 0, bb.height > 0 else { return }
        let pad = art.outlineWidth
        let s = min(box.width / (bb.width + 2 * pad), box.height / (bb.height + 2 * pad))
        ctx.saveGState()
        ctx.translateBy(x: box.midX - bb.midX * s, y: box.midY - bb.midY * s)
        ctx.scaleBy(x: s, y: s)
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        if !earned {
            Painter.stroke(ctx, art.silhouette, outline, width: art.outlineWidth, 0.6)
            Painter.fill(ctx, art.silhouette, RGBA(hex: 0xF7ECD6, alpha: 0.38))
            ctx.restoreGState()
            return
        }
        let col = badgeGlyphColors(metal)
        for p in art.parts { Painter.stroke(ctx, p, outline, width: art.outlineWidth * 2, 1) }
        for p in art.parts { Painter.fill(ctx, p, col.fill) }
        if !art.shade.isEmpty { Painter.fill(ctx, art.shade, col.rim, 0.3) }
        Painter.stroke(ctx, art.detail, col.rim, width: max(art.detailWidth, 0.5), 1)
        Painter.fill(ctx, art.shine, col.glint)
        if !art.holes.isEmpty { Painter.fill(ctx, art.holes, palette.velvet) }
        ctx.restoreGState()
    }
}

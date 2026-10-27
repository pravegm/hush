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

import SwiftUI

/// The App Store icon (ROUND-1 App): the chest, its lid slightly open, one sleepy eye peeking out of the dark gap, and
/// gold glow spilling from inside, on candlelit teal-black.
///
/// Pure vector in a 1024-unit design space, full-bleed, opaque and square-cornered: the system applies the mask.
/// Rendered to Documents/AppIcon-1024.png by demo `screen=icon` / `HUSH_ICON=1` (IconExport in App/DemoMode.swift);
/// CI copies it into Hush/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png.
struct AppIconArt: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            Canvas(opaque: true, rendersAsynchronously: false) { context, size in
                let scale = min(size.width, size.height) / 1024
                context.scaleBy(x: scale, y: scale)
                AppIconPainter.paint(&context)
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

enum AppIconPainter {
    static let night = Color(hushHex: 0x061113)
    static let teal = Color(hushHex: 0x143A3E)
    static let candle = Color(hushHex: 0xFFB45E)
    static let gold = Color(hushHex: 0xF6C45B)
    static let goldLight = Color(hushHex: 0xFFE7A6)
    static let goldDeep = Color(hushHex: 0xB5781F)
    static let wood = Color(hushHex: 0x9A6438)
    static let woodDark = Color(hushHex: 0x5E3A1E)
    static let iron = Color(hushHex: 0x30383B)
    static let ironLight = Color(hushHex: 0x59666A)
    static let mouth = Color(hushHex: 0x1A0A0E)
    static let ivory = Color(hushHex: 0xFFF5DE)
    static let iris = Color(hushHex: 0xF2A33A)

    /// The chest's frame in the 1024 space.
    static let bodyRect = CGRect(x: 172, y: 560, width: 680, height: 330)
    static let gapTop: CGFloat = 470
    static let lidRect = CGRect(x: 160, y: 250, width: 704, height: 230)

    static func paint(_ ctx: inout GraphicsContext) {
        background(&ctx)
        glow(&ctx)
        mouthAndEye(&ctx)
        body(&ctx)
        lid(&ctx)
        coins(&ctx)
    }

    static func background(_ ctx: inout GraphicsContext) {
        let all = Path(CGRect(x: 0, y: 0, width: 1024, height: 1024))
        ctx.fill(all, with: .linearGradient(Gradient(colors: [teal, night]), startPoint: CGPoint(x: 512, y: 0),
                                            endPoint: CGPoint(x: 512, y: 1024)))
        ctx.fill(all, with: .radialGradient(Gradient(colors: [candle.opacity(0.32), candle.opacity(0)]),
                                            center: CGPoint(x: 512, y: 520), startRadius: 0, endRadius: 560))
    }

    static func glow(_ ctx: inout GraphicsContext) {
        var g = ctx
        g.blendMode = .plusLighter
        g.fill(Path(ellipseIn: CGRect(x: 150, y: 330, width: 724, height: 330)),
               with: .radialGradient(Gradient(colors: [goldLight.opacity(0.7), gold.opacity(0.25), gold.opacity(0)]),
                                     center: CGPoint(x: 512, y: 520), startRadius: 20, endRadius: 380))
    }

    static func mouthAndEye(_ ctx: inout GraphicsContext) {
        // The dark gap between the lid and the body.
        let gap = CGRect(x: 190, y: gapTop, width: 644, height: bodyRect.minY - gapTop + 20)
        ctx.fill(Path(roundedRect: gap, cornerRadius: 24), with: .color(mouth))
        // Gold light along the gap's lower lip.
        ctx.fill(Path(roundedRect: CGRect(x: 210, y: bodyRect.minY - 18, width: 604, height: 22), cornerRadius: 11),
                 with: .linearGradient(Gradient(colors: [gold.opacity(0), goldLight, gold.opacity(0)]),
                                       startPoint: CGPoint(x: 210, y: 0), endPoint: CGPoint(x: 814, y: 0)))
        // One sleepy eye: half-closed, the iris peeking under a heavy lid.
        let eye = CGRect(x: 412, y: gapTop + 8, width: 200, height: 76)
        ctx.fill(Path(ellipseIn: eye), with: .color(ivory))
        var irisCtx = ctx
        irisCtx.clip(to: Path(ellipseIn: eye))
        irisCtx.fill(Path(ellipseIn: CGRect(x: 470, y: gapTop + 14, width: 84, height: 84)), with: .color(iris))
        irisCtx.fill(Path(ellipseIn: CGRect(x: 496, y: gapTop + 40, width: 32, height: 32)), with: .color(night))
        // The heavy eyelid.
        var lidPath = Path()
        lidPath.move(to: CGPoint(x: eye.minX - 6, y: eye.midY + 2))
        lidPath.addQuadCurve(to: CGPoint(x: eye.maxX + 6, y: eye.midY + 2), control: CGPoint(x: eye.midX, y: eye.minY - 40))
        lidPath.addLine(to: CGPoint(x: eye.maxX + 6, y: eye.minY - 10))
        lidPath.addLine(to: CGPoint(x: eye.minX - 6, y: eye.minY - 10))
        lidPath.closeSubpath()
        irisCtx.fill(lidPath, with: .color(Color(hushHex: 0x7A2E3A)))
        var lash = Path()
        lash.move(to: CGPoint(x: eye.minX, y: eye.midY + 2))
        lash.addQuadCurve(to: CGPoint(x: eye.maxX, y: eye.midY + 2), control: CGPoint(x: eye.midX, y: eye.minY - 36))
        ctx.stroke(lash, with: .color(night), style: StrokeStyle(lineWidth: 10, lineCap: .round))
    }

    static func body(_ ctx: inout GraphicsContext) {
        let r = bodyRect
        ctx.fill(Path(roundedRect: r, cornerRadius: 48),
                 with: .linearGradient(Gradient(colors: [wood, woodDark]), startPoint: CGPoint(x: 512, y: r.minY),
                                       endPoint: CGPoint(x: 512, y: r.maxY)))
        // Planks.
        for y in [r.minY + 110, r.minY + 220] {
            ctx.fill(Path(CGRect(x: r.minX + 20, y: y, width: r.width - 40, height: 8)), with: .color(woodDark))
        }
        // Iron bands.
        for x in [r.minX + 90, r.maxX - 150] {
            let band = CGRect(x: x, y: r.minY, width: 60, height: r.height)
            ctx.fill(Path(band), with: .color(iron))
            ctx.fill(Path(CGRect(x: x + 8, y: r.minY, width: 10, height: r.height)), with: .color(ironLight))
            for sy in stride(from: r.minY + 40, to: r.maxY - 20, by: 90) {
                ctx.fill(Path(ellipseIn: CGRect(x: x + 22, y: sy, width: 16, height: 16)), with: .color(ironLight))
            }
        }
        // The lock plate.
        let lock = CGRect(x: 512 - 58, y: r.minY + 40, width: 116, height: 140)
        ctx.fill(Path(roundedRect: lock, cornerRadius: 22), with: .color(goldDeep))
        ctx.fill(Path(roundedRect: lock.insetBy(dx: 8, dy: 8), cornerRadius: 16),
                 with: .linearGradient(Gradient(colors: [goldLight, gold]), startPoint: CGPoint(x: 512, y: lock.minY),
                                       endPoint: CGPoint(x: 512, y: lock.maxY)))
        ctx.fill(Path(ellipseIn: CGRect(x: 496, y: lock.minY + 44, width: 32, height: 32)), with: .color(mouth))
        ctx.fill(Path(CGRect(x: 504, y: lock.minY + 70, width: 16, height: 36)), with: .color(mouth))
    }

    static func lid(_ ctx: inout GraphicsContext) {
        let r = lidRect
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + 100))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + 100), control: CGPoint(x: r.midX, y: r.minY - 90))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        // Tilted back a little: the lid is slightly open.
        let tilt = CGAffineTransform(translationX: 512, y: r.maxY).rotated(by: -0.04).translatedBy(x: -512, y: -r.maxY)
        let lidPath = p.applying(tilt)
        ctx.fill(lidPath, with: .linearGradient(Gradient(colors: [wood, woodDark]),
                                                startPoint: CGPoint(x: 512, y: r.minY), endPoint: CGPoint(x: 512, y: r.maxY)))
        ctx.stroke(lidPath, with: .color(iron), style: StrokeStyle(lineWidth: 18, lineJoin: .round))
        // Teeth along the lid's lower edge (a hint of what it is).
        for i in 0..<6 {
            let x = 300 + CGFloat(i) * 80
            var tooth = Path()
            tooth.move(to: CGPoint(x: x, y: r.maxY - 6))
            tooth.addQuadCurve(to: CGPoint(x: x + 46, y: r.maxY - 6), control: CGPoint(x: x + 23, y: r.maxY + 54))
            tooth.closeSubpath()
            ctx.fill(tooth.applying(tilt), with: .color(ivory))
        }
        for x in [r.minX + 90, r.maxX - 150] {
            ctx.fill(Path(CGRect(x: x, y: r.minY + 40, width: 60, height: r.height - 40)).applying(tilt),
                     with: .color(iron))
        }
    }

    static func coins(_ ctx: inout GraphicsContext) {
        // Two coins glinting on the gap's lip.
        for (x, y) in [(CGFloat(280), CGFloat(532)), (CGFloat(700), CGFloat(540))] {
            let c = CGRect(x: x, y: y, width: 74, height: 40)
            ctx.fill(Path(ellipseIn: c.offsetBy(dx: 0, dy: 8)), with: .color(goldDeep))
            ctx.fill(Path(ellipseIn: c), with: .color(gold))
        }
        var spark = Path()
        let s = CGPoint(x: 760, y: 500)
        spark.move(to: CGPoint(x: s.x, y: s.y - 34))
        spark.addLine(to: CGPoint(x: s.x + 8, y: s.y - 8))
        spark.addLine(to: CGPoint(x: s.x + 34, y: s.y))
        spark.addLine(to: CGPoint(x: s.x + 8, y: s.y + 8))
        spark.addLine(to: CGPoint(x: s.x, y: s.y + 34))
        spark.addLine(to: CGPoint(x: s.x - 8, y: s.y + 8))
        spark.addLine(to: CGPoint(x: s.x - 34, y: s.y))
        spark.addLine(to: CGPoint(x: s.x - 8, y: s.y - 8))
        spark.closeSubpath()
        ctx.fill(spark, with: .color(ivory))
    }
}

import SwiftUI

/// Game Center achievement badges: one 1024 × 1024 image per achievement, in the app icon's style: the candlelit
/// teal-black dungeon, a medallion whose rim marks the tier (verdigris for the first four, silver, then gold), and one
/// simple motif picked from the achievement's id and title (a relic crown, a chest, a sleeping eye, teeth, the daily
/// sun, a coin stack, a key). No text except short numerals.
///
/// Pure vector in a 1024-unit design space, opaque, square-cornered. Rendered to Documents/badges/<id>.png by demo
/// `screen=badges` (BadgeExport in App/DemoMode.swift).
struct AchievementBadge: View {
    let def: AchievementDef
    let index: Int
    var side: CGFloat = 1024

    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: false) { context, size in
            let scale = min(size.width, size.height) / 1024
            context.scaleBy(x: scale, y: scale)
            BadgePainter.paint(&context, motif: BadgePainter.motif(id: def.id, title: def.title + " " + def.detail),
                               tier: BadgePainter.tier(index: index), numeral: index + 1)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

enum BadgePainter {
    enum Tier: Equatable { case verdigris, silver, gold }
    enum Motif: Equatable { case relic, chest, hush, bite, daily, gold, rank, numeral }

    static let night = Color(hushHex: 0x061012)
    static let deep = Color(hushHex: 0x10292C)
    static let candle = Color(hushHex: 0xFFB45E)
    static let gold = Color(hushHex: 0xF6C45B)
    static let goldLight = Color(hushHex: 0xFFE39B)
    static let goldDeep = Color(hushHex: 0xB5781F)
    static let ivory = Color(hushHex: 0xFFF6E2)
    static let wood = Color(hushHex: 0x8A5A32)
    static let woodDark = Color(hushHex: 0x5C3A1F)
    static let velvet = Color(hushHex: 0xB8344F)

    static let center = CGPoint(x: 512, y: 512)

    /// Four per tier, in `Achievements.all` order (the catalogue runs from first steps to the big ones). Pure; tested.
    static func tier(index: Int) -> Tier {
        if index >= 8 { return .gold }
        if index >= 4 { return .silver }
        return .verdigris
    }

    /// The motif from the id and title's words. Pure; tested.
    static func motif(id: String, title: String) -> Motif {
        // Every id starts "hush.ach.", so only the key after it counts (else every badge would read "hush").
        let key = id.hasPrefix("hush.ach.") ? String(id.dropFirst("hush.ach.".count)) : id
        let words = (key + " " + title).lowercased()
        if words.contains("relic") || words.contains("codex") || words.contains("crown") { return .relic }
        if words.contains("hush") || words.contains("quiet") || words.contains("asleep") || words.contains("stir")
            || words.contains("silent") || words.contains("ghost") { return .hush }
        if words.contains("bite") || words.contains("chomp") || words.contains("teeth") { return .bite }
        if words.contains("daily") || words.contains("dungeon") || words.contains("day") { return .daily }
        if words.contains("rank") || words.contains("whisperer") || words.contains("thief") { return .rank }
        if words.contains("gold") || words.contains("haul") || words.contains("coin") { return .gold }
        if words.contains("chest") || words.contains("bank") { return .chest }
        return .numeral
    }

    static func paint(_ ctx: inout GraphicsContext, motif: Motif, tier: Tier, numeral: Int) {
        background(&ctx)
        medallion(&ctx, tier: tier)
        switch motif {
        case .relic: crown(&ctx)
        case .chest: chest(&ctx)
        case .hush: sleepingEye(&ctx)
        case .bite: teeth(&ctx)
        case .daily: sun(&ctx)
        case .gold: coins(&ctx)
        case .rank: key(&ctx)
        case .numeral: number(&ctx, numeral)
        }
    }

    static func background(_ ctx: inout GraphicsContext) {
        let all = Path(CGRect(x: 0, y: 0, width: 1024, height: 1024))
        ctx.fill(all, with: .linearGradient(Gradient(colors: [deep, night]), startPoint: CGPoint(x: 512, y: 0),
                                            endPoint: CGPoint(x: 512, y: 1024)))
        ctx.fill(all, with: .radialGradient(Gradient(colors: [candle.opacity(0.28), candle.opacity(0)]),
                                            center: CGPoint(x: 512, y: 470), startRadius: 0, endRadius: 560))
    }

    static func medallion(_ ctx: inout GraphicsContext, tier: Tier) {
        let rim: [Color]
        switch tier {
        case .verdigris: rim = [Color(hushHex: 0x8FD6BE), Color(hushHex: 0x3E8C7A)]
        case .silver: rim = [Color(hushHex: 0xEEF3F2), Color(hushHex: 0x8E9C9A)]
        case .gold: rim = [goldLight, goldDeep]
        }
        let outer = Path(ellipseIn: CGRect(x: 132, y: 132, width: 760, height: 760))
        ctx.fill(outer, with: .linearGradient(Gradient(colors: rim), startPoint: CGPoint(x: 512, y: 132),
                                              endPoint: CGPoint(x: 512, y: 892)))
        let inner = Path(ellipseIn: CGRect(x: 180, y: 180, width: 664, height: 664))
        ctx.fill(inner, with: .radialGradient(Gradient(colors: [Color(hushHex: 0x1E4045), night]),
                                              center: CGPoint(x: 512, y: 440), startRadius: 0, endRadius: 360))
    }

    static func crown(_ ctx: inout GraphicsContext) {
        var p = Path()
        p.move(to: CGPoint(x: 300, y: 640))
        p.addLine(to: CGPoint(x: 280, y: 400))
        p.addLine(to: CGPoint(x: 400, y: 510))
        p.addLine(to: CGPoint(x: 512, y: 350))
        p.addLine(to: CGPoint(x: 624, y: 510))
        p.addLine(to: CGPoint(x: 744, y: 400))
        p.addLine(to: CGPoint(x: 724, y: 640))
        p.closeSubpath()
        ctx.fill(p, with: .linearGradient(Gradient(colors: [goldLight, gold]), startPoint: CGPoint(x: 512, y: 350),
                                          endPoint: CGPoint(x: 512, y: 640)))
        ctx.fill(Path(CGRect(x: 300, y: 640, width: 424, height: 56)), with: .color(goldDeep))
        for x in [280.0, 512.0, 744.0] {
            let y: CGFloat = x == 512 ? 350 : 400
            ctx.fill(Path(ellipseIn: CGRect(x: x - 26, y: y - 26, width: 52, height: 52)), with: .color(velvet))
        }
    }

    static func chest(_ ctx: inout GraphicsContext) {
        let body = Path(roundedRect: CGRect(x: 290, y: 500, width: 444, height: 210), cornerRadius: 26)
        ctx.fill(body, with: .color(wood))
        var lid = Path()
        lid.move(to: CGPoint(x: 290, y: 500))
        lid.addLine(to: CGPoint(x: 290, y: 440))
        lid.addQuadCurve(to: CGPoint(x: 734, y: 440), control: CGPoint(x: 512, y: 300))
        lid.addLine(to: CGPoint(x: 734, y: 500))
        lid.closeSubpath()
        ctx.fill(lid, with: .color(woodDark))
        for x in [340.0, 654.0] {
            ctx.fill(Path(CGRect(x: x, y: 380, width: 30, height: 330)), with: .color(Color(hushHex: 0x3A3F42)))
        }
        ctx.fill(Path(roundedRect: CGRect(x: 476, y: 470, width: 72, height: 92), cornerRadius: 12),
                 with: .color(gold))
    }

    static func sleepingEye(_ ctx: inout GraphicsContext) {
        var lid = Path()
        lid.move(to: CGPoint(x: 300, y: 560))
        lid.addQuadCurve(to: CGPoint(x: 724, y: 560), control: CGPoint(x: 512, y: 700))
        ctx.stroke(lid, with: .color(ivory), style: StrokeStyle(lineWidth: 40, lineCap: .round))
        for i in 0..<5 {
            let t = CGFloat(i) / 4
            let x = 340 + t * 344
            let y = 560 + sin(t * .pi) * 66
            var lash = Path()
            lash.move(to: CGPoint(x: x, y: y + 10))
            lash.addLine(to: CGPoint(x: x + (t - 0.5) * 40, y: y + 62))
            ctx.stroke(lash, with: .color(ivory), style: StrokeStyle(lineWidth: 18, lineCap: .round))
        }
        z(&ctx, at: CGPoint(x: 600, y: 330), size: 110)
        z(&ctx, at: CGPoint(x: 700, y: 250), size: 70)
    }

    static func z(_ ctx: inout GraphicsContext, at p: CGPoint, size: CGFloat) {
        var path = Path()
        path.move(to: CGPoint(x: p.x - size / 2, y: p.y - size / 2))
        path.addLine(to: CGPoint(x: p.x + size / 2, y: p.y - size / 2))
        path.addLine(to: CGPoint(x: p.x - size / 2, y: p.y + size / 2))
        path.addLine(to: CGPoint(x: p.x + size / 2, y: p.y + size / 2))
        ctx.stroke(path, with: .color(goldLight), style: StrokeStyle(lineWidth: size * 0.18, lineCap: .round,
                                                                     lineJoin: .round))
    }

    static func teeth(_ ctx: inout GraphicsContext) {
        ctx.fill(Path(roundedRect: CGRect(x: 270, y: 380, width: 484, height: 260), cornerRadius: 120),
                 with: .color(velvet))
        for i in 0..<4 {
            let x = 300 + CGFloat(i) * 108
            var top = Path()
            top.move(to: CGPoint(x: x, y: 380))
            top.addQuadCurve(to: CGPoint(x: x + 108, y: 380), control: CGPoint(x: x + 54, y: 560))
            ctx.fill(top, with: .color(ivory))
        }
        for i in 0..<3 {
            let x = 354 + CGFloat(i) * 108
            var bottom = Path()
            bottom.move(to: CGPoint(x: x, y: 640))
            bottom.addQuadCurve(to: CGPoint(x: x + 108, y: 640), control: CGPoint(x: x + 54, y: 480))
            ctx.fill(bottom, with: .color(ivory))
        }
    }

    static func sun(_ ctx: inout GraphicsContext) {
        ctx.fill(Path(ellipseIn: CGRect(x: 392, y: 392, width: 240, height: 240)), with: .color(gold))
        for i in 0..<12 {
            let a = Double(i) / 12 * 2 * .pi
            var ray = Path()
            ray.move(to: CGPoint(x: 512 + cos(a) * 160, y: 512 + sin(a) * 160))
            ray.addLine(to: CGPoint(x: 512 + cos(a) * 250, y: 512 + sin(a) * 250))
            ctx.stroke(ray, with: .color(goldLight), style: StrokeStyle(lineWidth: 26, lineCap: .round))
        }
    }

    static func coins(_ ctx: inout GraphicsContext) {
        for i in 0..<4 {
            let y = 640 - CGFloat(i) * 70
            let r = CGRect(x: 352, y: y - 40, width: 320, height: 110)
            ctx.fill(Path(ellipseIn: r.offsetBy(dx: 0, dy: 18)), with: .color(goldDeep))
            ctx.fill(Path(ellipseIn: r), with: .linearGradient(Gradient(colors: [goldLight, gold]),
                                                               startPoint: CGPoint(x: 512, y: r.minY),
                                                               endPoint: CGPoint(x: 512, y: r.maxY)))
        }
    }

    static func key(_ ctx: inout GraphicsContext) {
        ctx.stroke(Path(ellipseIn: CGRect(x: 300, y: 360, width: 200, height: 200)), with: .color(gold),
                   style: StrokeStyle(lineWidth: 48))
        ctx.fill(Path(CGRect(x: 488, y: 436, width: 280, height: 48)), with: .color(gold))
        ctx.fill(Path(CGRect(x: 680, y: 484, width: 40, height: 90)), with: .color(gold))
        ctx.fill(Path(CGRect(x: 600, y: 484, width: 40, height: 60)), with: .color(gold))
    }

    static func number(_ ctx: inout GraphicsContext, _ n: Int) {
        let text = Text("\(n)").font(.system(size: 360, weight: .black, design: .rounded)).foregroundColor(goldLight)
        ctx.draw(text, at: center, anchor: .center)
    }
}

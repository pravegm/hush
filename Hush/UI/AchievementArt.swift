import SwiftUI

// MARK: - Loot and relic art in SwiftUI (one source with the scene: ChestArt's LootArt)

/// The three colours an item is painted in (`ChestArt.lootColors`).
struct LootPalette {
    var fill: RGBA
    var rim: RGBA
    var glint: RGBA

    init(fill: RGBA, rim: RGBA, glint: RGBA) {
        self.fill = fill; self.rim = rim; self.glint = glint
    }

    init(_ kind: LootKind) {
        let c = ChestArt.lootColors(kind)
        self.init(fill: c.fill, rim: c.rim, glint: c.glint)
    }
}

/// Paints a `LootArt` (y up, centred) into a SwiftUI GraphicsContext the way the scene does (R2 Scene 15: Codex,
/// Results and badges look like the in-game relic): the dark outline under every part, the fill, the rim detail, the
/// shine, then the holes in `holeColor`. Or, `silhouette`, one dark flat shape (an unfound Codex slot).
enum LootPainter {
    static func paint(_ art: LootArt, palette: LootPalette, in ctx: inout GraphicsContext, rect: CGRect,
                      holeColor: Color, silhouette: Color? = nil) {
        let box = art.silhouette.boundingBoxOfPath
        guard box.width > 0, box.height > 0, rect.width > 0, rect.height > 0 else { return }
        let pad = art.outlineWidth
        let s = min(rect.width / (box.width + 2 * pad), rect.height / (box.height + 2 * pad))
        // y up → y down, centred in `rect`.
        let t = CGAffineTransform(a: s, b: 0, c: 0, d: -s, tx: rect.midX - box.midX * s, ty: rect.midY + box.midY * s)
        let outline = Color(hush: ChestArt.outline)
        if let silhouette {
            let shape = Path(art.silhouette).applying(t)
            ctx.stroke(shape, with: .color(outline.opacity(0.6)),
                       style: StrokeStyle(lineWidth: art.outlineWidth * s, lineJoin: .round))
            ctx.fill(shape, with: .color(silhouette))
            return
        }
        let parts = art.parts.map { Path($0).applying(t) }
        for p in parts {
            ctx.stroke(p, with: .color(outline), style: StrokeStyle(lineWidth: art.outlineWidth * s, lineCap: .round,
                                                                    lineJoin: .round))
        }
        for p in parts { ctx.fill(p, with: .color(Color(hush: palette.fill))) }
        ctx.stroke(Path(art.detail).applying(t), with: .color(Color(hush: palette.rim)),
                   style: StrokeStyle(lineWidth: max(art.detailWidth * s, 0.5), lineCap: .round, lineJoin: .round))
        ctx.fill(Path(art.shine).applying(t), with: .color(Color(hush: palette.glint)))
        ctx.fill(Path(art.holes).applying(t), with: .color(holeColor))
    }
}

/// A relic drawn from `ChestArt.relicArt` in the in-game style (found), or its dark, softened silhouette (unfound).
struct RelicArt: View {
    let relic: Relic
    let found: Bool
    var holeColor: Color = Color(hush: ChestArt.palette.velvet)

    var body: some View {
        let art = ChestArt.relicArt(relic.shape, radius: 50)
        let palette = LootPalette(.relic(relic.id))
        let found = self.found
        let hole = holeColor
        Canvas { ctx, size in
            LootPainter.paint(art, palette: palette, in: &ctx, rect: CGRect(origin: .zero, size: size), holeColor: hole,
                              silhouette: found ? nil : Color(hushHex: 0x2A0C18))
        }
        .blur(radius: found ? 0 : 1.6)
        .shadow(color: found ? HushTheme.candle.opacity(0.35) : .clear, radius: 6)
        .accessibilityHidden(true)
    }
}

/// A velvet tile (the chest's lining), the Codex's and the badge page's ground.
struct VelvetTile: View {
    var selected = false
    var radius: CGFloat = 16

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape.fill(LinearGradient(colors: [Color(hushHex: 0x6E2240), Color(hush: ChestArt.palette.velvet),
                                           Color(hushHex: 0x3E1023)],
                                  startPoint: .top, endPoint: .bottom))
            .overlay(shape.stroke(selected ? HushTheme.gold : HushTheme.goldDeep.opacity(0.45),
                                  lineWidth: selected ? 2.5 : 1.2))
            .overlay(shape.inset(by: 4).stroke(Color.black.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
    }
}

// MARK: - Game Center badges

/// Game Center achievement badges: one 1024 × 1024 image per achievement, in the in-game style (R2, juror P2-15): a
/// velvet medallion whose rim marks the tier (bronze, silver, gold), with one of the game's own relics drawn from
/// `ChestArt` as the motif, a different relic for each of the 12 (no two badges alike). No text.
///
/// Rendered to Documents/badges/<id>.png by demo `screen=badges` (BadgeExport in App/DemoMode.swift), and shown small
/// on the Badges page and on Results.
struct AchievementBadge: View {
    let def: AchievementDef
    let index: Int
    var side: CGFloat = 1024
    var earned = true

    var body: some View {
        let motif = BadgePainter.motif(index: index)
        let tier = BadgePainter.tier(index: index)
        let earned = self.earned
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            let scale = min(size.width, size.height) / 1024
            context.scaleBy(x: scale, y: scale)
            BadgePainter.paint(&context, motif: motif, tier: tier, earned: earned)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

enum BadgePainter {
    enum Tier: Equatable { case bronze, silver, gold }

    /// The 12 motifs, one per achievement in `Achievements.all` order (first steps → the big ones). Pure; tested.
    static let motifs: [RelicShape] = [.key, .bell, .lantern, .goblet, .crown, .musicBox, .idol, .compass, .hourglass,
                                       .scroll, .spyglass, .pocketWatch]

    static func motif(index: Int) -> RelicShape {
        motifs[((index % motifs.count) + motifs.count) % motifs.count]
    }

    /// Four per tier, in `Achievements.all` order. Pure; tested.
    static func tier(index: Int) -> Tier {
        if index >= 8 { return .gold }
        if index >= 4 { return .silver }
        return .bronze
    }

    static let night = Color(hushHex: 0x061012)
    static let deep = Color(hushHex: 0x10292C)
    static let candle = Color(hushHex: 0xFFB45E)

    static func rimColors(_ tier: Tier) -> [Color] {
        switch tier {
        case .bronze: return [Color(hushHex: 0xF0A96A), Color(hushHex: 0x7A3E18)]
        case .silver: return [Color(hushHex: 0xF2F6F5), Color(hushHex: 0x7C8A88)]
        case .gold: return [Color(hushHex: 0xFFE39B), Color(hushHex: 0xB5781F)]
        }
    }

    static func paint(_ ctx: inout GraphicsContext, motif: RelicShape, tier: Tier, earned: Bool) {
        let all = Path(CGRect(x: 0, y: 0, width: 1024, height: 1024))
        ctx.fill(all, with: .linearGradient(Gradient(colors: [deep, night]), startPoint: CGPoint(x: 512, y: 0),
                                            endPoint: CGPoint(x: 512, y: 1024)))
        ctx.fill(all, with: .radialGradient(Gradient(colors: [candle.opacity(earned ? 0.3 : 0.08), candle.opacity(0)]),
                                            center: CGPoint(x: 512, y: 470), startRadius: 0, endRadius: 560))
        let outline = Color(hush: ChestArt.outline)
        // The rim (tier metal) with the chunky outline, rivets, and the velvet inside.
        let outer = Path(ellipseIn: CGRect(x: 120, y: 120, width: 784, height: 784))
        ctx.stroke(outer, with: .color(outline), lineWidth: 26)
        let rim = earned ? rimColors(tier) : [Color(hushHex: 0x8A9693), Color(hushHex: 0x4A5552)]
        ctx.fill(outer, with: .linearGradient(Gradient(colors: rim), startPoint: CGPoint(x: 512, y: 120),
                                              endPoint: CGPoint(x: 512, y: 904)))
        for i in 0..<12 {
            let a = Double(i) / 12 * 2 * .pi
            let p = CGPoint(x: 512 + cos(a) * 356, y: 512 + sin(a) * 356)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 12, y: p.y - 12, width: 24, height: 24)),
                     with: .color(outline.opacity(0.55)))
        }
        let inner = Path(ellipseIn: CGRect(x: 192, y: 192, width: 640, height: 640))
        ctx.stroke(inner, with: .color(outline), lineWidth: 14)
        let velvet = earned ? [Color(hushHex: 0x7A2848), Color(hush: ChestArt.palette.velvet), Color(hushHex: 0x2E0A1A)]
            : [Color(hushHex: 0x2A3436), Color(hushHex: 0x1A2224), Color(hushHex: 0x0E1416)]
        ctx.fill(inner, with: .radialGradient(Gradient(colors: velvet), center: CGPoint(x: 470, y: 420), startRadius: 0,
                                              endRadius: 400))
        // The relic, 66 % of the velvet, never over the rim.
        let art = ChestArt.relicArt(motif, radius: 50)
        let box = CGRect(x: 512 - 212, y: 512 - 212, width: 424, height: 424)
        let palette: LootPalette
        switch tier {
        case .bronze: palette = LootPalette(fill: RGBA(hex: 0xE59A55), rim: RGBA(hex: 0x6A3412), glint: RGBA(hex: 0xFFE2B4))
        case .silver: palette = LootPalette(fill: RGBA(hex: 0xD8E2EA), rim: RGBA(hex: 0x56626F), glint: RGBA(hex: 0xFFFFFF))
        case .gold: palette = LootPalette(fill: RGBA(hex: 0xFFC94A), rim: RGBA(hex: 0x8A5A12), glint: RGBA(hex: 0xFFF4CC))
        }
        LootPainter.paint(art, palette: palette, in: &ctx, rect: box, holeColor: Color(hush: ChestArt.palette.velvet),
                          // R3 (juror P2): a locked badge is a readable cream silhouette, not black on grey.
                          silhouette: earned ? nil : Color(hushHex: 0xF7ECD6, alpha: 0.38))
    }
}

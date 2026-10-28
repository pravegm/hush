import SpriteKit
import UIKit

/// What a chest is dressed as: its tier, or the rare golden mimic (gold leaf, whatever the tier).
enum ChestDress: Hashable {
    case tier(ChestTier)
    case golden

    static func of(tier: ChestTier, golden: Bool) -> ChestDress { golden ? .golden : .tier(tier) }

    var key: String {
        switch self {
        case .tier(let t): return t.rawValue
        case .golden: return "golden"
        }
    }

    static var all: [ChestDress] { ChestTier.allCases.map { ChestDress.tier($0) } + [.golden] }
}

/// How each chest is dressed (GAME-DESIGN §6: wooden → iron-bound → gilded → royal, visibly richer; R2 golden).
struct TierStyle {
    let wood: RGBA
    let woodDark: RGBA
    let band: RGBA
    let stud: RGBA
    let velvet: RGBA
    let tuft: RGBA
    /// Iron (or gold) bands across the walls and lid.
    let bands: Bool
    /// Gold trim, gold studs and corner filigree.
    let gilt: Bool
    /// Set gems.
    let gems: Bool
    /// Gold leaf flecks over the wood (the golden mimic).
    let leaf: Bool

    static func of(_ tier: ChestTier) -> TierStyle { of(.tier(tier)) }

    static func of(_ dress: ChestDress) -> TierStyle {
        switch dress {
        case .tier(.wooden):
            return TierStyle(wood: RGBA(hex: 0x8A5A33), woodDark: RGBA(hex: 0x4A2C18), band: RGBA(hex: 0x5E6873),
                             stud: RGBA(hex: 0xA3ACB6), velvet: RGBA(hex: 0x5C1A33), tuft: RGBA(hex: 0x3A0E20),
                             bands: false, gilt: false, gems: false, leaf: false)
        case .tier(.iron):
            return TierStyle(wood: RGBA(hex: 0x74503A), woodDark: RGBA(hex: 0x3A2414), band: RGBA(hex: 0x4E5862),
                             stud: RGBA(hex: 0xB4BDC7), velvet: RGBA(hex: 0x40264A), tuft: RGBA(hex: 0x28142E),
                             bands: true, gilt: false, gems: false, leaf: false)
        case .tier(.gilded):
            return TierStyle(wood: RGBA(hex: 0x7E4628), woodDark: RGBA(hex: 0x40200F), band: RGBA(hex: 0xE3AC3A),
                             stud: RGBA(hex: 0xFFE08A), velvet: RGBA(hex: 0x701832), tuft: RGBA(hex: 0x480E20),
                             bands: true, gilt: true, gems: false, leaf: false)
        case .tier(.royal):
            return TierStyle(wood: RGBA(hex: 0x6A2230), woodDark: RGBA(hex: 0x320C16), band: RGBA(hex: 0xFFC94A),
                             stud: RGBA(hex: 0xFFF0B4), velvet: RGBA(hex: 0x4C1C62), tuft: RGBA(hex: 0x2E0C3C),
                             bands: true, gilt: true, gems: true, leaf: false)
        case .golden:
            return TierStyle(wood: RGBA(hex: 0xC8912E), woodDark: RGBA(hex: 0x6E4A12), band: RGBA(hex: 0xFFE08A),
                             stud: RGBA(hex: 0xFFF6CC), velvet: RGBA(hex: 0x1E5A4A), tuft: RGBA(hex: 0x12382E),
                             bands: true, gilt: true, gems: false, leaf: true)
        }
    }
}

extension SceneTextures {
    // MARK: The floor: chest walls and bed

    /// The chest seen from above (canvas `ChestLayout.frameRect`): rims, inner wall faces, the velvet bed, metalwork.
    static func chestFrame(_ tier: ChestTier) -> SKTexture { chestFrame(.tier(tier)) }

    static func chestFrame(_ dress: ChestDress) -> SKTexture {
        let fr = ChestLayout.frameRect
        return make("frame-\(dress.key)", width: fr.width, height: fr.height) { ctx, _ in
            // Draw in canvas coordinates.
            ctx.translateBy(x: -fr.minX, y: -fr.minY)
            drawChestFrame(ctx, TierStyle.of(dress))
        }
    }

    private static func drawChestFrame(_ ctx: CGContext, _ st: TierStyle) {
        let fr = ChestLayout.frameRect
        let rim = ChestLayout.rimInner
        let bed = ChestLayout.interior
        let lit = ScenePaint.lighter(st.wood, 0.12)
        Painter.fill(ctx, rect: fr, st.woodDark)

        // The rims' top surfaces (lit by the player's candle).
        let leftRim = CGRect(x: 0, y: fr.minY, width: rim.minX, height: fr.height)
        let rightRim = CGRect(x: rim.maxX, y: fr.minY, width: fr.maxX - rim.maxX, height: fr.height)
        let frontRim = CGRect(x: 0, y: fr.minY, width: fr.width, height: rim.minY - fr.minY)
        let backRim = CGRect(x: 0, y: rim.maxY, width: fr.width, height: fr.maxY - rim.maxY)
        for (i, r) in [leftRim, rightRim].enumerated() {
            Painter.gradient(ctx, Painter.rect(r), [lit, st.wood], [0, 1], from: CGPoint(x: r.minX, y: r.midY),
                             to: CGPoint(x: r.maxX, y: r.midY))
            Painter.grain(ctx, r, alongX: false, st.woodDark, seed: UInt64(11 + i), count: 3)
            var y = r.minY + 120
            while y < r.maxY - 20 {
                Painter.stroke(ctx, Painter.rect(CGRect(x: r.minX, y: y, width: r.width, height: 0.01)), st.woodDark,
                               width: 2.4, 0.8)
                y += 130
            }
        }
        for (i, r) in [frontRim, backRim].enumerated() {
            Painter.gradient(ctx, Painter.rect(r), [lit, st.wood], [0, 1], from: CGPoint(x: r.midX, y: r.maxY),
                             to: CGPoint(x: r.midX, y: r.minY))
            Painter.grain(ctx, r, alongX: true, st.woodDark, seed: UInt64(21 + i), count: 2)
        }

        // The inner faces (in shadow): back, left, right.
        let backFace = Painter.polygon([CGPoint(x: rim.minX, y: rim.maxY), CGPoint(x: bed.minX, y: bed.maxY),
                                        CGPoint(x: bed.maxX, y: bed.maxY), CGPoint(x: rim.maxX, y: rim.maxY)])
        let leftFace = Painter.polygon([CGPoint(x: rim.minX, y: rim.minY), CGPoint(x: bed.minX, y: bed.minY),
                                        CGPoint(x: bed.minX, y: bed.maxY), CGPoint(x: rim.minX, y: rim.maxY)])
        let rightFace = Painter.polygon([CGPoint(x: bed.maxX, y: bed.minY), CGPoint(x: rim.maxX, y: rim.minY),
                                         CGPoint(x: rim.maxX, y: rim.maxY), CGPoint(x: bed.maxX, y: bed.maxY)])
        let faceWood = ScenePaint.darker(st.wood, 0.42)
        Painter.gradient(ctx, backFace, [ScenePaint.darker(st.wood, 0.25), faceWood], [0, 1],
                         from: CGPoint(x: 0, y: rim.maxY), to: CGPoint(x: 0, y: bed.maxY))
        ctx.saveGState()
        ctx.addPath(backFace)
        ctx.clip()
        var x = bed.minX + 64
        while x < bed.maxX - 20 {
            Painter.stroke(ctx, Painter.polygon([CGPoint(x: x, y: bed.maxY), CGPoint(x: x + 1, y: bed.maxY),
                                                 CGPoint(x: x + 1, y: rim.maxY), CGPoint(x: x, y: rim.maxY)]),
                           st.woodDark, width: 2, 0.7)
            x += 86
        }
        ctx.restoreGState()
        for f in [leftFace, rightFace] {
            Painter.gradient(ctx, f, [faceWood, ScenePaint.darker(st.wood, 0.55)], [0, 1],
                             from: CGPoint(x: 0, y: rim.minY), to: CGPoint(x: 0, y: rim.maxY))
        }

        // The velvet bed with diamond tufting.
        let bedPath = Painter.rect(bed)
        Painter.gradient(ctx, bedPath, [ScenePaint.lighter(st.velvet, 0.08), st.velvet, ScenePaint.darker(st.velvet, 0.2)],
                         [0, 0.6, 1], from: CGPoint(x: bed.midX, y: bed.maxY), to: CGPoint(x: bed.midX, y: bed.minY))
        ctx.saveGState()
        ctx.addPath(bedPath)
        ctx.clip()
        let step: CGFloat = 64
        var k: CGFloat = -bed.height
        while k < bed.width + bed.height {
            let a = Painter.polygon([CGPoint(x: bed.minX + k, y: bed.minY), CGPoint(x: bed.minX + k + 1.5, y: bed.minY),
                                     CGPoint(x: bed.minX + k + 1.5 + bed.height, y: bed.maxY),
                                     CGPoint(x: bed.minX + k + bed.height, y: bed.maxY)])
            Painter.fill(ctx, a, st.tuft, 0.55)
            let b = Painter.polygon([CGPoint(x: bed.minX + k, y: bed.maxY), CGPoint(x: bed.minX + k + 1.5, y: bed.maxY),
                                     CGPoint(x: bed.minX + k + 1.5 + bed.height, y: bed.minY),
                                     CGPoint(x: bed.minX + k + bed.height, y: bed.minY)])
            Painter.fill(ctx, b, st.tuft, 0.55)
            k += step
        }
        var row = 0
        var by = bed.minY + step / 2
        while by < bed.maxY {
            var bx = bed.minX + (row % 2 == 0 ? step / 2 : 0)
            while bx < bed.maxX + 1 {
                Painter.fill(ctx, Painter.circle(CGPoint(x: bx, y: by), 4.5), st.tuft, 0.9)
                Painter.fill(ctx, Painter.circle(CGPoint(x: bx - 1.2, y: by + 1.2), 1.8),
                             st.gilt ? st.stud : ScenePaint.lighter(st.velvet, 0.35), 0.8)
                bx += step
            }
            by += step / 2
            row += 1
        }
        // Ambient occlusion along the walls.
        let ao = ScenePaint.outline
        Painter.linear(ctx, [RGBA(ao.r, ao.g, ao.b, 0.75), RGBA(ao.r, ao.g, ao.b, 0)], [0, 1],
                       from: CGPoint(x: 0, y: bed.minY), to: CGPoint(x: 0, y: bed.minY + 34))
        ctx.restoreGState()
        for (edge, inward) in [(CGPoint(x: bed.minX, y: 0), CGPoint(x: bed.minX + 26, y: 0)),
                               (CGPoint(x: bed.maxX, y: 0), CGPoint(x: bed.maxX - 26, y: 0)),
                               (CGPoint(x: 0, y: bed.maxY), CGPoint(x: 0, y: bed.maxY - 30))] {
            ctx.saveGState()
            ctx.addPath(bedPath)
            ctx.clip()
            Painter.linear(ctx, [RGBA(ao.r, ao.g, ao.b, 0.6), RGBA(ao.r, ao.g, ao.b, 0)], [0, 1], from: edge, to: inward)
            ctx.restoreGState()
        }

        // Chunky outlines: the rim's inner edge and the bed.
        Painter.stroke(ctx, Painter.rect(rim), ScenePaint.outline, width: 4, 0.9)
        Painter.stroke(ctx, bedPath, ScenePaint.outline, width: 3, 0.7)
        if st.gilt {
            Painter.stroke(ctx, Painter.rect(rim.insetBy(dx: -5, dy: -5)), st.band, width: 3, 0.95)
        }
        if st.leaf {
            for r in [leftRim, rightRim, frontRim, backRim] { goldLeaf(ctx, r, seed: UInt64(r.minX + r.minY + 5)) }
        }

        // Metalwork.
        drawCornerBrackets(ctx, st, frame: fr, rim: rim)
        if st.bands {
            for y in [CGFloat(206), 352] {
                for r in [CGRect(x: 0, y: y, width: rim.minX, height: 22),
                          CGRect(x: rim.maxX, y: y, width: fr.maxX - rim.maxX, height: 22)] {
                    strap(ctx, r, st)
                }
            }
            for x in [CGFloat(172), 498] {
                strap(ctx, CGRect(x: x - 12, y: fr.minY, width: 24, height: rim.minY - fr.minY), st)
                strap(ctx, CGRect(x: x - 11, y: bed.maxY, width: 22, height: fr.maxY - bed.maxY), st)
            }
        }
        if st.gilt {
            // (No filigree in the back-right corner: the pause socket is there.)
            for c in [CGPoint(x: bed.minX + 4, y: bed.minY + 4), CGPoint(x: bed.maxX - 4, y: bed.minY + 4),
                      CGPoint(x: bed.minX + 4, y: bed.maxY - 4)] {
                filigree(ctx, c, toward: CGPoint(x: bed.midX, y: bed.midY), st.band)
            }
        }
        // Studs along the side rims.
        var sy = fr.minY + 46
        // R4: no studs on the right rim where the pause seat may sit (it grows on phones: down to y ≈ 342).
        let socketBottom = ChestLayout.pauseSeat(viewScale: ChestLayout.minViewScale).minY - 6
        let jewels = st.gems ? ChestLayout.royalFloorJewels : []
        let jr = ChestLayout.royalJewelRadius
        while sy < fr.maxY - 16 {
            if !(st.bands && (abs(sy - 217) < 20 || abs(sy - 363) < 20)) {
                for x in [CGFloat(12), fr.maxX - 12] where x < fr.midX || sy < socketBottom {
                    // (No stud under a jewel.)
                    if jewels.contains(where: { abs($0.x - x) < jr + 8 && abs($0.y - sy) < jr + 8 }) { continue }
                    Painter.rivet(ctx, CGPoint(x: x, y: sy), 3.6, st.stud)
                }
            }
            sy += 44
        }
        // R11 (juror P2-4, tester 11, frame 16): the royal jewels sit where nothing of the HUD or the App covers them
        // (`ChestLayout.royalFloorJewels`): on the front brackets' corners and on the right rim between its straps.
        // They were on the candle, under the hint plate's cap and under the pause coin, and the back-rim pair was half
        // under the fold strip.
        let jewelColors = [RGBA(hex: 0xEC3352), RGBA(hex: 0xA95CE4), RGBA(hex: 0x3C7CEE)]
        for (i, c) in jewels.enumerated() {
            gemStud(ctx, c, jewelColors[i % jewelColors.count], size: jr)
        }
    }

    /// Gold-leaf flecks and a sheen over wood (the golden mimic).
    static func goldLeaf(_ ctx: CGContext, _ r: CGRect, seed: UInt64) {
        var rng = SceneRNG(seed: seed &+ 0x601D)
        ctx.saveGState()
        ctx.addPath(Painter.rect(r))
        ctx.clip()
        Painter.linear(ctx, [RGBA(1, 0.95, 0.7, 0), RGBA(1, 0.95, 0.7, 0.28), RGBA(1, 0.95, 0.7, 0)], [0, 0.5, 1],
                       from: CGPoint(x: r.minX, y: r.maxY), to: CGPoint(x: r.maxX, y: r.minY))
        let n = max(Int(r.width * r.height / 900), 4)
        for _ in 0..<n {
            let p = CGPoint(x: rng.range(r.minX, r.maxX), y: rng.range(r.minY, r.maxY))
            let s = rng.range(1.5, 4)
            Painter.fill(ctx, Painter.polygon([CGPoint(x: p.x - s, y: p.y), CGPoint(x: p.x, y: p.y + s * 0.7),
                                               CGPoint(x: p.x + s, y: p.y), CGPoint(x: p.x, y: p.y - s * 0.7)]),
                         RGBA(hex: 0xFFF3C0), Double(rng.range(0.4, 0.8)))
        }
        ctx.restoreGState()
    }

    static func strap(_ ctx: CGContext, _ r: CGRect, _ st: TierStyle) {
        let p = Painter.roundRect(r, 3)
        Painter.chunky(ctx, p, st.band, outline: 1.6, light: 0.35, shade: 0.35,
                       from: CGPoint(x: r.minX, y: r.maxY), to: CGPoint(x: r.maxX, y: r.minY))
        let long = r.width > r.height
        let n = max(Int((long ? r.width : r.height) / 34), 1)
        for i in 0..<n {
            let t = (CGFloat(i) + 0.5) / CGFloat(n)
            let c = long ? CGPoint(x: r.minX + t * r.width, y: r.midY) : CGPoint(x: r.midX, y: r.minY + t * r.height)
            Painter.rivet(ctx, c, 3.2, st.stud)
        }
    }

    static func bracket(_ ctx: CGContext, _ r: CGRect, _ metal: RGBA) {
        Painter.stroke(ctx, Painter.roundRect(r, 4), ScenePaint.outline, width: 3.2, 0.9)
        Painter.gradient(ctx, Painter.roundRect(r, 4),
                         [ScenePaint.lighter(metal, 0.3), metal, ScenePaint.darker(metal, 0.35)], [0, 0.5, 1],
                         from: CGPoint(x: r.minX, y: r.maxY), to: CGPoint(x: r.maxX, y: r.minY))
    }

    private static func drawCornerBrackets(_ ctx: CGContext, _ st: TierStyle, frame fr: CGRect, rim: CGRect) {
        let metal = st.gilt ? st.band : RGBA(hex: 0x5E6873)
        let arm: CGFloat = 76
        let corners: [(CGPoint, CGFloat, CGFloat)] = [(CGPoint(x: fr.minX, y: fr.minY), 1, 1),
                                                       (CGPoint(x: fr.maxX, y: fr.minY), -1, 1),
                                                       (CGPoint(x: fr.minX, y: fr.maxY), 1, -1),
                                                       (CGPoint(x: fr.maxX, y: fr.maxY), -1, -1)]
        for (c, sx, sy) in corners {
            // R3/R4: no bracket in the back-right corner: the pause coin sits there in its round brass seat
            // (drawn by `SceneFloorHUD` under the coin), never on metalwork.
            if sx < 0 && sy < 0 { continue }
            let t1 = sy > 0 ? rim.minY - fr.minY : fr.maxY - rim.maxY
            let t2 = sx > 0 ? rim.minX - fr.minX : fr.maxX - rim.maxX
            let a = CGRect(x: sx > 0 ? c.x : c.x - arm, y: sy > 0 ? c.y : c.y - t1, width: arm, height: t1)
            let b = CGRect(x: sx > 0 ? c.x : c.x - t2, y: sy > 0 ? c.y : c.y - arm, width: t2, height: arm)
            for r in [a, b] {
                Painter.stroke(ctx, Painter.roundRect(r, 4), ScenePaint.outline, width: 3.2, 0.9)
            }
            for r in [a, b] {
                Painter.gradient(ctx, Painter.roundRect(r, 4),
                                 [ScenePaint.lighter(metal, 0.3), metal, ScenePaint.darker(metal, 0.35)], [0, 0.5, 1],
                                 from: CGPoint(x: r.minX, y: r.maxY), to: CGPoint(x: r.maxX, y: r.minY))
            }
            Painter.rivet(ctx, CGPoint(x: c.x + sx * t2 * 0.5, y: c.y + sy * t1 * 0.5), 4, st.stud)
            Painter.rivet(ctx, CGPoint(x: c.x + sx * (arm - 12), y: c.y + sy * t1 * 0.5), 3.4, st.stud)
            Painter.rivet(ctx, CGPoint(x: c.x + sx * t2 * 0.5, y: c.y + sy * (arm - 12)), 3.4, st.stud)
        }
    }

    private static func filigree(_ ctx: CGContext, _ c: CGPoint, toward m: CGPoint, _ gold: RGBA) {
        let sx: CGFloat = m.x > c.x ? 1 : -1
        let sy: CGFloat = m.y > c.y ? 1 : -1
        let p = CGMutablePath()
        p.move(to: c)
        p.addCurve(to: CGPoint(x: c.x + sx * 34, y: c.y + sy * 8), control1: CGPoint(x: c.x + sx * 14, y: c.y),
                   control2: CGPoint(x: c.x + sx * 30, y: c.y + sy * 2))
        p.addCurve(to: CGPoint(x: c.x + sx * 24, y: c.y + sy * 14), control1: CGPoint(x: c.x + sx * 38, y: c.y + sy * 14),
                   control2: CGPoint(x: c.x + sx * 28, y: c.y + sy * 18))
        p.move(to: c)
        p.addCurve(to: CGPoint(x: c.x + sx * 8, y: c.y + sy * 34), control1: CGPoint(x: c.x, y: c.y + sy * 14),
                   control2: CGPoint(x: c.x + sx * 2, y: c.y + sy * 30))
        p.addCurve(to: CGPoint(x: c.x + sx * 14, y: c.y + sy * 24), control1: CGPoint(x: c.x + sx * 14, y: c.y + sy * 38),
                   control2: CGPoint(x: c.x + sx * 18, y: c.y + sy * 28))
        Painter.stroke(ctx, p, ScenePaint.outline, width: 5, 0.7)
        Painter.stroke(ctx, p, gold, width: 2.6, 1)
    }

    static func gemStud(_ ctx: CGContext, _ c: CGPoint, _ color: RGBA, size: CGFloat = 12) {
        Painter.rivet(ctx, c, size, RGBA(hex: 0xFFC94A))
        let g = Painter.circle(c, size * 0.67)
        Painter.stroke(ctx, g, ScenePaint.outline, width: 2, 0.8)
        Painter.radial(ctx, [ScenePaint.lighter(color, 0.6), color, ScenePaint.darker(color, 0.4)], [0, 0.4, 1],
                       center: CGPoint(x: c.x - size * 0.17, y: c.y + size * 0.17), radius: size * 0.75)
        Painter.fill(ctx, Painter.circle(CGPoint(x: c.x - size * 0.25, y: c.y + size * 0.25), size * 0.18),
                     RGBA(1, 1, 1), 0.85)
    }

    /// Horizontal planks with grain, alternating shade by plank index (shared by the lid, its extension and the
    /// front wall so they line up). `firstIndex` is the index of the plank whose bottom edge is at `firstBottom`.
    private static func planks(_ ctx: CGContext, _ area: CGRect, firstBottom: CGFloat, firstIndex: Int, height: CGFloat,
                               _ st: TierStyle, darkness: Double, seedBase: UInt64) {
        ctx.saveGState()
        ctx.addPath(Painter.rect(area))
        ctx.clip()
        var y = firstBottom
        var i = firstIndex
        while y < area.maxY {
            let r = CGRect(x: area.minX, y: y, width: area.width, height: height)
            let c = i % 2 == 0 ? ScenePaint.darker(st.wood, darkness) : ScenePaint.darker(st.wood, darkness + 0.08)
            Painter.gradient(ctx, Painter.rect(r), [ScenePaint.lighter(c, 0.06), c], [0, 1],
                             from: CGPoint(x: 0, y: r.maxY), to: CGPoint(x: 0, y: r.minY))
            Painter.grain(ctx, r, alongX: true, st.woodDark, seed: seedBase &+ UInt64(max(i, 0)), count: 3)
            Painter.stroke(ctx, Painter.rect(CGRect(x: r.minX, y: r.minY, width: r.width, height: 0.01)), st.woodDark,
                           width: 3, 0.9)
            y += height
            i += 1
        }
        ctx.restoreGState()
    }

    // MARK: The lid's underside (the mimic's upper jaw and face)

    static func lid(_ tier: ChestTier) -> SKTexture { lid(.tier(tier)) }

    /// The lid half's body (canvas lid, 670 × 456): planks to the top edge, side borders, bands, the fleshy eye bed.
    /// The far border and corner brackets are `lidCap` (drawn at the top of the visible lid, which may be higher).
    static func lid(_ dress: ChestDress) -> SKTexture {
        let s = ChestLayout.lidSize
        return make("lid-\(dress.key)", width: s.width, height: s.height) { ctx, sz in
            drawLid(ctx, sz, TierStyle.of(dress))
        }
    }

    static let lidBorder: CGFloat = 34

    private static func drawLid(_ ctx: CGContext, _ s: CGSize, _ st: TierStyle) {
        let border = lidBorder
        let mouthTop = ChestLayout.gumY + 4
        let inner = CGRect(x: border, y: mouthTop, width: s.width - 2 * border, height: s.height - mouthTop)
        Painter.fill(ctx, rect: CGRect(origin: .zero, size: s), st.woodDark)
        planks(ctx, inner, firstBottom: mouthTop, firstIndex: 0, height: 60, st, darkness: 0.18, seedBase: 100)
        // The side borders (to the top edge: the extension continues them).
        for r in [CGRect(x: 0, y: mouthTop, width: border, height: s.height - mouthTop),
                  CGRect(x: s.width - border, y: mouthTop, width: border, height: s.height - mouthTop)] {
            sideBorder(ctx, r, st)
        }
        for x in [border, s.width - border] {
            Painter.stroke(ctx, Painter.rect(CGRect(x: x, y: mouthTop, width: 0.01, height: s.height - mouthTop)),
                           ScenePaint.outline, width: 4, 0.85)
        }
        Painter.stroke(ctx, Painter.rect(CGRect(x: border, y: mouthTop, width: inner.width, height: 0.01)),
                       ScenePaint.outline, width: 4, 0.85)
        if st.leaf { goldLeaf(ctx, inner, seed: 41) }
        // The mouth: the dark throat behind the teeth.
        let mouth = CGRect(x: 0, y: 0, width: s.width, height: mouthTop)
        Painter.linear(ctx, [ScenePaint.throat, RGBA(hex: 0x4A1022)], [0, 1], from: CGPoint(x: 0, y: 0),
                       to: CGPoint(x: 0, y: mouth.maxY))
        // Bands.
        if st.bands {
            for x in [CGFloat(140), 530] {
                strap(ctx, CGRect(x: x - 15, y: mouthTop, width: 30, height: s.height - mouthTop), st)
            }
        }
        // Studs along the side borders.
        var sy = mouthTop + 40
        while sy < s.height - 10 {
            Painter.rivet(ctx, CGPoint(x: border * 0.5, y: sy), 4, st.stud)
            Painter.rivet(ctx, CGPoint(x: s.width - border * 0.5, y: sy), 4, st.stud)
            sy += 58
        }
        // R2: the eye sits in a fleshy eyelid bed, not a carved porthole.
        let ec = ChestLayout.eyeCenter
        let er = ChestLayout.eyeRadius
        let bed = ChestArt.mimicEyeBed(size: s)
        if st.gilt {
            var t = CGAffineTransform(translationX: ec.x, y: ec.y).scaledBy(x: 1.08, y: 1.12)
                .translatedBy(x: -ec.x, y: -ec.y)
            if let ring = bed.copy(using: &t) {
                Painter.stroke(ctx, ring, ScenePaint.outline, width: 9, 0.8)
                Painter.stroke(ctx, ring, st.band, width: 5, 1)
            }
        }
        Painter.stroke(ctx, bed, ScenePaint.outline, width: 10, 0.9)
        ctx.saveGState()
        ctx.addPath(bed)
        ctx.clip()
        Painter.radial(ctx, [ScenePaint.lighter(ChestArt.flesh, 0.12), ChestArt.flesh, ChestArt.fleshDark],
                       [0, 0.55, 1], center: CGPoint(x: ec.x - er * 0.3, y: ec.y + er * 0.3), radius: er * 1.9,
                       extend: true)
        // The socket's dark hollow right round the eyeball.
        let hollow = ChestArt.mimicEye(wake: 1, size: s).white
        var grow = CGAffineTransform(translationX: ec.x, y: ec.y).scaledBy(x: 1.06, y: 1.12)
            .translatedBy(x: -ec.x, y: -ec.y)
        if let h = hollow.copy(using: &grow) { Painter.fill(ctx, h, RGBA(hex: 0x2A0A12), 0.9) }
        ctx.restoreGState()
        // A soft crease above the bed.
        let crease = CGMutablePath()
        crease.move(to: CGPoint(x: ec.x - er * 1.2, y: ec.y + er * 1.05))
        crease.addQuadCurve(to: CGPoint(x: ec.x + er * 1.2, y: ec.y + er * 1.05),
                            control: CGPoint(x: ec.x, y: ec.y + er * 1.6))
        Painter.stroke(ctx, crease, ChestArt.fleshDark, width: 4, 0.55)
        if st.gems {
            // Clear of the brow above and the plate below.
            for (k, a) in [CGFloat(0.25), 0.7, 2.44, 2.89].enumerated() {
                let p = CGPoint(x: ec.x + cos(a) * (er * 1.75 + 10), y: ec.y + sin(a) * (er * 1.2 + 14))
                gemStud(ctx, p, k % 2 == 0 ? RGBA(hex: 0xEC3352) : RGBA(hex: 0x3C7CEE), size: 10)
            }
        }
    }

    private static func sideBorder(_ ctx: CGContext, _ r: CGRect, _ st: TierStyle) {
        Painter.gradient(ctx, Painter.rect(r), [st.wood, ScenePaint.darker(st.wood, 0.2)], [0, 1],
                         from: CGPoint(x: r.minX, y: r.maxY), to: CGPoint(x: r.maxX, y: r.minY))
        Painter.grain(ctx, r, alongX: false, st.woodDark, seed: UInt64(r.minX + 3), count: 2)
        if st.leaf { goldLeaf(ctx, r, seed: UInt64(r.minX + 9)) }
    }

    /// The lid's far border and its corner brackets (670 × 90, transparent below the brackets).
    static func lidCap(_ dress: ChestDress) -> SKTexture {
        make("lid-cap-\(dress.key)", width: 670, height: ChestLayout.lidCapHeight) { ctx, s in
            let st = TierStyle.of(dress)
            let border = lidBorder
            let top = CGRect(x: 0, y: s.height - border, width: s.width, height: border)
            Painter.fill(ctx, rect: top.insetBy(dx: 0, dy: -1), ScenePaint.outline, 0.85)
            Painter.gradient(ctx, Painter.rect(top), [st.wood, ScenePaint.darker(st.wood, 0.2)], [0, 1],
                             from: CGPoint(x: 0, y: top.maxY), to: CGPoint(x: 0, y: top.minY))
            Painter.grain(ctx, top, alongX: true, st.woodDark, seed: 7, count: 2)
            if st.leaf { goldLeaf(ctx, top, seed: 17) }
            Painter.stroke(ctx, Painter.rect(CGRect(x: border, y: top.minY, width: s.width - 2 * border, height: 0.01)),
                           ScenePaint.outline, width: 4, 0.85)
            if st.bands {
                for x in [CGFloat(140), 530] {
                    strap(ctx, CGRect(x: x - 15, y: top.minY, width: 30, height: border), st)
                }
            }
            let metal = st.gilt ? st.band : RGBA(hex: 0x5E6873)
            for (cx, sx) in [(CGFloat(0), CGFloat(1)), (s.width, -1)] {
                let a = CGRect(x: sx > 0 ? cx : cx - 84, y: s.height - border, width: 84, height: border)
                let b = CGRect(x: sx > 0 ? cx : cx - border, y: s.height - 84, width: border, height: 84)
                for r in [a, b] { Painter.stroke(ctx, Painter.roundRect(r, 4), ScenePaint.outline, width: 3.2, 0.9) }
                for r in [a, b] { bracket(ctx, r, metal) }
                Painter.rivet(ctx, CGPoint(x: cx + sx * border * 0.5, y: s.height - border * 0.5), 4.5, st.stud)
                Painter.rivet(ctx, CGPoint(x: cx + sx * 64, y: s.height - border * 0.5), 3.4, st.stud)
                Painter.rivet(ctx, CGPoint(x: cx + sx * border * 0.5, y: s.height - 66), 3.4, st.stud)
            }
            if st.gems {
                gemStud(ctx, CGPoint(x: s.width / 2, y: s.height - border / 2), RGBA(hex: 0xEC3352), size: 11)
            }
        }
    }

    /// Two more lid planks with the side borders and bands (repeated upward above the canvas lid).
    static func lidTile(_ dress: ChestDress) -> SKTexture {
        let h = ChestLayout.lidTileHeight
        return make("lid-tile-\(dress.key)", width: 670, height: h) { ctx, s in
            let st = TierStyle.of(dress)
            let border = lidBorder
            Painter.fill(ctx, rect: CGRect(origin: .zero, size: s), st.woodDark)
            // The canvas lid's planks start at 64 every 60, so a tile starting at lid y 456 has edges at 28 and 88.
            let inner = CGRect(x: border, y: 0, width: s.width - 2 * border, height: s.height)
            planks(ctx, inner, firstBottom: -32, firstIndex: 6, height: 60, st, darkness: 0.18, seedBase: 100)
            if st.leaf { goldLeaf(ctx, inner, seed: 43) }
            for r in [CGRect(x: 0, y: 0, width: border, height: s.height),
                      CGRect(x: s.width - border, y: 0, width: border, height: s.height)] {
                sideBorder(ctx, r, st)
            }
            for x in [border, s.width - border] {
                Painter.stroke(ctx, Painter.rect(CGRect(x: x, y: 0, width: 0.01, height: s.height)), ScenePaint.outline,
                               width: 4, 0.85)
            }
            if st.bands {
                for x in [CGFloat(140), 530] {
                    strap(ctx, CGRect(x: x - 15, y: 0, width: 30, height: s.height), st)
                }
            }
            for y in [CGFloat(54), 112] {
                Painter.rivet(ctx, CGPoint(x: border * 0.5, y: y), 4, st.stud)
                Painter.rivet(ctx, CGPoint(x: s.width - border * 0.5, y: y), 4, st.stud)
            }
        }
    }

    // MARK: Below the floor: the chest's front wall, the big lock, the tabletop

    /// The chest's front face (670 × 314: its top 104 pt sit behind the satchel), planks, corner posts, bands.
    static func frontWall(_ dress: ChestDress) -> SKTexture {
        let h = ChestLayout.frontWallTop + ChestLayout.frontWallMax
        // 1.5× is plenty for the wall under the satchel (it keeps five dresses' walls under 10 MB).
        return make("front-\(dress.key)", width: 670, height: h, scale: 1.5) { ctx, s in
            let st = TierStyle.of(dress)
            Painter.fill(ctx, rect: CGRect(origin: .zero, size: s), st.woodDark)
            let body = CGRect(x: 40, y: 14, width: s.width - 80, height: s.height - 14)
            planks(ctx, body, firstBottom: s.height - 60 * 6, firstIndex: 0, height: 60, st, darkness: 0.0,
                   seedBase: 500)
            if st.leaf { goldLeaf(ctx, body, seed: 61) }
            // Corner posts.
            for r in [CGRect(x: 0, y: 0, width: 40, height: s.height), CGRect(x: s.width - 40, y: 0, width: 40,
                                                                             height: s.height)] {
                Painter.gradient(ctx, Painter.rect(r), [ScenePaint.lighter(st.wood, 0.1), ScenePaint.darker(st.wood, 0.3)],
                                 [0, 1], from: CGPoint(x: r.minX, y: 0), to: CGPoint(x: r.maxX, y: 0))
                Painter.grain(ctx, r, alongX: false, st.woodDark, seed: UInt64(r.minX + 71), count: 2)
                Painter.stroke(ctx, Painter.rect(r), ScenePaint.outline, width: 3, 0.85)
            }
            // The base trim and its shadow.
            let base = CGRect(x: 0, y: 0, width: s.width, height: 16)
            Painter.gradient(ctx, Painter.rect(base), [ScenePaint.darker(st.wood, 0.1), ScenePaint.darker(st.wood, 0.45)],
                             [0, 1], from: CGPoint(x: 0, y: 16), to: CGPoint(x: 0, y: 0))
            Painter.stroke(ctx, Painter.rect(CGRect(x: 0, y: 16, width: s.width, height: 0.01)), ScenePaint.outline,
                           width: 3, 0.9)
            if st.bands {
                for x in [CGFloat(172), 498] {
                    strap(ctx, CGRect(x: x - 12, y: 0, width: 24, height: s.height), st)
                }
            }
            // Corner brackets at the bottom corners.
            let metal = st.gilt ? st.band : RGBA(hex: 0x5E6873)
            for (cx, sx) in [(CGFloat(0), CGFloat(1)), (s.width, -1)] {
                let a = CGRect(x: sx > 0 ? cx : cx - 90, y: 0, width: 90, height: 30)
                let b = CGRect(x: sx > 0 ? cx : cx - 40, y: 0, width: 40, height: 96)
                for r in [a, b] { Painter.stroke(ctx, Painter.roundRect(r, 4), ScenePaint.outline, width: 3.2, 0.9) }
                for r in [a, b] { bracket(ctx, r, metal) }
                Painter.rivet(ctx, CGPoint(x: cx + sx * 20, y: 15), 4.5, st.stud)
                Painter.rivet(ctx, CGPoint(x: cx + sx * 72, y: 15), 3.6, st.stud)
                Painter.rivet(ctx, CGPoint(x: cx + sx * 20, y: 78), 3.6, st.stud)
            }
            var y: CGFloat = 130
            while y < s.height - 10 {
                Painter.rivet(ctx, CGPoint(x: 20, y: y), 3.6, st.stud)
                Painter.rivet(ctx, CGPoint(x: s.width - 20, y: y), 3.6, st.stud)
                y += 52
            }
            if st.gems {
                gemStud(ctx, CGPoint(x: 20, y: 150), RGBA(hex: 0xEC3352), size: 10)
                gemStud(ctx, CGPoint(x: s.width - 20, y: 150), RGBA(hex: 0x3C7CEE), size: 10)
            }
        }
    }

    /// R4: one keyhole outline (y up): a round top of `radius` at `center` and a tapered slot below it, joined with no
    /// neck (the slot is 1.3 × the radius wide where it meets the circle, 1.8 × at its flat foot, 2.6 × long). Pure
    /// geometry, `nonisolated` (texture closures call it). Tests: one connected shape, wider at the foot than the neck.
    nonisolated static func keyholePath(center c: CGPoint, radius r: CGFloat) -> CGPath {
        let ring = CGMutablePath()
        ArtPrim.oval(ring, CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        let slot = CGMutablePath()
        ArtPrim.polygon(slot, [CGPoint(x: c.x - r * 0.65, y: c.y - r * 0.2), CGPoint(x: c.x + r * 0.65, y: c.y - r * 0.2),
                               CGPoint(x: c.x + r * 0.9, y: c.y - r * 2.8), CGPoint(x: c.x - r * 0.9, y: c.y - r * 2.8)])
        return ring.union(slot)
    }

    /// The big brass lock on the chest's front (150 × 170): a hasp from the lid edge, a shield plate, a keyhole.
    static var bigLock: SKTexture {
        make("big-lock-r4", width: 150, height: 170) { ctx, s in
            let hasp = Painter.roundRect(CGRect(x: s.width / 2 - 22, y: s.height - 60, width: 44, height: 58), 10)
            Painter.chunky(ctx, hasp, ScenePaint.brass, outline: 2.4, light: 0.4, shade: 0.4,
                           from: CGPoint(x: 0, y: s.height), to: CGPoint(x: 0, y: s.height - 60))
            Painter.rivet(ctx, CGPoint(x: s.width / 2, y: s.height - 18), 5, ScenePaint.brassLight)
            let shield = CGMutablePath()
            shield.move(to: CGPoint(x: 14, y: s.height - 56))
            shield.addLine(to: CGPoint(x: s.width - 14, y: s.height - 56))
            shield.addCurve(to: CGPoint(x: s.width / 2, y: 6), control1: CGPoint(x: s.width - 10, y: 60),
                            control2: CGPoint(x: s.width * 0.7, y: 18))
            shield.addCurve(to: CGPoint(x: 14, y: s.height - 56), control1: CGPoint(x: s.width * 0.3, y: 18),
                            control2: CGPoint(x: 10, y: 60))
            shield.closeSubpath()
            Painter.chunky(ctx, shield, ScenePaint.brass, outline: 3, light: 0.5, shade: 0.45,
                           from: CGPoint(x: 14, y: s.height - 56), to: CGPoint(x: s.width - 14, y: 10))
            var inset = CGAffineTransform(translationX: s.width / 2, y: 60).scaledBy(x: 0.8, y: 0.8)
                .translatedBy(x: -s.width / 2, y: -60)
            if let inner = shield.copy(using: &inset) {
                Painter.stroke(ctx, inner, ScenePaint.brassDark, width: 2.5, 0.8)
            }
            // R4 (tester 7, founder): the keyhole reads as a keyhole either way up (turned captures read the old
            // one as "!"): a raised oval escutcheon frames it, and the slot joins the round top with no neck (it is
            // wider than half the circle where they meet), tapering out to a flat foot.
            let kc = CGPoint(x: s.width / 2, y: 74)
            let esc = Painter.oval(CGRect(x: kc.x - 23, y: kc.y - 46, width: 46, height: 76))
            Painter.chunky(ctx, esc, ScenePaint.brassDark, outline: 2, light: 0.55, shade: 0.3,
                           from: CGPoint(x: kc.x - 23, y: kc.y + 30), to: CGPoint(x: kc.x + 23, y: kc.y - 46))
            Painter.stroke(ctx, Painter.oval(CGRect(x: kc.x - 18, y: kc.y - 40, width: 36, height: 64)),
                           ScenePaint.brassLight, width: 1.6, 0.55)
            let hole = SceneTextures.keyholePath(center: kc, radius: 11)
            Painter.fill(ctx, hole, RGBA(hex: 0x140804))
            Painter.stroke(ctx, hole, ScenePaint.outline, width: 2.2, 0.9)
            Painter.stroke(ctx, hole, ScenePaint.brassLight, width: 1, 0.5)
            for c in [CGPoint(x: 30, y: s.height - 70), CGPoint(x: s.width - 30, y: s.height - 70),
                      CGPoint(x: s.width / 2, y: 22)] {
                Painter.rivet(ctx, c, 4.5, ScenePaint.brassLight)
            }
            Painter.fill(ctx, Painter.oval(CGRect(x: 30, y: s.height - 92, width: 16, height: 30)), RGBA(1, 1, 1), 0.45)
        }
    }

    /// The tabletop under the chest (670 × 160): dark oak, a contact shadow along the top.
    static var tabletop: SKTexture {
        make("tabletop", width: 670, height: 160) { ctx, s in
            Painter.fill(ctx, rect: CGRect(origin: .zero, size: s), RGBA(hex: 0x24160C))
            var y = s.height
            var i = 0
            while y > 0 {
                let r = CGRect(x: 0, y: y - 44, width: s.width, height: 44)
                let c = i % 2 == 0 ? RGBA(hex: 0x3A2414) : RGBA(hex: 0x33200F)
                Painter.gradient(ctx, Painter.rect(r), [ScenePaint.lighter(c, 0.06), c], [0, 1],
                                 from: CGPoint(x: 0, y: r.maxY), to: CGPoint(x: 0, y: r.minY))
                Painter.grain(ctx, r, alongX: true, RGBA(hex: 0x1A0E06), seed: UInt64(900 + i), count: 3)
                Painter.stroke(ctx, Painter.rect(CGRect(x: 0, y: r.minY, width: s.width, height: 0.01)),
                               RGBA(hex: 0x140A04), width: 2.5, 0.9)
                y -= 44
                i += 1
            }
            // The chest's contact shadow and a candle-lit sheen.
            Painter.linear(ctx, [RGBA(0, 0, 0, 0), RGBA(0, 0, 0, 0.75)], [0, 1], from: CGPoint(x: 0, y: s.height - 30),
                           to: CGPoint(x: 0, y: s.height))
            Painter.radial(ctx, [RGBA(1, 0.8, 0.5, 0.12), RGBA(1, 0.8, 0.5, 0)], [0, 1],
                           center: CGPoint(x: s.width / 2, y: s.height * 0.4), radius: s.width * 0.5)
        }
    }

    // MARK: The tongue (the mimic's tell, on the bed)

    static let tongueSize = CGSize(width: 460, height: 282)

    /// R3: a real tongue: a wide root at the throat (~78 % of the texture), the sides drawing in to a rounded POINT
    /// at the bag end (no blunt dome, no twin lobes).
    static func tonguePath(_ s: CGSize) -> CGPath {
        let p = CGMutablePath()
        let w = s.width, h = s.height
        p.move(to: CGPoint(x: w * 0.11, y: h))
        p.addCurve(to: CGPoint(x: w * 0.355, y: h * 0.2), control1: CGPoint(x: w * 0.05, y: h * 0.6),
                   control2: CGPoint(x: w * 0.2, y: h * 0.33))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.018), control1: CGPoint(x: w * 0.43, y: h * 0.12),
                   control2: CGPoint(x: w * 0.465, y: h * 0.03))
        p.addCurve(to: CGPoint(x: w * 0.645, y: h * 0.2), control1: CGPoint(x: w * 0.535, y: h * 0.03),
                   control2: CGPoint(x: w * 0.57, y: h * 0.12))
        p.addCurve(to: CGPoint(x: w * 0.89, y: h), control1: CGPoint(x: w * 0.8, y: h * 0.33),
                   control2: CGPoint(x: w * 0.95, y: h * 0.6))
        p.closeSubpath()
        return p
    }

    /// The tongue's velvet body (shared by the resting and the curled texture): fill, papillae, throat shade.
    private static func drawTongueBody(_ ctx: CGContext, _ sz: CGSize, base t: RGBA, highlight: Double) {
        let path = tonguePath(sz)
        Painter.stroke(ctx, path, ScenePaint.darker(t, 0.6), width: 8, 0.95)
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        Painter.radial(ctx, [ScenePaint.lighter(t, 0.12), t, ScenePaint.darker(t, 0.34)], [0, 0.5, 1],
                       center: CGPoint(x: sz.width * 0.44, y: sz.height * 0.46), radius: sz.width * 0.5,
                       extend: true)
        // Velvet stipple (papillae, ~15 %) and a few darker pores: in every state.
        var rng = SceneRNG(seed: 0x70_9E)
        for _ in 0..<220 {
            let p = CGPoint(x: rng.range(10, sz.width - 10), y: rng.range(10, sz.height - 10))
            Painter.fill(ctx, Painter.circle(p, rng.range(0.9, 2.2)), ScenePaint.lighter(t, 0.42),
                         Double(rng.range(0.1, 0.2)))
        }
        for _ in 0..<70 {
            let p = CGPoint(x: rng.range(10, sz.width - 10), y: rng.range(10, sz.height - 10))
            Painter.fill(ctx, Painter.circle(p, rng.range(0.8, 1.6)), ScenePaint.darker(t, 0.35), 0.25)
        }
        // One soft, off-centre specular highlight (a single sheen: never two lobes).
        ctx.saveGState()
        ctx.translateBy(x: sz.width * 0.4, y: sz.height * 0.52)
        ctx.scaleBy(x: 1, y: 1.8)
        Painter.radial(ctx, [RGBA(1, 0.9, 0.93, highlight), RGBA(1, 0.9, 0.93, 0)], [0, 1], center: .zero, radius: 44)
        ctx.restoreGState()
        // The throat: the root recedes into the dark at the fold.
        Painter.linear(ctx, [RGBA(0.05, 0.01, 0.02, 0), RGBA(0.05, 0.01, 0.02, 0.92)], [0, 1],
                       from: CGPoint(x: 0, y: sz.height * 0.66), to: CGPoint(x: 0, y: sz.height))
        ctx.restoreGState()
    }

    /// The velvet tongue lying on the bed: root at the top (the throat at the hinge), tip toward the player. R3: no
    /// crease in the texture (it is `tongueCrease`, shown only when lit).
    static var tongue: SKTexture {
        let s = tongueSize
        return make("tongue-r3", width: s.width, height: s.height) { ctx, sz in
            drawTongueBody(ctx, sz, base: ChestArt.palette.tongue, highlight: 0.32)
            // A soft rim light along the upper-left edge, inside the outline.
            let path = tonguePath(sz)
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            var shift = CGAffineTransform(translationX: 4, y: -4)
            if let rim = path.copy(using: &shift) {
                Painter.stroke(ctx, rim, ScenePaint.lighter(ChestArt.palette.tongue, 0.5), width: 7, 0.22)
            }
            ctx.restoreGState()
        }
    }

    /// The short median groove at the root (a child of the tongue; its alpha follows the light, 0 when dim).
    static var tongueCrease: SKTexture {
        make("tongue-crease-r3", width: 16, height: 90) { ctx, s in
            let t = ChestArt.palette.tongue
            for k in 0..<6 {
                let y0 = s.height - CGFloat(k) * 14
                let seg = CGMutablePath()
                seg.move(to: CGPoint(x: s.width / 2, y: y0))
                seg.addLine(to: CGPoint(x: s.width / 2 - 0.5, y: y0 - 14))
                Painter.stroke(ctx, seg, ScenePaint.darker(t, 0.45), width: 6 - CGFloat(k) * 0.7,
                               0.6 * (1 - Double(k) / 6))
            }
        }
    }

    /// R3: the tongue tensed (Waking): the SAME filled outline, darker and redder (+20 % saturation, −15 % value),
    /// the tip curling up (its paler underside shows as a crescent at the point, with a shadow below it). Drawn over
    /// `tongue` at the curl level, so it never hollows out.
    static var tongueCurl: SKTexture {
        let s = tongueSize
        return make("tongue-curl-r3", width: s.width, height: s.height) { ctx, sz in
            let tense = RGBA(hex: 0xB8243E)
            drawTongueBody(ctx, sz, base: tense, highlight: 0.18)
            let w = sz.width, h = sz.height
            ctx.saveGState()
            ctx.addPath(tonguePath(sz))
            ctx.clip()
            // The curled tip: a shadow under it, then the pale underside.
            let under = CGMutablePath()
            under.move(to: CGPoint(x: w * 0.4, y: h * 0.13))
            under.addQuadCurve(to: CGPoint(x: w * 0.6, y: h * 0.13), control: CGPoint(x: w * 0.5, y: h * 0.26))
            under.addQuadCurve(to: CGPoint(x: w * 0.4, y: h * 0.13), control: CGPoint(x: w * 0.5, y: -h * 0.02))
            under.closeSubpath()
            Painter.fill(ctx, Painter.oval(CGRect(x: w * 0.4, y: 0, width: w * 0.2, height: h * 0.09)),
                         RGBA(0.05, 0.01, 0.02), 0.45)
            Painter.gradient(ctx, under, [ScenePaint.lighter(tense, 0.42), ScenePaint.lighter(tense, 0.18)], [0, 1],
                             from: CGPoint(x: 0, y: h * 0.22), to: CGPoint(x: 0, y: h * 0.04))
            Painter.stroke(ctx, under, ScenePaint.darker(tense, 0.55), width: 3, 0.8)
            ctx.restoreGState()
        }
    }

    // MARK: The satchel (bag strip) and the pouch

    /// The pouch's front (drawn over the bagged loot so it sits IN the pouch), canvas `ChestLayout.pouchRect`.
    static func pouchFrontPath() -> CGPath {
        let r = ChestLayout.pouchRect
        let m = ChestLayout.pouchMouth
        let p = CGMutablePath()
        // The mouth's front lip (the lower arc of the mouth), then the sack's body down to its rounded bottom.
        p.move(to: CGPoint(x: m.x - 52, y: m.y + 4))
        p.addCurve(to: CGPoint(x: m.x + 52, y: m.y + 4), control1: CGPoint(x: m.x - 30, y: m.y - 14),
                   control2: CGPoint(x: m.x + 30, y: m.y - 14))
        p.addCurve(to: CGPoint(x: r.maxX - 6, y: r.minY + 34), control1: CGPoint(x: m.x + 66, y: m.y - 6),
                   control2: CGPoint(x: r.maxX, y: r.minY + 62))
        p.addCurve(to: CGPoint(x: r.minX + 6, y: r.minY + 34), control1: CGPoint(x: r.maxX - 12, y: r.minY - 6),
                   control2: CGPoint(x: r.minX + 12, y: r.minY - 6))
        p.addCurve(to: CGPoint(x: m.x - 52, y: m.y + 4), control1: CGPoint(x: r.minX, y: r.minY + 62),
                   control2: CGPoint(x: m.x - 66, y: m.y - 6))
        p.closeSubpath()
        return p
    }

    static var satchel: SKTexture {
        let r = ChestLayout.bagStrip
        return make("satchel-r2", width: r.width, height: r.height + 2) { ctx, s in
            let body = Painter.roundRect(CGRect(x: 4, y: 2, width: s.width - 8, height: s.height - 8), 18)
            Painter.chunky(ctx, body, ScenePaint.leather, outline: 2.5, light: 0.12, shade: 0.35,
                           from: CGPoint(x: 0, y: s.height), to: CGPoint(x: 0, y: 0))
            ctx.saveGState()
            ctx.addPath(body)
            ctx.clip()
            Painter.grain(ctx, CGRect(x: 4, y: 2, width: s.width - 8, height: s.height - 8), alongX: true,
                          ScenePaint.leatherDark, seed: 77, count: 5)
            ctx.restoreGState()
            // Stitching.
            ctx.saveGState()
            ctx.setLineDash(phase: 0, lengths: [7, 6])
            Painter.stroke(ctx, Painter.roundRect(CGRect(x: 12, y: 9, width: s.width - 24, height: s.height - 22), 12),
                           RGBA(hex: 0xE8C48A), width: 2, 0.7)
            ctx.restoreGState()
            // The HUD plates: tooled darker leather.
            for p in [ChestLayout.bagValueRect, ChestLayout.counterRect] {
                let panel = Painter.roundRect(p, 14)
                Painter.fill(ctx, panel, ScenePaint.leatherDark, 0.92)
                Painter.stroke(ctx, panel, ScenePaint.outline, width: 2.5, 0.8)
                ctx.saveGState()
                ctx.setLineDash(phase: 0, lengths: [5, 5])
                Painter.stroke(ctx, Painter.roundRect(p.insetBy(dx: 6, dy: 6), 10), RGBA(hex: 0xC89A5E), width: 1.6, 0.6)
                ctx.restoreGState()
            }
            // The pouch's open mouth (behind the bagged loot): a dark hollow with its back rim.
            let m = ChestLayout.pouchMouth
            let mouth = Painter.oval(CGRect(x: m.x - 54, y: m.y - 16, width: 108, height: 36))
            Painter.stroke(ctx, mouth, ScenePaint.outline, width: 5, 0.95)
            Painter.fill(ctx, mouth, ScenePaint.leather)
            let hollow = Painter.oval(CGRect(x: m.x - 46, y: m.y - 12, width: 92, height: 28))
            Painter.gradient(ctx, hollow, [RGBA(hex: 0x0E0603), RGBA(hex: 0x2A160B)], [0, 1],
                             from: CGPoint(x: 0, y: m.y + 16), to: CGPoint(x: 0, y: m.y - 12))
            // The drawstring's gathered back.
            for k in 0..<7 {
                let x = m.x - 40 + CGFloat(k) * 13.3
                Painter.stroke(ctx, Painter.rect(CGRect(x: x, y: m.y + 12, width: 0.01, height: 7)),
                               ScenePaint.leatherDark, width: 2, 0.8)
            }
            // Buckled straps at the plates' inner ends.
            for x in [CGFloat(258), 412] {
                let strapR = CGRect(x: x - 5, y: 10, width: 10, height: s.height - 22)
                Painter.chunky(ctx, Painter.rect(strapR), ScenePaint.leatherDark, outline: 1, light: 0.15, shade: 0.2,
                               from: CGPoint(x: strapR.minX, y: 0), to: CGPoint(x: strapR.maxX, y: 0))
            }
        }
    }

    /// The pouch's front, over the bagged loot (pouchRect-sized texture).
    static var pouchFront: SKTexture {
        let r = ChestLayout.pouchRect
        return make("pouch-front", width: r.width, height: r.height) { ctx, _ in
            ctx.translateBy(x: -r.minX, y: -r.minY)
            let p = pouchFrontPath()
            Painter.chunky(ctx, p, ScenePaint.lighter(ScenePaint.leather, 0.08), outline: 2.6, light: 0.3, shade: 0.4,
                           from: CGPoint(x: r.minX, y: r.maxY), to: CGPoint(x: r.maxX, y: r.minY))
            ctx.saveGState()
            ctx.addPath(p)
            ctx.clip()
            Painter.grain(ctx, r, alongX: true, ScenePaint.leatherDark, seed: 88, count: 3)
            // The lip's rolled edge and the drawstring.
            let m = ChestLayout.pouchMouth
            let lip = CGMutablePath()
            lip.move(to: CGPoint(x: m.x - 52, y: m.y + 2))
            lip.addCurve(to: CGPoint(x: m.x + 52, y: m.y + 2), control1: CGPoint(x: m.x - 30, y: m.y - 16),
                         control2: CGPoint(x: m.x + 30, y: m.y - 16))
            Painter.stroke(ctx, lip, ScenePaint.lighter(ScenePaint.leather, 0.35), width: 7, 0.9)
            ctx.saveGState()
            ctx.setLineDash(phase: 0, lengths: [5, 5])
            var down = CGAffineTransform(translationX: 0, y: -12)
            if let st = lip.copy(using: &down) { Painter.stroke(ctx, st, RGBA(hex: 0xE8C48A), width: 1.8, 0.7) }
            ctx.restoreGState()
            ctx.restoreGState()
            // A brass grommet and the drawstring's knot.
            Painter.rivet(ctx, CGPoint(x: m.x, y: m.y - 22), 6, ScenePaint.brass)
            let knot = CGMutablePath()
            knot.move(to: CGPoint(x: m.x, y: m.y - 22))
            knot.addQuadCurve(to: CGPoint(x: m.x - 16, y: m.y - 52), control: CGPoint(x: m.x - 18, y: m.y - 30))
            knot.move(to: CGPoint(x: m.x, y: m.y - 22))
            knot.addQuadCurve(to: CGPoint(x: m.x + 14, y: m.y - 54), control: CGPoint(x: m.x + 20, y: m.y - 34))
            Painter.stroke(ctx, knot, ScenePaint.outline, width: 5, 0.8)
            Painter.stroke(ctx, knot, RGBA(hex: 0xD9B07A), width: 2.6, 1)
        }
    }

    // MARK: The fold: the brass hinge strip

    static var hinge: SKTexture {
        make("hinge", width: 670, height: 40) { ctx, s in
            Painter.fill(ctx, rect: CGRect(origin: .zero, size: s), RGBA(hex: 0x0E0805))
            Painter.linear(ctx, [RGBA(0.25, 0.15, 0.08, 1), RGBA(0.05, 0.03, 0.02, 1), RGBA(0.18, 0.1, 0.05, 1)],
                           [0, 0.5, 1], from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: s.height))
            for x0 in [CGFloat(96), 474] {
                let leaf = Painter.roundRect(CGRect(x: x0, y: 3, width: 100, height: 34), 5)
                Painter.chunky(ctx, leaf, ScenePaint.brass, outline: 1.6, light: 0.3, shade: 0.35,
                               from: CGPoint(x: x0, y: 37), to: CGPoint(x: x0 + 100, y: 3))
                let knuckle = CGRect(x: x0 + 4, y: 13, width: 92, height: 14)
                Painter.gradient(ctx, Painter.roundRect(knuckle, 7),
                                 [ScenePaint.brassDark, ScenePaint.brassLight, ScenePaint.brass, ScenePaint.brassDark],
                                 [0, 0.35, 0.6, 1], from: CGPoint(x: 0, y: knuckle.maxY), to: CGPoint(x: 0, y: knuckle.minY))
                Painter.stroke(ctx, Painter.roundRect(knuckle, 7), ScenePaint.outline, width: 1.6, 0.8)
                var kx = knuckle.minX + 23
                while kx < knuckle.maxX - 5 {
                    Painter.stroke(ctx, Painter.rect(CGRect(x: kx, y: knuckle.minY, width: 0.01, height: knuckle.height)),
                                   ScenePaint.brassDark, width: 1.6, 0.9)
                    kx += 23
                }
                for c in [CGPoint(x: x0 + 12, y: 8), CGPoint(x: x0 + 88, y: 8), CGPoint(x: x0 + 12, y: 32),
                          CGPoint(x: x0 + 88, y: 32)] {
                    Painter.rivet(ctx, c, 3.2, ScenePaint.brassLight)
                }
            }
        }
    }

    // MARK: The mouth: lip and fangs

    /// R3: the gum's lower edge (lip-local, y up from `lipBottom`): a lip curve, lowest at the centre, rising
    /// `gumRise` at the corners.
    /// Pure maths, so `nonisolated`: texture-drawing closures call it off the main actor (CI 40527739288).
    nonisolated static func gumEdge(_ x: CGFloat) -> CGFloat {
        let u = (x - 335) / 335
        return ChestLayout.gumRise * min(u * u, 1)
    }

    /// R3: the upper fangs: 7 across the lid (between its side borders), the 2nd and 6th long canines, one chipped.
    /// (centre x, half width, length) in lid points.
    static let fangSpec: [(x: CGFloat, half: CGFloat, len: CGFloat, chipped: Bool)] = {
        let left: CGFloat = 34, slot: CGFloat = 86
        let lens: [CGFloat] = [40, 58, 44, 47, 42, 58, 40]
        return (0..<7).map { i -> (x: CGFloat, half: CGFloat, len: CGFloat, chipped: Bool) in
            let canine = i == 1 || i == 5
            let x: CGFloat = left + slot * (CGFloat(i) + 0.5)
            let half: CGFloat = slot * (canine ? 0.46 : 0.42)
            return (x: x, half: half, len: lens[i], chipped: i == 4)
        }
    }()

    /// One pointed fang with a rounded tip (the `teethRow` curve), root at `rootY`, tip `len` below.
    static func addFang(_ p: CGMutablePath, x mid: CGFloat, half: CGFloat, rootY: CGFloat, len: CGFloat,
                        chipped: Bool) {
        let left = mid - half, right = mid + half
        p.move(to: CGPoint(x: left, y: rootY + 4))
        if chipped {
            let cut = len * 0.8
            p.addCurve(to: CGPoint(x: mid - half * 0.22, y: rootY - cut), control1: CGPoint(x: left, y: rootY - cut * 0.4),
                       control2: CGPoint(x: mid - half * 0.5, y: rootY - cut * 0.9))
            p.addLine(to: CGPoint(x: mid + half * 0.3, y: rootY - cut * 0.86))
            p.addCurve(to: CGPoint(x: right, y: rootY + 4), control1: CGPoint(x: mid + half * 0.6, y: rootY - cut * 0.7),
                       control2: CGPoint(x: right, y: rootY - cut * 0.4))
        } else {
            p.addCurve(to: CGPoint(x: mid - half * 0.14, y: rootY - len * 0.95),
                       control1: CGPoint(x: left, y: rootY - len * 0.38),
                       control2: CGPoint(x: mid - half * 0.3, y: rootY - len * 0.82))
            p.addQuadCurve(to: CGPoint(x: mid + half * 0.14, y: rootY - len * 0.95),
                           control: CGPoint(x: mid, y: rootY - len * 1.05))
            p.addCurve(to: CGPoint(x: right, y: rootY + 4), control1: CGPoint(x: mid + half * 0.3, y: rootY - len * 0.82),
                       control2: CGPoint(x: right, y: rootY - len * 0.38))
        }
        p.closeSubpath()
    }

    /// R4: the lip's top edge (lip-texture y, from the bottom of the 50 pt texture): level at the corners, `lipSag`
    /// lower at the centre. Pure maths, `nonisolated` (texture closures call it).
    nonisolated static func lipTopEdge(_ x: CGFloat, height h: CGFloat) -> CGFloat {
        let u = (x - 335) / 335
        return h - ChestLayout.lipSag * (1 - min(u * u, 1))
    }

    /// R3: the fleshy upper lip along the lid's fold edge (670 × 46). Its lower edge is a lip CURVE (lowest at the
    /// centre, rising at the corners) with a soft scallop over each fang, never a straight tube. R4 (juror: "still a
    /// straight bar"): a deeper curve (`gumRise` 14) and the TOP edge curves too (`lipSag`), with a crease and a wet
    /// highlight that follow the curve: one drawn lip line, the same at every stage.
    static var lip: SKTexture {
        make("lip-r4", width: 670, height: ChestLayout.lipHeight + 4) { ctx, s in
            // (4 pt of room under the curve for the scallops; the sprite sits 4 pt lower.)
            let h = s.height
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: lipTopEdge(0, height: h)))
            p.addLine(to: CGPoint(x: 0, y: 4 + gumEdge(0)))
            var xs: [CGFloat] = [0, 34]
            for k in 1...7 { xs.append(34 + 86 * CGFloat(k)) }
            xs.append(670)
            for i in 1..<xs.count {
                let a = xs[i - 1], b = xs[i]
                let m = (a + b) / 2
                let dip: CGFloat = (b - a) > 40 ? 5 : 2
                p.addQuadCurve(to: CGPoint(x: b, y: 4 + gumEdge(b)), control: CGPoint(x: m, y: 4 + gumEdge(m) - dip))
            }
            // The top edge back across, a smooth sag.
            var tx: CGFloat = s.width
            p.addLine(to: CGPoint(x: tx, y: lipTopEdge(tx, height: h)))
            while tx > 0 {
                tx = max(tx - 20, 0)
                p.addLine(to: CGPoint(x: tx, y: lipTopEdge(tx, height: h)))
            }
            p.closeSubpath()
            Painter.stroke(ctx, p, ScenePaint.outline, width: 5, 0.9)
            Painter.gradient(ctx, p, [ChestArt.fleshDark, ChestArt.flesh, ScenePaint.lighter(ChestArt.flesh, 0.15),
                                      ScenePaint.darker(ChestArt.fleshDark, 0.3)], [0, 0.3, 0.6, 1],
                             from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: s.height))
            // A wet highlight following the lower curve.
            let hl = CGMutablePath()
            var x: CGFloat = 40
            hl.move(to: CGPoint(x: x, y: 4 + gumEdge(x) + 12))
            while x < s.width - 40 {
                x = min(x + 30, s.width - 40)
                hl.addLine(to: CGPoint(x: x, y: 4 + gumEdge(x) + 12))
            }
            Painter.stroke(ctx, hl, RGBA(1, 0.85, 0.88), width: 2.5, 0.4)
            // The lip's upper crease, following the top curve.
            let cr = CGMutablePath()
            x = 24
            cr.move(to: CGPoint(x: x, y: lipTopEdge(x, height: h) - 8))
            while x < s.width - 24 {
                x = min(x + 30, s.width - 24)
                cr.addLine(to: CGPoint(x: x, y: lipTopEdge(x, height: h) - 8))
            }
            Painter.stroke(ctx, cr, ChestArt.fleshDark, width: 2.2, 0.6)
        }
    }

    /// The upper fangs (670 × `teethTextureHeight`, anchor at the top). Each root follows the lip curve, so when the
    /// sprite's top sits at `ChestLayout.lipBottom + gumRise + 6` every root is just behind the lip.
    static var teeth: SKTexture {
        make("fangs-r4", width: 670, height: ChestLayout.teethTextureHeight) { ctx, s in
            let p = CGMutablePath()
            for f in fangSpec {
                // Texture y of the root: 2 pt above the lip edge at this x, when fully bared.
                let rootY = s.height - (ChestLayout.gumRise + 6) + gumEdge(f.x) + 2
                addFang(p, x: f.x, half: f.half, rootY: rootY, len: f.len, chipped: f.chipped)
            }
            Painter.stroke(ctx, p, ScenePaint.outline, width: 6, 0.95)
            Painter.gradient(ctx, p, [RGBA(hex: 0xD9C7A0), ScenePaint.ivory, RGBA(hex: 0xFFFDF4)], [0, 0.55, 1],
                             from: CGPoint(x: 0, y: s.height), to: CGPoint(x: 0, y: 0))
            ctx.saveGState()
            ctx.addPath(p)
            ctx.clip()
            for f in fangSpec {
                let rootY = s.height - (ChestLayout.gumRise + 6) + gumEdge(f.x)
                Painter.fill(ctx, Painter.oval(CGRect(x: f.x - f.half * 0.55, y: rootY - f.len * 0.75, width: 6,
                                                      height: f.len * 0.5)), RGBA(1, 1, 1), 0.5)
            }
            ctx.restoreGState()
        }
    }

    /// The lower fangs for the bite: roots on a gum at the bottom, tips pointing up (670 × 72).
    static var lowerTeeth: SKTexture {
        make("lower-fangs-r2", width: 670, height: 72) { ctx, s in
            let gumR = CGRect(x: 0, y: 0, width: s.width, height: 18)
            var t = CGAffineTransform(translationX: 0, y: 14)
            let row = ChestArt.teethRow(width: s.width, height: 50, count: 8, pointingDown: false)
            let p = row.copy(using: &t) ?? row
            drawTeeth(ctx, p, rootY: 14, tipY: s.height, count: 8, width: s.width)
            Painter.chunky(ctx, Painter.roundRect(gumR, 8), ChestArt.flesh, outline: 2, light: 0.2, shade: 0.4,
                           from: CGPoint(x: 0, y: gumR.maxY), to: CGPoint(x: 0, y: 0))
        }
    }

    static func drawTeeth(_ ctx: CGContext, _ p: CGPath, rootY: CGFloat, tipY: CGFloat, count: Int, width: CGFloat) {
        Painter.stroke(ctx, p, ScenePaint.outline, width: 6, 0.95)
        Painter.gradient(ctx, p, [RGBA(hex: 0xD9C7A0), ScenePaint.ivory, RGBA(hex: 0xFFFDF4)], [0, 0.55, 1],
                         from: CGPoint(x: 0, y: rootY), to: CGPoint(x: 0, y: tipY))
        ctx.saveGState()
        ctx.addPath(p)
        ctx.clip()
        // A gloss stripe down each fang's left side.
        let n = max(count, 1)
        for i in 0..<n {
            let x = (CGFloat(i) + 0.34) * width / CGFloat(n)
            let len = abs(rootY - tipY)
            let lo = min(rootY, tipY)
            Painter.fill(ctx, Painter.oval(CGRect(x: x - 3, y: lo + len * 0.3, width: 6, height: len * 0.5)),
                         RGBA(1, 1, 1), 0.5)
        }
        ctx.restoreGState()
    }

    // MARK: Small brass and HUD pieces

    /// The brass name plate (no text: the name and the trait/tier sub-line sit on it).
    static var plate: SKTexture {
        let s = ChestLayout.plateSize
        return make("plate-r2", width: s.width, height: s.height) { ctx, sz in
            let body = Painter.roundRect(CGRect(x: 3, y: 3, width: sz.width - 6, height: sz.height - 6), 14)
            Painter.chunky(ctx, body, ScenePaint.brass, outline: 2, light: 0.45, shade: 0.35,
                           from: CGPoint(x: 0, y: sz.height), to: CGPoint(x: 0, y: 0))
            Painter.stroke(ctx, Painter.roundRect(CGRect(x: 10, y: 9, width: sz.width - 20, height: sz.height - 18), 9),
                           ScenePaint.brassDark, width: 2, 0.8)
            // The engraved rule between the name and the sub-line.
            Painter.stroke(ctx, Painter.rect(CGRect(x: 60, y: sz.height * 0.44, width: sz.width - 120, height: 0.01)),
                           ScenePaint.brassDark, width: 1.4, 0.5)
            Painter.rivet(ctx, CGPoint(x: 22, y: sz.height / 2), 5, ScenePaint.brassLight)
            Painter.rivet(ctx, CGPoint(x: sz.width - 22, y: sz.height / 2), 5, ScenePaint.brassLight)
        }
    }

    /// One half of the brass brow plate over the eye (the LEFT half: its inner end at the texture's right edge).
    static var browHalf: SKTexture {
        let s = ChestLayout.browHalf
        return make("brow-half", width: s.width + 6, height: s.height + 6) { ctx, sz in
            let p = CGMutablePath()
            let h = sz.height
            p.move(to: CGPoint(x: sz.width - 2, y: h - 3))
            p.addLine(to: CGPoint(x: 14, y: h - 7))
            p.addQuadCurve(to: CGPoint(x: 14, y: 9), control: CGPoint(x: 2, y: h / 2))
            p.addLine(to: CGPoint(x: sz.width - 2, y: 3))
            p.closeSubpath()
            Painter.chunky(ctx, p, ScenePaint.brass, outline: 2, light: 0.5, shade: 0.45,
                           from: CGPoint(x: 0, y: h), to: CGPoint(x: 0, y: 0))
            Painter.stroke(ctx, Painter.rect(CGRect(x: 22, y: h / 2, width: sz.width - 30, height: 0.01)),
                           ScenePaint.brassDark, width: 1.6, 0.6)
            Painter.rivet(ctx, CGPoint(x: 18, y: h / 2), 4, ScenePaint.brassLight)
            Painter.rivet(ctx, CGPoint(x: sz.width * 0.55, y: h / 2), 3, ScenePaint.brassLight)
        }
    }

    /// The noise meter's plate: brass, a recess for "NOISE", the dark segment well, stage notches, and the teeth at
    /// the full end (where it bites).
    /// R3: the meter plate's shape in white (tint it: the slam's red flash).
    static var meterFlash: SKTexture {
        let m = ChestLayout.meterRect
        return make("meter-flash-r11", width: m.width, height: m.height) { ctx, s in
            Painter.fill(ctx, Painter.roundRect(CGRect(origin: .zero, size: s).insetBy(dx: 1.5, dy: 1.5), s.height / 2),
                         RGBA(1, 1, 1))
        }
    }

    static var meterPlate: SKTexture {
        let m = ChestLayout.meterRect
        return make("meter-plate-r11", width: m.width, height: m.height) { ctx, s in
            let body = Painter.roundRect(CGRect(origin: .zero, size: s).insetBy(dx: 1.5, dy: 1.5), s.height / 2)
            Painter.chunky(ctx, body, ScenePaint.brass, outline: 1.5, light: 0.4, shade: 0.4,
                           from: CGPoint(x: 0, y: s.height), to: CGPoint(x: 0, y: 0))
            // The label's recess (R11: 74 wide, clear of the well that now starts at x 140).
            let lc = CGPoint(x: ChestLayout.meterLabelCenter.x - m.minX, y: ChestLayout.meterLabelCenter.y - m.minY)
            Painter.fill(ctx, Painter.roundRect(CGRect(x: lc.x - 37, y: 5, width: 74, height: s.height - 10), 8),
                         ScenePaint.brassLight, 0.55)
            let well = ChestLayout.meterWell.offsetBy(dx: -m.minX, dy: -m.minY)
            Painter.fill(ctx, Painter.roundRect(well.insetBy(dx: -2, dy: -2), 6), RGBA(hex: 0x120A06), 1)
            // Stage notches at 0.35 and 0.70.
            for f in [CGFloat(0.35), 0.70] {
                let x = well.minX + well.width * f
                Painter.fill(ctx, Painter.polygon([CGPoint(x: x - 4, y: s.height), CGPoint(x: x + 4, y: s.height),
                                                   CGPoint(x: x, y: well.maxY - 1)]), ScenePaint.outline, 0.9)
                Painter.fill(ctx, Painter.polygon([CGPoint(x: x - 4, y: 0), CGPoint(x: x + 4, y: 0),
                                                   CGPoint(x: x, y: well.minY + 1)]), ScenePaint.outline, 0.9)
            }
            // The teeth: a little red mouth with fangs top and bottom.
            let tc = CGPoint(x: ChestLayout.meterTeethCenter.x - m.minX, y: ChestLayout.meterTeethCenter.y - m.minY)
            let mouth = Painter.roundRect(CGRect(x: tc.x - 20, y: tc.y - 11, width: 40, height: 22), 9)
            Painter.stroke(ctx, mouth, ScenePaint.outline, width: 3, 0.95)
            Painter.fill(ctx, mouth, RGBA(hex: 0x7A0E1C))
            var up = CGAffineTransform(translationX: tc.x - 17, y: tc.y + 10)
            let topRow = ChestArt.teethRow(width: 34, height: 9, count: 4, pointingDown: true)
            if let t1 = topRow.copy(using: &up) {
                Painter.stroke(ctx, t1, ScenePaint.outline, width: 1.6, 0.9)
                Painter.fill(ctx, t1, ScenePaint.ivory)
            }
            var dn = CGAffineTransform(translationX: tc.x - 15, y: tc.y - 10)
            let botRow = ChestArt.teethRow(width: 30, height: 7, count: 4, pointingDown: false)
            if let t2 = botRow.copy(using: &dn) {
                Painter.stroke(ctx, t2, ScenePaint.outline, width: 1.6, 0.9)
                Painter.fill(ctx, t2, ScenePaint.ivory)
            }
        }
    }

    /// The candle's track on the left rim (a dark slot with a brass edge).
    static var torchTrack: SKTexture {
        let r = ChestLayout.torchRect
        return make("torch-track", width: r.width, height: r.height) { ctx, s in
            let p = Painter.roundRect(CGRect(origin: .zero, size: s).insetBy(dx: 2, dy: 2), 12)
            Painter.fill(ctx, p, RGBA(hex: 0x140B06), 0.85)
            Painter.stroke(ctx, p, ScenePaint.brassDark, width: 3, 1)
            Painter.stroke(ctx, p.copy(strokingWithWidth: 0.01, lineCap: .round, lineJoin: .round, miterLimit: 1),
                           ScenePaint.outline, width: 1, 0.5)
        }
    }

    /// A wax candle column (anchor it at the bottom; scale y to burn it down).
    static var wax: SKTexture {
        make("wax", width: 24, height: 214) { ctx, s in
            let body = CGMutablePath()
            body.move(to: CGPoint(x: 2, y: 0))
            body.addLine(to: CGPoint(x: 2, y: s.height - 10))
            body.addQuadCurve(to: CGPoint(x: 9, y: s.height - 4), control: CGPoint(x: 4, y: s.height))
            body.addQuadCurve(to: CGPoint(x: 16, y: s.height - 6), control: CGPoint(x: 12, y: s.height - 10))
            body.addQuadCurve(to: CGPoint(x: 22, y: s.height - 9), control: CGPoint(x: 20, y: s.height))
            body.addLine(to: CGPoint(x: 22, y: 0))
            body.closeSubpath()
            Painter.gradient(ctx, body, [RGBA(hex: 0xC9B48A), RGBA(hex: 0xFFF4DA), RGBA(hex: 0xE8D6AE),
                                         RGBA(hex: 0xA8916A)], [0, 0.35, 0.6, 1],
                             from: CGPoint(x: 0, y: 0), to: CGPoint(x: s.width, y: 0))
            // Drips.
            for (x, len) in [(CGFloat(5), CGFloat(26)), (16, 40)] {
                Painter.fill(ctx, Painter.roundRect(CGRect(x: x - 2.5, y: s.height - 8 - len, width: 5, height: len), 2.5),
                             RGBA(hex: 0xFFF8E6), 0.9)
            }
        }
    }

    /// The candle's brass dish.
    static var candleDish: SKTexture {
        make("candle-dish", width: 44, height: 22) { ctx, s in
            let dish = Painter.oval(CGRect(x: 2, y: 2, width: s.width - 4, height: s.height - 6))
            Painter.chunky(ctx, dish, ScenePaint.brass, outline: 1.5, light: 0.45, shade: 0.4,
                           from: CGPoint(x: 0, y: s.height), to: CGPoint(x: 0, y: 0))
            Painter.fill(ctx, Painter.oval(CGRect(x: 10, y: 9, width: s.width - 20, height: 7)), ScenePaint.brassDark, 0.8)
        }
    }

    /// A candle flame (white-hot core, orange edge). Anchor it at its base.
    static var flame: SKTexture {
        make("flame", width: 30, height: 48) { ctx, s in
            func drop(_ w: CGFloat, _ h: CGFloat) -> CGPath {
                let p = CGMutablePath()
                let cx = s.width / 2
                p.move(to: CGPoint(x: cx, y: 2))
                p.addCurve(to: CGPoint(x: cx, y: 2 + h), control1: CGPoint(x: cx + w, y: 2),
                           control2: CGPoint(x: cx + w * 0.2, y: 2 + h * 0.6))
                p.addCurve(to: CGPoint(x: cx, y: 2), control1: CGPoint(x: cx - w * 0.2, y: 2 + h * 0.6),
                           control2: CGPoint(x: cx - w, y: 2))
                p.closeSubpath()
                return p
            }
            Painter.fill(ctx, drop(14, 44), RGBA(hex: 0xFF8A1E), 0.9)
            Painter.fill(ctx, drop(10, 32), RGBA(hex: 0xFFC94A), 1)
            Painter.fill(ctx, drop(5.5, 18), RGBA(hex: 0xFFF6D8), 1)
        }
    }

    /// The brass clasp on the IN BAG plate (the shut-hold ring goes round it), with a little sack on it.
    static var clasp: SKTexture {
        make("clasp", width: 68, height: 68) { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            let disk = Painter.circle(c, 29)
            Painter.chunky(ctx, disk, ScenePaint.brass, outline: 2, light: 0.45, shade: 0.4,
                           from: CGPoint(x: c.x - 29, y: c.y + 29), to: CGPoint(x: c.x + 29, y: c.y - 29))
            Painter.stroke(ctx, Painter.circle(c, 23), ScenePaint.brassDark, width: 2, 0.8)
            let sack = CGMutablePath()
            sack.move(to: CGPoint(x: c.x - 7, y: c.y + 8))
            sack.addCurve(to: CGPoint(x: c.x, y: c.y - 15), control1: CGPoint(x: c.x - 22, y: c.y - 2),
                          control2: CGPoint(x: c.x - 16, y: c.y - 15))
            sack.addCurve(to: CGPoint(x: c.x + 7, y: c.y + 8), control1: CGPoint(x: c.x + 16, y: c.y - 15),
                          control2: CGPoint(x: c.x + 22, y: c.y - 2))
            sack.closeSubpath()
            Painter.chunky(ctx, sack, ScenePaint.leather, outline: 1.6, light: 0.3, shade: 0.3,
                           from: CGPoint(x: c.x - 10, y: c.y + 8), to: CGPoint(x: c.x + 10, y: c.y - 15))
            let tie = Painter.polygon([CGPoint(x: c.x - 9, y: c.y + 14), CGPoint(x: c.x + 9, y: c.y + 14),
                                       CGPoint(x: c.x + 5, y: c.y + 7), CGPoint(x: c.x - 5, y: c.y + 7)])
            Painter.chunky(ctx, tie, ScenePaint.leather, outline: 1.4, from: CGPoint(x: 0, y: c.y + 14),
                           to: CGPoint(x: 0, y: c.y + 7))
            Painter.fill(ctx, Painter.circle(CGPoint(x: c.x, y: c.y - 5), 3.2), ChestArt.palette.gold)
        }
    }

    /// The BANKED icon: a little stack of the gold coins (same disc as the loot).
    static var coinStack: SKTexture {
        make("coin-stack-r2", width: 52, height: 52) { ctx, s in
            let fill = ChestArt.lootColors(.copper)
            for (i, y) in [CGFloat(8), 16, 24].enumerated() {
                let r = CGRect(x: 7 + CGFloat(i % 2) * 2, y: y, width: 36, height: 15)
                // The coin's edge, then its face.
                let edge = Painter.roundRect(CGRect(x: r.minX, y: r.minY - 3, width: r.width, height: r.height), 7)
                Painter.stroke(ctx, edge, ScenePaint.outline, width: 3, 0.9)
                Painter.fill(ctx, edge, fill.rim)
                let p = Painter.oval(r)
                Painter.chunky(ctx, p, fill.fill, outline: 1.5, light: 0.4, shade: 0.3,
                               from: CGPoint(x: r.minX, y: r.maxY), to: CGPoint(x: r.maxX, y: r.minY))
                Painter.stroke(ctx, Painter.oval(r.insetBy(dx: 6, dy: 2.5)), fill.rim, width: 1.4, 0.8)
            }
            Painter.fill(ctx, Painter.oval(CGRect(x: 15, y: 33, width: 10, height: 3)), RGBA(1, 1, 1), 0.85)
            _ = s
        }
    }

    /// The Hush Chain medallion (a brass disc with two linked rings embossed; the multiplier sits on it).
    static var chainMedallion: SKTexture {
        make("chain-medallion-r3", width: 64, height: 64) { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            let d = Painter.circle(c, 28)
            Painter.chunky(ctx, d, ScenePaint.brass, outline: 2.2, light: 0.5, shade: 0.45,
                           from: CGPoint(x: c.x - 28, y: c.y + 28), to: CGPoint(x: c.x + 28, y: c.y - 28))
            Painter.fill(ctx, Painter.circle(c, 21), RGBA(hex: 0x2A1A0C), 0.92)
            // R3: the linked rings read at a glance (the number is beside the medallion now, not on it).
            for (dx, a) in [(CGFloat(-7), CGFloat(0.45)), (7, -0.45)] {
                let ring = CGMutablePath()
                ArtPrim.oval(ring, CGRect(x: -11, y: -7, width: 22, height: 14))
                var t = CGAffineTransform(translationX: c.x + dx, y: c.y).rotated(by: a)
                let placed = ring.copy(using: &t) ?? ring
                Painter.stroke(ctx, placed, ScenePaint.outline, width: 6, 0.9)
                Painter.stroke(ctx, placed, ScenePaint.brassLight, width: 3.2, 1)
            }
            Painter.stroke(ctx, Painter.circle(c, 21), ScenePaint.brassDark, width: 2, 0.9)
        }
    }

    /// A jagged crack across the medallion (the chain breaking).
    static var chainCrack: SKTexture {
        make("chain-crack", width: 64, height: 64) { ctx, s in
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 10, y: 50))
            for q in [CGPoint(x: 22, y: 38), CGPoint(x: 28, y: 42), CGPoint(x: 34, y: 28), CGPoint(x: 40, y: 32),
                      CGPoint(x: 54, y: 12)] {
                p.addLine(to: q)
            }
            p.move(to: CGPoint(x: 34, y: 28))
            p.addLine(to: CGPoint(x: 30, y: 14))
            Painter.stroke(ctx, p, ScenePaint.outline, width: 4.5, 1)
            Painter.stroke(ctx, p, RGBA(1, 0.95, 0.85), width: 1.5, 0.9)
            _ = s
        }
    }

    /// A dark rounded backing for the candle countdown.
    static var countdownPill: SKTexture {
        let r = ChestLayout.countdownRect
        return make("countdown-pill", width: r.width, height: r.height) { ctx, s in
            let p = Painter.roundRect(CGRect(origin: .zero, size: s).insetBy(dx: 2, dy: 2), s.height / 2 - 2)
            Painter.fill(ctx, p, RGBA(hex: 0x120805), 0.82)
            Painter.stroke(ctx, p, ScenePaint.brassDark, width: 2.5, 0.95)
        }
    }

    /// The lid slider's track (no hinge): a dark slot in a brass frame with ticks.
    static var sliderTrack: SKTexture {
        let h = ChestLayout.sliderMaxY - ChestLayout.sliderMinY + 40
        let w = ChestLayout.sliderTrackWidth
        return make("slider-track-r3", width: w, height: h) { ctx, s in
            // R3: a recessed brass channel in the lid's right edge band (shorter, narrower).
            let frame = Painter.roundRect(CGRect(origin: .zero, size: s).insetBy(dx: 2.5, dy: 2.5), s.width / 2 - 2.5)
            Painter.chunky(ctx, frame, ScenePaint.brass, outline: 2, light: 0.35, shade: 0.4,
                           from: CGPoint(x: 0, y: 0), to: CGPoint(x: s.width, y: 0))
            let slot = Painter.roundRect(CGRect(x: s.width / 2 - 6, y: 14, width: 12, height: s.height - 28), 6)
            Painter.fill(ctx, slot, RGBA(hex: 0x120A06), 1)
            var y: CGFloat = 30
            while y < s.height - 24 {
                Painter.stroke(ctx, Painter.rect(CGRect(x: 5, y: y, width: 5, height: 0.01)), ScenePaint.brassDark,
                               width: 2, 0.9)
                Painter.stroke(ctx, Painter.rect(CGRect(x: s.width - 10, y: y, width: 5, height: 0.01)),
                               ScenePaint.brassDark, width: 2, 0.9)
                y += 38
            }
        }
    }

    /// The lid slider's knob: a brass lever handle (R3: compact, inside the right edge band).
    static var sliderKnob: SKTexture {
        let k = ChestLayout.sliderKnobSize
        return make("slider-knob-r3", width: k.width, height: k.height) { ctx, s in
            let bar = Painter.roundRect(CGRect(x: 3, y: 9, width: s.width - 6, height: s.height - 18), (s.height - 18) / 2)
            Painter.chunky(ctx, bar, ScenePaint.brass, outline: 2.2, light: 0.5, shade: 0.4,
                           from: CGPoint(x: 0, y: s.height - 9), to: CGPoint(x: 0, y: 9))
            for dx in [CGFloat(-18), -12, 12, 18] {
                Painter.stroke(ctx, Painter.rect(CGRect(x: s.width / 2 + dx, y: 15, width: 0.01, height: s.height - 30)),
                               ScenePaint.brassDark, width: 2.2, 0.9)
            }
            Painter.rivet(ctx, CGPoint(x: s.width / 2, y: s.height / 2), 7, ScenePaint.brassLight)
        }
    }

    /// R3: an in-world plate (`ChestArt.drawPlate`) as a texture (the chain tab, the relic card).
    static func plateTexture(size: CGSize, style: PlateStyle) -> SKTexture {
        let w = max(size.width.rounded(), 8), h = max(size.height.rounded(), 8)
        return make("plate-\(style.rawValue)-\(Int(w))x\(Int(h))", width: w, height: h) { ctx, s in
            ChestArt.drawPlate(ctx, size: s, style: style)
        }
    }

    /// R4 (juror P1-2): the pause coin's seat: a round brass ring with four little rivets round a dark recess the
    /// coin sits in (no square boss plate, nothing that reads as a corner bracket). 120 × 120, drawn at any size
    /// (`ChestLayout.pauseSeatRadius(viewScale:)`): the recess is the coin's radius, the ring the 4 pt round it.
    static var pauseSeat: SKTexture {
        make("pause-seat-r4", width: 120, height: 120, scale: 3) { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            let outer = s.width / 2 - 1.5
            // The coin's radius as a share of the seat's (27.5 of 31.5 at any scale).
            let coinR = ChestLayout.pauseCoinViewDiameter / 2
            let k = coinR / (coinR + ChestLayout.pauseSeatViewRing)
            let inner = outer * k
            // A soft contact shadow, the ring, then the recess.
            Painter.radial(ctx, [RGBA(0, 0, 0, 0.45), RGBA(0, 0, 0, 0)], [0.8, 1], center: CGPoint(x: c.x + 1, y: c.y - 2),
                           radius: outer + 1.5)
            let ring = Painter.circle(c, outer)
            Painter.chunky(ctx, ring, ScenePaint.brass, outline: 2.4, light: 0.45, shade: 0.45,
                           from: CGPoint(x: c.x - outer, y: c.y + outer), to: CGPoint(x: c.x + outer, y: c.y - outer))
            let rr = (outer + inner) / 2
            let rivetR = max((outer - inner) * 0.22, 1.2)
            for i in 0..<4 {
                let a = CGFloat(i) * .pi / 2 + .pi / 4
                Painter.rivet(ctx, CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr), rivetR, ScenePaint.brassLight)
            }
            let recess = Painter.circle(c, inner)
            Painter.fill(ctx, recess, RGBA(hex: 0x1A0F08))
            ctx.saveGState()
            ctx.addPath(recess)
            ctx.clip()
            Painter.linear(ctx, [RGBA(0, 0, 0, 0.7), RGBA(0, 0, 0, 0)], [0, 1], from: CGPoint(x: c.x, y: c.y + inner),
                           to: CGPoint(x: c.x, y: c.y - inner * 0.2))
            ctx.restoreGState()
            Painter.stroke(ctx, recess, ScenePaint.outline, width: 2, 0.9)
        }
    }

    /// R4 (tester 8: "empty wood panel"): the carved plaque in the lid's extension on phones: a recessed dark panel
    /// cut into the planks with a thin brass rim and two rivets; the chest's tier and number are engraved on it.
    static var lidPlaque: SKTexture {
        let sz = ChestLayout.plaqueSize
        return make("lid-plaque-r4", width: sz.width, height: sz.height, scale: 3) { ctx, s in
            let r = CGRect(x: 3, y: 3, width: s.width - 6, height: s.height - 6)
            let body = Painter.roundRect(r, 12)
            Painter.stroke(ctx, body, ScenePaint.outline, width: 4, 0.85)
            Painter.chunky(ctx, body, ScenePaint.brassDark, outline: 1.2, light: 0.35, shade: 0.4,
                           from: CGPoint(x: r.minX, y: r.maxY), to: CGPoint(x: r.maxX, y: r.minY))
            let well = r.insetBy(dx: 7, dy: 6)
            let wellPath = Painter.roundRect(well, 8)
            Painter.gradient(ctx, wellPath, [RGBA(hex: 0x1C0E06), RGBA(hex: 0x2E1A0E), RGBA(hex: 0x3A2414)], [0, 0.5, 1],
                             from: CGPoint(x: 0, y: well.maxY), to: CGPoint(x: 0, y: well.minY))
            ctx.saveGState()
            ctx.addPath(wellPath)
            ctx.clip()
            // The carved edge: dark at the top (in shadow), lit along the bottom.
            Painter.linear(ctx, [RGBA(0, 0, 0, 0.55), RGBA(0, 0, 0, 0)], [0, 1], from: CGPoint(x: 0, y: well.maxY),
                           to: CGPoint(x: 0, y: well.maxY - 10))
            Painter.stroke(ctx, Painter.rect(CGRect(x: well.minX, y: well.minY + 1, width: well.width, height: 0.01)),
                           ScenePaint.brassLight, width: 1.4, 0.35)
            ctx.restoreGState()
            Painter.stroke(ctx, wellPath, ScenePaint.outline, width: 1.6, 0.8)
            for x in [r.minX + 12, r.maxX - 12] {
                Painter.rivet(ctx, CGPoint(x: x, y: r.midY), 3.4, ScenePaint.brassLight)
            }
        }
    }

    /// R3: the gold-multiplier seal on the name plate's left end (a milled brass coin; brighter for the golden
    /// mimic).
    static func plateSeal(golden: Bool) -> SKTexture {
        let d = ChestLayout.sealRadius * 2 + 6
        return make("plate-seal-\(golden)", width: d, height: d) { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            let r = ChestLayout.sealRadius
            let metal = golden ? RGBA(hex: 0xFFD45A) : ScenePaint.brass
            // A milled edge.
            let milled = CGMutablePath()
            for i in 0..<28 {
                let a = CGFloat(i) / 28 * 2 * .pi
                let p = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                milled.addEllipse(in: CGRect(x: p.x - 2.6, y: p.y - 2.6, width: 5.2, height: 5.2))
            }
            Painter.fill(ctx, milled, ScenePaint.outline, 0.9)
            let disk = Painter.circle(c, r - 1)
            Painter.chunky(ctx, disk, metal, outline: 1.8, light: 0.5, shade: 0.45,
                           from: CGPoint(x: c.x - r, y: c.y + r), to: CGPoint(x: c.x + r, y: c.y - r))
            Painter.stroke(ctx, Painter.circle(c, r - 6), ScenePaint.brassDark, width: 1.6, 0.8)
            if golden {
                Painter.radial(ctx, [RGBA(1, 1, 0.9, 0.55), RGBA(1, 1, 0.9, 0)], [0, 1],
                               center: CGPoint(x: c.x - r * 0.35, y: c.y + r * 0.35), radius: r * 0.7)
            }
        }
    }

    /// R3: the golden mimic's name plate (bright gold leaf, emerald studs): "GOLDEN" reads before the words do.
    static var plateGolden: SKTexture {
        let s = ChestLayout.plateSize
        return make("plate-golden-r3", width: s.width, height: s.height) { ctx, sz in
            let body = Painter.roundRect(CGRect(x: 3, y: 3, width: sz.width - 6, height: sz.height - 6), 14)
            Painter.chunky(ctx, body, RGBA(hex: 0xFFD45A), outline: 2, light: 0.55, shade: 0.3,
                           from: CGPoint(x: 0, y: sz.height), to: CGPoint(x: 0, y: 0))
            goldLeaf(ctx, CGRect(x: 6, y: 6, width: sz.width - 12, height: sz.height - 12), seed: 91)
            Painter.stroke(ctx, Painter.roundRect(CGRect(x: 10, y: 9, width: sz.width - 20, height: sz.height - 18), 9),
                           RGBA(hex: 0x9A6A10), width: 2.2, 0.85)
            Painter.stroke(ctx, Painter.rect(CGRect(x: 60, y: sz.height * 0.44, width: sz.width - 120, height: 0.01)),
                           RGBA(hex: 0x9A6A10), width: 1.4, 0.5)
            gemStud(ctx, CGPoint(x: 22, y: sz.height / 2), RGBA(hex: 0x2CC67C), size: 7)
            gemStud(ctx, CGPoint(x: sz.width - 22, y: sz.height / 2), RGBA(hex: 0x2CC67C), size: 7)
        }
    }

    /// An up-chevron on the slider track (a hint while the lid is shut and the bag is empty).
    static var chevron: SKTexture {
        make("chevron", width: 40, height: 26) { ctx, s in
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 6, y: 6))
            p.addLine(to: CGPoint(x: s.width / 2, y: s.height - 6))
            p.addLine(to: CGPoint(x: s.width - 6, y: 6))
            Painter.stroke(ctx, p, ScenePaint.outline, width: 9, 0.8)
            Painter.stroke(ctx, p, ChestArt.palette.candle, width: 5, 1)
        }
    }

    // MARK: The eye

    /// The iris (gold-amber, fibres, dark rim), sized to `ChestLayout.eyeRadius × 0.6`.
    static var iris: SKTexture {
        let r = ceil(ChestLayout.eyeRadius * 0.6)
        return make("iris", width: 2 * r + 4, height: 2 * r + 4) { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            Painter.radial(ctx, [RGBA(hex: 0xFFE98A), RGBA(hex: 0xF0B02E), RGBA(hex: 0xB86A14), RGBA(hex: 0x5A3008)],
                           [0, 0.35, 0.78, 1], center: c, radius: r)
            for k in 0..<28 {
                let a = CGFloat(k) / 28 * 2 * .pi
                let p = CGMutablePath()
                p.move(to: CGPoint(x: c.x + cos(a) * r * 0.3, y: c.y + sin(a) * r * 0.3))
                p.addLine(to: CGPoint(x: c.x + cos(a + 0.05) * r * 0.9, y: c.y + sin(a + 0.05) * r * 0.9))
                Painter.stroke(ctx, p, RGBA(hex: 0x7A4A0C), width: 1.4, 0.35)
            }
            Painter.stroke(ctx, Painter.circle(c, r - 1.5), ScenePaint.outline, width: 3.5, 0.9)
        }
    }

    static var irisSide: CGFloat { ceil(ChestLayout.eyeRadius * 0.6) * 2 + 4 }

    /// The pupil: a cat-like vertical slit (scale x to narrow it).
    static var pupil: SKTexture {
        make("pupil", width: 26, height: 76) { ctx, s in
            let p = CGMutablePath()
            p.move(to: CGPoint(x: s.width / 2, y: 1))
            p.addCurve(to: CGPoint(x: s.width / 2, y: s.height - 1), control1: CGPoint(x: s.width - 1, y: s.height * 0.3),
                       control2: CGPoint(x: s.width - 1, y: s.height * 0.7))
            p.addCurve(to: CGPoint(x: s.width / 2, y: 1), control1: CGPoint(x: 1, y: s.height * 0.7),
                       control2: CGPoint(x: 1, y: s.height * 0.3))
            p.closeSubpath()
            Painter.fill(ctx, p, RGBA(hex: 0x120604))
        }
    }
}

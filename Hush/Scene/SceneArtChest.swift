import SpriteKit
import UIKit

/// How each chest tier is dressed (GAME-DESIGN §6: wooden → iron-bound → gilded → royal, visibly richer).
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
    /// Set gems and the lid crest.
    let gems: Bool

    static func of(_ tier: ChestTier) -> TierStyle {
        switch tier {
        case .wooden:
            return TierStyle(wood: RGBA(hex: 0x8A5A33), woodDark: RGBA(hex: 0x4A2C18), band: RGBA(hex: 0x5E6873),
                             stud: RGBA(hex: 0xA3ACB6), velvet: RGBA(hex: 0x5C1A33), tuft: RGBA(hex: 0x3A0E20),
                             bands: false, gilt: false, gems: false)
        case .iron:
            return TierStyle(wood: RGBA(hex: 0x74503A), woodDark: RGBA(hex: 0x3A2414), band: RGBA(hex: 0x4E5862),
                             stud: RGBA(hex: 0xB4BDC7), velvet: RGBA(hex: 0x40264A), tuft: RGBA(hex: 0x28142E),
                             bands: true, gilt: false, gems: false)
        case .gilded:
            return TierStyle(wood: RGBA(hex: 0x7E4628), woodDark: RGBA(hex: 0x40200F), band: RGBA(hex: 0xE3AC3A),
                             stud: RGBA(hex: 0xFFE08A), velvet: RGBA(hex: 0x701832), tuft: RGBA(hex: 0x480E20),
                             bands: true, gilt: true, gems: false)
        case .royal:
            return TierStyle(wood: RGBA(hex: 0x6A2230), woodDark: RGBA(hex: 0x320C16), band: RGBA(hex: 0xFFC94A),
                             stud: RGBA(hex: 0xFFF0B4), velvet: RGBA(hex: 0x4C1C62), tuft: RGBA(hex: 0x2E0C3C),
                             bands: true, gilt: true, gems: true)
        }
    }
}

extension SceneTextures {
    // MARK: The floor: chest walls and bed

    /// The chest seen from above (canvas `ChestLayout.frameRect`): rims, inner wall faces, the velvet bed, metalwork.
    static func chestFrame(_ tier: ChestTier) -> SKTexture {
        let fr = ChestLayout.frameRect
        return make("frame-\(tier.rawValue)", width: fr.width, height: fr.height) { ctx, _ in
            // Draw in canvas coordinates.
            ctx.translateBy(x: -fr.minX, y: -fr.minY)
            drawChestFrame(ctx, TierStyle.of(tier))
        }
    }

    private static func drawChestFrame(_ ctx: CGContext, _ st: TierStyle) {
        let fr = ChestLayout.frameRect
        let rim = ChestLayout.rimInner
        let bed = ChestLayout.interior
        let lit = ScenePaint.lighter(st.wood, 0.12)
        Painter.fill(ctx, rect: fr, st.woodDark)

        // The rims' top surfaces (lit by the player's torch).
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
            for c in [CGPoint(x: bed.minX + 4, y: bed.minY + 4), CGPoint(x: bed.maxX - 4, y: bed.minY + 4),
                      CGPoint(x: bed.minX + 4, y: bed.maxY - 4), CGPoint(x: bed.maxX - 4, y: bed.maxY - 4)] {
                filigree(ctx, c, toward: CGPoint(x: bed.midX, y: bed.midY), st.band)
            }
        }
        if st.gems {
            gemStud(ctx, CGPoint(x: rim.minX / 2, y: 280), RGBA(hex: 0xEC3352))
            gemStud(ctx, CGPoint(x: (rim.maxX + fr.maxX) / 2, y: 280), RGBA(hex: 0x3C7CEE))
            gemStud(ctx, CGPoint(x: 120, y: rim.maxY + 6), RGBA(hex: 0x2CC67C))
            gemStud(ctx, CGPoint(x: 550, y: rim.maxY + 6), RGBA(hex: 0xA95CE4))
        }
        // Studs along the side rims.
        var sy = fr.minY + 46
        while sy < fr.maxY - 16 {
            if !(st.bands && (abs(sy - 217) < 20 || abs(sy - 363) < 20)) && !(st.gems && abs(sy - 280) < 20) {
                Painter.rivet(ctx, CGPoint(x: 12, y: sy), 3.6, st.stud)
                Painter.rivet(ctx, CGPoint(x: fr.maxX - 12, y: sy), 3.6, st.stud)
            }
            sy += 44
        }
    }

    private static func strap(_ ctx: CGContext, _ r: CGRect, _ st: TierStyle) {
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

    private static func drawCornerBrackets(_ ctx: CGContext, _ st: TierStyle, frame fr: CGRect, rim: CGRect) {
        let metal = st.gilt ? st.band : RGBA(hex: 0x5E6873)
        let arm: CGFloat = 76
        let corners: [(CGPoint, CGFloat, CGFloat)] = [(CGPoint(x: fr.minX, y: fr.minY), 1, 1),
                                                       (CGPoint(x: fr.maxX, y: fr.minY), -1, 1),
                                                       (CGPoint(x: fr.minX, y: fr.maxY), 1, -1),
                                                       (CGPoint(x: fr.maxX, y: fr.maxY), -1, -1)]
        for (c, sx, sy) in corners {
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

    private static func gemStud(_ ctx: CGContext, _ c: CGPoint, _ color: RGBA) {
        Painter.rivet(ctx, c, 12, RGBA(hex: 0xFFC94A))
        let g = Painter.circle(c, 8)
        Painter.stroke(ctx, g, ScenePaint.outline, width: 2, 0.8)
        Painter.radial(ctx, [ScenePaint.lighter(color, 0.6), color, ScenePaint.darker(color, 0.4)], [0, 0.4, 1],
                       center: CGPoint(x: c.x - 2, y: c.y + 2), radius: 9)
        Painter.fill(ctx, Painter.circle(CGPoint(x: c.x - 3, y: c.y + 3), 2.2), RGBA(1, 1, 1), 0.85)
    }

    // MARK: The tongue (the mimic's tell, on the bed)

    static let tongueSize = CGSize(width: 460, height: 282)

    private static func tonguePath(_ s: CGSize) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: s.width * 0.065, y: s.height))
        p.addCurve(to: CGPoint(x: s.width * 0.5, y: 6), control1: CGPoint(x: -s.width * 0.01, y: s.height * 0.52),
                   control2: CGPoint(x: s.width * 0.2, y: 6))
        p.addCurve(to: CGPoint(x: s.width * 0.935, y: s.height), control1: CGPoint(x: s.width * 0.8, y: 6),
                   control2: CGPoint(x: s.width * 1.01, y: s.height * 0.52))
        p.closeSubpath()
        return p
    }

    /// The velvet tongue lying on the bed: root at the top (the throat at the hinge), tip toward the player.
    static var tongue: SKTexture {
        let s = tongueSize
        return make("tongue", width: s.width, height: s.height) { ctx, sz in
            let t = ChestArt.palette.tongue
            let path = tonguePath(sz)
            Painter.stroke(ctx, path, ScenePaint.darker(t, 0.6), width: 8, 0.95)
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            Painter.radial(ctx, [ScenePaint.lighter(t, 0.16), t, ScenePaint.darker(t, 0.32)], [0, 0.55, 1],
                           center: CGPoint(x: sz.width / 2, y: sz.height * 0.55), radius: sz.width * 0.56, extend: true)
            // Velvet sheen on each lobe.
            for cx in [sz.width * 0.3, sz.width * 0.7] {
                Painter.radial(ctx, [RGBA(1, 0.85, 0.9, 0.3), RGBA(1, 0.85, 0.9, 0)], [0, 1],
                               center: CGPoint(x: cx, y: sz.height * 0.55), radius: 80)
            }
            // Papillae.
            var rng = SceneRNG(seed: 0x70_9E)
            for _ in 0..<90 {
                let p = CGPoint(x: rng.range(20, sz.width - 20), y: rng.range(20, sz.height - 30))
                Painter.fill(ctx, Painter.circle(p, rng.range(1.6, 3)), ScenePaint.lighter(t, 0.35), 0.4)
            }
            // The centre groove.
            let groove = CGMutablePath()
            groove.move(to: CGPoint(x: sz.width / 2, y: sz.height))
            groove.addQuadCurve(to: CGPoint(x: sz.width / 2, y: sz.height * 0.26),
                                control: CGPoint(x: sz.width / 2 - 8, y: sz.height * 0.6))
            Painter.stroke(ctx, groove, ScenePaint.darker(t, 0.45), width: 8, 0.7)
            var hi = CGAffineTransform(translationX: 6, y: 0)
            if let g2 = groove.copy(using: &hi) {
                Painter.stroke(ctx, g2, ScenePaint.lighter(t, 0.3), width: 3, 0.6)
            }
            // The throat: the root recedes into the dark.
            Painter.linear(ctx, [RGBA(0.05, 0.01, 0.02, 0), RGBA(0.05, 0.01, 0.02, 0.9)], [0, 1],
                           from: CGPoint(x: 0, y: sz.height * 0.72), to: CGPoint(x: 0, y: sz.height))
            ctx.restoreGState()
        }
    }

    /// The tongue's curl (Waking): rolled-up edges and a lifted tip, over `tongue` (same size).
    static var tongueCurl: SKTexture {
        let s = tongueSize
        return make("tongue-curl", width: s.width, height: s.height) { ctx, sz in
            let t = ChestArt.palette.tongue
            let left = CGMutablePath()
            left.move(to: CGPoint(x: sz.width * 0.08, y: sz.height * 0.9))
            left.addCurve(to: CGPoint(x: sz.width * 0.42, y: 22), control1: CGPoint(x: sz.width * 0.03, y: sz.height * 0.5),
                          control2: CGPoint(x: sz.width * 0.2, y: 18))
            var mirror = CGAffineTransform(translationX: sz.width, y: 0).scaledBy(x: -1, y: 1)
            let right = left.copy(using: &mirror) ?? left
            for side in [left as CGPath, right] {
                Painter.stroke(ctx, side, ScenePaint.darker(t, 0.55), width: 30, 0.55)
                Painter.stroke(ctx, side, ScenePaint.lighter(t, 0.22), width: 20, 1)
                Painter.stroke(ctx, side, ScenePaint.lighter(t, 0.5), width: 5, 0.8)
            }
            // The tip lifts: its pale underside shows, with a shadow beneath.
            Painter.fill(ctx, Painter.oval(CGRect(x: sz.width / 2 - 70, y: 2, width: 140, height: 30)),
                         RGBA(0.05, 0.01, 0.02), 0.5)
            let tip = Painter.oval(CGRect(x: sz.width / 2 - 62, y: 14, width: 124, height: 46))
            Painter.stroke(ctx, tip, ScenePaint.darker(t, 0.6), width: 6, 0.9)
            Painter.gradient(ctx, tip, [ScenePaint.lighter(t, 0.45), ScenePaint.lighter(t, 0.1)], [0, 1],
                             from: CGPoint(x: 0, y: 60), to: CGPoint(x: 0, y: 14))
        }
    }

    // MARK: The satchel (bag strip)

    static var satchel: SKTexture {
        let r = ChestLayout.bagStrip
        return make("satchel", width: r.width, height: r.height + 2) { ctx, s in
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
            // The mouth along the top, with the leather lip.
            let mouth = Painter.roundRect(CGRect(x: 262, y: s.height - 26, width: 146, height: 16), 8)
            Painter.fill(ctx, mouth, RGBA(hex: 0x1E0F07), 0.95)
            // The HUD panels: tooled darker leather.
            for p in [ChestLayout.bagValueRect, ChestLayout.counterRect] {
                let panel = Painter.roundRect(p, 14)
                Painter.fill(ctx, panel, ScenePaint.leatherDark, 0.9)
                Painter.stroke(ctx, panel, ScenePaint.outline, width: 2.5, 0.8)
                ctx.saveGState()
                ctx.setLineDash(phase: 0, lengths: [5, 5])
                Painter.stroke(ctx, Painter.roundRect(p.insetBy(dx: 6, dy: 6), 10), RGBA(hex: 0xC89A5E), width: 1.6, 0.6)
                ctx.restoreGState()
            }
            // Straps and buckles between the panels.
            for x in [CGFloat(284), 386] {
                let strapR = CGRect(x: x - 13, y: 0, width: 26, height: s.height)
                Painter.chunky(ctx, Painter.rect(strapR), ScenePaint.leatherDark, outline: 1.2, light: 0.15, shade: 0.2,
                               from: CGPoint(x: strapR.minX, y: 0), to: CGPoint(x: strapR.maxX, y: 0))
                let buckle = Painter.roundRect(CGRect(x: x - 17, y: 38, width: 34, height: 26), 5)
                Painter.stroke(ctx, buckle, ScenePaint.outline, width: 7, 0.9)
                Painter.stroke(ctx, buckle, ScenePaint.brass, width: 4, 1)
                Painter.stroke(ctx, Painter.rect(CGRect(x: x - 1, y: 40, width: 2, height: 22)), ScenePaint.brassLight,
                               width: 2, 0.9)
            }
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

    // MARK: The lid's underside (the mimic's upper jaw and face)

    static func lid(_ tier: ChestTier) -> SKTexture {
        let s = ChestLayout.lidSize
        return make("lid-\(tier.rawValue)", width: s.width, height: s.height) { ctx, sz in
            drawLid(ctx, sz, TierStyle.of(tier))
        }
    }

    private static func drawLid(_ ctx: CGContext, _ s: CGSize, _ st: TierStyle) {
        let border: CGFloat = 34
        let mouthTop = ChestLayout.gumY + 4
        let inner = CGRect(x: border, y: mouthTop, width: s.width - 2 * border, height: s.height - mouthTop - border)
        let shade = ScenePaint.darker(st.wood, 0.18)
        Painter.fill(ctx, rect: CGRect(origin: .zero, size: s), st.woodDark)
        // Planks (horizontal boards, in the lid's shade).
        var y = inner.minY
        var i = 0
        while y < inner.maxY {
            let h = min(60, inner.maxY - y)
            let r = CGRect(x: inner.minX, y: y, width: inner.width, height: h)
            let c = i % 2 == 0 ? shade : ScenePaint.darker(st.wood, 0.26)
            Painter.gradient(ctx, Painter.rect(r), [ScenePaint.lighter(c, 0.06), c], [0, 1],
                             from: CGPoint(x: 0, y: r.maxY), to: CGPoint(x: 0, y: r.minY))
            Painter.grain(ctx, r, alongX: true, st.woodDark, seed: UInt64(100 + i), count: 3)
            Painter.stroke(ctx, Painter.rect(CGRect(x: r.minX, y: r.minY, width: r.width, height: 0.01)), st.woodDark,
                           width: 3, 0.9)
            y += 60
            i += 1
        }
        // The frame: left, right and far borders.
        for r in [CGRect(x: 0, y: mouthTop, width: border, height: s.height - mouthTop),
                  CGRect(x: s.width - border, y: mouthTop, width: border, height: s.height - mouthTop),
                  CGRect(x: 0, y: s.height - border, width: s.width, height: border)] {
            Painter.gradient(ctx, Painter.rect(r), [st.wood, ScenePaint.darker(st.wood, 0.2)], [0, 1],
                             from: CGPoint(x: r.minX, y: r.maxY), to: CGPoint(x: r.maxX, y: r.minY))
            Painter.grain(ctx, r, alongX: r.width > r.height, st.woodDark, seed: UInt64(r.minX + r.minY), count: 2)
        }
        Painter.stroke(ctx, Painter.rect(inner), ScenePaint.outline, width: 4, 0.85)
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
        // Corner brackets on the far corners.
        let metal = st.gilt ? st.band : RGBA(hex: 0x5E6873)
        for (cx, sx) in [(CGFloat(0), CGFloat(1)), (s.width, -1)] {
            let a = CGRect(x: sx > 0 ? cx : cx - 84, y: s.height - border, width: 84, height: border)
            let b = CGRect(x: sx > 0 ? cx : cx - border, y: s.height - 84, width: border, height: 84)
            for r in [a, b] { Painter.stroke(ctx, Painter.roundRect(r, 4), ScenePaint.outline, width: 3.2, 0.9) }
            for r in [a, b] {
                Painter.gradient(ctx, Painter.roundRect(r, 4),
                                 [ScenePaint.lighter(metal, 0.3), metal, ScenePaint.darker(metal, 0.35)], [0, 0.5, 1],
                                 from: CGPoint(x: r.minX, y: r.maxY), to: CGPoint(x: r.maxX, y: r.minY))
            }
            Painter.rivet(ctx, CGPoint(x: cx + sx * border * 0.5, y: s.height - border * 0.5), 4.5, st.stud)
        }
        // Studs along the side borders.
        var sy = mouthTop + 40
        while sy < s.height - 100 {
            Painter.rivet(ctx, CGPoint(x: border * 0.5, y: sy), 4, st.stud)
            Painter.rivet(ctx, CGPoint(x: s.width - border * 0.5, y: sy), 4, st.stud)
            sy += 58
        }
        // The eye socket: a dark carved recess the eye sits in.
        let ec = ChestLayout.eyeCenter
        let er = ChestLayout.eyeRadius
        let socket = Painter.oval(CGRect(x: ec.x - er * 1.55, y: ec.y - er * 1.15, width: er * 3.1, height: er * 2.5))
        Painter.stroke(ctx, socket, ScenePaint.outline, width: 16, 0.9)
        Painter.stroke(ctx, socket, ScenePaint.lighter(st.wood, 0.1), width: 10, 1)
        ctx.saveGState()
        ctx.addPath(socket)
        ctx.clip()
        Painter.radial(ctx, [RGBA(hex: 0x160A05), RGBA(hex: 0x2A160B), st.woodDark], [0, 0.6, 1],
                       center: ec, radius: er * 1.6, extend: true)
        ctx.restoreGState()
        if st.gilt {
            Painter.stroke(ctx, Painter.oval(CGRect(x: ec.x - er * 1.55 - 9, y: ec.y - er * 1.15 - 9,
                                                    width: er * 3.1 + 18, height: er * 2.5 + 18)),
                           st.band, width: 3.5, 1)
        }
        if st.gems {
            for k in 0..<6 {
                let a = CGFloat(k) / 6 * 2 * .pi + 0.26
                let p = CGPoint(x: ec.x + cos(a) * (er * 1.55 + 22), y: ec.y + sin(a) * (er * 1.25 + 20))
                gemStud(ctx, p, k % 2 == 0 ? RGBA(hex: 0xEC3352) : RGBA(hex: 0x3C7CEE))
            }
            // A crest above the eye: the crown.
            let crown = ChestArt.relicArt(.crown, radius: 22)
            ctx.saveGState()
            ctx.translateBy(x: ec.x, y: s.height - border - 34)
            drawLoot(ctx, crown, (st.band, ScenePaint.brassDark, ScenePaint.brassLight), radius: 22)
            ctx.restoreGState()
        }
        // Soft vignette: the lid's far corners sink into shadow.
        Painter.radial(ctx, [RGBA(0, 0, 0, 0), RGBA(0, 0, 0, 0), RGBA(0, 0, 0, 0.45)], [0, 0.55, 1],
                       center: CGPoint(x: s.width / 2, y: s.height * 0.45), radius: s.width * 0.75, extend: true)
    }

    /// The gum along the lid's fold edge: velvet, scalloped where the teeth root (bottom edge at y 0 of the texture).
    static var gum: SKTexture {
        make("gum", width: 670, height: 30) { ctx, s in
            let p = CGMutablePath()
            let n = 9
            let slot = s.width / CGFloat(n)
            p.move(to: CGPoint(x: 0, y: s.height))
            p.addLine(to: CGPoint(x: 0, y: 8))
            for i in 0..<n {
                let x0 = CGFloat(i) * slot
                p.addQuadCurve(to: CGPoint(x: x0 + slot, y: 8), control: CGPoint(x: x0 + slot / 2, y: -6))
            }
            p.addLine(to: CGPoint(x: s.width, y: s.height))
            p.closeSubpath()
            Painter.stroke(ctx, p, ScenePaint.outline, width: 5, 0.9)
            Painter.gradient(ctx, p, [ScenePaint.lighter(ScenePaint.gum, 0.15), ScenePaint.gum,
                                      ScenePaint.darker(ScenePaint.gum, 0.35)], [0, 0.4, 1],
                             from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: s.height))
        }
    }

    /// The upper teeth, roots at the top edge, tips pointing down.
    static var teeth: SKTexture {
        make("teeth", width: 670, height: 64) { ctx, s in
            var t = CGAffineTransform(translationX: 0, y: s.height - 2)
            let row = ChestArt.teethRow(width: s.width, height: ChestLayout.teethLength, count: 9, pointingDown: true)
            let p = row.copy(using: &t) ?? row
            drawTeeth(ctx, p, rootY: s.height, tipY: 0)
        }
    }

    /// The lower teeth for the bite: roots on a gum at the bottom, tips pointing up.
    static var lowerTeeth: SKTexture {
        make("lower-teeth", width: 670, height: 72) { ctx, s in
            let gumR = CGRect(x: 0, y: 0, width: s.width, height: 18)
            var t = CGAffineTransform(translationX: 0, y: 14)
            let row = ChestArt.teethRow(width: s.width, height: 50, count: 8, pointingDown: false)
            let p = row.copy(using: &t) ?? row
            drawTeeth(ctx, p, rootY: 14, tipY: s.height)
            Painter.chunky(ctx, Painter.roundRect(gumR, 8), ScenePaint.gum, outline: 2, light: 0.2, shade: 0.3,
                           from: CGPoint(x: 0, y: gumR.maxY), to: CGPoint(x: 0, y: 0))
        }
    }

    private static func drawTeeth(_ ctx: CGContext, _ p: CGPath, rootY: CGFloat, tipY: CGFloat) {
        Painter.stroke(ctx, p, ScenePaint.outline, width: 6, 0.95)
        Painter.gradient(ctx, p, [RGBA(hex: 0xD9C7A0), ScenePaint.ivory, RGBA(hex: 0xFFFDF4)], [0, 0.55, 1],
                         from: CGPoint(x: 0, y: rootY), to: CGPoint(x: 0, y: tipY))
        ctx.saveGState()
        ctx.addPath(p)
        ctx.clip()
        // A gloss stripe down each tooth's left side.
        let n = 9
        for i in 0..<n {
            let x = (CGFloat(i) + 0.32) * 670 / CGFloat(n)
            Painter.fill(ctx, Painter.oval(CGRect(x: x - 5, y: min(rootY, tipY) + 10, width: 10,
                                                  height: abs(rootY - tipY) - 24)), RGBA(1, 1, 1), 0.45)
        }
        ctx.restoreGState()
    }

    // MARK: Small brass and HUD pieces

    /// The brass name plate (no text: the label sits on it).
    static var plate: SKTexture {
        let s = ChestLayout.plateSize
        return make("plate", width: s.width, height: s.height) { ctx, sz in
            let body = Painter.roundRect(CGRect(x: 3, y: 3, width: sz.width - 6, height: sz.height - 6), 12)
            Painter.chunky(ctx, body, ScenePaint.brass, outline: 2, light: 0.45, shade: 0.35,
                           from: CGPoint(x: 0, y: sz.height), to: CGPoint(x: 0, y: 0))
            Painter.stroke(ctx, Painter.roundRect(CGRect(x: 10, y: 9, width: sz.width - 20, height: sz.height - 18), 8),
                           ScenePaint.brassDark, width: 2, 0.8)
            Painter.rivet(ctx, CGPoint(x: 20, y: sz.height / 2), 4.5, ScenePaint.brassLight)
            Painter.rivet(ctx, CGPoint(x: sz.width - 20, y: sz.height / 2), 4.5, ScenePaint.brassLight)
        }
    }

    /// The snore-o-meter's plate: a brass frame, a dark well, a sleepy face and the stage notches.
    static var meterPlate: SKTexture {
        let m = ChestLayout.meterRect
        return make("meter-plate", width: m.width, height: m.height) { ctx, s in
            let body = Painter.roundRect(CGRect(origin: .zero, size: s).insetBy(dx: 1.5, dy: 1.5), s.height / 2)
            Painter.chunky(ctx, body, ScenePaint.brass, outline: 1.5, light: 0.4, shade: 0.4,
                           from: CGPoint(x: 0, y: s.height), to: CGPoint(x: 0, y: 0))
            let well = ChestLayout.meterWell.offsetBy(dx: -m.minX, dy: -m.minY)
            Painter.fill(ctx, Painter.roundRect(well.insetBy(dx: -2, dy: -2), 6), RGBA(hex: 0x120A06), 1)
            // The sleepy face.
            let fc = CGPoint(x: 16, y: s.height / 2)
            Painter.fill(ctx, Painter.circle(fc, 11), ChestArt.palette.candle)
            Painter.stroke(ctx, Painter.circle(fc, 11), ScenePaint.outline, width: 2, 0.9)
            for dx in [CGFloat(-4.5), 4.5] {
                let lidLine = CGMutablePath()
                lidLine.move(to: CGPoint(x: fc.x + dx - 3, y: fc.y + 2))
                lidLine.addQuadCurve(to: CGPoint(x: fc.x + dx + 3, y: fc.y + 2), control: CGPoint(x: fc.x + dx, y: fc.y - 1.5))
                Painter.stroke(ctx, lidLine, ScenePaint.outline, width: 1.8, 1)
            }
            Painter.fill(ctx, Painter.oval(CGRect(x: fc.x - 2, y: fc.y - 6, width: 4, height: 3)), ScenePaint.outline, 0.9)
            // Stage notches at 0.35 and 0.70.
            for f in [CGFloat(0.35), 0.70] {
                let x = well.minX + well.width * f
                Painter.fill(ctx, Painter.polygon([CGPoint(x: x - 4, y: s.height), CGPoint(x: x + 4, y: s.height),
                                                   CGPoint(x: x, y: well.maxY - 1)]), ScenePaint.outline, 0.9)
                Painter.fill(ctx, Painter.polygon([CGPoint(x: x - 4, y: 0), CGPoint(x: x + 4, y: 0),
                                                   CGPoint(x: x, y: well.minY + 1)]), ScenePaint.outline, 0.9)
            }
        }
    }

    /// The torch gauge's track on the left rim (a dark slot with a brass edge).
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

    /// The brass clasp on the satchel (the shut-hold ring goes round it), with a little sack on it.
    static var clasp: SKTexture {
        make("clasp", width: 68, height: 68) { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            let disk = Painter.circle(c, 29)
            Painter.chunky(ctx, disk, ScenePaint.brass, outline: 2, light: 0.45, shade: 0.4,
                           from: CGPoint(x: c.x - 29, y: c.y + 29), to: CGPoint(x: c.x + 29, y: c.y - 29))
            Painter.stroke(ctx, Painter.circle(c, 23), ScenePaint.brassDark, width: 2, 0.8)
            // The sack.
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

    /// A gold coin stack (the counter's icon).
    static var coinStack: SKTexture {
        make("coin-stack", width: 48, height: 48) { ctx, s in
            let gold = ChestArt.palette.gold
            for (i, y) in [CGFloat(10), 18, 26].enumerated() {
                let r = CGRect(x: 6 + CGFloat(i % 2) * 2, y: y, width: 34, height: 14)
                let p = Painter.oval(r)
                Painter.chunky(ctx, p, gold, outline: 1.5, light: 0.4, shade: 0.35,
                               from: CGPoint(x: r.minX, y: r.maxY), to: CGPoint(x: r.maxX, y: r.minY))
                Painter.stroke(ctx, Painter.oval(r.insetBy(dx: 7, dy: 3)), ScenePaint.brassDark, width: 1.4, 0.8)
            }
            Painter.fill(ctx, Painter.oval(CGRect(x: 14, y: 34, width: 9, height: 3)), RGBA(1, 1, 1), 0.8)
            _ = s
        }
    }

    /// The lid slider's track (no hinge): a dark slot in a brass frame with ticks.
    static var sliderTrack: SKTexture {
        let h = ChestLayout.sliderMaxY - ChestLayout.sliderMinY + 40
        return make("slider-track", width: 56, height: h) { ctx, s in
            let frame = Painter.roundRect(CGRect(origin: .zero, size: s).insetBy(dx: 3, dy: 3), 24)
            Painter.chunky(ctx, frame, ScenePaint.brass, outline: 2, light: 0.35, shade: 0.4,
                           from: CGPoint(x: 0, y: 0), to: CGPoint(x: s.width, y: 0))
            let slot = Painter.roundRect(CGRect(x: s.width / 2 - 7, y: 16, width: 14, height: s.height - 32), 7)
            Painter.fill(ctx, slot, RGBA(hex: 0x120A06), 1)
            var y: CGFloat = 30
            while y < s.height - 24 {
                Painter.stroke(ctx, Painter.rect(CGRect(x: 8, y: y, width: 10, height: 0.01)), ScenePaint.brassDark,
                               width: 2, 0.9)
                Painter.stroke(ctx, Painter.rect(CGRect(x: s.width - 18, y: y, width: 10, height: 0.01)),
                               ScenePaint.brassDark, width: 2, 0.9)
                y += 38
            }
        }
    }

    /// The lid slider's knob: a brass lever handle.
    static var sliderKnob: SKTexture {
        make("slider-knob", width: 96, height: 56) { ctx, s in
            let bar = Painter.roundRect(CGRect(x: 4, y: 12, width: s.width - 8, height: 32), 16)
            Painter.chunky(ctx, bar, ScenePaint.brass, outline: 2.2, light: 0.5, shade: 0.4,
                           from: CGPoint(x: 0, y: 44), to: CGPoint(x: 0, y: 12))
            for dx in [CGFloat(-22), -12, 12, 22] {
                Painter.stroke(ctx, Painter.rect(CGRect(x: s.width / 2 + dx, y: 18, width: 0.01, height: 20)),
                               ScenePaint.brassDark, width: 2.4, 0.9)
            }
            Painter.rivet(ctx, CGPoint(x: s.width / 2, y: 28), 9, ScenePaint.brassLight)
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

import SpriteKit
import UIKit

/// Colour helpers on the shared `RGBA`, as plain functions (no extension on a shared type, so nothing can clash with
/// another module's helpers).
enum ScenePaint {
    static func ui(_ c: RGBA) -> UIColor {
        UIColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: CGFloat(c.a))
    }

    static func ui(_ c: RGBA, alpha: CGFloat) -> UIColor {
        UIColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: alpha)
    }

    static func cg(_ c: RGBA, _ alpha: Double = 1) -> CGColor {
        CGColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: CGFloat(c.a * alpha))
    }

    static func lighter(_ c: RGBA, _ t: Double) -> RGBA { c.mixed(with: RGBA(1, 1, 1, c.a), t) }
    static func darker(_ c: RGBA, _ t: Double) -> RGBA { c.mixed(with: RGBA(0, 0, 0, c.a), t) }

    /// WCAG relative luminance (sRGB).
    static func luminance(_ c: RGBA) -> Double {
        func lin(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
    }

    /// WCAG contrast ratio (1…21).
    static func contrast(_ a: RGBA, _ b: RGBA) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    static let outline = ChestArt.outline
    static let ivory = RGBA(hex: 0xF6EBD2)
    static let brass = RGBA(hex: 0xD9A441)
    static let brassLight = RGBA(hex: 0xFFE39A)
    static let brassDark = RGBA(hex: 0x7A5214)
    static let leather = RGBA(hex: 0x8A5530)
    static let leatherDark = RGBA(hex: 0x4E2B16)
    static let meterGreen = RGBA(hex: 0x56D68C)
    static let eyeWhite = RGBA(hex: 0xF5ECD7)
    static let throat = RGBA(hex: 0x1A0508)
    static let gum = RGBA(hex: 0x8A2440)
}

/// xorshift64 for cosmetic randomness (never the simulation's `SeededRandom`).
struct SceneRNG {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    /// 0 ..< 1
    mutating func unit() -> CGFloat {
        CGFloat(Double(next() >> 11) / 9_007_199_254_740_992.0)
    }

    mutating func range(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * unit() }

    mutating func sign() -> CGFloat { unit() < 0.5 ? -1 : 1 }

    /// A stateless 0 ..< 1 hash of an index (stable per-item phases).
    static func hash(_ i: Int, _ salt: UInt64) -> CGFloat {
        var z = UInt64(bitPattern: Int64(i)) &+ (salt &+ 1) &* 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z = z ^ (z >> 31)
        return CGFloat(Double(z >> 11) / 9_007_199_254_740_992.0)
    }
}

/// CoreGraphics painting in a y-up context (every texture here is drawn y up, like the canvas).
enum Painter {
    static func fill(_ ctx: CGContext, _ path: CGPath, _ c: RGBA, _ alpha: Double = 1) {
        ctx.addPath(path)
        ctx.setFillColor(ScenePaint.cg(c, alpha))
        ctx.fillPath()
    }

    static func fill(_ ctx: CGContext, rect: CGRect, _ c: RGBA, _ alpha: Double = 1) {
        ctx.setFillColor(ScenePaint.cg(c, alpha))
        ctx.fill(rect)
    }

    static func stroke(_ ctx: CGContext, _ path: CGPath, _ c: RGBA, width: CGFloat, _ alpha: Double = 1) {
        ctx.addPath(path)
        ctx.setStrokeColor(ScenePaint.cg(c, alpha))
        ctx.setLineWidth(width)
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.strokePath()
    }

    /// Fills `path` with a linear gradient (colours from `a` to `b`).
    static func gradient(_ ctx: CGContext, _ path: CGPath, _ colors: [RGBA], _ locations: [CGFloat],
                         from a: CGPoint, to b: CGPoint) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        linear(ctx, colors, locations, from: a, to: b)
        ctx.restoreGState()
    }

    static func linear(_ ctx: CGContext, _ colors: [RGBA], _ locations: [CGFloat], from a: CGPoint, to b: CGPoint) {
        guard colors.count >= 2, colors.count == locations.count else { return }
        let cg = colors.map { ScenePaint.cg($0) } as CFArray
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cg, locations: locations) else {
            return
        }
        ctx.drawLinearGradient(g, start: a, end: b, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    static func radial(_ ctx: CGContext, _ colors: [RGBA], _ locations: [CGFloat], center: CGPoint, radius: CGFloat,
                       extend: Bool = false) {
        guard radius > 0, colors.count >= 2, colors.count == locations.count else { return }
        let cg = colors.map { ScenePaint.cg($0) } as CFArray
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cg, locations: locations) else {
            return
        }
        ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius,
                               options: extend ? [.drawsAfterEndLocation] : [])
    }

    static func rect(_ r: CGRect) -> CGPath { CGPath(rect: r, transform: nil) }

    static func roundRect(_ r: CGRect, _ corner: CGFloat) -> CGPath {
        let p = CGMutablePath()
        ArtPrim.roundedRect(p, r, corner: corner)
        return p
    }

    static func oval(_ r: CGRect) -> CGPath {
        let p = CGMutablePath()
        ArtPrim.oval(p, r)
        return p
    }

    static func circle(_ c: CGPoint, _ r: CGFloat) -> CGPath {
        oval(CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }

    static func polygon(_ pts: [CGPoint]) -> CGPath {
        let p = CGMutablePath()
        ArtPrim.polygon(p, pts)
        return p
    }

    /// A chunky shape: a dark outline, a gradient body (light at `lightFrom`, dark at `lightTo`).
    static func chunky(_ ctx: CGContext, _ path: CGPath, _ base: RGBA, outline: CGFloat, light: Double = 0.3,
                       shade: Double = 0.3, from a: CGPoint, to b: CGPoint) {
        stroke(ctx, path, ScenePaint.outline, width: outline * 2, 0.9)
        gradient(ctx, path, [ScenePaint.lighter(base, light), base, ScenePaint.darker(base, shade)], [0, 0.5, 1],
                 from: a, to: b)
    }

    /// A rivet / stud: a small domed circle.
    static func rivet(_ ctx: CGContext, _ c: CGPoint, _ r: CGFloat, _ base: RGBA) {
        let p = circle(c, r)
        stroke(ctx, p, ScenePaint.outline, width: max(r * 0.5, 1.2), 0.85)
        gradient(ctx, p, [ScenePaint.lighter(base, 0.6), base, ScenePaint.darker(base, 0.4)], [0, 0.45, 1],
                 from: CGPoint(x: c.x - r, y: c.y + r), to: CGPoint(x: c.x + r, y: c.y - r))
    }

    /// Wood grain: thin wavy lines along a board (horizontal when `alongX`).
    static func grain(_ ctx: CGContext, _ r: CGRect, alongX: Bool, _ c: RGBA, seed: UInt64, count: Int = 4) {
        var rng = SceneRNG(seed: seed)
        ctx.saveGState()
        ctx.addPath(rect(r))
        ctx.clip()
        for _ in 0..<max(count, 1) {
            let p = CGMutablePath()
            if alongX {
                let y = r.minY + rng.range(0.15, 0.85) * r.height
                let wob = rng.range(1.5, 4)
                p.move(to: CGPoint(x: r.minX, y: y))
                var x = r.minX
                while x < r.maxX {
                    let nx = min(x + rng.range(40, 90), r.maxX)
                    p.addQuadCurve(to: CGPoint(x: nx, y: y + rng.sign() * rng.range(0, wob)),
                                   control: CGPoint(x: (x + nx) / 2, y: y + rng.sign() * wob))
                    x = nx
                }
            } else {
                let x = r.minX + rng.range(0.15, 0.85) * r.width
                let wob = rng.range(1.5, 4)
                p.move(to: CGPoint(x: x, y: r.minY))
                var y = r.minY
                while y < r.maxY {
                    let ny = min(y + rng.range(40, 90), r.maxY)
                    p.addQuadCurve(to: CGPoint(x: x + rng.sign() * rng.range(0, wob), y: ny),
                                   control: CGPoint(x: x + rng.sign() * wob, y: (y + ny) / 2))
                    y = ny
                }
            }
            stroke(ctx, p, c, width: rng.range(1.2, 2.4), Double(rng.range(0.25, 0.45)))
        }
        // A knot or two.
        if rng.unit() < 0.6 {
            let k = CGPoint(x: r.minX + rng.range(0.2, 0.8) * r.width, y: r.minY + rng.range(0.25, 0.75) * r.height)
            let kr = rng.range(3, 6)
            stroke(ctx, oval(CGRect(x: k.x - kr * 1.6, y: k.y - kr, width: kr * 3.2, height: kr * 2)), c,
                   width: 1.6, 0.45)
            fill(ctx, circle(k, kr * 0.5), c, 0.5)
        }
        ctx.restoreGState()
    }
}

/// Textures generated in code once and cached (no per-frame texture work).
@MainActor
enum SceneTextures {
    private static var cache: [String: SKTexture] = [:]

    /// Number of textures built so far (tests: the frame loop never adds any once warm).
    static var count: Int { cache.count }

    static func has(_ key: String) -> Bool { cache[key] != nil }

    /// Draws into a fresh image (the context is y up, origin bottom-left, in points) and caches it under `key`.
    static func make(_ key: String, width: CGFloat, height: CGFloat, scale: CGFloat = 2,
                     draw: (CGContext, CGSize) -> Void) -> SKTexture {
        if let t = cache[key] { return t }
        let size = CGSize(width: max(width, 1), height: max(height, 1))
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = scale
        fmt.opaque = false
        let img = UIGraphicsImageRenderer(size: size, format: fmt).image { rc in
            let ctx = rc.cgContext
            ctx.translateBy(x: 0, y: size.height)
            ctx.scaleBy(x: 1, y: -1)
            draw(ctx, size)
        }
        let t = SKTexture(image: img)
        t.filteringMode = .linear
        cache[key] = t
        return t
    }

    private static let white = RGBA(1, 1, 1)
    private static func w(_ a: Double) -> RGBA { RGBA(1, 1, 1, a) }

    // MARK: Soft shapes (white; tint with the sprite colour)

    static var dot: SKTexture {
        make("dot", width: 32, height: 32) { ctx, s in
            Painter.radial(ctx, [w(1), w(1), w(0)], [0, 0.55, 1], center: CGPoint(x: s.width / 2, y: s.height / 2),
                           radius: s.width / 2)
        }
    }

    static var soft: SKTexture {
        make("soft", width: 64, height: 64, scale: 1) { ctx, s in
            Painter.radial(ctx, [w(1), w(0.5), w(0)], [0, 0.42, 1], center: CGPoint(x: s.width / 2, y: s.height / 2),
                           radius: s.width / 2)
        }
    }

    static var glow: SKTexture {
        make("glow", width: 128, height: 128) { ctx, s in
            Painter.radial(ctx, [w(1), w(0.42), w(0.12), w(0)], [0, 0.22, 0.55, 1],
                           center: CGPoint(x: s.width / 2, y: s.height / 2), radius: s.width / 2)
        }
    }

    /// A four-point twinkle with a soft halo (glints).
    static var sparkle: SKTexture {
        make("sparkle", width: 48, height: 48) { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            Painter.radial(ctx, [w(0.6), w(0)], [0, 1], center: c, radius: s.width * 0.3)
            let r = s.width * 0.48, k = s.width * 0.06
            let p = CGMutablePath()
            p.move(to: CGPoint(x: c.x, y: c.y - r))
            p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
            p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
            p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
            p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
            p.closeSubpath()
            Painter.fill(ctx, p, white)
        }
    }

    /// A sunburst of 10 soft rays (relics, the relic banner).
    static var rays: SKTexture {
        make("rays", width: 256, height: 256) { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            let n = 10
            for i in 0..<n {
                let a0 = CGFloat(i) / CGFloat(n) * 2 * .pi
                let half: CGFloat = i % 2 == 0 ? 0.12 : 0.07
                let p = CGMutablePath()
                p.move(to: c)
                p.addLine(to: CGPoint(x: c.x + cos(a0 - half) * 140, y: c.y + sin(a0 - half) * 140))
                p.addLine(to: CGPoint(x: c.x + cos(a0 + half) * 140, y: c.y + sin(a0 + half) * 140))
                p.closeSubpath()
                ctx.saveGState()
                ctx.addPath(p)
                ctx.clip()
                Painter.radial(ctx, [w(0.95), w(0.5), w(0)], [0, 0.4, 1], center: c, radius: 128)
                ctx.restoreGState()
            }
            Painter.radial(ctx, [w(0.8), w(0)], [0, 1], center: c, radius: 44)
        }
    }

    /// A vertical alpha ramp, white: `alphas` from the bottom (y 0) to the top.
    static func vertical(_ key: String, _ alphas: [Double], _ locations: [CGFloat]) -> SKTexture {
        make("v-\(key)", width: 4, height: 256, scale: 1) { ctx, s in
            Painter.linear(ctx, alphas.map { w($0) }, locations, from: CGPoint(x: 2, y: 0),
                           to: CGPoint(x: 2, y: s.height))
        }
    }

    /// Edges dark, centre clear (torch out, stage vignette). White: tint it.
    static var vignette: SKTexture {
        make("vignette", width: 256, height: 256, scale: 1) { ctx, s in
            Painter.radial(ctx, [w(0), w(0), w(0.55), w(1)], [0, 0.42, 0.72, 1],
                           center: CGPoint(x: s.width / 2, y: s.height / 2), radius: s.width * 0.62, extend: true)
        }
    }

    /// A rounded meter segment with a top gloss (white: tint it).
    static var segment: SKTexture {
        make("segment", width: 19, height: 16) { ctx, s in
            let r = CGRect(origin: .zero, size: s)
            Painter.fill(ctx, Painter.roundRect(r, 4), white)
            Painter.fill(ctx, Painter.roundRect(CGRect(x: 3, y: s.height * 0.55, width: s.width - 6,
                                                       height: s.height * 0.32), 2), RGBA(1, 1, 1), 0.55)
        }
    }

    // MARK: Loot

    static func lootKey(_ kind: LootKind) -> String { ChestArt.lootKeyName(kind) }

    /// The item's art at `radius` (the sprite's size in points is `lootSide(radius)` square). The pixels come from
    /// `ChestArt.lootImage`, the same image SwiftUI uses (one art source). `value` picks the coin stack.
    static func loot(_ kind: LootKind, radius: CGFloat, value: Int = 0) -> SKTexture {
        let r = max(radius.rounded(), 4)
        let n = ChestArt.coinCount(kind, value: value)
        let key = "loot-\(lootKey(kind))-\(Int(r))-\(n)"
        if let t = cache[key] { return t }
        guard let img = ChestArt.lootImage(kind, value: value, radius: r, scale: 3) else {
            let side = lootSide(r)
            return make(key, width: side, height: side, scale: 3) { ctx, s in
                ctx.translateBy(x: s.width / 2, y: s.height / 2)
                ChestArt.drawArt(ctx, ChestArt.lootArt(kind, radius: r, value: value), ChestArt.lootColors(kind),
                                 radius: r)
            }
        }
        let t = SKTexture(cgImage: img)
        t.filteringMode = .linear
        cache[key] = t
        return t
    }

    static func lootSide(_ radius: CGFloat) -> CGFloat { ChestArt.artSide(radius: radius) }

    /// Draws a `LootArt` centred at the context's origin (y up) (the shared renderer).
    static func drawLoot(_ ctx: CGContext, _ art: LootArt, _ col: (fill: RGBA, rim: RGBA, glint: RGBA),
                         radius r: CGFloat) {
        ChestArt.drawArt(ctx, art, col, radius: r)
    }

    /// A soft dark ellipse for an item's contact shadow (white: tint it).
    static var shadow: SKTexture {
        make("shadow", width: 64, height: 40, scale: 1) { ctx, s in
            ctx.saveGState()
            ctx.scaleBy(x: 1, y: s.height / s.width)
            Painter.radial(ctx, [w(0.9), w(0.5), w(0)], [0, 0.5, 1], center: CGPoint(x: s.width / 2, y: s.width / 2),
                           radius: s.width / 2)
            ctx.restoreGState()
        }
    }
}

/// Large, high-contrast text for SpriteKit (≥ 18 pt): the system rounded black face with a dark outline.
@MainActor
final class SceneLabel {
    static let minimumSize: CGFloat = 18

    let node: SKLabelNode
    let size: CGFloat
    private(set) var text: String = ""
    private var color: UIColor
    private var outline: UIColor?
    /// The smallest size this label may be drawn or scaled to (18 pt for play text; 14 pt for small-caps labels).
    let floorSize: CGFloat
    /// The outline thickness (% of the font size, negative = stroke and fill).
    private let strokeWidth: Double
    /// Letter spacing in points (small-caps labels are tracked out).
    private let kern: CGFloat
    /// When > 0 the label is scaled down to fit (never below `floorSize`).
    var maxWidth: CGFloat = 0

    init(size: CGFloat, color: UIColor, outline: UIColor? = ScenePaint.ui(ScenePaint.outline),
         align: SKLabelHorizontalAlignmentMode = .center, minimumSize: CGFloat = SceneLabel.minimumSize,
         strokeWidth: Double = -5, kern: CGFloat = 0) {
        floorSize = max(minimumSize, 12)
        self.size = max(size, floorSize)
        self.color = color
        self.outline = outline
        self.strokeWidth = strokeWidth
        self.kern = kern
        node = SKLabelNode()
        node.horizontalAlignmentMode = align
        node.verticalAlignmentMode = .center
        node.numberOfLines = 1
    }

    func setOutline(_ c: UIColor?) {
        guard c != outline else { return }
        outline = c
        rebuild()
    }

    static func font(_ size: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: .black)
        if let d = base.fontDescriptor.withDesign(.rounded) { return UIFont(descriptor: d, size: size) }
        return base
    }

    func set(_ s: String) {
        guard s != text else { return }
        text = s
        rebuild()
    }

    func setColor(_ c: UIColor) {
        guard c != color else { return }
        color = c
        rebuild()
    }

    private func rebuild() {
        var attrs: [NSAttributedString.Key: Any] = [.font: SceneLabel.font(size), .foregroundColor: color]
        if let o = outline {
            attrs[.strokeColor] = o
            attrs[.strokeWidth] = strokeWidth
        }
        if kern != 0 { attrs[.kern] = kern }
        node.attributedText = NSAttributedString(string: text, attributes: attrs)
        if maxWidth > 0 {
            node.setScale(1)
            let wdt = node.frame.width
            let k = wdt > maxWidth ? max(maxWidth / wdt, floorSize / size) : 1
            node.setScale(k)
        }
    }
}

/// Thousands separators for the counters.
enum SceneNumber {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.maximumFractionDigits = 0
        return f
    }()

    static func gold(_ v: Int) -> String { formatter.string(from: NSNumber(value: v)) ?? "\(v)" }
}

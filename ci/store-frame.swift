// Hush App Store frame compositor (macOS host side), adapted from Swoop's ci/store-frame.swift (landscape, book pose)
// for Hush's portrait sets and the tabletop pose. ci/store-set.sh compiles it with `xcrun swiftc` (falling back to
// `xcrun swift` as a script). It draws one portrait store frame from one raw simulator capture, in the caption system
// of docs/appstore/screenshots.md ("Caption style"):
//
//   store-frame --in raw.png --out frame.png --size 1320x2868 --caption "It's waking. *Freeze!* / Hold still and it settles."
//               [--radius 0.06]
//   store-frame --in duo-inner.png --out frame.png --size 1320x2868 --caption "…" --tabletop [--angle 125]
//               [--elevation 28] [--fold 1428]
//
// Layout (every Hush slot is portrait): the caption band runs across the top (3–21.5 % of the height) and the picture
// sits under it, as large as fits (23.5–97 %). The type is sized from the WIDTH (a portrait headline of ≤ 6 words wraps
// to ≤ 2 balanced lines), so the 6.9", 6.3" and Duo frames read alike.
// Look (screenshots.md): the dungeon teal-black #12161C, a little lighter at the top and deeper at the bottom, with a
// warm candle glow (gold #F2B84B at low strength) rising from behind the picture, added with plus-lighter blending
// (never gold at partial alpha over the dark). Headline: SF Pro Rounded Heavy (plain system Heavy if the rounded design
// is missing) in parchment #F3E9D2; `*word*` is the ONE highlight, ink #12161C letters on a gold #F2B84B marker swash.
// " / " starts the sub-line, SF Pro Rounded Semibold in warm grey #BFB39A at ~46 % of the headline size.
//
// Flat frames: the capture itself, unaltered, scaled to fit, with rounded corners (--radius × its shorter side), a
//   hairline gold edge and a soft shadow. No device is drawn.
// --tabletop: the capture must be a real iPhone Duo inner-display frame in the tabletop canvas (2007 × 2853, the fold
//   across the middle at y ≈ 1368–1488 px). It is split at the fold (--fold px from the top, default 1428 at 2853 high):
//   the top part (the lid) and the bottom part (the floor) are each mapped, by a true perspective transform (Core
//   Image CIPerspectiveTransform; the corner order is self-tested at start-up), onto one half of a stylised iPhone Duo
//   standing like a little laptop: the floor half flat on a table, the lid half raised to --angle degrees from it
//   (default 125), seen from in front and --elevation degrees above (default 28). Drawn around it: a thin graphite
//   bezel (2.4 % of the device width), the floor half's front edge, the hinge barrel (showing past the side bezels), a
//   soft drop shadow and a table shadow. No hands. Nothing is drawn ON the screen: the pixels are the capture's, only
//   warped; the outer corners are clipped to the display's rounded corners.
// Caption glossary (screenshots.md "the app's words, exactly"; Guideline 2.3.7): a caption using "torch", "#1" or
//   "Made for iPhone Duo" is REJECTED: no frame is written, exit status 2, `store-frame: caption rejected: …`.
// Output: exactly --size pixels (default: the input's size), opaque sRGB PNG with no alpha channel.
// Prints one line: `store-frame: <out> <W>x<H> mode=flat|tabletop layout=top cap=<% of W> lines=<n> font=<name>
//   rounded=<yes|no>` plus, for --tabletop, ` angle=<a> elevation=<e> fold=<px> warp=<ok|flipV|flipH|flipVH>
//   extent=<ok|mismatch>`.
import AppKit
import CoreGraphics
import CoreImage
import CoreText
import Foundation
import ImageIO

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(("store-frame: " + message + "\n").data(using: .utf8)!)
    exit(1)
}

// MARK: Arguments (`--key value`; a key followed by another `--key`, or by nothing, is a flag set to "1")

var options: [String: String] = [:]
var argv = Array(CommandLine.arguments.dropFirst())
while !argv.isEmpty {
    let key = argv.removeFirst()
    guard key.hasPrefix("--"), key.count > 2 else { fail("bad argument \(key)") }
    let name = String(key.dropFirst(2))
    if let next = argv.first, !next.hasPrefix("--") {
        options[name] = argv.removeFirst()
    } else {
        options[name] = "1"
    }
}
guard let input = options["in"], let output = options["out"] else { fail("needs --in and --out") }
let rawCaption = options["caption"] ?? ""
let tabletopMode = (options["tabletop"] ?? "0") != "0"
let cornerFraction = CGFloat(Double(options["radius"] ?? "") ?? 0.06)

// MARK: Caption glossary (the app's own words only; checked before anything is drawn)

func captionProblems(_ caption: String) -> [String] {
    let plain = caption.replacingOccurrences(of: "*", with: "")
    let rules: [(pattern: String, label: String)] = [
        ("\\btorch(es|lit)?\\b", "\"torch\" (the app says candle)"),
        ("#\\s?1\\b", "\"#1\" (Guideline 2.3.7)"),
        ("\\bmade for iphone duo\\b", "\"Made for iPhone Duo\" (Apple adds its own badge)"),
    ]
    var found: [String] = []
    let range = NSRange(plain.startIndex..., in: plain)
    for rule in rules {
        guard let re = try? NSRegularExpression(pattern: rule.pattern, options: [.caseInsensitive]) else { continue }
        if re.firstMatch(in: plain, options: [], range: range) != nil { found.append(rule.label) }
    }
    return found
}

let rejected = captionProblems(rawCaption)
if !rejected.isEmpty {
    let message = "store-frame: caption rejected: uses " + rejected.joined(separator: ", ")
        + " (docs/appstore/screenshots.md); no frame written"
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    print(message)
    exit(2)
}

func number(_ key: String, _ fallback: Double) -> Double {
    guard let text = options[key], let value = Double(text), value.isFinite else { return fallback }
    return value
}

guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: input) as CFURL, nil),
      let shot = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fail("cannot read \(input)") }

var width = shot.width, height = shot.height
if let size = options["size"], !size.isEmpty, size != "raw" {
    let parts = size.lowercased().split(separator: "x").compactMap { Int($0) }
    guard parts.count == 2, parts[0] > 64, parts[1] > 64 else { fail("bad --size \(size)") }
    width = parts[0]
    height = parts[1]
}
let W = CGFloat(width), H = CGFloat(height)

guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { fail("no sRGB colour space") }
// noneSkipLast: an opaque RGB bitmap, so the PNG has no alpha channel (App Store Connect rejects alpha).
guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                              space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fail("no context") }
let ctx: CGContext = context
ctx.interpolationQuality = .high
ctx.setShouldAntialias(true)

func srgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// Palette (docs/appstore/screenshots.md "Caption style"; sRGB).
let dungeon: UInt32 = 0x12161C       // the dungeon teal-black
let dungeonTop: UInt32 = 0x1A2129    // a little lighter at the top
let dungeonDeep: UInt32 = 0x0A0D11   // deeper at the bottom
let candleGold: UInt32 = 0xF2B84B    // the candle glow and the swash
let parchment: UInt32 = 0xF3E9D2     // headline
let warmGrey: UInt32 = 0xBFB39A      // sub-line
let ink: UInt32 = 0x12161C           // ink on gold
let shadowInk: UInt32 = 0x05070A     // drop shadows
let bezelLit: UInt32 = 0x262B33      // graphite, the lid (faces the light)
let bezelDark: UInt32 = 0x171A1F     // graphite, the floor half
let edgeDark: UInt32 = 0x0C0E11      // the floor half's front edge

/// A top-left-origin rect → Core Graphics' bottom-left origin.
func cg(_ r: CGRect) -> CGRect { CGRect(x: r.minX, y: H - r.maxY, width: r.width, height: r.height) }

// R15 (founder: "the header and all as per requirement"): `--banner header|search` lays the same caption system and
// the same tabletop Duo out for Apple's optional creative assets (App Store Connect Help, "Creative assets
// specifications"): the product page header 21:9 (3840 x 1646) and the search results art 3:2 (3840 x 2560).
// header: the words in a column on the left, the Duo on the right, both inside the area an iPhone shows (about 8 % is
//   lost per side under the back/share buttons) and the device's centre near the template's safe area.
// search: one headline line and the sub-line across the top, the Duo big and centred under it.
let bannerKind = (options["banner"] ?? "").lowercased()
if !bannerKind.isEmpty && bannerKind != "header" && bannerKind != "search" { fail("--banner is header or search") }

// Top-left-origin boxes for the caption and the picture.
let band: CGRect = {
    switch bannerKind {
    case "header": return CGRect(x: W * 0.11, y: H * 0.20, width: W * 0.36, height: H * 0.60)
    case "search": return CGRect(x: W * 0.06, y: H * 0.045, width: W * 0.88, height: H * 0.19)
    default: return CGRect(x: W * 0.06, y: H * 0.030, width: W * 0.88, height: H * 0.185)
    }
}()
let pictureBox: CGRect = {
    switch bannerKind {
    case "header": return CGRect(x: W * 0.49, y: H * 0.05, width: W * 0.40, height: H * 0.90)
    case "search": return CGRect(x: W * 0.08, y: H * 0.255, width: W * 0.84, height: H * 0.715)
    default: return CGRect(x: W * 0.04, y: H * 0.235, width: W * 0.92, height: H * 0.735)
    }
}()

// MARK: Background

ctx.setFillColor(srgb(dungeon))
ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
if let sweep = CGGradient(colorsSpace: space, colors: [srgb(dungeonTop), srgb(dungeon), srgb(dungeonDeep)] as CFArray,
                          locations: [0, 0.45, 1]) {
    ctx.drawLinearGradient(sweep, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}
ctx.saveGState()
ctx.setBlendMode(.plusLighter)   // additive warm light: never gold at partial alpha over the dark
if let glow = CGGradient(colorsSpace: space, colors: [srgb(candleGold, 0.17), srgb(candleGold, 0)] as CFArray,
                         locations: [0, 1]) {
    let centre = CGPoint(x: W * 0.5, y: H - pictureBox.midY - pictureBox.height * 0.08)
    ctx.drawRadialGradient(glow, startCenter: centre, startRadius: 0, endCenter: centre,
                           endRadius: max(W, H) * 0.48, options: [])
}
ctx.restoreGState()

// MARK: Flat frame (the capture, unaltered, scaled to fit the picture box)

func drawFlat() {
    let fit = min(pictureBox.width / CGFloat(shot.width), pictureBox.height / CGFloat(shot.height))
    let shotW = (CGFloat(shot.width) * fit).rounded()
    let shotH = (CGFloat(shot.height) * fit).rounded()
    let shotRect = CGRect(x: (pictureBox.midX - shotW / 2).rounded(), y: (pictureBox.midY - shotH / 2).rounded(),
                          width: shotW, height: shotH)   // top-left origin
    let radius = max(0, min(min(shotW, shotH) * cornerFraction, shotW * 0.49, shotH * 0.49))
    let shotPath = CGPath(roundedRect: cg(shotRect), cornerWidth: radius, cornerHeight: radius, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -H * 0.008), blur: H * 0.032, color: srgb(0x000000, 0.55))
    ctx.addPath(shotPath)
    ctx.setFillColor(srgb(shadowInk))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shotPath)
    ctx.clip()
    ctx.draw(shot, in: cg(shotRect))
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shotPath)
    ctx.setStrokeColor(srgb(candleGold, 0.30))
    ctx.setLineWidth(max(1, W * 0.0018))
    ctx.strokePath()
    ctx.restoreGState()
}

// MARK: Tabletop frame (a Duo inner capture on a stylised iPhone Duo standing like a little laptop)

/// Core Image renders the perspective warps. A paravirtual GPU can refuse, so a software context is the fallback.
var ciContext = CIContext(options: [CIContextOption.outputColorSpace: space])
var usedSoftwareCI = false

func render(_ image: CIImage, _ rect: CGRect) -> CGImage? {
    if let out = ciContext.createCGImage(image, from: rect) { return out }
    if usedSoftwareCI { return nil }
    usedSoftwareCI = true
    ciContext = CIContext(options: [CIContextOption.outputColorSpace: space, CIContextOption.useSoftwareRenderer: true])
    return ciContext.createCGImage(image, from: rect)
}

/// Warps `image` so its top-left / top-right / bottom-left / bottom-right corners land on the given points
/// (bottom-left-origin pixel coordinates of the output). Returns the rendered image and where to draw it.
func warp(_ image: CGImage, tl: CGPoint, tr: CGPoint, bl: CGPoint, br: CGPoint) -> (image: CGImage, rect: CGRect)? {
    guard let filter = CIFilter(name: "CIPerspectiveTransform") else { return nil }
    filter.setValue(CIImage(cgImage: image), forKey: kCIInputImageKey)
    filter.setValue(CIVector(cgPoint: tl), forKey: "inputTopLeft")
    filter.setValue(CIVector(cgPoint: tr), forKey: "inputTopRight")
    filter.setValue(CIVector(cgPoint: bl), forKey: "inputBottomLeft")
    filter.setValue(CIVector(cgPoint: br), forKey: "inputBottomRight")
    guard let out = filter.outputImage else { return nil }
    let rect = out.extent.integral
    guard rect.width >= 1, rect.height >= 1, rect.width < 40000, rect.height < 40000,
          let rendered = render(out, rect) else { return nil }
    return (rendered, rect)
}

/// RGB of one pixel (x from the left, y from the top) of a CGImage.
func pixel(_ image: CGImage, _ x: Int, _ yFromTop: Int) -> (r: Int, g: Int, b: Int)? {
    guard let probe = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    probe.interpolationQuality = .none
    probe.setFillColor(srgb(0x000000))
    probe.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
    probe.draw(image, in: CGRect(x: -CGFloat(x), y: -CGFloat(image.height - 1 - yFromTop),
                                 width: CGFloat(image.width), height: CGFloat(image.height)))
    guard let data = probe.data else { return nil }
    let bytes = data.assumingMemoryBound(to: UInt8.self)
    return (Int(bytes[0]), Int(bytes[1]), Int(bytes[2]))
}

/// Self-test of the warp's corner convention: a four-colour test card (red top-left, green top-right, blue
/// bottom-left, white bottom-right) is warped onto an upright square and read back. Returns which flips the real warps
/// need, or nil if Core Image can't warp at all.
func warpConvention() -> (flipV: Bool, flipH: Bool)? {
    guard let card = CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                               bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
    card.setFillColor(srgb(0xFF0000)); card.fill(CGRect(x: 0, y: 4, width: 4, height: 4))   // top-left
    card.setFillColor(srgb(0x00FF00)); card.fill(CGRect(x: 4, y: 4, width: 4, height: 4))   // top-right
    card.setFillColor(srgb(0x0000FF)); card.fill(CGRect(x: 0, y: 0, width: 4, height: 4))   // bottom-left
    card.setFillColor(srgb(0xFFFFFF)); card.fill(CGRect(x: 4, y: 0, width: 4, height: 4))   // bottom-right
    guard let image = card.makeImage(),
          let done = warp(image, tl: CGPoint(x: 0, y: 80), tr: CGPoint(x: 80, y: 80),
                          bl: CGPoint(x: 0, y: 0), br: CGPoint(x: 80, y: 0)) else { return nil }
    // Sample the centre of the output's top-left quadrant (in the output image's own pixels).
    let qx = max(0, min(done.image.width - 1, done.image.width / 4))
    let qy = max(0, min(done.image.height - 1, done.image.height / 4))
    guard let p = pixel(done.image, qx, qy) else { return nil }
    func near(_ r: Int, _ g: Int, _ b: Int) -> Bool { abs(p.r - r) < 90 && abs(p.g - g) < 90 && abs(p.b - b) < 90 }
    if near(255, 0, 0) { return (false, false) }
    if near(0, 0, 255) { return (true, false) }
    if near(0, 255, 0) { return (false, true) }
    if near(255, 255, 255) { return (true, true) }
    return nil
}

struct P3 { var x: Double; var y: Double; var z: Double }

/// The axis-aligned box around some points.
func bounds(_ points: [CGPoint]) -> CGRect {
    guard let first = points.first else { return .zero }
    var lo = first, hi = first
    for p in points {
        lo.x = min(lo.x, p.x); lo.y = min(lo.y, p.y)
        hi.x = max(hi.x, p.x); hi.y = max(hi.y, p.y)
    }
    return CGRect(x: lo.x, y: lo.y, width: hi.x - lo.x, height: hi.y - lo.y)
}

var tabletopReport = ""

func drawTabletop() {
    let iw = shot.width, ih = shot.height
    let aspect = Double(iw) / Double(ih)
    if aspect < 0.55 || aspect > 0.85 {
        FileHandle.standardError.write("store-frame: warning: --tabletop source is \(iw)x\(ih), not a portrait Duo inner capture\n"
            .data(using: .utf8)!)
    }
    var fold = Int((Double(ih) * 1428.0 / 2853.0).rounded())
    if let text = options["fold"], let f = Int(text) { fold = f }
    fold = max(1, min(ih - 1, fold))
    let w = Double(iw)
    let hl = Double(fold)          // the lid: the capture's top part (rows 0 ..< fold)
    let hf = Double(ih - fold)     // the floor: the bottom part
    let angleDeg = max(95, min(170, number("angle", 125)))
    let elevDeg = max(5, min(60, number("elevation", 28)))
    let alpha = angleDeg * Double.pi / 180
    let elev = elevDeg * Double.pi / 180
    let bezel = w * 0.024
    let deviceRadius = w * 0.065
    let screenRadius = max(0, deviceRadius - bezel)
    let distance = max(w, hl + hf) * 3.2            // camera distance from the hinge: mild perspective
    let ce = cos(elev), se = sin(elev)

    guard let convention = warpConvention() else { fail("Core Image perspective warp unavailable") }

    /// The floor half lies on the table (y = 0), reaching toward the viewer (+z); `s` is the distance from the hinge.
    func floorPoint(_ a: Double, _ s: Double) -> P3 { P3(x: a, y: 0, z: s) }
    /// The lid half rises from the hinge at `alpha` from the floor (90° = upright, more = leaning back).
    func lidPoint(_ a: Double, _ s: Double) -> P3 { P3(x: a, y: s * sin(alpha), z: s * cos(alpha)) }
    /// A camera in front of the hinge, `elev` above the table, looking at it; perspective from `distance`.
    func project(_ p: P3) -> CGPoint {
        let zc = p.y * se + p.z * ce
        let yc = p.y * ce - p.z * se
        let k = distance / max(distance - zc, 1)
        return CGPoint(x: p.x * k, y: yc * k)
    }
    /// A half's outline in its plane (a across, s from the hinge): square at the hinge, rounded at the far corners.
    func outline(_ aHalf: Double, _ sMax: Double, _ r: Double) -> [(Double, Double)] {
        var pts: [(Double, Double)] = [(-aHalf, 0)]
        let n = 12
        for i in 0...n {
            let t = Double.pi - Double(i) / Double(n) * Double.pi / 2
            pts.append((-aHalf + r + r * cos(t), sMax - r + r * sin(t)))
        }
        for i in 0...n {
            let t = Double.pi / 2 - Double(i) / Double(n) * Double.pi / 2
            pts.append((aHalf - r + r * cos(t), sMax - r + r * sin(t)))
        }
        pts.append((aHalf, 0))
        return pts
    }

    let floorBody = outline(w / 2 + bezel, hf + bezel, deviceRadius)
    let lidBody = outline(w / 2 + bezel, hl + bezel, deviceRadius)
    let barrelReach = w / 2 + bezel * 1.6
    let barrelWorld = [P3(x: -barrelReach, y: 0, z: 0), P3(x: barrelReach, y: 0, z: 0)]

    // Fit the projected device into the picture box (a little headroom below for the table shadow).
    var raw: [CGPoint] = barrelWorld.map(project)
    raw += floorBody.map { project(floorPoint($0.0, $0.1)) }
    raw += lidBody.map { project(lidPoint($0.0, $0.1)) }
    let minX = raw.map(\.x).min() ?? 0, maxX = raw.map(\.x).max() ?? 1
    let minY = raw.map(\.y).min() ?? 0, maxY = raw.map(\.y).max() ?? 1
    let box = cg(pictureBox)
    let fitBox = CGRect(x: box.minX, y: box.minY + box.height * 0.06, width: box.width, height: box.height * 0.90)
    let scale = min(fitBox.width / max(maxX - minX, 1), fitBox.height / max(maxY - minY, 1))
    let midX = (minX + maxX) / 2, midY = (minY + maxY) / 2
    func place(_ q: CGPoint) -> CGPoint {
        CGPoint(x: fitBox.midX + (q.x - midX) * scale, y: fitBox.midY + (q.y - midY) * scale)
    }
    func onFloor(_ a: Double, _ s: Double) -> CGPoint { place(project(floorPoint(a, s))) }
    func onLid(_ a: Double, _ s: Double) -> CGPoint { place(project(lidPoint(a, s))) }
    func path(_ pts: [(Double, Double)], _ map: (Double, Double) -> CGPoint) -> CGPath {
        let p = CGMutablePath()
        for (i, q) in pts.enumerated() {
            if i == 0 { p.move(to: map(q.0, q.1)) } else { p.addLine(to: map(q.0, q.1)) }
        }
        p.closeSubpath()
        return p
    }
    let floorBodyPath = path(floorBody, onFloor)
    let lidBodyPath = path(lidBody, onLid)
    let floorScreenPath = path(outline(w / 2, hf, screenRadius), onFloor)
    let lidScreenPath = path(outline(w / 2, hl, screenRadius), onLid)
    let deviceBounds = floorBodyPath.boundingBox.union(lidBodyPath.boundingBox)
    let thickness = max(2, CGFloat(w * 0.016) * CGFloat(scale))

    // Table shadow: a soft ellipse under the floor half.
    if let ground = CGGradient(colorsSpace: space, colors: [srgb(0x000000, 0.55), srgb(0x000000, 0)] as CFArray,
                               locations: [0, 1]) {
        let fb = floorBodyPath.boundingBox
        ctx.saveGState()
        ctx.translateBy(x: fb.midX, y: fb.midY - thickness)
        ctx.scaleBy(x: fb.width * 0.62, y: fb.height * 0.70)
        ctx.drawRadialGradient(ground, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 1, options: [])
        ctx.restoreGState()
    }

    // The hinge barrel: a metal bar along the fold, behind the halves, showing past the side bezels.
    let b0 = place(project(barrelWorld[0])), b1 = place(project(barrelWorld[1]))
    if let metal = CGGradient(colorsSpace: space,
                              colors: [srgb(0x0C1015), srgb(0x5C6470), srgb(0x2A3038), srgb(0x0C1015)] as CFArray,
                              locations: [0, 0.38, 0.62, 1]) {
        let barrelH = max(2, CGFloat(bezel * 1.7) * CGFloat(scale))
        let barrelRect = CGRect(x: min(b0.x, b1.x), y: min(b0.y, b1.y) - barrelH / 2,
                                width: abs(b1.x - b0.x), height: barrelH + abs(b1.y - b0.y))
        let corner = max(0, min(barrelRect.width * 0.49, barrelRect.height * 0.49))
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: barrelRect, cornerWidth: corner, cornerHeight: corner, transform: nil))
        ctx.clip()
        ctx.drawLinearGradient(metal, start: CGPoint(x: barrelRect.midX, y: barrelRect.maxY),
                               end: CGPoint(x: barrelRect.midX, y: barrelRect.minY), options: [])
        ctx.restoreGState()
    }

    // The body: one soft drop shadow for both halves, the floor half's front edge (a darker copy a little lower), then
    // each half's bezel (the lid faces the candle light).
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -H * 0.010), blur: H * 0.035, color: srgb(0x000000, 0.55))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.addPath(floorBodyPath)
    ctx.addPath(lidBodyPath)
    ctx.setFillColor(srgb(bezelDark))
    ctx.fillPath()
    ctx.endTransparencyLayer()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.translateBy(x: 0, y: -thickness)
    ctx.addPath(floorBodyPath)
    ctx.setFillColor(srgb(edgeDark))
    ctx.fillPath()
    ctx.restoreGState()
    for (bodyPath, colour) in [(lidBodyPath, bezelLit), (floorBodyPath, bezelDark)] {
        ctx.saveGState()
        ctx.addPath(bodyPath)
        ctx.setFillColor(srgb(colour))
        ctx.fillPath()
        ctx.addPath(bodyPath)
        ctx.setStrokeColor(srgb(0xFFFFFF, 0.12))
        ctx.setLineWidth(max(1, W * 0.0016))
        ctx.strokePath()
        ctx.restoreGState()
    }

    // The screens: each part of the capture, only warped (true perspective), clipped to the display's outline.
    // CGImage cropping counts rows from the top: the lid is rows 0 ..< fold, the floor fold ..< ih.
    guard let lidHalf = shot.cropping(to: CGRect(x: 0, y: 0, width: iw, height: fold)),
          let floorHalf = shot.cropping(to: CGRect(x: 0, y: fold, width: iw, height: ih - fold)) else {
        fail("cannot split the capture at y=\(fold)")
    }
    var extentOK = true
    func drawHalf(_ half: CGImage, _ clip: CGPath, tl: CGPoint, tr: CGPoint, bl: CGPoint, br: CGPoint) {
        var c = (tl: tl, tr: tr, bl: bl, br: br)
        if convention.flipV { c = (tl: c.bl, tr: c.br, bl: c.tl, br: c.tr) }
        if convention.flipH { c = (tl: c.tr, tr: c.tl, bl: c.br, br: c.bl) }
        guard let done = warp(half, tl: c.tl, tr: c.tr, bl: c.bl, br: c.br) else { fail("perspective warp failed") }
        let expected = bounds([tl, tr, bl, br])
        if abs(done.rect.minX - expected.minX) > 4 || abs(done.rect.maxX - expected.maxX) > 4
            || abs(done.rect.minY - expected.minY) > 4 || abs(done.rect.maxY - expected.maxY) > 4 {
            extentOK = false
        }
        ctx.saveGState()
        ctx.addPath(clip)
        ctx.clip()
        ctx.setFillColor(srgb(0x000000))      // the panel is black glass behind the picture
        ctx.fill(clip.boundingBox)
        ctx.draw(done.image, in: done.rect)
        ctx.restoreGState()
    }
    // The lid: the image's top edge is the far edge (s = hl), its bottom edge the hinge.
    drawHalf(lidHalf, lidScreenPath, tl: onLid(-w / 2, hl), tr: onLid(w / 2, hl),
             bl: onLid(-w / 2, 0), br: onLid(w / 2, 0))
    // The floor: the image's top edge is the hinge, its bottom edge the edge nearest the player (s = hf).
    drawHalf(floorHalf, floorScreenPath, tl: onFloor(-w / 2, 0), tr: onFloor(w / 2, 0),
             bl: onFloor(-w / 2, hf), br: onFloor(w / 2, hf))

    // The hinge seam through the side bezels (never over the screen).
    ctx.saveGState()
    ctx.setStrokeColor(srgb(0x000000, 0.70))
    ctx.setLineWidth(max(1, W * 0.0018))
    ctx.move(to: onFloor(-w / 2, 0)); ctx.addLine(to: onFloor(-w / 2 - bezel, 0))
    ctx.move(to: onFloor(w / 2, 0)); ctx.addLine(to: onFloor(w / 2 + bezel, 0))
    ctx.strokePath()
    ctx.restoreGState()

    let flips = (convention.flipV ? "V" : "") + (convention.flipH ? "H" : "")
    tabletopReport = " angle=\(Int(angleDeg.rounded())) elevation=\(Int(elevDeg.rounded())) fold=\(fold)"
        + " warp=\(flips.isEmpty ? "ok" : "flip" + flips)" + " extent=\(extentOK ? "ok" : "mismatch")"
        + (usedSoftwareCI ? " ci=software" : "")
        + " device=\(Int(deviceBounds.width))x\(Int(deviceBounds.height))"
}

if tabletopMode { drawTabletop() } else { drawFlat() }

// MARK: Caption (Core Text, laid out top-down, drawn in Core Graphics coordinates)

struct Seg { var text: String; var hi: Bool }
typealias Token = [Seg]          // one unbreakable word (a `*highlighted phrase*` stays in one token)
typealias Words = [Token]

/// Splits on spaces outside `*…*`; `*` toggles the highlight and is never drawn.
func tokenize(_ text: String) -> Words {
    var tokens: Words = []
    var current: Token = []
    var buffer = ""
    var hi = false
    func flushSeg() {
        if !buffer.isEmpty { current.append(Seg(text: buffer, hi: hi)); buffer = "" }
    }
    for ch in text {
        if ch == "*" { flushSeg(); hi.toggle(); continue }
        if ch == " " && !hi {
            flushSeg()
            if !current.isEmpty { tokens.append(current); current = [] }
            continue
        }
        buffer.append(ch)
    }
    flushSeg()
    if !current.isEmpty { tokens.append(current) }
    return tokens
}

let fontKey = NSAttributedString.Key(rawValue: kCTFontAttributeName as String)
let colorKey = NSAttributedString.Key(rawValue: kCTForegroundColorAttributeName as String)
let kernKey = NSAttributedString.Key(rawValue: kCTKernAttributeName as String)

struct Style { var font: CTFont; var color: CGColor; var hiColor: CGColor; var kern: CGFloat }

/// One line's attributed string and its highlighted UTF-16 ranges (highlighted letters in `hiColor`).
func attributed(_ words: Words, _ style: Style) -> (text: NSAttributedString, highlights: [NSRange]) {
    let result = NSMutableAttributedString()
    var highlights: [NSRange] = []
    let kern = NSNumber(value: Double(style.kern))
    let plain: [NSAttributedString.Key: Any] = [fontKey: style.font, colorKey: style.color, kernKey: kern]
    let lit: [NSAttributedString.Key: Any] = [fontKey: style.font, colorKey: style.hiColor, kernKey: kern]
    for (i, token) in words.enumerated() {
        if i > 0 { result.append(NSAttributedString(string: " ", attributes: plain)) }
        for seg in token {
            if seg.hi { highlights.append(NSRange(location: result.length, length: (seg.text as NSString).length)) }
            result.append(NSAttributedString(string: seg.text, attributes: seg.hi ? lit : plain))
        }
    }
    return (result, highlights)
}

func measure(_ words: Words, _ style: Style) -> CGFloat {
    let line = CTLineCreateWithAttributedString(attributed(words, style).text as CFAttributedString)
    return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
}

func greedy(_ words: Words, _ limit: CGFloat, _ style: Style) -> [Words] {
    var lines: [Words] = []
    var current: Words = []
    for token in words {
        if current.isEmpty || measure(current + [token], style) <= limit {
            current.append(token)
        } else {
            lines.append(current)
            current = [token]
        }
    }
    if !current.isEmpty { lines.append(current) }
    return lines
}

/// As many lines as a greedy wrap needs, at the narrowest width that keeps that count (even lines, no orphan).
func balanced(_ words: Words, _ width: CGFloat, _ style: Style) -> [Words] {
    guard words.count > 1, measure(words, style) > width else { return [words] }
    let count = greedy(words, width, style).count
    var lo: CGFloat = 0
    var hi = width
    for _ in 0..<18 {
        let mid = (lo + hi) / 2
        if greedy(words, mid, style).count <= count { hi = mid } else { lo = mid }
    }
    return greedy(words, hi, style)
}

/// Balanced lines, preferring a break after a sentence (". ", "! ", "? ", ": ") when that costs no extra line.
func wrap(_ words: Words, _ width: CGFloat, _ style: Style, sentenceBreaks: Bool) -> [Words] {
    let plain = balanced(words, width, style)
    guard sentenceBreaks, plain.count > 1, words.count > 1 else { return plain }
    func widest(_ lines: [Words]) -> CGFloat { lines.map { measure($0, style) }.max() ?? 0 }
    var chosen = plain
    var chosenIsSentence = false
    for i in 0..<(words.count - 1) {
        guard let last = words[i].last?.text.last, ".!?:".contains(last) else { continue }
        let option = balanced(Array(words[...i]), width, style) + balanced(Array(words[(i + 1)...]), width, style)
        guard option.count <= plain.count else { continue }
        if !chosenIsSentence || widest(option) < widest(chosen) {
            chosen = option
            chosenIsSentence = true
        }
    }
    return chosen
}

struct Laid {
    var lines: [CTLine] = []
    var highlights: [[NSRange]] = []
    var widths: [CGFloat] = []
    var lineHeight: CGFloat = 0
    var ascentShare: CGFloat = 0.8
    var size: CGFloat = 0
    var capHeight: CGFloat = 0
    var height: CGFloat { lineHeight * CGFloat(lines.count) }
}

func lay(_ words: Words, _ style: Style, width: CGFloat, sentenceBreaks: Bool, leading: CGFloat) -> Laid {
    var laid = Laid()
    let ascent = CTFontGetAscent(style.font), descent = CTFontGetDescent(style.font)
    laid.lineHeight = (ascent + descent) * leading
    laid.ascentShare = ascent / max(ascent + descent, 1)
    laid.size = CTFontGetSize(style.font)
    laid.capHeight = CTFontGetCapHeight(style.font)
    for lineWords in wrap(words, width, style, sentenceBreaks: sentenceBreaks) {
        let (text, highlights) = attributed(lineWords, style)
        let line = CTLineCreateWithAttributedString(text as CFAttributedString)
        laid.lines.append(line)
        laid.highlights.append(highlights)
        laid.widths.append(CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)))
    }
    return laid
}

var usedRounded = true
func roundedFont(_ size: CGFloat, _ weight: NSFont.Weight) -> CTFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    if let descriptor = base.fontDescriptor.withDesign(.rounded),
       let font = NSFont(descriptor: descriptor, size: size) {
        return font as CTFont
    }
    usedRounded = false
    return base as CTFont
}

// Portrait: the type follows the width (cap height 7.2 % of W, shrinking in 5 % steps to a 4.6 % floor).
// R15 banners: the type follows the band's height (header: a big wordmark-sized headline; search: one line).
let capStart: CGFloat = bannerKind == "header" ? H * 0.17 : (bannerKind == "search" ? H * 0.072 : W * 0.072)
let capFloor: CGFloat = bannerKind == "header" ? H * 0.07 : (bannerKind == "search" ? H * 0.04 : W * 0.046)
let maxHeadLines = bannerKind == "search" ? 1 : 2
let maxSubLines = 2

var reportCap: CGFloat = 0
var reportLines = 0
var reportFont = ""

func drawLaid(_ laid: Laid, top: CGFloat) {
    for (i, line) in laid.lines.enumerated() {
        let lineTop = top + CGFloat(i) * laid.lineHeight
        let baseline = lineTop + laid.lineHeight * laid.ascentShare     // top-left origin
        let x = band.midX - laid.widths[i] / 2
        let baseCG = H - baseline
        for range in laid.highlights[i] {
            // The marker swash: ink letters on candle gold, slightly tilted like a highlighter stroke.
            let x0 = CTLineGetOffsetForStringIndex(line, range.location, nil)
            let x1 = CTLineGetOffsetForStringIndex(line, range.location + range.length, nil)
            let pad = laid.size * 0.10
            let swash = CGRect(x: x + x0 - pad, y: baseCG - laid.size * 0.15,
                               width: (x1 - x0) + pad * 2, height: laid.capHeight + laid.size * 0.30)
            ctx.saveGState()
            ctx.translateBy(x: swash.midX, y: swash.midY)
            ctx.rotate(by: 0.018)
            let local = CGRect(x: -swash.width / 2, y: -swash.height / 2, width: swash.width, height: swash.height)
            let corner = max(0, min(swash.height * 0.28, swash.width * 0.49, swash.height * 0.49))
            ctx.addPath(CGPath(roundedRect: local, cornerWidth: corner, cornerHeight: corner, transform: nil))
            ctx.setFillColor(srgb(candleGold))
            ctx.fillPath()
            ctx.restoreGState()
        }
        ctx.saveGState()
        ctx.textMatrix = .identity
        ctx.textPosition = CGPoint(x: x, y: baseCG)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
}

if !rawCaption.trimmingCharacters(in: .whitespaces).isEmpty {
    let parts = rawCaption.components(separatedBy: " / ")
    let headWords = tokenize(parts[0])
    let subText: String? = parts.count > 1 ? parts.dropFirst().joined(separator: " / ") : nil
    let subWords = subText.map { tokenize($0.replacingOccurrences(of: "*", with: "")) } ?? []

    let probe = roundedFont(100, .heavy)
    let capRatio = max(CTFontGetCapHeight(probe) / 100, 0.5)

    var cap = capStart
    var head = Laid()
    var sub: Laid? = nil
    var gap: CGFloat = 0
    while true {
        let size = cap / capRatio
        let headStyle = Style(font: roundedFont(size, .heavy), color: srgb(parchment), hiColor: srgb(ink),
                              kern: -0.008 * size)
        head = lay(headWords, headStyle, width: band.width, sentenceBreaks: true, leading: 0.94)
        sub = nil
        if !subWords.isEmpty {
            let subStyle = Style(font: roundedFont(size * 0.46, .semibold), color: srgb(warmGrey), hiColor: srgb(warmGrey),
                                 kern: 0)
            sub = lay(subWords, subStyle, width: band.width * 0.96, sentenceBreaks: true, leading: 1.08)
        }
        gap = sub == nil ? 0 : size * 0.30
        let total = head.height + gap + (sub?.height ?? 0)
        let fits = head.lines.count <= maxHeadLines && (sub?.lines.count ?? 0) <= maxSubLines && total <= band.height
        if fits || cap <= capFloor { break }
        cap = max(capFloor, cap * 0.95)
    }

    let total = head.height + gap + (sub?.height ?? 0)
    let top = max(band.minY, band.midY - total / 2)
    drawLaid(head, top: top)
    if let sub { drawLaid(sub, top: top + head.height + gap) }

    reportCap = cap
    reportLines = head.lines.count
    reportFont = CTFontCopyPostScriptName(roundedFont(10, .heavy)) as String
}

// MARK: Output (opaque sRGB PNG, no alpha)

guard let flat = ctx.makeImage(),
      let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL, "public.png" as CFString,
                                                        1, nil) else { fail("cannot create \(output)") }
CGImageDestinationAddImage(destination, flat, nil)
guard CGImageDestinationFinalize(destination) else { fail("cannot write \(output)") }
let capPercent = String(format: "%.1f", Double(reportCap / W * 100))
let layoutName = bannerKind.isEmpty ? "top" : "banner-\(bannerKind)"
print("store-frame: \(output) \(width)x\(height) mode=\(tabletopMode ? "tabletop" : "flat") layout=\(layoutName) "
      + "cap=\(capPercent)%W lines=\(reportLines) font=\(reportFont.isEmpty ? "-" : reportFont) "
      + "rounded=\(usedRounded ? "yes" : "no")" + tabletopReport)

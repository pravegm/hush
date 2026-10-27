// badges.swift: collects Hush's 12 Game Center achievement images for asc.swift.
// Copied into pravegm/hush on 27 Oct 2026 from Brim (pravegm/brim, tools/appstore/badges.swift) and adapted: 12 IDs,
// Hush paths, the IDs read from GameCenterManager or (fallback) the literal "hush.ach.*" strings in Hush/Core, the
// dungeon background #12161C, and a 4 x 3 contact sheet. Brim's notes below still describe how it works.
//
//   xcrun swift tools/appstore/badges.swift --from <dir> [--out <dir>]
//
// Hush draws its badges itself (Hush/UI/AchievementArt.swift, AchievementBadge, as Brim does). Every CI
// run (ci.yml) plays a `NN-badges` scenario (demo key screen=badges, Hush/App/DemoMode.swift), which writes
// Documents/badges/<id>.png
// at 1024 x 1024; ci/screenshots.sh copies them into the `screenshots` artifact, folder badges/. Point --from at that
// folder. This script does not redraw anything: it
//   1. checks the IDs: the PNG names must equal GameCenterManager.achievementIDs (Hush/App/GameCenterManager.swift;
//      if that isn't a literal list, the "hush.ach.*" strings in Hush/Core/Ranks.swift or Achievements.swift),
//      the IDs in docs/appstore/achievements.md and, if it exists, the achievements in docs/appstore/asc-metadata.json;
//   2. checks each image is 1024 x 1024;
//   3. writes it to <out>/<id>.png as an opaque sRGB PNG at 72 ppi. The app's renderer writes RGBA; Game Center asks
//      for RGB without transparency, so the alpha channel is dropped. Any pixel that isn't fully opaque is first
//      composited onto the dungeon teal-black #12161C (Hush's background), and the count is printed (0 expected).
//   4. writes <out>/preview.png, a 4 x 3 contact sheet.
// Default <out> is tools/appstore/badges. Exits 1 on any mismatch or unreadable image.

import CoreGraphics
import Foundation
import ImageIO

let scriptURL = URL(fileURLWithPath: #filePath).standardizedFileURL
let scriptDir = scriptURL.deletingLastPathComponent()
let repoRoot: URL = {
    if let r = ProcessInfo.processInfo.environment["ASC_REPO_ROOT"], !r.isEmpty { return URL(fileURLWithPath: r) }
    let guess = scriptDir.deletingLastPathComponent().deletingLastPathComponent()
    if FileManager.default.fileExists(atPath: guess.appendingPathComponent("project.yml").path) { return guess }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
}()

func fail(_ s: String) -> Never {
    FileHandle.standardError.write("error: \(s)\n".data(using: .utf8)!)
    exit(1)
}

var fromDir: URL? = nil
var outDir = scriptDir.appendingPathComponent("badges")
do {
    var args = Array(CommandLine.arguments.dropFirst())
    while !args.isEmpty {
        let a = args.removeFirst()
        switch a {
        case "--from":
            guard !args.isEmpty else { fail("--from needs a directory") }
            fromDir = URL(fileURLWithPath: args.removeFirst())
        case "--out":
            guard !args.isEmpty else { fail("--out needs a directory") }
            outDir = URL(fileURLWithPath: args.removeFirst())
        case "-h", "--help":
            print("usage: xcrun swift tools/appstore/badges.swift --from <screenshots artifact>/badges [--out <dir>]")
            exit(0)
        default:
            fail("unknown argument \(a)")
        }
    }
}

// MARK: - The IDs, from three places

func quoted(_ s: Substring) -> [String] {
    var found: [String] = []
    var rest = s
    while let open = rest.firstIndex(of: "\"") {
        let after = rest.index(after: open)
        guard let close = rest[after...].firstIndex(of: "\"") else { break }
        found.append(String(rest[after..<close]))
        rest = rest[rest.index(after: close)...]
    }
    return found
}

/// The achievement IDs in Hush/Core (where Achievements.all lives), in file order. Ranks.swift (27 Oct 2026) builds
/// each as "hush.ach." + key through `def("key", "Title", "Detail")`, so the `def("…"` keys are read and prefixed;
/// failing that, IDs written out in full ("hush.ach.<key>"). Interpolated IDs can't be read. Same rule as asc.swift.
func coreIDs() -> [String] {
    let prefix = "hush.ach."
    func isKey(_ s: String) -> Bool { s.range(of: "^[A-Za-z0-9_.]+$", options: .regularExpression) != nil }
    var fromDefs: [String] = []
    var literal: [String] = []
    for p in ["Hush/Core/Ranks.swift", "Hush/Core/Achievements.swift"] {
        guard let text = try? String(contentsOf: repoRoot.appendingPathComponent(p), encoding: .utf8) else { continue }
        for part in text.components(separatedBy: "def(\"").dropFirst() {
            guard let end = part.firstIndex(of: "\"") else { continue }
            let key = String(part[..<end])
            let id = key.hasPrefix(prefix) ? key : prefix + key
            if isKey(key) && !fromDefs.contains(id) { fromDefs.append(id) }
        }
        // Comments such as `"hush.ach.<key>"` are skipped by isKey (letters, digits, `_` and `.` only).
        for s in quoted(Substring(text)) where s.hasPrefix(prefix) && s.count > prefix.count && isKey(s) && !literal.contains(s) {
            literal.append(s)
        }
    }
    return fromDefs.isEmpty ? literal : fromDefs
}

func appIDs() -> [String] {
    let url = repoRoot.appendingPathComponent("Hush/App/GameCenterManager.swift")
    // `static let achievementIDs: [String] = [ ... ]` (Brim): the list starts after "= [" on the declaration's line.
    // Swoop-style managers build it from Core (`= Achievements.all.map …`); then read Core's literal IDs instead.
    if let text = try? String(contentsOf: url, encoding: .utf8), let start = text.range(of: "static let achievementIDs") {
        let declaration = text[start.lowerBound...].prefix(while: { !$0.isNewline })
        if let open = declaration.range(of: "= [") {
            let tail = text[open.upperBound...]
            guard let close = tail.firstIndex(of: "]") else { fail("\(url.path): achievementIDs list not closed") }
            let ids = quoted(tail[..<close])
            if !ids.isEmpty { return ids }
        }
    }
    let ids = coreIDs()
    if ids.isEmpty { fail("no achievement IDs: neither a literal GameCenterManager.achievementIDs list nor def(\"key\" / \"hush.ach.*\" strings in Hush/Core") }
    return ids
}

func docIDs() -> [String] {
    let url = repoRoot.appendingPathComponent("docs/appstore/achievements.md")
    guard let text = try? String(contentsOf: url, encoding: .utf8) else { fail("\(url.path) not found") }
    // Table rows: | 1 | `hush.ach.first` | ...
    return text.components(separatedBy: .newlines).compactMap { line in
        guard line.range(of: "^\\| [0-9]+ \\| `", options: .regularExpression) != nil else { return nil }
        let cells = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        return cells.count > 1 ? cells[1].replacingOccurrences(of: "`", with: "") : nil
    }
}

func metadataIDs() -> [String]? {
    let url = repoRoot.appendingPathComponent("docs/appstore/asc-metadata.json")
    guard let data = try? Data(contentsOf: url),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let list = root["achievements"] as? [[String: Any]] else { return nil }
    return list.compactMap { $0["vendorIdentifier"] as? String }
}

let ids = appIDs()
guard ids.count == 12 else { fail("the app has \(ids.count) achievement IDs, expected 12") }
var mismatch = false
func compare(_ name: String, _ other: [String]?) {
    guard let other = other else { print("  \(name): not found, skipped"); return }
    let a = Set(ids), b = Set(other)
    if a == b && other.count == ids.count { print("  \(name): same 12 IDs"); return }
    mismatch = true
    print("  \(name): MISMATCH. Missing: \(a.subtracting(b).sorted().joined(separator: ", ")). Extra: \(b.subtracting(a).sorted().joined(separator: ", "))")
}
print("IDs (the app): \(ids.joined(separator: ", "))")
compare("docs/appstore/achievements.md", docIDs())
compare("docs/appstore/asc-metadata.json", metadataIDs())

guard let from = fromDir else {
    if mismatch { fail("achievement IDs differ") }
    print("No --from given: IDs checked, no images collected.")
    exit(0)
}
let files = ((try? FileManager.default.contentsOfDirectory(atPath: from.path)) ?? []).filter { $0.hasSuffix(".png") }
compare("\(from.path) (rendered by the app)", files.map { String($0.dropLast(4)) })
if mismatch { fail("achievement IDs differ") }

// MARK: - Flatten and write

let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

func load(_ url: URL) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

/// Number of pixels whose alpha is below 255.
func translucentPixels(_ image: CGImage) -> Int {
    let w = image.width, h = image.height
    var buf = [UInt8](repeating: 0, count: w * h * 4)
    let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: srgb,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    var n = 0
    var i = 3
    while i < buf.count { if buf[i] < 255 { n += 1 }; i += 4 }
    return n
}

func opaqueCopy(_ image: CGImage, size: Int) -> CGImage {
    // noneSkipLast: RGB with no alpha channel in the written PNG.
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.setFillColor(CGColor(srgbRed: 0x12 / 255.0, green: 0x16 / 255.0, blue: 0x1C / 255.0, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { fail("can't write \(url.path)") }
    let props: [CFString: Any] = [kCGImagePropertyDPIWidth: 72, kCGImagePropertyDPIHeight: 72, kCGImagePropertyHasAlpha: false]
    CGImageDestinationAddImage(dest, image, props as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { fail("can't finalise \(url.path)") }
}

/// Bytes 25 (colour type) of the IHDR chunk: 2 = RGB, 6 = RGBA.
func pngColourType(_ url: URL) -> UInt8? {
    guard let d = try? Data(contentsOf: url), d.count > 25 else { return nil }
    return d[25]
}

try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
var flattened: [CGImage] = []
var failed = false
for id in ids {
    let src = from.appendingPathComponent("\(id).png")
    guard let img = load(src) else { print("  \(id): can't read \(src.path)"); failed = true; continue }
    guard img.width == 1024 && img.height == 1024 else { print("  \(id): \(img.width)x\(img.height), Game Center needs 1024x1024"); failed = true; continue }
    let translucent = translucentPixels(img)
    let opaque = opaqueCopy(img, size: 1024)
    let dst = outDir.appendingPathComponent("\(id).png")
    writePNG(opaque, to: dst)
    let bytes = (try? FileManager.default.attributesOfItem(atPath: dst.path)[.size] as? Int) ?? 0
    let ct = pngColourType(dst).map { $0 == 2 ? "RGB" : "colour type \($0)" } ?? "?"
    print("  \(id): 1024x1024, \(translucent) translucent px\(translucent > 0 ? " flattened onto #12161C" : ""), wrote \(ct) PNG \(bytes / 1024) KB")
    if pngColourType(dst) != 2 { print("  \(id): the written PNG is not plain RGB"); failed = true }
    flattened.append(opaque)
}
if failed { fail("some badges could not be collected") }

// Contact sheet: 4 x 3 at 256 px with 16 px gaps.
let cell = 256, gap = 16, cols = 4, rows = 3
let sheetW = cols * cell + (cols + 1) * gap, sheetH = rows * cell + (rows + 1) * gap
let sheet = CGContext(data: nil, width: sheetW, height: sheetH, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
sheet.setFillColor(CGColor(srgbRed: 0.17, green: 0.13, blue: 0.2, alpha: 1))
sheet.fill(CGRect(x: 0, y: 0, width: sheetW, height: sheetH))
sheet.interpolationQuality = .high
for (i, img) in flattened.enumerated() {
    let c = i % cols, r = i / cols
    let x = gap + c * (cell + gap), y = sheetH - (gap + (r + 1) * cell + r * gap)
    sheet.draw(img, in: CGRect(x: x, y: y, width: cell, height: cell))
}
writePNG(sheet.makeImage()!, to: outDir.appendingPathComponent("preview.png"))
print("OK: \(flattened.count) badges in \(outDir.path) (+ preview.png)")

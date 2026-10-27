import SwiftUI
import UIKit

// MARK: - Demo mode (CI screenshots, design review). Active in DEBUG builds only: `current` is nil in Release.
//
// Launch argument: `-hushDemo "key=value;key;key=value"` (ci/scenarios.txt, ci/duo.sh). Values can't contain `;`.
// Unknown keys are ignored. Every line CI greps starts with `HUSH-` (never rename them).
//
// Keys (design/ROUND-1.md)
// - `screen=home|run|results|codex|settings|lesson|pose|cover|icon|daily`
//     home      Home (the title chest follows the hinge, or holds at `lid=`).
//     run       straight into play of `mode` (default run). Implied by `mode=` without `screen`.
//     results   the Results screen for `mode`: a REAL run of it played headless at launch by the pilot (`pilot=`,
//               default casual) and recorded into the demo progress, so best, rank and relics are all true.
//     codex / settings / daily   those pages.
//     lesson    the First Chest lesson (at `lessonStep=`, default 1).
//     pose      force the "Stand it up like a little laptop" card (over `mode` if given, else Home).
//     cover     force the cover-display card (the sleeping mimic, "Open to carry on").
//     icon      render AppIconArt to Documents/AppIcon-1024.png (`HUSH-T icon ok 1024x1024`, `HUSH-ICON <path>`)
//               and show it full screen. `HUSH_ICON=1` in the environment does the same without `-hushDemo`.
// - `mode=run|daily|attract`      the run mode (`daily` = today's scored try; `attract` never ends, never bites).
// - `seed=<n>`                    the run seed (default 7 for run/attract, so frames are stable; daily = today's).
// - `pilot=novice|casual|expert|perfect`   ThiefPilot drives the lid and the touches (fed in as real touches).
//                                 Without it `screen=run` takes the real hinge (Duo CI) or the slider.
// - `progress=fresh|mid|late`     seeded in-memory progress (fresh: nothing; mid: rank 4, 9 relics, best 2,400;
//                                 late: rank 10, 22 relics, best 9,800). Demo runs never write UserDefaults.
// - `freezeOn=ready|reveal|stirring|waking|bite|bank|relic|torchLow|torchOut|results`
//                                 stop stepping the session (the scene keeps drawing) at the first such moment, and
//                                 print `HUSH-T freeze <tag>`. Moments that are events (bite, bank, relic, torchLow,
//                                 torchOut) hold 0.3 s after the event so their FX are on screen.
// - `freezeAfter=<s>`             freeze after s seconds of play (`HUSH-T freeze after`); with `freezeOn`, the
//                                 moment only counts once s seconds have passed.
// - `lid=<0…1>`                   hold the lid at this openness (no pilot, no hinge; shut for the first 0.25 s so the
//                                 chest opens): static frames.
// - `noise=<0…1>`                 hold the noise at this level (stage frames).
// - `lessonStep=<1…6>`            start the lesson at that step.
// - `turn=0|1`                    force "Turn the chest round" off or on.
// - `fold=1`                      lay out as if a fold exists (phone sims; Duo-layout frames).
// - `sound=0`                     mute.
// - `orient=portrait|landscape`   ask iOS for that interface orientation at launch (re-asked every 2 s; the Duo
//                                 simulator boots in book pose). `HUSH-T orient <o> ok|failed|lost`.
// - `screen=badges`               render every achievement badge to Documents/badges/<gc id>.png
//                                 (`HUSH-T badges done <n>`), then Home.
// Extra keys
// - `skipTo=<s>`                  `screen=run`: play the first s seconds headless (pilot, default expert) first, so
//                                 late moments (`freezeOn=torchLow`) don't take real minutes. `HUSH-T skipped <s>`.
//
// Log lines: `HUSH-T demo '<args>' starts`, `HUSH-T canvas <w>x<h> fold=<0|1> turned=<0|1>`,
// `HUSH-T input hinge|slider|pilot|fixed`, `HUSH-T lid …` (10 Hz in play), `HUSH-T event <name> …`,
// `HUSH-T paused closing|menu|background|pose`, `HUSH-T resumed`, `HUSH-T freeze <tag>`, `HUSH-T frame 120`,
// `HUSH-T screen <route>`, `HUSH-T run gold=<g> chests=<n> bites=<b> seconds=<s>`, `HUSH-T icon ok|failed`.
// (`HUSH-H <t> <angle>` hinge samples come from Feel's HingeReader.)

struct DemoMode: Equatable {
    enum Screen: String, Equatable, CaseIterable {
        case home, run, results, codex, settings, lesson, pose, cover, icon, daily, badges
    }
    enum ModeKey: String, Equatable { case run, daily, attract }
    enum Freeze: String, Equatable, CaseIterable {
        case ready, reveal, stirring, waking, bite, bank, relic, torchLow, torchOut, results

        /// Event moments hold a beat after the event; state moments freeze at once.
        var isEvent: Bool {
            switch self {
            case .bite, .bank, .relic, .torchLow, .torchOut: return true
            case .ready, .reveal, .stirring, .waking, .results: return false
            }
        }
    }
    enum Preset: String, Equatable { case fresh, mid, late }
    enum Orient: String, Equatable { case portrait, landscape }

    static let defaultSeed: UInt64 = 7
    static let freezeEventDelay: Double = 0.3

    var raw: String
    var screen: Screen?
    var mode: ModeKey?
    var seed: UInt64?
    var pilot: PilotSkill?
    var progress: Preset?
    var freezeOn: Freeze?
    /// `freezeAfter=` (the field is named apart from the key: the TestFlight demo guard greps Release for the key).
    var holdAfter: Double?
    var lid: Double?
    var noise: Double?
    var lessonStep: Int?
    var turn: Bool?
    var fold = false
    var sound = true
    var skipTo: Double?
    var orient: Orient?

    init(raw: String) { self.raw = raw }

    /// The screen the app opens on.
    var effectiveScreen: Screen {
        if let screen { return screen }
        return mode == nil ? .home : .run
    }

    /// The run `mode=` asks for (`daily` = today's scored try; default run).
    func runMode(today: Int) -> RunMode {
        switch mode ?? .run {
        case .run: return .run
        case .daily: return .daily(day: today, scored: true)
        case .attract: return .attract
        }
    }

    #if DEBUG
    private static func flag(_ value: String) -> Bool {
        value.isEmpty || value == "1" || value == "on" || value == "true" || value == "yes"
    }

    private static func number(_ value: String) -> Double? {
        guard let d = Double(value), d.isFinite else { return nil }
        return d
    }

    private static func unit(_ value: String) -> Double? {
        number(value).map { min(max($0, 0), 1) }
    }

    /// Parses `key=value;key` (pure; tested).
    static func parse(_ raw: String) -> DemoMode {
        var config = DemoMode(raw: raw)
        for part in raw.split(separator: ";") {
            let pieces = part.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard let key = pieces.first, !key.isEmpty else { continue }
            let value = pieces.count > 1 ? pieces[1] : ""
            switch key {
            case "screen": config.screen = Screen(rawValue: value.lowercased())
            case "mode": config.mode = ModeKey(rawValue: value.lowercased())
            case "seed": config.seed = UInt64(value)
            case "pilot": config.pilot = PilotSkill(rawValue: value.lowercased())
            case "progress": config.progress = Preset(rawValue: value.lowercased())
            case "freezeOn":
                config.freezeOn = Freeze.allCases.first { $0.rawValue.lowercased() == value.lowercased() }
            case "freezeAfter":
                if let s = number(value) { config.holdAfter = max(s, 0) }
            case "lid": config.lid = unit(value)
            case "noise": config.noise = unit(value)
            case "lessonStep":
                if let n = Int(value) { config.lessonStep = min(max(n, 1), LessonScript.Step.done.rawValue) }
            case "turn": config.turn = flag(value)
            case "fold": config.fold = flag(value)
            case "sound": config.sound = flag(value)
            case "skipTo":
                if let s = number(value) { config.skipTo = max(s, 0) }
            case "orient": config.orient = Orient(rawValue: value.lowercased())
            default: break
            }
        }
        return config
    }
    #endif

    /// The scenario for this launch: DEBUG builds with `-hushDemo` (or `HUSH_ICON=1`) only; nil otherwise.
    static let current: DemoMode? = {
        #if DEBUG
        let raw = UserDefaults.standard.string(forKey: "hushDemo")
        let icon = ProcessInfo.processInfo.environment["HUSH_ICON"] == "1"
        guard raw != nil || icon else { return nil }
        // CI redirects stdout to a file (fully buffered); line-buffer it so the scripts see HUSH- lines on time.
        setvbuf(stdout, nil, _IOLBF, 0)
        var config = DemoMode.parse(raw ?? "")
        if icon { config.screen = .icon }
        return config
        #else
        return nil
        #endif
    }()
}

// MARK: - Seeded progress (`progress=`)

enum DemoPresets {
    static func progress(_ preset: DemoMode.Preset?, today: Int) -> ProgressData {
        var data = ProgressData()
        switch preset ?? .fresh {
        case .fresh:
            return data
        case .mid:
            fill(&data, rank: 4, relics: 9, best: 2_400, runs: 26, today: today, dailies: [1_840, 1_310])
        case .late:
            fill(&data, rank: 10, relics: 22, best: 9_800, runs: 148, today: today,
                 dailies: [7_420, 6_150, 8_030, 5_900])
        }
        return data
    }

    private static func fill(_ data: inout ProgressData, rank: Int, relics: Int, best: Int, runs: Int, today: Int,
                             dailies: [Int]) {
        let top = ThiefRanks.count - 1
        let r = min(max(rank, 0), top)
        let lo = ThiefRanks.threshold(r)
        let hi = r < top ? ThiefRanks.threshold(r + 1) : lo + 1_000
        // A third of the way into the rank, so the Home bar is visibly part-filled.
        data.lifetimeGold = lo + max((hi - lo) / 3, 1)
        data.bestRun = best
        data.runs = runs
        data.chestsOpened = runs * 6
        data.chestsBanked = runs * 5
        data.hushed = runs * 2
        data.bites = runs
        data.itemsBagged = runs * 22
        data.bestChest = best / 3
        data.mostChestsInRun = min(4 + rank / 2, 9)
        data.mostHushedInRun = min(1 + rank / 3, 6)
        let found = Array(RelicCatalog.all.prefix(relics).map(\.id))
        data.foundRelics = Set(found)
        data.relicOrder = found
        data.achievements = Set(Achievements.all.prefix(min(rank, Achievements.all.count)).map(\.id))
        data.lessonDone = true
        for (i, gold) in dailies.enumerated() {
            let day = today - 1 - i
            data.daily[day] = DailyRecord(gold: gold, finished: true, practiceBest: gold / 2)
            data.dailyAttempted.insert(day)
            data.bestDaily = max(data.bestDaily, gold)
        }
        data.lastDailyDay = today - 1
    }
}

// MARK: - App icon render (`screen=icon`, `HUSH_ICON=1`)

@MainActor
enum IconExport {
    static let side: CGFloat = 1024
    static let fileName = "AppIcon-1024.png"

    /// Renders AppIconArt at 1024 × 1024 px, opaque, to Documents/AppIcon-1024.png (CI copies it into
    /// Hush/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png).
    static func render() {
        let renderer = ImageRenderer(content: AppIconArt().frame(width: side, height: side))
        renderer.proposedSize = ProposedViewSize(width: side, height: side)
        renderer.scale = 1
        renderer.isOpaque = true
        guard let cgImage = renderer.cgImage else {
            AppTrace.t("HUSH-T icon failed: renderer returned no image")
            return
        }
        guard let data = opaquePNG(cgImage, side: side),
              let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            AppTrace.t("HUSH-T icon failed: no PNG data")
            return
        }
        let url = directory.appendingPathComponent(fileName)
        do {
            try data.write(to: url)
            AppTrace.t("HUSH-T icon ok \(cgImage.width)x\(cgImage.height)")
            AppTrace.t("HUSH-ICON \(url.path)")
        } catch {
            AppTrace.t("HUSH-T icon failed: \(error.localizedDescription)")
        }
        // The small-size check: the master downsampled as the Home screen shows it.
        var written: [String] = []
        for size in [180, 60, 40] {
            let s = CGFloat(size)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let small = UIGraphicsImageRenderer(size: CGSize(width: s, height: s), format: format).image { _ in
                UIImage(cgImage: cgImage).draw(in: CGRect(x: 0, y: 0, width: s, height: s))
            }
            if let png = small.pngData(),
               (try? png.write(to: directory.appendingPathComponent("AppIcon-\(size).png"))) != nil {
                written.append("\(size)")
            }
        }
        AppTrace.t("HUSH-T icon sizes \(written.joined(separator: ","))")
    }

    /// Redraws into an opaque 1× context so the PNG carries no alpha channel (App Store requirement).
    static func opaquePNG(_ cgImage: CGImage, side: CGFloat) -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            UIImage(cgImage: cgImage).draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        return image.pngData()
    }
}

// MARK: - Orientation (`orient=portrait|landscape`, ported from Brim's DemoOrientation)

/// The Duo simulator boots in book pose and has no CLI rotate, so a tabletop launch asks iOS for portrait itself:
/// re-asked every 2 s until the window fills a portrait screen for 0.8 s, then watched (re-asked if it is lost) for
/// 10 minutes. Logs `HUSH-T orient <o> ok …`, `HUSH-T orient <o> lost …`, `HUSH-T orient <o> failed after 30s …`.
@MainActor
enum DemoOrientation {
    private static var started = false

    static func request(_ orient: DemoMode.Orient) {
        guard !started else { return }
        started = true
        let mask: UIInterfaceOrientationMask = orient == .portrait ? .portrait : .landscape
        let name = orient.rawValue
        AppTrace.t("HUSH-T orient \(name) requested")
        Task { @MainActor in
            let start = Date()
            var reported = false
            var failedLogged = false
            var lostLogged = false
            var lastRequest = Date.distantPast
            var matchedSince: Date?
            while Date().timeIntervalSince(start) < 600 {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
                    continue
                }
                let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
                let w = window?.bounds.size ?? .zero
                let s = scene.screen.bounds.size
                let o = scene.effectiveGeometry.interfaceOrientation
                // The window must fill the screen (Brim run 40203342285 logged "ok" for a letterboxed column).
                let fills = w.width >= s.width - 2 && w.height >= s.height - 2
                let matched: Bool
                if orient == .portrait {
                    matched = o.isPortrait && w.height > w.width && s.height > s.width && fills
                } else {
                    matched = o.isLandscape && w.width > w.height && s.width > s.height && fills
                }
                let shape = "window=\(Int(w.width))x\(Int(w.height)) screen=\(Int(s.width))x\(Int(s.height))"
                if matched {
                    let since = matchedSince ?? Date()
                    matchedSince = since
                    if !reported && Date().timeIntervalSince(since) >= 0.8 {
                        reported = true
                        lostLogged = false
                        AppTrace.t("HUSH-T orient \(name) ok \(shape)")
                    }
                } else {
                    matchedSince = nil
                    if reported && !lostLogged {
                        lostLogged = true
                        reported = false
                        AppTrace.t("HUSH-T orient \(name) lost \(shape); re-requesting")
                    }
                    if Date().timeIntervalSince(lastRequest) >= 2 {
                        lastRequest = Date()
                        window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
                            AppTrace.t("HUSH-T orient request error: \(error.localizedDescription)")
                        }
                    }
                    if !failedLogged && Date().timeIntervalSince(start) > 30 {
                        failedLogged = true
                        AppTrace.t("HUSH-T orient \(name) failed after 30s \(shape)")
                    }
                }
            }
        }
    }
}

// MARK: - Achievement badges render (`screen=badges`)

@MainActor
enum BadgeExport {
    static let side: CGFloat = 1024

    /// Renders every AchievementBadge at 1024 × 1024 px, opaque, to Documents/badges/<Game Center id>.png.
    static func renderAll() {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            AppTrace.t("HUSH-T badges done 0 (no Documents directory)")
            return
        }
        let directory = documents.appendingPathComponent("badges", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var written = 0
        for (index, def) in Achievements.all.enumerated() {
            let id = GameCenterManager.gameCenterID(def.id)
            let badge = AchievementBadge(def: def, index: index).frame(width: side, height: side)
            let renderer = ImageRenderer(content: badge)
            renderer.proposedSize = ProposedViewSize(width: side, height: side)
            renderer.scale = 1
            renderer.isOpaque = true
            guard let cgImage = renderer.cgImage, let data = IconExport.opaquePNG(cgImage, side: side) else {
                AppTrace.t("HUSH-T badges failed \(id): no image")
                continue
            }
            do {
                try data.write(to: directory.appendingPathComponent("\(id).png"))
                written += 1
            } catch {
                AppTrace.t("HUSH-T badges failed \(id): \(error.localizedDescription)")
            }
        }
        AppTrace.t("HUSH-T badges done \(written)")
    }
}

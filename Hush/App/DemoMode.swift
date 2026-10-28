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
//     pose      R6: force the small, non-blocking pose tip "Stand it up like a little laptop" on Home (with `mode=`,
//               the run starts and plays: book pose never blocks). Only on a Duo-shaped screen or with `fold=1`: a phone
//               never shows it (R2). Logs `HUSH-T pose tip shown|hidden|dismissed`.
//     cover     force the cover-display card (the sleeping mimic, "Open to carry on").
//     icon      render the icon (ChestArt.appIcon) to Documents/AppIcon-1024.png (`HUSH-T icon ok 1024x1024`, `HUSH-ICON <path>`)
//               and show it full screen. `HUSH_ICON=1` in the environment does the same without `-hushDemo`.
// - `mode=run|daily|attract`      the run mode (`daily` = today's scored try; `attract` never ends, never bites).
// - `seed=<n>`                    the run seed (default 7 for run/attract, so frames are stable; daily = today's).
// - `pilot=novice|casual|expert|perfect`   ThiefPilot drives the lid and the touches (fed in as real touches).
//                                 Without it `screen=run` takes the real hinge (Duo CI) or the slider.
// - `progress=fresh|mid|late`     seeded in-memory progress (fresh: nothing; mid: 9 relics, best 5,200; late: 22
//                                 relics, best 9,800; ranks and achievements follow from them, DemoPresets). Demo runs
//                                 never write UserDefaults.
// - `freezeOn=ready|reveal|stirring|waking|bite|bank|relic|torchLow|torchOut|results`
//                                 stop stepping the session (the scene keeps drawing) at the first such moment, and
//                                 print `HUSH-T freeze <tag>`. Moments that are events (bite, bank, relic, torchLow,
//                                 torchOut) hold 0.3 s after the event so their FX are on screen (bank: 1.25 s, so the
//                                 counter has rolled to the new total).
// - `freezeOn=creak`              (R3) freeze 0.3 s after the slam's CREAK (Feel's `onCreakAccent`; every crack logs
//                                 `HUSH-T event creak`). The relic tag waits 1.65 s (the relic card), a LESSON bank 0.5 s.
// - `freezeDelay=<s>`             (R3) the beat after the tag event, overriding the defaults above (0…10 s).
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
//                                 (`HUSH-T badges done <n>`), then show the Badges page (R2).
// Extra keys
// - `skipTo=<s>`                  `screen=run`: play the first s seconds headless (pilot, default expert) first, so
//                                 late moments (`freezeOn=torchLow`) don't take real minutes. `HUSH-T skipped <s>`.
// - `noiseUntil=pause`            (R2) with `noise=`: hold it only until the first pause of any reason, then
//                                 `HUSH-T noise released <n>` and let the session own it (duo.sh REOPEN-NO-BITE).
// - `pose=book`                   (R3) implies `screen=pose`, on any screen shape, and the App never asks for portrait.
//                                 R6: it shows the pose tip (the blocking card is gone). CI: POSE-CARD.
// - `quarter=<0…3>`               (R6) force the canvas's clockwise quarter turns k over `AppRules.quarterTurns`, but
//                                 only on a fold and only when k's parity fits the window (odd k = landscape window),
//                                 so the drawn frame stays portrait. `fold=1;orient=landscape` also gives a phone sim the
//                                 Duo's mask, so it can turn landscape.
// - `hold=closing`                (R8, QA-5 P2-7) `screen=run`: start on the closing card, held whatever drives the
//                                 lid, until its "Carry on" (shown after 3 s) is tapped. `HUSH-T demo hold closing`,
//                                 then `HUSH-T carry on …`. CI's odd-k tap test (HushUITests).
// - `golden=1`                    (R2) run/attract: the first seed (from `seed=`) whose chest #3 is a golden mimic;
//                                 its arrival logs `HUSH-T event chestArrived … golden=1`.
// - `hint=holdToPause`            (R11) with `fold=1` in a run: the press-and-hold pause coin shows "Hold to pause"
//                                 beside it and its ring half full (`HUSH-T hold hint forced`).
// - `midRun=1`                    (R11) `screen=cover`: over a run ("Open to carry on"), like `mode=run`.
// - `escape=1`                    (R11) `screen=cover`: the "Already open?" plate at once (Carry on / Home), which a
//                                 forced cover never offers by itself (`HUSH-T cover escape shown forced …`).
// - `noiseUntil=bite`             (R12) with `noise=`: hold it only until the first bite, then `HUSH-T noise released
//                                 <n>` and let the session own it (the robbed chest's frame, duo.sh BITE-CLOSE-NEXT).
// - `bag=<n>`                     (R12) put n lit items of the first chest straight into the bag on its first looting
//                                 steps (picked and dropped at walking pace: no drag noise). `HUSH-T demo bag <n> value
//                                 <v>` (duo.sh BANK-CLOSE-FULL). Not in the lesson.
// - `startOpen=1`                 (R12) with `lid=`: no shut beat, the lid is open from the first frame (Play pressed
//                                 with the lid up, rule 2): the first chest loots at once. `HUSH-T demo start open lid=<o>`.
// R12 log lines: `HUSH-T hint <HeistHint rawValue|none>` whenever the HUD's chosen hint changes (replaces R6's lone
// `HUSH-T hint tooWide`), `HUSH-T first chest phase=<looting|ready> openness=<o>` (the run's first step), `HUSH-T next
// chest dealt under the pause reason=<closing|cover|shut>` (a robbed chest folded shut in one go).
//
// Log lines: `HUSH-T demo '<args>' starts`, `HUSH-T canvas <w>x<h> fold=<0|1> turned=<0|1> k=<0…3>` (R6: the real
// window; turned = k == 2), `HUSH-T iface <o>`, `HUSH-T carry on …`, `HUSH-T watchdog resume …`, `HUSH-T hint tooWide`,
// `HUSH-T hinge nil …`, `HUSH-T pose tip shown|hidden|dismissed`,
// `HUSH-T input hinge|slider|pilot|fixed`, `HUSH-T lid …` (10 Hz in play), `HUSH-T event <name> …`,
// `HUSH-T paused closing|menu|background|pose`, `HUSH-T resumed angle <θ|->`, `HUSH-T phase active|inactive|background`,
// `HUSH-T freeze <tag>`, `HUSH-T frame 120`, `HUSH-T gold mismatch …` (never expected),
// `HUSH-T screen <route>`, `HUSH-T run gold=<g> chests=<n> bites=<b> seconds=<s>`, `HUSH-T icon ok|failed`.
// (`HUSH-H <t> <angle>` hinge samples come from Feel's HingeReader.)

struct DemoMode: Equatable {
    enum Screen: String, Equatable, CaseIterable {
        case home, run, results, codex, settings, lesson, pose, cover, icon, daily, badges
    }
    enum ModeKey: String, Equatable { case run, daily, attract }
    enum Freeze: String, Equatable, CaseIterable {
        case ready, reveal, stirring, waking, bite, bank, relic, torchLow, torchOut, results, creak

        /// Event moments hold a beat after the event; state moments freeze at once.
        var isEvent: Bool {
            switch self {
            case .bite, .bank, .relic, .torchLow, .torchOut, .creak: return true
            case .ready, .reveal, .stirring, .waking, .results: return false
            }
        }
    }
    enum Preset: String, Equatable { case fresh, mid, late }
    enum Orient: String, Equatable { case portrait, landscape }

    static let defaultSeed: UInt64 = 7
    static let freezeEventDelay: Double = 0.3
    /// R2 (tester 1, frame 14 "+179 but the total reads 151"): a bank frame waits for the counter's roll (0.3 s delay
    /// + 0.9 s) so the number on screen is the sum of the banks.
    static let bankFreezeDelay: Double = 1.25
    /// R3 (CI): the lesson's bank frame (07b) must show the bank moment, not the final card that follows 1 s later.
    static let lessonBankFreezeDelay: Double = 0.5
    /// R3 (CI): a relic frame lands on the Scene's relic-found card (it rises after `SceneMoments.bankGroupEnd`, 1.15 s),
    /// not on the bank moment before it.
    static let relicFreezeDelay: Double = 1.65

    /// `golden=1`: the first seed at or after `start` whose first possible golden chest (#3, Core's
    /// `Tuning.goldenFromIndex`) is golden. Core keeps the golden stream apart, so this changes nothing else. Pure;
    /// tested.
    static func goldenSeed(from start: UInt64) -> UInt64 {
        var s = max(start, 1)
        for _ in 0..<5_000 {
            if ChestFactory.isGolden(seed: s, index: Tuning.goldenFromIndex) { return s }
            s &+= 1
        }
        return start
    }

    /// How long an event moment holds before the freeze. Pure; tested.
    static func freezeDelay(_ tag: Freeze, lesson: Bool = false) -> Double {
        switch tag {
        case .bank: return lesson ? lessonBankFreezeDelay : bankFreezeDelay
        case .relic: return relicFreezeDelay
        default: return freezeEventDelay
        }
    }

    /// R3 (CI): `freezeDelay=<s>` overrides the beat after the tag event. Pure; tested.
    func holdDelay(_ tag: Freeze, lesson: Bool = false) -> Double {
        eventHold ?? Self.freezeDelay(tag, lesson: lesson)
    }

    var raw: String
    var screen: Screen?
    var mode: ModeKey?
    var seed: UInt64?
    var pilot: PilotSkill?
    var progress: Preset?
    var freezeOn: Freeze?
    /// `freezeAfter=` (the field is named apart from the key: the TestFlight demo guard greps Release for the key).
    var holdAfter: Double?
    /// `freezeDelay=` (R3; named apart from the key for the same reason): seconds after the tag event.
    var eventHold: Double?
    var lid: Double?
    var noise: Double?
    var lessonStep: Int?
    var turn: Bool?
    var fold = false
    var sound = true
    var skipTo: Double?
    var orient: Orient?
    /// `noiseUntil=pause`: hold `noise=` only until the first pause, then let it go (`HUSH-T noise released <n>`).
    var noiseUntilPause = false
    /// `golden=1`: the run's seed is the first one (from `seed=`, default 7) whose chest #3 is a golden mimic.
    var golden = false
    /// `pose=book` (R3): no automatic portrait asks. R6: shows the pose tip (any screen shape).
    var poseBook = false
    /// `quarter=<0…3>` (R6): force the canvas's quarter turns where they fit the window (`AppRules.forcedTurnsFit`).
    var quarter: Int?
    /// `hold=closing` (R8, QA-5 P2-7): a run starts on the closing card, held whatever drives the lid, until "Carry on".
    var holdClosing = false
    /// `hint=holdToPause` (R11): the press-and-hold coin shows "Hold to pause" and a half-full ring (needs a fold).
    var holdHint = false
    /// `midRun=1` (R11): `screen=cover` over a run (like `mode=run`).
    var midRun = false
    /// `escape=1` (R11): `screen=cover` shows its "Already open?" plate at once.
    var coverEscape = false
    /// `noiseUntil=bite` (R12): hold `noise=` only until the first bite, then let it go.
    var noiseUntilBite = false
    /// `bag=<n>` (R12, CI ask; named apart from the key): n of the first chest's items go straight into the bag.
    var bagItems: Int?
    /// `startOpen=1` (R12; named apart from the key): `lid=` is held open from the very first frame.
    var opensAtStart = false

    init(raw: String) { self.raw = raw }

    /// The screen the app opens on.
    var effectiveScreen: Screen {
        if let screen { return screen }
        if poseBook { return .pose }
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
            case "freezeDelay":
                if let s = number(value) { config.eventHold = min(max(s, 0), 10) }
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
            case "noiseUntil":
                config.noiseUntilPause = value.lowercased() == "pause"
                config.noiseUntilBite = value.lowercased() == "bite"
            case "bag":
                if let n = Int(value), n > 0 { config.bagItems = min(n, 12) }
            case "startOpen": config.opensAtStart = flag(value)
            case "golden": config.golden = flag(value)
            case "pose": config.poseBook = value.lowercased() == "book"
            case "quarter":
                if let n = Int(value), (0...3).contains(n) { config.quarter = n }
            case "hold": config.holdClosing = value.lowercased() == "closing"
            case "hint": config.holdHint = value.lowercased() == "holdtopause"
            case "midRun": config.midRun = flag(value)
            case "escape": config.coverEscape = flag(value)
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

/// R2 (UX P1-14, tester 2/3): every number a seeded profile shows agrees with every other one. The best haul, the
/// lifetime gold (so the rank), the relic count and the achievements all come from one small made-up history, and the
/// achievements are Core's own rules applied to that history (never "the first n"). `mid` has a best above a casual
/// run (its Results frame shows "… short of your best"); `late` has one an expert run can beat ("New best!").
enum DemoPresets {
    struct Profile: Equatable {
        var runs: Int
        /// Gold per run on average (lifetime = runs × this, never below the best haul).
        var averageRun: Int
        var best: Int
        var relics: Int
        var mostChests: Int
        var mostHushed: Int
        var bestChain: Int
        var highestTier: ChestTier
        var dailies: [Int]
    }

    static let mid = Profile(runs: 9, averageRun: 1_150, best: 5_200, relics: 9, mostChests: 9, mostHushed: 3,
                             bestChain: 3, highestTier: .gilded, dailies: [3_840, 3_110])
    static let late = Profile(runs: 60, averageRun: 2_350, best: 9_800, relics: 22, mostChests: 14, mostHushed: 6,
                              bestChain: 5, highestTier: .royal, dailies: [8_420, 7_150, 9_030, 6_900])

    static func progress(_ preset: DemoMode.Preset?, today: Int) -> ProgressData {
        switch preset ?? .fresh {
        case .fresh: return ProgressData()
        case .mid: return make(mid, today: today)
        case .late: return make(late, today: today)
        }
    }

    /// Pure; tested (best ≤ lifetime, Home's rank = the rank of the lifetime, Codex count = relics, achievements
    /// earned by the history's best run).
    static func make(_ p: Profile, today: Int) -> ProgressData {
        var data = ProgressData()
        data.runs = p.runs
        data.lifetimeGold = max(p.runs * p.averageRun, p.best + (p.runs - 1) * 300)
        data.bestRun = p.best
        data.chestsOpened = p.runs * 7
        data.chestsBanked = p.runs * 6
        data.hushed = p.runs * 2
        data.bites = p.runs
        data.itemsBagged = p.runs * 24
        data.bestChest = p.best / 4
        data.mostChestsInRun = p.mostChests
        data.mostHushedInRun = p.mostHushed
        let found = Array(RelicCatalog.all.prefix(p.relics).map(\.id))
        data.foundRelics = Set(found)
        data.relicOrder = found
        data.lessonDone = true
        for (i, gold) in p.dailies.enumerated() {
            let day = today - 1 - i
            data.daily[day] = DailyRecord(gold: gold, finished: true, practiceBest: gold / 2)
            data.dailyAttempted.insert(day)
            data.bestDaily = max(data.bestDaily, gold)
        }
        data.lastDailyDay = today - 1
        // The history's best run, as Core's achievement rules see it.
        let bestRun = RunResult(mode: .run, seed: 1, gold: p.best, seconds: 120, chestsOpened: p.mostChests + 1,
                                chestsBanked: p.mostChests, hushed: p.mostHushed, bites: 0,
                                relics: Array(found.prefix(1)), bestChestValue: p.best / 4, itemsBagged: p.mostChests * 4,
                                highestTier: p.highestTier, lostToBites: 0, bestChain: p.bestChain, goldenBanked: 1)
        let earned = Achievements.earned(after: bestRun, lifetimeGold: data.lifetimeGold, relicsFound: p.relics,
                                         alreadyEarned: [])
        data.achievements = Set(earned.map(\.id))
        return data
    }
}

// MARK: - App icon render (`screen=icon`, `HUSH_ICON=1`)

@MainActor
enum IconExport {
    static let side: CGFloat = 1024
    static let fileName = "AppIcon-1024.png"

    /// Renders the icon (R3: the Scene's `ChestArt.appIcon(size:)`, decision 6) at 1024 × 1024 px, flattened onto an
    /// opaque RGB PNG with no alpha, to Documents/AppIcon-1024.png (CI copies it into
    /// Hush/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png).
    static func render() {
        guard let cgImage = AppIconCache.image() else {
            AppTrace.t("HUSH-T icon failed: ChestArt.appIcon returned no image")
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
            AppTrace.t("HUSH-T icon ok \(cgImage.width)x\(cgImage.height) rgb=\(OpaquePNG.colorType(data) == 2 ? 1 : 0)")
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
            if let smallCG = small.cgImage, let png = OpaquePNG.encode(smallCG),
               (try? png.write(to: directory.appendingPathComponent("AppIcon-\(size).png"))) != nil {
                written.append("\(size)")
            }
        }
        AppTrace.t("HUSH-T icon sizes \(written.joined(separator: ","))")
    }

    /// Redraws into an opaque 1× context and writes an RGB PNG with NO alpha channel (ITMS-90717: `pngData()` keeps an
    /// alpha channel even for an opaque renderer, so the bytes come from `OpaquePNG`).
    static func opaquePNG(_ cgImage: CGImage, side: CGFloat) -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            UIImage(cgImage: cgImage).draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        guard let flat = image.cgImage else { return nil }
        return OpaquePNG.encode(flat)
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
            // R11 (Scene R11): the Scene's struck-metal badge at 1024 × 1, the same art as the Badges page; the SwiftUI
            // render only if it returns nothing.
            let scene = BadgePainter.image(motif: BadgePainter.motif(index: index), tier: BadgePainter.tier(index: index),
                                           earned: true, side: side, scale: 1)
            let drawn: CGImage?
            if let scene {
                drawn = scene
            } else {
                let badge = AchievementBadge(def: def, index: index).frame(width: side, height: side)
                let renderer = ImageRenderer(content: badge)
                renderer.proposedSize = ProposedViewSize(width: side, height: side)
                renderer.scale = 1
                renderer.isOpaque = true
                drawn = renderer.cgImage
            }
            guard let cgImage = drawn, let data = IconExport.opaquePNG(cgImage, side: side) else {
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

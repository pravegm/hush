import CoreGraphics
import Foundation
import SwiftUI
import UIKit

/// Where the app is.
enum AppRoute: String, Equatable {
    case home, playing, lesson, results, codex, badges, settings, daily

    /// The scene is live (a session steps) on these routes.
    var isPlay: Bool { self == .playing || self == .lesson }
}

/// Where the lid comes from this run.
enum AppInputKind: String, Equatable {
    case hinge, slider, pilot, fixed
}

/// What the display shows as a whole (GAME-DESIGN §3, ARCHITECTURE "Orientation").
enum AppPose: String, Equatable {
    /// Portrait: the tabletop chest (or any iPhone).
    case play
    /// A Duo held like a book (landscape): "Turn it round. Lift the glowing half."
    case standUp
    /// Shut, on the cover display: the sleeping mimic, "Open to carry on".
    case cover
}

enum ScreenSide: String, Equatable { case left, right }

/// Pure app rules (tested in HushTests/AppTests.swift).
enum AppRules {
    /// The driver clamps a frame to this (ARCHITECTURE "The frame loop").
    static let maxStep: Double = 1.0 / 30.0
    /// A long side under this is the Duo's cover display.
    static let coverMaxSide: CGFloat = 760
    /// R2 (P0-2): after any resume the lid makes no noise for this long (`HeistSession.resumeGrace`).
    static let resumeGraceSeconds: Double = 0.5
    /// R2: the closing card says "Hold still…" once the lid is back at or above this (Feel's `canResume` angle).
    static let resumeAngle: Double = 95
    /// R2 (P1-8): the pause menu never opens while the hinge is this shut (the cover display takes over).
    static let menuShutAngle: Double = 20

    static func clampStep(_ dt: Double) -> Double {
        guard dt.isFinite, dt > 0 else { return 0 }
        return min(dt, maxStep)
    }

    /// The session is in play (the candle burns, the lid matters): `.ready` or `.looting`.
    static func isLive(_ phase: RunPhase) -> Bool {
        switch phase {
        case .ready, .looting: return true
        case .banked, .bitten, .torchOut, .finished: return false
        }
    }

    /// R2 (QA-1 P1-1): while paused the lid is still to Feedback (`paused`), so no creak or haptic hangs on.
    static func telemetry(_ s: HeistSnapshot, dragSpeed: Double, playing: Bool, paused: Bool = false) -> HeistTelemetry {
        HeistTelemetry(lidSpeed: paused ? 0 : s.lidSpeed, openness: s.openness, noise: s.noise, stage: s.stage,
                       dragSpeed: paused ? 0 : (dragSpeed.isFinite ? max(dragSpeed, 0) : 0),
                       torchRemaining: s.torchRemaining, playing: playing && !paused)
    }

    // MARK: Pose and the fold

    /// R3 (founder decision 1): a cover-sized canvas on a Duo is ALWAYS the cover display, a pause (the R2
    /// "cover-open" fallback is gone: the portrait-mask fix removed the letterboxed column it was for). `playAnyway`:
    /// the player chose "Play anyway" on the book-pose card (portrait was refused), so landscape is played.
    static func pose(canvas: CGSize, hingeSeen: Bool, isShut: Bool, playAnyway: Bool = false) -> AppPose {
        let valid = canvas.width > 1 && canvas.height > 1
        guard valid else { return .play }
        let long = max(canvas.width, canvas.height)
        // Shut, iOS moves the app to the cover display (a small canvas). A stale "shut" latch never covers the lit
        // inner display (Swoop Duo R3 P2-7): there the closing card speaks instead.
        if hingeSeen && long < coverMaxSide { return .cover }
        _ = isShut
        let duo = hingeSeen || OrientationLock.looksLikeDuo(canvas)
        if canvas.width > canvas.height && duo && !playAnyway { return .standUp }
        return .play
    }

    /// The two kinds of canvas a Duo hands the app: the cover display (small) and the inner display.
    enum CanvasClass: String, Equatable { case small, inner }

    /// Pure; tested. Nil for a degenerate size.
    static func canvasClass(_ size: CGSize) -> CanvasClass? {
        guard size.width > 10, size.height > 10 else { return nil }
        return max(size.width, size.height) < coverMaxSide ? .small : .inner
    }

    /// R3 (decision 1): any small ↔ inner canvas change during a live hinge run holds the run in the closing pause
    /// (it resumes only through `canResume`), even when the pose doesn't change. Pure; tested.
    static func handoverHolds(from old: CanvasClass?, to new: CanvasClass?, liveHingeRun: Bool) -> Bool {
        guard liveHingeRun, let old, let new else { return false }
        return old != new
    }

    /// R3 (decision 1): a live hinge run never resumes on a small canvas. Pure; tested.
    static func mayResume(canResume: Bool, canvas: CanvasClass?) -> Bool {
        canResume && canvas != .small
    }

    /// R3 (QA-2 P2-2): the closing pause only engages while a chest is live. The bank, bite and candle-out moments
    /// play out whatever the lid is doing, so Results never wait on a closing pause. Pure; tested.
    static func closingApplies(_ phase: RunPhase) -> Bool { isLive(phase) }

    /// R3 (QA-2 P2-2): a moment (bank, bite, candle out) keeps stepping under a closing or pose pause (never under
    /// the menu or the background). Pure; tested.
    static func stepsThroughPause(_ phase: RunPhase, menuOrBackground: Bool) -> Bool {
        !isLive(phase) && !menuOrBackground
    }

    /// R3 (REVIEW-2-duo P1-2): the AUTOMATIC portrait asks (card shown, launch, cover → inner) only fire when the
    /// device isn't held landscape: a Duo held like a book should see the card, not be flipped under the player's
    /// hands. The lift rule and the card's button always ask. Pure; tested.
    static func mayAutoAskPortrait(_ device: UIDeviceOrientation) -> Bool {
        switch device {
        case .landscapeLeft, .landscapeRight: return false
        case .portrait, .portraitUpsideDown, .faceUp, .faceDown, .unknown: return true
        @unknown default: return true
        }
    }

    /// Why the pose is what it is (`HUSH-T pose <pose> reason=<…>`, so CI can see why a card is up). Pure; tested.
    static func poseReason(_ pose: AppPose, canvas: CGSize, forced: Bool, angle: Double?) -> String {
        let size = "\(Int(canvas.width.rounded()))x\(Int(canvas.height.rounded()))"
        let a = angle.map { AppTrace.fixed($0, 1) } ?? "-"
        if forced { return "forced \(size)" }
        switch pose {
        case .cover: return "cover-sized \(size) angle=\(a)"
        case .standUp: return "landscape \(size) angle=\(a)"
        case .play: return canvas.width > canvas.height ? "play-anyway \(size)" : "portrait \(size)"
        }
    }

    /// R2: a demo-forced pose card only shows where it could really happen: the book-pose card never on a phone
    /// (UX: frame 25 must not happen on a phone). Pure; tested.
    static func allowsForcedPose(_ pose: AppPose, screen: CGSize, demoFold: Bool) -> Bool {
        switch pose {
        case .play, .cover: return true
        case .standUp: return demoFold || OrientationLock.looksLikeDuo(screen)
        }
    }

    /// The play canvas has a real fold: a Duo's inner display in portrait (or demo `fold=1`).
    static func hasFold(canvas: CGSize, hingeSeen: Bool, demoFold: Bool) -> Bool {
        guard canvas.height >= canvas.width else { return false }
        if demoFold { return true }
        if hingeSeen { return max(canvas.width, canvas.height) >= coverMaxSide }
        return OrientationLock.looksLikeDuo(canvas)
    }

    // MARK: Turned round (GAME-DESIGN §3, the blurred-half rule)

    /// Only the Duo's portrait canvas turns round, and only with "Turn the chest round" on. R2: the scene turns itself
    /// (`ChestScene.turned`); the App turns only its SwiftUI overlays. A Game Center sheet (presented by UIKit in iOS's
    /// own orientation) un-turns the app while it is up (QA-1 P2-6).
    static func turnsRound(wanted: Bool, pose: AppPose, portrait: Bool, hasFold: Bool, systemSheet: Bool = false) -> Bool {
        wanted && pose == .play && portrait && hasFold && !systemSheet
    }

    /// The safe-area insets in the drawn layout's terms: turned round, the top inset is at the bottom and so on.
    static func insets(_ safe: EdgeInsets, turnedRound: Bool) -> EdgeInsets {
        guard turnedRound else { return safe }
        return EdgeInsets(top: safe.bottom, leading: safe.trailing, bottom: safe.top, trailing: safe.leading)
    }

    /// The screen edges whose system gestures wait for a second swipe while a chest is live: the bottom (Home), and
    /// turned round both ends (the Home edge is at the drawn top). None while paused or in menus.
    static func deferredEdges(live: Bool, turnedRound: Bool) -> Edge.Set {
        guard live else { return [] }
        return turnedRound ? [.top, .bottom] : .bottom
    }

    /// The pose card's "Lift this half" in book pose. In portrait the lid is drawn on the upper half; turned round
    /// that is the interface's BOTTOM half. landscapeRight puts the interface bottom on the right (the home-indicator
    /// side), landscapeLeft on the left.
    static func liftSide(interface: InterfaceSide, turned: Bool) -> ScreenSide {
        switch interface {
        case .landscapeRight: return turned ? .right : .left
        case .landscapeLeft: return turned ? .left : .right
        }
    }

    /// R2 (P0-1): with the pose card up, the hinge moving ≥ 15° into the play range means "they lifted it": ask iOS
    /// for portrait. Pure; tested.
    static let liftedDelta: Double = 15
    static func liftedFromBook(angle: Double, angleAtCard: Double?) -> Bool {
        guard angle.isFinite, angle >= 90, angle <= 165 else { return false }
        guard let start = angleAtCard, start.isFinite else { return false }
        return abs(angle - start) >= liftedDelta
    }

    /// R2 (P1-7): held upright in the hand the normal way (camera end up) while turned round, every screen reads
    /// upside down to the player: say so. Only with the hinge open (60…170°). Pure; tested.
    static func readsUpsideDown(turned: Bool, cameraUp: Bool, angle: Double?) -> Bool {
        guard turned, cameraUp, let a = angle, a.isFinite else { return false }
        return a >= 60 && a <= 170
    }

    // MARK: Hints

    /// Teaching hints retire after the first runs; warnings and cues always show.
    static let teachingRuns = 5

    static func isWarning(_ hint: HeistHint) -> Bool {
        switch hint {
        case .freeze, .slower, .tooWide, .easeLidDown, .candleLow: return true
        case .openSlowly, .dragToBag, .shutToBank, .relicDeeper: return false
        }
    }

    static func isTeaching(_ hint: HeistHint) -> Bool {
        switch hint {
        case .openSlowly, .dragToBag, .shutToBank: return true
        case .freeze, .slower, .tooWide, .easeLidDown, .candleLow, .relicDeeper: return false
        }
    }

    static func showsHint(_ hint: HeistHint, runs: Int) -> Bool {
        !isTeaching(hint) || runs < teachingRuns
    }

    /// R2: "Freeze!" (or any hint) never stays up under a bite or the candle's end. Pure; tested.
    static func silencesHints(_ phase: RunPhase) -> Bool {
        switch phase {
        case .bitten, .torchOut, .finished: return true
        case .ready, .looting, .banked: return false
        }
    }

    // MARK: Runs and the Daily

    /// Results' Again: a Daily (scored or not) is always practised, even after 00:00 UTC (QA-1 P2-3: it used to start
    /// the new day's scored try). Pure; tested.
    static func againMode(_ mode: RunMode) -> RunMode {
        switch mode {
        case .run: return .run
        case let .daily(day, _): return .daily(day: day, scored: false)
        case .attract: return .attract
        case .lesson: return .run
        }
    }

    /// "27 Oct" for a Daily day number (days since 2026-01-01, UTC). Pure; tested.
    static func dailyDate(day: Int, locale: Locale = .current) -> String {
        let base = DateComponents(calendar: DailyClock.calendar, timeZone: DailyClock.calendar.timeZone,
                                  year: 2026, month: 1, day: 1)
        guard let start = DailyClock.calendar.date(from: base),
              let date = DailyClock.calendar.date(byAdding: .day, value: day, to: start) else { return "today" }
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = DailyClock.calendar.timeZone
        f.setLocalizedDateFormatFromTemplate("dMMM")
        return f.string(from: date)
    }

    /// A partial run is worth filing on abandon only if something happened (else a quick Restart would count runs and
    /// retire the teaching hints early). Pure; tested.
    static func worthRecording(_ r: RunResult) -> Bool {
        switch r.mode {
        case .attract, .lesson: return false
        case .run, .daily: return r.gold > 0 || r.chestsOpened > 0 || !r.relics.isEmpty || r.bites > 0
        }
    }

    // MARK: Results

    /// "The Moth-Eaten Crown" → "the Moth-Eaten Crown" mid-sentence.
    static func midSentence(_ name: String) -> String {
        if name.hasPrefix("The ") { return "the " + name.dropFirst(4) }
        return name
    }

    /// One sentence naming the best moment, or the cause of the end (GAME-DESIGN §7).
    static func story(_ r: RunResult, outcome: RecordOutcome, relicName: (RelicID) -> String) -> String {
        if let first = r.relics.first {
            if r.relics.count > 1 {
                return "\(r.relics.count) relics, \(midSentence(relicName(first))) among them. Sticky fingers!"
            }
            return "You lifted \(midSentence(relicName(first))) from right under its nose."
        }
        if r.gold <= 0 {
            return r.bites > 0 ? "The mimic kept every coin. Gentler next time." :
                "Nothing banked. Close the lid to bank your loot."
        }
        if outcome.showsNewBest { return "A new best haul. The mimics are whispering about you." }
        if r.goldenBanked > 0 { return "You robbed a golden mimic. It'll sulk for weeks." }
        if r.bestChain >= 3 { return "A Hush Chain of \(r.bestChain). Not one snore missed." }
        if r.hushed >= 3 && r.bites == 0 { return "\(r.hushed) chests, and it never even stirred. Ghostly." }
        if r.bites >= 2 { return "Bitten \(r.bites) times: \(r.lostToBites.formatted()) gold went down the hatch." }
        if r.chestsBanked >= 6 { return "\(r.chestsBanked) chests emptied before the candle gave out." }
        return "The candle guttered out. \(r.gold.formatted()) gold made it home."
    }

    /// Results' line under the haul: "New best!" (a pill, elsewhere), else "312 short of your best". Nil when there's
    /// no best yet or nothing was banked. Pure; tested.
    static func nearMiss(gold: Int, best: Int, newBest: Bool) -> String? {
        guard !newBest, best > 0, gold > 0, gold < best else { return nil }
        return "\((best - gold).formatted()) short of your best"
    }

    /// R3 (tester 6: "why did the run end?"): one line under the title. A run only ends when the candle goes out;
    /// bites shorten it (10 s each), so they are the cause named when there were any. Pure; tested.
    static func causeLine(_ r: RunResult) -> String {
        switch r.bites {
        case ..<1: return "Your candle burned out."
        case 1: return "The mimic bit you once. Candle out."
        default: return "The mimic bit you \(r.bites) times. Candle out."
        }
    }

    /// What a Hush Chain of `n` pays (Core's rule: ×(1 + 0.1 · min(n, 5))). Pure; tested.
    static func chainGold(_ n: Int) -> Double {
        1 + Tuning.chainStep * Double(min(max(n, 0), Tuning.chainMax))
    }

    /// "Longest Hush Chain: 3 (gold ×1.3)". Pure; tested.
    static func chainLine(_ n: Int) -> String {
        "Longest Hush Chain: \(n) (gold ×\(String(format: "%.1f", chainGold(n))))"
    }
}

/// R3 (UX P1-3 / P1-8 / P2-11): one-time teaching callouts in the hint band (≤ 6 words), each shown once ever.
enum RunTip: String, CaseIterable {
    case chain, chainBroken, jingle

    var text: String {
        switch self {
        case .chain: return "Hush Chain! Sleepy banks pay more"
        case .chainBroken: return "It stirred. Chain broken."
        case .jingle: return "Full bags jingle. Bank soon."
        }
    }

    /// Shown on every golden chest's arrival (not a once-ever tip).
    static let golden = "A golden mimic! Double gold."
    /// The bag-jingle floor that first earns the tip.
    static let jingleFloor: Double = 0.10
}

/// Keeps the HUD's one-line hint calm (no flicker): a new hint shows once it has been wanted for `settle` s and the
/// current one has been up `minShow` s; "Freeze!" and "Slower…" show at once. R3 (UX P0-2): "Freeze!" replaces ANY
/// hint on the very frame it is wanted ("Slower…" included). R3 (QA-2 P2-3): the App clocks it on wall time and clears
/// it when a pause begins, so nothing freezes on screen through a pause. Pure; tested.
struct HintGate: Equatable {
    static let settle: Double = 0.15
    static let minShow: Double = 0.7

    private(set) var shown: HeistHint?
    private var candidate: HeistHint?
    private var candidateSince: Double = 0
    private var shownAt: Double = -100

    init() {}

    static func isUrgent(_ hint: HeistHint?) -> Bool {
        guard let hint else { return false }
        return hint == .freeze || hint == .slower
    }

    mutating func update(_ wanted: HeistHint?, now: Double) -> HeistHint? {
        if wanted != candidate {
            candidate = wanted
            candidateSince = now
        }
        guard wanted != shown else { return shown }
        if wanted == .freeze {
            shown = wanted
            shownAt = now
            return shown
        }
        let urgent = Self.isUrgent(wanted) && !Self.isUrgent(shown)
        let stable = now - candidateSince >= Self.settle
        let longEnough = shown == nil || now - shownAt >= Self.minShow
        if urgent || (stable && longEnough) {
            shown = wanted
            shownAt = now
        }
        return shown
    }

    /// R2: drop the hint at once (a bite starts: "Freeze!" must not linger under CHOMP).
    mutating func clear() {
        shown = nil
        candidate = nil
        shownAt = -100
    }
}

/// R2 (REVIEW-1-duo P0-2): the closing pause. A hinge run pauses when the lid is closing (θ < `Tuning.closingAngle` for
/// `Tuning.closingDwell`, Feel's gate, or shut) and resumes only once the lid is open again AND Feel says it is held
/// still in the play range (`HingeLidSource.canResume`: ≥ 95°, < 6°/s for 0.3 s). A run coming back from the cover
/// display or the book-pose card enters it too (`hold()`), so reopening never resumes mid-motion. Pure; tested.
struct ClosingPause: Equatable {
    enum Change: Equatable { case paused, resumed }

    private(set) var paused = false
    private var belowSince: Double?

    init() {}

    /// Pause without waiting for the dwell (back from the cover display or the pose card, mid-run).
    mutating func hold() {
        paused = true
        belowSince = nil
    }

    mutating func clear() {
        paused = false
        belowSince = nil
    }

    /// One frame (or a hinge report while paused).
    mutating func update(angle: Double?, gateClosing: Bool, isShut: Bool, canResume: Bool, now: Double) -> Change? {
        if let a = angle, a.isFinite, a < Tuning.closingAngle {
            if belowSince == nil { belowSince = now }
        } else {
            belowSince = nil
        }
        let dwelled = belowSince.map { now - $0 >= Tuning.closingDwell } ?? false
        let closing = gateClosing || dwelled || isShut
        if closing {
            guard !paused else { return nil }
            paused = true
            return .paused
        }
        if paused && canResume {
            paused = false
            return .resumed
        }
        return nil
    }
}

/// The Daily Dungeon's clock: the day turns at 00:00 UTC everywhere, matching the Game Center daily leaderboard
/// (founder, 27 Oct). Every App call of `DailySeed.dayNumber(for:calendar:)` goes through here, and so does the
/// one-scored-try rule.
enum DailyClock {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// Today's Daily day number (days since 2026-01-01, UTC).
    static func today(now: Date = Date()) -> Int {
        DailySeed.dayNumber(for: now, calendar: calendar)
    }

    /// When the next Daily starts (the next 00:00 UTC).
    static func nextReset(after now: Date = Date()) -> Date? {
        calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 0), matchingPolicy: .nextTime)
    }
}

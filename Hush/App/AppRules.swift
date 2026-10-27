import CoreGraphics
import Foundation
import SwiftUI

/// Where the app is.
enum AppRoute: String, Equatable {
    case home, playing, lesson, results, codex, settings, daily

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
    /// A Duo held like a book (landscape): "Stand it up like a little laptop".
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

    static func clampStep(_ dt: Double) -> Double {
        guard dt.isFinite, dt > 0 else { return 0 }
        return min(dt, maxStep)
    }

    /// The session is in play (the torch burns, the lid matters): `.ready` or `.looting`.
    static func isLive(_ phase: RunPhase) -> Bool {
        switch phase {
        case .ready, .looting: return true
        case .banked, .bitten, .torchOut, .finished: return false
        }
    }

    static func telemetry(_ s: HeistSnapshot, dragSpeed: Double, playing: Bool) -> HeistTelemetry {
        HeistTelemetry(lidSpeed: s.lidSpeed, openness: s.openness, noise: s.noise, stage: s.stage,
                       dragSpeed: dragSpeed.isFinite ? max(dragSpeed, 0) : 0, torchRemaining: s.torchRemaining,
                       playing: playing)
    }

    // MARK: Pose and the fold

    static func pose(canvas: CGSize, hingeSeen: Bool, isShut: Bool) -> AppPose {
        let valid = canvas.width > 1 && canvas.height > 1
        guard valid else { return .play }
        let long = max(canvas.width, canvas.height)
        // Shut, iOS moves the app to the cover display (a small canvas). A stale "shut" latch never covers the lit
        // inner display (Swoop Duo R3 P2-7): there the closing card speaks instead.
        if hingeSeen && long < coverMaxSide { return .cover }
        _ = isShut
        let duo = hingeSeen || OrientationLock.looksLikeDuo(canvas)
        if canvas.width > canvas.height && duo { return .standUp }
        return .play
    }

    /// The play canvas has a real fold: a Duo's inner display in portrait (or demo `fold=1`).
    static func hasFold(canvas: CGSize, hingeSeen: Bool, demoFold: Bool) -> Bool {
        guard canvas.height >= canvas.width else { return false }
        if demoFold { return true }
        if hingeSeen { return max(canvas.width, canvas.height) >= coverMaxSide }
        return OrientationLock.looksLikeDuo(canvas)
    }

    // MARK: Turned round (GAME-DESIGN §3, the blurred-half rule; Brim's method, simpler)

    /// Only the Duo's portrait canvas turns round, and only with "Turn the chest round" on. Hush never asks iOS for
    /// upside down, so this is the whole rule.
    static func turnsRound(wanted: Bool, pose: AppPose, portrait: Bool, hasFold: Bool) -> Bool {
        wanted && pose == .play && portrait && hasFold
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

    // MARK: Hints

    /// Teaching hints retire after the first runs; warnings always show.
    static let teachingRuns = 5

    static func isWarning(_ hint: HeistHint) -> Bool {
        switch hint {
        case .freeze, .slower, .tooWide, .easeLidDown: return true
        case .openSlowly, .dragToBag, .shutToBank: return false
        }
    }

    static func showsHint(_ hint: HeistHint, runs: Int) -> Bool {
        isWarning(hint) || runs < teachingRuns
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
                "Nothing banked. Ease the lid shut to keep loot."
        }
        if outcome.showsNewBest { return "A new best haul. The mimics are whispering about you." }
        if r.hushed >= 3 && r.bites == 0 { return "\(r.hushed) chests, and it never even stirred. Ghostly." }
        if r.bites >= 2 { return "Bitten \(r.bites) times: \(r.lostToBites.formatted()) gold went down the hatch." }
        if r.chestsBanked >= 6 { return "\(r.chestsBanked) chests emptied before the torch gave out." }
        return "The torch flickered out with \(r.gold.formatted()) gold in your pocket."
    }
}

/// Keeps the HUD's one-line hint calm (no flicker): a new hint shows once it has been wanted for `settle` s and the
/// current one has been up `minShow` s; "Freeze!" and "Slower…" show at once. Pure; tested.
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
        let urgent = Self.isUrgent(wanted) && !Self.isUrgent(shown)
        let stable = now - candidateSince >= Self.settle
        let longEnough = shown == nil || now - shownAt >= Self.minShow
        if urgent || (stable && longEnough) {
            shown = wanted
            shownAt = now
        }
        return shown
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

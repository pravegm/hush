import Foundation
import GameKit
import UIKit

/// Thin, polite Game Center wrapper (ported from Swoop). Authentication is quiet: a sign-in view controller handed to
/// us is never presented by itself. Scores and achievements earned while signed out are queued in UserDefaults and
/// sent once a player is authenticated; every failure is silent and nothing ever blocks play. The access point stays
/// off (it would sit over the chest). Skipped entirely in demo runs (`-hushDemo`).
@MainActor
final class GameCenterManager {
    static let shared = GameCenterManager()

    enum Leaderboard {
        /// Best Haul: gold banked in one run (classic, all-time).
        static let best = "hush.best"
        /// Daily Dungeon: the day's scored try (a recurring leaderboard that resets daily).
        static let daily = "hush.daily"
    }

    /// `hush.ach.<key>` (Core's ids may already carry the prefix). Pure; tested.
    nonisolated static func gameCenterID(_ achievementID: String) -> String {
        achievementID.hasPrefix("hush.ach.") ? achievementID : "hush.ach.\(achievementID)"
    }

    static var achievementIDs: [String] { Achievements.all.map { gameCenterID($0.id) } }

    private(set) var isAuthenticated = false
    /// Achievement banners are drawn by UIKit in iOS's own orientation, upside down for a turned-round Duo player
    /// (QA-1 P2-6): off on a Duo (Results names what was earned anyway).
    var bannersAllowed = true
    private var started = false
    private var disabled = false
    private let reportedKey = "hush.gc.reported"
    private let pendingKey = "hush.gc.pending"
    private let pendingScoresKey = "hush.gc.pendingScores"
    private var inFlight: Set<String> = []
    private var signInController: UIViewController?

    private init() {}

    /// Called once at launch.
    func authenticate() {
        guard !started else { return }
        started = true
        if DemoMode.current != nil {
            disabled = true
            return
        }
        GKAccessPoint.shared.isActive = false
        GKLocalPlayer.local.authenticateHandler = { viewController, _ in
            Task { @MainActor in
                GameCenterManager.shared.authenticationChanged(signIn: viewController)
            }
        }
    }

    enum DashboardResult: Equatable { case shown, signingIn, signedOut }

    /// Home's Game Center button (it must never do nothing). `onDismiss` runs once the sheet has gone (the app draws
    /// itself un-turned while a Game Center sheet is up, QA-1 P2-6).
    func showDashboard(onDismiss: @escaping @MainActor () -> Void = {}) -> DashboardResult {
        if disabled { return .signedOut }
        if GKLocalPlayer.local.isAuthenticated {
            GKAccessPoint.shared.trigger(handler: {
                Task { @MainActor in onDismiss() }
            })
            return .shown
        }
        if let signIn = signInController, let top = Self.topViewController() {
            signInController = nil
            top.present(signIn, animated: true)
            Self.watchDismissal(of: signIn, then: onDismiss)
            return .signingIn
        }
        return .signedOut
    }

    /// Polls until a presented controller has gone (UIKit gives no callback for a sheet we didn't make).
    private static func watchDismissal(of vc: UIViewController, then done: @escaping @MainActor () -> Void) {
        Task { @MainActor [weak vc] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            for _ in 0..<1_200 {
                guard let vc, vc.presentingViewController != nil || vc.isBeingPresented else { break }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            done()
        }
    }

    /// R3 (QA-2 P2-7): is any sheet up over our windows right now? The App asks on each activation: if the dashboard's
    /// dismissal handler never fired, nothing is presented any more, and the app turns round again.
    func sheetIsUp() -> Bool {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for window in scenes.flatMap({ $0.windows }) where window.rootViewController?.presentedViewController != nil {
            return true
        }
        return false
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }
        guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first else { return nil }
        var top = window.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    /// A scored Daily left early: its gold so far goes to the Daily board (the board keeps the best).
    func reportDailyPartial(gold: Int, day: Int) {
        guard !disabled, gold > 0 else { return }
        queueScore(gold, leaderboard: Leaderboard.daily, day: day)
    }

    /// After a run: leaderboard scores (gold) and every achievement the progress now holds.
    func report(result: RunResult, outcome: RecordOutcome, progress: ProgressData) {
        guard !disabled else { return }
        let gold = max(result.gold, 0)
        switch result.mode {
        case .run:
            if gold > 0 { queueScore(gold, leaderboard: Leaderboard.best, day: nil) }
        case let .daily(day, scored):
            // R3 (QA-2 P2-13): a Daily goes to the Daily board only. Best Haul is the Run's best, as Home shows it.
            if scored && outcome.dailyCounted && gold > 0 {
                queueScore(gold, leaderboard: Leaderboard.daily, day: day)
            }
        case .attract, .lesson:
            return
        }
        unlock(Set(progress.achievements.map { Self.gameCenterID($0) }))
    }

    // MARK: - Queue entries (pure; tested)

    struct QueuedScore: Equatable {
        var leaderboard: String
        var score: Int
        var day: Int?
        var token: String
    }

    nonisolated static func encode(leaderboard: String, score: Int, day: Int?, token: String) -> String {
        "\(leaderboard)|\(score)|\(day ?? -1)|\(token)"
    }

    nonisolated static func parse(_ entry: String) -> QueuedScore? {
        let parts = entry.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2, !parts[0].isEmpty, let value = Int(parts[1]) else { return nil }
        var day: Int?
        if parts.count >= 3, let d = Int(parts[2]), d >= 0 { day = d }
        let token = parts.count >= 4 ? parts[3] : entry
        return QueuedScore(leaderboard: parts[0], score: value, day: day, token: token)
    }

    /// A Daily score flushed after its day ended would land on the next day's board, so it is dropped.
    nonisolated static func isStale(_ score: QueuedScore, today: Int) -> Bool {
        guard score.leaderboard == Leaderboard.daily else { return false }
        guard let day = score.day else { return true }
        return day != today
    }

    nonisolated static func pending(earned: Set<String>, reported: Set<String>, known: Set<String>) -> Set<String> {
        earned.subtracting(reported).filter { known.contains($0) }
    }

    /// One pending Daily entry per day (the larger wins), and the cap never evicts a Best Haul entry first.
    nonisolated static func enqueue(_ entry: String, into queue: [String], cap: Int = 20) -> [String] {
        guard let new = parse(entry) else { return queue }
        var out = queue
        if new.leaderboard == Leaderboard.daily {
            if let i = out.firstIndex(where: { e in
                guard let p = parse(e) else { return false }
                return p.leaderboard == Leaderboard.daily && p.day == new.day
            }) {
                if let old = parse(out[i]), old.score >= new.score { return out }
                out.remove(at: i)
            }
        }
        out.append(entry)
        while out.count > cap {
            if let i = out.firstIndex(where: { parse($0)?.leaderboard != Leaderboard.best }) {
                out.remove(at: i)
            } else {
                out.removeFirst()
            }
        }
        return out
    }

    func unlock(_ ids: Set<String>) {
        guard !disabled else { return }
        let reported = Set(UserDefaults.standard.stringArray(forKey: reportedKey) ?? [])
        let pending = Self.pending(earned: ids, reported: reported, known: Set(Self.achievementIDs))
        UserDefaults.standard.set(Array(pending).sorted(), forKey: pendingKey)
        flush()
    }

    // MARK: - Internals

    private func authenticationChanged(signIn: UIViewController?) {
        if let signIn { signInController = signIn }
        isAuthenticated = GKLocalPlayer.local.isAuthenticated
        if isAuthenticated { signInController = nil }
        GKAccessPoint.shared.isActive = false
        flush()
    }

    private func queueScore(_ score: Int, leaderboard: String, day: Int?) {
        let queue = UserDefaults.standard.stringArray(forKey: pendingScoresKey) ?? []
        let entry = Self.encode(leaderboard: leaderboard, score: score, day: day, token: UUID().uuidString)
        UserDefaults.standard.set(Self.enqueue(entry, into: queue), forKey: pendingScoresKey)
        flush()
    }

    private func flush() {
        guard isAuthenticated, !disabled else { return }
        let today = DailyClock.today()
        let queued = UserDefaults.standard.stringArray(forKey: pendingScoresKey) ?? []
        let kept = queued.filter { entry in
            guard let parsed = Self.parse(entry) else { return false }
            return !Self.isStale(parsed, today: today)
        }
        if kept.count != queued.count { UserDefaults.standard.set(kept, forKey: pendingScoresKey) }
        for entry in kept where !inFlight.contains(entry) {
            guard let parsed = Self.parse(entry) else { continue }
            inFlight.insert(entry)
            GKLeaderboard.submitScore(parsed.score, context: max(parsed.day ?? 0, 0), player: GKLocalPlayer.local,
                                      leaderboardIDs: [parsed.leaderboard]) { error in
                let ok = error == nil
                Task { @MainActor in
                    GameCenterManager.shared.didSubmit(entry, ok: ok)
                }
            }
        }

        let ids = UserDefaults.standard.stringArray(forKey: pendingKey) ?? []
        guard !ids.isEmpty else { return }
        let achievements: [GKAchievement] = ids.map { id in
            let achievement = GKAchievement(identifier: id)
            achievement.percentComplete = 100
            achievement.showsCompletionBanner = bannersAllowed
            return achievement
        }
        GKAchievement.report(achievements) { error in
            let ok = error == nil
            Task { @MainActor in
                GameCenterManager.shared.didReport(ids, ok: ok)
            }
        }
    }

    private func didSubmit(_ entry: String, ok: Bool) {
        inFlight.remove(entry)
        guard ok else { return }
        let queue = (UserDefaults.standard.stringArray(forKey: pendingScoresKey) ?? []).filter { $0 != entry }
        UserDefaults.standard.set(queue, forKey: pendingScoresKey)
    }

    private func didReport(_ ids: [String], ok: Bool) {
        guard ok else { return }
        var reported = Set(UserDefaults.standard.stringArray(forKey: reportedKey) ?? [])
        reported.formUnion(ids)
        UserDefaults.standard.set(Array(reported).sorted(), forKey: reportedKey)
        let pending = (UserDefaults.standard.stringArray(forKey: pendingKey) ?? []).filter { !reported.contains($0) }
        UserDefaults.standard.set(pending, forKey: pendingKey)
    }
}

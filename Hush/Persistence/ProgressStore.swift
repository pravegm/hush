import Combine
import Foundation

// MARK: - Stored data (pure value types; tested in HushTests/AppTests.swift)

/// One day of the Daily Dungeon: the scored try (one a day) and the best practice haul.
struct DailyRecord: Codable, Equatable {
    /// Gold banked on the day's scored try.
    var gold: Int
    /// False when the scored try was left before the torch went out (the gold so far was filed).
    var finished: Bool
    /// The best practice haul that day (never on a leaderboard).
    var practiceBest: Int

    init(gold: Int = 0, finished: Bool = false, practiceBest: Int = 0) {
        self.gold = gold
        self.finished = finished
        self.practiceBest = practiceBest
    }

    /// Tolerant: a field added later never drops the Daily history.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // R5 (QA-4 P2-F): clamped, so a hand-edited save can never overflow a sum later.
        gold = ProgressRules.clampTotal((try? c.decodeIfPresent(Int.self, forKey: .gold)) ?? 0)
        finished = (try? c.decodeIfPresent(Bool.self, forKey: .finished)) ?? true
        practiceBest = ProgressRules.clampTotal((try? c.decodeIfPresent(Int.self, forKey: .practiceBest)) ?? 0)
    }
}

/// What recording a finished run changed, for the Results screen.
struct RecordOutcome: Equatable {
    var isNewBest = false
    /// The best for this mode before the run (0 = none).
    var previousBest = 0
    /// The best for this mode after the run.
    var best = 0
    var rankBefore = 0
    var rankAfter = 0
    var lifetimeBefore = 0
    var lifetimeAfter = 0
    /// Relics banked for the first time (Codex pages filled by this run).
    var newRelics: [RelicID] = []
    /// Achievements earned by this run.
    var newAchievements: [AchievementDef] = []
    /// Daily: this run was the day's one scored try.
    var dailyCounted = false
    /// Daily practice (not scored).
    var practice = false
    /// Nothing was recorded (attract, lesson).
    var ignored = false

    /// "New best!" only when an earlier best was beaten (never on the very first haul).
    var showsNewBest: Bool { isNewBest && previousBest > 0 }
    /// R3 (UX P1-4): the very first haul of this mode ("First haul!", never "Best 3,849" on the first run).
    var isFirstHaul: Bool { isNewBest && previousBest == 0 && best > 0 }
    var rankedUp: Bool { rankAfter > rankBefore }
}

/// Everything the game remembers. JSON under `ProgressStore.key`, versioned, decoded tolerantly.
struct ProgressData: Codable, Equatable {
    /// v2 (R2: `pendingRun`). v1 (R1). v0 = a save without a version (never shipped; the migration rule is still tested).
    static let currentVersion = 2

    var version = ProgressData.currentVersion
    /// Best gold banked in a Run.
    var bestRun = 0
    /// Best scored Daily Dungeon haul ever.
    var bestDaily = 0
    var lifetimeGold = 0
    var runs = 0
    var chestsOpened = 0
    var chestsBanked = 0
    var hushed = 0
    var bites = 0
    var itemsBagged = 0
    var bestChest = 0
    var mostChestsInRun = 0
    var mostHushedInRun = 0
    /// The Relic Codex: found once, kept for ever.
    var foundRelics: Set<RelicID> = []
    /// The order relics were found in (the Codex's "newest" badge).
    var relicOrder: [RelicID] = []
    /// Achievement ids earned (`AchievementDef.id`).
    var achievements: Set<String> = []
    /// Daily Dungeon days (`DailyClock.today()`: UTC days) → that day's record.
    var daily: [Int: DailyRecord] = [:]
    /// Days whose scored try has STARTED (left early or not): any later try that day is practice.
    var dailyAttempted: Set<Int> = []
    /// The latest day a Daily was played: a clock set back never gives another scored try.
    var lastDailyDay = Int.min
    /// The First Chest lesson was finished or skipped.
    var lessonDone = false
    /// R2 (QA-1 P1-3): a live run's result so far, saved when the app goes to the background. A kill there never
    /// loses its relics, gold or achievements: the next launch files it (`ProgressStore.recoverPendingRun`).
    var pendingRun: RunResult?
    /// R3: the one-time teaching callouts already shown (`RunTip` raw values: the Hush Chain, its first break, the bag
    /// jingle). Optional in the JSON, so no version bump.
    var seenTips: Set<String> = []

    init() {}

    /// Tolerant: unknown or missing fields fall back to their defaults, never wiping the rest.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let storedVersion = (try? c.decodeIfPresent(Int.self, forKey: .version)) ?? 0
        version = ProgressData.currentVersion
        // R5 (QA-4 P2-F): every total is clamped to 0…`ProgressRules.maxTotal` (a hand-edited `lifetimeGold` near
        // Int.max used to trap in the next `+=`).
        let total = { (key: CodingKeys) -> Int in
            ProgressRules.clampTotal((try? c.decodeIfPresent(Int.self, forKey: key)) ?? 0)
        }
        bestRun = total(.bestRun)
        bestDaily = total(.bestDaily)
        lifetimeGold = total(.lifetimeGold)
        runs = total(.runs)
        chestsOpened = total(.chestsOpened)
        chestsBanked = total(.chestsBanked)
        hushed = total(.hushed)
        bites = total(.bites)
        itemsBagged = total(.itemsBagged)
        bestChest = total(.bestChest)
        mostChestsInRun = total(.mostChestsInRun)
        mostHushedInRun = total(.mostHushedInRun)
        foundRelics = (try? c.decodeIfPresent(Set<RelicID>.self, forKey: .foundRelics)) ?? []
        relicOrder = (try? c.decodeIfPresent([RelicID].self, forKey: .relicOrder)) ?? []
        achievements = (try? c.decodeIfPresent(Set<String>.self, forKey: .achievements)) ?? []
        daily = (try? c.decodeIfPresent([Int: DailyRecord].self, forKey: .daily)) ?? [:]
        dailyAttempted = (try? c.decodeIfPresent(Set<Int>.self, forKey: .dailyAttempted)) ?? []
        lastDailyDay = (try? c.decodeIfPresent(Int.self, forKey: .lastDailyDay)) ?? Int.min
        lessonDone = (try? c.decodeIfPresent(Bool.self, forKey: .lessonDone)) ?? false
        pendingRun = ((try? c.decodeIfPresent(RunResult.self, forKey: .pendingRun)) ?? nil).map(ProgressRules.sanitized)
        seenTips = (try? c.decodeIfPresent(Set<String>.self, forKey: .seenTips)) ?? []
        ProgressRules.migrate(&self, fromVersion: storedVersion)
    }

    // MARK: Derived

    func dailyRecord(day: Int) -> DailyRecord? { daily[day] }
    var relicsFound: Int { foundRelics.count }
}

// MARK: - Rules (pure; tested)

enum ProgressRules {
    /// R5 (QA-4 P2-F): no stored total goes past this (a billion gold is ~50,000 record runs), so no sum can overflow.
    static let maxTotal = 1_000_000_000

    /// `v` within 0…`maxTotal`. Pure; tested.
    static func clampTotal(_ v: Int) -> Int { min(max(v, 0), maxTotal) }

    /// `a + b` (b ≥ 0 as filed), saturating at `maxTotal`, never trapping. Pure; tested.
    static func adding(_ a: Int, _ b: Int) -> Int {
        let (sum, overflow) = clampTotal(a).addingReportingOverflow(clampTotal(b))
        return overflow ? maxTotal : clampTotal(sum)
    }

    /// A run read back from a save (the pending checkpoint), its counts clamped like the totals. Pure; tested.
    static func sanitized(_ r: RunResult) -> RunResult {
        var r = r
        r.gold = clampTotal(r.gold)
        r.chestsOpened = clampTotal(r.chestsOpened)
        r.chestsBanked = clampTotal(r.chestsBanked)
        r.hushed = clampTotal(r.hushed)
        r.bites = clampTotal(r.bites)
        r.itemsBagged = clampTotal(r.itemsBagged)
        r.bestChestValue = clampTotal(r.bestChestValue)
        r.lostToBites = clampTotal(r.lostToBites)
        r.goldenBanked = clampTotal(r.goldenBanked)
        return r
    }

    /// Brings an older save up to `ProgressData.currentVersion`.
    /// - v0 → v1: a player with runs on record has met the mimic, so the First Chest lesson isn't forced on them;
    ///   relics found before `relicOrder` existed are given a stable (sorted) order.
    static func migrate(_ data: inout ProgressData, fromVersion version: Int) {
        if version < 1 {
            if data.runs > 0 { data.lessonDone = true }
        }
        // Every version: the order list covers exactly the found set.
        let missing = data.foundRelics.subtracting(data.relicOrder).sorted()
        data.relicOrder = data.relicOrder.filter { data.foundRelics.contains($0) } + missing
        var seen = Set<RelicID>()
        data.relicOrder = data.relicOrder.filter { seen.insert($0).inserted }
    }

    /// One scored Daily try a day: not if that day's try has started, nor on a day before the last one played.
    static func canPlayScoredDaily(_ data: ProgressData, today: Int) -> Bool {
        if data.dailyAttempted.contains(today) { return false }
        if data.lastDailyDay != Int.min && today < data.lastDailyDay { return false }
        return true
    }

    /// The scored try starts: the day is used up from now on (a quit or a crash never gives a second one).
    static func noteDailyStart(_ data: inout ProgressData, day: Int) {
        data.dailyAttempted.insert(day)
        data.lastDailyDay = max(data.lastDailyDay, day)
        if data.daily[day] == nil { data.daily[day] = DailyRecord(gold: 0, finished: false, practiceBest: 0) }
    }

    /// R2 (QA-1 P1-3): a run left early (Home, Restart, a kill in the background) files its result so far like any
    /// other run (relics into the Codex, gold into the rank, achievements), and a scored Daily left early keeps its gold
    /// as the day's score, marked unfinished. "New best!" compares against the best from before the run (QA-1 P2-2: a
    /// partial never raises the best on its own any more).
    static func recordAbandoned(_ result: RunResult, into data: inout ProgressData, today: Int,
                                rankFor: (Int) -> Int = { ThiefRanks.rank(forLifetimeGold: $0) },
                                earn: (RunResult, Int, Int, Set<String>) -> [AchievementDef] = {
                                    Achievements.earned(after: $0, lifetimeGold: $1, relicsFound: $2, alreadyEarned: $3)
                                }) -> RecordOutcome {
        let outcome = record(result, into: &data, today: today, rankFor: rankFor, earn: earn)
        if case let .daily(day, scored) = result.mode, scored, var r = data.daily[day] {
            r.finished = false
            data.daily[day] = r
        }
        // R3 (QA-2 P2-14): a run left with nothing banked doesn't count as a run (five quick Restarts must not retire
        // the teaching hints); its relics, bites and the Daily try are still filed above.
        if max(result.gold, 0) == 0, !outcome.ignored { data.runs = max(data.runs - 1, 0) }
        return outcome
    }

    /// The personal best a session shows for `mode` (Run: the best Run; Daily: that day's best).
    static func best(for mode: RunMode, in data: ProgressData) -> Int {
        switch mode {
        case .run: return data.bestRun
        case let .daily(day, _):
            guard let r = data.daily[day] else { return 0 }
            return max(r.gold, r.practiceBest)
        case .attract, .lesson: return 0
        }
    }

    /// The rank bar: the fraction of the way from `rank`'s threshold to the next (1 at the top rank).
    static func rankProgress(lifetime: Int, rank: Int, threshold: (Int) -> Int = { ThiefRanks.threshold($0) },
                             count: Int = ThiefRanks.count) -> Double {
        guard rank + 1 < count else { return 1 }
        let lo = threshold(rank)
        let hi = threshold(rank + 1)
        guard hi > lo else { return 1 }
        return min(max(Double(lifetime - lo) / Double(hi - lo), 0), 1)
    }

    /// Files a finished run. `rankFor` and `earn` are injectable so the tests don't lean on Core's catalogues.
    static func record(_ result: RunResult, into data: inout ProgressData, today: Int,
                       rankFor: (Int) -> Int = { ThiefRanks.rank(forLifetimeGold: $0) },
                       earn: (RunResult, Int, Int, Set<String>) -> [AchievementDef] = {
                           Achievements.earned(after: $0, lifetimeGold: $1, relicsFound: $2, alreadyEarned: $3)
                       }) -> RecordOutcome {
        var outcome = RecordOutcome()
        let gold = clampTotal(result.gold)
        switch result.mode {
        case .attract, .lesson:
            outcome.ignored = true
            outcome.rankBefore = rankFor(data.lifetimeGold)
            outcome.rankAfter = outcome.rankBefore
            outcome.lifetimeBefore = data.lifetimeGold
            outcome.lifetimeAfter = data.lifetimeGold
            return outcome
        case .run:
            outcome.previousBest = data.bestRun
            if gold > data.bestRun {
                outcome.isNewBest = true
                data.bestRun = gold
            }
            outcome.best = data.bestRun
        case let .daily(day, scored):
            var record = data.daily[day] ?? DailyRecord()
            if scored {
                outcome.dailyCounted = true
                outcome.previousBest = data.bestDaily
                record.gold = max(record.gold, gold)
                record.finished = true
                if gold > data.bestDaily {
                    outcome.isNewBest = true
                    data.bestDaily = gold
                }
                outcome.best = data.bestDaily
                data.dailyAttempted.insert(day)
                data.lastDailyDay = max(data.lastDailyDay, day)
            } else {
                outcome.practice = true
                outcome.previousBest = record.practiceBest
                if gold > record.practiceBest {
                    outcome.isNewBest = true
                    record.practiceBest = gold
                }
                outcome.best = record.practiceBest
            }
            data.daily[day] = record
        }
        outcome.lifetimeBefore = data.lifetimeGold
        outcome.rankBefore = rankFor(data.lifetimeGold)
        // R5 (QA-4 P2-F): saturating sums, so even a tampered save never traps here.
        data.lifetimeGold = adding(data.lifetimeGold, gold)
        outcome.lifetimeAfter = data.lifetimeGold
        outcome.rankAfter = rankFor(data.lifetimeGold)
        data.runs = adding(data.runs, 1)
        data.chestsOpened = adding(data.chestsOpened, result.chestsOpened)
        data.chestsBanked = adding(data.chestsBanked, result.chestsBanked)
        data.hushed = adding(data.hushed, result.hushed)
        data.bites = adding(data.bites, result.bites)
        data.itemsBagged = adding(data.itemsBagged, result.itemsBagged)
        data.bestChest = max(data.bestChest, clampTotal(result.bestChestValue))
        data.mostChestsInRun = max(data.mostChestsInRun, clampTotal(result.chestsBanked))
        data.mostHushedInRun = max(data.mostHushedInRun, clampTotal(result.hushed))
        data.lessonDone = true
        for relic in result.relics where !data.foundRelics.contains(relic) {
            data.foundRelics.insert(relic)
            data.relicOrder.append(relic)
            outcome.newRelics.append(relic)
        }
        let earned = earn(result, data.lifetimeGold, data.foundRelics.count, data.achievements)
        for def in earned where !data.achievements.contains(def.id) {
            data.achievements.insert(def.id)
            outcome.newAchievements.append(def)
        }
        return outcome
    }
}

// MARK: - The store

/// The player's progress for SwiftUI. `defaults` nil = in-memory (demo runs and tests): nothing is written.
@MainActor
final class ProgressStore: ObservableObject {
    static let key = "hush.progress"

    /// Where a save that can't be decoded is kept (QA-1 P2-15). Never overwritten: a second, different bad save goes
    /// to `hush.progress.bak.<unix time>`.
    static let backupKey = "hush.progress.bak"

    @Published private(set) var data: ProgressData
    private let defaults: UserDefaults?

    init(defaults: UserDefaults?) {
        self.defaults = defaults
        if let raw = defaults?.data(forKey: Self.key) {
            if let decoded = Self.decode(raw) {
                data = decoded
            } else {
                // One bad write (or a future format) must never wipe progress for good: keep the raw bytes first.
                if let defaults { Self.backUp(raw, in: defaults) }
                data = ProgressData()
            }
        } else {
            data = ProgressData()
        }
    }

    /// Copies an undecodable save aside without overwriting an earlier copy. Returns the key used.
    @discardableResult
    nonisolated static func backUp(_ raw: Data, in defaults: UserDefaults, now: Date = Date()) -> String {
        if let existing = defaults.data(forKey: backupKey) {
            if existing == raw { return backupKey }
            let key = "\(backupKey).\(Int(now.timeIntervalSince1970))"
            defaults.set(raw, forKey: key)
            return key
        }
        defaults.set(raw, forKey: backupKey)
        return backupKey
    }

    init(inMemory data: ProgressData) {
        self.defaults = nil
        self.data = data
    }

    nonisolated static func encode(_ data: ProgressData) -> Data? { try? JSONEncoder().encode(data) }
    nonisolated static func decode(_ raw: Data) -> ProgressData? { try? JSONDecoder().decode(ProgressData.self, from: raw) }

    var rank: Int { ThiefRanks.rank(forLifetimeGold: data.lifetimeGold) }

    func best(for mode: RunMode) -> Int { ProgressRules.best(for: mode, in: data) }
    func canPlayScoredDaily(today: Int) -> Bool { ProgressRules.canPlayScoredDaily(data, today: today) }

    func startDaily(day: Int) {
        var d = data
        ProgressRules.noteDailyStart(&d, day: day)
        commit(d)
    }

    func record(_ result: RunResult, today: Int) -> RecordOutcome {
        var d = data
        d.pendingRun = nil
        let outcome = ProgressRules.record(result, into: &d, today: today)
        commit(d)
        return outcome
    }

    /// A run left early (Home, Restart, a new run): filed now.
    func recordAbandoned(_ result: RunResult, today: Int) -> RecordOutcome {
        var d = data
        d.pendingRun = nil
        let outcome = ProgressRules.recordAbandoned(result, into: &d, today: today)
        commit(d)
        return outcome
    }

    /// The app went to the background mid-run: keep the result so far in case it is killed there.
    func saveCheckpoint(_ result: RunResult) {
        var d = data
        d.pendingRun = result
        commit(d)
    }

    func clearCheckpoint() {
        guard data.pendingRun != nil else { return }
        var d = data
        d.pendingRun = nil
        commit(d)
    }

    /// At launch: a run killed in the background is filed as left early. Returns it (for Game Center) or nil.
    func recoverPendingRun(today: Int) -> (RunResult, RecordOutcome)? {
        guard let pending = data.pendingRun else { return nil }
        let outcome = recordAbandoned(pending, today: today)
        return (pending, outcome)
    }

    /// R3: a one-time callout was shown. Returns false if it had been shown before (then don't show it).
    @discardableResult
    func markTip(_ tip: String) -> Bool {
        guard !data.seenTips.contains(tip) else { return false }
        var d = data
        d.seenTips.insert(tip)
        commit(d)
        return true
    }

    func markLessonDone() {
        guard !data.lessonDone else { return }
        var d = data
        d.lessonDone = true
        commit(d)
    }

    /// Demo presets (in-memory stores only write nothing anyway).
    func replace(_ newData: ProgressData) { commit(newData) }

    private func commit(_ newData: ProgressData) {
        if newData != data { data = newData }
        guard let defaults, let raw = Self.encode(newData) else { return }
        defaults.set(raw, forKey: Self.key)
    }
}

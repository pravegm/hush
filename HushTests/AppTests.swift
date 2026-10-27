import CoreGraphics
import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Hush

// App engineer tests: progress/settings round-trip, migration and the corrupt-save backup; the Daily one-scored-try
// rule and its R2 fixes; recording a run and an abandoned one; demo parsing and the seeded profiles; the turned-round,
// pose and orientation rules; the R2 pause rules (resume gating, rest); the First Chest's step gating; the hint gate and
// copy (≤ 6 words, the new hints included); log formats; Game Center queue rules; the HUD geometry with the R2
// fill-the-screen layout; the opaque PNG writer.

// MARK: - Helpers

private func makeRun(mode: RunMode = .run, gold: Int = 1_200, banked: Int = 5, hushed: Int = 2, bites: Int = 1,
                     relics: [RelicID] = [], lost: Int = 40) -> RunResult {
    RunResult(mode: mode, seed: 7, gold: gold, seconds: 118, chestsOpened: banked + bites, chestsBanked: banked,
              hushed: hushed, bites: bites, relics: relics, bestChestValue: gold / 3, itemsBagged: banked * 4,
              highestTier: .iron, lostToBites: lost)
}

/// One rank per 1,000 gold.
private func fakeRank(_ gold: Int) -> Int { min(gold / 1_000, 11) }

private func noAchievements(_ r: RunResult, _ lifetime: Int, _ relics: Int, _ earned: Set<String>) -> [AchievementDef] {
    []
}

private func firstHaulOnly(_ r: RunResult, _ lifetime: Int, _ relics: Int, _ earned: Set<String>) -> [AchievementDef] {
    r.chestsBanked > 0 ? [AchievementDef(id: "hush.ach.test", title: "Test", detail: "A test")] : []
}

private func record(_ r: RunResult, _ data: inout ProgressData, today: Int = 300,
                    earn: (RunResult, Int, Int, Set<String>) -> [AchievementDef] = noAchievements) -> RecordOutcome {
    ProgressRules.record(r, into: &data, today: today, rankFor: fakeRank, earn: earn)
}

private func abandon(_ r: RunResult, _ data: inout ProgressData, today: Int = 300,
                     earn: (RunResult, Int, Int, Set<String>) -> [AchievementDef] = noAchievements) -> RecordOutcome {
    ProgressRules.recordAbandoned(r, into: &data, today: today, rankFor: fakeRank, earn: earn)
}

private func near(_ a: CGFloat, _ b: CGFloat, _ tol: CGFloat = 0.6) -> Bool { abs(a - b) <= tol }

// MARK: - Persistence

@MainActor
struct PersistenceTests {
    @Test func progressRoundTrips() throws {
        var d = ProgressData()
        d.bestRun = 2_400
        d.lifetimeGold = 9_000
        d.runs = 12
        d.foundRelics = [RelicID("relic03"), RelicID("relic01")]
        d.relicOrder = [RelicID("relic03"), RelicID("relic01")]
        d.achievements = ["hush.ach.a"]
        d.daily[299] = DailyRecord(gold: 800, finished: true, practiceBest: 300)
        d.dailyAttempted = [299]
        d.lastDailyDay = 299
        d.lessonDone = true
        d.pendingRun = makeRun(relics: [RelicID("relic02")])
        let raw = try #require(ProgressStore.encode(d))
        let back = try #require(ProgressStore.decode(raw))
        #expect(back == d)
    }

    @Test func v0SaveMigrates() throws {
        // No version: a v0 save. Runs on record mean the lesson isn't forced; relics get an order.
        let json = #"{"bestRun": 900, "runs": 3, "foundRelics": ["relic02", "relic01"]}"#
        let back = try #require(ProgressStore.decode(Data(json.utf8)))
        #expect(back.version == ProgressData.currentVersion)
        #expect(back.bestRun == 900)
        #expect(back.lessonDone)
        #expect(back.relicOrder == [RelicID("relic01"), RelicID("relic02")])
        #expect(back.pendingRun == nil)
    }

    @Test func v0WithoutRunsStillTeaches() throws {
        let back = try #require(ProgressStore.decode(Data(#"{"bestRun": 0}"#.utf8)))
        #expect(!back.lessonDone)
    }

    @Test func toleratesBadFields() throws {
        let json = #"{"version": 1, "bestRun": "lots", "runs": 4, "lifetimeGold": -50, "lessonDone": true, "pendingRun": 7}"#
        let back = try #require(ProgressStore.decode(Data(json.utf8)))
        #expect(back.bestRun == 0)
        #expect(back.runs == 4)
        #expect(back.lifetimeGold == 0)
        #expect(back.lessonDone)
        #expect(back.pendingRun == nil)
    }

    @Test func futureVersionDecodes() throws {
        let back = try #require(ProgressStore.decode(Data(#"{"version": 99, "runs": 2, "newThing": [1,2]}"#.utf8)))
        #expect(back.runs == 2)
    }

    @Test func settingsRoundTripAndDefaults() throws {
        var s = SettingsData()
        #expect(s.turnRound)
        #expect(s.soundOn && s.hapticsOn && !s.respectSilentSwitch && !s.reduceMotion)
        s.turnRound = false
        s.respectSilentSwitch = true
        let raw = try #require(SettingsStore.encode(s))
        #expect(SettingsStore.decode(raw) == s)
        let old = try #require(SettingsStore.decode(Data(#"{"soundOn": false}"#.utf8)))
        #expect(!old.soundOn)
        #expect(old.turnRound)
    }

    @Test func inMemoryStoreWritesNothing() {
        let store = ProgressStore(inMemory: ProgressData())
        store.markLessonDone()
        #expect(store.data.lessonDone)
    }

    /// QA-1 P2-15: an undecodable save is copied aside before the fresh profile, and a later bad save never overwrites
    /// that copy.
    @Test func corruptSaveIsBackedUpNeverOverwritten() throws {
        let suite = "hush.tests.corrupt.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let bad = Data("{not json".utf8)
        defaults.set(bad, forKey: ProgressStore.key)
        let store = ProgressStore(defaults: defaults)
        #expect(store.data == ProgressData())
        #expect(defaults.data(forKey: ProgressStore.backupKey) == bad)
        let worse = Data("[1,2,3".utf8)
        let key = ProgressStore.backUp(worse, in: defaults, now: Date(timeIntervalSince1970: 1_000))
        #expect(key != ProgressStore.backupKey)
        #expect(defaults.data(forKey: ProgressStore.backupKey) == bad)
        #expect(defaults.data(forKey: key) == worse)
        // The same bytes again: kept once.
        #expect(ProgressStore.backUp(bad, in: defaults) == ProgressStore.backupKey)
    }

    /// QA-1 P1-3: a run killed in the background is filed at the next launch.
    @Test func checkpointIsRecoveredOnce() {
        let store = ProgressStore(inMemory: ProgressData())
        store.saveCheckpoint(makeRun(gold: 300, relics: [RelicID("relic09")]))
        #expect(store.data.pendingRun != nil)
        let recovered = store.recoverPendingRun(today: 300)
        #expect(recovered?.0.gold == 300)
        #expect(store.data.pendingRun == nil)
        #expect(store.data.foundRelics.contains(RelicID("relic09")))
        #expect(store.recoverPendingRun(today: 300) == nil)
    }
}

// MARK: - Daily and recording

@MainActor
struct DailyRuleTests {
    @Test func oneScoredTryADay() {
        var d = ProgressData()
        #expect(ProgressRules.canPlayScoredDaily(d, today: 300))
        ProgressRules.noteDailyStart(&d, day: 300)
        #expect(!ProgressRules.canPlayScoredDaily(d, today: 300))
        #expect(ProgressRules.canPlayScoredDaily(d, today: 301))
    }

    @Test func dailyDayTurnsAtMidnightUTC() {
        // 23:59:30 and 00:00:30 UTC are different Daily days, whatever the local time zone.
        let before = Date(timeIntervalSince1970: 1_793_059_170)   // 2026-10-26 23:59:30 UTC
        let after = before.addingTimeInterval(60)
        #expect(DailyClock.today(now: after) == DailyClock.today(now: before) + 1)
        // CI run 40489135408: the UTC zone may report itself as "GMT"; what matters is a zero offset all year.
        let offset = DailyClock.calendar.timeZone.secondsFromGMT(for: before)
        #expect(offset == 0)
        let reset = DailyClock.nextReset(after: before)
        #expect(reset.map { abs($0.timeIntervalSince(before) - 30) < 1 } == true)
    }

    @Test func clockSetBackNeverGivesAnotherTry() {
        var d = ProgressData()
        ProgressRules.noteDailyStart(&d, day: 300)
        #expect(!ProgressRules.canPlayScoredDaily(d, today: 299))
    }

    @Test func scoredThenPractice() {
        var d = ProgressData()
        ProgressRules.noteDailyStart(&d, day: 300)
        let o1 = record(makeRun(mode: .daily(day: 300, scored: true), gold: 700), &d)
        #expect(o1.dailyCounted)
        #expect(d.daily[300]?.gold == 700)
        #expect(d.bestDaily == 700)
        let o2 = record(makeRun(mode: .daily(day: 300, scored: false), gold: 1_500), &d)
        #expect(o2.practice)
        #expect(!o2.dailyCounted)
        #expect(d.daily[300]?.gold == 700)
        #expect(d.daily[300]?.practiceBest == 1_500)
        #expect(d.bestDaily == 700)
    }

    /// R2: a scored Daily left early keeps its gold as the day's score, unfinished, and the try stays used.
    @Test func leftEarlyFilesGoldSoFar() {
        var d = ProgressData()
        ProgressRules.noteDailyStart(&d, day: 300)
        let o = abandon(makeRun(mode: .daily(day: 300, scored: true), gold: 420), &d)
        #expect(o.dailyCounted)
        #expect(d.daily[300]?.gold == 420)
        #expect(d.daily[300]?.finished == false)
        #expect(d.bestDaily == 420)
        #expect(!ProgressRules.canPlayScoredDaily(d, today: 300))
    }

    /// QA-1 P2-2: backgrounding no longer files a partial into the best, so the run's own "New best!" is judged
    /// against the best from before the run (a first-ever Daily shows none, a beaten one shows it).
    @Test func backgroundingNeverRaisesTheDailyBest() {
        let store = ProgressStore(inMemory: ProgressData())
        store.startDaily(day: 300)
        store.saveCheckpoint(makeRun(mode: .daily(day: 300, scored: true), gold: 900))
        #expect(store.data.bestDaily == 0)
        store.clearCheckpoint()
        var d = store.data
        d.bestDaily = 600
        let o = record(makeRun(mode: .daily(day: 300, scored: true), gold: 900), &d)
        #expect(o.previousBest == 600)
        #expect(o.showsNewBest)
    }

    /// QA-1 P2-3: "Practise this dungeon" after 00:00 UTC is practice of THAT dungeon, never the new day's scored try.
    @Test func againIsAlwaysPractice() {
        #expect(AppRules.againMode(.daily(day: 300, scored: true)) == .daily(day: 300, scored: false))
        #expect(AppRules.againMode(.daily(day: 299, scored: false)) == .daily(day: 299, scored: false))
        #expect(AppRules.againMode(.run) == .run)
        #expect(AppRules.againMode(.lesson) == .run)
        #expect(AppRules.againMode(.attract) == .attract)
    }

    @Test func dailyDateNamesTheDay() {
        // Day 299 since 2026-01-01 is 27 Oct.
        let s = AppRules.dailyDate(day: 299, locale: Locale(identifier: "en_GB"))
        #expect(s.contains("27"))
        #expect(s.contains("Oct"))
        let banner = GameController.startBanner(.daily(day: 299, scored: true)) ?? ""
        #expect(banner.hasPrefix("Daily Dungeon"))
        #expect(HushCopy.wordCount(banner) <= 6)
    }

    @Test func runRecordsBestRankRelicsAchievements() {
        var d = ProgressData()
        let first = record(makeRun(gold: 800, relics: [RelicID("relic05")]), &d, earn: firstHaulOnly)
        #expect(first.isNewBest)
        #expect(!first.showsNewBest)   // the very first haul is not "New best!"
        #expect(first.newRelics == [RelicID("relic05")])
        #expect(first.newAchievements.map(\.id) == ["hush.ach.test"])
        #expect(d.lessonDone)
        let second = record(makeRun(gold: 1_500, relics: [RelicID("relic05")]), &d, earn: firstHaulOnly)
        #expect(second.showsNewBest)
        #expect(second.previousBest == 800)
        #expect(second.newRelics.isEmpty)
        #expect(second.newAchievements.isEmpty)
        #expect(second.rankBefore == 0 && second.rankAfter == 2)
        #expect(second.rankedUp)
        #expect(d.lifetimeGold == 2_300)
        #expect(d.runs == 2)
        #expect(d.relicOrder == [RelicID("relic05")])
    }

    /// QA-1 P1-3: quitting keeps the relics (the Codex said "found"), the gold and the achievements.
    @Test func abandonWritesRelicsGoldAndAchievements() {
        var d = ProgressData()
        let partial = makeRun(gold: 640, banked: 2, relics: [RelicID("relic12")])
        let o = abandon(partial, &d, earn: firstHaulOnly)
        #expect(d.foundRelics.contains(RelicID("relic12")))
        #expect(o.newRelics == [RelicID("relic12")])
        #expect(d.lifetimeGold == 640)
        #expect(d.bestRun == 640)
        #expect(d.achievements.contains("hush.ach.test"))
    }

    @Test func onlyRealPartialsAreFiled() {
        #expect(!AppRules.worthRecording(makeRun(gold: 0, banked: 0, hushed: 0, bites: 0)))
        #expect(AppRules.worthRecording(makeRun(gold: 0, banked: 0, hushed: 0, bites: 1)))
        #expect(AppRules.worthRecording(makeRun(gold: 10, banked: 1)))
        #expect(!AppRules.worthRecording(makeRun(mode: .lesson, gold: 10, banked: 1)))
        #expect(!AppRules.worthRecording(makeRun(mode: .attract, gold: 10, banked: 1)))
    }

    @Test func attractAndLessonAreIgnored() {
        var d = ProgressData()
        let a = record(makeRun(mode: .attract), &d)
        let l = record(makeRun(mode: .lesson), &d)
        #expect(a.ignored && l.ignored)
        #expect(d == ProgressData())
    }

    @Test func bestPerMode() {
        var d = ProgressData()
        d.bestRun = 900
        d.daily[300] = DailyRecord(gold: 400, finished: true, practiceBest: 650)
        #expect(ProgressRules.best(for: .run, in: d) == 900)
        #expect(ProgressRules.best(for: .daily(day: 300, scored: false), in: d) == 650)
        #expect(ProgressRules.best(for: .daily(day: 301, scored: true), in: d) == 0)
        #expect(ProgressRules.best(for: .lesson, in: d) == 0)
    }

    @Test func rankProgress() {
        let t: (Int) -> Int = { $0 * 1_000 }
        let p = ProgressRules.rankProgress(lifetime: 2_250, rank: 2, threshold: t, count: 12)
        #expect(abs(p - 0.25) < 1e-9)
        #expect(ProgressRules.rankProgress(lifetime: 99_999, rank: 11, threshold: t, count: 12) == 1)
    }
}

// MARK: - Demo mode

#if DEBUG
@MainActor
struct DemoModeTests {
    @Test func parsesEveryKey() {
        let d = DemoMode.parse("screen=results;mode=daily;seed=42;pilot=expert;progress=mid;freezeOn=torchLow;"
                               + "freezeAfter=2.5;lid=0.8;noise=1.7;lessonStep=4;turn=0;fold=1;sound=0;skipTo=30;"
                               + "orient=portrait;noiseUntil=pause;golden=1")
        #expect(d.screen == .results)
        #expect(d.mode == .daily)
        #expect(d.seed == 42)
        #expect(d.pilot == .expert)
        #expect(d.progress == .mid)
        #expect(d.freezeOn == .torchLow)
        #expect(d.holdAfter == 2.5)
        #expect(d.lid == 0.8)
        #expect(d.noise == 1)
        #expect(d.lessonStep == 4)
        #expect(d.turn == false)
        #expect(d.fold)
        #expect(!d.sound)
        #expect(d.skipTo == 30)
        #expect(d.orient == .portrait)
        #expect(d.noiseUntilPause)
        #expect(d.golden)
        #expect(d.runMode(today: 300) == .daily(day: 300, scored: true))
    }

    @Test func defaultsAndCase() {
        let d = DemoMode.parse("freezeOn=TORCHOUT;bogus=1;;turn")
        #expect(d.freezeOn == .torchOut)
        #expect(d.turn == true)
        #expect(d.effectiveScreen == .home)
        #expect(!d.noiseUntilPause && !d.golden)
        #expect(DemoMode.parse("mode=attract").effectiveScreen == .run)
        #expect(DemoMode.parse("").runMode(today: 1) == .run)
        #expect(DemoMode.parse("screen=badges").screen == .badges)
        #expect(DemoMode.parse("lessonStep=99").lessonStep == 6)
    }

    @Test func freezeMoments() {
        var s = HeistSnapshot(phase: .looting, stage: .stirring)
        #expect(GameController.matches(.stirring, s, events: []))
        #expect(!GameController.matches(.waking, s, events: []))
        #expect(!GameController.matches(.ready, s, events: []))
        s.phase = .ready
        #expect(GameController.matches(.ready, s, events: []))
        #expect(GameController.matches(.bite, s, events: [.bitten(lostValue: 10)]))
        #expect(GameController.matches(.torchLow, s, events: [.torchLow]))
        #expect(!GameController.matches(.results, s, events: [.finished]))
        #expect(DemoMode.Freeze.bite.isEvent && !DemoMode.Freeze.reveal.isEvent)
        // A bank frame waits for the counter's roll (0.3 s + 0.9 s), so the number shown is the total.
        #expect(DemoMode.freezeDelay(.bank) >= 1.2)
        #expect(DemoMode.freezeDelay(.bite) < 0.5)
    }

    /// R3: `pose=book` holds the book card (CI's POSE-BOOK frame); `freezeOn=creak` and `freezeDelay=` (CI R3 asks).
    @Test func r3Keys() {
        let book = DemoMode.parse("pose=book")
        #expect(book.poseBook)
        #expect(book.effectiveScreen == .pose)
        #expect(!DemoMode.parse("pose=other").poseBook)
        #expect(DemoMode.parse("screen=home;pose=book").effectiveScreen == .home)
        let creak = DemoMode.parse("freezeOn=creak;freezeDelay=1.5")
        #expect(creak.freezeOn == .creak && DemoMode.Freeze.creak.isEvent)
        #expect(creak.holdDelay(.creak) == 1.5)
        #expect(DemoMode.parse("freezeDelay=99").eventHold == 10)
        #expect(DemoMode.parse("").holdDelay(.relic) == DemoMode.relicFreezeDelay)
        #expect(DemoMode.parse("").holdDelay(.bank, lesson: true) < DemoMode.bankFreezeDelay)
        #expect(DemoMode.parse("").holdDelay(.bank) == DemoMode.bankFreezeDelay)
        let s = HeistSnapshot(phase: .looting)
        #expect(GameController.matches(.creak, s, events: [], creak: true))
        #expect(!GameController.matches(.creak, s, events: []))
    }

    @Test func goldenSeedMakesChestThreeGolden() {
        let s = DemoMode.goldenSeed(from: 7)
        #expect(s >= 7)
        #expect(ChestFactory.isGolden(seed: s, index: Tuning.goldenFromIndex))
    }
}
#endif

/// R2: the seeded profiles agree with themselves (tester 2/3: "Codex 9/24 vs 22 of 24", "NEW BEST 2,794 vs Best
/// 2,400").
@MainActor
struct DemoPresetTests {
    @Test func profilesAreConsistent() {
        for p in [DemoPresets.mid, DemoPresets.late] {
            let d = DemoPresets.make(p, today: 300)
            #expect(d.bestRun == p.best)
            #expect(d.lifetimeGold >= d.bestRun)
            #expect(d.foundRelics.count == p.relics)
            #expect(d.relicOrder.count == p.relics)
            #expect(d.mostChestsInRun == p.mostChests)
            #expect(d.lessonDone)
            // Achievements follow Core's own rules for that history (a relic found ⇒ the first-relic badge, …).
            let expected = Achievements.earned(after: RunResult(mode: .run, seed: 1, gold: p.best, seconds: 120,
                                                                chestsOpened: p.mostChests + 1,
                                                                chestsBanked: p.mostChests, hushed: p.mostHushed,
                                                                bites: 0, relics: Array(d.relicOrder.prefix(1)),
                                                                bestChestValue: p.best / 4,
                                                                itemsBagged: p.mostChests * 4,
                                                                highestTier: p.highestTier, lostToBites: 0,
                                                                bestChain: p.bestChain, goldenBanked: 1),
                                               lifetimeGold: d.lifetimeGold, relicsFound: p.relics, alreadyEarned: [])
            #expect(d.achievements == Set(expected.map(\.id)))
            #expect(d.bestDaily == p.dailies.max())
        }
        #expect(DemoPresets.mid.best < DemoPresets.late.best)
        #expect(DemoPresets.mid.relics < DemoPresets.late.relics)
        #expect(DemoPresets.progress(.fresh, today: 300) == ProgressData())
    }

    /// R3 (testers 5/6: "Codex 9/24" on Home vs "22 of 24" on the Codex). The source was CI shooting the Duo's Codex
    /// with `progress=late` and Home with `mid` (ci/duo.sh). One preset renders the same numbers on Home, the Codex
    /// and Results; a recorded run moves all three together.
    @Test func onePresetAgreesAcrossHomeCodexAndResults() throws {
        let today = 300
        let store = ProgressStore(inMemory: DemoPresets.progress(.mid, today: today))
        let start = store.data
        let total = RelicCatalog.all.count
        #expect(HomeMenu.codexLine(start) == "Codex \(DemoPresets.mid.relics)/\(total)")
        #expect(CodexView.subtitle(found: start.foundRelics.count, total: total)
                .hasPrefix("\(DemoPresets.mid.relics) of \(total)"))
        #expect(RankRow.bestLine(start.bestRun) == "Best \(DemoPresets.mid.best.formatted())")
        // `screen=results;progress=mid;pilot=casual;seed=7`: the same run, recorded into the same store.
        let session = HeistSession(mode: .run, seed: 7, bestRun: store.best(for: .run), foundRelics: start.foundRelics,
                                   options: SessionOptions.`for`(.run))
        DemoRunner.playToEnd(session, skill: .casual, seed: 7)
        let result = try #require(session.result)
        let outcome = store.record(result, today: today)
        #expect(outcome.previousBest == DemoPresets.mid.best)
        #expect(outcome.best == store.data.bestRun)
        let after = store.data
        #expect(HomeMenu.codexLine(after) == "Codex \(DemoPresets.mid.relics + outcome.newRelics.count)/\(total)")
        #expect(CodexView.subtitle(found: after.foundRelics.count, total: total)
                .hasPrefix("\(after.foundRelics.count) of \(total)"))
        #expect(HomeMenu.badgesLine(after)
                == "Badges \(start.achievements.count + outcome.newAchievements.count)/\(Achievements.all.count)")
        #expect(RankRow.bestLine(after.bestRun) == "Best \(outcome.best.formatted())")
    }
}

/// R3: the one-time tips, the abandoned-run counter, the diagnostics gate.
@MainActor
struct R3ProgressTests {
    @Test func tipsShowOnceAndPersist() throws {
        let store = ProgressStore(inMemory: ProgressData())
        #expect(store.markTip(RunTip.chain.rawValue))
        #expect(!store.markTip(RunTip.chain.rawValue))
        #expect(store.data.seenTips == [RunTip.chain.rawValue])
        let raw = try #require(ProgressStore.encode(store.data))
        #expect(ProgressStore.decode(raw)?.seenTips == [RunTip.chain.rawValue])
        // An R2 save (no `seenTips`) decodes with none seen.
        #expect(ProgressStore.decode(Data(#"{"version": 2, "runs": 3}"#.utf8))?.seenTips.isEmpty == true)
    }

    /// QA-2 P2-14: five quick Restarts with nothing banked never retire the teaching hints.
    @Test func emptyAbandonsDontCountAsRuns() {
        var d = ProgressData()
        for _ in 0..<5 { _ = abandon(makeRun(gold: 0, banked: 0, hushed: 0, bites: 1), &d) }
        #expect(d.runs == 0)
        #expect(AppRules.showsHint(.dragToBag, runs: d.runs))
        _ = abandon(makeRun(gold: 300, banked: 1), &d)
        #expect(d.runs == 1)
    }

    @Test func diagnosticsNeedDebugOrTheGesture() throws {
        let suite = "hush.tests.diag.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #if DEBUG
        #expect(BuildChannel.showsDiagnostics(defaults: defaults))
        #else
        #expect(!BuildChannel.showsDiagnostics(defaults: defaults))
        BuildChannel.toggleDiagnostics(defaults: defaults)
        #expect(BuildChannel.showsDiagnostics(defaults: defaults))
        #endif
    }
}

// MARK: - Turned round, pose and orientation

@MainActor
struct TurnedRoundTests {
    @Test func onlyADuoPortraitPlayTurns() {
        #expect(AppRules.turnsRound(wanted: true, pose: .play, portrait: true, hasFold: true))
        #expect(!AppRules.turnsRound(wanted: false, pose: .play, portrait: true, hasFold: true))
        #expect(!AppRules.turnsRound(wanted: true, pose: .play, portrait: true, hasFold: false))
        #expect(!AppRules.turnsRound(wanted: true, pose: .standUp, portrait: false, hasFold: true))
        #expect(!AppRules.turnsRound(wanted: true, pose: .cover, portrait: true, hasFold: true))
        #expect(!AppRules.turnsRound(wanted: true, pose: .play, portrait: false, hasFold: true))
        // QA-1 P2-6: a Game Center sheet un-turns the app.
        #expect(!AppRules.turnsRound(wanted: true, pose: .play, portrait: true, hasFold: true, systemSheet: true))
    }

    @Test func insetsTurnWithTheCanvas() {
        let safe = EdgeInsets(top: 10, leading: 2, bottom: 30, trailing: 4)
        let turned = AppRules.insets(safe, turnedRound: true)
        #expect(turned.top == 30 && turned.bottom == 10 && turned.leading == 4 && turned.trailing == 2)
        #expect(AppRules.insets(safe, turnedRound: false) == safe)
    }

    @Test func deferredEdges() {
        #expect(AppRules.deferredEdges(live: true, turnedRound: false) == .bottom)
        #expect(AppRules.deferredEdges(live: true, turnedRound: true) == [.top, .bottom])
        #expect(AppRules.deferredEdges(live: false, turnedRound: true) == [])
    }

    @Test func liftSideFollowsTheInterface() {
        #expect(AppRules.liftSide(interface: .landscapeRight, turned: true) == .right)
        #expect(AppRules.liftSide(interface: .landscapeRight, turned: false) == .left)
        #expect(AppRules.liftSide(interface: .landscapeLeft, turned: true) == .left)
        #expect(AppRules.liftSide(interface: .landscapeLeft, turned: false) == .right)
    }

    @Test func poses() {
        let inner = CGSize(width: 669, height: 951)
        let book = CGSize(width: 951, height: 669)
        let cover = CGSize(width: 393, height: 520)
        let phone = CGSize(width: 402, height: 874)
        #expect(AppRules.pose(canvas: inner, hingeSeen: true, isShut: false) == .play)
        #expect(AppRules.pose(canvas: book, hingeSeen: true, isShut: false) == .standUp)
        #expect(AppRules.pose(canvas: book, hingeSeen: false, isShut: false) == .standUp)
        #expect(AppRules.pose(canvas: cover, hingeSeen: true, isShut: true) == .cover)
        #expect(AppRules.pose(canvas: phone, hingeSeen: false, isShut: false) == .play)
        #expect(AppRules.hasFold(canvas: inner, hingeSeen: true, demoFold: false))
        #expect(AppRules.hasFold(canvas: inner, hingeSeen: false, demoFold: false))
        #expect(!AppRules.hasFold(canvas: phone, hingeSeen: false, demoFold: false))
        #expect(AppRules.hasFold(canvas: phone, hingeSeen: false, demoFold: true))
        #expect(!AppRules.hasFold(canvas: book, hingeSeen: true, demoFold: false))
    }

    /// UX: a phone never shows the book-pose card (R1's frame 25).
    @Test func phoneNeverShowsTheBookCard() {
        let phone = CGSize(width: 402, height: 874)
        #expect(!AppRules.allowsForcedPose(.standUp, screen: phone, demoFold: false))
        #expect(AppRules.allowsForcedPose(.standUp, screen: phone, demoFold: true))
        #expect(AppRules.allowsForcedPose(.standUp, screen: CGSize(width: 669, height: 951), demoFold: false))
        #expect(AppRules.allowsForcedPose(.cover, screen: phone, demoFold: false))
        #expect(StandUpCard.splitsOnFold(CGSize(width: 951, height: 669)))
        #expect(!StandUpCard.splitsOnFold(CGSize(width: 402, height: 874)))
    }

    @Test func orientationMasks() {
        #expect(OrientationLock.mask(isDuo: true) == .allButUpsideDown)
        #expect(OrientationLock.mask(isDuo: false) == .portrait)
        #expect(OrientationLock.looksLikeDuo(CGSize(width: 669, height: 951)))
        #expect(!OrientationLock.looksLikeDuo(CGSize(width: 402, height: 874)))
        #expect(!OrientationLock.trustsStoredHinge(true, screen: CGSize(width: 402, height: 874)))
        // R2 P0-1: a live run holds the inner display in portrait once it IS portrait; the cover keeps the Duo mask.
        #expect(OrientationLock.mask(isDuo: true, liveRun: true, inner: true, interfacePortrait: true) == .portrait)
        #expect(OrientationLock.mask(isDuo: true, liveRun: false, inner: true, interfacePortrait: true)
                == .allButUpsideDown)
        #expect(OrientationLock.mask(isDuo: true, liveRun: true, inner: false, interfacePortrait: true)
                == .allButUpsideDown)
        #expect(OrientationLock.mask(isDuo: false, liveRun: false, inner: true, interfacePortrait: false) == .portrait)
        // Duo run 40506125012: a run starting in book pose (landscape) must keep the landscapes, or iOS shows a
        // 469 × 669 compatibility column instead of rotating. Portrait is then ASKED for, never forced by the mask.
        let bookPose = OrientationLock.mask(isDuo: true, liveRun: true, inner: true, interfacePortrait: false)
        #expect(bookPose == .allButUpsideDown)
        #expect(bookPose.contains(.landscapeLeft) && bookPose.contains(.landscapeRight) && bookPose.contains(.portrait))
        for duo in [true, false] {
            for live in [true, false] {
                for inner in [true, false] {
                    for portrait in [true, false] {
                        let m = OrientationLock.mask(isDuo: duo, liveRun: live, inner: inner,
                                                     interfacePortrait: portrait)
                        #expect(!m.contains(.portraitUpsideDown))
                        #expect(m.contains(.portrait))
                    }
                }
            }
        }
    }

    /// R3 (founder decision 1): the "cover-open" fallback is gone. A cover-sized canvas on a Duo is always the cover
    /// display (a pause), whatever the hinge says; "Play anyway" plays a landscape book pose.
    @Test func aSmallCanvasIsAlwaysTheCover() {
        for small in [CGSize(width: 466, height: 678), CGSize(width: 469, height: 669), CGSize(width: 669, height: 469)] {
            #expect(AppRules.pose(canvas: small, hingeSeen: true, isShut: false) == .cover)
            #expect(AppRules.pose(canvas: small, hingeSeen: true, isShut: false, playAnyway: true) == .cover)
        }
        let book = CGSize(width: 951, height: 669)
        #expect(AppRules.pose(canvas: book, hingeSeen: true, isShut: false, playAnyway: true) == .play)
        #expect(AppRules.canvasClass(CGSize(width: 466, height: 678)) == .small)
        #expect(AppRules.canvasClass(CGSize(width: 669, height: 951)) == .inner)
        #expect(AppRules.canvasClass(.zero) == nil)
    }

    /// R3 (decision 1): any small ↔ inner change during a live hinge run holds the closing pause, and the run resumes
    /// only through `canResume` on the inner display, never on the small canvas.
    @Test func aHandoverHoldsUntilStillOnTheInnerDisplay() {
        #expect(AppRules.handoverHolds(from: .inner, to: .small, liveHingeRun: true))
        #expect(AppRules.handoverHolds(from: .small, to: .inner, liveHingeRun: true))
        #expect(!AppRules.handoverHolds(from: .inner, to: .inner, liveHingeRun: true))
        #expect(!AppRules.handoverHolds(from: .inner, to: .small, liveHingeRun: false))
        #expect(!AppRules.handoverHolds(from: nil, to: .small, liveHingeRun: true))
        #expect(!AppRules.mayResume(canResume: true, canvas: .small))
        #expect(AppRules.mayResume(canResume: true, canvas: .inner))
        #expect(!AppRules.mayResume(canResume: false, canvas: .inner))

        // The sequence: playing on the inner display → iOS hands over to the cover (hold) → the hinge is open and
        // still while the canvas is still small (no resume) → the inner display relights (still held) → still there.
        var p = ClosingPause()
        var canvas: AppRules.CanvasClass = .inner
        #expect(p.update(angle: 130, gateClosing: false, isShut: false,
                         canResume: AppRules.mayResume(canResume: true, canvas: canvas), now: 0) == nil)
        if AppRules.handoverHolds(from: canvas, to: .small, liveHingeRun: true) { p.hold() }
        canvas = .small
        #expect(p.paused)
        for i in 1...20 {
            let change = p.update(angle: 120, gateClosing: false, isShut: false,
                                  canResume: AppRules.mayResume(canResume: true, canvas: canvas), now: Double(i) * 0.1)
            #expect(change == nil)
        }
        #expect(p.paused)
        if AppRules.handoverHolds(from: canvas, to: .inner, liveHingeRun: true) { p.hold() }
        canvas = .inner
        // The reopening hand is still moving: held.
        #expect(p.update(angle: 125, gateClosing: false, isShut: false,
                         canResume: AppRules.mayResume(canResume: false, canvas: canvas), now: 2.1) == nil)
        #expect(p.paused)
        // Open and still on the inner display: resumes.
        #expect(p.update(angle: 125, gateClosing: false, isShut: false,
                         canResume: AppRules.mayResume(canResume: true, canvas: canvas), now: 2.5) == .resumed)
    }

    /// R3 (REVIEW-2-duo P1-2): the automatic portrait asks never fire while the Duo is held landscape like a book.
    @Test func autoPortraitAskWaitsForTheBookToClose() {
        #expect(!AppRules.mayAutoAskPortrait(.landscapeLeft))
        #expect(!AppRules.mayAutoAskPortrait(.landscapeRight))
        for o in [UIDeviceOrientation.portrait, .faceUp, .faceDown, .unknown, .portraitUpsideDown] {
            #expect(AppRules.mayAutoAskPortrait(o))
        }
    }

    /// R3 (QA-2 P2-5): the cover display's shape keeps the stored hinge; no other iPhone shape does.
    @Test func theCoverDisplayTrustsTheStoredHinge() {
        #expect(OrientationLock.looksLikeDuoCover(CGSize(width: 466, height: 678)))
        #expect(OrientationLock.trustsStoredHinge(true, screen: CGSize(width: 466, height: 678)))
        #expect(!OrientationLock.looksLikeDuoCover(CGSize(width: 402, height: 874)))
        #expect(!OrientationLock.looksLikeDuoCover(CGSize(width: 375, height: 667)))
        #expect(!OrientationLock.trustsStoredHinge(false, screen: CGSize(width: 466, height: 678)))
    }

    /// R3 (UX P1-6, QA-2 P2-4): the pose card's words and its way out.
    @Test func poseCardCopyAndWayOut() {
        #expect(StandUpCard.title == "Turn it sideways. Lift the glowing half.")
        #expect(!StandUpCard.title.contains("round"))
        #expect(StandUpCard.wayOut == "Play anyway")
        #expect(!StandUpCard.showsWayOut(refused: false, waited: false))
        #expect(StandUpCard.showsWayOut(refused: true, waited: false))
        #expect(StandUpCard.showsWayOut(refused: false, waited: true))
    }

    @Test func poseReasonsSayWhy() {
        #expect(AppRules.poseReason(.cover, canvas: CGSize(width: 469, height: 669), forced: false, angle: 104.2)
                == "cover-sized 469x669 angle=104.2")
        #expect(AppRules.poseReason(.standUp, canvas: CGSize(width: 951, height: 669), forced: false, angle: nil)
                == "landscape 951x669 angle=-")
        #expect(AppRules.poseReason(.play, canvas: CGSize(width: 669, height: 951), forced: false, angle: 120)
                == "portrait 669x951")
        #expect(AppRules.poseReason(.play, canvas: CGSize(width: 951, height: 669), forced: false, angle: 104)
                .hasPrefix("play-anyway"))
        #expect(AppRules.poseReason(.standUp, canvas: CGSize(width: 669, height: 951), forced: true, angle: nil)
                .hasPrefix("forced"))
    }

    /// P0-1: a ≥ 15° lift into the play range under the book card asks iOS for portrait.
    @Test func liftUnderTheBookCardAsksForPortrait() {
        #expect(AppRules.liftedFromBook(angle: 120, angleAtCard: 178))
        #expect(!AppRules.liftedFromBook(angle: 170, angleAtCard: 178))      // still near flat
        #expect(!AppRules.liftedFromBook(angle: 120, angleAtCard: 112))      // barely moved
        #expect(!AppRules.liftedFromBook(angle: 60, angleAtCard: 178))       // out of the play range
        #expect(!AppRules.liftedFromBook(angle: 120, angleAtCard: nil))
    }

    /// P1-7: camera end up while turned, with the hinge open, reads upside down.
    @Test func upsideDownHold() {
        #expect(AppRules.readsUpsideDown(turned: true, cameraUp: true, angle: 120))
        #expect(!AppRules.readsUpsideDown(turned: false, cameraUp: true, angle: 120))
        #expect(!AppRules.readsUpsideDown(turned: true, cameraUp: false, angle: 120))
        #expect(!AppRules.readsUpsideDown(turned: true, cameraUp: true, angle: 20))
        #expect(!AppRules.readsUpsideDown(turned: true, cameraUp: true, angle: nil))
    }
}

// MARK: - Pauses (R2, REVIEW-1-duo P0-2)

@MainActor
struct PauseRuleTests {
    /// The closing pause resumes only once Feel says the lid is open AND still, never mid-lift.
    @Test func resumeNeedsAStillOpenLid() {
        var p = ClosingPause()
        // Under the closing angle for the dwell: paused.
        #expect(p.update(angle: Tuning.closingAngle - 10, gateClosing: false, isShut: false, canResume: false,
                         now: 0) == nil)
        #expect(p.update(angle: Tuning.closingAngle - 10, gateClosing: false, isShut: false, canResume: false,
                         now: Tuning.closingDwell + 0.01) == .paused)
        #expect(p.paused)
        // Back up at 130° but still moving: stays paused (the R1 bite on reopen).
        #expect(p.update(angle: 130, gateClosing: false, isShut: false, canResume: false, now: 1.0) == nil)
        #expect(p.paused)
        // Feel's gate still says closing: no resume even if "resumable" flickers.
        #expect(p.update(angle: 130, gateClosing: true, isShut: false, canResume: true, now: 1.1) == nil)
        #expect(p.paused)
        // Open and still: resumes.
        #expect(p.update(angle: 130, gateClosing: false, isShut: false, canResume: true, now: 1.5) == .resumed)
        #expect(!p.paused)
    }

    @Test func shutPausesAtOnceAndHoldWaits() {
        var p = ClosingPause()
        #expect(p.update(angle: 5, gateClosing: false, isShut: true, canResume: false, now: 0) == .paused)
        var q = ClosingPause()
        // Back from the cover display: held until still.
        q.hold()
        #expect(q.paused)
        #expect(q.update(angle: 150, gateClosing: false, isShut: false, canResume: false, now: 0) == nil)
        #expect(q.update(angle: 150, gateClosing: false, isShut: false, canResume: true, now: 0.4) == .resumed)
    }

    @Test func aNinetyDegreeRestNeverPauses() {
        var p = ClosingPause()
        for i in 0..<100 {
            #expect(p.update(angle: 90, gateClosing: false, isShut: false, canResume: true, now: Double(i) * 0.1) == nil)
        }
        #expect(!p.paused)
    }

    /// R3 (founder decision 2): noise is FROZEN while paused (no rest, no step), the candle doesn't burn, and the first
    /// step back is frame-sized however long the pause was (Core R3). Drives the real controller's frame loop.
    @Test func noiseIsUnchangedAcrossAPause() {
        var data = ProgressData()
        data.lessonDone = true
        let controller = GameController(store: ProgressStore(inMemory: data), settings: SettingsStore(defaults: nil))
        controller.play()
        #expect(controller.input == .slider)
        let frame = 1.0 / 60.0
        var t = 1_000.0
        // Shut for a beat (the chest opens from the shut zone), then a fast slide: a loud lid makes noise.
        controller.sliderTouch(began: true, ended: false, fraction: 0, time: t)
        for _ in 0..<30 {
            t += frame
            _ = controller.advance(dt: frame, now: t)
        }
        for i in 1...12 {
            t += frame
            controller.sliderTouch(began: false, ended: false, fraction: Double(i) / 12 * 0.7, time: t)
            _ = controller.advance(dt: frame, now: t)
        }
        controller.openMenu()
        t += frame
        let before = controller.advance(dt: frame, now: t).0
        var after = before
        // 30 s of wall time paused, frames still drawing (and a 5 s gap the scene didn't draw).
        for i in 0..<300 {
            t += i == 150 ? 5 : 0.1
            after = controller.advance(dt: frame, now: t).0
        }
        #expect(after.noise == before.noise)
        #expect(after.stage == before.stage)
        #expect(after.torchRemaining == before.torchRemaining)
        #expect(after.time == before.time)
        // Back: the first step is a frame, never the pause (a 30 s dt would burn 30 s of candle).
        controller.resume()
        t += 30
        let back = controller.advance(dt: 30, now: t).0
        #expect(before.torchRemaining - back.torchRemaining <= AppRules.maxStep * 3)
        #expect(back.time - before.time <= AppRules.maxStep + 1e-9)
    }

    /// R3 (QA-2 P2-2): the closing pause only engages while a chest is live; the bank, bite and candle-out moments
    /// step through a closing or pose pause (never through the menu or the background), so Results always arrive.
    @Test func momentsNeverWaitOnTheLid() {
        #expect(AppRules.closingApplies(.ready))
        #expect(AppRules.closingApplies(.looting))
        #expect(!AppRules.closingApplies(.banked(elapsed: 0.2)))
        #expect(!AppRules.closingApplies(.torchOut(elapsed: 0)))
        #expect(AppRules.stepsThroughPause(.torchOut(elapsed: 0.5), menuOrBackground: false))
        #expect(AppRules.stepsThroughPause(.bitten(elapsed: 0.5), menuOrBackground: false))
        #expect(!AppRules.stepsThroughPause(.torchOut(elapsed: 0.5), menuOrBackground: true))
        #expect(!AppRules.stepsThroughPause(.looting, menuOrBackground: false))
    }

    /// Telemetry while paused is a still lid (QA-1 P1-1: no creak hangs on through the closing card).
    @Test func pausedTelemetryIsStill() {
        let s = HeistSnapshot(lidSpeed: 28.7, noise: 0.4)
        let t = AppRules.telemetry(s, dragSpeed: 90, playing: true, paused: true)
        #expect(t.lidSpeed == 0 && t.dragSpeed == 0 && !t.playing)
        let live = AppRules.telemetry(s, dragSpeed: 90, playing: true)
        #expect(live.lidSpeed == 28.7 && live.playing)
    }

    @Test func closingCardCopy() {
        #expect(ClosingCard.title(lifted: false).contains("Lift"))
        #expect(ClosingCard.title(lifted: true) == "Hold still…")
        #expect(ClosingCard.detail(lifted: false).contains("candle"))
        #expect(CoverCard.detail(midRun: true).contains("hold still"))
        // R3 (P1-4): before the first hinge report.
        #expect(ClosingCard.title(lifted: false, awaitingHinge: true) == "Move the lid a little")
    }
}

// MARK: - The First Chest

@MainActor
struct LessonTests {
    /// Steps the script through its praise beat.
    private func settle(_ s: inout LessonScript, from t: Double) -> Double {
        let end = t + LessonScript.praiseSeconds + 0.05
        _ = s.update(LessonScript.Input(time: end, angle: 100))
        return end
    }

    @Test func poseNeedsHalfASecondInRange() {
        var s = LessonScript()
        _ = s.update(LessonScript.Input(time: 0, angle: 100))
        _ = s.update(LessonScript.Input(time: 0.3, angle: 105))
        #expect(!s.isPraising)
        _ = s.update(LessonScript.Input(time: 0.35, angle: 140))   // out of range: the clock restarts
        _ = s.update(LessonScript.Input(time: 0.6, angle: 100))
        _ = s.update(LessonScript.Input(time: 1.0, angle: 100))
        #expect(!s.isPraising)
        _ = s.update(LessonScript.Input(time: 1.15, angle: 101))
        #expect(s.isPraising)
        _ = settle(&s, from: 1.15)
        #expect(s.step == .open)
    }

    /// P1-6: the pose window is 90…112°, never where the chest still says "Ease the lid down first".
    @Test func poseWindowMatchesTheShutZone() {
        #expect(LessonScript.poseMin == 90)
        #expect(LessonScript.poseMax == 112)
        var s = LessonScript()
        _ = s.update(LessonScript.Input(time: 0, angle: 118))
        _ = s.update(LessonScript.Input(time: 1.0, angle: 118))
        #expect(!s.isPraising)
        #expect(s.line(slider: false, angle: 118, hint: nil).hasPrefix("Close the lid"))
    }

    /// R3 (UX P0-1): the lid marker's arrow and the card's line come from one angle branch and never disagree.
    @Test func liftMarkerAndLineAgree() {
        let s = LessonScript()
        var angles: [Double?] = [nil, Double.nan]
        angles += stride(from: 0.0, through: 180.0, by: 0.5).map { Optional($0) }
        for angle in angles {
            let d = s.display(slider: false, angle: angle, hint: nil)
            guard let cue = d.liftCue else {
                Issue.record("no lid cue at \(String(describing: angle))")
                continue
            }
            #expect(cue == LessonScript.liftCue(angle: angle))
            switch cue {
            case .lower:
                #expect(cue.pointsUp == false)
                #expect(cue.label == "Lower this half a little")
                #expect(d.line.hasPrefix("Close the lid"))
            case .hold:
                #expect(cue.pointsUp == nil)
                #expect(cue.label == "Hold it there…")
                #expect(d.line == "Hold it there…")
            case .lift, .liftMore:
                #expect(cue.pointsUp == true)
                #expect(cue.label == "Lift this half")
                #expect(!d.line.hasPrefix("Close"))
            }
        }
        #expect(LessonScript.liftCue(angle: 140) == .lower)
        #expect(LessonScript.liftCue(angle: 100) == .hold)
        #expect(LessonScript.liftCue(angle: 70) == .liftMore)
        #expect(LessonScript.liftCue(angle: 175) == .lift)
        #expect(LessonScript.liftCue(angle: nil) == .lift)
        // The lever (no fold) has no lid marker.
        #expect(s.display(slider: true, angle: nil, hint: nil).liftCue == nil)
    }

    /// R3 (decision 3): one verb, "bank".
    @Test func theBankStepSaysBank() {
        let s = LessonScript(start: .bank)
        #expect(s.line(slider: true, angle: nil, hint: nil) == "Slide the lever down to bank it.")
        #expect(s.line(slider: false, angle: nil, hint: nil) == "Ease the lid shut to bank it.")
    }

    @Test func sliderPoseAndWords() {
        var s = LessonScript()
        #expect(s.line(slider: true, angle: nil, hint: nil) == "Slide the lever up… slowly.")
        _ = s.update(LessonScript.Input(time: 0, hasHinge: false, openness: 0.01))
        #expect(!s.isPraising)
        _ = s.update(LessonScript.Input(time: 0.1, hasHinge: false, openness: 0.06))
        #expect(s.isPraising)
    }

    @Test func openStepPointsAtTheNoise() {
        let s = LessonScript(start: .open)
        #expect(s.line(slider: false, angle: nil, hint: nil) == "Open the lid… slowly. Watch the noise.")
        #expect(s.line(slider: true, angle: nil, hint: nil).hasSuffix("Watch the noise."))
        #expect(s.display(slider: false, angle: nil, hint: nil).pointsAtMeter)
    }

    @Test func openGrabFreezeBank() {
        var s = LessonScript(start: .open)
        _ = s.update(LessonScript.Input(time: 0, openness: 0.05))
        #expect(s.step == .open)
        _ = s.update(LessonScript.Input(time: 0.1, openness: 0.2, anyGrabbable: true))
        var t = settle(&s, from: 0.1)
        #expect(s.step == .grab)
        #expect(s.canSkip)
        _ = s.update(LessonScript.Input(time: t + 0.1, events: [.itemBagged(id: 1, kind: .copper, value: 8)]))
        t = settle(&s, from: t + 0.1)
        #expect(s.step == .freeze)
        // The scripted stir comes after a beat.
        let early = s.update(LessonScript.Input(time: t + 0.2))
        #expect(early.isEmpty)
        let stir = s.update(LessonScript.Input(time: t + LessonScript.stirDelay + 0.01))
        #expect(stir == [.nudgeNoise(LessonScript.stirLevel)])
        #expect(s.line(slider: false, angle: nil, hint: nil) == "It's stirring. Freeze!")
        // Moving resets the stillness clock.
        let t0 = t + LessonScript.stirDelay + 0.02
        _ = s.update(LessonScript.Input(time: t0))
        _ = s.update(LessonScript.Input(time: t0 + 1.0, lidSpeed: 20))
        #expect(s.movedDuringFreeze)
        _ = s.update(LessonScript.Input(time: t0 + 1.1))
        let notYet = s.update(LessonScript.Input(time: t0 + 2.0))
        #expect(notYet.isEmpty)
        let calm = s.update(LessonScript.Input(time: t0 + 2.7))
        #expect(calm == [.nudgeNoise(LessonScript.calmLevel)])
        t = settle(&s, from: t0 + 2.7)
        #expect(s.step == .bank)
        _ = s.update(LessonScript.Input(time: t + 0.1, events: [.banked(value: 8, items: 1, hushed: true)]))
        _ = settle(&s, from: t + 0.1)
        #expect(s.step == .done)
        #expect(s.display(slider: false, angle: nil, hint: nil).isFinal)
    }

    /// QA-1 P2-1: an early bank (before the Freeze was taught) sends the lesson round once more; a second one ends it.
    @Test func bankingEarlyGoesRoundOnce() {
        var s = LessonScript(start: .grab)
        _ = s.update(LessonScript.Input(time: 0, events: [.banked(value: 8, items: 1, hushed: true)]))
        var t = settle(&s, from: 0)
        #expect(s.step == .open)
        #expect(s.earlyBanks == 1)
        _ = s.update(LessonScript.Input(time: t + 0.1, anyGrabbable: true))
        t = settle(&s, from: t + 0.1)
        #expect(s.step == .grab)
        _ = s.update(LessonScript.Input(time: t + 0.1, events: [.banked(value: 8, items: 1, hushed: true)]))
        _ = settle(&s, from: t + 0.1)
        #expect(s.step == .done)
    }

    @Test func skipOnlyAfterStepTwo() {
        #expect(!LessonScript(start: .pose).canSkip)
        #expect(!LessonScript(start: .open).canSkip)
        #expect(LessonScript(start: .grab).canSkip)
        #expect(LessonScript(start: .pose, replay: true).canSkip)
    }

    @Test func loudLidSaysSlowerThenCalms() {
        var s = LessonScript(start: .open)
        _ = s.update(LessonScript.Input(time: 0, lidSpeed: 60, noise: 0.5))
        #expect(s.isSlower)
        #expect(s.line(slider: false, angle: nil, hint: nil).hasPrefix("Slower"))
        let calm = s.update(LessonScript.Input(time: 0.2, lidSpeed: 2, noise: 0.5))
        #expect(calm == [.nudgeNoise(LessonScript.grumbleFallback)])
    }

    @Test func lessonChestIsTheBrief() {
        let spec = LessonChest.spec
        #expect(spec.mimic == .heavySleeper)
        #expect(spec.items.filter { $0.kind == .copper }.count == 2)
        #expect(spec.items.filter { $0.kind == .silver }.count == 1)
        #expect(spec.items.count == 4)
        // QA-1 P2-1: nothing is lit while the lid is still in the shut zone.
        #expect(spec.items.allSatisfy { $0.depth >= 0.2 })
        for item in spec.items {
            #expect(FloorSpace.interior.contains(item.position))
            // Behind the lesson card's band (the card never covers what it asks you to grab).
            let canvasY = ScreenLayout.foldMinY - item.position.y
            #expect(canvasY > HUDLayout.lessonBand.maxY + item.radius)
        }
        let options = LessonChest.options
        #expect(!options.torch && !options.bites)
        #expect(options.fixedChest != nil)
    }

    /// UX P0-2: the lesson card never covers the noise meter.
    @Test func lessonCardClearsTheMeter() {
        #expect(HUDLayout.lessonBand.minY >= ChestLayout.meterRect.maxY + HUDLayout.meterClearance - 0.001)
        #expect(!HUDLayout.lessonBand.intersects(ChestLayout.meterRect))
    }
}

// MARK: - Hints, copy, story

@MainActor
struct CopyTests {
    @Test func hintsAreShort() {
        for hint in HushCopy.allHints {
            #expect(HushCopy.wordCount(HushCopy.hint(hint, slider: false)) <= 6)
            #expect(HushCopy.wordCount(HushCopy.hint(hint, slider: true)) <= 6)
        }
        #expect(HushCopy.hint(.candleLow, slider: false) == "Candle's low. Bank it!")
        #expect(HushCopy.hint(.relicDeeper, slider: false) == "Something glints deeper…")
        for mode in [RunMode.run, .daily(day: 1, scored: true), .daily(day: 1, scored: false)] {
            let banner = GameController.startBanner(mode) ?? ""
            #expect(HushCopy.wordCount(banner) <= 6)
        }
        for slider in [true, false] {
            for row in HushCopy.stakes(slider: slider) { #expect(HushCopy.wordCount(row.text) <= 6) }
        }
        #expect(HushCopy.stakes(slider: false).map(\.text) == ["Candle out = run over", "Too loud? It bites your bag",
                                                              "Ease the lid shut to bank"])
        #expect(HushCopy.stakes(slider: true).last?.text == "Slide the lever down to bank")
        for tip in RunTip.allCases { #expect(HushCopy.wordCount(tip.text) <= 6) }
        #expect(HushCopy.wordCount(RunTip.golden) <= 6)
        #expect(RunTip.chain.text == "Hush Chain! Sleepy banks pay more")
        #expect(RunTip.chainBroken.text == "It stirred. Chain broken.")
        #expect(RunTip.golden == "A golden mimic! Extra gold!")
    }

    /// R3 (decision 3): one verb, "bank", in the lid's words on a fold and the lever's without.
    @Test func oneVerbBank() {
        #expect(HushCopy.hint(.shutToBank, slider: false) == "Ease the lid shut to bank")
        #expect(HushCopy.hint(.shutToBank, slider: true) == "Slide the lever down to bank")
        var lines = HushCopy.allHints.flatMap { [HushCopy.hint($0, slider: false), HushCopy.hint($0, slider: true)] }
        lines += HushCopy.stakes(slider: true).map(\.text) + HushCopy.stakes(slider: false).map(\.text)
        for step in LessonScript.Step.allCases {
            lines.append(LessonScript(start: step).line(slider: false, angle: nil, hint: nil))
            lines.append(LessonScript(start: step).line(slider: true, angle: nil, hint: nil))
        }
        for line in lines { #expect(!line.lowercased().contains("keep it")) }
        // A fold's words never mention the lever.
        for hint in HushCopy.allHints { #expect(!HushCopy.hint(hint, slider: false).lowercased().contains("lever")) }
        for step in LessonScript.Step.allCases {
            #expect(!LessonScript(start: step).line(slider: false, angle: 100, hint: nil).lowercased().contains("lever"))
        }
    }

    /// R3 (UX P1-9): VoiceOver hears the stages, the bites and the banks.
    @Test func announcements() {
        #expect(HushCopy.announcement(.stageChanged(from: .asleep, to: .stirring)) == "It's stirring.")
        #expect(HushCopy.announcement(.stageChanged(from: .stirring, to: .waking)) == "It's waking. Freeze!")
        #expect(HushCopy.announcement(.stageChanged(from: .waking, to: .stirring)) == nil)
        #expect(HushCopy.announcement(.bitten(lostValue: 179)) == "Chomp! Lost 179 gold.")
        #expect(HushCopy.announcement(.banked(value: 975, items: 3, hushed: false)) == "Banked 975 gold.")
        #expect(HushCopy.announcement(.lidCracked) == nil)
        let spoken = SpokenHUD(HeistSnapshot(stage: .waking, torchRemaining: 41.2, bagValue: 179, banked: 1_118))
        #expect(spoken.candleSeconds == 42 && spoken.banked == 1_118 && spoken.bagGold == 179)
        #expect(HushCopy.stageWord(.waking) == "it's waking")
    }

    /// "Candle" everywhere the player reads it.
    @Test func itIsACandle() {
        var lines: [String] = HushCopy.allHints.flatMap { [HushCopy.hint($0, slider: false), HushCopy.hint($0, slider: true)] }
        lines += [GameController.startBanner(.run) ?? "", ClosingCard.detail(lifted: false), CoverCard.detail(midRun: true)]
        lines += HushCopy.stakes(slider: false).map(\.text) + HushCopy.stakes(slider: true).map(\.text)
        lines += RunTip.allCases.map(\.text) + [RunTip.golden, AppRules.causeLine(makeRun(bites: 0))]
        for step in LessonScript.Step.allCases {
            let s = LessonScript(start: step)
            lines.append(s.line(slider: false, angle: nil, hint: nil))
            lines.append(s.line(slider: true, angle: nil, hint: nil))
        }
        lines.append(AppRules.story(makeRun(gold: 500, banked: 2, hushed: 0, bites: 0), outcome: RecordOutcome(),
                                    relicName: { _ in "" }))
        for line in lines { #expect(!line.lowercased().contains("torch")) }
    }

    @Test func teachingHintsRetire() {
        #expect(AppRules.showsHint(.dragToBag, runs: 0))
        #expect(!AppRules.showsHint(.dragToBag, runs: AppRules.teachingRuns))
        #expect(AppRules.showsHint(.freeze, runs: 500))
        #expect(AppRules.showsHint(.candleLow, runs: 500))
        #expect(AppRules.showsHint(.relicDeeper, runs: 500))
        #expect(AppRules.isWarning(.candleLow))
    }

    /// "Freeze!" never stays up under a bite.
    @Test func biteSilencesTheHint() {
        #expect(AppRules.silencesHints(.bitten(elapsed: 0)))
        #expect(AppRules.silencesHints(.torchOut(elapsed: 0)))
        #expect(!AppRules.silencesHints(.looting))
        var g = HintGate()
        _ = g.update(.freeze, now: 0)
        #expect(g.shown == .freeze)
        g.clear()
        #expect(g.update(nil, now: 0.05) == nil)
    }

    @Test func hintGateIsCalm() {
        var g = HintGate()
        #expect(g.update(.openSlowly, now: 0) == nil)
        #expect(g.update(.openSlowly, now: 0.2) == .openSlowly)
        // Urgent hints show at once.
        #expect(g.update(.freeze, now: 0.25) == .freeze)
        // …and hold their minimum time.
        #expect(g.update(nil, now: 0.5) == .freeze)
        #expect(g.update(nil, now: 1.0) == nil)
    }

    /// R3 (UX P0-2): "Freeze!" replaces ANY hint on the very frame it is wanted, "Slower…" included.
    @Test func freezeReplacesSlowerOnTheSameFrame() {
        var g = HintGate()
        _ = g.update(.slower, now: 0)
        #expect(g.shown == .slower)
        #expect(g.update(.freeze, now: 0.01) == .freeze)
        var h = HintGate()
        _ = h.update(.dragToBag, now: 0)
        _ = h.update(.dragToBag, now: 0.2)
        #expect(h.shown == .dragToBag)
        #expect(h.update(.freeze, now: 0.21) == .freeze)
        // On wall time it settles even while nothing steps (QA-2 P2-3): a cleared gate shows nothing.
        h.clear()
        #expect(h.update(nil, now: 5) == nil)
    }

    @Test func storyNamesTheMoment() {
        let relicRun = makeRun(relics: [RelicID("relic01")])
        let story = AppRules.story(relicRun, outcome: RecordOutcome(), relicName: { _ in "The Moth-Eaten Crown" })
        #expect(story.contains("the Moth-Eaten Crown"))
        let bitten = AppRules.story(makeRun(gold: 0, bites: 3), outcome: RecordOutcome(), relicName: { _ in "" })
        #expect(bitten.contains("mimic"))
        var best = RecordOutcome()
        best.isNewBest = true
        best.previousBest = 10
        #expect(AppRules.story(makeRun(), outcome: best, relicName: { _ in "" }).contains("best"))
        var golden = makeRun(bites: 0)
        golden.goldenBanked = 1
        #expect(AppRules.story(golden, outcome: RecordOutcome(), relicName: { _ in "" }).contains("golden"))
    }

    @Test func nearMissLine() {
        #expect(AppRules.nearMiss(gold: 2_088, best: 2_400, newBest: false) == "312 short of your best")
        #expect(AppRules.nearMiss(gold: 2_500, best: 2_400, newBest: true) == nil)
        #expect(AppRules.nearMiss(gold: 500, best: 0, newBest: false) == nil)
        #expect(AppRules.nearMiss(gold: 0, best: 900, newBest: false) == nil)
    }

    @Test func homeCaptionTeaches() {
        #expect(HomeView.caption(HomeLid(openness: 0, speed: 0), hinge: true) == "Lift the lid… slowly.")
        #expect(HomeView.caption(HomeLid(openness: 0, speed: 0), hinge: false) == "Slide its lid up… slowly.")
        #expect(HomeView.caption(HomeLid(openness: 0.5, speed: 0), hinge: true).contains("peeking"))
        #expect(HomeView.caption(HomeLid(openness: 0.5, speed: 80), hinge: true).contains("mimic"))
    }

    @Test func homeRankRowNeverEmpty() {
        #expect(RankRow.bestLine(0) == "No haul yet")
        #expect(RankRow.bestLine(2_400).hasPrefix("Best"))
        #expect(RankRow.nextLine(rank: 0) == "Next: \(ThiefRanks.title(1))")
        #expect(RankRow.nextLine(rank: ThiefRanks.count - 1) == nil)
        #expect(HushProgressBar.shown(0) >= HushProgressBar.minimumShown)
        #expect(HushProgressBar.shown(.nan) >= HushProgressBar.minimumShown)
        #expect(HushProgressBar.shown(2) == 1)
    }

    @Test func settingsCopy() {
        #expect(SettingsView.turnTitle == "Turn the chest round")
        #expect(!SettingsView.turnDetail.contains("sharp"))
        #expect(SettingsView.silentTitle == "Play sound on silent")
        #expect(CodexView.subtitle(found: 9, total: 24).hasPrefix("9 of 24"))
    }

    @Test func resultsPieces() {
        #expect(AchievementRow.moreLine(1) == nil)
        #expect(AchievementRow.moreLine(2) == nil)
        #expect(AchievementRow.moreLine(3) == "+1 more")
        let log = [ChestOutcome(tier: .wooden, golden: false, value: 120, hushed: true, bitten: false),
                   ChestOutcome(tier: .iron, golden: true, value: 0, hushed: false, bitten: true)]
        #expect(ChestStrip.spoken(log) == "2 chests: 1 banked, 1 hushed, 1 bitten")
    }

    /// R3 (UX P1-4): the strip is capped at two rows plus "+N more", explains itself, and the run says why it ended.
    @Test func resultsRestructure() {
        let nine = ChestStrip.visible(count: 9, perRow: 6)
        #expect(nine.shown == 9 && nine.more == 0)
        let twelve = ChestStrip.visible(count: 12, perRow: 6)
        #expect(twelve.shown == 12 && twelve.more == 0)
        let fifteen = ChestStrip.visible(count: 15, perRow: 6)
        #expect(fifteen.shown == 11 && fifteen.more == 4)
        let per = ChestStrip.perRow(width: 370, side: ChestStrip.side(compact: false))
        #expect(per >= 3 && per <= 7)
        let wide = ChestStrip.perRow(width: 560, side: ChestStrip.side(compact: false))
        #expect(wide > per)
        let hushed = ChestOutcome(tier: .wooden, golden: false, value: 120, hushed: true, bitten: false)
        let bit = ChestOutcome(tier: .iron, golden: false, value: 0, hushed: false, bitten: true)
        let gold = ChestOutcome(tier: .gilded, golden: true, value: 0, hushed: false, bitten: false)
        #expect(ChestStrip.legend([hushed]) == "💤 = banked while it slept")
        #expect(ChestStrip.legend([hushed, bit, gold])?.contains("golden") == true)
        #expect(ChestStrip.legend([ChestOutcome(tier: .wooden, golden: false, value: 50, hushed: false,
                                                bitten: false)]) == nil)
        #expect(ChestChip.caption(gold, isLast: true) == "out")
        #expect(ChestChip.caption(bit, isLast: true) == "bit")
        #expect(ChestChip.caption(hushed, isLast: false) == "+120")
        #expect(AppRules.causeLine(makeRun(bites: 0)) == "Your candle burned out.")
        #expect(AppRules.causeLine(makeRun(bites: 1)).contains("once"))
        #expect(AppRules.causeLine(makeRun(bites: 3)).contains("3 times"))
        #expect(AppRules.chainLine(3) == "Longest Hush Chain: 3 (gold ×1.3)")
        #expect(abs(AppRules.chainGold(9) - (1 + Tuning.chainStep * Double(Tuning.chainMax))) < 1e-9)
        // The scroll fade shows only while there's more below.
        #expect(!FadingScroll<EmptyView>.state(contentHeight: 300, viewHeight: 400, offset: 0).overflows)
        let long = FadingScroll<EmptyView>.state(contentHeight: 900, viewHeight: 400, offset: 0)
        #expect(long.overflows && !long.atEnd)
        #expect(FadingScroll<EmptyView>.state(contentHeight: 900, viewHeight: 400, offset: 500).atEnd)
    }

    /// R3 (UX P1-4): the first ever haul says "First haul!", never "Best 3,849".
    @Test func firstHaulIsCelebrated() {
        var d = ProgressData()
        let first = record(makeRun(gold: 3_849), &d)
        #expect(first.isFirstHaul && !first.showsNewBest)
        let second = record(makeRun(gold: 4_000), &d)
        #expect(!second.isFirstHaul && second.showsNewBest)
        var e = ProgressData()
        #expect(!record(makeRun(gold: 0, banked: 0), &e).isFirstHaul)
    }

    @Test func badgesAreAllDifferent() {
        #expect(BadgePainter.tier(index: 0) == .bronze)
        #expect(BadgePainter.tier(index: 5) == .silver)
        #expect(BadgePainter.tier(index: 11) == .gold)
        let motifs = (0..<Achievements.all.count).map { BadgePainter.motif(index: $0) }
        #expect(Set(motifs).count == motifs.count)
    }

    @Test func portraitRules() {
        #expect(PortraitScenes.homeTier(rank: 0) == .wooden)
        #expect(PortraitScenes.homeTier(rank: 11) == .royal)
        #expect(PortraitScenes.wake(speed: 0) == 0)
        #expect(PortraitScenes.wake(speed: 500) == 1)
        #expect(PortraitScenes.wake(speed: .nan) == 0)
        #expect(PortraitScenes.resultsPose(makeRun(bites: 2)).wake > PortraitScenes.resultsPose(makeRun(bites: 0)).wake)
    }

    @Test func dynamicTypeGrowsWithinTheCap() {
        let base: CGFloat = 17
        let large = HushType.scaled(base, .body, category: .large)
        let xxl = HushType.scaled(base, .body, category: .accessibilityExtraExtraExtraLarge)
        #expect(abs(large - base) < 0.5)
        #expect(xxl <= base * HushType.maxGrowth(.body) + 0.001)
        #expect(xxl >= large)
        // R4 (founder, CI R4): the cap is at the accessibility sizes only. XXXL grows as iOS scales it, and an AX size
        // is larger than XXXL (frames 41 ≠ 45), but by no more than `accessibilityGrowth`.
        let xxxl = HushType.scaled(base, .body, category: .extraExtraExtraLarge)
        let axl = HushType.scaled(base, .body, category: .accessibilityLarge)
        let native = UIFontMetrics(forTextStyle: .body).scaledValue(
            for: base, compatibleWith: UITraitCollection(preferredContentSizeCategory: .extraExtraExtraLarge))
        #expect(abs(xxxl - native) < 0.01)
        #expect(axl > xxxl + 0.5)
        #expect(axl <= xxxl * HushType.accessibilityGrowth + 0.001)
    }
}

// MARK: - Logs and Game Center

@MainActor
struct TraceTests {
    @Test func lidLineFormat() {
        let line = AppTrace.lidLine(openness: 0.4251, speed: 12.34, angle: 127.66, noise: 0.181, stage: .stirring)
        #expect(line == "HUSH-T lid 0.43 speed 12.3 angle 127.7 noise 0.18 stage stirring")
        let noAngle = AppTrace.lidLine(openness: 0, speed: .nan, angle: nil, noise: 0, stage: .asleep)
        #expect(noAngle == "HUSH-T lid 0.00 speed 0.0 angle - noise 0.00 stage asleep")
    }

    @Test func eventNamesAreCaseNames() {
        #expect(AppTrace.describe(.lidCracked) == "lidCracked")
        #expect(AppTrace.describe(.bitten(lostValue: 12)).hasPrefix("bitten"))
        #expect(AppTrace.describe(.stageChanged(from: .asleep, to: .waking)) == "stageChanged from=asleep to=waking")
        #expect(AppTrace.describe(.itemBagged(id: 2, kind: .gem(.ruby), value: 70)).contains("kind=gem.ruby"))
        #expect(AppTrace.describe(.chainUp(count: 3, multiplier: 1.3)) == "chainUp count=3 multiplier=1.30")
        #expect(AppTrace.describe(.chainBroken(count: 2)) == "chainBroken count=2")
        #expect(AppTrace.describe(.biteCost(lostValue: 164, seconds: 10)) == "biteCost lost=164 seconds=10.0")
    }

    @Test func gameCenterIDs() {
        #expect(GameCenterManager.gameCenterID("hush.ach.royal") == "hush.ach.royal")
        #expect(GameCenterManager.gameCenterID("royal") == "hush.ach.royal")
    }

    @Test func dailyQueueKeepsTheBestPerDay() {
        let a = GameCenterManager.encode(leaderboard: GameCenterManager.Leaderboard.daily, score: 500, day: 300, token: "a")
        let b = GameCenterManager.encode(leaderboard: GameCenterManager.Leaderboard.daily, score: 300, day: 300, token: "b")
        let c = GameCenterManager.encode(leaderboard: GameCenterManager.Leaderboard.daily, score: 900, day: 300, token: "c")
        var q = GameCenterManager.enqueue(a, into: [])
        q = GameCenterManager.enqueue(b, into: q)
        #expect(q == [a])
        q = GameCenterManager.enqueue(c, into: q)
        #expect(q == [c])
        let parsed = GameCenterManager.parse(c)
        #expect(parsed?.score == 900 && parsed?.day == 300)
        if let parsed { #expect(GameCenterManager.isStale(parsed, today: 301)) }
    }

    /// The gold counter is the sum of the banks (testers saw 379 → 179): a headless run's banks add up to its total.
    @Test func banksAddUpToTheTotal() {
        let session = HeistSession(mode: .run, seed: 7, bestRun: 0, foundRelics: [], options: SessionOptions())
        var sum = 0
        DemoRunner.play(session, skill: .casual, seed: 7, seconds: 90, onEvent: { e in
            if case let .banked(value, _, _) = e { sum += value }
        })
        #expect(sum == session.snapshot.banked)
    }

    @Test func mostLitPicksTheBrightestGrabbable() {
        func state(_ id: Int, light: Double, grabbable: Bool, place: LootPlace = .inChest) -> LootState {
            LootState(item: LootItem(id: id, kind: .copper, value: 5, depth: 0.1, position: CGPoint(x: 100, y: 100),
                                     radius: 20, rotation: 0),
                      position: CGPoint(x: Double(id) * 10, y: 100), place: place, light: light, grabbable: grabbable)
        }
        var s = HeistSnapshot()
        s.loot = [state(1, light: 0.6, grabbable: true), state(2, light: 0.9, grabbable: true),
                  state(3, light: 1, grabbable: false), state(4, light: 1, grabbable: true, place: .inBag)]
        #expect(GameController.mostLit(s)?.id == 2)
        s.loot = []
        #expect(GameController.mostLit(s) == nil)
    }
}

// MARK: - Geometry (R2: the scene fills the screen)

@MainActor
struct LayoutTests {
    @Test func duoCanvasFitsExactly() {
        let fit = CanvasFit(viewSize: CGSize(width: 670, height: 952))
        #expect(fit.contentOffsetY == 0)
        #expect(near(fit.rect.minX, 0) && near(fit.rect.minY, 0))
        #expect(near(fit.rect.width, 670) && near(fit.rect.height, 952))
        // Canvas (y up) → view (y down): the floor half is the lower part of the view.
        #expect(near(fit.floorRect.minY, 496))
        #expect(near(fit.floorRect.maxY, 952))
        let duo = CanvasFit(viewSize: CGSize(width: 669, height: 951))
        #expect(duo.contentOffsetY == 0)
        #expect(near(duo.canvasRect.height, 951, 1.5))
    }

    /// A phone: no bars. The scene is taller than the canvas; the canvas sits at contentOffsetY with the same
    /// extension above and below, and the scene covers the whole view.
    @Test func phoneFillsWithContentOffset() {
        let view = CGSize(width: 402, height: 874)
        let layout = ScreenLayout.make(hasFold: false, viewSize: view)
        let fit = CanvasFit(viewSize: view, layout: layout)
        #expect(layout.size.height > ScreenLayout.canvasHeight)
        #expect(fit.contentOffsetY == layout.contentOffsetY)
        #expect(fit.contentOffsetY > 200)
        // The scene covers the view (aspect-fill): no bars.
        #expect(fit.rect.minX <= 0.5 && fit.rect.minY <= 0.5)
        #expect(fit.rect.maxX >= view.width - 0.5 && fit.rect.maxY >= view.height - 0.5)
        // The canvas is full width, centred, with the extension both sides.
        let canvas = fit.canvasRect
        #expect(near(canvas.width, view.width))
        let above = canvas.minY - fit.rect.minY
        let below = fit.rect.maxY - canvas.maxY
        #expect(near(above, fit.contentOffsetY * fit.scale, 1))
        #expect(near(below, fit.contentOffsetY * fit.scale, 1))
        // A canvas point maps through the offset: canvas y = 0 sits contentOffsetY above the scene's bottom.
        let bottom = fit.viewPoint(canvas: CGPoint(x: 0, y: 0))
        #expect(near(bottom.y, fit.rect.maxY - fit.contentOffsetY * fit.scale))
        // The default fit is the same layout as the scene's.
        #expect(CanvasFit(viewSize: view) == fit)
    }

    @Test func hudSitsOnTheFloorHalf() {
        let floor = HUDLayout.floor
        #expect(floor.contains(HUDLayout.hintBand))
        #expect(floor.contains(HUDLayout.pauseRect))
        #expect(floor.contains(HUDLayout.lessonBand))
        #expect(HUDLayout.hintBand.minY >= HUDLayout.meterTop)
        #expect(!HUDLayout.hintBand.intersects(HUDLayout.pauseRect))
        // UX P0-10: the hint band is at the floor's back edge, by the fold, not in the loot.
        #expect(HUDLayout.hintBand.midY > ScreenLayout.foldMinY / 2)
    }

    /// Juror P1-10: the pause coin keeps ≥ 16 pt from every edge, inside the safe area, on a phone and the Duo.
    @Test func pauseCoinIsInset() {
        let side = HushTheme.minTap
        for (size, insets) in [(CGSize(width: 402, height: 874), EdgeInsets(top: 62, leading: 0, bottom: 34, trailing: 0)),
                               (CGSize(width: 375, height: 667), EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0)),
                               (CGSize(width: 669, height: 951), EdgeInsets(top: 24, leading: 0, bottom: 20,
                                                                            trailing: 0))] {
            let info = AppCanvas(size: size, insets: insets, hasFold: false, turned: false)
            let c = info.pauseCenter(side: side)
            #expect(c.x + side / 2 <= size.width - insets.trailing - AppCanvas.pauseInset + 0.001)
            #expect(c.x - side / 2 >= insets.leading + AppCanvas.pauseInset - 0.001)
            #expect(c.y - side / 2 >= insets.top + AppCanvas.pauseInset - 0.001)
            #expect(c.y + side / 2 <= size.height - insets.bottom - AppCanvas.pauseInset + 0.001)
        }
    }

    /// R3 ("Play anyway"): a landscape view shows the whole portrait canvas (aspect-fit), never a crop.
    @Test func landscapeFitsTheWholeCanvas() {
        let view = CGSize(width: 951, height: 669)
        let fit = CanvasFit(viewSize: view)
        let canvas = fit.canvasRect
        #expect(canvas.minX >= -0.5 && canvas.minY >= -0.5)
        #expect(canvas.maxX <= view.width + 0.5 && canvas.maxY <= view.height + 0.5)
    }

    /// R3: the lid's teaching words sit in the lid half above the brow; the closing card never covers the meter.
    @Test func r3HUDSlots() {
        #expect(HUDLayout.lid.contains(HUDLayout.lidLabelBand))
        #expect(HUDLayout.cardArea.minY >= ChestLayout.meterRect.maxY)
        #expect(HUDLayout.cardArea.maxY <= ScreenLayout.foldMinY)
        #expect(HUDLayout.cardArea.height > 200)
    }

    @Test func homeHalvesClearTheFold() {
        let info = AppCanvas(size: CGSize(width: 669, height: 951), insets: EdgeInsets(), hasFold: true, turned: true)
        #expect(info.isFoldClear(info.floorHalf))
        #expect(info.isFoldClear(info.lidHalf))
        #expect(info.floorHalf.minY > info.size.height / 2)
        #expect(info.floorHalf.height > 400)
    }
}

// MARK: - The app icon / badge PNGs (ITMS-90717: no alpha channel)

struct OpaquePNGTests {
    @Test func checksums() {
        #expect(OpaquePNG.crc32(Array("IEND".utf8)) == 0xAE42_6082)
        #expect(OpaquePNG.adler32(Array("Wikipedia".utf8)) == 0x11E6_0398)
    }

    @Test func writesAnRGBPNGThatDecodes() throws {
        // 3 × 2: red, green, blue / white, black, grey (RGBX).
        let px: [UInt8] = [255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255,
                           255, 255, 255, 255, 0, 0, 0, 255, 128, 128, 128, 255]
        let png = try #require(OpaquePNG.encodeRGB(rgbaRows: px, width: 3, height: 2))
        #expect(OpaquePNG.colorType(png) == 2)
        let image = try #require(UIImage(data: png)?.cgImage)
        #expect(image.width == 3 && image.height == 2)
        let alpha = image.alphaInfo
        #expect(alpha == .none || alpha == .noneSkipLast || alpha == .noneSkipFirst)
    }

    @Test func flattensAnyImage() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let img = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16), format: format).image { ctx in
            UIColor.orange.withAlphaComponent(0.5).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 16, height: 8))
        }
        let cg = try #require(img.cgImage)
        let png = try #require(OpaquePNG.encode(cg))
        #expect(OpaquePNG.colorType(png) == 2)
        #expect(UIImage(data: png) != nil)
    }
}

// MARK: - R4: polish to "yes"

@MainActor
struct R4Tests {
    /// App 1 (juror P0-1, UX P1-1): a plate's text is laid out inside `ChestArt.plateTextRect`, clear of the brass
    /// end-caps plus 8 pt, and the plate never grows past the width it was given.
    @Test func plateTextStaysOffTheCaps() {
        for style in PlateStyle.allCases {
            for (textWidth, maxWidth) in [(CGFloat(180), CGFloat(500)), (CGFloat(900), CGFloat(500)),
                                          (CGFloat(60), CGFloat(320))] {
                let plate = PlateFit.plateSize(maxWidth: maxWidth, style: style) { w in
                    CGSize(width: min(w ?? textWidth, textWidth), height: 30)
                }
                #expect(plate.width <= maxWidth + 0.001)
                let r = PlateFit.textRect(in: plate, style: style)
                let cap = ChestArt.plateCapWidth(plate)
                #expect(r.minX >= cap + 8 - 1)
                #expect(plate.width - r.maxX >= cap + 8 - 1)
                #expect(r.minY >= -0.001 && r.maxY <= plate.height + 0.001)
                // A short line hugs: the text gets its whole width.
                if textWidth < maxWidth / 2 { #expect(r.width >= textWidth - 1) }
            }
        }
        #expect(HintLine.minScale == 0.7)
    }

    /// App 1: the hint plate keeps 16 pt from the pause stud, centred while it can be.
    @Test func hintPlateClearsThePauseStud() {
        let live = HUDLayout.hintPlateRect
        #expect(!live.intersects(HUDLayout.pauseRect.insetBy(dx: -HUDLayout.pauseGap + 0.5,
                                                              dy: -HUDLayout.pauseGap + 0.5)))
        let band = CGRect(x: 72, y: 404, width: 500, height: 48)
        let stud = CGRect(x: 520, y: 400, width: 56, height: 56)
        let r = HUDLayout.hintPlateRect(band: band, pause: stud)
        #expect(r.maxX <= stud.minX - HUDLayout.pauseGap + 0.001)
        #expect(abs(r.midX - band.midX) < 0.001)
        let far = CGRect(x: 600, y: 300, width: 56, height: 56)
        #expect(HUDLayout.hintPlateRect(band: band, pause: far) == band)
    }

    /// App 2: one prompt at a time. The bank beat and the relic card hide the hint (a live "Freeze!" still shows), and
    /// the lesson's pay-off never sits behind the closing card (QA-3 P2-3).
    @Test func onePromptAtATime() {
        #expect(AppRules.promptBlocked(phase: .banked(elapsed: 0.3), relicCardUp: false))
        #expect(AppRules.promptBlocked(phase: .looting, relicCardUp: true))
        #expect(!AppRules.promptBlocked(phase: .looting, relicCardUp: false))
        #expect(AppRules.hintSuppressed(.dragToBag, phase: .looting, relicCardUp: true))
        #expect(AppRules.hintSuppressed(.shutToBank, phase: .banked(elapsed: 0.1), relicCardUp: false))
        #expect(!AppRules.hintSuppressed(.freeze, phase: .looting, relicCardUp: true))
        #expect(!AppRules.hintSuppressed(.dragToBag, phase: .looting, relicCardUp: false))
        var script = LessonScript(start: .bank)
        #expect(!script.isFinishing)
        let actions = script.update(LessonScript.Input(time: 1, events: [.banked(value: 8, items: 1, hushed: true)]))
        #expect(actions.isEmpty)
        #expect(script.isFinishing)
        #expect(LessonScript(start: .done).isFinishing)
        #expect(!AppRules.closingApplies(.looting, lessonFinishing: true))
        #expect(AppRules.closingApplies(.looting, lessonFinishing: false))
    }

    /// App 3 (QA-3 P1-1): an input switch to the hinge mid-run holds; a switch to the lever keeps the lid's openness.
    @Test func inputSwitchRules() {
        #expect(AppRules.switchHolds(from: .slider, to: .hinge, liveRun: true))
        #expect(AppRules.switchHolds(from: .fixed, to: .hinge, liveRun: true))
        #expect(!AppRules.switchHolds(from: .hinge, to: .hinge, liveRun: true))
        #expect(!AppRules.switchHolds(from: .slider, to: .hinge, liveRun: false))
        #expect(!AppRules.switchHolds(from: .hinge, to: .slider, liveRun: true))
        #expect(AppRules.switchKeepsOpenness(from: .hinge, to: .slider, liveRun: true))
        #expect(!AppRules.switchKeepsOpenness(from: .slider, to: .slider, liveRun: true))
        #expect(!AppRules.switchKeepsOpenness(from: .hinge, to: .slider, liveRun: false))
    }

    /// Founder (CI R4, frame 32): a fold layout never draws or takes the lever, whoever drives the lid; without a fold
    /// ("Play anyway" landscape, a phone) the lever shows for the slider, the pilot and a `lid=` hold.
    @Test func aFoldLayoutNeverUsesTheLever() {
        for input in [AppInputKind.slider, .pilot, .fixed, .hinge] {
            #expect(!AppRules.usesSlider(playRoute: true, layoutHasFold: true, input: input))
            #expect(!AppRules.usesSlider(playRoute: false, layoutHasFold: false, input: input))
            #expect(AppRules.usesSlider(playRoute: true, layoutHasFold: false, input: input) == (input != .hinge))
        }
    }

    /// App 3 (QA-3 P1-1 and its P2): the real controller. A lever run handed to the hinge (a fold appears, or the
    /// player leaves "Play anyway" for portrait) is held in the closing pause and doesn't step; "Play anyway" mid-run
    /// hands the lever the lid where it is, so the open chest never snaps shut or auto-banks.
    @Test func playAnywayHandOversNeverJumpTheLid() {
        var data = ProgressData()
        data.lessonDone = true
        data.runs = 10
        let controller = GameController(store: ProgressStore(inMemory: data), settings: SettingsStore(defaults: nil))
        controller.play()
        #expect(controller.input == .slider)
        let frame = 1.0 / 60.0
        var t = 2_000.0
        // Open gently on the lever, to half.
        controller.sliderTouch(began: true, ended: false, fraction: 0, time: t)
        for i in 1...150 {
            t += frame
            controller.sliderTouch(began: false, ended: false, fraction: Double(i) / 150 * 0.5, time: t)
            _ = controller.advance(dt: frame, now: t)
        }
        controller.sliderTouch(began: false, ended: true, fraction: 0.5, time: t)
        t += frame
        let open = controller.advance(dt: frame, now: t).0.openness
        #expect(open > 0.3)

        // The inner display in portrait (a fold): the run goes to the hinge, held, and doesn't step.
        controller.updateCanvas(CGSize(width: 669, height: 951), hasFold: true, turned: false)
        #expect(controller.input == .hinge)
        #expect(controller.isClosingPaused)
        #expect(!controller.usesSlider)
        t += frame
        let held = controller.advance(dt: frame, now: t).0
        for _ in 0..<30 {
            t += frame
            _ = controller.advance(dt: frame, now: t)
        }
        t += frame
        #expect(controller.advance(dt: frame, now: t).0.time == held.time)

        // "Play anyway" mid-run: the lever starts where the lid is (not where it was left: 0 on a hinge run).
        controller.slider.reset(openness: 0)
        controller.choosePlayAnyway()
        #expect(controller.input == .slider)
        #expect(abs(controller.slider.openness - open) < 0.001)
        controller.updateCanvas(CGSize(width: 951, height: 669), hasFold: false, turned: false)
        #expect(controller.input == .slider)
        #expect(controller.usesSlider)
        var banked = false
        var last = held
        for _ in 0..<90 {
            t += frame
            let (s, events) = controller.advance(dt: frame, now: t)
            last = s
            if events.contains(where: { e in
                if case .banked = e { return true }
                return false
            }) { banked = true }
        }
        #expect(!banked)
        #expect(last.openness > 0.3)

        // Back to portrait: "Play anyway" ends, the hinge takes over held (QA-3 P1-1).
        controller.updateCanvas(CGSize(width: 669, height: 951), hasFold: true, turned: false)
        #expect(!controller.playAnyway)
        #expect(controller.input == .hinge)
        #expect(controller.isClosingPaused)
        t += frame
        let again = controller.advance(dt: frame, now: t).0
        for _ in 0..<30 {
            t += frame
            _ = controller.advance(dt: frame, now: t)
        }
        t += frame
        #expect(controller.advance(dt: frame, now: t).0.time == again.time)
        controller.goHome()
    }

    /// App 4 (QA-3 P2-4/5, UX P2-9): VoiceOver. Stirring once per chest, a late stage line re-checked when it fires,
    /// only "Chomp!" and Waking interrupt, and the lesson's steps are announced.
    @Test func voiceOverAnnouncements() {
        var gate = AnnounceGate()
        gate.chestArrived(0)
        let first = gate.allowsStage(.stirring)
        let second = gate.allowsStage(.stirring)
        let waking1 = gate.allowsStage(.waking)
        let waking2 = gate.allowsStage(.waking)
        #expect(first && !second && waking1 && waking2)
        gate.chestArrived(1)
        let next = gate.allowsStage(.stirring)
        #expect(next)

        #expect(AppRules.stageAnnouncementDue(.waking, current: .waking, phase: .looting, paused: false))
        #expect(!AppRules.stageAnnouncementDue(.waking, current: .biting, phase: .bitten(elapsed: 0.1), paused: false))
        #expect(!AppRules.stageAnnouncementDue(.stirring, current: .asleep, phase: .looting, paused: false))
        #expect(!AppRules.stageAnnouncementDue(.stirring, current: .stirring, phase: .looting, paused: true))

        #expect(!HushCopy.queuesAnnouncement(.bitten(lostValue: 40)))
        #expect(!HushCopy.queuesAnnouncement(.stageChanged(from: .stirring, to: .waking)))
        #expect(HushCopy.queuesAnnouncement(.stageChanged(from: .asleep, to: .stirring)))
        #expect(HushCopy.queuesAnnouncement(.banked(value: 10, items: 1, hushed: true)))

        let open = LessonScript(start: .open).display(slider: true, angle: nil, hint: nil)
        #expect(LessonDisplay.announcement(from: nil, to: open) == open.line)
        #expect(LessonDisplay.announcement(from: open, to: open) == nil)
        let grab = LessonScript(start: .grab).display(slider: true, angle: nil, hint: nil)
        #expect(LessonDisplay.announcement(from: open, to: grab) == "Drag a coin into your bag.")
        let pose1 = LessonScript(start: .pose).display(slider: false, angle: 60, hint: nil)
        let pose2 = LessonScript(start: .pose).display(slider: false, angle: 100, hint: nil)
        #expect(pose1.line != pose2.line)
        #expect(LessonDisplay.announcement(from: pose1, to: pose2) == nil)
        let final = LessonScript(start: .done).display(slider: true, angle: nil, hint: nil)
        #expect(final.isFinal)
        #expect(LessonDisplay.announcement(from: grab, to: final) == LessonDisplay.finalTitle)
        #expect(LessonDisplay.announcement(from: final, to: final) == nil)
    }

    /// App 5: copy.
    @Test func r4Copy() {
        #expect(HomeView.caption(HomeLid(openness: 0, speed: 0), hinge: false).hasPrefix("Slide"))
        #expect(!HomeView.caption(HomeLid(openness: 0, speed: 0), hinge: false).contains("Drag"))
        #expect(LessonScript(start: .grab).line(slider: true, angle: nil, hint: nil) == "Drag a coin into your bag.")
        #expect(RunTip.golden == "A golden mimic! Extra gold!")
        #expect(!RunTip.golden.contains("×") && !RunTip.golden.lowercased().contains("double"))
        // "15 chests opened": counted as the strip shows them (the one the candle went out on too).
        var r = makeRun(gold: 3_000, banked: 6, hushed: 1, bites: 1)
        #expect(AppRules.chestsOpened(r) == 7)
        #expect(AppRules.story(r, outcome: RecordOutcome(), relicName: { _ in "" })
            == "7 chests opened before the candle gave out.")
        r.chestLog = Array(repeating: ChestOutcome(tier: .wooden, golden: false, value: 50, hushed: false,
                                                   bitten: false), count: 15)
        #expect(AppRules.chestsOpened(r) == 15)
        #expect(AppRules.story(r, outcome: RecordOutcome(), relicName: { _ in "" }).hasPrefix("15 chests opened"))
    }

    /// App 7 (UX P2-7): large Dynamic Type wraps instead of truncating.
    @Test func largeTypeWraps() {
        #expect(CodexView.nameLines(.large) == 2)
        #expect(CodexView.nameLines(.xxLarge) == 3)
        #expect(CodexView.nameLines(.accessibility3) == 3)
        // Home's Daily status wraps (lineLimit 2) instead of truncating; its words don't change with the size.
        #expect(HomeMenu.dailyStatus(scoredReady: true, todayGold: nil) == "Today's try ready")
        #expect(HomeMenu.dailyStatus(scoredReady: false, todayGold: 1_200).hasSuffix("today"))
        #expect(HomeMenu.dailyStatus(scoredReady: false, todayGold: nil) == "Practice")
        #expect(FadingScroll<EmptyView>.chevronStrip >= 16)
    }

    /// App 8 (juror P1-4): the pose card's Duo is drawn from the game's art (the sleeping eye at card size).
    @Test func poseArtDrawsAtCardSize() {
        let eye = ChestArt.mimicEye(wake: 0.06, size: CGSize(width: 110, height: 80))
        #expect(!eye.white.isEmpty && !eye.lidTop.isEmpty)
        #expect(!ChestArt.mimicEyeBed(size: CGSize(width: 110, height: 80)).isEmpty)
        #expect(ChestArt.lootImage(.copper, radius: 12) != nil)
        #expect(ChestArt.glyphImage(.arrowUp, side: 24) != nil)
    }

    /// App 10: Diagnostics. The channel is reported, never used to show UI; the panel lists the live hinge and the
    /// hand-off and relight angles.
    @Test func diagnosticsReportTheChannelAndAngles() throws {
        #expect(BuildChannel.kind(isDebug: true, receiptName: "sandboxReceipt") == .debug)
        #expect(BuildChannel.kind(isDebug: false, receiptName: "sandboxReceipt") == .testFlight)
        #expect(BuildChannel.kind(isDebug: false, receiptName: "receipt") == .appStore)
        #expect(BuildChannel.kind(isDebug: false, receiptName: nil) == .appStore)
        let lines = AppRules.diagnosticsLines(channel: "TestFlight", version: "1.0 (14)", hinge: 104.25, input: "hinge",
                                              handoff: 12, relight: nil, resumeAngle: 95, orientation: "mask portrait")
        #expect(lines.first == "Build: TestFlight 1.0 (14)")
        #expect(lines.contains { $0.hasPrefix("Hinge now: 104.") })
        #expect(lines.contains("Last hand-off to cover: 12.0°"))
        #expect(lines.contains("Last relight of inner: -"))
        #expect(lines.contains("Resume needs: 95.0° and still"))
        let none = AppRules.diagnosticsLines(channel: "App Store", version: "1.0 (1)", hinge: nil, input: "lever",
                                             handoff: nil, relight: nil, resumeAngle: 95, orientation: "")
        #expect(none.contains("Hinge now: no reading · lid: lever"))
        #expect(SettingsView.versionText.hasPrefix("Version "))
    }
}

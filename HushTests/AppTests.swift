import CoreGraphics
import Foundation
import QuartzCore
import SpriteKit
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

    @Test func poses() {
        let inner = CGSize(width: 669, height: 951)
        let book = CGSize(width: 951, height: 669)
        let cover = CGSize(width: 393, height: 520)
        let phone = CGSize(width: 402, height: 874)
        #expect(AppRules.pose(canvas: inner, hingeSeen: true, isShut: false) == .play)
        // R6: book pose plays (it never blocks), drawn with quarter turns.
        #expect(AppRules.pose(canvas: book, hingeSeen: true, isShut: false) == .play)
        #expect(AppRules.pose(canvas: book, hingeSeen: false, isShut: false) == .play)
        #expect(AppRules.pose(canvas: cover, hingeSeen: true, isShut: true) == .cover)
        #expect(AppRules.pose(canvas: phone, hingeSeen: false, isShut: false) == .play)
        #expect(AppRules.hasFold(canvas: inner, hingeSeen: true, demoFold: false))
        #expect(AppRules.hasFold(canvas: inner, hingeSeen: false, demoFold: false))
        #expect(!AppRules.hasFold(canvas: phone, hingeSeen: false, demoFold: false))
        #expect(AppRules.hasFold(canvas: phone, hingeSeen: false, demoFold: true))
        #expect(!AppRules.hasFold(canvas: book, hingeSeen: true, demoFold: false))
        // R6: RootView judges the fold on the portrait-equivalent canvas, so book pose is a fold.
        #expect(AppRules.hasFold(canvas: AppRules.portraitSize(book), hingeSeen: true, demoFold: false))
    }

    /// UX: a phone never shows the book-pose prompt (R1's frame 25). R6: it is the non-blocking tip.
    @Test func phoneNeverShowsTheBookCard() {
        let phone = CGSize(width: 402, height: 874)
        #expect(!AppRules.allowsForcedPoseTip(screen: phone, demoFold: false))
        #expect(AppRules.allowsForcedPoseTip(screen: phone, demoFold: true))
        #expect(AppRules.allowsForcedPoseTip(screen: CGSize(width: 669, height: 951), demoFold: false))
        #expect(!AppRules.showsPoseTip(duo: false, route: .home, lessonStep: nil, device: .landscapeLeft,
                                       dismissed: false))
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
    /// display (a pause), whatever the hinge says; R6: a landscape inner display plays.
    @Test func aSmallCanvasIsAlwaysTheCover() {
        for small in [CGSize(width: 466, height: 678), CGSize(width: 469, height: 669), CGSize(width: 669, height: 469)] {
            #expect(AppRules.pose(canvas: small, hingeSeen: true, isShut: false) == .cover)
        }
        let book = CGSize(width: 951, height: 669)
        #expect(AppRules.pose(canvas: book, hingeSeen: true, isShut: false) == .play)
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

    /// R6: the blocking card's words and "Play anyway" are gone; the tip says one short thing.
    @Test func poseTipCopy() {
        #expect(PoseTip.text == "Stand it up like a little laptop")
        #expect(HushCopy.wordCount(PoseTip.text) <= 7)
        #expect(!PoseTip.text.contains("round"))
    }

    @Test func poseReasonsSayWhy() {
        #expect(AppRules.poseReason(.cover, canvas: CGSize(width: 469, height: 669), forced: false, angle: 104.2)
                == "cover-sized 469x669 angle=104.2")
        #expect(AppRules.poseReason(.play, canvas: CGSize(width: 669, height: 951), forced: false, angle: 120)
                == "portrait 669x951")
        #expect(AppRules.poseReason(.play, canvas: CGSize(width: 951, height: 669), forced: false, angle: 104)
                == "landscape-play 951x669")
        #expect(AppRules.poseReason(.cover, canvas: CGSize(width: 669, height: 951), forced: true, angle: nil)
                .hasPrefix("forced"))
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
        // R12 rule 7: an open lid at step 1 is asked to close.
        #expect(s.line(slider: false, angle: 118, hint: nil) == LessonScript.closeToStart)
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
                #expect(cue.label == "Close the lid a little")
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
        // R11 (UX P2-2): one "to". R12 rule 3: bank = close the lid.
        #expect(s.line(slider: false, angle: nil, hint: nil) == "Close the lid to bank it.")
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
        // R12 rule 7: "Now open it… slowly." (closed lid).
        #expect(s.line(slider: false, angle: nil, hint: nil) == "Now open it… slowly. Watch the noise.")
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
            // R12: the founder's `.closeForNext` line is 7 words; every other hint keeps ≤ 6.
            #expect(HushCopy.wordCount(HushCopy.hint(hint, slider: false)) <= HushCopy.wordLimit(hint))
            #expect(HushCopy.wordCount(HushCopy.hint(hint, slider: true)) <= HushCopy.wordLimit(hint))
            #expect(HushCopy.wordCount(HushCopy.hint(hint, slider: false, lidOpen: true)) <= HushCopy.wordLimit(hint))
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
                                                              "Close the lid to bank it"])
        #expect(HushCopy.stakes(slider: true).last?.text == "Slide the lever down to bank")
        for tip in RunTip.allCases { #expect(HushCopy.wordCount(tip.text) <= 6) }
        #expect(HushCopy.wordCount(RunTip.golden) <= 6)
        #expect(RunTip.chain.text == "Hush Chain! Sleepy banks pay more")
        #expect(RunTip.chainBroken.text == "It stirred. Chain broken.")
        #expect(RunTip.golden == "A golden mimic! Extra gold!")
    }

    /// R3 (decision 3): one verb, "bank", in the lid's words on a fold and the lever's without.
    @Test func oneVerbBank() {
        #expect(HushCopy.hint(.shutToBank, slider: false) == "Close the lid to bank")
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
        // R11 (tester 11): the lever's own words on a phone.
        #expect(HomeView.caption(HomeLid(openness: 0, speed: 0), hinge: false) == "Slide the lever up… slowly.")
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

    /// App 3 (QA-3 P1-1): the real controller. A lever run handed to the hinge (a fold appears) is held in the closing
    /// pause and doesn't step. R6: "Play anyway" is gone: the same Duo turned landscape (k = 1) stays on the hinge,
    /// still a fold, never the lever, and the turn alone never pauses or re-holds the run.
    @Test func foldHandOversNeverJumpTheLid() {
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

        // R6: the Duo turned landscape (book pose / flat): still the hinge, still a fold, no lever, k odd.
        controller.updateCanvas(CGSize(width: 951, height: 669), hasFold: true, quarterTurns: 1)
        #expect(controller.input == .hinge)
        #expect(controller.layoutHasFold)
        #expect(!controller.usesSlider)
        #expect(controller.quarterTurns == 1)
        #expect(controller.pose == .play)
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

// MARK: - R5: the release candidate

@MainActor
struct R5Tests {
    private func makeController() -> GameController {
        var data = ProgressData()
        data.lessonDone = true
        data.runs = 10
        data.lifetimeGold = 4_200
        data.bestRun = 5_200
        return GameController(store: ProgressStore(inMemory: data), settings: SettingsStore(defaults: nil))
    }

    /// The ideal height of `view` laid out `width` wide, at `size` (the fonts follow the test host's own text size,
    /// iOS's default, Large).
    private func height<V: View>(_ view: V, width: CGFloat, size: DynamicTypeSize = .large) -> CGFloat {
        let host = UIHostingController(rootView: AnyView(view.environment(\.dynamicTypeSize, size)))
        return host.sizeThatFits(in: CGSize(width: width, height: 10_000)).height
    }

    /// The fold canvases: the Duo's inner display (turned round, no insets), and a 393 pt phone emulating the fold
    /// (`fold=1`), turned round (the Dynamic Island's 59 pt inset at the floor's foot) and not.
    private var duo: AppCanvas {
        AppCanvas(size: CGSize(width: 669, height: 951), insets: EdgeInsets(), hasFold: true, turned: true)
    }
    private var phoneTurned: AppCanvas {
        let raw = EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)
        return AppCanvas(size: CGSize(width: 393, height: 852), insets: AppRules.insets(raw, turnedRound: true),
                         hasFold: true, turned: true)
    }
    private var phoneUnturned: AppCanvas {
        AppCanvas(size: CGSize(width: 393, height: 852), insets: EdgeInsets(top: 59, leading: 0, bottom: 34,
                                                                             trailing: 0),
                  hasFold: true, turned: false)
    }

    /// App 2 (UX P1-1, juror P1-1, frames 30 and 39): Home's menu and the lesson's final card fit the floor half at
    /// the default text size on the Duo and on a 393 pt phone with `fold=1`, so the plain (never clipped, never
    /// scrolling) version is the one shown.
    @Test func foldLayoutsFitTheFloorHalf() {
        let controller = makeController()
        #expect(!duo.tightFloor)
        #expect(phoneTurned.tightFloor && phoneUnturned.tightFloor)
        for info in [duo, phoneTurned, phoneUnturned] {
            let floor = info.floorHalf.height
            let menu = HomeMenu(controller: controller, store: controller.store, compact: info.isCompact,
                                tight: info.tightFloor)
            let menuHeight = height(menu, width: HomeView.menuWidth(info))
            #expect(menuHeight > 200)
            #expect(menuHeight <= floor, "Home \(info.size): \(menuHeight) > \(floor)")
            let card = LessonFinalCard(controller: controller, compact: info.isCompact,
                                       width: LessonFinalCard.width(info), tight: info.tightFloor)
            let cardHeight = height(card, width: info.size.width)
            #expect(cardHeight > 200)
            #expect(cardHeight <= floor, "Final card \(info.size): \(cardHeight) > \(floor)")
        }
        #expect(HomeMenu.spacing(compact: false, tight: true) < HomeMenu.spacing(compact: false, tight: false))
        #expect(HomeMenu.playHeight(compact: false, tight: true) >= HushTheme.minTap)
    }

    /// App 1 (QA-4 P1-A, frame 44): at the accessibility sizes Home stacks the pairs one per row (and puts the Daily
    /// status under its title), so the menu grows by at least two rows.
    @Test func accessibilityHomeStacksOnePerRow() {
        let controller = makeController()
        let menu = HomeMenu(controller: controller, store: controller.store, compact: false)
        let plain = height(menu, width: 370)
        let stacked = height(menu, width: 370, size: .accessibility3)
        #expect(stacked >= plain + 2 * HushTheme.secondaryHeight)
    }

    /// App 3 (UX P1-2, frames 32 and 13c): a fold layout, turned round or NOT ("Turn the chest round" off), never draws
    /// or takes the lever: the controller hands the lid to the hinge and the scene hides the lever.
    @Test func anUnturnedFoldNeverUsesTheLever() throws {
        let controller = makeController()
        controller.play()
        controller.updateCanvas(CGSize(width: 402, height: 874), hasFold: false, turned: false)
        let scene = try #require(controller.scene)
        scene.update(100)
        #expect(controller.usesSlider)
        #expect(scene.leverShowing)

        controller.updateCanvas(CGSize(width: 402, height: 874), hasFold: true, turned: false)
        #expect(controller.layoutHasFold)
        #expect(!controller.isTurned)
        #expect(scene.layout.hasFold)
        #expect(controller.input == .hinge)
        #expect(!controller.usesSlider)
        scene.update(100.02)
        #expect(!scene.leverShowing)
        let before = controller.slider.openness
        controller.sliderTouch(began: true, ended: false, fraction: 0, time: 200)
        controller.sliderTouch(began: false, ended: false, fraction: 0.8, time: 200.5)
        #expect(controller.slider.openness == before)
        controller.goHome()
    }

    /// App 5 (juror P2-1/2, tester 9): the hint plate centres on the chest's axis, keeps 16 pt from the pause seat as
    /// drawn at each scale, and 20 pt from the fold; the Daily marker centres on the axis, 12 pt above the plaque.
    @Test func platesSitOnTheChestsAxis() {
        #expect(abs(HUDLayout.chestAxisX - ScreenLayout.canvasWidth / 2) < 0.001)
        for scale in [CGFloat(1), 0.6, 0.55] {
            let r = HUDLayout.hintPlateRect(viewScale: scale)
            #expect(r.maxY <= ScreenLayout.foldMinY - HUDLayout.foldClearance + 0.001)
            #expect(r.maxX <= ChestLayout.pauseSeat(viewScale: scale).minX - HUDLayout.pauseGap + 0.001)
            #expect(r.minX >= HUDLayout.hintBand.minX - 0.001)
            // A short plate is centred on the axis; a long one stays inside the band.
            let short = HUDLayout.plateMinX(width: 240, axis: HUDLayout.chestAxisX, band: r)
            #expect(abs(short + 120 - HUDLayout.chestAxisX) < 0.001)
            let long = HUDLayout.plateMinX(width: r.width - 10, axis: HUDLayout.chestAxisX, band: r)
            #expect(long >= r.minX - 0.001 && long + r.width - 10 <= r.maxX + 0.001)
        }
        #expect(HUDLayout.hintPlateRect.maxY <= ScreenLayout.foldMinY - HUDLayout.foldClearance + 0.001)
        #expect(HUDLayout.clearOfFold(CGRect(x: 0, y: 100, width: 10, height: 10)).minY == 100)

        // The Daily marker on a 402 pt phone: on the axis, inside the safe area, 12 pt above the plaque.
        let phone = AppCanvas(size: CGSize(width: 402, height: 874),
                              insets: EdgeInsets(top: 62, leading: 0, bottom: 34, trailing: 0), hasFold: false,
                              turned: false)
        let marker = HUDLayout.dailyMarkerCenter(phone, markerHeight: 36)
        let layout = ScreenLayout.make(hasFold: false, viewSize: phone.size)
        let fit = CanvasFit(viewSize: phone.size, layout: layout)
        #expect(abs(marker.x - fit.viewPoint(canvas: CGPoint(x: HUDLayout.chestAxisX, y: 0)).x) < 0.5)
        let t = ChestLayout.topExtension(layout)
        #expect(t >= ChestLayout.plaqueMinExtension)
        let plaqueTop = fit.viewPoint(canvas: CGPoint(x: 0, y: ChestLayout.lidBottom
            + ChestLayout.plaqueCenterY(topExtension: t) + ChestLayout.plaqueSize.height / 2)).y
        #expect(marker.y + 18 <= plaqueTop - HUDLayout.markerGap + 0.5)
        #expect(marker.y - 18 >= phone.safeRect.minY - HUDLayout.markerInsetAllowance - 0.5)
        // The Duo has no plaque: the marker sits at the lid's far end, centred.
        let duoMarker = HUDLayout.dailyMarkerCenter(duo)
        #expect(abs(duoMarker.x - 669 / 2) < 1)
        #expect(duoMarker.y == duo.safeRect.minY + AppCanvas.pauseInset + 16)
    }

    /// App 5 (juror P2-3) and 7 (UX P2-5): the bite moment hides the pause coin; the first Hush Chain tip shows at
    /// its bank, stays 3.5 s, and for 3 s only "Freeze!" may replace it; the relic card still defers every callout.
    @Test func theFirstChainTipOwnsItsBank() {
        #expect(AppRules.isBiteMoment(.bitten(elapsed: 0.2)))
        #expect(!AppRules.isBiteMoment(.looting))
        let chain = RunTip.chain.text
        #expect(AppRules.isBankTip(chain))
        #expect(!AppRules.calloutBlocked(chain, phase: .banked(elapsed: 0.1), relicCardUp: false))
        #expect(AppRules.calloutBlocked(chain, phase: .banked(elapsed: 0.1), relicCardUp: true))
        #expect(AppRules.calloutBlocked(RunTip.golden, phase: .banked(elapsed: 0.1), relicCardUp: false))
        #expect(!AppRules.calloutBlocked(RunTip.golden, phase: .looting, relicCardUp: false))
        #expect(AppRules.calloutSeconds(chain) >= 3.5)
        #expect(AppRules.calloutHold(chain) >= 3)
        #expect(AppRules.calloutHold(RunTip.golden) == 0)
        #expect(AppRules.calloutSeconds(RunTip.golden) == GameController.calloutSeconds)
        #expect(!AppRules.calloutYields(to: .dragToBag, held: true))
        #expect(!AppRules.calloutYields(to: .slower, held: true))
        #expect(AppRules.calloutYields(to: .freeze, held: true))
        #expect(AppRules.calloutYields(to: .slower, held: false))
        #expect(!AppRules.calloutYields(to: .dragToBag, held: false))
    }

    /// App 4 (QA-4 P2-E): VoiceOver hears "Slower…" once a lesson step, and no line again within 3 s.
    @Test func lessonVoiceOverNeverRepeatsSlower() {
        var gate = LessonSpeechGate()
        let slower = "Slower… it's grumbling."
        let step = "Slide the lever up… slowly. Watch the noise."
        let first = gate.allows(step, step: 2, now: 10)
        let slower1 = gate.allows(slower, step: 2, now: 11)
        let back = gate.allows(step, step: 2, now: 12.5)
        let slower2 = gate.allows(slower, step: 2, now: 20)
        let later = gate.allows(step, step: 2, now: 20)
        let nextStep = gate.allows(slower, step: 3, now: 30)
        #expect(first && slower1)
        #expect(!back)
        #expect(!slower2)
        #expect(later)
        #expect(nextStep)
    }

    /// App 4 (QA-4 P2-F): a tampered save's totals are clamped on decode, and filing a run never overflows.
    @Test func savedTotalsAreClamped() throws {
        var tampered = ProgressData()
        tampered.lifetimeGold = Int.max - 5
        tampered.bestRun = Int.max
        tampered.pendingRun = makeRun(gold: Int.max)
        let raw = try #require(ProgressStore.encode(tampered))
        var back = try #require(ProgressStore.decode(raw))
        #expect(back.lifetimeGold == ProgressRules.maxTotal)
        #expect(back.bestRun == ProgressRules.maxTotal)
        #expect(back.pendingRun?.gold == ProgressRules.maxTotal)
        let outcome = record(makeRun(gold: Int.max), &back)
        #expect(outcome.lifetimeAfter == ProgressRules.maxTotal)
        #expect(back.lifetimeGold == ProgressRules.maxTotal)
        #expect(ProgressRules.adding(Int.max, Int.max) == ProgressRules.maxTotal)
        #expect(ProgressRules.adding(5, -3) == 5)
        #expect(ProgressRules.clampTotal(-9) == 0)
    }

    /// App 6 (UX P2-7, frames 20 and 38): the phone's hero portrait gives way so the strip's two rows end above the
    /// fade, within its bounds, and one step settles it.
    @Test func resultsStripClearsTheFade() {
        let fitted = ResultsView.fittedPortrait(current: 150, stripBottom: 717, viewport: 678, fade: 36, minimum: 60,
                                                maximum: 150)
        #expect(abs(fitted - 75) < 0.001)
        let settled = ResultsView.fittedPortrait(current: fitted, stripBottom: 717 - 75, viewport: 678, fade: 36,
                                                 minimum: 60, maximum: 150)
        #expect(abs(settled - fitted) < 0.001)
        #expect(ResultsView.fittedPortrait(current: 150, stripBottom: 300, viewport: 678, fade: 36, minimum: 60,
                                           maximum: 150) == 150)
        #expect(ResultsView.fittedPortrait(current: 150, stripBottom: 2_000, viewport: 678, fade: 36, minimum: 60,
                                           maximum: 150) == 60)
        #expect(ResultsView.fittedPortrait(current: 120, stripBottom: 0, viewport: 678, fade: 36, minimum: 60,
                                           maximum: 150) == 120)
        #expect(ChestStrip.maxRows == 2)
        #expect(FadingScroll<EmptyView>.fadeHeight > 0)
        // The strip's measurement names the column's space by its literal.
        #expect(ResultsView.columnSpace == "hush.results.column")
    }

    /// App 8 (tester 10, frame 40): each badge's motif matches its meaning (and no two are alike).
    @Test func badgeArtMatchesItsMeaning() {
        let index = { (def: AchievementDef) in Achievements.all.firstIndex(of: def) ?? -1 }
        #expect(BadgePainter.motif(index: index(Achievements.fiveChests)) == .feather)
        #expect(BadgePainter.motif(index: index(Achievements.heavyBag)) == .idol)
        #expect(BadgePainter.motif(index: index(Achievements.hoard)) == .goblet)
        #expect(BadgePainter.motif(index: index(Achievements.firstRelic)) == .lantern)
        #expect(Set(BadgePainter.motifs).count == BadgePainter.motifs.count)
        #expect(BadgePainter.motifs.count == Achievements.all.count)
    }
}

// MARK: - R6: "any way up", never stuck

@MainActor
struct R6Tests {
    private func makeController() -> GameController {
        var data = ProgressData()
        data.lessonDone = true
        data.runs = 10
        return GameController(store: ProgressStore(inMemory: data), settings: SettingsStore(defaults: nil))
    }

    /// A live hinge run on the Duo's inner display (no hinge report yet: held on the closing card).
    private func makeFoldRun() -> GameController {
        let controller = makeController()
        controller.updateCanvas(CGSize(width: 669, height: 951), hasFold: true, quarterTurns: 2)
        controller.play()
        return controller
    }

    private let duoPortrait = CGSize(width: 669, height: 951)
    private let duoLandscape = CGSize(width: 951, height: 669)

    // MARK: Item 1: the founder's rule, every case

    /// ROUND-6's table, all 4 interfaces × turn round on/off × fold/no fold, plus `.unknown` keeping the last value.
    @Test func quarterTurnsTable() {
        let table: [(UIInterfaceOrientation, on: Int, off: Int)] = [
            (.portrait, 2, 0), (.landscapeRight, 1, 3), (.landscapeLeft, 3, 1), (.portraitUpsideDown, 0, 2),
        ]
        for row in table {
            #expect(AppRules.quarterTurns(interface: row.0, turnRound: true, hasFold: true) == row.on)
            #expect(AppRules.quarterTurns(interface: row.0, turnRound: false, hasFold: true) == row.off)
            #expect(AppRules.quarterTurns(interface: row.0, turnRound: true, hasFold: false) == 0)
            #expect(AppRules.quarterTurns(interface: row.0, turnRound: false, hasFold: false) == 0)
        }
        for last in 0...3 {
            #expect(AppRules.quarterTurns(interface: .unknown, turnRound: true, hasFold: true, last: last) == last)
            #expect(AppRules.quarterTurns(interface: .unknown, turnRound: false, hasFold: true, last: last) == last)
            #expect(AppRules.quarterTurns(interface: .unknown, turnRound: true, hasFold: false, last: last) == 0)
        }
        #expect(AppRules.normalisedTurns(-1) == 3)
        #expect(AppRules.normalisedTurns(6) == 2)
    }

    /// The lid (the canvas top) lands on the blurring side (the physical portrait-bottom) with turn round on, and on
    /// the opposite side with it off, for every interface.
    @Test func theLidPointsAtTheBlurringHalf() {
        let blur: [(UIInterfaceOrientation, Edge)] = [
            (.portrait, .bottom), (.landscapeRight, .trailing), (.landscapeLeft, .leading), (.portraitUpsideDown, .top),
        ]
        let opposite: [Edge: Edge] = [.top: .bottom, .bottom: .top, .leading: .trailing, .trailing: .leading]
        for (iface, side) in blur {
            let on = AppRules.quarterTurns(interface: iface, turnRound: true, hasFold: true)
            let off = AppRules.quarterTurns(interface: iface, turnRound: false, hasFold: true)
            #expect(AppRules.windowEdge(drawn: .top, quarterTurns: on) == side)
            #expect(AppRules.windowEdge(drawn: .top, quarterTurns: off) == opposite[side])
        }
    }

    /// The interface RootView draws for always agrees with the window's shape, so a fold's drawn frame is portrait.
    @Test func theSettledInterfaceMatchesTheWindow() {
        #expect(AppRules.settledInterface(.landscapeLeft, window: duoLandscape, last: .portrait) == .landscapeLeft)
        #expect(AppRules.settledInterface(.portrait, window: duoLandscape, last: .landscapeLeft) == .landscapeLeft)
        #expect(AppRules.settledInterface(.unknown, window: duoLandscape, last: .unknown) == .landscapeRight)
        #expect(AppRules.settledInterface(.landscapeRight, window: duoPortrait, last: .unknown) == .portrait)
        #expect(AppRules.settledInterface(.unknown, window: duoPortrait, last: .portraitUpsideDown)
                == .portraitUpsideDown)
        for iface in [UIInterfaceOrientation.unknown, .portrait, .landscapeLeft, .landscapeRight, .portraitUpsideDown] {
            for window in [duoPortrait, duoLandscape] {
                let o = AppRules.settledInterface(iface, window: window, last: .unknown)
                for turn in [true, false] {
                    let k = AppRules.quarterTurns(interface: o, turnRound: turn, hasFold: true)
                    let drawn = AppRules.drawnSize(window: window, quarterTurns: k)
                    #expect(drawn.height > drawn.width, "\(iface.rawValue) \(window) k=\(k)")
                }
            }
        }
    }

    // MARK: Item 2: the root frame, insets and gesture edges

    @Test func drawnFrameInsetsAndEdgesTurnWithK() {
        #expect(AppRules.drawnSize(window: duoLandscape, quarterTurns: 1) == duoPortrait)
        #expect(AppRules.drawnSize(window: duoLandscape, quarterTurns: 3) == duoPortrait)
        #expect(AppRules.drawnSize(window: duoPortrait, quarterTurns: 2) == duoPortrait)
        #expect(AppRules.portraitSize(duoLandscape) == duoPortrait)
        let safe = EdgeInsets(top: 10, leading: 2, bottom: 30, trailing: 4)
        #expect(AppRules.insets(safe, quarterTurns: 0) == safe)
        #expect(AppRules.insets(safe, quarterTurns: 2) == AppRules.insets(safe, turnedRound: true))
        let k1 = AppRules.insets(safe, quarterTurns: 1)
        #expect(k1.top == 4 && k1.leading == 10 && k1.bottom == 2 && k1.trailing == 30)
        let k3 = AppRules.insets(safe, quarterTurns: 3)
        #expect(k3.top == 2 && k3.leading == 30 && k3.bottom == 4 && k3.trailing == 10)
        #expect(AppRules.deferredEdges(live: true, quarterTurns: 0) == .bottom)
        #expect(AppRules.deferredEdges(live: true, quarterTurns: 2) == [.top, .bottom])
        #expect(AppRules.deferredEdges(live: true, quarterTurns: 1) == [.bottom, .leading])
        #expect(AppRules.deferredEdges(live: true, quarterTurns: 3) == [.bottom, .trailing])
        for k in 0...3 {
            #expect(AppRules.deferredEdges(live: false, quarterTurns: k) == [])
            #expect(AppRules.deferredEdges(live: true, quarterTurns: k).contains(.bottom))
        }
    }

    /// Demo `quarter=`: used only on a fold and only where its parity fits the window.
    @Test func forcedQuarterTurnsOnlyWhereTheyFit() {
        #expect(AppRules.forcedTurnsFit(3, window: duoLandscape, hasFold: true))
        #expect(AppRules.forcedTurnsFit(1, window: duoLandscape, hasFold: true))
        #expect(!AppRules.forcedTurnsFit(3, window: duoPortrait, hasFold: true))
        #expect(AppRules.forcedTurnsFit(0, window: duoPortrait, hasFold: true))
        #expect(!AppRules.forcedTurnsFit(2, window: duoLandscape, hasFold: true))
        #expect(!AppRules.forcedTurnsFit(3, window: duoLandscape, hasFold: false))
        #expect(DemoMode.parse("quarter=3").quarter == 3)
        #expect(DemoMode.parse("quarter=7").quarter == nil)
        #expect(DemoMode.parse("screen=run").quarter == nil)
    }

    /// CI greps `fold=` and `turned=` (k == 2) and now `k=`; the size is the real window.
    @Test func theCanvasLineCarriesK() {
        #expect(AppRules.canvasLine(duoLandscape, hasFold: true, quarterTurns: 3)
                == "HUSH-T canvas 951x669 fold=1 turned=0 k=3")
        #expect(AppRules.canvasLine(duoPortrait, hasFold: true, quarterTurns: 2)
                == "HUSH-T canvas 669x951 fold=1 turned=1 k=2")
        #expect(AppRules.canvasLine(CGSize(width: 402, height: 874), hasFold: false, quarterTurns: 0)
                .hasSuffix("fold=0 turned=0 k=0"))
    }

    // MARK: Item 3: the scene

    /// The scene gets the portrait-equivalent layout and k; the SpriteView stays the window; `turned` is k == 2.
    @Test func theSceneTurnsAndKeepsThePortraitLayout() throws {
        let controller = makeController()
        controller.updateCanvas(duoPortrait, hasFold: true, quarterTurns: 2)
        let scene = try #require(controller.scene)
        let portraitLayout = scene.layout
        #expect(scene.quarterTurns == 2)
        #expect(controller.isTurned)
        controller.updateCanvas(duoLandscape, hasFold: true, quarterTurns: 1)
        #expect(scene.quarterTurns == 1)
        #expect(!scene.turned)
        #expect(scene.layout == portraitLayout)
        #expect(scene.layout.hasFold)
        #expect(controller.quarterTurns == 1)
        #expect(!controller.isTurned)
        controller.updateCanvas(duoLandscape, hasFold: true, quarterTurns: 3)
        #expect(scene.quarterTurns == 3)
        // The R2 form still works.
        controller.updateCanvas(duoPortrait, hasFold: true, turned: true)
        #expect(scene.quarterTurns == 2)
        #expect(controller.scene === scene)
    }

    // MARK: Item 4: book pose never blocks

    @Test func bookPoseNeverBlocks() {
        for hinge in [true, false] {
            #expect(AppRules.pose(canvas: duoLandscape, hingeSeen: hinge, isShut: false) == .play)
            #expect(AppRules.pose(canvas: duoPortrait, hingeSeen: hinge, isShut: false) == .play)
        }
        #expect(AppRules.hasFold(canvas: AppRules.portraitSize(duoLandscape), hingeSeen: true, demoFold: false))
        #expect(AppRules.hasFold(canvas: AppRules.portraitSize(duoLandscape), hingeSeen: false, demoFold: false))
        // A Duo turned landscape mid-run plays on: the hinge, a fold, no lever, no pause of its own.
        let controller = makeFoldRun()
        controller.carryOn()
        #expect(!controller.isPaused)
        controller.updateCanvas(duoLandscape, hasFold: true, quarterTurns: 3)
        #expect(controller.pose == .play)
        #expect(!controller.isPaused)
        #expect(controller.input == .hinge)
        #expect(!controller.usesSlider)
        controller.goHome()
    }

    @Test func thePoseTipRules() {
        // Home and lesson step 1 only, a Duo, the device landscape, not dismissed.
        #expect(AppRules.showsPoseTip(duo: true, route: .home, lessonStep: nil, device: .landscapeLeft,
                                      dismissed: false))
        #expect(AppRules.showsPoseTip(duo: true, route: .lesson, lessonStep: 1, device: .landscapeRight,
                                      dismissed: false))
        #expect(!AppRules.showsPoseTip(duo: true, route: .lesson, lessonStep: 2, device: .landscapeRight,
                                       dismissed: false))
        for route in [AppRoute.playing, .results, .codex, .badges, .settings, .daily] {
            #expect(!AppRules.showsPoseTip(duo: true, route: route, lessonStep: nil, device: .landscapeLeft,
                                           dismissed: false))
            #expect(!AppRules.showsPoseTip(duo: true, route: route, lessonStep: nil, device: .landscapeLeft,
                                           dismissed: false, forced: true))
        }
        for device in [UIDeviceOrientation.portrait, .faceUp, .faceDown, .unknown, .portraitUpsideDown] {
            #expect(!AppRules.showsPoseTip(duo: true, route: .home, lessonStep: nil, device: device, dismissed: false))
        }
        #expect(!AppRules.showsPoseTip(duo: true, route: .home, lessonStep: nil, device: .landscapeLeft,
                                       dismissed: true))
        #expect(!AppRules.showsPoseTip(duo: false, route: .home, lessonStep: nil, device: .landscapeLeft,
                                       dismissed: false))
        #expect(AppRules.showsPoseTip(duo: false, route: .home, lessonStep: nil, device: .portrait,
                                      dismissed: true, forced: true))
        // Upright to gravity: none when iOS already turned with the device; a quarter turn when it didn't.
        #expect(AppRules.tipTurns(device: .landscapeLeft, interface: .landscapeRight) == 0)
        #expect(AppRules.tipTurns(device: .landscapeRight, interface: .landscapeLeft) == 0)
        #expect(AppRules.tipTurns(device: .landscapeLeft, interface: .portrait) == 1)
        #expect(AppRules.tipTurns(device: .landscapeRight, interface: .portrait) == 3)
        #expect(AppRules.tipTurns(device: .portrait, interface: .portrait) == 0)
        #expect(AppRules.tipTurns(device: .faceUp, interface: .portrait) == nil)
        #expect(AppRules.poseTipOnLeft(device: .landscapeLeft))
        #expect(!AppRules.poseTipOnLeft(device: .landscapeRight))
    }

    // MARK: Item 5: the orientation policy

    @Test func aLiveRunHoldsItsOrientationMenusDont() {
        for iface in [UIInterfaceOrientation.portrait, .landscapeLeft, .landscapeRight] {
            let held = OrientationLock.mask(isDuo: true, liveRun: true, inner: true, interface: iface)
            #expect(held.contains(UIInterfaceOrientationMask(rawValue: 1 << UInt(iface.rawValue))))
            #expect(held != .allButUpsideDown)
            #expect(OrientationLock.mask(isDuo: true, liveRun: false, inner: true, interface: iface)
                    == .allButUpsideDown)
            #expect(OrientationLock.mask(isDuo: true, liveRun: true, inner: false, interface: iface)
                    == .allButUpsideDown)
            #expect(OrientationLock.mask(isDuo: false, liveRun: true, inner: true, interface: iface) == .portrait)
        }
        #expect(OrientationLock.mask(isDuo: true, liveRun: true, inner: true, interface: .landscapeLeft)
                == .landscapeLeft)
        #expect(OrientationLock.mask(isDuo: true, liveRun: true, inner: true, interface: .unknown)
                == .allButUpsideDown)
        for iface in [UIInterfaceOrientation.unknown, .portrait, .landscapeLeft, .landscapeRight, .portraitUpsideDown] {
            for live in [true, false] {
                for inner in [true, false] {
                    let m = OrientationLock.mask(isDuo: true, liveRun: live, inner: inner, interface: iface)
                    #expect(!m.contains(.portraitUpsideDown))
                }
            }
        }
    }

    // MARK: Item 6: never stuck

    /// "Carry on" resumes at once, whatever the hinge says, and the run steps again.
    @Test func carryOnResumesAtOnce() {
        let controller = makeFoldRun()
        #expect(controller.input == .hinge)
        #expect(controller.isClosingPaused)
        controller.carryOn()
        #expect(!controller.isClosingPaused)
        #expect(!controller.isPaused)
        #expect(!controller.closingAwaitsHinge)
        let frame = 1.0 / 60.0
        var t = CACurrentMediaTime()
        let first = controller.advance(dt: frame, now: t).0
        for _ in 0..<30 {
            t += frame
            _ = controller.advance(dt: frame, now: t)
        }
        t += frame
        let later = controller.advance(dt: frame, now: t).0
        #expect(!controller.isClosingPaused)
        #expect(later.time > first.time)
        #expect(ClosingCard.carryOn == "Carry on")
        controller.goHome()
    }

    /// The founder's rule: the watchdog resumes only a closing pause, ≥ 6 s, with the last known angle ≥ the resume
    /// angle (R7: 92°, Feel's line), on the inner display. A lid sitting shut (no samples, a low angle, or none) stays
    /// paused.
    @Test func theWatchdogRule() {
        let ok = AppRules.watchdogResumes(pausedFor: 6.1, onlyClosing: true, liveRun: true, canvas: .inner, angle: 130)
        #expect(ok)
        #expect(!AppRules.watchdogResumes(pausedFor: 5.9, onlyClosing: true, liveRun: true, canvas: .inner,
                                          angle: 130))
        #expect(!AppRules.watchdogResumes(pausedFor: 9, onlyClosing: true, liveRun: true, canvas: .inner, angle: 91))
        #expect(!AppRules.watchdogResumes(pausedFor: 9, onlyClosing: true, liveRun: true, canvas: .inner, angle: 55))
        #expect(!AppRules.watchdogResumes(pausedFor: 9, onlyClosing: true, liveRun: true, canvas: .inner, angle: nil))
        #expect(!AppRules.watchdogResumes(pausedFor: 9, onlyClosing: true, liveRun: true, canvas: .small, angle: 130))
        #expect(!AppRules.watchdogResumes(pausedFor: 9, onlyClosing: true, liveRun: true, canvas: nil, angle: 130))
        #expect(!AppRules.watchdogResumes(pausedFor: 9, onlyClosing: false, liveRun: true, canvas: .inner, angle: 130))
        #expect(!AppRules.watchdogResumes(pausedFor: 9, onlyClosing: true, liveRun: false, canvas: .inner, angle: 130))
        #expect(!AppRules.watchdogResumes(pausedFor: .nan, onlyClosing: true, liveRun: true, canvas: .inner,
                                          angle: 130))
        #expect(AppRules.watchdogResumes(pausedFor: 9, onlyClosing: true, liveRun: true, canvas: .inner, angle: 95))
    }

    /// The real controller: a shut lid stays held; an open one is resumed by the watchdog; the menu is never.
    @Test func theWatchdogResumesAnOpenLidOnly() {
        let controller = makeFoldRun()
        #expect(controller.isClosingPaused)
        controller.hinge.ingest(angleDegrees: 40, at: CACurrentMediaTime())
        controller.backdateClosing(by: 10)
        let shut = controller.watchdogCheck(now: CACurrentMediaTime())
        #expect(!shut)
        #expect(controller.isClosingPaused)
        // The menu over the closing card: never resumed by the watchdog.
        controller.hinge.ingest(angleDegrees: 130, at: CACurrentMediaTime() + 0.05)
        controller.openMenu()
        let underMenu = controller.watchdogCheck(now: CACurrentMediaTime())
        #expect(!underMenu)
        #expect(controller.isPaused)
        controller.resume()
        controller.backdateClosing(by: 10)
        let open = controller.watchdogCheck(now: CACurrentMediaTime())
        #expect(open)
        #expect(!controller.isClosingPaused)
        #expect(!controller.isPaused)
        controller.goHome()
    }

    /// Every overlay has a reachable way back, and using it changes state.
    @Test func everyOverlayHasAWayBack() {
        // The pause menu: Resume and Home.
        let a = makeController()
        a.play()
        a.openMenu()
        #expect(a.isMenuOpen)
        a.resume()
        #expect(!a.isMenuOpen)
        a.openMenu()
        a.goHome()
        #expect(!a.isMenuOpen)
        #expect(a.route == .home)

        // The closing card: Carry on (above) and Home.
        let b = makeFoldRun()
        #expect(b.isClosingPaused)
        b.goHome()
        #expect(!b.isClosingPaused)
        #expect(b.route == .home)

        // The pose tip: ✕, never again.
        let c = makeController()
        #expect(!c.store.data.seenTips.contains(AppRules.poseTipKey))
        c.dismissPoseTip()
        #expect(c.store.data.seenTips.contains(AppRules.poseTipKey))
        #expect(!c.showsPoseTip)

        // The lesson cards: Skip (steps 2+), and the final card's "Got it" and "Not yet, take me home".
        let d = makeController()
        d.startLesson(replay: true, at: .open)
        #expect(d.route == .lesson)
        d.skipLesson()
        #expect(d.route == .home)
        d.startLesson(replay: true, at: .done)
        d.finishLesson()
        #expect(d.route == .playing)
        d.startLesson(replay: true, at: .done)
        d.finishLessonHome()
        #expect(d.route == .home)

        // Results: Again and Home.
        let e = makeController()
        e.again()
        #expect(e.route == .playing)
        e.goHome()
        #expect(e.route == .home)

        // The pages: Done.
        for page in [AppRoute.codex, .badges, .settings, .daily] {
            let f = makeController()
            f.show(page)
            #expect(f.route == page)
            f.show(.home)
            #expect(f.route == .home)
        }
    }

    // MARK: Item 7: flat is fine

    /// 175–180° in a live run: no pause, the hinge input kept (never the lever), "too wide" on the lid; a nil hinge
    /// context there keeps the last angle and the input.
    @Test func flatOpenKeepsPlaying() {
        let controller = makeFoldRun()
        let frame = 1.0 / 60.0
        var t = CACurrentMediaTime()
        controller.hinge.ingest(angleDegrees: 176, at: t)
        controller.carryOn()
        var angle = 176.0
        for i in 0..<240 {
            t += frame
            if i % 2 == 0 {
                angle = min(angle + 0.1, 180)
                controller.hinge.ingest(angleDegrees: angle, at: t)
            }
            _ = controller.advance(dt: frame, now: t)
            #expect(!controller.isClosingPaused)
        }
        #expect(!controller.isPaused)
        #expect(controller.input == .hinge)
        #expect(!controller.usesSlider)
        #expect(controller.hinge.lastLid.tooWide)
        let before = controller.hinge.angle
        controller.hingeUnavailable()
        controller.hingeUnavailable()
        #expect(controller.hinge.angle == before)
        #expect(controller.input == .hinge)
        t += frame
        _ = controller.advance(dt: frame, now: t)
        #expect(!controller.isPaused)
        // iOS turns the flat Duo landscape: still playing, still the hinge.
        controller.updateCanvas(duoLandscape, hasFold: true, quarterTurns: 1)
        t += frame
        _ = controller.advance(dt: frame, now: t)
        #expect(!controller.isPaused)
        #expect(controller.input == .hinge)
        #expect(AppRules.closingApplies(.looting))
        controller.goHome()
    }

    // MARK: Item 8: the event log

    @Test func theEventLogKeepsTheLastEighty() throws {
        var ring = EventRing()
        for i in 0..<100 {
            ring.append(EventLogEntry(time: 1_800_000_000 + Double(i), event: "e\(i)", angle: i % 2 == 0 ? 120 : nil))
        }
        #expect(ring.entries.count == EventRing.capacity)
        #expect(ring.entries.first?.event == "e20")
        #expect(ring.newestFirst.first?.event == "e99")
        let utc = try #require(TimeZone(identifier: "UTC"))
        let line = EventRing.line(EventLogEntry(time: 1_800_000_000.25, event: "pause closing", angle: 112.44),
                                  timeZone: utc)
        #expect(line.hasSuffix("  pause closing  112.4°"))
        #expect(EventRing.line(EventLogEntry(time: 0, event: "x", angle: nil), timeZone: utc).hasSuffix("  x  -"))
        let text = ring.text(timeZone: utc)
        #expect(text.split(separator: "\n").count == EventRing.capacity)
        #expect(text.hasPrefix(EventRing.line(ring.newestFirst[0], timeZone: utc)))
        // Round trip, and a tampered save longer than the ring is trimmed.
        let data = try JSONEncoder().encode(ring)
        let back = try JSONDecoder().decode(EventRing.self, from: data)
        #expect(back == ring)
        let long = (0..<200).map { EventLogEntry(time: Double($0), event: "x", angle: nil) }
        #expect(EventRing(entries: long).entries.count == EventRing.capacity)
    }

    @Test func theEventLogPersistsOnTheDevice() {
        let suite = "hush.tests.events.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        defer { defaults.removePersistentDomain(forName: suite) }
        let log = EventLog(defaults: defaults)
        log.add("pose play portrait 669x951", angle: 120)
        log.add("watchdog resume", angle: 131)
        let again = EventLog(defaults: defaults)
        #expect(again.ring.entries.count == 2)
        #expect(again.lines.first?.contains("watchdog resume") == true)
        #expect(again.text.hasPrefix("Hush event log"))
        let memory = EventLog(defaults: nil)
        memory.add("x", angle: nil)
        #expect(memory.ring.entries.count == 1)
        #expect(EventLogPanel.copyLabel == "Copy log")
    }

    /// The controller notes what the founder needs: the canvas (with k), pauses, Carry on and the watchdog.
    @Test func theControllerLogsTheEvents() {
        let controller = makeFoldRun()
        controller.carryOn()
        controller.updateCanvas(duoLandscape, hasFold: true, quarterTurns: 3)
        controller.hingeUnavailable()
        let events = controller.events.ring.entries.map(\.event)
        #expect(events.contains { $0.hasPrefix("canvas 669x951 fold=1 turned=1 k=2") })
        #expect(events.contains { $0.hasPrefix("canvas 951x669 fold=1 turned=0 k=3") })
        #expect(events.contains("paused closing"))
        #expect(events.contains("carry on"))
        #expect(events.contains("resumed"))
        #expect(events.contains("hinge nil"))
        #expect(!GameController.keepsEventLog(demo: DemoMode.parse("screen=home")))
        controller.goHome()
    }
}

// MARK: - R7: real hands (design/ROUND-7.md, App items 1–7)

/// Counts the Game Center sign-in asks (the controller's `authenticateGameCenter` is replaced in the tests).
@MainActor
private final class AskCounter {
    var asks = 0
}

@MainActor
struct R7Tests {
    private func makeController(lessonDone: Bool = true) -> GameController {
        var data = ProgressData()
        data.lessonDone = lessonDone
        data.runs = lessonDone ? 10 : 0
        return GameController(store: ProgressStore(inMemory: data), settings: SettingsStore(defaults: nil))
    }

    /// A live hinge run on the Duo's inner display (no hinge report yet: held on the closing card).
    private func makeFoldRun() -> GameController {
        let controller = makeController()
        controller.updateCanvas(CGSize(width: 669, height: 951), hasFold: true, quarterTurns: 2)
        controller.play()
        return controller
    }

    // MARK: Item 1: "down", never "shut"; a fresh chest skips "Hold still…"

    @Test func bankingSaysDownNeverShut() {
        // R12 rule 3 (founder): bank = close the lid (closing it all the way is fine now).
        #expect(HushCopy.hint(.shutToBank, slider: false) == "Close the lid to bank")
        #expect(HushCopy.bankLid == "Close the lid to bank")
        #expect(HushCopy.wordCount(HushCopy.bankLid) <= 6)
        #expect(HushCopy.stakes(slider: false).last?.text == "Close the lid to bank it")
        let bank = LessonScript(start: .bank).line(slider: false, angle: nil, hint: nil)
        #expect(bank == "Close the lid to bank it.")
        // No fold copy says "shut" (a hand told "shut" folds the Duo all the way, onto the cover display).
        var lines = HushCopy.allHints.map { HushCopy.hint($0, slider: false) }
        lines += HushCopy.stakes(slider: false).map(\.text)
        let angles: [Double?] = [nil, 60, 100, 140, 175]
        for step in LessonScript.Step.allCases {
            for angle in angles {
                lines.append(LessonScript(start: step).line(slider: false, angle: angle, hint: nil))
            }
        }
        let empty = RunResult(mode: .run, seed: 1, gold: 0, seconds: 120, chestsOpened: 2, chestsBanked: 0,
                              hushed: 0, bites: 0, relics: [], bestChestValue: 0, itemsBagged: 0,
                              highestTier: .wooden, lostToBites: 0)
        lines.append(AppRules.story(empty, outcome: RecordOutcome(), relicName: { _ in "" }))
        for line in lines { #expect(!line.lowercased().contains("shut"), "\(line)") }
    }

    /// The pure rule: a fresh chest resumes on the lift alone; a chest in play still needs lifted AND still.
    @Test func aFreshChestNeedsNoStillness() {
        #expect(AppRules.closingResumes(canResume: false, freshChest: true, lifted: true))
        #expect(!AppRules.closingResumes(canResume: false, freshChest: true, lifted: false))
        #expect(!AppRules.closingResumes(canResume: false, freshChest: false, lifted: true))
        #expect(AppRules.closingResumes(canResume: true, freshChest: false, lifted: true))
        #expect(AppRules.freshResumeGrace == 0.8)
        // The card over a fresh chest never says "Hold still…".
        for lifted in [true, false] {
            #expect(ClosingCard.title(lifted: lifted, fresh: true) == "Lift the lid for the next chest")
            #expect(!ClosingCard.title(lifted: lifted, fresh: true).contains("Hold still"))
        }
        #expect(ClosingCard.title(lifted: true) == "Hold still…")
        #expect(ClosingCard.title(lifted: true, awaitingHinge: true, fresh: true) == "Move the lid a little")
    }

    /// The real controller: the run's first chest (fresh, lid shut) resumes while the lid is still rising at 40°/s,
    /// once it passes Feel's line, with no stillness wait, and logs it.
    @Test func aFreshChestResumesOnTheLift() {
        let controller = makeFoldRun()
        #expect(controller.isClosingPaused)
        let frame = 1.0 / 60.0
        var t = CACurrentMediaTime()
        controller.hingeSample(angle: 40, time: t)
        var angle = 40.0
        var sawFresh = false
        var resumedWhileMoving = false
        for i in 0..<300 {
            t += frame
            if i % 2 == 0 && angle < 140 {
                angle += 40 * 2 * frame
                controller.hingeSample(angle: angle, time: t)
            }
            _ = controller.advance(dt: frame, now: t)
            if controller.closingFresh { sawFresh = true }
            if !controller.isClosingPaused {
                resumedWhileMoving = angle < 139
                break
            }
        }
        #expect(sawFresh)
        #expect(resumedWhileMoving)
        #expect(!controller.isPaused)
        let events = controller.events.ring.entries.map(\.event)
        #expect(events.contains("fresh chest resume"))
        controller.goHome()
    }

    // MARK: Item 2: the pause coin

    @Test func thePauseCoinNeedsAHoldOnADuoMidChest() {
        #expect(AppRules.pauseHoldSeconds == 0.35)
        #expect(AppRules.holdToPauseText == "Hold to pause")
        #expect(AppRules.pauseNeedsHold(duo: true, phase: .ready))
        #expect(AppRules.pauseNeedsHold(duo: true, phase: .looting))
        #expect(!AppRules.pauseNeedsHold(duo: true, phase: .banked(elapsed: 0.2)))
        #expect(!AppRules.pauseNeedsHold(duo: true, phase: .bitten(elapsed: 0.2)))
        #expect(!AppRules.pauseNeedsHold(duo: true, phase: .torchOut(elapsed: 0.2)))
        #expect(!AppRules.pauseNeedsHold(duo: false, phase: .looting))
        // A tap only hints; the hold pauses; where no hold is needed a tap pauses.
        #expect(AppRules.coinPress(heldFor: 0.1, needsHold: true) == .hint)
        #expect(AppRules.coinPress(heldFor: 0.34, needsHold: true) == .hint)
        #expect(AppRules.coinPress(heldFor: 0.35, needsHold: true) == .pause)
        #expect(AppRules.coinPress(heldFor: .nan, needsHold: true) == .hint)
        #expect(AppRules.coinPress(heldFor: 0.05, needsHold: false) == .pause)
        // The controller: a Duo's live chest asks for the hold.
        let controller = makeFoldRun()
        controller.carryOn()
        _ = controller.advance(dt: 1.0 / 60.0, now: CACurrentMediaTime())
        #expect(controller.pauseNeedsHold)
        controller.goHome()
    }

    // MARK: Item 3: the lesson

    /// Step 1 passes after 4 s anywhere in 80…125° ("That'll do."), and still after 0.5 s in 90…112°.
    @Test func thePoseStepIsLenient() {
        #expect(LessonScript.looseMin == 80 && LessonScript.looseMax == 125 && LessonScript.looseHold == 4)
        var s = LessonScript()
        for t in [0.0, 1.0, 2.0, 3.0, 3.95] {
            _ = s.update(LessonScript.Input(time: t, angle: 118))
            #expect(!s.isPraising)
        }
        _ = s.update(LessonScript.Input(time: 4.0, angle: 118))
        #expect(s.isPraising)
        #expect(s.line(slider: false, angle: 118, hint: nil) == LessonScript.loosePraise)
        _ = s.update(LessonScript.Input(time: 5.1, angle: 118))
        #expect(s.step == .open)

        // A wobbly rest between 85 and 124° (±5° hinge accuracy) passes too.
        var w = LessonScript()
        var t = 0.0
        var passed = false
        while t < 4.3 {
            let a: Double = Int(t * 10) % 2 == 0 ? 85 : 124
            _ = w.update(LessonScript.Input(time: t, angle: a))
            if w.isPraising { passed = true }
            t += 0.05
        }
        #expect(passed)

        // Outside 80…125° never passes; leaving the window restarts the clock.
        for angle in [79.0, 126.0, 170.0] {
            var o = LessonScript()
            _ = o.update(LessonScript.Input(time: 0, angle: angle))
            _ = o.update(LessonScript.Input(time: 6, angle: angle))
            #expect(!o.isPraising)
        }
        var r = LessonScript()
        _ = r.update(LessonScript.Input(time: 0, angle: 120))
        _ = r.update(LessonScript.Input(time: 3, angle: 140))
        _ = r.update(LessonScript.Input(time: 3.1, angle: 120))
        _ = r.update(LessonScript.Input(time: 6.5, angle: 120))
        #expect(!r.isPraising)
        _ = r.update(LessonScript.Input(time: 7.2, angle: 120))
        #expect(r.isPraising)
    }

    /// Skip shows from step 1 after 20 s of lesson (from the start on a replay).
    @Test func skipComesAfterTwentySeconds() {
        #expect(LessonScript.skipAfter == 20)
        var s = LessonScript()
        _ = s.update(LessonScript.Input(time: 5, angle: 150))
        #expect(!s.canSkip)
        _ = s.update(LessonScript.Input(time: 24.9, angle: 150))
        #expect(!s.canSkip)
        _ = s.update(LessonScript.Input(time: 25.0, angle: 150))
        #expect(s.canSkip)
        #expect(s.step == .pose)
        #expect(s.display(slider: false, angle: 150, hint: nil).canSkip)
        #expect(LessonScript(start: .pose, replay: true).canSkip)
        #expect(!LessonScript(start: .pose).canSkip)
    }

    /// Freeze is judged by displacement: a resting finger's tremor (fast but tiny) is still; a slow drift of 9 pt in
    /// 0.3 s is not, even under the old 60 pt/s drag line.
    @Test func freezeJudgesDisplacementNotDragSpeed() {
        #expect(LessonScript.stillDisplacement == 8 && LessonScript.stillWindow == 0.3)
        let frame = 1.0 / 60.0

        var s = LessonScript(start: .freeze)
        _ = s.update(LessonScript.Input(time: 0))
        let stir = s.update(LessonScript.Input(time: LessonScript.stirDelay + 0.01))
        #expect(stir == [.nudgeNoise(LessonScript.stirLevel)])
        var t = LessonScript.stirDelay + 0.01
        var calmed = false
        for i in 0..<130 {
            t += frame
            let wobble: CGFloat = i % 2 == 0 ? 0.8 : -0.8
            let held: [Int: CGPoint] = [1: CGPoint(x: 250 + wobble, y: 150)]
            let actions = s.update(LessonScript.Input(time: t, dragSpeed: 140, held: held))
            if actions.contains(.nudgeNoise(LessonScript.calmLevel)) { calmed = true }
        }
        #expect(calmed)
        #expect(!s.movedDuringFreeze)

        var m = LessonScript(start: .freeze)
        _ = m.update(LessonScript.Input(time: 0))
        _ = m.update(LessonScript.Input(time: LessonScript.stirDelay + 0.01))
        var t2 = LessonScript.stirDelay + 0.01
        var calmedM = false
        for i in 0..<130 {
            t2 += frame
            let held: [Int: CGPoint] = [1: CGPoint(x: 250 + CGFloat(i) * 0.5, y: 150)]
            let actions = m.update(LessonScript.Input(time: t2, dragSpeed: 30, held: held))
            if actions.contains(.nudgeNoise(LessonScript.calmLevel)) { calmedM = true }
        }
        #expect(!calmedM)
        #expect(m.movedDuringFreeze)

        // The pure window: nothing held is still; a new grab starts its own history; old samples age out.
        var still = LessonScript.HeldStillness()
        let none = still.update(time: 0, held: [:])
        #expect(none)
        let first = still.update(time: 0.1, held: [2: CGPoint(x: 10, y: 10)])
        #expect(first)
        let far = still.update(time: 0.2, held: [2: CGPoint(x: 30, y: 10)])
        #expect(!far)
        let later = still.update(time: 0.7, held: [2: CGPoint(x: 30, y: 10)])
        #expect(later)
    }

    // MARK: Item 4: Settings

    @Test func sensitivityAndVibrationPersistTolerantly() throws {
        let fresh = SettingsData()
        #expect(fresh.lidSensitivity == .normal)
        #expect(fresh.vibration == nil)
        // Unchosen vibration is not written at all (so it keeps following the device).
        let plain = try #require(SettingsStore.encode(fresh))
        let plainText = String(data: plain, encoding: .utf8) ?? ""
        #expect(!plainText.contains("vibration"))
        var s = SettingsData()
        s.lidSensitivity = .forgiving
        s.vibration = .strong
        let raw = try #require(SettingsStore.encode(s))
        #expect(SettingsStore.decode(raw) == s)
        // An R6 save: no new keys.
        let old = try #require(SettingsStore.decode(Data(#"{"soundOn": false, "hapticsOn": false}"#.utf8)))
        #expect(old.lidSensitivity == .normal)
        #expect(old.vibration == nil)
        #expect(!old.hapticsOn && !old.soundOn)
        // Bad values fall back; the other fields survive.
        let badJSON = #"{"lidSensitivity": "wild", "vibration": 3, "turnRound": false}"#
        let bad = try #require(SettingsStore.decode(Data(badJSON.utf8)))
        #expect(bad.lidSensitivity == .normal)
        #expect(bad.vibration == nil)
        #expect(!bad.turnRound)
        // A chosen Off means haptics off, whatever an old flag says.
        let off = try #require(SettingsStore.decode(Data(#"{"vibration": "off", "hapticsOn": true}"#.utf8)))
        #expect(off.vibration == .off)
        #expect(!off.hapticsOn)
        let careful = try #require(SettingsStore.decode(Data(#"{"lidSensitivity": "careful"}"#.utf8)))
        #expect(careful.lidSensitivity == .careful)
    }

    @Test func theSensitivityChoiceIsKeptOnTheDevice() throws {
        let suite = "hush.tests.settings.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(defaults: defaults)
        #expect(store.lidSensitivity == .normal)
        #expect(store.vibration == nil)
        store.lidSensitivity = .forgiving
        let again = SettingsStore(defaults: defaults)
        #expect(again.lidSensitivity == .forgiving)
        #expect(again.vibration == nil)
    }

    @Test func theSettingsRowsSayWhatTheyDo() {
        #expect(AppRules.sensitivityTitle == "Lid sensitivity")
        #expect(AppRules.vibrationTitle == "Vibration")
        // R11 (tester 11): the third is shown as "Strict" (stored as "careful").
        #expect(LidSensitivity.allCases.map { AppRules.sensitivityName($0) } == ["Forgiving", "Normal", "Strict"])
        #expect(HapticStrength.allCases.map(\.title) == ["Off", "Normal", "Strong"])
        for s in LidSensitivity.allCases {
            #expect(AppRules.sensitivityDetail(s).contains("The scored Daily always plays Normal."))
        }
        // What the Vibration row shows: the choice, else what the device plays.
        #expect(SettingsStore.shownVibration(chosen: nil, hapticsOn: true, hasFold: true) == .strong)
        #expect(SettingsStore.shownVibration(chosen: nil, hapticsOn: true, hasFold: false) == .normal)
        #expect(SettingsStore.shownVibration(chosen: nil, hapticsOn: false, hasFold: true) == .off)
        #expect(SettingsStore.shownVibration(chosen: .normal, hapticsOn: true, hasFold: true) == .normal)
        #expect(SettingsStore.shownVibration(chosen: .off, hapticsOn: true, hasFold: false) == .off)
        // The scored Daily plays Normal whatever is chosen (Core's override; the App passes the choice in).
        let scored: SessionOptions = SessionOptions.`for`(.daily(day: 3, scored: true), sensitivity: .forgiving)
        #expect(scored.sensitivity == .normal)
        let run: SessionOptions = SessionOptions.`for`(.run, sensitivity: .forgiving)
        #expect(run.sensitivity == .forgiving)
    }

    // MARK: Item 5: the Copy log carries the hinge trace

    @Test func theCopyLogCarriesTheHingeTrace() throws {
        #expect(AppRules.diagnosticsCopy(log: "a", trace: "b") == "a\n\nb")
        let controller = makeController()
        let now = CACurrentMediaTime()
        controller.hinge.ingest(angleDegrees: 120, at: now)
        controller.hinge.ingest(angleDegrees: 121.5, at: now + 0.033)
        controller.note("test event")
        let text = controller.diagnosticsCopyText
        #expect(text.hasPrefix("Hush event log"))
        let traceAt = try #require(text.range(of: "Hinge trace (raw, last 10 s)"))
        let eventAt = try #require(text.range(of: "test event"))
        #expect(eventAt.lowerBound < traceAt.lowerBound)
    }

    // MARK: Item 6: Game Center waits for the lesson

    @Test func gameCenterWaitsForTheLesson() {
        #expect(!AppRules.mayAuthenticateGameCenter(demo: false, lessonDone: false, route: .home))
        #expect(!AppRules.mayAuthenticateGameCenter(demo: false, lessonDone: false, route: .lesson))
        #expect(!AppRules.mayAuthenticateGameCenter(demo: false, lessonDone: true, route: .lesson))
        #expect(!AppRules.mayAuthenticateGameCenter(demo: false, lessonDone: true, route: .playing))
        #expect(AppRules.mayAuthenticateGameCenter(demo: false, lessonDone: true, route: .home))
        #expect(AppRules.mayAuthenticateGameCenter(demo: true, lessonDone: false, route: .lesson))

        let controller = makeController(lessonDone: false)
        let counter = AskCounter()
        controller.authenticateGameCenter = { counter.asks += 1 }
        controller.startLesson(replay: false)
        controller.authenticateGameCenterIfReady()
        #expect(counter.asks == 0)
        // "Got it": the first run starts; still no sign-in over it.
        controller.finishLesson()
        #expect(controller.route == .playing)
        #expect(counter.asks == 0)
        controller.goHome()
        #expect(counter.asks == 1)
        #expect(controller.gameCenterRequested)
        controller.show(.settings)
        controller.goHome()
        controller.authenticateGameCenterIfReady()
        #expect(counter.asks == 1)
    }

    // MARK: Item 7: "Other way round" in menus, up to flat

    @Test func theOtherWayRoundBannerReachesFlatInMenus() {
        #expect(!AppRules.readsUpsideDown(turned: true, cameraUp: true, angle: 175))
        #expect(AppRules.readsUpsideDown(turned: true, cameraUp: true, angle: 175, inMenus: true))
        #expect(AppRules.readsUpsideDown(turned: true, cameraUp: true, angle: 180, inMenus: true))
        #expect(AppRules.readsUpsideDown(turned: true, cameraUp: true, angle: 120, inMenus: true))
        #expect(!AppRules.readsUpsideDown(turned: true, cameraUp: true, angle: 59, inMenus: true))
        #expect(!AppRules.readsUpsideDown(turned: false, cameraUp: true, angle: 178, inMenus: true))
        #expect(!AppRules.readsUpsideDown(turned: true, cameraUp: false, angle: 178, inMenus: true))
        #expect(!AppRules.readsUpsideDown(turned: true, cameraUp: true, angle: nil, inMenus: true))
        #expect(HoldHintBanner.line(inMenus: false) == HoldHintBanner.text)
        #expect(HoldHintBanner.line(inMenus: true) == HoldHintBanner.menuText)
        #expect(!HoldHintBanner.menuText.contains("glowing"))
    }

    // MARK: The R6 watchdog follows Feel's resume line

    @Test func theWatchdogUsesFeelsResumeLine() {
        #expect(AppRules.resumeAngle == HingeLidSource.resumeAngle)
        #expect(AppRules.watchdogResumes(pausedFor: 7, onlyClosing: true, liveRun: true, canvas: .inner, angle: 90,
                                         resumeAngle: 88))
        #expect(!AppRules.watchdogResumes(pausedFor: 7, onlyClosing: true, liveRun: true, canvas: .inner, angle: 90,
                                          resumeAngle: 92))
        #expect(AppRules.watchdogResumes(pausedFor: 7, onlyClosing: true, liveRun: true, canvas: .inner, angle: 93,
                                         resumeAngle: .nan))
        #expect(!AppRules.watchdogResumes(pausedFor: 7, onlyClosing: true, liveRun: true, canvas: .inner, angle: 91,
                                          resumeAngle: .nan))
    }
}

// MARK: - R8: the player can never get stuck (design/QA-5.md)

@MainActor
struct R8Tests {
    private func makeController() -> GameController {
        var data = ProgressData()
        data.lessonDone = true
        data.runs = 10
        return GameController(store: ProgressStore(inMemory: data), settings: SettingsStore(defaults: nil))
    }

    /// A live hinge run on the Duo's inner display (no hinge report yet: held on the closing card).
    private func makeFoldRun() -> GameController {
        let controller = makeController()
        controller.updateCanvas(duoPortrait, hasFold: true, quarterTurns: 2)
        controller.play()
        return controller
    }

    private let duoPortrait = CGSize(width: 669, height: 951)
    private let duoLandscape = CGSize(width: 951, height: 669)
    private let cover = CGSize(width: 466, height: 678)
    private let column = CGSize(width: 469, height: 669)

    // MARK: P1-A: k is recomputed whenever the interface or the mask changes

    /// Every mask handed to iOS bumps `orientationEpoch` (RootView re-reads the interface on it); a run's hold let go
    /// is one. The same window with the interface turned 180° gives the other odd k.
    @Test func aMaskChangeReReadsTheInterface() {
        let controller = makeController()
        let before = controller.orientationEpoch
        controller.play()
        controller.goHome()
        let afterRun = controller.orientationEpoch
        #expect(afterRun > before)
        controller.maskChanged("mask test")
        #expect(controller.orientationEpoch == afterRun + 1)
        #expect(controller.events.ring.entries.map(\.event).contains("mask test"))
        // P1-A's repro: 951 × 669 both ways, landscapeRight → landscapeLeft: k 1 → 3 (turn round on), 3 → 1 (off).
        let right = AppRules.settledInterface(.landscapeRight, window: duoLandscape, last: .landscapeRight)
        let left = AppRules.settledInterface(.landscapeLeft, window: duoLandscape, last: right)
        #expect(left == .landscapeLeft)
        #expect(AppRules.quarterTurns(interface: right, turnRound: true, hasFold: true) == 1)
        #expect(AppRules.quarterTurns(interface: left, turnRound: true, hasFold: true) == 3)
        #expect(AppRules.quarterTurns(interface: left, turnRound: false, hasFold: true) == 1)
    }

    /// P2-1: a landscape window before iOS's report falls back on the device (named the other way round), then the
    /// constant; a landscape `last` still wins; a portrait window never takes the device's landscape.
    @Test func aLandscapeWindowFallsBackOnTheDevice() {
        #expect(AppRules.interfaceForDevice(.landscapeRight) == .landscapeLeft)
        #expect(AppRules.interfaceForDevice(.landscapeLeft) == .landscapeRight)
        for d in [UIDeviceOrientation.portrait, .portraitUpsideDown, .faceUp, .faceDown, .unknown] {
            #expect(AppRules.interfaceForDevice(d) == nil)
        }
        #expect(AppRules.settledInterface(.portrait, window: duoLandscape, last: .portrait, device: .landscapeRight)
                == .landscapeLeft)
        #expect(AppRules.settledInterface(.unknown, window: duoLandscape, last: .unknown, device: .landscapeLeft)
                == .landscapeRight)
        #expect(AppRules.settledInterface(.portrait, window: duoLandscape, last: .portrait, device: .faceUp)
                == .landscapeRight)
        #expect(AppRules.settledInterface(.portrait, window: duoLandscape, last: .landscapeRight,
                                          device: .landscapeRight) == .landscapeRight)
        #expect(AppRules.settledInterface(.landscapeRight, window: duoLandscape, last: .portrait,
                                          device: .landscapeRight) == .landscapeRight)
        #expect(AppRules.settledInterface(.landscapeLeft, window: duoPortrait, last: .portrait,
                                          device: .landscapeRight) == .portrait)
        // The portrait → landscapeLeft turn is drawn with k = 3 (turn round on) from the first frame, never 1.
        let o = AppRules.settledInterface(.portrait, window: duoLandscape, last: .portrait, device: .landscapeRight)
        #expect(AppRules.quarterTurns(interface: o, turnRound: true, hasFold: true) == 3)
    }

    // MARK: P1-B: the cover display is a screen, and its card has a way on

    @Test func aLetterboxOnTheInnerScreenPlays() {
        // R2's column on the landscape inner display (and the screen reported the column's way round).
        #expect(AppRules.isLetterbox(window: column, screen: duoLandscape))
        #expect(AppRules.isLetterbox(window: column, screen: duoPortrait))
        #expect(AppRules.pose(window: column, screen: duoLandscape, hingeSeen: true, isShut: false) == .play)
        #expect(AppRules.displayClass(window: column, screen: duoLandscape) == .inner)
        // The real cover display: its screen is cover-sized.
        #expect(!AppRules.isLetterbox(window: cover, screen: cover))
        #expect(AppRules.pose(window: cover, screen: cover, hingeSeen: true, isShut: false) == .cover)
        #expect(AppRules.displayClass(window: cover, screen: cover) == .small)
        // A stale inner screen can never make the real cover display play (no side shared).
        #expect(!AppRules.isLetterbox(window: cover, screen: duoPortrait))
        #expect(AppRules.pose(window: cover, screen: duoPortrait, hingeSeen: true, isShut: false) == .cover)
        // No screen known: R3's window rule.
        #expect(AppRules.pose(window: column, screen: .zero, hingeSeen: true, isShut: false) == .cover)
        #expect(AppRules.displayClass(window: column, screen: .zero) == .small)
        // The inner display and phones are unchanged.
        #expect(AppRules.pose(window: duoLandscape, screen: duoLandscape, hingeSeen: true, isShut: false) == .play)
        let se = CGSize(width: 375, height: 667)
        #expect(!AppRules.isLetterbox(window: se, screen: se))
        #expect(AppRules.pose(window: se, screen: se, hingeSeen: false, isShut: false) == .play)
        // The cover card's override plays.
        #expect(AppRules.pose(window: cover, screen: cover, hingeSeen: true, isShut: true, coverOverridden: true)
                == .play)
    }

    /// P2-6: a letterbox is never a hand-off (no hold, no hand-off angle); the real cover display still is.
    @Test func aLetterboxIsNeverAHandOff() {
        let controller = makeFoldRun()
        controller.hingeSample(angle: 120, time: CACurrentMediaTime())
        controller.carryOn()
        #expect(!controller.isPaused)
        controller.updateCanvas(column, hasFold: false, quarterTurns: 0, screen: duoLandscape)
        #expect(!controller.isClosingPaused)
        #expect(controller.handoffAngle == nil)
        controller.updateCanvas(cover, hasFold: false, quarterTurns: 0, screen: cover)
        #expect(controller.isClosingPaused)
        #expect(controller.handoffAngle != nil)
        controller.updateCanvas(duoPortrait, hasFold: true, quarterTurns: 2)
        controller.goHome()
    }

    @Test func theCoverCardOffersAWayOn() {
        #expect(!AppRules.coverOffersEscape(coverFor: 2.9, angle: 120))
        #expect(AppRules.coverOffersEscape(coverFor: 3, angle: 120))
        #expect(AppRules.coverOffersEscape(coverFor: 8, angle: 92))
        #expect(!AppRules.coverOffersEscape(coverFor: 8, angle: 91))
        #expect(!AppRules.coverOffersEscape(coverFor: 8, angle: nil))
        #expect(!AppRules.coverOffersEscape(coverFor: .nan, angle: 120))
        #expect(CoverCard.escapeButtons(midRun: true) == ["Carry on", "Home"])
        #expect(CoverCard.escapeButtons(midRun: false) == ["Home"])

        // Mid-run: the card offers its plate after 3 s with the hinge open; "Carry on" plays at once.
        let run = makeFoldRun()
        run.hingeSample(angle: 120, time: CACurrentMediaTime())
        run.setPose(.cover, canvas: cover)
        #expect(run.isPaused)
        let early = run.checkCoverEscape(now: CACurrentMediaTime())
        #expect(!early)
        let later = run.checkCoverEscape(now: CACurrentMediaTime() + 3.5)
        #expect(later)
        #expect(run.coverEscape)
        run.coverCarryOn()
        #expect(run.coverOverridden)
        #expect(run.pose == .play)
        #expect(!run.coverEscape)
        #expect(!run.isClosingPaused)
        #expect(!run.isPaused)
        // Shut for real: the override ends.
        run.hingeSample(angle: 4, time: CACurrentMediaTime() + 0.1)
        #expect(!run.coverOverridden)
        run.goHome()

        // In menus: "Home", drawn in play pose.
        let menus = makeController()
        menus.hingeSample(angle: 130, time: CACurrentMediaTime())
        menus.setPose(.cover, canvas: cover)
        let offered = menus.checkCoverEscape(now: CACurrentMediaTime() + 4)
        #expect(offered)
        menus.coverHome()
        #expect(menus.route == .home)
        #expect(menus.pose == .play)
        #expect(menus.coverOverridden)
        // A shut lid never offers it.
        let shut = makeController()
        shut.hingeSample(angle: 30, time: CACurrentMediaTime())
        shut.setPose(.cover, canvas: cover)
        let none = shut.checkCoverEscape(now: CACurrentMediaTime() + 10)
        #expect(!none)
        // A Duo in menus at 130° may take the menu hold on a slow runner: leave the shared lock as found.
        OrientationLock.setMenuHold(false)
    }

    // MARK: P1-C / P2-5: a silent hinge is re-subscribed

    @Test func theHingeIsReSubscribedWhenItMayHaveGoneSilent() {
        #expect(AppRules.hingeSilent(lastSample: nil, since: 5))
        #expect(AppRules.hingeSilent(lastSample: 4.9, since: 5))
        #expect(!AppRules.hingeSilent(lastSample: 5.1, since: 5))

        // "Carry on" re-subscribes.
        let a = makeFoldRun()
        let r0 = a.hingeRefresh
        a.carryOn()
        #expect(a.hingeRefresh == r0 + 1)
        a.goHome()

        // Every cover ↔ inner change re-subscribes.
        let b = makeFoldRun()
        b.hingeSample(angle: 120, time: CACurrentMediaTime())
        let r1 = b.hingeRefresh
        b.updateCanvas(cover, hasFold: false, quarterTurns: 0, screen: cover)
        #expect(b.hingeRefresh == r1 + 1)
        b.updateCanvas(duoPortrait, hasFold: true, quarterTurns: 2)
        #expect(b.hingeRefresh == r1 + 2)
        b.goHome()

        // The closing card with no report since it went up: re-subscribe, and "Move the lid a little".
        let c = makeFoldRun()
        #expect(c.isClosingPaused)
        let r2 = c.hingeRefresh
        let silent = c.closingSilenceCheck()
        #expect(silent)
        #expect(c.hingeRefresh == r2 + 1)
        #expect(c.closingAwaitsHinge)
        #expect(ClosingCard.title(lifted: true, awaitingHinge: true) == "Move the lid a little")
        c.hingeSample(angle: 60, time: CACurrentMediaTime() + 0.05)
        #expect(!c.closingAwaitsHinge)
        let heard = c.closingSilenceCheck()
        #expect(!heard)
        c.goHome()
    }

    /// The report the re-subscription delivers right after "Carry on" (a shut-looking 40°) never closes the card
    /// again; the chest keeps stepping.
    @Test func carryOnsOwnRefreshNeverClosesTheCard() {
        let controller = makeFoldRun()
        let t0 = CACurrentMediaTime()
        controller.hingeSample(angle: 40, time: t0)
        controller.carryOn()
        #expect(!controller.isClosingPaused)
        controller.hingeSample(angle: 40, time: t0 + 0.03)
        let frame = 1.0 / 60.0
        var t = t0 + 0.03
        for _ in 0..<24 {
            t += frame
            _ = controller.advance(dt: frame, now: t)
        }
        #expect(!controller.isClosingPaused)
        #expect(!controller.isPaused)
        #expect(AppRules.carryOnRefreshGrace == 0.5)
        controller.goHome()
    }

    // MARK: P1-D: the probe explains itself

    @Test func theProbeExplainsItself() {
        let frame = RootFrame(pose: .play, fold: true, turns: 3, interface: .landscapeLeft)
        let value = AppRules.canvasProbeValue(window: duoLandscape, frame: frame, held: .landscapeLeft)
        #expect(value == "k=3 w=951 h=669 fold=1 iface=landscapeLeft held=landscapeLeft")
        let k = value.split(separator: " ").first(where: { $0.hasPrefix("k=") }).map(String.init)
        #expect(k == "k=3")
        let unheld = AppRules.canvasProbeValue(window: duoPortrait, frame: RootFrame(pose: .play, fold: true, turns: 2,
                                                                                     interface: .portrait),
                                               held: .unknown)
        #expect(unheld.hasSuffix("iface=portrait held=unknown"))
        #expect(DemoMode.parse("screen=run;hold=closing").holdClosing)
        #expect(!DemoMode.parse("screen=run;hold=menu").holdClosing)
        #expect(!DemoMode.parse("screen=run").holdClosing)
    }

    // MARK: P2-2: Settings never flips under the finger

    @Test func settingsNeverFlipsUnderTheFinger() {
        #expect(AppRules.drawnTurnRound(wanted: true, frozen: false) == false)
        #expect(AppRules.drawnTurnRound(wanted: true, frozen: nil) == true)
        let controller = makeController()
        let start = controller.wantsTurnRound
        controller.show(.settings)
        controller.settings.turnRound = !start
        #expect(controller.wantsTurnRound == !start)
        #expect(controller.drawnTurnRound == start)
        #expect(controller.turnRoundPending)
        #expect(SettingsView.turnDetailLine(pending: true).hasSuffix(AppRules.turnAppliesLater))
        #expect(SettingsView.turnDetailLine(pending: false) == SettingsView.turnDetail)
        controller.show(.home)
        #expect(controller.drawnTurnRound == !start)
        #expect(!controller.turnRoundPending)
        // Outside Settings a change applies at once.
        controller.settings.turnRound = start
        #expect(controller.drawnTurnRound == start)
    }

    // MARK: P2-3: the pose tip never covers a card

    @Test func thePoseTipNeverCoversACard() {
        #expect(AppRules.poseTipAllowed(closingCard: false, menu: false))
        #expect(!AppRules.poseTipAllowed(closingCard: true, menu: false))
        #expect(!AppRules.poseTipAllowed(closingCard: false, menu: true))
        #expect(AppRules.showsPoseTip(duo: true, route: .lesson, lessonStep: 1, device: .landscapeLeft,
                                      dismissed: false))
        #expect(!AppRules.showsPoseTip(duo: true, route: .lesson, lessonStep: 1, device: .landscapeLeft,
                                       dismissed: false, cardUp: true))
        #expect(!AppRules.showsPoseTip(duo: true, route: .home, lessonStep: nil, device: .landscapeLeft,
                                       dismissed: false, forced: true, cardUp: true))
        // Lesson step 1 on a Duo waits on the closing card ("Move the lid a little"): no tip over it.
        let controller = makeController()
        controller.updateCanvas(duoPortrait, hasFold: true, quarterTurns: 2)
        controller.startLesson(replay: false)
        #expect(controller.isClosingPaused)
        #expect(!controller.showsPoseTip)
        controller.goHome()
    }

    // MARK: P2-4: menus don't re-rotate in the hand at a tabletop angle

    @Test func theMenuHoldRule() {
        var a = MenuOrientationHold()
        let unsettled = a.update(duo: true, menus: true, inner: true, angle: 110, stableFor: 0.5)
        #expect(!unsettled)
        let settled = a.update(duo: true, menus: true, inner: true, angle: 110, stableFor: 1.2)
        #expect(settled)
        // Once on, it keeps holding to 178° (a flat Duo hovers 172–180) and lets go past it.
        let nearFlat = a.update(duo: true, menus: true, inner: true, angle: 176, stableFor: 0)
        #expect(nearFlat)
        let flat = a.update(duo: true, menus: true, inner: true, angle: 179, stableFor: 9)
        #expect(!flat)
        let backAt176 = a.update(duo: true, menus: true, inner: true, angle: 176, stableFor: 9)
        #expect(!backAt176)
        let backAt120 = a.update(duo: true, menus: true, inner: true, angle: 120, stableFor: 9)
        #expect(backAt120)
        let low = a.update(duo: true, menus: true, inner: true, angle: 54, stableFor: 9)
        #expect(!low)
        // Never in a run, off the inner display, off a Duo, or with no angle.
        let cases: [(Bool, Bool, Bool, Double?)] = [(true, false, true, 110), (true, true, false, 110),
                                                    (false, true, true, 110), (true, true, true, nil)]
        for (duo, menus, inner, angle) in cases {
            var h = MenuOrientationHold()
            let on = h.update(duo: duo, menus: menus, inner: inner, angle: angle, stableFor: 9)
            #expect(!on)
        }
    }

    /// The controller: a Duo on Home at 110° holds; a run takes over with its own hold; back home it holds again;
    /// flat lets go.
    @Test func menusHoldTheirOrientationAtATabletopAngle() {
        let controller = makeController()
        controller.updateCanvas(duoPortrait, hasFold: true, quarterTurns: 2)
        controller.hinge.ingest(angleDegrees: 110, at: CACurrentMediaTime())
        controller.refreshMenuHold(now: CACurrentMediaTime() + 2)
        #expect(OrientationLock.menuHold)
        #expect(OrientationLock.holding)
        controller.play()
        #expect(OrientationLock.liveRun)
        #expect(!OrientationLock.menuHold)
        controller.goHome()
        #expect(!OrientationLock.liveRun)
        controller.refreshMenuHold(now: CACurrentMediaTime() + 2)
        #expect(OrientationLock.menuHold)
        controller.hinge.ingest(angleDegrees: 179, at: CACurrentMediaTime() + 0.1)
        controller.refreshMenuHold(now: CACurrentMediaTime() + 4)
        #expect(!OrientationLock.menuHold)
        #expect(!OrientationLock.holding)
        // The masks a hold hands iOS never exclude the interface it captured, and never allow upside down.
        for iface in [UIInterfaceOrientation.portrait, .landscapeLeft, .landscapeRight] {
            let m = OrientationLock.mask(isDuo: true, liveRun: true, inner: true, interface: iface)
            #expect(m.contains(UIInterfaceOrientationMask(rawValue: 1 << UInt(iface.rawValue))))
            #expect(!m.contains(.portraitUpsideDown))
        }
        OrientationLock.setMenuHold(false)
    }
}

// MARK: - R9 (design/notes/fix-k3-drag.md): the k = 3 drag on the Duo

/// R9: the SwiftUI overlays (`CanvasFit`, laid out in the drawn portrait frame and turned `90 * k` degrees by RootView)
/// and the scene (turned by its own world, drawn by SKView with the App's scale mode) agree on where every canvas point
/// is, for every k, on both Duo window shapes; a finger there maps back to the same canvas point; the pouch's centre is
/// in the bag; and `debug.state` formats what the App saw.
struct R9Tests {
    private static let windows = [CGSize(width: 951, height: 669), CGSize(width: 669, height: 951)]

    /// The points CI's drag aims at (the pouch, a few loot spots including the drawn amethyst of seed 7) and corners.
    private static var canvasPoints: [CGPoint] {
        let bag = HUDLayout.bagRect
        return [CGPoint(x: bag.midX, y: bag.midY), ChestLayout.canvas(fromFloor: CGPoint(x: 452, y: 197)),
                ChestLayout.canvas(fromFloor: CGPoint(x: 460, y: 150)), ChestLayout.canvas(fromFloor: CGPoint(x: 120, y: 300)),
                CGPoint(x: 10, y: 10), CGPoint(x: 660, y: 940), CGPoint(x: 335, y: 476)]
    }

    @Test @MainActor func canvasFitAgreesWithTheScenePlacementForEveryQuarterTurn() {
        for window in Self.windows {
            for k in 0...3 {
                let drawn = AppRules.drawnSize(window: window, quarterTurns: k)
                // Exactly what PlayLayer uses (`info.fit`) and what `updateCanvas` hands the scene.
                let fit = AppCanvas(size: drawn, insets: EdgeInsets(), hasFold: true, turned: k == 2).fit
                let layout = ScreenLayout.make(hasFold: true, viewSize: drawn)
                let scene = ChestScene(layout: layout)
                scene.quarterTurns = k
                let mode = AppRules.sceneScaleMode(drawn: drawn)
                scene.scaleMode = mode
                #expect(abs(fit.scale - AppRules.sceneViewScale(view: window, scene: scene.size, mode: mode)) < 0.0005)
                for p in Self.canvasPoints {
                    let ui = AppRules.windowPoint(fromDrawn: fit.viewPoint(canvas: p), drawn: drawn, window: window,
                                                  quarterTurns: k)
                    let sk = AppRules.viewPoint(fromScene: scene.scenePoint(fromCanvas: p), scene: scene.size,
                                                view: window, mode: mode)
                    #expect(near(ui.x, sk.x, 1) && near(ui.y, sk.y, 1),
                            "k=\(k) window=\(window) canvas=\(p): SwiftUI \(ui) vs scene \(sk)")
                    // A finger at the SwiftUI point: SKView's scene point, then `touch.location(in: world)`.
                    let touch = AppRules.scenePoint(fromView: ui, scene: scene.size, view: window, mode: mode)
                    let back = scene.canvasPoint(fromScene: touch)
                    #expect(near(back.x, p.x, 2) && near(back.y, p.y, 2),
                            "k=\(k) window=\(window) canvas=\(p) came back as \(back)")
                }
                // The pouch as `hud.bag` frames it drops in the bag (floor y ≥ FloorSpace.bagMinY).
                let bag = HUDLayout.bagRect
                let ui = AppRules.windowPoint(fromDrawn: fit.viewPoint(canvas: CGPoint(x: bag.midX, y: bag.midY)),
                                              drawn: drawn, window: window, quarterTurns: k)
                let back = scene.canvasPoint(fromScene: AppRules.scenePoint(fromView: ui, scene: scene.size,
                                                                            view: window, mode: mode))
                #expect(ChestLayout.floorTouchPoint(fromCanvas: back).y >= FloorSpace.bagMinY)
            }
        }
    }

    /// The Duo's own case, by hand (CI duo7: item id=0 drawn at about (692, 217), the pouch at (895, 334.5) in the
    /// 951 × 669 window at k = 3): the pouch is on the window's right, the lid's edge on the left.
    @Test @MainActor func duoLandscapeKThreePutsThePouchOnTheRight() {
        let window = CGSize(width: 951, height: 669)
        let drawn = AppRules.drawnSize(window: window, quarterTurns: 3)
        #expect(drawn == CGSize(width: 669, height: 951))
        let fit = AppCanvas(size: drawn, insets: EdgeInsets(), hasFold: true, turned: false).fit
        let bag = HUDLayout.bagRect
        let pouch = AppRules.windowPoint(fromDrawn: fit.viewPoint(canvas: CGPoint(x: bag.midX, y: bag.midY)),
                                         drawn: drawn, window: window, quarterTurns: 3)
        #expect(near(pouch.x, 895, 1.5) && near(pouch.y, 334.5, 1.5))
        let item = AppRules.windowPoint(fromDrawn: fit.viewPoint(canvas: ChestLayout.canvas(fromFloor:
                                            CGPoint(x: 452, y: 197))), drawn: drawn, window: window, quarterTurns: 3)
        #expect(near(item.x, 692, 1.5) && near(item.y, 217, 1.5))
        #expect(AppRules.sceneScaleMode(drawn: drawn) == .aspectFill)
        #expect(AppRules.sceneScaleMode(drawn: window) == .aspectFit)
    }

    @Test func touchTraceRecordsWhatTheAppSaw() {
        var t = DebugTouchTrace()
        #expect(t.hitText == "none" && t.end == .open && t.lastFloor == nil)
        t.began(at: CGPoint(x: 452, y: 197), accepted: true, picked: 0)
        #expect(t.hitText == "0" && t.end == .open)
        t.moved(to: CGPoint(x: 400, y: 300))
        t.ended(at: CGPoint(x: 335, y: 400), events: [.itemBagged(id: 0, kind: .copper, value: 10)])
        #expect(t.end == .inBag && t.began == 1 && t.moved == 1 && t.ended == 1)
        #expect(t.lastFloor == CGPoint(x: 335, y: 400))
        t.began(at: CGPoint(x: 10, y: 10), accepted: false, picked: nil)
        #expect(t.hitText == "ignored" && t.end == .open)
        t.ended(at: CGPoint(x: 10, y: 10), events: [])
        #expect(t.end == .ignored)
        t.began(at: CGPoint(x: 20, y: 20), accepted: true, picked: nil)
        #expect(t.hitText == "missed")
        t.ended(at: CGPoint(x: 20, y: 20), events: [.itemDropped(id: 3)])
        #expect(t.end == .dropped)
    }

    @Test func debugStateValueFormat() {
        var t = DebugTouchTrace()
        let empty = AppRules.debugStateValue(phase: nil, paused: [], input: .fixed, quarterTurns: 7, trace: t,
                                             route: .home, frozen: false, sceneSize: nil, viewSize: nil,
                                             scaleMode: nil)
        #expect(empty == "phase=- paused=0 input=fixed k=3 lastTouch=none hit=none ended=- touches=0/0/0 "
                + "route=home frozen=0 scene=- view=- mode=-")
        t.began(at: CGPoint(x: 451.6, y: 197.2), accepted: true, picked: 0)
        t.ended(at: CGPoint(x: 335.4, y: 399.6), events: [.itemBagged(id: 0, kind: .copper, value: 10)])
        let line = AppRules.debugStateValue(phase: .looting, paused: ["pose", "closing"], input: .hinge,
                                            quarterTurns: 3, trace: t, route: .playing, frozen: false,
                                            sceneSize: CGSize(width: 952, height: 670),
                                            viewSize: CGSize(width: 951, height: 669), scaleMode: .aspectFill)
        #expect(line == "phase=looting paused=closing+pose input=hinge k=3 lastTouch=floor(335,400) hit=0 "
                + "ended=inBag touches=1/0/1 route=playing frozen=0 scene=952x670 view=951x669 mode=fill")
        #expect(AppRules.phaseName(.banked(elapsed: 0.2)) == "banked")
    }
}

// MARK: - R10 (design/VISUAL-REGRESSION-R9.md, design/notes/r10.md): the visual regressions after the orientation rounds

/// R10: one source of truth for the pause coin and its brass seat (every k, every inset), the seat fading with a hidden
/// coin, the Settings split and pills, and the Results mimic's size.
@MainActor
struct R10Tests {
    private static let windows = [CGSize(width: 951, height: 669), CGSize(width: 669, height: 951)]

    /// Duo-like safe areas, in the WINDOW's frame (RootView turns them with k): none, a home-indicator edge, and the
    /// sim's landscape set with the sensor sides.
    private static let rawInsets = [EdgeInsets(),
                                    EdgeInsets(top: 0, leading: 0, bottom: 21, trailing: 0),
                                    EdgeInsets(top: 24, leading: 37, bottom: 21, trailing: 37),
                                    EdgeInsets(top: 37, leading: 0, bottom: 34, trailing: 0)]

    /// R1 (duo-06, k = 1: the coin sat ~33 pt off its seat): for every k and inset set, the scene's seat (given the
    /// App's canvas centre) lands on the SwiftUI coin to within a point, sized to it, and the hint plate keeps clear.
    @Test func pauseSeatSitsUnderTheCoinForEveryQuarterTurnAndInset() {
        for window in Self.windows {
            for k in 0...3 {
                for raw in Self.rawInsets {
                    let drawn = AppRules.drawnSize(window: window, quarterTurns: k)
                    let info = AppCanvas(size: drawn, insets: AppRules.insets(raw, quarterTurns: k), hasFold: true,
                                         turned: k == 2)
                    let fit = info.fit
                    let scene = ChestScene(layout: ScreenLayout.make(hasFold: true, viewSize: drawn))
                    scene.quarterTurns = k
                    let mode = AppRules.sceneScaleMode(drawn: drawn)
                    scene.scaleMode = mode
                    scene.viewScale = fit.scale
                    scene.pauseSeatCanvasCenter = info.pauseSeatCanvasCenter()
                    let seat = scene.pauseSeatRect
                    let coin = AppRules.windowPoint(fromDrawn: info.pauseCenter(), drawn: drawn, window: window,
                                                    quarterTurns: k)
                    let seatMid = scene.scenePoint(fromCanvas: CGPoint(x: seat.midX, y: seat.midY))
                    let drawnSeat = AppRules.viewPoint(fromScene: seatMid, scene: scene.size, view: window, mode: mode)
                    #expect(near(coin.x, drawnSeat.x, 1) && near(coin.y, drawnSeat.y, 1),
                            "k=\(k) window=\(window) insets=\(raw): coin \(coin) vs seat \(drawnSeat)")
                    // The seat is the coin's radius plus its 4 pt ring, in view points.
                    let ringR = ChestLayout.pauseCoinViewDiameter / 2 + ChestLayout.pauseSeatViewRing
                    #expect(near(seat.width / 2 * fit.scale, ringR, 0.5))
                    // The App's own seat rect is the scene's.
                    let appSeat = info.pauseSeatCanvasRect()
                    #expect(near(appSeat.midX, seat.midX, 0.01) && near(appSeat.midY, seat.midY, 0.01))
                    // The hint plate keeps its gap from the seat where it is really drawn.
                    let plate = HUDLayout.hintPlateRect(seat: appSeat)
                    #expect(plate.maxX <= appSeat.minX - HUDLayout.pauseGap + 0.5)
                    #expect(plate.width >= 300)
                }
            }
        }
    }

    /// Without side insets (a phone, the Duo with none) the App's centre is the scene's old view-scale clamp, so
    /// every frame that lined up before still does.
    @Test func pauseSeatMatchesTheOldClampWithoutSideInsets() {
        let phone = AppCanvas(size: CGSize(width: 402, height: 874),
                              insets: EdgeInsets(top: 62, leading: 0, bottom: 34, trailing: 0), hasFold: false,
                              turned: false)
        let duo = AppCanvas(size: CGSize(width: 669, height: 951), insets: EdgeInsets(), hasFold: true, turned: false)
        for info in [phone, duo] {
            let c = info.pauseSeatCanvasCenter()
            let old = ChestLayout.pauseCenter(viewScale: info.fit.scale)
            #expect(near(c.x, old.x, 1) && near(c.y, old.y, 1), "\(info.size): \(c) vs \(old)")
        }
    }

    /// `CanvasFit.canvasPoint(view:)` undoes `viewPoint(canvas:)` (portrait fill and landscape fit).
    @Test func canvasPointInvertsViewPoint() {
        for size in [CGSize(width: 402, height: 874), CGSize(width: 669, height: 951), CGSize(width: 951, height: 669)] {
            let fit = CanvasFit(viewSize: size)
            for p in [CGPoint(x: 0, y: 0), CGPoint(x: 622, y: 400), CGPoint(x: 335, y: 952), CGPoint(x: 12, y: -40)] {
                let back = fit.canvasPoint(view: fit.viewPoint(canvas: p))
                #expect(near(back.x, p.x, 0.01) && near(back.y, p.y, 0.01))
            }
        }
    }

    /// R5: the coin hides under the pause menu, the closing card, the final lesson card and the bite; the seat's
    /// target follows (0 whenever the coin is hidden).
    @Test func pauseSeatFadesWithTheCoin() {
        #expect(!AppRules.pauseCoinHidden(menuOpen: false, closingPaused: false, finalLessonCard: false))
        #expect(AppRules.pauseCoinHidden(menuOpen: true, closingPaused: false, finalLessonCard: false))
        #expect(AppRules.pauseCoinHidden(menuOpen: false, closingPaused: true, finalLessonCard: false))
        #expect(AppRules.pauseCoinHidden(menuOpen: false, closingPaused: false, finalLessonCard: true))
        #expect(AppRules.pauseCoinHidden(menuOpen: false, closingPaused: false, finalLessonCard: false, biting: true))
        #expect(SceneFloorHUD.seatTarget(biting: false, coinHidden: false) == 1)
        #expect(SceneFloorHUD.seatTarget(biting: false, coinHidden: true) == 0)
        #expect(SceneFloorHUD.seatTarget(biting: true, coinHidden: false) == 0)
    }

    /// R3: the Duo's Settings uses both halves; a phone keeps one column; the pills stack at the accessibility sizes;
    /// the scroll's foot is small now that the fade only shows while more is below.
    @Test func settingsUseBothHalvesAndPillsFit() {
        #expect(SettingsView.splitsAcrossHalves(hasFold: true))
        #expect(!SettingsView.splitsAcrossHalves(hasFold: false))
        #expect(SettingChoice<Int>.stacksPills(.accessibility1))
        #expect(SettingChoice<Int>.stacksPills(.accessibility5))
        #expect(!SettingChoice<Int>.stacksPills(.xxxLarge))
        #expect(!SettingChoice<Int>.stacksPills(.large))
        #expect(SettingChoice<Int>.pillPadding >= 10)
        #expect(PageScaffold<EmptyView>.scrollFoot >= 8 && PageScaffold<EmptyView>.scrollFoot < 72)
        // Content that fits is never faded (the old mask always faded the last 10 %: frame 24's Credits).
        let fits = FadingScroll<EmptyView>.state(contentHeight: 500, viewHeight: 520, offset: 0)
        #expect(!fits.overflows && fits.atEnd)
    }

    /// R4: the Results chest draws at least 90 pt wide on a phone at its smallest, and larger on the Duo's lid half;
    /// the phone's fitted portrait never goes under that floor.
    @Test func resultsMimicIsAClearChest() {
        #expect(ResultsView.drawnChestWidth(portrait: ResultsView.minPortrait) >= 90)
        #expect(ResultsView.drawnChestWidth(portrait: 20) >= 90)
        let duoLid = AppCanvas(size: CGSize(width: 669, height: 951), insets: EdgeInsets(), hasFold: true,
                               turned: false).lidHalf.height
        let duo = ResultsView.drawnChestWidth(portrait: ResultsView.duoPortrait(lidHeight: duoLid))
        #expect(duo > ResultsView.drawnChestWidth(portrait: ResultsView.minPortrait) + 20)
        let fitted = ResultsView.fittedPortrait(current: 150, stripBottom: 900, viewport: 700, fade: 36,
                                                minimum: ResultsView.minPortrait, maximum: 150)
        #expect(fitted >= ResultsView.minPortrait)
        // The ratio is the portrait scene's own geometry (600 × 480 aspect-fit, a 400-unit box, a 330-unit chest).
        #expect(PortraitScenes.size == CGSize(width: 600, height: 480))
        #expect(MimicPortraitScene.box == 400)
    }
}

// MARK: - R11 (design/ROUND-11.md App items 1–9, design/notes/app-R11.md): last polish before launch

/// R11: Forgiving is findable (option lines, "Strict", the Results nudge), a first Skip teaches the gist, the lever's
/// words on phone Home, the copy fixes, VoiceOver on the never-stuck cards, the Duo Settings split, the QA-6 P2s and
/// the stronger Results fade.
@MainActor
struct R11Tests {
    private func makeController(lessonDone: Bool = true, runs: Int = 10) -> GameController {
        var data = ProgressData()
        data.lessonDone = lessonDone
        data.runs = runs
        return GameController(store: ProgressStore(inMemory: data), settings: SettingsStore(defaults: nil))
    }

    /// A live hinge run on the Duo's inner display (no hinge report yet: held on the closing card).
    private func makeFoldRun() -> GameController {
        let controller = makeController()
        controller.updateCanvas(CGSize(width: 669, height: 951), hasFold: true, quarterTurns: 2)
        controller.play()
        return controller
    }

    private func height<V: View>(_ view: V, width: CGFloat, size: DynamicTypeSize = .large) -> CGFloat {
        let host = UIHostingController(rootView: AnyView(view.environment(\.dynamicTypeSize, size)))
        return host.sizeThatFits(in: CGSize(width: width, height: 10_000)).height
    }

    // MARK: Item 4: phone Home speaks of the lever (tester 11, three rounds running)

    /// Phone Home's resting caption is the lever's words, word for word the lesson's step 1 and the run's hint, never
    /// "its lid" (the source of "Slide its lid up… slowly." was `HomeView.caption`'s phone branch).
    @Test func phoneHomeUsesLeverWords() {
        let rest = HomeView.caption(HomeLid(openness: 0, speed: 0), hinge: false)
        #expect(rest == HomeView.phoneCaption)
        #expect(rest.lowercased().contains("lever"))
        // ("slide" contains "lid", CI 40662837159: check the phrases, not the letters.)
        let lower = rest.lowercased()
        #expect(!lower.contains("the lid") && !lower.contains("its lid"))
        #expect(rest == LessonScript(start: .pose).line(slider: true, angle: nil, hint: nil))
        #expect(rest.hasPrefix(HushCopy.hint(.openSlowly, slider: true)))
        // The Duo keeps the lid's words.
        #expect(HomeView.caption(HomeLid(openness: 0, speed: 0), hinge: true) == "Lift the lid… slowly.")
    }

    // MARK: Item 1: Forgiving is findable; "Careful" is "Strict"

    @Test func everySensitivityOptionSaysWhenToPickIt() {
        #expect(AppRules.sensitivityLine(.forgiving) == "For a stiff hinge or shaky hands. Easier to stay quiet.")
        #expect(AppRules.sensitivityLine(.normal) == "If it wakes while you're being gentle, try Forgiving.")
        #expect(AppRules.sensitivityLine(.careful) == "For thieves who never creak.")
        // The scored Daily line stays, whatever is chosen.
        for s in LidSensitivity.allCases {
            #expect(AppRules.sensitivityDetail(s) == AppRules.scoredDailyLine)
        }
        #expect(AppRules.scoredDailyLine == "The scored Daily always plays Normal.")
        #expect(AppRules.sensitivityName(.careful) == "Strict")
        #expect(!LidSensitivity.allCases.map { AppRules.sensitivityName($0) }.contains("Careful"))
    }

    /// The rename keeps every save: "careful" (R7–R10) decodes to Strict, "strict" too, and Strict is written back
    /// as "careful".
    @Test func strictIsStoredAsCareful() throws {
        let old = try #require(SettingsStore.decode(Data(#"{"lidSensitivity": "careful"}"#.utf8)))
        #expect(old.lidSensitivity == .careful)
        #expect(AppRules.sensitivityName(old.lidSensitivity) == "Strict")
        let alias = try #require(SettingsStore.decode(Data(#"{"lidSensitivity": "strict"}"#.utf8)))
        #expect(alias.lidSensitivity == .careful)
        let number = try #require(SettingsStore.decode(Data(#"{"lidSensitivity": 2, "soundOn": false}"#.utf8)))
        #expect(number.lidSensitivity == .normal)
        #expect(!number.soundOn)
        #expect(SettingsData.sensitivity(stored: nil) == .normal)
        #expect(SettingsData.sensitivity(stored: "forgiving") == .forgiving)
        #expect(SettingsData.sensitivity(stored: "wild") == .normal)
        var strict = SettingsData()
        strict.lidSensitivity = .careful
        let raw = try #require(SettingsStore.encode(strict))
        let text = String(decoding: raw, as: UTF8.self)
        #expect(text.contains("\"careful\""))
        let back = try #require(SettingsStore.decode(raw))
        #expect(back.lidSensitivity == .careful)
        // Through the store, on the device.
        let suite = "hush.tests.r11.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data(#"{"lidSensitivity": "careful"}"#.utf8), forKey: SettingsStore.key)
        let store = SettingsStore(defaults: defaults)
        #expect(store.lidSensitivity == .careful)
    }

    /// The nudge fires once, only at Normal, only after ≥ 3 bites in one of the first 2 runs, never on the scored
    /// Daily, the lesson or attract.
    @Test func theForgivingNudgeRule() {
        let n = AppRules.self
        #expect(n.offersForgivingNudge(mode: .run, bites: 3, runsSoFar: 1, sensitivity: .normal, seen: false))
        #expect(n.offersForgivingNudge(mode: .run, bites: 5, runsSoFar: 2, sensitivity: .normal, seen: false))
        #expect(n.offersForgivingNudge(mode: .daily(day: 4, scored: false), bites: 4, runsSoFar: 1,
                                       sensitivity: .normal, seen: false))
        // Once ever.
        #expect(!n.offersForgivingNudge(mode: .run, bites: 5, runsSoFar: 1, sensitivity: .normal, seen: true))
        // Never at Forgiving or Strict.
        #expect(!n.offersForgivingNudge(mode: .run, bites: 5, runsSoFar: 1, sensitivity: .forgiving, seen: false))
        #expect(!n.offersForgivingNudge(mode: .run, bites: 5, runsSoFar: 1, sensitivity: .careful, seen: false))
        // Too few bites, too late.
        #expect(!n.offersForgivingNudge(mode: .run, bites: 2, runsSoFar: 1, sensitivity: .normal, seen: false))
        #expect(!n.offersForgivingNudge(mode: .run, bites: 6, runsSoFar: 3, sensitivity: .normal, seen: false))
        #expect(!n.offersForgivingNudge(mode: .run, bites: 6, runsSoFar: 0, sensitivity: .normal, seen: false))
        // Never on the scored Daily, the lesson or attract.
        #expect(!n.offersForgivingNudge(mode: .daily(day: 4, scored: true), bites: 6, runsSoFar: 1,
                                        sensitivity: .normal, seen: false))
        #expect(!n.offersForgivingNudge(mode: .lesson, bites: 6, runsSoFar: 1, sensitivity: .normal, seen: false))
        #expect(!n.offersForgivingNudge(mode: .attract, bites: 6, runsSoFar: 1, sensitivity: .normal, seen: false))
        #expect(AppRules.forgivingNudgeLine == "Keeps waking? Try a forgiving lid.")
        #expect(AppRules.forgivingNudgeButton == "Make it forgiving")
        #expect(AppRules.forgivingNudgeDone == "Forgiving on. Change it in Settings.")
        // A summary offers nothing unless told.
        #expect(!ResultSummary(result: makeRun(), outcome: RecordOutcome(), title: "", story: "", rankTitle: "",
                               nextRankTitle: nil, rankProgressBefore: 0, rankProgressAfter: 0, againLabel: "")
            .offersForgiving)
    }

    /// "Make it forgiving" sets the player's Lid sensitivity (the next run plays it).
    @Test func makeItForgivingSetsTheLid() {
        let c = makeController(runs: 1)
        #expect(c.settings.lidSensitivity == .normal)
        c.makeLidForgiving()
        #expect(c.settings.lidSensitivity == .forgiving)
    }

    // MARK: Item 2: a first Skip lands on the stakes card

    @Test func aFirstSkipTeachesTheGist() {
        var s = LessonScript()
        let before = s.display(slider: false, angle: nil, hint: nil)
        s.skipToStakes()
        let d = s.display(slider: false, angle: nil, hint: nil)
        #expect(d.isFinal)
        #expect(d.gist)
        #expect(d.finalCardTitle == "Here's the gist, little thief.")
        #expect(LessonDisplay.announcement(from: before, to: d) == AppRules.gistTitle)
        // Reached normally, it is still "Lovely work…".
        let earned = LessonScript(start: .done).display(slider: false, angle: nil, hint: nil)
        #expect(!earned.gist)
        #expect(earned.finalCardTitle == LessonDisplay.finalTitle)

        // The controller: a first lesson's Skip stays in the lesson, on the card; "Got it" starts the first run.
        let c = makeController(lessonDone: false, runs: 0)
        c.startLesson(replay: false)
        c.skipLesson()
        #expect(c.route == .lesson)
        #expect(c.lessonDisplay?.isFinal == true)
        #expect(c.lessonDisplay?.gist == true)
        #expect(c.store.data.lessonDone)
        c.finishLesson()
        #expect(c.route == .playing)
        c.goHome()
        // A replay's Skip still goes Home.
        let r = makeController()
        r.startLesson(replay: true, at: .open)
        r.skipLesson()
        #expect(r.route == .home)
    }

    /// The stakes card says how to pause on a Duo's floor (≤ 6 words), not on a tight fold floor or a phone, and the
    /// Duo's four-row card still fits its floor half at the default size.
    @Test func theStakesCardSaysHowToPause() {
        let duoRows = LessonFinalCard.rows(slider: false, tight: false)
        #expect(duoRows.count == 4)
        #expect(duoRows.last?.text == "Close the lid to pause")
        #expect(duoRows.last?.icon == .pause)
        #expect(LessonFinalCard.rows(slider: false, tight: true).count == 3)
        #expect(LessonFinalCard.rows(slider: true, tight: false).count == 3)
        for slider in [true, false] { #expect(HushCopy.wordCount(HushCopy.pauseStake(slider: slider).text) <= 6) }
        #expect(!HushCopy.pauseStake(slider: false).text.lowercased().contains("shut"))

        let c = makeController()
        c.updateCanvas(CGSize(width: 669, height: 951), hasFold: true, quarterTurns: 2)
        #expect(!c.sliderWording)
        let duo = AppCanvas(size: CGSize(width: 669, height: 951), insets: EdgeInsets(), hasFold: true, turned: true)
        #expect(!duo.tightFloor)
        let card = LessonFinalCard(controller: c, compact: duo.isCompact, width: LessonFinalCard.width(duo),
                                   tight: duo.tightFloor)
        let cardHeight = height(card, width: duo.size.width)
        #expect(cardHeight > 200)
        #expect(cardHeight <= duo.floorHalf.height, "Final card \(cardHeight) > \(duo.floorHalf.height)")
    }

    // MARK: Item 4: copy

    @Test func theCopyFixes() {
        // R12 rule 7: the lesson's chest words ("Close the lid…").
        #expect(HushCopy.hint(.easeLidDown, slider: false) == "Close the lid a little first")
        #expect(HushCopy.wordCount(HushCopy.hint(.easeLidDown, slider: false)) <= 6)
        // "Ease the lid down" is gone.
        for hint in HushCopy.allHints {
            #expect(!HushCopy.hint(hint, slider: false).hasPrefix("Ease the lid down"))
        }
        let open = LessonScript(start: .open).line(slider: false, angle: nil, hint: .easeLidDown)
        #expect(open == "Close the lid a little first.")
        let lower = LessonScript(start: .pose).line(slider: false, angle: 140, hint: nil)
        #expect(lower == "Close the lid to start")
        let bank = LessonScript(start: .bank).line(slider: false, angle: nil, hint: nil)
        #expect(bank == "Close the lid to bank it.")
        #expect(bank.components(separatedBy: " to ").count == 2)   // one "to"
        let five = RunResult(mode: .run, seed: 1, gold: 900, seconds: 100, chestsOpened: 8, chestsBanked: 3,
                             hushed: 0, bites: 5, relics: [], bestChestValue: 300, itemsBagged: 12,
                             highestTier: .iron, lostToBites: 400)
        #expect(AppRules.causeLine(five) == "The mimic bit you 5 times, and your candle burned out.")
        #expect(AppRules.causeLine(makeRun(bites: 1)) == "The mimic bit you once, and your candle burned out.")
        #expect(AppRules.causeLine(makeRun(bites: 0)) == "Your candle burned out.")
    }

    // MARK: Item 5: "Hushed!" only on a Hushed bank (not a bug: frames 07b/14 and 19 were different runs)

    /// The bank's "Hushed!" (the scene's eyebrow and VoiceOver) comes from `banked(hushed:)` alone: ci19s 07b and 14
    /// logged `hushed=1` (the perfect pilot), 19 was the novice's run (no Hushed bank, "0 Hushed").
    @Test func hushedIsSaidOnlyForAHushedBank() {
        #expect(HushCopy.announcement(.banked(value: 179, items: 6, hushed: false)) == "Banked 179 gold.")
        #expect(HushCopy.announcement(.banked(value: 179, items: 6, hushed: false), chain: 1.1) == "Banked 179 gold.")
        #expect(HushCopy.announcement(.banked(value: 197, items: 6, hushed: true)) == "Hushed! Banked 197 gold.")
    }

    // MARK: Item 6: VoiceOver

    @Test func voiceOverHearsTheChainAndTheEscapes() {
        let events: [HeistEvent] = [.banked(value: 197, items: 6, hushed: true), .chainUp(count: 1, multiplier: 1.1)]
        let m = GameController.chainMultiplier(in: events)
        #expect(m == 1.1)
        #expect(GameController.chainMultiplier(in: [.banked(value: 9, items: 1, hushed: false)]) == nil)
        #expect(HushCopy.announcement(events[0], chain: m) == "Hushed! Banked 197 gold. Hush Chain, times 1.1.")
        #expect(HushCopy.announcement(.chainUp(count: 1, multiplier: 1.1)) == nil)
        #expect(AppRules.escapeAnnouncement(midRun: true) == "Carry on is ready.")
        #expect(AppRules.escapeAnnouncement(midRun: false).contains("Home"))
        // A VoiceOver double-tap pauses at once: the hint says what it does, not "press and hold".
        #expect(PauseCoin.accessibilityHintText == "Pauses the chest")
        #expect(!PauseCoin.accessibilityHintText.lowercased().contains("hold"))
    }

    // MARK: Item 7: the Duo Settings lid group fits

    @Test func playSoundOnSilentMovedToTheFloor() {
        #expect(!SettingsView.lidGroup.contains(SettingsView.silentTitle))
        #expect(SettingsView.lidGroup == ["Sound", "Vibration", "Lid sensitivity"])
        #expect(SettingsView.floorGroup(duo: true) == [SettingsView.silentTitle, SettingsView.turnTitle, "Reduce motion"])
        #expect(SettingsView.floorGroup(duo: false) == [SettingsView.silentTitle, "Reduce motion"])
        // QA-6 P2-4: VoiceOver reads the lid half (the title) first, however the halves are drawn.
        #expect(PageScaffold<EmptyView>.lidReadingPriority > PageScaffold<EmptyView>.floorReadingPriority)
    }

    // MARK: Item 8: QA-6 P2s

    /// P2-2: a healthy hinge at rest re-delivers after the 3 s refresh, so the words never flip to "Move the lid a
    /// little" (the copy check is a second later and finds the report).
    @Test func theClosingCardNoLongerFlickersAtThreeSeconds() {
        let c = makeFoldRun()
        #expect(c.isClosingPaused)
        let before = c.hingeRefresh
        let refreshed = c.closingSilenceRefresh()
        #expect(refreshed)
        #expect(c.hingeRefresh == before + 1)
        c.hingeSample(angle: 60, time: CACurrentMediaTime() + 0.05)
        let flipped = c.closingSilenceCopy()
        #expect(!flipped)
        #expect(!c.closingAwaitsHinge)
        #expect(AppRules.closingCopyCheckDelay >= 0.5)
        c.goHome()
        OrientationLock.setMenuHold(false)
    }

    /// P2-3: the cover card re-subscribes a hinge silent since it went up, once.
    @Test func theCoverCardRefreshesASilentHinge() {
        let c = makeController()
        c.hingeSample(angle: 120, time: CACurrentMediaTime() - 1)
        c.setPose(.cover, canvas: CGSize(width: 466, height: 678))
        let before = c.hingeRefresh
        let silent = c.coverSilenceCheck()
        #expect(silent)
        #expect(c.hingeRefresh == before + 1)
        c.hingeSample(angle: 120, time: CACurrentMediaTime() + 0.05)
        let again = c.coverSilenceCheck()
        #expect(!again)
        c.setPose(.play, canvas: CGSize(width: 669, height: 951))
        OrientationLock.setMenuHold(false)
    }

    /// P2-5: a system sheet is never held sideways: menus don't hold while one is up.
    @Test func aSystemSheetIsNeverHeld() {
        #expect(AppRules.menuHoldCountsMenus(systemSheetUp: false))
        #expect(!AppRules.menuHoldCountsMenus(systemSheetUp: true))
        var hold = MenuOrientationHold()
        let on = hold.update(duo: true, menus: true, inner: true, angle: 120, stableFor: 2)
        #expect(on)
        let sheet = hold.update(duo: true, menus: AppRules.menuHoldCountsMenus(systemSheetUp: true), inner: true,
                                angle: 120, stableFor: 2)
        #expect(!sheet)
    }

    /// Scene R11 wired: the badges (page, Results, the Game Center export) are the Scene's milled-bezel image, in the
    /// tier's metal, and Heavy Bag's glyph is the sack.
    @Test func theBadgesAreTheScenesStruckMetal() {
        #expect(BadgePainter.metal(.bronze) == .bronze)
        #expect(BadgePainter.metal(.silver) == .silver)
        #expect(BadgePainter.metal(.gold) == .gold)
        #expect(BadgePainter.metal(BadgePainter.tier(index: 11)) == .gold)
        let small = BadgePainter.image(motif: BadgePainter.motif(index: 5), tier: .silver, earned: false, side: 76,
                                       scale: 2)
        #expect(small != nil)
        #expect(BadgePainter.image(motif: .key, tier: .bronze, earned: true, side: 0, scale: 1) == nil)
        #expect(ChestArt.badgeGlyph(BadgePainter.motif(index: 5)) == .sack)
    }

    /// The scene's callouts take the plate's hint away while they show (ROUND-11 Scene 1).
    @Test func theHintStepsAsideForASceneCallout() {
        #expect(AppRules.hintYieldsToScene(sceneCallout: true))
        #expect(!AppRules.hintYieldsToScene(sceneCallout: false))
    }

    // MARK: Items 3 and 9: demo keys; the closing card at AX sizes; the Results fade

    @Test func theNewDemoKeysParse() {
        let hold = DemoMode.parse("screen=run;mode=run;seed=7;lid=0.6;fold=1;turn=0;hint=holdToPause")
        #expect(hold.holdHint && hold.fold)
        let cover = DemoMode.parse("screen=cover;midRun=1;escape=1")
        #expect(cover.effectiveScreen == .cover && cover.midRun && cover.coverEscape)
        let plain = DemoMode.parse("screen=cover")
        #expect(!plain.midRun && !plain.coverEscape && !plain.holdHint)
        #expect(PauseCoin.demoFill > 0 && PauseCoin.demoFill < 1)
    }

    @Test func theClosingCardFitsOrScrollsAtTheAccessibilitySizes() {
        #expect(ClosingCard.fitsByStages(.accessibility1))
        #expect(ClosingCard.fitsByStages(.accessibility5))
        #expect(!ClosingCard.fitsByStages(.xxxLarge))
        #expect(!ClosingCard.fitsByStages(.large))
    }

    /// Item 9 (tester 11 frame 20): a cut-off card under the fade reads as "more below": a taller, steeper fade.
    @Test func theResultsFadeSaysMoreBelow() {
        #expect(FadingScroll<EmptyView>.fadeHeight >= 48)
        let stops = FadingScroll<EmptyView>.fadeStops(fade: 0.3)
        #expect(stops.first?.opacity == 1)
        #expect(stops.last?.opacity == 0)
        #expect(stops.last?.location == 1)
        #expect(stops.contains { $0.opacity > 0 && $0.opacity < 0.5 })
        // Content that fits is never faded.
        let none = FadingScroll<EmptyView>.fadeStops(fade: 0)
        #expect(none.allSatisfy { $0.opacity == 1 })
        #expect(FadingScroll<EmptyView>.fadeMaxFraction <= 0.4)
    }
}

// MARK: - R12: the lid IS the chest (design/ROUND-12.md, founder's real-Duo test of build 6)

/// Drives a controller's hinge like a hand: a report every other frame, a 60 Hz frame clock (simulated time).
@MainActor
private final class DuoHand {
    let c: GameController
    var t: Double = CACurrentMediaTime()
    private(set) var angle: Double
    private(set) var last = HeistSnapshot()
    private(set) var events: [HeistEvent] = []

    init(_ c: GameController, at angle: Double) {
        self.c = c
        self.angle = angle
    }

    /// One report now (Home, before a run starts).
    func report() { c.hingeSample(angle: angle, time: t) }

    /// Moves the lid linearly to `to` over `seconds` (a hold when `to` is the current angle). `watch` sees every frame.
    @discardableResult
    func move(to target: Double, seconds: Double,
              watch: (GameController, HeistSnapshot, [HeistEvent], Double) -> Void = { _, _, _, _ in }) -> [HeistEvent] {
        let start = angle
        let frames = max(Int((seconds * 60).rounded()), 1)
        var out: [HeistEvent] = []
        for i in 1...frames {
            t += 1.0 / 60.0
            if i % 2 == 0 || i == frames {
                angle = start + (target - start) * Double(i) / Double(frames)
                c.hingeSample(angle: angle, time: t)
            }
            let (s, e) = c.advance(dt: 1.0 / 60.0, now: t)
            last = s
            out += e
            events += e
            watch(c, s, e, angle)
        }
        return out
    }

    @discardableResult
    func hold(_ seconds: Double,
              watch: (GameController, HeistSnapshot, [HeistEvent], Double) -> Void = { _, _, _, _ in }) -> [HeistEvent] {
        move(to: angle, seconds: seconds, watch: watch)
    }
}

private func has(_ events: [HeistEvent], _ match: (HeistEvent) -> Bool) -> Bool { events.contains(where: match) }
private func isArrival(_ e: HeistEvent) -> Bool {
    if case .chestArrived = e { return true }
    return false
}
private func isCrack(_ e: HeistEvent) -> Bool { e == .lidCracked }
private func isBank(_ e: HeistEvent) -> Bool {
    if case .banked = e { return true }
    return false
}

@MainActor
struct R12Tests {
    private func makeDuo(at angle: Double = 150) -> (GameController, DuoHand) {
        var data = ProgressData()
        data.lessonDone = true
        data.runs = 10
        let c = GameController(store: ProgressStore(inMemory: data), settings: SettingsStore(defaults: nil))
        c.settings.lidSensitivity = .forgiving
        c.updateCanvas(CGSize(width: 669, height: 951), hasFold: true, quarterTurns: 2)
        let hand = DuoHand(c, at: angle)
        hand.report()   // at Home: the hinge is known before Play
        return (c, hand)
    }

    private func done(_ c: GameController) {
        c.goHome()
        OrientationLock.setMenuHold(false)
    }

    /// The words on the plate right now (the hint, else the banner), as the player reads them.
    private func plateText(_ c: GameController) -> String? {
        if let h = c.hud.hint { return HushCopy.hint(h, slider: c.sliderWording, lidOpen: c.hud.lidOpen) }
        return c.hud.banner
    }

    // MARK: Copy

    @Test func theRobbedChestAndTheBankSayClose() {
        #expect(HushCopy.hint(.closeForNext, slider: false) == "Close the lid for the next chest")
        #expect(HushCopy.hint(.closeForNext, slider: true) == HushCopy.closeForNextLever)
        #expect(HushCopy.closeForNextLever.hasPrefix("Slide"))
        #expect(HushCopy.allHints.contains(.closeForNext))
        for slider in [true, false] {
            let line = HushCopy.hint(.closeForNext, slider: slider)
            #expect(HushCopy.wordCount(line) <= HushCopy.wordLimit(.closeForNext))
            #expect(!AppRules.asksToOpen(line))
            #expect(!line.lowercased().contains("shut"))
        }
        // It never retires and is no warning (it doesn't break through the bank beat).
        #expect(AppRules.showsHint(.closeForNext, runs: 500))
        #expect(!AppRules.isWarning(.closeForNext))
        #expect(!AppRules.isTeaching(.closeForNext))
        // Bank = close the lid (Duo); the lever keeps its words.
        #expect(HushCopy.hint(.shutToBank, slider: false) == "Close the lid to bank")
        #expect(HushCopy.hint(.shutToBank, slider: true) == "Slide the lever down to bank")
        #expect(HushCopy.stakes(slider: false)[2].text == "Close the lid to bank it")
        #expect(HushCopy.stakes(slider: true)[2].text == "Slide the lever down to bank")
        #expect(HushCopy.wordLimit(.shutToBank) == 6)
    }

    @Test func theRunStartBannerFollowsTheLid() {
        #expect(GameController.startBanner(.run) == "Candle lit. Open it gently.")
        #expect(GameController.startBanner(.run, lidOpen: false) == "Candle lit. Open it gently.")
        #expect(GameController.startBanner(.run, lidOpen: true) == "Candle lit. Gently does it.")
        #expect(HushCopy.wordCount(GameController.startBanner(.run, lidOpen: true) ?? "") <= 6)
        #expect(GameController.startBanner(.attract, lidOpen: true) == nil)
        #expect(GameController.startBanner(.lesson, lidOpen: true) == nil)
    }

    @Test func homeSaysLiftOnlyWhileClosed() {
        #expect(HomeView.caption(HomeLid(openness: 0, speed: 0), hinge: true) == "Lift the lid… slowly.")
        #expect(HomeView.caption(HomeLid(openness: 0.15, speed: 0), hinge: true) == "Lift the lid… slowly.")
        #expect(HomeView.caption(HomeLid(openness: 0.16, speed: 0), hinge: true) == "Shh… something's peeking.")
        #expect(HomeView.caption(HomeLid(openness: 0.25, speed: 0), hinge: false) == "Shh… something's peeking.")
        #expect(HomeView.caption(HomeLid(openness: 0.1, speed: 0), hinge: false) == HomeView.phoneCaption)
        #expect(HomeView.caption(HomeLid(openness: 0.9, speed: 0), hinge: true) == "It's watching you.")
    }

    /// Rule 7: close it, then open it slowly, in chest words; never "open" to an open lid.
    @Test func theLessonClosesThenOpens() {
        let pose = LessonScript()
        #expect(pose.line(slider: false, angle: 150, hint: nil) == "Close the lid to start")
        #expect(pose.line(slider: false, angle: 100, hint: nil) == "Hold it there…")
        #expect(LessonScript.LiftCue.lower.label == "Close the lid a little")
        let open = LessonScript(start: .open)
        #expect(open.line(slider: false, angle: 100, hint: nil, openness: 0) == "Now open it… slowly. Watch the noise.")
        #expect(open.line(slider: false, angle: 125, hint: nil, openness: 0.4) == "Keep going… slowly. Watch the noise.")
        #expect(open.display(slider: false, angle: 125, hint: nil, openness: 0.4).line.hasPrefix("Keep going"))
        #expect(open.line(slider: false, angle: 125, hint: .easeLidDown, openness: 0.4) == "Close the lid a little first.")
        #expect(open.line(slider: true, angle: nil, hint: nil, openness: 0.4).hasSuffix("Watch the noise."))
        #expect(LessonScript(start: .bank).line(slider: false, angle: nil, hint: nil) == "Close the lid to bank it.")
    }

    /// The sweep: no hint, banner, lesson line, lid marker or Home caption that says "open" can show while the lid's
    /// openness is past 0.15.
    @Test func nothingAsksToOpenAnOpenLid() {
        #expect(!AppRules.lidReadsOpen(0.15))
        #expect(AppRules.lidReadsOpen(0.151))
        #expect(!AppRules.lidReadsOpen(.nan))
        #expect(AppRules.asksToOpen("Open the lid… slowly"))
        #expect(AppRules.asksToOpen("Now open it… slowly."))
        let opens = stride(from: 0.16, through: 1.0, by: 0.02).map { $0 }
        let modes: [RunMode] = [.run, .daily(day: 300, scored: true), .daily(day: 300, scored: false), .attract, .lesson]
        let lessonHints: [HeistHint?] = [nil, .easeLidDown, .openSlowly, .dragToBag, .shutToBank]
        var angles: [Double?] = [nil]
        angles += stride(from: 113.0, through: 180.0, by: 1.0).map { Optional($0) }
        var bad: [String] = []
        for o in opens {
            let open = AppRules.lidReadsOpen(o)
            #expect(open)
            for slider in [true, false] {
                for h in HushCopy.allHints {
                    let line = HushCopy.hint(h, slider: slider, lidOpen: open)
                    if AppRules.asksToOpen(line) { bad.append("hint \(h.rawValue): \(line)") }
                }
                for step in LessonScript.Step.allCases {
                    let s = LessonScript(start: step)
                    for angle in angles {
                        for h in lessonHints {
                            let line = s.display(slider: slider, angle: angle, hint: h, openness: o).line
                            if AppRules.asksToOpen(line) { bad.append("lesson \(step): \(line)") }
                        }
                    }
                }
                let home = HomeView.caption(HomeLid(openness: o, speed: 0), hinge: !slider)
                if AppRules.asksToOpen(home) || home.hasPrefix("Lift the lid") { bad.append("home: \(home)") }
            }
            for m in modes {
                let banner = GameController.startBanner(m, lidOpen: open) ?? ""
                if AppRules.asksToOpen(banner) { bad.append("banner: \(banner)") }
            }
        }
        for angle in angles {
            let label = LessonScript.liftCue(angle: angle).label
            if AppRules.asksToOpen(label) { bad.append("marker: \(label)") }
        }
        #expect(bad.isEmpty, "\(Array(Set(bad)).sorted())")
        // Closed, the run still asks to open (the lid IS shut).
        #expect(HushCopy.hint(.openSlowly, slider: false, lidOpen: false) == "Open the lid… slowly")
        #expect(HushCopy.hint(.openSlowly, slider: false, lidOpen: true) == "A little wider… slowly")
    }

    /// The robbed chest's line is longer than the old 6-word rule: it must still fit its plate at the 0.7 shrink (the
    /// Duo's words on the Duo, the lever's on 393 and 402 pt phones).
    @Test func theRobbedChestLineFitsItsPlate() {
        let screens: [(CGSize, Bool)] = [(CGSize(width: 669, height: 951), true), (CGSize(width: 402, height: 874), false),
                                         (CGSize(width: 393, height: 852), false)]
        for (size, fold) in screens {
            let info = AppCanvas(size: size, insets: EdgeInsets(), hasFold: fold, turned: false)
            let fit = info.fit
            let band = fit.viewRect(canvas: HUDLayout.hintPlateRect(seat: info.pauseSeatCanvasRect()))
            let margins = PlateFit.margins(CGSize(width: band.width, height: 44), style: .parchment).width
            for line in [HushCopy.hint(.closeForNext, slider: !fold), HushCopy.hint(.openSlowly, slider: !fold, lidOpen: true)] {
                let text = Text(line).font(HushType.hint(scale: fit.textScale)).fixedSize()
                let natural = UIHostingController(rootView: text).sizeThatFits(in: CGSize(width: 10_000, height: 1_000)).width
                let room = band.width - margins
                #expect(natural * HintLine.minScale <= room, "\(line) at \(size): \(natural) × 0.7 > \(room)")
            }
        }
    }

    // MARK: Rules and demo keys

    @Test func theR12RulesAndTraceLines() {
        #expect(AppRules.hintTraceLine(.closeForNext) == "HUSH-T hint closeForNext")
        #expect(AppRules.hintTraceLine(.tooWide) == "HUSH-T hint tooWide")
        #expect(AppRules.hintTraceLine(nil) == "HUSH-T hint none")
        // `.closeForNext` belongs to the robbed chest alone (never after a bank).
        #expect(AppRules.allowsCloseForNext(.closeForNext, awaitingClose: true))
        #expect(!AppRules.allowsCloseForNext(.closeForNext, awaitingClose: false))
        #expect(AppRules.allowsCloseForNext(.openSlowly, awaitingClose: false))
        #expect(AppRules.allowsCloseForNext(nil, awaitingClose: false))
        // Feedback never plays the sleeping mimic's bed over the robbed chest.
        #expect(!AppRules.feedbackRobbed(.looting, awaitingClose: false))
        #expect(!AppRules.feedbackRobbed(.ready, awaitingClose: false))
        #expect(AppRules.feedbackRobbed(.ready, awaitingClose: true))
        #expect(!AppRules.feedbackRobbed(.bitten(elapsed: 0.2), awaitingClose: true))
    }

    @Test func theR12DemoKeysParse() {
        let bite = DemoMode.parse("screen=run;mode=run;seed=7;noise=1;noiseUntil=bite")
        #expect(bite.noiseUntilBite && !bite.noiseUntilPause)
        let pause = DemoMode.parse("noise=0.9;noiseUntil=pause")
        #expect(pause.noiseUntilPause && !pause.noiseUntilBite)
        let bag = DemoMode.parse("screen=run;mode=attract;seed=7;bag=1")
        #expect(bag.bagItems == 1)
        #expect(DemoMode.parse("bag=0").bagItems == nil)
        #expect(DemoMode.parse("bag=99").bagItems == 12)
        #expect(DemoMode.parse("screen=run").bagItems == nil)
        let open = DemoMode.parse("screen=run;lid=0.8;startOpen=1")
        #expect(open.opensAtStart && open.lid == 0.8)
        #expect(!DemoMode.parse("screen=run;lid=0.8").opensAtStart)

        // `startOpen=1`: the held lid is up from the very first frame; without it, the 0.25 s shut beat.
        let up = FixedLidSource()
        up.openness = 0.8
        up.startsOpen = true
        let first = up.lid(at: 10)
        #expect(first.openness == 0.8)
        #expect(!first.inShutZone)
        let beat = FixedLidSource()
        beat.openness = 0.8
        let shut = beat.lid(at: 10)
        let later = beat.lid(at: 10.3)
        #expect(shut.openness == 0)
        #expect(later.openness == 0.8)
    }

    @Test func theDemoBagPicksLitItemsOfTheFirstChest() {
        func item(_ id: Int, lit: Bool) -> LootState {
            let p = CGPoint(x: 150 + 60 * id, y: 150)
            return LootState(item: LootItem(id: id, kind: .copper, value: 5, depth: 0.1, position: p, radius: 22,
                                            rotation: 0),
                             position: p, place: .inChest, light: lit ? 1 : 0, grabbable: lit)
        }
        let first = ChestSpec(index: 0, tier: .wooden, mimic: .snorer, mimicName: "Sam", multiplier: 1, decay: 0.1,
                              items: [])
        var s = HeistSnapshot(phase: .looting, chest: first,
                              loot: [item(1, lit: true), item(2, lit: false), item(3, lit: true), item(4, lit: true)])
        let plan = DemoBagPlan(2)
        #expect(plan.picks(s) == [0, 2])
        #expect(DemoBagPlan(5).picks(s) == [0, 2, 3])
        #expect(DemoBagPlan(0).done)
        s.phase = .ready
        #expect(plan.picks(s).isEmpty)
        s.phase = .looting
        var second = first
        second.index = 1
        s.chest = second
        #expect(plan.picks(s).isEmpty)
        var p = DemoBagPlan(2)
        p.noteBagged(1)
        s.chest = first
        p.finishIfNeeded(s)
        #expect(!p.done)
        p.noteBagged(1)
        p.finishIfNeeded(s)
        #expect(p.done)
        #expect(DemoBagPlan.bagPoint.y >= FloorSpace.bagMinY)
    }

    // MARK: Every run-start path with the lid open goes straight into an open first chest (rule 2)

    @Test func everyRunStartWithTheLidOpenOpensTheFirstChest() {
        let paths: [(String, @MainActor (GameController, DuoHand) -> Void)] = [
            ("play", { c, _ in c.play() }),
            ("daily", { c, _ in c.playDaily() }),
            ("again", { c, _ in c.again() }),
            ("restart", { c, hand in
                c.play()
                hand.hold(0.3)
                c.restart()
            }),
            ("restart from the menu", { c, hand in
                c.play()
                hand.hold(0.3)
                c.openMenu()
                c.restart()
            }),
        ]
        for (name, begin) in paths {
            let (c, hand) = makeDuo(at: 150)
            begin(c, hand)
            #expect(c.route == .playing, "\(name)")
            var asked: [String] = []
            var lowered = false
            let events = hand.hold(0.5) { c, s, _, _ in
                if s.hint == .easeLidDown { lowered = true }
                if c.hud.lidOpen, let text = self.plateText(c), AppRules.asksToOpen(text) { asked.append(text) }
            }
            #expect(!c.isPaused, "\(name)")
            #expect(hand.last.phase == .looting, "\(name): \(hand.last.phase)")
            #expect(has(events, isCrack), "\(name)")
            #expect(!lowered, "\(name)")
            #expect(asked.isEmpty, "\(name): \(asked)")
            #expect(c.hud.lidOpen, "\(name)")
            if c.mode == .run {
                #expect(c.hud.banner == nil || c.hud.banner == "Candle lit. Gently does it.", "\(name)")
            }
            done(c)
        }
    }

    /// With the lid closed, the first chest arrives closed and opens with the lid ("Open the lid… slowly" is right).
    @Test func aClosedLidStartsAClosedChest() {
        let (c, hand) = makeDuo(at: 100)
        c.play()
        hand.hold(0.4)
        #expect(hand.last.phase == .ready)
        #expect(!c.hud.lidOpen)
        #expect(c.hud.banner == nil || c.hud.banner == "Candle lit. Open it gently.")
        let events = hand.move(to: 125, seconds: 2.5)
        #expect(has(events, isCrack))
        #expect(hand.last.phase == .looting)
        done(c)
    }

    // MARK: Rule 4 after a bite; the R7 fresh-chest resume (no "Hold still…")

    @Test func aBiteWaitsForTheCloseThenTheReopenIsFresh() throws {
        let (c, hand) = makeDuo(at: 150)
        c.play()
        hand.hold(0.4)
        #expect(hand.last.phase == .looting)
        c.nudgeSessionNoise(to: 1)
        let bit = hand.hold(0.1)
        let didBite = bit.contains(where: GameController.isBite)
        #expect(didBite)
        // Held open: the robbed chest waits, open and empty; no new chest while the lid is up.
        let waiting = hand.hold(3.0)
        #expect(!has(waiting, isArrival))
        #expect(c.awaitingClose)
        #expect(hand.last.hint == .closeForNext)
        let shown = try #require(c.hud.hint)
        #expect(shown == .closeForNext)
        #expect(plateText(c) == "Close the lid for the next chest")
        // Close to the shut zone: the next chest is dealt, and the robbed chest's line goes with it.
        var staleLine = false
        let closing = hand.move(to: 100, seconds: 1.4) { c, _, _, _ in
            if !c.awaitingClose && c.hud.hint == .closeForNext { staleLine = true }
        }
        #expect(has(closing, isArrival))
        #expect(!c.awaitingClose)
        #expect(!staleLine)
        // On down to the closing pause: a fresh chest.
        hand.move(to: 30, seconds: 1.8)
        hand.hold(0.8)
        #expect(c.isClosingPaused)
        #expect(c.closingFresh)
        // Reopen at 40°/s: it resumes on the lift, never "Hold still…", and the new chest opens.
        var holdStill = false
        var resumedAt: Double?
        let reopen = hand.move(to: 140, seconds: 2.75) { c, _, _, a in
            if c.isClosingPaused,
               ClosingCard.title(lifted: c.closingLifted, awaitingHinge: c.closingAwaitsHinge,
                                 fresh: c.closingFresh) == "Hold still…" { holdStill = true }
            if resumedAt == nil && !c.isClosingPaused { resumedAt = a }
        }
        let opened = hand.hold(0.5)
        #expect(!holdStill)
        #expect((resumedAt ?? 999) < 139)
        #expect(hand.last.phase == .looting)
        #expect(has(reopen + opened, isCrack))
        #expect(!has(reopen + opened, isArrival))
        done(c)
    }

    /// Bank = close the lid, all the way: the bank fires on the way down, the next chest is dealt under the closed
    /// lid, and the reopen resumes on the lift into it (no "Hold still…", never "Close the lid for the next chest").
    @Test func aFullCloseAfterABankReopensIntoTheNextChest() throws {
        let (c, hand) = makeDuo(at: 150)
        c.play()
        hand.hold(0.4)
        let item = try #require(hand.last.loot.first { $0.place == .inChest && $0.grabbable })
        c.floorTouchBegan(1, at: item.position, time: hand.t)
        c.floorTouchMoved(1, to: CGPoint(x: 335, y: 400), time: hand.t + 1.5)
        c.floorTouchEnded(1, at: CGPoint(x: 335, y: 400), time: hand.t + 1.5)
        hand.hold(0.2)
        #expect(hand.last.bagValue > 0)
        var closeLine = false
        var arrivalAngles: [Double] = []
        let watch: (GameController, HeistSnapshot, [HeistEvent], Double) -> Void = { c, _, e, a in
            if c.hud.hint == .closeForNext { closeLine = true }
            if has(e, isArrival) { arrivalAngles.append(a) }
        }
        // 20°/s, under the closing creak's quiet line, through the shut zone and on down to the cover.
        let down = hand.move(to: 100, seconds: 2.5, watch: watch) + hand.move(to: 30, seconds: 3.5, watch: watch)
        hand.hold(0.8, watch: watch)
        #expect(has(down, isBank))
        #expect(c.isClosingPaused)
        #expect(c.closingFresh)
        var holdStill = false
        var resumedAt: Double?
        hand.move(to: 140, seconds: 2.75) { c, s, e, a in
            watch(c, s, e, a)
            if c.isClosingPaused,
               ClosingCard.title(lifted: c.closingLifted, awaitingHinge: c.closingAwaitsHinge,
                                 fresh: c.closingFresh) == "Hold still…" { holdStill = true }
            if resumedAt == nil && !c.isClosingPaused { resumedAt = a }
        }
        hand.hold(0.5, watch: watch)
        #expect(!holdStill)
        #expect((resumedAt ?? 999) < 139)
        #expect(hand.last.phase == .looting)
        #expect(!closeLine)
        // The next chest came while the lid was closed (CI's BANK-CLOSE-FULL: never above 113°).
        #expect(arrivalAngles.count == 1)
        #expect(arrivalAngles.allSatisfy { $0 <= 113 }, "\(arrivalAngles)")
        done(c)
    }
}

import CoreGraphics
import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Hush

// App engineer tests: progress/settings round-trip and migration, the Daily one-scored-try rule, recording a run (with
// injected ranks and achievements, so they don't lean on Core's catalogues), demo parsing, the turned-round and pose
// rules, the First Chest's step gating, the hint gate and copy, log formats, Game Center queue rules, and the HUD
// geometry.

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
    }

    @Test func v0WithoutRunsStillTeaches() throws {
        let back = try #require(ProgressStore.decode(Data(#"{"bestRun": 0}"#.utf8)))
        #expect(!back.lessonDone)
    }

    @Test func toleratesBadFields() throws {
        let json = #"{"version": 1, "bestRun": "lots", "runs": 4, "lifetimeGold": -50, "lessonDone": true}"#
        let back = try #require(ProgressStore.decode(Data(json.utf8)))
        #expect(back.bestRun == 0)
        #expect(back.runs == 4)
        #expect(back.lifetimeGold == 0)
        #expect(back.lessonDone)
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
        #expect(DailyClock.calendar.timeZone.identifier == "UTC")
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

    @Test func leftEarlyFilesGoldSoFar() {
        var d = ProgressData()
        ProgressRules.noteDailyStart(&d, day: 300)
        ProgressRules.recordPartialDaily(&d, day: 300, gold: 420)
        #expect(d.daily[300]?.gold == 420)
        ProgressRules.recordPartialDaily(&d, day: 300, gold: 100)
        #expect(d.daily[300]?.gold == 420)
        #expect(!ProgressRules.canPlayScoredDaily(d, today: 300))
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
                               + "orient=portrait")
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
        #expect(d.runMode(today: 300) == .daily(day: 300, scored: true))
    }

    @Test func defaultsAndCase() {
        let d = DemoMode.parse("freezeOn=TORCHOUT;bogus=1;;turn")
        #expect(d.freezeOn == .torchOut)
        #expect(d.turn == true)
        #expect(d.effectiveScreen == .home)
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
    }
}
#endif

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

    @Test func orientationMasks() {
        #expect(OrientationLock.mask(isDuo: true) == .allButUpsideDown)
        #expect(OrientationLock.mask(isDuo: false) == .portrait)
        #expect(OrientationLock.looksLikeDuo(CGSize(width: 669, height: 951)))
        #expect(!OrientationLock.looksLikeDuo(CGSize(width: 402, height: 874)))
        #expect(!OrientationLock.trustsStoredHinge(true, screen: CGSize(width: 402, height: 874)))
    }
}

// MARK: - The First Chest

@MainActor
struct LessonTests {
    /// Steps the script through its praise beat.
    private func settle(_ s: inout LessonScript, from t: Double) -> Double {
        let end = t + LessonScript.praiseSeconds + 0.05
        _ = s.update(LessonScript.Input(time: end, angle: 110))
        return end
    }

    @Test func poseNeedsHalfASecondInRange() {
        var s = LessonScript()
        _ = s.update(LessonScript.Input(time: 0, angle: 110))
        _ = s.update(LessonScript.Input(time: 0.3, angle: 112))
        #expect(!s.isPraising)
        _ = s.update(LessonScript.Input(time: 0.35, angle: 140))   // out of range: the clock restarts
        _ = s.update(LessonScript.Input(time: 0.6, angle: 110))
        _ = s.update(LessonScript.Input(time: 1.0, angle: 110))
        #expect(!s.isPraising)
        _ = s.update(LessonScript.Input(time: 1.15, angle: 111))
        #expect(s.isPraising)
        _ = settle(&s, from: 1.15)
        #expect(s.step == .open)
    }

    @Test func sliderPoseAndWords() {
        var s = LessonScript()
        #expect(s.line(slider: true, angle: nil, hint: nil) == "Slide the lid up… slowly.")
        _ = s.update(LessonScript.Input(time: 0, hasHinge: false, openness: 0.01))
        #expect(!s.isPraising)
        _ = s.update(LessonScript.Input(time: 0.1, hasHinge: false, openness: 0.06))
        #expect(s.isPraising)
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

    @Test func bankingEarlyFinishesTheLesson() {
        var s = LessonScript(start: .grab)
        _ = s.update(LessonScript.Input(time: 0, events: [.banked(value: 8, items: 1, hushed: true)]))
        _ = settle(&s, from: 0)
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
}

// MARK: - Hints, copy, story

@MainActor
struct CopyTests {
    @Test func hintsAreShort() {
        let all: [HeistHint] = [.easeLidDown, .openSlowly, .slower, .freeze, .dragToBag, .shutToBank, .tooWide]
        for hint in all {
            #expect(HushCopy.wordCount(HushCopy.hint(hint, slider: false)) <= 6)
            #expect(HushCopy.wordCount(HushCopy.hint(hint, slider: true)) <= 6)
        }
        for mode in [RunMode.run, .daily(day: 1, scored: true), .daily(day: 1, scored: false)] {
            let banner = GameController.startBanner(mode) ?? ""
            #expect(HushCopy.wordCount(banner) <= 6)
        }
    }

    @Test func teachingHintsRetire() {
        #expect(AppRules.showsHint(.dragToBag, runs: 0))
        #expect(!AppRules.showsHint(.dragToBag, runs: AppRules.teachingRuns))
        #expect(AppRules.showsHint(.freeze, runs: 500))
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
    }

    @Test func homeCaptionTeaches() {
        #expect(HomeView.caption(HomeLid(openness: 0, speed: 0), hinge: true) == "Lift the lid… slowly.")
        #expect(HomeView.caption(HomeLid(openness: 0.5, speed: 0), hinge: true).contains("peeking"))
        #expect(HomeView.caption(HomeLid(openness: 0.5, speed: 80), hinge: true).contains("mimic"))
    }

    @Test func badgesHaveAMotifAndTier() {
        #expect(BadgePainter.tier(index: 0) == .verdigris)
        #expect(BadgePainter.tier(index: 5) == .silver)
        #expect(BadgePainter.tier(index: 11) == .gold)
        #expect(BadgePainter.motif(id: "hush.ach.firstrelic", title: "Relic Hunter") == .relic)
        #expect(BadgePainter.motif(id: "hush.ach.notapeep", title: "Not a Peep without stirring") == .hush)
        #expect(BadgePainter.motif(id: "hush.ach.heavybag", title: "Heavy Bag: bank 2,000 gold") == .gold)
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
}

// MARK: - Geometry

@MainActor
struct LayoutTests {
    @Test func canvasFitMapsTheCanvas() {
        let fit = CanvasFit(viewSize: CGSize(width: 670, height: 952))
        #expect(fit.rect == CGRect(x: 0, y: 0, width: 670, height: 952))
        // Canvas (y up) → view (y down): the floor half is the lower part of the view.
        let floor = fit.floorRect
        #expect(abs(floor.minY - 496) < 0.001)
        #expect(abs(floor.maxY - 952) < 0.001)
        let phone = CanvasFit(viewSize: CGSize(width: 402, height: 874))
        #expect(abs(phone.rect.width - 402) < 0.001)
        #expect(phone.rect.minY > 0)
    }

    @Test func hudSitsOnTheFloorHalf() {
        let floor = HUDLayout.floor
        #expect(floor.contains(HUDLayout.hintBand))
        #expect(floor.contains(HUDLayout.pauseRect))
        #expect(floor.contains(HUDLayout.lessonBand))
        #expect(HUDLayout.hintBand.minY >= HUDLayout.meterTop)
        #expect(!HUDLayout.hintBand.intersects(HUDLayout.pauseRect))
        #expect(HUDLayout.pauseRect.width >= HushTheme.minTap && HUDLayout.pauseRect.height >= HushTheme.minTap)
    }

    @Test func homeHalvesClearTheFold() {
        let info = AppCanvas(size: CGSize(width: 669, height: 951), insets: EdgeInsets(), hasFold: true, turned: true)
        #expect(info.isFoldClear(info.floorHalf))
        #expect(info.isFoldClear(info.lidHalf))
        #expect(info.floorHalf.minY > info.size.height / 2)
        #expect(info.floorHalf.height > 400)
    }
}

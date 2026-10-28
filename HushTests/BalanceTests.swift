import CoreGraphics
import Foundation
import Testing
@testable import Hush

// MARK: - Headless balance playtest (Round 2)
//
// Every PilotSkill plays real HeistSessions (mode .run, HUSH_BAL_SEEDS seeds, default 8) at 60 Hz with its touches fed
// in between steps, the way GameController feeds a pilot. Each run is capped at 10 min. Prints, per skill:
//   HUSH-BAL skill=casual gold=3803 p10=… p90=… seconds=131.3 banked=8.0 bites=0.0 maxBites=0 hushed=2.0 … n=8
// The assertions are the ROUND-2 table on MEDIANS, inside bands (tools/balance-sim.js mirrors them as BANDS and
// checks them with `windows=40` over 40 different 8-seed windows). The sim predicts, on these seeds:
//   8 seeds:  novice 1,244 gold / 4 chests / 4 bites; casual 3,803 / 8 / 0 / 2 Hushed; expert 10,089 / 12;
//             perfect 10,989 / 12, never bitten.
//   40 seeds: novice 1,685 / 5.5 / 3; casual 3,958 / 8 / 0 / 2; expert 11,007 / 13; perfect 11,573 / 13.
// R2 targets: novice ≥ 1,000 gold and ≥ 3 chests; casual banks 5–10 chests in 90–160 s, unbitten, ≥ 1 Hushed;
// novice < casual < expert, perfect ≥ 0.95 × expert; perfect never bitten; every chest log adds up to the gold.
// R7 ("real hands", design/notes/core-R7.md): novice and casual now move like people (casual closes at 20–40°/s,
// opens at 10–25°/s, stick-slip at every stroke; novice faster). The sim predicts:
//   8 seeds:  novice 1,347 / 4.5 / 3.5 bites; casual 4,966 / 9 / 0 / 1 Hushed; expert 11,328 / 12; perfect 11,076 / 12.
//   40 seeds: novice 1,589 / 5.5 / 4; casual 5,353 / 10 / 0 / 1; expert 11,414 / 13; perfect 11,597 / 13.
// R7 targets: casual never bitten on median and banks ≥ 6; novice ≥ 1,000 gold and ≥ 3 chests; expert and perfect
// within ±10 % of R6. The casual band moved (gold 3,500–7,000, banked 6–12, Hushed ≥ 0.5): faster real hands bank
// more chests in the same candle but Hush fewer of them (the 40 windows of 8 seeds span gold 4,276–6,560, banked
// 8.5–10.5, Hushed 0.5–2.5).
// Each skill is simulated once (memoised per skill), so the tests share the runs.

struct HushBalanceRun {
    var gold: Int
    var seconds: Double
    var chestsBanked: Int
    var bites: Int
    var hushed: Int
    var relics: Int
    var bestChain: Int
    var goldenBanked: Int
    /// chestLog has one entry per chest opened and its values add up to the gold.
    var logAddsUp: Bool
    var capped: Bool
}

final class HushBalanceMemo: @unchecked Sendable {
    static let shared = HushBalanceMemo()

    private let locks: [PilotSkill: NSLock]
    private let dataLock = NSLock()
    private var results: [PilotSkill: [HushBalanceRun]] = [:]

    init() {
        var l: [PilotSkill: NSLock] = [:]
        for s in PilotSkill.allCases { l[s] = NSLock() }
        locks = l
    }

    func runs(_ skill: PilotSkill) -> [HushBalanceRun] {
        let lock: NSLock = locks[skill] ?? NSLock()
        lock.lock()
        defer { lock.unlock() }
        dataLock.lock()
        let cached: [HushBalanceRun]? = results[skill]
        dataLock.unlock()
        if let c = cached { return c }
        let computed: [HushBalanceRun] = HushBalanceHarness.simulate(skill)
        dataLock.lock()
        results[skill] = computed
        dataLock.unlock()
        return computed
    }
}

/// Median bands per skill (the R2 table with room for seed noise and Swift/JS libm drift).
struct HushBalanceBands {
    var gold: ClosedRange<Double>
    var banked: ClosedRange<Double>
    var bites: ClosedRange<Double>?
    var hushed: ClosedRange<Double>?
    var seconds: ClosedRange<Double>?

    static func bands(_ skill: PilotSkill) -> HushBalanceBands {
        switch skill {
        case .novice:
            return HushBalanceBands(gold: 1_000...2_600, banked: 3...8, bites: 1...6, hushed: nil, seconds: nil)
        case .casual:
            // R7: real hands (see the header).
            return HushBalanceBands(gold: 3_500...7_000, banked: 6...12, bites: 0...0.5, hushed: 0.5...5,
                                    seconds: 90...160)
        case .expert:
            return HushBalanceBands(gold: 8_000...14_000, banked: 10...16, bites: 0...1, hushed: 8...16, seconds: nil)
        case .perfect:
            return HushBalanceBands(gold: 8_500...15_000, banked: 10...16, bites: nil, hushed: 9...16, seconds: nil)
        }
    }
}

enum HushBalanceHarness {
    static let frameDt: Double = 1.0 / 60.0
    static let capSeconds: Double = 600

    static var seedCount: Int {
        if let raw = ProcessInfo.processInfo.environment["HUSH_BAL_SEEDS"], let n = Int(raw), n > 0 { return n }
        return 8
    }

    /// The same seeds as tools/balance-sim.js.
    static func seed(_ i: Int) -> UInt64 {
        return UInt64(1000 + i * 7919)
    }

    static func runOne(_ skill: PilotSkill, seed: UInt64) -> HushBalanceRun {
        let session = HeistSession(mode: .run, seed: seed, bestRun: 0, foundRelics: [],
                                   options: SessionOptions.for(.run))
        var pilot = ThiefPilot(skill: skill, seed: seed &* 7 &+ 1)
        var t: Double = 0
        var frames: Int = 0
        let maxFrames: Int = Int(capSeconds / frameDt)
        while !session.isFinished && frames < maxFrames {
            let out: PilotOutput = pilot.step(dt: frameDt, snapshot: session.snapshot)
            for touch in out.touches {
                switch touch.phase {
                case .began: _ = session.touchBegan(id: touch.id, at: touch.point, time: t)
                case .moved: _ = session.touchMoved(id: touch.id, to: touch.point, time: t)
                case .ended: _ = session.touchEnded(id: touch.id, at: touch.point, time: t)
                }
            }
            _ = session.step(dt: frameDt, lid: out.lid)
            t += frameDt
            frames += 1
        }
        let capped: Bool = session.result == nil
        let r: RunResult = session.partialResult()
        let logGold: Int = r.chestLog.reduce(0) { (a: Int, c: ChestOutcome) -> Int in a + c.value }
        let adds: Bool = r.chestLog.count == r.chestsOpened && logGold == r.gold
        return HushBalanceRun(gold: r.gold, seconds: r.seconds, chestsBanked: r.chestsBanked, bites: r.bites,
                              hushed: r.hushed, relics: r.relics.count, bestChain: r.bestChain,
                              goldenBanked: r.goldenBanked, logAddsUp: adds, capped: capped)
    }

    static func simulate(_ skill: PilotSkill) -> [HushBalanceRun] {
        var out: [HushBalanceRun] = []
        var i: Int = 0
        while i < seedCount {
            out.append(runOne(skill, seed: seed(i)))
            i += 1
        }
        return out
    }

    static func percentile(_ values: [Double], _ p: Double) -> Double {
        if values.isEmpty { return 0 }
        let sorted: [Double] = values.sorted()
        let pos: Double = Double(sorted.count - 1) * p
        let lo: Int = Int(pos.rounded(.down))
        let hi: Int = min(sorted.count - 1, lo + 1)
        let f: Double = pos - Double(lo)
        return sorted[lo] + (sorted[hi] - sorted[lo]) * f
    }

    static func median(_ runs: [HushBalanceRun], _ value: (HushBalanceRun) -> Double) -> Double {
        return percentile(runs.map(value), 0.5)
    }

    static func medianGold(_ skill: PilotSkill) -> Double {
        return median(HushBalanceMemo.shared.runs(skill)) { (r: HushBalanceRun) -> Double in Double(r.gold) }
    }

    static func report(_ skill: PilotSkill, _ runs: [HushBalanceRun]) -> String {
        let gold: [Double] = runs.map { (r: HushBalanceRun) -> Double in Double(r.gold) }
        let secs: [Double] = runs.map { (r: HushBalanceRun) -> Double in r.seconds }
        let banked: [Double] = runs.map { (r: HushBalanceRun) -> Double in Double(r.chestsBanked) }
        let bites: [Double] = runs.map { (r: HushBalanceRun) -> Double in Double(r.bites) }
        let hushed: [Double] = runs.map { (r: HushBalanceRun) -> Double in Double(r.hushed) }
        let relics: [Double] = runs.map { (r: HushBalanceRun) -> Double in Double(r.relics) }
        let chains: [Double] = runs.map { (r: HushBalanceRun) -> Double in Double(r.bestChain) }
        let golden: Int = runs.reduce(0) { (a: Int, r: HushBalanceRun) -> Int in a + r.goldenBanked }
        let maxBites: Int = runs.map { (r: HushBalanceRun) -> Int in r.bites }.max() ?? 0
        let capped: Int = runs.filter { (r: HushBalanceRun) -> Bool in r.capped }.count
        let head: String = String(format: "HUSH-BAL skill=%@ gold=%.0f p10=%.0f p90=%.0f seconds=%.1f p10=%.1f p90=%.1f",
                                  skill.rawValue, percentile(gold, 0.5), percentile(gold, 0.1),
                                  percentile(gold, 0.9), percentile(secs, 0.5), percentile(secs, 0.1),
                                  percentile(secs, 0.9))
        let tail: String = String(format: " banked=%.1f bites=%.1f maxBites=%d hushed=%.1f relics=%.1f bestChain=%.1f goldenBanked=%d capped=%d n=%d",
                                  percentile(banked, 0.5), percentile(bites, 0.5), maxBites,
                                  percentile(hushed, 0.5), percentile(relics, 0.5), percentile(chains, 0.5),
                                  golden, capped, runs.count)
        return head + tail
    }
}

struct BalanceTests {

    @Test(arguments: PilotSkill.allCases)
    func skillTargets(skill: PilotSkill) {
        let runs: [HushBalanceRun] = HushBalanceMemo.shared.runs(skill)
        let line: String = HushBalanceHarness.report(skill, runs)
        // Unbuffered, so the line survives even if a later test crashes the runner.
        FileHandle.standardOutput.write(Data((line + "\n").utf8))
        let capped: Int = runs.filter { (r: HushBalanceRun) -> Bool in r.capped }.count
        #expect(capped == 0, "\(line)")
        let badLogs: Int = runs.filter { (r: HushBalanceRun) -> Bool in !r.logAddsUp }.count
        #expect(badLogs == 0, "chest log doesn't add up in \(badLogs) runs: \(line)")
        let b: HushBalanceBands = HushBalanceBands.bands(skill)
        let gold: Double = HushBalanceHarness.median(runs) { (r: HushBalanceRun) -> Double in Double(r.gold) }
        let banked: Double = HushBalanceHarness.median(runs) { (r: HushBalanceRun) -> Double in Double(r.chestsBanked) }
        #expect(b.gold.contains(gold), "gold median \(gold) outside \(b.gold): \(line)")
        #expect(b.banked.contains(banked), "banked median \(banked) outside \(b.banked): \(line)")
        if let band = b.bites {
            let bites: Double = HushBalanceHarness.median(runs) { (r: HushBalanceRun) -> Double in Double(r.bites) }
            #expect(band.contains(bites), "bites median \(bites) outside \(band): \(line)")
        }
        if let band = b.hushed {
            let hushed: Double = HushBalanceHarness.median(runs) { (r: HushBalanceRun) -> Double in Double(r.hushed) }
            #expect(band.contains(hushed), "hushed median \(hushed) outside \(band): \(line)")
        }
        if let band = b.seconds {
            let seconds: Double = HushBalanceHarness.median(runs) { (r: HushBalanceRun) -> Double in r.seconds }
            #expect(band.contains(seconds), "seconds median \(seconds) outside \(band): \(line)")
        }
        if skill == .perfect {
            let maxBites: Int = runs.map { (r: HushBalanceRun) -> Int in r.bites }.max() ?? 0
            #expect(maxBites == 0, "\(line)")
        }
    }

    @Test func skillOrdersTheGold() {
        let novice: Double = HushBalanceHarness.medianGold(.novice)
        let casual: Double = HushBalanceHarness.medianGold(.casual)
        let expert: Double = HushBalanceHarness.medianGold(.expert)
        let perfect: Double = HushBalanceHarness.medianGold(.perfect)
        let line: String = "novice \(novice) casual \(casual) expert \(expert) perfect \(perfect)"
        #expect(novice < casual, "\(line)")
        #expect(casual < expert, "\(line)")
        // "expert ≤ perfect", with 5 % slack for seed noise (the sim has perfect 6–9 % ahead).
        #expect(perfect >= expert * 0.95, "\(line)")
    }

    /// R7 (ROUND-7 Core item 4): casual closes at 20–40 °/s and opens at 10–25 °/s, the novice is faster still, and both
    /// break away with a 0.5–2° stick-slip at the start of every stroke. Expert and perfect still play to the R2–R6
    /// lines (12 / 18 °/s), smooth.
    @Test func realHandsMoveLikePeople() {
        let casual: PilotProfile = PilotProfile.profile(.casual)
        let novice: PilotProfile = PilotProfile.profile(.novice)
        let expert: PilotProfile = PilotProfile.profile(.expert)
        let perfect: PilotProfile = PilotProfile.profile(.perfect)
        #expect(casual.close == 20...40)
        #expect(casual.open == 10...25)
        #expect(casual.slip == 0.5...2)
        #expect(novice.slip == 0.5...2)
        #expect(novice.open.upperBound > casual.open.upperBound)
        #expect(novice.close.lowerBound > casual.close.lowerBound && novice.close.upperBound > casual.close.upperBound)
        #expect(novice.slamChance == 0.3)
        #expect(expert.slip == 0...0 && perfect.slip == 0...0)
        #expect(abs(expert.open.lowerBound - 7.5) < 1e-9 && abs(expert.open.upperBound - 13.5) < 1e-9)
        #expect(abs(expert.close.lowerBound - 13.5) < 1e-9 && abs(expert.close.upperBound - 18) < 1e-9)
        #expect(abs(perfect.open.lowerBound - 9) < 1e-9 && abs(perfect.close.lowerBound - 17.1) < 1e-9)
        // A casual minute on the first balance seed: every stroke from still starts with a one-frame slip (0.5–2° in
        // 1/60 s = 30–120 °/s, less only when the stroke is shorter), and the strokes run at 10–40 °/s.
        let seed: UInt64 = HushBalanceHarness.seed(0)
        let session = HeistSession(mode: .run, seed: seed, bestRun: 0, foundRelics: [],
                                   options: SessionOptions.for(.run))
        var pilot = ThiefPilot(skill: .casual, seed: seed &* 7 &+ 1)
        let dt: Double = HushBalanceHarness.frameDt
        var t: Double = 0
        var frame: Int = 0
        var prev: Double = 0
        var slips: Int = 0
        var tooBig: Int = 0
        var steady: Double = 0
        while frame < 60 * 60 && !session.isFinished {
            let out: PilotOutput = pilot.step(dt: dt, snapshot: session.snapshot)
            for touch in out.touches {
                switch touch.phase {
                case .began: _ = session.touchBegan(id: touch.id, at: touch.point, time: t)
                case .moved: _ = session.touchMoved(id: touch.id, to: touch.point, time: t)
                case .ended: _ = session.touchEnded(id: touch.id, at: touch.point, time: t)
                }
            }
            _ = session.step(dt: dt, lid: out.lid)
            let v: Double = out.lid.speed
            if prev == 0 && v > 0 {
                if v >= 29.9 { slips += 1 }
                if v > 120.1 { tooBig += 1 }
            } else if prev > 0 && v > 0 {
                steady = max(steady, v)
            }
            prev = v
            t += dt
            frame += 1
        }
        #expect(slips >= 5, "slips \(slips)")
        #expect(tooBig == 0)
        #expect(steady <= 40 + 1e-6, "steady \(steady)")
    }

    @Test func mastersBuildHushChains() {
        // The chain is what makes mastery pay (REVIEW-1-feel: ~24 % of an expert's gold).
        let expert: [HushBalanceRun] = HushBalanceMemo.shared.runs(.expert)
        let chain: Double = HushBalanceHarness.median(expert) { (r: HushBalanceRun) -> Double in Double(r.bestChain) }
        #expect(chain >= 3, "expert best chain median \(chain)")
    }
}

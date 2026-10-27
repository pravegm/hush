import CoreGraphics
import Foundation
import Testing
@testable import Hush

// MARK: - Headless balance playtest
//
// Every PilotSkill plays real HeistSessions (mode .run, HUSH_BAL_SEEDS seeds, default 8) at 60 Hz with its touches fed
// in between steps, the way GameController feeds a pilot. Each run is capped at 10 min. Prints, per skill:
//   HUSH-BAL skill=casual gold=2585 p10=… p90=… seconds=131.9 banked=7.0 bites=0.0 maxBites=0 hushed=… relics=… n=8
// The assertions are the ROUND-1 targets on medians, with margins (tools/balance-sim.js predicts, 8 seeds:
// novice ~560 gold / 4 bites, casual ~2,590 / 7 chests / 132 s, expert ~4,880, perfect ~6,120 and never bitten):
//   novice gold < casual < expert, perfect ≥ 0.95 × expert; casual banks 4–8 chests and lasts 90–160 s;
//   novice is bitten ≥ 1 time per run; perfect is never bitten.
// Each skill is simulated once (memoised per skill), so the tests share the runs.

struct HushBalanceRun {
    var gold: Int
    var seconds: Double
    var chestsBanked: Int
    var bites: Int
    var hushed: Int
    var relics: Int
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
        if let r = session.result {
            return HushBalanceRun(gold: r.gold, seconds: r.seconds, chestsBanked: r.chestsBanked, bites: r.bites,
                                  hushed: r.hushed, relics: r.relics.count, capped: false)
        }
        let snap: HeistSnapshot = session.snapshot
        return HushBalanceRun(gold: snap.banked, seconds: snap.time, chestsBanked: snap.chestsBanked,
                              bites: snap.bites, hushed: snap.hushed, relics: 0, capped: true)
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
        let maxBites: Int = runs.map { (r: HushBalanceRun) -> Int in r.bites }.max() ?? 0
        let capped: Int = runs.filter { (r: HushBalanceRun) -> Bool in r.capped }.count
        return String(format: "HUSH-BAL skill=%@ gold=%.0f p10=%.0f p90=%.0f seconds=%.1f p10=%.1f p90=%.1f banked=%.1f bites=%.1f maxBites=%d hushed=%.1f relics=%.1f capped=%d n=%d",
                      skill.rawValue, percentile(gold, 0.5), percentile(gold, 0.1), percentile(gold, 0.9),
                      percentile(secs, 0.5), percentile(secs, 0.1), percentile(secs, 0.9), percentile(banked, 0.5),
                      percentile(bites, 0.5), maxBites, percentile(hushed, 0.5), percentile(relics, 0.5), capped,
                      runs.count)
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
        let seconds: Double = HushBalanceHarness.median(runs) { (r: HushBalanceRun) -> Double in r.seconds }
        let banked: Double = HushBalanceHarness.median(runs) { (r: HushBalanceRun) -> Double in Double(r.chestsBanked) }
        let bites: Double = HushBalanceHarness.median(runs) { (r: HushBalanceRun) -> Double in Double(r.bites) }
        let maxBites: Int = runs.map { (r: HushBalanceRun) -> Int in r.bites }.max() ?? 0
        switch skill {
        case .novice:
            #expect(bites >= 1, "\(line)")
        case .casual:
            #expect(banked >= 4 && banked <= 8, "\(line)")
            #expect(seconds >= 90 && seconds <= 160, "\(line)")
        case .expert:
            #expect(bites <= 1, "\(line)")
        case .perfect:
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
        // "expert ≤ perfect", with 5 % slack for seed noise (the sim has perfect ~25 % ahead).
        #expect(perfect >= expert * 0.95, "\(line)")
    }
}

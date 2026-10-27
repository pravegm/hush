import Foundation

/// The `HUSH-T …` lines CI greps (design/ROUND-1.md "Log lines"). They print only in DEBUG builds launched with
/// `-hushDemo` (or with `HUSH_ICON=1` in the environment, the icon render). One `print` + `fflush` per line. In Release
/// `enabled` is false and `t(_:)` does nothing, so it can be called from anywhere without `#if` guards.
enum AppTrace {
    static let enabled: Bool = {
        #if DEBUG
        let info = ProcessInfo.processInfo
        return info.arguments.contains("-hushDemo") || info.environment["HUSH_ICON"] == "1"
        #else
        return false
        #endif
    }()

    /// Prints one trace line (DEBUG + demo only), flushed so CI sees lines in order.
    static func t(_ line: @autoclosure () -> String) {
        #if DEBUG
        guard enabled else { return }
        print(line())
        fflush(stdout)
        #endif
    }

    /// A finite Double with `places` decimals (0 for NaN / infinity), for log lines.
    static func fixed(_ value: Double, _ places: Int) -> String {
        guard value.isFinite else { return String(format: "%.\(places)f", 0.0) }
        return String(format: "%.\(places)f", value)
    }

    static func stageName(_ stage: MimicStage) -> String {
        switch stage {
        case .asleep: return "asleep"
        case .stirring: return "stirring"
        case .waking: return "waking"
        case .biting: return "biting"
        }
    }

    static func kindName(_ kind: LootKind) -> String {
        switch kind {
        case .copper: return "copper"
        case .silver: return "silver"
        case let .gem(color): return "gem.\(color.rawValue)"
        case let .relic(id): return "relic.\(id.rawValue)"
        case .oil: return "oil"
        }
    }

    /// `HUSH-T lid <openness 2dp> speed <°/s 1dp> angle <θ 1dp|-> noise <2dp> stage <name>`. Pure; tested.
    static func lidLine(openness: Double, speed: Double, angle: Double?, noise: Double, stage: MimicStage) -> String {
        let a = angle.map { fixed($0, 1) } ?? "-"
        return "HUSH-T lid \(fixed(openness, 2)) speed \(fixed(speed, 1)) angle \(a) noise \(fixed(noise, 2)) "
            + "stage \(stageName(stage))"
    }

    /// The part after `HUSH-T event ` for a HeistEvent: the enum case name, then details. Pure; tested.
    static func describe(_ event: HeistEvent) -> String {
        switch event {
        case let .chestArrived(index, tier, mimic, name):
            return "chestArrived index=\(index) tier=\(tier.rawValue) mimic=\(mimic.rawValue) name=\(name)"
        case .lidCracked: return "lidCracked"
        case let .itemRevealed(id, kind): return "itemRevealed id=\(id) kind=\(kindName(kind))"
        case let .itemPicked(id, kind): return "itemPicked id=\(id) kind=\(kindName(kind))"
        case let .itemDropped(id): return "itemDropped id=\(id)"
        case let .itemBagged(id, kind, value): return "itemBagged id=\(id) kind=\(kindName(kind)) value=\(value)"
        case let .oilAdded(seconds): return "oilAdded seconds=\(fixed(seconds, 1))"
        case let .stageChanged(from, to): return "stageChanged from=\(stageName(from)) to=\(stageName(to))"
        case .dreamTwitch: return "dreamTwitch"
        case let .bitten(lostValue): return "bitten lost=\(lostValue)"
        case let .banked(value, items, hushed): return "banked value=\(value) items=\(items) hushed=\(hushed ? 1 : 0)"
        case let .relicFound(id): return "relicFound id=\(id.rawValue)"
        case .torchLow: return "torchLow"
        case .torchOut: return "torchOut"
        case .newBest: return "newBest"
        case .finished: return "finished"
        }
    }
}

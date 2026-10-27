import Combine
import QuartzCore
import SpriteKit
import SwiftUI

/// The HUD's state over the scene, published at ≤ 15 Hz (and at once when the hint changes).
@MainActor
final class HUDState: ObservableObject {
    @Published private(set) var hint: HeistHint?
    /// The run-start line ("Candle lit. Open it gently."), shown for a beat when no hint is up.
    @Published private(set) var banner: String?
    @Published private(set) var stage: MimicStage = .asleep
    /// Items in the bag (`hud.bag`'s accessibility value: VoiceOver and CI's turned-drag UI test).
    @Published private(set) var bagCount = 0
    /// Demo runs only: the most-lit grabbable item (`debug.loot`, CI's turned-drag UI test).
    @Published private(set) var debugLoot: DebugLoot?

    /// R3 (UX P1-9): what VoiceOver reads over the scene's HUD (the scene draws these; SwiftUI only names them).
    @Published private(set) var spoken = SpokenHUD()

    func update(hint: HeistHint?, banner: String?, stage: MimicStage, bagCount: Int, debugLoot: DebugLoot?,
                spoken: SpokenHUD? = nil) {
        if self.hint != hint { self.hint = hint }
        if self.banner != banner { self.banner = banner }
        if self.stage != stage { self.stage = stage }
        if self.bagCount != bagCount { self.bagCount = bagCount }
        if self.debugLoot != debugLoot { self.debugLoot = debugLoot }
        if let spoken, self.spoken != spoken { self.spoken = spoken }
    }
}

/// R3: the HUD values VoiceOver reads (whole seconds and gold, so they change at most once a second).
struct SpokenHUD: Equatable {
    var bagGold = 0
    var banked = 0
    var candleSeconds = 0
    var stage: MimicStage = .asleep

    init(bagGold: Int = 0, banked: Int = 0, candleSeconds: Int = 0, stage: MimicStage = .asleep) {
        self.bagGold = bagGold; self.banked = banked; self.candleSeconds = candleSeconds; self.stage = stage
    }

    init(_ s: HeistSnapshot) {
        let candle = s.torchRemaining.isFinite ? max(Int(s.torchRemaining.rounded(.up)), 0) : 0
        self.init(bagGold: s.bagValue, banked: s.banked, candleSeconds: candle, stage: s.stage)
    }
}

/// An item the UI test can aim at: its id, kind name, floor-space point and radius.
struct DebugLoot: Equatable {
    var id: Int
    var kind: String
    var floorPoint: CGPoint
    var radius: CGFloat
}

/// Home's title chest: the live lid (hinge on a Duo, a drag on other iPhones).
struct HomeLid: Equatable {
    var openness: Double = 0
    var speed: Double = 0
}

/// Home's caption follows the lid at ≤ 30 Hz. Its own object (QA-1 P2-14): publishing it on the controller re-built
/// the whole RootView, SpriteView included, 30 times a second.
@MainActor
final class HomeLidState: ObservableObject {
    @Published private(set) var lid = HomeLid()

    func update(_ fresh: HomeLid) {
        if fresh != lid { lid = fresh }
    }
}

/// R2 (juror P0-1, one art style): the Scene's front-view mimic (`MimicPortraitScene`, the app icon's chest in the
/// in-game textures) for Home, the cover card and Results. One scene per place (an SKScene shows in one view at a
/// time), made on first use.
@MainActor
final class PortraitScenes {
    /// The scenes' design size (the chest front, a little wider than tall).
    static let size = CGSize(width: 600, height: 480)
    static var aspect: CGFloat { size.width / size.height }

    private(set) lazy var home: MimicPortraitScene = PortraitScenes.make()
    private(set) lazy var cover: MimicPortraitScene = PortraitScenes.make()
    private(set) lazy var results: MimicPortraitScene = PortraitScenes.make()

    private static func make() -> MimicPortraitScene {
        let s = MimicPortraitScene(size: size)
        s.scaleMode = .aspectFit
        s.backgroundColor = .clear
        return s
    }

    func setReduceMotion(_ on: Bool) {
        home.reduceMotion = on
        cover.reduceMotion = on
        results.reduceMotion = on
    }

    /// Home's chest dresses up with the thief's rank. Pure; tested.
    nonisolated static func homeTier(rank: Int) -> ChestTier {
        switch rank {
        case ..<3: return .wooden
        case 3..<6: return .iron
        case 6..<9: return .gilded
        default: return .royal
        }
    }

    /// The live lid → how awake the portrait looks: asleep while quiet, glaring when loud. Pure; tested.
    nonisolated static func wake(speed: Double) -> Double {
        guard speed.isFinite else { return 0 }
        let span = max(Tuning.loudSpeed - Tuning.quietSpeed, 1)
        return min(max((speed - Tuning.quietSpeed) / span, 0), 1)
    }

    /// How the Results mimic looks after a run: smug and half-open if it bit, a sleepy peek if hushed. Pure; tested.
    nonisolated static func resultsPose(_ r: RunResult) -> (openness: Double, wake: Double) {
        if r.bites > 0 { return (0.35, min(0.55 + 0.15 * Double(r.bites), 1)) }
        if r.hushed > 0 { return (0.12, 0) }
        return (0.2, 0.25)
    }
}

/// Everything the Results screen shows (built once when a run is recorded).
struct ResultSummary: Equatable {
    var result: RunResult
    var outcome: RecordOutcome
    /// "Run over", "Daily Dungeon #299", "Daily practice".
    var title: String
    var story: String
    var rankTitle: String
    var nextRankTitle: String?
    var rankProgressBefore: Double
    var rankProgressAfter: Double
    var againLabel: String
    /// R2: "312 short of your best" (nil on a new best, a first haul or an empty run).
    var nearMiss: String? = nil
    /// R3: why the run ended ("Your candle burned out.", "The mimic bit you 3 times. Candle out.").
    var cause: String = ""
}

/// Demo `lid=`: the lid held at one openness, shut for the first 0.25 s so the chest opens (static frames).
@MainActor
final class FixedLidSource: LidSource {
    static let shutFor: Double = 0.25

    var openness: Double = 0
    private var start: TimeInterval?

    func reset() { start = nil }

    func lid(at time: TimeInterval) -> LidInput {
        let s = start ?? time
        start = s
        let o = time - s < Self.shutFor ? 0 : min(max(openness, 0), 1)
        return LidInput(openness: o, speed: 0, inShutZone: o <= 0.15, tooWide: false)
    }
}

/// A display-link tick (Home's live chest: the scene is paused there).
@MainActor
final class FrameTicker: NSObject {
    private var link: CADisplayLink?
    private let tick: @MainActor (TimeInterval) -> Void

    init(_ tick: @escaping @MainActor (TimeInterval) -> Void) {
        self.tick = tick
    }

    func start() {
        guard link == nil else { return }
        let l = CADisplayLink(target: self, selector: #selector(step(_:)))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        l.add(to: .main, forMode: .common)
        link = l
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        tick(link.timestamp)
    }
}

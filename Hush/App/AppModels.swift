import Combine
import QuartzCore
import SwiftUI

/// The HUD's state over the scene, published at ≤ 15 Hz (and at once when the hint changes).
@MainActor
final class HUDState: ObservableObject {
    @Published private(set) var hint: HeistHint?
    /// The run-start line ("Light's lit. Open it gently."), shown for a beat when no hint is up.
    @Published private(set) var banner: String?
    @Published private(set) var stage: MimicStage = .asleep

    func update(hint: HeistHint?, banner: String?, stage: MimicStage) {
        if self.hint != hint { self.hint = hint }
        if self.banner != banner { self.banner = banner }
        if self.stage != stage { self.stage = stage }
    }
}

/// Home's title chest: the live lid (hinge on a Duo, a drag on other iPhones).
struct HomeLid: Equatable {
    var openness: Double = 0
    var speed: Double = 0
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

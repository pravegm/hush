import CoreGraphics
import Foundation

/// Headless play for demo scenarios: a session is really played, step by step, by Core's ThiefPilot (its touches fed
/// in as real touches), so every number on a demo frame (gold, chests, bites, the Results card) is true.
enum DemoRunner {
    /// The headless frame step (s).
    static let step: Double = 1.0 / 60.0

    /// Plays `session` with a `skill` pilot for up to `seconds` of session time, or until it finishes. Returns the
    /// seconds played. `time0` is the touch clock's start (any monotonic base).
    @discardableResult
    static func play(_ session: HeistSession, skill: PilotSkill, seed: UInt64, seconds: Double, time0: Double = 0,
                     onEvent: (HeistEvent) -> Void = { _ in }) -> Double {
        var pilot = ThiefPilot(skill: skill, seed: seed &+ 101)
        var played = 0.0
        while played < seconds && !session.isFinished {
            let now = time0 + played
            let out = pilot.step(dt: step, snapshot: session.snapshot)
            var events: [HeistEvent] = []
            for touch in out.touches {
                switch touch.phase {
                case .began: events += session.touchBegan(id: touch.id, at: touch.point, time: now)
                case .moved: events += session.touchMoved(id: touch.id, to: touch.point, time: now)
                case .ended: events += session.touchEnded(id: touch.id, at: touch.point, time: now)
                }
            }
            events += session.step(dt: step, lid: out.lid)
            for e in events { onEvent(e) }
            played += step
        }
        return played
    }

    /// A whole run played to its end (a 900 s cap guards a pilot that never finishes).
    @discardableResult
    static func playToEnd(_ session: HeistSession, skill: PilotSkill, seed: UInt64, maxSeconds: Double = 900) -> Double {
        play(session, skill: skill, seed: seed, seconds: maxSeconds)
    }
}

import CoreHaptics
import Foundation
import os
import QuartzCore
import UIKit

/// One haptic note: a transient tap or a short continuous buzz (times relative to the cue's start).
struct FeelHapticNote: Sendable, Equatable {
    enum Kind: Sendable, Equatable { case transient, continuous }
    var kind: Kind
    var time: Double
    var intensity: Float
    var sharpness: Float
    var duration: Double

    static func tap(_ intensity: Float, _ sharpness: Float, at time: Double = 0) -> FeelHapticNote {
        FeelHapticNote(kind: .transient, time: time, intensity: intensity, sharpness: sharpness, duration: 0)
    }

    static func buzz(_ intensity: Float, _ sharpness: Float, at time: Double = 0, duration: Double) -> FeelHapticNote {
        FeelHapticNote(kind: .continuous, time: time, intensity: intensity, sharpness: sharpness, duration: duration)
    }
}

/// One point of an intensity-control curve.
struct FeelHapticPoint: Sendable, Equatable {
    var time: Double
    var value: Float
}

/// A haptic cue: notes plus an optional intensity-control curve (ramps and fades).
struct FeelHapticCue: Sendable, Equatable {
    var notes: [FeelHapticNote]
    /// Intensity-control points (time, 0…1 multiplier) applied across the cue (≤ 16); empty = none.
    var curve: [FeelHapticPoint]

    init(notes: [FeelHapticNote], curve: [FeelHapticPoint] = []) {
        self.notes = notes
        self.curve = curve
    }

    /// The end of the last note (s).
    var length: Double {
        notes.map { $0.time + $0.duration }.max() ?? 0
    }
}

/// Normal or Strong haptics (Swoop Round 3). Strong is the Duo default: the founder found the Duo's Taptic Engine
/// weak (Squish, real Duo), so Strong turns every tap into a short, rounder burst the actuator can actually push and
/// lifts the continuous creak. Off is `FeedbackDirector.hapticsOn = false`.
enum FeelHapticProfile: String, Codable, CaseIterable, Sendable {
    case off, normal, strong

    /// The default before the player chooses: Strong on a phone with a fold (a hinge was seen), Normal elsewhere.
    static func defaultFor(hasFold: Bool) -> FeelHapticProfile {
        hasFold ? .strong : .normal
    }
}

/// R7 (ROUND-7 Feel 3, DEVICE-RISKS-1 item 6): the Settings "Vibration" choice, `FeedbackDirector.hapticStrength`.
/// Before the player chooses it follows the device: Strong on a Duo (`deviceHasFold`), Normal elsewhere.
enum HapticStrength: String, Codable, CaseIterable, Sendable {
    case off, normal, strong

    /// The default before the player chooses: Strong on a phone with a fold, Normal elsewhere.
    static func defaultFor(hasFold: Bool) -> HapticStrength {
        hasFold ? .strong : .normal
    }

    /// The row's label.
    var title: String {
        switch self {
        case .off: return "Off"
        case .normal: return "Normal"
        case .strong: return "Strong"
        }
    }

    /// The haptic profile it plays.
    var profile: FeelHapticProfile {
        switch self {
        case .off: return .off
        case .normal: return .normal
        case .strong: return .strong
        }
    }

    init(profile: FeelHapticProfile) {
        switch profile {
        case .off: self = .off
        case .normal: self = .normal
        case .strong: self = .strong
        }
    }
}

/// The haptic vocabulary of Hush (GAME-DESIGN §10). Pure data, so it is testable.
enum FeelHapticBook {
    // MARK: The Strong profile

    /// Strong: continuous intensity × 1.4 (clamped). Every transient becomes a continuous burst this long, at this
    /// sharpness (rounder = more energy on a small actuator), with its intensity × `strongTapGain` (clamped).
    static let strongContinuousGain: Float = 1.4
    static let strongBurst: Double = 0.055
    static let strongBurstSharpness: Float = 0.4
    static let strongTapGain: Float = 1.15

    /// A cue in the given profile: Normal (and Off, which never plays) unchanged; Strong as above. The curve is kept.
    static func adapt(_ cue: FeelHapticCue, to profile: FeelHapticProfile) -> FeelHapticCue {
        guard profile == .strong else { return cue }
        let notes: [FeelHapticNote] = cue.notes.map { (note: FeelHapticNote) -> FeelHapticNote in
            switch note.kind {
            case .transient:
                return .buzz(min(note.intensity * strongTapGain, 1), strongBurstSharpness, at: note.time,
                             duration: strongBurst)
            case .continuous:
                return .buzz(min(note.intensity * strongContinuousGain, 1), note.sharpness, at: note.time,
                             duration: note.duration)
            }
        }
        return FeelHapticCue(notes: notes, curve: cue.curve)
    }

    // MARK: The continuous creak texture (the hinge you can feel)

    /// Creak intensity (0…1) for a lid speed: ∝ (speed − quiet) / 30 in the creak zone, 0 at or below
    /// `Tuning.quietSpeed`. The director passes `FeelSoundBook.creakSpeed(_:closing:)`, so a closing lid is silent up to
    /// `FeelSoundBook.closeQuietSpeed` here too.
    static let creakSpan = 30.0
    static func creakLevel(speed: Double) -> Float {
        guard speed.isFinite, speed > Tuning.quietSpeed else { return 0 }
        return Float(FeelMath.clamp01((speed - Tuning.quietSpeed) / creakSpan))
    }

    /// The creak for a profile (Strong × 1.4).
    static func creakLevel(speed: Double, profile: FeelHapticProfile) -> Float {
        let level = creakLevel(speed: speed)
        switch profile {
        case .off: return 0
        case .normal: return level
        case .strong: return min(level * strongContinuousGain, 1)
        }
    }

    /// Creak sharpness: 0.3 (a slow, woody groan) … 0.6 (a fast, keen squeal), before the per-send jitter.
    static let creakSharpnessLow: Float = 0.3
    static let creakSharpnessHigh: Float = 0.6
    /// Jitter (±) added to the creak's sharpness and (as a fraction) to its intensity at every send: the stick-slip
    /// grain you feel under your fingers.
    static let creakSharpnessJitter: Float = 0.07
    static let creakIntensityJitter: Float = 0.15
    static func creakSharpness(speed: Double) -> Float {
        let u = speed.isFinite ? FeelMath.clamp01((speed - Tuning.quietSpeed) / 40) : 0
        return creakSharpnessLow + (creakSharpnessHigh - creakSharpnessLow) * Float(u)
    }

    /// The loot rattle (dragging faster than 250 pt/s): a light, keen buzz.
    static func rattleLevel(dragSpeed: Double, profile: FeelHapticProfile) -> Float {
        guard profile != .off, dragSpeed.isFinite, dragSpeed > FeelSoundBook.rattleSpeed else { return 0 }
        let u = FeelMath.clamp01((dragSpeed - FeelSoundBook.rattleSpeed)
                                 / (FeelSoundBook.rattleFullSpeed - FeelSoundBook.rattleSpeed))
        let level = Float(0.12 + 0.3 * u)
        return profile == .strong ? min(level * strongContinuousGain, 1) : level
    }

    // MARK: Moments

    /// A coin into the bag: a crisp tick.
    static let coinTick = FeelHapticCue(notes: [.tap(0.45, 0.9)])
    /// A finger takes an item: a faint lift.
    static let pick = FeelHapticCue(notes: [.tap(0.3, 0.7)])
    /// Dropped back into the chest: a dull clunk.
    static let drop = FeelHapticCue(notes: [.tap(0.6, 0.3), .buzz(0.25, 0.2, at: 0.01, duration: 0.05)])
    /// Into the bag: a soft leather thump, then the item's tick.
    static let bagThump = FeelHapticCue(notes: [.tap(0.55, 0.3), .buzz(0.3, 0.2, at: 0.01, duration: 0.04),
                                                .tap(0.4, 0.9, at: 0.035)])
    /// A gem or relic into the bag: the thump and a brighter double sparkle.
    static let bagTreasure = FeelHapticCue(notes: [.tap(0.55, 0.3), .buzz(0.3, 0.2, at: 0.01, duration: 0.04),
                                                   .tap(0.45, 0.95, at: 0.035), .tap(0.35, 1.0, at: 0.11)])

    /// Banking: a heavy thunk, a rattle of light taps on the cascade's clinks, then the ka-ching.
    static func bank(cascade: [Double]) -> FeelHapticCue {
        var notes: [FeelHapticNote] = [.tap(1.0, 0.2), .buzz(0.75, 0.1, at: 0.005, duration: 0.12)]
        for (index, time) in cascade.prefix(14).enumerated() {
            let fade = Float(1 - 0.35 * Double(index) / Double(max(cascade.count - 1, 1)))
            notes.append(.tap(0.4 * fade, 0.85, at: time))
        }
        notes.append(.tap(0.7, 0.5, at: Double(FeelSoundBook.kaChingAt)))
        return FeelHapticCue(notes: notes)
    }

    /// The heartbeat at Waking: lub-dub, low and firm.
    static let heartbeat = FeelHapticCue(notes: [.tap(0.75, 0.15), .tap(0.5, 0.15, at: 0.14)])
    /// The bite: the strongest moment of the game. A full-strength slam, a heavy shudder that fades, and the jaw's
    /// second snap.
    static let bite = FeelHapticCue(
        notes: [.tap(1.0, 0.7), .buzz(1.0, 0.15, duration: 0.32), .tap(0.85, 0.4, at: 0.12)],
        curve: [FeelHapticPoint(time: 0, value: 1), FeelHapticPoint(time: 0.12, value: 0.9),
                FeelHapticPoint(time: 0.22, value: 0.5), FeelHapticPoint(time: 0.32, value: 0)]
    )
    /// The mimic stirs: one soft nudge (R7, DEVICE-RISKS-1 item 6: 0.35 → 0.5, the tells were too faint on a Duo). It
    /// wakes: a firm double.
    static let stirring = FeelHapticCue(notes: [.tap(0.5, 0.3)])
    /// R7 (ROUND-7 Feel 3): the faint "safe" grain of careful play, one per `FeelQuietTicker.degreesPerTick` (4°) of
    /// quiet lid travel, so a slow, silent open still feels like a hinge. Strong-adapted like every cue.
    static let quietTick = FeelHapticCue(notes: [.tap(0.18, 0.8)])
    static let waking = FeelHapticCue(notes: [.tap(0.8, 0.3), .tap(0.6, 0.3, at: 0.12)])
    /// A chest slides in and lands.
    static let chestArrived = FeelHapticCue(
        notes: [.buzz(0.25, 0.2, duration: 0.3), .tap(0.45, 0.4, at: 0.38)],
        curve: [FeelHapticPoint(time: 0, value: 0.3), FeelHapticPoint(time: 0.3, value: 1),
                FeelHapticPoint(time: 0.32, value: 0)]
    )
    /// The lid first cracks: the faintest glint.
    static let lidCracked = FeelHapticCue(notes: [.tap(0.2, 0.9)])
    static let oil = FeelHapticCue(notes: [.tap(0.35, 0.5), .tap(0.25, 0.5, at: 0.09)])
    static let torchLow = FeelHapticCue(notes: [.buzz(0.3, 0.3, duration: 0.25)],
                                        curve: [FeelHapticPoint(time: 0, value: 1),
                                                FeelHapticPoint(time: 0.25, value: 0)])
    static let torchOut = FeelHapticCue(notes: [.buzz(0.5, 0.1, duration: 0.8)],
                                        curve: [FeelHapticPoint(time: 0, value: 1),
                                                FeelHapticPoint(time: 0.8, value: 0)])
    static let newBest = FeelHapticCue(notes: [.tap(0.4, 0.8), .tap(0.5, 0.9, at: 0.085), .tap(0.65, 0.95, at: 0.17)])
    static let uiTap = FeelHapticCue(notes: [.tap(0.35, 0.7)])
    static let uiConfirm = FeelHapticCue(notes: [.tap(0.5, 0.8), .tap(0.4, 0.9, at: 0.06)])
    static let celebrate = FeelHapticCue(notes: [.tap(0.5, 0.6), .tap(0.6, 0.7, at: 0.09), .tap(0.75, 0.8, at: 0.18),
                                                 .tap(1.0, 0.9, at: 0.3)])

    // MARK: R2 moments

    /// The Hush Chain grew: one keen tap per chime of `FeelSoundBook.chainNotes`, climbing, starting at `delay`.
    static func chainUp(count: Int, delay: Double = 0) -> FeelHapticCue {
        let notes = FeelSoundBook.chainNotes(count: count)
        var taps: [FeelHapticNote] = []
        for index in 0..<notes.count {
            let k = Float(index) / Float(max(notes.count - 1, 1))
            taps.append(.tap(0.3 + 0.2 * k, 0.85 + 0.15 * k, at: max(delay, 0) + 0.065 * Double(index)))
        }
        return FeelHapticCue(notes: taps)
    }

    /// The chain broke: a sharp crack, then the shards as tiny ticks (the sound's own times).
    static func chainBroken(delay: Double = 0) -> FeelHapticCue {
        let start = max(delay, 0)
        var notes: [FeelHapticNote] = [.tap(0.7, 1.0, at: start)]
        for (index, time) in FeelSoundBook.chainShardTimes.enumerated() {
            notes.append(.tap(0.28 - 0.04 * Float(index), 1.0, at: start + Double(time)))
        }
        return FeelHapticCue(notes: notes)
    }

    /// A golden mimic arrives: a rising ripple of light taps with the glissando, then a soft swell.
    static func goldenArrived(delay: Double = 0.4) -> FeelHapticCue {
        let start = max(delay, 0)
        var notes: [FeelHapticNote] = []
        for index in 0..<7 {
            let k = Float(index) / 6
            notes.append(.tap(0.2 + 0.3 * k, 0.6 + 0.4 * k, at: start + 0.045 * Double(index)))
        }
        notes.append(.buzz(0.3, 0.5, at: start + 0.32, duration: 0.4))
        return FeelHapticCue(notes: notes,
                             curve: [FeelHapticPoint(time: 0, value: 1),
                                     FeelHapticPoint(time: start + 0.31, value: 1),
                                     FeelHapticPoint(time: start + 0.32, value: 0.2),
                                     FeelHapticPoint(time: start + 0.5, value: 1),
                                     FeelHapticPoint(time: start + 0.72, value: 0)])
    }

    /// The bite's coins spill: a light patter on the spill's own times (after the bite's slam and shudder).
    static func coinSpill(times: [Double]) -> FeelHapticCue {
        var notes: [FeelHapticNote] = []
        for (index, time) in times.prefix(12).enumerated() {
            let fade = Float(1 - 0.5 * Double(index) / Double(max(times.count - 1, 1)))
            notes.append(.tap(0.4 * fade, 0.85, at: max(time, 0)))
        }
        return FeelHapticCue(notes: notes)
    }

    /// The stage nudge for a stage change: a soft nudge up to Stirring, a firm double up to Waking; nothing for a step
    /// down, a bite (the `bite` cue) or no change.
    static func stageCue(from: MimicStage, to: MimicStage) -> FeelHapticCue? {
        guard to > from else { return nil }
        switch to {
        case .stirring: return stirring
        case .waking: return waking
        case .asleep, .biting: return nil
        }
    }

    /// R3 CREAK (the slam): a hard, keen crack you feel in the lid, then a smaller splinter tick. Sharper and shorter
    /// than the bite (which stays the strongest cue), with the sound's own second crack.
    static let creakAccent = FeelHapticCue(notes: [.tap(0.9, 1.0), .tap(0.45, 0.85, at: 0.014),
                                                   .tap(0.3, 0.9, at: 0.05)])

    /// The candle clock: the faintest tick from 15 s, a firmer, keener one twice a second in the last 5.
    static func candleTick(urgent: Bool) -> FeelHapticCue {
        let note: FeelHapticNote = urgent ? FeelHapticNote.tap(0.32, 0.9) : FeelHapticNote.tap(0.14, 0.8)
        return FeelHapticCue(notes: [note])
    }
}

/// Core Haptics for Hush: two looping advanced players carry the continuous feel (the creak texture and the loot
/// rattle, steered by dynamic parameters at ≤ 30 Hz with ramps, so there is no zipper), and every moment plays as its
/// own short pattern. Self-healing after stops and server resets (Squish's/Brim's/Swoop's pattern). Phones without
/// Core Haptics fall back to `UIImpactFeedbackGenerator` for the moments.
@MainActor
final class FeelHaptics {
    private static let log = Logger(subsystem: "com.pravegm.hush", category: "haptics")

    var enabled = true {
        didSet {
            guard oldValue != enabled else { return }
            if enabled {
                guard wantsStart else { return }
                if engine == nil { start() } else { restart() }
            } else {
                // Switched off mid-session: the hardware goes to sleep at once.
                setContinuous(creak: 0, sharpness: 0.4, rattle: 0, now: CACurrentMediaTime(), force: true)
                stopPlayers()
                if let engine, isRunning { engine.stop(completionHandler: nil) }
                isRunning = false
            }
        }
    }

    /// Normal or Strong (Off is `enabled = false`, set by the director).
    var profile: FeelHapticProfile = .normal

    /// Menus and long pauses: no looping players, and the engine may shut the hardware down by itself. A cue still
    /// plays (the engine is started again for it). Off: the players are rebuilt at once.
    var idle = false {
        didSet {
            guard oldValue != idle else { return }
            if idle {
                stopPlayers()
                engine?.isAutoShutdownEnabled = true
            } else {
                engine?.isAutoShutdownEnabled = false
                if engine != nil && (!isRunning || creakPlayer == nil) { restart() }
            }
        }
    }

    private let supportsHaptics: Bool = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?
    private var creakPlayer: CHHapticAdvancedPatternPlayer?
    private var rattlePlayer: CHHapticAdvancedPatternPlayer?
    private var isRunning = false
    private var wantsStart = false
    private var lastRecovery: CFTimeInterval = 0
    private var lastSend: CFTimeInterval = 0
    private var lastCreak: Float = 0
    private var lastSharpness: Float = 0.4
    private var lastRattle: Float = 0
    private var dice = FeelDice(seed: 0x4855_5348)
    private var fallbackLight: UIImpactFeedbackGenerator?
    private var fallbackMedium: UIImpactFeedbackGenerator?
    private var fallbackHeavy: UIImpactFeedbackGenerator?
    private(set) var lastError: String?

    init() {}

    /// Idempotent. Does nothing while haptics are off (it starts when they are switched on).
    func start() {
        wantsStart = true
        guard enabled else { return }
        guard supportsHaptics else {
            prepareFallback()
            return
        }
        guard engine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = idle
            // Both handlers arrive on an engine-internal queue: hop to the main actor.
            engine.stoppedHandler = { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.isRunning = false
                    self.creakPlayer = nil
                    self.rattlePlayer = nil
                }
            }
            engine.resetHandler = { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    self.isRunning = false
                    self.creakPlayer = nil
                    self.rattlePlayer = nil
                    self.restart()
                }
            }
            self.engine = engine
            restart()
        } catch {
            record("Couldn't create the haptic engine", error)
            engine = nil
        }
    }

    /// The app became active again: the system stops the engine on suspension.
    func resume() {
        guard supportsHaptics, enabled, wantsStart else { return }
        if engine == nil {
            start()
        } else if !isRunning || (!idle && creakPlayer == nil) {
            restart()
        }
    }

    /// Throttled recovery from the frame loop.
    func heal() {
        guard enabled, engine != nil, !isRunning || (!idle && creakPlayer == nil) else { return }
        guard UIApplication.shared.applicationState != .background else { return }
        restart()
    }

    private func restart() {
        guard enabled, let engine else { return }
        do {
            try engine.start()
            isRunning = true
        } catch {
            isRunning = false
            record("Couldn't start the haptic engine", error)
            return
        }
        creakPlayer = nil
        rattlePlayer = nil
        // Menus have no lid in play: no looping players to keep the hardware awake.
        if idle { return }
        do {
            creakPlayer = try makeLoopingPlayer(sharpness: 0.4)
            rattlePlayer = try makeLoopingPlayer(sharpness: 0.9)
            lastCreak = 0
            lastRattle = 0
        } catch {
            record("Couldn't build the continuous haptics", error)
        }
    }

    private func stopPlayers() {
        if let player = creakPlayer { try? player.stop(atTime: CHHapticTimeImmediate) }
        if let player = rattlePlayer { try? player.stop(atTime: CHHapticTimeImmediate) }
        creakPlayer = nil
        rattlePlayer = nil
        lastCreak = 0
        lastRattle = 0
    }

    /// One looping continuous event at intensity 1; the intensity control scales it (starts at 0).
    private func makeLoopingPlayer(sharpness: Float) throws -> CHHapticAdvancedPatternPlayer? {
        guard let engine else { return nil }
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: 0,
            duration: 30
        )
        let pattern = try CHHapticPattern(events: [event], parameters: [])
        let player = try engine.makeAdvancedPlayer(with: pattern)
        player.loopEnabled = true
        let zero = [CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: 0, relativeTime: 0)]
        try player.sendParameters(zero, atTime: CHHapticTimeImmediate)
        try player.start(atTime: CHHapticTimeImmediate)
        try player.sendParameters(zero, atTime: CHHapticTimeImmediate)
        return player
    }

    // MARK: - Per frame

    /// The continuous feel: call every frame with the lid speed (°/s) and the drag speed (pt/s); 0 for both fades it
    /// out. Sends at most ~30 times a second, ramping between values (no zipper); while creaking every send carries a
    /// little intensity and sharpness jitter (the stick-slip grain).
    func update(lidSpeed: Double, dragSpeed: Double, now: CFTimeInterval) {
        var creak: Float = 0
        var sharpness = lastSharpness
        var rattle: Float = 0
        if enabled {
            creak = FeelHapticBook.creakLevel(speed: lidSpeed, profile: profile)
            rattle = FeelHapticBook.rattleLevel(dragSpeed: dragSpeed, profile: profile)
            if creak > 0 {
                sharpness = FeelHapticBook.creakSharpness(speed: lidSpeed)
            }
        }
        setContinuous(creak: creak, sharpness: sharpness, rattle: rattle, now: now, force: false)
    }

    /// Fade the continuous feel to nothing.
    func quiet(now: CFTimeInterval) {
        setContinuous(creak: 0, sharpness: lastSharpness, rattle: 0, now: now, force: false)
    }

    private func setContinuous(creak: Float, sharpness: Float, rattle: Float, now: CFTimeInterval, force: Bool) {
        guard isRunning, let creakPlayer else { return }
        let silencing = (creak == 0 && lastCreak > 0) || (rattle == 0 && lastRattle > 0)
        // While creaking, every send is a little different (the jitter), so it sends at the full 30 Hz.
        let changed = creak > 0 || abs(rattle - lastRattle) > 0.015
        guard force || silencing || changed else { return }
        guard force || silencing || now - lastSend >= 1.0 / 30 else { return }
        lastSend = now
        var intensity = creak
        var keen = sharpness
        if creak > 0 {
            intensity = min(max(creak * (1 + FeelHapticBook.creakIntensityJitter * Float(dice.range(-1, 1))), 0), 1)
            keen = min(max(sharpness + FeelHapticBook.creakSharpnessJitter * Float(dice.range(-1, 1)),
                           FeelHapticBook.creakSharpnessLow), FeelHapticBook.creakSharpnessHigh)
        }
        let ramp: TimeInterval = silencing ? 0.06 : 1.0 / 30
        schedule(creakPlayer, from: lastCreak, to: intensity, ramp: ramp)
        // Sharpness control is an offset from the event's 0.4.
        try? creakPlayer.sendParameters([CHHapticDynamicParameter(parameterID: .hapticSharpnessControl,
                                                                  value: keen - 0.4, relativeTime: 0)],
                                        atTime: CHHapticTimeImmediate)
        if let rattlePlayer {
            schedule(rattlePlayer, from: lastRattle, to: rattle, ramp: ramp)
        }
        lastCreak = intensity
        lastSharpness = keen
        lastRattle = rattle
    }

    private func schedule(_ player: CHHapticAdvancedPatternPlayer, from start: Float, to end: Float,
                          ramp: TimeInterval) {
        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: start),
                CHHapticParameterCurve.ControlPoint(relativeTime: ramp, value: end),
            ],
            relativeTime: 0
        )
        try? player.scheduleParameterCurve(curve, atTime: CHHapticTimeImmediate)
    }

    // MARK: - Moments

    func play(_ cue: FeelHapticCue) {
        guard enabled, !cue.notes.isEmpty else { return }
        guard supportsHaptics else {
            playFallback(cue)
            return
        }
        if !isRunning || engine == nil {
            let now = CACurrentMediaTime()
            if now - lastRecovery > 0.5 {
                lastRecovery = now
                resume()
            }
        }
        guard let engine, isRunning else { return }
        do {
            let player = try engine.makePlayer(with: try Self.pattern(for: cue))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            record("Couldn't play a haptic", error)
        }
    }

    /// The Core Haptics pattern for a cue.
    private static func pattern(for cue: FeelHapticCue) throws -> CHHapticPattern {
        let events: [CHHapticEvent] = cue.notes.map { (note: FeelHapticNote) -> CHHapticEvent in
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: min(max(note.intensity, 0), 1))
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: min(max(note.sharpness, 0), 1))
            switch note.kind {
            case .transient:
                return CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness],
                                     relativeTime: note.time)
            case .continuous:
                return CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness],
                                     relativeTime: note.time, duration: max(note.duration, 0.01))
            }
        }
        var curves: [CHHapticParameterCurve] = []
        if !cue.curve.isEmpty {
            var points: [CHHapticParameterCurve.ControlPoint] = []
            for point in cue.curve.prefix(16) {
                points.append(CHHapticParameterCurve.ControlPoint(relativeTime: point.time, value: point.value))
            }
            curves.append(CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: points,
                                                 relativeTime: 0))
        }
        return try CHHapticPattern(events: events, parameterCurves: curves)
    }

    // MARK: - Fallback (no Core Haptics)

    private func prepareFallback() {
        if fallbackLight == nil { fallbackLight = UIImpactFeedbackGenerator(style: .light) }
        if fallbackMedium == nil { fallbackMedium = UIImpactFeedbackGenerator(style: .medium) }
        if fallbackHeavy == nil { fallbackHeavy = UIImpactFeedbackGenerator(style: .heavy) }
        fallbackLight?.prepare()
        fallbackMedium?.prepare()
        fallbackHeavy?.prepare()
    }

    /// Up to three notes of the cue as impacts (a buzz plays as one impact at its start).
    private func playFallback(_ cue: FeelHapticCue) {
        prepareFallback()
        let notes = Array(cue.notes.sorted { $0.time < $1.time }.prefix(3))
        for note in notes {
            let intensity = CGFloat(min(max(note.intensity, 0.05), 1))
            let generator: UIImpactFeedbackGenerator?
            if note.intensity >= 0.75 {
                generator = fallbackHeavy
            } else if note.intensity >= 0.4 {
                generator = fallbackMedium
            } else {
                generator = fallbackLight
            }
            guard let generator else { continue }
            if note.time <= 0.005 {
                generator.impactOccurred(intensity: intensity)
            } else {
                let delay = UInt64(note.time * 1_000_000_000)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: delay)
                    generator.impactOccurred(intensity: intensity)
                }
            }
        }
    }

    private func record(_ what: String, _ error: Error) {
        let nsError = error as NSError
        let message = "\(what): \(nsError.localizedDescription) (code \(nsError.code))"
        lastError = message
        Self.log.error("\(message, privacy: .public)")
    }
}

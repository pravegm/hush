import Foundation
import QuartzCore
import UIKit

/// Audio + haptics for Hush (GAME-DESIGN §10). The App calls `start()` once at launch, sets the toggles from its
/// SettingsStore, then calls `handle(_:telemetry:)` every game frame (and `homeLid(speed:openness:)` every Home frame).
/// Everything audible is synthesised in real time (`FeelSynth`); every touch is Core Haptics (`FeelHaptics`).
///
/// Per frame it builds one small value (`FeelBed`: the creak, the snore, the growl, the tiptoe motif, the dungeon, the
/// loot rattle), pushes it into a lock-free queue (≤ 60 Hz) and steers the two looping haptic players (≤ 30 Hz: the
/// creak texture and the rattle). It also keeps the beat for the heartbeat (sound and, at Waking, haptic together)
/// and the last-15-seconds torch tick. Events map to short recipes from `FeelSoundBook` and `FeelHapticBook`.
///
/// Battery: with `idle` set (menus), or after `idleDelay` s with no play and no events, the engines idle by themselves
/// (the haptic players stop, the audio engine naps once quiet). A playing frame, an event, a menu sound or the Home
/// creak wakes them. If the frames stop without a `silence()` (the app went away), a watchdog fades the continuous
/// layers after `staleAfter` s, so nothing can be left creaking.
@MainActor
final class FeedbackDirector: FeedbackSink {
    static let shared = FeedbackDirector()

    /// Seconds without play (and without events) before the engines idle.
    static let idleDelay: Double = 3
    /// The dungeon ambience is kept up this long after play stops (the 1.4–2 s bank and bite moments), then fades.
    static let ambienceHold: Double = 3
    /// Seconds without a `handle` or `homeLid` call after which the continuous layers fade by themselves.
    static let staleAfter: Double = 0.25
    /// Minimum gaps (s) between repeats of the same cue (a burst of events never machine-guns).
    static let revealGap: Double = 0.07
    static let revealMaxDelay: Double = 0.3
    static let pickGap: Double = 0.04
    static let dropGap: Double = 0.06

    var soundOn: Bool = true {
        didSet {
            guard oldValue != soundOn else { return }
            audio.enabled = soundOn
            audio.setBed(FeelSoundBook.idleBed(master: master))
        }
    }

    /// Haptics on/off (Settings). Turning it on restores the last profile, or the device default.
    var hapticsOn: Bool {
        get { profile != .off }
        set {
            if !newValue {
                applyProfile(.off)
            } else if profile == .off {
                applyProfile(profileChosen ? lastOnProfile : FeelHapticProfile.defaultFor(hasFold: deviceHasFold))
            }
        }
    }

    /// Additive (Swoop's Strong profile): Normal or Strong haptics. Setting it counts as the player's choice; until
    /// then the profile follows the device (`deviceHasFold`: Strong on a Duo, whose Taptic Engine is weak).
    var hapticProfile: FeelHapticProfile {
        get { profile }
        set {
            profileChosen = true
            applyProfile(newValue)
        }
    }

    /// Additive: the App sets this once a hinge has been seen (a Duo). It moves an unchosen profile to Strong.
    var deviceHasFold: Bool = false {
        didSet {
            guard oldValue != deviceHasFold, !profileChosen, profile != .off else { return }
            applyProfile(FeelHapticProfile.defaultFor(hasFold: deviceHasFold))
        }
    }

    /// `.ambient` (silenced by the switch) instead of `.playback` + `.mixWithOthers`.
    var respectSilentSwitch: Bool = false {
        didSet {
            guard oldValue != respectSilentSwitch else { return }
            audio.respectSilentSwitch = respectSilentSwitch
        }
    }

    /// Menus: the engines may nap once quiet. A menu sound or the Home creak still plays (it wakes them).
    var idle: Bool = false {
        didSet {
            guard oldValue != idle else { return }
            refreshIdle(now: CACurrentMediaTime())
        }
    }

    private let audio = FeelAudioEngine()
    private let haptics = FeelHaptics()
    private var started = false
    private var activationObserver: NSObjectProtocol?
    private var dice = FeelDice(seed: 0x4855_5348)
    private var profile: FeelHapticProfile = .normal
    private var lastOnProfile: FeelHapticProfile = .normal
    private var profileChosen = false

    private var lastBedSend: CFTimeInterval = 0
    private var lastHeal: CFTimeInterval = 0
    private var lastActive: CFTimeInterval = -Double.infinity
    private var lastPlaying: CFTimeInterval = -Double.infinity
    private var lastFrame: CFTimeInterval = -Double.infinity
    private var lastHomeCreak: CFTimeInterval = -Double.infinity
    private var audioIdle = false
    private var hapticIdle = false
    private var wasPlaying = false
    private var continuousLive = false
    private var watchdogPending = false

    private var nextBeat: CFTimeInterval = -Double.infinity
    private var beatStage: MimicStage = .asleep
    private var lastTorchSecond: Int?
    private var nextRevealSlot: CFTimeInterval = -Double.infinity
    private var lastPick: CFTimeInterval = -Double.infinity
    private var lastDrop: CFTimeInterval = -Double.infinity

    init() {
        // Menus play before any game frame: start from an audible, empty bed (a master of 0 mutes one-shots too).
        audio.setBed(FeelSoundBook.idleBed(master: master))
    }

    private var master: Float { soundOn ? FeelAudioEngine.masterGain : 0 }

    /// True while the engines idle (menus, a long pause).
    var idling: Bool { audioIdle }

    /// Audio session + engines. Safe to call more than once; also called lazily by the first sound.
    func start() {
        guard !started else { return }
        started = true
        audio.enabled = soundOn
        audio.respectSilentSwitch = respectSilentSwitch
        haptics.enabled = profile != .off
        if profile != .off { haptics.profile = profile }
        audio.start()
        haptics.start()
        activationObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.audio.resume()
                self?.haptics.resume()
            }
        }
    }

    // MARK: - Per frame

    func handle(_ events: [HeistEvent], telemetry: HeistTelemetry) {
        ensureStarted()
        let now = CACurrentMediaTime()
        lastFrame = now
        let creaking = FeelSoundBook.creakLevel(speed: telemetry.lidSpeed) > 0
        if telemetry.playing || !events.isEmpty || creaking {
            lastActive = now
        }
        if telemetry.playing { lastPlaying = now }
        refreshIdle(now: now)
        heal(now: now)

        // The continuous layers. Leaving play glides slowly instead of cutting.
        let leavingPlay = wasPlaying && !telemetry.playing
        if now - lastBedSend >= 1.0 / 60 || leavingPlay {
            lastBedSend = now
            let ambience = now - lastPlaying <= Self.ambienceHold ? 1.0 : 0.0
            var bed = FeelSoundBook.heistBed(telemetry: telemetry, master: master, ambience: ambience)
            if !telemetry.playing { bed.glide = FeelSoundBook.fadeGlide }
            audio.setBed(bed)
            continuousLive = true
        }
        wasPlaying = telemetry.playing
        haptics.update(lidSpeed: telemetry.lidSpeed, dragSpeed: telemetry.playing ? telemetry.dragSpeed : 0, now: now)

        keepTheBeat(telemetry: telemetry, now: now)
        tickTheTorch(telemetry: telemetry)

        var banking = false
        for event in events {
            if case .banked = event { banking = true }
        }
        var choirPlayed = false
        for event in events {
            react(to: event, banking: banking, choirPlayed: &choirPlayed, now: now)
        }
        scheduleWatchdog()
    }

    /// The Home screen's live creak: the title chest follows the hinge (or the slider). Call every Home frame with the
    /// lid source's speed (°/s) and openness. Creak sound and haptic only.
    func homeLid(speed: Double, openness: Double) {
        ensureStarted()
        let now = CACurrentMediaTime()
        lastFrame = now
        let creaking = FeelSoundBook.creakLevel(speed: speed) > 0
        if creaking {
            lastActive = now
            lastHomeCreak = now
        }
        refreshIdle(now: now)
        heal(now: now)
        if now - lastBedSend >= 1.0 / 60 {
            lastBedSend = now
            audio.setBed(FeelSoundBook.homeBed(speed: speed, openness: openness, master: master))
            continuousLive = true
        }
        wasPlaying = false
        haptics.update(lidSpeed: speed, dragSpeed: 0, now: now)
        scheduleWatchdog()
    }

    /// Fade the continuous layers out (pause, menus). One-shots already ringing play out; the engines idle after
    /// `idleDelay` s unless play resumes.
    func silence() {
        let now = CACurrentMediaTime()
        audio.setBed(FeelSoundBook.idleBed(master: master, glide: FeelSoundBook.fadeGlide))
        haptics.quiet(now: now)
        wasPlaying = false
        continuousLive = false
        nextBeat = -Double.infinity
        // Count the quiet from now (a pause right after a game frame still waits the full delay).
        lastActive = now
        lastPlaying = -Double.infinity
        scheduleIdleCheck()
    }

    // MARK: - Menu sounds

    func uiTap() {
        ensureStarted()
        audio.play(FeelSoundBook.uiTap())
        playHaptic(FeelHapticBook.uiTap)
    }

    func uiConfirm() {
        ensureStarted()
        audio.play(FeelSoundBook.uiConfirm())
        playHaptic(FeelHapticBook.uiConfirm)
    }

    /// Rank up, a new relic page, a new best on the results card: a rising chime arpeggio with a coin shower.
    func celebrate() {
        ensureStarted()
        audio.play(FeelSoundBook.celebrate(dice: &dice))
        playHaptic(FeelHapticBook.celebrate)
    }

    // MARK: - The beat and the torch

    /// The heartbeat: slow at Stirring (sound), fast at Waking (sound and haptic, in step).
    private func keepTheBeat(telemetry: HeistTelemetry, now: CFTimeInterval) {
        guard telemetry.playing, let interval = FeelSoundBook.heartInterval(stage: telemetry.stage) else {
            nextBeat = -Double.infinity
            beatStage = telemetry.stage
            return
        }
        if beatStage != telemetry.stage || !nextBeat.isFinite {
            // A new stage: the first beat comes quickly (after the stage's own sting has spoken).
            beatStage = telemetry.stage
            nextBeat = now + 0.25
            return
        }
        guard now >= nextBeat else { return }
        // Keep the grid (no drift), but never fire a burst of catch-up beats after a hitch.
        nextBeat += interval
        if nextBeat < now { nextBeat = now + interval }
        let fast = telemetry.stage == .waking
        audio.play(FeelSoundBook.heartbeat(fast: fast))
        if fast { playHaptic(FeelHapticBook.heartbeat) }
    }

    /// A dry tick on each whole second of the torch's last 15.
    private func tickTheTorch(telemetry: HeistTelemetry) {
        let remaining = telemetry.torchRemaining
        guard telemetry.playing, remaining.isFinite, remaining > 0,
              remaining <= FeelSoundBook.torchLowSeconds else {
            lastTorchSecond = nil
            return
        }
        let second = Int(remaining.rounded(.up))
        if let last = lastTorchSecond, second < last {
            audio.play(FeelSoundBook.torchTick())
        }
        lastTorchSecond = second
    }

    // MARK: - Events

    private func react(to event: HeistEvent, banking: Bool, choirPlayed: inout Bool, now: CFTimeInterval) {
        switch event {
        case .chestArrived(_, let tier, _, _):
            audio.play(FeelSoundBook.chestArrived(tier: tier, dice: &dice))
            playHaptic(FeelHapticBook.chestArrived)
        case .lidCracked:
            audio.play(FeelSoundBook.lidCracked())
            playHaptic(FeelHapticBook.lidCracked)
        case .itemRevealed(_, let kind):
            // Several items lit in one stroke: a little run of glints, not a pile-up.
            let delay = max(nextRevealSlot - now, 0)
            guard delay <= Self.revealMaxDelay else { return }
            nextRevealSlot = now + delay + Self.revealGap
            audio.play(FeelSoundBook.itemRevealed(kind, dice: &dice, delay: Float(delay)))
        case .itemPicked(_, let kind):
            guard now - lastPick >= Self.pickGap else { return }
            lastPick = now
            audio.play(FeelSoundBook.itemPicked(kind, dice: &dice))
            playHaptic(FeelHapticBook.pick)
        case .itemDropped:
            guard now - lastDrop >= Self.dropGap else { return }
            lastDrop = now
            audio.play(FeelSoundBook.itemDropped(dice: &dice))
            playHaptic(FeelHapticBook.drop)
        case .itemBagged(_, let kind, _):
            audio.play(FeelSoundBook.itemBagged(kind, dice: &dice))
            switch kind {
            case .gem, .relic: playHaptic(FeelHapticBook.bagTreasure)
            case .copper, .silver, .oil: playHaptic(FeelHapticBook.bagThump)
            }
        case .oilAdded:
            playHaptic(FeelHapticBook.oil)
        case .stageChanged(let from, let to):
            if to > from {
                switch to {
                case .stirring:
                    audio.play(FeelSoundBook.snort(dice: &dice))
                    playHaptic(FeelHapticBook.stirring)
                case .waking:
                    audio.play(FeelSoundBook.wakeSting())
                    playHaptic(FeelHapticBook.waking)
                case .asleep, .biting:
                    break // biting: the `bitten` event speaks
                }
            } else if to < from {
                audio.play(FeelSoundBook.sigh())
            }
        case .dreamTwitch:
            break // the Dreamer's fake twitch is lid art only: sound and haptics stay truthful
        case .bitten:
            nextBeat = -Double.infinity
            playHaptic(FeelHapticBook.bite)
            audio.play(FeelSoundBook.chomp(dice: &dice))
        case .banked(let value, _, let hushed):
            let cascade = FeelSoundBook.cascadeTimes(count: FeelSoundBook.cascadeCount(value: value))
            playHaptic(FeelHapticBook.bank(cascade: cascade))
            audio.play(FeelSoundBook.bank(value: value, hushed: hushed, dice: &dice))
        case .relicFound:
            // Fires with `banked` (one per relic): one choir, after the ka-ching.
            guard !choirPlayed else { return }
            choirPlayed = true
            audio.play(FeelSoundBook.relicChoir(delay: banking ? FeelSoundBook.kaChingAt + 0.15 : 0))
        case .torchLow:
            audio.play(FeelSoundBook.torchLow())
            playHaptic(FeelHapticBook.torchLow)
        case .torchOut:
            nextBeat = -Double.infinity
            audio.play(FeelSoundBook.torchOut())
            playHaptic(FeelHapticBook.torchOut)
        case .newBest:
            audio.play(FeelSoundBook.newBest(delay: banking ? FeelSoundBook.kaChingAt + 0.4 : 0))
            playHaptic(FeelHapticBook.newBest)
        case .finished:
            break // the results card may call `celebrate()`
        }
    }

    // MARK: - Helpers

    private func ensureStarted() {
        if !started { start() }
    }

    private func playHaptic(_ cue: FeelHapticCue) {
        haptics.play(FeelHapticBook.adapt(cue, to: profile))
    }

    private func applyProfile(_ newProfile: FeelHapticProfile) {
        profile = newProfile
        if newProfile != .off {
            lastOnProfile = newProfile
            haptics.profile = newProfile
        }
        haptics.enabled = newProfile != .off
    }

    private func heal(now: CFTimeInterval) {
        guard now - lastHeal > 1 else { return }
        lastHeal = now
        if !audioIdle { audio.heal() }
        if !hapticIdle { haptics.heal() }
    }

    /// Menus (`idle`) or a long quiet idle the engines; the Home creak keeps the haptic players up while it lasts.
    private func refreshIdle(now: CFTimeInterval) {
        let quiet = now - lastActive > Self.idleDelay
        let wantAudioIdle = idle || quiet
        let homeCreaking = now - lastHomeCreak < 1.0
        let wantHapticIdle = wantAudioIdle && !homeCreaking
        if wantAudioIdle != audioIdle {
            audioIdle = wantAudioIdle
            audio.idle = wantAudioIdle
        }
        if wantHapticIdle != hapticIdle {
            hapticIdle = wantHapticIdle
            if wantHapticIdle { haptics.quiet(now: now) }
            haptics.idle = wantHapticIdle
        }
    }

    /// After `silence()` no frames may come (a pause card, the menus): idle once the delay has passed.
    private func scheduleIdleCheck() {
        let delay = Self.idleDelay + 0.05
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self?.refreshIdle(now: CACurrentMediaTime())
        }
    }

    /// Frames stopped without a `silence()`: fade the continuous layers so nothing is left creaking or snoring.
    private func scheduleWatchdog() {
        guard !watchdogPending else { return }
        watchdogPending = true
        let delay = Self.staleAfter
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self?.watchdog()
        }
    }

    private func watchdog() {
        watchdogPending = false
        guard continuousLive else { return }
        let now = CACurrentMediaTime()
        if now - lastFrame >= Self.staleAfter {
            continuousLive = false
            wasPlaying = false
            nextBeat = -Double.infinity
            audio.setBed(FeelSoundBook.idleBed(master: master, glide: FeelSoundBook.fadeGlide))
            haptics.quiet(now: now)
            refreshIdle(now: now)
        } else {
            scheduleWatchdog()
        }
    }
}

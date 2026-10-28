import Combine
import Foundation

/// The player's settings (kept apart from progress). Versioned JSON, decoded tolerantly.
struct SettingsData: Codable, Equatable {
    static let currentVersion = 1

    var version = SettingsData.currentVersion
    var soundOn = true
    /// Haptics on or off. R7: kept for old saves, and derived from `vibration` once that is chosen
    /// (`vibration != .off`).
    var hapticsOn = true
    /// Off by default (GAME-DESIGN §10: sound plays on silent, `.playback`).
    var respectSilentSwitch = false
    /// "Turn the chest round" (GAME-DESIGN §3, the blurred-half rule): on by default; only matters on a Duo.
    var turnRound = true
    /// The app's own Reduce motion (the system setting is honoured as well).
    var reduceMotion = false
    /// R7 (ROUND-7 App 4, DEVICE-RISKS-1 D3): Settings › Lid sensitivity. Runs and practice play at it; the scored
    /// Daily always plays `.normal` (Core's `SessionOptions.for(_:sensitivity:)`).
    var lidSensitivity: LidSensitivity = .normal
    /// R7 (ROUND-7 App 4): Settings › Vibration. Nil until the player chooses, so an unchosen setting keeps following
    /// the device (Strong on a Duo, `FeedbackDirector.deviceHasFold`) instead of pinning a launch-time default.
    var vibration: HapticStrength? = nil

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = SettingsData.currentVersion
        soundOn = (try? c.decodeIfPresent(Bool.self, forKey: .soundOn)) ?? true
        hapticsOn = (try? c.decodeIfPresent(Bool.self, forKey: .hapticsOn)) ?? true
        respectSilentSwitch = (try? c.decodeIfPresent(Bool.self, forKey: .respectSilentSwitch)) ?? false
        turnRound = (try? c.decodeIfPresent(Bool.self, forKey: .turnRound)) ?? true
        reduceMotion = (try? c.decodeIfPresent(Bool.self, forKey: .reduceMotion)) ?? false
        // R7: an unknown or mistyped value falls back to the default (it never fails the whole decode).
        lidSensitivity = (try? c.decodeIfPresent(LidSensitivity.self, forKey: .lidSensitivity)) ?? .normal
        let chosen: HapticStrength? = try? c.decodeIfPresent(HapticStrength.self, forKey: .vibration)
        vibration = chosen
        if let v = chosen { hapticsOn = v != .off }
    }
}

/// Player settings for SwiftUI. Sound, haptics and the silent switch are pushed to `FeedbackDirector.shared` on every
/// change (and once at launch, `apply()`). `defaults` nil = in-memory (demo runs): nothing is written.
@MainActor
final class SettingsStore: ObservableObject {
    static let key = "hush.settings"

    @Published var soundOn: Bool { didSet { changed() } }
    @Published var hapticsOn: Bool { didSet { changed() } }
    @Published var respectSilentSwitch: Bool { didSet { changed() } }
    @Published var turnRound: Bool { didSet { save() } }
    @Published var reduceMotion: Bool { didSet { save() } }
    /// R7: Settings › Lid sensitivity (read at each run's start).
    @Published var lidSensitivity: LidSensitivity { didSet { save() } }
    /// R7: Settings › Vibration; nil = not chosen (it follows the device). Set it with `chooseVibration(_:)`.
    @Published private(set) var vibration: HapticStrength? { didSet { changed() } }

    /// Demo `sound=0`: muted for this launch, never saved.
    var muted = false {
        didSet { apply() }
    }

    private let defaults: UserDefaults?
    /// The vibration last pushed to Feedback (pushed once per change: setting it marks the profile as chosen).
    private var pushedVibration: HapticStrength?

    init(defaults: UserDefaults?) {
        self.defaults = defaults
        var stored = SettingsData()
        if let raw = defaults?.data(forKey: Self.key), let decoded = Self.decode(raw) {
            stored = decoded
        }
        soundOn = stored.soundOn
        hapticsOn = stored.hapticsOn
        respectSilentSwitch = stored.respectSilentSwitch
        turnRound = stored.turnRound
        reduceMotion = stored.reduceMotion
        lidSensitivity = stored.lidSensitivity
        vibration = stored.vibration
    }

    var snapshot: SettingsData {
        var d = SettingsData()
        d.soundOn = soundOn
        d.hapticsOn = hapticsOn
        d.respectSilentSwitch = respectSilentSwitch
        d.turnRound = turnRound
        d.reduceMotion = reduceMotion
        d.lidSensitivity = lidSensitivity
        d.vibration = vibration
        return d
    }

    nonisolated static func encode(_ data: SettingsData) -> Data? { try? JSONEncoder().encode(data) }
    nonisolated static func decode(_ raw: Data) -> SettingsData? { try? JSONDecoder().decode(SettingsData.self, from: raw) }

    /// R7: the Vibration row's choice. It is the player's from now on (stored), and `hapticsOn` follows it.
    func chooseVibration(_ strength: HapticStrength) {
        vibration = strength
        let on = strength != .off
        if hapticsOn != on { hapticsOn = on }
    }

    /// R7: what the Vibration row shows: the choice, or (unchosen) what the device plays: Off with haptics off, else
    /// Strong on a Duo and Normal elsewhere (`HapticStrength.defaultFor(hasFold:)`). Pure; tested.
    nonisolated static func shownVibration(chosen: HapticStrength?, hapticsOn: Bool, hasFold: Bool) -> HapticStrength {
        if let chosen { return chosen }
        return hapticsOn ? HapticStrength.defaultFor(hasFold: hasFold) : .off
    }

    /// Pushes the sound and haptic settings to the feedback engines (launch, and after every change).
    /// R7: a chosen Vibration is pushed as `hapticStrength` (once per change, so the profile counts as chosen and a
    /// later `deviceHasFold` can't move it); unchosen, only `hapticsOn` is pushed and the strength follows the device.
    func apply() {
        let feedback = FeedbackDirector.shared
        let sound = soundOn && !muted
        if feedback.soundOn != sound { feedback.soundOn = sound }
        if let v = vibration {
            if pushedVibration != v || feedback.hapticStrength != v {
                pushedVibration = v
                feedback.hapticStrength = v
            }
        } else if feedback.hapticsOn != hapticsOn {
            feedback.hapticsOn = hapticsOn
        }
        if feedback.respectSilentSwitch != respectSilentSwitch { feedback.respectSilentSwitch = respectSilentSwitch }
    }

    private func changed() {
        apply()
        save()
    }

    private func save() {
        guard let defaults, let raw = Self.encode(snapshot) else { return }
        defaults.set(raw, forKey: Self.key)
    }
}

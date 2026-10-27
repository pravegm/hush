import Combine
import Foundation

/// The player's settings (kept apart from progress). Versioned JSON, decoded tolerantly.
struct SettingsData: Codable, Equatable {
    static let currentVersion = 1

    var version = SettingsData.currentVersion
    var soundOn = true
    var hapticsOn = true
    /// Off by default (GAME-DESIGN §10: sound plays on silent, `.playback`).
    var respectSilentSwitch = false
    /// "Turn the chest round" (GAME-DESIGN §3, the blurred-half rule): on by default; only matters on a Duo.
    var turnRound = true
    /// The app's own Reduce motion (the system setting is honoured as well).
    var reduceMotion = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = SettingsData.currentVersion
        soundOn = (try? c.decodeIfPresent(Bool.self, forKey: .soundOn)) ?? true
        hapticsOn = (try? c.decodeIfPresent(Bool.self, forKey: .hapticsOn)) ?? true
        respectSilentSwitch = (try? c.decodeIfPresent(Bool.self, forKey: .respectSilentSwitch)) ?? false
        turnRound = (try? c.decodeIfPresent(Bool.self, forKey: .turnRound)) ?? true
        reduceMotion = (try? c.decodeIfPresent(Bool.self, forKey: .reduceMotion)) ?? false
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

    /// Demo `sound=0`: muted for this launch, never saved.
    var muted = false {
        didSet { apply() }
    }

    private let defaults: UserDefaults?

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
    }

    var snapshot: SettingsData {
        var d = SettingsData()
        d.soundOn = soundOn
        d.hapticsOn = hapticsOn
        d.respectSilentSwitch = respectSilentSwitch
        d.turnRound = turnRound
        d.reduceMotion = reduceMotion
        return d
    }

    nonisolated static func encode(_ data: SettingsData) -> Data? { try? JSONEncoder().encode(data) }
    nonisolated static func decode(_ raw: Data) -> SettingsData? { try? JSONDecoder().decode(SettingsData.self, from: raw) }

    /// Pushes the sound and haptic settings to the feedback engines (launch, and after every change).
    func apply() {
        let feedback = FeedbackDirector.shared
        let sound = soundOn && !muted
        if feedback.soundOn != sound { feedback.soundOn = sound }
        if feedback.hapticsOn != hapticsOn { feedback.hapticsOn = hapticsOn }
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

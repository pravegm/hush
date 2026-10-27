import Combine
import Foundation

/// R6 (ROUND-6 App 8): one line of the Diagnostics event log.
struct EventLogEntry: Codable, Equatable {
    /// Wall clock, seconds since 1970.
    var time: Double
    var event: String
    /// The hinge angle then (nil: no reading).
    var angle: Double?
}

/// The last `capacity` events, oldest first. Pure; tested.
struct EventRing: Codable, Equatable {
    static let capacity = 80

    private(set) var entries: [EventLogEntry] = []

    init() {}

    init(entries: [EventLogEntry]) {
        self.entries = Array(entries.suffix(Self.capacity))
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let decoded = (try? c.decodeIfPresent([EventLogEntry].self, forKey: .entries)) ?? []
        entries = Array(decoded.suffix(Self.capacity))
    }

    mutating func append(_ entry: EventLogEntry) {
        entries.append(entry)
        if entries.count > Self.capacity { entries.removeFirst(entries.count - Self.capacity) }
    }

    var newestFirst: [EventLogEntry] { Array(entries.reversed()) }

    /// "27 Oct 21:14:05.3  pause closing  112.4°". Pure; tested.
    static func line(_ e: EventLogEntry, timeZone: TimeZone = .current) -> String {
        let date = Date(timeIntervalSince1970: e.time.isFinite ? e.time : 0)
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "d MMM HH:mm:ss.S"
        let a = e.angle.map { $0.isFinite ? String(format: "%.1f°", $0) : "-" } ?? "-"
        return "\(f.string(from: date))  \(e.event)  \(a)"
    }

    /// Newest first, one event a line (what the Copy button puts on the pasteboard).
    func text(timeZone: TimeZone = .current) -> String {
        newestFirst.map { Self.line($0, timeZone: timeZone) }.joined(separator: "\n")
    }
}

/// The Diagnostics event log: pose changes and why, pauses, resumes and the watchdog, canvas changes (size, fold,
/// k), interface and device orientation changes, hinge nil, scene phase. Kept across launches in UserDefaults
/// (`hush.diag.events`), on this device only: nothing is sent anywhere. `defaults` nil = in memory (demo runs, tests).
@MainActor
final class EventLog: ObservableObject {
    static let key = "hush.diag.events"

    @Published private(set) var ring: EventRing
    private let defaults: UserDefaults?

    init(defaults: UserDefaults?) {
        self.defaults = defaults
        if let raw = defaults?.data(forKey: Self.key), let decoded = try? JSONDecoder().decode(EventRing.self, from: raw) {
            ring = decoded
        } else {
            ring = EventRing()
        }
    }

    func add(_ event: String, angle: Double?, now: Date = Date()) {
        var r = ring
        r.append(EventLogEntry(time: now.timeIntervalSince1970, event: event, angle: angle))
        ring = r
        guard let defaults, let raw = try? JSONEncoder().encode(r) else { return }
        defaults.set(raw, forKey: Self.key)
    }

    /// Newest first.
    var lines: [String] { ring.newestFirst.map { EventRing.line($0) } }

    /// The whole log for the pasteboard, with a header line.
    var text: String { "Hush event log (newest first)\n" + ring.text() }
}

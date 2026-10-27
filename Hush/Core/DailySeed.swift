import Foundation

// MARK: - The Daily Dungeon's seed (GAME-DESIGN §7): the same dungeon for everyone on a calendar day

enum DailySeed {

    /// Days since 2026-01-01 (day 0) in `calendar` (the player's local calendar by default). Negative before then.
    static func dayNumber(for date: Date, calendar: Calendar = .current) -> Int {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 1
        comps.day = 1
        comps.hour = 12
        guard let epoch = calendar.date(from: comps) else { return 0 }
        let a: Date = calendar.startOfDay(for: epoch)
        let b: Date = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    /// The run seed for a day number (deterministic, well mixed: neighbouring days are unrelated).
    static func seed(day: Int) -> UInt64 {
        var rng = SeededRandom(seed: 0x4855_5348_DA11_0000 ^ UInt64(bitPattern: Int64(day)))
        return rng.next()
    }
}

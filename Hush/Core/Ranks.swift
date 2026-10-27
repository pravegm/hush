import Foundation

// MARK: - Thief rank (GAME-DESIGN §7): 12 ranks by lifetime gold banked

enum ThiefRanks {

    /// Lifetime gold needed for each rank. A casual run banks about 2,500 (expert about 4,500), so the last rank
    /// takes roughly 60 casual runs.
    static let thresholds: [Int] = [0, 500, 1_500, 3_500, 7_000, 12_000, 20_000, 32_000, 50_000, 75_000, 110_000,
                                    160_000]

    static let titles: [String] = ["Pickpocket", "Cutpurse", "Sneak", "Lockpick", "Cat Burglar", "Shadow",
                                   "Vault Diver", "Gem Fancier", "Night Raider", "Master Thief", "Dungeon Legend",
                                   "Mimic Whisperer"]

    static let count: Int = 12

    /// 0…11.
    static func rank(forLifetimeGold gold: Int) -> Int {
        var r: Int = 0
        var i: Int = 0
        while i < count {
            if gold >= thresholds[i] { r = i }
            i += 1
        }
        return r
    }

    /// "Pickpocket" … "Mimic Whisperer" (clamped).
    static func title(_ rank: Int) -> String {
        return titles[min(max(rank, 0), count - 1)]
    }

    /// Lifetime gold needed for `rank` (clamped).
    static func threshold(_ rank: Int) -> Int {
        return thresholds[min(max(rank, 0), count - 1)]
    }
}

// MARK: - Achievements (GAME-DESIGN §7). Ids are Game Center ids too: "hush.ach.<key>"

struct AchievementDef: Hashable {
    let id: String
    let title: String
    let detail: String
}

enum Achievements {

    private static func def(_ key: String, _ title: String, _ detail: String) -> AchievementDef {
        return AchievementDef(id: "hush.ach." + key, title: title, detail: detail)
    }

    static let firstHaul = def("firsthaul", "First Haul", "Bank your first chest.")
    static let notAPeep = def("notapeep", "Not a Peep", "Bank a chest without the mimic ever stirring.")
    static let firstRelic = def("firstrelic", "Relic Hunter", "Bank your first relic.")
    static let fiveChests = def("fivechests", "Light Fingers", "Bank 5 chests in one run.")
    static let royal = def("royal", "Royal Treatment", "Reach a Royal chest.")
    static let heavyBag = def("heavybag", "Heavy Bag", "Bank 2,000 gold in one run.")
    static let hoard = def("hoard", "Dragon's Hoard", "Bank 5,000 gold in one run.")
    static let untouchable = def("untouchable", "Untouchable", "Bank 3 chests in a run without a single bite.")
    static let hushHush = def("hushhush", "Hush Hush", "Bank 3 chests in one run without the mimic stirring.")
    static let curator = def("curator", "Curator", "Find 12 relics for the Codex.")
    static let fullCodex = def("fullcodex", "Keeper of Curiosities", "Find all 24 relics.")
    static let fortune = def("fortune", "A Small Fortune", "Bank 25,000 gold in total.")

    /// Exactly 12.
    static let all: [AchievementDef] = [firstHaul, notAPeep, firstRelic, fiveChests, royal, heavyBag, hoard,
                                        untouchable, hushHush, curator, fullCodex, fortune]

    /// Newly earned after `run` (given lifetime totals including the run and what's already earned).
    /// Attract and lesson runs earn nothing.
    static func earned(after run: RunResult, lifetimeGold: Int, relicsFound: Int,
                       alreadyEarned: Set<String>) -> [AchievementDef] {
        switch run.mode {
        case .attract, .lesson: return []
        case .run, .daily: break
        }
        var out: [AchievementDef] = []
        func check(_ a: AchievementDef, _ met: Bool) {
            if met && !alreadyEarned.contains(a.id) { out.append(a) }
        }
        check(firstHaul, run.chestsBanked >= 1)
        check(notAPeep, run.hushed >= 1)
        check(firstRelic, relicsFound >= 1 || !run.relics.isEmpty)
        check(fiveChests, run.chestsBanked >= 5)
        check(royal, run.highestTier == .royal)
        check(heavyBag, run.gold >= 2_000)
        check(hoard, run.gold >= 5_000)
        check(untouchable, run.bites == 0 && run.chestsBanked >= 3)
        check(hushHush, run.hushed >= 3)
        check(curator, relicsFound >= 12)
        check(fullCodex, relicsFound >= RelicCatalog.all.count)
        check(fortune, lifetimeGold >= 25_000)
        return out
    }
}

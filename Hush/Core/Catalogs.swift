import Foundation

// MARK: - The Relic Codex (24 relics: the 12 RelicShapes twice, with different tints)

enum RelicCatalog {

    private static func make(_ n: Int, _ name: String, _ blurb: String, _ shape: RelicShape, _ hex: UInt32) -> Relic {
        let raw: String = n < 10 ? "relic0\(n)" : "relic\(n)"
        return Relic(id: RelicID(raw), name: name, blurb: blurb, shape: shape, tint: RGBA(hex: hex))
    }

    /// Exactly 24, ids relic01…relic24, in Codex order.
    static let all: [Relic] = [
        make(1, "The Moth-Eaten Crown", "Still fits. Mostly.", .crown, 0xE8B84A),
        make(2, "The Bottomless Goblet", "Pour in water, pour out regret.", .goblet, 0xC9A0DC),
        make(3, "The Ever-Warm Teacup", "Nobody remembers making the tea.", .teacup, 0xF2C1A0),
        make(4, "The Key to Nothing", "Opens no lock. Still, it hums.", .key, 0xD9A441),
        make(5, "The Ring of Mild Invisibility", "You're a little harder to notice.", .ring, 0x9FD8E8),
        make(6, "The Snore-Stone Amulet", "Hums along with sleeping mimics.", .amulet, 0x6FC7A1),
        make(7, "Sir Rattlesworth's Skull", "The previous owner. Very polite.", .skull, 0xEDE3C8),
        make(8, "The Dragon's Spare Egg", "Do not keep it warm.", .egg, 0xD8573E),
        make(9, "The Shy Mirror", "Shows everyone but you.", .mirror, 0xB8C7D9),
        make(10, "The Hushing Horn", "Blow it and the room goes quiet. Even you.", .horn, 0xC98B4F),
        make(11, "Lord Wobble's Loaded Dice", "Always rolls a seven. On one die.", .dice, 0xF4F1E6),
        make(12, "The Homesick Compass", "Always points to its old chest.", .compass, 0xB5874B),
        make(13, "The Tin Crown of King Nobody", "Ruled a kingdom of one sock.", .crown, 0xA9B4BE),
        make(14, "The Goblet of Lukewarm Fire", "Cosy. Mildly singed.", .goblet, 0xF08A3C),
        make(15, "The Chipped Cup of Courage", "Tastes like doing it anyway.", .teacup, 0x7FB3E0),
        make(16, "The Skeleton Key", "Literally. It has a tiny skull.", .key, 0xE6E0D0),
        make(17, "The Mimic's Wedding Ring", "It would like it back.", .ring, 0xF5D06B),
        make(18, "The Amulet of Slightly Better Luck", "Two per cent luckier. Allegedly.", .amulet, 0x5FA8E0),
        make(19, "The Laughing Skull", "Gets every joke a minute late.", .skull, 0xD4E07A),
        make(20, "The Golden Goose Egg", "The goose is still looking for it.", .egg, 0xF2C94C),
        make(21, "The Mirror of Tomorrow's Hair", "It's going to be a bad day.", .mirror, 0xE59AC4),
        make(22, "The Horn of Polite Thunder", "A rumble, then an apology.", .horn, 0x8C9EDB),
        make(23, "The Dice of Second Chances", "Roll again. Nobody saw.", .dice, 0xE5534B),
        make(24, "The Compass of True North-ish", "Close enough, usually.", .compass, 0x4FC3B0),
    ]

    /// All 24 ids in order.
    static var ids: [RelicID] { all.map { (r: Relic) -> RelicID in r.id } }

    /// The relic for an id. An unknown id gives a placeholder with that id (never crashes on stale saves).
    static func relic(_ id: RelicID) -> Relic {
        if let r = all.first(where: { (x: Relic) -> Bool in x.id == id }) { return r }
        return Relic(id: id, name: "An Unknown Relic", blurb: "Even the mimic isn't sure.", shape: .egg,
                     tint: RGBA(hex: 0xB0A890))
    }
}

// MARK: - Mimic name tags ("Snoring Sam"), about 10 per personality

enum MimicNames {

    static func names(for kind: MimicKind) -> [String] {
        switch kind {
        case .snorer:
            return ["Snoring Sam", "Rumbling Rita", "Wheezy Walt", "Honking Hal", "Drowsy Dot", "Puffing Percy",
                    "Nasal Nell", "Gurgling Gus", "Buzzsaw Bea", "Old Thunder Ted"]
        case .lightSleeper:
            return ["Twitchy Tess", "Jumpy Jack", "Fidgety Finn", "Edgy Edna", "Skittish Sid", "Prickly Pru",
                    "Wary Wendell", "Nervy Nora", "Startled Stan", "Itchy Ivy"]
        case .heavySleeper:
            return ["Heavy Hugo", "Dozy Doris", "Slumbering Sue", "Comatose Clive", "Lazy Lou", "Snoozy Suzie",
                    "Boulder Bert", "Deep Dora", "Mossy Moe", "Hibernating Hank"]
        case .dreamer:
            return ["Dreamy Daisy", "Mumbling Milo", "Wandering Wren", "Starry Stella", "Moony Max",
                    "Whimsical Winnie", "Drifting Dex", "Cloudy Clara", "Muttering Mabel", "Sleepwalking Sully"]
        }
    }

    /// A name for this personality, picked by `seed` (deterministic).
    static func name(for kind: MimicKind, seed: UInt64) -> String {
        let list: [String] = names(for: kind)
        if list.isEmpty { return "The Mimic" }
        return list[Int(seed % UInt64(list.count))]
    }
}

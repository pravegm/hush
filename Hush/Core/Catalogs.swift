import Foundation

// MARK: - The Relic Codex (R2: 24 relics, one per RelicShape, each named for its shape; no two share a tint)

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
        make(13, "The Candlestick That Never Drips", "It burns all night. The wax stays put.", .candlestick, 0xD6B370),
        make(14, "The Hourglass of Five More Minutes", "The sand stops whenever you get comfy.", .hourglass, 0xE3C58E),
        make(15, "The Bell That Will Not Ring", "Muffled on purpose. Thieves adore it.", .bell, 0xA9B4BE),
        make(16, "The Lantern of Polite Light", "Lights your way. Dims for sleepers.", .lantern, 0xF08A3C),
        make(17, "The Pocket Watch of Borrowed Time", "Runs a little slow. On purpose.", .pocketWatch, 0xC0C8D0),
        make(18, "The Spyglass of Next Door", "Sees one room over. Never further.", .spyglass, 0x8A6E4B),
        make(19, "The Scroll of Every Mimic", "Lists them all by name. Still going.", .scroll, 0xEADBB6),
        make(20, "The Potion of Quiet Feet", "Smells of socks. Works anyway.", .potion, 0x7B5CD6),
        make(21, "The Shell That Snores Back", "Hold it to your ear. It snores.", .shell, 0xF0B8C8),
        make(22, "The Feather of Tiptoes", "Tickles a lid open, ever so softly.", .feather, 0x5FA8E0),
        make(23, "The Lullaby Music Box", "One tune, and every mimic yawns.", .musicBox, 0xE5534B),
        make(24, "The Idol of the Sleepy God", "Its eyes close when you look away.", .idol, 0x4FC3B0),
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

    /// R2: golden mimics have gold names whatever their personality ("Midas Mo").
    static let goldenNames: [String] = ["Midas Mo", "Gilded Gwen", "Bullion Bob", "Goldie Locke", "Sovereign Sal",
                                        "Glittering Gil", "Nugget Nan", "Ducat Dan", "Auric Aggie", "Treasure Trev"]

    /// A name for this personality (or a gold name when `golden`), picked by `seed` (deterministic).
    static func name(for kind: MimicKind, seed: UInt64, golden: Bool = false) -> String {
        let list: [String] = golden ? goldenNames : names(for: kind)
        if list.isEmpty { return "The Mimic" }
        return list[Int(seed % UInt64(list.count))]
    }
}

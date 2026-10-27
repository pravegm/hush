import CoreGraphics
import Foundation

// MARK: - Contracts between the modules (owned by the founder; change only in a founder round)
//
// Core     (Hush/Core)      pure Swift game rules: no SpriteKit, no UIKit, no SwiftUI. Deterministic. Unit-tested.
// Input    (Hush/Input)     hinge / lid slider → LidInput (openness 0…1 + lid speed in °/s).
// Scene    (Hush/Scene)     SpriteKit rendering of a HeistSnapshot + cosmetic FX from HeistEvents; forwards touches.
// Feedback (Hush/Feedback)  live audio synth + Core Haptics from HeistEvents + HeistTelemetry.
// App/UI   (Hush/App, Hush/UI, Hush/Persistence) SwiftUI shell, the loop glue, menus, persistence, Game Center.
//
// CANVAS (Scene/UI): portrait, 670 × 952 pt, SpriteKit origin bottom-left. On an iPhone Duo in tabletop pose the fold
// runs left to right at mid-height (band y 456…496). The LID is the upper half (y ≥ 496), the FLOOR the lower half
// (y ≤ 456). Every geometry value below is in these CANVAS coordinates.
// R2: the SCENE may be taller than the canvas (`ScreenLayout.size`, phones are narrower than the Duo): the scene puts
// the 670 × 952 canvas in a world node at y = `contentOffsetY` and draws EXTENSION art above the lid and below the floor
// so there are no bars. On the Duo the extension is ~0.
// FLOOR SPACE (Core): points on the floor half. x 0…670 left → right; y 0 at the HINGE edge … 456 at the FRONT edge
// (nearest the player). The bag is the strip y ≥ FloorSpace.bagMinY. Canvas ↔ floor: canvas.y = 456 − floor.y.
// "Turned round" (the blurred-half rule, GAME-DESIGN §3), R2: applied INSIDE the scene (`ChestScene.turned` rotates the
// world node 180° about the scene centre; touches are read with `touch.location(in: world)`, so they are correct by
// construction) and by the App to its SwiftUI overlays. Core never knows about it.

// MARK: Geometry

public enum FloorSpace {
    public static let width: CGFloat = 670
    public static let height: CGFloat = 456
    /// The bag: the strip nearest the player.
    public static let bagMinY: CGFloat = 346
    /// Where loot may lie (inside the chest walls, behind the bag).
    public static let interior = CGRect(x: 78, y: 36, width: 514, height: 286)
    public static var bagRect: CGRect { CGRect(x: 0, y: bagMinY, width: width, height: height - bagMinY) }
}

/// The play canvas. Built once per canvas size by the App, handed to the scene and the UI.
public struct ScreenLayout: Equatable, Sendable {
    public static let canvasWidth: CGFloat = 670
    public static let canvasHeight: CGFloat = 952
    public static let foldMinY: CGFloat = 456
    public static let foldMaxY: CGFloat = 496

    /// The SCENE size: 670 wide, at least 952 tall (taller on screens narrower than the Duo's, to fill them).
    public var size: CGSize
    /// Whether this canvas has a real fold (a hinge was seen). Without one the lid half hosts the lid slider.
    public var hasFold: Bool
    /// The canvas rect actually on screen, in canvas coordinates (the whole canvas on every device).
    public var visibleRect: CGRect

    public init(size: CGSize = CGSize(width: canvasWidth, height: canvasHeight), hasFold: Bool,
                visibleRect: CGRect? = nil) {
        self.size = CGSize(width: canvasWidth, height: max(size.height, canvasHeight)); self.hasFold = hasFold
        self.visibleRect = visibleRect ?? CGRect(x: 0, y: 0, width: Self.canvasWidth, height: Self.canvasHeight)
    }

    public static func make(hasFold: Bool) -> ScreenLayout { ScreenLayout(hasFold: hasFold) }

    /// R2: the layout that fills a portrait view of `viewSize` points (aspect-fill by width; extra height becomes
    /// extension art). Landscape sizes are treated as portrait (width ≤ height).
    public static func make(hasFold: Bool, viewSize: CGSize) -> ScreenLayout {
        let w = max(min(viewSize.width, viewSize.height), 1), h = max(max(viewSize.width, viewSize.height), 1)
        let sceneHeight = max(canvasHeight, (canvasWidth * h / w).rounded())
        return ScreenLayout(size: CGSize(width: canvasWidth, height: sceneHeight), hasFold: hasFold)
    }

    /// Where the canvas's y = 0 sits in the scene (the extension below the floor; the same amount is above the lid).
    public var contentOffsetY: CGFloat { ((size.height - Self.canvasHeight) / 2).rounded() }
    /// Extension height above the lid and below the floor (each).
    public var extensionHeight: CGFloat { contentOffsetY }

    public var floorRect: CGRect { CGRect(x: 0, y: 0, width: size.width, height: Self.foldMinY) }
    public var lidRect: CGRect { CGRect(x: 0, y: Self.foldMaxY, width: size.width, height: size.height - Self.foldMaxY) }

    /// Canvas point (SpriteKit, origin bottom-left) → floor space. Points above the floor give y < 0.
    public func floorPoint(fromCanvas p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: Self.foldMinY - p.y) }
    public func canvasPoint(fromFloor p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: Self.foldMinY - p.y) }
    /// 0 at the fold edge of the lid half … 1 at its far (top) edge, for the lid slider.
    public func lidFraction(fromCanvas p: CGPoint) -> Double {
        let r = lidRect
        return Double(min(max((p.y - r.minY) / max(r.height, 1), 0), 1))
    }
}

// MARK: Colours (platform-neutral so Core stays UIKit-free)

public struct RGBA: Codable, Hashable, Sendable {
    public var r: Double, g: Double, b: Double, a: Double
    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) { self.r = r; self.g = g; self.b = b; self.a = a }
    /// 0xRRGGBB
    public init(hex: UInt32, alpha: Double = 1) {
        self.init(Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255, alpha)
    }
    public func mixed(with other: RGBA, _ t: Double) -> RGBA {
        let k = min(max(t, 0), 1)
        return RGBA(r + (other.r - r) * k, g + (other.g - g) * k, b + (other.b - b) * k, a + (other.a - a) * k)
    }
}

// MARK: Chests, mimics, loot

public enum ChestTier: String, Codable, CaseIterable, Sendable {
    case wooden, iron, gilded, royal
}

public enum MimicKind: String, Codable, CaseIterable, Sendable {
    case snorer, lightSleeper, heavySleeper, dreamer
}

public enum GemColor: String, Codable, CaseIterable, Sendable { case ruby, emerald, sapphire, amethyst }

/// Stable ids "relic01" … "relic24" (RelicCatalog in Core holds names, blurbs, colours).
public struct RelicID: RawRepresentable, Codable, Hashable, Sendable, Comparable {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ raw: String) { self.rawValue = raw }
    public static func < (a: RelicID, b: RelicID) -> Bool { a.rawValue < b.rawValue }
}

public struct Relic: Codable, Hashable, Sendable, Identifiable {
    public var id: RelicID
    public var name: String          // "The Moth-Eaten Crown"
    public var blurb: String         // one short line for the Codex
    public var shape: RelicShape     // which code-drawn silhouette the art uses
    public var tint: RGBA
    public init(id: RelicID, name: String, blurb: String, shape: RelicShape, tint: RGBA) {
        self.id = id; self.name = name; self.blurb = blurb; self.shape = shape; self.tint = tint
    }
}

/// R2: 24 distinct silhouettes, one per relic (the juror: "12 shapes in two colours looks cheap").
public enum RelicShape: String, Codable, CaseIterable, Sendable {
    case crown, goblet, teacup, key, ring, amulet, skull, egg, mirror, horn, dice, compass
    case candlestick, hourglass, bell, lantern, pocketWatch, spyglass, scroll, potion, shell, feather, musicBox, idol
}

public enum LootKind: Codable, Hashable, Sendable {
    case copper
    case silver
    case gem(GemColor)
    case relic(RelicID)
    /// Torch oil: adds `Tuning.oilSeconds` to the torch when bagged (immediately, not on banking).
    case oil
}

/// One item as dealt into a chest (immutable).
public struct LootItem: Codable, Hashable, Sendable, Identifiable {
    public var id: Int                // unique within the chest
    public var kind: LootKind
    public var value: Int             // gold, before the chest multiplier (oil: 0)
    /// 0 = lit as soon as the lid cracks … 1 = needs the lid fully open. GAME-DESIGN §4.
    public var depth: Double
    public var position: CGPoint      // floor space, inside FloorSpace.interior
    public var radius: CGFloat        // touch + art radius, pt
    public var rotation: Double       // radians, cosmetic
    public init(id: Int, kind: LootKind, value: Int, depth: Double, position: CGPoint, radius: CGFloat, rotation: Double) {
        self.id = id; self.kind = kind; self.value = value; self.depth = depth; self.position = position
        self.radius = radius; self.rotation = rotation
    }
}

/// A chest as dealt (deterministic from (seed, index, relics already found)).
public struct ChestSpec: Codable, Hashable, Sendable {
    public var index: Int             // 0-based within the run
    public var tier: ChestTier
    public var mimic: MimicKind
    public var mimicName: String      // "Snoring Sam"
    public var multiplier: Double     // 1, 1.5, 2, 3
    public var decay: Double          // noise decay per second while quiet
    public var items: [LootItem]
    /// R2: a rare golden mimic (loot ×2, noise ×1.25; REVIEW-1-feel feature B).
    public var golden: Bool
    public init(index: Int, tier: ChestTier, mimic: MimicKind, mimicName: String, multiplier: Double, decay: Double,
                items: [LootItem], golden: Bool = false) {
        self.index = index; self.tier = tier; self.mimic = mimic; self.mimicName = mimicName
        self.multiplier = multiplier; self.decay = decay; self.items = items; self.golden = golden
    }
}

/// R2: one line of the Results chest-by-chest strip.
public struct ChestOutcome: Codable, Hashable, Sendable {
    public var tier: ChestTier
    public var golden: Bool
    /// Gold banked from this chest (0 if bitten or the candle went out).
    public var value: Int
    public var hushed: Bool
    public var bitten: Bool
    public init(tier: ChestTier, golden: Bool, value: Int, hushed: Bool, bitten: Bool) {
        self.tier = tier; self.golden = golden; self.value = value; self.hushed = hushed; self.bitten = bitten
    }
}

// MARK: Modes

public enum RunMode: Codable, Hashable, Sendable {
    /// The main mode: chests until the torch is out. A fresh seed each run.
    case run
    /// Everyone's dungeon for that day (days since 2026-01-01, `DailySeed.dayNumber(for:)`). `scored` = the counted try.
    case daily(day: Int, scored: Bool)
    /// Title screen / CI frames: the torch never burns down and the mimic never bites.
    case attract
    /// The First Chest lesson (App drives the script): no torch, no bites.
    case lesson
}

// MARK: Live state

public enum MimicStage: Int, Codable, Comparable, Sendable {
    case asleep = 0, stirring, waking, biting
    public static func < (a: MimicStage, b: MimicStage) -> Bool { a.rawValue < b.rawValue }
}

public enum RunPhase: Equatable, Sendable {
    /// A chest has arrived; the lid must be in the shut zone before it can be opened (`shutHold` not used).
    case ready
    /// Lid in play: looting.
    case looting
    /// The haul was banked; `elapsed` s into the 1.4 s bank moment, then the next chest (`.ready`).
    case banked(elapsed: Double)
    /// The mimic bit; `elapsed` s into the 1.8 s bite moment, then the next chest.
    case bitten(elapsed: Double)
    /// The torch went out; `elapsed` s into the 2.0 s ending, then `.finished`.
    case torchOut(elapsed: Double)
    case finished
}

public enum LootPlace: Equatable, Sendable {
    case inChest
    /// Being dragged by touch `touchID`.
    case held(touchID: Int)
    case inBag
    /// Lost to a bite (shown flying back into the mimic's mouth).
    case lost
}

public struct LootState: Equatable, Sendable, Identifiable {
    public var item: LootItem
    public var id: Int { item.id }
    /// Current floor-space position (follows the finger while held; the bag slot once bagged).
    public var position: CGPoint
    public var place: LootPlace
    /// 0 = dark … 1 = fully lit (drives the glint/reveal). Grabbable when `grabbable`.
    public var light: Double
    public var grabbable: Bool
    public init(item: LootItem, position: CGPoint, place: LootPlace, light: Double, grabbable: Bool) {
        self.item = item; self.position = position; self.place = place; self.light = light; self.grabbable = grabbable
    }
}

/// One short instruction the HUD shows (Core decides which applies; UI owns the words).
public enum HeistHint: String, Codable, Sendable {
    case easeLidDown      // ready but the lid is open: "Ease the lid down"
    case openSlowly       // ready+shut, nothing opened yet this chest: "Open the lid… slowly"
    case slower           // lid speed in the loud zone: "Slower…"
    case freeze           // stage ≥ waking: "Freeze!"
    case dragToBag        // something lit is grabbable and the bag is empty
    case shutToBank       // the bag has loot: "Ease it shut to keep it"
    case tooWide          // the input reports tooWide: "That's wide enough"
    case candleLow        // R2: ≤ 15 s of candle and loot in the bag: "Candle's low. Bank it!"
    case relicDeeper      // R2: a relic glimmers but isn't lit yet: "Something glints deeper…"
}

/// Everything the scene, HUD and feedback need for one frame. Value type.
public struct HeistSnapshot: Equatable, Sendable {
    public var phase: RunPhase
    public var mode: RunMode
    public var time: Double                 // s since the session began
    public var chest: ChestSpec?            // the current chest
    public var loot: [LootState]            // the current chest's items
    public var openness: Double             // 0 shut … 1 wide (from the input)
    public var lidSpeed: Double             // °/s, ≥ 0 (from the input)
    public var noise: Double                // 0 … 1 (1 = bite)
    public var stage: MimicStage
    public var torchRemaining: Double       // s
    public var torchTotal: Double           // s (for the gauge: base + oil gained)
    public var bagValue: Int                // gold in hand, multiplier applied
    public var banked: Int                  // the run's gold so far (the score)
    public var bestRun: Int                 // personal best for this mode (0 = none)
    public var chestsBanked: Int
    public var hushed: Int                  // chests banked without the mimic ever leaving `.asleep`
    public var bites: Int
    /// 0…1 progress of holding the lid in the shut zone with loot in the bag (1 = banks).
    public var shutHold: Double
    public var hint: HeistHint?
    /// R2 Hush Chain: consecutive Hushed chests banked (resets on a stir or bite) and the multiplier the NEXT bank gets.
    public var chain: Int
    public var chainMultiplier: Double
    /// R2: the noise can't decay below this while loot is in the bag ("bag jingle", REVIEW-1-feel feature D).
    public var noiseFloor: Double

    public init(phase: RunPhase = .ready, mode: RunMode = .run, time: Double = 0, chest: ChestSpec? = nil,
                loot: [LootState] = [], openness: Double = 0, lidSpeed: Double = 0, noise: Double = 0,
                stage: MimicStage = .asleep, torchRemaining: Double = 0, torchTotal: Double = 0, bagValue: Int = 0,
                banked: Int = 0, bestRun: Int = 0, chestsBanked: Int = 0, hushed: Int = 0, bites: Int = 0,
                shutHold: Double = 0, hint: HeistHint? = nil, chain: Int = 0, chainMultiplier: Double = 1,
                noiseFloor: Double = 0) {
        self.phase = phase; self.mode = mode; self.time = time; self.chest = chest; self.loot = loot
        self.openness = openness; self.lidSpeed = lidSpeed; self.noise = noise; self.stage = stage
        self.torchRemaining = torchRemaining; self.torchTotal = torchTotal; self.bagValue = bagValue
        self.banked = banked; self.bestRun = bestRun; self.chestsBanked = chestsBanked; self.hushed = hushed
        self.bites = bites; self.shutHold = shutHold; self.hint = hint
        self.chain = chain; self.chainMultiplier = chainMultiplier; self.noiseFloor = noiseFloor
    }
}

public enum HeistEvent: Equatable, Sendable {
    case chestArrived(index: Int, tier: ChestTier, mimic: MimicKind, name: String)
    case lidCracked                          // openness first passed 0.05 in this chest
    case itemRevealed(id: Int, kind: LootKind)    // light first reached the glint level
    case itemPicked(id: Int, kind: LootKind)
    case itemDropped(id: Int)                // let go outside the bag: back into the chest (a clunk)
    case itemBagged(id: Int, kind: LootKind, value: Int)   // value with the multiplier
    case oilAdded(seconds: Double)
    case stageChanged(from: MimicStage, to: MimicStage)
    case dreamTwitch                         // a Dreamer's harmless fake twitch (lid art only)
    case bitten(lostValue: Int)
    case banked(value: Int, items: Int, hushed: Bool)
    case relicFound(RelicID)                 // fires with `banked` for each relic in the haul
    case torchLow                            // 15 s left (once per run)
    case torchOut
    case newBest                             // passed the personal best during the run (once)
    case finished
    // R2
    case chainUp(count: Int, multiplier: Double)   // a Hushed bank extended the Hush Chain (fires after `banked`)
    case chainBroken(count: Int)             // a chain of ≥ 2 was broken by a stir or a bite
    case biteCost(lostValue: Int, seconds: Double) // with `bitten`: what it cost (for the "−164 · −10s" callout)
}

/// What a finished run produced. Persisted and fed to ranks / achievements / Game Center.
public struct RunResult: Codable, Equatable, Sendable {
    public var mode: RunMode
    public var seed: UInt64
    public var gold: Int
    public var seconds: Double
    public var chestsOpened: Int
    public var chestsBanked: Int
    public var hushed: Int
    public var bites: Int
    public var relics: [RelicID]             // relics banked this run (in order)
    public var bestChestValue: Int
    public var itemsBagged: Int
    /// The highest tier reached (the chest the torch went out on counts).
    public var highestTier: ChestTier
    public var lostToBites: Int              // gold lost in bites
    // R2
    public var bestChain: Int                // longest Hush Chain
    public var goldenBanked: Int             // golden mimics banked
    public var chestLog: [ChestOutcome]      // one per chest opened, in order (the Results strip)
    public init(mode: RunMode, seed: UInt64, gold: Int, seconds: Double, chestsOpened: Int, chestsBanked: Int,
                hushed: Int, bites: Int, relics: [RelicID], bestChestValue: Int, itemsBagged: Int,
                highestTier: ChestTier, lostToBites: Int, bestChain: Int = 0, goldenBanked: Int = 0,
                chestLog: [ChestOutcome] = []) {
        self.mode = mode; self.seed = seed; self.gold = gold; self.seconds = seconds; self.chestsOpened = chestsOpened
        self.chestsBanked = chestsBanked; self.hushed = hushed; self.bites = bites; self.relics = relics
        self.bestChestValue = bestChestValue; self.itemsBagged = itemsBagged; self.highestTier = highestTier
        self.lostToBites = lostToBites; self.bestChain = bestChain; self.goldenBanked = goldenBanked
        self.chestLog = chestLog
    }

    private enum CodingKeys: String, CodingKey {
        case mode, seed, gold, seconds, chestsOpened, chestsBanked, hushed, bites, relics, bestChestValue, itemsBagged
        case highestTier, lostToBites, bestChain, goldenBanked, chestLog
    }

    /// Tolerant: R1 saves have no R2 keys.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mode = try c.decode(RunMode.self, forKey: .mode)
        seed = try c.decode(UInt64.self, forKey: .seed)
        gold = try c.decode(Int.self, forKey: .gold)
        seconds = try c.decode(Double.self, forKey: .seconds)
        chestsOpened = try c.decode(Int.self, forKey: .chestsOpened)
        chestsBanked = try c.decode(Int.self, forKey: .chestsBanked)
        hushed = try c.decode(Int.self, forKey: .hushed)
        bites = try c.decode(Int.self, forKey: .bites)
        relics = try c.decode([RelicID].self, forKey: .relics)
        bestChestValue = try c.decode(Int.self, forKey: .bestChestValue)
        itemsBagged = try c.decode(Int.self, forKey: .itemsBagged)
        highestTier = try c.decode(ChestTier.self, forKey: .highestTier)
        lostToBites = try c.decode(Int.self, forKey: .lostToBites)
        bestChain = try c.decodeIfPresent(Int.self, forKey: .bestChain) ?? 0
        goldenBanked = try c.decodeIfPresent(Int.self, forKey: .goldenBanked) ?? 0
        chestLog = try c.decodeIfPresent([ChestOutcome].self, forKey: .chestLog) ?? []
    }
}

// MARK: Input

/// The lid as the game sees it, once per frame.
public struct LidInput: Equatable, Sendable {
    public var openness: Double              // 0 shut … 1 wide (GAME-DESIGN §3: θ 100° … 165°)
    public var speed: Double                 // °/s, ≥ 0, filtered (the slider reports °/s-equivalent)
    public var inShutZone: Bool              // θ ≤ 110° (slider: openness ≤ 0.15)
    public var tooWide: Bool                 // θ > 172°
    public init(openness: Double = 0, speed: Double = 0, inShutZone: Bool = true, tooWide: Bool = false) {
        self.openness = openness; self.speed = speed; self.inShutZone = inShutZone; self.tooWide = tooWide
    }
}

// MARK: Feedback telemetry (continuous, every frame)

public struct HeistTelemetry: Equatable, Sendable {
    public var lidSpeed: Double              // °/s
    public var openness: Double
    public var noise: Double
    public var stage: MimicStage
    public var dragSpeed: Double             // pt/s of the fastest held item, 0 = none held
    public var torchRemaining: Double
    public var playing: Bool                 // false in menus, pauses and the result moments
    public init(lidSpeed: Double = 0, openness: Double = 0, noise: Double = 0, stage: MimicStage = .asleep,
                dragSpeed: Double = 0, torchRemaining: Double = 0, playing: Bool = false) {
        self.lidSpeed = lidSpeed; self.openness = openness; self.noise = noise; self.stage = stage
        self.dragSpeed = dragSpeed; self.torchRemaining = torchRemaining; self.playing = playing
    }
}

// MARK: Cross-module protocols

/// Where the lid comes from (hinge, slider). Called once per frame on the main actor.
@MainActor public protocol LidSource: AnyObject {
    func lid(at time: TimeInterval) -> LidInput
}

/// The scene asks the App's controller to advance the game once per frame and forwards touches to it.
/// Touch ids are stable per finger (the scene uses `ObjectIdentifier(touch).hashValue`). Times are `UITouch.timestamp`
/// (same clock as `CACurrentMediaTime()`).
@MainActor public protocol SceneDriver: AnyObject {
    /// Advance by `dt` (clamped by the driver) and return the frame to draw plus this frame's events.
    func advance(dt: TimeInterval, now: TimeInterval) -> (HeistSnapshot, [HeistEvent])
    /// A finger on the FLOOR half (floor space; y may be < 0 if it slid onto the lid).
    func floorTouchBegan(_ id: Int, at point: CGPoint, time: TimeInterval)
    func floorTouchMoved(_ id: Int, to point: CGPoint, time: TimeInterval)
    func floorTouchEnded(_ id: Int, at point: CGPoint, time: TimeInterval)
    /// The lid slider (only when `usesSlider`): `fraction` 0 at the fold … 1 at the lid's far edge.
    func sliderTouch(began: Bool, ended: Bool, fraction: Double, time: TimeInterval)
    var usesSlider: Bool { get }
}

/// Consumes events + telemetry (audio, haptics).
@MainActor public protocol FeedbackSink: AnyObject {
    func handle(_ events: [HeistEvent], telemetry: HeistTelemetry)
}

# Hush: architecture and module contracts

The types that modules share live in `Hush/Shared/Contracts.swift`, which the founder owns. This file sets out who
owns what, and the exact API each module must expose, so that the others can compile against it **without a compiler
on our side**. CI on GitHub's macOS runner is our only compiler.

**Rules**
- Swift 5 language mode, iOS 18 deployment target, built with Xcode 27.1 and the iOS 27.1 SDK.
- Hinge code goes behind `#available(iOS 27.1, *)`.
- Everything that touches views, nodes, audio or haptics is `@MainActor`.
- Core is plain value types plus final classes, with no actor isolation and no UIKit, SpriteKit or SwiftUI imports.
  Core may import Foundation and CoreGraphics only.
- No third-party packages.
- Every type and function listed here must exist with **exactly** this signature. You may add more, but not rename.

## The frame loop

```
SpriteView(ChestScene)                     ← SwiftUI hosts SpriteKit, preferredFramesPerSecond = 120
  ChestScene.update(currentTime)
    → driver.advance(dt:now:)              ← GameController (App), the hub
         lid    = lidSource.lid(at: now)       (HingeLidSource on a Duo, SliderLidSource elsewhere; ThiefPilot in attract/CI)
         events = session.step(dt, lid)        (Core: HeistSession, sub-steps at ≤ 1/120 s)
         feedback.handle(events, telemetry)    (Feedback: FeedbackDirector)
         publish HUD state at ≤ 15 Hz to SwiftUI
    ← (snapshot, events)
    ChestScene draws the lid (mimic), the fold, the floor (chest interior, loot, light, bag), FX for the events
  ChestScene.touchesBegan/Moved/Ended → driver.floorTouch… (floor half) / driver.sliderTouch (lid half, no hinge)
    → GameController → session.touchBegan/Moved/Ended (Core) → events go to feedback at once and to the scene next frame
```
`dt` is clamped to ≤ 1/30 s by the driver. The game pauses (no stepping) while the lid is closing (θ < 85° for 0.4 s),
the app is inactive, or the pause menu is open.

## Module ownership

| Module | Folder | Owner |
|---|---|---|
| Contracts | `Hush/Shared/` | founder |
| Core rules, chests, catalogues, pilot | `Hush/Core/` | **Core engineer** |
| Scene (SpriteKit) and chest/mimic/loot art | `Hush/Scene/` | **Scene engineer** |
| Input (hinge, slider) and Feedback (audio synth, haptics) | `Hush/Input/`, `Hush/Feedback/` | **Feel engineer** |
| App shell, UI, persistence, Game Center, demo mode | `Hush/App/`, `Hush/UI/`, `Hush/Persistence/` | **App engineer** |
| Tests | `HushTests/` | each engineer writes `HushTests/<Module>Tests.swift` |
| CI | `.github/`, `ci/`, `project.yml` | founder |

An engineer only writes inside their own folders. If you need something from another module that isn't listed
below, don't invent it: write a note in `design/NEEDS.md` and use a local `private` stand-in.

## Core API (Core engineer)

```swift
/// SplitMix64. Deterministic everywhere.
struct SeededRandom { init(seed: UInt64); mutating func next() -> UInt64; mutating func unit() -> Double /* [0,1) */
                      mutating func range(_ r: ClosedRange<Double>) -> Double; mutating func int(_ r: ClosedRange<Int>) -> Int }

enum Tuning { /* every number from GAME-DESIGN §3–§6 as static lets, documented; nothing hard-coded elsewhere */
    // at least these (used by other modules):
    static let shutAngle: Double          // 100   θ where openness = 0
    static let wideAngle: Double          // 165   θ where openness = 1
    static let shutZoneAngle: Double      // 110   θ ≤ this = shut zone
    static let tooWideAngle: Double       // 172
    static let closingAngle: Double       // 85    θ < this for closingDwell = pause
    static let closingDwell: Double       // 0.4
    static let quietSpeed: Double         // 8     °/s: silent below
    static let loudSpeed: Double          // 30    °/s: "Slower…" above
    static let torchSeconds: Double       // 100
    static let oilSeconds: Double         // 8
    static let sliderDegreesPerPoint: Double // 0.25 (lid slider: 1 pt/s ≈ 0.25 °/s)
}

enum Noise {
    /// Noise added per second by the lid moving at `speed` °/s (GAME-DESIGN §5 table, before the mimic multiplier).
    static func lidRate(speed: Double) -> Double
    /// Noise added per second by dragging an item at `speed` pt/s.
    static func dragRate(speed: Double) -> Double
    /// The stage for a noise level, with hysteresis from the previous stage.
    static func stage(for noise: Double, previous: MimicStage) -> MimicStage
}

enum Lid {
    /// θ → openness 0…1 (clamped). And the inverse (for the pilot and the slider).
    static func openness(angle: Double) -> Double
    static func angle(openness: Double) -> Double
}

enum RelicCatalog { static let all: [Relic] /* exactly 24, ids relic01…relic24 */; static func relic(_ id: RelicID) -> Relic }
enum MimicNames { static func name(for kind: MimicKind, seed: UInt64) -> String }   // "Snoring Sam", "Twitchy Tess" …

enum ChestFactory {
    /// Deterministic: the same (seed, index, found) gives the same chest. Relic chests prefer relics not in `found`.
    static func chest(seed: UInt64, index: Int, found: Set<RelicID>) -> ChestSpec
    static func tier(forIndex index: Int) -> ChestTier
}

struct SessionOptions: Equatable {
    var torch: Bool = true          // false: the torch never burns down (attract, lesson)
    var bites: Bool = true          // false: noise caps at 0.99 (attract, lesson)
    var noiseScale: Double = 1      // the lesson uses 0.6
    var fixedChest: ChestSpec? = nil   // the lesson's scripted chest (repeats)
    init(torch: Bool = true, bites: Bool = true, noiseScale: Double = 1, fixedChest: ChestSpec? = nil)
    static func `for`(_ mode: RunMode) -> SessionOptions
}

final class HeistSession {
    init(mode: RunMode, seed: UInt64, bestRun: Int, foundRelics: Set<RelicID>, options: SessionOptions)
    let mode: RunMode
    let seed: UInt64
    /// One frame. Returns this step's events in order.
    func step(dt: Double, lid: LidInput) -> [HeistEvent]
    /// Floor-space touches (ids are stable per finger; times are seconds on the CACurrentMediaTime clock).
    func touchBegan(id: Int, at point: CGPoint, time: Double) -> [HeistEvent]
    func touchMoved(id: Int, to point: CGPoint, time: Double) -> [HeistEvent]
    func touchEnded(id: Int, at point: CGPoint, time: Double) -> [HeistEvent]
    /// Adds noise directly (the lesson's scripted stir).
    func nudgeNoise(to level: Double)
    var snapshot: HeistSnapshot { get }
    var isFinished: Bool { get }
    var result: RunResult? { get }   // non-nil once finished
    /// Fastest held-item drag speed right now (pt/s), for telemetry.
    var dragSpeed: Double { get }
}

enum DailySeed {
    static func dayNumber(for date: Date, calendar: Calendar = .current) -> Int   // days since 2026-01-01
    static func seed(day: Int) -> UInt64
}

enum ThiefRanks {
    static let count: Int                                   // 12
    static func rank(forLifetimeGold gold: Int) -> Int      // 0…11
    static func title(_ rank: Int) -> String                // "Pickpocket" … "Mimic Whisperer"
    static func threshold(_ rank: Int) -> Int               // lifetime gold needed for `rank`
}

enum Achievements {   // ids are Game Center ids too: "hush.ach.<key>"
    static let all: [AchievementDef]                        // exactly 12
    /// Newly earned after `run` (given lifetime totals including the run and what's already earned).
    static func earned(after run: RunResult, lifetimeGold: Int, relicsFound: Int, alreadyEarned: Set<String>) -> [AchievementDef]
}
struct AchievementDef: Hashable { let id: String; let title: String; let detail: String }

enum PilotSkill: String, CaseIterable { case novice, casual, expert, perfect }
/// A simulated thief: drives the lid and the touches. Used by attract mode, CI frames and the balance tests.
struct PilotTouch: Equatable { enum Phase { case began, moved, ended }; var phase: Phase; var id: Int; var point: CGPoint }
struct PilotOutput: Equatable { var lid: LidInput; var touches: [PilotTouch] }
struct ThiefPilot {
    init(skill: PilotSkill, seed: UInt64)
    mutating func step(dt: Double, snapshot: HeistSnapshot) -> PilotOutput
}
```

**HeistSession behaviour** (GAME-DESIGN §4–§6):
- A new chest starts in `.ready`. `.looting` begins once `lid.inShutZone` has been true and openness then rises past
  0.02. If the lid isn't shut, the hint is `.easeLidDown`.
- **Light** per item = `clamp((openness − depth) / 0.10, 0, 1)`.
  - `itemRevealed` fires when light passes 0.4, once per item.
  - An item is grabbable when light ≥ 0.6 and the phase is `.looting`.
- **Touches:**
  - `touchBegan` on a grabbable item within `radius + 14` pt picks it up (nearest first; one item per finger).
  - While held, the item follows the finger.
  - Ending inside `FloorSpace.bagRect` bags it (into a bag slot position). Anywhere else drops it back at the nearest
    point inside `FloorSpace.interior`.
- **Noise:**
  - Integrated per sub-step from `Noise.lidRate(lid.speed)` × mimic multiplier × `noiseScale`, plus the drag rate,
    plus the one-off amounts.
  - It decays only after 0.4 s with no rate above 0.01. Restlessness applies.
  - `.dreamer` emits `dreamTwitch` every 4–9 s (seeded).
- **Bank:** in `.looting`, with ≥ 1 item in the bag and `inShutZone`, `shutHold` grows over 0.35 s. Reaching 1 banks
  the haul.
- **Bite:** noise ≥ 1 and `bites` is on.
- **Torch:** it burns only in `.looting` and `.ready`, never in the bank or bite moments. The run ends when it goes
  out.
- **Hint priority:** freeze > slower > tooWide > easeLidDown > shutToBank > dragToBag > openSlowly.

## Input API (Feel engineer)

```swift
@MainActor final class HingeLidSource: LidSource {   // fed by HingeReader samples
    init()
    func ingest(angleDegrees: Double, at time: TimeInterval)
    var hasHinge: Bool { get }                       // true once any real sample arrived (never goes back to false)
    var angle: Double? { get }                       // filtered hinge angle (180 = flat)
    var isClosing: Bool { get }                      // filtered angle < Tuning.closingAngle for Tuning.closingDwell
    func lid(at time: TimeInterval) -> LidInput
}
@MainActor final class SliderLidSource: LidSource {  // the no-hinge fallback: a vertical slider on the lid half
    init()
    func touch(began: Bool, ended: Bool, fraction: Double, time: TimeInterval)   // fraction 0 (shut) … 1 (wide)
    func lid(at time: TimeInterval) -> LidInput
}
struct HingeReader: ViewModifier                     // copy of Swoop's: (angle°, time) + onUnavailable
// usage: view.modifier(HingeReader(onUpdate: { angle, time in … }, onUnavailable: { … }))
enum FeelDemoLog { static let isEnabled: Bool; static func line(_ s: String) }   // `HUSH-T …` lines, DEBUG + -hushDemo only
```
- **Speed** is the magnitude of the derivative of a One-Euro-filtered angle, smoothed over about 0.25 s.
  - Samples stop arriving while the hinge is still, so with no sample for over 0.12 s the speed decays towards 0
    (time constant 0.15 s).
  - A sample after a long gap must not make a speed spike: use the gap-aware derivative.
- **The slider** reports speed as |d fraction/dt| × (lid travel, 65°).

## Feedback API (Feel engineer)

```swift
@MainActor final class FeedbackDirector: FeedbackSink {
    static let shared: FeedbackDirector
    func start()                                      // audio session + engines (idempotent)
    var soundOn: Bool; var hapticsOn: Bool; var respectSilentSwitch: Bool
    var idle: Bool                                    // menus: the engine naps when quiet
    func handle(_ events: [HeistEvent], telemetry: HeistTelemetry)
    func uiTap(); func uiConfirm(); func celebrate()  // menus, rank up, new relic page
    func silence()                                    // fade the continuous layers out (pause, menus)
    func homeLid(speed: Double, openness: Double)     // the Home screen's live creak (the title chest follows the hinge)
}
```

## Scene API (Scene engineer)

```swift
@MainActor final class ChestScene: SKScene {
    init(layout: ScreenLayout)                        // scene.size = layout.size; scaleMode .aspectFit
    weak var driver: SceneDriver?
    var reduceMotion: Bool
    var layout: ScreenLayout                          // settable (a hinge appears later)
    func reset()                                      // new session: clear FX
}
/// The chest, mimic and loot drawn with CoreGraphics paths, so SwiftUI (Home, Codex, icon) and SpriteKit share one
/// art source.
enum ChestArt {
    static func lootPath(_ kind: LootKind, radius: CGFloat) -> CGPath              // centred at the origin
    static func lootColors(_ kind: LootKind) -> (fill: RGBA, rim: RGBA, glint: RGBA)
    static func relicPath(_ shape: RelicShape, radius: CGFloat) -> CGPath
    /// The mimic's face on the lid half, `wake` 0 (asleep) … 1 (biting); `size` = the lid half's size.
    static func mimicEye(wake: Double, size: CGSize) -> (white: CGPath, iris: CGPath, lidTop: CGPath)
    static let palette: HushPalette
}
struct HushPalette { let wood: RGBA; let woodDark: RGBA; let iron: RGBA; let gold: RGBA; let velvet: RGBA
                     let tongue: RGBA; let dungeon: RGBA; let dungeonDeep: RGBA; let candle: RGBA; let danger: RGBA
                     let amber: RGBA; let text: RGBA }
```
The scene draws only from snapshots and events. It owns cosmetic state: glints, coin bursts, the bite slam, dust and
camera shake. It never changes game state. It forwards touches to the driver:
- Touches starting on the floor half, in floor space, go to `floorTouch…`.
- Touches on the lid half go to `sliderTouch` when `driver.usesSlider` is true, and are ignored otherwise.

## App API (App engineer)

- **`GameController`** (`@MainActor ObservableObject`, `SceneDriver`) owns the session, the lid source (hinge,
  slider or pilot) and the feedback, and exposes HUD state to SwiftUI.
- **Persistence.** `ProgressStore` and `SettingsStore` keep versioned JSON in UserDefaults.
- **Demo mode** (DEBUG and CI) is turned on by the launch argument `-hushDemo "key=value;key"`. The keys are
  documented at the top of `Hush/App/DemoMode.swift` and in `design/ROUND-1.md`.
- **Log lines CI greps** all start with `HUSH-`:
  - `HUSH-T` for timing, demo and events;
  - `HUSH-H <t> <angle>` for hinge samples, at most 10/s.
  - `HUSH-T frame 120` is printed once the scene has drawn 120 frames.
- **Orientation:**
  - Supported: portrait plus both landscapes, *not* upside down (`UIRequiresFullScreen` stays on, so iOS would
    refuse it anyway).
  - Play is portrait (tabletop). Landscape on a Duo (book pose) shows the pose card: "Stand it up like a little
    laptop".
- **Turned round:**
  - On a Duo with "Turn the chest round" on (the default), RootView draws the play canvas rotated 180°
    (`rotationEffect`), so the floor lands on the sharp half.
  - Copy Brim's approach (`C:\Users\59527\Fold\Brim\UI\RootView.swift`: `turnsRound`, `insets(_:turnedRound:)`,
    `deferredEdges`).

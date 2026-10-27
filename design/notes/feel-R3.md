# Feel R3 hand-off: input, audio, haptics

*Feel engineer, Round 3. Files: `Hush/Input/HingeLidSource.swift`, `Hush/Feedback/FeedbackDirector.swift`,
`FeelSoundBook.swift`, `FeelHaptics.swift`, `HushTests/FeelTests.swift`. Nothing committed. Not compiled here (CI is the
compiler). The CREAK detector's test cases were checked in a Node port (numbers below).*

## For the App engineer (exact names)

```swift
// FeedbackDirector — CREAK (the slam)
// LIVE PATH: automatic. `handle(_:telemetry:)` detects the slam itself. The App needs NO new call.
@discardableResult func creakAccent() -> Bool   // optional manual trigger; shares the 0.5 s refractory (never doubles)
var onCreakAccent: (() -> Void)?               // main actor, fires on every crack (automatic or manual)
private(set) var creakAccents: Int             // count (diagnostics, tests)

// FeedbackDirector — frame rate (REVIEW-2-duo P2-7)
func preferredFPS(lidSpeed: Double, animating: Bool) -> Int   // NEW: call every PLAY frame
func preferredFPS(lidSpeed: Double, animating: Bool, at: TimeInterval) -> Int   // same, explicit time (tests)
var preferredFPS: Int                    // the CEILING: 60 under Low Power or thermal ≥ .fair (R3: was ≥ .serious), else 120
var onPreferredFPSChange: ((Int) -> Void)?   // unchanged: fires when the ceiling changes
nonisolated static func fps(lowPower: Bool, thermal: ProcessInfo.ThermalState) -> Int   // the ceiling, pure

// HingeLidSource — resume angle after a cover trip (REVIEW-2-duo P1-3)
var requiredResumeAngle: Double          // default 95 (= resumeAngle); clamped 90…150 when used; reset() keeps it
var effectiveResumeAngle: Double { get } // the sanitised value canResume uses
static func coverResumeAngle(relight: Double?) -> Double   // min(95, max(90, relight + 3)); nil/NaN → 95
```

### Wiring the frame rate (about 5 lines in the frame loop)
```swift
let fps = feedback.preferredFPS(lidSpeed: lid.speed,
                                animating: session.dragSpeed > 0 || anyFingerDown || !AppRules.isLive(snapshot.phase)
                                           || sceneHasLootInFlight || hudIsAnimating)
if fps != preferredFPS { preferredFPS = fps }   // publish only on change (SpriteView preferredFramesPerSecond)
```
- 120 (the ceiling) while `lidSpeed > 1°/s` or `animating`, **held for 1 s** after the last of either, so it never
  flaps. 60 otherwise. Never above the ceiling, so Low Power and heat still give 60.
- Paused / menus / Home: keep using `min(preferredFPS, 60)` as today (Home's ticker is already capped at 60).
- Pass `lid.speed` (the frame's `LidInput.speed`: hinge or slider). It is the clamped play-range speed, which is the
  range where the lid art actually moves.

### Wiring the CREAK
- Nothing is required. On every `handle` call the director runs `FeelCreakDetector` on `telemetry.noise`.
- **The Scene's "CREAK!" should use the same detector**, or the App should forward `onCreakAccent` to the Scene.
  Otherwise the picture and the sound disagree in one place: the lesson's Freeze step `nudgeNoise(0.55)` is a scripted
  jump of more than 0.25 with a still lid. Feel deliberately stays silent on it (the player did nothing loud). A
  Scene rule on noise alone would flash "CREAK!" at a player who is doing exactly what it asked.
  - Option A (simplest): `feedback.onCreakAccent = { [weak scene] in scene?.showCreak() }`.
  - Option B: the Scene owns a `FeelCreakDetector` and calls
    `update(noise: snapshot.noise, lidSpeed: snapshot.lidSpeed, dragSpeed: …, playing: isLive, at: now)`.

## What changed

### CREAK (the slam, tester 6)
- **Rule** (`FeelCreakDetector`, pure, in `FeedbackDirector.swift`):
  - Fires when this frame's noise minus the lowest noise in the last **0.3 s** is more than **0.25**.
  - Only while `playing`. A non-playing call forgets the history.
  - **Only with real loudness:** the lid was over `Tuning.loudSpeed` (30°/s), or a drag over `Tuning.dragQuietSpeed`,
    within the same 0.3 s. Scripted jumps (the lesson stir, demo `noise=`) never crack. A jump this big needs about
    45°/s of lid anyway.
  - **Refractory 0.5 s**, then a fresh rise of 0.25 from the noise at the crack. A long slam cracks at most twice a
    second.
  - A `bitten` on the same frame suppresses it, so the CHOMP stays the one big sound. The crack usually lands about
    0.1 s before a slam's bite, which reads as "too loud → bite".
- **Sound** (`FeelSoundBook.creakAccent(dice:)`), all under 0.1 s:
  - a bright high-pass snap;
  - a dry 620–700 Hz wood crack (5 partials, 35 ms);
  - a 2 kHz splinter at 14 ms;
  - a 210 → 120 Hz knock;
  - a smaller second crack at 45–60 ms.
  - Peak gain 0.26: louder than a coin, under the CHOMP's 0.36.
- **Haptic** (`FeelHapticBook.creakAccent`): a keen 0.9 tap at sharpness 1.0, a 0.45 tap at 14 ms and a 0.3 tap at
  50 ms. Under the bite.
- **Log:** DEBUG with `-hushDemo` logs `HUSH-T creak accent noise <n>` (or `manual`). CI's slam re-shoot can grep it.
- **Node port of the test:**
  - a careful open never cracks;
  - a 120°/s slam (noise +1.6/s) cracks once, **0.158 s** in;
  - holding loud afterwards: still one;
  - a 0.3 rise over 0.6 s: none.

### Frame rate (REVIEW-2-duo P2-7)
- `FeelFrameRate` (pure): ceiling while busy, held for 1 s; 60 when idle.
- The ceiling now drops to 60 at thermal `.fair` (the reviewer's fix; by `.serious` the Duo is already hot).

### VoiceOver: the stage cues (checked)
- Nothing in Feedback reads VoiceOver, Reduce Motion or the HUD.
- Every `stageChanged` plays its cue in `handle`, factored into `FeelSoundBook.stageCue(from:to:dice:)` and
  `FeelHapticBook.stageCue(from:to:)`, and tested for every pair:
  - a snort up to Stirring, the wake sting up to Waking, a sigh for any step down;
  - a haptic nudge only on the way up;
  - nothing for a bite (the CHOMP).
- The heartbeat (60 bpm at Stirring, 110 at Waking) keeps the stage audible the whole time.
- The session is `.playback` + `.mixWithOthers` (or `.ambient`), so the cues mix with VoiceOver speech.
- **One App note:** with VoiceOver's audio ducking on, an announcement posted on the same frame ducks the snort
  (0.2 s). Posting the stage announcement about 0.3 s after `stageChanged` lets the cue be heard first. This is
  optional.

### Input
- **P1-3 (cover relight below 95°):** `requiredResumeAngle` and `coverResumeAngle(relight:)`.
  - The App learns `relight` (the first inner canvas after `.cover`) and sets
    `hinge.requiredResumeAngle = HingeLidSource.coverResumeAngle(relight: relight)`.
  - It sets it back to `HingeLidSource.resumeAngle` on resume.
  - Changing it restarts the 0.3 s hold.
- **P1-4 (the first hinge sample):** checked. On the Input side the first report is a fresh base for both meters (speed
  0), and the predictor and smoother start on it, so it can't spike the noise. The guard (hold, then `reset()`) belongs
  to the App, as briefed.

## Not Feel (left to their owners)
- QA-2 P2-9 (resume-grace exploit) and P2-10 / REVIEW-2-duo P2-6 (menu Resume skips `canResume`): App and Core.
- REVIEW-2-duo P2-5 and decision 2 (no `rest` in pauses): App and Core. Feel copes either way: paused telemetry
  isn't `playing`, so no creak, no crack and no beat.

## Tests (`HushTests/FeelTests.swift`)
**Updated**
- `preferredFPSDropsUnderLowPowerOrHeat` (`.fair` → 60; values bound with typed `let`s).
- The recipe, haptic-shape and render lists include the crack and the stage cues.

**New**
- `frameRateIsFastOnlyWhileSomethingMoves`
- `aSlamCracksOnceAndAScriptedJumpNever`
- `theCreakAccentIsSharpAndPlaysThroughTheDirector`
- `everyStageChangeHasItsCue`
- `aCoverTripCanLowerTheResumeAngle`

No mutating call sits inside `#expect`: every `update`, `claim` and `fps` result is bound with `let` first.

## Compile risks I couldn't rule out without a compiler
- `FeedbackDirector` now has `var preferredFPS: Int`, `static var preferredFPS: Int` and the methods
  `preferredFPS(lidSpeed:animating:)` and `preferredFPS(lidSpeed:animating:at:)`.
  - The declarations are legal: the full names differ, as with `Array.first` and `first(where:)`.
  - A bare `FeedbackDirector.preferredFPS` in an untyped context could in theory be ambiguous with the unapplied
    instance method. Every existing use is typed: `GameController` assigns it to an `Int`, and the tests use
    `let x: Int`.
  - If CI objects, delete the `static var preferredFPS` (nothing in the App uses it).

## Listen and feel on the device
1. **Slam the lid** from about 130° to shut. You should hear a sharp wooden crack and feel a keen tap, then the "too
   loud" noise, then usually a bite. Ease it shut at 15°/s: no crack.
2. **Lesson, the Freeze step:** the mimic stirs on its own. There must be **no** crack, in sound or picture.
3. **Battery:** play 5 runs, and with the debug overlay on watch for 60 fps while you hold the lid still with nothing
   moving, and 120 while you move it.
4. **VoiceOver on:** Stirring gives a snort and a slow heartbeat; Waking gives the sting and a fast heartbeat, with
   the App's announcement.

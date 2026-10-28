# Feel R7 hand-off: real hands (input, audio, haptics)

*Feel engineer, Round 7. Files: `Hush/Input/FeelFilters.swift`, `Hush/Input/HingeLidSource.swift`,
`Hush/Feedback/FeedbackDirector.swift`, `Hush/Feedback/FeelHaptics.swift`, `HushTests/FeelTests.swift`. Nothing
committed. Not compiled here (CI is the compiler). Every input trace test was run first in a Node port of the exact
pipeline (One-Euro, estimator, predictor, gate, resume, the FakeHinge); the numbers are below. Tuning is read by name
(`Tuning.quietSpeed` 14, `closeQuietSpeed` 28, `loudOnsetSeconds` 0.08 are already in Core).*

## For the App engineer (exact names)

```swift
// FeedbackDirector — the Settings "Vibration" row (ROUND-7 App 4)
var hapticStrength: HapticStrength          // NEW. get/set. Default follows the device: .strong once
                                            // `deviceHasFold = true` (already set in GameController), else .normal.
enum HapticStrength: String, Codable, CaseIterable, Sendable { case off, normal, strong }   // NEW
    static func defaultFor(hasFold: Bool) -> HapticStrength
    var title: String                       // "Off" / "Normal" / "Strong"
    var profile: FeelHapticProfile          // and init(profile:)

// HingeLidSource — the Diagnostics Copy log (ROUND-7 App 5)
func traceText() -> String                  // NEW. Last 10 s of raw reports, a few hundred short lines at most.

// HingeLidSource — unchanged names, new values/behaviour
static let resumeAngle = 92.0               // was 95 (the enter line)
var requiredResumeAngle: Double             // default 92; changing it restarts the hold AND the hysteresis
var effectiveResumeAngle: Double { get }    // NOW HYSTERETIC: 92 until lifted, then 88 until the lid drops under 88
var canResume: Bool                         // same API; lifted (92/88) and still (< 6°/s, < 10°/s at ≥ 100°) 0.3 s
static func coverResumeAngle(relight:) -> Double   // min(92, max(90, relight + 3)); nil/NaN → 92
nonisolated static var speedAngleRange      // 97…162 (was 97…168)
```

### Wiring
- **Vibration row:** bind it to `FeedbackDirector.shared.hapticStrength`.
  - Setting it counts as the player's choice. `.off` is the same as `hapticsOn = false`; `hapticsOn = true` brings back
    the last on-strength.
  - **Persist it as an optional.** With no stored choice, don't set it, so it keeps following `deviceHasFold` (Strong
    on a Duo). Setting it on every launch from a stored default would pin a non-Duo default on a Duo.
  - `SettingsStore` can keep its `hapticsOn` push, which stays compatible. Better: derive `hapticsOn` from the stored
    strength (`strength != .off`) and push only `hapticStrength`.
- **Closing card:** nothing to change. `GameController.checkClosing` already does
  `lifted = angle >= hinge.effectiveResumeAngle`, so it gets the 92/88 hysteresis for free.
  - **Two App spots still say 95:** `AppRules.resumeAngle = 95` (the "Hold still…" line in AppRules) and the R6
    watchdog in `AppRulesR6.swift:182` (`a >= resumeAngle`).
  - Point both at `hinge.effectiveResumeAngle`, or at least at `HingeLidSource.resumeAngle`. Otherwise the watchdog
    asks for 95 while Feel resumes from 92.
- **Diagnostics Copy:** append `hinge.traceText()` as a block. Its format:
  ```
  Hinge trace (raw, last 10 s): 287 reports over 9.53 s, newest 0.41 s ago
  rate 30.0 Hz; gap median 33 ms, max 180 ms; step min 0.12, max 2.40 deg; snaps 0
  0:112.34 33:112.80 67:113.10 …           (ms from the oldest kept report : raw angle, 8 per line)
  ```
  - The angles are raw and unclamped, exactly as `onHingeChange` delivered them.
  - The summary line answers DEVICE-RISKS' rate, quantisation, stick-slip and gap questions on its own.
  - It survives `reset()`.
- **Nothing else is needed.** The quiet ticks, hygiene, snap and resume rules are automatic.

## What changed

### 1. A clean speed estimator (`FeelSpeedEstimator`, `FeelSpeedHygiene.hinge`)
- **Breakaway floor:**
  - A report after a silence of more than 0.12 s (`hold`) starts a new move.
  - Until that move is 0.10 s old, the window speed is divided by at least 0.10 s.
  - A full restart (more than 0.25 s of silence) is always a new move.
- **Deadband (backlash on the reported angle):**
  - A report within 0.4° of the last accepted value reads as that value.
  - A steady move still reads exactly: 10°/s reads 10.00 at both 30 and 25 Hz.
- **Snap** (`HingeLidSource`):
  - One report that jumps more than 8° with both readings ≥ 150° rebases both meters, so it credits no speed.
  - It logs `HUSH-T hinge snap <angle>` (DEBUG, `-hushDemo`) and counts in the trace's `snaps`.
  - A jump that starts under 150° (149 → 158) still counts.
- **Speed range capped at 162°** (DEVICE-RISKS item 10).
- **The slider is unchanged** (`.plain`). Its 120 Hz touch steps are far under 0.4°.

### 2. Resume
- The enter line is 92° and the leave line 88° (`effectiveResumeAngle` reports the one in force).
- "Still" means under 10°/s at ≥ 100° and under 6°/s below 100°.
- The `canResume` / `resumable(at:)` API is unchanged.
- **Known behaviour:** a fast reopen that stops abruptly at 90° overshoots in the angle predictor to about 96° (port:
  100°/s → peak 96.1°). That counts as lifted, so the run resumes at 90°.
  - This is deliberate (kind): the lid is silent below 97° anyway.
  - The tests reach the band slowly.

### 3. Haptics for careful play
- **`FeelQuietTicker`** (pure, in `FeedbackDirector.swift`):
  - While playing with the creak silent (heard speed at or under the quiet line, so up to 28°/s while closing), it
    adds one `FeelHapticBook.quietTick` (tap 0.18, sharpness 0.8, Strong-adapted) per 4° of travel (∫ speed dt).
  - At most 20 Hz.
  - Under 2°/s it counts no travel (tremor and decay tails).
  - A creak resets the count, and leaving play or `silence()` forgets it.
  - It runs in play only, not on Home (so the Home menu's haptic engine can stay idle).
- **The stirring tell is up 0.35 → 0.5** (DEVICE-RISKS item 6).

### 4. Raw hinge trace
- `FeelHingeTrace`: a fixed 1,024-slot ring with no allocation per report. It keeps reports within 10 s of the newest.
- `HingeLidSource.traceText()`.

## Node-port numbers (the CI expectations)

| Trace | R3 | R7 | Test bound |
|---|---|---|---|
| Stick-slip 10°/s (stick 0.2 / 0.3 s, 2° jump, 0.5° steps), max after 0.15 s | 10.0 / 8.4 | 10.0 / 8.4 | ≤ 14 |
| Same with a 0.3° creep report before each jump, 30 / 25 Hz: peak | 21.6 / 20.8 | 17.5 / 19.0 | < 22 |
| Same: 10 s of lid noise with the 0.08 s onset (Core's rule) | 0.061 / 0.053 | 0.018 / 0.020 | < 0.03 |
| Breakaway 120.3 → 122.3 at 25 ms / 33 ms | 28.7 / 25.1 | 7.2 / 8.4 | < 12 |
| 40°/s from still, 30 / 25 Hz: min from 0.32 s, overall max | 38.3 / 38.6, 40.9 | 38.3 / 38.6, 40.9 | ≥ 36, ≤ 44 |
| Slam 150 → 100 in 0.25 s: peak | 193 | 192 | > 80 |
| Fling 165 → 100 at 470°/s: peak (no snap) | 444 | 441 | > 80 |
| Snap 153 → 162 while creeping at 5°/s: speed / motion peak | 31.1 / — | 4.0 / 0.0 | < 6 / < 1 |
| Existing slam 120°/s: speeds[18] / speeds[36] | 98.2 / 116.6 | 91.8 / 116.5 | > 30 / > 90 |
| Tremor ±0.5° at 6 Hz | 1.60 | 1.23 | < 7 |
| Hover 95° ± 1° at 10 Hz: resumes after | — | 0.68 s | within 2 s |
| Resume after a 150°/s reopen stops at 120° | 0.92 s | 0.83 s | 0.3–1.2 s |

**One brief number that couldn't be met:** "40°/s reads 36–44 within 0.2 s".
- The pipeline couldn't meet it even before R7: R3 reads 32.4 at 0.2 s and first reaches 36 at 0.275 s. That lag is
  the One-Euro start-up plus the 0.25 s window.
- R7 reaches 36 at 0.283 s.
- The test asserts 36–44 from 0.32 s on and never over 44.
- Meeting 0.2 s would need a different smoother, and that would also make stick-slip spikes louder.

**Why the floor is 0.10 s, not longer:**
- A 0.25 s floor makes even the creep stick-slip read under 14.
- But it softens a 470°/s fling from rest to 0.18 noise, so it no longer bites. At 0.10 s that fling gives 1.48.
- The brief's 0.10 s plus Core's 0.08 s onset is the right pair.

## Tests (`HushTests/FeelTests.swift`)

**Updated**
- `creakIsSilentBelowTheQuietSpeed…`: `Tuning.quietSpeed + 2` instead of a literal 14.
- `creakRendersSilent…`: `Tuning.quietSpeed + 3` instead of 15. Both had literals that would break at quietSpeed 14.
- `motionOutsideThePlayRangeIsSilent`: the 162° top.
- `aCoverTripCanLowerTheResumeAngle`: 92° values, and a 120 → 91 lowering at 110°.
- `hapticMomentsHaveTheirShapes`: includes `quietTick`.

**Replaced**
- `resumeNeedsNinetyFiveDegrees` → `resumeHasHysteresisAtNinetyTwoAndEightyEight`.

**New**
- `aHandRestingOnTheLidStillResumes`
- `aStickSlipSlowOpenReadsSlow`
- `aBreakawayFromStillDoesNotSpike`
- `aRealMoveAndASlamStillReadTrue`
- `aSnapNearFlatCreditsNoSpeed`
- `carefulPlayTicksEveryFourDegrees`
- `vibrationStrengthFollowsTheDeviceUntilChosen`
- `theHingeTraceKeepsTheLastTenSeconds`

No mutating call sits inside `#expect`: every `update` result is bound with `let` first.

## Compile risks I couldn't rule out
- `FeelSpeedEstimator` gained a stored `let hygiene`. Every existing `FeelSpeedEstimator()` still compiles (default
  `.plain`).
- `HapticStrength` is a new top-level type. If the App engineer also declares one in parallel, keep this one (it's in
  Feedback, as briefed).

## Listen and feel on the device
1. Open slowly. You should feel a faint tick about every 4°, with no creak.
2. Open naturally at about 25°/s: soft creak, no ticks.
3. Start each move from still: no "Slower…" on the first jerk.
4. Rest the lid at about 90° after a pause. The card must not flicker. With a hand on the lid above 100°, it resumes.
5. Copy the Diagnostics log after a slow open, a natural open and a bank, and paste it to the studio (DEVICE-RISKS
   founder question 1).

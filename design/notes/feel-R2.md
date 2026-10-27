# Feel R2 hand-off: input, audio, haptics

*Feel engineer, Round 2. Files: `Hush/Input/FeelFilters.swift`, `Hush/Input/HingeLidSource.swift`,
`Hush/Feedback/FeedbackDirector.swift`, `FeelSoundBook.swift`, `FeelHaptics.swift`, `HushTests/FeelTests.swift`.
Nothing committed. Not compiled here (CI is the compiler). The input timing tests were checked in a Node port of the
exact pipeline (all pass; numbers below).*

## For the App engineer (exact names)

```swift
// HingeLidSource
var canResume: Bool                    // θ ≥ 95° and hinge motion < 6°/s, held 0.3 s. Poll every frame while paused.
func resumable(at: TimeInterval) -> Bool
func reset()                           // call at the moment of resume, and in setAppActive(true)
var isClosing: Bool                    // now < 70° (Tuning.closingAngle) for 0.4 s; unlatches above 78°
var motionSpeed: Double                // unclamped hinge motion, °/s (diagnostics, HUSH-T lines)
static let resumeAngle = 95.0, resumeSpeed = 6.0, resumeHold = 0.3
nonisolated static var speedAngleRange: ClosedRange<Double>   // 97…168

// FeedbackDirector
func glimmer(on: Bool)                 // pass `snapshot.hint == .relicDeeper` (every frame is fine)
func goldenArrived()                   // NEW: call once when `.chestArrived` comes and `snapshot.chest?.golden == true`
private(set) var preferredFPS: Int     // 60 under Low Power or thermal ≥ .serious, else 120
static var preferredFPS: Int           // the same, from `shared` (so `FeedbackDirector.preferredFPS` works too)
var onPreferredFPSChange: ((Int) -> Void)?   // main actor, on change
nonisolated static func fps(lowPower: Bool, thermal: ProcessInfo.ThermalState) -> Int
```

**`goldenArrived()` is the one call the brief didn't name.** `HeistEvent.chestArrived` carries no golden flag and the
telemetry has no chest, so the director can't tell on its own. One line in the frame loop:
`if events.contains(where: { if case .chestArrived = $0 { return true }; return false }), snapshot.chest?.golden == true { feedback.goldenArrived() }`.

**The resume rule, end to end**
1. Pause (closing card) when `isClosing`.
2. While paused, send `lidSpeed: 0` (QA-1 P1-1). The director copes anyway (see below).
3. Each paused frame: `if hinge.canResume { hinge.reset(); session.resumeGrace(seconds: 0.5); resume }`.
4. Cards: "Hold still…" between 78° and resume.
- `GameController.closingResumeAbove` and the App's own `Tuning.closingAngle` dwell become redundant: `canResume` is
  the resume test, and `isClosing` already uses `Tuning.closingAngle` (Core moved it to 70).

## What changed

### Input
1. **`reset()`** now also clears the resume hold and the new motion meter, and zeroes `lastLid.speed`. It keeps
   `hasHinge`, the last reading and the closing latch, as before.
2. **Closing:** `FeelClosingGate` reads `Tuning.closingAngle` (70) and `reopenMargin` is 8, so it unlatches above 78°.
   An upright rest at 85 ± 5° never pauses (tested).
3. **`canResume`:**
   - It judges a separate, **unclamped** speed estimator (`motionMeter`) on the raw reports, so a lid still moving
     above 168° or below 97° doesn't count as still.
   - It uses `FeelSpeedEstimator.peekSpeed(at:)`, a new non-advancing read: the larger of the per-sample and display
     estimates, decaying like the display speed once reports stop. It is conservative (never below what a frame
     would read).
   - It works without frames: the hold matures on the clock, judged from the reports and each poll.
   - **Port numbers:**

| Case | Result |
|---|---|
| Reopen 60 → 120° at 150°/s, then an abrupt stop | resumable 0.92 s after the stop (never while moving, even past 95°) |
| Same, no frames | 0.91 s |
| Slow wobble at 3°/s | resumable |
| 15°/s | not resumable |
| Held still at 93° for 2 s | not resumable |
| 97°, after the hand stops | ~0.55 s |

   A real hand decelerates, so it will usually be quicker than the abrupt-stop case.
4. **Speed clamp (P1-5):** the speedometer sees `clamp(raw, 97, 168)`.
   - A 180 → 170 snap at 40°/s reads 0.
   - A 96 → 30° fold at 110°/s reads 0.
   - The real motion during the snap still reads 37°/s on `motionSpeed`.
   - 10°/s inside the range still reads 10.00.

### Feedback
- **The creak follows the noise rule.**
  - Silent at ≤ `Tuning.quietSpeed` (12 now).
  - While closing, silent at ≤ `Tuning.closeQuietSpeed` (18): `FeelSoundBook.creakSpeed(_:closing:)` shifts the
    curve by 6°/s, so the shape is unchanged.
  - The direction is `FeelLidDirection`, which mirrors HeistSession exactly: openness fell since the last frame.
  - Sound and haptic both use it.
- **Pause robustness (QA-1 P1-1):** `FeelFrozenSpeedGuard`.
  - Outside play, a non-zero speed that hasn't changed at all for 0.3 s reads as 0. A live speed changes every frame.
  - The creak sound and haptic stop by themselves, and the engines can nap again (`lastActive` uses the heard speed).
  - The same guard covers Home.
- **Chain up:** a rising chime on a D-major-pentatonic ladder (A5 → D7).
  - It plays up to 3 notes, ending one rung higher per chain step, plus a glint.
  - After a bank it starts at 1.55 s, after the ka-ching and the Hushed chimes.
  - Haptic: one keen tap per note.
- **Chain broken:** a glassy crack (high-pass snap, two inharmonic glass rings) and 4 shards tinkling down over 0.31 s.
  - Delay: 0.12 s after a stir's snort, or 1.1 s after a bite (after the CHOMP and the coin spill).
  - Haptic: a sharp tap and 4 tiny ticks.
- **Golden arrival:** a 7-note glass glissando D6 → E7 and a trembling D-major chord (vibrato at 7.5 Hz), plus an air
  shimmer and late glints.
  - It starts at 0.4 s, after the chest's thunk.
  - Haptic: a rising ripple of 7 taps and a soft swell.
- **Candle clock:**
  - From 15 s: a tick-tock each second (wood, 2.4/2.0 kHz, gain 0.05) with a faint haptic tick (0.14).
  - In the last 5 s: twice a second, higher (3.0/2.5 kHz), louder (0.07), with a click and a firmer haptic (0.32).
  - Oil raising the candle never ticks. `FeelSoundBook.torchTickSlot` is pure and tested: 9 + 10 ticks.
- **Bite cost:** coins spill from 0.3 s, after the CHOMP's teeth.
  - 4–10 FM clinks (by value) bouncing apart and slowing to 0.9 s, with stone knocks and a last coin spinning down.
  - A candle gutter at 0.95 s for the seconds lost.
  - An empty bag gives the gutter only.
  - Haptic: a patter on the same times.
- **Relic glimmer:** twinkles of 3.2–4.8 kHz glass at gain 0.012–0.02 (under half a coin), every 0.28–0.6 s, sometimes
  with a second higher sparkle.
  - It plays during play only.
  - It ends by itself on a bank, a bite, a new chest, the candle going out and `silence()`.
  - No haptic, so the creak texture stays clean.
- **`preferredFPS`:** computed at init and refreshed on `thermalStateDidChangeNotification` and
  `NSProcessInfoPowerStateDidChange` (main queue). DEBUG logs `HUSH-T thermal <raw> lowPower <0|1> fps <n>`; it is not
  the literal the Release guard greps.
- Every exhaustive `HeistEvent` switch is updated: `chainUp`, `chainBroken`, `biteCost`. Feel has no `HeistHint`
  switch.

## Tests (`HushTests/FeelTests.swift`, now 52)

**Updated for R2**
- The closing dwell (now 70°).
- Gate hysteresis (relative to the gate's constants).
- The creak silent line (`Tuning.quietSpeed`).
- The event list, recipes and haptic shapes, with the new ones included.

**New**
- `anUprightRestNeverPauses`
- `resumeWaitsForTheLidToBeOpenAndStill`
- `resumeNeedsNinetyFiveDegrees`
- `resumeIsJudgedWithoutFrames`
- `noHingeNeverResumes`
- `motionOutsideThePlayRangeIsSilent` (includes the 180 → 170 jump)
- `speedPeekNeverAdvancesAndDecays`
- `closingIsQuieterThanOpening`
- `aFrozenSpeedStopsCreaking`
- `theChainClimbsAStepPerHushedBank`
- `aBiteSpillsCoinsByValue`
- `theCandleTicksFasterInItsLastFiveSeconds`
- `theNewMomentsRenderCleanly`
- `glimmerAndGoldenThroughTheDirector`
- `preferredFPSDropsUnderLowPowerOrHeat`

## Compile risks I couldn't rule out without a compiler
- `FeedbackDirector` has both an instance `preferredFPS` and a `static var preferredFPS`.
  - Swift allows a static and an instance member with the same name, and inside the class I use `self.preferredFPS`.
  - If CI objects, delete the static one and use `FeedbackDirector.shared.preferredFPS`.

## Listen and feel on the device
1. **Closing:** lower the lid after a bank to an upright 90° and rest it. No pause card. Below 70° it pauses.
   - Reopen at your normal speed: the card waits ("Hold still…") and resumes about half a second after your hand
     stops.
   - No creak or buzz while the card is up and the lid is still.
2. **The closing creak:** easing the lid shut at about 15°/s should be silent. Opening at 15°/s should creak softly.
3. **The chain:** two Hushed banks in a row. A rising sparkle after the ka-ching, one step higher each time.
   - Stir the mimic with a chain of 2 or more: a glassy crack.
4. **The bite with loot in the bag:** the CHOMP, then coins skittering away, then a candle gutter.
5. **The last 15 s:** tick-tock each second, then quicker and keener in the last 5, with a faint tick in the fingers.
6. **A relic chest:** while "Something glints deeper…" shows, a faint high twinkle. Too much? Lower `glimmerTwinkle`'s
   gains.
7. **Low Power Mode on:** the game should run at 60 fps (the App wires it).

# DEVICE-RISKS-1: what else the founder most likely hit on TestFlight 1.0 (1)

*Real-device QA lead, 27 Oct, late evening. Read-only: no source was edited. The founder tested TF 1.0 (1), which is
the R4 commit (`docs/PROJECT-LOG.md:55`). He wrote "lots of issues … please fix all issues" and named only one:
going flat gets stuck. ROUND-6 is fixing that one. This file predicts the others from evidence, ranked by
likelihood × severity, so they can be fixed tonight. Line numbers are as of this evening. `GameController.swift` is
being edited for R6, so its lines are given by function name.*

## What we actually know about a real Duo (sister-game evidence)

| Fact | Source |
|---|---|
| The hinge reports at 25–30 Hz while moving (20–60 ms apart, with occasional 100–200 ms gaps) and **sends nothing while still** | Squish `design/FOLD-PRESS.md:531`; Brim `design/QA-2.md` P1-1; `HingeLidSource.swift:7` |
| A real person's **slow close** runs at 25–60°/s and a fast one at about 470°/s. Fully open reads 180°; slow presses start at about 175° | Squish `FOLD-PRESS.md:531-533` |
| `status == .closed` fires at about 85° (Hush ignores `status`, which is correct) | Squish `docs/HANDOVER.md:80` |
| The inner display stayed lit at about 90° in book pose: Swoop's founder saw the app's *own* 90° pause, not the cover display | Swoop `docs/PROJECT-LOG.md:94-105` |
| One fixed half blurs for about 2 s when a fold starts from flat. System banners appear at iOS's top. A Duo lying flat never auto-rotates. `UIRequiresFullScreen` rules out upside-down | memory `iphone-duo-hinge-api`; Brim `docs/HANDOVER.md:11,16` |
| Founder pattern on every first device test: Squish had no sound (`.ambient`), weak vibration and no onboarding. Squish 1.0 (3) felt "jumpy" and "out of sync" (it trusted `status`). Swoop's controls were unclear, its bird sat on the blurred half, its 90° pause cut a natural fold, and it felt "half baked" | memory `squish-device-feedback`; `FOLD-PRESS.md:519-521`; Swoop `design/ROUND-6.md`, project log |
| How fast people really move a hinge: a natural "slow" is **20–40°/s**; "as slowly as you can" averages 6–12°/s, but **stick-slip swings it ±30–50 %** | Hush `design/REVIEW-1-feel.md:61-64` |
| The balance and CI pilots never move like a hand: they open at 5–16°/s and close at 8–15°/s ("eases shut at 6–15°/s") | `Core/ThiefPilot.swift:43,79-93` |

The common thread: **every CI check and balance run uses smooth, robot-slow hinge motion.** The founder's hand is
faster and jerkier, and it starts from still every time.

---

## Ranked predictions

| # | Issue | Likely | Severity | Sim-CI verifiable? |
|---|---|---|---|---|
| 1 | A natural "gentle" open or close wakes the mimic, and easing it shut to bank bites | **High** | High | Partly (balance and unit; feel needs the device) |
| 2 | Lid speed spikes at the start of every move and on stick-slip, giving false "Slower…", creaks and noise that never decays | **High** (hardware-shaped) | High | **Yes** (unit traces plus a STICK-SLIP Duo check) |
| 3 | "Ease the lid shut" makes him fold the Duo fully shut after every bank: the outer screen, then "Hold still…", every chest | **High** | Medium | **Yes** (BANK-SHUT-REOPEN) |
| 4 | Pause coin under the lid hand: the menu pops mid-chest | Medium | Medium | Partly (frame plus UI test) |
| 5 | Resting the lid upright (the bank pose) is near the inner→cover hand-off, so screens flip | Medium | Medium | No (sim hand-off ≠ device) |
| 6 | Haptics feel weak or "on the table", and there is no feel at all while playing well | Medium | Medium | No (device only) |
| 7 | Resume friction: "Lift a little" ↔ "Hold still…" flicker at about 95°, and a hand on the lid never reads "still" | Medium | Medium | **Yes** (HOVER-95) |
| 8 | Lesson step 1 is strict (90–112° for 0.5 s against ±5°) and can't be skipped until step 3 | Medium | Medium | **Yes** (unit plus sim) |
| 9 | Upside-down system UI (banners, Control Centre, TestFlight feedback) at his near edge; menus unreadable when picked up flat | Medium | Low–Med | Partly |
| 10 | Near flat: a hinge snap or detent turns relic reaches into a slam; the last degrees jump | Med–Low | Medium | Partly (unit) |
| 11 | Finger tremor fails the lesson's Freeze ("Not a twitch"); natural drags are loud | Med–Low | Medium | Unit only |
| 12 | Warm after 5 runs; battery | Low–Med | Low–Med | No |

---

### 1. A natural "gentle" hand wakes the mimic, and banking bites (H × H)
- **Evidence:**
  - `Tuning.swift:38` `quietSpeed` is 12, `:41` `closeQuietSpeed` is 18 and `:43` `loudSpeed` is 30.
  - The feel lead's own table: "a first-timer's natural 'slow' of 25–30°/s turns the meter amber"; 40°/s →
    Waking, 45°/s → bite (`REVIEW-1-feel.md:69-87`).
  - A real slow *close* runs at 25–60°/s (Squish hardware log). At 40°/s, closing from 150° to 110° adds
    0.008·22 + 0.0004·22² = **0.37 noise** (×1.35 for a Light sleeper, ×1.25 for golden). That's on top of whatever
    the opening left, at the exact moment the bag is full.
  - Every balance pilot closes at 8–15°/s (`ThiefPilot.swift:79-93`), so the harness has never seen a bank-time
    bite.
- **What he sees:**
  - "It wakes up even when I'm slow."
  - "It bit me as I was shutting it."
  - The Hush Chain never builds.
  - "Slower…" during the lesson.
- **Fix (tonight):**
  - `Tuning.closeQuietSpeed` 18 → **28**. Closing is the cash-out, and the speedometer is already clamped to
    97–168°.
  - `Tuning.quietSpeed` 12 → **14**.
  - Re-run `tools/balance-sim.js` with ThiefPilot close speeds of 20–45°/s and opens of 10–30°/s (casual), and
    check that Hushed-bank rates hold.
  - Optionally, a first-runs ramp: noise ×0.8 for the first 3 runs (`SessionOptions.noiseScale`).
  - Add the defensive D3 setting below.
- **Verify:** BalanceTests at the new pilot speeds. Feel is founder-only.

### 2. Speed spikes at every start from still, and on stick-slip (H × H; the hardware decides how bad)
- **Mechanism:**
  - The Duo sends nothing while still, so every move starts after a silence longer than `restartGap` (0.25 s).
    `FeelSpeedEstimator.sample` then restarts with the first report as base (`FeelFilters.swift:251-266`).
  - The next report arrives 20–40 ms later. `windowSpeed` divides by `newest − base`, which is only that 20–40 ms
    (`:291`; the `minElapsed` floor is only 1/60 s, `:201`).
  - A free-stop hinge breaks away with a small jump, and the One-Euro-filtered move is divided by about 0.03 s.
    Hand-computed with the real filter constants:

    | Breakaway step | Interval | Reads |
    |---|---|---|
    | 1° | 33 ms | ~11°/s |
    | 2° | 33 ms | ~26°/s |
    | 2° | 20 ms | ~33°/s ("Slower…" > 30) |
    | 3° | 33 ms | ~44°/s |

    That lasts about 0.1–0.25 s, until the window refills.
  - **Stick-slip at a 6°/s mean** (2° slips every 0.33 s) restarts on every slip and reads about 26°/s each time.
    Any source above 0.01/s resets `quietFor` (`HeistSession.swift:304`), and the slips come faster than
    `decayGrace` (0.3 s), so the noise **never decays**. That is about +0.09/s of noise while the player does
    exactly what was asked: about 0.9 over a 10 s "perfect" open.
  - This is REVIEW-1-duo hardware risk 4 and REVIEW-2-duo question 5. Both are still unanswered.
- **What he sees:** "Slower…" and a creak the instant he starts moving, however gently. Over a long slow open the
  meter creeps up. "The lid moves in little jumps" (runbook step 4).
- **Fix (`Input/FeelFilters.swift`, `FeelSpeedEstimator`):**
  - **Breakaway floor:** while the samples since the last restart span less than 0.10 s, divide by
    `max(elapsed, 0.10)` instead of `minElapsed`. A 2° breakaway then reads about 9°/s. A real slam from rest is
    late by only about 70 ms and then reads true.
  - **Step deadband:** in `windowSpeed`, ignore a per-step `|Δ| < 0.4°` in the path term (report jitter).
  - **Persistence gate (`Core/Noise.swift` or `HeistSession.play`):** lid noise counts only once speed has been
    above quiet for ≥ 0.08 s. The creak and haptic can still react at once, so it stays honest.
- **Verify:** yes.
  - New `FeelTests` traces:
    - 0.5 s still, then a 2° step at 20 ms and at 33 ms: the peak stays under 12°/s;
    - stick-slip of 2° every 0.33 s: chest noise stays under 0.1 over 10 s;
    - a slam 150 → 100 in 0.25 s: still a bite.
  - `ci/duo.sh` STICK-SLIP: `hinge set` +2° every 0.35 s from 110 to 150. PASS if there's no `stage stirring`.
  - Ask the founder for D4's raw trace to confirm.

### 3. "Ease the lid shut to bank" means fold it shut, so every chest goes via the outer screen (H × M)
- **Evidence:**
  - The copy says "shut": `UI/PlayHUD.swift:13,33`, `App/LessonScript.swift:324`. The game's shut, though, is
    **100°** (`Tuning.swift:16,22`).
  - A real chest, and the founder's hand (Swoop: a natural fold "goes about halfway", deeper than designed), keeps
    going.
  - The bank fires at ≤ 110° after 0.35 s. The hand carries on to 0°. The inner display goes dark, and
    `noteCanvasClass` / `setPose` hold the closing pause (`GameController.noteCanvasClass`, `setPose`).
  - The next chest arrives under the pause (`AppRules.stepsThroughPause`). He must then reopen to ≥ 95° and hold
    still for 0.3 s (`HingeLidSource.swift:32-36`).
- **What he sees:**
  - After every bank: the outer screen ("Open to carry on"), reopen, "Hold still…", then the next chest.
  - It feels slow and broken: "it keeps going to the outside screen".
  - The runbook's steps 6–8 sit exactly on this path.
- **Fix:**
  - Copy: "Lower the lid **to upright** to bank" (HUD, StakeRow, lesson step 5). Add an "upright" tick on the lid
    plaque while there's loot in the bag.
  - After a bank, while the new chest is still `.ready` with nothing revealed, a reopen resumes **without** the
    stillness wait. The lid is silent below 97° anyway (`speedAngleRange`), and looting needs ≤ 110° first. Use
    `canResume` at ≥ 95° with no hold, plus `resumeGrace(0.8)`.
  - Keep the full rule for pauses taken mid-chest.
- **Verify:** yes. BANK-SHUT-REOPEN in `ci/duo.sh`: bank, 110 → 0 at 40°/s, 0 → 130 at 40°/s. PASS if the next
  `lidCracked` comes ≤ 1.5 s after crossing 95°, with no bite.

### 4. The pause coin sits under the lid hand (M × M)
- **Evidence:**
  - `Scene/SceneLayout.swift:74` still has `pauseArea = (594, 372, 56, 56)`: the floor's right corner, about 28 pt
    from the crease. That is where a right hand easing the lid rests.
  - REVIEW-2-duo P2-8 flagged it, and it was never moved.
  - It's a single tap (`PlayHUD.swift:130`). Runbook step 14 asks about it.
- **What he sees:** the pause menu pops up mid-chest. On Resume he waits on "Hold still…".
- **Fix:**
  - Move it to the bag strip's far corner (canvas about x 600–660, y 12–76), and move `Tuning.lootKeepOut`
    (`:170`) with it. The Daily seed's deal changes, but only from tomorrow's Daily on.
  - Or, during a live chest, make it a 0.35 s press-and-hold with a filling ring. Taps stay instant in the lesson's
    final card and menus.
- **Verify:** the frame shows the new position; an XCUITest checks that a 0.1 s tap doesn't open the menu mid-chest.

### 5. The upright rest sits near the hand-off: screens swap while banking (M × M)
- **Evidence:**
  - The sim handed off at 74.2° and 92.3° (REVIEW-2-duo P1-3).
  - The bank pose and the lesson's pose step (90–112°, `LessonScript.swift:104-105`) live right there.
  - Swoop's device evidence says the real inner display stays lit to at least about 90°, which lowers this risk.
- **What he sees:** with the lid resting upright, the inner screen goes dark or flickers onto the outer screen.
- **Fix:**
  - Keep all play above 95°. Make the "upright" bank cue 100–105° (item 3).
  - Read the device's real hand-off and relight angles from Diagnostics (runbook step 9). If the hand-off is above
    88°, raise `shutAngle` and `shutZoneAngle` by the difference.
- **Verify:** only on the device (the sim's hand-off is different).

### 6. Haptics feel weak, or are felt on the table, and playing well feels like nothing (M × M)
- **Evidence:**
  - Squish's founder: "Vibration felt weak".
  - The creak haptic is exactly 0 at ≤ 12°/s (`Feedback/FeelHaptics.swift:93-96`), so careful play gives no lid
    feel at all.
  - Which half holds the Taptic Engine is unknown (REVIEW-1-duo hardware question 9). If it is the floor, the table
    swallows it.
- **What he sees:** "I can't feel the hinge"; "haptics are weak".
- **Fix:**
  - Add a faint "safe" grain while opening quietly: one tick (0.18, 0.8) per 4° of quiet travel, Strong-adapted.
  - Expose Haptics: Off / Normal / Strong in Settings. `FeedbackDirector` already has the profile; only the UI is
    missing.
  - Lift the tells (`stirring` is 0.35 → 0.5).
- **Verify:** unit tests for the tick cadence; the feel is device only.

### 7. Resume friction at about 95° (M × M)
- **Evidence:**
  - `closingLifted` flips exactly at `effectiveResumeAngle` (`GameController.checkClosing`), so the card toggles
    "Lift the lid a little" ↔ "Hold still…" for a lid resting at 94–96° (±5° accuracy).
  - The resume wait needs a hinge motion under 6°/s for 0.3 s (`HingeLidSource.swift:32-36`). A hand still on the
    lid, plus item 2's breakaway spikes, can hold it off.
  - Swoop's rule: never put a pause line near 90°.
- **What he sees:** a flickering card, and "it won't carry on". R6's watchdog only steps in after 6 s.
- **Fix:**
  - Give `lifted` hysteresis: "Hold still…" from ≥ 92°, back to "Lift…" only below 88°.
  - `resumeSpeed` 6 → 10°/s once ≥ 100°.
  - Item 2's floor also feeds `motionMeter`.
  - R6's "Carry on" plate after 3 s.
- **Verify:** yes. HOVER-95: hold 95° with ±1° wiggles at 10 Hz. PASS if `resumed` comes within 2 s.

### 8. Lesson step 1 is strict and can't be skipped (M × M)
- **Evidence:**
  - The pose window is 90–112° held for 0.5 s (`LessonScript.swift:104-106`, `Tuning.swift:244-246`) against ±5°
    accuracy and a laptop rest of 105–125°.
  - `canSkip` only opens from step 3 (`LessonScript.swift:141`).
  - The lid cue words are drawn on the lid, which is the half that blurs as it lifts.
- **What he sees:** "Close the lid a little, nearly upright…" while he thinks it is upright, and no Skip on the
  first launch.
- **Fix:**
  - Pass the pose step after 0.5 s in 88–112°, **or** after 4 s anywhere in 80–125° ("That'll do.").
  - Offer Skip from step 1 after 20 s, and always on the pause menu.
  - Keep the duplicate line on the floor card (it already exists).
- **Verify:** yes. Unit tests on `LessonScript`; a sim POSE-LOOSE check at 118° for 5 s.

### 9. Upside-down system UI, and menus unreadable when picked up (M × L–M)
- **Evidence:**
  - Brim's founder: "system banners still came from the old end".
  - `project.yml:39` `UIRequiresFullScreen: true` means iOS never goes upside down. Notification, Game Center
    welcome, Control Centre and TestFlight's feedback sheet all draw at his near edge, upside down.
  - `AppRules.readsUpsideDown` needs 60–170° (`AppRules.swift:232-235`), so a Duo held **flat** at 180°, camera
    up, shows Home upside down with no explanation.
- **Fix:**
  - Extend `readsUpsideDown` to 170–180° on menus (not in runs).
  - Show Brim's one-time card: "Upside down on purpose: the chest goes on the half your Duo keeps sharp."
  - Defer `GameCenterManager.authenticate()` until Home after the lesson, so the welcome banner never lands on the
    lesson.
  - Leave the Release `UIRequiresFullScreen` drop (Brim build 12) for 1.0.1: it was never verified on a device.
- **Verify:** unit tests for the rule; the banner's own frame.

### 10. Near flat: a snap or detent, and relic reaches (M–L × M)
- **Evidence:**
  - Relics need about 156–161° (`Tuning.swift:141`).
  - The speedometer counts up to 168° (`HingeLidSource.swift:30`).
  - If the hinge snaps the last degrees toward flat (REVIEW-1-duo P1-9, unknown), the reach becomes a counted jump.
    Going flat was the stuck bug's trigger.
- **Fix:**
  - Cap the speedometer's range at 162° (it is `wideAngle + 3` today).
  - Treat any single report jump over 8° above 150° as a snap: no noise, plus a "That's wide enough" nudge.
- **Verify:** unit trace.

### 11. Finger tremor and drag noise (M–L × M)
- **Evidence:**
  - The lesson's Freeze needs a drag speed under 60 pt/s (`LessonScript.swift:113`). A finger resting on a coin
    makes sub-point moves at 120 Hz that can read 60+ pt/s.
  - Natural drags run at 1,000–2,000 pt/s, against the 350 quiet line (`Tuning.swift:53`).
- **Fix:**
  - Freeze judges a held item's *displacement*: still means less than 8 pt in 0.3 s.
  - Add a 2 pt deadband to drag speed.
- **Verify:** unit tests.

### 12. Heat (L–M × L–M)
- **Evidence:** REVIEW-2-duo P2-7. The policy only partly landed (`FeedbackDirector.swift:175-193`).
- **Fix:**
  - 60 fps unless a touch is down or the lid is moving.
  - 60 fps at `.fair` thermal state.
  - Cap Home's ticker at 60.

### Checked and unlikely
- **Phantom speed from a still lid:**
  - the Duo sends nothing while still;
  - ±0.5° jitter reads ≤ 1.6°/s (feel tests);
  - Brim's angle-driven pour at 1.55× gain passed the founder ("all good", Brim HANDOVER:8).
- **Silent switch:** the audio session is `.playback` + `.mixWithOthers` with self-healing (`FeelAudioEngine.swift:9-13,
  181-197`).
- **Permissions:** none are requested at first launch.
- **Game Center:** its sign-in sheet is never auto-presented (`GameCenterManager.swift:42-55`).
- **The cover "small chest flash":** the fallback was deleted in R3.

### Watch list for the R6 build itself (new risks it introduces)
1. **Menus flip and animate** when the Duo is tilted in the hand, now that menus allow both landscapes. Lock the mask
   to the current orientation whenever the hinge is 60–175°, not only in live runs, or turn the transition animation
   off.
2. **Keep `HingeReader` and the `SpriteView` outside the rotated subtree.** A rebuilt subtree re-inits `@State`
   (`enabled`), drops hinge updates and recreates the scene.
3. **Insets and deferred edges for k = 1 and k = 3.** A Home swipe on the long edge must still need two swipes in a
   run.
4. The watchdog's auto-resume must use `resumeGrace` and never fire on the cover display (`mayResume`).

---

## Cheap defensive changes (forgiving on unknown hardware)

- **D1. Calibrate in the lesson.**
  - In step 2 ("Open the lid… slowly"), log this player's speed while the lesson says nothing is wrong.
  - Set `quietSpeed = clamp(p75 × 1.15, 12, 20)` for the first 3 runs, then decay it back toward Normal.
  - Also record the hinge's breakaway peak, and use it as the start-of-move allowance.
  - Store it in `SettingsStore` (new field, decoded with a default).
- **D2. One input-hygiene layer** in `FeelSpeedEstimator`: the breakaway floor, the step deadband and the
  persistence gate (item 2). It's about 30 lines and fully unit-testable. It also protects `canResume`.
- **D3. "Lid sensitivity" in Settings › Controls**, Duo only: Careful / Normal / Forgiving.
  - It scales `quietSpeed` 12 / 14 / 18, `closeQuietSpeed` 22 / 28 / 34 and `loudSpeed` 26 / 30 / 38.
  - Route every reader through `Noise.quietSpeed(closing:)` (`Noise.swift:18`). Today `FeelHaptics` and
    `FeelSoundBook` read `Tuning.quietSpeed` directly.
  - The scored Daily always uses Normal.
- **D4. A hinge flight recorder** beside R6's event log.
  - The last 20 s of raw `(t, angle)` reports, plus each chest's peak speed and its noise from the lid vs drags.
  - It goes into the same Copy button. One device session then answers the rate, quantisation, stick-slip and
    hand-off questions for good.
- **D5. Always an alternative.**
  - "Use the on-screen lever" on the Duo, for a stiff or worn hinge (REVIEW-1-ux and REVIEW-2-ux asked for it).
  - Every hold plate shows "Carry on" after 3 s.
  - Skip is available from lesson step 1.

## Questions for the founder's next session (add to runbook §4)
1. Paste the D4 trace after one slow open, one natural open and one bank.
2. "Did it ever say Slower when you were barely moving?"
3. "When it said shut, how far did you close it?"
4. Which hand eases the lid, and where do its fingers rest?

# App engineer, Round 7 hand-off: real hands (28 Oct)

Source: `design/ROUND-7.md` (App items 1–7), `design/DEVICE-RISKS-1.md` (items 3, 4, 8, 9, 11, D3, D4, D5), and the
Core and Feel R7 notes (their names are used exactly). Nothing has been compiled (CI is the compiler). Nothing is
committed. R6's behaviour is kept; only the watchdog's angle and one copy line in its tests changed.

**Files**
- `Hush/App/`:
  - `AppRulesR7.swift` (new: every R7 pure rule);
  - `AppRules.swift` (`resumeAngle` 92, `readsUpsideDown(…, inMenus:)`, the "Nothing banked" story line);
  - `AppRulesR6.swift` (`watchdogResumes(…, resumeAngle:)`);
  - `LessonScript.swift`;
  - `GameController.swift`;
  - `HushApp.swift`.
- `Hush/UI/`:
  - `PlayHUD.swift` (`HushCopy.bankLid`, `ClosingCard(fresh:)`, the new `PauseCoin`);
  - `HushTheme.swift` (`BrassCoinFace`, split out of `BrassCoinButton`);
  - `Pages.swift` (`SettingChoice`, the two new rows, Copy log);
  - `RootView.swift` (`HoldHintBanner(inMenus:)`).
- `Hush/Persistence/SettingsStore.swift`.
- `HushTests/AppTests.swift`: new `R7Tests` (14 tests). Three old expectations were updated: two copy strings and the
  watchdog's 94° case, now 91°.
- `design/NEEDS.md`: answers for CI.

## The 7 items

1. **Copy, and the fresh chest.**
   - The copy never says "shut" any more:
     - the hint and the final card say "Ease the lid down to bank" (`HushCopy.bankLid`, 6 words);
     - lesson step 5 says "Ease the lid down to upright to bank it.";
     - the empty-run story says "Ease the lid down to bank your loot.".
   - A test checks that no fold copy contains "shut".
   - **Fresh chest:** `checkClosing` reads `session.isFreshChest`.
     - Over a fresh chest, `AppRules.closingResumes(canResume:freshChest:lifted:)` resumes the closing pause once the
       filtered angle reaches `hinge.effectiveResumeAngle`, with no stillness wait. It adds
       `resumeGrace(AppRules.freshResumeGrace)` (0.8 s) and logs `HUSH-T fresh chest resume` (and to the event log).
     - The card says "Lift the lid for the next chest" and never "Hold still…" (`closingFresh` is published).
     - A chest in play keeps the full rule. The cover-display rule (`mayResume`) still applies.
   - **Closing card and watchdog:** the card already used `hinge.effectiveResumeAngle`.
     - The watchdog now passes it too (`watchdogResumes(…, resumeAngle:)`).
     - `AppRules.resumeAngle` is 92 (= `HingeLidSource.resumeAngle`, tested). It is now only the pure rule's default.
2. **The pause coin** (`PauseCoin`).
   - It stays where it was, so `lootKeepOut` and the Daily's deal are unchanged.
   - It needs a press-and-hold when `GameController.pauseNeedsHold` (`AppRules.pauseNeedsHold(duo:phase:)`) is true:
     a Duo (a hinge seen or a fold layout) during a live chest (`.ready` / `.looting`, the lesson included). This is
     published from `publishHUD`.
   - While held, a gold ring fills over 0.35 s, and the pause fires at 0.35 s while the finger is still down.
   - A shorter press shows "Hold to pause" beside the coin for 1.6 s (`AppRules.coinPress`).
   - Phones, and the bank and bite moments, keep the tap coin (`BrassCoinButton`).
   - For VoiceOver it is a button with the hint "Press and hold to pause", and activating it pauses at once.
3. **The lesson** (`LessonScript`).
   - **Pose step:**
     - it passes after 0.5 s in 90–112° ("That's it."), as before;
     - or after 4 s anywhere in 80–125° (`looseMin/looseMax/looseHold`, "That'll do.");
     - the two clocks are independent.
   - **Skip:** `canSkip` is also true once the lesson has run 20 s (`skipAfter`, from its first update), still from the
     start on a replay.
   - **Freeze:**
     - `Input.held` (item id → floor point, filled by the controller from `.held` loot) feeds `HeldStillness`;
     - "still" means every held item stayed under 8 pt from each of its positions in the last 0.3 s;
     - `dragSpeed` no longer counts (`stillDragSpeed` is removed).
4. **Settings.**
   - `SettingsData` gains `lidSensitivity: LidSensitivity` (default `.normal`) and `vibration: HapticStrength?`
     (nil = unchosen, and not written at all).
     - Both are decoded tolerantly: an unknown or mistyped value falls back, and the other fields survive.
     - A stored `vibration` drives `hapticsOn` (`!= .off`).
   - `SettingsStore`:
     - `lidSensitivity` (saved);
     - `vibration` (`chooseVibration(_:)` also sets `hapticsOn`);
     - `shownVibration(chosen:hapticsOn:hasFold:)`.
   - `apply()` pushes a chosen strength to `FeedbackDirector.hapticStrength`, once per change. Unchosen, it pushes only
     `hapticsOn`, so the strength keeps following `deviceHasFold` (Strong on a Duo).
   - **UI:** the old Haptics toggle is replaced by the **Vibration** row (Off / Normal / Strong). A new **Lid
     sensitivity** row (Forgiving / Normal / Careful) always ends its detail with "The scored Daily always plays
     Normal." Both use `SettingChoice`, with pills that are full tap height and carry VoiceOver's `isSelected`.
   - Runs use `SessionOptions.for(m, sensitivity: settings.lidSensitivity)`. Core forces the scored Daily to `.normal`;
     the lesson keeps `LessonChest.options`.
5. **Copy log.**
   - `GameController.diagnosticsCopyText` = the event log + "\n\n" + `hinge.traceText()`
     (`AppRules.diagnosticsCopy`).
   - `EventLogPanel(copyText:)` puts it on the pasteboard.
6. **Game Center.**
   - HushApp no longer calls `authenticate()` directly. It calls `controller.authenticateGameCenterIfReady()`, which
     every `setRoute` calls too.
   - `AppRules.mayAuthenticateGameCenter` allows it only when the lesson is done AND the route is Home, or in demo
     runs. So the welcome banner never lands on the lesson or on the first run after "Got it". Scores and achievements
     queue until then (as before).
   - It asks once (`gameCenterRequested`). `authenticateGameCenter` is a replaceable closure, for the test.
7. **"Other way round".**
   - `readsUpsideDown(…, inMenus:)` runs to 180° on non-play routes (60–170° in runs).
   - The controller re-judges it on a route change too (`refreshHoldHint`).
   - In menus the banner says "Upside down on purpose: turn your Duo round ↻" (Home has no glowing half).

## Tests (`R7Tests`)
- `bankingSaysDownNeverShut`
- `aFreshChestNeedsNoStillness`
- `aFreshChestResumesOnTheLift` (the real controller: the first report at 40°, then a 40°/s rise; it resumes before the
  lid stops)
- `thePauseCoinNeedsAHoldOnADuoMidChest`
- `thePoseStepIsLenient`
- `skipComesAfterTwentySeconds`
- `freezeJudgesDisplacementNotDragSpeed` (±0.8 pt tremor at 140 pt/s passes; a 30 pt/s drift fails)
- `sensitivityAndVibrationPersistTolerantly`
- `theSensitivityChoiceIsKeptOnTheDevice`
- `theSettingsRowsSayWhatTheyDo`
- `theCopyLogCarriesTheHingeTrace`
- `gameCenterWaitsForTheLesson`
- `theOtherWayRoundBannerReachesFlatInMenus`
- `theWatchdogUsesFeelsResumeLine`

No mutating call sits inside `#expect`. The tests never call `SettingsStore.apply()` / `chooseVibration`, so the
shared `FeedbackDirector` is untouched.

## Risks
- **The fresh-chest resume also covers a run's FIRST hinge report** (the run starts with the lid shut, so the chest is
  fresh). If that first report is already ≥ 92°, the run resumes on the next frame without the 0.3 s stillness hold,
  which the R3 first-report guard used to wait for. Nothing can be lost: `hinge.reset()` gives a fresh speed base,
  the chest is `.ready`, and there is 0.8 s of grace. Any CI check that expects a stillness wait there should accept
  `HUSH-T fresh chest resume`.
- **`PauseCoin` uses `DragGesture(minimumDistance: 0)`.** A finger that slides off the coin still counts as held. The
  gesture's end always arrives, but if SwiftUI cancels it (a system gesture), `onEnded` may not fire. `onDisappear`
  resets the coin, and the next press starts afresh.
- **Settings frames change** (a new row, and Vibration replaces Haptics). The card is taller by about one row; on the
  smallest phones it scrolls in `PageScaffold` as before.
- **Not done:** the optional "first 3 runs × 0.8" ramp and D1's lesson calibration; Skip on the pause menu; a `sensitivity=`
  demo key (easy to add if CI wants it).

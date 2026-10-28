# App + Input + UI tests, Round 8 hand-off: "the player can never get stuck" (28 Oct)

Source: `design/QA-5.md` (4 P1s, 8 P2s). Nothing compiled here (CI is the compiler). Nothing committed. R6/R7 behaviour
is kept; no existing test expectation was changed.

**Files**
- `Hush/App/`:
  - `AppRulesR8.swift` (new: every R8 pure rule, and `MenuOrientationHold`);
  - `AppRulesR6.swift` (`settledInterface(…, device:)`, `showsPoseTip(…, cardUp:)`);
  - `OrientationLock.swift` (menu hold, `setHolds`, letterbox flag and heal, key-window and screen sizes);
  - `GameController.swift`;
  - `DemoMode.swift` (`hold=closing`).
- `Hush/UI/`:
  - `RootView.swift` (`SceneGeometryObserver`, the screen, the epoch, the refresh token, the probe);
  - `PoseCards.swift` (`CoverCard` escape plate);
  - `Pages.swift` (the turn-round row's pending line).
- `Hush/Input/HingeReader.swift` (`refreshToken`, API compatible).
- Tests: `HushTests/AppTests.swift` `R8Tests` (12 tests); `HushTests/FeelTests.swift` (1 test);
  `HushUITests/TurnedDragUITests.swift` (poll, fail, and a new odd-k tap test).
- `design/NEEDS.md`: answers for CI.

## The P1s

**P1-A: k goes stale when a hold is let go.**
- `SceneGeometryObserver` is a zero-size `UIViewRepresentable`. It KVO-observes its window scene's `effectiveGeometry`
  (documented as KVO-compliant) and calls `refreshWindowInsets()` on every change. That re-reads the insets, the
  screen and the interface now, and again at 350 and 900 ms.
- Every mask the app hands iOS bumps `GameController.orientationEpoch` (`OrientationLock.onMask` → `maskChanged`).
  RootView re-reads on it too.
- So a 180° turn with no size, inset or device change is seen at once, and k follows.
- `controller.interfaceChanged` now also re-captures a hold (run or menu) in the new interface, so the mask never
  disagrees with it.

**P1-B: the cover card on the inner display.**
- RootView reads the window's SCREEN (`OrientationLock.windowScreenSize()`, kept in `@State screenSize`).
- `AppRules.isLetterbox(window:screen:)` is true for a cover-sized window on an inner-sized screen that shares one of
  its sides, either way round (469 × 669 on 951 × 669).
  - Such a window PLAYS (`pose(window:screen:…)`).
  - It is the inner display for every rule (`displayClass`): no hand-off hold, no hand-off angle (this also closes
    P2-6), and resume is allowed.
- **Hedge (a deviation from the literal "screen only" rule).** A cover window that shares NO side with an inner
  screen keeps R3's window rule and stays the cover. So a stale screen can never make the real cover display
  (466 × 678) play. Transitions are safe for the same reason: cover ↔ inner sizes share no side.
- On a letterbox, `OrientationLock.letterboxed` stops any hold from capturing the column's orientation.
  `watchLetterbox` waits 0.5 s, then calls `healLetterbox()`: it drops the hold (in runs and menus) and asks for
  `allButUpsideDown`. It asks again every 2 s, up to 5 tries.
- **Belt and braces (the cover card's escape).** After 3 s on the cover card, if the last raw hinge report is ≥ 92°,
  the card shows "Already open?":
  - "Carry on" (runs): `coverOverridden = true`, the pose goes to play, then the closing "Carry on" path runs;
  - "Home": `coverOverridden = true`, then `goHome()`.
  - The override ends on a display change or when the Duo is shut (≤ 10°).
  - It never shows on a demo-forced cover.

**P1-C: a silent hinge.**
- `HingeReader(onUpdate:onUnavailable:refreshToken:)`: `refreshToken` defaults to 0, so the old call shapes still
  compile. Any change does the same 30 ms off/on re-subscription as activation does.
- The controller bumps `hingeRefresh` (`HUSH-T hinge refresh <reason>`):
  - on every cover ↔ inner change;
  - at 3 s on the closing card when no report has arrived since it went up (`closingSilenceCheck`);
  - on "Carry on" (hinge input only).
- After "Carry on", the reports in the next 0.5 s (`carryOnRefreshGrace`) are the re-subscription's own. They never
  close the card again, so a true low lid can't bounce the escape straight back.

**P1-D: the CI hole.**
- `waitForOddK` polls `debug.canvas` up to 15 s (an `XCTNSPredicateExpectation`) and `XCTFail`s if k never goes odd.
  It never skips. The failure message starts "`<label>` from …" so ci.yml's verdict grep catches it.
- The probe's value is `AppRules.canvasProbeValue`: `k= w= h= fold= iface=<o> held=<o>`.
- `HUSH-T iface` now ends with `held=`. The canvas line is unchanged, because tests and duo.sh read it exactly.

## The P2s
1. **P2-1:** `settledInterface` falls back on the device (`interfaceForDevice`, landscapes swapped) before
   `.landscapeRight`.
2. **P2-2:** Settings freezes the turn-round it opened with (`frozenTurnRound`, set before `route` is published), and
   the new value applies as Settings closes (`HUSH-T turn round applied`). The row adds "Turns round when you close
   Settings." while a change waits.
3. **P2-3:** `showsPoseTip` is false while the closing card or the menu is up (`cardUp`, forced or not).
4. **P2-4:** in menus on a Duo's inner display, with the hinge at 60–172°, the app holds its interface orientation,
   the same way a live run does (`MenuOrientationHold` → `OrientationLock.setMenuHold`).
   - It lets go below 55° or above 178°.
   - "Unless the interface genuinely changed for > 1 s" is implemented as: the hold only ENGAGES after the interface
     (or the display) has been unchanged for 1 s, so a real rotation finishes first.
   - k itself is never held against a real interface change: the drawing is fixed to the physical halves whatever iOS
     does, so holding k would draw it wrong-way up. Instead iOS is stopped from rotating.
   - A run ending at a tabletop angle hands its hold straight to the menu hold in one mask (`setHolds`), with no
     unlocked moment. This is P1-A's trigger, gone at tabletop angles.
   - Never in demo runs (DemoOrientation's asks would be refused).
5. **P2-5:** 3 s of silence on the closing card → `closingAwaitsHinge` → "Move the lid a little", until the next report.
6. **P2-6:** covered by `displayClass` (above).
7. **P2-7:** demo `hold=closing` plus `testLandscapeCarryOnTapsAtOddK`: poll for an odd k, tap "Carry on", and pass
   when the button goes.
8. **P2-8:** `watchSystemSheet` polls at 1 Hz from 2 s after the Game Center sheet is asked for, and clears
   `systemSheetUp` after two "no sheet" polls in a row.

## Tests (`R8Tests`)
- `aMaskChangeReReadsTheInterface`
- `aLandscapeWindowFallsBackOnTheDevice`
- `aLetterboxOnTheInnerScreenPlays`
- `aLetterboxIsNeverAHandOff`
- `theCoverCardOffersAWayOn`
- `theHingeIsReSubscribedWhenItMayHaveGoneSilent`
- `carryOnsOwnRefreshNeverClosesTheCard`
- `theProbeExplainsItself`
- `settingsNeverFlipsUnderTheFinger`
- `thePoseTipNeverCoversACard`
- `theMenuHoldRule`
- `menusHoldTheirOrientationAtATabletopAngle`

Feel: `hingeReaderKeepsItsAPIAndTakesARefreshToken`. No mutating call sits inside `#expect`. The menu-hold test
resets `OrientationLock.menuHold` at its end.

## Risks
- **Screen bounds on the Duo.** P1-B assumes `windowScene.screen.bounds` is the display the app is on. The hedge keeps
  the real cover display covered even if it is stale, but a Duo log should confirm: a `HUSH-T letterbox` line must
  never appear on a plain fold or reopen.
- **The menu hold is new.** It is the live-run hold applied to menus, so it inherits that hold's rules (captured
  from the real interface, dropped off the inner display, never while letterboxed). If a Duo log ever shows a
  letterbox after it, the heal runs. It is easy to switch off: return false from `menuHoldWanted`.
- **KVO on `effectiveGeometry`** is documented but untested here. The epoch and the old triggers still work without
  it.
- **The hinge re-subscription** may produce one `onUnavailable` (nil) callback while disabled. That is harmless: it
  only logs `hinge nil` once.
- **The new UI test** is non-fatal, like the drag. A phone sim that refuses landscape now FAILS the landscape drag
  instead of skipping, as asked.

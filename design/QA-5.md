# QA-5: "the player can never get stuck" (R6 + R7 tree)

*Senior QA, 28 Oct. Read-only: no source was edited. Scope: the founder's real-Duo P0 ("when i open the whole phone it
gets stuck and there is no way for me to continue playing") against the R6/R7 code (commits bfe5288 → 47cfeed). Line
numbers are as of 47cfeed. Nothing here was run on hardware. Findings marked "hardware-dependent" need a Duo or the Duo
sim to confirm.*

## Verdict

**Proved, with two hardware-dependent exceptions.** On every code path that behaves the way the Duo simulator does,
every state has a visible exit that needs no special knowledge and gets back to play or Home within 3 s. The two
exceptions:
- **The cover card shown on the inner display** (P1-B). It has no control, and it heals only through iOS.
- **A hinge that goes silent after a display hand-off** (P1-C). Only backgrounding the app recovers it.

Both are "stuck, no way to continue". Neither can be ruled out without a device, and both are cheap to close.

Two more P1s:
- **P1-A: a wrong-way-up picture.** k goes stale after the run's orientation lock is released.
- **P1-D: a CI hole.** The landscape (odd-k) drag test reads its probe too early and SKIPS, so the R6 P0 path has
  no passing UI evidence. This also explains the "874×402 window vs k=2 402×874 canvas" artefact.

There is no P0 in the code as written: nothing in the App blocks on orientation any more.

## 1. The state space and how it collapses

| Dimension | Values | Does it gate an exit? |
|---|---|---|
| Route | home, playing, lesson, results, codex, badges, settings, daily | Yes: decides which screen and controls are drawn |
| Pose (`AppRules.pose`, AppRules.swift:71) | play, cover | Yes: cover draws only `CoverCard`, which has no controls |
| Pause reasons (GameController.swift:28) | menu, closing, background, pose (any set) | Yes |
| Lesson step | 1 pose … 5 bank, 6 done (final card); praise beats | Only the Skip timing |
| Input | hinge, slider (phones), pilot/fixed (demo) | The closing pause exists only for `.hinge` |
| Interface orientation | portrait, landscapeLeft, landscapeRight (never upside down) | No: it only sets k |
| Canvas class | inner, small (`canvasClass`) | Yes: small means cover pose; resume is barred on small |
| k | 0…3 (fold), 0 (no fold) | No: k only rotates the drawing; every control rotates with it |
| Mask | portrait (phones); allButUpsideDown (Duo menus); one orientation (Duo live run on inner) | Only indirectly (letterbox, P1-B) |

**Observation.** The exit controls depend only on (route, pose, pause set, lesson step, input). k, the interface and
the mask change where things are drawn, not whether they exist. RootView always renders the turned layer
(RootView.swift:111-119), so a k change never removes a control.

The product therefore collapses to the cells below. Orientation then matters only through:
- whether k matches the interface (P1-A);
- whether iOS hands the inner display a cover-sized window (P1-B).

### Exit per state (pose = play, inner display unless noted)

| State | What is drawn | Exit | Time to exit |
|---|---|---|---|
| Home | Home | Play, Daily, Codex, Settings… | 0 s |
| Codex / Badges / Settings / Daily | PageScaffold | Done | 0 s |
| Results | ResultsView (only routed when `summary != nil`, GameController.swift:1484) | Again, Home | 0 s |
| Run or lesson, live, not paused | Chest + pause coin | Coin: tap (phones), 0.35 s hold on a Duo with a "Hold to pause" hint on tap | 0.35 s |
| Menu (`.menu`) | PauseMenu | Resume (into the closing gate on a hinge), Restart, Home | 0 s |
| Closing card (`.closing`) | ClosingCard | Home at once; **Carry on** after 3 s (GameController.swift:1038-1052); watchdog at 6 s if the last raw angle ≥ the resume line (:1064-1076); resumes itself when lifted ≥ 92° and still 0.3 s, or over a fresh chest on the lift | 0–3 s |
| "Move the lid a little" (no hinge report yet) | ClosingCard (awaiting) | Home; Carry on at 3 s (plays a shut lid; the first report re-holds, :922-929) | 3 s |
| `.background` only (inactive: Control Centre, a call banner) | Chest, coin visible | Return to the app clears it (:743-760) | — |
| `.background` (backgrounded mid-run, hinge ≥ 20°) | Menu opened (:775) | Resume, Restart, Home | 0 s |
| Lesson steps 1–5 | Step card, coin | Doing the step; Skip from step 3, from step 1 after 20 s of session time, any time on a replay | ≤ 20 s |
| Lesson step 1 paused (closing) | Closing card (the lesson card is hidden while paused, PlayHUD.swift:99-106) | Home, Carry on at 3 s | 3 s |
| Lesson final card | LessonFinalCard | Got it, "Not yet, take me home" | 0 s |
| Bank, bite or candle-out moment under a closing or pose pause | Moment plays through (`stepsThroughPause`) | Reaches Results; headless finish after 2.6 s if not drawn (:1438-1457) | ≤ 2.6 s |
| **Pose cover, mid-run or menus** (small canvas) | CoverCard, no controls | Reopen the Duo → inner canvas → pose play → closing hold → the card above | Reopen + 0.3 s |
| Game Center sheet up | UIKit sheet over the app (drawn k with turn-round off) | The sheet's own Done; dismissal → `systemSheetUp = false` (:1201-1206), also cleared on activation (:750-755) | 0 s |
| PoseTip (Home, lesson step 1, device landscape) | Small plate, non-blocking | ✕; it never blocks | 0 s |

### Transitions checked (trigger → result → exit)

| Trigger | Live run | Menus |
|---|---|---|
| Open to 180° and hold | No pause: `tooWide` hint only. A nil hinge context only logs (:936-941). A snap ≥ 150° credits no speed. Plays. | Plays (Home's chest). |
| Rotate the device in the hand, any angle | Mask locked to the captured interface (OrientationLock.swift:62-72): no rotation, k unchanged, correct. | Rotates; k follows the interface (RootView.swift:83-96). See P1-A and P2-1 for stale-k windows. |
| Face up or face down | No interface change. | Same; the tip hides (not landscape). |
| Close to the cover and reopen (fast, slow, partly) | Small canvas → hold and pose → CoverCard; reopen → inner → hold → closing card (resume angle lowered to the relight angle + 3, ≥ 90°). Partly: closing card + Carry on. | CoverCard; reopen. |
| Background and return | Menu (or the pause card if shut) → Resume → closing gate. Hinge resubscribed on `.active` (HingeReader.swift:43-53). | Fine. |
| A call | Inactive: quiet pause, clears on active. Answered: background → menu. | Fine. |
| Game Center | Not reachable mid-run. | Sheet; k drawn with turn-round off; restored on dismissal or activation. |
| Settings toggles | Not reachable mid-run (the pause menu has no Settings). | "Turn the chest round" flips the page under the finger (P2-2). Sensitivity and Vibration have no layout effect. |
| Lesson at each step | Each passes by doing, or by Skip ≤ 20 s; the closing card always has Home. | — |
| Hinge nil, or nothing, for a long time | Nothing: the lid holds its last angle (correct, the Duo is still). Paused: canResume matures on the clock; watchdog at 6 s; Carry on at 3 s. **A dead subscription is P1-C.** | Fine. |
| Interface and lock disagree | The lock is re-captured on every canvas-line change (GameController.swift:674-680 → OrientationLock.swift:106-112), so it converges. A letterbox is P1-B. | Unlocked. |

## 2. Findings

### P1-A: k goes stale (wrong-way-up) when the run's lock is released and iOS turns the interface 180°
- **Where:**
  - RootView.swift:166-185. The interface is re-read only on a window-size change, an inset change, a
    device-orientation notification or a scene phase, plus 350 / 900 ms later.
  - OrientationLock.swift:149-168. `setLiveRun(false)` widens the mask, and that can make iOS rotate without any of
    those triggers.
  - GameController.swift:1192 and :1464 (`lockForLiveRun(false)` in `goHome` and `handleFinished`).
- **Repro (Duo, or the Duo sim):**
  1. Hold the Duo upright like a book: device `.landscapeLeft`, interface `.landscapeRight`, k = 1.
  2. Start a run. It locks to `.landscapeRight`.
  3. Mid-run, turn the Duo 180° in the hand (device `.landscapeRight`). The interface stays put because of the lock.
     The notification re-reads `.landscapeRight`, which is correct.
  4. Hold the coin, then Home (or let the candle burn out).
  5. The mask widens and iOS rotates the interface to `.landscapeLeft`. The window is still 951 × 669 and the insets are
     symmetric in landscape, so there is no window or inset change. The device orientation did not change, so there is
     no notification either.
  6. RootView keeps `interface = .landscapeRight` and k = 1. It should be 3. Home, Results and the NEXT run (whose lock
     captures the true `.landscapeLeft`) are drawn 180° wrong (the lid on the sharp half) until the device is moved
     again.
- **Effect:**
  - Not a dead end: the scene and the overlays share k, so the touches still map.
  - It is exactly the "wrong way up, confusing" class the founder hit.
  - The same blind spot covers any rotation that commits more than 0.9 s after its trigger.
- **Fix (minimal):** in RootView, observe the key window scene's `effectiveGeometry` (KVO-compliant) and call
  `refreshInterface()` on every change.
- **Fix (smaller still):** have `OrientationLock.onMask` bump a published `orientationEpoch` on the controller, and in
  RootView call `.onChange(of: controller.orientationEpoch) { refreshWindowInsets() }`.
- **Test:** make the interface source injectable in RootView. Then assert that a mask change followed by an interface
  change, with the same window, re-runs `handleCanvas` with the new k.

### P1-B: the cover card drawn on the inner display has no control (hardware-dependent)
- **Where:**
  - AppRules.swift:77. `if hingeSeen && long < coverMaxSide { return .cover }` judges the *window*, not the screen.
  - RootView.swift:120-124. `CoverCard` (PoseCards.swift:272-320) has no button.
  - The only heal is GameController.swift:674-680 → OrientationLock.swift:106-112. It runs during a live run only, and
    it relies on iOS un-letterboxing by itself after the mask widens, without a geometry request.
- **Repro:** use the R2 mechanism (Duo run 40506125012): a mask that excludes the current interface on the inner
  display makes iOS run the app as a 469 × 669 compatibility column. Ways R6/R7 can still produce that for a moment:
  - Tap Play during a menu rotation, so `setLiveRun(true)` captures the outgoing orientation (OrientationLock.swift:152).
  - The cover-return `requestPortrait` (GameController.swift:787) races the re-capture at :679, which locks the
    pre-request orientation while the portrait request is still in flight.
- **Effect:**
  1. The column is cover-sized, so pose is `.cover`. The player sees "Open to carry on" on an open Duo, with nothing to
     tap.
  2. If iOS keeps the column after the mask widens (as R2 saw, "it stays there"), the only way out is backgrounding the
     app. That is the founder's exact sentence.
  3. As a side effect, the letterbox is logged as a cover hand-off, which poisons the Diagnostics hand-off angle (P2-6).
- **Fix:**
  1. `pose` should be `.cover` only when the window's *screen* is the cover display:
     `window.windowScene?.screen.bounds` long side < 760.
  2. A cover-sized window on the inner screen is a letterbox. Treat it as `.play`, clear the run's held interface
     (`lockedInterface = .unknown`) even outside live runs, and call
     `requestGeometryUpdate(.iOS(interfaceOrientations: .allButUpsideDown))`.
  3. **Belt and braces:** after 3 s on `CoverCard` with the last hinge angle ≥ 30°, show a "Home" plate (and in a run,
     "Carry on").
- **Test:** pure `pose(window:screen:hingeSeen:)` table: a 469 × 669 window on a 951 × 669 screen gives `.play`.

### P1-C: a hinge that goes silent after a hand-off is unrecoverable without backgrounding (hardware-dependent)
- **Where:**
  - HingeReader.swift:43-53 re-subscribes ONLY on `.active`. Its own header warns: "iOS may send no hinge change at
    all".
  - The watchdog needs the last raw angle ≥ the resume line (AppRulesR6.swift:184-185;
    GameController.swift:1069).
  - Carry on (GameController.swift:1026-1033) resumes whatever the hinge last said.
- **Repro:** fold to the cover display, so the last reports are low (≤ 10°, `isShut` latched), then reopen. If iOS moves
  the app back to the inner display without a scene-phase change, and the subscription delivers nothing:
  1. The closing card says "Lift the lid a little" on an open Duo.
  2. The watchdog never fires (the last raw angle is ≤ 10).
  3. Carry on resumes a frozen, shut lid: the chest can't be opened.
  4. Home and Play inherit the frozen angle (`start()` doesn't hold when `hinge.hasHinge`).
  5. Only backgrounding the app fixes it, and that is special knowledge.
- **Fix (about 10 lines):**
  - The controller publishes `hingeRefresh: Int`.
  - `HingeReader` takes it, and `.onChange(of:)` does the same off/on toggle it does on `.active`.
  - Bump it:
    - on every canvas-class change (`noteCanvasClass`);
    - in `startClosingWatch` when the card reaches 3 s with no `hinge.lastSampleTime` newer than the card;
    - on Carry on.
- **Test:** a controller test can assert the bump in each of the three places.

### P1-D: CI never exercises odd k; the "874×402 vs k=2 402×874" artefact is a test race, not a stale canvas
- **Where:** TurnedDragUITests.swift:71-79.
  - `canvas.waitForExistence(timeout: 6)` returns the moment the element exists, and `debug.canvas` exists from the
    first frame (RootView.swift:133-135).
  - The value is read once, before `DemoOrientation` makes its first landscape request (DemoMode.swift, first ask at
    0.4 s, re-asked every 2 s).
  - So it reads k = 2 and throws `XCTSkip`: "342 green" includes a skip on the R6 P0 path.
- **Why the app canvas wasn't stale:**
  - The probe's `w=/h=` and `k=` come from the same GeometryReader pass as the drawn frame (RootView.swift:38-42,
    276-285), so the app was laid out portrait at that instant.
  - XCUITest reports `app.windows.firstMatch.frame` in the DEVICE orientation, which was set to `.landscapeRight`
    before launch. A still-portrait app therefore reads 874 × 402.
  - `updateCanvas` (GameController.swift:669-698) and the scene's `quarterTurns` setter are idempotent and are called on
    every frame change.
  - The only in-app staleness found is P1-A (the interface state, not the geometry).
- **Fix:**
  - Poll the probe until k is odd (an `NSPredicate` on `value`, up to 10 s).
  - Then FAIL rather than skip, if the app logged `HUSH-T orient landscape ok`.
  - Add `iface=<o> held=<o>` to the probe value (RootView.swift:282) and to the `HUSH-T canvas` line, so the next
    artefact explains itself.

### P2s
- **P2-1: `settledInterface` falls back to `.landscapeRight`** (AppRulesR6.swift:52-61) when the window turns landscape
  before iOS's report does.
  - Effect: a portrait → landscapeLeft rotation in menus can draw k = 1 instead of 3 (180° wrong) for up to 350 ms.
  - Fix: fall back on `UIDevice.current.orientation` (device landscapeRight → interface landscapeLeft) before the
    constant.
- **P2-2: "Turn the chest round" flips the page under the finger.** Pages.swift:365 → RootView.swift:90 flips the
  Settings page 180° the instant it's toggled. The toggle is then at the mirrored spot.
  - Effect: not stuck, but disorienting.
  - Fix: show a one-line "Flipped. Tap again to undo" toast drawn in the NEW k.
  - Or apply the new k when Settings closes.
- **P2-3: the pose tip can cover the closing card.** It draws above the turned layer (RootView.swift:125-128). In lesson
  step 1 with the Duo held like a book, the closing card ("Move the lid a little", with Carry on and Home) sits on the
  same page, so the tip's plate can cover part of those buttons.
  - Fix: `tipOn` should also need `!controller.isClosingPaused && !controller.isMenuOpen`.
- **P2-4: menus re-rotate and flip as the Duo is tilted in the hand** (OrientationLock.swift:65; DEVICE-RISKS watch
  item 1 was not done).
  - Effect: not stuck. The iOS rotation animation plays over an instant k redraw.
  - Fix: hold the current orientation in menus too while the hinge is 60–175°.
- **P2-5: misleading copy after a nil context at flat.** After activation at a nil context at flat, the last angle is
  stale (for example 60°), so the card says "Lift the lid a little" on a flat Duo. Carry on (3 s) is the exit.
  - Fix: P1-C's refresh. Also, with no report for 3 s, say "Move the lid a little" (the awaiting copy).
- **P2-6: the Diagnostics hand-off angle is polluted.** Any small-canvas event is recorded as the hand-off
  (GameController.swift:704-722), letterboxes included, and that misleads the founder's device log.
  - Fix: record it only when the screen is the cover display (see P1-B).
- **P2-7: no UI test taps a SwiftUI control at odd k.** "Carry on", "Home", "Resume", "Skip" and the Settings
  ScrollView are untested at k = 1 / 3. Hit-testing through `rotationEffect` at 90° is assumed; R2 only proved 180°
  on hardware.
  - Fix: add a landscape demo with a forced closing hold (for example `hold=closing`). Tap the "Carry on" label, then
    assert that `hud.bag` reappears, or check `HUSH-T carry on`.
- **P2-8: a Game Center dismissal handler that never fires** leaves Home drawn with turn-round off until the next
  activation (GameController.swift:1201-1206, :750-755).
  - Effect: not stuck.
  - Fix: also clear `systemSheetUp` when `sheetIsUp()` turns false, polled at 1 Hz while it is set.

## 3. Odd-k checks (as asked)
- **k against the interface:**
  - The table (AppRulesR6.swift:30-43) matches ROUND-6 and is table-tested.
  - The scene and the SwiftUI layer both use `frame.turns` from the same render (scene via `updateCanvas`, :156), so
    they never disagree with each other.
  - The only way k can disagree with the real interface is a stale `interface` state (P1-A, P2-1).
- **Touches at odd k:**
  - The scene reads `touch.location(in: world)` (ChestScene.swift:714-728), which is right by construction. It is
    unit-tested for k = 0…3 at 951 × 669 and 669 × 951.
  - The XCUITest that should prove it on a real synthesized touch skips (P1-D).
  - SwiftUI controls rotate with their hit areas. Unproven at 90° (P2-7).
- **Safe areas at odd k:** `insets(_:quarterTurns:)` (AppRulesR6.swift:103-108) maps each drawn edge to the window edge
  it lands on (top → trailing for k = 1, which is right for a clockwise turn). Every page and HUD rect reads `info.insets`
  or `safeRect`, never the environment, because the inner GeometryReader ignores the safe area (RootView.swift:58).
  `deferredEdges` keeps the window bottom plus the floor-front edge. Nothing found wrong.
- **Wrong-way-up drawing:** only P1-A (persistent) and P2-1 (≤ 350 ms).

## 4. What to ask the device session (adds to the runbook)
1. After a fold to the cover and a reopen, does `HUSH-T hinge` / "hinge back" appear in the Copy log within 1 s
   (P1-C)?
2. Is there ever a "pose cover" line while the Duo is open (P1-B)?
3. After a run ends with the Duo turned 180° in the hand, do the log's interface line and k agree (P1-A)?

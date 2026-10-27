# App engineer, Round 6 hand-off: "any way up", never stuck (27 Oct)

Nothing here has been compiled (CI is the compiler). Nothing is committed.

**Files**
- `Hush/App/`:
  - `AppRulesR6.swift` (new: every R6 pure rule);
  - `AppRules.swift` (`.standUp` removed; pose, reason and fold rules);
  - `GameController.swift`;
  - `OrientationLock.swift`;
  - `DemoMode.swift`.
- `Hush/UI/`:
  - `RootView.swift` (rewritten);
  - `PoseCards.swift` (`StandUpCard` replaced by `PoseTip`);
  - `PlayHUD.swift` ("Carry on");
  - `Pages.swift` (`EventLogPanel`).
- `Hush/Persistence/EventLog.swift` (new).
- `HushTests/AppTests.swift`: new `R6Tests` (18 tests), plus old tests updated.
- `design/NEEDS.md`: answers to CI.

Scene's R6 API is used by its exact names:
- set `scene.quarterTurns = k` only (never `turned`, never `scene.size`);
- give `scene.layout` the portrait-equivalent layout;
- keep the SpriteView at the real window size.

## The 8 items

1. **`AppRules.quarterTurns(interface:turnRound:hasFold:last:)`**: the founder's table, written exactly.
   - No fold: 0.
   - `.unknown` keeps `last` (RootView passes the controller's current k).
   - `last` defaults to 0, so the 3-argument call in the brief compiles as written.
   - Tests:
     - `quarterTurnsTable`: all 4 × 2 × 2 cases, plus unknown;
     - `theLidPointsAtTheBlurringHalf`: the lid's window edge is the blurring side when on, and the opposite when off.
2. **Root content.**
   - `RootView` settles a `RootFrame` (pose, fold, k, interface) per window size:
     - the fold is judged on the **portrait-equivalent** canvas (`AppRules.portraitSize`);
     - the interface comes from `OrientationLock.interfaceOrientation()` (`effectiveGeometry`), and
       `AppRules.settledInterface` makes it agree with the window's shape, so a fold's drawn frame is always portrait.
   - Every SwiftUI screen is laid out in `AppRules.drawnSize(window:quarterTurns:)` (w/h swapped for odd k) and turned
     by `.rotationEffect(.degrees(90 * k))`, with `.animation(nil, value: k)`, about the window centre.
   - Insets follow `AppRules.insets(_:quarterTurns:)`, which generalises R2's swap. Deferred system-gesture edges
     follow `deferredEdges(live:quarterTurns:)`: the window bottom plus the edge under the drawn floor's front.
   - The rotated layer is always present (k = 0 is the identity), so a k change never swaps views.
   - Kept un-rotated, in the window's frame: the cover card, the hold-hint banner, the icon layer and the pose tip
     (which has its own gravity turn).
   - Game Center: `systemSheetUp` → the rule runs with turn-round off (in portrait that is R2's k = 0).
3. **The scene.**
   - `updateCanvas(_:hasFold:quarterTurns:)` takes the REAL window and builds the layout from `drawnSize`.
   - It sets `scene.quarterTurns`.
   - `scaleMode` is aspect-fill whenever the drawn frame is portrait.
   - The R2 `updateCanvas(_:hasFold:turned:)` remains as a wrapper (k = 2 / 0).
   - The canvas line is `AppRules.canvasLine`: `HUSH-T canvas <w>x<h> fold= turned=(k==2) k=`.
   - Test: `theSceneTurnsAndKeepsThePortraitLayout`.
4. **Book pose never blocks.**
   - `AppPose.standUp` is gone: `AppRules.pose` only knows `.play` / `.cover`.
   - "Play anyway", `playAnyway`, `portraitRefused`, `stoodItUp`, `liftedFromBook` and `liftSide` are removed. A Duo
     is a fold in every orientation, so `usesSlider` is false and it always uses the hinge.
   - **`PoseTip`** ("Stand it up like a little laptop", with ✕):
     - it shows only on Home and lesson step 1, on a Duo, while `UIDevice` says landscape (`AppRules.showsPoseTip`);
     - it is drawn upright to gravity (`AppRules.tipTurns(device:interface:)`) on the book's sharp page;
     - ✕ or passing lesson step 1 stores `seenTips["poseTip"]`, so it never shows again.
5. **Orientation.** `OrientationLock.mask(isDuo:liveRun:inner:interface:)`:
   - Duo: portrait + both landscapes, never upside down.
   - A live run, the lesson included, holds the orientation it was in on the inner display. The hold is re-captured
     whenever the canvas changes, and dropped off the inner display. That way the mask never disagrees with the
     interface (the R2 letterbox).
   - Menus are unlocked. The launch and cover-return portrait asks stay, and nothing depends on them.
6. **Never stuck.**
   - **Carry on:** after 3 s the closing card shows "Carry on" (primary), next to Home, which is always there. Tapping
     it does `hinge.reset()`, clears the closing pause, then `resumeGrace(0.8)`. After that, only a NEW hinge report
     can close the card again, so a stale low reading can't snap it back.
   - **Watchdog (founder's correction applied):** a pause held ONLY by the closing pause, on the inner display, up
     ≥ 6 s, with the last known angle ≥ 95° resumes the same way and logs `HUSH-T watchdog resume`. A shut or silent
     lid stays paused.
   - Overlay audit, and the exit each one has:

     | Overlay | Way back |
     |---|---|
     | Pose tip | ✕ |
     | Pause menu | Resume, Restart, Home |
     | Closing card | Carry on, Home, the watchdog |
     | Cover card | Reopen |
     | Lesson cards | Skip, Got it, "Not yet, take me home" |
     | Results | Again, Home |
     | Codex, Badges, Settings, Daily | Done |

   - Tests: `carryOnResumesAtOnce`, `theWatchdogRule`, `theWatchdogResumesAnOpenLidOnly`, `everyOverlayHasAWayBack`.
7. **Flat is fine.**
   - Audit: nothing in the App gates on 172–180°.
   - `hingeUnavailable()` only logs, once per nil run. It keeps the last angle and the hinge input.
   - The root cause of the founder's P0 was the landscape flip to `.standUp`, now gone. A flip mid-menu just changes k.
   - Test: `flatOpenKeepsPlaying`, which runs 176 → 180° for 4 s with no pause, too wide, nil context and a flip to
     k = 1.
8. **Event log.**
   - `EventLog` keeps a ring of 80 `{time, event, angle}` entries in UserDefaults (`hush.diag.events`), on the device
     only. It is in-memory for demo runs and tests.
   - What it logs: launch, pose changes and reasons, every pause reason, resume, Carry on, the watchdog, canvas lines
     (size, fold, k), interface and device orientation, masks, hinge nil and back, scene phase, and the pose tip.
   - The Diagnostics panel shows it newest first, monospaced, scrolling, with **Copy log** (`UIPasteboard`).
   - Tests: `theEventLogKeepsTheLastEighty`, `theEventLogPersistsOnTheDevice`, `theControllerLogsTheEvents`.

## Founder: getting the log after a device test
1. Open Hush. On Home tap **Settings** (the gear).
2. Tap **About** to open it.
3. Press and hold the grey **Version …** line for **2 seconds** (it clicks). Diagnostics opens, with the EVENT LOG
   under it.
4. Tap **Copy log**, then paste it into a message to Claude.

The log keeps the last 80 events across launches, so you can do this after the app restarts.

## Demo keys and logs (DEBUG)
- `quarter=<0..3>` forces k, but only on a fold and when its parity fits the window.
- `fold=1;orient=landscape` gives a phone sim the Duo mask.
- `screen=pose` / `pose=book` force the pose tip on Home.
- `debug.canvas` is an accessibility element valued `k= w= h= fold=`.
- New logs:
  - `HUSH-T pose tip shown|hidden|dismissed`
  - `HUSH-T carry on`
  - `HUSH-T watchdog resume`
  - `HUSH-T hint tooWide`
  - `HUSH-T iface <o>`
  - `HUSH-T hinge nil`
  - `held=` on the `HUSH-T mask` line
- No `HUSH-T pose standUp` line exists any more.

## Risks
- **Hit-testing and accessibility frames through `rotationEffect` at odd k.** SwiftUI transforms both. R2 relied on
  this at 180°, but 90° is new. CI's landscape drag is the check.
- **Stale interface reads.** RootView re-reads the interface on window change, inset change and device notifications,
  plus 350 ms and 900 ms later. A 180° landscape flip that changes neither the size nor the insets would wait for the
  device notification.
- **The closing card's height.** It is a row taller when "Carry on" shows. On a 393 pt phone's fold floor it may come
  close to the meter (compact metrics apply).
- **Removed tests.** The book card's copy and lift tests were deleted with the feature, and the Play-anyway half of the
  handover test was replaced.

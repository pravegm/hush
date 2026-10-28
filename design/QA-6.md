# QA-6: release-candidate audit (R8, R9, R10 on top of QA-5)

*Senior QA, 28 Oct. I read the code only and edited no source. I ran nothing on a simulator or on hardware.*

*Scope: `git diff d4cbd33 HEAD -- Hush HushTests HushUITests`. That is R8 (16724a2), R9/R9b/R9c (5d50e2c, ecb97a3,
d939921, d6d0e2c), the Duo CI fix (7c77c5a) and R10 (ed92bbb), up to c6e046c. I also re-checked the store, review and
privacy text against the code. Line numbers are as of c6e046c.*

## Verdict: ship build 1.0 (4), but fix two things first

There is no P0 and no code P1. The RC binary can ship. Before you press Submit:

1. **Correct the App Review notes and the privacy-policy sentence (P1-1, P1-2).** Neither change needs a new build:
   the notes live in App Store Connect and the policy on the site.
2. **Get the founder's real-finger check at an odd k (P1-3).** Nothing in CI has ever passed a touch on a quarter-turned
   (landscape) layout. That layout is the founder's own P0 path.

Every P2 can wait for 1.0.1. If a build 5 is cut for any other reason, take P2-1, P2-2 and P2-4.

## 1. QA-5 items: are they fixed?

| QA-5 item | Fix in the code | Status |
|---|---|---|
| **P1-A** k goes stale after a hold is released | Three changes: <br>• `SceneGeometryObserver` KVO on `effectiveGeometry` (RootView.swift:65, :352-401). <br>• `orientationEpoch` is bumped on every mask (GameController `maskChanged`), and RootView.swift:76 re-reads on it. <br>• `interfaceChanged` re-captures any hold. <br>A run that ends at a tabletop angle hands over to the menu hold in one mask (`setHolds`), so it never passes through an unlocked moment. | **Fixed** |
| **P1-B** cover card on the inner display | Three changes: <br>• `AppRules.isLetterbox` / `pose(window:screen:)` / `displayClass` (AppRulesR8.swift:17-42). <br>• `watchLetterbox` heal: 5 tries, then `requestGeometryUpdate`. <br>• After 3 s at 92° or more, the card shows "Already open? Carry on / Home" (PoseCards.swift, GameController.swift:937-1005). <br>The hedge keeps a real cover display covered even when the screen size is stale. | **Fixed** (hardware-dependent; see P2-3 for one residual compound case) |
| **P1-C** a silent hinge | `HingeReader(refreshToken:)` (HingeReader.swift:69-71). It is bumped on display change, after 3 s of closing silence, and on Carry on. `carryOnRefreshGrace` stops a re-subscription report from closing the card again. | **Fixed** |
| **P1-D** odd-k UI test skipped | Two changes: <br>• `waitForOddK` polls, then fails. <br>• The probe now carries `iface= held=`. <br>**But** the odd-k drag and Carry-on tests now skip on both CI targets: <br>• the phone job doesn't run the landscape tests (5d50e2c); <br>• the Duo sim skips them with `win=0` (d6d0e2c). | **Closed as a test defect; the evidence gap remains (P1-3)** |
| P2-1 settled-interface fallback | `interfaceForDevice` (AppRulesR6.swift:58-62) | Fixed |
| P2-2 Settings flips under the finger | `frozenTurnRound` (GameController.swift:1553-1560), plus the pending line on the Settings row | Fixed |
| P2-3 pose tip over a card | `showsPoseTip(cardUp:)` | Fixed |
| P2-4 menus re-rotate in the hand | `MenuOrientationHold` (AppRulesR8.swift:126-147); see §2.4 | Fixed |
| P2-5 misleading copy after silence | `closingSilenceCheck` → "Move the lid a little" | Fixed (but see P2-2) |
| P2-6 polluted hand-off angle | `displayClass` | Fixed |
| P2-7 no odd-k SwiftUI tap test | `hold=closing` plus `testLandscapeCarryOnTapsAtOddK` | Test written, but never passes in CI (P1-3) |
| P2-8 Game Center dismissal never fires | `watchSystemSheet` polls at 1 Hz | Fixed |

## 2. The focus areas

### 2.1 DEBUG and demo diagnostics leaking into Release: clean, with one nit

- **Logging is off in Release.**
  - `AppTrace.t` takes an `@autoclosure`, and its body is `#if DEBUG` (AppTrace.swift:17-23). So every
    `HUSH-T touch / iface / hinge refresh / letterbox / menu hold` string is never even built in Release.
  - `FeelHingeLog` is gated the same way.
- **The demo path is unreachable in Release.**
  - `demo` comes from `#if DEBUG` (DemoMode.swift:239), so `isDemo` is always false in Release.
  - Everything R9 added is guarded by `isDemo`: `noteTouch`, `floorTouchMoved`'s trace, `refreshDebugState`
    (GameController.swift:454-532), `DebugStateElement` and `canvasProbe` (RootView.swift:145-148).
- **No DEBUG-only symbol is referenced from Release code.**
  - `DebugWindowTouchCounter` exists only under `#if DEBUG` (DebugTouchCounter.swift:4).
  - Its only two references are inside `#if DEBUG` too (GameController.swift:517, :528).
  - The TestFlight archive of build 4 compiled, which confirms this.
- **What does reach Release:**
  - a `DebugStateProbe` object, allocated once;
  - some R9 pure helpers that are never called;
  - **P2-1** below (one string allocation per touch).
- **No diagnostic UI appears in Release.**

### 2.2 R10 pause coin and seat: one source of truth for every k and inset. Holds.

- **There is one point.** `AppCanvas.pauseSeatCanvasCenter` (Layout.swift:272) is the coin's own clamped centre, taken
  back through `CanvasFit.canvasPoint`.
  - RootView hands it over on `onAppear` and on `onChange(of: info)` (RootView.swift:282-283).
  - A new scene picks it up in `makeScene`.
  - The hint plate is measured against the same rect.
  - So the coin and its seat coincide by construction, for any window, k or inset, not only the tested ones.
- **What is tested:** both Duo windows × k = 0…3 × 4 inset sets (AppTests.swift:3207), plus the phone without side
  insets.
- **Residual: a one-frame lag.** When `updateCanvas` rebuilds the scene before `onChange(info)` fires, the new scene
  draws one frame at the old centre. This is invisible.
- **Test gap (P3):** no phone window carries a side inset, and the 375 × 667 shape is not in the k table.

### 2.3 Settings on the Duo and on the phone

- **Every row can be reached.**
  - Each half has its own `FadingScroll`.
  - **Done** sits outside the scroll (Pages.swift:22-60).
  - `scrollBounceBehavior(.basedOnSize)` and the end-aware fade mean nothing is ever stuck under the fade.
  - The phone keeps one column.
- **Open risks:**
  - **The VoiceOver order across the two halves (P2-4).**
  - **No odd-k scroll evidence** (part of P1-3).
  - Design note: Sound, Vibration, Lid sensitivity and Play sound on silent now sit on the LID half, the half you push
    and the one that blurs. That goes against AppCanvas's own rule: "On a Duo the main buttons go on the FLOOR half
    (Layout.swift:215)". It is not stuck. A tap on the raised half moves the hinge in menus, which is harmless. Ask
    the founder whether it feels right on the device.

### 2.4 The menu orientation hold (R8). It can't leave the UI wrong-way-up or stuck.

- **It cannot draw wrong-way-up.** The drawing is fixed to the device whatever iOS does: an iOS turn of 180° plus a
  k change of 2 adds up to 0. So holding the interface changes only whether iOS plays a rotation, never what the
  player sees.
- **It cannot get stuck:**
  - it engages only after 1 s of calm, at 60–172°;
  - it lets go below 55° or above 178°, on leaving the inner display (`noteCanvasClass` → `refreshMenuHold`), and on
    a run start (`setHolds(true, false)`);
  - a letterbox captures `.unknown`, which means unlocked (OrientationLock.swift:79-85, `captureNow`);
  - if iOS turns anyway, the hold is re-captured, so the mask never disagrees with the interface.
- **A silent hinge** (P1-C) can leave it on, but that only means "no iOS rotation in menus", which is harmless.
- **Phones and demo runs never hold** (`isDuo`, `!isDemo`).
- **Residual P2-5:** a system sheet opened during a hold stays in the held orientation (see the P2 table).

### 2.5 Performance at 120 and 60 fps. Nothing new per frame is costly.

**Per frame:**
- `advance` sets `scene.pauseSeatHidden` (GameController.swift:370), which is a compare-guarded setter;
- `dimSeat`;
- `refreshDebugState` (it returns at once in Release);
- PlayLayer recomputes `pauseSeatCanvasRect()` on its body, which is a few float operations.

**Per hinge sample:**
- `refreshMenuHold` (GameController.swift:1191): a struct update, and it touches the mask only when the hold flips
  (with hysteresis).

**Event-driven:**
- the `effectiveGeometry` KVO (on geometry changes only; the observer re-attaches only per scene);
- the epoch;
- `refreshWindowInsets`. It starts a 0.9 s Task each time, but the callers are rare.

The refresh loop converges: a mask re-capture happens only when the interface really differs, so epoch → re-read →
same interface → stop.

**Timers:**
- the cover watch at 2 Hz, and only while the cover card is up;
- the letterbox heal, at most 5 tries;
- the Game Center poll at 1 Hz, and only while the sheet is up;
- the menu-hold settle, a one-shot.

None of them runs during play. The only new main-thread I/O is that each `note()` writes the 80-entry event ring to
UserDefaults (EventLog.swift:74-80). R8 adds a note per mask change and per hinge refresh: rare, and never per frame.

### 2.6 Persistence. Tolerant, with correct defaults.

- **SettingsData** (SettingsStore.swift:28-41): every key uses `decodeIfPresent` with its own default. An unknown
  `lidSensitivity` falls back to `.normal`. An unchosen `vibration` stays nil and follows the device.
- **EventRing:** a bad array decodes as empty, and the ring is capped at 80.
- **Nothing persisted is new in R8–R10.** `frozenTurnRound`, `coverOverridden` and the menu hold live in memory only,
  so a relaunch starts clean.

### 2.7 Never stuck, re-proved for the new states

| New state | Exit |
|---|---|
| Cover card's escape | Carry on or Home after 3 s at 92° or more. The card's own words ("Open me gently") lead there. The override ends on a display change or on a shut lid. |
| Closing card after a silence refresh | The same Home, Carry on at 3 s and watchdog at 6 s as before. |
| Carry on with a truly low lid | It plays a shut lid. The first new report re-holds (by design, QA-5). |
| Settings split | Done is always on the floor half, outside any scroll. |
| R10 coin hidden (menu, closing card, final lesson card, bite) | Each of these cards has its own exits. |
| Demo `hold=closing` | Demo only. |

Nothing new blocks. One compound, hardware-dependent case remains (P2-3).

## 3. Findings

### P1-1: the App Review notes describe the R3 game, not build 4
**Where:** docs/appstore/review-notes.md:29-35; its check table, :76-79; and the HANDOVER.md:62 claim that "review notes
… match the build". Each sentence below is false against the code:

| Line | The notes say | The code (build 4) has |
|---|---|---|
| :29 | "if iOS keeps it in landscape, 'Play anyway' offers the lever" | Gone since R6. PoseCards.swift:81 says the R3 blocking card and its "Play anyway" lever path are gone. Hush plays in any orientation. |
| :30 | "held like a book, a card shows which half to lift" | A small, dismissible "Stand it up like a little laptop" tip. Nothing blocks. |
| :32 | "above 168 degrees makes none" | The speed range is 97…162 (HingeLidSource.swift:42, `min(wideAngle + 3, 162)`). |
| :35 | "RESUME at 95 degrees" | 92°, releasing at 88 (AppRules.swift:41, HingeLidSource.swift:45). |
| :34-35 (missing) | Nothing about the way out of a pause | The pause card shows **Carry on** and **Home** after 3 s, and the watchdog resumes it after 6 s. The cover card offers "Already open?". |
| (missing) | Nothing about pausing on a Duo | The pause coin is a 0.35 s **press-and-hold** mid-chest ("Hold to pause"; AppRulesR7.swift:25). A reviewer who taps it will think pause is broken. |

- **Scenario:** a reviewer with a Duo holds it like a book and looks for "Play anyway". Or they tap the pause coin and
  nothing happens. The result is a 2.1 "can't verify" rejection, or worse, a 2.3 accuracy rejection.
- **Minimal fix:** rewrite §2 a, c, e and f, and add a line on press-and-hold, keeping the whole block under 4,000
  bytes (it is 3,915 now, so cut §4 to make room). Update the check table's numbers. No build is needed.

### P1-2: the privacy policy says the hinge reading "isn't stored". It is.
- **Where:**
  - docs/privacy.html:45 and docs/appstore/privacy.md:63: "never leaves your iPhone and isn't stored".
  - review-notes.md:29: "only the last screen-switch angle is kept".
- **The code (since R6) stores it:**
  - `EventLog` keeps the last 80 events, each with its hinge angle, across launches in UserDefaults `hush.diag.events`
    (EventLog.swift:55-80, GameController.swift:286-288).
  - It also keeps `hush.diag.handoff` and `hush.diag.relight` (GameController.swift:347-348).
  - These are in the device backup.
- **What stays true:** the "Data Not Collected" label (nothing leaves the device unless the user taps Copy log).
- **Scenario:** a 5.1.1 reviewer, or a user, reads the policy, and it is untrue.
- **Minimal fix:**
  - **Doc only (preferred for the RC):** "…never leaves your iPhone. A short on-device diagnostics log (the last 80 game
    events, with the lid angle) is kept on the phone and is never sent."
  - **Or code (build 5):** pass `angle: nil` from `note()` in Release builds.

### P1-3: no passing automated evidence of ANY touch at an odd k (hardware gate)
- **Where:**
  - HushUITests/TurnedDragUITests.swift:111-113 skips on `win=0` (the Duo sim);
  - 5d50e2c: the phone CI doesn't run the landscape tests;
  - docs/HANDOVER.md:60-61 says they "pass or skip on a phone simulator", which in practice means they skip.
- **Scenario:** the founder's own path: opened flat → iOS goes landscape → stood back up → iOS doesn't rotate back
  (HANDOVER.md:13-15). The game then plays at k = 1 or 3. If the SKView drag or a SwiftUI tap (Carry on, Settings
  scroll) misbehaves under a 90° `rotationEffect` on hardware, the P0 returns as "can't play" rather than "stuck".
  R2 proved only 180° on hardware.
- **The code looks right:**
  - the scene inverts its own world transform (unit-tested for every k);
  - the overlays share k;
  - fix-k3-drag.md worked the numbers by hand.
- **Minimal fix (verification, not code):** make HANDOVER "Please try" step 2 a release gate. With the Duo in book
  pose, or after the flat-open recovery:
  1. drag a coin into the bag;
  2. tap the pause coin (hold it), then **Resume**;
  3. scroll Settings and tap **Done**;
  4. close the lid until the pause card shows, wait 3 s, then tap **Carry on**.

  In the Copy log, the canvas line must show an odd k. If the founder can't run it, ship: the risk is play at one
  pose, not a dead end, because Home is reachable. Then put it first in 1.0.1.

### P2s

| # | Sev | File:line | Scenario | Minimal fix |
|---|---|---|---|---|
| P2-1 | P2 | Hush/Scene/ChestScene.swift:728-741 | The R9b `rawTouchesBegan` and `lastRawTouch` run in Release. Every touch-begin pays a second `location(in:)` and builds a string (`"canvas(..)view(..)"`). This is not per frame and does no I/O, but it is diagnostic code outside both `#if DEBUG` and `isDemo`. | Wrap the counter and the string in `#if DEBUG`, and keep `beginTouch` as before. `debugStateLine` already reads `scene?.rawTouchesBegan ?? -1`, so expose stubs (or gate that line too). |
| P2-2 | P2 | Hush/App/GameController.swift:1340, :1353-1358; PlayHUD.swift:322 | The common case: the player rests the lid at about 60° and the closing card says "Lift the lid a little to carry on". No report arrives while the lid is still, so at 3 s `hingeSilent` is true on a healthy hinge. The copy flips to "Move the lid a little", the hinge is re-subscribed, and (if iOS re-delivers) the copy flips straight back. It is a flicker at the same moment Carry on appears, and VoiceOver may re-read it. | Set `closingAwaitsHinge` only if no report has arrived about 1 s AFTER the refresh: keep the refresh at 3 s, and check the copy again at 4 s. |
| P2-3 | P2 (hardware, compound) | GameController.swift:937-975 | P1-B and P1-C together, when the screen reads cover-sized: the cover card is on an open Duo, no display-class change bumps the hinge refresh, and the last raw angle is stale at 10° or less. The escape needs 92° or more, so it never shows, and only backgrounding the app recovers. | In the cover watch, once at 3 s: if `hingeSilent(lastSample:since: coverSince)`, call `refreshHinge("cover silent")` (mirroring `closingSilenceCheck`). Optionally also show Home after 10 s whatever the angle. |
| P2-4 | P2 (verify) | Hush/UI/Pages.swift:22-50 | On a Duo, Settings is two sibling groups: the lid half (title, Sound, Vibration, Sensitivity, Silent) and the floor half (Turn round, Reduce motion, Replay/About/Credits, Done). The default k = 2 (turned round) draws the lid half at the screen's iOS-bottom. If VoiceOver orders those siblings by screen position, it reads "Turn the chest round … Done" before the "Settings" heading. The same applies at k = 3. | On the lid group, add `.accessibilitySortPriority(1)` inside a `.accessibilityElement(children: .contain)` parent. Confirm with VoiceOver on the device at k = 0 and k = 2. |
| P2-5 | P2 | GameController.swift:1083-1100 | A Game Center sheet (or the share or copy UI) opens while the menu hold is on, and the user turns the Duo. The sheet stays in the held orientation, sideways to the user. Its Done still works, so this is not stuck. | Pass `menus: !systemSheetUp` into `menuHoldWanted`, and call `refreshMenuHold()` whenever `systemSheetUp` changes. |
| P2-6 | P2 | docs/appstore/metadata.md:57, :67, :108, :118; ci/duo-store-scenarios.txt:35 (D3 "Ease it shut to *bank*."); screenshots.md:43; support.html:69; index.html:70, :143; press-kit.md:95; social-launch.md:39, :48; accessibility.md:8 | The store copy says "ease the lid shut". The app's own copy since R7 says "Ease the lid down to bank" (PlayHUD.swift:22, LessonScript.swift:401), and HANDOVER says "never 'shut'". The review notes promise Hush "never asks the user to close the phone". | "ease the lid down to bank it". D3: "Ease it down to *bank*." (5 words). Rebuild the D3 frame only if the caption is burnt in. |
| P2-7 | P2 | metadata.md:92 ("switches for sound, haptics and Reduce motion"); its check table :280 (`closeQuietSpeed` 18 → 28, R7), :294 (resume 95 → 92), :299 ("Sound and Haptics switches") | Since R7, Vibration is Off / Normal / Strong, and Lid sensitivity was added. | "Settings has Sound, Vibration, Lid sensitivity and Reduce motion". Fix the three table cells. |
| P2-8 | P2 (evidence) | docs/PROJECT-LOG.md:94; duo.yml is manual | The "13 / 13 PASS" Duo run is dated between 7c77c5a (05:34) and R10 (06:25), so it predates R10. Duo-06 (the seat at k = 1), duo-h3 and duo-ui-settings have not been seen on R10 code. r10.md asks for exactly that check. | Dispatch duo.yml (`hinge frames ui`) on c6e046c, and look at duo-06 and the Settings frames before submitting. |
| P2-9 | P3 | Hush/Scene/SceneFloorHUD.swift:396-401; ChestScene.swift:433 | The seat's fade runs on FX time, which stops 0.4 s after the session pauses. Under the menu or closing card it ends at about 1.5 % alpha, never below the 1 % hide line. That is invisible, but "fades right out" is not literally true. | Pass the wall-clock `dt` to `dimSeat` (it is cosmetic, not sim state). |
| P2-10 | P3 | PoseCards.swift:316-319 | The cover card's "Already open?" plate appears 3 s later with no VoiceOver notice. | Post `.layoutChanged` when `coverEscape` turns true. |

## 4. For the device session (adds to HANDOVER "Please try")
1. Run P1-3's four odd-k touches, and read the k in the Copy log.
2. At the default turn-round, run VoiceOver through Settings: does it start at the "Settings" heading (P2-4)?
3. Fold to the cover and reopen five times. Does `hinge refresh display` appear, followed by a hinge line, within
   1 s? Is a `letterbox` line ever logged on a plain fold?

# REVIEW-2: Duo specialist (27 Oct)

*Reviewer: the studio's iPhone Duo specialist. Read: REVIEW-1-duo, ROUND-2, notes app/feel/scene/ci-R2 (including
the 469 × 669 root cause), `App/OrientationLock`, `UI/RootView`, `App/GameController`, `App/AppRules`,
`App/LessonScript`, `Input/HingeLidSource`, `Input/FeelFilters`, `Scene/ChestScene`, and `project.yml`.*

*Evidence:*
- *the Duo sim runs `artifacts/duo3` (the fixed run) and `artifacts/duo2` (the regression): `checks.tsv` and
  `logs/*.txt`;*
- *the phone frames of the Duo layout, `ci6/screenshots/30–39`.*

*No source edited.*

## Verdict

**Score: 7.0 / 10 for the Duo experience (R1: 6.0). Launch: NOT YET.**
- First, one small fix (P0-1 below: the cover-display fallback) plus P1-2 and P1-4.
- Then one founder device session decides. I expect about 8 once those three land and the device session is clean.

**What R2 got right:**
- **Resume rule (`canResume`).** The reopen waits for an open, still lid, measured on its own unclamped motion meter.
  - On the sim: the app paused at 62.7°, rested the noise from 0.60 to 0.50, and resumed at 117.9° only after the
    reports stopped (`reopen.txt` 655–662). No bite.
  - Cover → reopen resumed at 134.1° with the noise at 0.00, and it rose to only 0.20 on a 40°/s finish
    (`frames.txt` 839–851).
- **Turning round inside the scene.** Touches are read in `world`, and a real XCUITest drag through the SpriteView
  passed.
- **The speed clamp to 97–168°.** On the sim, 104° → 61° made no noise (`reopen.txt` 647).
- **The closing pause moved to 70°.** UPRIGHT-NO-PAUSE passes.
- **Smaller fixes that landed:**
  - the menu opens only on background;
  - the lesson window is 90–112° (`LessonScript` 87–88);
  - the camera-up "Other way round" banner;
  - relic depth is reachable at about 157°.
- **The orientation fix after the regression is correct.** It locks portrait only once the interface is portrait,
  and asks for portrait while landscape. PORTRAIT now passes: 669 × 951, fold=1, turned=1.

**What still blocks launch:** the regression's "belt and braces" fallback misreads the **real** cover display, and the
sim shows it doing so twice (P0-1). Two smaller problems remain:
- the book-pose card can no longer be seen;
- a Duo run can start on the lever and take its first lift unguarded.

## R1 issues: status

| R1 | Issue | Status | Evidence / caveat |
|---|---|---|---|
| P0-1 | Book pose → tabletop lock-out | **Fixed** | Brim's `requestPortrait` / `adoptMask`; the button; the ask on a lift; the live-run lock once portrait. duo3 PORTRAIT PASS. *New side effect: P1-2.* |
| P0-2 | Reopen bites | **Fixed in the main path** | REOPEN: resumed at 117.9° after still, no bite; COVER-REOPEN noise 0.00 → 0.20. *Reopened by the fallback: P0-1. Inner relight with no pose change has no hold.* |
| P1-3 | Turned drags unverified | **Fixed** | The scene turns itself; the XCUITest drag passed on CI. Still eyeball it once on the device. |
| P1-4 | 85° pause inside the upright rest | **Fixed in app** | 70° / 78°; UPRIGHT-NO-PAUSE PASS. *But iOS hands the app to the cover display first (sim at 74° and 92°): P1-3.* |
| P1-5 | Noise outside the play range | **Fixed** | `speedAngle` is clamped to 97–168°; the feel tests include the 180 → 170 case. |
| P1-6 | Lesson pose window vs the ready rule | **Fixed** | 90–112°, with "Close it a little…" above it. |
| P1-7 | Wrong half / upside-down hold | **Partly fixed** | The camera-up banner exists. A wrong half with the sensor in the flat half stays undetectable (hardware). |
| P1-8 | Cover handover opens the menu | **Fixed** | The menu opens on `.background` only, never under 20°. |
| P1-9 | Relics near a flat detent | **Fixed** (depth 0.80–0.88) | Whether the hinge has a detent is a hardware question. |
| P2-10 | No thermal policy | **Partly fixed** | 60 fps only under Low Power or thermal ≥ .serious. No idle drop to 60 (P2-7). |
| P2-11 | `reset()` never called | **Fixed** | On every resume and on becoming active. |
| P2-12 | Book card layout | **Fixed, but moot** | Brim's two pages are in, but the card now vanishes in under 1 s (P1-2). |

## Top 10 issues

### P0-1. The cover-sized-canvas fallback fires on the real cover display (new in R2)
**Evidence (2 of 2 slow closes on the sim):**
- `duo3/logs/frames.txt`:
  - 782: `pose cover reason=cover-sized 466x678 angle=74.2`;
  - 787–789: `cover-open angle=70.7`, then `pose play reason=small-canvas-open 466x678`, **0.7 s later**.
- `duo3/logs/ui-pose-book.txt`:
  - 24: the cover at 92.3°;
  - 28–30: `small-canvas-open` at 86.0°;
  - 36: back to the cover at 59.8°.

**Cause:** `smallCanvasOpenSince` is stamped by any hinge sample ≥ 60°, including every sample during play, and it
is never reset when the cover pose begins. So the "held open for 2.5 s" condition has always matured already by the
first poll, 0.5 s after the cover appears. Also, 60° is inside the cover display's own lit range: the sim's cover was
still lit at 118° on a reopen (`frames.txt` 828–834).

**What the player gets:**
1. **Every gentle close** (the game teaches 15–18°/s): on the cover display, the sleeping-mimic card flips to a tiny
   unturned chest with the closing card, then back again.
2. **On a gentle reopen, if the hardware relights the inner display late (above ~95°):**
   - the run resumes on the cover display (the inner is dark, the candle burns);
   - the inner then relights as a `.play → .play` change, so `setPose`'s `closingPause.hold()` never runs;
   - so the reopening hand's motion goes straight into the noise, which is the R1 P0-2 bite again.

**Fix (App, about 15 lines):**
1. **Learn the cover display's size.**
   - When `isShut` (≤ 10°) and the canvas's long side is under 760, store `coverCanvas` (466 × 678 on the sim).
   - A small canvas within ±2 pt of it **is** the cover display and is never "open".
   - Only a different small canvas (the 469 × 669 column) may use the fallback.
2. **Until the cover size is learned:**
   - reset `smallCanvasOpenSince = nil` in `setPose(.cover)`, so the clock starts at cover entry;
   - raise `smallCanvasOpenAngle` to **130°**;
   - keep 2.5 s.
3. **Never resume a live hinge run on a small canvas.** In `checkClosing`, pass
   `canResume: hinge.canResume && max(canvas) >= AppRules.coverMaxSide`.
4. **In `updateCanvas`, any change of canvas class (small ↔ inner) during a live hinge run calls
   `closingPause.hold(); setClosing(true)`**, even when the pose stays `.play`. This closes the late-relight hole for
   good.
5. **CI: add a COVER-SLOW-CLOSE check to `ci/duo.sh`.**
   - Steps: 120 → 0 at 15°/s, then hold 3 s.
   - FAIL on any `pose play reason=small-canvas-open`.
   - Add a COVER-SLOW-REOPEN check too: 0 → 160 at 20°/s with a 1 s stop at 100°. PASS when the first `resumed`
     comes after the last canvas change.

### P1-2. The automatic portrait ask hides the book card and can ping-pong in the hand (new in R2)
**Evidence:** duo3 POSE-BOOK.
- The card appeared at line 2 of `ui-pose-book.txt` and portrait arrived by line 8, before any hinge sample.
- CI calls this "the fix working". For a first-time player it isn't: the card is visible for well under a second.

**What happens on hardware:**
- Launch while holding the Duo like a book: iOS obeys `requestGeometryUpdate`, and the player now sees Home or the
  lesson sideways, with no instruction.
- On Home the mask still allows the landscapes. Any wobble through face-up and back to landscape posts a device
  orientation change, so iOS rotates back to landscape. The card returns, the app asks again 1 s later, and the screen
  flips every second or so while the player holds it like a book.
- The live-run lock prevents this in runs, but not on Home or in menus.

**Fix:**
1. Gate the **automatic** asks (card shown, launch, cover → inner) on `UIDevice.current.orientation`.
   - Ask only when the orientation is `.faceUp`, `.faceDown`, `.portrait`, `.portraitUpsideDown` or `.unknown`.
   - Never ask while it is `.landscapeLeft` or `.landscapeRight`: that is the Duo held like a book, and the card
     should speak.
2. In `deviceOrientationChanged`, while `pose == .standUp`, ask the moment the orientation leaves landscape. That is
   exactly the "stood it up" moment (the floor goes flat).
3. Keep `liftedFromBook` and the "I've stood it up" button unconditional, as backstops for the P0-1 lock-out.
4. Log `HUSH-T orient ask reason=<card|lift|button|device|launch|cover> device=<o>`.
5. CI: the sim's device orientation may read `.unknown`. If so, POSE-BOOK still shows portrait; leave it INFO, and add
   a unit test for the gate.

### P1-3. iOS's cover handover comes before the 70° pause (hardware-shaped)
**Evidence:** on the sim the app moved to the cover at 74.2° (`frames.txt` 782) and at 92.3° (`ui-pose-book.txt` 24).
On hardware, `status == .closed` fires at about 85°.

**What it means:**
- On a real Duo the closing card is rarely seen. Lowering the lid past upright ends on the cover display instead.
- With ±5° accuracy, an upright 85–90° rest after banking may drop the run onto the cover display. Coming back then
  needs ≥ 95° and stillness.
- R1's upright-rest trap is back, but caused by iOS this time, not by the app.

**Fix:** measure it first (script step 9). Then:
1. Cover card mid-run: "Open me past upright, then hold still".
2. If the inner display relights below 95°, set the resume angle after a cover trip to `max(90, relight + 3)`.
   - Learn `relight` from the first inner canvas after `.cover`, and log it as `HUSH-T relight angle=<θ>`.
   - Keep 95° for the inner closing card.

### P1-4. A Duo run can start on the lever, and the first hinge report is not guarded
**Evidence:** `reopen.txt` 7–18.
- The run starts with `input slider`, then `resumed angle -` with no hold.
- The hinge arrives later (`input hinge`), with no reset and no hold.
- Phone frame `34-lesson-1-fold` shows what a fold layout with the slider looks like: "Slide the lever up… slowly",
  with the lever on the lid.

**Why it matters on hardware:** the Duo sends nothing while still. If the first report only comes once the hinge moves,
a launch in book pose plays on a lever the player can't use. The first lift into tabletop (180° → 110° through the
counted 168–110° range at hand speed) then lands live on the first chest.

**Fix:**
1. When `hingeSeen` (stored and trusted) or the layout has a fold, never choose `.slider`. Use `.fixed` (shut), hold
   the closing pause, and have the card say "Move the lid a little".
2. On the first hinge sample during a live run, call `hinge.reset()`, then `closingPause.hold()` and
   `setClosing(true)`. It then resumes on `canResume`.
3. Hide the lever whenever the layout has a fold.

### P2-5. Free calm-down while folded: verify, then cap it
- `rest(dt:)` decays the noise with the candle stopped, on the closing pause and on the cover display alike.
- After a bank, folding below 70° or onto the cover display calms the mimic at no candle cost.
- If noise carries over to the next chest, that is a habit-forming exploit ("fold, count to five, reopen").

**Fix (Core and Feel call):**
- burn the candle at 1× for the first 10 s of a closing or cover pause, then freeze it; or
- rest only down to the Stirring line (0.34) when the pause started above it.

Add a BalanceTest: fold-to-calm never beats holding the lid in the shut zone.

### P2-6. The menu's Resume skips the hinge gate
**Cause:** `resume()` clears `.menu` and play starts at once, wherever the lid is.

**Fix:** for a hinge run, `resume()` calls `closingPause.hold()` and `setClosing(true)`, so the run continues only on
`canResume`.

### P2-7. 120 fps whenever nothing is wrong
**Cause:** `preferredFPS` drops to 60 only under Low Power or thermal ≥ .serious, and by then the device is already
hot. The hinge delivers 25–30 Hz, so 120 Hz only helps drags.

**Fix:**
- In play, use 120 only while a touch is down or `hinge.speed > 1`, held for 1 s; otherwise 60.
- Use 60 at thermal `.fair`.
- Home's `FrameTicker` should be capped at 60 too (`preferredFrameRateRange`).

### P2-8. The pause coin sits under the lid hand
**Cause:** `ChestLayout.pauseArea` (y 372–436) is on the floor's hinge edge, where the fingers easing the lid rest
(frame 31). A stray tap opens the menu mid-chest.

**Fix:**
- move it to the bag strip's far corner (canvas x 600–660, y 12–76); or
- during a live chest, need a 0.35 s press.

### P2-9. The portrait lock can't be seen
**Cause:** the lock engages only through `interfaceChanged()` → `refreshSupportedOrientations()`, and that depends on
`effectiveGeometry` already reading portrait inside SwiftUI's `onChange(of: canvas)`. Nothing shows whether it did.

**Fix:**
- Log `HUSH-T mask <portrait|allButUpsideDown> live=<0|1> iface=<o>` on every refresh.
- Add the mask to Settings › About in test builds.

### P2-10. Wrong-half detection is still one-sided (R1 P1-7 carry-over)
- The banner covers the camera-up hold only.
- **Fix:** if step 13 shows the wrong half reads `.portrait`, extend `readsUpsideDown` to tabletop (hinge 90–170°,
  `.portrait` for 0.7 s, copy "Lift the other half"); otherwise leave it.

## Hardware-only questions (only the founder's Duo can answer)
1. **Book-pose launch:** does the card stay up (after the P1-2 fix), and does iOS ping-pong between orientations on
   Home without it?
2. **Inner display hand-off on the way down and relight on the way up:** the two angles, from the `HUSH-T pose` and
   `relight` lines (P1-3, P0-1).
3. **The first hinge report:** does it arrive at launch while the hinge is still, or only once it moves (P1-4)?
4. **`UIDevice.orientation` in tabletop,** for the correct half and for the wrong half (P1-2, P2-10).
5. **The report rate and quantisation at 3–15°/s,** and whether a slow open stick-slips. `canResume` treats gaps
   over 0.25 s as still.
6. **Heat over 5 runs** at the current fps policy.

## Founder device test script (TestFlight, about 15 minutes; screen-record steps 2, 8 and 10)
1. Fresh install. Hold the Duo open **like a book** and launch. **Expect** the "Turn it round. Lift the glowing half."
   card to stay up while you hold it like that. Wiggle it for 5 s: **expect no flipping** (P1-2).
2. Put it on a table and lift the **glowing** half like a laptop lid. **Expect** the chest to appear the right way up
   within about 2 s. If it doesn't, tap "I've stood it up". The lever must never show (P1-4).
3. While lifting from flat, note which half blurs. **Expect** the lid you lifted, never the floor.
4. Lesson: rest the lid upright. **Expect** "That's it", then "Open the lid… slowly. Watch the noise." Open over about
   8 s: **expect silence and a glinting coin.** Note whether the lid moves smoothly or in little jerks.
5. Drag the coin into the pouch with one finger. **Expect** it to stay under your finger.
6. In a real run, after a bank, rest the lid **upright (about 90°) for 5 s.** Note which screen stays lit: the inner
   with no card, or the outside screen (P1-3).
7. Lower the lid **slowly** to shut, over about 5 s. Watch the outside screen. **Expect** only the sleeping mimic,
   never a small chest flashing up (P0-1).
8. Reopen **slowly**, pausing for 1 s at about upright and again at about 130°. **Expect** the inner screen to light,
   then "Hold still…", then the run to carry on with no bite and the candle not having moved on the dark screen
   (P0-1, P0-2).
9. Close and reopen once at normal speed. Then open Settings › About and read out the `relight` and hand-off angles,
   or take a screenshot (P1-3).
10. Mid-run, pick the Duo up and tilt it sideways. **Expect** the run to stay portrait, with no book card.
11. Tap Pause, then Resume **while the lid is moving.** **Expect** it to wait for stillness (P2-6).
12. Hold the Duo upright like a normal phone (camera at the top). **Expect** the gold "Other way round" banner.
13. Lift the **wrong** half on purpose. Note whether anything tells you, and send the About screen's orientation line
    (P2-10).
14. While easing the lid, did your fingers ever hit the pause coin by the fold (P2-8)?
15. Play 5 runs in a row, then report: is it warm? Does the creak feel like the hinge itself? Is the haptic in your
    fingers, or a buzz on the table?

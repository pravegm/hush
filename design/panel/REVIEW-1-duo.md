# REVIEW-1: Duo specialist (27 Oct)

*Reviewer: the studio's iPhone Duo specialist (Squish, Brim and Swoop real-Duo logs). Read: CLAUDE.md, GAME-DESIGN
§3/§8/§9, ARCHITECTURE, notes app/feel/ci-R1, `Hush/Input/*`, `UI/RootView`, `UI/PoseCards`, `App/AppRules`,
`App/OrientationLock`, `App/GameController`, `App/LessonScript`, and Brim's `OrientationLock` / `PoseCards` for
comparison. Evidence: Duo sim run `artifacts/duo1` (frames, `logs/*.txt`, `checks.tsv`), phone frames `ci2/30-34`.
No source edited.*

## Verdict

**Score: 6.0 / 10 for the Duo experience. Launch: NO. One device round is needed after the two P0s are fixed.**

What's right:
- **The input pipeline is the best of the four games.** Speed is computed on the raw reports and is gap-aware, with
  decay when samples stop, and is never read off the predictor. The angle runs on its own predictor and One-Euro path.
  On the sim the STILL check reads exactly 0.0, and a slow 5.4°/s sweep never made noise (`slow-open.txt`).
- **Turning round is done properly.** In the raw frames the mimic/lid is on the device's physical bottom half (the half
  that blurs) and the floor is on the sharp top half. Every time-critical tell is on the floor: the meter, "Freeze!",
  the tongue, the torch and the bag. The bag strip sits on the device's top edge, which is the floor's front edge
  nearest the player in tabletop pose.
- `status` is never used. The hinge subscription is re-armed on activation, and `hasHinge` never demotes.

What blocks launch (both found by reading the code and the sim logs, not guessed):
1. **The book pose → tabletop path can lock the player out.** No Release build ever asks iOS for portrait.
2. **Reopening from the cover display or the closing pause resumes mid-motion and bites.** The sim log shows it
   happening.

## How it plays on a real Duo, end to end

### On a table vs in the hand
- **On a table it's the intended pose, and it works.** The floor rests on the table, and one hand eases the lid while
  the other steadies the floor. Dragging comes as a separate beat, and hinge friction holds the lid while you drag.
  Taps on the floor can't move the hinge angle. Hand tremor moves the whole phone but not the hinge angle, which is
  relative.
- **In the hand it's playable but cramped.** The floor (about 11 × 8 cm) sits in one palm like a tray, and the other
  hand must both move the lid and drag. That's fine because the phases are sequential (open, drag, shut), but:
  - the pause button sits at the floor's hinge edge, under the lid hand;
  - holding the phone sideways in the hand can rotate iOS to landscape mid-run. That brings up the book-pose card,
    and then P0-1's lock-out.

### Which half to lift
- The app marks the lid half three ways: the gold outline, "Lift this half ↑" on the lid in lesson 1 (frame
  `duo-ui-lesson-1-150`), and "Lift me" on the closing card.
- That is clear **once the interface is already portrait.** It is not unmistakable before that:
  - **Held upright in the hand the normal way** (camera end up), every turned screen reads upside down: Home, the
    lesson and Results. The player has to work out on their own that the answer is "turn the phone round". Brim
    shipped this, but there the founder knew why. A first-time buyer will think it's a bug.
  - **Starting in book pose** (the usual way to open a Duo; the sim boots that way too) shows the StandUp card. See
    P0-1.

### Lifting the wrong half
- The hinge angle is symmetric, so the app can't tell which half was lifted. The lesson's pose step **passes anyway**.
- With the wrong half lifted, everything is upside down to the player, and the loot sits on the raised half with the
  bag at its far top edge.
- It's obviously wrong, so players will flip it. But the app never says so, and the fold blur then lands on the floor.

### The book-pose card
- The copy is good, but the layout ignores the vertical fold:
  - the title starts about 12 pt from the crease;
  - the two-halves drawing is a miniature drawn on one half, rather than the half itself glowing;
  - "Floor" uses an app-grid icon.
- **And it has no way out.** See P0-1.

### The 100–165° range
- **100° = shut** is a fair abstraction: the lid is nearly upright and the floor stays fully visible.
- But a real chest shuts *towards* you, so players will overshoot to about 90°, which is upright and where a laptop
  lid naturally rests.
- **The closing pause at 85° is only 5° from that rest, inside the Duo's ±5° accuracy.** This is exactly the trap
  Swoop's founder hit at 90° ("never put a pause near 90° again").
- **165°** is comfortable on a table: the lid lies low and the mimic is viewed from above.
- **Relics need 159–164°**, which sits just under "too wide" (172°). If the Duo's hinge snaps the last few degrees to
  flat (a detent), reaching a relic becomes a slam. See P1-9.

### Speed fairness
- **The thresholds are honest for a deliberate slow hand.** Silent up to 8°/s, Stirring over a full open at about
  20°/s, "Slower…" at 30.
- **A normal "gentle" laptop opening (40–90°/s) bites.** That is the game, and the lesson teaches it.
- **Sparse samples under-read rather than over-read.** On the sim (about 5 Hz) a 5.4°/s sweep read 4.3–5.5°/s and
  dropped to 0 across gaps longer than 0.25 s, so the error favours the player.
- **Jitter false positives:** tremor at ±0.5° reads ≤ 1.6°/s (feel tests). One real false positive remains: hinge
  motion *outside* the playable range still makes noise (P1-5).

### The closing pause and the cover card
- **The pause logic works.** CLOSE-PAUSE passed: paused, then resumed.
- **But it resumes the instant θ ≥ 88°, while the hand is still opening.** `frames.txt`, lines 490–525:
  - "HUSH-T resumed" comes out at 87.2° with the speed at **33.3°/s**;
  - the noise then climbs 0.84 → 0.99 in 0.3 s;
  - attract mode caps at 0.99, so a real run would bite.
- **Noise isn't decayed during the pause either.** The run went into the cover display at 0.81 and came back at 0.84.
- The cover card itself ("Open to carry on") is clear and truthful (frame `duo-04`).

### The Home live chest
- It follows the hinge from the same `HingeLidSource` and has a live creak, a nice first-touch teach. No issues.
  `FrameTicker` runs at display rate on Home, which is a small battery cost.

### The lesson's pose gate (95–125° for 0.5 s)
- **The window doesn't match the chest's own rule.** A chest only starts looting after θ ≤ 110°.
- So a player who passes the pose at 111–125° is told "Open the lid… slowly" and then "Ease the lid down first". That
  is a contradiction in the first 10 seconds of the game.

### Thermal and 120 Hz
- The display runs at a fixed 120 fps (SpriteView, plus `CADisableMinimumFrameDurationOnPhone`), with a real-time synth
  and a looping haptic player all at once. The hinge only delivers 30 Hz.
- There is no thermal or Low Power policy (the app note lists it as "Not done").
- Back-to-back 2-minute runs on the big inner panel will warm the Duo. Nobody has measured it.

## Top 12 issues

### P0-1. Book pose → tabletop can lock the player on the StandUp card
**Cause:**
- The Release build has no `requestGeometryUpdate` anywhere. Only DEBUG `DemoMode` asks for portrait, which is why
  every CI Duo frame is portrait.
- In book pose the interface is landscape. Lifting the glowing half (the device's portrait-bottom) puts the phone
  physically upside-down portrait, or face-up if the motion sensor is in the floor half.
- iOS refuses upside-down for a full-screen app, and a phone lying flat never rotates. So the interface **stays
  landscape**, `pose == .standUp`, and the card asks for what the player has already done.
- The same lock happens mid-run if the phone tips sideways in the hand.
- The only escape is undiscoverable: hold the phone the wrong way up (camera end up) so iOS goes portrait, then turn it
  round.
- Brim needed exactly this: its card has "Turn the screen" (calling `requestPortrait()`) and "Play with touch".

**Fix:**
1. Port Brim's `OrientationLock.requestPortrait()`, `adoptMask(_:)` (Brim found SwiftUI's hosting controller
   intersects the mask) and `requestFailed`. In Hush, request `.portrait` only (never upside down).
2. On `StandUpCard`, add a 56-pt **"I've stood it up"** button that calls `OrientationLock.requestPortrait()`. Put it
   on the non-lift half, and keep "Play with touch" too.
3. Also call `requestPortrait()` automatically:
   - when the card is up and a hinge sample lands in 90–165° after the angle has changed by ≥ 15° since the card
     appeared (they lifted it);
   - on launch on the inner display;
   - on every cover → inner handover during a live run.
4. While `isLiveRun` on the inner display, return `.portrait` from `mask(screen:)` so a sideways tilt can't drop the
   run into landscape. Keep `.allButUpsideDown` on Home and in menus.

**Test:** P0-1 steps in the device script.

### P0-2. Resuming from the closing pause or the cover display bites the player
**Cause:** `checkClosing` clears at θ ≥ 88°, and `setPose(.play)` clears the pose pause at once. Neither waits for the
lid to settle, so the reopening hand's 30–90°/s goes straight into the noise (evidence above).

**Fix:**
1. Add a resume gate in `GameController.checkClosing` / `setPose`. A paused run resumes only when **θ ≥ 95° and
   `hinge.speed < Tuning.quietSpeed` for 0.3 s**.
   - Until then the closing card says "Hold still…".
   - On the cover display, the card says "Open me gently, then hold still".
2. Call `hinge.reset()` at the moment of resume.
3. Give a **0.5 s lid-noise grace** after any resume: pass `speed: 0` to the session.
4. While the closing or pose pause is up, step the noise decay alone (`session.decayOnly(dt:)`, or cap it at the
   Stirring floor of 0.34 on resume), so "the mimic settles while the lid is shut".
5. Add a SLAM-on-reopen check to `ci/duo.sh`:
   - steps: shut to 0 → cover → sweep to 150 in 0.8 s;
   - PASS when there's no `stageChanged … to=waking` within 2 s of `resumed`.

### P1-3. Turned drags are unverified
**Cause:** CI's pilot injects touches straight into `HeistSession`, so no real finger has ever gone through
`SpriteView` + `.rotationEffect(180°)` (app note's own risk).
- If UIKit doesn't map the point through the SwiftUI transform, grabs land at the mirrored point and nothing can be
  picked up.

**Fix:**
- Verify first (script step 6).
- If it fails, don't rotate the SpriteView. Rotate inside SpriteKit instead: `scene.camera.zRotation = .pi`, mirroring
  `ScreenLayout`. Keep `rotationEffect` for the SwiftUI layers only.

### P1-4. The closing pause at 85° sits inside the natural 90° rest
**Cause:** with ±5° accuracy, an upright lid can read 84–86°. Players lowering the lid after banking will get spurious
"Lift the lid a little" pauses (Swoop's device lesson).

**Fix:**
- `Tuning.closingAngle = 70`.
- `FeelClosingGate.reopenMargin = 8` (resume ≥ 78°).
- `GameController.closingResumeAbove = 78`.
- Keep the 0.4 s dwell.
- Update GAME-DESIGN §3 and the feel tests.

### P1-5. Hinge motion outside the playable range makes noise
**Cause:** speed is the raw angular speed at any angle. In `frames.txt` the noise rose 0.47 → 0.81 while the lid went
101° → 74°, when openness was already 0 and the in-game chest was already shut.
- Near flat (165–180°) any motion, including a hinge detent snap, is noise for no gameplay reason.

**Fix:** in `HingeLidSource.ingest`, feed the speedometer the clamped angle `FeelMath.clamp(raw, Tuning.shutAngle − 3,
Tuning.wideAngle + 3)`.
- A slam through 150 → 100 still counts.
- Movement below 97° and above 168° is silent.
- Add a test: a 180 → 170 jump makes no noise.

### P1-6. The lesson pose gate contradicts the chest's ready rule
**Cause:** the pose step passes at 95–125°, but looting needs θ ≤ 110° first. Passing at 111–125° yields "Open slowly"
then "Ease the lid down first".

**Fix:**
- `LessonScript.poseMin = 90` (after P1-4) and `poseMax = 112`.
- Copy: above 112, "Like a laptop, lid nearly upright…".
- GAME-DESIGN §8: "90–112° for 0.5 s".

### P1-7. A wrong half or an upside-down hold is never detected
**Fix:**
1. Call `UIDevice.current.beginGeneratingDeviceOrientationNotifications()`.
2. While `turned` and the hinge is at 60–170°, if `UIDevice.current.orientation == .portrait` (camera end up) for
   0.7 s, show an **un-turned** banner on both halves: "Other way round: lift the glowing half ↻". Hold lesson step 1
   while it shows.
3. The same banner covers the hand-held "everything is upside down" first impression on Home.
4. Log `HUSH-T device-orient <o>` in DEBUG.
5. If the founder's Duo reports `.faceUp` in tabletop either way (the motion sensor is in the floor half), keep only
   the hand-held case and the copy.

### P1-8. The cover handover may open the pause menu
**Cause:** `setAppActive(false)` calls `openMenu()` on a live run. If folding shut passes through `.inactive` on
hardware (unknown), every close ends on the menu, under "Open to carry on".

**Fix:**
- Open the menu only on `.background` (or after 1 s inactive), and never while `hinge.angle < 20`.
- Log `HUSH-T phase <p>` to find out.

### P1-9. Relics need 159–164°, close to a possible flat detent
**Fix:** after P1-5, check on the device that the hinge free-stops at 160°. If it snaps:
- move relic depth to 0.80–0.86, reachable at about 157°;
- lower `tooWideAngle` to 168.

### P2-10. No thermal or Low Power policy at a fixed 120 fps
**Fix:**
- `preferredFramesPerSecond`: 120 only while `hinge.speed > 1` or a touch is down, otherwise 60.
- 60 when `ProcessInfo.isLowPowerModeEnabled`.
- 30, with particles halved, when `thermalState >= .serious`.
- Observe `thermalStateDidChangeNotification`, and log `HUSH-T thermal <state>`.

### P2-11. `HingeLidSource.reset()` is never called
The feel note asks for it on activation.

**Fix:** call `hinge.reset()` in `setAppActive(true)` and on any `setPose(.play)` transition (pairs with P0-2).

### P2-12. The StandUp card layout ignores the vertical fold
**Fix:** use Brim's `bookPages` layout:
- the **whole lift half** is filled with a gold glow and a big "Lift this half ↑";
- the copy and the P0-1 button go on the floor half, ≥ 24 pt from the crease;
- swap the grid icon for a flat-chest glyph.

### Also noted (not in the 12)
- No "play with the slider" option on a Duo, for accessibility or for players who can't move a hinge gently.
- If `hush.hasHinge` is stored but no live sample has arrived, a Duo run silently uses the lid slider. Say "Move the
  lid a little" instead.
- iOS banners appear at the device's physical top, which is the player's near edge, upside down. This is the same as
  Brim and can't be fixed.

## Hardware-only risks (only the founder's Duo can answer)
1. **Orientation:** in tabletop with the glowing half lifted, does iOS leave the interface in landscape after a book
   pose start (P0-1)? Does `UIDevice.orientation` read `.portraitUpsideDown` or `.faceUp` (P1-7)?
2. **Real-finger drags** through the turned SpriteView (P1-3).
3. **The hinge report rate and quantisation** at 5–15°/s: is it 25–30 Hz, or does it only report on change in 1°
   steps? The sim gave about 5 Hz. The `HUSH-T lid` speed should read within ±20 % of the true speed.
4. **Stick-slip at slow speed:** does a deliberately slow opening jerk in 2–5° steps and read as 15–25°/s? That would
   make "gentle" impossible.
5. **The hinge free-stop range and any detent** near 160–180° (P1-9), and whether the lid holds at 100° unsupported.
6. **Angle accuracy at an upright 90°:** what does the app read (P1-4)?
7. **The blur:** after the turn, it should be on the lid when lifting from flat, never on the floor.
8. **The cover handover:** does the scene pass through `.inactive` (P1-8)? When reopening, at what angle does the inner
   display relight? The sim needed about 150°.
9. **Haptics:** which half holds the Taptic Engine? On a table, does the creak haptic buzz the table louder than the
   creak audio?
10. **The speaker's position** relative to the floor and the lid, and the snore/creak balance at arm's length.
11. **Heat and battery** over 5 runs in a row at 120 fps (P2-10).
12. **System gestures:** with `[.top, .bottom]` deferred while turned, does a Home swipe on the lid's far edge need two
    swipes, and does Control Centre still appear?

## Device test script for the founder (TestFlight build, about 15 minutes)
1. Open the Duo like a book (flat or half open). Launch Hush. **Expect** the "Stand it up like a little laptop" card,
   with one half glowing.
2. Put it on a table and lift the **glowing** half up like a laptop lid. **Expect** the card to go away within about
   2 s and the chest to appear the right way up. *If the card stays, tap the button on the card (after the fix) and
   note what happened.* (P0-1)
3. While lifting from flat, watch which half blurs for a second. **Expect** it to be the half you lifted, not the half
   on the table.
4. Lesson step 1: rest the lid at about upright. **Expect** "That's it." Then follow "Open the lid… slowly".
   **Expect** no "Ease the lid down" straight after. (P1-6)
5. Open very slowly, over about 8 seconds. **Expect** silence, then the coin to glint. Note whether the lid moves
   smoothly or in little jerks. (Risks 3–4)
6. Drag the coin into the bag with one finger. **Expect** it to follow your finger exactly, not jump to the other side.
   (P1-3)
7. At "Freeze!", hold completely still. **Expect** the snoring to come back. Ease the lid shut. **Expect** the bank
   sound.
8. In a real run, rest the lid fully upright (90°) for 5 s. **Expect** no "Lift the lid a little" card. (P1-4)
9. Open the lid as wide as it goes without forcing it. **Expect** it to stop by itself, without snapping flat. Note
   whether the relic depth is reachable. (P1-9)
10. Mid-run, close the Duo fully. **Expect** the sleeping mimic on the outside screen, with no pause menu. (P1-8)
11. Reopen it at your normal speed. **Expect** the run to wait for you to hold still, then carry on, with no bite.
    (P0-2)
12. Mid-run, pick the Duo up and tilt it sideways in your hands. **Expect** the run not to switch to the book card.
    (P0-1)
13. Hold the Duo upright in your hand the normal way (camera at the top). **Expect** a "turn me round" hint, not just
    upside-down text. (P1-7)
14. Lift the **wrong** half on purpose. **Expect** the app to tell you to swap. (P1-7)
15. Play 5 runs in a row. Then report: is the phone warm? Did the creak feel like the phone's own hinge? Is the haptic
    felt in your fingers, or as a buzz on the table? (Risks 9–11)

Send back: a screen recording of steps 2, 6 and 11, and Settings › About (if a hinge/orient readout is added).

# Round 6: "Any way up": never stuck (brief)

## The founder's real-Duo test of TestFlight 1.0 (1), 27 Oct late evening
> "when i open the whole phone it gets stuck and there is no way for me to continue playing"
> "lots of issues i saw when i tested … please fix all issues"

**Diagnosis (founder):**
- **What happens:** opening the Duo fully flat and holding it lets iOS rotate the interface to landscape. Folding
  back to tabletop leaves it there, because a Duo lying in tabletop or flat never auto-rotates.
- **Why play stops:** the game plays only in portrait on a Duo. In landscape it shows the blocking book-pose
  ("standUp") card, and its exits depend on iOS agreeing to rotate. That is a dead end on hardware.
- **Underlying flaw:** correctness depends on iOS's interface orientation. It must not.

## The fix: draw the right way up in ANY interface orientation
We always know where the blurring half is: the physical half that is the **bottom in iOS portrait**. That is the
left half in book pose (the founder's report), and Brim's finding.

| Interface orientation | Screen side of the blurring half |
|---|---|
| `.portrait` | bottom |
| `.landscapeLeft` (home edge on the left) | left |
| `.landscapeRight` (home edge on the right) | right |
| `.portraitUpsideDown` | top |

The portrait canvas (lid = canvas top) is drawn with `k` **clockwise quarter turns**, so that the lid's edge points
at the blurring side when "Turn the chest round" is on (the default), and at the opposite side when it's off:

| Interface | k (turn round ON) | k (OFF) |
|---|---|---|
| portrait | 2 | 0 |
| landscapeRight | 1 | 3 |
| landscapeLeft | 3 | 1 |
| portraitUpsideDown | 0 | 2 |

- On a canvas without a fold (other iPhones), `k = 0` always.
- k = 2 is today's "turned".

**Founder pure rule (App owns it; write it exactly, with a table test):**
`AppRules.quarterTurns(interface: UIInterfaceOrientation, turnRound: Bool, hasFold: Bool) -> Int`.
- `.unknown` keeps the last known value.

**Conventions:**
- SpriteKit `zRotation` is counter-clockwise, so the scene uses `world.zRotation = -CGFloat(k) * .pi / 2`.
- SwiftUI `rotationEffect` is clockwise, so the App uses `.degrees(90 * k)`.

With this, a Duo standing in tabletop while iOS says landscape still shows an upright chest: the lid on the raised,
blurring half and the floor on the sharp half nearest the player.

## App engineer
1. **`AppRules.quarterTurns`** as above, tested over all 4 × 2 × 2 cases.
2. **The whole root content**, every screen (Home, lesson, run HUD, Results, Codex, Badges, Settings, Daily, cards):
   - draw it in a **portrait** frame: the window size, with width and height swapped when k is odd;
   - rotate it by `90 * k` degrees about the window's centre;
   - turn safe-area insets and system-gesture edges with it (extend R2's `insets(_:turnedRound:)` to quarter turns).
3. **The scene:**
   - Build its layout from the *portrait-equivalent* size (`ScreenLayout.make(hasFold:viewSize:)` with w and h
     swapped when k is odd).
   - Set `scene.quarterTurns = k`; the scene engineer adds it. Keep `turned` working as `k == 2`.
   - The scene's own SKView size is the real window.
4. **Book pose no longer blocks.**
   - On a Duo, `.standUp` never blocks Home, the lesson or a run.
   - Replace the blocking card with a small, dismissible, non-blocking tip ("Stand it up like a little laptop"),
     drawn the right way up:
     - only on Home and lesson step 1;
     - only while the device orientation (`UIDevice`) is landscape;
     - not again after the player taps ✕ or the lesson passes step 1.
   - Remove the "Play anyway" landscape-lever path on a Duo (a Duo always uses the hinge now). Keep the lever for
     phones.
5. **Orientation policy on a Duo:**
   - Allow portrait and both landscapes (upside down stays out, as before).
   - During a **live run**, lock the mask to the *current* orientation, so iOS never flips the picture mid-chest.
   - Unlock it in menus.
   - Keep asking for portrait where R2–R4 did; it's harmless now, but nothing may depend on it.
6. **Never stuck: escape hatches.**
   - **Closing or "Hold still…" card:**
     - After 3 s it shows a big **"Carry on"** plate and a **"Home"** plate.
     - "Carry on" resumes at once: `hinge.reset()`, then `session.resumeGrace(seconds: 0.8)`.
     - **Watchdog:** a paused live run whose last hinge angle is ≥ 95° (or which has had no hinge sample for 4 s)
       and which is still paused after 6 s resumes itself the same way, and logs `HUSH-T watchdog resume`.
   - **Cover card:** reopening is the way; nothing to add.
   - **Every overlay** (pose tip, pause menu, closing card, lesson cards, Results, Codex, Settings) has a reachable
     way back. Audit them all, and add a test per overlay that its exit action exists and changes state.
7. **Flat is fine.**
   - At θ ≥ 172° a run keeps playing: the "That's wide enough" hint shows, with no pause or block.
   - Check `HingeLidSource` and every gate for anything that misbehaves at 175–180° (a nil hinge context when
     fully open must keep the last angle and the hinge input; never switch to the slider).
   - Add tests.
8. **Diagnostics event log:**
   - A ring buffer of the last 80 events, persisted across launches, each with time, event and angle:
     - pose changes with their reasons;
     - pause, resume and watchdog;
     - canvas changes (size, fold, k);
     - interface and device orientation changes;
     - hinge nil;
     - scene phase.
   - Show it in the Diagnostics panel (scrollable, monospaced, newest first) with a **Copy** button
     (`UIPasteboard`), so the founder can paste it to Claude. It's stored on the device only.
   - Tell the founder (in your notes) the exact steps: Settings › About › hold "Version" 2 s › Copy log.

## Scene engineer
1. `ChestScene.quarterTurns: Int` (0…3, clockwise screen turns).
   - `world.zRotation = -k·π/2` about the scene centre.
   - When k is odd the scene size is landscape (the App sets the SKView to the window). Position and scale the
     world so the portrait canvas (with its extensions) fills it exactly.
   - Touches stay `touch.location(in: world)`.
   - `turned` becomes a computed alias for k == 2 (get and set).
2. Every place that assumes `turned` (the keyhole, text orientation, glints, the eye tracking the finger, shake
   direction, particle gravity) must use the world's frame, so all four k values look identical to the player.
3. **Tests:** for every k, a touch at an item's on-screen position maps to that item's floor point, and the lid
   half's on-screen rect is on the expected side. Repeat at scene sizes 951 × 669 and 669 × 951.

## CI engineer
1. **XCUITest:**
   - Add a landscape variant of the turned drag: `XCUIDevice.shared.orientation = .landscapeLeft` with a demo that
     forces k = 3, e.g. `orient=landscape;fold=1;turn=1`. The drag must still bag the item.
   - Ask the App, through NEEDS.md, for a demo key to force k if needed.
2. **`ci/duo.sh` new checks:**
   - **FLAT-OPEN:** in a live run (`screen=run;mode=attract`), sweep 140 → 180 over 4 s, hold 3 s, sweep back to
     140 over 4 s. PASS if `HUSH-T lid` lines keep coming throughout, there's no pause lasting > 1 s, and the run
     is still live (lid lines after the return).
   - **LANDSCAPE-PLAY:** launch a run with `orient=landscape` (the sim's book pose), hinge at 105, then a slow
     open to 160. PASS if the pose is `play` (no `standUp` block), the canvas line shows k odd, lid lines move with
     the hinge, and `lidCracked` appears. Shoot a frame: it must show the chest drawn sideways in raw capture
     (correct for the player).
   - **WATCHDOG:** close to 60° (pause), then reopen to 130° with the tool's slowest step and keep tiny wiggles
     going. PASS if a `resumed` or `watchdog resume` line appears within 8 s.
3. Keep every existing check.

Every engineer: write `design/notes/<role>-R6.md`. Don't commit.

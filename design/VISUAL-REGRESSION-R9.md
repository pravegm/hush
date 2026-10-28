# Visual regression check, R9 (round 4 `ci9s` vs latest `ci17s`, plus Duo sim `duo10` / `duo8`)

Method: each `ci17s` frame was laid side by side with the `ci9s` frame of the same name at the same scale. The Duo
frames `duo10` and `duo8` (the non-raw ones) were compared with each other and turned upright by eye. Close crops were
taken of the pause coin and its seat, the hint plates, the chain tab and the lesson card edges. No files were edited.

Overall, the k-quarter-turn root holds up. No phone frame is sideways or upside down where it shouldn't be. The fold
frames (25, 30, 31, 33, 34, 39) are turned 180° as before. There is no black or blank area, and the HUD, candle, meter,
plates and pouch all line up with the scene. The real regressions are below.

## Regressions (ranked)

### R1 (P1): the pause coin is not in its brass seat on the Duo when unturned (k=1)
- **Where:** `duo8/.../duo-06-half-135-unturned.png`, floor corner (native ≈ x1198, y1770–1870). The SwiftUI coin
  sits about 33 pt (≈ 98 px) toward the interior from the scene's brass seat. The seat's empty dark recess shows below
  the coin, and the coin overlaps the interior's frame. In the k=3 frames (`duo-02`, `duo-h1`, `duo-h11`, `duo-h9`,
  `duo-ui-lesson-*`) and on the phone (09, 31, 32), coin and seat line up exactly.
- **Likely cause:** `AppCanvas.pauseCenter()` (`Hush/UI/Layout.swift:248`) clamps the coin into `safeRect` (the
  insets of the rotated portrait frame). The scene's seat (`ChestLayout.pauseCenter(viewScale:)`,
  `Hush/Scene/SceneLayout.swift:89`) only applies the view-scale clamp and knows nothing about safe insets. At k=1 the
  inset edge (sim home indicator / sensor side) lands on the floor's coin corner, so only the coin is pushed in. Fix
  either by giving the scene the same safe-inset clamp, or by positioning the coin from the seat rect the scene
  reports (`pauseSeatRect`).

### R2 (P1, capture content): store and caption frames lost "Hushed!" and the Hush Chain
- **Where:** `14-bank` and `14b-bank-settled`. Old: "Hushed! BANKED +197 / Hush Chain ×1.1", sleeping eye, CHAIN tab
  by BANKED. New: "BANKED +179" only, the eye half-open, the meter reads STIRRING, no chain tab. Also `10`, `31`, `32`,
  `35` (no CHAIN tab, BANKED 179 instead of 197) and `36b` (chain tab gone, BANKED 359 instead of 373).
- **Why it matters:** `ci/scenarios.txt` lines 66–67 still promise "Hushed! … Hush Chain ×1.1" and "the chain medal
  by BANKED", so the frames no longer show what their captions sell, and 14 is a store beat.
- **Likely cause:** the R6–R9 lid and noise retune. The casual pilot's open now logs `speed 22.0` (was 14.4), and the
  noise climbs to about 0.23. Logs: `logs/10-run-reveal*.txt` shows `stageChanged asleep→stirring` and then
  `banked … hushed=0`, and `chainUp` never fires. Either re-tune the `pilot=casual` speed to the new sensitivity, or
  update the captions. Seed 7's run also diverges further on (16 is now Chest 10 with 18 in the bag, not Chest 8
  with 858).

### R3 (P2): Duo Settings now overflows its half with no scroll cue
- **Where:** `duo10/.../duo-ui-settings.png` (and `duo8`), turned upright. The new Vibration and Lid sensitivity
  segmented rows push the list down. "Play sound on silent" is cut by the Done bar: its subtitle "The creak plays with
  the ringer off." is half under it. Reduce motion, Replay First Chest, About, Credits and the new Diagnostics are all
  off-screen, and there is no chevron or fade cue. Meanwhile the lid half holds only the "Settings" title, over a lot
  of empty space.
- **Phone, milder:** `24-settings` at the default size shows the Credits row faded under the Done fade. Its grey heart
  and text read as disabled. In `43` (AXL) and `47`, Replay, About and Credits only appear after a scroll. The row
  label "Forgiving" fills its pill edge to edge at AXL (`43`, y≈637).
- **Likely cause:** the R7–R8 rows were added to a fixed-height list built for 4 toggles. On the Duo, move the title
  and some rows onto the lid half, or add the Results-style "⌄" scroll hint.

### R4 (P2): the Results hero mimic now reads as a speck
- **Where:** `19`, `20`, `21`, `38`, `41`, `45`. The R5 "hero gives way" change was intended, but the drawn chest is
  now about 45–50 pt wide (≈ 140–150 px at 3x), dwarfed by the 1,476 / 17,966 number. In `41`/`45` (AXL/XXXL) it is
  emoji-sized. `ResultsView.swift:125` floors the frame at `minPortrait` (60 pt), but the portrait scene's padding
  leaves the art itself smaller than that floor.
- **Upside:** the strip's two rows plus "+N more" now sit above the fade (the intended win).

### R5 (P3): an empty pause seat shows as a black hole beside modal cards
- **Where:** `39-lesson-final-fold`, where the empty dark seat sits by the card's lower-left (the coin is hidden for
  the final card). Also `duo8/.../duo-h3-closing-card-55.png`, where it sits by the "Carry on / Home" card's corner.
  (`13-bite` hides the coin during the bite, which R5 intended. The empty ring there is acceptable.)
- **Likely cause:** the coin is hidden (R5/R8) but the scene's `pauseSeatAlpha` isn't dimmed with it. Fade the seat
  out with the coin, or let the card cover it.

### R6 (P3, check): a ghost ruby over the meter's end in `26-daily`
- A half-transparent red gem sits at the NOISE meter's right end / BANKED plate corner (≈ x905, y805 in the pair
  view), outside the interior. It is probably an item in flight, but it lands where the CHAIN tab lives. Worth
  checking that a dropped or returning item can't fade out over the HUD.

## Frame-by-frame verdicts (phone, `ci9s` → `ci17s`)
| Frame | Verdict |
|---|---|
| 01, 02, 27 | same |
| 03–07, 07b, 08 | same (07 lesson copy unchanged on a slider phone) |
| 09, 11, 12, 13b, 13c, 17, 18 | intended: the hint plate is centred on the chest axis (R5) and sits clear of the pause coin |
| 10, 31, 32, 35 | **R2** (no chain tab); otherwise the intended R5 plate centring |
| 13 | intended: the coin is hidden during the bite (R5), and the seat ring stays visible |
| 14, 14b | **R2** |
| 15, 36, 37 | intended: the chain tab reads "CHAIN ×1.5 / ×1.2 / ×1.3" |
| 16 | the run diverges (Chest 10, bag 18): weaker "torch low" beat; plate fine |
| 19, 20, 21, 38, 41, 45 | intended strip fix; **R4** hero size |
| 22, 23, 42, 46 | same |
| 24, 43, 47 | intended new rows; **R3** (phone, mild) |
| 25 | intended: no pose card, and Home is drawn turned for the fold |
| 26 | intended: the daily plaque is centred; **R6** |
| 30 | improvement: the Game Center row is no longer clipped at the top |
| 33, 34 | same |
| 36b | **R2** (chain tab gone) |
| 39 | improvement: the card no longer runs off the top; copy is now "Ease the lid down to bank"; **R5** empty seat |
| 40 | intended: new badge glyphs (feather, figure) |
| 44 | improvement (R5): AXL Home no longer truncates "Codex 9…" or "Today's try r…" |

## Duo sim (`duo10` vs `duo8`, turned upright)
- `duo-ui-home-120`, `duo-ui-home-150`, `duo-ui-codex`, `duo-ui-results`, `duo-ui-cover`, `duo-ui-pose-book`: same,
  and they read correctly once turned.
- `duo-ui-lesson-1-150` / `duo-ui-lesson-after-pose`: intended ("Skip" was added to the first card); the plates sit
  over the chest.
- `duo-ui-pose-card`: no pose tip is shown, because the sim gives no landscape UIDevice reading (checks.tsv
  POSE-NO-BLOCK). This is a capture gap, not a regression.
- `duo-ui-settings`: **R3**.
- `duo8` play frames (`duo-h1`, `duo-h11`, `duo-02`, `duo-h9`, `duo-h10`): the coin is seated, the HUD is intact, and
  each half is the right way up. `duo-06` (k=1): **R1**. `duo-h3`: the Carry on / Home card is clean and readable;
  **R5** empty seat.

## Not covered by any capture (can't verify visually)
The press-and-hold ring on the pause coin, the "Hold to pause" toast, the "Already open?" cover card, the Diagnostics
screen, the pose tip (the sim can't trigger it), and the phone pause menu with Carry on / Home.

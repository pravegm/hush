# Hush: Don't Wake the Mimic — Visual launch review, round 2 (Juror 1)

Reviewer role: Apple Design Award juror / senior iOS game art director
Frames reviewed: `artifacts/ci6/screenshots/01…40`, `app-icon-1024.png`, `badges/*` (12), and `artifacts/duo3/duo-screens/duo-screens/*` (Duo raw frames mentally rotated 180°).
Coordinates are in the 920×2000 display frame for phone captures (×1.31 for native px) and the 1407×2000 frame for Duo composites (×1.43), unrotated.

---

## Verdict

**Score: 7.5 / 10 (up from 6). Launch verdict: NOT YET — close. About 4–6 days of work.**

This is a big step up. The letterbox is gone: the chest now fills the phone, top to bottom. Coins read as coins. The floor title is gone and the tier now sits on the nameplate subtitle. The eye has a fleshy lid and a brass brow plate that tilts. Teeth are pointed and uneven. The HUD has real labels and a pouch. Codex relics are proper outlined sprites. Results has a mimic portrait and a chest-by-chest strip. On the Duo, Home is hinge-reactive ("Shh… something's peeking", with the lid lifting to show teeth and tongue). That is the most featurable moment in the game.

What still blocks launch:
1. A rendering bug wipes out the whole floor half at the bank moment on Wooden and Iron chests. Those are the first chests every player banks.
2. The app icon is still drawn in a third, flat style.
3. While asleep, the mimic has no mouth.
4. In its dim and waking states the tongue still reads as buttocks or a toilet seat.
5. A layer of black/teal SwiftUI capsules and cards still sits on top of the brass-and-leather world.

The rest is collisions and edge clipping.

---

## Round-1 issues: status

| R1 # | Issue | Status | Evidence |
|---|---|---|---|
| P0-1 | Four art styles (Home/Cover/Codex/Results/badges/icon vs in-game) | **Partly** | Home, Cover, Results, Codex and badges now use the outlined in-game sprite language (`01`, `19`, `22`, badges). **The app icon is unchanged**: flat, no outlines, round orange pupil, square lock plate, puck coins. Menus still sit on the teal "fintech" gradient with teal SwiftUI cards (`01`, `19`, `24`, `40`). No `MimicPortrait` eye on any phone menu. |
| P0-2 | Tongue reads as buttocks | **Partly** | When lit (`10`, `26`, `36`) it now has a front tip, a short groove and speckle, and it works. When empty or dim, the Duo version (`duo-ui-lesson-1-150`, `duo-h2-slam-bite`) is still a broad round dome with a centre crease. When waking (`12`, `18`, `33`) it turns into a hollow U-outline with an oval tip, which reads as a toilet seat or a horseshoe magnet. That is a new problem. |
| P0-3 | Stage title drawn over loot | **Fixed** | Tier is now the nameplate subtitle ("Heavy sleeper · Wooden"). The floor is clean. |
| P0-4 | 35% letterbox on non-Duo iPhones | **Fixed** | Full-bleed on the iPhone 18 Pro. The bars are now a lid-plank band (y 0–345) and a chest-front band with the lock (y 1650–1940). That is about 32% filler, but it is in-world and no longer black. |
| P0-5 | Pose screen clipped in portrait | **Unverified** | `25-pose` and `duo-ui-pose-book` both captured Home, not Pose. Fix the capture script and re-shoot. |
| P1-6 | Coins look like cinnamon buns | **Fixed** | Gold star discs, silver keyhole coins, offset stacks (`10`, `17`). |
| P1-7 | Mimic not charming (curtain fringe, porthole eye) | **Partly** | Fleshy eyelid and tilting brow plate: done (`06`, `12`, `13`). Pointed, irregular teeth with canines: done (`12`). **But asleep, the teeth are gone entirely.** The upper jaw is a straight pink tube across the full width (`03`–`11`, `14`–`17`, `26`, `36`, `duo-h1`). The face reads as an eye above a pool noodle. |
| P1-8 | Status pills cover loot; "Freeze!" during CHOMP | **Mostly fixed** | Fixed band under the hinge (`10`, `11`, `18`). "Freeze!" is gone in `13`. Loot can still sit against the pill (`09`: the relic chest touches the pill's bottom-right). |
| P1-9 | Tutorial card hides meter and loot | **Partly** | The meter is now visible (`04`–`07`). The card is still 2 lines and about 150 px tall, and it covers the bottom ~25% of the floor and the tongue tip (`05`, `06`). |
| P1-10 | Pause clipped, collides with bracket, teal SwiftUI style | **Partly** | It is now a brass stud and no longer off-screen. It still sits *on top of* the floor frame's corner bracket and rim in every gameplay frame (`04`: x 760–880, y 1040–1160; `31`/`duo-*`: bottom-left). |
| P1-11 | Bag/bank HUD ambiguous | **Mostly fixed** | IN BAG / BANKED labels, open pouch, cream count when above 0, "+10" pop-up (`09`). The fly-in loot still covers the BANKED label and the NOISE meter (`15`, `16`: "BAN…ED"). |
| P1-12 | Results has no art, dead space | **Mostly fixed** | Portrait reacts to the run: smug teeth when bitten (`19`), asleep when hushed (`20`), golden (`21`). Chest strip, rank bar with track and NEW relic row (`duo-ui-results`). New: the stat row is clipped by the buttons (see #9). |
| P1-13 | Codex relics primitive and duplicated | **Fixed** | 24 unique outlined relics on velvet tiles, dice with pips, blurred locked silhouettes, subtitle padding, bottom fade (`22`, `23`). |
| P1-14 | Cover reads as the Amazon smile | **Partly** | It now shows the Home chest with a keyhole, a teeth line and Zs. There is no eye or fang peek. Layout is top-aligned with 55–65% empty below (`27`, `duo-ui-cover`). |
| P2-15 | Badges duplicated, flat, small | **Partly** | 12 unique outlined motifs, tier-coloured rings, ~60% fill. Motifs are reused relics that don't match the achievement (see #13). Royal is still not a crowned chest. The locked state is nearly invisible (`40`). |
| P2 misc | Home truncation | **Fixed** | Numbers only on phone, "Codex 9/24" on Duo. |
| | Home dead space y 950–1310 | **Not fixed** | `01`/`02`: empty band y 960–1260. |
| | Home "Slide the lid up…" copy | **Fixed on Duo / not on phone** | The Duo chest peeks with the hinge (`duo-ui-home-150`, excellent). On phone it is static text under a static chest. |
| | Torch-low floor light | **Unverified** | `16` has the floor dark (lid shut). `09` has the candle at 50% with the floor fully bright. |
| | CHOMP contrast, shake | **Fixed** (contrast) | Cream fill with a dark-red stroke (`13`). |
| | `08` stray lid slider | **Partly** | The thumb now parks *below* the gum band, outside the velvet (`08`: y 895–940). |
| | Relic reveal text stack | **Partly / unverified** | `15` captured a bank, not a relic reveal. "Hush Chain ×1.5" is right-aligned off the centred stack. |
| | Fold lesson copy | **Not fixed** | `34`: "Slide the lever up… slowly" with a highlight around an *empty* lever track. |
| | Settings icon / rows | **Fixed** | Key glyph, list rows (`24`). |

---

## Top 12 remaining issues

### P0-1 — Bank-moment floor void on Wooden and Iron chests
- **Where:** `14-bank` (Wooden) and `37-chain-badge` (Iron-bound). When the lid shuts, the whole floor half is bare `#0A1416`:
  - the floor frame, corner brackets, side planks, chest-front panel and lock all vanish;
  - the bag strip, NOISE meter, candle, pause stud and CHAIN medal are left floating in black.
- **Contrast:** Gilded (`15`) and Royal (`16`) keep the frame and only darken the interior. So this is a per-tier layering/alpha bug, not a design choice.
- **Why it's P0:** it hits the first chests every player banks, on the game's core reward beat, and it looks like a crash.
- **Fix:**
  - Darken only the interior velvet/tongue node (alpha → 0.85 black overlay).
  - Keep the frame, front panel and lock at full alpha for every tier.
  - Add a snapshot test per tier for the "lid shut" state.

### P0-2 — The app icon is still the off-style third look
- **Where:** `app-icon-1024.png`: flat fills, no outlines, round orange pupil, square lock plate, puck-shaped coins, rounded-rectangle body. It doesn't match the slit amber eye (`12`), the shield lock (`04`), the pointed teeth (`12`) or the star coins (`10`). It is the first frame on the store page and on the Home Screen.
- **Fix:**
  - Redraw it in the in-game language: 3–4 pt dark outline, top-left highlight, inner shade band.
  - Slit amber eye with an iris starburst, shield lock with keyhole, irregular pointed teeth with 2 canines, star-stamped coins spilling from the seam.
  - Keep the tilted-lid composition (still the best mimic read at 60 px).
  - Line the lid bands up with the body bands, and lighten the iron so it holds at 40 px.

### P1-3 — The sleeping mimic has no mouth
- **Where:** every asleep frame (`03`, `04`, `09`–`11`, `14`–`17`, `26`, `35`, `36`, `duo-h1`, `duo-02`). The gum band is a ruler-straight pink tube across the full width (y 840–900) with a scalloped underside and no teeth. Teeth only drop in from stirring (`06`, `11`). For most of a run the "upper jaw with fangs" reads as an eye on a wall above a pool noodle.
- **Fix:**
  - Always show 5–7 tooth tips (about 30% length) below the gum while asleep, with 2 canines slightly longer. Stirring extends them to 60%, waking to 100% (`12`).
  - Give the gum a lip curve (dips 12 pt at centre, rises at the corners), not a straight bar.
  - Keep the drool glint (already there at x 150, y 905) and add a slow breath (y-scale 1.00→1.02, 2.4 s).

### P1-4 — The tongue still fails when it isn't lit
- **Where:**
  - Waking/freeze: the fill drops out and leaves a U-shaped rim highlight plus an oval tip. In `12` and `18` (x 210–710, y 1090–1410) and in `33` it reads as a toilet seat or horseshoe magnet seen from above.
  - Empty dim state on the Duo (`duo-ui-lesson-1-150`, `duo-h2-slam-bite`, raw x 320–1090, y 330–900): a round-ended dome with a centre crease, which is the R1 buttocks problem again.
- **Fix:**
  - Never hollow it out. In waking, keep the fill and push it toward darker red (+20% saturation, −15% value), and *curl* the tip up (scale y 0.9 at the tip end).
  - Taper the front edge to a real point, about 55% of the base width.
  - Fade the median groove to 0 alpha in dim states.
  - Add papillae at 15% alpha in all states.

### P1-5 — SwiftUI chrome still sits on the brass world
- **Where:**
  - Black capsule hint pills ("Drag the loot into your bag", "Slower…", "Freeze!": `10`, `11`, `18`).
  - Teal glass lesson cards (`04`–`07`, `34`), the teal "Lovely work, little thief." sheet with SF Symbols (`08`, `39`), and the teal resume card (`duo-h3`).
  - The resume card covers the NOISE meter ("…SION") and stacks three prompts at once: the "Open the lid… slowly" pill, "Lift me" and "Lift the lid a little to carry on".
  - Green "CHAIN", "Hushed!" and "Hush Chain ×1.5" text (`10`, `15`) is a colour that exists nowhere else in the art.
- **Fix:**
  - Build one in-world message plate: a parchment or dark-leather strip with brass end-caps and stitched edge, matching the bag strip.
  - Reuse it for hints, lesson steps and the resume prompt; show one prompt at a time.
  - Redraw the lesson-end sheet as a parchment note pinned to the lid, with drawn icons (candle, fang, lock) instead of SF Symbols.
  - Replace the green with the brass/cream palette, or a single "hush" teal used consistently.

### P1-6 — Collisions inside the lid
- **Where:**
  - The lever track pokes through the teeth (`12`, `18`: x 800–870, y 900–940).
  - The thumb overlaps the nameplate's right end (`04`: x 770–890, y 740–785).
  - The thumb parks under the gum band, outside the velvet (`07`, `08`).
  - The Zs drift into the thumb (`10`, `26`, `35`, `36`: x 730–770).
  - "Slide this up… slowly" is written across the eyelashes (`03` y 630–680, `34`, and "Lift this half" in `duo-ui-lesson-1-150`).
  - The bottom of the eye socket touches the nameplate top (y 740 vs 748).
- **Fix:**
  - Recess the lever in its own brass channel (x ≥ 800) that ends above the gum (y ≤ 830), with travel clamped to the velvet.
  - Move the Zs to the upper-left of the eye.
  - Put teaching labels in a fixed slot above the brow plate (y 360–410), never over the eye.
  - Leave a 12 pt gap between socket and nameplate.

### P1-7 — Edge clipping and off-axis numbers
- **Where:**
  - The CHAIN medal sits flush on the screen edge with its "CHAIN" label touching it: right edge in `10`, `14`, `15`, `32`, `35`, `37` (x 835–915, y 1345–1450), left edge in `31`.
  - "Hush Chain ×1.5" is right-aligned under a centred "BANKED +1,407" (`15`).
  - The "0:15" pill crowds the left edge over the candle (`16`: x 5–115).
  - "−10s" touches the candle frame (`13`).
- **Fix:**
  - Inset everything by the safe area + 16 pt.
  - Dock the chain medal into the bag strip next to BANKED, or into the NOISE meter end cap.
  - Make every bank pop one centred stack: eyebrow ("Hushed!"), title ("BANKED +1,407"), sub ("Chain ×1.5").
  - Attach time pills to the candle's brass holder.

### P1-8 — Pause stud sits on the frame bracket
- **Where:** every gameplay frame (phone top-right x 760–880, y 1040–1160; Duo raw bottom-left x 60–170, y 795–905). The brass coin overlaps the iron corner bracket, the frame rim and the velvet at once.
- **Fix:** make the stud *be* the corner bracket's rivet boss, recessed 4 pt into the bracket. Or, on phone, move it into the dead lid-plank band (y 0–345) at the top-right safe inset.

### P1-9 — Results stat row clipped; uneven cards
- **Where:**
  - `19`–`21` and `38`: the stat cards are cut hard by the Home/Again bar ("13" cut in half in `21`, "Hushed" cut mid-word in `38`, and a stray yellow sliver at x 75–150, y 1725 in `19`).
  - The three cards have different heights and baselines (`19`: middle card y 1445–1690 vs the sides y 1480–1655), because "Hushed / banked while it slept" wraps to 3 lines.
  - On phone the NEW relic row is only reachable by scrolling past the clipped area.
- **Fix:**
  - Add a 32 pt gradient mask above the pinned buttons.
  - Use equal-height cards with a 2-line maximum ("Hushed" / "while asleep").
  - On compact height, scale the hero chest to 0.8×, and the score to 0.85× past 5 digits, so stats and NEW relic fit above the fold.

### P1-10 — Fold-mode lesson teaches a lever that doesn't exist
- **Where:** `34-lesson-1-fold`: the card says "Slide the lever up… slowly". The highlight (x 40–135, y 1060–1625) outlines an empty track with no lever, and "Slide this up… slowly" sits over the eye. This was flagged in R1 and is not fixed. (`duo-ui-lesson-1-150` correctly says "Lift this half".)
- **Fix:** in fold mode, always use the hinge copy ("Lift the lid… slowly") with the `duo-h3` hinge diagram, and remove the lever highlight.

### P1-11 — Cover display is top-heavy and has no face
- **Where:** `27-cover` and `duo-ui-cover`. The chest is pinned at the top with 55–65% of the screen empty below. On a folded Duo this is the first thing anyone sees, and it shows a plain chest.
- **Fix:**
  - Centre the group vertically and scale the chest about 1.5×.
  - Let the amber eye glint through the seam every ~5 s, with the tooth tips visible.
  - Keep the copy.

### P1-12 — The world outside the chest still looks like a banking app
- **Where:** Home, Results, Codex, Settings and Badges (`01`, `19`, `22`, `24`, `40`) all use the same teal-green gradient with teal rounded cards and a Done bar.
- **Problems:**
  - Home has a dead band (y 960–1260).
  - On phone, the mimic's eye never appears on any menu.
  - On the Duo Codex, the lid half is 900 px of empty title (`duo-ui-codex`).
- **Fix:**
  - Use one dungeon backdrop (dark stone, a warm torch vignette behind the hero) and brass-edged leather cards, or the velvet tile style the Codex already uses.
  - Phone Home: idle-peek the lid every 6 s, showing the eye and teeth like the Duo's 150° state, and move the rank block up to close the gap.
  - Duo Codex: put the selected relic's large sprite and lore on the lid half.

---

## Further P2 polish
- **Badges (`40`, `badges/*`):**
  - Locked state is black on dark grey and nearly invisible; use 35% cream silhouettes.
  - Motifs don't match their achievements: Heavy Bag shows a music box, Hoard a robot-like idol, Fortune a pocket watch that shares the compass's silhouette.
  - Royal is still not a crowned chest.
  - Riveted rings read as portholes; try a coin rim with a milled edge instead.
  - The badge grid uses teal cards while the Codex uses velvet tiles; unify them.
- **Phone filler bands:** the top plank band (17%) and the bottom lock band (15%) are dead except on Daily (`26`), where the pill is a good use. Put the candle timer, chest tier progress or pause up there.
- **Nameplate subtitles:** "Dreamer · fake twitches · Iron-bound · gold ×1.5" (`37`) is crowded and mixes casing. Use 2 tokens maximum, Title Case, and show the multiplier as a brass tab.
- **Loot spawn margins:** loot still spawns against the NOISE meter (`26`: coin at x 230, y 1430) and under the hint band (`09`). Keep 12% clear at both ends.
- **Codex tile jitter:** heights and icon baselines vary in row 3 (`22`: skull tile y 930–1225 vs egg y 945–1215). Use a fixed tile height and a fixed icon box.
- **NEW relic row on Duo Results:** the right two-thirds of the card is empty; add the relic's one-line lore. The Music Box is drawn red here and silver on the Heavy Bag badge; use one sprite.
- **Capture gaps:** `25-pose`, `duo-ui-pose-book` (both Home) and `15-relic` (a bank) don't show what their names say. Fix and re-shoot before the store set.

---

## What's great (keep it)
1. **Hinge-reactive Home on the Duo** (`duo-ui-home-150`). The lid lifts with the device and the eyelashes, teeth and tongue peek out under "Shh… something's peeking." This is the frame that gets a game featured. Lead the App Store set with it.
2. **The eye and brow plate.** Closed lashes, a gold slit cracking open, then a full amber cat-eye glare. The brass brow plate goes flat, then a V, then a sharp V (`04`, `06`, `12`, `13`). It reads instantly and has personality.
3. **Full-bleed chest with tier progression in the frame.** Wooden, iron bands (`37`), gilded with a ruby brow (`09`), royal maroon with gems and crown (`16`). The tier now changes the whole screen, not just the lid.
4. **The HUD is in-world and legible.** The leather strip with IN BAG / BANKED stamps, the open pouch that fills (`12`: gems and coins visible in the mouth), the candle, and the segmented meter with its teeth end cap.
5. **Codex and Results now belong to the game.** Real relic sprites, and the Results portrait changes with the run (smug with teeth after bites, Zs when hushed, golden on a gold run). The chest strip with "bit" and Zz tags tells the story of a run at a glance.
6. **Typography and voice.** The cream CHOMP! with a dark-red stroke, the "Lovely work, little thief." header, and names like "Wary Wendell" and "The Ring of Mild Invisibility". Keep it all.

---

## App Store screenshot readiness

| Frame | Usable? | Why / what's needed |
|---|---|---|
| `duo-ui-home-150` (rotated) | **Yes** | Hero shot. Add a caption panel. |
| `duo-h1-slow-open-160` (rotated) | After P1-3 | Great loot spread; the toothless gum weakens it. |
| `10` / `32` / `35` (phone run) | After P1-5, P1-7 | Full-bleed and readable; the pill and the clipped CHAIN medal hurt. |
| `12` / `18` (waking) | After P1-4 | Big drama; the hollow tongue reads as a toilet seat. |
| `13` (bite) | **Yes** (after P1-8) | Strong. |
| `16` (royal) | Re-shoot open | Best tier art, but the floor is dark in this capture. |
| `19`–`21` (results) | After P1-9 | Good portrait; the clipped stats show. |
| `22` / `23` (codex) | **Yes** | Clean. |
| `01` (home, phone) | Borderline | Dead band, static chest. |
| `14`, `37` | **No** | Floor-void bug. |
| `27` / `duo-ui-cover` | No | Top-heavy and empty. |
| `40` (badges) | No | Locked state invisible, off-style cards. |

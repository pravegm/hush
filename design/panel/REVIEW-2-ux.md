# Review 2: UX, clarity and onboarding (senior game UX lead)

*Inputs: my REVIEW-1-ux.md (6.5), GAME-DESIGN.md, ROUND-2.md; the copy and logic in `Hush/UI/` (PlayHUD, PoseCards,
HomeView, ResultsView, HushTheme) and `Hush/App/` (LessonScript, AppRules incl. HintGate); Core's `currentHint()`. Frames:
the phone set `artifacts/ci6/screenshots/01–40` and the Duo simulator set `artifacts/duo3/duo-screens/duo-screens/`
(turned 180° on purpose, read rotated). I did not edit any file.*

## Score: 8.0 / 10. Verdict: the in-chest clarity is now at launch standard; two small P0s stand between it and ship

This is a big step. Every R1 P0 on the HUD has landed: **IN BAG / BANKED** plates that never swap, a **NOISE** meter
with teeth at the full end, the stakes card, the lever drawn and pointed at, the bite that says what it cost
("CHOMP! / Too loud! / −179", "−10s" off the candle), the candle countdown, traits and tiers on the lid nameplate, the
hint moved to the fold, and no letterbox bars. A first-timer can now answer "what do I do, what's at risk, what's my
score, why did I lose" from the screen alone. That is exactly what the sister games lacked.

What keeps it from 8.5+:
- two real clarity bugs at the two most important moments: the Duo's very first lesson step, and the instant the
  mimic wakes;
- the new R2 systems (the Hush Chain and the golden mimic) arrive with no explanation;
- Results hides its meaning below the fold on a good run;
- several R2 claims (lesson steps 2 and 4, the Duo pose card, the golden mimic) have **no frame proving them**.

Fix the two P0s (about half a day, both are one-function changes) and P1-3 to P1-6 (about a day of copy and layout),
and I'd score it 8.5–9.

## First-chest comprehension test (round 2)

| Question | Answer from the frames | R1 | R2 |
|---|---|---|---|
| Open slowly? | Phone: "Slide the lever up… slowly." plus a ringed lever with an arrow (03). Duo: "Lift this half" glowing (duo-ui-lesson-1-150), **but see P0-1** | ✅ | ✅ phone / ⚠️ Duo |
| What's the noise meter? | The "NOISE" plate, 20 segments, teeth at the full end, never covered (03–07). "Watch the noise" plus a ring in code (step-2 frame not captured) | ❌ | ✅ |
| Drag to bag? | "Drag the coin into your bag." The pouch is a clear target and loot piles in it (12, 26) | ✅ | ✅ |
| IN BAG vs BANKED? | Labelled plates; the bag shows "+10"; the bank shows a big "BANKED +1,407" with coins flying to it (09, 15, 16) | ❌ | ✅ (the "not safe" idea only comes via the final card) |
| Shut to bank? | Lesson "Slide the lever down to keep it."; hint "Slide it down to keep it"; final card "Shut the lid to bank it". Three verbs for one act (P1-5) | ⚠️ | ⚠️ |
| The candle? | "Candle out = run over" on the final card; "0:15" countdown by the candle (16); "+6s" on the flask. The candle itself is never pointed at | ❌ | ✅ (weak until the last 15 s) |
| What a bite costs? | "Too loud!" plus "−179" plus "−10s", and the hint is cleared (13). Excellent | ⚠️ | ✅ |
| Hushed? | "Hushed!" pops over BANKED (15); Results says "Hushed: banked while it slept" with 💤 on the strip (20) | ❌ | ✅ |
| Hush Chain? | A "CHAIN ×1.2" medallion on the rim (09, 10, 37) and a "Hush Chain ×1.5" pop (15). **Nothing says what it is or how to grow or keep it** | — | ❌ (P1-3) |
| Golden mimic? | No frame shows one (36 is `expect-miss` and shows a plain Snorer). Only a glowing gold chest in the Results strip, with no legend | — | ❓ (P1-8) |

## R1 issues: status

| # | R1 issue | Status | Evidence / what's left |
|---|---|---|---|
| 1 | Bag and bank unlabelled | ✅ Fixed | "IN BAG"/"BANKED" plates; same sides when turned (31, duo frames). Left: no "Not safe yet" sublabel; VoiceOver reads "In bag" only (P1-9) |
| 2 | Noise meter unlabelled and hidden | ✅ Fixed | NOISE plate, teeth icon, the lesson band clears it in 03–07. Step-2 ring unverified in frames |
| 3 | Lesson never teaches the stakes | ✅ Fixed | 08/39: three icon rows plus "Got it" / "Not yet, take me home". Nit: the bite row uses a ⚠️ triangle, not teeth |
| 4 | Phone lever invisible | ✅ Fixed | Lever always drawn, step 1 rings it, "Slide this up… slowly" (03) |
| 5 | Duo pose hand-off | ⚠️ Partly | Animated turn-and-lift diagram, "I've stood it up" button and the floor-half body copy are in code. But "Turn it **round**" says 180° to a UK reader (P1-6), no frame shows the card (duo-ui-pose-book shows Home), and the lesson's first step now contradicts itself (P0-1) |
| 6 | Bite cost unclear | ✅ Fixed | 13 is a model bite frame |
| 7 | "Torch" copy, no low warning | ✅ Fixed | "candle" everywhere; 0:15 countdown; "Candle's low. Bank it!" hint; "+6s" flask |
| 8 | Personalities and tiers invisible, "×1" jargon | ✅ Fixed | "Light sleeper · Wooden", "Snorer · Gilded · gold ×2", "Dreamer · fake twitches · Royal · gold ×3". A one-time "Gilded! Gold ×2" step-up wasn't seen |
| 9 | Arrival tag over loot | ✅ Fixed | It's on the lid nameplate now |
| 10 | Hint band in the drag path | ✅ Fixed | The band sits at the fold edge (09–12). Its right end can still touch a back-row item (09, the relic box) |
| 11 | Phone letterboxed | ✅ Fixed | Extension art: lid planks above, front wall and lock below; no bars |
| 12 | Banking reads small | ✅ Mostly | "Hushed! / BANKED +1,407" centred (15). The first-time meaning ("It never stirred.") is missing; the stagger can't be checked from stills |
| 13 | Results unexplained, dead gap | ⚠️ Partly | Sublabels, chest strip, "751 short of your best" and named achievements (in code) are done. On a long run the tiles, rank and achievements fall below the fold behind the buttons (21, 38). The first run reads "Best 3,849" (19) (P1-4) |
| 14 | Home truncation and empty states | ✅ Mostly | "0/24", the rank sliver, "Next: Cutpurse", "No haul yet". Left: the phone shows icon-only Codex/Badges, and a ~300 pt dead gap under the caption remains (01, 02) |
| 15 | P2 polish | ⚠️ Partly | Codex ✅ (2-line subtitle, distinct silhouettes, "Tap a relic to read it"). Settings ✅ "Play sound on silent". Daily marker ✅ "DAILY DUNGEON · OCT 27". Dynamic Type ⚠️ (`UIFontMetrics` capped at 1.3× on menus; no Large frames captured). Colour-only meter ❌. VoiceOver stage announcements ❌. "Use on-screen lever" setting ❌ |

## Top 12 remaining issues

### P0: must fix before launch

**P0-1. Duo lesson step 1 gives two opposite instructions at once.**
- duo-ui-lesson-1-150 (hinge at 147°): the band says **"Close it a little, nearly upright…"** while the lid glows
  **"↑ Lift this half"**.
- `LessonOverlay` always draws `arrow.up` + "Lift this half" when `marksLid`. `LessonScript.line` changes with the
  angle, but the marker doesn't.
- The pose window is 90–112°, so most people who stand it "like a laptop" (120–150°) land here. Their very first
  instruction contradicts itself.
- **Fix:** drive the marker from the same angle branch as the line:
  - θ > 112°: arrow **down**, **"Lower this half a little"**; band **"Close the lid a little, nearly upright…"**
  - θ < 90°: arrow up, **"Lift this half a bit more"**; band **"Lift it a little more…"**
  - θ ≥ 168° or no angle: arrow up, **"Lift this half"**; band **"Stand your Duo like a little laptop."**
  - Inside the window: a green tick plus **"Hold it there…"** for the 0.5 s hold, so passing the step feels earned.
  - Add a LessonScript test that the marker's direction and the line never disagree.

**P0-2. When the mimic wakes, "Slower…" can stay up instead of "Freeze!".**
- In 12 and 33 the meter is in the red with the eye wide open, and the hint still says "Slower…". 18 (static)
  correctly shows "Freeze!".
- Core returns `.freeze` at Waking. But `HintGate.update` only fast-tracks an urgent hint when the shown one is *not*
  urgent (`urgent = isUrgent(wanted) && !isUrgent(shown)`). Slower → Freeze therefore waits for `settle` plus
  `minShow`, up to about 0.7 s.
- That is exactly the window in which the player decides whether to keep moving, and "Slower…" tells them to keep
  going.
- **Fix:** add `if wanted == .freeze && shown != .freeze { shown = wanted; shownAt = now; return shown }` before the
  generic rule, and add a HintGate test (Slower shown, Freeze wanted → Freeze on the same frame).

### P1: fix before launch if at all possible

**P1-3. The Hush Chain is unexplained.**
- What the player sees is a "CHAIN ×1.2" medallion on the rim, a "Hush Chain ×1.5" pop and, on Results,
  "Longest Hush Chain: 3".
- Nothing says that it multiplies gold, that it grows by banking while the mimic sleeps, or that a stir breaks it.
  It reads as a mystery number, the "half-baked" signal again.
- **Fix:**
  - **First `chainUp` ever:** a hint-band banner (≤ 6 words, shown about 2 s) **"Hush Chain! Sleepy banks pay more"**.
  - **First `chainBroken`:** **"It stirred. Chain broken."**
  - **Medallion caption:** "CHAIN" becomes **"GOLD ×1.2"** under the linked-rings emboss, so the number says what it
    multiplies.
  - **Results:** **"Longest Hush Chain: 3 (gold ×1.3)"**.
  - **Medallion position:** inset it so it clears the screen edge. On phones it touches the right edge (09, 15, 37).

**P1-4. Results hides its meaning on a good run, and the first run under-celebrates.**
- **21/38:** with 13–15 chests, the strip takes 3 rows and pushes the stat tiles, the rank bar and the named
  achievements under Home/Again. The tiles show as cut-off tops ("13", "Hushed…"), and nothing hints that the page
  scrolls.
- **19:** the very first run shows **"Best 3,849"** (the same number as the haul), because `showsNewBest` needs
  `previousBest > 0`.
- **Tiles:** the three tiles have different heights and misaligned tops (19, 20).
- **Fix:**
  - On phones, put the 3 stat tiles **above** the chest strip.
  - Cap the strip at 2 rows (12 chests) plus a **"+3 more"** chip.
  - Add a bottom fade with a small chevron when the content scrolls.
  - Pin tile heights equal, with the detail line reserved even when empty.
  - First run: the pill **"First haul!"** and, under it, **"Now beat it."** (not "Best X").
  - Add a one-line legend under the strip, shown only when relevant: **"💤 hushed · teeth = bitten · gold = golden
    mimic"**.

**P1-5. One act, three verbs: "keep", "bank", "shut".**
- The lesson says "Slide the lever down to keep it."; the run hint says **"Slide it down to keep it"** (two "it"s:
  the lever? the loot?); the final card says "Shut the lid to bank it"; the plate says BANKED.
- In 06/07 the bank step even shows IN BAG 0, so "it" points at nothing. That may be the capture (see P1-7), but the
  copy should survive it.
- **Fix (≤ 6 words, the word "bank" everywhere, because it matches the plate):**
  - Hint `.shutToBank`: slider **"Slide the lever down to bank"**; hinge **"Ease the lid shut to bank"**.
  - Lesson bank step: **"Slide the lever down to bank it."** / **"Ease the lid shut to bank it."**
  - Lesson praise (unchanged): "Banked! Gently does it."
  - Bag plate, first 3 runs while bag > 0: the sublabel **"not safe yet"** under IN BAG (the R1 ask; the amber warm
    glow already exists in `SceneFloorHUD`).

**P1-6. Duo pose card: "Turn it round" means a half-turn, and the card is unproven.**
- The card title is **"Turn it round. Lift the glowing half."**, but the motion is a quarter-turn. In UK English
  "turn it round" is 180°.
- Settings uses the same phrase for the 180° canvas flip ("Turn the chest round"), so the two collide.
- No frame shows the card: duo-ui-pose-book captured Home, because the auto-portrait now skips it.
- **Fix:**
  - Title **"Turn it sideways. Lift the glowing half."**; body unchanged ("Keep the other half flat, nearest you.
    That's the floor.").
  - CI: add a `pose=book` demo capture that holds the card (no auto-portrait), and a compact-width capture.

**P1-7. The lesson frames don't prove the lesson.**
- 04 ("lesson-2-open") shows step 3, "Drag the coin…". 05 shows the same step again.
- 06 ("lesson-4-freeze") shows step 5, "Slide the lever down to keep it.", with the meter in the amber.
- 07 shows step 5 with IN BAG 0 and BANKED 0.
- So "Open… slowly. Watch the noise." with the meter ring, "It's stirring. Freeze!" and the pay-off of a banked coin
  (BANKED > 0) have never been seen on screen.
- **Fix (CI):** make the `lessonStep=` demo seed the state each step needs:
  - step 2: lid cracked, ring visible;
  - step 4: the scripted stir at 0.55, red-bordered card;
  - step 5: the coin in the bag (IN BAG 8);
  - plus one "banked" frame (BANKED 8, "Banked! Gently does it.").
- Re-shoot 04–07. Until then, R2's "Watch the noise" and the freeze step are unverified.

**P1-8. The golden mimic is unseen and unexplained.**
- 36 is `expect-miss`: a plain "Puffing Percy · Snorer · Wooden".
- The nameplate copy ("GOLDEN · gold ×2 · light sleeper") is in `SceneLid`, but there's no frame of the gilded chest,
  the sparkle or the "×2" coins. Nothing tells the player "rare, risky, worth it".
- **Fix:**
  - On the first golden arrival, show a hint-band banner **"A golden mimic! Double gold."** (5 words). Keep the
    nameplate's "light sleeper".
  - CI: `golden=1` must actually land on the golden chest for the frame.
  - Results legend: see P1-4.

**P1-9. VoiceOver in a run knows only "In bag".**
- `accessibilityHooks` exposes `hud.bag` as "In bag" plus a count. BANKED, the noise stage, the candle and bites are
  SpriteKit-only and silent. The only announcement in the app is `.screenChanged` on the cover.
- **Fix:**
  - Add elements for **"Banked, 1,118 gold"** and **"Candle, 42 seconds"**.
  - Post `.announcement` on stage changes: **"It's stirring."** / **"It's waking. Freeze!"** / **"Chomp! Lost 179
    gold."** / **"Banked 975 gold."**
  - Make the bag's label **"In bag, 179 gold, not safe yet"**.

### P2: polish

**P2-10. The between-chest beat looks broken in stills.**
- In 14 and 37 the whole floor and front wall vanish. Black teal is left, with the candle, the meter and the plates
  floating in it.
- In motion it may be brief, but it's the "unfinished app" look the juror flagged.
- **Fix:**
  - Keep the front wall, the lock and the table edge drawn during the swap, and dim only the interior.
  - Show **"Next chest…"** in the hint band while it slides in.

**P2-11. The meter is colour-only, and the jingle tick is unexplained.**
- Stirring and Waking are told apart by green, amber and red alone.
- R2's bag-jingle floor draws a white tick in the meter (12, 26) that nothing explains. Players will wonder why the
  noise won't drop to zero.
- **Fix:**
  - Swap the plate word by stage: **"NOISE"** → **"STIRRING"** → **"WAKING!"**. The teeth icon opens progressively.
  - The first time the floor passes 0.10, show the hint **"Full bags jingle. Bank soon."** (5 words). It also teaches
    the gamble.

**P2-12. Home, cover and small seams.**
- **Home (01, 02):**
  - Show words on the phone: **"Codex 9/24"** and **"Badges 7/12"**, as the Duo already does. Icon-only "0/24" means
    nothing to a first-timer.
  - Fill the ~300 pt gap under the caption with the last run (**"Last haul 4,449 · 8 chests"**), or pull the chest
    down.
- **Cover on a phone-sized canvas (27):** two-thirds of it is empty. Centre the stack vertically.
- **Settings:** add **"Use the on-screen lever"** ("For a stiff or worn hinge.") on the Duo, as R1 asked.
- **Dynamic Type:** capture Results, Codex, Settings and Home at Large and at AX1 in CI. The code scales them (capped
  at 1.3×), but no frame proves "no clipping" yet.

## Strengths (keep these)
1. **The bite frame is textbook.**
   - "CHOMP!", "Too loud!", "−179" and "−10s" each answer one question (what happened, why, what it cost in gold, and
     in time).
   - The hint is silenced, and the eye and teeth sell it.
2. **The HUD now reads like a game, not a prototype.**
   - Labelled leather plates, a pouch you can see loot pile into, a NOISE strip with teeth at the end, and a candle
     that becomes a "0:15" clock when it matters.
   - All of it is on the sharp half and never swaps sides.
3. **The lesson's final card is the stakes in one glance.** "Candle out = run over / Too loud? It bites your bag /
   Shut the lid to bank it", with an escape hatch ("Not yet, take me home").
4. **The nameplate does strategy for free.** "Light sleeper · Wooden" and "Dreamer · fake twitches · Royal · gold ×3"
   turn charm into decisions, and keep text off the loot.
5. **Results tells the run's story.**
   - The chest-by-chest strip (💤, "bit", values) makes Hushed and bites legible.
   - "751 short of your best" pulls toward Again.
   - The sums add up: 19 and 20 total exactly.
6. **The meta screens look finished.**
   - Codex: distinct silhouettes, "Tap a relic to read it".
   - Badges: a real screen with plain rules ("Bank a chest without the mimic ever stirring.").
   - Settings: "Play sound on silent".
   - The Daily marker "DAILY DUNGEON · OCT 27".
   - The closing card is calm and has an exit.

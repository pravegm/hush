# Review 3: UX, clarity and onboarding (senior game UX lead)

*Inputs: my REVIEW-2-ux.md (8.0), ROUND-3.md (founder decisions); the copy and VoiceOver code in `Hush/UI/`
(PlayHUD `HushCopy`, LessonStepCard, HintLine, PoseCards, ResultsView `ChestStrip`, HomeView) and `Hush/App/`
(LessonScript `LiftCue`, AppRules `HintGate` / `RunTip` / `causeLine` / `chainLine`, GameController `announce`).
Frames: `artifacts/ci8s/01–47` per `captures.tsv`. I did not edit any file.*

## Score: 8.8 / 10. Verdict: launch-ready on clarity: **yes**

Both R2 P0s are fixed in code and on screen. Every R2 P1 has landed or mostly landed. For the first time the lesson
frames show the lesson: lid ring, meter ring, the red "It's stirring. Freeze!" card, IN BAG 24 "not safe yet", then
"Banked! Gently does it." A first-timer can now answer every question in my comprehension test from the frames alone,
including the two R2 gaps (the Hush Chain and the golden mimic).

What's left is finish, not comprehension. Two P1s are visible in almost every in-run frame, so they will be in every
store screenshot:
- text runs into the brass end-caps of the new in-world plates;
- the chain medal is clipped at the screen edge.

Both are layout constants, about half a day together. Fix them before the store capture and this is a 9. Nothing
below blocks launch on clarity.

## First-chest comprehension test (round 3)

| Question | R2 | R3 | Evidence |
|---|---|---|---|
| Open slowly? | ✅ phone / ⚠️ Duo | ✅ | 03 lever ring + arrow; 34 fold: band "Stand your Duo like a little laptop." and marker "↑ Lift this half" agree |
| Noise meter? | ✅ | ✅ | 04: "…Watch the noise." with the meter ringed |
| Freeze? | ⚠️ | ✅ | 06 red lesson card; 12, 18, 33 "Freeze!" at Waking (no stale "Slower…") |
| Drag to bag? | ✅ | ✅ | 05, 10 |
| Bag vs bank? | ✅ | ✅ | "not safe yet" under IN BAG (07, 12, 33, 36); one verb "bank" in the lesson, the hints and the final card (07, 08, 36, 39) |
| Candle? | ✅ | ✅ | 08 "Candle out = run over"; 16 "0:15" beside the candle, not over it |
| Bite cost? | ✅ | ✅ | 13 "CHOMP! / Too loud! / −179 / −10s" |
| Hush Chain? | ❌ | ✅ | 09/14 tip "Hush Chain! Sleepy banks pay more"; medal reads "GOLD ×1.2"; the break tip and "Longest Hush Chain: 3 (gold ×1.3)" are in code. **Medal clipped (P1-2)** |
| Golden mimic? | ❓ | ✅ | 36b gilded frame, sparkle, "GOLDEN MIMIC · Heavy sleeper", "×2" on loot. **The numbers disagree (P2-3)**; the banner isn't captured |
| Why did it end? | — | ✅ | 19 "The mimic bit you 2 times. Candle out."; 20 "Your candle burned out." |

## R2 issues: status

| # | R2 issue | Status | Evidence / what's left |
|---|---|---|---|
| P0-1 | Duo step 1 contradicts itself | ✅ Fixed | `LessonScript.liftCue` drives both the marker and the line (lift / lower / hold / liftMore), with a tick on "Hold it there…". 34 agrees. Only the `.lift` branch is in frames; lower and hold rely on the test |
| P0-2 | "Slower…" over a waking mimic | ✅ Fixed | `HintGate.update` puts `.freeze` up on the same frame. 12 and 33 show "Freeze!" with the eye open |
| P1-3 | Hush Chain unexplained | ⚠️ Mostly | Tip, break tip, "GOLD ×1.x" and the Results line are all done. The medal's "HUSH CHAIN" label is cut to "HUSH CHAI" and the medal sits ~10 pt from the edge (07b, 09, 10, 15, 16, 31, 37) → P1-2 |
| P1-4 | Results hides meaning, first run | ✅ Mostly | Tiles above the strip, equal heights, "FIRST HAUL! / Now beat it." (19), "+4 more" (21, 38), a chevron fade, the cause line. Left: row 2 of the strip sits under the fade, and the legend, chain line, rank and badges are all below the fold on phones (P2-5) |
| P1-5 | Three verbs | ✅ Fixed | "Slide the lever down to bank" / "Ease the lid shut to bank" everywhere; "not safe yet" sub-label |
| P1-6 | "Turn it round", pose unproven | ✅ Fixed | 25 "Turn it sideways. Lift the glowing half."; "Play anyway" in code; the VO label says "a quarter turn" |
| P1-7 | Lesson frames don't prove the lesson | ✅ Fixed | 03 → 04 → 05 → 06 → 07 → 07b → 08 each show their own step. Nit: 06 shows IN BAG 0 at the freeze step (the step-3 coin isn't seeded into the bag) |
| P1-8 | Golden unseen | ✅ Mostly | 36b is unmistakable. The banner "A golden mimic! Double gold." isn't in a frame, and the medal says ×3 while the loot says ×2 (P2-3). 36 (`golden-mimic`) actually shows a Gilded snorer: the caption is wrong |
| P1-9 | VoiceOver knows only "In bag" | ✅ Fixed (code) | `hud.banked` / `hud.candle` / `hud.noise` elements; "In bag, N gold, not safe yet"; announcements for stirring, waking + Freeze, Chomp + loss, Hushed / Banked, candle low and callouts. Not checked on a device |
| P2-10 | Bank beat looks broken | ⚠️ Partly | Frame, lock and HUD now stay (14, 16, 37), but the interior goes to near-black, and there's no "Next chest…" (P2-4) |
| P2-11 | Colour-only meter, jingle tick | ⚠️ Partly | The jingle tip "Full bags jingle. Bank soon." is in code. The plate still says "NOISE" at Waking (12, 18, 33) (P2-6) |
| P2-12 | Home, cover, Dynamic Type | ✅ Mostly | Phone Home shows "Codex 9/24 · Badges 7/12" plus the rank and "Best 5,200" (01, 44); Large frames are captured with no clipping. Left: AX-L truncation, cover seams (P2-7, P2-8). "Use the on-screen lever" was never added (the founder didn't ask; "Play anyway" covers the refusal case) |

## Remaining issues

### P0
None.

### P1: fix before the store capture (both are visible in nearly every in-run frame)

**P1-1. Plate text runs into the brass end-caps.**
- With decision 5, every hint and lesson card sits on a plate with rivet caps at both ends. The text padding
  ignores them:
  - `HintLine` uses `.padding(.horizontal, 14 * scale)`;
  - `LessonStepCard` uses `.padding(.leading, 22 * scale)`.
- Effect in the frames:
  - The first letter sits under or on the left cap: "Drag" (05), "It's" (06), "Slide" (07), "Banked!" (07b),
    "Stand" (34).
  - The last letter touches the right cap: "bag" (10, 15, 31, 32, 35, 36b), "more" (09, 14), "bank" (36).
  - On the wide tip, the plate also butts into the pause coin (09, 14).
- **Fix:**
  - Expose `PlateBackground.capInset` (the cap width) and pad by `capInset + 8 pt` on both sides, for the hint,
    banner and lesson card alike.
  - Let `HintLine` clamp its width to `band.width − pauseCoin.width − 16 pt`, so `minimumScaleFactor` does the
    shrinking rather than the caps.
  - Add a snapshot or unit check that the text frame never intersects the cap rects.
- **Copy (optional, buys room):** "Hush Chain! Sleepy banks pay more" → **"Hush Chain! Calm banks pay more"**.

**P1-2. The chain medal is clipped and touches the edge.**
- The small-caps "HUSH CHAIN" overruns the medal ("HUSH CHAI", with the right stroke cut). The medal sits on the
  corner bracket about 10 pt from the screen edge (phone 07b, 09, 10, 15, 16, 36, 37; fold 31 on the other side).
- This was a Scene P0 line in ROUND-3 ("≥ 16 pt inset everywhere; the CHAIN medal moves inside the frame").
- **Fix:**
  - Size the medal to its longest label plus 12 pt, or use **"CHAIN"** in small caps over **"GOLD ×1.2"**.
  - Move it left until it is ≥ 16 pt clear of the screen edge and off the bracket. Between the meter's teeth and the
    BANKED plate's top edge there is room if the meter is shortened by the medal's width.

### P2: polish (ship without them if you must)

**P2-3. Golden: three numbers for one chest.**
- 36b: the seal says **GOLD ×3**, the loot pops **×2** and the banner says "Double gold." The seal is the real total
  (tier × golden); the pop is only the golden part.
- **Fix:** the loot pop shows the chest's total (**"×3"**), matching the seal. Banner: **"A golden mimic! Extra gold!"**,
  so no number can contradict the seal.
- CI: hold a frame on the banner, and re-caption 36 (it's a Gilded chest, not golden).

**P2-4. The bank beat is a black void.**
- 14, 16, 37: the interior goes near-black for the swap. 14 shows only the tip over black.
- **Fix:**
  - Dim the interior to about 40 % instead of black.
  - When no callout is up, show **"Next chest…"** in the hint band during the slide-in.

**P2-5. On phones, Results still hides the story's second half.**
- Row 2 of the strip sits under the fade (19, 21, 41). The legend ("💤 = banked while it slept · teeth = it bit · glow
  = golden mimic"), the chain line, the rank bar and the badges are all below the fold. The glowing chest in the strip
  (19, 20, 38) is unexplained unless the player scrolls.
- **Fix:**
  - Put the legend **inside the strip card, above the chips**, at 13 pt.
  - When the story runs to 3 lines (21), cap the strip at **1 row plus "+N more"**.

**P2-6. The meter is still colour-only.**
- Stirring and Waking differ by green, amber and red only (11/12/18). VoiceOver now covers blind players, but not
  colour-blind ones.
- **Fix:** the plate word follows the stage: **"NOISE" → "STIRRING" → "WAKING!"**. Reuse `HushCopy.stageWord`'s
  source of truth.

**P2-7. Dynamic Type at AX-L truncates names.**
- 42: "The Bottomless G…", "Sir Rattlesworth'…". 44: "Today's try…".
- 41 and 45 are identical, so the 1.3× cap holds, and nothing clips.
- **Fix:**
  - Codex names: `lineLimit(3)` + `minimumScaleFactor(0.85)`.
  - The Home Daily detail becomes **"Ready"** when `dynamicTypeSize ≥ .xxxLarge`.

**P2-8. Small seams.**
- 27 (cover): hairlines above and below the chest canvas, and a "z" cut by the top line.
- 07: the flying ruby covers the "IN BAG" label; fly it under the label, as the Scene brief says.
- 07b: "Hush Chain ×1.1" pops on the lesson's first bank, before the tip has ever explained it. Suppress the chain pop
  in the lesson, since the run's first chain gets the tip.

**P2-9. VoiceOver: lesson steps are silent.**
- The lesson line changes, but nothing is announced.
- **Fix:** post `.announcement` with `lesson.line` on each step change, and on praise ("Banked! Gently does it.").

**P2-10. CI: CREAK is unproven.**
- 13b (`expect-miss`) is the bite frame again, so tester 6's "a slam should read as too loud" has no frame.
- **Fix:** freeze on the creak event in a non-bite slam (noise < bite threshold).

## Strengths (keep these)
1. **The lesson is now proven, step by step.** It rings what it names (lever, meter), turns red for the stir, shows
   "not safe yet" on a full bag and pays it off with "Banked! Gently does it." Then the stakes card lists three drawn
   icons, with an exit.
2. **Two real bugs fixed at the root.** The Duo step-1 marker and line now come from one function (`liftCue`), so they
   *can't* disagree again. "Freeze!" beats any hint on the same frame.
3. **One verb, layout-keyed copy.** "bank" everywhere; lever words with no fold, lid words with one (36 vs 39); no
   lever drawn on the fold (31, 33, 34).
4. **Results tells you why.** "RUN OVER / The mimic bit you 2 times. Candle out.", "FIRST HAUL! Now beat it.",
   "751 short of your best", and equal tiles above the strip.
5. **The new systems explain themselves in ≤ 6 words**: the chain tip, the break tip, the jingle tip, and "GOLD ×1.2"
   in place of a mystery number. Tiers and traits stay on the nameplate, with the multiplier seal.
6. **Accessibility is real now.** BANKED, the candle and NOISE are named. Stages, bites and banks are announced; the
   bag says "not safe yet". Large type is captured and doesn't clip.

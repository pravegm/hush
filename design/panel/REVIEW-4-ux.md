# Review 4: UX, clarity and onboarding (senior game UX lead)

*Inputs: my REVIEW-3-ux.md (8.8), ROUND-4.md, `design/notes/app-R4.md`, `scene-R4.md`, `ci-R4.md`. Code checked in
`Hush/UI/` (PlayHUD, HomeView, Pages) and `Hush/App/` (GameController `showCallout` / `publishHUD`, AppRules
`usesSlider` / `turnsRound` / `RunTip`). Frames: `artifacts/ci9s/01–47` and logs; R3 frames `ci8s/30`, `ci8s/39` for
comparison. I didn't edit any file except this one.*

## Score: 8.9 / 10. Verdict: launch-ready on clarity: **yes**

Both R3 P1s are fixed on screen. Every plate's text now clears the brass caps: 03–09, 10, 11, 16, 34, 36 and 08's
leather button. The chain tab reads "CHAIN / GOLD ×1.1", sits ~50 pt from the edge, and always matches the bank
stack's "Hush Chain ×1.1" (14, 14b, 37). Most R3 P2s landed too: one golden number, a 40 % bank beat with
"Next chest…", NOISE → STIRRING → WAKING!, the legend inside the strip, Codex names wrapping, a real CREAK frame.
On the phone, the in-run screen is now clean enough for store screenshots.

The score would be 9+, but R4 broke two Duo screens that R3 had right:
- **Fold Home and the fold lesson's final card are clipped at default text size** (30, 39 vs ci8s/30, 39).
- **The lever still draws on an unturned fold** (32, 13c; the log says `fold=1 turned=0`). A Duo owner who switches
  off "Turn the chest round" will see it.

Neither stops a player understanding the game, so the verdict stays yes. But this is a Duo-first game, so fix both
before the Duo store capture and the founder's device test. Each is small.

## First-chest comprehension test (round 4)
Every R3 ✅ still holds. These changed:

| Question | R4 | Evidence |
|---|---|---|
| Freeze? | ✅ stronger | 06 "STIRRING" + red card; 12/13b/33 "WAKING!" + "Freeze!" (no longer colour-only) |
| Bag vs bank? | ✅ | 07 "not safe yet"; 07b "Banked! Gently does it." with no stray chain pop |
| Hush Chain? | ✅ / ⚠️ | Tab and stack agree (14, 37). The tip is in the logs (`callout Hush Chain!…` at chest 2's lidCracked) but **in no frame**, and "Drag the loot" replaces it within 2.4 s (10). See P2-5 |
| Golden mimic? | ✅ | 36: banner "A golden mimic! Extra gold!", seal ×3, pop ×3. One number at last |
| Slam? | ✅ new | 13b/13c "CREAK!" + "Freeze!" + WAKING!, with no bite |
| Between chests? | ✅ new | 14b "Next chest…" over a dimmed interior, not black |

## R3 issues: status

| # | R3 issue | Status | Evidence / what's left |
|---|---|---|---|
| P1-1 | Plate text runs into the caps | ✅ Fixed | `PlateTextLayout` + `plateTextRect`. 05 "Drag a coin into your bag.", 10 "…your bag", 36 "…Extra gold!" all clear the caps; the hint plate no longer meets the pause coin (09, 11, 16) |
| P1-2 | Chain medal clipped at the edge | ✅ Fixed | "CHAIN / GOLD ×1.x", fully on screen, ~48 pt in, same value as the stack (14, 37). The label is small (~9 pt) and now sits beside a second "GOLD ×" seal (P2-4) |
| P2-3 | Golden: three numbers | ✅ Fixed | 36/36b: seal ×3 = pop ×3; the banner has no number; 36 now really is the golden chest |
| P2-4 | Bank beat is a black void | ✅ Fixed | 14, 14b, 37: interior ~40 %, "Next chest…", no hint (one prompt at a time) |
| P2-5 | Results hides the second half | ⚠️ Mostly | The legend is inside the strip card and adapts (19 "teeth = it bit · glow = golden mimic"; 20/21/38 "zZ = banked while it slept"). Row 2 and the "+N more" tile still sit under the fade (20, 38). P2-7 |
| P2-6 | Meter colour-only | ✅ Fixed | NOISE / STIRRING / WAKING! (06, 11, 12, 16, 33); VoiceOver says "Noise, <stage>" |
| P2-7 | AX-L truncates names | ⚠️ Partly | Codex wraps (42, 46) and the chevron has its own strip (41, 45). **Home at AX-L is worse**: "Codex 9…", "Badges…", "Today' / s try r…" (44). P2-6 below |
| P2-8 | Seams | ⚠️ Partly | Cover hairlines and the clipped "z" are gone (27); the lesson chain pop is gone (07b). The **ruby still covers "IN BAG"** (07), and a bank flyer covers the "B" of BANKED (14) |
| P2-9 | Lesson steps silent for VoiceOver | ✅ Fixed (code) | `LessonDisplay.announcement`; Chomp/Waking interrupt, everything else queues; stirring once per chest. Not device-checked |
| P2-10 | CREAK unproven | ✅ Fixed | 13b: attract mode, CREAK without a bite. But 13c (the "fold" copy) is the phone layout again (P1-2) |
| nit | 06 shows IN BAG 0 at the freeze step | ❌ Not | Still 0 (06) |

R4-brief items I also checked:
- the phone plaque ("Wooden · Chest 1", "Royal · Chest 8") fills the empty panel;
- the turned keyhole no longer reads "!" (31, 33, 34);
- the Relic Hunter lantern reads (40);
- the pose card (25) now draws two halves with the glowing lift half.

## Remaining issues

### P0
None.

### P1: fix before the Duo store capture and the founder's device test

**P1-1. Fold Home and the fold lesson's final card are clipped at default type (a regression).**
- 30: the Settings / Game Center row is cut by the screen edge.
- 39: "Not yet, take me home" is sliced, and the card overruns the floor half.
- R3 fitted both (ci8s/30, 39).
- **Cause:** R4's `ViewThatFits { content; ScrollView { content } }`. Home is at HomeView.swift:42 and the final card at
  PlayHUD.swift:396. The content no longer fits the Duo's ~437 pt half at default size, so the bare ScrollView is
  chosen, and it hard-clips.
- **Fix:**
  - **Make the fitting variant fit on a fold at default sizes.** On a fold, use compact metrics: tile height −8 pt,
    stack spacing 12 → 8, and the final card's width back to R3's.
  - **Add a test** that the non-scroll variant is chosen at `.large` and `.xxxLarge` in a 402 × 437 floor half.
  - **Scroll only at the accessibility sizes,** and then use `FadingScroll` (fade + chevron), anchored so the primary
    action ("Play" / "Got it") is fully visible.

**P1-2. The lever still shows on an unturned fold.**
- 32 and 13c log `fold=1 turned=0`, yet they draw the phone layout's lever (identical to 10 and 13b).
- A real Duo reaches this through Settings › "Turn the chest round" off (`Pages.swift:345`). That screen would say
  "Lift this half" while drawing a lever.
- The pure rules are right: `AppRules.usesSlider` and `ChestScene.showsLever` both need `!hasFold`. So `hasFold` is
  being lost on the unturned path before it reaches the scene (as the Scene note itself suspects).
- **Fix:**
  - Trace `layout.hasFold` from `RootView.content(… fold:, turned: false)` into `ChestScene`.
  - Add a controller+scene test (fold, turn off → `leverShowing == false`, and lid touches drive nothing).
  - Re-shoot 32 and 13c. 13c must actually differ from 13b.

### P2: polish (ship without them if you must)

**P2-4. Two "GOLD ×" numbers on one chest, and the tab is tiny.**
- 15: seal "GOLD ×2" next to the tab's "GOLD ×1.5". 36: "GOLD ×3" next to "GOLD ×1.2".
- Players will ask which one is the real number. The tab text is ~9 pt.
- **Fix:** the tab reads **"CHAIN ×1.5"** on one line (drop "GOLD"), at ≥ 11 pt, and the seal keeps "GOLD ×3".
- Optional: VoiceOver element "Hush Chain, times 1.5".

**P2-5. The first Hush Chain tip is easy to miss.**
- It now waits for the bank beat (correct), then lands at chest 2's lidCracked. It lasts 2.4 s while the player is
  concentrating on a slow lift, and "Drag the loot into your bag" replaces it (10).
- **Fix:**
  - A deferred tip gets **3.5 s**, and a non-warning hint can't replace it for the first 3 s.
  - Add a CI frame of it (chest 2, ~1 s after lidCracked, fresh profile). It's the only on-screen explanation of the
    chain.

**P2-6. Home at AX-L (44) has regressed** since the 1.3× cap was lifted.
- **Fix:**
  - At accessibility sizes, use **one tile per row** ("Codex 9/24", "Badges 7/12" in full).
  - The Daily detail becomes **"Ready"** (as in R3) with `lineLimit(1)`, and the title may wrap.
  - Check "Game Center" (it touches its tile edge).
  - Nothing may break inside a word: "Today' / s try r…" is the worst case.

**P2-7. Results: the strip still runs under the fade.**
- 20 and 38 show row 2 half-hidden, and 38's "+N more" sits under the fade.
- **Fix:** cap the strip at **1 row, with "+N more" as its last chip**, whenever the story is ≥ 2 lines.

**P2-8. Small seams.**
- 07: the dropped ruby sits over "IN BAG". Draw items heading for the bag under the label, as was done for held items.
- 14: a flyer covers BANKED's "B". End the arc under the label.
- 26: the Daily marker almost touches the plaque (~4 pt) and is left-aligned while the plaque is centred. Centre it,
  or merge them: "Daily · Oct 27 · Chest 1".
- 36: "Golden · Heavy sleeper" reverses the order every other plate uses ("Heavy sleeper · Wooden"). Use
  **"Heavy sleeper · Golden"**.
- 06: seed the step-3 coin into the bag so the freeze step shows IN BAG > 0.

**P2-9. VoiceOver bank line omits the chain.**
- "Hushed! Banked 197 gold." → **"Hushed! Banked 197 gold. Hush Chain, times 1.1."** when `chainUp` fires that frame.

## Strengths (keep these)
1. **The plates are solved structurally.** `plateTextRect` plus a fitting layout plus a cap test, not padding by eye.
   Every hint, card and leather button now reads cleanly.
2. **One prompt at a time.** The bank beat is a calm, readable pause: stack → "Next chest…". The golden chest shows
   one number. The chain tab and the stack can't disagree.
3. **The meter speaks.** STIRRING and WAKING! make the core danger readable without colour, and VoiceOver reuses the
   same word.
4. **Slams are taught.** "CREAK!" + "Freeze!" without a bite is exactly tester 6's "too loud" moment.
5. **Results explains itself above the fold:** the cause line, "Opened / chests", and a legend that lists only the
   marks this run used.
6. **The lesson is still the best thing in the build:** ring, red stir card, "not safe yet", "Banked! Gently does it.",
   the stakes card. VoiceOver now hears every step.

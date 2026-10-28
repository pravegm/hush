# Hush: Don't Wake the Mimic — Visual launch review, round 5 (Juror 1)

**Reviewer:** Apple Design Award juror / senior iOS game art director

**Frames reviewed:**
- `artifacts/ci19s/01…47` (iPhone 18 Pro, 1206×2622), `app-icon-1024.png` and `badges/*`, compared with `ci9s` (the R4 set).
- Spot-checked against the latest Duo simulator set, `duo11`: `duo-06`, `duo-h3` and `duo-ui-settings`.
- Frames 30–39 are the Duo layout on a phone, shown rotated 180°. Frames 41–47 are Large Dynamic Type.
- Coordinates are in the 920×2000 display frame. Multiply by 1.31 for native pixels.

---

## Verdict

**Score: 9.2 / 10. Launch verdict: YES.**
- Score history: R1 6.0 → R2 7.5 → R3 8.5 → R4 9.0 → R5 9.2.
- **Condition:** one Duo simulator re-run must show the R10 fixes landed on the device itself (P1-1). This is a verification gate, not more design work.

**What R4 asked for is done.**
- The fold clip is gone.
  - `39`: the lesson-end card sits whole inside the floor half, with its full border, stitching and both buttons.
  - `30`: Home in fold shows every button intact.
- The AX Home screen no longer breaks words (`44`).

**Nothing in the phone set regressed.** The orientation rebuild is invisible in the frames, which is the best outcome it could have had. Every gameplay frame is right way up and in register, in every pose:
- the HUD, candle, meter, pouch, chain tab and pause coin
- the phone layout (`09`–`18`)
- the fold layout (`31`, `33`, `34`)
- phone-turned (`35`)

**Why this is a featured-quality game:**
- The chest-as-jaw premise reads in one glance.
- The face progression (asleep → stirring → waking → CHOMP) is genuinely funny.
- The tiers escalate beautifully, from Wooden through Iron, Gilded and Royal to Golden.

**Why it isn't a 9.5:**
- The secondary chrome is still generic SwiftUI: teal buttons, plain coin, porthole badges.
- A few in-game shouts stack against each other.

Neither is a launch blocker.

---

## Since R4: improved

| Area | Evidence | Note |
|---|---|---|
| **Fold clipping (R4 P1-1)** | `39`, `30` | **Fixed.** The card and the Home grid fit the half with margin. |
| **AX Home (R4 P1-2)** | `44` | **Fixed.** It's one column, "Daily Dungeon / Today's try ready" stacks, nothing is truncated, and the ⌄ cue shows there's more. |
| Prompts on the chest axis | `12`, `13c`, `33` | "Freeze!" now centres on the eye and lock axis (x=460). |
| Daily plaque collision | `26` | **Fixed.** The plaque is centred in the plank band and clear of the nameplate. |
| Hushed and chain beat restored | `14`, `37` | "Hushed! BANKED +197 / Hush Chain ×1.1" with the CHAIN tab. This is store-worthy again. |
| Results hero | `19`, `21`, `41` | The mimic is now about 200 px wide, the right size against the number. It no longer reads as a speck. |
| Results outcome pill | `19`, `21` | "gold banked · NEW BEST!" on one row buys room for the strip. |
| Settings | `24`, `43`, `47` | The new Vibration and Lid sensitivity rows are cleanly typeset. At AXL the pills stack. The fade and ⌄ appear only when more is below. |
| Pause during bite | `13` | The coin and seat are both hidden, so CHOMP has the floor to itself. |
| Carry on / Home card | `duo-h3` | Leather and brass, a hinge-angle glyph, and clear hierarchy. A good new screen. |
| Zs | `36`, `15` | They now stay on the velvet, clear of the gilded bands. |

## Since R4: unchanged or new nits
- Long hint plates still sit left of the chest axis (P2-2).
- Two shouts now stack against each other in the bank and creak beats (P2-1).
- The torch-low frame got weaker as a store shot: Chest 10 with 18 in the bag, where R4 had a full bag (P2-6).
- The Results-strip "zZ" glyphs are system blue (P2-3). They were blue in R4 as well, and I missed them.

---

## Remaining issues

### P1-1 — The R10 fixes are not yet seen on the Duo simulator (verify before submission)
**Where:** the latest Duo set, `duo11`, still shows all three R9 Duo issues, so it predates R10 or R10 didn't take on the device.

| Frame | What it shows |
|---|---|
| `duo-06` (k=1) | The coin is about 70 px off its brass seat, and the dark recess shows below it. |
| `duo-h3` | An empty black seat ring sits at the top-left corner of the Carry on card. |
| `duo-ui-settings` | The lid half holds only the "Settings" title. On the floor half, "Play sound on silent" runs under Done. |

**Why P1:** these are the Duo, the game's main mode, and two of them are exactly the frames a reviewer hits: pausing, and opening Settings.

**Fix:**
1. Run Duo CI on `c6e046c` or later.
2. Close this only when all of the following are true:
   - `duo-06` shows the coin centred in its seat.
   - `duo-h3` shows no empty ring.
   - `duo-ui-settings` shows the title plus the sound-and-feel card on the lid half, and the rest plus Done on the floor half, with no row under Done.
3. If any one is still wrong, that one is the only thing between this game and submission.

### P2 — Polish (don't block launch, but do before the store shots)
1. **Shouts stack against each other.**
   - **Where:**
     - `13c`: "CREAK!" butts the underside of the "Freeze!" plate (gap ≈ 0).
     - `14`: "Hushed!" touches the hint plate's bottom edge, and the plate repeats the callout ("Hush Chain! Sleepy banks pay more" over "Hush Chain ×1.1").
   - **Fix:**
     - Enforce a minimum 12 pt gap below the active plate for any callout.
     - Better: suppress the hint plate while a bank or creak callout is on screen, keeping R3's one-prompt-at-a-time rule.
     - `14` is a store beat, so do this one.
2. **Long hint plates sit off-axis.** "Slide the lever up… slowly", "Drag the loot into your bag" and "Hush Chain!…" centre at x≈405 (`09`, `10`, `14`, `35`), while short plates centre at 460.
   - **Fix:** cap the plate width at `2 × (coinLeft − pauseGap − axisX)` and wrap to 2 lines beyond it. Every plate then shares the eye and lock axis.
3. **The Results strip uses system-blue "zZ".** The legend and every hushed chest in `19`, `20`, `21`, `38` and `41` carry bright blue glyphs, the only cold blue in a warm amber palette.
   - **Fix:** tint them to the cream/amber Z colour used on the lid (`#E9D3A0`-ish) at about 0.85 opacity.
4. **Royal tier art is hidden under the HUD** (`16`).
   - The purple corner gem is half under the pause coin.
   - The green gem is under the "Candle's low" plate's left cap.
   - The red gem overlaps the candle glass.
   - **Fix:** move the tier corner jewels about 24 pt inward, or skip them in the HUD corners.
5. **Fold lesson scroll crowds the candle** (`34`). Its right cap is within about 5 px of the candle tube.
   - **Fix:** inset the scroll by the candle width plus 12 pt on that side.
6. **Store-shot seed for torch-low.** `16` is now Chest 10 with 18 in the bag, and "IN BAG 18" undersells the tension.
   - **Fix:** pick a seed or pilot that reaches Royal with a full bag (several hundred or more) when the candle is low.
7. **Carried over from R4, all chrome:**
   - Cream instead of green for "Banked! Gently does it." (`07b`).
   - Leather or brass treatment for the teal secondary buttons: Home (`01`, `30`), Results Home, Done.
   - A star-stamped hero coin on Results.
   - Milled rims instead of porthole rings on the badges (`40`).
   - The Heavy Bag glyph reads as a pawn or figure. Use a sack.
8. **Results copy says the bite count three times** (`19`): the subtitle, the headline sentence and the tile.
   - **Fix:** make the subtitle just "Candle out.", or make the headline about the gold, not the count.
9. **Emulation only:** in `31` and `08` the Dynamic Island sits over the floor hasp or plank. It doesn't exist on the Duo. Just don't use these phone-emulation frames as Duo store art.

---

## What's great (keep it)
1. **The orientation rebuild is invisible.** That is the highest compliment it can get. Fold, unturned, phone-turned and Duo k=1 or k=3 all read correctly.
2. **The face system and the tiers** remain the heart of the game: `09` → `11` → `12` → `13`, and Wooden → Iron → Gilded → Royal → Golden.
3. **The lesson-end card in fold (`39`)** is now one of the best frames: a full leather card on the floor half over a sleeping Dozy Doris.
4. **Settings copy** is warm and specific: "Feel every creak, and every careful step." and "The scored Daily always plays Normal." Large Type is handled properly.
5. **The icon** is still the strongest asset: the peeking amber eye, teeth and coins.

---

## App Store screenshot readiness

| Frame | Usable? | Needs |
|---|---|---|
| `app-icon-1024` | **Yes** | — |
| `10` / `36` (loot, golden) | **Yes** | P2-2 is optional. |
| `12` / `13c` (waking, Freeze!) | **Yes** | `13c`: P2-1 CREAK gap. |
| `13` (CHOMP) | **Yes** | — |
| `14` / `37` (Hushed + chain) | **Yes** | After P2-1. |
| `15` (relic) | **Yes** | — |
| `16` (royal, torch-low) | **Yes** | After P2-6 seed and P2-4 jewels. |
| `08` / `39` (lesson end, phone / fold) | **Yes** | — |
| `30` (Home, fold) | **Yes** | — |
| `31` / `33` / `34` (fold gameplay, lesson) | **Yes** | Use Duo-sim captures for Duo store art, not phone emulation. |
| `19`–`21`, `38` (Results) | **Yes** | After P2-3 blue Zs. |
| `26` (Daily) | **Yes** | — |
| `27` (cover) | **Yes** | — |
| `duo-h3` (Carry on) | After P1-1 | Empty seat ring. |
| `duo-ui-settings` | After P1-1 | Row under Done. |
| `01` (Home, phone), `40` (Badges) | Borderline | Teal chrome, porthole rims. |

# Hush: Don't Wake the Mimic — Visual launch review, round 4 (Juror 1)

Reviewer role: Apple Design Award juror / senior iOS game art director
Frames reviewed: `artifacts/ci9s/01…47` (iPhone 18 Pro, 1206×2622), `app-icon-1024.png`, `badges/*`. Frames 30–39 are the Duo layout on a phone, shown rotated 180°. Frames 41–47 are Large Dynamic Type. Duo simulator captures are judged separately.
Coordinates are in the 920×2000 display frame. Multiply by 1.31 for native pixels.

---

## Verdict

**Score: 9.0 / 10 (R1 6.0 → R2 7.5 → R3 8.5 → R4 9.0). Launch verdict: NOT YET. One fix stands between this and a yes, and it should take hours, not days.**

The team did what I asked in R3:
- **P0 typesetting:** fixed everywhere. The hint plates now hug their text between the caps. Lesson-scroll text sits inside the dashed border and wraps onto a second line inside the plate.
- **Chain medal:** fits in both orientations.
- **Cover:** finished.
- **Pose screen:** drawn in the game's own art style.
- **Relic reveal:** has the stage to itself.

Every gameplay frame from 09 to 18 and 36 to 37 is now store-ready, and the tier progression still carries the whole game.

The one thing that keeps it off "yes" is new, and it's in the Duo layout, which is the game's main mode. **In fold mode the floor half's content is hard-clipped at the outer edge.** The lesson-end card in `39` loses its top border, its stitching and half of the "Not yet, take me home" button. In `30`, the Home screen's Settings and Game Center buttons are sheared off. On a Duo-first game, a sliced button on the Duo Home screen is exactly the frame a features editor stops on.

Fix it, confirm on the Duo simulator that the clip is gone, and this is a 9 and a yes. If the Duo simulator already lays these out cleanly and the cut only happens in the phone emulation, the verdict is yes now. Someone needs to check that before submission.

---

## R3 issues: status

| R3 # | Issue | Status | Evidence (R4 frames) |
|---|---|---|---|
| P0-1 | Text overflows the parchment plates | **Fixed** | Hint plates are laid out cap \| text \| cap with clear padding, and the type sits at about 80% of plate height (`09`, `10`, `16`, `36`, `36b`). The lesson scroll keeps its text inside the dashed border, and the 2-line copy grows the plate instead of running over the border (`04`, `05`, `07b`). Fold scroll is clean (`34`). |
| P1-2 | Right-edge HUD: pause, chain medal, hint plate | **Mostly fixed** | The chain medal is now "CHAIN / GOLD ×1.1" with its own end-cap, clear of the bracket (`10`, `14`, `36`), and clear of the left edge in fold (`31`). The ghost disc is gone, and the hint plate no longer butts the stud. **Left:** pause stayed on the floor corner instead of moving to the lid band. That costs two things: the prompt plates centre at x≈400, not on the chest axis at x=460 (P2-1 below), and the stud hides the floor's top-right bracket and gem (`16`). |
| P1-3 | Cover: hairlines, clipped Z, no face | **Fixed** | `27`: no lines and no clip, and the Zs drift free. It's now a full chest with teeth and tongue showing through the seam, and the group sits near optical centre. The eye glint can't be checked in a still frame. |
| P1-4 | Pose screen off-style | **Mostly fixed** | `25`: an outlined chest drawn in the game's style. The lid has the eye and teeth, the floor is velvet with a coin and a gem, and the lid glows with a lift arrow. The SF glyph is gone. **Left:** the copy is plain SwiftUI text rather than the lesson-scroll plate, there's no hinge-arc animation (can't be seen in a still anyway), and the drawing sits on a flat dark disc. It no longer embarrasses; it just isn't the best screen in the game. |
| P1-5 | One prompt at a time | **Fixed** | `15`: hints are suppressed under the relic card and the loot is dimmed. |
| P2 | Gum lip curve | Not fixed | Still a straight bar (`09`, `12`). |
| P2 | Green "Banked! Gently does it." | Not fixed | `07b`. |
| P2 | Teal SwiftUI buttons on Home and Results | Not fixed | `01`, `19`, `40`. |
| P2 | Closed-lid interior | **Fixed** | Velvet and tongue now show through (`07b`, `14`). |
| P2 | Fly-in loot covers the strip labels | Not fixed | `14`: a coin sits on the "B" of BANKED. |
| P2 | "not safe yet" on the dashed border | Marginal | About 8 px clear (`12`). Acceptable. |
| P2 | Large Type: Results chevron | **Fixed** | `41`, `45`. |
| P2 | Large Type: Codex truncation | **Fixed** | `46`: every name wraps in full ("Sir Rattlesworth's Skull"). |
| P2 | Large Type: Home | **Worse** | `44`: see P1-2 below. |
| P2 | Results Zs in blue | **Fixed** | Cream now (`45`). |
| P2 | Results hero coin is a plain disc | Not fixed | `19`, `41`. |
| P2 | Badges: porthole rings, Royal crown | Not fixed | `40`. |
| P2 | Socket touches the nameplate | **Fixed** | `09`: about 45 px gap. |
| P2 | Zs cross the gilded and iron bands | Not fixed | `15`, `36`, `36b`. |
| P2 | Golden-mimic nameplate casing | **Fixed** | "Golden · Heavy sleeper" (`36`). |
| P2 | Torch-low unverified | **Verified** | `16`: lid open, candle nearly out, "0:09" docked, "Candle's low. Bank it!". Reads well, and the royal tier is gorgeous. |

---

## Remaining issues

### P1-1 — Fold layout: floor-half content is hard-clipped (blocks "yes")
- **Where:**
  - `39`, the lesson-end card in fold. The card is cut by a straight line at y≈140 (native ≈185). Its top border, the dashed stitching and the upper half of the "Not yet, take me home" leather button are gone, and the lock plate peeks above the cut.
  - `30`, Home in fold. The same line shears the Settings and Game Center buttons.
  - The same card on the phone layout (`08`) fits, so this is a fold-layout sizing bug, not an art problem.
- **Why P1:** it's the Duo layout. That's the premise, the main mode, and the frames you'd show to argue for featuring. A cut-off button reads as broken.
- **Fix:**
  - Lay the floor-half content out against the half's safe rect instead of the full half.
  - When it doesn't fit, scale it, and don't clip:
    - **Lesson card:** use `ViewThatFits`. The compact variant drops the rule line under the title, uses 2/3 of the row spacing and a shorter "Got it" button.
    - **Home menu:** use a smaller row height in fold, or collapse Settings and Game Center into one row of two small brass studs.
  - Add a snapshot or UI assertion that no direct child's frame exceeds the half's bounds.
  - Verify on the Duo simulator. Mark it closed only when the Duo captures are clean.

### P1-2 — Home at accessibility sizes breaks words (cheap)
- **Where:** `44` (AX L).
  - "Today' / s try r…" breaks mid-word at the apostrophe.
  - "Codex 9…" and "Badges…" are truncated.
  - The "Game Center" label touches its card's right edge.
- **Why P1:** ADA jurors open Large Type. A word split at an apostrophe is the one AX frame that looks careless, and the rest of the AX work (`41`, `45`, `46`, `47`) is good.
- **Fix:**
  - At `dynamicTypeSize.isAccessibilitySize`:
    - Switch the 2-column grid to one column.
    - Put the Daily status under the title, or drop it.
    - Keep counts on the same line ("Codex 9/24") and give the button room to wrap to 2 lines.
  - Never let a status label wrap at 2 lines in a narrow trailing slot.

### P2 — Polish (don't block launch)
1. **Prompts off-axis:** "Freeze!" and the hint plates centre on the space left of pause (x≈400), not the chest axis (x=460) that the eye, nameplate and lock share. It shows most in `12` and `13c` under the centred eye. The R3 move would fix it: pause to the top-right of the lid-plank band, then centre the plates.
2. **Daily plate collides:** in `26`, "DAILY DUNGEON · OCT 27" overlaps the top-left of the "Wooden · Chest 1" nameplate, and its left cap sits at x≈5, under the rounded screen corner. Centre it in the plank band (y≈150) with at least 12 pt above the nameplate.
3. **CHOMP vs pause:** in `13`, the lower teeth row and gum line run under the pause stud and across the candle top. Fade the pause stud to 0.3 during the bite.
4. **Pause hides tier art:** the purple gem on the royal floor's top-right is half-covered (`16`). This goes away with item 1.
5. **Carried over:**
   - Gum dip.
   - Cream instead of green for "Banked! Gently does it.".
   - Leather or velvet treatment for the secondary buttons.
   - Star-stamped hero coin on Results.
   - Milled badge rims and a crowned-chest Royal badge.
   - Fly-in loot routed behind the strip labels.
   - Zs clamped to the velvet between the bands.
6. **Pose screen:** put the copy on the lesson-scroll plate and give the CTA the leather/brass treatment from `08`. That's the last step from "fine" to "lovely".

---

## What's great (keep it)
1. **Typesetting is now worthy of the art.** The parchment hint plates, the lesson scroll with progress dots and "Skip", the red "Freeze!" plate and the "Candle's low. Bank it!" warning all sit inside their frames with proper caps. This was the R3 blocker and it's gone.
2. **Cover and icon now tell one story.** A sleeping chest with teeth showing through the seam on the cover, and the peeking amber eye on the icon.
3. **The face system and tier progression** remain the best things in the game: `04` → `11` → `12` → `13`, and Wooden → Iron → Gilded → Royal → Golden (`09`, `15`, `16`, `36`).
4. **Torch-low (`16`)** is a strong new store candidate. Royal tier, nearly spent candle, "0:09", "STIRRING", a full bag.
5. **Large Type** on Results, Codex and Settings is genuinely good. Wrapping, not truncating.

---

## App Store screenshot readiness

| Frame | Usable? | Needs |
|---|---|---|
| `app-icon-1024` | **Yes** | — |
| `10` / `36b` (loot run) | **Yes** | — |
| `12` / `13c` (waking, Freeze!) | **Yes** | P2-1 off-axis plate is the only nit. |
| `13` (CHOMP) | **Yes** | P2-3 optional. |
| `15` (relic reveal) | **Yes** | — |
| `16` (royal, torch-low) | **Yes** | New hero candidate. |
| `08` (lesson end, phone) | **Yes** | — |
| `39` (lesson end, fold) | **No** | P1-1 clip. |
| `30` (Home, fold) | **No** | P1-1 clip. |
| `31` / `33` / `34` (fold gameplay, lesson) | **Yes** | — |
| `19`–`21`, `38` (Results) | **Yes** | — |
| `22` / `46` (Codex) | **Yes** | — |
| `26` (Daily) | After P2-2 | Plate overlaps the nameplate. |
| `27` (cover) | **Yes** | — |
| `25` (pose) | Borderline | Fine, not a hero. |
| `01` (Home, phone) | Borderline | Teal buttons. |
| `40` (Badges) | Borderline | Porthole rings. |

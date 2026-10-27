# Hush: Don't Wake the Mimic — Visual launch review, round 3 (Juror 1)

Reviewer role: Apple Design Award juror / senior iOS game art director
Frames reviewed: `artifacts/ci8s/01…47` (iPhone 18 Pro, 1206×2622), `app-icon-1024.png`, `badges/*` (12). Frames 30–39 are the Duo layout on a phone, shown rotated 180°. Frames 41–47 are Large Dynamic Type. Duo simulator captures are judged separately.
Coordinates are in the 920×2000 display frame. Multiply by 1.31 for native pixels.

---

## Verdict

**Score: 8.5 / 10 (R1 6.0 → R2 7.5 → R3 8.5). Launch verdict: NOT YET. About 1–2 days of work, almost all layout and typesetting.**

This round fixed the things that made the game look broken or off-brand:
- **App icon:** redrawn in the in-game style. It now matches the game.
- **Bank-moment floor:** the void is gone on Wooden and Iron.
- **Sleeping mimic:** it has teeth now.
- **Tongue:** a filled, pointed shape in every state. It no longer reads as buttocks or a toilet seat.
- **Hint and lesson chrome:** in-world now (parchment plates, a red leather "Freeze!" plate, a stitched leather lesson card with drawn icons).
- **Lever:** has its own channel.
- **Fold lesson:** teaches the hinge.
- **Results:** fits above the fold.

The art direction is now coherent from the icon to the Codex.

Three things still keep it off "yes":
1. **Text overflows its frames in every gameplay frame.** The new parchment hint plates and lesson scrolls are typeset too large for their frames. Letters run over the brass end-caps and the dashed border. This shows in every store-candidate gameplay frame.
2. **The HUD collides with the right edge.** The pause stud still sits on the corner bracket. The HUSH CHAIN medal is cut off by the screen edge.
3. **The cover and pose screens are not finished.** The cover has two stray hairlines and a clipped Z. The pose screen is the last flat, SF-Symbol screen in the game.

None of this is art. It is layout, and it is cheap to fix. Fix the P0 and P1 items below and I'd score it 9 and say yes.

---

## Round-2 issues: status

| R2 # | Issue | Status | Evidence (R3 frames) |
|---|---|---|---|
| P0-1 | Bank-moment floor void (Wooden/Iron) | **Fixed** | `14`, `07b`, `37`: the frame, brackets, front panel and lock all stay. Only the interior goes dark. |
| P0-2 | App icon in a third, flat style | **Fixed** | Outlined, tilted lid, slit amber eye, pointed teeth with canines, shield lock with keyhole, star coins. It matches the game and reads at small sizes. |
| P1-3 | Sleeping mimic has no mouth | **Mostly fixed** | 7 tooth tips with longer canines in every asleep frame (`04`, `09`, `26`, `37`). They grow when it stirs (`06`) and wakes (`12`). The gum is still a ruler-straight bar with no lip curve (P2). |
| P1-4 | Tongue fails unlit (toilet seat / buttocks) | **Fixed** | Filled pointed heart-tongue in lit (`10`, `26`), dim (`09`) and waking states. Waking (`12`, `18`) keeps the fill, darkens it and curls the tip. No hollow U. |
| P1-5 | SwiftUI chrome on the brass world | **Mostly fixed** | Parchment hint plates, a red leather "Freeze!" plate, a parchment lesson scroll with brass caps, and a leather lesson-end card with drawn candle, fang and lock (`08`, `39`). Still left: the green "Banked! Gently does it." (`07b`), the teal SwiftUI buttons on Home and Results, and the new text overflow (P0-1). |
| P1-6 | Collisions inside the lid | **Fixed** | The lever sits in a brass channel ending at y≈810, above the gum. The thumb is clamped and no longer hits the teeth or the nameplate (`12`, `18`). The teaching label is off the eye. Leftovers: the socket still touches the nameplate (y≈740/748), and the Zs sit on the gilded band (`15`, `36`) (P2). |
| P1-7 | Edge clipping / off-axis numbers | **Partly** | The bank pop is a centred eyebrow/title/sub stack (`07b`). "−10s" is clear of the candle (`13`). "0:15" is docked by the candle (`16`). **The CHAIN medal is clipped**: it is docked at the meter end, but "HUSH CHAI…" runs into the right bracket and screen edge in every frame (`07b`, `09`, `10`, `15`, `36b`, `37`), and into the left edge in fold (`31`). |
| P1-8 | Pause stud sits on the frame bracket | **Not fixed** | Same spot in every gameplay frame (x 760–890, y 1045–1160), over the bracket, with a dark ghost disc behind it. |
| P1-9 | Results stat row clipped, uneven cards | **Fixed** | Equal-height cards with 2-line labels, fully above the buttons (`19`, `20`, `21`, `38`). The chest strip fades under a mask with a chevron. |
| P1-10 | Fold lesson teaches a lever that doesn't exist | **Fixed** | `34`: "Stand your Duo like a little laptop." / "Lift this half", no lever. `39`: "Ease the lid shut to bank". |
| P1-11 | Cover top-heavy, no face | **Partly** | Centred and scaled up (`27`). There is still no eye glint. **New:** two full-width hairlines (y≈605 and y≈1208), and the top one clips a Z. |
| P1-12 | Menus look like a banking app | **Partly** | The backdrop is now a warm olive-to-black vignette, and Codex and Badges use velvet tiles. Home, Results and Settings buttons are still teal SwiftUI cards. Home's dead band is smaller (y≈970–1090). |
| R1 P0-5 | Pose screen | **Now verifiable: off-style** | `25` is not clipped, but it is a flat gold trapezoid over a teal box with an SF Symbols `shippingbox`. It is the only screen left in the old look. |
| P2 | Badges | **Partly** | Velvet tiles match the Codex, and the locked state is now readable cream. Royal is still a crown, not a crowned chest, and the riveted rings still read as portholes. |
| P2 | Nameplate subtitles | **Fixed** | Two tokens plus a brass "GOLD ×2" tab (`15`, `16`, `37`). Exception: the golden mimic's "GOLDEN MIMIC · Heavy sleeper" (`36b`) mixes casing. |
| P2 | Capture gaps | **Fixed** | `25` shows Pose and `15` shows the relic reveal. (Torch-low is still unverified: `16` has the lid shut.) |

---

## Remaining issues

### P0-1 — Text overflows the new parchment plates
- **Where:**
  - **Hint plate** (top of floor, y 1040–1095): the text is wider than the plate. The first and last letters sit *on* the brass end-caps:
    - "Hush Chain! Sleepy banks pay more" (`09`, `14`)
    - "Drag the loot into your bag" (`10`, `15`, `35`, `36b`)
    - "Slide the lever down to bank" (`36`): both ends are on the caps.
  - **Hint plate height:** the cap height fills the plate, so descenders touch the bottom edge.
  - **Lesson scroll** (y 1300–1440): the body text starts at x≈105, on top of the left end-cap and outside the dashed border:
    - "Slide the lever up…" (`03`)
    - "Drag the coin…", where the D is cut (`05`)
    - "It's stirring." (`06`)
    - "Banked!" (`07b`)
  - **Lesson scroll, wrapped text:** "…Watch the noise." wraps onto the bottom border (`04`). The fold-mode scroll has the same problem (`34`).
- **Why P0:** it appears in every gameplay and tutorial frame, so it will be in every store screenshot. Text spilling out of its frame is the first thing an editor's eye catches, and it undoes the in-world chrome win.
- **Fix:**
  - **Hint plate:**
    - Lay it out as cap | text | cap with 14 pt padding inside each cap, and hug the text width.
    - Set `lineLimit(1)` with `minimumScaleFactor(0.75)`, and cap the width at the floor width minus 2× the safe inset minus the pause area.
    - Set the font to about 80% of the plate height (it is about 100% now).
  - **Lesson scroll:**
    - Inset the text 20 pt inside the dashed border on both sides.
    - Let the scroll grow vertically for 2 lines; don't let the text wrap onto the border.
    - Move the progress dots inside the border too.
  - Add a snapshot test with the longest hint string.

### P1-2 — Right-edge HUD collisions: pause stud, chain medal, hint plate
- **Where:**
  - The pause stud covers the floor's top-right bracket and rim in every gameplay frame, with a dark duplicate disc behind it (x 840–895).
  - The HUSH CHAIN medal at the meter's right end is clipped by the screen edge and bracket in every frame ("HUSH CHAI", x 775–900, y 1465–1510), and by the left edge in fold (`31`).
  - The hint plate's right cap butts into the stud (`10`, `36`).
- **Fix:** do it in one move.
  - Move pause into the dead top lid-plank band (y 0–345) as a brass stud at the top-right safe inset. In fold mode, put it in the equivalent chest-front band.
  - Remove the ghost disc.
  - Dock the chain medal *inside* the bag strip, as a tab on the BANKED plate's top edge ("CHAIN ×1.2"). Or shorten it to an icon plus "×1.2" that fits before the bracket with 16 pt clearance.
  - That frees the whole top edge of the floor for the hint plate, centred.

### P1-3 — Cover: stray hairlines, clipped Z, no face
- **Where:** `27`. Two 1 px full-width lines at y≈605 and y≈1208 (x 85–835). They look like a container border or a clip rect. The Z at x≈700 is cut off by the top line. The bottom 30% of the screen is empty. There is no eye, only teeth.
- **Fix:**
  - Remove the borders and the clip so the Zs can drift freely.
  - Add the amber eye glint through the seam every ~5 s.
  - Lift the group up about 8% so the copy sits nearer optical centre.

### P1-4 — Pose screen is the last off-style screen
- **Where:** `25`. A flat gold trapezoid and a teal box with an SF `shippingbox` glyph, on a plain gradient. This is the first screen a Duo owner sees, and the game's whole premise.
- **Fix:**
  - Draw a Duo-shaped chest at about 60° in the in-game language: outlined wood lid with the eye and teeth, velvet floor with a coin.
  - Add a small animated hinge arc and "Lift this half" on the lid.
  - Replace the SF glyph with the chest.
  - Reuse the lesson-scroll plate for the copy.

### P1-5 — One prompt at a time
- **Where:** `15`. The relic reveal ("RELIC FOUND! The Lullaby Music Box") shows under the "Drag the loot into your bag" hint plate. The relic card's right roller also overlaps loot. This is a hero moment and a store candidate.
- **Fix:**
  - Suppress hints while any reveal card or bank stack is up.
  - Dim the loot behind the relic card (black at 0.35).

---

## P2 polish (don't block launch)
- **Gum:** add a 10–12 pt centre dip and lift at the corners so the upper jaw reads as a lip, not a bar. Add the slow breath scale.
- **Green text:** the lesson "Banked! Gently does it." is green (`07b`). Use the cream/brass palette. (The meter's green segments are fine.)
- **Home/Results buttons:** the secondary teal SwiftUI cards (Daily, Codex, Badges, Settings, Game Center, Home, Done) are the last banking-app tell. Make them brass-edged leather, or velvet like the Codex tiles.
- **Dead top lid-plank band** (17% of the screen, every frame): P1-2's pause move uses some of it. The Daily plate (`26`) already shows how well it works.
- **Closed-lid interior** (`07b`, `14`, `16`, `37`): flat `#0A1416`. Let 10–15% of the velvet and tongue show through, so it reads as "dark inside a chest", not "nothing rendered".
- **Fly-in loot:** it covers the IN BAG and BANKED labels and the meter end (`07`: "IN E…"; `16`). Fly it behind the strip labels or along an arc above them.
- **"not safe yet"** sits on the IN BAG plate's dashed border (`07`, `12`, `36`). Give it 4 pt.
- **Large Type:**
  - The Results "more" chevron overlaps "+363"/"+358" (`41`, `45`).
  - The Codex truncates "The Bottomless G…" and "Sir Rattlesworth'…" (`46`). Allow 3 lines and let the tile grow.
  - Home shows "Today's try…" (`44`). Drop the trailing label at AX sizes.
- **Results art:**
  - The Zs in the chest strip are bright blue, a colour found nowhere else. Use cream.
  - The hero coin is a plain disc. Use the star-stamped in-game coin.
- **Badges:**
  - Replace the porthole rings with a milled coin rim.
  - Make Royal a crowned chest.
- **Small overlaps:**
  - The socket touches the nameplate (leave a 12 pt gap).
  - The Zs overlap the gilded and iron bands (`15`, `36`, `37`). Clamp them to the velvet between the bands.
- **Golden-mimic nameplate:** "GOLDEN MIMIC · Heavy sleeper" mixes casing. Use "Golden · Heavy sleeper".
- **Torch-low:** still unverified. Re-shoot with the lid open at candle ≤25%.

---

## What's great (keep it)
1. **The icon.** It finally belongs to the game: tilted lid, fangs, a slit eye peeking, a shield lock and star coins spilling out. It reads instantly on a dark Home Screen.
2. **The mimic's face system.** Closed lashes with tooth tips, then a gold slit, then a full amber cat-eye. The brass brow goes from flat to V to sharp V, the teeth lengthen, and the floor washes red. Every state reads in a thumbnail (`04` → `06` → `12` → `13`).
3. **Tier progression across the whole screen.** Wooden, iron-bound, gilded with a ruby brow and a GOLD ×2 tab, royal maroon with gems and a crown brow, and the golden mimic with teal velvet (`36b`). It is the best "the world levels up with you" treatment I've seen in a one-screen game.
4. **The in-world teaching layer.** The parchment scroll with progress dots, the red leather "Freeze!" plate, and the stitched lesson-end card with drawn icons and the "Not yet, take me home" leather button (`08`, `39`). Once the typesetting is fixed, this is ADA-level craft.
5. **Results.** The tier-matched chest portrait (smug teeth when bitten, Zs when hushed), the giant score, an honest one-line story, equal stat cards and the chest-by-chest strip. You can read the run at a glance.
6. **The Codex.** 24 distinct outlined relics on velvet, with charming names. Locked relics are blurred silhouettes with a "?".
7. **Fold-mode copy and layout.** The hinge is the lesson. The lever is gone and the HUD mirrors correctly.

---

## App Store screenshot readiness

| Frame | Usable? | Needs |
|---|---|---|
| `app-icon-1024` | **Yes** | — |
| `12` / `18` (waking, Freeze!) | **Yes** | Best drama frame. Clear it of the P1-2 HUD edge issues first. |
| `13` (CHOMP) | **Yes** | After P1-2. |
| `10` / `26` / `36b` (loot run) | After P0-1, P1-2 | Hint text overflow, clipped chain medal. |
| `15` (relic reveal) | After P0-1, P1-5 | Two prompts at once. |
| `16` (royal) | Re-shoot open | Gorgeous tier, but the lid is shut in this frame. |
| `08` / `39` (lesson end) | **Yes** | — |
| `19`–`21`, `38` (Results) | **Yes** | P2 colour nits only. |
| `22` (Codex) | **Yes** | — |
| `40` (Badges) | Borderline | Porthole rings. |
| `01`/`02` (Home, phone) | Borderline | Teal buttons, static chest. |
| `27` (cover), `25` (pose) | **No** | P1-3, P1-4. |

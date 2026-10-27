# Hush: Don't Wake the Mimic — Visual launch review (Juror 1)

Reviewer role: Apple Design Award juror / senior iOS game art director
Frames reviewed: `artifacts/ci2/screens/01…40`, `app-icon-1024.png`, `badges/*` (12), and `artifacts/duo1/duo-screens/duo-screens/*` (Duo raw frames mentally rotated 180°).
Coordinates below are in the 920×2000 display frame for phone captures (multiply by 1.31 for native px) unless stated.

---

## Verdict

**Score: 6 / 10. Launch verdict: NOT YET.**

The in-game chest is good. The eye changes with each stage, the chest tiers step up nicely, the brass hinges sit on the fold, the leather bag strip and the candle work as in-world HUD, and the named mimics give the game a voice. It looks like a real game.

Everything outside the chest looks like it came from a different, unfinished app. Home, Cover, Results, Codex, Pose and the badges are flat vector shapes with no outlines, on a fintech-style teal gradient. On Home, the chest has no face at all. A juror sees three or four art styles in the first 30 seconds. On top of that, the main scene has a few readability and taste problems that would stop it being featured:
- the tongue reads as buttocks
- text is drawn over the loot
- coins look like cinnamon buns
- on a standard iPhone, about 35% of the screen is black letterbox

None of this needs a redesign. It is an art-unification and layout pass of roughly 1–2 weeks.

---

## Top 15 issues (priority order)

### P0-1 — Four art styles. The Home, Cover, Codex, Results and badge art does not match the in-game chest.
- **Where:** `01/02-home` (flat brown box, grey bands, blank yellow square lock, no eye, no teeth, lid bands don't continue onto the lid). `27-cover` / `duo-ui-cover` (a brown rounded rectangle with a smile). `22/23-codex` (flat primitive relics). `19–21-results` (flat coin, no mimic). `badges/*` (flat). The in-game art (`09–18`) is outlined cartoon with highlights, a maroon velvet lid, a cat-slit eye and rounded teeth. The app icon is a third look again: brown wood, pointed fangs, a round orange pupil.
- **Fix:** Pick the in-game sprite language as the master style: dark-brown 3–4 pt outline, one top-left highlight, one inner shade band, palette tokens shared with SpriteKit. Then make one `MimicPortrait` SpriteKit scene (an `SKView` wrapped in `UIViewRepresentable`). It reuses the real lid, eye, teeth, nameplate and lock textures at small scale, and it is used on Home, Cover, Results and the lesson-end card. On Home it should idle-breathe (lid y-scale 1.00→1.015, 2.4 s ease-in-out), with the closed-lash eye and drifting Zs. Redraw the Home lock with a keyhole, and run the iron bands through the lid. Bring the icon closer too: either give the in-game eye a round pupil like the icon, or give the icon a slit pupil, and use one tooth shape everywhere (see P1-7).

### P0-2 — The tongue reads as buttocks.
- **Where:** `09-run-ready`, `10`, `14-bank`, `26-daily`, `duo-h2-after-slam`. It is a full-width pink U with one dark vertical crease from the top edge almost to the bottom, and the effect is strongest when it is dimly lit. This will be screenshotted and mocked.
- **Fix:** Taper the shape into a clear tongue tip pointing at the bag (front edge), and narrow it to about 70% of the floor width. Shorten the median groove to the back 35–40% and fade its alpha to 0 toward the tip. Add papillae: a tiled noise texture of small lighter dots at about 15% alpha. Add an off-centre specular highlight blob. Make the back (hinge side) a darker throat gradient. Give it a slight asymmetric curl or sway animation, ±2° every 3 s.

### P0-3 — The stage title is drawn on the floor, over the loot.
- **Where:** `05` (ghost "Dozy Doris / Wooden chest ×1" behind the loot), `06` (overlaps the silver bar and coin), `07`, `11` ("Wheezy Walt / Wooden chest ×1" over coins and gems), `duo-h2`. It also repeats the brass nameplate directly above it.
- **Fix:** Remove the floor title. Show the chest tier as a small engraved second line on the lid nameplate ("Wheezy Walt · Wooden"), with a brass slide-in when each chest starts. If the floor label has to stay, show it only while the lid is shut and the floor is dark, fade it out (0.2 s) before any loot alpha goes above 0, and keep its z below the loot.

### P0-4 — About 35% black letterbox on non-Duo iPhones. These frames can't be used as App Store screenshots.
- **Where:** every gameplay capture on the iPhone 18 Pro (`03–18`, `26`, `31–34`): black bars of roughly 0–345 px at the top and 1650–2000 px at the bottom.
- **Fix:** Lay the scene out to fill the screen in safe-area units, not as a fixed-aspect canvas fitted to the screen. Grow the lid velvet upward: more rivet rows, and corner brackets pinned to the top safe inset. Grow the bag strip and a wooden table surface downward, to the bottom safe inset. As a fallback, fill the bars with a dungeon backdrop (dark stone wall plus torch glow) instead of `#0A1416`. Build the App Store set from Duo frames (`duo-h1`, `duo-02` rotated) and add caption panels.

### P0-5 — The Pose screen is clipped on a portrait iPhone.
- **Where:** `25-pose`. The headline runs off the right edge ("Stand i… up like… little… laptop"), the body text is cut, and the "Floor" card is cut on the left. (The landscape `duo-ui-pose-book` is fine.)
- **Fix:** In compact width, use a `VStack` (diagram on top, copy below) through `ViewThatFits`, or a `horizontalSizeClass` switch. Add `.minimumScaleFactor(0.8)` and `.lineLimit(nil)`. While you're there, swap the "Floor" glyph (a 2×2 app grid) for a floor icon: a coin pile or a flat chest base.

### P1-6 — Coins look like cinnamon buns or roses.
- **Where:** all loot scenes (`04`, `05`, `10`, `11`, `17`, `26`). The lesson copy says "Drag the coin into your bag", but the object is an orange swirl blob.
- **Fix:** Redraw coins as gold discs (#F5C542 face, #B8862B rim, 3 pt dark outline) with an embossed crown or keyhole mark and a highlight crescent. Use stacks of 2–3 slightly offset coins for higher values. Keep copper as a separate, clearly bronze tier if you need it.

### P1-7 — The mimic is not yet charming. The lid looks like a theatre curtain with a porthole, and the sleeping teeth look like a lace trim.
- **Where:** `03`, `09`, `10`, `14`. The scalloped white row with a pink band reads as curtain fringe or a doily. The eye in its round brown frame reads as a ship's porthole. Only `12`/`13` (big slit eye, bigger teeth) feel like a creature.
- **Fix:**
  - **Teeth:** make them pointed and slightly irregular, matching the icon's fangs. Use one chipped tooth and 2 longer canines, and darken the gum band.
  - **Eye socket:** replace the frame with a fleshy eyelid. Add a brass brow plate above it that tilts −5° when stirring and −12° when waking.
  - **Asleep:** add a slow lid "breath" and a drool glint at one tooth.
  - **Stirring:** add tiny tongue-tip twitches.
  - **Bite:** add a 3-frame squash on the lid.

### P1-8 — Status and hint pills cover the loot.
- **Where:** "Drag the loot into your bag" covers the silver bar (`10`, `17`, and the gold vial in `17`). "Slower…" and "Freeze!" sit on the tongue tip and loot (`11`, `12`, `16`, `18`). "Freeze!" is still on screen during "CHOMP!" (`13`), which contradicts it.
- **Fix:** Give messages a fixed band. On the lid, just under the nameplate, works best: the player is looking at the lid while lifting. Or put them inline at the left of the snore-o-meter row. Don't spawn loot in the bottom 12% of the floor. Hide the "Freeze!" pill as soon as the bite fires.

### P1-9 — The tutorial card hides the snore-o-meter and half the loot.
- **Where:** `03`, `04`, `05`, `07`. The card sits on top of the meter, and in `06` the meter only peeks out under the red-bordered card, at the exact moment the lesson is about noise.
- **Fix:** Shrink the card to one line (about 110 pt tall). Anchor it to the lid half above the hinge, or put it above the meter with an 8 pt gap. Keep the meter always on top (highest zPosition). Pulse the meter when the lesson refers to it.

### P1-10 — The pause button is clipped at the screen edge and collides with the frame bracket.
- **Where:** every gameplay frame (right edge around y 1075; in `31`/`33`/`34` it is half off-screen on the left).
- **Fix:** Inset it by safe area + 16 pt. Restyle it as a round brass stud in the top lid corner bracket, matching the hinge material, instead of a teal SwiftUI-style circle.

### P1-11 — The bag and bank HUD is ambiguous.
- **Where:**
  - Two unlabeled counters: grey "0" next to the bag medallion, gold "0" next to the coin stack. `09` shows 379 at the start of a run, so it is unclear what the gold number counts.
  - Bagged loot piles up between the two centre buckles, not at the bag (`12`, `16`, `26`).
  - Gold flying to the counter covers its digits (`14`, `15`).
  - The bag count stays grey even when it is not 0 in some states.
- **Fix:**
  - Emboss small-caps labels "BAG" and "BANKED" into the leather (11 pt, 60% cream).
  - Anchor the pile to the bag pouch, and draw the pouch with an open mouth that glows while the player is dragging (drop-target affordance).
  - Draw the counter digits above the fly-in particles, and land particles on the icon, not the numbers.
  - Use cream for the bag count when it is above 0.
  - Keep the "+179" pop-up next to its counter.

### P1-12 — The Results screen has no art and a large dead area.
- **Where:** `19`, `20`, `21`, `duo-ui-results`. It is text on a gradient with about 500 px of empty space between the flavour line and the stats. The "NEW relic" row uses a flat teal circle as a placeholder (`21`). The rank bar is a stub with no visible track (`19`).
- **Fix:**
  - Put the `MimicPortrait` (P0-1) in the void: smug and chewing if bitten, still asleep if hushed.
  - Show a coin pile illustration that scales in 3 steps with the score.
  - Use the real in-game relic sprite in the NEW row.
  - Give the rank bar a visible track (12% cream) and a label.
  - On the Duo, keep the hero on the lid half and the actions on the floor half (that part is already right).

### P1-13 — Codex relic art is low quality, repeats shapes, and doesn't match the in-game relic.
- **Where:** `22`, `23`, `duo-ui-codex`.
  - The 24 relics are about 12 silhouettes in two colours each: two skulls, two rings, two amulets, two mirrors, two horns, two keys, two eggs, and so on.
  - The primitives misread: the skull looks like a light bulb, the ring like a balloon, the Shy Mirror like a ping-pong paddle.
  - The in-game reveal "Dice of Second Chances" (`15`) is a nice red outlined die with pips, but "Lord Wobble's Loaded Dice" in the Codex is a blank white square.
  - The subtitle in `22` runs edge to edge with no margin.
  - The last row is cut off hard by the Done button.
- **Fix:**
  - Draw 24 unique outlined relic sprites in the in-game style, and use the same texture in the reveal, the Codex and Results.
  - Give the subtitle 24 pt horizontal padding and `.multilineTextAlignment(.center)`.
  - Fade the bottom of the scroll view into the Done button (a gradient mask).
  - Keep locked silhouettes, but blur or simplify them so the shape isn't given away completely.

### P1-14 — The Cover display mimic reads as the Amazon smile or a wallet.
- **Where:** `27-cover`, `duo-ui-cover`, `duo-04-cover-shut`. A brown rounded rectangle with a grey border and a white smile curve. On a Duo this is the first thing anyone sees.
- **Fix:** Draw a closed chest front: lid seam, brass lock with a keyhole, iron bands, with a sliver of the sleeping eye and the fang tips showing through the seam. Animate a slow breath and drifting Zs. Keep the copy ("Open me… gently" is good).

### P2-15 — Badges: duplicates, a flat style, and clipping.
- **Where:** `badges/`:
  - `curator` and `fullcodex` are identical (the same crown).
  - `heavybag` and `hoard` are identical (coin stack, silver ring).
  - `firsthaul` and `fortune` are the same coin stack in another colour.
  - `hushhush` and `notapeep` are the same eye in another colour.
  - The "Z" in `hushhush`/`notapeep` crosses the ring.
  - `royal` is a plain wooden chest with no crown or gems, although the in-game royal tier (`16`) has both.
  - Motifs fill only about 45% of the disc, so they become mush at the 40–60 pt Game Center size.
- **Fix:** 12 unique motifs in the outlined style, filling 65–70% of the inner disc, kept inside the ring. Tie the ring colour to the tier (bronze / silver / gold). The royal badge should show the crowned, jewelled chest.

### Further P2 polish (fold into the passes above)
- **Home truncation:** `01`/`02` truncate "Codex 0/…" and "Codex 9/…" while "Settings" in the next button is set larger. Use one font size across the row, and label it "Codex" with a numeric badge, or use `ViewThatFits`. The trophy-only button needs an accessibility label and should match its siblings.
- **Home layout:** dead space from y 950 to 1310. Move the hero down, or put the Daily Dungeon preview there. At Rank 1 (`01`) the empty rank bar is invisible; give it a track.
- **Home copy:** "Drag the lid up… slowly." on Home suggests the chest can be dragged. Either make it interactive (drag the chest lid to start Play, which would be delightful) or drop the line.
- **Torch low (`16`):** the candle is nearly gone but the floor is still fully lit. Tie the ambient light on the floor to the torch level (vignette alpha 0 → 0.55), and flicker the light below 20%.
- **Bite (`13`):** red "CHOMP!" on a red tongue has weak contrast. Use a cream fill with a thick dark-red stroke, add a 6 pt screen shake and a white flash frame, and remove the "Freeze!" pill.
- **`08` lesson end:** a stray brass lid-slider gauge appears on the right of the lid, overlapping the corner bracket and teeth (y 370–940). Hide it while the card is shown, or seat it inside the frame. The card's coin is in the flat style (see P0-1).
- **Relic reveal (`15`):** "Hushed!", "Relic found!" and "+948" sit on three different baselines and sizes. Stack them as one centred group (eyebrow, title, value).
- **Fold lesson (`34`):** the copy says "Slide up here" with a finger gesture. In fold mode it should say "Lift the lid" with the hinge diagram used in `duo-h3` ("Lift me" is already right).
- **Settings (`24`):** the graduation-cap icon for "Replay First Chest" is off-theme (use a key or chest glyph). About and Credits as full-width buttons feel heavy; make them list rows.

---

## Five things that are already great — keep them

1. **The eye tells you the danger level.** Closed lashes (`10`), a slit cracking open (`06`, `17`), a half-open cat eye (`12`), a fully open glare (`13`). Players can read the danger at a glance, with no UI needed. Don't touch the timing.
2. **Chest tier progression.** Wooden, then iron bands (`09`), then brass bands and brackets (`15`), then royal with a crown, gems and a red-gold frame (`16`). Clear, rewarding and very screenshot-friendly.
3. **In-world HUD built on the hardware.** Brass hinges right on the Duo fold, the leather bag strip with buckles, the candle as the torch gauge, the segmented snore-o-meter (green to amber to red) with the face icon. The Duo full-bleed frames (`duo-h1-slow-open-160`, `duo-02-half-135`) look great, and the 180° turned layout comes out clean.
4. **Voice and naming.** Brass nameplates (Dozy Doris, Wheezy Walt, Mumbling Milo), "Lovely work, little thief.", "Bitten 3 times: 1,019 gold went down the hatch.", "The Compass of True North-ish". Make the redrawn art match this tone.
5. **The app icon concept.** Fangs plus a peeking eye under a tilted lid, with a warm glow from inside. It reads well at small sizes and is the best mimic in the whole project. Use it as the reference for the mimic redraw (P0-1, P1-7). Small tweaks only: lighten the iron bands, which are lost against the dark background below 60 px, and line the lid bands up with the body bands.

---

## Screenshot readiness (App Store)

| Frame | Usable as a store shot? | Why |
|---|---|---|
| `duo-h1-slow-open-160` (rotated) | Yes, after P0-2 / P1-6 | Full-bleed, warm, clear concept |
| `16-torch-low` (royal) | After P0-4 and the pill move | Best tier art, but letterboxed |
| `12-waking` / `13-bite` | After P0-4, P1-8 | Strong drama, but the pills and black bars hurt it |
| `15-relic` | After the text-stack fix | A nice moment, but the labels are messy |
| `01-home` | No | Off-style chest, dead space, truncated button |
| `19–21-results` | No | No art |
| `22/23-codex` | No | Placeholder-grade relics |
| `25-pose` | No | Clipped |

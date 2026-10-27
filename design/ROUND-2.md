# Round 2: from "promising" to launch standard (brief)

**Inputs** (read the ones for your role in full):
- `design/panel/REVIEW-1-juror.md`, 6.0/10;
- `REVIEW-1-ux.md`, 6.5;
- `REVIEW-1-duo.md`, 6.0;
- `design/REVIEW-1-feel.md`, the balance and features;
- `design/QA-1.md`, the code QA;
- `design/fresh/tester1.md`, `tester2-duo.md`, `tester3-phone.md`: understood 6–8, premium 5–7, would pay 5–6.

**Verdict:** the core works and charms (the eye, the tiers, the in-world HUD, the copy, the icon concept). Five things
keep it from launch standard:
1. there is no real gamble yet;
2. everything outside the chest is a different, unfinished app;
3. the HUD is unlabelled;
4. phones get letterbox bars;
5. there are two Duo blockers.

**Founder contract changes** (already made in `Hush/Shared/Contracts.swift`; update every exhaustive switch):
- `ScreenLayout.make(hasFold:viewSize:)`, `size` (the scene can be taller than 952), `contentOffsetY`,
  `extensionHeight`. All geometry is still in 670 × 952 canvas coordinates.
- Turning round is now done **inside the scene**: `ChestScene.turned`.
- `RelicShape`: 24 cases.
- `ChestSpec.golden`; `ChestOutcome`.
- `HeistHint.candleLow`, `.relicDeeper`.
- `HeistSnapshot.chain`, `chainMultiplier`, `noiseFloor`.
- `HeistEvent.chainUp`, `chainBroken`, `biteCost`.
- `RunResult.bestChain`, `goldenBanked`, `chestLog` (decoding is tolerant).

Copy rule: it is a **candle** everywhere the player reads it (the art is a candle). Code names (`torch…`) may stay.

---

## Core engineer (Core, CoreTests, BalanceTests, tools)
1. **Take REVIEW-1-feel's tuning (§ prioritised changes 1–11)**, exactly as numbered:
   - `quietSpeed` 12, plus the new linear and quadratic rates;
   - `closeQuietSpeed` 18;
   - decay grace 0.3, and tier decays 0.16 / 0.14 / 0.12 / 0.10;
   - `dragQuietSpeed` 350;
   - bite penalty 10 s; oil 6 s;
   - `relicChance` 0.25;
   - the new rank and achievement thresholds and swaps;
   - BalanceTests: casual banks 5–10.
2. **Features A–D** from REVIEW-1-feel:
   - **A. Hush Chain:** ×1.1 per consecutive Hushed chest, capped at ×1.5. A stir or a bite resets it. Emit `chainUp`
     and `chainBroken`; fill `chain`, `chainMultiplier` and `bestChain`.
   - **B. Golden mimic:** 6 % of chests from #3, from its own random stream so the Daily is unchanged. Loot ×2, noise
     ×1.25; `ChestSpec.golden`; the `royal` achievement becomes Midas Touch.
   - **C. Relic glimmer:** `.relicDeeper` when a relic is within 0.25 of being lit but isn't yet. The scene draws the
     glimmer from depth and openness.
   - **D. Bag jingle:** a noise floor of 0.035 × items in the bag, capped at 0.30, exposed as `noiseFloor`. Port the
     pilot fix (unfreeze at max(unfreeze, floor + 0.04)) so attract mode and CI never hang.
3. **Duo fixes in Core:**
   - Relic depth 0.84–0.92 becomes **0.80–0.88**, so relics are reachable at about 157°, not 164° (REVIEW-1-duo P1-9).
   - Add `func rest(dt: Double)`: noise decays (to the floor), with no candle, no bites and no other events except
     `stageChanged`. The App calls it while paused.
   - Add `func resumeGrace(seconds: Double)`: lid noise is ignored for that long.
   - `biteCost` comes with every `bitten`.
   - `chestLog` gets one entry per chest; a chest the candle went out on counts as value 0.
   - Hint: `.candleLow` when ≤ 15 s are left and the bag has loot (priority just below freeze and slower);
     `.relicDeeper` just above `openSlowly`.
4. Update `ThiefPilot` to match the R2 sim (the expert and perfect pilots adapt), then `tools/balance-sim.js` = the
   R2 sim. CI's BalanceTests must match the R2 table (40 seeds median):

   | Skill | Gold | Chests banked | Bites | Hushed |
   |---|---|---|---|---|
   | novice | ≈1,635 | ≈5 | ≈3 | — |
   | casual | ≈3,945 | ≈8 | 0 | ≈2 |
   | expert | ≈10,847 | ≈13 | — | — |
   | perfect | ≈11,553 | — | 0 | — |

   With 8 seeds, novice ≥ 1,000 gold and ≥ 3 chests. Keep the assertions robust (medians, bands).
5. **RelicCatalog:** 24 relics with 24 different shapes. Rename each relic to suit its shape. Tints vary.
6. Keep the lesson chest working (positions as given).

## Scene engineer (Scene, SceneTests): art unification and readability (juror P0/P1)
1. **Turned round in the scene:**
   - Everything lives under one `world` node.
   - `turned = true` rotates it by π about the scene centre.
   - Read every touch with `touch.location(in: world)`.
   - Tests: a turned touch at the visual position of an item maps to that item's floor point.
2. **Fill the screen:**
   - Use `layout.size` and `contentOffsetY`.
   - **Extension art:** above the lid, the lid's planks and iron continue (a taller lid, with the eye centred in the
     *canvas* lid area); below the floor, the chest's front wall with a big brass lock, then a tabletop edge.
   - Phones show no bars at all. On the Duo the extension is ~0.
3. **One art style:**
   - Build **`MimicPortraitScene: SKScene`**, the front view of the closed chest in the in-game textures: the lid
     cracked, fangs and one big eye peeking, a slow breath idle. The app icon is the reference.
   - API: `init(size:)`, `var openness: Double` (0…1), `var wake: Double` (0…1), `var tier: ChestTier`,
     `var golden: Bool`, `var reduceMotion: Bool`.
   - The App uses it on Home, the cover card and Results.
4. **The tongue** must not read as buttocks:
   - Taper it to a rounded tip pointing at the bag.
   - Drop the long centre crease (keep a short one near the root).
   - Add velvet texture or stipple, a top-edge highlight and a darker throat at the fold.
5. **Coins** become clear gold discs: a rim, an embossed star or crown, and a shine. Higher values are drawn as a
   stack of 2–3. Silver is a silver disc with a different emboss. Gems are faceted. Oil is a little flask with "+6s".
6. **Mimic charm:**
   - Pointed fangs like the icon's (still rounded tips, a cute-scary read), tucked behind a lip when Asleep.
   - A fleshy eyelid over the eye, not a porthole.
   - A brass brow plate that tilts angry as it wakes.
7. **HUD labels** (UX P0):
   - The bag plate says "IN BAG" and the bank plate says "BANKED" (small caps, ≥ 14 pt labels, numbers ≥ 28 pt).
   - The plates never swap sides between the Duo and the phone.
   - The bag is a clear leather **pouch** that glows as a drop target while an item is held. Bagged loot piles in
     the pouch, not at the buckles.
   - The noise meter is labelled "NOISE", with a **teeth icon** at its full end, and stays on top of everything.
8. **No text over loot:**
   - The chest-arrival tag ("Dozy Doris") goes on the **lid nameplate**, with a sub-line for the trait ("Light
     sleeper", "Heavy sleeper", "Dreamer · fake twitches", "Snorer") and the tier ("Iron-bound · gold ×1.5").
   - Golden: "GOLDEN · gold ×2 · light sleeper".
9. **Bite callout:** "Too loud!" plus "−164" over the pouch, and "−10s" flying off the candle (use `biteCost`).
   "Freeze!" must clear the instant a bite starts (the App owns the hint; the scene must not draw its own).
10. **Chain:** a chain badge by the BANKED plate ("Hush Chain ×1.3") that pops on `chainUp` and cracks on
    `chainBroken`.
11. **Golden mimic:** a gilded chest with a gold-leaf lid and a sparkle, the coins worth double flash "×2".
12. **Relic glimmer:** a faint pulsing sparkle at a relic's spot while it's within 0.25 of being lit.
13. **Candle low:** in the last 15 s, the flame gutters and a big "0:12" countdown shows by the candle. The candle
    shows "+6s" when oil is bagged.
14. **Relic art:** 24 distinct `relicPath` silhouettes.
15. Relic and Codex art and `lootArt` must look the same in SwiftUI and SpriteKit (one source).

## Feel engineer (Input, Feedback, FeelTests)
1. **The resume rule** (REVIEW-1-duo P0-2):
   - `HingeLidSource` gets `func reset()`, called on resume (filters cleared).
   - Closing pause: under **70°** for 0.4 s.
   - Resume needs ≥ **95°** held still (speed < 6°/s) for 0.3 s. Expose `canResume: Bool`.
2. Clamp the angle used for **speed** to 97–168°, so motion outside the play range makes no noise (P1-5).
3. Sounds and haptics for: the chain (a rising sparkle chime per step), the chain broken (a glassy crack), the golden
   mimic arriving (a shimmer), the candle-low tick (in the last 15 s; faster in the last 5) and the bite cost (a
   coin-spill sound).
4. Relic glimmer: a faint high shimmer while `.relicDeeper` shows (the App can pass it in telemetry or call
   `glimmer(on:)`; add it).
5. Low Power / thermal: expose `FeedbackDirector.preferredFPS` (60 under Low Power or thermal ≥ .serious, else 120).

## App engineer (App, UI, Persistence, AppTests)
1. **Duo P0-1 (stuck on the book-pose card):** port Brim's Release-path orientation handling
   (`C:\Users\59527\Fold\Brim\App\OrientationLock.swift`: `requestPortrait`, `adoptMask`, `requestFailed`).
   - Request portrait automatically when the hinge moves or the pose card shows.
   - Add an "I've stood it up" button on the card.
   - Lock the mask to portrait while a run is live. Never ask for upside down.
2. **Duo P0-2:**
   - While paused (closing, cover, menu) call `session.rest(dt:)` each frame.
   - Resume only when `HingeLidSource.canResume`; then `reset()` the filters and `session.resumeGrace(seconds: 0.5)`.
   - Open the pause menu only on **background**, not on inactive (P1-8).
3. **Turned round:**
   - Stop rotating the SpriteView. Set `scene.turned`.
   - Rotate only the SwiftUI overlays (HUD, cards, lesson band).
   - Lesson pose window 90–112° (P1-6).
4. **Fill the screen:**
   - The scene uses `ScreenLayout.make(hasFold:viewSize:)`, aspect-filling the whole screen.
   - `CanvasFit` and HUD rects map canvas → view with `contentOffsetY`.
   - The pause button is a brass coin inset ≥ 16 pt from every edge, inside the safe area (it is clipped now).
5. **One art style:**
   - Home, the cover card and Results use the Scene's `MimicPortraitScene` (SpriteView). On Home its openness
     follows the hinge or slider; on cover it is asleep.
   - The Codex and badges use `ChestArt` relic art on velvet tiles.
   - Remove the flat placeholder chests.
6. **Clarity (UX P0/P1):**
   - Lesson step 2: "Open the lid… slowly. Watch the noise."
   - The lesson band must never cover the noise meter. Move it to the lid half or above the meter (canvas y ≥ 260 in
     floor terms). Check every step's frame.
   - **The lesson's last card has 3 icon rows:** "Candle out = run over", "Too loud? It bites your bag", "Shut the
     lid to bank it". Then "Got it".
   - **Phone:** always draw the lever. The copy is "Slide the lever up… slowly", pointing at the lever.
   - **Duo pose card:** an animated diagram: turn it sideways, then lift the glowing half, with "Turn it round. Lift
     the glowing half." Use Brim's two-page layout, with the whole lift half glowing and text away from the fold
     (P2-12). In compact width (a phone), a stacked layout. A phone never shows the Duo pose card (frame 25 must not
     happen on a phone).
   - "Hushed" explained on Results ("Hushed: banked while it slept").
   - Results:
     - the chest-by-chest strip from `chestLog` (tier icon, value, a 💤 for Hushed, teeth for bitten, gold for
       golden);
     - "312 short of your best" or "New best!";
     - named achievements earned this run;
     - no dead gap.
   - Home:
     - the Codex label never truncates;
     - the rank bar is visible even at 0 (track plus a "next: Sneak" label);
     - the best haul and the rank match the Results numbers. Fix the "NEW BEST 2,794 vs Best 2,400" demo seeding
       mismatch and "Codex 9/24 vs 22 of 24 found" so demo `progress=` seeds are consistent.
   - The Daily screen and run say "Daily Dungeon" plus the date.
   - Settings copy: "Turn the chest round" with the detail line "Keeps the loot on the half that stays sharp when you
     fold". On the Duo, Settings toggles sit on the floor half.
   - Hints: `.candleLow` → "Candle's low. Bank it!"; `.relicDeeper` → "Something glints deeper…". Hints sit in a
     fixed band at the floor's **back edge by the fold** (it must not cover loot or the drag path). Ask the Scene for
     the band rect, or use a band the scene keeps clear: canvas y 404–452.
7. Gold numbers on screen must always add up: the banked counter equals the sum of the banks. Check the demo
   `skipTo` path (testers saw 379 → 179).
8. `screen=badges` must render a real badge grid screen (40-badges currently shows Home).
9. The frame rate follows `FeedbackDirector.preferredFPS`.
10. All copy and layout in Results, Codex and Settings must pass Dynamic Type at the default and Large sizes without
    clipping (the Codex's bottom row is cut by Done; the subtitle runs off the edges).

## CI engineer
1. Store frames come in round 3. For now, add a `turn=1` phone frame and a real-finger turned-drag check if any
   simulator tool can inject a touch (e.g. `xcrun simctl io … ` has none; check whether `idb` can be installed
   quickly; if not, document it).
2. Duo: re-shoot the SLAM frame *during* the bite (freeze on bite), and add a REOPEN-NO-BITE check:
   - noise 0.6, close to 60°, reopen to 120° in 0.4 s;
   - expect no `bitten` within 2 s, and `resumed` logged only after the angle is ≥ 95°.
3. Update the closing check to the new 70° threshold.

## Everyone: QA-1
Fix every QA-1 item (`design/QA-1.md`, P1 and P2) that sits in your folders. In particular:
- **App:**
  - P1-1: while paused, send `lidSpeed: 0` in telemetry.
  - P1-2: folded into the resume rule above.
  - P1-3: write relics, gold and achievements on abandon.
  - The lesson Freeze/Bank skip.
  - The Daily partial-best and the practice-after-midnight bugs.
  - The idle timer.
  - Game Center sheets while turned: the scene is no longer rotated by SwiftUI, so present GC un-turned.
  - Lesson and hint overflow on phones.
  - Per-frame allocations.
  - Corrupt-save backup: keep a `.bak` copy and don't overwrite it silently.
  - Copy.
- **Core:** P1-3 needs `HeistSession.partialResult(): RunResult` (the result so far, for abandon). Add it.
- **CI:** add a `testflight.yml` check that fails if `AppIcon-1024.png` is the placeholder (the founder committed the
  rendered icon at R2 start; compare it against a known-bad hash, or check that its pixel variance is above a
  threshold).

Every engineer: write `design/notes/<role>-R2.md`. Don't commit.

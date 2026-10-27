# Scene R4 hand-off (Scene engineer and art lead): polish to "yes"

**Not verified:** nothing here has been compiled (no Mac). CI is the check. New pure helpers that texture closures call
are `nonisolated` (`SceneTextures.lipTopEdge`, `SceneTextures.keyholePath`, as `gumEdge` was). No new files.
Tests: 13 new `@Test`s in `HushTests/SceneTests.swift` (section `// MARK: R4`), and 5 R3 assertions updated (golden
casing, the seat's radius, the taller fangs texture, the node budget 350 → 360).

## For the App (names are final)
| Item | API / rule |
|---|---|
| **Plate text** (item 1) | `ChestArt.plateTextRect(in size: CGSize, style: PlateStyle) -> CGRect`: lay EVERY plate's text in this rect (hint, banner, toasts, lesson card, pause / resume / closing cards). Inside the stitched border and ≥ 8 pt clear of both brass caps, for `plateImage(size:)` plates and stretched `plateSliceImage` plates alike. Symmetric, so y-up = y-down. For the 464 × 48 hint plate it is x 27…437, y 12…36 (24 pt tall: font ≈ 19 pt, `minimumScaleFactor(0.7)`). Insets alone: `ChestArt.plateTextInsets(size:)`. `plateInsets(style)` stays 20 / 30 / 20 / 30 and is only the nine-slice cap insets (it covers the cap + 8 pt; it is not text padding). Geometry helpers: `plateCapRects(size:)` and `plateStitchRect(size:)`. |
| **Hint band** (item 3) | `ChestLayout.hintBand` is **x 60…524**, y 404…452 (was 72…572). It keeps ≥ 8 pt from the pause seat at every phone scale. Your `hintPlateRect` still works: the band no longer meets `pauseRect` + 16. |
| **Pause coin** (item 3) | `ChestLayout.pauseArea` is unchanged (x 594…650, y 372…428: the Duo's coin). The scene now draws a **round brass seat** under the coin at `ChestLayout.pauseCenter(viewScale:)`. This is exactly your `AppCanvas.pauseCenter` clamp (a 56 pt tap frame 16 pt inside the edge), sized to your 55 pt coin + a 4 pt ring at the device's scale. No more square boss plate or "ghost disc". **Keep `BrassCoinButton` at 50 (+5) pt and the clamp at 16 + 28 pt.** If you change either, change `ChestLayout.pauseCoinViewDiameter` / `pauseTapViewSide` / `pauseViewInset` too. The scene reads its scale from its `SKView` (`ChestScene.viewScale`, the `CanvasFit.scale` rule). |
| **Chain tab** (item 2) | `ChestLayout.chainRect` is **x 470…590, y 98…142**: left of the front-right bracket, about 48 screen pt from the edge on a phone. It reads "CHAIN" over "GOLD ×1.1". It shows the **last bank's** multiplier (from `chainUp`), the same number as the bank stack's "Hush Chain ×1.1", from the bank's own frame. It is hidden in the lesson, and so is the stack's chain line. Text column: `chainTextRect` x 497…563. |
| **Meter** | `meterRect` is **x 56…460** (was 520), the well x 142…412 and the teeth at x 436. The word follows the stage: NOISE → STIRRING → WAKING! (`ChestCopy.meterWord`, `ChestScene.meterWord`). VoiceOver may reuse the word. |
| **Bank beat** (item 4) | Between chests the interior keeps about **40 %** of its light: the shutter is at 0.6 and the floor's own lid-shut darkness lifts under it (`ChestScene.interiorLight` ≈ 0.4). **"Next chest…"** shows from 0.8 s into a bank, under the stack, until the next chest's shadow lifts. It never shows in the lesson, over the relic card, or at the run's end. **One prompt at a time:** hide the hint while `bankActive \|\| nextChestShowing \|\| relicBannerShowing`. The counter now finishes rolling at 0.7 s (it was 1.2 s), so "+119" and "115" no longer sit side by side in a still. |
| **Golden** (item 7) | The pop over each revealed golden item is `ChestCopy.goldenPop(c)`: the seal's own total ("×3" on a ×3 chest). The plate line is **"Golden · Light sleeper"** (one casing). Your banner "A golden mimic! Extra gold!" carries no number, so a golden chest now shows one number. Read-out: `ChestScene.lastGoldenPop`. |
| **Phone plaque** (item 8) | A carved plaque in the extension above the lid on phones (extension ≥ 100 pt): "Iron-bound · Chest 4" (golden: "Golden · Chest 4"), from `ChestCopy.extensionPlaque`. It is centred about 45 pt above the canvas lid (lid-local y ≈ 501). That is ≥ 8 pt above your `lidLabelSlot` and under the Daily marker at the safe-area top (gap ≈ 10 pt on a 393 pt phone). If you move the Daily marker lower, keep it ≥ 60 canvas pt from the extension's top, or tell me. Read-outs: `plaqueText`, `plaqueShowing`. |
| **Lever** (founder, CI frame 32) | One rule: `ChestScene.showsLever(hasFold:usesSlider:)` = `!hasFold && usesSlider`. It is re-checked against the **current** layout at every draw and every touch. `turned` plays no part. Tested on fold + unturned and fold + turned. If frame 32 still shows a lever, then either the scene was given `layout.hasFold == false`, or it is your lever highlight (`HUDLayout.leverTrack`): key that highlight on the same rule. |
| **"!" padlock** (App item 9, tester 7) | It's the chest's front lock keyhole. In the turned (fold) frames the art is upside down, so the slot sat above the round top and read as "!". **Fixed in the art:** an oval brass escutcheon frames it, and the slot joins the round top with no neck and tapers to a flat foot (`SceneTextures.keyholePath`, tested). It is not a pose or lock indicator, so there's nothing to label. |
| **Cover** (item 9) | `applyCoverStyle()` now also sets `fillsView` (`resizeFill`, sized to its view). With no letterbox, there are no hairlines. The Zzz drift only as high as the card allows (they fade before the edge), so none is clipped; Home and Results get the same clamp. The amber eye: a warm shine in the seam always (a still shows something watching) and a starry glint on the pupil at each peek (the lid lifts more: 0.16 → 0.3). The juror's "lift the group ~8 %" is the card layout: yours. |

## Delivered (ROUND-4 Scene, items 1–11)
1. **Plates:** `plateTextRect(in:style:)`, `plateTextInsets(size:)`, `plateCapRects`, `plateStitchRect`. `drawPlate` uses the same helpers, so the rects match the art. Tests check every style and 7 sizes, slices, degenerate sizes, and that the longest hints fit the hint plate at ≥ 0.7.
2. **Chain medal:** "CHAIN" / "GOLD ×1.x" sized to the tab's text column; shows the last bank's multiplier, the same frame as the bank; off in the lesson. Tested with the snapshot's NEXT rate set differently (×1.2 vs ×1.1).
3. **Pause stud:** round seat under the coin at every scale (0.55 … 1); ≥ 16 screen pt from the edge; on no bracket (the back-right corner has none, and right-rim studs stop under the seat); ≥ 8 pt from the hint band; off the meter and the HUD. Hint band shortened.
4. **Bank beat:** about 40 % light, never black, with "Next chest…", on every tier and the golden mimic, on the Duo and a phone; tested, lesson included.
5. **Gum:** a curved lip line at every stage. The lower edge dips 14 pt at the centre (was 10), and the top edge sags 5 pt. The crease and the wet highlight follow the curve. The band is ≥ 32 pt thick everywhere. Fang tuck is 44 → 40 and the texture 72 → 80 pt, so no root ever shows above the lip and no tip clips (tested at every stage).
6. **Noise word:** NOISE / STIRRING / WAKING!, warmer then red ink, fits its 72 pt recess (tested).
7. **Golden:** pop = seal; "Golden · <trait>".
8. **Phone extension:** the carved plaque (one texture, warmed in `init`).
9. **Seams:**
   - A held item now draws under the HUD's labels and the pouch's lip (z 28.5 < 29), so "IN BAG" always reads.
   - The bank flyers fly a low arc in the bag strip, under the meter and BANKED.
   - The lesson's chain pop is gone.
   - The cover's hairlines, clipped Z and eye glint are fixed.
10. **Relic Hunter badge:** the lantern relic is redrawn so its silhouette reads: carrying ring, peaked roof with a finial, two see-through panes (holes) either side of the candle post, a flared foot. The locked cream silhouette now reads too. The Codex lantern changes with it (same art source).
11. **Icon:** every coin and sparkle is inside an 80 % centred circle (`ChestArt.iconLooseBits`, `iconSafeRadius`; tested). The table coin moved from (884, 196) to lean on the chest's front at (694, 236). The sparkle moved in slightly.

## Layout changes (canvas, y up; names kept)
meter 56…460 (well 142…412, teeth 436) · chain tab 470…590 × 98…142 (medallion (479, 120) r 15, text 497…563) · hint
band 60…524 × 404…452 · pause area unchanged 594…650 × 372…428; seat = `pauseSeat(viewScale:)` (Duo 590.5…653.5,
phone 0.6 ≈ 544…649) · `nextChestPoint` (335, 236) · plaque 360 × 50 at lid-local y `plaqueCenterY(topExtension:)` ·
lid: `gumRise` 14, `lipSag` 5, `teethTuck` 40, `teethTextureHeight` 80. New constants: `meterLabelWidth`,
`pauseCoinViewDiameter`, `pauseTapViewSide`, `pauseViewInset`, `pauseSeatViewRing`, `minViewScale`, `chainTextRect`,
`frontRightBracketMinX`, `plaqueSize`, `plaqueMinExtension`. `pauseSocketRadius` is now the Duo seat's radius (31.5).

## Performance
4 new nodes (the seat, "Next chest…", the plaque and its label) and 3 small textures warmed in `init` (seat, plaque,
the new chain-tab size). Per frame it is still transforms and alphas; the meter word is rebuilt only on a stage
change. The seat only moves when the view's scale changes. Node budget test: 350 → 360; the drawn budget is unchanged.

## Not done / notes
- **Phones:** the coin necessarily overlaps the interior's back-right corner (x ≈ 551…592). The App's 55 pt coin is
  92 canvas pt at 0.6 and can't fit beside the loot. This is as before. If CI shows loot hiding under it, Core could
  keep `ChestFactory.place` out of `ChestLayout.pauseSeat(viewScale: 0.6)` in R5.
- The capture rotation (fold frames shown upside down) is CI's: the keyhole now reads either way up regardless.

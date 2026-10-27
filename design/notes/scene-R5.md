# Scene R5 hand-off (Scene engineer and art lead): release candidate

**Not verified:** nothing here has been compiled (no Mac). CI is the check. No new files, no new textures beyond the
resized meter plate / flash (keys bumped to `-r5`) and the wider chain tab plate. Nothing new is called from a
texture-drawing closure. No git commit.
Tests: 5 new `@Test`s in `HushTests/SceneTests.swift` (section `// MARK: R5`). 4 R4 assertions were updated: the tab
text is now "CHAIN ×1.x", and the tab has one line instead of two.

## For the App (names are final)
| Item | API / rule |
|---|---|
| **Chest centre** (your item 5) | `ChestLayout.chestCenterX` = **335** (canvas x, `static let`). The eye, brow, name plate, lock, pouch, mouth and `lidLabelSlot` all sit on it (tested). To centre a plate on it and keep it ≥ 8 pt clear of the pause seat, use half-width = `min(chestCenterX − hintBand.minX, pauseSeat(viewScale: s).minX − gap − chestCenterX)`. With gap 8 that gives ≈ 495 pt on the Duo, ≈ 402 at 0.6 and ≈ 379 at 0.55 (tested ≥ 300 at every scale). With your 16 pt `pauseGap`, subtract 16 more. |
| **Fold clearance** (your item 5) | `hintBand` is **unchanged** (y 404…452), so nothing of yours moves under you. To stay ≥ 20 pt clear of the fold edge (`ChestLayout.floorTop` = 456), the plate's maxY must be ≤ 436 (e.g. y 388…436). The scene keeps clear of that: the golden "×n" pop is now clamped at y 356 (was 372), so it tops out at ≈ 383. "CREAK!" (y 356) and the bank stack are unchanged and already under 388. |
| **Pause coin in the bite** (your item 5) | The scene's brass seat now dims to 0.3 while `ChestScene.biteActive` and eases back after it (`pauseSeatAlpha`, tested). Key your coin's hide/dim on the same `biteActive` flag so the two agree. |
| **Chain tab** (my item 1) | One line: **"CHAIN ×1.2"** (`SceneFloorHUD.chainText`, `ChestScene.chainTabText`). It is 20 canvas pt, ≥ 11 screen pt even at 0.55 scale; it may fit down to 19 pt, ≥ 11 pt on every phone 390 pt wide and up. `chainRect` is now **x 424…590** × 98…142. The medallion is at (433, 120), the text column x 451…563. **`meterRect` is now x 56…414** (well 142…366, still 20 segments; teeth at 390). Its y is unchanged, so `HUDLayout.meterTop`, `lessonBand` and `cardArea` don't move. Your lesson ring round the meter (`PlayHUD` reads `meterRect`) follows automatically. VoiceOver: "Hush Chain, times 1.2" is yours. |
| **Daily marker** (your item 5, frame 26) | The phone plaque ("Wooden · Chest 1") is the scene's and has not moved. Its rule from R4 still holds: keep the Daily marker ≥ 60 canvas pt from the extension's top, or ≥ 12 pt above the plaque (`ChestLayout.plaqueCenterY(topExtension:)` ± 25). |

## Delivered (ROUND-5 Scene, items 1–4)
1. **Chain tab:** "CHAIN ×1.2" on one line, cream on leather, at ≥ 11 screen pt. "GOLD ×n" now appears only on the
   name plate's seal. The tab grew left into room taken from the meter (the meter is 46 pt shorter, and its segments
   are 11.2 pt instead of 13.5). One label node fewer.
2. **Flying loot never covers IN BAG / BANKED** (frames 07, 14). The R4 z-order was already right: the labels *are*
   drawn over the loot (zoomed CI frames show the B over the coin). The trouble was red-on-cream and gold-on-gold.
   - New `ChestLayout.bagLabelRect` / `bankLabelRect` (tested to contain the labels as drawn).
   - New `SceneLootView.labelClearAlpha(at:radius:minAlpha:)`.
   - **Bank flyers** fade out before their edge reaches a label. They stay faded, with no flicker back in at the
     stack, and the stack's sparks and pop mark each landing. Each flyer is fully drawn leaving the pouch. Tested pure
     on every pile slot and size, and in the scene frame by frame on the Duo and a phone (`flyersClearOfLabels`,
     `visibleFlyers`).
   - **A held item**, and the 0.18 s hop into the pouch, fades to 0.3 over a label, so the word reads through it
     under the finger. It is whole again away from the label (`heldItemAlpha`).
3. **`ChestLayout.chestCenterX`**: see the table above.
4. **Juror leftovers:**
   - **Zzz on the bands: fixed.** The Zs drift in a velvet lane between the lid's left border and its left band
     (`ChestLayout.zzzLane` 38…121, `SceneLid.zzzPoint`). On iron, gilded, royal and golden lids they no longer
     cross a strap, and they keep out of the App's lid-label slot. Tested for every Z size and phase. The band
     centres are recorded as `ChestLayout.lidBandXs` / `lidBandHalfWidth`. The art still uses its own literals, and
     its texture is untouched.
   - **Gum curve: not done (not cheap).** A curve that reads at 670 pt wide needs ≈ 25 pt of rise. Today
     `gumRise` (14) is capped by two R4-tested invariants: the lip band must stay ≥ 32 pt thick in its 50 pt
     texture, and no fang tip may clip in the 80 pt fangs texture. Lifting the cap means regrowing both textures and
     re-tuning the tuck. That isn't RC-safe, so it is a candidate for 1.1.

## Not done / notes
- Placing the hint plate (fold clearance, centring, the Daily overlap) is the App's work. The numbers it needs are
  in the table above.
- The bite-cost "−10s" pop (y ≤ 336 + 46 rise) can reach y ≈ 395. That is fine as long as the App hides its hint
  during a bite, which it should, since the pause coin hides too.
- Performance: per frame, one distance check per flying or held item against 2 rects. No allocation.

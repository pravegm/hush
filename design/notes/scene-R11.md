# Scene R11 hand-off (Scene engineer and art lead): last polish

**Not verified:** nothing here has been compiled (no Mac). CI is the check. No new files, no new nodes (the node budget
is unchanged). The new art is pure CoreGraphics in `ChestArt` (nonisolated, like the rest of it); nothing new is
called from a texture-drawing closure or a `static let` initializer. All R6–R10 behaviour is kept: quarter turns,
touches in `world`, the pause seat's single source of truth (`pauseSeatCanvasCenter`), the seat fade, and the label
fades. Tests: 9 new `@Test`s in `HushTests/SceneTests.swift` (`// MARK: R11`). No existing assertion was changed; the
R4/R5 chain-tab and meter tests still hold with the new numbers. No git commit.

## For the App (names are final)
| Item | API / rule |
|---|---|
| **Callouts** (item 1) | `ChestScene.calloutActive: Bool`: true while "CREAK!", the bank stack, the bite, the relic card or "Next chest…" is up. Hide the hint plate while it is true (your `AppRules.hintYieldsToScene` already reads it). **Either way** the scene now keeps every callout `ChestLayout.calloutGap` (12) view pt under the plate. It assumes the tallest plate (`hintPlateViewHeight` 48 view pt, centred at `ChestLayout.hintPlateMidY` = 412, your `clearOfFold` band). Optional: set `ChestScene.hintPlateCanvasRect` (canvas, y up) to the plate as drawn. It can only lower the callouts. The lesson is untouched (its card is at the bottom). |
| **Praise ink** (item 6) | `ChestArt.praiseInk(.parchment)` = #7A4300, a burnished gold-brown (≥ 4.8 : 1 on both parchment tones, tested). One line: `PlateArt.calm = Color(hush: ChestArt.praiseInk(.parchment))` turns "Banked! Gently does it." (and "Hold it there…") gold-brown, not moss green. Leather / urgent: the game's gold / the urgent accent. |
| **Heavy Bag glyph** (item 6) | `ChestArt.badgeGlyphArt(motif, radius: 50)` in place of `ChestArt.relicArt(motif, radius: 50)` in `BadgePainter.paint`. `.idol` (Heavy Bag's unique motif; your `motifs` and its test stay) draws a tied sack of gold. Every other motif is unchanged. `ChestArt.badgeGlyph(_:)` says which. |
| **Badge bezel** (item 6) | `ChestArt.badgeImage(motif:metal:earned:side:scale:) -> CGImage?` (cached) is the whole badge: the ground and candle glow, a milled edge (60 teeth), a raised ring lit top-left with a laurel and a star in relief, a sunk lip, the velvet, and the glyph in the tier palette (a cream silhouette until earned). No rivets, no porthole. `BadgeMetal` is `.bronze / .silver / .gold` (your `Tier` by name). Simplest: in `AchievementBadge`'s Canvas, `context.draw(Image(decorative: img, scale: 1), in: CGRect(origin: .zero, size: size))`, falling back on `BadgePainter.paint` if nil. The export at 1024 is `side: 1024, scale: 1`. |
| **Raw-touch diagnostics** (QA-6 P2-1) | `rawTouchesBegan` and `lastRawTouch` are counted and built only `#if DEBUG`. In Release they are computed stubs reading `0` and `"-"`, so `debugStateLine` still compiles. `touchesBegan` does no extra `location(in:)` and builds no string in Release. |
| **Layout changes you read** | `meterRect` is now x 56…386 (was 400). Your lesson ring and the VoiceOver frame follow automatically. `countdownRect` is x 72…150, y 150…190. Nothing of yours keys on the chain tab. |

## Delivered (ROUND-11 Scene, items 1–7)
1. **Callouts never touch.**
   - `ChestLayout.calloutCeiling(viewScale:plate:)` is the plate's bottom minus 12 / scale.
   - "CREAK!" and the bank stack ("Hushed!", "BANKED +n", "Hush Chain ×n", with "Next chest…") drop just enough to sit under it:
     - CI phone (0.6): about 41 and 33 pt;
     - Duo: about 17 and 9 pt.
   - The drop never exceeds 60, and CHOMP! never reaches the plate.
   - The golden "×n", "+6s" and "−10s" popups are clamped under it too.
   - Tested: pure numbers at 0.55 to 1, and the scene on the CI phone (a creak and a Hushed bank, ≥ 12 view pt). The lesson doesn't move.
2. **CHAIN pill.** It is 16 pt further left (x 394…574): 20 canvas pt (12 screen pt on the CI phone) short of the front-right bracket.
   - The tab no longer swells on a pop (only the medallion does), and its crack jolt only goes left.
   - The meter gave up the room (x 56…386, well 140…340: 20 segments of 10 pt, teeth at 361). Texture keys are now `-r11`.
3. **Royal jewels** (`ChestLayout.royalFloorJewels`): one on each front bracket's corner and one on the right rim between its straps.
   - Previously they sat on the candle, under the plate's cap, under the coin, and half under the fold strip.
   - Tested clear of the candle, the countdown, the seat and the plate at every scale, the HUD and the fold.
   - No stud is drawn under a jewel.
4. **"0:10" chip.** It sits 22 canvas pt (≥ 12 screen pt at every phone scale) from the candle (was 8), and is 4 pt higher.
5. **"not safe yet".** It is now 22 canvas pt (13.2 screen pt on the CI phone), heavy weight, with ink at 0.86 alpha.
   - It sits at y 29, off the stitching.
   - While it shows, the IN BAG number eases up to y 55 at 0.9 scale, and the words fade in with it. With an empty bag the number sits level with BANKED again.
6. **Art.** The praise ink, the sack glyph and the milled-bezel badge, with APIs as above. Tested: contrast and warmth, the sack's silhouette (heavy foot, tied neck), and the milled teeth read from the rendered pixels.
7. **Relic card.** Any item in the chest whose drawn circle meets the card as drawn (pop included, plus 14 pt) fades with the card, so it is hidden while the card is up. It is drawn again once the card goes. Tested with frame 15's coin under the right handle.

## Not done / notes
- **Not wired (App files):** the green praise ink and the badges are App-drawn, so they need the two or three lines above in `HushTheme.swift` / `AchievementArt.swift`. Until then the old green and portholes remain.
- The CI phone frames to check next: 13b, 13c, 14, 14b (gap under the plate), 14 / 37 (CHAIN clear of the bracket), 15, 16, and 07 / 12 ("not safe yet").
- The 375 pt phones (scale 0.56) get 12.3 screen pt for "not safe yet". Going larger needs the plate re-laid out.

# Scene R12 hand-off (Scene engineer and art lead): the lid IS the chest

**Not verified:** nothing here has been compiled (no Mac). CI is the check. No new files. There are 2 new sprites (the
cover and the outgoing cover for the arrival crossfade), and 5 new textures (one cover per dress, 1.5×, about 9 MB for
all five). They are warmed in `setUp` with the other dress textures, so no frame builds a texture (tested). The cover
art is CoreGraphics in `SceneArtChest.swift`, drawn with the file's own helpers (`planks`, `strap`, `bracket`,
`filigree`, `gemStud`, `goldLeaf`, `keyholePath`), exactly like `chestFrame`. No `HeistHint` switch exists in Scene,
so `.closeForNext` needed no case. Tests: 6 new `@Test`s in `HushTests/SceneTests.swift` (`// MARK: R12`). No existing
assertion was changed. No git commit.

## For the App / CI (names are final)
| Item | API / rule |
|---|---|
| **Cover** | Nothing to wire. It follows `snapshot.openness`: whole at ≤ 0.02, lifting back to the hinge to 0.15, gone above. |
| **Read-outs** | `closedCoverShowing`, `closedCoverAlpha`, `closedCoverSlide` (front edge's travel, canvas pt), `closedCoverYScale`, `closedCoverDress`, `closedCoverArrivalOffset`, `closedCoverOldShowing`, `closedCoverCanvasFrame`, `closedCoverInWorld`, `closedCoverGlobalZ`, `hudLowestGlobalZ`. |
| **Robbed chest** | `ChestScene.isRobbed(snapshot)`: `hint == .closeForNext` and no loot (or only `.lost`). Read-out `robbedChestShowing`. |
| **Hint plate** | While robbed, "Next chest…" is never drawn, so `calloutActive` stays false and the App's "Close the lid for the next chest" plate shows. |
| **Pure** | `ChestLayout.coverPose(openness:reduceMotion:) -> CoverPose` (alpha, slide, yScale, shade, lift, `isShut`, `isVisible`). Also `coverRect`, `coverTextureRect`, `coverJewels`, `coverLockCenter`, `coverArrivalOffset(age:reduceMotion:)`. |
| **CI frames** | At `lid=0` the floor shows the cover in the chest's tier. In the robbed frame, the chest is open and empty, the tongue is curled, the brow is in the angry "V" with the eye narrowed (wake 0.72), and the fangs are bared. |

## Delivered (ROUND-12 Scene)
1. **The closed-chest cover** (rule 5).
   - What it is: the outside of the lid seen from above, over the interior (`ChestLayout.coverRect`, x 38…632, y 122…454). It overhangs the rims, ends 2 pt short of the fold strip, and stays clear of the bag strip's plates.
   - Every dress has its own cover. All of them have:
     - planks inside a raised border, with a candle highlight that falls off towards the hinge;
     - corner brackets (none in the back-right corner, where the pause seat sits, as on the frame);
     - studs round the border;
     - a brass hasp and a shield lock with a keyhole at the front edge, above the meter;
     - a chunky outline, and a soft shadow baked round the sides and front.

     By dress:

     | Dress | Extras |
     |---|---|
     | Wooden | none |
     | Iron | iron bands at x 172 / 498, carrying on from the frame's front straps |
     | Gilded | gold bands, gilt trim, filigree, gold lock |
     | Royal | adds three set jewels: either side of the lock, and a boss in the middle |
     | Golden | gold leaf over the boards and the border |
   - The jewels and the lock are tested clear of:
     - the candle, the countdown, the meter and the chain tab;
     - the pause seat and the hint plate, at every scale;
     - the bands.
   - Motion. The cover is anchored at the hinge edge. As the openness goes 0.02 → 0.15 (smoothstep), it foreshortens towards the fold (yScale 1 → 0.42), so its front edge slides back to the hinge. It also darkens a little as it tilts from the candle, and fades over the second half. Reduce Motion: a crossfade in place.
   - Layering (tested by total z). The cover sits at z 27.8 in the floor root:
     - over the loot (25) and the between-chests shadow (27);
     - under a held item (28.5) and under the HUD's lowest piece (the pause seat, 28);
     - so the meter (90), IN BAG / BANKED, the candle and the chain tab stay on top.

     Two fixes for things that would otherwise show through or over the shut lid:
     - While the lid is shut, nothing inside the chest is drawn (no halo or glint over the lid), and no relic glimmers while the cover is up at all.
     - A bite with the lid shut hides the throat and lower fangs (they are drawn over the cover's layer).
   - It lives in `world` (`floor.root`) and follows the chest's hop, so all four k draw it. Tested for k 0…3 × the five dresses.
2. **The robbed chest after a bite** (`isRobbed`). It is drawn open and empty:
   - The bite's end no longer dims the interior. There is no "Next chest…" and no between-chests shadow.
   - The cover shows only once the lid nears shut.
   - Tongue: curled tight and a little red.
   - Lid (`SceneLid.update(angry:)`): the eye narrowed (0.72), the brow in the bite's "V", the fangs bared (0.9), no blinks, no Zzz. This holds even though Core puts the mimic back to Asleep.
3. **The next chest under a shut lid arrives already covered.** On `chestArrived`, `floor.arrive()` keeps the old cover fading out (0.45 s) under the new one. The new one is in the new dress from the first frame and settles 14 pt up into place over 0.4 s (not under Reduce Motion). The interior never shows (tested: alpha 1 on every frame after a bite-close and after a bank, for every tier and golden).

## Not done / notes
- The golden rim twinkles (`SceneFloor` sparkles) still draw on the frame's rims. Where those rims lie under the cover, they are hidden while the lid is shut. The cover's gold leaf carries the golden look meanwhile.
- `MimicPortraitScene` (the home title chest) is unchanged. It already follows the lid.
- CI frames to check: the cover at `lid=0`, wooden and royal (the jewels, the lock above the meter), and the robbed frame with "Close the lid for the next chest". BANK-CLOSE-FULL: the bank stack reads over the cover.

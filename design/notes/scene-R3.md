# Scene R3 hand-off (Scene engineer and art lead): the last mile

**Not verified:** nothing here has been compiled (no Mac). CI is the check. Pure CoreGraphics (`ChestArt`, plates,
glyphs, the icon) is nonisolated; everything SpriteKit stays `@MainActor`. New files (XcodeGen picks them up):
`Hush/Scene/ChestArtPlates.swift`, `Hush/Scene/ChestArtIcon.swift`.

## For the App (names are final)
| Item | API |
|---|---|
| **CREAK** (founder rule) | `ChestScene.showCreak()`. Draws "CREAK!" (under the hint band), the meter's red flash and jolt, a lid twitch and a canvas bump (no shakes under Reduce Motion; the meter flash still shows). Call it from `FeedbackDirector.shared.onCreakAccent` (already wired in `GameController`). **The scene has no noise rule of its own** (the lesson's `nudgeNoise(0.55)` jumps the noise with the lid still and must not creak). Ignored during a bite. Read-outs: `creakShowing`, `creakCount`, `meterFlash`. |
| **Plates** (decision 5) | `PlateStyle` `.parchment` (hints, lesson steps, toasts), `.leather` (pause / resume / closing cards), `.urgent` ("Freeze!"). `ChestArt.plateImage(size:style:scale:) -> CGImage?` renders a plate at exactly `size` pt (cached per size): `Image(decorative: img, scale: scale)` in a frame of that size. For cards that change size: `ChestArt.plateSliceImage(style:)` (120 × 56 pt) + `ChestArt.plateInsets(style)` (20 / 30 / 20 / 30) with `.resizable(capInsets:)`. `ChestArt.platePath(size:)` (symmetric, so y-up = y-down) for shadows / hit shapes. Ink: `ChestArt.plateColors(style)` → `text`, `accent` (eyebrows), `muted` (sub-lines, "Skip"), plus `fill`/`fillDark`/`stitch`/`edge` (all tested ≥ 4.5:1 text, ≥ 3:1 accent). One prompt at a time: the plate is the only card. |
| **Drawn glyphs** (no SF Symbols in the chest) | `ChestArt.glyphImage(_ PlateGlyph, side:scale:)`: `.candle .fang .lock .coin .bag .arrowUp .arrowDown .pause .tick .chain .eye`, in the game's outlined style. Use them for the lesson-end card (candle / fang / lock), the lesson arrows and the resume card's "Lift me". |
| **Icon** (decision 6) | `ChestArt.appIcon(size: CGFloat) -> CGImage` (non-optional), opaque: `CGImageAlphaInfo.noneSkipLast`, no alpha channel at all. In the game's style: slit amber eye with iris starburst (the in-game eye), shield lock and keyhole, 8 irregular fangs with 2 long canines, star coins from the seam, lid and body iron bands lined up, lightened iron. Tested opaque at 1024 / 120 / 60 px and that the eye reads at 60 px (≥ 3:1 against the dungeon corner). `appIconImage(size:)` is the optional form. |
| **Lid label slot** | `ChestLayout.lidLabelSlot` = canvas **x 110…560, y 902…946**: the lid-half teaching words ("Slide this up… slowly", "Lift this half") go here, ABOVE the brow plate, never over the eye or lashes (juror P1-6). The App already maps it (`HUDLayout.lidLabelBand`). |
| **Lever** | `ChestLayout.leverTrack` (canvas rect, for the step-1 highlight) = x 602…638, y 608…876. Short, in the lid's right edge band, above the lip and teeth, right of the plate. A fold layout (`layout.hasFold`) never draws it and never forwards lid touches to `sliderTouch` (decision 4) even if `usesSlider` is true: `ChestScene.leverShowing`. |
| **Pause coin** | `ChestLayout.pauseArea` **moved**: now **x 594…650, y 372…428** (56 × 56; `pauseCenter` (622, 400)). The frame draws a brass **socket** there instead of the back-right corner bracket (radius `pauseSocketRadius` 37), so the coin sits in its seat, never on the metalwork. Please draw the coin ≤ 56 pt, centred on `pauseCenter`. |
| Hint band | unchanged: x 72…572, y 404…452. |
| Meter | `ChestLayout.meterRect` **shortened**: x 56…**520**, y 104…136 (top 136 unchanged). The right end of the front rim is the Hush Chain tab. |
| "not safe yet" | Drawn by the scene under the IN BAG number while the bag holds loot (decision 3). `ChestScene.showsBagSublabel = false` retires it (e.g. after the teaching runs). |
| Cover portrait | `MimicPortraitScene.applyCoverStyle()` (asleep, cracked a sliver, `idlePeek`: the amber eye glints through the seam every ~5 s with the tooth tips, then the slow 2.4 s breath; `artScale` 1.2 so the chest fills the card and is centred on its body). `idlePeek` and `artScale` also settable on their own. Off under Reduce Motion. |

## Delivered (ROUND-3 Scene)
1. **P0 bank void.** The chest never leaves. `chestRoot` (frame, bed, tongue, front wall, lock) only hops ≤ 8 pt and is
   always at full alpha. Between chests a **shutter** (the lid's shadow) covers only `ChestLayout.rimInner`: it sweeps
   fold → front in 0.35 s on a bank (and at 1.45–1.8 s of a bite) and stays down; on arrival it lifts in 0.5 s while
   the new dress **cross-fades** over the old one (`frameOld` / `wallOld`). Test `bankDarkensOnlyTheInteriorOnEveryTier`
   checks every tier + golden, Duo and phone, every frame through the bank, the gap and the next arrival
   (`chestShellIsWhole`, `interiorShut`).
2. **Sleeping mouth.** The lip's lower edge is a curve (lowest at the centre, +10 pt at the corners) with a scallop over
   each fang. 7 fangs (2 canines, one chipped), roots following the curve. Asleep they stay 40 % bared
   (`ChestLayout.teethAsleep`): every tip shows (≈ 12–30 pt; canines ≈ half). Stirring 60 %, waking 80–100 %. Slow jaw
   breath (2.4 s) while asleep; the drool sits on the left canine's tip. Tucked roots never rise above the lip (tested).
3. **Tongue.** New outline tapering to a rounded point (no dome). The groove is its own node, shown only when lit
   (0 when dim, fades while tensed). Waking/biting uses a fully FILLED darker/redder copy of the same outline with the
   tip curling up (pale underside crescent), cross-faded on top: never a hollow U. Papillae ~15 % in every state.
4. **Lid collisions.** Lever: x 620, track 36 wide, y 132…360 (lid-local), knob 60 × 46: above the lip (96), right of
   the plate (≤ 565), inside the 16 pt inset. Zzz moved to the upper-left of the eye. The teaching slot is above the
   brow (`lidLabelSlot`).
5. **Edges (≥ 16 pt).** Candle x 16…50 (dish 34 wide); the countdown pill hangs beside the dish (x 58…136, y 146…186);
   IN BAG plate from x 16, BANKED to x 654; "−10s"/"+6s" pop clear of the candle. Test: every HUD rect and the pause
   coin inside the side insets.
6. **Hush Chain.** A leather tab on the front rim (`chainRect` x 530…654, y 100…140): linked-rings medallion,
   "HUSH CHAIN" small caps, "GOLD ×1.2" under it. Pops on `chainUp`, cracks on `chainBroken`. No green anywhere: the
   bank stack is cream "Hushed!" / gold "BANKED +n" / amber "Hush Chain ×1.3", one centred column (y 372 / 332 / 292).
7. **Golden mimic.** Gold-leaf frame and lid (R2) + twinkles on the floor's rims too, a bright golden name plate with
   emerald studs, "GOLDEN MIMIC · Light sleeper" on it, a bright seal with the real multiplier (QA-2 P2-8), "×2" over
   each item as it's revealed.
8. **Name plate (juror P2).** Two tokens ("Light sleeper · Iron-bound", "Dreamer · Royal"); the multiplier is a milled
   brass seal on the plate's left end ("GOLD ×1.5", hidden at ×1). `ChestCopy.plateSubline`, `plateSeal`, `plateTrait`.
9. **Relic found.** A 380 × 250 parchment card centred on the floor (y 147…397, under the hint band): "RELIC FOUND!",
   the relic art (r 60), its name, over the sunburst. Starts when the bank stack ends (1.15 s), fully shown 0.12–1.5 s
   (`relicCardFullyShown`, ≥ 1.2 s for a still frame). Bank flyers now rise out of the pouch and dive into the BANKED
   coin stack **under** the plate's labels (they live under the HUD), so "BANKED" is never covered.
10. **CREAK** as above (founder change: `showCreak()` only).
11. **Icon, plates, glyphs, cover portrait** as above.
12. **QA-2 P2-6.** The relic glimmer uses Core's `HeistSession.relicGlimmers` for on/off (same window as the hint and
    sound), brightening toward the glint line.

## Layout changes (canvas, y up)
meter x 56…520 (well 142…472, teeth at 496) · chain tab 530…654 × 100…140 · candle 16…50 · countdown 58…136 × 146…186 ·
IN BAG 16…256 (clasp (60, 52), number from x 104, "not safe yet" y 21) · BANKED 424…654 (coin (626, 46), number right
596) · pause 594…650 × 372…428 (socket) · relic card centre (335, 272). Lid: lip 50…96 (curved edge, +10 at corners),
fangs top = 66 + 44·(1 − shown), seal (112, 131) r 31, lever x 620 y 132…360, Zzz upper-left of the eye.

## Performance
Per frame still only transforms / alphas. New nodes: ~16, mostly hidden (dress cross-fade 2, crease 1, rim sparkles 3,
seal 3, chain tab 1, meter flash 1, bag sub-label 1, creak 1, relic card 2, bank sub 1). Tree budget test raised
330 → 350; drawn budget unchanged (≤ 185). New textures are small (plates, seal, golden plate) and warmed in `init`.
The 120 fps budget is unaffected; Feel owns the 60 / 120 switch.

## Not done / notes
- QA-2 P2-11 (warm `.golden` lazily) left as is: all dresses are still warmed in `init` (~0.4 s once).
- The App must still move its SwiftUI cards onto the plates and use `lidLabelSlot` for the lid words; the scene can't.

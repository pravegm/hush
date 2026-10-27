# Scene R2 hand-off (Scene engineer and art lead): art unification and readability

**Not verified:** nothing here has been compiled (no Mac here). The first CI run is the check. All Scene code is
`@MainActor` except `ChestArt` / `Painter` / `ScenePaint` / `ArtImageCache` (pure CoreGraphics, any thread).

## What the App must do (names are final)
| Item | API |
|---|---|
| Fill the screen | Build the scene with `ScreenLayout.make(hasFold:viewSize:)` (the SpriteView's full size). The scene is `layout.size`; `scaleMode` defaults to `.aspectFill` (`.aspectFit` also works: the aspect matches). The canvas sits at `contentOffsetY`; map canvas → view as `viewY = (size.height − contentOffsetY − canvasY) × scale`. |
| Turned round | `scene.turned = true`. **Stop rotating the SpriteView.** Rotate only the SwiftUI overlays. Touches need nothing (read in `world`). |
| Hint band | `ChestLayout.hintBand` = **x 72…572, canvas y 404…452** (the floor's back edge by the fold). No scene HUD there. |
| Pause coin | `ChestLayout.pauseArea` = **x 582…646, y 372…436** (64 × 64; 24 pt from the right edge, 20 pt below the fold, ≥ 16 from every canvas edge). No scene HUD there. |
| Meter top | `ChestLayout.meterRect` is now **x 56…614, y 104…136** (`HUDLayout.meterTop` = 136). The lesson band must clear it (Scene keeps canvas y 140…400 free of HUD except the candle at x ≤ 84 and the chain medallion at x ≥ 606). |
| Portrait | `MimicPortraitScene(size:)`; `openness` (0 sliver … 1 wide grin), `wake` (0 asleep … 1 glare), `tier`, `golden`, `reduceMotion`; extra: `showsBackdrop`. Show it with `SpriteView(scene:, options: [.allowsTransparency])` (clear background; `scaleMode = .resizeFill`, the art fits a centred 400-unit box). Home: openness follows the hinge/slider; cover: `openness ≈ 0.1, wake 0`; Results: hushed → asleep, bitten → `wake 1, openness 0.6`. |
| One art source (SwiftUI) | `ChestArt.relicImage(relic, found:, radius:, scale:)` and `ChestArt.lootImage(kind, value:, radius:, scale:)` → `CGImage` (cached, thread-safe). Show with `Image(decorative: img, scale: scale)`: it is `ChestArt.artSide(radius:)` points square. These are the exact pixels the scene's textures use. Locked relics are a simplified dark silhouette. Please replace `RelicArt`'s flat `relicPath` fill with this. |

## Delivered (ROUND-2 Scene 1–15)
1. **World + turned.** `world` (canvas coordinates) → `shaker` (shaken) + `overlay`. `turned` = rotation π about the scene
   centre (`world.position = (W, H − offset)`). Touches: `touch.location(in: world)` → `beginTouch/moveTouch/endTouch`
   (internal, the tests use them). Test `turnedTouchMapsToTheItemsFloorPoint`. Drags that overshoot into the front
   wall / table clamp into the bag (`ChestLayout.floorTouchPoint`). The slider fraction spans the whole visible lid.
2. **Extension art.** Above the lid: plank tiles (`lidTile`, aligned with the canvas lid's planks, bands and studs),
   the far border and corner brackets (`lidCap`) moved to the top of the visible lid, one vignette over all of it.
   The eye stays centred in the canvas lid. Below the floor: the chest's front wall (in `chestRoot`, so it slides with
   the chest), a big brass lock centred on it, then the tabletop. The exit offset grows with the extension. On the Duo
   the extension is 0 and none of it is drawn. Overlays (flash, danger, candle-out dark) cover the whole scene.
3. **`MimicPortraitScene`** (new file): front view in the in-game textures (planks, bands/brackets by dress, the big lock,
   a domed lid tilted like the icon, the same fang row and the same eye/iris/slit pupil/fleshy lid as the game), warm
   glow, coins on the rim, 2.4 s breath, blinks, Zzz, golden sparkle. Textures built lazily per dress.
4. **Tongue** redrawn: ~70 % width at the root tapering to a rounded tip at the bag; one off-centre highlight (no twin
   lobes); short crease at the root only, fading; velvet stipple; rim light on the upper edge; dark throat at the
   fold; ±1.5° asymmetric sway (3 s). Curl texture matches the new outline.
5. **Coins:** gold discs (#F5C542 face, dark rim ring, embossed star, crescent shine), 2–3-coin stacks by value
   (`ChestArt.coinCount`: copper 5–6 → 1, 7–8 → 2, 9–10 → 3; silver ≥ 30 → 2), each coin with its own outline
   (`LootArt.layerDetail`). Silver: silver disc, keyhole emboss. Gems: faceted with shaded facets. Oil: flask with a
   "+6s" parchment tag (text from `Tuning.oilSeconds`, CoreText).
6. **Mimic charm:** pointed fangs with rounded tips (2 long canines, varied lengths, one chipped), tucked up behind a
   fleshy lip while asleep and sliding down as it wakes (no squash); drool glint while asleep; a fleshy eyelid bed
   (no porthole) with a crease; a brass brow plate in two halves that tilts into an angry "V" (−2° asleep, 5° stirring,
   12° waking, 16° biting); a centre knob per dress (rivet / ruby / the royal crown / emerald); the lid squashes on
   the slam.
7. **HUD labels:** "IN BAG" (left) and "BANKED" (right), 15 pt small caps (14 pt floor), numbers 34 pt; IN BAG warms
   to pulsing amber while the bag is at risk (stage ≥ stirring). The pouch (middle) glows gold as a drop target while
   an item is held (brighter over the bag); bagged loot piles IN the pouch (its front is drawn over the pile).
   "NOISE" engraved on the meter, teeth at its full end, a tick at the bag-jingle floor (`noiseFloor`); the meter is on
   top of everything (z 90 in the shaker).
8. **No text over loot:** the floor title is gone. The lid's name plate has the name and a sub-line
   (`ChestCopy.plateSubline`): "Light sleeper · Iron-bound · gold ×1.5" (×1 hidden), golden
   "GOLDEN · gold ×2 · light sleeper". The plate slides in with each new name.
9. **Bite callout:** CHOMP! (cream, thick dark-red edge), "Too loud!", "−164" over the pouch, "−10s" off the candle,
   from `biteCost` (either order with `bitten` in a frame; `bitten.lostValue` is the fallback). The scene draws no
   Freeze.
10. **Chain:** a brass medallion on the right rim above BANKED ("×1.3", "CHAIN" caption), shown while `chain ≥ 1` and
    `chainMultiplier > 1`; pops on `chainUp` (with a "Hush Chain ×1.3" popup by it), cracks, shakes and fades on
    `chainBroken`.
11. **Golden:** a gold-leaf dress (`ChestDress.golden`: gold wood with flecks and sheen, bright gold bands, emerald
    velvet), sparkles on the lid, "×2" over each item as it's revealed.
12. **Relic glimmer:** a faint pulsing gold sparkle at a relic's spot while openness ≥ depth − 0.25 and it isn't
    revealed yet (`SceneLootView.glimmer`); `ChestScene.glimmeringRelics` for CI.
13. **Candle low:** in the last `Tuning.torchLowSeconds` the flame gutters (shrinks, dips), the floor's edges sink into
    gloom (0 → 0.55), and a big "0:12" countdown sits over the empty top of the candle's track (red and faster under
    5 s). "+6s" rises from the flame on `oilAdded`.
14. **24 relic silhouettes** (`relicArt`): the 12 R1 shapes (ring, skull and mirror redrawn so they no longer read as a
    balloon, a light bulb and a paddle) plus candlestick, hourglass, bell, lantern, pocket watch, spyglass, scroll,
    potion, shell, feather, music box, idol. Test: all 24 grid-sampled silhouettes differ. Silhouettes are true unions
    (`CGPath.union`) minus holes.
15. **One source:** `ChestArt.drawArt` renders everything; `SceneTextures.loot` makes its SKTexture from
    `ChestArt.lootImage` (the same cached CGImage SwiftUI gets).

## QA-1 (Scene items)
- P2-7 (turned touch mapping): correct by construction now (touches read in `world`, the SpriteView isn't rotated);
  unit-tested. Still eyeball one real turned drag on the first device build.
- P2-12: `SceneLootView.update` allocates nothing per frame (no Set / filter / sort / dictionary / key strings; a slot
  is configured only when its item changes; a frame stamp finds stale slots; insertion sort on a reused buffer).
- P2-13: the HUD formats numbers only when the Int changes (bag, banked, countdown seconds, chain tenths).
- Copy: "candle" in all scene comments; the scene shows no "torch" text.

## Layout (canvas, y up)
Floor: bag strip y 0…110 (IN BAG x 12…256, pouch x 264…406, BANKED x 424…658) · meter y 104…136 · interior 134…420 ·
candle x 7…45 (countdown x 4…84, y 300…344) · chain medallion centre (638, 176) · pause 582…646 × 372…436 · hint band
72…572 × 404…452. Lid (lid-local): lip y 50…96, plate centre (335, 131) 460 × 70, eye centre (335, 255) r 91, brow
centre (335, 384), slider x 606. Bank group: "Hushed!" y 372 over "BANKED +n" y 332; relic banner centre y 280.

## Performance and memory
- Textures are code-drawn once and cached; per frame only transforms/alphas/colours change. The eye's paths rebuild
  only on a quantised wake change; the ring on its 64 steps; labels only when their text changes.
- Drawn nodes ≈ 130 in a looting frame (tested ≤ 185); tree ≤ 330.
- Memory: five dresses (four tiers + golden) × frame (3.8 MB) + lid (4.9 MB) + front wall (1.9 MB at 1.5×) + cap and tile
  (~1 MB) ≈ 58 MB, all warmed in `init` (~0.4 s once). If that is too much, drop the frame/lid scale to 1.5
  (`SceneTextures.make` `scale:`) or stop warming `.golden` until chest #3.

## Assumptions about Core / Feel
- `biteCost` comes with every `bitten` (same frame, either order). `chain` / `chainMultiplier` are the NEXT bank's
  multiplier; the badge shows from `chain ≥ 1`. `ChestSpec.golden` set on the chest from its arrival. `noiseFloor` is
  the bag-jingle floor (0…0.3). Relic shapes come from `RelicCatalog` (an unknown id draws a gold crown).
- The candle-low threshold is `Tuning.torchLowSeconds`; the oil tag reads `Tuning.oilSeconds`.

## Not done / for the App
- The App owns the hint text, Freeze clearing on a bite, the Codex/Results/badge layouts, and presenting
  `MimicPortraitScene`. Badges can reuse `ChestArt.relicImage` / `lootImage` on velvet tiles.

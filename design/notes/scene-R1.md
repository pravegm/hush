# Scene R1 hand-off (Scene engineer and art lead)

**Not verified:** nothing here has been compiled yet (no Mac here). The first CI run is the check.

## Files (`Hush/Scene/`, tests in `HushTests/SceneTests.swift`)
| File | What |
|---|---|
| `ChestArt.swift` | The shared art source (pure CoreGraphics, no actor): `HushPalette`, `ChestArt.palette`, `lootPath`, `lootColors`, `relicPath`, `mimicEye`. Extras: `lootArt`/`relicArt` (silhouette + detail strokes + shine + holes, for richer SwiftUI drawing), `mimicEyeCenter/Radius`, `mimicLashes`, `teethRow`, `flippedVertically`. |
| `SceneLayout.swift` | `ChestLayout`: every rect on the canvas (pure, tested). The App already reads `hintBand` and `pauseArea`. |
| `SceneTextures.swift` | Texture cache, `Painter` (y-up CG helpers), `ScenePaint` (colours, WCAG contrast), `SceneRNG`, `SceneLabel` (≥ 18 pt rounded black text with outline), `SceneNumber`. |
| `SceneArtChest.swift` | The big code-drawn textures: chest frame and lid per tier, tongue, satchel, hinge, teeth, plate, meter, candle, clasp, slider, iris. `TierStyle` per tier. |
| `SceneFloor.swift` | The chest on the floor half: frame, the velvet tongue (the tell), darkness, the warm wash. |
| `SceneFloorHUD.swift` | Snore-o-meter, torch candle, in-hand value + shut-hold ring, gold counter (rolls). |
| `SceneLoot.swift` | Loot nodes from `LootState` (light, glints, relic rays, held lift, bag pile, bitten flight). |
| `SceneLid.swift` | The lid half: planks, eye (crop-clipped iris), teeth/jaw, name plate, Zzz, slider. |
| `SceneMoments.swift` | Bite, bank, arrival, relic banner, torch out, the Waking pulse, popups, shake. |
| `SceneParticles.swift` | Fixed particle pools (dust, sparks, smoke, motes). |
| `ChestScene.swift` | The `SKScene`: frame loop, events → moments, touches → driver. |

## Layout (canvas 670 × 952, y up; view y-down = 952 − y)
- **Floor half (sharp), y 0…456**
  - Bag strip y 0…110 (= `FloorSpace.bagRect`): the satchel. In-hand value + clasp + shut-hold ring in the left panel
    (x 12…256), gold counter + coin stack in the right panel (x 424…658). Bagged loot is drawn as a pile in the
    satchel's mouth (x 270…400), **not** at Core's slot positions (those sit under the numbers). Purely cosmetic: the
    whole strip is still the drop target.
  - Snore-o-meter on the front rim: `ChestLayout.meterRect` = x 88…582, y 106…134 (20 segments; notches at 0.35/0.70;
    shakes past 0.85; red segments pulse at Waking).
  - **Hint band (App): `ChestLayout.hintBand` = x 80…590, y 138…198** (view y 754…814). No scene HUD there. Front loot
    can pass under it (it's the interior's front edge).
  - Interior (`FloorSpace.interior`) y 134…420. Torch candle on the left rim `torchRect` x 7…45, y 150…412.
  - **Pause (App): `ChestLayout.pauseArea` = x 600…670, y 386…456** (view y 496…566). No scene HUD there.
  - The App's `lessonBand` (x 50…620, y 138…254) is free of scene HUD too. Moments' titles sit at y ≥ 296; the relic
    banner's name at y ≈ 230 only shows on a bank with a relic (never in the lesson).
- **Fold band y 456…496:** the brass hinge strip.
- **Lid half y 496…952 (may blur):** ambience only: the mimic's face, the name plate (x 165…505, y 582…638), Zzz, the
  slider (x ≈ 578…634, only when `driver.usesSlider`). Nothing time-critical.

## What the App must know
- `ChestScene(layout:)`, `driver`, `reduceMotion`, `layout`, `reset()` as in ARCHITECTURE. `scaleMode = .aspectFit`,
  `anchorPoint = .zero`, background = `palette.dungeonDeep`. All big textures are warmed in `init` (~0.3 s once).
- **`reset()`** clears moments/FX/loot; it keeps live touches so their ends still reach the driver. A snapshot whose
  `time` jumps back > 0.25 s also resets.
- **Clock:** FX run on snapshot time (pauses freeze them) plus up to 0.4 s of wall time after the session stops
  stepping, so a `freezeOn=` frame shows the moment's peak (bite: teeth slammed + CHOMP; bank: flyers mid-air;
  relic: banner up).
- **Touches:** begin below canvas y 476 (mid fold band) → floor (`floorTouch…`, floor space via
  `layout.floorPoint(fromCanvas:)`, follow-ups stay on the floor even onto the lid). Begin above → `sliderTouch` only
  when `usesSlider`. Ids `ObjectIdentifier(touch).hashValue`, times `touch.timestamp`. Ends are forwarded for every
  begun touch, cancel = end. Multi-touch on in `didMove`. Turned round: UIKit maps `location(in:)` through the
  rotation; please eyeball a turned drag on the first Duo/CI frames (App NEEDS item).
- **Read-outs for CI/tests:** `biteActive`, `bankActive`, `relicBannerShowing`, `torchOutLevel`, `eyeWake`,
  `teethShown`, `shownBanked`, `chestOffset`, `visibleLoot`, `nodeCount`, `drawnNodeCount`, `drawnFrames`.
- The scene does **not** print `HUSH-T frame 120` (the App does).
- `reduceMotion`: no shake, no red flash, gentler twitch/flicker; the Waking pulse is steady.

## Art decisions
- **Chunky cartoon:** every shape has a thick warm-black outline (`ChestArt.outline` #1C100A), a top-left-lit gradient,
  rim-colour detail strokes and a glint shine. Loot: copper = a 3-coin pile, silver = an ingot, gems = classic cut gem
  icon, oil = a corked amber flask with a flame mark, 12 relic silhouettes (crown, goblet, teacup, key, ring, amulet,
  skull, egg, mirror, horn, dice, compass) tinted by `Relic.tint`.
- **Light:** the interior sits under a dark layer (0.72 → 0.06 with openness) plus a front-heavy ramp; a warm additive
  wash grows down from the fold (12 % → 100 % of the interior). Each item shows by its own `light` (fades in by 0.4,
  darkened until 1), sits in its own warm pool of light, glints when lit ≥ 0.6, and relics get a slow golden sunburst
  from light 0.4. Motes drift in the light. The torch flickers the light; in the last 15 s it gutters (dips) and the
  candle track pulses red.
- **The tell (floor):** the tongue breathes on a 4.2 s cycle (Asleep), twitches every 0.7–2 s (Stirring), curls its
  edges and lifts its tip with a quiver (Waking), and reddens with noise. The floor also gets a red edge pulse at
  Waking. The meter is the truthful read-out; Dreamer twitches only touch the lid.
- **The mimic (lid):** one big cat-slit amber eye in a carved socket: a drooping shut lid with lashes and Zzz (Asleep),
  random flicker-opens (Stirring), half-open and tracking the finger / held item (Waking), wide (Bite). Nine chunky
  ivory teeth hang from a velvet gum at the fold: nubs asleep, bared as it wakes.
- **Tiers:** wooden (warm wood, iron corner brackets, red velvet), iron-bound (darker wood, iron straps and rivets, plum
  velvet), gilded (gold straps, gold trim and filigree, crimson velvet with gold buttons), royal (lacquered red-brown,
  gold, gem studs on rims and round the eye, a crown crest, royal-purple velvet).
- **Moments:** see `SceneMoments.swift`'s header (timings). The chest leaves off the front after a bite or a bank and
  the next one slides in from the front, so there is never a cut.

## Palette (`ChestArt.palette`)
wood #8A5A33 · woodDark #4A2C18 · iron #58626D · gold #FFC94A · velvet #5C1A33 · tongue #E45A72 · dungeon #12282C ·
dungeonDeep #071315 · candle #FFD98A · danger #FF4A3D · amber #FFAA33 · text #FFF4DC. Scene extras: meter green
#56D68C, brass #D9A441, leather #8A5530 / #4E2B16, ivory #F6EBD2. Tested contrasts: text/gold/candle on dungeonDeep ≥ 7,
danger/amber ≥ 4.5, plate letters on brass ≥ 4.5.

## Performance
- Static art is cached textures (scale 2–3); per frame only transforms/alphas change. CGPath rebuilds: the eye only
  when its quantised openness (25 steps) changes; the shut-hold ring only when its 64-step progress changes.
- ≈ 130 nodes drawn in a typical looting frame (≈ 200 in the tree incl. hidden pools); tested ≤ 160 / ≤ 260.
- Memory: eight tier textures (~35 MB at 2×). If that's a problem, drop the frame/lid scale to 1.5.

## Assumptions about Core (from `core-R1.md`)
Lost items keep their last position (the scene flies them from where it drew them). `light` is 1 for held/bagged.
Relic names come from `RelicCatalog.all` (fallback "A relic", a gold crown for an unknown id).

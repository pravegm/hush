
## App engineer (R1)
- **Scene:** none blocking. The App frames the SpriteView to the aspect-fit canvas rect itself (`UI/Layout.swift`
  `CanvasFit`) and draws its HUD in `ChestLayout.hintBand` (hint), `ChestLayout.pauseArea` (pause) and
  `HUDLayout.lessonBand` (x 50…620, y 138…254: the First Chest card). Please keep scene HUD out of those, and keep
  forwarding touch ENDS even while the driver ignores begins (the App always accepts ends so no item stays "held").
- **Scene:** `HUSH-T frame 120` is printed by the App's `advance(dt:now:)` (it counts frames). The scene need not.
- **Scene:** the canvas is drawn turned round with SwiftUI `.rotationEffect(180°)` on the whole hosted view, SpriteView
  included. UIKit maps touches through that transform; please confirm `touch.location(in: self)` is right on the
  first CI/Duo frames (a turned frame with a drag).
- **Feel:** the App makes a fresh `SliderLidSource()` per run (so Home's drag never leaks a jump into a chest), and
  sets `FeedbackDirector.deviceHasFold = true` on the first hinge sample.
- **Core:** the App reads `HeistSession.result` once `isFinished`, and calls `nudgeNoise(to:)` for the lesson's
  scripted stir (0.55), its calm-down (0.1), and the demo `noise=` hold (every frame).

## CI engineer (R2)
All of these are DEBUG / demo-only unless stated. Every new line keeps the `HUSH-` prefix. CI already uses them and
degrades gracefully (SKIP / INFO / expect-miss) until they land.
- **App: `noiseUntil=pause` demo key** (for duo.sh REOPEN-NO-BITE). With `noise=<x>`, hold the noise only until the
  first pause of any reason, then stop calling `nudgeNoise` for the rest of the run and print
  `HUSH-T noise released <noise 2dp>`. Without it `noise=0.6` is held all run, so a bite is impossible and the check
  can only report INFO "inconclusive".
- **App: `HUSH-T resumed angle <θ 1dp>`** (append the hinge angle at the moment of resume; keep `HUSH-T resumed` as the
  prefix, CLOSE-PAUSE greps it). REOPEN-NO-BITE checks θ ≥ 95°. Until then it uses the last `HUSH-H` sample before the
  line (10 Hz at most, so it can lag by a sample).
- **App (+ Core if a hook is needed): `golden=1` demo key** (ci/scenarios.txt `36-golden-mimic`). Make the run's first
  chest golden (`ChestSpec.golden = true`, bypassing "6 % from #3"), without touching the Daily's stream. Also add
  `golden=1` to the `HUSH-T event chestArrived …` trace of a golden chest (the scenario's expect is
  `event chestArrived .*golden=1`).
- **App / Scene: accessibility hooks for the turned-drag UI test** (HushUITests/TurnedDragUITests.swift; a UI test can't
  read stdout, so not `HUSH-T event itemBagged`):
  - `hud.bag` (all builds; good for VoiceOver too): an accessibility element whose **frame is the IN BAG pouch's
    on-screen rect** (where it is drawn, after `ChestScene.turned`), `accessibilityValue` = the in-bag item count as a
    plain decimal string ("0", "1", …), label e.g. "In bag".
  - `debug.loot` (DEBUG demo runs only): an element whose **frame is the on-screen rect of the most-lit item that can be
    grabbed right now** (light ≥ the grab threshold), `accessibilityValue` = "id=<n> kind=<k>"; absent or zero-size
    while nothing is lit. Compute the frame from where the node is DRAWN, e.g.
    `scene.convertPoint(toView: world.convert(itemNode.position, to: scene))` plus the SpriteView's origin, never from
    the touch-mapping code under test.
  - Both must be pure accessibility (e.g. a clear SwiftUI overlay with `.accessibilityElement()` +
    `.allowsHitTesting(false)`, or `UIAccessibilityElement`s on the SKView), so the synthesized touch still reaches the
    SpriteView. The test launches `-hushDemo "screen=run;mode=attract;seed=7;lid=0.9;turn=1;fold=1"`, drags at 200 pt/s
    from `debug.loot` to `hud.bag`, and expects the value to rise within 5 s. It SKIPS while either element is missing.
- **App / Scene: hold the frame on an event freeze.** For `freezeOn=bite|bank|relic|torchLow|torchOut`, after the 0.3 s
  beat also pause the scene's actions (`scene.isPaused = true`, or hold the FX at their peak), so "Too loud! −N", "−10s"
  and the chomp are still on screen when a shot lands 3–15 s later (the Duo's two-panel shots are slow; R1's SLAM
  frame showed the next chest instead).
- **App / founder: commit the app icon without an alpha channel.** The R2 `AppIcon-1024.png` is RGBA (fully opaque);
  App Store Connect refuses a 1024 icon with an alpha channel (ITMS-90717). testflight.yml now flattens it in the
  workspace for its own build (ci/icon-check.sh, FIX_ALPHA=1), but the committed file should be RGB.

## App engineer (R2)
All promised hooks were found and are called by their exact names: Core `rest(dt:)`, `resumeGrace(seconds:)`,
`partialResult()`, `.candleLow`, `.relicDeeper`; Scene `ChestScene.turned`, `MimicPortraitScene` (`openness`, `wake`,
`tier`, `golden`, `reduceMotion`), `ChestLayout.hintBand` (y 404…452), `pauseArea`, `pouchRect`; Feel
`HingeLidSource.canResume` / `reset()`, `FeedbackDirector.glimmer(on:)`, `goldenArrived()`, `preferredFPS` (instance) and
`onPreferredFPSChange`. Nothing blocking.
- **CI (your R2 list, all done):**
  - `noiseUntil=pause` → `HUSH-T noise released <n 2dp>` at the first pause of any reason.
  - `HUSH-T resumed angle <θ 1dp|->` (prefix kept).
  - `golden=1`: no Core hook needed. The run's seed becomes the first seed ≥ `seed=` (default 7) whose chest #3 is golden
    (`ChestFactory.isGolden(seed:index: Tuning.goldenFromIndex)`), so the Daily stream is untouched. The golden chest's
    arrival logs `HUSH-T event chestArrived … golden=1`. A pilot reaches chest #3 in ~25 s (use `pilot=expert`, or
    `skipTo=20`). **Core**, only if you want the literal "first chest golden": add `SessionOptions.goldenFirst`.
  - `hud.bag` (all builds): frame = `ChestLayout.pouchRect` mapped to the screen (turned with the overlay), value =
    the in-bag item count. `debug.loot` (demo only): the most-lit grabbable item, from the snapshot's floor point
    through the App's own canvas→view mapping (`CanvasFit`; independent of the scene's touch mapping), value
    `id=<n> kind=<k>`. Both are `.accessibilityElement()` on clear views with hit testing off.
  - Event freezes (`bite|bank|relic|torchLow|torchOut`) set `scene.isPaused = true` (and SpriteView's `isPaused`) 0.4 s
    after the freeze. The bank freeze itself waits 1.25 s (the counter's roll), so the number shown is the total.
  - The icon and badges are written as RGB PNGs (colour type 2, no alpha) by `App/OpaquePNG.swift`; the icon line is
    now `HUSH-T icon ok 1024x1024 rgb=1`. **Founder/CI:** copy the next rendered icon over the committed RGBA one.
  - `screen=pose` on a phone sim now shows Home (a phone never shows the book card). Shoot it with `fold=1` or on the
    Duo sim (`orient=landscape`; the App never asks for portrait while `orient=landscape` is set).
  - New lines: `HUSH-T phase active|inactive|background`, `HUSH-T abandoned gold= chests= relics=`,
    `HUSH-T device-orient <raw>`, `HUSH-T orient portrait requested (release path)`, `HUSH-T gold mismatch …` (should
    never appear), `HUSH-T skipped <s> banked=<g>`, `HUSH-T event stageChanged … rest=1` (the mimic settling while
    paused).
- **Scene:** the App sets `scaleMode = .aspectFill` on the ChestScene (the SpriteView is the whole screen) and
  `backgroundColor = .clear`, `scaleMode = .aspectFit` on the portraits (600 × 480 scenes). Keep `hintBand` clear of
  `pauseArea` (tested in AppTests) and the lesson band (canvas y 148…264, above the meter) free of scene HUD.
- **Hardware (founder's Duo):** whether `GKAccessPoint.trigger(handler:)` calls back on dismissal (the app is drawn
  un-turned while the dashboard is up and re-turns in the handler); whether `UIDevice.orientation` reads `.portrait`
  when held camera-up in tabletop (the "Other way round" banner).


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

## CI engineer (R3)
DEBUG / demo-only unless stated; keep the `HUSH-` prefix. CI already passes these keys (unknown keys are ignored) and
reports INFO / expect-miss / no-freeze until they land. `pose=book` is in DemoMode already: thanks, CI uses it.
- **App: the CREAK rule, visible to CI** (duo.sh SLAM-CREAK, scenarios `13b-creak`). Wherever the App applies the
  "noise jumps > 0.25 in 0.3 s" rule (the call to `FeedbackDirector.creakAccent()` / the Scene's CREAK), print
  `HUSH-T creak jump=<Δ 2dp> noise=<n 2dp>`, and add `creak` to `DemoMode.Freeze` as an EVENT freeze (0.3 s, then the
  scene hold), logging `HUSH-T freeze creak`. If Feel detects it inside `handle` instead, log the same line from there.
- **App: the relic freeze must land on the relic card** (juror R2: "15 captured a bank"). The card only rises once the
  bank group has had `SceneMoments.bankGroupEnd` (1.15 s), but `freezeDelay(.relic)` is 0.3 s, so the scene is paused
  before the card exists. Make `.relic` wait until the card is up (≈ bankGroupEnd + 0.5 = 1.65 s, or the Scene's R3
  card timing), and ideally add a `freezeDelay=<s>` key that overrides any event freeze's delay (Swoop has it):
  scenarios `15-relic`, `DR2-relic`, `PR2-relic` already pass `freezeDelay=1.7`.
- **App: a lesson bank freeze that shows the praise.** In a lesson, `freezeOn=bank` waits `bankFreezeDelay` (1.25 s),
  past `LessonScript.praiseSeconds` (1.0 s), so the frame is the final card, never "Banked! Gently does it."
  (REVIEW-2-ux P1-7 wants BANKED 8 with that line). Use ≤ 0.6 s for the bank freeze while `mode == .lesson`
  (scenario `07b-lesson-banked`).
- **App: a lesson trace.** On every `lessonDisplay` change print `HUSH-T lesson step <n> praise=<0|1> line '<line>'`,
  so CI can prove each lesson frame's step (scenarios 04/05 expect `HUSH-T lesson step 2|3`).
- **App (+ Core if needed): a deterministic golden chest.** `golden=1` makes chest #3 golden, so the golden frames
  (36, 36b, DR1, PR1) rely on `freezeAfter=` timing to skip chests 1–2. A `golden=first` (e.g. Core's
  `SessionOptions.goldenFirst`, as the App suggested in R2) would make "the first chest is golden" exact.
- **App (nice to have):** print `HUSH-T dynamic-type <UIContentSizeCategory raw value>` at launch, so the Large
  Dynamic Type frames (41–47, launched with `-UIPreferredContentSizeCategoryName …`) can prove the size took.
- **App / Scene: cover-display handover lines.** COVER-SLOW-REOPEN reports the relight angle from the first
  `HUSH-T pose play` after a shut; REVIEW-2-duo P1-3's `HUSH-T relight angle=<θ>` would make it exact (CI already
  greps it).
- **Launch lead:** the store captions now live in `ci/store-scenarios.txt` and `ci/duo-store-scenarios.txt` (copied
  from screenshots.md §A/§B, 27 Oct, ≤ 6 + 6 words, linted). Two args differ from the doc (both real states, noted in
  the files): D1/P1 use the casual pilot (the proven reveal), DR1/PR1 wait for chest #3 (golden=1's chest).

## App engineer (R3)
Every hook named in the brief is called by its exact name. Present at the end of the round: Scene `ChestArt.appIcon(size:)`
(ChestArtIcon.swift), `ChestArt.plateImage(size:style:)` / `plateColors` / `glyphImage` (ChestArtPlates.swift),
`ChestScene.showCreak()`, `ChestLayout.pauseArea` / `hintBand` / `meterRect` / `leverTrack` / `lidLabelSlot`; Feel
`onCreakAccent`, `preferredFPS(lidSpeed:animating:)`, `requiredResumeAngle`, `coverResumeAngle(relight:)`,
`effectiveResumeAngle`. Nothing blocking.
- **CI:** the "Codex 9/24 vs 22/24" mismatch is `ci/duo.sh` line 414: `ui-codex` launches with `progress=late` while
  `ui-home` / `ui-results` use `progress=mid`. Please shoot the Duo Codex with `progress=mid` (keep a separate
  `codex-late` frame if you want the full Codex). AppTests `onePresetAgreesAcrossHomeCodexAndResults` pins the App side.
- **CI (your R3 list, done):** `freezeOn=creak` (logs `HUSH-T event creak` on every crack; Feel also logs `HUSH-T creak
  accent …`), `freezeDelay=<s>` (any event freeze, 0…10 s), `.relic` now waits 1.65 s by default, a LESSON bank waits
  0.5 s, `HUSH-T lesson step <n> praise=<0|1> line '<…>'`, `HUSH-T dynamic-type <category>`, `HUSH-T relight angle=<θ>` and
  `HUSH-T handoff angle=<θ>`. Not done: `golden=first` (needs Core's `SessionOptions.goldenFirst`; `golden=1` + chest #3
  stands).
- **CI, behaviour changes to expect in the Duo logs:**
  - no `pose cover-open` / `small-canvas-open` lines ever (decision 1); new `HUSH-T handover hold <from>-><to> angle=<θ>`
    on every small ↔ inner change in a live hinge run, and the run then resumes only on the inner canvas;
  - a live run's first hinge report logs `HUSH-T first hinge sample held angle=<θ>` and pauses (it resumes on
    `canResume`, so expect one extra `HUSH-T resumed angle …` early in a hinge run);
  - a Duo-layout demo run with no pilot, no `lid=` and no hinge yet is `input fixed` (shut, no lever), not `slider`;
  - `HUSH-T orient ask reason=<card|launch|cover|lift|device|button> device=<n>` before each portrait request, and
    `HUSH-T orient ask skipped …` when the device is held landscape (POSE-BOOK in book pose should now keep the card);
  - `HUSH-T mask <portrait|allButUpsideDown> live=<0|1> iface=<…>` on every mask refresh;
  - `HUSH-T callout <text>` for the one-time tips and the golden banner; `HUSH-T ending finished headless` if a candle-out
    had to be finished off-screen.
- **Founder / Launch lead:** Settings › About's line is now "Diagnostics", shown in DEBUG or after a 2-second press on
  the About text (any build). TestFlight builds no longer show it by themselves. Device-test step 9 needs the press.


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

## App engineer (R4)
Hooks called by exact name, all present at the end of the round: Scene `ChestArt.plateTextRect(in:style:)`
(ChestArtPlates.swift; every plate's text is laid out in it through `PlateFit` / `PlateTextLayout` in HushTheme.swift),
`ChestArt.plateCapWidth`, `ChestLayout.pauseArea` / `hintBand` (the hint plate is `HUDLayout.hintPlateRect`: the band kept
16 pt clear of the pause area wherever the Scene puts it), `SceneMoments.bankGroupEnd` / `bannerTime` (the App hides
hints and holds callouts while the relic card is up). Nothing blocking.
- **Scene (ROUND-4 App 9, tester 7's "!" padlock; agrees with CI's finding below):** it is not an indicator. It is the
  chest's front-lock keyhole (`SceneArtChest.bigLock`, ~line 621: a round hole over a narrow slot). Upright (frame 32)
  it reads as a keyhole; in a turned frame (30, 31, 33, 34, the player's own view once the Duo is turned) the hole is
  under the slot, so a still shows "!". The App has nothing to label or remove. Suggested art fix: a classic keyhole
  (a shorter slot that flares wide at the bottom, hole and slot as one filled outline: today they are two sub-paths
  of one path, so check the 4 pt overlap doesn't cancel under the fill rule), and the same for `PlateGlyph.lock` (39's
  stakes row).
- **CI, your lever question (32):** there's no lever in `32-reveal-fold-unturned`; `usesSlider` is false on any fold
  layout (App and Scene both check `layout.hasFold`). The brass bar with a knob above the eye is the mimic's brow plate.
- **CI (captions to update):**
  - `19-results-fresh` and every Results frame: the first tile is now **Opened / chests** (`AppRules.chestsOpened`: the
    strip's count, the chest the candle went out on included), not "Banked chests". The story's "N chests emptied" line
    is now "N chests opened before the candle gave out."
  - One prompt at a time: the first Hush Chain tip arrives WITH a bank, so it now shows once the NEXT chest is live
    (after the bank beat, and after the relic card if one is queued), for its full 2.4 s; `HUSH-T callout <text>` is
    logged then. A golden chest's banner can likewise wait for a relic card. Freezes keyed on the tip need ~1.2–3 s more.
  - New log: `HUSH-T input switch hold <from>-><to>` (a live run handed to the hinge: leaving Play anyway, or a fold
    appearing). It does not release `noiseUntil=pause`.
  - The Results chevron has its own 18 pt strip under the scroll (41/45); the legend is inside the strip card (19).
  - Dynamic Type (your 41 = 45 question): fixed per the founder. Text grows in full through XXXL and is capped only at
    the accessibility sizes (1.12 × XXXL, `HushType.accessibilityGrowth`), so 41–44 (AX-L) should now be larger than
    45–47. Please re-shoot 41–47 and check that nothing clips (Home's menu and the lesson's final card scroll at the cap).
  - Frame 32 lever: the App rule is now `AppRules.usesSlider` (no lever on any fold layout, turned or not), and tested.
- **Founder / Launch lead (runbook steps 9 and 13):** the exact steps are in `design/notes/app-R4.md` "Diagnostics".
  The press is now on the grey **Version** line under About (2 s); it clicks when it toggles; the panel shows the hinge
  angle live plus the last hand-off and relight angles (kept across launches).

## CI engineer (R4)
No new demo key is needed: every R4 re-shoot uses keys that exist (`mode=attract`, `freezeDelay=`, `freezeAfter=`,
`lid=`). Asks and findings from the R3 frames (`artifacts/ci8s`, `artifacts/store1`), details in `design/notes/ci-R4.md`:
- **App (R4 item 9, the "!" padlock):** it is the front padlock drawn turned round. Its keyhole (round top over the
  slot) reads as "!" upside down. It shows in every turned fold frame (30, 31, 33, 34) and as the lock glyph on 39's
  "Ease the lid shut to bank" row. It is not a pose or lock indicator. Keep the glyph upright, or use a symmetric one.
- **App:** `32-reveal-fold-unturned` (`fold=1;turn=0`, phone sim, casual pilot) draws the lever on the lid half, and
  `31` (`fold=1`, turned) doesn't. Is a lever meant to show on a fold layout when it isn't turned? The Duo store set
  (`turn=0`) didn't show one, so this may be pilot or phone-sim only. Please check.
- **App (Dynamic Type):** the logs confirm the category is applied (`HUSH-T dynamic-type …AccessibilityL`), but
  `41-results-axl` and `45-results-xxxl` are the same picture, so the type stops growing at XXXL. If the cap is
  intended, say so and 41–44 only prove the capped layout. If not, the AX frames haven't tested AX3 yet.
- **Founder / docs (`docs/appstore/screenshots.md`; CI may not edit it):**
  - D3/P3 args gain `freezeDelay=0.25` and D4/P4 `freezeDelay=0.6`. At the default 1.25 s, plus the 0.4 s scene
    hold, the whole bank group had gone, so store1's frames showed only a black interior.
  - DR1/PR1: args are now `pilot=expert;golden=1;freezeAfter=13;freezeOn=bank;freezeDelay=1.75`. The headline changes
    from "A golden mimic. *Double* gold." to "*Extra* gold", because R4's seal shows the real total multiplier (×3 on
    an Iron-bound golden chest).
  - Checklist line 74 ("D3's floor is not blacked out") stays open until Scene R4 item 4 lands.
- **Founder (duo.sh SLAM, run 40533062342):**
  - The hold before the slam now has two 1° wiggles, so samples keep flowing.
  - A slam that peaks under 60°/s with no hit is retried once.
  - It is INCONCLUSIVE, not FAIL, when the tool under-delivers twice (peak < 60°/s and the noise rose < 0.05).
  - Every SLAM line records the slam's sample count.
  - INCONCLUSIVE never trips STRICT=1.
- **Done for App R3's ask:** `duo.sh` `ui-codex` uses `progress=mid` now, the same preset as Home and Results.

## App engineer (R5)
Hooks called by exact name, all present at the end of the round: Scene `ChestLayout.chestCenterX` (335),
`pauseSeat(viewScale:)`, `topExtension(_:)`, `plaqueCenterY(topExtension:)` / `plaqueSize` / `plaqueMinExtension`,
`ChestScene.biteActive`. The App never assumed the meter's width (`meterRect` is read for its y, the VoiceOver element
and the lesson ring only), so the new 56…414 meter and 424…590 chain tab need nothing from the App. Nothing blocking.
- **CI (re-shoot and check):**
  - **30 / 39 (and a Duo `ui-home`):** fold Home and the fold lesson's final card use compact metrics on a short fold
    floor (`AppCanvas.tightFloor`: floor half < 420 pt). Expect no clip and no scroll at default type.
  - **44 (AX-L Home):** the Daily status sits under its title; Codex / Badges and Settings / Game Center stack one per
    row; the menu scrolls with the fade and chevron. Expect no "…" and no mid-word break. A **44b**
    (`screen=home;fold=1;dynamicType=AX-L`) would cover the fold too.
  - **12 / 13c / 16:** the hint plate is centred on the chest's axis (x 335) while it fits, and sits 16 pt lower
    (canvas y 388…436, 20 pt off the fold). **13:** the pause coin is hidden during the bite (the Scene dims its seat).
  - **26:** the Daily marker is centred on the chest, 12 pt above the plaque.
  - **20 / 38:** the phone Results' hero mimic shrinks (to ≥ 60 pt) so both strip rows sit above the fade.
  - **40 + badges/*.png:** Light Fingers is a feather, Heavy Bag the idol, Dragon's Hoard the goblet.
  - **First Hush Chain tip:** it now shows AT the first chain bank (`HUSH-T callout Hush Chain! …` lands on the bank
    frame, not chest 2's lidCracked) for 3.5 s. A frame of it: `freezeOn=bank` on the first hushed bank of a fresh
    profile with `freezeDelay=1.0`.
- **Founder:** the Game Center badge images for Light Fingers, Heavy Bag and Dragon's Hoard changed: re-upload those
  three 1024 PNGs from the next `screen=badges` run if the old ones are already in App Store Connect.

## CI engineer (R6)
New checks in `ci/duo.sh` (FLAT-OPEN, WATCHDOG, LANDSCAPE-PLAY) and a landscape drag XCUITest
(`testLandscapeTurnedDragBagsALitItem`, in ci.yml and now also on the Duo in duo.yml). Details in `design/notes/ci-R6.md`.
Everything works without the asks below (fallbacks), but each makes a verdict sharper:
- **App: `k=<0..3>` at the END of the canvas line**: `HUSH-T canvas <w>x<h> fold=<0|1> turned=<0|1> k=<k>`. Keep the
  prefix and the first `<w>x<h>`: PORTRAIT, COVER-SLOW-REOPEN (`INNER_CANVAS` 669x951) and the launch's portrait wait read
  it. Your in-progress `updateCanvas` says `<w>x<h>` is the REAL window, so CI assumes that. Without `k=`, LANDSCAPE-PLAY
  falls back to the aspect (wider than tall = odd k), and says INCONCLUSIVE if the size is portrait-shaped.
- **App: the `quarter=<0..3>` demo key** (forces k over `AppRules.quarterTurns`, DEBUG only). The landscape XCUITest
  launches `screen=run;mode=attract;seed=7;lid=0.9;turn=1;fold=1;orient=landscape;quarter=3`, because on the iPhone 18 Pro
  sim (ci.yml) a `fold=1` phone may never get a landscape interface.
- **App: a `debug.canvas` accessibility element** (demo runs only, pure accessibility, no hit testing, like `debug.loot`),
  `accessibilityValue` = `k=<k> w=<w> h=<h> fold=<0|1>`. The landscape test then checks that k is odd, and SKIPS rather
  than passing on a portrait layout. Without it, k is not verified (the window size is recorded instead).
- **App: the `hud.bag` and `debug.loot` frames must be the on-screen rects AFTER the quarter turn.** If they sit inside the
  rotated root, check that SwiftUI reports the rotated bounding box. If they don't, the drag lands on the wrong spot and
  the test FAILs, and VoiceOver's frames are wrong too.
- **App: the watchdog line** is grepped as `HUSH-T watchdog resume` (or any `HUSH-T resumed …`). Keep that wording.
- **App, the watchdog's "no hinge sample for 4 s" branch: already covered, please keep it.** On the sim a STILL hinge
  sends no samples, so the brief's rule alone would resume a lid resting closed at 55–60° after 6 s. CLOSE-PAUSE's duo-h3
  (a 15 s shot on the closing card at 55°) would catch exactly that. The in-progress `AppRules.watchdogResumes` already
  keeps a silent hinge whose last angle is under `Tuning.closingAngle` paused. If that refinement goes, CLOSE-PAUSE's
  `resumed@` will show a resume at 55°.
- **App: POSE-CARD.** `screen=pose;pose=book;orient=landscape` still expects `HUSH-T pose standUp` and a landscape frame.
  R6 removes the blocking card on a Duo. Tell CI:
  - what `pose=book` shows now (the held card for the frame, or the new tip);
  - the tip's log line (say `HUSH-T tip standUp shown|dismissed`).
  POSE-CARD can then follow. Until then a POSE-CARD FAIL there may be by design.
- **App (optional):** `HUSH-T hint tooWide` when "That's wide enough" shows. FLAT-OPEN would then assert the hint at 180°.
  Today it only proves no pause, no gap in the lid lines, no slider switch, and still live after the return.

## App engineer (R6)
Answers to CI (R6), all delivered (details in `design/notes/app-R6.md`):
- **Canvas line:** `HUSH-T canvas <w>x<h> fold=<0|1> turned=<0|1> k=<0..3>`. `<w>x<h>` is the REAL window, `turned` =
  k == 2, `k=` last. `fold=1` now also on a Duo's LANDSCAPE inner display (the fold is judged on the
  portrait-equivalent canvas).
- **`quarter=<0..3>`** (DEBUG): forces k, but only on a fold and only when its parity fits the window (odd k on a
  landscape window). On a portrait window `quarter=3` is ignored and the rule's k is used, so `debug.canvas` then
  says an even k and your test SKIPS, as designed. `fold=1;orient=landscape` also gives a phone sim the Duo's mask
  (portrait + both landscapes), so `XCUIDevice.shared.orientation = .landscapeLeft` can really turn it.
- **`debug.canvas`** (demo runs only, no hit testing): value `k=<k> w=<w> h=<h> fold=<0|1>` (the real window).
- **`hud.bag` / `debug.loot`:** they live inside the rotated SwiftUI root (`rotationEffect(90·k)` about the window
  centre). SwiftUI reports accessibility frames after the transform (R2's 180° turned drag relied on that), and for
  quarter turns the bounding box is the exact rect. Not verifiable here: if the landscape drag misses, tell me.
- **Watchdog:** `HUSH-T watchdog resume angle=<θ>` (any resume also logs `HUSH-T resumed angle …`). Founder's
  correction applied: it resumes ONLY a closing pause (no menu, background or cover), paused ≥ 6 s, with the last
  known hinge angle ≥ 95° and the canvas on the inner display. There is NO "silent hinge" clause any more: a lid
  resting at 55–60° (or with no reading at all) stays paused forever, so CLOSE-PAUSE's duo-h3 holds.
- **"Carry on":** the closing card shows it after 3 s; tapping it logs `HUSH-T carry on angle=<θ>` then
  `HUSH-T resumed angle …`. After it (or the watchdog) only a NEW hinge report can close the card again.
- **POSE-CARD:** the blocking card is gone. `screen=pose` / `pose=book` (with or without `orient=landscape`) now show the
  small "Stand it up like a little laptop" tip on Home, and log `HUSH-T pose tip shown` (then `hidden` /
  `dismissed`). No `HUSH-T pose standUp` line exists any more (never expect it). Suggested POSE-CARD: launch
  `screen=pose;pose=book;orient=landscape`, PASS on `HUSH-T pose tip shown` with no `HUSH-T paused pose` and the
  Home route (`HUSH-T screen home`). Scenario 25's expect column should become `HUSH-T pose tip shown`. With `mode=`
  the run starts and plays (the tip is Home / lesson step 1 only).
- **`HUSH-T hint tooWide`** when "That's wide enough" goes up. Also new: `HUSH-T iface <orientation>`,
  `HUSH-T hinge nil angle=<θ>` (once per nil run), `HUSH-T mask … held=<orientation>` (the live hold).
- **Orientation policy:** a live run (the lesson too) holds the orientation it is in on the inner display
  (`HUSH-T mask landscapeLeft|landscapeRight|portrait live=1`); menus are unlocked (`allButUpsideDown`). Demo runs
  with `orient=landscape` or `pose=book` take no hold (as before).
- **Founder:** Diagnostics now has the event log and a Copy button: Settings › About › hold "Version" 2 s › Copy log.

## App engineer (R7)
For CI (details in `design/notes/app-R7.md`). Nothing blocking; no demo key changed.
- **Resume line:** the App now follows Feel's line in force everywhere (`hinge.effectiveResumeAngle`: 92° to enter,
  88° once lifted). The R6 watchdog resumes at that line (was 95°). A check that greps `HUSH-T resumed angle <θ>` and
  needs θ ≥ 95 should now accept θ ≥ 88.
- **Fresh chest (BANK-SHUT-REOPEN):** over a fresh chest (`HeistSession.isFreshChest`: ready, never opened past 0.05,
  empty bag; also the run's first chest with the lid shut) the closing pause resumes as soon as the filtered angle
  reaches the line, with no stillness wait, and logs `HUSH-T fresh chest resume angle=<θ>` before the usual
  `HUSH-T resumed angle <θ>`. The lid gets 0.8 s of grace. The card reads "Lift the lid for the next chest", never
  "Hold still…". A pause over a chest in play keeps the full rule (lifted AND still 0.3 s).
- **Pause coin:** same place (`pauseArea`, `lootKeepOut` unchanged, so no Daily deal changes). On a Duo (a hinge seen
  or a fold layout) during a live chest it needs a 0.35 s press-and-hold; a shorter press shows "Hold to pause". A UI
  test can check that a 0.1 s tap on "Pause" leaves the menu shut (`XCUIElement.press(forDuration: 0.1)`), and that
  `press(forDuration: 0.6)` opens it. VoiceOver's activate still pauses at once.
- **Copy:** "Ease the lid down to bank" (hint, final card), lesson step 5 "Ease the lid down to upright to bank it.".
  Store frames that show the old "shut" line will differ.
- **Lesson:** step 1 also passes after 4 s anywhere in 80–125° (praise "That'll do."); Skip shows from step 1 after
  20 s; the Freeze step judges held items by displacement (< 8 pt in 0.3 s).
- **Settings:** the Haptics toggle is now "Vibration" (Off / Normal / Strong); new "Lid sensitivity" (Forgiving /
  Normal / Careful) row. Settings frames will differ.
- **Game Center:** `GameCenterManager.authenticate()` now runs on the first visit to Home after the lesson
  (`HUSH-T gc authenticate route=home`), or at once in demo runs (as before).
- **Diagnostics:** "Copy log" = the event log, a blank line, then `HingeLidSource.traceText()`.

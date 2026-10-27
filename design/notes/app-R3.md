# App engineer, Round 3 hand-off (27 Oct)

Not compiled here (CI is the compiler). Nothing committed. Files touched: `Hush/App/` (GameController, AppRules,
AppModels, BuildChannel, DemoMode, GameCenterManager, LessonScript, OrientationLock), `Hush/UI/` (HushTheme, PlayHUD,
PoseCards, ResultsView, HomeView, Pages, RootView, Layout, AppIconArt, AchievementArt), `Hush/Persistence/ProgressStore`,
`HushTests/AppTests.swift`, `design/NEEDS.md`. Every parallel hook was present at the end and is called by its exact name
(list in NEEDS.md, "App engineer (R3)").

## Founder decisions
1. **Cover fallback deleted.** `smallCanvasOpen`, `smallCanvasIsOpen`, `watchSmallCanvas` and their tests are gone; a
   cover-sized canvas on a Duo is always `.cover`. New pure rules (`AppRules.canvasClass`, `handoverHolds`,
   `mayResume`): any small ↔ inner canvas change during a live hinge run calls `closingPause.hold()` (logged
   `HUSH-T handover hold`), and the closing pause never resumes while the canvas is small. Tests:
   `aSmallCanvasIsAlwaysTheCover`, `aHandoverHoldsUntilStillOnTheInnerDisplay` (the whole close → cover → relight →
   still sequence through `ClosingPause`).
2. **Noise frozen in pause.** The paused path neither steps nor rests (no catch-up either); the first step back is
   `clampStep(dt)` (≤ 1/30 s). `restChunks`, `rest(_:seconds:)`, `pauseRestSettlesWithoutTheCandle` and
   `restChunksCoverTheGap` are retired. New `noiseIsUnchangedAcrossAPause` drives a real `GameController`: noise, stage,
   candle and clock are identical after 35 s paused, and the first frame back burns ≤ one frame.
3. **"bank" everywhere.** Hint `.shutToBank` = "Ease the lid shut to bank" / "Slide the lever down to bank"; lesson
   "… to bank it."; the stakes row follows the layout; Results' empty story says "Close the lid to bank your loot".
   "not safe yet" under IN BAG is drawn by the Scene; the App keeps it on for the teaching runs
   (`scene.showsBagSublabel = runs < 5`). VoiceOver reads "In bag, 179 gold, not safe yet". The cover card calls the
   Scene's `applyCoverStyle()` and is centred.
4. **Copy follows the layout.** `sliderWording` = no fold (`layout.hasFold`), for hints, lesson, stakes and Home's
   caption. A fold layout never draws or takes the lever (`usesSlider`, `sliderTouch`). Input on a Duo never falls back
   to the lever: before the first hinge report a real run is `.hinge`, held in the closing pause ("Move the lid a
   little"); a demo run is `.fixed` (shut) so CI's fold frames still draw. "Play anyway" (below) is the one lever case.
5. **In-world plates.** `PlateBackground(style:)` shows the Scene's `ChestArt.plateImage(size:style:)` (the one-line
   source is `PlateArt.image`; a drawn fallback uses `ChestArt.plateColors`). Parchment: hint, callouts, lesson step,
   the lid cue, the Daily marker. Leather: pause menu, closing card, lesson final card, the new `.leather` button kind.
   Urgent: "Freeze!" and the lesson's stir. No SF Symbols in the chest (drawn `PauseGlyph`, `ArrowGlyph`, `TickGlyph`,
   the Scene's `glyphImage` for the stakes). One prompt at a time: the hint, lesson overlay and pause coin hide while a
   card is up; the closing card is ONE plate between the meter and the fold (`HUDLayout.cardArea`, never over NOISE) and
   the lid-half "Lift me" is gone.
6. **Icon.** `AppIconArt` shows `ChestArt.appIcon(size: 1024)` (cached); `IconExport` writes that image through
   OpaquePNG (RGB, no alpha). `AppIconPainter` deleted.

## The rest of the brief
- **Lesson step 1 (UX P0-1):** `LessonScript.LiftCue` (`lift`/`lower`/`liftMore`/`hold`) drives both the line and the
  marker: "↓ Lower this half a little" above 112°, "Hold it there…" (tick) in 90–112°, "↑ Lift this half" below 90° or
  flat. The words sit in the Scene's `lidLabelSlot` above the brow, never on the lashes. Test `liftMarkerAndLineAgree`
  sweeps 0–180°. The phone lever marker lost its duplicate sentence.
- **Hints (UX P0-2, QA P2-3):** `.freeze` replaces any hint on the same frame (test). The gate is clocked on wall time
  and cleared when a pause begins.
- **Callouts:** first `chainUp` ever "Hush Chain! Sleepy banks pay more", first `chainBroken` "It stirred. Chain
  broken.", first jingle floor ≥ 0.10 "Full bags jingle. Bank soon." (once ever: `ProgressData.seenTips`, tolerant, no
  version bump); every golden arrival "A golden mimic! Double gold.". 2.4 s in the hint band; a warning hint wins.
- **Results:** tiles first (equal height, detail line reserved, "while it slept"), then the strip capped at 2 rows
  with "+N more", a legend ("💤 = banked while it slept · teeth = it bit · glow = golden mimic", only what's there),
  "Longest Hush Chain: 3 (gold ×1.3)", "First haul! / Now beat it." on the first haul, a cause line under the title
  ("Your candle burned out." / "The mimic bit you 3 times. Candle out."), the last empty chip says "out". `FadingScroll`
  fades the overflow above the buttons with a chevron. **Never blocked:** the closing pause only engages while a chest is
  live, moments step through closing/pose pauses, and a candle-out the scene couldn't draw (cover display) is finished
  headless after 2.6 s (`HUSH-T ending finished headless`).
- **Pose card:** "Turn it sideways. Lift the glowing half."; `pose=book` demo key (implies `screen=pose`, any shape, no
  portrait asks); automatic asks (card, launch, cover) skip while `UIDevice.orientation` is landscape; the lift rule and
  the button always ask; leaving landscape while the card is up asks (`reason=device`). "Play anyway" appears after a
  refused request (`OrientationLock.onRefused`) or 8 s, and plays landscape on the lever, aspect-fit (CanvasFit and
  `scene.scaleMode`), until the interface is portrait again.
- **First hinge sample:** a live run's first report resets the filters and holds the pause (not counted as CI's
  `noiseUntil=pause` release). **Menu Resume** holds the closing pause first on a hinge run.
- **Feel:** `onCreakAccent` → `scene.showCreak()` (+ `HUSH-T event creak`); `preferredFPS(lidSpeed:animating:)` every
  play frame (animating = a held item, a moment, a callout), 60 when paused or off-play; `requiredResumeAngle =
  coverResumeAngle(relight:)` on a live relight, back to 95 on resume and at each run start.
- **VoiceOver:** `hud.banked`, `hud.candle`, `hud.noise` elements; announcements for Stirring/Waking (0.3 s late, after
  Feel's cue), bites, banks, candle low and the callouts (`HushCopy.announcement`, tested).
- **Game Center:** on activation, a stuck `systemSheetUp` with nothing presented is cleared. Dailies no longer post to
  Best Haul (QA P2-13).
- **App Review:** `BuildChannel.isTestBuild` (sandbox receipt) is gone. "Diagnostics" (input, screen, mask, ask,
  hand-off and relight angles, device orientation) shows in DEBUG or after a 2 s press on the About text.
- **Clipping/polish:** page scrolls end 72 pt below their last row; Codex names in a fixed 2-line box (aligned grid);
  locked badges are cream silhouettes on dimmed velvet; Settings' turn detail in plain words.
- **Home:** Codex and Badges always say their word; Settings and Game Center are labelled buttons; the phone floor opens
  with a "Best haul / rank" card (falls back to the old stack on short screens); captions keyed on the fold.
- **Demo presets:** the "9/24 vs 22/24" source is `ci/duo.sh` shooting the Codex with `progress=late` (NEEDS for CI).
  Test `onePresetAgreesAcrossHomeCodexAndResults` renders Home, Codex and Results lines from one `mid` store.
- **QA-2 App P2s also done:** P2-5 (cover-shaped screen keeps the stored hinge), P2-14 (an abandon with no gold doesn't
  count as a run), P2-9 is Core's (grace ends on a loud lid). CI R3 asks: `freezeOn=creak`, `freezeDelay=<s>`, relic
  1.65 s, lesson bank 0.5 s, lesson/dynamic-type/relight/mask/orient-ask lines.

## Risks / not done
- `ViewThatFits` on the phone Home and `onScrollGeometryChange` in `FadingScroll` are new layout paths: check frames
  01/02/19–21/38 and the Large Dynamic Type frames.
- The plate images are rendered per size (the Scene caches by size); a hint whose size animates would re-render, but
  none does (they scale-effect).
- `noiseIsUnchangedAcrossAPause` builds a second `GameController` in the test host (it takes over Feel's callbacks for
  the rest of the test run; harmless in tests).
- Not done: Duo Codex's empty lid half (selected relic on the lid), "Use the on-screen lever" setting, `golden=first`.

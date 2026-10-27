# App engineer, Round 2 hand-off (27 Oct)

Uncompiled (CI is the compiler). Nothing committed. Files touched: `Hush/App/` (GameController, AppRules, AppModels,
AppTrace, DemoMode, GameCenterManager, LessonScript, OrientationLock, **new** OpaquePNG), `Hush/UI/` (RootView, HomeView,
PlayHUD, PoseCards, ResultsView, Pages, Layout, HushTheme, AchievementArt), `Hush/Persistence/ProgressStore.swift`,
`HushTests/AppTests.swift`, `design/NEEDS.md`. Every promised hook from Core, Scene and Feel was present at the end and
is called by its exact name (NEEDS.md, App R2).

## The brief, item by item
1. **Duo P0-1 (book-pose lock-out).**
   - Brim's Release path is ported into `OrientationLock`: `requestPortrait()` (never upside down), `adoptMask(_:)` (the
     SwiftUI host answers with our mask) and `requestFailed(_:)` (reported; Settings › About in test builds).
   - Portrait is asked for when the card shows, when the hinge moves ≥ 15° into 90–165° under it
     (`AppRules.liftedFromBook`), at launch on a Duo, on every cover → inner handover mid-run, and by the card's
     **"I've stood it up"** button.
   - While a run is live on the inner display the mask is **portrait only** (`mask(isDuo:liveRun:inner:)`); Home and
     menus keep portrait + landscapes.
   - Every automatic ask is skipped under demo `orient=landscape`, so CI can still shoot the book card.
2. **Duo P0-2 (reopen bites).**
   - While paused (closing, pose/cover, menu, background) the session RESTS: `session.rest(dt:)` every frame the
     scene draws, and one catch-up (≤ 30 s, `AppRules.restChunks`) for time it didn't (cover display, background).
   - `ClosingPause` (pure, tested): Feel's gate or shut pauses; it resumes only when `hinge.canResume`. A run back from
     the cover or the book card enters the same pause (`hold()`), so it never resumes mid-lift.
   - Every resume calls `hinge.reset()` and `session.resumeGrace(seconds: 0.5)`, then logs
     `HUSH-T resumed angle <θ>`.
   - The card says "Lift the lid a little to carry on" below 95°, then "Hold still…".
   - The menu opens only on `.background` (P1-8), never while the hinge is under 20°. `.inactive` pauses quietly.
   - Paused telemetry is a still lid (`lidSpeed 0`, QA P1-1).
3. **Turned round.** The SpriteView is never rotated. `scene.turned` is set; only the SwiftUI layer rotates. Lesson
   pose window **90–112°**, with "Close it a little, nearly upright…" above it.
4. **Fill the screen.**
   - The scene is `ScreenLayout.make(hasFold:viewSize:)`, aspect-fill, the SpriteView full screen.
   - `CanvasFit` maps canvas → view through `contentOffsetY` (tested on a phone and on the Duo).
   - The pause button is a **brass coin** (`BrassCoinButton`), clamped ≥ 16 pt inside the safe area
     (`AppCanvas.pauseCenter`, tested on three screens).
5. **One art style.**
   - Home, the cover card and Results show `MimicPortraitScene` (`PortraitScenes`). Home's openness and wake follow
     the hinge or a drag; its tier rises with rank. The cover is asleep. Results is smug if bitten, a sleepy peek if
     hushed, gold if a golden mimic was banked.
   - The flat chests are gone (TitleChest, SleepingMimic, PeekingEye).
   - The Codex draws `ChestArt.relicArt` with the scene's painting order (`LootPainter`) on velvet tiles. Unfound
     relics are a blurred silhouette plus "?".
   - The badges are a velvet medallion with a tier rim and a different ChestArt relic for each of the 12.
6. **Clarity.**
   - **Lesson:** step 2 says "Open the lid… slowly. Watch the noise." and a ring pulses round the meter. The card sits
     at canvas y 148–264, 12 pt above the meter and below the loot, and is hit-transparent except Skip. The final card
     has the 3 stake rows and "Got it".
   - **Phone:** the lever is always drawn (`usesSlider` is true for pilot and `lid=` runs too). Step 1 points at it:
     "Slide this up… slowly".
   - **Book card:** Brim's two pages; the whole lift half glows; the copy is "Turn it round. Lift the glowing half."
     over an animated turn-then-lift diagram. Narrow windows get one stacked column, and a phone never shows it.
   - **Results:**
     - the `chestLog` strip (tier chest, value, zzz, teeth, golden glow);
     - "Hushed: banked while it slept";
     - "312 short of your best" or "New best!";
     - up to 2 named achievements with badges, "+1 more", tapping through to the Badges page;
     - one scrolling column off the Duo (no dead gap, nothing clipped).
   - **Home:** "Codex 9/24" and "Badges 3/12" via `ViewThatFits` (never truncated); Settings and Game Center are icon
     tiles; the rank bar always shows a track, a 4 % sliver and "Next: Sneak"; the best line reads "No haul yet" when
     there is none.
   - **Demo `progress=`** (`DemoPresets.make`): best, lifetime, relics and achievements come from one history, and
     the achievements use Core's own rules. `mid` best 5,200 (casual Results shows a near miss); `late` 9,800 (expert
     beats it).
   - **Daily:** the run banner, the HUD pill, the Daily page and Results all say "Daily Dungeon · 27 Oct".
   - **Settings:** "Turn the chest round" with the brief's detail line, and "Play sound on silent". On the Duo the
     title sits on the lid half and the toggles on the floor half (`PageScaffold`). About and Credits are list rows.
   - **Hints:** `.candleLow` reads "Candle's low. Bank it!" (amber, always shown); `.relicDeeper` reads "Something
     glints deeper…" and drives `glimmer(on:)`. Both sit in `ChestLayout.hintBand` (y 404–452). The hint clears the
     instant a bite starts.
7. **Gold adds up.** Every demo frame checks the counter against the sum of `banked` events (`HUSH-T gold mismatch` if
   ever not), skipTo included. Bank freezes wait 1.25 s for the roll. Demo Results show the final haul at once. Test:
   a 90 s casual run's banks sum to its total.
8. **`screen=badges`** renders the PNGs and shows the new Badges page (route `.badges`, also on Home).
9. **FPS.** The SpriteView follows `FeedbackDirector.shared.preferredFPS` via `onPreferredFPSChange`; the portraits
   run at ≤ 60.
10. **Dynamic Type.** Menu, Results, Codex and Settings type scales through `UIFontMetrics`, capped at 1.3×. Those
    screens wrap and scroll; the page scroll fades above Done instead of being cut by it; the Codex subtitle has gutters
    and wraps.

**QA-1 (App):**
- **P1-1** done.
- **P1-2** is the resume rule above.
- **P1-3:** Home, Restart and a new run file `partialResult()`, so relics, gold, achievements, the Daily score and
  Game Center are kept. The background saves a checkpoint (`ProgressData.pendingRun`, v2) and the next launch files it
  if the app was killed.
- **P2:**
  - Lesson: the first coin moved to depth 0.20, and an early bank goes round once.
  - Daily: no partial ever raises `bestDaily`, and Again is always practice of that dungeon.
  - Idle timer: the screen may sleep while paused.
  - Game Center: the app is drawn un-turned while a sheet is up, and Duo banners are off.
  - Phone overflow: lesson and hint type scale with the canvas.
  - Allocations: Home's caption has its own ObservableObject, lesson strings are built at ≤ 15 Hz, and the loot counts
    no longer allocate.
  - Corrupt save: backed up to `hush.progress.bak`, never overwritten.
  - Copy: "candle" everywhere (tested), "Practice never reaches the leaderboard", and a Daily warning on the closing
    card.

**CI asks (NEEDS):** `noiseUntil=pause`, `resumed angle`, `golden=1` (by seed search, no Core hook), `hud.bag` and
`debug.loot`, the scene paused on event freezes, and RGB icon and badge PNGs (`OpaquePNG`, colour type 2, tested by
decoding).

**Feel asks:** `goldenArrived()` on a golden chest's arrival; `preferredFPS` from the instance.

**Duo P1-7:** held camera-up while turned, with the hinge open, for 0.7 s, shows an un-turned "Other way round: lift the
glowing half ↻" on both halves.

## Risks / not done
- **`GKAccessPoint.trigger(handler:)`.** If the handler fires on presentation, not dismissal, the dashboard shows
  upside down for a turned Duo player (the R1 state, no worse).
- **`ViewThatFits` inside the button label** is the Codex/Badges truncation fix. Check frame 01/02 on CI.
- **The lever marker** uses `ChestLayout.sliderX/MinY/MaxY`. If the Scene stretched the lever into the extension, the
  ring may sit a little low.
- **The pose-step lid glow** covers the lid half of the canvas only (not the extension above it on phones; phones show
  the lever marker instead).
- **Not done:** a "Use on-screen lever" option on a Duo (UX P2); VoiceOver lid control; the stage-change announcements.

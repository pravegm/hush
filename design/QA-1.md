# QA-1: Round 1 code review (senior QA, 27 Oct)

**Scope.** I read the whole of `Hush/`: Core, Input, Feedback, Scene, App, UI, Persistence and Shared. I also read the
design docs, the R1 hand-offs and the Duo CI artifacts (`artifacts/duo1/.../logs/*.txt`, `checks.tsv`). I traced every
finding through the code end to end. "Unverified" means I couldn't prove it from the code or the logs alone (for
example, it needs a real Duo).

No source files were edited.

**Headline.**
- No crash path found. I checked force unwraps, indexing, `Int(NaN)`, division by zero, audio render-thread
  allocation and SpriteKit NaN.
- One release blocker: the placeholder app icon.
- Three player-visible P1 bugs. Two of them can be seen in CI's own CLOSE-PAUSE log.

---

## P0: blockers

### P0-1. A placeholder app icon is committed and would ship
- **Where:** `Hush/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`.
- **What goes wrong:** the file is a flat gold rectangle on teal (I opened it). CI renders the real icon
  (`IconExport`) only into an artifact, and "CI never commits" (ci-R1.md). An archive made today ships the rectangle.
  That's a Guideline 2.3 / 4.0 rejection, or at best a broken store page.
- **Fix:** commit `ci-screens/app-icon-1024.png` from the latest ci.yml run over this file before any TestFlight or App
  Store archive. Add a size or hash check to `testflight.yml` that fails if the placeholder is still there.

---

## P1: player-visible bugs

### P1-1. The creak sound and haptic keep running at a frozen speed through a pause (worst in the closing pause)
- **Where:**
  - `App/GameController.swift:153-155`: while paused, it sends `AppRules.telemetry(session.snapshot, …, playing: false)`.
  - `Core/HeistSession.swift:141`: `snapshot.lidSpeed` is the last *stepped* `lid.speed`, so it freezes while paused.
  - `Feedback/FeedbackDirector.swift:152-171`: `heistBed` plays the creak at `restingCreakShare` 0.8
    (`FeelSoundBook.swift:120,159`), and `haptics.update(lidSpeed:)` keeps the haptic creak player going.
- **Why it happens:** the closing pause starts *while the lid is moving* (θ < 85° held for 0.4 s). CI's
  `logs/close-pause.txt:107-109` shows the speed was 28.7 °/s when it paused.
- **Scenario:**
  - The player lowers the lid and the "Lift the lid a little" card appears.
  - A loud groan plus a continuous haptic buzz (≈ 0.6 level × Strong) play for as long as the lid stays at 10–88°.
  - That was 9 s in the CI run. The hinge is perfectly still.
  - It also keeps both engines awake, because `lastActive` is refreshed every frame while the creak is "creaking".
  - The same happens to the pause menu if it opens while the lid is moving.
  - The `silence()` from `setPause` is overwritten on the very next frame.
- **Fix:** in the paused branch, send `lidSpeed: 0`. Or send the live hinge speed (`input == .hinge ? hinge.lid(at:
  now).speed : 0`), so a real hinge move during the pause still creaks truthfully.

### P1-2. Resuming after the closing or pose pause happens mid-motion, and the lift itself makes noise
- **Where:**
  - `App/GameController.swift:410-413`: it resumes the moment the angle is ≥ 88°, with no "lid is still" condition.
  - `Input/HingeLidSource.swift:92`: `reset()` is never called anywhere. Feel's hand-off asks for it on activation.
- **Evidence:** CI `logs/close-pause.txt:118-147`.
  - It resumed at 86.9–88° while the lid was rising at 24–29 °/s.
  - Noise went from 0.33 to 0.65 in about 1.5 s, and the mimic went to Stirring.
- **Scenario:**
  - The game tells the player "Lift the lid a little to carry on", and the play starts again halfway through that lift.
  - In a real run, with a Light Sleeper (×1.35) or noise already high, the player can be woken or bitten for obeying
    the card.
  - A bite with an empty bag still costs 15 s of torch.
  - Reopening from fully shut is worse:
    - the cover display stays lit to about 150°, so `pose` returns to `.play` while the hand is still opening the phone;
    - a fast close (85° to 10° in under 0.4 s) can reach the cover before `checkClosing` latches, so no closing pause
      covers the reopen at all.
  - Book pose to tabletop (the `.pose` pause) has the same problem.
- **Fix:**
  1. Lift `.closing` and `.pose` only when θ ≥ 88 **and** `hinge.speed < Tuning.quietSpeed` has held for about 0.3 s.
     The card can say "…and hold still".
  2. Call `hinge.reset()` when they lift.
  - A cheaper alternative is a 0.5 s window after a resume in which lid speed adds no noise.

### P1-3. Quitting a run throws away its banked relics, gold and achievements, even though the relic banner already said "found"
- **Where:**
  - `App/GameController.swift:507-521` (`goHome`), `493-503` (`restart`) and `662-669` (`abandonLiveRun` only files
    Daily gold);
  - `Persistence/ProgressStore.swift:250-254`: relics, lifetime gold and achievements are written only by
    `ProgressRules.record`, which runs only when `session.result` exists (`handleFinished`).
- **Scenario:**
  - The player banks a relic. The relic banner and choir play.
  - They then press Pause → Home, Pause → Restart, or the closing card's Home (`UI/PlayHUD.swift:201`), or the app is
    killed in the background.
  - The relic is not in the Codex, which says relics are "found once and stay".
  - The thief-rank gold is gone, and an achievement earned in that run (for example First Haul or Relic Hunter) is never
    awarded.
- **Fix (minimal):** add `store.noteRelics(_:)` and call it on each `.relicFound` event, so the Codex is written at once.
  Better: on abandon, build a `RunResult` from the session's counters and `record()` it. That needs a
  `HeistSession.partialResult`, which is Core-owned, so log it in NEEDS.md.

---

## P2: polish and smaller bugs

### Game logic
1. **The lesson skips its Freeze and Bank steps on gentle openers.**
   - **Where:** `App/LessonScript.swift:11-12` (coin depth 0.02, grabbable at openness 0.08) and `133-137` (a bank in
     the grab/freeze/bank steps jumps to `.done`).
   - **Why:** the shut zone is openness ≤ 0.15 on the slider and θ ≤ 110° (openness 0.154) on the hinge. So a player who
     stops at "Look: gold!" and bags the coin banks 0.35 s later, and goes straight to "Banked! Gently does it."
   - **Result:** the scripted stir and Freeze are never taught. That's likely on the slider, and possible on a Duo given
     ±5° accuracy.
   - **Fix:** put the first coin at depth ≥ 0.12, or suspend banking (`shutHold`) until the lesson reaches `.bank`.
2. **Backgrounding mid scored-Daily breaks "New best!".**
   - **Where:** `GameController.swift:330-332` calls `recordPartialDaily`, which raises `bestDaily` to the run's own
     partial gold (`ProgressStore.swift:163`). `record()` then compares against it (`:214-219`).
   - **Scenario:** a call, Control Center or a notification pull during a scored Daily.
     - If nothing more is banked, a real new best shows no pill.
     - If more is banked, "New best!" shows against the run's own partial, even on a first-ever Daily.
   - **Fix:** keep partials out of `bestDaily` (keep them in `daily[day].gold` only), or compare against the best from
     before the run starts.
3. **"Practise this dungeon" after 00:00 UTC starts a *scored* try.**
   - **Where:** `GameController.swift:475` (`scored: day != today`) and `:711`.
   - **Scenario:** a Daily finishes just before 00:00 UTC, and Results shows after it. Tapping "Practise this dungeon"
     uses up the new day's one scored try. The banner says so, but the button didn't.
   - **Fix:** always practise from Results (`scored: false`), or relabel the button when the day has turned.
4. **The screen never sleeps while paused.**
   - **Where:** `isIdleTimerDisabled = true` at `GameController.swift:632` is cleared only on finish or Home (`:516`,
     `:675`).
   - **Scenario:** a Duo left half-closed shows the closing card lit indefinitely, and the same goes for the pause menu
     after a background return.
   - **Fix:** re-enable the idle timer while `isPaused`, and disable it again on resume.
5. **A scored Daily killed in the background never reaches the Game Center Daily board.**
   - **Where:** `GameController.swift:330-332` files the score locally only. The GC partial is sent only from
     `abandonLiveRun` (`:668`).
   - **Fix:** also call `reportDailyPartial` there.

### Lifecycle and the turned canvas
6. **Game Center UI is upside down for a turned player.**
   - **Where:** `AppRules.turnsRound` (`AppRules.swift:83-85`) turns Home round too.
   - **Result:** the dashboard and sign-in sheet (`GameCenterManager.swift:60,65`) and the achievement banners
     (`showsCompletionBanner = true`, `:212`) are presented by UIKit in iOS's own orientation, which is 180° from what
     the player sees.
   - **Fix:** un-turn while a GC controller is presented, or drop the banners. Unverified on hardware.
7. **Unverified: touch mapping through `.rotationEffect(180°)`.**
   - **Where:** `RootView.swift:39`, `ChestScene.swift:379`.
   - **What I can say:** UIKit's `location(in:)` should honour the layer transform, but no CI step injects a touch. The
     Duo pass is hinge-only, so a turned drag has never been exercised.
   - **Fix:** add a DEBUG-only `touch=` demo key that logs `HUSH-T touch canvas x,y floor x,y`, and check one real drag
     on the first device build.
8. **Pause/resume: `hinge.reset()` is never called.** I found no speed spike from this (the estimator is gap-aware), so
   it's a contract gap only. It's folded into the P1-2 fix.

### Layout (iPhones without a fold; canvas scale ≈ 0.587 on a 393 × 852 screen)
9. **The lesson's last card is wider than small iPhones.** `LessonFinalCard` is fixed at `width: 380` plus 2 × 22
   padding, which is 424 pt (`PlayHUD.swift:359-360`). It's clipped on 393/375-pt screens, and the buttons touch the edge
   on an SE.
   - **Fix:** use `min(info.size.width - 32, 380)`.
10. **The lesson card overflows its band on phones.**
    - **Where:** `PlayHUD.swift:252-254` frames the card to `lessonBand` (`Layout.swift:57-59`), which is only about
      334 × 68 pt on a phone. The content (dots, two lines of 23 pt, padding) is about 100 pt.
    - **Result:** it spills over the meter and close to the lesson coin. The card's background takes hits, so it can
      block a touch on the coin's lower edge.
    - **Fix:** allow two lines at a smaller size when `fit.scale < 0.8`.
11. **The hint capsule is taller than the hint band on phones.** A 26 pt font plus 16 of padding is about 47 pt, against
    a band of about 35 pt (`PlayHUD.swift:38-43`). It overlaps the noise meter by a few points.
    - **Fix:** scale the hint font by `fit.scale`.

### Performance (per frame at 120 Hz)
12. **`SceneLootView.update` allocates a lot every frame** (`Scene/SceneLoot.swift`):
    - a `Set`, a `filter` + `sorted` array and a `[Int: Int]` (`:174-183`);
    - and it rebuilds an interpolated `String` key for **every item, every frame** inside `configure` (`:64`, called
      from `:197`).
    - **Fix:** skip `configure` when `slot.id == st.id` and the kind hasn't changed, and reuse scratch buffers.
13. **Two `NumberFormatter` calls per frame.** `SceneFloorHUD.swift:275,307` call
    `SceneNumber.gold` (`SceneTextures.swift:469`) before `set()`'s equality check.
    - **Fix:** compare the `Int` first.
14. **Smaller per-frame allocations:**
    - `HeistSession.swift:216` makes `Array(touches.keys)` per sub-step while dragging;
    - `GameController.swift:178,586-589` builds the lesson display strings every frame;
    - `GameController.swift:447-448` publishes `homeLid` at 30 Hz on the controller, which re-evaluates all of
      `RootView` (SpriteView included) at 30 Hz on Home. Move it to its own `ObservableObject`, as `HUDState` already
      is.

### Persistence
15. **A save that can't be decoded silently becomes a fresh profile and is overwritten.**
    - **Where:** `ProgressStore.swift:276-280` decodes, and the first `commit` overwrites (`:325-328`).
    - **Result:** one bad write, or a future top-level format, wipes all progress for good.
    - **Fix:** copy the raw bytes to `hush.progress.corrupt` before falling back.

### Accessibility
16. **VoiceOver labels on Home and Results:**
    - Home's rank row says "Best haul 0 gold" when there's no best (`HomeView.swift:181`);
    - the Codex button reads "9 slash 24" (`:113`);
    - the Results gold is a count-up `Text`, so VoiceOver can read a mid-count number (`ResultsView.swift:27`). Give it
      `accessibilityLabel("\(gold) gold banked")`;
    - the rank progress bars have no label or value.
17. **Dynamic Type isn't supported at all:** every font is a fixed `.system(size:)` in `HushTheme.swift:76-87`. There's
    no clipping, and it matches the "Larger Text: No" decision. Reduce Motion is honoured (both the system setting and
    the in-app one) in the scene and the UI: verified.

### Copy
18. **"FREEZE" in the store copy doesn't match the app.** The store copy and review notes say "FREEZE appears"
    (`metadata.md:71`, `review-notes.md:24`, DECISIONS #7). The app only ever shows "Freeze!"
    (`UI/PlayHUD.swift:11`), and the scene has no FREEZE text. Make the two agree.
19. **"Practice never counts. Sneak about freely."** (`Pages.swift:173`) isn't quite true. Practice gold adds to lifetime
    gold and thief rank, counts as a run and can earn achievements (`ProgressStore.swift:235-259`). Either say "never
    counts for the leaderboard", or exclude practice from these.
20. **The closing card's Home on a scored Daily gives no warning** (`PlayHUD.swift:201`). The pause menu shows "Leaving
    keeps the gold you've banked." The closing card gives no warning at all.

---

## Checked and found OK
- **Audio render thread:**
  - The SPSC ring uses `Atomic` indices.
  - Commands are POD enums, so nothing touches ARC on the audio thread.
  - Voices and the modal bank are preallocated.
  - There's no locking, and NaN is reset.
  - Every `Int(…)` in `FeelSynth.start` comes from constant specs.
  - `cascadeCount` guards `log2(0)`.
- **Crash surface:** I found no force unwraps or unchecked indexing. Divisions are guarded (`max(…, ε)`), CGFloat inputs
  go through `isFinite`, and `updateCanvas` guards the size.
- **Stuck states:**
  - Touch ends are always forwarded (`ChestScene.finish`, `GameController.floorTouchEnded`), so nothing stays "held".
  - Bank and bite clear touches.
  - The closing gate re-judges from reports while frames are paused, so a closing pause always resumes.
  - Results always follows `handleFinished`.
  - Every lesson step can be passed on the slider and on the hinge.
- **Release vs Debug:**
  - `DemoMode.current`, `AppTrace` and `FeelDemoLog` are compiled out or false in Release.
  - Nothing DEBUG-only is referenced from Release code.
  - **Unverified:** the Release-only `BuildChannel` `#else` branch and the Game Center auth path never run in CI, which
    only does Debug tests and demo runs with GC disabled. Run `testflight.yml` with `check_only` before the first upload.
- **Safe areas and system gestures:** the insets are swapped with the turn. Both ends defer system gestures while turned
  and live. The status bar and home indicator are hidden.

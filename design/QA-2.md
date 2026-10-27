# QA-2: Round 2 code review (senior QA, 27 Oct)

**Scope.** I read `design/QA-1.md`, `ROUND-2.md`, every `design/notes/*-R2.md` and `Hush/Shared/Contracts.swift`, and
reviewed the R2 diff (`git diff 6bcb5b8 HEAD -- Hush`, 43 files). I read these files end to end: `GameController`,
`AppRules`, `OrientationLock`, `HingeLidSource`, `FeelFilters`, `LessonScript`, `ProgressStore`, `GameCenterManager`,
`RootView`, `PlayHUD`, `PoseCards`, `Layout`, `AppModels`, and the HeistSession / FeedbackDirector / SceneLoot /
ChestScene / MimicPortraitScene diffs. I also checked the latest Duo CI artifact (`artifacts/duo3/.../logs/frames.txt`,
`checks.tsv`), the icon PNG bytes and `docs/appstore/*`.

No source files were edited. "Unverified" means I couldn't settle it from the code and the logs, usually because it needs
a real Duo.

**Headline.**
- No crash path found. I re-checked force unwraps, `Int(NaN)`, the new `MainActor.assumeIsolated` sites (both run on the
  main queue), the swizzled mask getter, `restChunks`, and the candle tick slots.
- No P0.
- **Two P1s:**
  - P1-1: the new cover-sized-canvas fallback also fires on the **real** cover display, and CI's own log shows it.
  - P1-2: the App Store and Game Center copy still describes R1, and players will see it.
- QA-1: 22 items fixed, 3 partly fixed, 1 not fixed (table below).

---

## QA-1 verification

| QA-1 item | Status | Evidence (file:line) |
|---|---|---|
| P0-1 placeholder icon | **Fixed** (residual P2-1) | `AppIcon-1024.png`: 773,239 B, sha256 `93025edc…` (not the placeholder's `a29bfd3d…`), 1024², rendered art. `ci/icon-check.sh` is fatal in `testflight.yml:39-44,110-114`. The file is still RGBA (see P2-1). |
| P1-1 creak/haptic frozen through a pause | **Fixed** | `GameController.swift:224` sends paused telemetry; `AppRules.swift:69-73` sets lidSpeed and dragSpeed to 0 when paused; `FeedbackDirector.swift:602` `FeelFrozenSpeedGuard` is a second guard. |
| P1-2 resume mid-motion; `reset()` never called | **Partly** | The closing, book-pose and cover → inner paths are fixed: `ClosingPause` (`AppRules.swift:333-372`), `canResume` (`HingeLidSource.swift:84-94`), `hold()` on returning to play (`GameController.swift:492-496`), and `reset()` + `resumeGrace` on every resume (`:1050-1051`). CI's REOPEN-NO-BITE run (40510297922) passes. **The new small-canvas fallback reopens the hole: see P1-1.** |
| P1-3 abandon loses relics, gold and achievements | **Fixed** | `abandonLiveRun` (`GameController.swift:912-924`) uses `partialResult()` (`HeistSession.swift:167`). `recordAbandoned` (`ProgressStore.swift:166-177,347-353`). Background checkpoint (`GameController.swift:464-473`, `ProgressStore.swift:356-374`), recovered at launch (`GameController.swift:398-400`). |
| P2-1 lesson skips Freeze/Bank | **Fixed** | The coin is at depth 0.20 (`LessonScript.swift:13`). An early bank goes round once (`:140-155`). |
| P2-2 background breaks "New best!" | **Fixed** | `recordPartialDaily` is gone; the checkpoint never touches `bestDaily`. The best is compared before the run (`ProgressStore.swift:223-236`). |
| P2-3 "Practise" after 00:00 UTC is scored | **Fixed** | `AppRules.againMode` (`AppRules.swift:219-226`), `GameController.swift:702-704`. |
| P2-4 screen never sleeps while paused | **Fixed** | `refreshIdleTimer` (`GameController.swift:1067-1070`) runs on every pause change (`:1055`). |
| P2-5 killed Daily never reaches GC | **Fixed** | Recovered at launch → `GameCenterManager.report` (queued, flushed after auth). |
| P2-6 GC UI upside down when turned | **Partly** (unverified) | Un-turned while `systemSheetUp` (`AppRules.swift:141-143`); Duo banners off (`GameController.swift:155,557`). Clearing the flag relies on `GKAccessPoint.trigger(handler:)` firing on dismissal (`GameCenterManager.swift:64-66`): see P2-7. |
| P2-7 turned touch mapping | **Fixed** | Touches are read in `world` (`ChestScene.swift:509-523`). The XCUITest real-finger drag passed. |
| P2-8 `hinge.reset()` never called | **Fixed** | `GameController.swift:453,876,1050`. |
| P2-9 lesson final card too wide | **Fixed** | `PlayHUD.swift:335` (`min(width − 32, 380)`), `:482`. |
| P2-10 lesson card overflows on phones | **Fixed** | Band at canvas y 146–262 (`Layout.swift:88-91`); type × `textScale` ≥ 0.72 (`Layout.swift:57`, `PlayHUD.swift:394-418`). |
| P2-11 hint capsule taller than its band | **Fixed** (marginal) | `HushType.hint(scale:)` (`HushTheme.swift:107`). On a 393-pt phone it is about 30 pt against a 28-pt band, which is fine. |
| P2-12 SceneLoot per-frame allocations | **Fixed** | Scratch buffers and an insertion sort; a slot is configured only when its item changes (`SceneLoot.swift:206-387`). |
| P2-13 NumberFormatter per frame | **Fixed** | Formatting happens only on change (`SceneFloorHUD.swift:452-454,510-512`). |
| P2-14 small per-frame allocations, `homeLid` at 30 Hz | **Fixed** | Touches are an array (`HeistSession`); lesson strings at ≤ 15 Hz (`GameController.swift:823-828`); `HomeLidState` (`AppModels.swift:43-50`). |
| P2-15 corrupt save overwritten | **Fixed** | `ProgressStore.swift:293-317` (`.bak`, never overwritten). |
| P2-16 VoiceOver labels | **Fixed** | `HomeView.swift:172,178,285-287`; `ResultsView.swift:80-81`; `ChestStrip.spoken`. |
| P2-17 Dynamic Type | **Partly** (by design) | The pages scale through `UIFontMetrics`, capped at 1.3× (`HushTheme.swift:78-118`). The in-run text stays fixed. |
| P2-18 "FREEZE" in the store copy vs "Freeze!" in the app | **Not fixed** | `docs/appstore/asc-metadata.json:20,30`, `review-notes.md:24,70`, `screenshots.md:68`. Folded into P1-2. |
| P2-19 "Practice never counts" | **Fixed** | `Pages.swift:276`. |
| P2-20 closing card's Home gives no Daily warning | **Fixed** | `PlayHUD.swift:266-272`. |
| "Checked OK" items (touch ends, results, demo code out of Release) | **Still OK** | DemoMode parsing is `#if DEBUG` (`DemoMode.swift:143-206`). The Release literal guard still holds (`GameController.swift:626-632`). |

---

## P1: player-visible bugs

### P1-1. The "cover-sized canvas = compatibility column" fallback also fires on the real cover display. A reopen can then resume, unseen, mid-motion.

**Where:**
- `GameController.swift:565-570`: `smallCanvasOpenSince` is set at the **first** hinge sample ≥ 60° and kept for as long
  as the hinge stays ≥ 60°. That is the whole run.
- `:588-607`: `watchSmallCanvas` polls every 0.5 s.
- `AppRules.swift:80-103`: `pose(…smallCanvasOpen:)` and `smallCanvasIsOpen`.
- `GameController.swift:492-496`: the resume gate (`hold()`) only fires on a pose **change** into `.play`.

**Why it misfires.** The "held ≥ 60° for 2.5 s" clock is not measured from when the cover-sized canvas appeared. iOS
moves the app to the cover display while the hinge is still ≥ 60°, which is what the sim does. The fallback then
triggers at the first poll, 0.5 s later, and the game is "played" on the cover display.

**Proof:** CI Duo run, `artifacts/duo3/.../logs/frames.txt:782-789`:
- `pose cover reason=cover-sized 466x678 angle=74.2`;
- then `pose cover-open angle=70.7: a small canvas with the hinge open`;
- then `pose play reason=small-canvas-open 466x678`.

The cover card was replaced by the game for about 9 s, until the hinge dropped under 60° (`:795`).

**Scenario on a Duo, mid-run.** It depends on the handover angle, which the sim puts at about 118–150° on the way up:
1. The player shuts the Duo and then reopens it slowly, as the cover card tells them ("Open me gently, then hold still").
2. 60° to the relight angle takes ≥ 2.5 s, so the cover-sized canvas flips to `.play` and `hold()`s.
3. The player pauses at ≥ 95° for 0.3 s while the inner display is still dark, or lit but not yet handed over.
4. The run **resumes on the cover display**, which faces away from the player. The candle burns and hinge noise
   counts.
5. When the inner display takes over, the canvas changes size but the pose stays `.play`. So there is no `hold()`, no
   `reset()` and no grace.
6. A hand still opening at 30–90°/s is fully noisy. This is R1's P0-2 again, by another route.

Even when it is harmless (closing past 74°), the SpriteView renders the chest at 120 Hz on the cover display instead of
showing the cover card. Unverified on hardware: it depends on the real handover angle.

**Minimal fix:**
1. Start the clock when the cover pose begins: set `smallCanvasOpenSince = now` in `setPose(.cover)`, or use
   `max(openSince, coverSince)`.
2. Arm the fallback only when the canvas before the small one was a **landscape inner** canvas (the book-pose →
   column case of run 40506125012). Simpler: drop it, since the `interfacePortrait` mask fix removes the column's
   cause.
3. Belt and braces: in `updateCanvas`, a cover-sized → inner-sized change during a live hinge run calls
   `closingPause.hold(); setClosing(true)`, the same as a pose change. Any future display handover then waits for an
   open, still lid.

### P1-2. The App Store, Game Center and review copy still describe R1. Game Center will show players the wrong rules.

**Where:** `docs/appstore/asc-metadata.json`, `review-notes.md`, `metadata.md`, `support.html`, `index.html`,
`press-kit.md`, `screenshots.md`. This is outside `Hush/`, but it ships with the binary.

| Copy | Says | The app (R2) |
|---|---|---|
| Achievement `hush.ach.royal` (`asc-metadata.json:175-188`) | "Royal Treatment: Reach a Royal chest" | "Midas Touch: Bank a golden mimic" (`Ranks.swift:59`) |
| `hushhush` (`:256-267`) | "Hush Hush: Bank 3 chests … without the mimic stirring" | "Hush Chain": a chain of 5 (`Ranks.swift:64`, `bestChain ≥ 5`) |
| Heavy Bag | 2,000 gold | 3,000 |
| Dragon's Hoard | 5,000 gold | 8,000 |
| A Small Fortune | 25,000 gold | 50,000 |
| Light Fingers' earned text (`:164,169`) | "Five chests, one torch." | the app says "candle" |
| Description (`:20,30`) and review notes (`review-notes.md:24`) | "a bite costs … 15 seconds of torch", "FREEZE appears" | the bite costs 10 s (`Tuning`); the app shows "Freeze!" |
| Review notes (`review-notes.md:33`) | "Below about 85 degrees play pauses" | it pauses below **70°**, and resumes only at ≥ 95° held still |

**Scenario:**
- A Game Center player sees "Royal Treatment" unlock when they bank a golden chest.
- "Bank 2,000 gold in one run" doesn't unlock at 2,500.
- A reviewer tests the closing pause at 85° and sees nothing happen.
- That's a 2.3.1 accuracy risk and a visible inconsistency.

**Fix:**
- Regenerate the achievement localizations from `Achievements.all`. Note that the ids stay the same.
- Replace "torch" with "candle", 15 s with 10 s, FREEZE with "Freeze!", and 85° with 70° (resume ≥ 95°, held still).
- Mention the golden mimic and the Hush Chain.
- Add a test or CI grep that fails while `docs/appstore` contains "torch" or "15 seconds".
- The badge art `hush.ach.royal.png` must show Midas Touch, not a Royal chest. Check `BadgeExport`.

---

## P2: polish and smaller bugs

1. **The committed icon still has an alpha channel.**
   - **Where:** `AppIcon-1024.png` IHDR byte 25 = **6 (RGBA)**, depth 8. I decoded it: every alpha value is 255, so it
     is fully opaque.
   - **Risk:** `testflight.yml` flattens it in the workspace (`FIX_ALPHA=1`), so CI uploads are safe. Any other archive
     (Xcode Organizer, Xcode Cloud, a future workflow) ships an alpha channel, which is ITMS-90717.
   - **Fix:** commit the flattened RGB PNG (colour type 2). Then make `ci/icon-check.sh`'s alpha check fatal without
     `FIX_ALPHA`.
2. **A closing pause freezes the end-of-chest and end-of-run moments.**
   - **Where:** `ClosingPause` runs in every phase (`GameController.swift:212-213,611-638`). `rest()` is a no-op outside
     `.ready`/`.looting` (`HeistSession.swift:204-206`).
   - **Scenario:** the candle goes out, the player shuts the lid (a natural reaction), and the torch-out moment freezes
     under "Lift the lid a little to carry on". Results never arrive until they lift to ≥ 95° and hold still. The same
     happens to "BANKED +n" or the CHOMP if the lid drops under 70° during the 1.4–2 s moment.
   - **Fix:** don't pause, or auto-resume, while `!AppRules.isLive(snapshot.phase)`, at least in `.torchOut`.
3. **The hint freezes on screen through a pause.**
   - **Where:** `publishHUD` asks for `nil` while paused (`GameController.swift:997`), but `HintGate.update` is clocked
     by session time (`:1003`), which stops while paused. The new candidate never becomes "stable" (`AppRules.swift:312`).
   - **Result:** whatever was up stays drawn under the dimmed closing card or menu: "Freeze!", "Slower…", "Something
     glints deeper…". It also keeps `setGlimmer(true)`. The director stays silent only because telemetry isn't playing.
   - **Fix:** call `hintGate.clear()` when a pause begins (in `setPause`), the same as `silencesHints` does.
4. **The book-pose card has no way out.**
   - **Where:** `PoseCards.swift:194-197`: only "I've stood it up". There is no Home button, and REVIEW-1-duo P0-1 asked
     to keep "Play with touch".
   - **Scenario:** if `requestGeometryUpdate(.portrait)` is refused or ignored (the reason is only recorded,
     `OrientationLock.swift:126-129`), the player can't leave the card at all.
   - **Fix:** add a quiet "Home" or "Play with the lever" fallback after one failed request. Unverified: the request is
     probably honoured on hardware.
5. **Launching on the cover display erases the stored hinge flag.**
   - **Where:** `GameController.swift:150-153` judges `trustsStoredHinge` with `looksLikeDuo(UIScreen.main.bounds)`.
     The cover (466 × 678) fails the "short side ≥ 600" test, so `hush.hasHinge` is deleted.
   - **Result:** it self-heals on the first hinge sample, but until then the app treats the device as a phone: the Home
     caption says "Slide", the lever shows, and banners are on.
   - **Fix:** also trust a cover-shaped screen (ratio ≈ 0.69, short side ≥ 440).
6. **Glimmer geometry differs between Scene and Core.**
   - **Where:** the Scene glimmers from `depth − 0.25` and fades through light 0.15–0.45 (`SceneLoot.swift:198-204`).
     Core's hint and sound use `depth + 0.04 − 0.25 … < depth + 0.04` (`HeistSession.swift:699-703`).
   - **Result:** the twinkle starts about 0.04 openness (≈ 2.6°) before the sound and hint, and can run on past them.
   - **Fix:** use `HeistSession.relicGlimmers` in the Scene, as core-R2 asks.
7. **Unverified: Game Center dismissal.** `systemSheetUp` is cleared only by `GKAccessPoint.trigger(handler:)`
   (`GameCenterManager.swift:64-66`).
   - If the handler fires on presentation, the dashboard is upside down for a turned player.
   - If it never fires, the app stays **un-turned for the whole session**, so the blur lands on the floor.
   - **Fix:** also clear the flag on `scenePhase == .active` or on a timeout, and log it in the test build.
8. **The golden plate understates the payout.**
   - **Where:** `SceneLid.swift:33` always says "GOLDEN · gold ×2", but `ChestSpec.multiplier` is tier × 2. An iron
     golden chest pays ×3 and a gilded one ×4. The plate also hides the tier.
   - **Fix:** "GOLDEN · gold ×\(multiplier)", or "gold ×2 more".
9. **Resume grace and rest are a small exploit, and a balance note.**
   - **The exploit:** every resume grants 0.5 s of silent lid (`GameController.swift:1051`). A deliberate dip under 70°
     then becomes a free, candle-free noise decay (`rest`), followed by a silent burst of lid motion.
   - **What limits it:** the speedometer's residual after a fling (τ 0.15 s) still counts once the grace ends.
   - **Fix:** end the grace early once `lid.speed` has been over `Tuning.loudSpeed` for more than about 0.15 s, or
     forgive only speeds under about 40°/s. Watch it in the founder's device test.
10. **The pause menu's Resume bypasses `canResume`.**
    - **Where:** `GameController.swift:712-716`.
    - **Why it matters little:** under 70° the closing gate re-pauses at once, and under 97° the lid is silent (the
      speed clamp). So the risk is only a hand still moving the lid above 97° when Resume is tapped, which the 0.5 s
      grace mostly covers.
    - **Fix:** while `input == .hinge`, route a Resume through `closingPause.hold()`.
11. **Memory and launch.**
    - About 58 MB of textures are warmed in `ChestScene.setUp` (`ChestScene.swift:193-201`), on the main thread, the
      first time the canvas lays out (that is, at launch).
    - RAM is not a concern on a Duo-class device, even counting the UIImage-backed CPU copies `SKTexture(image:)` keeps.
      The cost is the ~0.4 s first-frame hitch, which the Scene engineer measured on the sim.
    - **Fix:** warm `.golden` lazily (chest #3 at the earliest), or warm off the main thread with `CGImage` and wrap it
      on the main thread.
    - **No leaks found:**
      - `ChestScene` is built once (`GameController.swift:426-433`);
      - the three portraits are persistent (`AppModels.swift:61-63`);
      - the texture caches are static and keyed by constants;
      - every `Task` loop holds `self` weakly.
12. **Per frame at 120 Hz (minor, pre-existing).**
    - `HeistSession.snapshot` is built 2–4 times a frame, each time running `currentHint()` over the loot (and the relic
      glimmer test).
    - Because the scene keeps last frame's snapshot, the session's `loot` array is copied (copy-on-write) every step:
      one small allocation a frame.
    - **Fix:** take one snapshot per frame in `advance` and pass it down.
13. **A scored Daily posts to the Best Haul leaderboard** (`GameCenterManager.swift:113-116`), but `bestRun` and Home's
    "Best" ignore Dailies (`ProgressStore.swift:223-236`). Game Center can show a higher "Best Haul" than the app.
    **Fix:** either stop posting Dailies there, or raise `bestRun` too.
14. **Abandoning still counts runs.** Any abandon with a chest opened counts as a run (`AppRules.swift:243-247`,
    `ProgressStore.swift:253`). Five quick Restarts retire the teaching hints (`AppRules.teachingRuns`). **Fix:** count
    abandoned runs only if gold > 0, or keep a separate counter for the hints.
15. **App Review sees the test-build About panel.** `BuildChannel` treats a sandbox receipt as a test build
    (`BuildChannel.swift:11`), and App Review installs carry one. So reviewers see "Screen: … · portrait ask: …" in
    Settings › About. It's harmless, but tidy it, or name it "Diagnostics".
16. **The SwiftUI root controller's getter is swizzled with `class_replaceMethod`** (`OrientationLock.swift:139-154`).
    It uses public runtime API, on a private SwiftUI subclass found by name. The review risk is low. The risk is that
    an iOS update renames the class: the lock then silently stops working, and `HUSH-T root mask adopted` stops
    appearing in CI. Keep that log line as a CI check.

---

## Checked and found OK
- **Crash surface (R2 code):**
  - no new force unwraps (`TimeZone(identifier: "UTC")!` is safe);
  - `Int(…)` only on finite values (`torchTickSlot`, the chain value, the `±Ns` popups, `restChunks`);
  - the swizzled mask getter and the FPS observer run on the main thread, so `MainActor.assumeIsolated` is sound;
  - `requestGeometryUpdate`'s error hops to the main actor.
- **Stuck states:**
  - The closing pause always resumes while frames run. `lid(at:)` is polled every paused frame
    (`GameController.swift:221`), and `canResume` matures on the clock without reports.
  - The gate unlatches above 78°, and `isShut` releases at ≥ 15°.
  - `.pose` and `.background` survive Home by design and are cleared by the pose or the phase.
  - The menu needs Resume.
  - The orientation lock engages only once portrait, so I found no path back to the letterboxed column.
- **Lesson:** every step can be passed on a Duo and on a phone:
  - pose: 90–112° for 0.5 s, or the lever ≥ 0.04;
  - open: coin grabbable at ≈ 117°;
  - freeze: hinge silent while still;
  - bank: ≤ 110° for 0.35 s;
  - an early bank goes round once, then passes.
- **Hush Chain:**
  - +1 per Hushed bank, ×(1 + 0.1·min(n, 5));
  - it breaks on the first stir or bite, with `chainBroken` only at ≥ 2;
  - `rest()` can't stir the mimic;
  - the counter equals the sum of the banks.
- **Golden:** its own stream, from index 2; noise ×1.25 on every source; ×2 included in `multiplier`.
- **Jingle:** the floor is capped at 0.30, under Stirring's down-line of 0.31, and it never raises the noise.
- **Glimmer sound:** it is gated by `playing`.
- **Abandon and persistence:**
  - Home, Restart and a new run file `partialResult()` exactly once (the `recorded` latch);
  - the background checkpoint is cleared on `.active` and recovered after a kill;
  - a scored Daily is marked attempted at start and `finished=false` on abandon;
  - Again is always practice.
- **Release vs Debug:**
  - DemoMode, AppTrace and FeelDemoLog are compiled out;
  - the Release portrait request path is exercised in Debug CI (`orient portrait requested (release path)`,
    `root mask adopted` in every Duo log);
  - **unverified:** the Game Center auth, dashboard and sign-in sheet, the background checkpoint and `isIdleTimer`
    paths (CI skips them under `-hushDemo`), and the sandbox-receipt branch.
- **Copy:** no "torch" anywhere the player reads in the app (the code names only). The in-app copy matches R2.
- **Accessibility:** QA-1's labels are fixed; Reduce Motion is honoured in the new cards and drawings. Still missing:
  VoiceOver lid control (noted by the App engineer).

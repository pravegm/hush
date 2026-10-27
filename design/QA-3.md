# QA-3: Round 3 code review (senior QA, 27 Oct)

**Scope.** I read `QA-2.md`, `ROUND-3.md` and every `design/notes/*-R3.md`, and reviewed the R3 diff
(`git diff 578d9b0 HEAD -- Hush HushTests`, 41 files, +4,308/−1,010). I read end to end: `GameController`, `AppRules`,
`HingeLidSource`, `HingeReader`, `RootView`, `PlayHUD`, `PoseCards`, `ResultsView`, `Layout`, `HomeView` (layout half),
`ProgressStore` (record paths), `BuildChannel`, `GameCenterManager`, `DemoMode`, and the R3 diffs of `OrientationLock`,
`LessonScript`, `AppModels`, `HeistSession`, `FeedbackDirector` (frame rate), `ChestArtPlates` / `ArtImageCache`.
I also checked the R3 phone capture set (`artifacts/ci8s`, `captures.tsv` and its logs), the icon bytes, and
`docs/appstore/*` / `docs/LAUNCH-RUNBOOK.md`. There is no R3 Duo artifact locally, so every Duo-sim claim is
taken from the code, not from a log.

No source files were edited. "Unverified" means I couldn't settle it from the code and the logs, usually because it needs
a real Duo.

**Headline.**
- **No P0.** I found no crash path. I checked:
  - the new `Int(…)` sites (all on finite values or guarded);
  - the one new force unwrap (`ChestArtIcon` 1 × 1 fallback, unreachable in practice);
  - every `MainActor.assumeIsolated` callback (`onRefused`, `onCreakAccent`, `onPreferredFPSChange`), which all
    arrive on the main actor;
  - `ChestStrip` indexing (`vis.shown ≤ log.count`).
- **One P1:**
  - **P1-1:** leaving "Play anyway" mid-run (landscape → portrait) switches the run to the hinge with **no hold, no
    filter reset and no grace**. This is the "resume mid-motion" class that decision 1 forbids.
- **Decision 1 is verified in code.** A live hinge run can't resume on a small canvas, and always resumes on the inner one
  through `canResume`.
- **Decision 2 is verified.** Noise, stage and candle are frozen in every pause. I found no free calm-down and no new
  exploit.
- **QA-2: 19 items fixed, 4 partly fixed, 2 not fixed** (table below).
- **App icon:** byte 25 is **2 (RGB)** and there is no tRNS chunk (checked with Node).

---

## QA-2 verification

| QA-2 item | Status | Evidence (file:line) |
|---|---|---|
| P1-1 cover-sized canvas fallback played on the cover display | **Fixed** | The fallback is gone: `AppRules.pose` returns `.cover` for any small canvas once a hinge is seen (`AppRules.swift:69-80`). A small↔inner change during a live hinge run holds the pause (`GameController.swift:557-579`, `AppRules.swift:93-96`). Resume is gated on the canvas (`AppRules.swift:99-101`, `GameController.swift:780`). The cover pose also keeps the `.pose` reason set (`:645`). See "Decision 1" below. |
| P1-2 store / Game Center copy describes R1 | **Fixed** | `asc-metadata.json`: Midas Touch, Hush Chain, Heavy Bag 3,000, Dragon's Hoard 8,000, A Small Fortune 50,000 match `Ranks.swift:59-96`. No "torch" anywhere in `docs/` (0 whole-word hits), "Freeze!", 10 s, pause at 70°. Two small residuals are in P2-9. |
| P2-1 icon has an alpha channel | **Fixed** (residual) | `AppIcon-1024.png`: 1024², depth 8, **colour type 2**, chunks IHDR/IDAT/IEND only, 686,319 B. `ci/icon-check.sh:66-108` still only *warns* on alpha without `FIX_ALPHA` (P2-10). |
| P2-2 a closing pause freezes the end-of-chest and end-of-run moments | **Fixed** | `closingApplies` = live phases only (`AppRules.swift:105`, used at `GameController.swift:778`). Moments step through closing and pose pauses (`AppRules.swift:109-111`, `GameController.swift:272-283`). Headless candle-out after 2.6 s (`:1116-1135`). |
| P2-3 hint frozen through a pause | **Fixed** | The gate runs on wall time (`GameController.swift:1207-1218`) and is cleared when a pause begins (`:1269-1274`). |
| P2-4 book-pose card has no way out | **Fixed**, but see P1-1 | "Play anyway" appears on a refusal or after 8 s (`PoseCards.swift:97-104,212-217`, `GameController.swift:691-697`). Its *exit* path is P1-1. |
| P2-5 a cover launch forgets the hinge | **Fixed** | `OrientationLock.looksLikeDuoCover` and `trustsStoredHinge` (`OrientationLock.swift` R3 hunk), used at `GameController.swift:180-183`. |
| P2-6 glimmer geometry differs between Scene and Core | **Fixed** | `SceneLoot.swift:198-201` uses `HeistSession.relicGlimmers`. |
| P2-7 Game Center dismissal handler | **Partly** (unverified) | The activation fallback is at `GameController.swift:602-606`. `sheetIsUp()` (`GameCenterManager.swift:92-98`) only sees a `presentedViewController` on our own windows. If GameKit presents the dashboard in its own window, the fallback can clear the flag while the dashboard is still up. That needs a device. |
| P2-8 golden plate says ×2 | **Fixed** | `SceneLid.swift:47-50` (the real `multiplier`). |
| P2-9 resume-grace exploit | **Fixed** (residual P2-6) | `HeistSession.swift:233-240,290-299` (the grace ends after 0.15 s above 30°/s). |
| P2-10 menu Resume bypasses `canResume` | **Fixed** | `GameController.swift:873-881` (the hold is taken before the menu reason drops). |
| P2-11 ~58 MB texture warm-up on the main thread at launch | **Not fixed** | Left as is (`scene-R3.md` "Not done"). |
| P2-12 snapshot built 2–4× per frame | **Not fixed**, slightly worse | `checkClosing(now:phase: session.snapshot.phase)` (`GameController.swift:266`) builds one more full snapshot (loot copy and `currentHint()`) per frame. So does the paused branch (`:274,278`). |
| P2-13 Dailies post to Best Haul | **Fixed** | `GameCenterManager.swift:122-126`. |
| P2-14 abandoning counts runs | **Fixed** | `ProgressStore.swift:182-184`. |
| P2-15 App Review sees the test-build About panel | **Fixed** (residual P2-2) | Only `#if DEBUG` or a hidden 2 s press (`BuildChannel.swift:12-26`, `Pages.swift:355-367`). Nothing reads the receipt any more. |
| P2-16 swizzled root mask | **Unchanged** (OK) | The `HUSH-T root mask adopted` and `HUSH-T mask` lines are still there for CI. |
| QA-1 P1-2 resume mid-motion | **Fixed** (except P1-1) | Decision 1 plus `resume()` through the gate and the first-sample guard. |
| QA-1 P2-6 Game Center UI upside down | **Partly** | As P2-7 above. |
| QA-1 P2-17 Dynamic Type | **Partly** (by design) | The AXL and XXXL frames 41–47 render. |
| QA-1 P2-18 "FREEZE" in the store copy | **Fixed** | — |

---

## P1

### P1-1. Leaving "Play anyway" mid-run switches the run to the hinge with no hold, no reset and no grace

**Where:**
- `GameController.swift:532-535`: in `updateCanvas`, when the canvas turns portrait, `playAnyway = false; refreshInput()`.
- `refreshInput` (`:487-492`) only calls `setInput(.hinge)`.
- `setPose(.play)` returns early because the pose was already `.play` (`:630`): `AppRules.pose` gives `.play` for
  landscape + `playAnyway` (`AppRules.swift:78`). So the hold at `:640-644` never runs.
- `noteCanvasClass` sees inner → inner, so there is no handover hold either (`:558`).

**Scenario (Duo, mid-run):**
1. The player holds the Duo like a book and the card appears. After 8 s they tap **Play anyway** and play landscape on the
   lever.
2. They pick the Duo up and turn it upright (portrait) to stand it in tabletop. The hinge usually moves while they do.
3. On the first portrait frame the run plays on the hinge at once:
   - no `closingPause.hold()`;
   - no `hinge.reset()`: the hinge filters weren't polled during the lever play (`currentLid` only reads the active
     source), so the predictor and smoother start from stale state;
   - no `resumeGrace`;
   - the lid jumps from the lever's openness to the hinge's in one frame.
4. Any hinge motion above 30°/s counts in full. A slam can bite with no warning card.

This is QA-1 P0-2 / QA-2 P1-1 again, by a third route. It is reachable by every Duo player who waits 8 s on the card.

**Minimal fix:** in `refreshInput()`, when a live run's input *changes to* `.hinge`, call `hinge.reset()`,
`closingPause.hold()` and `setClosing(true)` (the same three calls as the first-sample guard at `:750-756`). Add a
test: Play anyway → portrait canvas during a live run → `isClosingPaused == true` and no step until `canResume`.

**The reverse direction (P2, the same fix site):** `choosePlayAnyway()` mid-run hands the lid to the run's untouched
`SliderLidSource` (openness 0, `SliderLidSource.swift:21`, made fresh at `GameController.swift:1032`). The open chest
snaps shut in one frame. With loot in the bag it then **auto-banks** after the shut-hold. Fix: when switching to the
slider mid-run, call `slider.reset(openness: session.snapshot.openness)` first.

---

## P2

1. **"Play anyway" on a Duo laid flat stays landscape for good.**
   - **Where:** once `pose == .play` (landscape), nothing asks for portrait again:
     - `deviceOrientationChanged` asks only when `pose == .standUp` (`:704`);
     - so does the lift rule (`:739-745`).
   - **Why:** a Duo lying in tabletop never auto-rotates (memory: hinge API notes).
   - **Scenario:** a player who tapped Play anyway and then stood the Duo up in tabletop plays sideways, on a lever, on a
     hinge device. They can only fix it by picking the device up.
   - Also, `portraitRefused` latches true for the whole session (`:204-206`). Any early refusal, even one at launch, puts
     "Play anyway" on every later card at once.
   - **Fix:**
     - while `playAnyway` and `hingeSeen`, run the `liftedFromBook` / `askPortrait(reason: "lift")` rule too;
     - offer "I've stood it up" in the pause menu;
     - reset `portraitRefused` when a request succeeds.
2. **The founder's device test can no longer collect the hand-off and relight angles.**
   - `LAUNCH-RUNBOOK.md:172` (step 9) says: if a grey "Test build" line appears under About, screenshot it; if not, skip
     the step.
   - TestFlight builds are Release, so the line (now "Diagnostics") appears only after a hidden 2 s press
     (`Pages.swift:357`).
   - The step will always be skipped, and the angles for `requiredResumeAngle` and REVIEW-2-duo P1-3 are lost.
   - **Fix:** step 9 should say: "Settings › About, press and hold the About text for 2 s, screenshot the Diagnostics
     line". Step 13 too.
3. **On a Duo, the lesson's final card is hidden behind the closing card.**
   - **Where:** `PlayHUD.swift:86-90` hides `LessonOverlay` (final card included) while `isClosingPaused`.
   - **Scenario:** the bank step says "Ease the lid shut to bank it". After the bank the lid is shut (< 70° for 0.4 s), so
     the closing pause engages on the next live chest (`closingApplies`). The player sees "Lift the lid a little to carry
     on" instead of "Lovely work, little thief". They must lift and hold still before "Got it" appears.
   - The closing card's Home leaves without `markLessonDone`, so the lesson runs again next launch.
   - Not stuck, but the wrong prompt at the lesson's pay-off. Unverified on a device: CI's lesson frames use `lid=`, not
     the hinge.
   - **Fix:** skip the closing pause while `lessonScript?.step == .done`, or show the final card instead of the closing
     card.
4. **VoiceOver: a stale stage announcement can cut off "Chomp!"**
   - **Where:** stage announcements are delayed 0.3 s in an uncancelled `Task` (`GameController.swift:426-436`).
   - **Scenario:** in a slam, Waking arrives about 0.1 s before the bite. VoiceOver starts "Chomp! Lost 240 gold.", then
     is interrupted 0.2 s later by "It's waking. Freeze!", after the player has already been bitten.
   - Other announcements interrupt each other the same way: a bank and the "Hush Chain!" tip on the same frame, a
     golden arrival.
   - **Fix:**
     - keep the pending stage announcement in a property; cancel it on a bite, a bank or a pause, and re-check
       `session.snapshot.stage` when it fires;
     - queue the rest with `NSAttributedString` + `.accessibilitySpeechQueueAnnouncement: true`.
5. **VoiceOver: "It's stirring." can repeat every few seconds.**
   - **Why:** with a full bag the jingle floor (≤ 0.30, `core-R3.md`) sits 0.05 under the Stirring line, and the
     hysteresis is only 0.04 (`Tuning.swift:83-87`). Every small drag announces Stirring again, and the drop back is
     silent, so the cycle repeats.
   - **Fix:** announce Stirring at most once per chest, or ≥ 5 s apart. Always announce Waking.
6. **The resume grace also applies to the lever (phones), where it isn't needed.**
   - **Where:** `setPause`'s resume branch grants `resumeGrace(0.5)` for every input (`GameController.swift:1281`).
   - **Scenario (phone):** tap the pause coin, then Resume, then sweep the lever quickly. Up to 0.5 s of motion under
     30°/s plus 0.15 s above it is silent, and the candle is frozen for the whole pause/resume cycle. Repeating it opens
     a chest faster than a slow open, for free. It's tedious, so the gain is small.
   - **Fix:** grant the grace only when `input == .hinge`.
7. **Per-frame cost.**
   - QA-2 P2-12 is still open and now costs one more snapshot (`:266`).
   - Plates are rendered synchronously in the SwiftUI body at 3× (`HushTheme.swift:218-237` →
     `ChestArtPlates.swift:145-153`). The first pause menu renders the menu plate plus 3 leather buttons (about
     1140 × 900 px for the menu), which is a visible hitch.
   - `ArtImageCache` (`ChestArt.swift:876-892`) is unbounded and keyed by every rounded size. That's bounded in practice
     (no plate's size animates: `GeometryReader` sees only final sizes), but each landscape/portrait or Dynamic Type
     change adds a new set of large bitmaps.
   - **Fix:**
     - pass the phase into `checkClosing` from the one snapshot;
     - warm the leather menu and button plates in `ChestScene.setUp`;
     - cap the cache, or use `plateSliceImage` + `resizable(capInsets:)` for the cards.
8. **Results at AXL Dynamic Type: the overflow chevron sits on the chest-strip captions.**
   - **Where:** frame `ci8s/41-results-axl.png`: "+363 ⌄ +358". The chevron is drawn over the content
     (`ResultsView.swift:247-256`).
   - **Fix:** give it a small backdrop, or inset the scroll's bottom by the chevron's height.
9. **Review-note and store-copy residuals.**
   - `review-notes.md:35` (and `asc-metadata.json` notes §2f) say resume is "only at 95 degrees or more". After a cover
     trip it can be as low as **90°** (`HingeLidSource.swift:58-61`, `GameController.swift:571`).
   - §2 also says "On a Duo … no lever is shown", but Play anyway shows one in landscape.
   - Say "about 90–95°", and mention the landscape fallback.
10. **The icon check doesn't enforce RGB.** `ci/icon-check.sh:66-108` only warns about alpha without `FIX_ALPHA`, so a
    future RGBA commit would pass `ci.yml`. Now that the committed file is RGB, make the alpha check fatal.
11. **CI evidence gaps in R3 (phone set `ci8s`):**
    - `13b-creak`: `expect-miss`. The novice pilot never cracks (`logs/13b-creak.txt`: a steady 30°/s), so there is no
      phone frame of CREAK!.
    - `36-golden-mimic`: `no-freeze`. The golden chest #3 arrived before `freezeAfter=18`.
    - `35-reveal-phone-turned`: `expect-miss`. It expects `turned=1` on a phone, but `turnsRound` needs a fold, so the
      scenario's expectation is wrong.
    - **Fix (`ci/scenarios.txt:43,77,83`):**
      - 13b: use a slam script or `pilot=novice` plus a slider slam;
      - 36: `freezeAfter=10`, or freeze on `event chestArrived …golden=1`;
      - 35: expect `fold=0 turned=0`.
12. **The app icon's eye reads poorly at small sizes (design note, unverified at 60 px).** The fangs cover most of the
    slit eye (it is about 60 px tall at 1024, so about 3–4 px at 60 px). That weakens the "slit amber eye" in
    decision 6. Worth a look on a Home screen.

---

## Verified (checked and found OK)

- **Decision 1: never resume on the cover; always resume on the inner display.**
  - **Shut:**
    - `setPose(.cover)` sets the `.pose` reason (`:645`);
    - `noteCanvasClass(.small)` holds the closing pause (`:574-578`);
    - `mayResume` returns false while the canvas is `.small` (`AppRules.swift:99-101`).
    - So there are three independent locks. Off the demo path the scene isn't even drawn (`RootView.swift:168-172`).
  - **Relight:** `handleCanvas` calls `setPose(.play)` first, and it holds *before* dropping `.pose`
    (`GameController.swift:640-645`). Then `noteCanvasClass(.inner)` holds again and lowers the resume angle to what's
    visible (`:569-571`).
  - **Resume:** only when `closingPause.update` gets `canResume` (≥ the effective angle, < 6°/s for 0.3 s), and
    `setPause` then resets the filters, puts the angle back to 95° and grants the grace (`:1275-1284`). No path leaves
    `.closing` set without its card: `setClosing` and `clearRunPauses` keep the two in step.
- **First hinge sample:** a run that starts before any report waits ("Move the lid a little", `:1062-1066`). The first
  report resets the filters and holds (`:750-758`), without releasing CI's `noiseUntil` (`guardHold`). A lever run
  promoted to the hinge by its first sample is held too. P1-1 is the one input switch that isn't covered.
- **Noise frozen in every pause (decision 2):**
  - the paused branch neither steps nor rests (`:272-283`), and the first step back is `clampStep(dt)` (≤ 1/30 s);
  - moments step only under the closing and pose pauses, never under the menu or the background, and they burn no
    candle;
  - Feel forgets its CREAK history while not playing;
  - no exploit beyond P2-6, and nothing unfair: noise only rises from activity, so freezing it is neutral.
- **Results are never blocked:**
  - a closing or pose pause can't freeze `.torchOut`;
  - the cover display is covered by the headless finish (`:1116-1135`, guarded by `recorded` and `torchOut`);
  - a menu opened during the candle-out moment gives way to Results after 2.6 s;
  - `showResults` clears the run pauses.
- **Lesson:**
  - **Duo:** resume ≥ 95° fits the 90–112° pose window. The coin is grabbable at about 117°. The freeze step is silent
    while still. The bank completes before the 70° / 0.4 s dwell at any speed under about 285°/s.
  - **Phone:** lever ≥ 0.04. Lever words follow the layout (`LessonScript.swift:290-318`). The marker and the line come
    from one branch (`liftCue`).
- **120/60 fps:**
  - `FeelFrameRate` (`FeedbackDirector.swift:770-794`): the ceiling while the lid moves > 1°/s, while dragging, during
    moments or a callout, held for 1 s; 60 when idle; capped by Low Power and heat;
  - 60 when paused or off play (`:277,945`);
  - published only on change;
  - SwiftUI re-renders at most about once a second.
- **Game Center:** Dailies go to the Daily board only. Queued scores and the signed-out toast are unchanged. Banners are
  off on a Duo.
- **App Review and Release:**
  - `DemoMode.current` (`DemoMode.swift:221-233`) and `AppTrace` are `#if DEBUG`;
  - `pose=book` and `freezeDelay` are parsed only inside the DEBUG block;
  - Diagnostics are never shown from the receipt;
  - `AppIconArt` is reachable only from demo `screen=icon`.
- **Copy:**
  - no user-visible "torch" in `Hush/` (only the enum names in `AppTrace`) or in `docs/`;
  - "bank" is the only verb: `HushCopy.hint(.shutToBank)` and the lesson "… to bank it." The remaining "keep" strings
    aren't the bank verb ("Leaving keeps the gold you've banked", "Keep the other half flat").
- **Persistence:** `seenTips` decodes tolerantly with no version bump. `markTip` is idempotent. The zero-gold abandon
  decrements `runs` after `record` (achievements don't read `runs`).
- **Play anyway, landscape layout:**
  - the scene and the HUD both use aspect-fit for a landscape view (`Layout.swift:27-31`,
    `GameController.swift:549`), so the overlays stay on the chest;
  - SpriteKit converts touches for `.aspectFit`;
  - the pause menu and the final card fit a 669-pt-tall floor half (compact).
  - Unverified: Home and Results look in landscape (no capture).

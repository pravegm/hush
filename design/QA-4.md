# QA-4: Round 4 release-candidate review (senior QA, 27 Oct)

**Scope.** I read `QA-3.md`, `ROUND-4.md` and `design/notes/{app,core,scene,ci}-R4.md`. I reviewed the R4 diff, which is
`git diff cd0f5f0 088edab -- Hush HushTests`. A docs-only commit, `835c5ab`, landed on top during the review, so
`HEAD~1` is no longer R3.

I read these end to end:
- the R4 hunks of `GameController`, `AppRules`, `LessonScript`, `BuildChannel`, `Pages`, `HomeView`, `HushTheme`,
  `PlayHUD`, `ResultsView`, `Layout` and `ChestScene`;
- the R4 hunks of `SceneFloorHUD` (seat, chain), `SceneLayout` (pause clamp) and `SceneLid` (`ChestCopy`);
- `SliderLidSource`, `HingeLidSource.reset/canResume`, and `ProgressStore` (load, backup, record);
- the new `playAnywayHandOversNeverJumpTheLid` test.

I also checked:
- the **R4 phone capture set `artifacts/ci9s`**: all 49 frames are `expect-ok`. I looked at 05, 14, 16, 25, 36, 41, 42
  and 44;
- `docs/appstore/review-notes.md`, `metadata.md`, `screenshots.md`, `press-kit.md` and `support.html` against `Tuning`,
  `HingeLidSource`, `ChestFactory` and `SceneLid`.

No source was edited. "Unverified" means it needs a real Duo, or a frame that doesn't exist.

## Verdict: **fix first** (one small P1), then ship as 1.0

- **No P0.** I found:
  - no crash path in the R4 code;
  - no stuck state in Play anyway ↔ hinge, pause/resume, the cover display or the lesson;
  - no Release leak (the test-only and Diagnostics UI);
  - no unsafe save path.
- **QA-3 P1-1 is fixed and tested.** That was the last correctness P1.
- **One P1, new in R4:** at the new Dynamic Type cap, Home's menu truncates and wraps mid-word (frame 44). It's a
  regression of R4 App item 7, on the first screen a large-text user sees. The fix is under an hour, and CI re-shoots
  frame 44 to verify it.
- **Store-doc P2s:** fix them before you paste the App Review notes. They're text edits, with no build needed.
- Everything else is P2 and can wait for 1.0.1.

---

## QA-3 verification

| QA-3 item | Status | Evidence (file:line) |
|---|---|---|
| **P1-1** leaving Play anyway → hinge with no hold, reset or grace | **Fixed** | See "P1-1, traced end to end" below. |
| P1-1 reverse: Play anyway mid-run snaps the lid shut and auto-banks | **Fixed** | `slider.reset(openness: snapshot.openness)` runs before `setInput` (`GameController.swift:560-562`), guarded by `AppRules.switchKeepsOpenness` (`AppRules.swift:127`). The slider is relative (`SliderLidSource.swift:37-52`), so the first touch can't jump. The test asserts openness kept and no bank in 90 frames. |
| P2-1 Play anyway on a flat Duo stays landscape; `portraitRefused` latches | **Not fixed** (out of the R4 brief) | `deviceOrientationChanged` asks only when `pose == .standUp` (`GameController.swift:788`), and so does the lift rule (`:823-829`). `portraitRefused` is set and never reset (`:212`). |
| P2-2 runbook step 9 can't collect the angles | **Fixed** | `DiagnosticsPanel` (`Pages.swift` R4 hunk) appears after a 2 s press on the Version line, in any build. The angles persist (`GameController.swift:649,653`). The runbook asks for it (`LAUNCH-RUNBOOK.md:191`). |
| P2-3 lesson final card behind the closing card | **Fixed** | `checkClosing` clears the hold while `lessonFinishing` (`GameController.swift:862-868`). `closingApplies(_:lessonFinishing:)` is at `AppRules.swift:107`, and `LessonScript.isFinishing` at `LessonScript.swift:143`. Cover and pose holds taken during the final card are cleared on the next frame, so it can't get stuck. Unverified on a Duo: frame 39 uses `lid=`. |
| P2-4 stale stage line cuts "Chomp!" | **Fixed** | `stageAnnounceTask` is cancelled on a bite, a bank (`GameController.swift:466-470`) and any pause (`:1386`), and re-checked when it fires (`AppRules.stageAnnouncementDue`, `:523`). Only Chomp and Waking interrupt (`PlayHUD.swift:56-62`); the rest queue. |
| P2-5 "It's stirring." repeats | **Fixed** | `AnnounceGate` (`AppRules.swift:501-520`): once per chest. |
| P2-6 resume grace on the lever | **Not fixed** (out of the brief) | `setPause` still grants 0.5 s for every input (`GameController.swift:1397`). |
| P2-7 per-frame cost | **Not fixed**, slightly worse | `checkClosing(…phase: session.snapshot.phase)` still builds one more snapshot per frame (`:286`). Hugging plates (`PlateTextLayout`, `HushTheme.swift` R4) render one more plate bitmap for every distinct text width. `ArtImageCache` is still uncapped. |
| P2-8 Results chevron over the totals | **Fixed** | The chevron has its own 18 pt strip (`ResultsView.swift`, `FadingScroll.chevronStrip`). Frame 41 shows it below the tiles. |
| P2-9 review-note residuals ("95 degrees or more", "no lever is shown") | **Not fixed** | `review-notes.md:35` and `:29` are unchanged (and so is `asc-metadata.json` notes). See P2-A. |
| P2-10 the icon check doesn't enforce RGB | **Fixed** | A fatal step, "App icon is RGB, no alpha" (`.github/workflows/ci.yml:134-137`, `icon-check.sh --alpha-only`). |
| P2-11 CI frames that missed (13b, 36, 35) | **Fixed** | `ci9s/captures.tsv`: 13b, 13c, 35 and 36 are `froze expect-ok`. Frame 36 shows the golden chest with its banner up. |
| P2-12 the icon's eye at 60 px | **Unverified** | The coins moved inside the safe circle (`ChestArtIcon.swift` R4, tested). The eye is unchanged, so it needs a look on a Home screen. |
| QA-2 P2-7 / QA-1 P2-6 Game Center dismissal | **Unchanged** (unverified) | `GameCenterManager` isn't in the diff. It needs a device. |
| QA-2 P2-11 texture warm-up at launch | **Unchanged** | R4 adds 3 small textures (`scene-R4.md`). |

### P1-1, traced end to end

**The switch.** `updateCanvas` sees a portrait canvas, sets `playAnyway = false` and calls `refreshInput()`
(`GameController.swift:614-616`). On a live run, `refreshInput()` (`:554-574`) then:
1. calls `hinge.reset()`. The filters are re-seeded from the last raw report (`HingeLidSource.swift:173-188`), so a
   Duo lying still can still resume;
2. calls `closingPause.hold()`;
3. calls `setClosing(true)` under `guardHold`, so CI's `noiseUntil` isn't released.

**What it covers.**
- `isLiveRun` is true during the bank and bite beats, so the hold covers those phases too.
- The hold is consumed on the next live chest (`closingApplies`).
- If the hinge has never reported, `closingAwaitsHinge` is set.

**The test.** `playAnywayHandOversNeverJumpTheLid` (`AppTests.swift:1543-1613`) drives the real controller through
lever → fold → Play anyway → portrait. It asserts the run is held and makes no step.

---

## P1

### P1-A. Home at accessibility text sizes truncates and wraps mid-word (an R4 regression)

**Where:**
- The new cap lets accessibility sizes grow to 1.12 × XXXL (`HushTheme.swift`, `HushType.scaled`). That is about
  1.5× body, where R3 capped at 1.3×.
- On Home's phone layout, `ViewThatFits` chooses the plain `HomeMenu` because it fits vertically. It never falls back
  to the scroll, because the problem is width, not height.
- `HomeView.swift:248-259`: "Daily Dungeon" has `layoutPriority(1)`, so the status column is left about 2 words wide.
- `HomeView.swift:303-305`: `CountLabel` is `lineLimit(1)` with `minimumScaleFactor(0.7)`, which isn't enough at the
  new cap.

**Scenario:** frame `ci9s/44-home-axl.png` (AX-L, the phone):
- the Daily status reads **"Today'" / "s try r…"** (split at the apostrophe, then truncated);
- the buttons read **"Codex 9…"** and **"Badges…"**;
- "Game Center" touches its tile edge.

This is the first screen a large-text user sees. R4 App item 7 ("names never truncate", frame 44) was meant to fix
exactly this. The app engineer's note says the status "wraps to 2 lines", but the frame shows it doesn't.

**Minimal fix:** in `HomeMenu`, when `dynamicTypeSize.isAccessibilitySize`:
- put the Daily status *under* "Daily Dungeon" (a `VStack(alignment: .leading)`), not beside it;
- stack Codex and Badges one per row (or drop the "9/24" count and keep it in the VoiceOver label);
- stack Settings and Game Center the same way.

The scroll fallback already exists for the extra height.

**Verify:** re-shoot frame 44, and add a 44b on the Duo fold layout (`screen=home;fold=1;dynamicType=AX-L`). Expect no
"…" anywhere.

---

## P2

**A. App Review notes: three claims the build no longer matches** (`review-notes.md`, mirrored in `asc-metadata.json`
`notes`). These are text edits; re-count the 4,000-byte limit after editing.
1. **§2, line 29: "The angle is used only during play, never stored or sent."**
   - R4 now **stores** the hand-off and relight angles in UserDefaults on every cover hand-off
     (`GameController.swift:649,653`, keys `hush.diag.*`).
   - That's on the device only, so "Data Not Collected" stays true. But the sentence is now false, and the check table
     at `review-notes.md:75` says "angle never persisted" (`Persistence/` grep; the write isn't in `Persistence/`).
   - **Fix (copy):** "…never sent; the last fold angle is kept on the device for an optional diagnostics line". Or
     **fix (code):** write the keys only while `BuildChannel.showsDiagnostics()` is true.
2. **§2f, line 35: "only at 95 degrees or more".** After a cover trip the resume angle is `max(90, relight + 3)`
   (`HingeLidSource.swift:58-61`). Say "about 90 to 95 degrees". This is QA-3 P2-9, still open.
3. **§2, line 29: "On a Duo … no lever is shown".** Play anyway shows one, in landscape (`AppRules.usesSlider`,
   `AppRules.swift:114`). Add "(except the optional landscape 'Play anyway' fallback)".

**B. Golden copy: "double" in the store, "extra" and "×3/×4/×6" in the app.**
- **The code:** `ChestSpec.multiplier` = tier × 2 (`ChestFactory.swift:165`), and golden chests start at chest #3,
  which is Iron-bound or higher (`Tuning.swift:216-218`).
- **What the app shows:**
  - the seal and the pop show the *total* multiplier (`SceneLid.swift:49-51,69-72`);
  - so a golden chest never shows ×2. Frame 36 shows "GOLD ×3" on the seal and "×3" pops;
  - the plaque reads "Golden · Chest 3", so the Iron-bound tier that explains the ×3 is hidden (`SceneLid.swift:63-66`);
  - an ordinary Royal chest *also* reads "GOLD ×3" (frame 16).
- **What the docs say:**
  - "double gold" in the description (`metadata.md:77,128`), `review-notes.md:45` ("pays double"), `press-kit.md:31,50,133`,
    `featuring-nomination.md:37`, `support.html:74` and `index.html:168`;
  - the Midas Touch after-text, "Double gold, and away you crept." (`achievements.md:46`, `asc-metadata.json:184,189`);
  - "Extra gold" in the app banner (`AppRules.swift:378`) and the store frame DR1 (`screenshots.md:49`).
- **Is it accurate?** "Double gold" is true relative to the tier, so it isn't a 2.3 accuracy risk. But a player who
  reads "double" and sees ×3 is confused.
- **Fix (docs only):** say "a golden mimic doubles a chest's gold" everywhere. Optionally, show the tier on the
  golden plaque ("Golden Iron-bound · Chest 3").
- **Also:** `screenshots.md:49` says "Use only if the frame shows the gilded chest". Frame 36 is the Iron-bound
  golden chest #3, so update that condition.

**C. A golden chest still shows two "GOLD ×" numbers.** The chain tab reads "GOLD ×1.2" beside the seal's "GOLD ×3"
(frame 36). That's against R4 Scene item 7 ("no other number appears"). Hide the chain tab's number while a golden
chest is live, or label it "CHAIN ×1.2".

**D. The relic card hint gate runs on the wall clock; the relic card runs on scene time.**
- `relicCardUntil = now + bankGroupEnd + bannerTime` (`GameController.swift:456-459`).
- If the menu is opened while the card is up, the card freezes (no stepping under the menu), but the gate runs out.
  After Resume the hint shows over the card: two prompts.
- It's rare, and nothing gets stuck. **Fix:** push `relicCardUntil` on by the paused time when the menu closes.

**E. VoiceOver in the lesson: "Slower… it's grumbling." can alternate with the step line.**
- `LessonDisplay.announcement` speaks whenever `warning` flips (`LessonScript.swift:54-61`).
- `isSlower` lasts `slowerSeconds` and re-arms on every loud frame (`:185-188`). A player moving fast in the open or
  grab step queues "Slower…" and then the step line, again and again.
- **Fix:** don't re-announce the same line within 3 s.

**F. Persistence: overflow on a tampered save.**
- Decoding is safe: every field is decoded with `try?`, an undecodable save is backed up and never wiped
  (`ProgressStore.swift:300-326`), and a bad `pendingRun` decodes to nil.
- But only the floor is clamped (`max(…, 0)`, `:107-118`). A hand-edited `lifetimeGold` near `Int.max` traps in
  `data.lifetimeGold += gold` (`:259`).
- Ordinary corruption fails the JSON parse, so this needs a tampered file. **Fix:** clamp on decode, for example to
  `1_000_000_000`.

**G. Still open from QA-3:** P2-1 (Play anyway on a flat Duo), P2-6 (lever grace), P2-7 (per-frame cost), and the
QA-2 P2-11 warm-up. None is a launch blocker. See the table.

---

## Store and review-notes claims checked against the code

| Claim | Code | OK? |
|---|---|---|
| Pause below 70° for 0.4 s | `Tuning.closingAngle` 70, `closingDwell` 0.4 (`Tuning.swift:27,29`); `ClosingPause` (`AppRules.swift` ~457-462) | Yes |
| Resume ≥ 95°, held still (< 6°/s for 0.3 s), inner display only | `HingeLidSource.swift:32,114-124`; `mayResume` (`AppRules.swift:99-101`) | Yes, except after a cover trip, where it can be 90° (P2-A2) |
| Bite = the bag + 10 s | `Tuning.biteTorchPenalty` 10 (`Tuning.swift:203`); `HeistSession.swift:485-488` | Yes |
| Candle 100 s, oil +6 s | `Tuning.swift:199,201` | Yes |
| Hush Chain ×1.1 → ×1.5 | `chainStep` 0.10, `chainMax` 5 (`Tuning.swift:211-212`); `AppRules.swift:355` | Yes |
| Golden ×2 | `goldenValueMultiplier` 2 (`Tuning.swift:218`); the seal shows tier × 2 | Yes in code; the copy is confusing (P2-B) |
| Lever on non-Duo iPhones; none on a fold layout | `AppRules.usesSlider` (`:114-117`); `ChestScene.showsLever` | Yes; Play anyway is the exception (P2-A3) |
| Shut ≈ 100°, wide ≈ 165°, bank ≤ 110° held 0.35 s, wide-enough > 172° | `Tuning.swift:16,18,22,24,229` | Yes |
| The hinge angle is never stored | `GameController.swift:649,653` | **No** (P2-A1) |
| No test UI for App Review | `BuildChannel.showsDiagnostics` (`BuildChannel.swift:41-47`); `DemoMode` and `AppTrace` are `#if DEBUG` | Yes. The receipt only names the channel *inside* the panel. |

## Checked and OK

- **Crashes.**
  - The new divisions are guarded: `viewScale` > 0.05 (`SceneLayout` `pauseCenter`/`pauseSeatRadius`), and
    `unit = max(xScale, 0.001)` (`MimicPortraitScene`).
  - The new `Int(…)` sites are on finite values (`chainShown`/`chainText`, `SceneFloorHUD.swift:428-439`).
  - The `viewScale` didSet doesn't recurse.
  - `PlateFit.textRect` falls back on a NaN or empty rect.
  - `DiagnosticsPanel`'s `ForEach(id: \.self)` lines are always distinct.
  - Every stage-announcement `Task` re-checks `isCancelled` and `self`.
- **Stuck states.**
  - Play anyway → lever: the closing pause is cleared at once (`checkClosing`, `input != .hinge`), and `setPose(.play)`
    doesn't hold.
  - A pending callout never outlives a run (it is cleared at start and on Home).
  - The lesson's finishing frames can't lock the closing card.
  - Menu Resume still goes through the hinge gate (`:963-971`).
- **Release.**
  - Diagnostics show only after the hidden press, and the press works in TestFlight and App Store builds alike. That's
    as intended: App Review would need to find a 2 s hold on the version line.
  - `BuildChannel.current` is evaluated only inside the panel.
- **Game Center:** unchanged since QA-3. Signed out, you get the toast and queued scores.
- **Performance at 120 / 60 fps:**
  - R4 adds 4 nodes, and the meter word is rebuilt only on a stage change;
  - the seat is re-placed only when the scale changes;
  - the `FeelFrameRate` policy is unchanged.
  - QA-3 P2-7 still stands.
- **Plates:** text is laid out in `ChestArt.plateTextRect` through `PlateTextLayout`. Frames 05, 16 and 36 show the
  lines clear of the brass caps. The hint plate keeps 16 pt from the pause seat (`Layout.swift` `hintPlateRect`;
  frames 16 and 36).
- **Copy:**
  - no user-visible "torch" (only enum names and a texture key);
  - the only "keep" strings aren't the bank verb ("Keep the other half flat", "Do not keep it warm.");
  - the lesson says "Drag a coin…"; phone Home says "Slide its lid up… slowly." (frame 44);
  - Results says "Opened / chests" (frame 41), and that tile counts only chests that were being looted
    (`HeistSession.swift:569-571`).
- **Codex and Results at AX-L:** names wrap with no "…" (frame 42), and the chevron no longer covers totals (frame 41).

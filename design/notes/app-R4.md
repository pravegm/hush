# App engineer, Round 4 hand-off (27 Oct)

Not compiled here (CI is the compiler). Nothing committed. Files touched: `Hush/App/` (GameController, AppRules,
BuildChannel, LessonScript), `Hush/UI/` (HushTheme, PlayHUD, Layout, PoseCards, ResultsView, HomeView, Pages),
`HushTests/AppTests.swift` (new `R4Tests`, 10 tests; two R3 copy assertions updated), `design/NEEDS.md`. The Scene's
`ChestArt.plateTextRect(in:style:)` landed in parallel and is called by that exact name (it is symmetric, so y-up and
y-down are the same). `artifacts/store1/` isn't on this machine, so I checked against `ci8s` and the reviews only.

## The 10 items
1. **Plates (juror P0-1, UX P1-1).** New `PlateFit` + `PlateTextLayout` (a SwiftUI `Layout`, HushTheme.swift). The plate
   hugs its text up to the width it's given, then proposes the child exactly `plateTextRect`, so `minimumScaleFactor`
   shrinks the text before it can reach a cap. Used by `onPlate(_:)` (the hint, callouts and run banner, the lesson
   step card, the lid cue) and by `hushPlate` (pause menu, closing card, final card, Daily marker). Leather buttons use
   it too ("Not yet, take me home" was 14 pt from a 16 pt cap). One line with `minimumScaleFactor(0.7)` (`HintLine.minScale`);
   lesson lines may take 2 lines. The hint plate sits in `HUDLayout.hintPlateRect`: the hint band kept 16 pt clear of
   `pauseArea`, centred while it can be. Tests: `plateTextStaysOffTheCaps` (every style, long, short and capped text:
   ≥ cap + 8 pt each side), `hintPlateClearsThePauseStud`.
2. **One prompt at a time.** `AppRules.promptBlocked` / `hintSuppressed`: during the bank beat (`.banked`) and while
   the relic card is up (`relicCardUntil`, from `SceneMoments.bankGroupEnd + bannerTime` per relic), no hint shows (a
   live warning such as "Freeze!" still does), and callouts wait (`pendingCallout`). They show in full once the next
   chest is live. That covers the first Hush Chain tip, which lands with the bank (frame 14). A callout already beats
   the hint. **QA-3 P2-3:** `closingApplies(_:lessonFinishing:)` stops the closing pause once the lesson is banked
   (`LessonScript.isFinishing`: the praise beat or the final card), and clears a hold already taken, so the final card
   is never behind the closing card. Test: `onePromptAtATime`.
3. **QA-3 P1-1.** `refreshInput()`: when a live run's input changes to `.hinge` (`AppRules.switchHolds`), it calls
   `hinge.reset()`, `closingPause.hold()` and `setClosing(true)`. "Move the lid a little" shows if there's no report
   yet. The log is `HUSH-T input switch hold`, and it doesn't release `noiseUntil`. **Reverse (P2):** a live run handed
   to the lever (`switchKeepsOpenness`) calls `slider.reset(openness: snapshot.openness)` first, so the lid neither
   snaps shut nor auto-banks. Tests: `inputSwitchRules`, and `playAnywayHandOversNeverJumpTheLid`, which drives the
   real controller: open on the lever → fold canvas (held, no step) → Play anyway (the lever starts at the lid's
   openness; no bank in 90 frames) → portrait again (held, no step).
4. **VoiceOver (QA-3 P2-4/5, UX P2-9).**
   - The 0.3 s stage line is kept in `stageAnnounceTask`. It is cancelled by a bite, a bank or any pause, and
     re-checked when it fires (`stageAnnouncementDue`: same stage, live chest, not paused).
   - `AnnounceGate` says "It's stirring." at most once per chest. Waking is always said.
   - Only "Chomp!" and Waking interrupt. Everything else queues (`NSAttributedString` +
     `.accessibilitySpeechQueueAnnouncement`, `HushCopy.queuesAnnouncement`).
   - Lesson steps, praise, warnings and the final card are announced (`LessonDisplay.announcement`; the pose step's
     angle-driven line changes aren't re-read). In the lesson the step line replaces the stage lines.
   - Test: `voiceOverAnnouncements`.
5. **Copy.** Phone Home: "Slide its lid up… slowly." Lesson: "Drag a coin into your bag." Golden: "A golden mimic!
   Extra gold!" Results: the first tile is **Opened / chests** (`AppRules.chestsOpened`: the strip's count, the chest
   the candle went out on included), and the story says "N chests opened before the candle gave out." Test: `r4Copy`.
6. **Results legend** is inside the chest-strip card, above the chips, at 13 pt (scaled).
7. **Dynamic Type.**
   - The `FadingScroll` chevron has its own 18 pt strip under the scroll, shown only when it overflows, so it never
     covers a total (41/45).
   - Codex names have `CodexView.nameLines`: 2 lines, 3 from xxLarge, `minimumScaleFactor(0.7)` and tightening, in a
     fixed box so the grid stays aligned.
   - Home's Daily status wraps to 2 lines (CI's 44 caption expects "Today's try ready" wrapped).
   - Test: `largeTypeWraps`.
8. **Pose screen (juror P1-4).** `DuoChestHalf` draws each half in the game's art:
   - the lid half: wood with planks, the sleeping eye (`ChestArt.mimicEye` / `mimicEyeBed`, flesh colours), teeth
     (`teethRow`) at the hinge, a glowing gold rim and the plate `arrowUp` glyph;
   - the floor half: velvet, a coin and a ruby (`lootImage`), and the bag strip's brass edge.

   It replaces the flat gold trapezoid and the SF `shippingbox`, and it is also the hero on the book card's lift page.
   "I've stood it up" uses the drawn `TickGlyph`. Test: `poseArtDrawsAtCardSize`.
9. **The "!" padlock** is the chest's front-lock keyhole (`SceneArtChest.bigLock`). It is not a pose or lock
   indicator. A turned fold still puts the hole under the slot, so it reads "!". Frame 32 (upright) is a plain
   keyhole. There was nothing for the App to label or remove. I asked Scene for a classic flared keyhole (NEEDS),
   which CI found too.
10. **Diagnostics:** below. `BuildChannel.kind(isDebug:receiptName:)` now names the channel (Debug / TestFlight (sandbox
    receipt) / App Store), but only inside the panel. It never decides whether UI shows: App Review installs carry a
    sandbox receipt too, so every Release build needs the hidden press. Test: `diagnosticsReportTheChannelAndAngles`.

## Founder follow-ups (from CI R4)
- **Lever on a fold (frame 32).** `usesSlider` is now one pure rule, `AppRules.usesSlider(playRoute:layoutHasFold:input:)`:
  no lever on any fold layout, turned or not, whoever drives the lid. `sliderTouch` goes through the same rule.
  "Play anyway" is landscape, which is never a fold layout, so it keeps its lever. Tests: `aFoldLayoutNeverUsesTheLever`
  and the controller checks in `playAnywayHandOversNeverJumpTheLid`. The R3 code already had `!layoutHasFold`, and
  frame 32 shows no lever (the brass bar over the eye is the brow plate), so the drawing side is the Scene's (NEEDS).
- **Dynamic Type cap.** The flat 1.3× cap is gone. `HushType.scaled` grows in full through XXXL, and only the
  accessibility sizes are capped, at `accessibilityGrowth` (1.12) × the style's XXXL size. 41 (AX-L) is now larger
  than 45 (XXXL). So nothing clips at the cap: Home's menu (fold and phone) and the lesson's final card fall back to
  a scroll (`ViewThatFits`). Results, the pages, Codex and Settings already scroll; names wrap. Test:
  `dynamicTypeGrowsWithinTheCap` (XXXL = iOS's size; AX-L > XXXL; AX-L ≤ 1.12 × XXXL). Unverified on frames until
  CI re-shoots 41–47.
- **Golden banner:** "A golden mimic! Extra gold!" (`RunTip.golden`, tested).

## Diagnostics: the founder's steps (TestFlight build, for LAUNCH-RUNBOOK steps 9 and 13)
1. Install the TestFlight build and do the device test as written. The angles are recorded whenever the Duo hands the
   app from the inside screen to the outside one ("hand-off") and back ("relight"). This happens during steps 6–9
   (close slowly, then reopen). They are kept across launches.
2. Go to Home (pause coin → **Home**), then tap **Settings** (the labelled gear button).
3. In the second card, tap **About**. It opens a short paragraph and, under it, a small grey line: **"Version 1.0 (N)"**.
4. **Press and hold that Version line for 2 full seconds.** There's a click (and a haptic), and a **DIAGNOSTICS** box
   appears under it. It stays on across launches; the same 2 s press hides it.
5. Take a screenshot. While you're there, move the lid: the hinge angle updates 4 times a second.

The panel shows, one fact a line:
- `Build: TestFlight (sandbox receipt) 1.0 (N)`;
- `Hinge now: 104.3° · lid: hinge` (live; "no reading" until the hinge reports);
- `Last hand-off to cover: 12.0°` (the angle when the outside screen took over; "-" if it never happened);
- `Last relight of inner: 31.5°` (the angle when the inside screen came back on);
- `Resume needs: 95.0° and still` (the closing card's current resume angle);
- the orientation-mask status and the device orientation.

The founder updates the runbook. Step 9's "grey Test build line" becomes the press above; step 13 the same.

## Risks / not done
- `PlateTextLayout` is a new layout path for every in-chest plate and leather button. Check 03–08, 09/10/14/15, 34, 36,
  39, the pause menu and the closing card. Plates are rendered per exact size, so hugging plates add one bitmap per
  string size (bounded; QA-3 P2-7 still stands).
- The chain tip and the golden banner may now show 1–3 s later (after the bank beat or the relic card). CI freezes
  keyed on them may need more delay (NEEDS).
- Not done: QA-3 P2-1 (Play anyway on a flat Duo stays landscape), P2-6 (lever resume grace), P2-7 (per-frame cost).
  None was in the R4 brief.

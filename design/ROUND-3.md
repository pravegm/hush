# Round 3: the last mile to launch standard (brief)

**R2 scores (R1 in brackets):**
- Apple juror 7.5 (6.0). UX 8.0 (6.5). Duo 7.0 (6.0).
- QA-2: no P0, two P1s; 22 of the 26 QA-1 items fixed.
- Fresh testers 4–6: understood 7 / 8 / 7, premium 8 / 6.5 / 8, would pay 7 / 7 / 7.

Read the reports for your role in full:
- `design/panel/REVIEW-2-juror.md`, `REVIEW-2-ux.md`, `REVIEW-2-duo.md`;
- `design/QA-2.md`;
- `design/fresh/tester4-duo.md`, `tester5-phone.md`, `tester6-duo.md`.

**Founder decisions** (these override the reports where they differ):
1. **Delete the small-canvas "cover-open" fallback entirely.** The portrait-mask fix removed the letterboxed column
   it was for. The cover display is a pause, always. On any small ↔ inner canvas change during a live run, call
   `closingPause.hold()` (resume only through `canResume`), and never resume on a small canvas.
2. **Noise is frozen while paused.** Don't call `session.rest(dt:)` from the pause path. Closing the lid must not
   be a free way to calm the mimic (REVIEW-2-duo P2). The reopen bite is already prevented by the stillness gate,
   the filter reset and the 0.5 s grace.
3. **One verb: "bank".** Use "Ease the lid shut to bank" (Duo) and "Slide the lever down to bank" (phone). IN BAG
   gets a sub-label, "not safe yet".
4. **The copy follows the layout, not the input.**
   - With `layout.hasFold` (a real Duo, or demo `fold=1`), every lesson, hint and Home line uses lid words ("Open
     the lid… slowly").
   - Without a fold, it uses lever words.
   - A fold layout never draws or uses the lever (REVIEW-2-duo P1-4).
5. **Hints and cards become in-world:** one parchment or leather plate style for the hint, the lesson card, the
   pause, resume and closing cards and the toasts. No black pills, no teal app cards, no SF Symbols inside the
   chest. Show one prompt at a time (the resume card stacks three).
6. **The app icon is redrawn in the game's style:** a slit amber eye, a shield lock, pointed fangs, star coins and
   outlines. It must stay readable at 60 px. It must be an RGB PNG with no alpha.

---

## Scene engineer
- **P0:** the bank moment on wooden and iron chests blacks out the whole floor (frames 14, 37). Darken only the
  interior; the frame, front and lock stay at full alpha. Check every tier.
- **The sleeping mouth:** always show 5–7 tooth tips with a curved gum line (no straight pink tube) at every stage.
- **The tongue in dim and waking states:** keep the fill (no hollow U), taper the tip, drop the crease when dim.
  Check frames 12, 18, 33 and duo-ui-lesson-1-150.
- **Lid collisions:**
  - The lever track must never cross the teeth, the nameplate or the Zs.
  - Move the lever to the lid's right edge band, clear of the gum, and shorten it.
  - Teaching labels must not sit on the eyelashes.
- **Screen edges:** nothing touches an edge (≥ 16 pt inset everywhere).
  - The CHAIN medal moves inside the frame.
  - The chain label "GOLD ×1.2" (UX), with "HUSH CHAIN" in small caps above it.
  - The "0:15" pill sits beside the candle, not over it.
  - The "Hush Chain ×1.5" banner is centred.
  - Agree with the App a pause-coin spot that isn't on a corner bracket, and update `ChestLayout.pauseArea`.
- **Golden mimic:** unmistakable at a glance: a gilded frame, a sparkle, "GOLDEN" on the plate, and ×2 on the coins.
- **The relic-found moment:** a big, visible relic card (the art plus its name) for about 1.2 s on the floor, so a
  still frame shows the relic. Flying loot must not cover the BANKED label: fly it *into* the plate, under the
  label.
- **The slam:** when the noise jumps by > 0.25 in 0.3 s, show a visible "CREAK!" shake and a red flash on the meter.
  That way even a non-bite slam reads as "too loud" (tester 6).
- **The icon:** add `ChestArt.appIcon(size: CGFloat) -> CGImage` (opaque, the game's style, decision 6). The App's
  `AppIconArt` will call it.
- `MimicPortraitScene` for the cover: an eye and a sleeping-breath idle, filling the card (juror P1-8).

## App engineer
- **Decisions 1–5.** Delete the fallback and its tests; add tests for the handover hold. Freeze the noise in pause.
  Apply "bank" everywhere. Key the copy on the layout. Use the in-world plate style for every card and hint.
- **UX P0-1:** the Duo lesson step 1's arrow and line come from the same angle branch:
  - "↓ Lower this half a little" above 112°;
  - "Hold it there…" inside 90–112°;
  - "↑ Lift this half" below 90°.
- **UX P0-2:** an urgent hint (freeze) replaces any hint on the same frame. Add a test. The hint gate runs on wall
  time, so it can't freeze during a pause (QA-2 P2-3).
- **The Hush Chain explained:**
  - First chain: a toast, "Hush Chain! Sleepy banks pay more".
  - First break: "It stirred. Chain broken."
  - Results legend: "💤 = banked while it slept".
- **The golden banner:** "A golden mimic! Double gold." (once per golden chest, on arrival).
- **Results:**
  - The stat tiles are above the chest strip, equal height, never under the buttons.
  - The strip is capped at 2 rows plus "+N more".
  - There is a scroll fade.
  - "First haul!" shows on the first run.
  - A cause line says why the run ended ("Your candle burned out" or "The mimic bit you N times").
  - Results never wait on a closing pause (QA-2 P2-2): finishing a run shows Results whatever the lid is doing.
- **The pose card:**
  - "Turn it sideways. Lift the glowing half." CI captures it at `screen=pose;pose=book` (add the key if needed).
  - The automatic portrait ask fires only when the device orientation isn't landscape (REVIEW-2-duo P1-2). Keep the
    lift detection and the "I've stood it up" button.
  - The card has a way out ("Play anyway") if portrait is refused (QA-2 P2-4).
- **The first hinge sample:** guard it (hold the pause, then reset). Menu Resume goes through the hinge gate.
- **VoiceOver:**
  - Add elements for BANKED, the candle and NOISE.
  - Announce the stages ("It's waking. Freeze!"), bites and banks (`UIAccessibility.post(.announcement)`).
- **Game Center:** if the dismissal handler never fires, restore turning round on the next activation (QA-2 P2-7).
- **App Review:** App Review installs carry a sandbox receipt, so they must not see a test-build About panel
  (QA-2 P2-15). Show TestFlight-only UI only behind a DEBUG flag or a hidden gesture, never from the receipt alone.
- **Clipping and polish:**
  - The Codex and Settings bottom rows clear the Done button.
  - The Codex grid is aligned (not staggered).
  - Locked badges are readable silhouettes.
  - Home's icon-only buttons get labels ("Codex", "Badges", the flask = "Daily"?): name what it is.
  - Home has no dead space (on the phone: a "Best haul / rank" card).
  - The demo `progress=` presets agree across Home, Codex and Results. Testers flagged "Codex 9/24 vs 22/24" again:
    find the source and add a test that renders all three from one preset.
- **`AppIconArt`** calls `ChestArt.appIcon(size:)` and renders opaque.
- **Every QA-2 App item** (P2s included) in your folders.

## Feel engineer
- **Every QA-2 and REVIEW-2-duo item** in Input and Feedback.
- **VoiceOver:** a quiet audio cue for the stages, already present (just check it).
- **CREAK:** add a short, sharp wooden "crack" accent when the noise jumps > 0.25 in 0.3 s, so a slam is unmissable
  even without a bite. Add `FeedbackDirector.creakAccent()`; the App calls it from the same rule as the Scene.
  Alternatively detect it in `handle` from telemetry, and note which you chose.
- **Frame rate:** 120 fps only while the lid moves or something animates, and 60 fps when idle in play. Battery is
  a P2 from REVIEW-2-duo. Expose it through `preferredFPS(moving:)` or similar, and document it.

## Core engineer
- `rest(dt:)` stays in the API but is no longer used for pauses (decision 2). Add a test that noise is unchanged
  across a pause.
- Check the chain, golden and jingle rules against the QA-2 notes (no changes expected).
- Run the balance sim again after any change. There should be no tuning change this round.

## CI engineer
- **`ci/duo.sh`:**
  - Add COVER-SLOW-CLOSE: sweep 120 → 40 over 6 s. PASS if no `pose play` is logged while the canvas is cover-sized,
    and the run stays paused.
  - Add COVER-SLOW-REOPEN: from shut, reopen over 5 s to 140°. PASS if the run resumes only on the 669×951 canvas,
    after `resumed angle ≥ 95`, with no bite in 2 s.
  - Add a `pose=book` frame.
  - Re-shoot the slam so the CREAK accent is visible.
- **`ci/scenarios.txt`:**
  - Fix the mislabelled lesson frames 04–07, so each frame shows its step.
  - Golden: a real golden chest (check that `golden=1` produces one).
  - Relic: freeze on the relic card.
  - Large Dynamic Type frames for Results, Codex and Settings (`-UIPreferredContentSizeCategoryName
    UICTContentSizeCategoryAccessibilityL` or the XXL launch argument).
- **Store pipeline:** adapt Swoop's `store.yml`, `ci/store-capture.sh`, `ci/store-frame.swift`, `ci/store-set.sh` and
  scenario lists for Hush (6.9" iPhone set plus a Duo set).
  - Captions ≤ 6 words, from `docs/appstore/screenshots.md`.
  - Truthful frames only, from real demo states.
  - Manual trigger.
- **A docs grep in `ci.yml`** (non-fatal warning): "torch" in `docs/appstore/*.md`, `docs/*.html` or
  `asc-metadata.json`.

## Launch lead
- **QA-2 P1-2:** regenerate every store, Game Center and review text from the code as it is now:
  - `Hush/Core/Ranks.swift` `Achievements.all` (titles, details, thresholds; the ids are unchanged);
  - `Tuning.swift` (10 s bite, 6 s oil, 70° pause, ≥ 95° held still to resume);
  - "candle", not "torch";
  - "Freeze!" as the app shows it;
  - the Hush Chain, golden mimics, the relic glimmer and the bag jingle described truthfully.
- Update `docs/appstore/*.md`, `asc-metadata.json`, `review-notes.md`, the site pages and `LAUNCH-RUNBOOK.md` §4
  (the device test script: use `design/panel/REVIEW-2-duo.md`'s 15 steps).

Every engineer: write `design/notes/<role>-R3.md`. Don't commit.

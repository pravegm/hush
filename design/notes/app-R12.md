# App engineer, Round 12: the lid IS the chest (28 Oct)

Source: `design/ROUND-12.md` (rules 1–7, App section), the coordinator's relays of CI's asks (`design/NEEDS.md`, CI R12)
and Core's hooks (`design/notes/core-R12.md`). Nothing compiled here (CI is the compiler). Nothing committed.

**Files**
- `Hush/App/`: `AppRulesR12.swift` (new: `lidOpenLine`/`lidReadsOpen`, `asksToOpen`, `hintTraceLine`,
  `allowsCloseForNext`, `feedbackPlays`, `DemoBagPlan`), `GameController.swift`, `LessonScript.swift`, `AppRules.swift`,
  `AppModels.swift` (`HUDState.lidOpen`, `FixedLidSource.startsOpen`), `DemoMode.swift`.
- `Hush/UI/`: `PlayHUD.swift` (`HushCopy`, `HintLine.lidOpen`), `HomeView.swift`.
- `HushTests/AppTests.swift`: `R12Tests` (13 tests) and a `DuoHand` helper; 9 old expectations follow the copy.
- `ci/scenarios.txt` (frames 53–55, captions 09 and 39), `design/NEEDS.md`.

## The model, App side
- **"Open" never shows over an open lid.** The HUD carries `lidOpen` (openness > 0.15, the shut zone's edge) and the
  words follow it at render time, so even a hint the gate is still holding re-words itself:
  - `.openSlowly` with the lid up (Core asks while nothing is lit yet): "A little wider… slowly".
  - Run banner: "Candle lit. Open it gently." only while closed, else "Candle lit. Gently does it." (re-chosen every
    frame of its 2.6 s, and the first frame already uses the hinge's last lid).
  - Home: "Lift the lid… slowly." only at openness ≤ 0.15 (was 0.3), else "Shh… something's peeking."
  - Lesson (rule 7): step 1 open → "Close the lid to start" (marker "Close the lid a little"); step 2 closed → "Now
    open it… slowly. Watch the noise.", up → "Keep going… slowly. Watch the noise."; Core's lesson gate
    `.easeLidDown` → "Close the lid a little first(.)"; step 5 → "Close the lid to bank it."
  - `R12Tests.nothingAsksToOpenAnOpenLid` sweeps every hint, banner, lesson step × angle × hint, lid marker and Home
    caption at openness 0.16…1.
- **Bank = close the lid** (rule 3): `.shutToBank` "Close the lid to bank" (phone unchanged), stakes row "Close the lid
  to bank it", Results' empty-run story "Close the lid to bank your loot."
- **`.closeForNext`** (rule 4): "Close the lid for the next chest" on a fold (the founder's 7 words; `wordLimit` lets
  this one hint have 7). On a phone "Slide it down for the next chest": the brief's "Slide the lever down for the next
  chest" (8 words, 39 characters) estimates at ~0.70 of full size on a 393–402 pt phone's plate, exactly the
  truncation line; `R12Tests.theRobbedChestLineFitsItsPlate` measures both. Not a warning, never retires. Shown only
  while `session.awaitingClose`; a gate still holding it is cleared the frame the next chest is dealt, so it can never
  follow a bank (CI's ask 4; Core deals the post-bank chest "seen shut").
- **Every run start with the lid up opens at once** (rules 2, 6): Play, Daily, Again, Restart and Restart from the menu
  all go through `start()`, which never holds when a hinge is known (`closingAwaitsHinge` only without one). Core does
  the rest. `R12Tests.everyRunStartWithTheLidOpenOpensTheFirstChest` drives all five on a simulated hinge at 150°.
- **Fresh chest / closing pause** (R7 interplay): Core's `isFreshChest` is now any non-lesson `.ready` chest except the
  robbed one, so a full fold after a bank (the bank fires on the way down; the next chest is dealt during the bank
  moment, under the lid) pauses on "Lift the lid for the next chest" and resumes on the lift, never "Hold still…".
  Tested end to end with a real drag, bank, fold to 30° and a 40°/s reopen (`aFullCloseAfterABankReopensIntoTheNextChest`,
  which also checks the next `chestArrived` came at ≤ 113°), and the same after a bite (`aBiteWaitsForTheClose…`).
- **Core hook 1, `noteLidShut()`:** called when the closing pause engages, whenever a closing card is up and the hinge
  reads ≤ 110° (covers a menu Resume's hold followed by a fold), when the cover display takes over (handover to the
  small canvas, pose `.cover`) and when the Duo is shut (≤ 10°). Never from a hold made with the lid open. Logs
  `HUSH-T next chest dealt under the pause reason=…`.
- **Core hook 2, the snore over the robbed chest:** Feedback has no snore-only switch and the Feel engineer owns that
  file, so while `awaitingClose` the App sends `playing: false` (`AppRules.feedbackPlays`). Side effect: the creak and
  candle tick are quiet during the close too. Asked Feel in NEEDS for `setRobbed(_:)` if they want those back.

## Demo / CI
- `HUSH-T hint <rawValue|none>` on every change of the chosen hint, before a scene callout hides it.
- `bag=<n>` (field `bagItems`): synthetic touches (ids from −9000) bag n lit items of chest #1 on its first looting
  steps at ~100 pt/s; `HUSH-T demo bag <n> value <v>`. Not in the lesson.
- `noiseUntil=bite`, `startOpen=1` (field `opensAtStart`), `HUSH-T first chest phase=… openness=…`.
- Frames: 53 start-open (`lid=0.8;startOpen=1`), 54 the closed cover (`lid=0`), 55 the robbed chest
  (`lid=0.7;startOpen=1;noise=1;noiseUntil=bite;freezeOn=bite;freezeDelay=3.4`), all `fold=1;turn=0`.
- Test hooks on `GameController`: `nudgeSessionNoise(to:)`, `awaitingClose`.

## Risks / to check in the next CI run
- The controller tests lean on Core's R12 rules and on the hinge filters' timing (60 Hz simulated frames, a report every
  other frame). If one fails on timing, widen its holds before doubting the rule.
- Frame 55's hint can still sit under the scene's bite callout if that lasts past 3.4 s after the bite; the expect line
  (`HUSH-T hint closeForNext`) passes either way.
- "Close the lid to bank it" and "Close the lid to pause" now share the Duo's stakes card: both true (the bank fires at
  ≤ 110° on the way down, the pause under 70°), but it reads as one gesture doing two things. UX may want one line.
- `playing: false` over the robbed chest also silences the closing creak there (see hook 2).

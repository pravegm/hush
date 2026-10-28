# App engineer, Round 11 hand-off: last polish before launch (28 Oct)

Source: `design/ROUND-11.md` (App items 1–9), `design/panel/REVIEW-5-ux.md`, `design/QA-6.md` (P2-1…P2-5, P2-10),
`design/fresh/tester11-phone.md`, `design/notes/scene-R11.md`. Nothing compiled here (CI is the compiler). Nothing
committed. R6–R10 behaviour is kept: quarter turns, never-stuck (Carry on, the watchdog, the cover escape), the pause
seat's single source of truth, the masks and holds.

**Files**
- `Hush/App/`: `AppRulesR11.swift` (new: every R11 pure rule), `AppRulesR7.swift` (Strict, the detail line),
  `AppRules.swift` (cause line), `AppModels.swift` (`ResultSummary.offersForgiving`), `LessonScript.swift`,
  `GameController.swift`, `DemoMode.swift`.
- `Hush/UI/`: `PlayHUD.swift`, `Pages.swift`, `ResultsView.swift`, `HomeView.swift`, `PoseCards.swift`,
  `HushTheme.swift`, `AchievementArt.swift`.
- `Hush/Persistence/SettingsStore.swift`.
- `HushTests/AppTests.swift`: `R11Tests` (19 tests); 4 old expectations follow the intended copy changes (Home phone
  caption, lesson step 5 twice, "Strict").
- `ci/scenarios.txt` (frames 48–52, 5 captions), `design/NEEDS.md`.

## The 9 items
1. **Forgiving is findable.**
   - Each option has its own line under the pills (bold name, then the line; the chosen one in parchment), and the
     same line is that pill's VoiceOver hint (`SettingChoice(optionLines:)`, `AppRules.sensitivityLine`):
     - Forgiving: "For a stiff hinge or shaky hands. Easier to stay quiet."
     - Normal: "If it wakes while you're being gentle, try Forgiving."
     - Strict: "For thieves who never creak."
   - The row's own line is the scored Daily line alone.
   - **"Careful" is "Strict"** (display only). Core's `LidSensitivity.careful` and its raw "careful" are untouched, so
     every save reads as Strict. `SettingsData.sensitivity(stored:)` also accepts "strict"; anything else is Normal.
   - **The Results nudge** (`AppRules.offersForgivingNudge`): at Normal only, ≥ 3 bites, one of the first 2 runs
     (counted after this one is filed), never the scored Daily, the lesson or attract, once ever
     (`seenTips["forgivingTip"]`, marked when offered). It is a parchment plate under the cause line ("Keeps waking? Try
     a forgiving lid.") with a leather **Make it forgiving** (`GameController.makeLidForgiving`), which turns into
     "Forgiving on. Change it in Settings."
2. **A first Skip goes to the stakes card.** `LessonScript.skipToStakes()` jumps to `.done` with no praise. The card's
   title is "Here's the gist, little thief." (`LessonDisplay.gist`, `finalCardTitle`, VoiceOver too). "Got it" starts
   the first run; "Not yet, take me home" goes Home. A replay's Skip still goes Home. On a Duo's full floor the card has
   a fourth row, **"Close the lid to pause"** (`LessonFinalCard.rows`). It is left off phones and tight fold floors: the
   phone's 08 card is 389 of its 403 pt floor, and a row is about 38 pt.
3. **Frames.** `ci/scenarios.txt` 48 pose tip (`screen=pose;fold=1`), 49 "Hold to pause" (new `hint=holdToPause`: ring
   half full plus the plate), 50 "Already open?" (new `midRun=1;escape=1`), 51 the closing card with Carry on at AX-XXXL
   (`hold=closing`), 52 Results with the nudge. duo.sh lines are suggested in NEEDS (not my file).
4. **Copy.**
   - Phone Home said "Slide its lid up… slowly." because of `HomeView.caption`'s phone branch. It now uses
     `HomeView.phoneCaption` = "Slide the lever up… slowly.", word for word the lesson's step 1 (tested against it and the
     run's hint).
   - `.easeLidDown` / lesson step 2: "Lower the lid a little first".
   - The pose step's `.lower`: "Lower the lid a little, nearly upright…".
   - Step 5: "Ease the lid back upright to bank it." (one "to"; UX's "back to upright to bank" still had two).
   - Cause line: "The mimic bit you 5 times, and your candle burned out."
5. **"Hushed!" vs "0 Hushed": not a bug.** The scene's eyebrow shows only on `bankHushed` (`banked(hushed:)`), and
   VoiceOver's line is the same. The ci19s logs: 07b `banked value=119 … hushed=1` and 14 `value=197 … hushed=1` (perfect
   pilot); 19 is `pilot=novice` with 5 bites and no Hushed bank. These were different runs. A test pins the copy.
6. **VoiceOver.**
   - The closing card posts `.screenChanged` with its title.
   - Carry on and the cover card's escape announce "Carry on is ready." (or "Already open? Home is ready." in menus) and
     take VoiceOver focus (`@AccessibilityFocusState`).
   - The pause coin's hint is "Pauses the chest".
   - A Hushed bank that raises the chain says "Hushed! Banked 197 gold. Hush Chain, times 1.1."
     (`GameController.chainMultiplier(in:)`).
7. **Duo Settings.** "Play sound on silent" now heads the floor card. The lid group is Sound, Vibration and Lid
   sensitivity. Estimate from duo12: about 377 of 411 pt, so it fits only if each option line stays on one line at the
   default size. On a phone the row order is unchanged.
8. **QA-6 P2s.**
   - P2-1: `debugStateLine` reads the scene's raw-touch counters only `#if DEBUG`. The Scene engineer has gated the
     counters themselves too.
   - P2-2: the 3 s re-subscribe is unchanged, but "Move the lid a little" waits 1 s more for a report
     (`closingSilenceRefresh` / `closingSilenceCopy`).
   - P2-3: the cover card re-subscribes a silent hinge once at 3 s (`coverSilenceCheck`).
   - P2-4: `PageScaffold` is one accessibility container, with the lid half at sort priority 2 and the floor half at 1.
   - P2-5: while a system sheet is up, menus don't hold (`AppRules.menuHoldCountsMenus`), and the hold is judged again
     when the sheet goes (`systemSheetUp` didSet).
   - P2-10: as in item 6.
9. **Results fade.** `FadingScroll`'s fade is 56 pt (was 36, cap 35 %) and steeper (35 % opacity by its middle). The
   chevron is larger, heavier and fully opaque.

**Scene R11 wired (founder):**
- `ChestScene.calloutActive` hides the hint plate's hint. Our own callouts (the bank's Hush Chain tip, the golden
  banner) stay, because the scene keeps its stack 12 pt under the plate.
- `PlateArt.calm` is `ChestArt.praiseInk(.parchment)` ("Banked!", "Phew…", "Hold it there…").
- `AchievementBadge` draws `ChestArt.badgeImage` (falling back on `BadgePainter.paint`), as do the Badges page,
  Results and the `screen=badges` 1024 export. `BadgePainter.paint` uses `badgeGlyphArt` (Heavy Bag is a sack).
- `hintPlateCanvasRect` is left nil: the plate hugs its text, so the scene's tallest-plate estimate is the safe floor.

## Risks / to check in the next frames
- **The Duo Settings lid group** is an estimate: check duo-ui-settings (and 24, 43, 47 on the phone).
- **`R11Tests.theStakesCardSaysHowToPause`** hosts the Duo's four-row card. It should come to about 427 of 441 pt; if
  CI shows it over, drop the row there too.
- **Frame 19 now shows the nudge as well** (fresh, novice, 5 bites), which is correct, and its caption says so.
- **Hiding the hint during `calloutActive`** also hides "Freeze!" for CREAK!'s 0.7 s and the next chest's opening hint
  under "Next chest…".

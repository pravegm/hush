# Review 5: UX, clarity and onboarding (senior game UX lead)

*Inputs: my REVIEW-4-ux.md (8.9), ROUND-6.md, ROUND-7.md, `design/notes/app-R6.md`, `app-R7.md`, `app-R8.md`, `r10.md`.
Code read: `Hush/UI/PlayHUD.swift` (HushCopy, ClosingCard, LessonOverlay, LessonFinalCard, PauseCoin), `PoseCards.swift`
(PoseTip, CoverCard), `Pages.swift` (Settings, SettingChoice, PageScaffold), `Hush/App/AppRulesR7.swift`,
`LessonScript.swift`, and `GameController` (carryOn, the closing watch, announce, skipLesson). Frames: `artifacts/ci19s/01–47`
and logs; the Duo-sim set `artifacts/duo11/duo-screens` for the closing card, Settings and pose (the only place they are
drawn). I didn't edit any file except this one.*

## Score: 8.8 / 10. Verdict: launch-ready on clarity: **yes, after the three P1s below (all copy or flow, each < 1 day)**

The founder's dead end is gone. The fix is structural, not a better card. Nothing blocks on orientation now. Every
overlay has a way back (`everyOverlayHasAWayBack`). The closing card grows a big **Carry on** after 3 s, and the
watchdog covers a player who never taps it. The cover card says "Already open?" when the hinge disagrees. Carry on
can't trap anyone: a lid that really is low just plays on at a low angle, because the card only comes back on a new
closing motion. Banking copy no longer says "shut", so nobody is told to fold the Duo closed.

R4's P1s are fixed:
- 39: the final card fits on the fold, with "Not yet, take me home" whole.
- 44: Home at AX-L is one tile per row, with a chevron.
- 43 and 47: Settings pills stack at AX sizes and stay whole at XXXL.

The 0.1 drop is about the new controls. Mechanically they're right. But one of them can't be found by the players who
need it (Forgiving). One drops a struggling first-timer onto Home with nothing taught (Skip). And none of the new
mechanisms has been seen in a frame: no pose tip, no "Hold to pause", no "Already open?", no Duo Settings from the R10
build.

## Are the new mechanisms self-explanatory?

| Mechanism | Verdict | Why |
|---|---|---|
| Press-and-hold pause (Duo, mid-chest) | ✅ | A tap says "Hold to pause" for 1.6 s and a gold ring fills while held. Holding also works on the tap coin, so "hold" is never wrong. Not in any frame |
| Carry on (closing card) | ✅ | duo-h3: "Lift the lid a little to carry on" over a primary "Carry on" and a leather "Home". Both paths share one verb. The hint "Resumes the chest now" is right |
| "Already open?" (cover card) | ✅ | Plain question, two obvious answers. Not in any frame |
| Pose tip | ✅ copy / ⚠️ unseen | "Stand it up like a little laptop / Lid up, the floor flat and nearest you." matches lesson step 1 and the diagram's VO label. **No frame anywhere**: duo11 POSE-NO-BLOCK logs `tip: none`, and ci19s 25 doesn't force it (P1-3) |
| Fresh-chest resume | ✅ | "Lift the lid for the next chest" and no "Hold still…". The calmest card in the game |
| Lesson step 1, loose pass | ✅ | "That'll do." after 4 s in 80–125°. Kind, and it doesn't lie |
| Skip after 20 s | ⚠️ | It appears without warning, which is fine, but it goes straight Home (P1-2) |
| Lid sensitivity | ❌ discoverability | The row explains only the option already chosen ("How much noise the lid makes."). Nothing says *when* to pick Forgiving, and nothing in play ever points to it (P1-1) |
| Vibration | ✅ | "Strong suits the Duo." until chosen. Clear |

## Remaining issues

### P0
None.

### P1: fix before the next TestFlight

**P1-1. The players who need Forgiving will never find it.**
The setting exists for exactly the player who is gentle but keeps getting bitten on a jerky hinge (the founder's #1
complaint). That player is in a run or on Results, not in Settings, and the Normal detail line doesn't tell them
anything.
- **Settings copy:** `AppRules.sensitivityDetail` describes the choice and says when to switch:
  - Normal: **"If it wakes while you're being gentle, try Forgiving. The scored Daily always plays Normal."**
  - Forgiving: **"Small jolts from the hinge make less noise. The scored Daily always plays Normal."**
  - Careful: **"Every creak counts for more. For steady hands. The scored Daily always plays Normal."**
- **In-game nudge (one time, Results only):**
  - **When:** sensitivity is Normal, the run ended in a bite, it's one of the player's first 5 runs or the second
    bitten run in a row, and the tip hasn't been shown (`seenTips["forgivingTip"]`).
  - **What:** a parchment line under the cause line, **"Keeps waking? Try a forgiving lid."**, with a small leather
    button **"Make it forgiving"**. The button sets `.forgiving` and swaps the line to **"Forgiving on. Change it in
    Settings."**
  - **Never** on the scored Daily.
  - **Test:** the rule fires once and never fires at Forgiving or Careful.
- **VoiceOver:** give each pill its own `accessibilityHint` (the matching first sentence above). Today a VO user hears
  only "Lid sensitivity: Forgiving" and has to select an option to find out what it does.

**P1-2. Skip on a first lesson drops the player on Home with nothing taught.**
- `skipLesson()` marks the lesson done and calls `goHome()`.
- The 20 s Skip is offered precisely to the player stuck at step 1. They never see the stakes card (candle, bite,
  bank) or "Hold to pause", tap Play, and get bitten without knowing why.
- **Fix:** when `!lessonReplaying`, Skip goes to the **final stakes card** (`LessonFinalCard`: "Got it" → first run,
  "Not yet, take me home"), with the title **"Here's the gist, little thief."** instead of "Lovely work…", which it
  hasn't earned. A replay's Skip stays Home.

**P1-3. The new controls have never been seen in a frame.** Each R1–R4 regression was caught only from frames, so this
is a clarity risk, not a CI nicety.
- ci19s 25 runs `screen=home;progress=mid;fold=1`, so it shows Home with no tip. Use the DEBUG `screen=pose` key
  (app-R6), which forces the tip.
- Add demo keys and frames for:
  - **Hold to pause**: `hint=holdToPause` shows the beside-coin plate, and a frame shows the ring half full.
  - **Cover "Already open?"**: `screen=cover;midRun=1;escape=1`.
  - **The closing card with Carry on at AX-L** on the fold floor.
- **Re-shoot duo-ui-settings on the R10 build.** The duo11 frame still shows the pre-R10 layout: the title alone on
  the lid half, with "Play sound on silent" fading on the floor. The split (feel rows on the lid, the rest plus Done on
  the floor) is unverified, and so is the founder's About › Version path.

### P2: polish

**P2-1. VoiceOver for the never-stuck cards.**
- No announcement or focus move when the closing card appears, when Carry on appears, or when "Already open?"
  appears. Only the cover pose posts `.screenChanged`. The pause coin hides, so VO focus is left on nothing.
- **Fix:**
  - On `setClosing(true)`: `.screenChanged` with the card's title.
  - When `closingEscape` or `coverEscape` turns true: `.layoutChanged` with the Carry on button, and announce
    **"Carry on is ready."**
- **The pause coin's hint is wrong under VO.** "Press and hold to pause", but VO's double-tap pauses at once. Under
  VoiceOver use **"Pauses the chest"** (or no hint; it has the button trait).

**P2-2. One phrase, two meanings: "Ease the lid down…"**
- `.easeLidDown` says **"Ease the lid down first"**: get under 110° before looting.
- The bank hint says **"Ease the lid down to bank"**.
- A player told "Ease the lid down first" at the start of a chest has just been taught that this phrase banks.
- **Fix:**
  - `.easeLidDown` → **"Lower the lid a little first"**.
  - Lesson pose `.lower` → **"Lower the lid a little, nearly upright…"** (today it says "Close…", the only "close" left).
  - Lesson step 5 → **"Ease the lid back to upright to bank it."** (today: "down to upright to bank", two "to"s).

**P2-3. Sensitivity is invisible outside Settings.**
- Results under Forgiving or Careful: add a caption in the stats block, **"Forgiving lid"** / **"Careful lid"**, so a
  best score has context.
- Daily page: when the setting isn't Normal, the "Your scored try is ready" card adds **"Your scored try plays a
  Normal lid."** Otherwise a Forgiving player's Daily suddenly feels harsher with no reason given.

**P2-4. Dynamic Type on the closing card.**
- `ClosingCard` is a fixed, centred plate with no scroll or fitting fallback. At AX sizes, with Carry on and the
  Daily line, it can overrun the card area on a fold.
- **Fix:** `ViewThatFits`:
  1. the full card;
  2. then without `DuoDiagram` and the detail line;
  3. then `FadingScroll(anchor: .bottom)`, so Carry on and Home stay whole.
- The "Hold to pause" plate is fixed 16 pt × canvas scale. That's acceptable for an in-world plate, but let it
  `minimumScaleFactor(0.8)` rather than run off a narrow floor.

**P2-5. Carry-overs from R4 still open in code:**
- The VO bank line still omits the chain. "Hushed! Banked 197 gold." → **"Hushed! Banked 197 gold. Hush Chain, times
  1.1."** when `chainUp` fires.
- The final stakes card doesn't mention pausing. On a Duo, a fourth row, **"Hold the coin to pause"**, fits on the
  non-tight card. Skip it on `tightFloor`.

## Copy consistency check (the R6–R10 strings)
- **"Carry on":** cover title "Open to carry on", closing title "Lift the lid a little to carry on", both buttons
  "Carry on", hint "Resumes the chest now". Consistent.
- **Banking:** "Ease the lid down to bank" in the hint, the stakes card and the empty story; the lever variants on
  phones. Consistent. The one clash is P2-2.
- **"Laptop":** "Stand it up like a little laptop" (tip), "Stand your Duo like a little laptop." (lesson), and "The Duo
  stood like a little laptop, lid raised" (VO). Consistent.
- **"Candle":** cover "Your candle waits", closing "Your candle does too", VO "Your candle is low." Consistent.
- **No "shut" anywhere** in fold copy (tested).

## First session on a Duo
1. Launch. Game Center now waits until after the lesson (good: no banner over step 1).
2. Lesson step 1, any orientation: the tip shows if the Duo is held like a book. It passes in ≤ 4 s for any sensible
   laptop angle.
3. Steps 2–5 are unchanged and still the best thing in the build.
4. The stakes card (39), then the first run.
5. Folding to bank → "Lift the lid for the next chest", with no stillness wait.
6. An accidental fold → the closing card. After 3 s: Carry on and Home.

The only path a player can get lost on is the step-1 Skip (P1-2). The only frustration loop with no exit offered is
repeated bites on a jerky hinge (P1-1).

## Strengths (keep these)
1. **Never stuck is designed, not patched:** the escape in the card, the watchdog behind it, and a test per overlay.
2. **The copy got kinder without getting vaguer:** "That'll do.", "Lift the lid for the next chest", "Already open?".
3. **"Hold to pause" teaches itself** on the first wrong tap, and costs a phone player nothing.
4. **Settings at every size** (24, 43, 47): pills stack at AX sizes, nothing truncates, and the fade appears only when
   there's more to see.

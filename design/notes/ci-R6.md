# CI engineer, Round 6 hand-off (27 Oct)

**Files changed:**
- `ci/duo.sh`: the R6 helpers (a line clock and quarter-turn parsing) and three new checks at the end of the hinge
  pass: FLAT-OPEN, WATCHDOG, LANDSCAPE-PLAY.
- `HushUITests/TurnedDragUITests.swift`: the drag is now a shared helper, and there's a new
  `testLandscapeTurnedDragBagsALitItem`. The portrait test is unchanged in behaviour.
- `.github/workflows/ci.yml`: the "Turned drag" step reports both tests, one summary line each.
- `.github/workflows/duo.yml`:
  - a new non-fatal step, "Landscape drag on the Duo (UI test)", with input `uitest` (default on);
  - the job timeout goes 150 → 180 min, and the Capture timeout 80 → 90 min.
- `design/NEEDS.md`: a "CI engineer (R6)" section appended.
- `project.yml` is unchanged: the UI target's sources are the whole `HushUITests` folder.

**Status:** nothing has run and nothing is committed.
- `bash -n` passes on every `ci/*.sh` and on every `run: |` block of ci.yml and duo.yml (extracted, with `${{ }}`
  stubbed out).
- I tested the new helpers on a synthetic log written live by a background writer. They are `clock_start`/`clock_stop`,
  `lid_gap`, `pause_spans`, `angles`, `openness`, `canvas_k`, `k_odd`, `canvas_full_before`, `ge`/`le`/`fsub`. The test
  covered a 1.5 s pause with a resume, a pause still open at the window's end, and canvas lines with and without `k=`.
- No YAML parser is available on this machine. I checked the workflow edits by eye: no tabs, and indentation matches the
  neighbouring steps.

## The line clock (why, and how)
- **Why:** the app's `HUSH-T` lines carry no time. `HUSH-H` lines have the app's clock, but they stop whenever the hinge
  is still. A rule like "no pause > 1 s" or "within 8 s" needs wall time.
- **How:** `clock_start <log>` runs a background perl loop (Time::HiRes, a core module on macOS). Every 0.2 s it appends
  `<epoch> <line count>` to `<log>.clock`. `clock_stop` kills it and adds one exact final sample.
- **Reading it:** `line_time` maps a line to the first sample that contains it, which is at most 0.2 s late.
- **The clock files are evidence:** `logs/flat-open.txt.clock` and `logs/watchdog.txt.clock` ship in the artifact.
- **If perl fails** (fewer than 5 samples):
  - FLAT-OPEN judges on line counts instead: ≥ 15 lid lines in the 3 s hold, ≥ 7 in the 1.5 s after, and every pause
    resumed.
  - WATCHDOG passes on a resume found inside its wiggle loop.
  - Both say so in the detail.

## The checks (ROUND-6 "CI engineer" 2)
| Check | Run | PASS | FAIL | INCONCLUSIVE |
|---|---|---|---|---|
| FLAT-OPEN | attract, 140 → 180 (4 s), still hold 3 s, → 140 (4 s), +1.5 s | lid lines never stop for > 1.2 s, no pause > 1 s, no slider switch, ≥ 3 lid lines after the return | any of those broken | the logged angle never reached 170°, twice |
| WATCHDOG | attract at 130, → 60 (5 s) + a 1° wiggle (pause), → 130 over 14 s, then 1° wiggles | `HUSH-T resumed` / `HUSH-T watchdog resume` ≤ 8 s after reaching 130 (on the way up counts too) | resumed while still at 60; paused, reopen arrived (≥ 95° logged), no resume in 8 s (**STUCK**); no pause although the log went ≤ 65° | the close (nothing ≤ 70°, after one more try) or the reopen (nothing ≥ 95°) never arrived |
| LANDSCAPE-PLAY | `orient=landscape`, NO portrait ask, hinge 105 → 160 (7 s) | no `pose standUp`, no `paused pose`, k odd, lid angle range ≥ 30° and openness range ≥ 0.2, `lidCracked` | any of those broken (k even in landscape included) | the tool never delivered ≥ 150°, twice; the sim never reached landscape (no `orient landscape ok`, no odd k, no landscape frame); or k unreadable (no `k=`, portrait-shaped size) with all else passing |

New frames:
- `duo-h9-flat-open-after`;
- `duo-h10-watchdog-after`;
- `duo-h11-landscape-play-160`. Its raw capture must be LANDSCAPE, with the chest drawn sideways: lid on the raised half.
  That is correct for the player. Eyeball it.

All three checks run after the timed windows, so no shot falls inside a window.

The hinge-tool lessons are kept:
- Every move is a 60 Hz `sweep`.
- 1° wiggles run before each window, so samples are flowing.
- Each check retries once when the logged angles show the move never arrived.
- A twice under-delivered move is INCONCLUSIVE, never FAIL. INCONCLUSIVE never trips STRICT=1.
- Every check has its own launch.
- All existing checks are unchanged.

Decisions to know:
- **The 3 s hold at 180 is perfectly still,** with no wiggles. That's the real case: a Duo lying flat sends nothing, and
  the App must keep the last angle and the hinge input. The return is a slow 4 s sweep, so the R4 "fast move after a
  still hold" failure can't apply.
- **The lid-gap limit is 1.2 s:** the 1 s rule plus the clock's 0.2 s grain. It's `FLAT_GAP_MAX`. The pause rule is
  exactly 1 s, as the brief says.
- **"The tool's slowest step":** `hinge` has no step-size option, only `set` (a jump) and `sweep` (60 Hz). So the
  slowest reopen is a long sweep: 14 s for 70°, about 5°/s (`WATCHDOG_REOPEN_S`). Then 1° wiggles, so the lid is never
  perfectly still for the resume gate. That's the case where only the watchdog can rescue the run.
- **LANDSCAPE-PLAY runs last in the hinge pass,** since it leaves the sim landscape. Afterwards the portrait wait goes
  back to 25 s if portrait ever worked, so the frames pass isn't shot sideways.
- **FLAT-OPEN also reports, without judging:** the count of lid lines whose angle is `-` (hinge nil at 175–180°) and the
  angle after the return.

## The landscape XCUITest (ROUND-6 "CI engineer" 1)
- **Demo:** `screen=run;mode=attract;seed=7;lid=0.9;turn=1;fold=1;orient=landscape;quarter=3`.
- **Device rotation:** `XCUIDevice.shared.orientation = .landscapeRight`.
- **Why not `.landscapeLeft` as the brief wrote:** UIDeviceOrientation and UIInterfaceOrientation name the landscapes
  oppositely. Device `.landscapeRight` is interface `.landscapeLeft` (home edge on the left). ROUND-6's table gives k = 3
  for that with turn round on, so the rule and `quarter=3` agree. With device `.landscapeLeft`, the rule would give k = 1.
  That's still odd, but it isn't the k the brief asked for.
- **`tearDown`** puts the device back in portrait.
- **Can the sim rotate?** XCUIDevice can rotate a phone sim, but the App may not give a `fold=1` phone a landscape
  interface. So `quarter=3` (asked in NEEDS) is what forces k there, and `orient=landscape` covers a sim that does rotate.
- **Odd k is only checked once the App adds `debug.canvas`.** If that element reports an even k, the test SKIPS rather
  than passing on a portrait layout. Until it exists, the drag runs and the window size is attached.
- **Where it runs:**
  - in ci.yml on the iPhone 18 Pro, with both tests in the summary;
  - in duo.yml on the real Duo sim, after the capture, with `-only-testing` this test only. That's the one place a true
    landscape interface is proven (R3 POSE-CARD).
- **On the Duo, an open question:** does XCUIDevice rotation work on the Duo sim? If it doesn't, `orient=landscape` still
  gets the landscape interface there.

## Asks (in NEEDS)
- `k=` at the end of the canvas line.
- The `quarter=` key.
- The `debug.canvas` element.
- Frames after the turn.
- The watchdog log wording.
- The POSE-CARD expectation now that the card no longer blocks.
- Optional: `HUSH-T hint tooWide`.

**The watchdog's "no hinge sample for 4 s" branch.** On the sim a still hinge sends no samples. So the brief's rule alone
would resume a lid resting CLOSED at 55–60° after 6 s, and CLOSE-PAUSE's 15 s shot at 55° would catch exactly that. The
App's in-progress `AppRules.watchdogResumes` already guards it: a silent hinge under `Tuning.closingAngle` stays paused.
NEEDS asks the App to keep that guard. If it goes, CLOSE-PAUSE's detail will show a resume at 55°.

## Risks
1. **Timing on the runner.** Each `hinge` call has start-up overhead, so a wiggle takes about 1–2 s, not 0.8 s. WATCHDOG's
   loop can overrun 8 s by one wiggle, but the verdict uses the line clock, not the loop. The three checks add about
   6 min; the capture timeout is now 90.
2. **The frames don't capture "That's wide enough".** FLAT-OPEN proves the run kept playing at 180°, not that the hint
   showed (no log line for it yet).
3. **POSE-CARD may FAIL by design** once the App's R6 removes the blocking card. That needs the App's answer.
4. **The duo.yml UI step costs a build-for-testing** of about 10–15 min. Untick `uitest` to skip it.

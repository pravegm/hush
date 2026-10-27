# CI engineer, Round 1 hand-off (27 Oct)

Files: `.github/workflows/ci.yml`, `duo.yml`, `testflight.yml`, `tf-status.yml`; `ci/screenshots.sh`,
`ci/scenarios.txt`, `ci/duo.sh`.
- They are adapted from Swoop, which is proven on the `xcode-27` runners. The Duo orientation approach comes from Brim.
- Nothing has run yet. The repo is private, and Actions are blocked by billing until the founder makes it public.
- `asc.yml` in the same folder belongs to the store/ASC engineer. I didn't touch it, but ci.yml now feeds it (see
  "badges" below).

## ci.yml (push to main on Hush/**, HushTests/**, project.yml, ci/**, the workflow; or run it manually)
- **Input:** `filter`, a regex on scenario names (default `.`), e.g. `fold`, `^1[0-6]-`.
- **Steps:**
  1. Xcode 27.1 and XcodeGen.
  2. `xcodebuild test` on the "iPhone 18 Pro" simulator, with `TEST_RUNNER_HUSH_BAL_SEEDS=8`. The test process sees
     `HUSH_BAL_SEEDS`.
  3. On failure, `errors.txt`.
  4. A **Balance table**: the `HUSH-BAL` lines in the job summary.
  5. A **demo-guard positive control** (see testflight).
  6. `bash ci/screenshots.sh`.
  7. **Render the app icon** (non-fatal):
     - Launch `-hushDemo "screen=icon"` with `HUSH_ICON=1`.
     - Read `HUSH-ICON <path>`, falling back to `Documents/AppIcon-1024.png`.
     - Copy it to `ci-screens/app-icon-1024.png`.
     - Warn if it isn't 1024×1024 or has alpha.
- **Artifacts:**
  - `logs`: build.log, errors.txt.
  - `screenshots` (`ci-screens/`):
    - `<scenario>.png`;
    - `logs/<scenario>.txt` and `.at-capture.txt`;
    - `captures.tsv` (name, ok/launch-failed/screenshot-failed, WxH, froze/no-freeze, expect-ok/expect-miss);
    - `device.txt`, `app-icon-1024.png`, `badges/`.
  - A per-scenario table goes in the job summary.
- **Gate:** only build and tests fail the job. Frames, the icon and expects never do.

## ci/scenarios.txt (`name|demo args|wait|caption|expect`)
33 frames:
- Home fresh/mid.
- Lesson steps 1–6, phone texts, with `lid=` holding each step still.
- Run frozen on `ready`, `reveal`, `stirring`, `waking` and `bite` (novice), `bank`, `relic` (expert, `skipTo=25`) and
  `torchLow` (`skipTo=75`).
- Static stage frames (`lid`/`noise`).
- Results fresh/mid/late.
- Codex mid/late, Settings, pose, Daily, cover.
- `fold=1` frames: Home, reveal turned, reveal with `turn=0`, waking, lesson 1.
- `40-badges`.

How waiting works:
- `freezeOn=<tag>` waits for `HUSH-T freeze <tag>` (up to max(wait, 60) s), then 2 s. The tag regex allows camelCase
  (`torchLow`).
- `expect` is a log regex checked at capture.
- Unsettled shots are re-taken up to 3 times: under 80 KB, or landscape without `orient=landscape`.

The **pose** card is portrait on the phone, because there is no CLI rotate on a phone sim. The real landscape card is
the Duo's `duo-ui-pose-book`.

## duo.yml + ci/duo.sh (manual)
**Inputs:**
- `passes`: `hinge frames ui`.
- `orient`: `portrait`.
- `strict`: false. If true, a FAIL fails the job.

**Steps:**
1. Install the iOS 27.1 runtime (3 tries).
2. Create and boot the "iPhone Duo".
3. Install `hinge` (3 tries; the job stops if it is missing).
4. Build for the Duo and warm up the hinge helper.
5. Capture.

**Artifact `duo-screens`:**
- PNGs (the lit panel);
- `raw/` (both panels);
- `logs/run.txt` (the PASS/FAIL lines) and `logs/<launch>.txt`;
- `checks.tsv`;
- build.log.

The checks table also goes in the job summary.

**Checks** (each a `<CHECK> PASS|FAIL (detail)` line):

| Check | How | PASS |
|---|---|---|
| PORTRAIT | Shot of the inner display right after the launch at 105° | The PNG is taller than wide |
| SLOW-OPEN | 105°, `screen=run;mode=attract;seed=7`, sweep 105→160 over 7 s | `event lidCracked` and max `noise` < 0.35 |
| STILL | Same launch: 1.5 s hold at 160 | The last `speed` in the hold < 1.0 |
| SLAM | `mode=run`: 105→150 over 6 s, hold 2 s, 150→104 in 0.3 s | `event bitten`, `stageChanged … to=waking/biting` or `stage waking/biting` logged since the slam began, read 2 s after the sweep |
| CLOSE-PAUSE | 120→60 over 1.5 s, then back to 120 | `paused closing`, then a later `resumed` |

INFO lines (STILL-RUN, TURNED, COVER, UNTURNED, POSE-BOOK) record the canvas and other evidence, with no verdict.

**Frames:**
- `duo-01-closed-105`, `02-half-135`, `03-wide-160`, `04-cover-shut`, `05-reopened-165` (reopened to 165, because the
  cover stays lit until ~150° when reopening), and `06-half-135-unturned`.
- `duo-h*`: the hinge pass.
- `duo-ui-*`: Home at 120 and 150, lesson 1 and its pose step passing, Results, Codex, Settings, the book-pose card,
  and the cover.

**Orientation:**
- The Duo sim boots in book pose (landscape inner display).
- There is no CLI rotate, and `simctl io … screenConfig` crash-loops SpringBoard (never used).
- So I took Brim's proven route: tabletop launches append `;orient=portrait`, and the app asks for portrait itself
  through DEBUG `requestGeometryUpdate`. That gave Brim 2007×2853 portrait inner frames.
- Launches without the key stay in book pose, and that is how the pose card is shot.

**Carried over from the sister projects:**
- Display names are probed (LCD-1/primary-1/3/internal; LCD/primary/1/external). Both panels are captured, and the
  brighter one is kept.
- `hinge set` has 3 retries, and moves are `sweep`s at 60 Hz.
- 2.5 s settles. No shot is taken inside a timed window (a shot takes ~15 s).
- Every call goes through `to <s>`.

## testflight.yml / tf-status.yml
These are Swoop's, renamed for `com.pravegm.hush` and the Hush product. They keep the same signing path:
- the archive is ad-hoc signed, or unsigned with the entitlements stamped on;
- the export uses Apple's cloud-managed distribution certificate through the Admin API key;
- `check_only` makes an unsigned Release archive;
- `tf-status` lists the build states.

The **demo guard**:
- It fails if the Release binary has `^freezeAfter$` **or** `HUSH-T paused closing`.
- I added it to the upload job too, not only `check_only`.
- Why the second string: Swift keeps literals of 15 bytes or fewer inline in code, so `strings` likely can't see
  `freezeAfter`. ci.yml's positive control warns if the 21-byte literal is missing from the Debug build.

## Known risks / asks
1. **App engineer: add `orient=portrait` to DemoMode.**
   - It doesn't exist today, and unknown keys are ignored.
   - Copy the block from `Brim/App/DemoMode.swift`, around lines 340–385: re-request every 2 s, and log
     `HUSH-T orient portrait ok|failed|lost`.
   - The Duo mask is already `.allButUpsideDown`.
   - Without it, the Duo frames are the book-pose card, PORTRAIT FAILs, and play may sit behind the pose card.
2. **No `AppIcon.appiconset` in Hush/Assets.xcassets**, but `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` is set.
   - actool will likely error on the first build.
   - The App engineer should add a Contents.json (a 1024 slot; an empty one only warns).
   - Later, commit `app-icon-1024.png` from the artifact, as Swoop did. CI never commits.
3. **`screen=badges` isn't a DemoMode screen yet.** `40-badges` then shows Home and copies nothing. asc.yml treats that
   as a warning while `BADGES_REQUIRED=false`.
4. **`HUSH-T canvas` isn't printed yet** (RootView is still to come). Its `<w>x<h>` meaning is unspecified, so PORTRAIT
   is judged on the PNG, and the canvas line is evidence only.
5. **The SLAM timing** is "lines since the slam began, read 2 s after the sweep returns". The `hinge` tool's start-up
   lag (Swoop run 40389436645) makes the window a little longer than 2 s.
6. **Timing guesses (unmeasured):**
   - The duo run takes ~45–75 min.
   - `relic` and `torchLow` rely on `skipTo` and seed 7. A missed freeze is captured anyway and flagged `no-freeze`.
7. **The guard can block an upload.** If HUSH-T lines are ever gated at runtime instead of `#if DEBUG`, the demo
   guard blocks the TestFlight upload. That is by design.

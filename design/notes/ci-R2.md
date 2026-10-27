# CI engineer, Round 2 hand-off (27 Oct)

Files changed:
- `ci/duo.sh`, `ci/scenarios.txt`;
- `ci/icon-check.sh` (new);
- `.github/workflows/ci.yml`, `testflight.yml`, `duo.yml` (header only);
- `project.yml` (the UI test target and its scheme only);
- `HushUITests/TurnedDragUITests.swift` (new).

I appended my asks to `design/NEEDS.md` ("CI engineer (R2)"). Nothing has run yet, and nothing is committed.

## 1. Duo (`ci/duo.sh`)

| Check | R2 change | PASS |
|---|---|---|
| SLAM | Launches with `freezeOn=bite`. The inner panel is shot (`shoot_now`, inner only, ~3–7 s) the moment `HUSH-T freeze bite` appears. | As before; the detail now also notes whether the bite froze. |
| UPRIGHT-NO-PAUSE (new) | 120 → 78° over 1.5 s, then hold 2 s. | No `paused closing`. The R1 85° threshold would FAIL this. |
| CLOSE-PAUSE | Then 78 → 55° (under the new 70°), then back to 120. | `paused closing`, then `resumed`. The detail logs the angle at each. |
| REOPEN-NO-BITE (new) | Real run, `noise=0.6;noiseUntil=pause`. 105 → 130 at 6°/s, 130 → 60 at 14°/s, 2 s on the card, then 60 → 120 in 0.4 s. | Paused, not resumed while low, no `event bitten` within 2 s of the reopen, and the first `resumed` at an angle ≥ 95°. |
| COVER-REOPEN (INFO) | Frames pass: the resume angle and the noise after reopening 0 → 165. | Evidence only. |

How REOPEN-NO-BITE reads the angle: from `HUSH-T resumed angle θ` once the App prints it. Until then it uses the last
`HUSH-H` sample or `lid … angle` line before `resumed`.

Without `HUSH-T noise released` (the App's `noiseUntil` key), the noise is held all run, so a bite can't happen. A run
that would otherwise PASS is then reported as **INFO "inconclusive"**, never a false PASS.

Other changes:
- The lesson pose sweep goes to 105°, inside the new 90–112° window.
- The POSE-BOOK INFO now explains a portrait frame: R2's automatic `requestPortrait` is expected to cause one.
- New frames:
  - `duo-h2-slam-bite`: the bite itself.
  - `duo-h2-after-slam`: kept for comparison.
  - `duo-h3-closing-card-55`: renamed from `-60`.
  - `duo-h6-reopened-120`.

## 2. Turned drag: research, then an XCUITest

**What I found:**
- **`xcrun simctl io` has no touch verb.** It only has screenshot, recordVideo and enumerate. Community pages that show
  `simctl io … tap` are unverified.
- **idb (Meta)** needs two installs: `brew tap facebook/fb && brew install idb-companion`, plus the `fb-idb` client
  through pipx on Python 3.11/3.12. There are known Python 3.14 breakages. It is workable, but it is two third-party
  pieces on every run.
- **AXe** (cameroncooke/AXe) installs in one line: `brew install cameroncooke/axe/axe`.
  - It has `axe drag --start-x … --end-x … --duration --steps`, plus `touch --down/--up`.
  - It was validated on Xcode 27 beta 3 with iOS 27.
  - It is the best non-Apple option: it reads stdout, and it works on the Duo sim alongside `hinge`.
- **An XCUITest target** is Apple-supported, with no extra binaries on the runner. Its synthesized drags go through
  UIKit hit-testing, the SpriteView and the scene's `touch.location(in: world)`, just like a finger.

**Chosen:** the XCUITest.
- `HushUITests` is a `bundle.ui-testing` target that depends on Hush and has its **own scheme**, so the gate and the
  Release archive never build it. It contains one test, `testTurnedDragBagsALitItem`.
- **What the test does:**
  1. Launches with `-hushDemo "screen=run;mode=attract;seed=7;lid=0.9;turn=1;fold=1"`.
  2. Reads two accessibility elements: `debug.loot` (the frame of a lit item as drawn) and `hud.bag` (the pouch's
     frame, with the in-bag count as its value).
  3. Drags at 200 pt/s from the item to the pouch.
  4. Expects the count to rise within 5 s.
- It **SKIPs** while the App hasn't exposed those elements (NEEDS.md).
- **In ci.yml** it is the "Turned drag" step:
  - non-fatal;
  - it retries once with ad-hoc signing if the unsigned runner won't load;
  - the verdict goes in the summary, and `uitest-*.xcresult` (with screenshot attachments) goes in the `logs`
    artifact.

**Fallback:** if XCUITest proves flaky on SpriteKit, AXe is the next step. Install it in the job, then
`axe drag --udid $UDID` using the positions from `debug.loot`, and grep `HUSH-T event itemBagged`.

## 3. App icon guard (`ci/icon-check.sh`)
**The R1 placeholder:**
- `git show d969f22:…/AppIcon-1024.png`: 5,343 bytes, sha256
  `a29bfd3dc05dacdf9a148b7b61725d972764d78e456c5fdf79c9302903a5ee70` (computed with Node's crypto, hardcoded).
- The committed R2 icon has sha256 `93025edc…`: 773 KB, 1024², RGBA, fully opaque.

**Checks:**
1. The file isn't the placeholder (by that hash).
2. It is 1024 × 1024.
3. It has at least 40 distinct colours on a 64 px sips sample. The placeholder has 2 and the real icon 115. Pixel
   variance can't be used: the placeholder's luma spread is 52, higher than the real icon's 35.
4. It has no alpha channel.

**Where it runs:**
- **testflight.yml**, both jobs, right after Xcode is selected: fatal.
  - With `FIX_ALPHA=1`, an alpha channel is flattened in the workspace only, losslessly through ImageIO (`xcrun swift`),
    with a JPEG round trip as the fallback.
  - The committed RGBA icon would otherwise hit ITMS-90717 at upload.
- **ci.yml**: a warning only.

## 4. Scenarios (`ci/scenarios.txt`)
- **35-reveal-phone-turned**: a phone with `turn=1` (no fold). Expects `fold=0 turned=1`.
- **36-golden-mimic**: needs the App's `golden=1` key. Expects `event chestArrived .*golden=1`. It is an expect-miss
  until the key lands.
- **37-chain-badge**: `pilot=perfect;freezeAfter=24;freezeOn=bank`, so it freezes on the 3rd or later all-Hushed bank.
  Expects `event chainUp`.
- **38-results-chest-strip**: Results with `pilot=perfect`.
- **39-lesson-final-fold**: the 3-row final card in the Duo layout.
- **Captions updated** to R2 copy (candle, lever, the final card's three rows, chest strip, "Hushed:", the badge
  grid, the bite callout). `08-lesson-6-card` is the phone final card.

## Risks / asks
1. **REOPEN-NO-BITE's strength depends on the App's `noiseUntil=pause`.** Without it the check is INFO. Also,
   lowering the lid passes the shut zone, so the chest probably banks on the way down. That is realistic (bank, then
   overshoot), but the reopen then meets a fresh chest. The held 0.6 applies to it until the pause.
2. **Resume angle evidence:** `HUSH-H` is rate-limited to 10 Hz, so without `resumed angle θ` the "last angle" can be
   one sample stale. That errs towards FAIL, never a false PASS.
3. **`shoot_now` relies on DemoMode's 0.3 s event hold.** I asked App/Scene to pause the scene's actions on event
   freezes, so the callout survives a slow shot.
4. **The UI test is unverified on the runner.** Unknowns:
   - whether unsigned UI test runners load on xcode-27 (hence the ad-hoc retry);
   - whether `XCUICoordinate.press(…withVelocity:…)` lands as one continuous drag on SKView.
   If it fails for tooling reasons, switch to AXe (above).
5. **Nothing has been run on a Mac** (Windows workspace). I checked both scripts with `bash -n` and unit-tested the
   `angle_before` / `first_line` helpers on a sample log. I couldn't run a YAML lint here: fetching js-yaml through
   npx was denied, so the workflow YAML is reviewed by eye only.

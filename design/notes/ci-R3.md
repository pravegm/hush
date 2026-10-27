# CI engineer, Round 3 hand-off (27 Oct)

Files changed:
- `ci/duo.sh`, `ci/scenarios.txt`, `ci/screenshots.sh`;
- `ci/store-capture.sh`, `ci/store-set.sh`, `ci/store-frame.swift`, `ci/store-scenarios.txt`,
  `ci/duo-store-scenarios.txt` (all new);
- `.github/workflows/store.yml` (new), `ci.yml` (one step), `duo.yml` (header only).

I appended my asks to `design/NEEDS.md` ("CI engineer (R3)"). Nothing has run yet, and nothing is committed. All
scripts pass `bash -n`; the new helpers and the caption lint were unit-tested on sample logs. The workflow YAML was
checked by a small structural lint (no YAML library here). `store-frame.swift` has **not been compiled**: there is no
Swift toolchain on this Windows machine. `store-set.sh` falls back to `xcrun swift` and lists a failed compile in
`logs/store-frame-build.log`.

## 1. Duo (`ci/duo.sh`)

| Check / frame | What it does | PASS |
|---|---|---|
| SLAM-CREAK (new) | Attract run (never bites), `freezeOn=creak`. 105 → 150 over 6 s, then a slam 150 → 104 in 0.3 s. The inner panel is shot the moment a creak line appears: `duo-h2c-slam-creak`. | A creak line (`HUSH-T freeze creak`, `creak …` or `event creak …`) within 3 s. FAIL only if the logged noise rose > 0.25 over 3 lid samples with no line. Otherwise INFO (the hook is missing). |
| COVER-SLOW-CLOSE (new) | Real run, `noise=0.6;noiseUntil=pause`. 120 → 40 over 6 s, then 3 s hold. | A `HUSH-T paused` line, no `HUSH-T pose play` on a cover-sized canvas, no `small-canvas-open`, and no resume. The canvas size is taken from the pose line itself (`poseReason` prints it); if it's missing, from the last `HUSH-T canvas` line. "Cover-sized" means a long side under 760. |
| COVER-SLOW-REOPEN (new) | Same launch, on down to 0, 3 s on the cover (`duo-h7-…` shot), then 0 → 140 over 5 s. If nothing resumes in 4 s it goes on to 165 (the sim can keep the cover lit to about 150°). | The first `HUSH-T resumed` is on `INNER_CANVAS` (669x951) at ≥ 95°, no resume ever on a cover-sized canvas, and no `event bitten` within 2 s. It is INFO if `noise released` is missing. The detail reports the relight angle and how far it had to go. |
| POSE-CARD (new, ui pass) | `screen=pose;pose=book;orient=landscape`, not tabletop: `duo-ui-pose-card`. | A landscape inner frame and a `HUSH-T pose standUp` line. |
| store pass (new, opt-in) | `PASSES=store`: one tabletop launch per `STORE_LIST` line at `STORE_ANGLE` (150°). It waits for the freeze line, then writes `store-<name>.png` and `logs/store-<name>.at-capture.txt`. | Frames only. |

The `pose=book` key is in `DemoMode.swift` now, so POSE-CARD can pass today. The old POSE-BOOK INFO (Home launched in
book pose) is kept as evidence of how the automatic ask behaves.

## 2. Phone scenarios (`ci/scenarios.txt`)
**Lesson frames (REVIEW-2-ux P1-7).** I worked the timings out from `LessonScript` and Core's light rule,
light = (openness − depth) / 0.10, where grab needs ≥ 0.6 and glint ≥ 0.4.

| Frame | Problem | Fix |
|---|---|---|
| `04` | At `lid=0.3` the first coin (depth 0.20) is grabbable at once, so step 2 passed straight to step 3. | `lid=0.25`: the coin glints (0.5) but can't be grabbed, so step 2 holds. |
| `05` | None: it was already right. | Unchanged. |
| `06` | The stillness passed step 4 to step 5 by 2.3 s. | `freezeAfter=1.6`, inside the 0.8–2.3 s "It's stirring. Freeze!" window. `noise=` is dropped: the meter now shows the script's own stir. |
| `07` | Step 5 started with an empty bag. | `lessonStep=5;pilot=perfect;freezeAfter=4.5`: the pilot bags a coin at about 2.7 s and closes at about 7.5 s. Expects `event itemBagged`. |
| `07b` (new) | No frame showed the pay-off. | `freezeOn=bank`. It shows the final card over BANKED until the App shortens the lesson bank freeze (NEEDS). |

**Other frames:**
- **Golden (36, 36b):** `golden=1` makes chest **#3** golden, but R2's frame froze on chest #1. `freezeAfter=18` with
  `freezeOn=ready` freezes on chest #3's arrival. 36b uses `freezeAfter=22;freezeOn=reveal`. Both expect
  `chestArrived …golden=1`.
- **Relic (15):** the relic card waits for `SceneMoments.bankGroupEnd` (1.15 s), but the relic freeze held only 0.3 s
  plus 0.4 s. That is why R2 captured a bank. The scenario passes `freezeDelay=1.7`, and NEEDS asks the App for the key
  or a longer relic hold.
- **New frames:**
  - `13b-creak` (`freezeOn=creak`);
  - `25-pose` (`pose=book;fold=1`);
  - `41–47` Large Dynamic Type: Results, Codex, Settings and Home at AccessibilityL, plus Results, Codex and Settings
    at XXXL.
- **`ci/screenshots.sh`:** a 6th or 7th column that starts with `-` holds extra launch arguments, passed after
  `-hushDemo`. So does the `EXTRA_LAUNCH_ARGS` env. The store files' `frame` column is ignored, because it never starts
  with `-`. The script is safe on bash 3.2.

## 3. Store pipeline (from Swoop)
- **`store.yml`** is manual only. It has three jobs:
  - **phones:** the 6.9" set (1320 × 2868), plus the 6.3" set (1206 × 2622 or 1179 × 2556, input `phone_61`, on by
    default) because screenshots.md calls it the required size;
  - **duo:** 2007 × 2853, `turn=0`;
  - **assemble.**

  The artifacts `store-69/store/`, `store-61/store/` and `store-duo/duo-screens/store/` match `build-metadata.js` and
  `asc.yml` exactly (P1-hero-open … P6-codex, D1 … D6).
- **`store-set.sh`:**
  - It checks the **last** canvas line at capture. The Duo needs `669x951 fold=1 turned=0`; the phones need `fold=0`.
  - It checks the freeze, skip and golden lines and the expect.
  - It lints the captions: ≤ 6 words in the headline and in the sub-line, no "FREEZE", no "keep", and no "lever" or
    "slide" on the Duo.
  - It reads back the size and alpha.
  - Problem frames go to `_flagged/`.
- **`store-frame.swift`:**
  - It draws portrait frames: the caption at the top, the type sized from the width, the screenshots.md palette and a
    plus-lighter candle glow.
  - It rejects "torch", "#1" and "Made for iPhone Duo" (exit 2).
  - `--tabletop` is the frame-1 composite. The floor half lies flat, the lid is raised to `--angle` (125°), and the
    camera is `--elevation` (28°) above. It uses a true perspective warp with Swoop's self-tested corner convention,
    and draws a graphite bezel, a front edge, the hinge barrel and a table shadow. Only the pixels are warped.
- **Captions** are copied from screenshots.md §A/§B. Two args differ from the doc, and both are still real states:
  - D1 and P1 use the casual pilot, the proven reveal (an expert may never open to 0.75);
  - DR1 and PR1 wait for chest #3.

## 4. `ci.yml`
"Store copy says candle, not torch" is the first step. It has `if: always()` and `continue-on-error`. It runs
whole-word `grep -i -w "torch(es)?"` over `docs/appstore/*.md`, `docs/*.html` and `asc-metadata.json`, and puts one
`::warning file=,line=::` per hit plus a summary table. Today it finds 0 hits. Docs-only pushes don't trigger `ci.yml`,
so I didn't widen the paths: a full build per doc edit would be costly.

## Risks
1. **The timing-gated frames (07, 36, 36b, DR1/PR1) rest on pilot pace estimates.** Their expects flag a miss, so
   check `captures.tsv` and the MANIFEST.
2. **The tabletop composite's look is unverified.** If frame 1 looks wrong, the fallback is the flat D1 (re-run with
   `frame` set to flat), and screenshots.md allows it.
3. **The CREAK and relic frames depend on App hooks** (NEEDS CI R3). Until they land, SLAM-CREAK is INFO and 15 may
   still show the bank.

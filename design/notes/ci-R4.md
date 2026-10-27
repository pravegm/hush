# CI engineer, Round 4 hand-off (27 Oct)

**Files changed:**
- `ci/scenarios.txt`, `ci/store-scenarios.txt`, `ci/duo-store-scenarios.txt`;
- `ci/screenshots.sh`: warns about a stray column;
- `ci/duo.sh`: the SLAM rework, and `ui-codex` uses `progress=mid`;
- `ci/icon-check.sh` (`--alpha-only`) and `.github/workflows/ci.yml` (one fatal step);
- an appended "CI engineer (R4)" section in `design/NEEDS.md`.

**Status:** nothing has run and nothing is committed.
- Every script passes `bash -n`.
- I linted all three lists: field counts, no stray `|`, waits are numbers, no duplicate names.
- The new expects match the R3 logs wherever the state is the same.
- `icon-check.sh --alpha-only` ran on the committed icon: colour type 2, no tRNS, exit 0.
- `slam_samples` ran on duo4's `slam.txt` and `slam-creak.txt`.

**No new demo key is needed.** Every fix uses keys DemoMode already parses.

## How I timed the freezes
An event freeze stops the session `freezeDelay` s after the event. The defaults are:

| Event | Default `freezeDelay` |
|---|---|
| bite, torchLow, creak | 0.3 s |
| bank | 1.25 s |
| lesson bank | 0.5 s |
| relic | 1.65 s |

After that, the scene keeps drawing for `sceneHoldDelay` (0.4 s) before it pauses. So the moment's age in the frame is
about `freezeDelay` + 0.4 s. The windows in `SceneMoments` are:

| Moment | Shown from … to (s) |
|---|---|
| Bank group ("Hushed!", "BANKED +N", "Hush Chain ×1.N") | 0.15 … 1.15 |
| Flying loot | 0.12 … ~1.0 |
| "CREAK!" | 0 … 0.7 (fades from 0.45) |
| Golden banner | 0 … 1.9 |
| Next chest arrives | 1.4 after the bank (`Tuning.bankMomentSeconds`) |

A state freeze (ready, reveal, stirring, waking) is the first frame of that state.

## The three QA-3 misses
- **`13b-creak`:**
  - **Two faults.**
    - The expect `HUSH-T (freeze |event )?creak` contained a `|`. The `IFS='|'` read split it, so it could never
      match.
    - The frame was the bite. A novice always slams with a full bag (noise about 0.6), and a 70–120°/s slam adds
      0.8 or more, so in a real run every novice slam bites.
  - **Fix:** `mode=attract`, where the session never bites and noise caps at 0.99.
    - The pilot and chest #1 are the same as in a real run. I checked: Wheezy Walt in both the run and attract logs.
    - So seed 7's novice slams about 5.8 s in, as R3's log shows: noise 0.59 → 0.91, `HUSH-T event creak`.
  - `freezeDelay=0`, so "CREAK!" is about 0.4 s old when the scene pauses.
  - The expect is now `HUSH-T event creak`.
  - **New:** `13c-creak-fold`, the same CREAK in the Duo layout with `turn=0`.
  - `13b` is the phone CREAK frame the brief asked for.
- **`36-golden-mimic`:**
  - `ready` is never seen after a bank: the expert's lid already sits in the shut zone. That's why R3 logged
    `no-freeze`.
  - It now freezes 1.75 s after bank #2 (`freezeAfter=13;freezeOn=bank;freezeDelay=1.75`). That is 0.35 s into chest #3,
    the golden one, with the banner up.
  - In the R3 log the banks were at about 9 s and 18 s, so 13 s has plenty of margin either way.
  - PR1 and DR1 use the same args.
- **`35-reveal-phone-turned`:**
  - `AppRules.turnsRound` needs a fold, so a phone is never drawn turned round.
  - The expect is now `fold=0 turned=0`, as QA-3 proposed, and the caption says so. The frame is a negative check.

## The other phone frames, checked against their captions
I looked at the PNGs, apart from the four listed under "Not viewed".

| Frame | R3 miss | R4 change |
|---|---|---|
| 09 ready | Chest #2 with the "Hush Chain!" tip: the pilot cracks chest #1 in its first step | `lid=0`: chest #1 is held in `ready` with its hint; expect `input fixed` |
| 11 stirring | The first Stirring frame: one amber pip, eyes shut | `freezeAfter=4`: mid-stir, noise about 0.5 (R3 log: 0.44–0.64 from 2.2 s to 5.8 s) |
| 14 bank | A black interior only: 1.25 s + 0.4 s is past the bank group | `freezeDelay=0.25`; the new `14b-bank-settled` keeps the default, for "counter = sum" |
| 16 torch-low | A "BANKED +975" moment and no hint: the casual banks 0.1 s after torchLow | `freezeDelay=6.5`: the next chest, loot in the bag, "Candle's low. Bank it!" at about 0:08 (estimate) |
| 25 pose | No "Play anyway": it appears after 8 s | Wait 11 s |
| 37 chain | A black interior only; the medal static | `freezeDelay=0.6`: "Hush Chain ×1.3" up |

**Captions that were stale (the frames were right):**
- 01: no slider on Home.
- 02: best 5,200, not 2,400.
- 05: R4 copy, "Drag a coin".
- 19, 20, 21, 38: what is actually above the fold.
- 24: "Play sound on silent".
- 26: there's no today's best before a first try.
- 27: off a run the card says "Open me… gently"; mid-run it says "Open to carry on".
- 30: drawn turned round.
- 36b: the seal vs the gem multiplier.
- 41–47: the expect is now the `dynamic-type` line.

**Frames that met their moment:** 03, 04, 06, 07, 07b, 08, 10, 12, 15, 17, 18, 22, 31, 33, 34, 39, 40, 41–45.

**Not viewed** (their args and logs match a frame I did view): 13, 23, 46, 47.

**Findings for other roles** (also in NEEDS):
- **The "!" padlock (App R4 item 9)** is the front padlock drawn turned round: its keyhole reads as "!" upside down.
- **32** (`fold=1;turn=0`) draws the lever, and 31 doesn't.
- **41 and 45 are identical,** so the type stops growing at XXXL.
- **Scene and App defects these frames will show until they land:** plate overflow (04, 05), the medal vs toast
  multiplier (07b: ×1.1 vs ×1.2), the black bank beat (14, 37), seal ×3 vs gem ×2 (36b), the chevron over totals
  (41/45), names cut with "…" (42/44), hairlines and the clipped "z" (27). These are out of CI's hands.

## The store set (`artifacts/store1`, captions in `screenshots.md`)
- **P3/D3 "Slide it down / Ease it shut to bank" and P4/D4 "Sleepy banks pay more":** both 69 and Duo showed only
  the black interior and BANKED, with no bank moment. The fix is `freezeDelay=0.25` and `0.6`.
- **PR1/DR1 (reserve):**
  - The args are the golden fix above.
  - The headline says "*Extra* gold" instead of "*Double* gold", because the seal shows ×3. That's still 5 words.
  - `screenshots.md` must follow; see NEEDS.
- **OK:** P1/D1 (the reveal, tabletop composite), P2/D2, P5/D5, P6/D6.
- I didn't view the 6.1" set or P6 separately: they come from the same args as 69/22.

## `ci/duo.sh`
- **SLAM** (the founder's mid-task item, run 40533062342: peak 24.4°/s, the slam reached the app as 1–2 samples):
  - After the STILL-RUN reading, `hinge_wiggle 150 2` sweeps 150 → 149 → 150 twice, 0.4 s each way. That's about
    2.5°/s, under quietSpeed 12, so it's silent, and it keeps samples flowing up to the slam.
  - If the peak is under `SLAM_MIN_PEAK` (60°/s) with no hit, it re-opens to 150 over 8 s (about 6°/s, silent),
    wiggles and slams once more.
  - **The verdict:**
    - PASS on a waking or bite line;
    - INCONCLUSIVE if the peak is still under 60°/s and the noise rose less than 0.05;
    - FAIL otherwise.
  - The line records the attempt, the peak, the slam's samples (lid-angle changes before 106°, plus the HUSH-H count;
    the failing duo4 slam reads 1) and the noise before and after.
  - INCONCLUSIVE is counted in the run summary and never trips `STRICT=1`.
  - I didn't wiggle SLAM-CREAK, because it passed at 91°/s. Note that duo4's `slam-creak.txt` shows the 105 → 150
    open sweep only arriving with the slam, so the same tool lag is there.
- **`ui-codex`:** `progress=mid`, as App R3 asked ("Codex 9/24 vs 22/24").

## QA-3 P2-10 (icon RGB)
`ci.yml` has a new fatal step, "App icon is RGB, no alpha", which runs `ci/icon-check.sh --alpha-only`.
- It fails on IHDR colour type 4 or 6, on a tRNS chunk, or when sips reports hasAlpha.
- The existing step stays warning-only, and `testflight.yml` still flattens with `FIX_ALPHA=1`.

## Risks
1. **16 is an estimate.** If the next chest's bag is still empty 6.5 s after torchLow, the hint is not up. Eyeball 16;
   the fallback is `freezeDelay=8`.
2. **13b depends on the attract run following R3's sequence up to the slam.** Noise differs only above the 0.99 cap, so
   it should. If no creak line comes, it's flagged `no-freeze`.
3. **The pose card's 8 s timer.** If it starts only after the first draw, 11 s is still enough.

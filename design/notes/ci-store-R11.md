# CI engineer, store screenshots R11 (28 Oct)

**Files changed:**
- `ci/store-upright.sh` (new): turns a Duo capture upright when its log has an odd k;
- `ci/store-capture.sh`: runs it after every Duo capture pass;
- `ci/store-set.sh`: runs it again on its own folder and the tabletop source folder, and checks the canvas of a turned capture as the upright canvas;
- comments in `ci/duo-store-scenarios.txt` and `.github/workflows/store.yml`.

**Scenario lines:** none changed. Every raw capture in store3 already shows the right moment, and every phone frame was already OK.

## What went wrong on run 40668557600 (store3)

| Frame | Result | Why |
|---|---|---|
| D1–D5 | raw 2853 × 2007, not framed (FLAGGED "slot size turned sideways") | see below |
| P1 (6.3" and 6.9") | `_flagged/`, flat fallback | P1 is the tabletop composite of D1. D1's raw was 2853 × 2007, not the Duo inner 2007 × 2853, so store-set fell back to P1's own flat phone capture and flagged it. It is the same root cause as D1–D5. |
| D6, P2–P6 (both sizes) | OK | Viewed: the right moments and true captions. |

**Root cause (from the app logs, `raw-duo/logs/store-D*.txt`).**
- Every Duo launch asks for `orient=portrait`. On a run screen iOS refuses it, over and over: `HUSH-T orient request error: … Requested: portrait; Supported: landscapeLeft`, and then `orient portrait failed after 30s window=951x669`.
- A live run holds the interface it went live in (`OrientationLock.mask(isDuo:liveRun:inner:interface:)`, R6/R8). The run goes live at launch, and the Duo simulator boots in book pose, which is landscapeLeft. So the run is held in landscape.
- Since R6 the app then draws the same portrait tabletop canvas turned one quarter clockwise: `HUSH-T canvas 951x669 fold=1 turned=0 k=1`.
- The codex is a menu, so nothing holds it: it turned portrait (`669x951 … k=0`, `orient portrait ok`). That is why only D6 was framed.
- The capture script's retries could not help, because the result is the same every time. All three passes gave 2853 × 2007.
- The brief expected `orient=portrait` to give a portrait run. It doesn't any more, and I can't change that from `ci/`: it's App code.

## The fix
- **What gets turned.** The pixels of a k=1 capture are the right frame, only sideways. The fold is the vertical band at x ≈ 1370–1487 px.
  - `store-upright.sh` turns a capture back only when the last canvas line of its own log has `fold=1` and an odd k, and the capture has the shape of that window turned (2853 × 2007 = 951 × 669 at 3×).
  - It turns k=1 by 270° clockwise and k=3 by 90°.
  - The result is 2007 × 2853, with the lid half on top and the fold across the middle at y ≈ 1365–1482 px. That is what the tabletop compositor expects.
- **Records.**
  - The landscape original is kept as `raw/store-<name>-landscape-k<k>.png`.
  - Each turn is a line in `raw-duo/rotated.tsv`.
  - The script is idempotent: it skips portrait captures. So it is safe to run again in assemble (needed for `duo_from_run` reuse).
- **Canvas check.**
  - `store-set.sh` checks a turned capture's canvas as the upright one: `951x669 … k=1` reads as `669x951 fold=1 turned=0 k=0 (upright: drawn k=1 …)`. So `REQUIRE_CANVAS` and `TABLETOP_REQUIRE` still guard against cover-display and wrong-k captures.
  - If the logged k doesn't match the turn, the frame is FLAGGED.
  - The MANIFEST note says "capture turned upright from k=1".
- **Truthful.** Since R6 the canvas is drawn the same in every orientation (`AppRules.quarterTurns`), so the upright picture is what a tabletop player sees. Only the capture is turned; nothing is drawn.
- **Local test.** I ran it on the store3 captures with a fake `sips` (it swaps the IHDR width and height) and a fake compositor. Duo: ok 6, flagged 0. 6.3": ok 6, flagged 0, and P1 is a tabletop from D1.

## Store run 40675006542 (commit 4d5f0ec), artifacts in `artifacts/store4/`
This was a full run: the phones, a fresh Duo capture and assemble, all three jobs a success. It is the only store run I used.
- **The Duo capture worked first time.** `store-upright.sh` turned D1–D5 after the first pass, so there were no retries.
- **MANIFESTs:** Duo ok 6, flagged 0, missing 0; 6.9" ok 6; 6.3" ok 6. Every frame is slot size with `alpha no`. Both P1s are the D1 tabletop, `warp=ok`.
- **I viewed every framed PNG:**

| Frame | Verdict |
|---|---|
| D1 / P1 ×2 | The tabletop composite stands upright with the lid half raised. Wary Wendell is asleep, the lid is open with gems and coins, the meter is empty. |
| D2 | Upright. "Freeze!" plate, WAKING! meter, the eye open, "179 not safe yet". |
| D3 | "Hushed! BANKED +197 / Hush Chain ×1.1", CHAIN ×1.1, and the floor isn't black. |
| D4 | "Hushed! BANKED +429 / Hush Chain ×1.3", CHAIN ×1.3 medal, banked 855. |
| D5 | Teeth across the fold, "CHOMP! Too loud! −179", "−10s" by the candle, no red flash. |
| D6 | Codex "9 of 24 found". The title is on the lid half and the grid on the floor half (the R10 layout), so there is a big empty middle; it is true, just sparse. |
| P2–P6 (6.9" and 6.3") | The same moments with the lever drawn. P3 is "Hushed! BANKED +197" with the caption "Slide it down to bank" (lever). P6 is the 3-column Codex. |

## For the App and the docs (not changed here)
- `docs/appstore/screenshots.md` §A says a quarter-turned (odd k) capture is flagged and never uploaded. Since R11 an odd-k capture is turned upright from its logged k instead; only an unexplained mismatch is flagged. Update that line in the next docs pass.
- A true portrait Duo run capture would need the App to leave a DEBUG `orient=portrait` run unheld until the portrait ask succeeds. It isn't needed: the turned frames are pixel-for-pixel the app's tabletop canvas.
- The D1 reveal lands on chest #2 (Wary Wendell, BANKED 179, "Drag the loot into your bag"). The R7 casual pilot banks chest #1 before a reveal is held. The caption is still true: the lid is open, the mimic is asleep and the meter is low.

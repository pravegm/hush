#!/usr/bin/env bash
# iPhone Duo simulator pass for Hush (called by .github/workflows/duo.yml). Adapted from Swoop's and Brim's ci/duo.sh
# (both proven on these runners; Brim is the tabletop/portrait one).
#
# Lessons inherited from Squish, Brim and Swoop (Squish docs/DUO-CI.md, Brim research/02-hinge-tech.md):
#  - `simctl io screenshot` needs --display on the Duo; the names vary (LCD/LCD-1, primary/primary-1, 1/3), so we probe
#    them once, capture BOTH panels every shot and keep the lit one (brightness check: a panel that is off is black).
#  - Never run `simctl io … screenConfig` on the Duo (SpringBoard crash loop).
#  - Wait ~2.5 s after a hinge move for the display to settle; `hinge` occasionally drops a move, so `set` retries 3x.
#    `hinge sweep` streams at 60 Hz, so the app sees a real motion (and a real lid speed) rather than a jump.
#  - Closing from open, the inner panel stays lit down to ~20°; 0° switches to the cover. Reopening from shut, the
#    cover stays lit until ~150°, so every reopen goes to 165° before coming back down.
#  - Every simctl / hinge call has a timeout; a shot takes ~15 s, so no shot is ever taken inside a timed check window.
#
# ORIENTATION (tabletop = the inner display in portrait). The Duo sim boots in BOOK pose: the inner canvas is
# landscape (951 x 669 pt) with the fold running top to bottom. There is no CLI rotate (`simctl` has no rotate verb,
# and screenConfig is banned), so Brim's proven route is used: the app itself asks the window scene for portrait
# (DEBUG `requestGeometryUpdate`, which works because the Debug Info.plist keeps UIRequiresFullScreen) when the demo
# args contain `orient=portrait`. Brim got the 669 x 951 pt tabletop canvas (2007 x 2853 px inner frames) this way on
# its first Duo run, with the fold horizontal at mid-height. So every tabletop launch below appends `;orient=portrait`
# (env ORIENT; ORIENT= sends nothing) and waits for "HUSH-T orient portrait ok" or a portrait `HUSH-T canvas <w>x<h>`
# line. The PORTRAIT check reports whether it worked, judged on the inner-display PNG (taller than wide). Launches
# WITHOUT the key stay in book pose, which is how the landscape pose card is shot.
# STATUS: `orient=portrait` landed in R1 (duo run 1: PORTRAIT PASS, 2007 x 2853 inner frames).
# (Hush's Info.plist lists no upside-down orientation; "turned round" is drawn by the scene from R2 (ChestScene.turned),
# so the sim needs nothing more for the turned-round frames.)
#
# R2 (design/ROUND-2.md "CI engineer", REVIEW-1-duo P0-2/P1-4, tester2-duo "the slam frame showed nothing"):
#  - SLAM launches with `freezeOn=bite` and shoots the inner panel alone the moment `HUSH-T freeze bite` is logged, so
#    the frame is the bite itself, not the next chest 15 s later.
#  - CLOSE-PAUSE uses the new 70° closing threshold (sweep to 55°); UPRIGHT-NO-PAUSE holds 78° (an upright lid, ±5°
#    of 90° reads as low as 84°) and expects no pause.
#  - REOPEN-NO-BITE: noise 0.6 (demo `noise=0.6;noiseUntil=pause`, design/NEEDS.md CI R2), close to 60°, wait 2 s,
#    reopen to 120° in 0.4 s. PASS: no `event bitten` within 2 s of the reopen, and `HUSH-T resumed` only after a
#    logged angle >= 95° (`HUSH-T resumed angle <θ>` when the App prints it, else the last `HUSH-H` sample before it).
#
# R3 (design/ROUND-3.md "CI engineer", decision 1, REVIEW-2-duo P0-1 / P1-2, tester 6 "a slam that doesn't bite reads
# as nothing"):
#  - COVER-SLOW-CLOSE: a real run, 120 → 40° over 6 s (13°/s, the taught gentle close), then 3 s at 40°. PASS: the run
#    paused, never logged `HUSH-T pose play` while the canvas was cover-sized (long side < 760 pt; the pose line carries
#    the canvas size) nor `small-canvas-open`, and never resumed.
#  - COVER-SLOW-REOPEN (same launch, after a full shut): 0 → 140° over 5 s (on to 165° if the sim's cover display is
#    still lit and nothing resumed in 4 s: the sim relights late, R2 duo3). PASS: the first `HUSH-T resumed` is on the
#    inner canvas (INNER_CANVAS, 669x951) at a logged angle >= 95°, no resume ever on a cover-sized canvas, and no
#    `event bitten` in the 2 s after it (noise=0.6 held until the first pause, then frozen there by decision 2, so a
#    reopen leaking into the noise would bite).
#  - SLAM-CREAK: an attract slam (never bites) with `freezeOn=creak`; the inner panel is shot the moment a CREAK line
#    (`HUSH-T freeze creak` / `HUSH-T creak …` / `HUSH-T event creak …`) appears, so duo-h2c-slam-creak shows the
#    "CREAK!" shake and the red meter flash (design/NEEDS.md CI R3 asks the App for the tag and the line).
#  - duo-ui-pose-card: `screen=pose;pose=book;orient=landscape` (R3 key: the card is held, no portrait ask), so the
#    "Turn it sideways. Lift the glowing half." card is finally a frame (REVIEW-2-ux P1-6, juror "capture gaps").
#
# R6 (design/ROUND-6.md "CI engineer" 2, the founder's real-Duo P0: opened fully flat, iOS rotated to landscape, the
# game was stuck behind the book-pose card). Three checks at the end of the hinge pass, all timed with a LINE CLOCK (a
# background perl loop sampling "<epoch> <line count>" of the log every 0.2 s: the app's lines carry no time):
#  - FLAT-OPEN: attract run, 140 → 180 over 4 s, a still 3 s hold, back to 140 over 4 s. PASS: lid lines never stop
#    (> 1.2 s), no pause > 1 s, no slider switch, lid lines after the return.
#  - WATCHDOG: close to 60° (pause), the slowest reopen to 130° (14 s sweep), 1° wiggles. PASS: `HUSH-T resumed` or
#    `HUSH-T watchdog resume` within 8 s of reaching 130.
#  - LANDSCAPE-PLAY: `orient=landscape` launch (no portrait ask), 105 → 160 over 7 s. PASS: no standUp block, k odd
#    (`k=` on the canvas line, else a landscape canvas), the lid follows the hinge, lidCracked; frame duo-h11.
#  Each retries once and says INCONCLUSIVE (never FAIL) when the hinge tool under-delivers the move twice.
#
# R12 (design/ROUND-12.md, founder's real-Duo test of build 6: "chest closed means lid closed, chest open means lid
# open"). The lid angle IS the chest's openness: no hidden shut gate before a chest can be played, the next chest is
# only dealt under a closed lid, and closing the lid banks. Three checks at the end of the hinge pass (line clock):
#  - START-OPEN: hinge at 150, an attract run. PASS: `event lidCracked` within 3 s of the run starting, no
#    `hint easeLidDown` / `hint openSlowly` while open, and the lid lines carry 150°'s openness (0.77).
#  - BITE-CLOSE-NEXT: a real run at 150 bitten by the demo noise (`noise=1;noiseUntil=bite`, deterministic: a sim slam
#    peaks ~80°/s and may only stir, R7, and a slam ends in the shut zone, which would deal the next chest), held open
#    ≥ 2 s after the bite moment: no `chestArrived` while open; close to 100 (openness 0): `chestArrived` within 1 s of
#    the first lid line ≤ 110°; reopen to 150: `lidCracked` (or, while the noise hold isn't released, the held noise's
#    bite: a bite needs a looting chest).
#  - BANK-CLOSE-FULL: an attract run at 150 with one item bagged by the demo (`bag=1`, design/NEEDS.md CI R12), closed in
#    one go to 30° then 0°. PASS: `banked` before the first pause, the next `chestArrived` at a logged angle ≤ 110°, and
#    after the reopen (to 165°) a resume and the new chest's `lidCracked`.
#  Older checks: SLOW-OPEN and LANDSCAPE-PLAY start at 100° (openness 0, the closed chest) instead of 105° (0.08, which
#  is already cracked), so their sweep really opens a closed chest; the frames pass adds duo-00-closed-100 (the R12
#  closed-chest cover). `HUSH-T hint <name>` lines are asked for in design/NEEDS.md (CI R12); without them the hint parts
#  of the checks are reported as pending, never failed.
#
# R13 (commit be9a963, "the phone IS the chest"; Hush/Core/Tuning.swift "R13 The Duo's hinge", Lid.hingeOpenness,
# HingeLidSource): the PHYSICAL hinge angle maps onto the chest directly. Every trajectory and threshold below follows:
#  - openness = θ / 150 clamped (0 at 0°, 1 at ≥ 150°; was (θ − 100) / 65); lidCracked first at openness 0.05 ≈ 7.5°;
#  - shut zone (bank / next chest) θ ≤ 15° (was 110°); closing pause θ < 12° for 0.4 s, unlatching above 20° (was 70 /
#    78°); resume at θ ≥ 18° held still, hysteresis down to 15° (was 92 / 88°); the watchdog resumes after 6 s at ≥ 18°;
#  - the lid speed in `HUSH-T lid … speed X` is hinge °/s × 0.4333 (65 / 150): the noise rules are unchanged in LID °/s,
#    so every speed threshold here stays in logged (lid) °/s and the physical moves are made faster instead (the slam is
#    160 → 20° in 0.4 s, 350°/s physical ≈ 152 lid °/s, the old 150 → 104 in 0.3 s slam's lid speed); a gentle move is
#    ≤ ~25°/s physical (≈ 11 lid °/s, under quietSpeed 14);
#  - a closed start is 5° (openness 0.03), an open start 150°; closing to bank / for the next chest goes to 5°;
#  - lesson pose window 45–150° (loose 30–165°), no shut-first gate; too wide still > 172°; the cover card's "Already
#    open?" escape still at ≥ 92°.
#  Simulator: closing below ~90° the sim may hand the app to the cover display while the chest is still OPEN (R12b: a
#  bag banks at once, `HUSH-T banked under the pause reason=cover`; a robbed chest's next one is dealt under the pause,
#  `HUSH-T next chest dealt under the pause reason=…`, its `chestArrived` with the first step back). Its cover stays lit on
#  a reopen up to ~150°, so every reopen after a deep close either goes to 160–165° or, when nothing resumed and the
#  cover is still up (`cover_up`), goes on to 165° and looks again; a check the cover display blocked is INCONCLUSIVE.
#  MEASURED (duo run 40725260104, R13): closing, the sim hands the app to its cover display at 62–92°; reopening, the
#  inner display relights at ~20–24° (not ~150°); HUSH-H samples keep flowing on the cover; a paused run logs no lid
#  lines (no steps). So on the sim no run step ever happens in the 15° shut zone.
#
# R14 (commit 518ea49, founder: "playing starts with the chest closed right? so ask the user to close the phone if it
# is not to start playing, then the chest should open as the phone opens"):
#  - EVERY run's first chest waits for the lid to be seen shut (a step at θ ≤ 15°, or noteLidShut under the closing
#    pause / cover takeover): while open before that the hint is `easeLidDown` ("Close the phone to start"), phase
#    ready, no lidCracked, no candle. START-OPEN is inverted into START-CLOSED. Every check that needs an OPEN first
#    chest (SLAM, SLAM-CREAK, BITE-CLOSE-NEXT, BANK-CLOSE-FULL) first runs `open_first_chest` (close to 5°, reopen);
#    when that fails the check is INCONCLUSIVE and names the cause (START-CLOSED carries the FAIL). Checks of the
#    pause itself (UPRIGHT-NO-PAUSE, CLOSE-PAUSE, REOPEN-NO-BITE, COVER-SLOW-*, FLAT-OPEN, WATCHDOG) don't need it.
#  - `shut_gap_note`: when a first chest never opened, says whether any run step reached the shut zone. On the sim
#    none can (see MEASURED), and the App's `noteLidShutIfRobbed` only calls `session.noteLidShut()` with loot in the
#    bag or a robbed chest, so a cover takeover / closing pause never marks the FIRST chest seen shut. R14b (ab96a50)
#    fixes that and logs `HUSH-T first chest seen shut reason=…`, which silences the note. R14b also ends an EMPTY
#    chest opened past 0.2 when the phone closes (`next chest dealt under the pause`): a new `chestArrived` on a
#    reopen after a mid-chest close (CLOSE-PAUSE, REOPEN-NO-BITE, COVER-SLOW-*, WATCHDOG) is correct, never judged.
#  - Every closing pause resumes on the lift (≥ 18°, no "Hold still…"); a non-still resume logs `HUSH-T fresh chest
#    resume`. `easeLidDown` is the expected first-chest hint (bad only after a lidCracked); `tooWide` never shows
#    (FLAT-OPEN fails on a `hint tooWide` line); the pose tip never shows unforced (POSE-NO-BLOCK); the lesson starts at
#    its open step, its chest also waiting for the close. `startOpen=1` no longer opens a chest.
#
# PASSES=store (R3): the App Store Duo set (ci/store-capture.sh duo → ci/duo-store-scenarios.txt), one tabletop capture
# per line at STORE_ANGLE (150°): store-<name>.png + logs/store-<name>.at-capture.txt (ci/store-set.sh frames them).
#
# Env: UDID (required), OUT (duo-screens), PASSES ("hinge frames ui"; "store" is opt-in), ORIENT ("portrait"), STRICT
# (1 = exit 1 when a check FAILs; default 0: the frames and the PASS/FAIL table are the evidence), INNER_CANVAS
# ("669x951"), STORE_LIST / STORE_FILTER / STORE_ANGLE (the store pass); R6: FLAT_TOP (180), FLAT_GAP_MAX (1.2),
# WATCHDOG_REOPEN_S (14), WATCHDOG_LIMIT (8); R12: BITE_NEXT_LIMIT (1); R13: SLAM_MIN_PEAK (60 lid °/s); R14: START_CLOSED_HOLD (3).
# Writes: $OUT/*.png (lit panel), $OUT/raw/<shot>-inner|cover.png, $OUT/logs/<launch>.txt (app stdout+stderr),
# $OUT/logs/run.txt (this script), $OUT/checks.tsv (check <TAB> PASS|FAIL|INFO|INCONCLUSIVE <TAB> detail) and, when
# $GITHUB_STEP_SUMMARY is set, a summary table.
set -uo pipefail

APP="build/Build/Products/Debug-iphonesimulator/Hush.app"
BUNDLE="com.pravegm.hush"
OUT="${OUT:-duo-screens}"
PASSES="${PASSES:-hinge frames ui}"
ORIENT="${ORIENT-portrait}"
STRICT="${STRICT:-0}"
INNER_CANVAS="${INNER_CANVAS:-669x951}"
: "${UDID:?UDID is required}"
mkdir -p "$OUT/raw" "$OUT/logs"
OUT_ABS="$(cd "$OUT" && pwd)"
RUNLOG="$OUT_ABS/logs/run.txt"
CHECKS="$OUT_ABS/checks.tsv"
: > "$CHECKS"
log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$RUNLOG" >&2; }
to() {
  local s="$1"; shift
  if command -v gtimeout >/dev/null 2>&1; then gtimeout -k 5 "$s" "$@"
  elif command -v timeout >/dev/null 2>&1; then timeout -k 5 "$s" "$@"
  else perl -e 'alarm shift; exec @ARGV or die "exec failed: $!\n"' "$s" "$@"; fi
}

# result <CHECK> <PASS|FAIL|INFO|INCONCLUSIVE> <detail>: one line in the run log ("SLOW-OPEN PASS (…)") and in checks.tsv.
result() {
  log "$1 $2 ($3)"
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$CHECKS"
}

# write_summary: the checks as a table in the job summary (called on every exit path).
write_summary() {
  [[ -n "${GITHUB_STEP_SUMMARY:-}" ]] || return 0
  {
    echo "### Hush on the iPhone Duo simulator"
    echo ""
    echo "Passes: \`$PASSES\`; displays inner=\`${INNER:-?}\` cover=\`${COVER:-?}\`; orient key: \`${ORIENT:-none}\`."
    echo ""
    echo "| Check | Result | Detail |"
    echo "|---|---|---|"
    awk -F'\t' '{ d = $3; gsub(/\|/, "\\|", d); r = ($2 == "INFO" ? $2 : "**" $2 "**"); printf "| %s | %s | %s |\n", $1, r, d }' "$CHECKS"
    echo ""
    echo "Frames: $(ls "$OUT_ABS"/*.png 2>/dev/null | xargs -n1 basename 2>/dev/null | tr '\n' ' ')"
  } >> "$GITHUB_STEP_SUMMARY"
}

INNER=""; COVER=""
to 300 xcrun simctl install "$UDID" "$APP" || {
  log "install failed, retrying"; sleep 5
  to 300 xcrun simctl install "$UDID" "$APP" || { result INSTALL FAIL "simctl install failed twice"; write_summary; exit 1; }
}

for c in LCD-1 primary-1 3 internal; do
  to 30 xcrun simctl io "$UDID" screenshot --display="$c" "$OUT_ABS/raw/_p.png" >/dev/null 2>>"$RUNLOG" && { INNER="$c"; break; }
done
for c in LCD primary 1 external; do
  [[ "$c" == "$INNER" ]] && continue
  to 30 xcrun simctl io "$UDID" screenshot --display="$c" "$OUT_ABS/raw/_p.png" >/dev/null 2>>"$RUNLOG" && { COVER="$c"; break; }
done
rm -f "$OUT_ABS/raw/_p.png"
log "displays inner=$INNER cover=$COVER"

HAVE_HINGE=0; command -v hinge >/dev/null 2>&1 && HAVE_HINGE=1
(( HAVE_HINGE )) || log "WARN no hinge tool: the hinge checks will FAIL and every frame stays at the boot angle"
CUR=180
hinge_set() {   # hinge_set <angle>: a confirmed set, 3 tries
  (( HAVE_HINGE )) || return 1
  local a
  for a in 1 2 3; do to 20 hinge -d "$UDID" -t 3 "$1" >>"$RUNLOG" 2>&1 && { CUR="$1"; return 0; }; sleep 1; done
  log "WARN hinge set $1 failed"; return 1
}
hinge_sweep() {   # hinge_sweep <to> <seconds>: continuous 60 Hz stream so the app sees a real motion
  (( HAVE_HINGE )) || return 1
  to $(( ${2%.*} + 20 )) hinge -d "$UDID" sweep "$CUR" "$1" "$2" >>"$RUNLOG" 2>&1 || log "WARN sweep $CUR -> $1 exited non-zero"
  CUR="$1"
}
# hinge_wiggle <angle> <n> (R4): n tiny 1° sweeps (angle → angle−1 → angle, 0.4 s each way, ~2.5°/s: silent) so hinge
# samples keep flowing through a "hold" (a perfectly still hold made the tool deliver the next fast sweep as 1–2
# samples, duo run 40533062342).
hinge_wiggle() {
  (( HAVE_HINGE )) || return 1
  local i
  for (( i = 0; i < $2; i++ )); do hinge_sweep $(( $1 - 1 )) 0.4; hinge_sweep "$1" 0.4; done
}
# A slam whose logged peak lid speed is under this (°/s) is retried once, then INCONCLUSIVE if the noise didn't move.
# R13: the logged speed is the LID's (hinge °/s × 0.4333) and the noise rules are unchanged in it, so the line stays 60
# lid °/s (≈ 138°/s physical, 2× closeQuietSpeed 28); the slam itself is made faster physically (350°/s nominal).
SLAM_MIN_PEAK="${SLAM_MIN_PEAK:-60}"
# R13: the shut zone, the closing line and the resume line (physical °), for the checks and their messages.
SHUT_ZONE=15; CLOSE_LINE=12; RESUME_LINE=18; RESUME_LOW=15

# brightness of a PNG, 0-255 (sips → 16×16 BMP)
brightness() {
  local tmp="$OUT_ABS/raw/_b.bmp"
  to 20 sips -z 16 16 -s format bmp "$1" --out "$tmp" >/dev/null 2>&1 || { echo -1; return; }
  python3 -I - "$tmp" <<'PY' 2>/dev/null || echo -1
import struct, sys
b = open(sys.argv[1], "rb").read()
off = struct.unpack_from("<I", b, 10)[0]; w, h = struct.unpack_from("<ii", b, 18); bpp = struct.unpack_from("<H", b, 28)[0]
step = bpp // 8; row = (w * step + 3) & ~3; tot = n = 0
for y in range(abs(h)):
    for x in range(w):
        p = off + y * row + x * step; tot += b[p] + b[p + 1] + b[p + 2]; n += 3
print(int(tot / n))
PY
  rm -f "$tmp"
}

LAST_PICK=""   # R13: the panel the last `shoot` kept (inner|cover): the frames pass reads it to spot a lit cover at 5°
shoot() {   # shoot <name> <inner|cover>: both panels to raw/, the lit one (or the wanted one) to <name>.png
  local name="$1" want="$2" ib=-1 cb=-1 pick
  [[ -n "$INNER" ]] && to 30 xcrun simctl io "$UDID" screenshot --display="$INNER" "$OUT_ABS/raw/$name-inner.png" >/dev/null 2>>"$RUNLOG" && ib=$(brightness "$OUT_ABS/raw/$name-inner.png")
  [[ -n "$COVER" ]] && to 30 xcrun simctl io "$UDID" screenshot --display="$COVER" "$OUT_ABS/raw/$name-cover.png" >/dev/null 2>>"$RUNLOG" && cb=$(brightness "$OUT_ABS/raw/$name-cover.png")
  if [[ -z "$INNER$COVER" ]]; then to 30 xcrun simctl io "$UDID" screenshot "$OUT_ABS/$name.png" >/dev/null 2>>"$RUNLOG"; return; fi
  if (( ib > 6 && cb <= 6 )); then pick=inner; elif (( cb > 6 && ib <= 6 )); then pick=cover; else pick="$want"; fi
  LAST_PICK="$pick"
  [[ -f "$OUT_ABS/raw/$name-$pick.png" ]] && cp "$OUT_ABS/raw/$name-$pick.png" "$OUT_ABS/$name.png"
  [[ "$pick" != "$want" ]] && log "NOTE $name: wanted the $want panel, the $pick panel was the lit one"
  log "shot $name (inner=$ib cover=$cb -> $pick, hinge ${CUR}°) size=$(to 20 sips -g pixelWidth -g pixelHeight "$OUT_ABS/$name.png" 2>/dev/null | awk '/pixel/{printf "%s ", $2}')"
}

# shoot_now <name>: the inner panel only, at once (no cover capture, no brightness probe): for a moment that must not
# be missed (the bite). ~3–7 s instead of ~15 s.
shoot_now() {
  local name="$1"
  if [[ -n "$INNER" ]]; then to 30 xcrun simctl io "$UDID" screenshot --display="$INNER" "$OUT_ABS/$name.png" >/dev/null 2>>"$RUNLOG"
  else to 30 xcrun simctl io "$UDID" screenshot "$OUT_ABS/$name.png" >/dev/null 2>>"$RUNLOG"; fi
  log "shot $name (inner only, at once, hinge ${CUR}°) size=$(png_wh "$OUT_ABS/$name.png")"
}

# wait_for <file> <regex> <seconds>: poll (0.2 s) until the log has the line; returns 1 on a timeout.
wait_for() {
  local i=0 n=$(( $3 * 5 ))
  while (( i < n )); do grep -qE "$2" "$1" 2>/dev/null && return 0; sleep 0.2; i=$((i+1)); done
  return 1
}

# Log helpers. The app prints one line per event (print + fflush), so line numbers order events in time.
nlines() { local n; n=$(wc -l < "$1" 2>/dev/null | tr -d ' '); echo "${n:-0}"; }
count() { local n; n=$(grep -cE "$1" "$2" 2>/dev/null); echo "${n:-0}"; }
after() { tail -n +"$(( $2 + 1 ))" "$1" 2>/dev/null; }     # after <file> <line>: the lines logged since <line>
# between <file> <a> <b>: lines a+1 … b (awk, because BSD head rejects -n 0)
between() { awk -v a="$2" -v b="$3" 'NR > a + 0 && NR <= b + 0' "$1" 2>/dev/null; }
# lid_vals <field>: from "HUSH-T lid <o> speed <v> angle <θ> noise <n> stage <s>" lines on stdin, the <field> values.
lid_vals() { awk -v k="$1" '/HUSH-T lid / { for (i = 1; i < NF; i++) if ($i == k) print $(i + 1) }'; }
# slam_samples <file> <line> [stop °, default 25] (R4): how many samples the app saw during a slam (R13: 160 → 20°):
# the distinct lid angles logged after <line> that differ from the one before (starting from the hold's last angle, at
# or before <line>), up to the first angle <= stop, and the raw HUSH-H lines in that span. Duo run 40533062342's failing
# slam reads 1 (146.7 -> 136.0 -> 103.2); a streamed slam at 10 Hz lid lines reads 2-4.
# R14: [le|ge] (default le): a closing slam stops at the first angle <= stop, an opening one (ge) at the first >= stop.
slam_samples() {
  awk -v a="$2" -v s="${3:-25}" -v dir="${4:-le}" '
    /HUSH-T lid / { v = ""; for (i = 1; i < NF; i++) if ($i == "angle" && $(i + 1) ~ /^[0-9.]+$/) v = $(i + 1) + 0 }
    !/HUSH-T lid / { v = "" }
    NR <= a + 0 { if (v != "") prev = v; next }
    /^HUSH-H / { h++ }
    v != "" { if ((dir == "ge" && v >= s + 0) || (dir != "ge" && v <= s + 0)) exit; if (prev == "" || v != prev) m++; prev = v }
    END { printf "%d (lid-angle changes before %s°), HUSH-H=%d\n", m, s, h }' "$1" 2>/dev/null
}
max_of() { awk 'BEGIN { m = "" } $1 ~ /^-?[0-9.]+$/ { if (m == "" || $1 + 0 > m + 0) m = $1 } END { print (m == "" ? "none" : m) }'; }
min_of() { awk 'BEGIN { m = "" } $1 ~ /^-?[0-9.]+$/ { if (m == "" || $1 + 0 < m + 0) m = $1 } END { print (m == "" ? "none" : m) }'; }
lt() { [[ "$1" =~ ^-?[0-9.]+$ ]] && awk -v a="$1" -v b="$2" 'BEGIN { exit !(a + 0 < b + 0) }'; }   # lt <a> <b>: a < b
# angle_before <file> <line>: the last hinge angle logged before line <line> ("HUSH-H <t> <θ>" samples, at most 10 Hz,
# or the angle field of a "HUSH-T lid …" line), or "none".
angle_before() {
  awk -v n="$2" 'NR >= n + 0 { exit }
    /^HUSH-H / { a = $3 }
    /HUSH-T lid / { for (i = 1; i < NF; i++) if ($i == "angle" && $(i + 1) ~ /^[0-9.]+$/) a = $(i + 1) }
    END { print (a == "" ? "none" : a) }' "$1" 2>/dev/null
}
# first_line <file> <regex> <after line>: the line number of the first match after <after line>, or "".
first_line() { awk -v a="$3" -v re="$2" 'NR > a + 0 && $0 ~ re { print NR; exit }' "$1" 2>/dev/null; }
# canvas_line <file>: the latest "HUSH-T canvas <w>x<h> …" line; is_portrait <line>: h > w.
canvas_line() { grep -oE "HUSH-T canvas [0-9]+x[0-9]+.*" "$1" 2>/dev/null | tail -1 | tr -d '\r'; }
is_portrait() {
  local wh w h
  wh=$(echo "$1" | grep -oE "[0-9]+x[0-9]+" | head -1); w=${wh%x*}; h=${wh#*x}
  [[ "$w" =~ ^[0-9]+$ && "$h" =~ ^[0-9]+$ ]] && (( h > w ))
}

# canvas_before <file> <line>: the "<w>x<h>" of the last `HUSH-T canvas` line before line <line>, or "none".
canvas_before() {
  awk -v n="$2" 'NR >= n + 0 { exit }
    /HUSH-T canvas [0-9]+x[0-9]+/ { if (match($0, /canvas [0-9]+x[0-9]+/)) c = substr($0, RSTART + 7, RLENGTH - 7) }
    END { print (c == "" ? "none" : c) }' "$1" 2>/dev/null
}
# is_cover_size <WxH>: the long side is under 760 pt (AppRules.coverMaxSide; the sim's cover canvas is 466 x 678).
is_cover_size() {
  local w="${1%x*}" h="${1#*x}"
  [[ "$w" =~ ^[0-9]+$ && "$h" =~ ^[0-9]+$ ]] || return 1
  (( (w > h ? w : h) < 760 ))
}
# max_jump: from noise values on stdin (10 Hz lid lines), the largest rise over 3 samples (~0.3 s), "none" if < 4.
max_jump() {
  awk '$1 ~ /^-?[0-9.]+$/ { v[n++] = $1 + 0 }
    END { m = ""; for (i = 3; i < n; i++) { lo = v[i - 3]; if (v[i - 2] < lo) lo = v[i - 2]; if (v[i - 1] < lo) lo = v[i - 1]
            d = v[i] - lo; if (m == "" || d > m) m = d }
          if (m == "") print "none"; else printf "%.2f\n", m }'
}

# png_wh <file>: "WxH" of a PNG, or "?". The Duo's inner-display capture follows the interface orientation (Brim:
# 2007 x 2853 in portrait, 2853 x 2007 for the book card), so it is the ground truth for PORTRAIT.
png_wh() {
  local w h
  w=$(to 20 sips -g pixelWidth "$1" 2>/dev/null | awk '/pixelWidth/ {print $2}')
  h=$(to 20 sips -g pixelHeight "$1" 2>/dev/null | awk '/pixelHeight/ {print $2}')
  if [[ -n "$w" && -n "$h" ]]; then echo "${w}x${h}"; else echo "?"; fi
}

# ---- R6 helpers: a wall clock for log lines, quarter turns, angle ranges -------------------------------------------
# The app's lines carry no time (only HUSH-H has the app's clock, and it stops while the hinge is still), so a timed
# check runs a LINE CLOCK: a background perl loop that appends "<epoch s> <line count>" to <log>.clock every 0.2 s.
# line_time maps a line number to the first sample that had it (≤ 0.2 s late), which is enough for 1 s and 8 s rules.
CLOCK_PID=""
now_s() { perl -MTime::HiRes=time -e 'printf "%.3f\n", time'; }
clock_start() {   # clock_start <log> [max seconds, default 150]
  local f="$1"
  : > "$f.clock"
  perl -MTime::HiRes=time,sleep -e '
    my ($f, $out, $max) = @ARGV; my $end = time + $max;
    open(my $o, ">>", $out) or exit 1; select($o); $| = 1;
    while (time < $end) { my $n = 0; if (open(my $h, "<", $f)) { $n++ while <$h>; close($h) } printf "%.3f %d\n", time, $n; sleep 0.2 }
  ' "$f" "$f.clock" "${2:-150}" 2>/dev/null &
  CLOCK_PID=$!
}
clock_stop() {    # clock_stop <log>: stop the loop and add one last exact sample
  [[ -n "$CLOCK_PID" ]] && { kill "$CLOCK_PID" 2>/dev/null; wait "$CLOCK_PID" 2>/dev/null; }
  CLOCK_PID=""
  printf '%s %s\n' "$(now_s)" "$(nlines "$1")" >> "$1.clock"
}
clock_ok() { [[ "$(wc -l < "$1.clock" 2>/dev/null | tr -d ' ')" -ge 5 ]] 2>/dev/null; }   # clock_ok <log>: ≥ 5 samples
# line_time <log> <line>: the epoch second by which <line> was in the log, or "" (not sampled).
line_time() { awk -v L="$2" '$2 + 0 >= L + 0 { print $1; exit }' "$1.clock" 2>/dev/null; }
# lid_gap <log> <a> <b> <t0> <t1>: over lines a+1 … b, the longest time without a `HUSH-T lid` line, counting the
# stretch from <t0> to the first one and from the last one to <t1>: "<gap s> <lid lines> <line after the gap|end>".
lid_gap() {
  awk -v a="$2" -v b="$3" -v t0="$4" -v t1="$5" '
    function tm(L,   j) { for (j = 1; j <= m; j++) if (cn[j] + 0 >= L + 0) return ct[j]; return "" }
    FNR == NR { ct[++m] = $1; cn[m] = $2; next }
    FNR > a + 0 && FNR <= b + 0 && /HUSH-T lid / { LL[++n] = FNR }
    END {
      prev = t0; mx = 0; at = "start"
      for (i = 1; i <= n; i++) { t = tm(LL[i]); if (t == "") continue; if (t - prev > mx) { mx = t - prev; at = LL[i] }; prev = t }
      if (t1 - prev > mx) { mx = t1 - prev; at = "end" }
      printf "%.1f %d %s\n", mx, n, at
    }' "$1.clock" "$1" 2>/dev/null
}
# pause_spans <log> <a> <b> <t1>: every `HUSH-T paused …` in lines a+1 … b, timed to the next `HUSH-T resumed` /
# `HUSH-T watchdog resume` (or to <t1> if none by line b): "<longest s> <count> <line:secs,…|none>".
pause_spans() {
  awk -v a="$2" -v b="$3" -v t1="$4" '
    function tm(L,   j) { for (j = 1; j <= m; j++) if (cn[j] + 0 >= L + 0) return ct[j]; return "" }
    FNR == NR { ct[++m] = $1; cn[m] = $2; next }
    /HUSH-T paused/ { P[FNR] = 1 }
    /HUSH-T (resumed|watchdog resume)/ { R[FNR] = 1 }
    { N = FNR }
    END {
      mx = 0; k = 0; s = ""
      for (i = a + 1; i <= b; i++) if (i in P) {
        r = ""; for (j = i + 1; j <= b; j++) if (j in R) { r = j; break }
        ta = tm(i); if (ta == "") ta = t1
        tb = (r != "" ? tm(r) : ""); if (tb == "") tb = t1
        d = tb - ta; k++; if (d > mx) mx = d
        s = s sprintf("%s%d:%.1fs%s", (s == "" ? "" : ","), i, d, (r == "" ? "(no resume)" : ""))
      }
      printf "%.1f %d %s\n", mx, k, (s == "" ? "none" : s)
    }' "$1.clock" "$1" 2>/dev/null
}
# angles <log> <a> <b>: every hinge angle logged in lines a+1 … b (HUSH-H samples and the lid lines' angle field).
angles() {
  awk -v a="$2" -v b="$3" 'NR > a + 0 && NR <= b + 0 {
      if ($1 == "HUSH-H" && $3 ~ /^[0-9.]+$/) print $3
      else if (/HUSH-T lid /) for (i = 1; i < NF; i++) if ($i == "angle" && $(i + 1) ~ /^[0-9.]+$/) print $(i + 1) }' "$1" 2>/dev/null
}
hh_count() { between "$1" "$2" "$3" | grep -c '^HUSH-H ' | tr -d ' '; }   # hh_count <log> <a> <b>: HUSH-H lines
# canvas_full_before <log> <line>: the whole last `HUSH-T canvas …` line before <line> (or "").
canvas_full_before() {
  awk -v n="$2" 'NR >= n + 0 { exit } /HUSH-T canvas [0-9]+x[0-9]+/ { c = $0 } END { print c }' "$1" 2>/dev/null | tr -d '\r'
}
# canvas_k <canvas line>: the App's R6 `k=<0..3>` (quarter turns), or "" when the line has none.
canvas_k() { echo "$1" | grep -oE '(^| )k=[0-3]' | head -1 | grep -oE '[0-3]$'; }
# k_odd <canvas line>: 0 (true) when the layout is a landscape quarter turn: k odd when the line has `k=`, else (the
# pre-R6 fallback) the canvas is wider than tall. Sets K_HOW to say which.
K_HOW=""
k_odd() {
  local k wh w h
  k=$(canvas_k "$1")
  if [[ -n "$k" ]]; then K_HOW="k=$k"; (( k % 2 == 1 )); return; fi
  wh=$(echo "$1" | grep -oE "[0-9]+x[0-9]+" | head -1); w=${wh%x*}; h=${wh#*x}
  K_HOW="no k= on the canvas line; aspect ${wh:-?}"
  [[ "$w" =~ ^[0-9]+$ && "$h" =~ ^[0-9]+$ ]] && (( w > h ))
}
num() { [[ "$1" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; }
ge() { num "$1" && num "$2" && awk -v a="$1" -v b="$2" 'BEGIN { exit !(a + 0 >= b + 0) }'; }   # ge <a> <b>: a >= b
le() { num "$1" && num "$2" && awk -v a="$1" -v b="$2" 'BEGIN { exit !(a + 0 <= b + 0) }'; }   # le <a> <b>: a <= b
lid_count() { between "$1" "$2" "$3" | grep -c 'HUSH-T lid ' | tr -d ' '; }   # lid_count <log> <a> <b>
# openness <log> <a> <b>: the lid lines' openness values (field 3 of "HUSH-T lid <o> speed …").
openness() { between "$1" "$2" "$3" | awk '/HUSH-T lid / { for (i = 1; i < NF; i++) if ($i == "lid" && $(i + 1) ~ /^[0-9.]+$/) { print $(i + 1); break } }'; }
fsub() { awk -v a="$1" -v b="$2" 'BEGIN { if (a !~ /^-?[0-9.]+$/ || b !~ /^-?[0-9.]+$/) print "none"; else printf "%.1f\n", a - b }'; }

# ---- R12 helpers -----------------------------------------------------------------------------------------------------
# first_angle_line <log> <after> <le|ge> <θ>: the first `HUSH-T lid` line after <after> whose angle (the App's own
# reading, the one its shut zone uses) is <= (le) or >= (ge) θ, or "". R13: a `HUSH-H <t> <θ>` sample counts too (on
# the sim the cover display can take the run before the shut zone, and a paused run may log no lid lines).
first_angle_line() {
  awk -v a="$2" -v op="$3" -v t="$4" 'NR > a + 0 {
      v = ""
      if ($1 == "HUSH-H" && $3 ~ /^[0-9.]+$/) v = $3 + 0
      else if (/HUSH-T lid /) { for (i = 1; i < NF; i++) if ($i == "angle" && $(i + 1) ~ /^[0-9.]+$/) { v = $(i + 1) + 0; break } }
      if (v != "" && ((op == "le" && v <= t + 0) || (op == "ge" && v >= t + 0))) { print NR; exit }
    }' "$1" 2>/dev/null
}
# cover_up <log> (R13): 0 when the sim's cover display holds the app now: the latest `HUSH-T pose cover|play` line says
# cover (or, with no pose line, the latest canvas is cover-sized).
cover_up() {
  local p
  p=$(grep -oE 'HUSH-T pose (cover|play)' "$1" 2>/dev/null | tail -1 | awk '{print $3}')
  [[ "$p" == cover ]] && return 0
  [[ -n "$p" ]] && return 1
  is_cover_size "$(canvas_before "$1" $(( $(nlines "$1") + 1 )))"
}
# cover_note <log> <a> <b> (R13): "; the sim's cover display took over at line N (θ°)" when a `HUSH-T pose cover` line
# is in a+1 … b, else "".
cover_note() {
  local c
  c=$(first_line "$1" "HUSH-T pose cover" "$2")
  [[ -n "$c" ]] && (( c <= $3 )) && echo "; the sim's cover display took over at line $c ($(angle_before "$1" "$c")°)"
}
# last_lid <log> <a> <b> <field>: the <field> (angle|lid|noise|speed) of the last `HUSH-T lid` line in a+1 … b, or "none".
last_lid() { local v; v=$(between "$1" "$2" "$3" | lid_vals "$4" | grep -E '^-?[0-9.]+$' | tail -1); echo "${v:-none}"; }
# hints <log> <a> <b>: the `HUSH-T hint <name>` names logged in a+1 … b, comma-joined, or "none".
hints() { between "$1" "$2" "$3" | grep -oE 'HUSH-T hint [A-Za-z]+' | awk '{ s = s (s == "" ? "" : ",") $3 } END { print (s == "" ? "none" : s) }'; }
# hints_on: 0 when the App prints HUD hint lines (any `HUSH-T hint` other than the R6 tooWide one) in any log so far.
hints_on() { grep -hoE 'HUSH-T hint [A-Za-z]+' "$OUT_ABS"/logs/*.txt 2>/dev/null | grep -vqE ' tooWide$'; }
# bad_hints <log> <a> <b>: R12 rule 7, never ask to open an open lid: every `hint easeLidDown` (no longer produced in
# runs) and every `hint openSlowly` logged while the angle was > 20° (R13: above the 15° shut zone and the hinge's ±5°
# slack; was 115°), as "line:name@angle" (space-joined), or "".
# R14: `easeLidDown` ("Close the phone to start") is the EXPECTED hint while the run's first chest waits for the close;
# it is bad only once a chest has been opened (after the log's first `event lidCracked`).
bad_hints() {
  local ln nm an out="" fc
  fc=$(first_line "$1" "HUSH-T event lidCracked" 0)
  while IFS=: read -r ln nm; do
    [[ -n "$ln" ]] || continue
    an=$(angle_before "$1" "$ln")
    # R13 (run 40725260104): `openSlowly` over an open lid is Core's "nothing lit yet": the App words it "A little
    # wider… slowly" from openness 0.03 (≈ 4.5°; `HushCopy.hint(lidOpen:)`, unit-tested by nothingAsksToOpenAnOpenLid),
    # so only `easeLidDown` is a bad hint here (R14: and only after a chest was opened).
    if [[ "$nm" == easeLidDown && -n "$fc" ]] && (( fc < ln )); then out="$out $ln:$nm@$an"; fi
  done < <(awk -v a="$2" -v b="$3" 'NR > a + 0 && NR <= b + 0 && match($0, /HUSH-T hint (easeLidDown|openSlowly)/) {
             print NR ":" substr($0, RSTART + 12, RLENGTH - 12) }' "$1" 2>/dev/null)
  echo "${out# }"
}
# shut_gap_note <log> <a> <b> (R14): "" when a run step reached the shut zone in a+1 … b (a `HUSH-T lid` line ≤ 15°:
# the first chest was seen shut by Core itself) or nothing paused the run there; else why the first chest could not be
# seen shut: the run was paused (cover display / closing) before any step got to ≤ 15°, and the App's
# noteLidShutIfRobbed only calls session.noteLidShut() with loot in the bag or a robbed chest.
shut_gap_note() {
  local s p
  s=$(awk -v a="$2" -v b="$3" 'NR > a + 0 && NR <= b + 0 && /HUSH-T lid / {
        for (i = 1; i < NF; i++) if ($i == "angle" && $(i + 1) ~ /^[0-9.]+$/ && $(i + 1) + 0 <= 15) { print NR; exit } }' "$1" 2>/dev/null)
  [[ -n "$s" ]] && return 0
  # R14b (ab96a50): the App logs `HUSH-T first chest seen shut reason=<cover|closing|shut>` when the pause / cover /
  # shut marks it; then the gap is closed and the reason for a chest that still didn't open lies elsewhere.
  s=$(first_line "$1" "HUSH-T first chest seen shut" "$2")
  [[ -n "$s" ]] && (( s <= $3 )) && return 0
  p=$(first_line "$1" "HUSH-T (paused|pose cover)" "$2")
  [[ -n "$p" ]] && (( p <= $3 )) || return 0
  echo "; no run step reached the shut zone (no lid line ≤ ${SHUT_ZONE}°): the run was paused from line $p ($(sed -n "${p}p" "$1" | grep -oE 'HUSH-T (paused [a-z]+|pose cover)' | head -1), $(angle_before "$1" "$p")°) and GameController.noteLidShutIfRobbed calls session.noteLidShut() only with loot in the bag or a robbed chest, so the first chest was never seen shut (App gap: R14 needs it for the first chest too)"
}
# open_first_chest <log> [top °, default 150] (R14): a run launched with the lid up waits for a close: close to 5° (6 s,
# ≤ 25°/s physical, silent), a wiggle, reopen to <top> (6 s), 1° wiggles until `event lidCracked|bitten` (a held demo
# noise bites before the crack logs) or 6 s. Sets FC_OK (1|0) and FC_NOTE (what happened, for the check's detail).
FC_OK=0; FC_NOTE=""
open_first_chest() {
  local f="$1" top="${2:-150}" c0 r0 t=0 bo=""
  FC_OK=0
  if [[ -n "$(first_line "$f" "HUSH-T event (lidCracked|bitten)" 0)" ]]; then
    FC_OK=1; FC_NOTE="first chest: already open with the lid up (R14 expects it closed: see START-CLOSED)"; return 0
  fi
  c0=$(nlines "$f")
  hinge_sweep 5 6; hinge_wiggle 5 1; sleep 0.5
  r0=$(nlines "$f")
  hinge_sweep "$top" 6
  while (( t < 6 )); do
    bo=$(first_line "$f" "HUSH-T event (lidCracked|bitten)" "$c0"); [[ -n "$bo" ]] && break
    hinge_wiggle "$top" 1; t=$((t + 1))
  done
  if [[ -n "$bo" ]]; then
    FC_OK=1; FC_NOTE="first chest opened by a close to 5° and a reopen to ${top}° ($(sed -n "${bo}p" "$f" | grep -oE 'event [A-Za-z]+' | head -1)@$bo, $(angle_before "$f" "$bo")°)"
  else
    FC_NOTE="the first chest never opened after a close to 5° and a reopen to ${top}°$(shut_gap_note "$f" "$c0" "$r0")"
  fi
}
# dt_lines <log> <l1> <l2>: seconds from line l1 to line l2 by the line clock, or "none".
dt_lines() {
  local t1 t2
  t1=$(line_time "$1" "$2"); t2=$(line_time "$1" "$3")
  if [[ -n "$t1" && -n "$t2" ]]; then fsub "$t2" "$t1"; else echo none; fi
}

# How long a tabletop launch waits for a portrait canvas (or "HUSH-T orient portrait ok"). Cut to 3 s after the first
# miss, so an app without the orient key costs one 25 s wait per run, not one per launch.
ORIENT_WAIT=25

# launch <name> <demo args> <tabletop 1|0>: start the app (stdout+stderr → logs/<name>.txt), wait for its 120th frame
# and, for a tabletop launch, for a portrait canvas.
launch() {
  local name="$1" args="$2" tabletop="${3:-1}" f t=0
  f="$OUT_ABS/logs/$name.txt"
  if [[ "$tabletop" == 1 && -n "$ORIENT" ]]; then args="$args;orient=$ORIENT"; fi
  to 30 xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  : > "$f"
  to 60 xcrun simctl launch --terminate-running-process --stdout="$f" --stderr="$f" \
    "$UDID" "$BUNDLE" -hushDemo "$args" >/dev/null 2>>"$RUNLOG" || {
      log "WARN launch $name failed, retrying"; sleep 3
      to 60 xcrun simctl launch --terminate-running-process --stdout="$f" --stderr="$f" \
        "$UDID" "$BUNDLE" -hushDemo "$args" >/dev/null 2>>"$RUNLOG" || log "WARN launch $name failed twice"
    }
  while (( t < 45 )); do grep -q "HUSH-T frame 120" "$f" 2>/dev/null && break; sleep 1; t=$((t+1)); done
  (( t >= 45 )) && log "WARN $name: no 'HUSH-T frame 120' after 45 s"
  if [[ "$tabletop" == 1 && -n "$ORIENT" ]]; then
    t=0
    while (( t < ORIENT_WAIT )); do
      { grep -q "HUSH-T orient portrait ok" "$f" 2>/dev/null || is_portrait "$(canvas_line "$f")"; } && break
      sleep 1; t=$((t+1))
    done
    if (( t >= ORIENT_WAIT )); then
      log "WARN $name: no portrait canvas / 'orient portrait ok' after ${ORIENT_WAIT} s ($(canvas_line "$f"))"
      ORIENT_WAIT=3
    fi
  fi
  log "launched $name ($args): $(canvas_line "$f"); $(grep -m1 -oE 'HUSH-T input [a-z]+' "$f" 2>/dev/null); $(count 'HUSH-H' "$f") hinge lines"
  sleep 2
}

# ---- pass: the hinge checks (design/ROUND-1.md, CI engineer) ---------------------------------------------------
if [[ " $PASSES " == *" hinge "* ]]; then
  # 1. SLOW-OPEN: the closed chest, attract run (never bites), sweep 100 → 160 over 8 s (7.5°/s, under the 8°/s creak
  #    floor). PASS: `event lidCracked` and the max logged noise < 0.35 (the mimic stays Asleep).
  #    R12: starts at 100° (openness 0: the closed-chest cover) instead of 105° (0.08: under R7+ the chest is already
  #    cracked there at launch, so the old check proved nothing about the open). The shut gate is gone, so the start
  #    angle no longer has to sit in the shut zone. A crack logged before the sweep while the lid read ≤ 102° (openness
  #    ≤ 0.03) FAILs: a closed chest opened by itself.
  #    R13: the closed chest is the phone (nearly) shut: from 5° (openness 0.03; lidCracked first at 0.05 ≈ 7.5°),
  #    reached by a closing sweep (the sim keeps the inner panel lit further down when closing), 5 → 160 over 8 s
  #    (19°/s physical ≈ 8.4 lid °/s, under quietSpeed 14). To 160, not 120: if the sim lit its cover display at 5°,
  #    the inner display relights only near 150° on the way up, and the run resumes and cracks there. A crack logged
  #    before the sweep while the lid read ≤ 6° (openness ≤ 0.04) FAILs. No crack at all with the cover still lit at
  #    the top is INCONCLUSIVE (the sim's cover display, not the app).
  # 3. STILL (same launch): hold 1.5 s at 160 after the sweep. PASS: the last logged lid speed in the hold is < 1.0
  #    (speed must decay when hinge samples stop: they arrive at 25–30 Hz moving and not at all while still).
  hinge_set 40; hinge_sweep 5 1.5; hinge_set 5
  launch slow-open "screen=run;mode=attract;seed=7" 1
  SL="$OUT_ABS/logs/slow-open.txt"
  # PORTRAIT: the inner-display capture is taller than wide (taken before the timed window; a shot takes ~15 s).
  # R12: duo-h0-closed-100 (was duo-h0-ready-105) shows the closed-chest cover. R13: duo-h0-closed-5. If the sim's
  # cover display is the lit one at 5°, PORTRAIT is judged on the later wide-open frame (duo-h1) instead.
  shoot duo-h0-closed-5 inner
  scov0="$LAST_PICK"
  wh=$(png_wh "$OUT_ABS/duo-h0-closed-5.png"); cl=$(canvas_line "$SL")
  d="inner frame $wh; ${cl:-no canvas line}; orient=${ORIENT:-none}; $(grep -m1 -oE 'HUSH-T orient [a-z]+ [a-z]+' "$SL" || echo 'no HUSH-T orient line')"
  # R6: a landscape inner display is playable too (drawn with odd k, the right way up for a tabletop Duo).
  portrait_judge() {
    if is_portrait "$wh"; then result PORTRAIT PASS "$d"
    elif k_odd "$cl"; then result PORTRAIT PASS "$d (landscape interface, drawn with odd k: playable since R6)"
    else result PORTRAIT FAIL "$d (neither portrait nor an odd-k landscape canvas)"; fi
  }
  [[ "$scov0" == cover ]] || portrait_judge
  m0=$(nlines "$SL")
  sa0=$(angle_before "$SL" $(( m0 + 1 )))
  hinge_sweep 160 8
  m1=$(nlines "$SL")
  sleep 1.5
  m2=$(nlines "$SL")
  cracked=$(count "HUSH-T event lidCracked" "$SL")
  scl=$(first_line "$SL" "HUSH-T event lidCracked" 0)
  sca=$( [[ -n "$scl" ]] && angle_before "$SL" "$scl" || echo none )
  maxn=$(after "$SL" "$m0" | lid_vals noise | max_of)
  maxv=$(between "$SL" "$m0" "$m1" | lid_vals speed | max_of)
  inp=$(grep -m1 -oE "HUSH-T input [a-z]+" "$SL" | awk '{print $3}')
  hl=$(count "HUSH-H" "$SL")
  scv=""; [[ "$scov0" == cover ]] && scv="; the sim's cover display was the lit panel at 5° (the run waited for the relight)"
  d="lidCracked=$cracked (first@${scl:-none}, ${sca}°; $( [[ -n "$scl" ]] && (( scl <= m0 )) && echo 'before the sweep' || echo 'in the sweep')) start ${sa0}° maxNoise=$maxn peakSpeed=${maxv} lid°/s input=${inp:-none} HUSH-H=$hl$scv"
  if [[ -n "$scl" ]] && (( scl <= m0 )) && le "$sca" 6; then result SLOW-OPEN FAIL "$d; the closed chest (≤ 6°) cracked before the sweep"
  elif (( cracked > 0 )) && lt "$maxn" 0.35; then result SLOW-OPEN PASS "$d"
  elif (( cracked == 0 )) && cover_up "$SL"; then result SLOW-OPEN INCONCLUSIVE "$d (the sim's cover display was still lit at 160°: nothing was opened)"
  elif (( cracked == 0 )) && sgn=$(shut_gap_note "$SL" 0 "$m1") && [[ -n "$sgn" ]]; then
    result SLOW-OPEN INCONCLUSIVE "$d$sgn (R14: the closed start never counted as seen shut; START-CLOSED judges it)"
  else result SLOW-OPEN FAIL "$d"; fi
  hold=$(between "$SL" "$m1" "$m2" | lid_vals speed)
  last=$(echo "$hold" | grep -E '^-?[0-9.]+$' | tail -1)
  low=$(echo "$hold" | min_of)
  d="last speed in the 1.5 s hold=${last:-none} min=$low ($(echo "$hold" | grep -cE '^-?[0-9.]+$') lid lines)"
  if [[ -n "$last" ]] && lt "$last" 1.0; then result STILL PASS "$d"; else result STILL FAIL "$d"; fi
  shoot duo-h1-slow-open-160 inner
  if [[ "$scov0" == cover ]]; then
    wh=$(png_wh "$OUT_ABS/duo-h1-slow-open-160.png"); cl=$(canvas_line "$SL")
    d="inner frame $wh (duo-h1-slow-open-160: the cover was lit at 5°); ${cl:-no canvas line}; orient=${ORIENT:-none}; $(grep -m1 -oE 'HUSH-T orient [a-z]+ [a-z]+' "$SL" || echo 'no HUSH-T orient line')"
    portrait_judge
  fi

  # 2. SLAM: a real run, sweep 105 → 150 over 6 s, hold 2 s, then slam 150 → 104 in 0.3 s (~150°/s). PASS:
  #    `event bitten` or the stage reaching waking/biting within 2 s of the slam (lines logged since the slam began,
  #    read 2 s after the sweep returns; the hinge tool's start-up lag only makes the window longer, never shorter).
  #    R2: `freezeOn=bite` stops the session 0.3 s after the bite (DemoMode), and the inner panel is shot the moment
  #    `HUSH-T freeze bite` appears (shoot_now), so duo-h2-slam-bite shows the CHOMP and the "Too loud! −N" callout,
  #    not the next chest (tester2-duo: "the slam frame showed nothing"). A later full shot is kept for comparison.
  #    R4 (duo run 40533062342: SLAM FAIL at peakSpeed 24.4°/s): after the 2 s still hold the `hinge` tool delivered the
  #    150 → 104 slam as 1–2 samples (lid lines 146.7 → 136.0 → 103.2, speed 0), and the app's gap-aware speed rightly
  #    refuses to differentiate across that silence (the same slam in SLAM-CREAK read 91°/s). So:
  #     - the hold is no longer perfectly still: after the STILL-RUN reading, 2 tiny 1° wiggles (150 → 149 → 150, 0.4 s
  #       each way, ~2.5°/s: silent, under quietSpeed 12) keep hinge samples flowing up to the slam;
  #     - a slam whose logged peak is under SLAM_MIN_PEAK (60°/s) and that hit nothing is retried once: a gentle
  #       re-open to 150 over 8 s (~6°/s, silent), the wiggles again, the slam again;
  #     - if the retry still under-delivers (peak < 60°/s and the noise rose < 0.05), the result is INCONCLUSIVE (the
  #       tool, not the app), never FAIL. FAIL is kept for a slam that reached ≥ 60°/s (or moved the noise) and still
  #       didn't wake or bite;
  #     - every SLAM line records the slam's sample count (distinct lid angles logged inside 106–149° during the slam,
  #       plus the raw HUSH-H lines) and the attempt number.
  #    R13 (the phone is the chest): launched open at 160° (openness 1: the first chest loots at once), a 1.5 s hold,
  #    then the slam 160 → 20° in 0.4 s (350°/s physical ≈ 152 lid °/s nominal, the old slam's lid speed, over 61 lid°
  #    instead of 46). It ends at 20°: above the 15° shut zone (no bank, no next chest) and the 12° closing line (no
  #    pause). The re-open for a retry is 20 → 160 over 8 s (7.6 lid °/s, silent). SLAM_MIN_PEAK stays 60 LID °/s.
  #    The sim may hand the app to its cover display on the way down (a pause that freezes the noise): a slam the cover
  #    took before it registered is retried, and twice is INCONCLUSIVE, never FAIL.
  #    R14: duo run 40725260104 had the sim's cover display take the closing slam both times (handover at ~70°), and
  #    the first chest now waits for a close. So: launch with the lid up (160°), `open_first_chest` to 30° (close to
  #    5°, reopen to 30°: the inner display relights at ~22° and the run resumes on the lift), then an OPENING slam
  #    30 → 160° in 0.4 s (325°/s physical ≈ 141 lid °/s; opening is loud from quietSpeed 14, and no cover handover
  #    happens opening). The retry closes gently to 5° and comes back to 30° first. No open first chest: INCONCLUSIVE.
  hinge_set 160
  launch slam "screen=run;mode=run;seed=7;freezeOn=bite" 1
  SM="$OUT_ABS/logs/slam.txt"
  hinge_wiggle 160 1
  open_first_chest "$SM" 30
  sfc_ok=$FC_OK; sfc_note="$FC_NOTE"
  log "SLAM: $sfc_note"
  h0=$(nlines "$SM"); hinge_wiggle 30 1; sleep 1.5
  hl2=$(sed -n "$(( h0 + 1 )),\$p" "$SM" | lid_vals speed | grep -E '^-?[0-9.]+$' | tail -1)
  result STILL-RUN INFO "last speed 1.5 s into the hold at 30 (real run)=${hl2:-none}"
  attempt=1; froze=""; hit=""; bit=""; peak=none; pn=none; n0=none; ns=""; scov=""
  while (( sfc_ok )); do
    hinge_wiggle 30 2
    n0=$(head -n "$(nlines "$SM")" "$SM" | lid_vals noise | grep -E '^-?[0-9.]+$' | tail -1)
    s0=$(nlines "$SM")
    hinge_sweep 160 0.4
    # The bite usually lands while the sweep call is still returning; catch the freeze line as soon as it is there.
    if wait_for "$SM" "HUSH-T freeze bite" 3; then shoot_now duo-h2-slam-bite; froze="froze on the bite"
    else froze="no 'HUSH-T freeze bite' within 3 s"; fi
    sleep 0.5
    hit=$(after "$SM" "$s0" | grep -m1 -E "HUSH-T (event bitten|event stageChanged .*to=(waking|biting)|lid .* stage (waking|biting))" | tr -d '\r')
    bit=$(after "$SM" "$s0" | grep -m1 -E "HUSH-T event bitten" | tr -d '\r')
    peak=$(after "$SM" "$s0" | lid_vals speed | max_of)
    pn=$(after "$SM" "$s0" | lid_vals noise | max_of)
    ns=$(slam_samples "$SM" "$s0" 155 ge)
    scov=$(after "$SM" "$s0" | grep -m1 -oE "HUSH-T pose cover[^\r]*" | tr -d '\r')
    log "SLAM attempt $attempt: peakSpeed=${peak} lid°/s noise ${n0:-none} -> $pn; $ns; ${hit:-no hit}${scov:+; $scov}"
    [[ -n "$hit" ]] && break
    { [[ "$peak" == none ]] || lt "$peak" "$SLAM_MIN_PEAK" || [[ -n "$scov" ]]; } || break
    (( attempt >= 2 )) && break
    attempt=2
    log "SLAM: peak ${peak} lid°/s (line ${SLAM_MIN_PEAK}), no hit${scov:+, the sim cover display took over}: close gently to 5°, back to 30° and slam again"
    hinge_sweep 5 6; hinge_wiggle 5 1; hinge_sweep 30 3
    sleep 1
  done
  rise=$(awk -v a="${n0:-0}" -v b="$pn" 'BEGIN { if (b !~ /^-?[0-9.]+$/) print "none"; else printf "%.2f\n", b - (a ~ /^-?[0-9.]+$/ ? a : 0) }')
  d="$sfc_note; attempt $attempt/2; slam 30 → 160° in 0.4 s; peakSpeed=${peak} lid°/s (hinge × 0.4333); slam samples: $ns; noise ${n0:-none} -> $pn (rise $rise); first: ${hit:-none}; bite: ${bit:-none}; $froze${scov:+; cover: $scov}"
  # R7 (real hands: closing quiet 28 deg/s, 0.08 s onset): a sim slam (the tool's peak is ~80 deg/s) may only stir;
  # it must still register as clearly too loud (noise rise >= 0.35, i.e. Stirring).
  if (( ! sfc_ok )); then result SLAM INCONCLUSIVE "$sfc_note (no open chest to slam: START-CLOSED judges the first chest)"
  elif [[ -n "$hit" ]]; then result SLAM PASS "$d"
  elif [[ "$rise" != none ]] && ge "$rise" 0.35; then result SLAM PASS "$d (registered as loud: rise $rise >= 0.35)"
  elif { [[ "$peak" == none ]] || lt "$peak" "$SLAM_MIN_PEAK"; } && { [[ "$rise" == none ]] || lt "$rise" 0.05; }; then
    result SLAM INCONCLUSIVE "$d (the hinge tool under-delivered the slam twice: peak < ${SLAM_MIN_PEAK} lid°/s, noise unchanged)"
  elif [[ -n "$scov" ]]; then
    result SLAM INCONCLUSIVE "$d (the sim's cover display took the run mid-slam both times: the pause froze the noise)"
  else result SLAM FAIL "$d"; fi
  [[ -f "$OUT_ABS/duo-h2-slam-bite.png" ]] || shoot_now duo-h2-slam-bite
  shoot duo-h2-after-slam inner

  # 2b. SLAM-CREAK (R3, tester 6): the same slam in attract mode (never bites), so the frame is the CREAK accent alone:
  #     the "CREAK!" shake and the red flash on the meter when the noise jumps > 0.25 in 0.3 s (Scene/Feel rule; the
  #     App logs it and freezes on `freezeOn=creak`, design/NEEDS.md CI R3). PASS: a creak line within 3 s of the
  #     slam. FAIL: no creak line although the logged noise rose > 0.25 over 3 lid samples. INFO otherwise (no line,
  #     no measurable jump: the App hook or the attract noise may be missing).
  #     R13: the same slam as SLAM, 160 → 20° in 0.4 s from an open start at 160°. R14: as SLAM, `open_first_chest` to
  #     30°, then the opening slam 30 → 160° in 0.4 s; no open first chest: INCONCLUSIVE.
  hinge_set 160
  launch slam-creak "screen=run;mode=attract;seed=7;freezeOn=creak" 1
  SK="$OUT_ABS/logs/slam-creak.txt"
  hinge_wiggle 160 1
  open_first_chest "$SK" 30
  kfc_ok=$FC_OK; kfc_note="$FC_NOTE"
  hinge_wiggle 30 1; sleep 1.5; hinge_wiggle 30 1
  k0=$(nlines "$SK")
  hinge_sweep 160 0.4
  if wait_for "$SK" "HUSH-T (freeze creak|event creak|creak )" 3; then shoot_now duo-h2c-slam-creak; got="creak line seen"
  else shoot_now duo-h2c-slam-creak; got="no creak line within 3 s (shot anyway)"; fi
  sleep 0.5
  kl=$(after "$SK" "$k0" | grep -m1 -E "HUSH-T (freeze creak|event creak|creak )" | tr -d '\r')
  kj=$(after "$SK" "$k0" | lid_vals noise | max_jump)
  kp=$(after "$SK" "$k0" | lid_vals speed | max_of)
  d="$kfc_note; peakSpeed=${kp} lid°/s noise jump(0.3 s)=$kj; first: ${kl:-none}; $got$(cover_note "$SK" "$k0" "$(nlines "$SK")")"
  if [[ -n "$kl" ]]; then result SLAM-CREAK PASS "$d"
  elif (( ! kfc_ok )); then result SLAM-CREAK INCONCLUSIVE "$d (no open chest to slam: START-CLOSED judges the first chest)"
  elif [[ "$kj" != none ]] && awk -v j="$kj" 'BEGIN { exit !(j + 0 > 0.25) }'; then result SLAM-CREAK FAIL "$d (the rule was met)"
  else result SLAM-CREAK INFO "$d (no line and no jump > 0.25 logged: App hook pending?)"; fi

  # 4a. UPRIGHT-NO-PAUSE (REVIEW-1-duo P1-4): the closing pause moved from 85° to 70° so a lid resting upright (90°,
  #     which the Duo can read as low as ~84°) never pauses. From 120, sweep to 78° and hold 2 s: no `paused closing`.
  # 4b. CLOSE-PAUSE: then on down to 55° (< 70° held 0.4 s pauses) → `paused closing`; back to 120 → `resumed`.
  # R13 (the phone is the chest): a phone at 25° is an OPEN chest (openness 0.17), so UPRIGHT-NO-PAUSE holds the lid
  #     low but open: 120 → 25° (2 s), held 2 s: no `paused closing` (the line is 12°). A cover-display pause the sim
  #     may throw in on the way down is reported, not judged (COVER-SLOW-CLOSE owns that). CLOSE-PAUSE: on down to 5°
  #     (< 12° held 0.4 s) → `paused closing` (any `HUSH-T paused` counts when the sim's cover display took the run
  #     first; the detail says which); reopen to 40° and hold still (resume at ≥ 18°, still) → `resumed`; if nothing
  #     resumed and the cover display is still up (the sim relights only near 150°), on to 165° and look again.
  hinge_set 120
  launch close-pause "screen=run;mode=attract;seed=7" 1
  CP="$OUT_ABS/logs/close-pause.txt"
  hinge_wiggle 120 1; sleep 1
  u0=$(nlines "$CP")
  hinge_sweep 25 2; sleep 2
  u1=$(nlines "$CP")
  up=$(first_line "$CP" "HUSH-T paused closing" "$u0")
  ucov=$(between "$CP" "$u0" "$u1" | grep -m1 -oE "HUSH-T paused [a-z]+" | tr -d '\r')
  d="held 25° (openness 0.17) for 2 s: $( [[ -n "$up" ]] && echo "paused closing at line $up (angle $(angle_before "$CP" "$up")°)" || echo "no closing pause" ); last angle $(angle_before "$CP" $(( u1 + 1 )))°${ucov:+; first pause line: $ucov}$(cover_note "$CP" "$u0" "$u1")"
  if [[ -z "$up" ]]; then result UPRIGHT-NO-PAUSE PASS "$d"; else result UPRIGHT-NO-PAUSE FAIL "$d (closing line still above 25°? R13: 12°)"; fi
  hinge_sweep 5 1; hinge_wiggle 5 1; sleep 1
  p=$(first_line "$CP" "HUSH-T paused closing" "$u1")
  [[ -z "$p" && -n "$up" ]] && p="$up"
  [[ -z "$p" ]] && p=$(first_line "$CP" "HUSH-T paused" "$u0")
  pw=$( [[ -n "$p" ]] && sed -n "${p}p" "$CP" | grep -oE "paused [a-z]+" | awk '{print $2}' )
  shoot duo-h3-closing-card-5 inner
  went=40
  hinge_sweep 40 1.5; sleep 2
  r=""
  [[ -n "$p" ]] && r=$(first_line "$CP" "HUSH-T resumed" "$p")
  if [[ -n "$p" && -z "$r" ]] && cover_up "$CP"; then
    went=165; log "CLOSE-PAUSE: no resume at 40° and the sim's cover display is still up: on to 165°"
    hinge_sweep 165 1.5; sleep 2
    r=$(first_line "$CP" "HUSH-T resumed" "$p")
  fi
  d="paused@line ${p:-none} (${pw:-?}, angle $( [[ -n "$p" ]] && angle_before "$CP" "$p" || echo -)°), reopened to ${went}°, resumed@line ${r:-none} (angle $( [[ -n "$r" ]] && angle_before "$CP" "$r" || echo -)°); HUSH-H=$(count 'HUSH-H' "$CP")$(cover_note "$CP" "$u1" "$(nlines "$CP")")"
  if [[ -n "$p" && -n "$r" ]]; then result CLOSE-PAUSE PASS "$d"
  elif [[ -n "$p" ]] && cover_up "$CP"; then result CLOSE-PAUSE INCONCLUSIVE "$d (the sim's cover display was still lit at 165°)"
  else result CLOSE-PAUSE FAIL "$d"; fi
  shoot "duo-h4-resumed-$went" inner

  # 5. REOPEN-NO-BITE (REVIEW-1-duo P0-2, QA-1 P1-2): a real run (bites on) with the noise held at 0.6 until the pause
  #    (`noiseUntil=pause` releases the demo hold at the first pause and logs `HUSH-T noise released`). Open gently to
  #    130° (6°/s), lower gently to 60° (14°/s, under the closing creak), wait 2 s on the closing card, then reopen to
  #    120° in 0.4 s (~150°/s: the "normal" hand). PASS: no `event bitten` within 2 s of the reopen, no `resumed`
  #    while the lid was still low, and the first `resumed` after the reopen only once a logged angle is >= 95°.
  #    Without the release line the hold stays on all run (a bite is impossible), so a clean run is INFO, not PASS.
  #    R13: launched open at 150° (the chest loots at once), lowered gently to 5° over 6 s (24°/s physical ≈ 10.5 lid
  #    °/s, under closeQuietSpeed 28), 2 s on the closing card, then the quick hand: 5 → 160° in 0.5 s (310°/s ≈ 134
  #    lid °/s, the old 150°/s reopen's lid speed; to 160 so the sim's cover display, if it took the run on the way
  #    down, relights inside the move). The first `resumed` must be at a logged angle ≥ 15° (R13: resume at 18°,
  #    hysteresis 15°). If the sim took the run to its cover display, the first pause may be `paused pose`: it counts.
  hinge_set 150
  launch reopen "screen=run;mode=run;seed=7;noise=0.6;noiseUntil=pause" 1
  RO="$OUT_ABS/logs/reopen.txt"
  hinge_wiggle 150 1; sleep 1
  c0=$(nlines "$RO")
  hinge_sweep 5 6; sleep 2
  p=$(first_line "$RO" "HUSH-T paused closing" "$c0")
  [[ -z "$p" ]] && p=$(first_line "$RO" "HUSH-T paused" "$c0")
  # (no shot here: a shot takes 3–15 s and the wait on the card must stay 2 s; duo-h3 already shows the closing card)
  r0=$(nlines "$RO")
  early=$(first_line "$RO" "HUSH-T resumed" "${p:-$c0}")
  [[ -n "$early" && "$early" -gt "$r0" ]] && early=""
  hinge_sweep 160 0.5
  sleep 2
  r2=$(nlines "$RO")
  sleep 3
  bitten=$(between "$RO" "$r0" "$r2" | grep -m1 -E "HUSH-T event bitten" | tr -d '\r')
  waking=$(between "$RO" "$r0" "$r2" | grep -m1 -E "HUSH-T event stageChanged .*to=(waking|biting)" | tr -d '\r')
  rl=$(first_line "$RO" "HUSH-T resumed" "$r0")
  ra=""
  if [[ -n "$rl" ]]; then
    ra=$(sed -n "${rl}p" "$RO" | grep -oE "angle [0-9.]+" | awk '{print $2}')
    [[ -n "$ra" ]] || ra=$(angle_before "$RO" "$rl")
  fi
  released=$(count "HUSH-T noise released" "$RO")
  # Duo run 40510297922: the pause line can land in the log after the 2 s wait (it was at line 655, the resume at
  # 662), so look again now, and accept it if it comes before the resume.
  if [[ -z "$p" ]]; then
    p=$(first_line "$RO" "HUSH-T paused" "$c0")
    [[ -n "$p" && -n "$rl" && "$p" -gt "$rl" ]] && p=""
  fi
  pre=$( [[ -n "$p" ]] && angle_before "$RO" "$p" || echo -)
  pw=$( [[ -n "$p" ]] && sed -n "${p}p" "$RO" | grep -oE "paused [a-z]+" | awk '{print $2}' )
  maxn=$(after "$RO" "${rl:-$r0}" | lid_vals noise | max_of)
  d="paused@${p:-none} (${pw:-?}, ${pre}°); resumed while low: ${early:-no}; resumed@${rl:-none} angle ${ra:-none}°; bitten≤2s: ${bitten:-none}; waking≤2s: ${waking:-none}; maxNoise after resume=$maxn; noise released=$released$(cover_note "$RO" "$c0" "$r0")"
  verdict=PASS
  [[ -z "$p" ]] && { verdict=FAIL; d="$d; never paused at 5°"; }
  [[ -n "$early" ]] && { verdict=FAIL; d="$d; resumed before the reopen"; }
  [[ -n "$bitten" ]] && verdict=FAIL
  if [[ -z "$rl" ]]; then
    if cover_up "$RO"; then verdict=INCONCLUSIVE; d="$d; no resume: the sim's cover display was still lit at 160°"
    else verdict=FAIL; d="$d; no resume within 5 s of the reopen"; fi
  elif [[ "$ra" == none ]] || lt "$ra" "$RESUME_LOW"; then verdict=FAIL; d="$d; resumed below ${RESUME_LOW}° (R13: resume enters at ${RESUME_LINE}°, hysteresis ${RESUME_LOW}°)"; fi
  [[ -n "$bitten" || -n "$early" || -z "$p" ]] && [[ "$verdict" == INCONCLUSIVE ]] && verdict=FAIL
  if [[ "$verdict" == PASS && "$released" == 0 ]]; then
    verdict=INFO; d="$d; INCONCLUSIVE: no 'HUSH-T noise released', so noise=0.6 was held all run (no bite possible). App: noiseUntil=pause (design/NEEDS.md)"
  fi
  # R14: launched with the lid up, the first chest waits for this close; the reopen should open it (a bite needs a
  # looting chest). Without a lidCracked after the reopen no bite was possible: INCONCLUSIVE, with the reason.
  rcr=$(first_line "$RO" "HUSH-T event lidCracked" "$r0")
  if [[ "$verdict" == PASS && -z "$rcr" ]]; then
    verdict=INCONCLUSIVE; d="$d; the chest never opened on the reopen, so no bite was possible$(shut_gap_note "$RO" "$c0" "$r0")"
  else d="$d; lidCracked after the reopen@${rcr:-none}"; fi
  result REOPEN-NO-BITE "$verdict" "$d"
  shoot duo-h6-reopened-160 inner

  # 6. COVER-SLOW-CLOSE (R3 decision 1, REVIEW-2-duo P0-1): the cover display is a pause, always. A real run with the
  #    noise held at 0.6 until the first pause (then frozen there, decision 2). From 120°, close gently to 40° over 6 s
  #    (13°/s, under the 18°/s closing creak: iOS hands the app to the cover display around 74–92° on the sim), then
  #    hold 3 s. PASS: a `HUSH-T paused` line, no `HUSH-T pose play` on a cover-sized canvas and no `small-canvas-open`
  #    (the deleted R2 fallback), and no `HUSH-T resumed` after the pause.
  #    R13: from an open 150°, the gentle close is 150 → 5° over 6 s (24°/s physical ≈ 10.5 lid °/s), then 3 s at 5°
  #    (under the 12° closing line, so the run pauses whether or not the sim's cover display takes it on the way: on
  #    the sim it may now do so while the chest is still open, which must be a pause too).
  hinge_set 150
  launch cover-slow "screen=run;mode=run;seed=7;noise=0.6;noiseUntil=pause" 1
  CS="$OUT_ABS/logs/cover-slow.txt"
  hinge_wiggle 150 1; sleep 1
  k0=$(nlines "$CS")
  hinge_sweep 5 6; sleep 3
  k1=$(nlines "$CS")
  kp=$(first_line "$CS" "HUSH-T paused" "$k0")
  kc=$(first_line "$CS" "HUSH-T pose cover" "$k0")
  kca=$( [[ -n "$kc" ]] && sed -n "${kc}p" "$CS" | grep -oE "angle=[0-9.]+" | head -1 )
  bad=""
  while IFS=: read -r ln sz; do
    [[ -n "$ln" ]] || continue
    [[ -n "$sz" ]] || sz=$(canvas_before "$CS" "$ln")
    is_cover_size "$sz" && bad="$bad line $ln ($sz)"
  done < <(awk -v a="$k0" -v b="$k1" 'NR > a + 0 && NR <= b + 0 && /HUSH-T pose play/ {
             s = ""; if (match($0, /[0-9]+x[0-9]+/)) s = substr($0, RSTART, RLENGTH); print NR ":" s }' "$CS" 2>/dev/null)
  small=$(between "$CS" "$k0" "$k1" | grep -c "small-canvas-open" | tr -d ' ')
  kr=""; [[ -n "$kp" ]] && kr=$(first_line "$CS" "HUSH-T resumed" "$kp")
  [[ -n "$kr" && "$kr" -gt "$k1" ]] && kr=""
  d="paused@${kp:-none} ($( [[ -n "$kp" ]] && sed -n "${kp}p" "$CS" | grep -oE 'paused [a-z]+' || echo -), $( [[ -n "$kp" ]] && angle_before "$CS" "$kp" || echo -)°); cover pose@${kc:-none} ${kca:-}; play-on-cover:${bad:- none}; small-canvas-open=$small; resumed while low: ${kr:-no}; last canvas $(canvas_before "$CS" $(( k1 + 1 )))"
  if [[ -n "$kp" && -z "$bad" && "${small:-0}" == 0 && -z "$kr" ]]; then result COVER-SLOW-CLOSE PASS "$d"
  else result COVER-SLOW-CLOSE FAIL "$d"; fi

  # 7. COVER-SLOW-REOPEN: on down to shut (0°, the cover display), 3 s there, then reopen over 5 s to 140° (28°/s: the
  #    hardware relights the inner display somewhere on the way). PASS: the first `HUSH-T resumed` comes on the inner
  #    canvas ($INNER_CANVAS) at a logged angle >= 95°, no resume at all on a cover-sized canvas, and no `event
  #    bitten` in the 2 s after the resume. A clean run without `HUSH-T noise released` is INFO (the hold made a bite
  #    impossible), as in REOPEN-NO-BITE. R13: from 5° to 0°; 0 → 140° over 5 s is 28°/s physical ≈ 12 lid °/s (under
  #    quietSpeed 14); the first resume must be at a logged angle ≥ 15° (resume 18°, hysteresis 15°).
  hinge_sweep 1 0.5; hinge_set 0; sleep 3
  shoot duo-h7-cover-after-slow-close cover
  m0=$(nlines "$CS")
  hinge_sweep 140 5
  rl=""; t=0; went=140
  while (( t < 20 )); do rl=$(first_line "$CS" "HUSH-T resumed" "$m0"); [[ -n "$rl" ]] && break; sleep 0.2; t=$((t+1)); done
  if [[ -z "$rl" ]]; then
    # The sim can keep the cover display lit up to ~150° on a reopen (R2 duo3: still lit at 118°, resumed at 134°,
    # Brim: ~150°). Not resuming on the cover is right; go on to 165° (the known relight) and look again.
    went=165
    hinge_sweep 165 1
    t=0
    while (( t < 30 )); do rl=$(first_line "$CS" "HUSH-T resumed" "$m0"); [[ -n "$rl" ]] && break; sleep 0.2; t=$((t+1)); done
  fi
  sleep 2
  mb=$(nlines "$CS")
  sleep 1
  ra=""; rc="none"; bit=""
  if [[ -n "$rl" ]]; then
    ra=$(sed -n "${rl}p" "$CS" | grep -oE "angle [0-9.]+" | awk '{print $2}')
    [[ -n "$ra" ]] || ra=$(angle_before "$CS" "$rl")
    rc=$(canvas_before "$CS" "$rl")
    bit=$(between "$CS" "$rl" "$mb" | grep -m1 -E "HUSH-T event bitten" | tr -d '\r')
  fi
  oncover=""
  while read -r ln; do
    [[ -n "$ln" ]] || continue
    c=$(canvas_before "$CS" "$ln"); is_cover_size "$c" && oncover="$oncover line $ln ($c)"
  done < <(awk -v a="$m0" '/HUSH-T resumed/ && NR > a + 0 { print NR }' "$CS" 2>/dev/null)
  pl=$(first_line "$CS" "HUSH-T pose play" "$m0")
  relight=$( [[ -n "$pl" ]] && angle_before "$CS" "$pl" || echo none )
  released=$(count "HUSH-T noise released" "$CS")
  d="reopened to ${went}°; resumed@${rl:-none} angle ${ra:-none}° canvas $rc; relit (pose play)@${pl:-none} ~${relight}°$(grep -m1 -oE 'HUSH-T relight angle=[0-9.]+' "$CS" | sed 's/^HUSH-T / /'); resumed on cover:${oncover:- none}; bitten≤2s: ${bit:-none}; maxNoise after=$(after "$CS" "${rl:-$m0}" | lid_vals noise | max_of); noise released=$released"
  verdict=PASS
  if [[ -z "$rl" ]]; then
    if cover_up "$CS"; then verdict=INCONCLUSIVE; d="$d; no resume: the sim's cover display was still lit at 165°"
    else verdict=FAIL; d="$d; no resume after the reopen (even at 165°)"; fi
  else
    { [[ "$ra" == none ]] || lt "$ra" "$RESUME_LOW"; } && { verdict=FAIL; d="$d; resumed below ${RESUME_LOW}° (R13 hysteresis)"; }
    inner_flip="${INNER_CANVAS#*x}x${INNER_CANVAS%x*}"   # R6: the inner display may be landscape (odd k) too
    [[ "$rc" != "$INNER_CANVAS" && "$rc" != "$inner_flip" ]] && { verdict=FAIL; d="$d; resumed on $rc, not the inner $INNER_CANVAS or $inner_flip"; }
  fi
  [[ -n "$oncover" ]] && verdict=FAIL
  [[ -n "$bit" ]] && verdict=FAIL
  if [[ "$verdict" == PASS && "$released" == 0 ]]; then
    verdict=INFO; d="$d; INCONCLUSIVE: no 'HUSH-T noise released' (noise held all run, no bite possible)"
  fi
  # R14: the run's first chest waited for this close; the reopen should open it (else no bite was possible).
  ccr=$(first_line "$CS" "HUSH-T event lidCracked" "$m0")
  if [[ "$verdict" == PASS && -z "$ccr" ]]; then
    verdict=INCONCLUSIVE; d="$d; the chest never opened on the reopen, so no bite was possible$(shut_gap_note "$CS" "$k0" "$m0")"
  else d="$d; lidCracked after the reopen@${ccr:-none}"; fi
  result COVER-SLOW-REOPEN "$verdict" "$d"
  shoot "duo-h8-cover-slow-reopened-$went" inner

  # ---- R6 (design/ROUND-6.md "CI engineer" 2, the founder's real-Duo P0: "when i open the whole phone it gets stuck") --
  # 8. FLAT-OPEN: an attract run (`screen=run;mode=attract`), sweep 140 → 180 over 4 s, hold 3 s at the top, sweep back
  #    to 140 over 4 s, then 1.5 s more. The hold is perfectly STILL on purpose: a Duo lying flat sends nothing, and the
  #    App must keep the last angle and the hinge input through that (and through a nil hinge context at 175–180°).
  #    Timed with the line clock. PASS: `HUSH-T lid` lines throughout (no stretch without one > FLAT_GAP_MAX, 1.2 s =
  #    the 1 s rule + the clock's 0.2 s grain), no pause lasting > 1 s, no switch to the slider, and lid lines after the
  #    return (the run is still live). Tool lesson (R4): a window whose logged angles never reach 170° is retried once
  #    (wiggles at 140 first, so samples are flowing); twice → INCONCLUSIVE (the tool), never FAIL.
  FLAT_TOP="${FLAT_TOP:-180}"
  # R9: 1.6 s. Duo run 40625977143 FAILed at exactly 1.2 s: the gap sat on the DEBUG-only `orient=portrait` demo loop
  # (its 30 s re-asks fail while a live run holds landscape; Release never runs it); play itself never paused.
  FLAT_GAP_MAX="${FLAT_GAP_MAX:-1.6}"
  hinge_set 140
  launch flat-open "screen=run;mode=attract;seed=7" 1
  FO="$OUT_ABS/logs/flat-open.txt"
  attempt=1
  while :; do
    hinge_wiggle 140 1
    clock_start "$FO"
    f0=$(nlines "$FO"); ft0=$(now_s)
    hinge_sweep "$FLAT_TOP" 4
    f1=$(nlines "$FO")
    sleep 3
    f2=$(nlines "$FO")
    hinge_sweep 140 4
    f3=$(nlines "$FO")
    sleep 1.5
    f4=$(nlines "$FO"); ft4=$(now_s)
    clock_stop "$FO"
    ftop=$(angles "$FO" "$f0" "$f3" | max_of)
    log "FLAT-OPEN attempt $attempt: top logged angle ${ftop}°; HUSH-H up/hold/back=$(hh_count "$FO" "$f0" "$f1")/$(hh_count "$FO" "$f1" "$f2")/$(hh_count "$FO" "$f2" "$f3")"
    ge "$ftop" 170 && break
    (( attempt >= 2 )) && break
    attempt=2
    log "FLAT-OPEN: the logged angle never reached 170° (the hinge tool under-delivered?): again"
    hinge_set 140; sleep 1
  done
  fgap=""; _flids=""; fgat=""; fpmax=""; fpn=""; fplist=""
  read -r fgap _flids fgat < <(lid_gap "$FO" "$f0" "$f4" "$ft0" "$ft4")
  read -r fpmax fpn fplist < <(pause_spans "$FO" "$f0" "$f4" "$ft4")
  fup=$(lid_count "$FO" "$f0" "$f1"); fhold=$(lid_count "$FO" "$f1" "$f2")
  fback=$(lid_count "$FO" "$f2" "$f3"); fafter=$(lid_count "$FO" "$f3" "$f4")
  fnil=$(between "$FO" "$f0" "$f4" | grep -cE 'HUSH-T lid .* angle - ' | tr -d ' ')
  fsl=$(between "$FO" "$f0" "$f4" | grep -m1 -oE 'HUSH-T input (slider|switch.*->slider)[^\r]*')
  fin=$(grep -oE "HUSH-T input [a-z]+" "$FO" | tail -1 | awk '{print $3}')
  fend=$(angles "$FO" "$f3" "$f4" | tail -1)
  d="attempt $attempt/2; top ${ftop}°; lid lines up/hold/back/after=$fup/$fhold/$fback/$fafter; longest gap without a lid line ${fgap:-?} s (before ${fgat:-?}); pauses ${fpn:-?} (longest ${fpmax:-?} s: ${fplist:-?}); lid lines with angle '-' (no hinge angle): $fnil; slider: ${fsl:-none}; input ${fin:-none}; angle after the return ${fend:-none}°"
  if ! ge "$ftop" 170; then
    result FLAT-OPEN INCONCLUSIVE "$d (the hinge tool never delivered the flat open twice: no logged angle ≥ 170°)"
  elif ! clock_ok "$FO"; then
    # No line clock (perl failed?): judge on line counts (10 Hz: ≥ 15 in the 3 s hold, ≥ 7 in the 1.5 s after) and
    # on every pause having a resume inside the window.
    if (( fhold >= 15 && fafter >= 7 )) && [[ -z "$fsl" && "$fplist" != *"no resume"* ]]; then
      result FLAT-OPEN PASS "$d (no line clock: judged on line counts)"
    else result FLAT-OPEN FAIL "$d (no line clock: judged on line counts)"; fi
  else
    why=""
    ge "$fgap" "$FLAT_GAP_MAX" && why="$why; lid lines stopped for ${fgap} s (> ${FLAT_GAP_MAX})"
    num "$fpmax" && awk -v p="$fpmax" 'BEGIN { exit !(p + 0 > 1.0) }' && why="$why; a pause lasted ${fpmax} s (> 1 s)"
    (( fafter < 3 )) && why="$why; no lid lines after the return (the run is not live)"
    [[ -n "$fsl" ]] && why="$why; switched to the slider"
    # R14: "That's wide enough" never shows (AppRules.showsHint), even flat at 180°.
    ftw=$(between "$FO" "$f0" "$f4" | grep -c 'HUSH-T hint tooWide' | tr -d ' ')
    (( ftw > 0 )) && why="$why; 'hint tooWide' logged $ftw time(s) (R14: never shown)"
    if [[ -z "$why" ]]; then result FLAT-OPEN PASS "$d"; else result FLAT-OPEN FAIL "$d$why"; fi
  fi
  shoot duo-h9-flat-open-after inner

  # 9. WATCHDOG (R6 App 6, never stuck): an attract run at 130°, a gentle close to 60° (5 s, 14°/s: under the closing
  #    creak) and a 1° wiggle there (the closing pause: < 70° held 0.4 s); then the reopen to 130° at the slowest step
  #    this tool offers (`hinge` has no step size: a long 60 Hz sweep, WATCHDOG_REOPEN_S = 14 s, 5°/s), then tiny 1°
  #    wiggles at 130 (so the lid is never perfectly still for the resume gate) until a resume or 8 s. Line clock.
  #    PASS: a `HUSH-T resumed` or `HUSH-T watchdog resume` no later than 8 s after the reopen reached 130 (one on the
  #    way up, after the reopen began, is a pass too). FAIL: a resume before the reopen began (lid still at 60°); paused,
  #    the reopen arrived (a logged angle ≥ 95°) and nothing resumed in 8 s (stuck); or no pause although the log went
  #    ≤ 65°. INCONCLUSIVE: the tool never delivered the close (nothing ≤ 70° logged, after one more try) or the reopen.
  #    R13: the close is 130 → 5° (5 s, 25°/s physical ≈ 11 lid °/s) and a wiggle at 5° (the pause: < 12° held 0.4 s);
  #    the slow reopen is 5 → 160° over WATCHDOG_REOPEN_S (14 s, 11°/s: never "still", which is < 6°/s below 100° and
  #    < 10°/s above, so only the hold at the top or the watchdog can resume) to 160°, not 130°: the sim's cover display,
  #    which may have taken the run on the close, relights only near 150°. The 8 s count from reaching 160. FAIL: a
  #    resume while the lid was still at 5°; paused, the reopen arrived (a logged angle ≥ 140°) and nothing resumed in
  #    8 s (stuck); or no pause although the log went ≤ 10°. INCONCLUSIVE: nothing ≤ 12° logged (after one more try),
  #    the reopen never reached 140°, or nothing resumed with the cover display still lit at the top.
  WD_REOPEN_S="${WATCHDOG_REOPEN_S:-14}"
  WD_LIMIT="${WATCHDOG_LIMIT:-8}"
  WD_TOP=160
  hinge_set 130
  launch watchdog "screen=run;mode=attract;seed=7" 1
  WD="$OUT_ABS/logs/watchdog.txt"
  hinge_wiggle 130 1; sleep 1
  w0=$(nlines "$WD")
  hinge_sweep 5 5; hinge_wiggle 5 1; sleep 0.5
  wp=$(first_line "$WD" "HUSH-T paused" "$w0")
  wlow=$(angles "$WD" "$w0" "$(nlines "$WD")" | min_of)
  if [[ -z "$wp" ]] && ! le "$wlow" "$CLOSE_LINE"; then
    log "WATCHDOG: no pause and nothing ≤ ${CLOSE_LINE}° logged (lowest ${wlow}°): the hinge tool under-delivered? close again"
    hinge_set 5; hinge_wiggle 5 2; sleep 0.5
    wp=$(first_line "$WD" "HUSH-T paused" "$w0")
    wlow=$(angles "$WD" "$w0" "$(nlines "$WD")" | min_of)
  fi
  w1=$(nlines "$WD")
  wearly=""
  [[ -n "$wp" ]] && wearly=$(between "$WD" "$wp" "$w1" | grep -m1 -oE "HUSH-T (resumed|watchdog resume)[^\r]*")
  clock_start "$WD"
  hinge_sweep "$WD_TOP" "$WD_REOPEN_S"
  w2=$(nlines "$WD"); wt2=$(now_s)
  wr=""; wn=0
  while :; do
    wr=$(first_line "$WD" "HUSH-T (resumed|watchdog resume)" "$w1"); [[ -n "$wr" ]] && break
    awk -v a="$(now_s)" -v b="$wt2" -v l="$WD_LIMIT" 'BEGIN { exit !(a - b >= l + 0.5) }' && break
    hinge_wiggle "$WD_TOP" 1; wn=$((wn + 1))
  done
  sleep 0.5
  w3=$(nlines "$WD")
  clock_stop "$WD"
  [[ -n "$wr" ]] || wr=$(first_line "$WD" "HUSH-T (resumed|watchdog resume)" "$w1")
  wdt=none; wline=""; wang=""; wwhen="no resume"
  if [[ -n "$wr" ]]; then
    wline=$(sed -n "${wr}p" "$WD" | grep -oE "HUSH-T (resumed|watchdog resume)[^\r]*")
    wang=$(echo "$wline" | grep -oE "angle [0-9.]+" | awk '{print $2}'); [[ -n "$wang" ]] || wang=$(angle_before "$WD" "$wr")
    wrt=$(line_time "$WD" "$wr"); [[ -n "$wrt" ]] && wdt=$(fsub "$wrt" "$wt2")
    if (( wr <= w2 )); then wwhen="during the reopen (${wdt} s vs reaching $WD_TOP)"; wdt=on-the-way-up
    else wwhen="${wdt} s after reaching $WD_TOP"; fi
  fi
  wtop=$(angles "$WD" "$w1" "$w3" | max_of)
  wpa=$( [[ -n "$wp" ]] && angle_before "$WD" "$wp" || echo - )
  wpw=$( [[ -n "$wp" ]] && sed -n "${wp}p" "$WD" | grep -oE "paused [a-z]+" | awk '{print $2}' )
  d="paused@${wp:-none} (${wpw:-?}, ${wpa}°, lowest logged ${wlow}°); resumed before the reopen: ${wearly:-no}; reopen 5 → $WD_TOP over ${WD_REOPEN_S} s, top logged ${wtop}°, $wn wiggle(s) after; first resume@${wr:-none}: ${wline:-none} (angle ${wang:-none}°), $wwhen; watchdog lines: $(count 'HUSH-T watchdog resume' "$WD")$(cover_note "$WD" "$w0" "$w3")"
  if [[ -z "$wp" ]]; then
    if le "$wlow" 10; then result WATCHDOG FAIL "$d; never paused although the lid went to ${wlow}°"
    else result WATCHDOG INCONCLUSIVE "$d (the hinge tool never delivered the close: nothing ≤ ${CLOSE_LINE}° logged)"; fi
  elif [[ -n "$wearly" ]]; then
    result WATCHDOG FAIL "$d; resumed while the lid was still at 5°"
  elif [[ -n "$wr" ]]; then
    if [[ "$wdt" == on* ]] || ! num "$wdt" || le "$wdt" "$(awk -v l="$WD_LIMIT" 'BEGIN { print l + 0.2 }')"; then
      result WATCHDOG PASS "$d$( num "$wdt" || [[ "$wdt" == on* ]] || echo ' (no line clock: within the wiggle loop)')"
    else result WATCHDOG FAIL "$d; resumed, but ${wdt} s after reaching $WD_TOP (> ${WD_LIMIT} s)"; fi
  elif ! ge "$wtop" 140; then
    result WATCHDOG INCONCLUSIVE "$d (the hinge tool never delivered the reopen: nothing ≥ 140° logged)"
  elif cover_up "$WD"; then
    result WATCHDOG INCONCLUSIVE "$d (the sim's cover display was still lit at ${WD_TOP}°: a resume there would be wrong)"
  else
    result WATCHDOG FAIL "$d; STUCK: no resume within ${WD_LIMIT} s of reaching ${WD_TOP}°"
  fi
  shoot duo-h10-watchdog-after inner

  # 10. LANDSCAPE-PLAY: the founder's dead end, reproduced. A run launched with `orient=landscape` and NO portrait ask
  #     (tabletop 0: the sim's own book-pose landscape, which is the interface iOS left the real Duo in), hinge at 105,
  #     then a slow open to 160 over 7 s (7.9°/s, under the creak floor). PASS: no `HUSH-T pose standUp` and no
  #     `HUSH-T paused pose` (the book card no longer blocks), the canvas line says k odd (`k=` when the App prints it;
  #     before that a landscape canvas), the lid lines follow the hinge (angle range ≥ 30°, openness range ≥ 0.2), and
  #     `event lidCracked`. duo-h11-landscape-play-160 is shot after the window: a LANDSCAPE raw capture with the chest
  #     drawn sideways (correct for the player: the lid on the raised, blurring half). INCONCLUSIVE: the sim never
  #     reached a landscape interface (no `orient landscape ok`, no odd k and no landscape frame: nothing was tested), k
  #     unreadable (no `k=` and a portrait-shaped canvas line), or the tool never delivered the open (after a retry).
  #     R12: from 100° (openness 0, the closed chest) instead of 105° (already cracked at launch), 100 → 160 over 7 s
  #     (8.6°/s; attract, and this check reads no noise). The detail says whether lidCracked came inside the window.
  #     R13: from 5° (openness 0.03, reached by a closing sweep), 5 → 160 over 7 s (22°/s physical ≈ 9.6 lid °/s); the
  #     retry closes gently back to 5°. If the sim's cover display is lit at 5° the run waits for its relight (~150°);
  #     lidCracked may then come late in the window, which still counts.
  hinge_sweep 5 6; hinge_set 5
  launch landscape-play "screen=run;mode=attract;seed=7;orient=landscape" 0
  LP="$OUT_ABS/logs/landscape-play.txt"
  t=0
  while (( t < 20 )); do
    grep -q "HUSH-T orient landscape ok" "$LP" 2>/dev/null && break
    cl=$(canvas_line "$LP"); [[ -n "$(canvas_k "$cl")" ]] && k_odd "$cl" && break
    sleep 1; t=$((t+1))
  done
  sleep 1
  attempt=1
  while :; do
    hinge_wiggle 5 1
    l0=$(nlines "$LP")
    lcov=0; cover_up "$LP" && lcov=1   # R13: the sim's cover display lit at 5° (no lid lines until the relight)
    hinge_sweep 160 7
    sleep 1.5
    l1=$(nlines "$LP")
    ltop=$(angles "$LP" "$l0" "$l1" | max_of)
    log "LANDSCAPE-PLAY attempt $attempt: top logged angle ${ltop}°, HUSH-H=$(hh_count "$LP" "$l0" "$l1"), lid lines=$(lid_count "$LP" "$l0" "$l1")"
    ge "$ltop" 150 && break
    (( attempt >= 2 )) && break
    attempt=2
    log "LANDSCAPE-PLAY: the logged angle never reached 150° (the hinge tool under-delivered?): close gently and again"
    hinge_sweep 5 6; sleep 1
  done
  lstand=$(grep -m1 -nE "HUSH-T pose standUp" "$LP" 2>/dev/null | tr -d '\r' | cut -c1-120)
  lpp=$(between "$LP" "$l0" "$l1" | grep -m1 -nE "HUSH-T paused pose" 2>/dev/null | tr -d '')   # R7: only inside the window (later checks reuse this log)
  lpose=$(grep -oE "HUSH-T pose [A-Za-z-]+" "$LP" | tail -1 | awk '{print $3}')
  lcl=$(canvas_full_before "$LP" $(( l1 + 1 )))
  if k_odd "$lcl"; then lk=odd; elif [[ -n "$(canvas_k "$lcl")" ]]; then lk=even; else lk=unknown; fi
  lkhow="$K_HOW"
  lor=$(grep -oE "HUSH-T orient landscape (ok|failed|lost)[^\r]*" "$LP" | tail -1)
  la=$(between "$LP" "$l0" "$l1" | lid_vals angle)
  lar=$(fsub "$(echo "$la" | max_of)" "$(echo "$la" | min_of)")
  lo=$(openness "$LP" "$l0" "$l1")
  lorr=$(awk -v a="$(echo "$lo" | max_of)" -v b="$(echo "$lo" | min_of)" 'BEGIN { if (a !~ /^[0-9.]+$/ || b !~ /^[0-9.]+$/) print "none"; else printf "%.2f\n", a - b }')
  lcr=$(head -n "$l1" "$LP" | grep -c "HUSH-T event lidCracked" | tr -d ' ')   # whole log to l1 (a retry's window may follow the crack)
  lcw=$(between "$LP" "$l0" "$l1" | grep -c "HUSH-T event lidCracked" | tr -d ' ')   # R12: inside the window (R13: from 5°)
  linp=$(grep -oE "HUSH-T input [a-z]+" "$LP" | tail -1 | awk '{print $3}')
  shoot duo-h11-landscape-play-160 inner
  lwh=$(png_wh "$OUT_ABS/duo-h11-landscape-play-160.png")
  lland=0
  [[ "$lwh" != "?" ]] && ! is_portrait "$lwh" && lland=1
  d="canvas: ${lcl#HUSH-T canvas } ($lkhow: $lk); ${lor:-no 'orient landscape' line}; last pose ${lpose:-none}; standUp: ${lstand:-none}; paused pose: ${lpp:-none}; input ${linp:-none}; lid angle range ${lar}° openness range ${lorr} (top ${ltop}°, attempt $attempt/2); lidCracked=$lcr ($lcw in the window); frame $lwh (want landscape, the chest drawn sideways)"
  reached=0
  { [[ "$lor" == *" ok"* ]] || [[ "$lk" == odd ]] || (( lland )); } && reached=1
  why=""
  [[ -n "$lstand" ]] && why="$why; the standUp card came up"
  [[ -n "$lpp" ]] && why="$why; the run paused for the pose"
  [[ "$lk" == even ]] && why="$why; k is even in landscape"
  { [[ "$lar" == none ]] || lt "$lar" 30; } && why="$why; the lid angle didn't follow the hinge"
  { [[ "$lorr" == none ]] || lt "$lorr" 0.2; } && why="$why; the openness didn't move"
  lgap=""; (( lcr == 0 )) && lgap=$(shut_gap_note "$LP" 0 "$l1")
  (( lcr == 0 )) && [[ -z "$lgap" ]] && why="$why; no lidCracked"
  [[ -n "$lgap" ]] && d="$d$lgap"
  (( lcov )) && d="$d; the sim's cover display was lit at 5° (the run waits for its relight: a paused run logs no lid lines)"
  if ! ge "$ltop" 150; then
    result LANDSCAPE-PLAY INCONCLUSIVE "$d (the hinge tool never delivered the open twice: no logged angle ≥ 150°)"
  elif (( lcov )) && [[ -z "$lstand$lpp" && "$lk" != even ]] && { [[ "$lar" == none ]] || lt "$lar" 30 || [[ "$lorr" == none ]] || lt "$lorr" 0.2 || (( lcr == 0 )); }; then
    result LANDSCAPE-PLAY INCONCLUSIVE "$d (the cover display held the run for most of the open: the follow rule can't be judged)"
  elif (( ! reached )); then
    result LANDSCAPE-PLAY INCONCLUSIVE "$d (the sim never reached a landscape interface: nothing was tested)"
  elif [[ -n "$why" ]]; then
    result LANDSCAPE-PLAY FAIL "$d$why"
  elif [[ -n "$lgap" ]]; then
    result LANDSCAPE-PLAY INCONCLUSIVE "$d (all else passed; R14: the first chest was never seen shut, START-CLOSED judges it)"
  elif [[ "$lk" == unknown ]]; then
    result LANDSCAPE-PLAY INCONCLUSIVE "$d (all else passed, but k is unreadable: no k= on the canvas line and a portrait-shaped size; App: add k=, design/NEEDS.md CI R6)"
  else
    result LANDSCAPE-PLAY PASS "$d"
  fi
  # The sim is landscape now: give the next tabletop launch the full portrait wait again if portrait ever worked.
  grep -q "HUSH-T orient portrait ok" "$OUT_ABS"/logs/*.txt 2>/dev/null && ORIENT_WAIT=25

  # ---- R12 (design/ROUND-12.md "CI engineer": the lid IS the chest) -------------------------------------------------
  # 11. START-CLOSED (R14, commit 518ea49; was R12's START-OPEN, inverted: "playing starts with the chest closed … ask
  #     the user to close the phone if it is not, then the chest should open as the phone opens"). Hinge at 150 BEFORE
  #     the launch, an attract run, the line clock from before the launch; the run starts at the first `HUSH-T screen
  #     playing` / `first chest` / `event chestArrived` / `lid` line. Phase 1, the lid up: held START_CLOSED_HOLD (3 s)
  #     past the run start with 1° wiggles (samples flowing): PASS needs NO `event lidCracked`, `HUSH-T first chest
  #     phase=ready` (when logged), a `hint easeLidDown` ("Close the phone to start"; pending when the App prints no
  #     hint lines), and the lid lines carrying 150°'s openness (θ / 150 = 1.00 ± 0.05; the hinge still drives the lid).
  #     Frame duo-h12-start-closed-150. Phase 2, `open_first_chest`: close to 5°, reopen to 150°: PASS needs the
  #     `lidCracked` after the reopen began, and no `easeLidDown` after it. FAIL with `shut_gap_note` when the first
  #     chest never opens. INCONCLUSIVE: the lid never read ~150° (the tool didn't set it).
  SC_HOLD="${START_CLOSED_HOLD:-3}"
  hinge_set 150
  SO="$OUT_ABS/logs/start-closed.txt"
  : > "$SO"
  clock_start "$SO" 200
  launch start-closed "screen=run;mode=attract;seed=7" 1
  sa=$(first_line "$SO" "HUSH-T (screen playing|first chest|event chestArrived|lid )" 0)
  t=0
  while (( t < 10 )); do
    hinge_wiggle 150 1; t=$((t + 1))
    s1=$(nlines "$SO"); sdt=$( [[ -n "$sa" ]] && dt_lines "$SO" "$sa" "$s1" || echo none )
    if num "$sdt"; then ge "$sdt" "$SC_HOLD" && break; elif (( t >= 4 )); then break; fi
  done
  s1=$(nlines "$SO")
  scr0=$(first_line "$SO" "HUSH-T event lidCracked" 0)
  [[ -n "$scr0" ]] && (( scr0 > s1 )) && scr0=""
  sph=$(grep -m1 -oE "HUSH-T first chest phase=[a-z]+[^\r]*" "$SO")
  sang=$(last_lid "$SO" 0 "$s1" angle); sop=$(last_lid "$SO" 0 "$s1" lid)
  swant=$(awk -v a="$sang" 'BEGIN { if (a !~ /^[0-9.]+$/) print "none"; else { o = a / 150; if (o < 0) o = 0; if (o > 1) o = 1; printf "%.2f\n", o } }')
  sdiff=$(awk -v a="$sop" -v b="$swant" 'BEGIN { if (a !~ /^[0-9.]+$/ || b !~ /^[0-9.]+$/) print "none"; else { d = a - b; if (d < 0) d = -d; printf "%.2f\n", d } }')
  shs=$(hints "$SO" 0 "$s1")
  sarr=$(grep -m1 -oE "HUSH-T event chestArrived[^\r]*" "$SO")
  shoot duo-h12-start-closed-150 inner
  open_first_chest "$SO" 150
  s2=$(nlines "$SO")
  clock_stop "$SO"
  scr=$(first_line "$SO" "HUSH-T event lidCracked" "$s1")
  scra=$( [[ -n "$scr" ]] && angle_before "$SO" "$scr" || echo none )
  sbad=$(bad_hints "$SO" 0 "$s2")
  d="run start@${sa:-none}; held with the lid up ${sdt} s: lidCracked ${scr0:+@$scr0}${scr0:-none}; ${sph:-no 'first chest' line}; last lid line angle ${sang}° openness ${sop} (want ${swant}, off by ${sdiff}); hints while up: ${shs}$(hints_on || echo ' (the App prints no HUD hint lines yet)'); ${sarr:-no chestArrived line}; then: $FC_NOTE; $(grep -m1 -oE "HUSH-T first chest seen shut[^]*" "$SO" || echo "no 'first chest seen shut' line"); hints after: $(hints "$SO" "$s1" "$s2")"
  if ! { ge "$sang" 140 && le "$sang" 160; }; then
    result START-CLOSED INCONCLUSIVE "$d (the lid never read ~150°: the hinge tool didn't set it)"
  elif [[ -n "$scr0" ]]; then
    result START-CLOSED FAIL "$d; the first chest opened with the phone up (R14: it waits for a close)"
  elif [[ -n "$sph" && "$sph" != *phase=ready* ]]; then
    result START-CLOSED FAIL "$d; the first chest did not start ready (closed)"
  elif hints_on && [[ "$shs" != *easeLidDown* ]]; then
    result START-CLOSED FAIL "$d; no 'hint easeLidDown' (\"Close the phone to start\") while the phone was up"
  elif ! { num "$sdiff" && le "$sdiff" 0.05 && ge "$sang" 145 && le "$sang" 155; }; then
    result START-CLOSED FAIL "$d; the lid lines don't carry 150°'s openness (θ / 150)"
  elif [[ -z "$scr" ]]; then
    result START-CLOSED FAIL "$d; the first chest never opened after the close and the reopen"
  elif [[ -n "$sbad" ]]; then
    result START-CLOSED FAIL "$d; 'Close the phone to start' after the chest was opened: $sbad"
  else
    result START-CLOSED PASS "$d; lidCracked@$scr (${scra}°)$( num "$sdt" || echo ' (no line clock: held 4 wiggles)')"
  fi
  shoot duo-h12b-start-opened-150 inner

  # 12. BITE-CLOSE-NEXT (rule 4: after a bite the robbed chest stays open and empty; the next chest is dealt only when
  #     the lid enters the shut zone, and arrives closed). A real run at 150 with `noise=1;noiseUntil=bite`: the held
  #     noise bites the first chest the moment it loots (Core's nudgeNoise allows the bite), and `noiseUntil=bite`
  #     (NEEDS CI R12) lets the noise go after that bite (`HUSH-T noise released`). Not a slam, on purpose: the sim's slam
  #     peaks ~80°/s and may only stir (R7, SLAM's rise rule), and a slam ends at 104°, inside the shut zone, which would
  #     itself deal the next chest. Then the bite moment (1.8 s), ≥ 2 s held open (1° wiggles at 150 so samples flow) and
  #     the robbed-chest frame; a close to 100° over 4 s (openness 0: at 105° it is 0.08, so a chest dealt there would
  #     loot and crack at once and the reopen would prove nothing); a reopen to 150 over 5 s (10°/s, quiet). Line clock.
  #     PASS: no `chestArrived` between the bite and the close; the next `chestArrived` at a logged angle ≤ 113° (the
  #     shut zone + the 10 Hz lines' slack) and no later than BITE_NEXT_LIMIT (1 s) + 0.3 s (clock and lid-line grain)
  #     after the first lid line ≤ 110° (no clock: ≤ 13 lid lines); nothing opens it before the reopen; its `lidCracked`
  #     after the reopen began (until noiseUntil=bite lands the hold stays on and bites it before the crack can log:
  #     that bite counts, a bite needs a looting chest); with HUD hint lines, `hint closeForNext` between the bite and
  #     the close, and no bad hint. INCONCLUSIVE: no bite although the chest opened (the demo hold didn't bite), or the
  #     tool never delivered the close (nothing ≤ 110° logged, after one more try) or the reopen (top < 140°).
  #     R13: the close is 150 → 5° over 4 s (36°/s physical ≈ 16 lid °/s, under closeQuietSpeed 28) and a hold at 5°;
  #     the shut zone is ≤ 15° (a logged angle ≤ 18° with the 10 Hz slack; HUSH-H samples count, a paused run logs no lid
  #     lines). The next chest is dealt EITHER by a step in the shut zone (`chestArrived` ≤ 18°, within 1.3 s of the
  #     first reading ≤ 15°) OR under the pause (`HUSH-T next chest dealt under the pause reason=closing|cover|shut`:
  #     the closing pause, the Duo shut ≤ 10°, or the sim's cover display, which may take the run on the way down while
  #     the robbed chest is still open; its `chestArrived` may then log with the first step back, on the reopen). FAIL:
  #     a `chestArrived` above 18° with no dealt-under-the-pause line before it, or one logged after the reopen with no
  #     such line. The reopen is to 165° over 6 s (27°/s ≈ 12 lid °/s; 165 so the sim's cover relights), then 1°
  #     wiggles until the new chest opens (or 6 s). Frames duo-h13-robbed-open-150, duo-h13b-next-opened-165.
  BN_LIMIT="${BITE_NEXT_LIMIT:-1}"
  hinge_set 150
  BC="$OUT_ABS/logs/bite-close.txt"
  : > "$BC"
  clock_start "$BC" 240
  launch bite-close "screen=run;mode=run;seed=7;noise=1;noiseUntil=bite" 1
  # R14: the first chest waits for a close; the held noise bites it as soon as the reopen opens it.
  hinge_wiggle 150 1
  open_first_chest "$BC" 150
  bfc_note="$FC_NOTE"
  wait_for "$BC" "HUSH-T event bitten" 8 || true
  bb=$(first_line "$BC" "HUSH-T event bitten" 0)
  if [[ -z "$bb" ]]; then
    clock_stop "$BC"
    bcr=$(count "HUSH-T event lidCracked" "$BC"); bn=$(nlines "$BC")
    d="$bfc_note; no bite in 8 s at 150°; lidCracked=$bcr; last lid line angle $(last_lid "$BC" 0 "$bn" angle)° noise $(last_lid "$BC" 0 "$bn" noise)"
    if (( bcr == 0 )); then result BITE-CLOSE-NEXT INCONCLUSIVE "$d (no open chest to bite: START-CLOSED judges the first chest)"
    else result BITE-CLOSE-NEXT INCONCLUSIVE "$d (the chest opened but the held noise=1 didn't bite: the App's demo hold?)"; fi
  else
    sleep 1.8                             # Tuning.biteMomentSeconds: the CHOMP, then the robbed chest waits for a close
    hinge_wiggle 150 3                    # ≥ 2 s held open (2.4 s), samples flowing
    shoot_now duo-h13-robbed-open-150     # inside the open hold on purpose: a longer hold is only stricter
    c0=$(nlines "$BC")
    bopen=$(between "$BC" "$bb" "$c0" | grep -m1 -oE "HUSH-T event chestArrived[^\r]*")
    bomin=$(angles "$BC" "$bb" "$c0" | min_of)
    bhs=$(hints "$BC" "$bb" "$c0")
    attempt=1
    hinge_sweep 5 4; hinge_wiggle 5 2
    be=$(first_angle_line "$BC" "$c0" le "$SHUT_ZONE")
    if [[ -z "$be" ]]; then
      attempt=2
      log "BITE-CLOSE-NEXT: no reading ≤ ${SHUT_ZONE}° after the close (the hinge tool under-delivered?): close again"
      hinge_set 5; hinge_wiggle 5 2
      be=$(first_angle_line "$BC" "$c0" le "$SHUT_ZONE")
    fi
    r0=$(nlines "$BC")
    hinge_sweep 165 6
    t=0; bo=""
    while (( t < 8 )); do
      bca=$(first_line "$BC" "HUSH-T event chestArrived" "$c0")
      [[ -n "$bca" ]] && bo=$(first_line "$BC" "HUSH-T event (lidCracked|bitten)" "$(( bca > r0 ? bca : r0 ))")
      [[ -n "$bo" ]] && break
      hinge_wiggle 165 1; t=$((t + 1))
    done
    sleep 0.5
    r1=$(nlines "$BC")
    clock_stop "$BC"
    bca=$(first_line "$BC" "HUSH-T event chestArrived" "$c0")
    bdl=$(first_line "$BC" "HUSH-T next chest dealt under the pause" "$c0")
    bdlw=$( [[ -n "$bdl" ]] && sed -n "${bdl}p" "$BC" | grep -oE "reason=[a-z]+" )
    bcaa=$( [[ -n "$bca" ]] && angle_before "$BC" "$bca" || echo none )
    bunder=0; [[ -n "$bdl" && -n "$bca" ]] && (( bdl <= bca && bdl < r0 )) && bunder=1
    bdt=none; bnl=none
    if [[ -n "$be" && -n "$bca" ]] && (( ! bunder )); then
      if (( bca >= be )); then bdt=$(dt_lines "$BC" "$be" "$bca"); bnl=$(lid_count "$BC" "$be" "$bca"); else bdt=0.0; bnl=0; fi
    fi
    bpre=""; [[ -n "$bca" ]] && (( bca < r0 )) && bpre=$(between "$BC" "$bca" "$r0" | grep -m1 -oE "HUSH-T event (lidCracked|bitten)[^\r]*")
    bwhen=""; [[ -n "$bca" ]] && bwhen=$( (( bca < r0 )) && echo "while closed" || echo "on the reopen" )
    botop=$(angles "$BC" "$r0" "$r1" | max_of)
    boev=""; boa=none
    if [[ -n "$bo" ]]; then boev=$(sed -n "${bo}p" "$BC" | grep -oE "HUSH-T event [A-Za-z]+" | awk '{print $3}'); boa=$(angle_before "$BC" "$bo"); fi
    brel=$(grep -m1 -oE "HUSH-T noise released[^\r]*" "$BC")
    bbad=$(bad_hints "$BC" "$bb" "$r1")
    blim=$(awk -v l="$BN_LIMIT" 'BEGIN { print l + 0.3 }')
    d="bite@$bb; held open after it: lowest ${bomin}°, chestArrived while open: ${bopen:-none}; hints bite→close: ${bhs}$(hints_on || echo ' (the App prints no HUD hint lines yet: NEEDS CI R12)'); close to 5° (attempt $attempt/2): first reading ≤ ${SHUT_ZONE}°@${be:-none}, dealt under the pause@${bdl:-none}${bdlw:+ ($bdlw)}, chestArrived@${bca:-none} (${bcaa}°, ${bwhen:-never}; ${bdt} s / ${bnl} lid lines after entering the shut zone)$(cover_note "$BC" "$c0" "$r0"); before the reopen: ${bpre:-nothing}; reopen to 165 (top ${botop}°): ${boev:-nothing}@${bo:-none} (${boa}°); ${brel:-no 'noise released' line (noiseUntil=bite pending: the hold stays on)}"
    if [[ -n "$bopen" ]]; then result BITE-CLOSE-NEXT FAIL "$d; the next chest was dealt while the lid was open"
    elif [[ -n "$bbad" ]]; then result BITE-CLOSE-NEXT FAIL "$d; asked to open or lower an open lid: $bbad"
    elif [[ -z "$be" && -z "$bdl" ]]; then result BITE-CLOSE-NEXT INCONCLUSIVE "$d (the hinge tool never delivered the close twice: no reading ≤ ${SHUT_ZONE}°)"
    elif [[ -z "$bca" ]]; then
      if [[ -n "$bdl" ]] && cover_up "$BC"; then result BITE-CLOSE-NEXT INCONCLUSIVE "$d (dealt under the pause, but the sim's cover display was still lit at 165°: no step back)"
      else result BITE-CLOSE-NEXT FAIL "$d; no chestArrived after closing the lid"; fi
    elif (( ! bunder )) && (( bca >= r0 )); then result BITE-CLOSE-NEXT FAIL "$d; the next chest was dealt on the way back up"
    elif (( ! bunder )) && num "$bcaa" && ! le "$bcaa" $(( SHUT_ZONE + 3 )); then result BITE-CLOSE-NEXT FAIL "$d; chestArrived above the shut zone (${bcaa}°) and not under the pause"
    elif (( ! bunder )) && num "$bdt" && ! le "$bdt" "$blim"; then result BITE-CLOSE-NEXT FAIL "$d; chestArrived ${bdt} s after entering the shut zone (> ${BN_LIMIT} s)"
    elif (( ! bunder )) && ! num "$bdt" && ! le "$bnl" 13; then result BITE-CLOSE-NEXT FAIL "$d; no line clock, and $bnl lid lines (> 13) between the shut zone and chestArrived"
    elif [[ -n "$bpre" ]]; then result BITE-CLOSE-NEXT FAIL "$d; the next chest opened while the lid sat at 5° (openness 0.03)"
    elif [[ -z "$bo" ]]; then
      if cover_up "$BC"; then result BITE-CLOSE-NEXT INCONCLUSIVE "$d (the sim's cover display was still lit at 165°)"
      elif ge "$botop" 140; then result BITE-CLOSE-NEXT FAIL "$d; the next chest never opened on the reopen"
      else result BITE-CLOSE-NEXT INCONCLUSIVE "$d (the hinge tool never delivered the reopen: top ${botop}°)"; fi
    elif hints_on && [[ "$bhs" != *closeForNext* ]]; then result BITE-CLOSE-NEXT FAIL "$d; no 'hint closeForNext' while the robbed chest waited"
    else
      result BITE-CLOSE-NEXT PASS "$d$( (( bunder )) && echo " (dealt under the pause ${bdlw:-})")$( [[ "$boev" == bitten ]] && echo ' (opened: the held noise bit the new chest at once; lidCracked logs once noiseUntil=bite lands)')$( (( bunder )) || num "$bdt" || echo ' (no line clock: judged on lid lines)')"
    fi
    shoot duo-h13b-next-opened-165 inner
  fi

  # 13. BANK-CLOSE-FULL (rule 3: bank = close the lid, and closing it all the way is fine). An attract run at 150 with
  #     one item put in the bag by the demo at the first chest's looting start (`bag=1`, NEEDS CI R12: `HUSH-T demo bag
  #     <n> …`). Why a demo key: loot only reaches the bag by a drag, `simctl` can't touch, and a pilot drives the LID as
  #     well (the hinge would be ignored), so neither tests the hinge's close. One go, as the founder does it: 150 → 30°
  #     over 5 s (24°/s; attract never bites), 1 s there (the inner display is still lit; the closing pause), then on to
  #     0° (the cover display, frame duo-h14), then a reopen to 165° (the sim's cover stays lit up to ~150°) with 1°
  #     wiggles until a resume or 8 s. Line clock. PASS: `event banked` before the first `HUSH-T paused` after the close
  #     began; the next `chestArrived` after the bank at a logged angle ≤ 113° (dealt under the closed lid, during the
  #     bank moment or the pause, never on the way back up); a `HUSH-T resumed` after the reopen when the close paused;
  #     the new chest's `lidCracked` after the reopen began; no bad hint. INCONCLUSIVE: no bag line and no bank (the key
  #     isn't in this build), or the tool never delivered the close (nothing ≤ 108°, after one more try via a hold at
  #     105°) or the reopen (top < 92°). The R7 fresh-chest resume line (`HUSH-T fresh chest resume`, no "Hold still" on
  #     a fresh chest) is reported, not judged.
  #     R13 (the phone is the chest): the close is 150 → 5° over 6 s (24°/s physical), 1 s at 5° (the shut zone is
  #     ≤ 15°, the closing pause < 12°), then 0°. R12b: when the closing pause begins, or the sim's cover display takes
  #     the run (on the sim it may do so on the way down, chest still open), with loot in the bag, the bag banks at once
  #     (`HUSH-T banked under the pause reason=…` after `event banked`, then `chestArrived`). So a pause logged before
  #     the bank passes when a banked-under-the-pause line follows it before the reopen, and the next chest may arrive
  #     above 18° only when banked under the pause. Close delivered: a reading ≤ 15° (retry via a hold at 20°). Reopen
  #     delivered: a logged angle ≥ 145° (the sim's cover relights ~150°); still on the cover at 165° is INCONCLUSIVE.
  hinge_set 150
  BK="$OUT_ABS/logs/bank-full.txt"
  launch bank-full "screen=run;mode=attract;seed=7;bag=1" 1
  # R14: the first chest waits for a close; `bag=1` bags on its first looting steps, after the reopen opens it.
  hinge_wiggle 150 1
  open_first_chest "$BK" 150
  kfc_ok=$FC_OK; kfc_note="$FC_NOTE"
  wait_for "$BK" "HUSH-T demo bag" 5 || true
  bagl=$(grep -m1 -oE "HUSH-T demo bag[^\r]*" "$BK")
  hinge_wiggle 150 1
  clock_start "$BK" 200
  b0=$(nlines "$BK"); attempt=1
  hinge_sweep 5 6; hinge_wiggle 5 1; sleep 1
  bk=$(first_line "$BK" "HUSH-T event banked" "$b0")
  blow=$(angles "$BK" "$b0" "$(nlines "$BK")" | min_of)
  if [[ -z "$bk" ]] && ! le "$blow" "$SHUT_ZONE"; then
    attempt=2
    log "BANK-CLOSE-FULL: nothing ≤ ${SHUT_ZONE}° logged on the close (lowest ${blow}°; the hinge tool under-delivered?): again, via a hold at 20°"
    hinge_set 20; hinge_wiggle 20 2; hinge_sweep 5 1; hinge_wiggle 5 1; sleep 1
    bk=$(first_line "$BK" "HUSH-T event banked" "$b0")
    blow=$(angles "$BK" "$b0" "$(nlines "$BK")" | min_of)
  fi
  bp=$(first_line "$BK" "HUSH-T paused" "$b0")
  bka=$( [[ -n "$bk" ]] && angle_before "$BK" "$bk" || echo none )
  bpa=$( [[ -n "$bp" ]] && angle_before "$BK" "$bp" || echo none )
  bpw=$( [[ -n "$bp" ]] && sed -n "${bp}p" "$BK" | grep -oE "paused [a-z]+" | awk '{print $2}' )
  hinge_sweep 1 0.5; hinge_set 0; sleep 3
  shoot duo-h14-bank-cover-0 cover
  r0=$(nlines "$BK")
  hinge_sweep 165 3
  t=0; brs=""
  while (( t < 10 )); do
    brs=$(first_line "$BK" "HUSH-T resumed" "$r0"); [[ -n "$brs" ]] && break
    hinge_wiggle 165 1; t=$((t + 1))
  done
  bca=""; [[ -n "$bk" ]] && bca=$(first_line "$BK" "HUSH-T event chestArrived" "$bk")
  boc=""
  if [[ -n "$bca" ]]; then
    t=0
    while (( t < 20 )); do boc=$(first_line "$BK" "HUSH-T event lidCracked" "$bca"); [[ -n "$boc" ]] && break; sleep 0.2; t=$((t + 1)); done
  fi
  sleep 0.5
  r1=$(nlines "$BK")
  clock_stop "$BK"
  # R12b: the bag banked under the pause (closing / cover / shut) before the reopen.
  bku=$(first_line "$BK" "HUSH-T banked under the pause" "$b0")
  [[ -n "$bku" ]] && (( bku >= r0 )) && bku=""
  bkuw=$( [[ -n "$bku" ]] && sed -n "${bku}p" "$BK" | grep -oE "reason=[a-z]+" )
  bcaa=$( [[ -n "$bca" ]] && angle_before "$BK" "$bca" || echo none )
  bcw=""
  if [[ -n "$bca" ]]; then
    if [[ -n "$bp" ]] && (( bca < bp )); then bcw="before the pause"
    elif (( bca < r0 )); then bcw="while closed"
    elif [[ -n "$brs" ]] && (( bca > brs )); then bcw="after the resume"
    else bcw="during the reopen"; fi
  fi
  rtop=$(angles "$BK" "$r0" "$r1" | max_of)
  rsa=none
  if [[ -n "$brs" ]]; then rsa=$(sed -n "${brs}p" "$BK" | grep -oE "angle [0-9.]+" | awk '{print $2}'); [[ -n "$rsa" ]] || rsa=$(angle_before "$BK" "$brs"); fi
  bocw=""; [[ -n "$boc" ]] && bocw=$( (( boc < r0 )) && echo "before the reopen" || echo "$(angle_before "$BK" "$boc")°" )
  kfresh=$(after "$BK" "$r0" | grep -m1 -oE "HUSH-T fresh chest resume[^\r]*")
  kbad=$(bad_hints "$BK" "$b0" "$r1")
  khs=$(hints "$BK" "$b0" "$r1")
  d="$kfc_note; ${bagl:-no 'HUSH-T demo bag' line}; close 150 → 5 → 0 (attempt $attempt/2, lowest ${blow}°): banked@${bk:-none} (${bka}°)${bku:+, under the pause@$bku ($bkuw)}, first pause@${bp:-none} (${bpw:-}${bp:+, }${bpa}°)$(cover_note "$BK" "$b0" "$r0"); next chestArrived@${bca:-none} (${bcaa}°, ${bcw:-never}); reopen to 165 (top ${rtop}°): resumed@${brs:-none} (${rsa}°), ${kfresh:-no fresh-chest resume line}; new chest lidCracked@${boc:-none} (${bocw:-})"
  d="$d; hints: ${khs}$(hints_on || echo ' (the App prints no HUD hint lines yet: NEEDS CI R12)')"
  if (( ! kfc_ok )) && [[ -z "$bk" ]]; then
    result BANK-CLOSE-FULL INCONCLUSIVE "$d (no open chest to bag from: START-CLOSED judges the first chest)"
  elif [[ -z "$bk" && -z "$bagl" ]]; then
    result BANK-CLOSE-FULL INCONCLUSIVE "$d (no bag: the App's bag=1 demo key isn't in this build, NEEDS CI R12)"
  elif [[ -z "$bk" ]] && ! le "$blow" "$SHUT_ZONE"; then
    result BANK-CLOSE-FULL INCONCLUSIVE "$d (the hinge tool never delivered the close twice: nothing ≤ ${SHUT_ZONE}° logged)"
  elif [[ -z "$bk" ]]; then
    result BANK-CLOSE-FULL FAIL "$d; loot in the bag, but closing the lid to 5° never banked"
  elif (( bk >= r0 )); then
    result BANK-CLOSE-FULL FAIL "$d; the bag banked only after the reopen (it must bank as the lid closes)"
  elif [[ -n "$bp" ]] && (( bp < bk )) && [[ -z "$bku" ]]; then
    result BANK-CLOSE-FULL FAIL "$d; the run paused before the bank, and it didn't bank under the pause (R12b)"
  elif [[ -z "$bca" ]]; then
    result BANK-CLOSE-FULL FAIL "$d; no next chest after the bank"
  elif num "$bcaa" && ! le "$bcaa" $(( SHUT_ZONE + 3 )) && ! { [[ -n "$bku" ]] && (( bca < r0 )); }; then
    result BANK-CLOSE-FULL FAIL "$d; the next chest was dealt with the lid open (${bcaa}°): it must arrive under the closed lid (or under the pause)"
  elif [[ -n "$kbad" ]]; then
    result BANK-CLOSE-FULL FAIL "$d; asked to open or lower an open lid: $kbad"
  elif [[ -n "$bp" && -z "$brs" ]] && ! ge "$rtop" 145; then
    result BANK-CLOSE-FULL INCONCLUSIVE "$d (the hinge tool never delivered the reopen: top ${rtop}°)"
  elif [[ -n "$bp" && -z "$brs" ]] && cover_up "$BK"; then
    result BANK-CLOSE-FULL INCONCLUSIVE "$d (the sim's cover display was still lit at 165°)"
  elif [[ -n "$bp" && -z "$brs" ]]; then
    result BANK-CLOSE-FULL FAIL "$d; no resume after the reopen to 165°"
  elif [[ -z "$boc" ]]; then
    result BANK-CLOSE-FULL FAIL "$d; the next chest never opened on the reopen"
  elif (( boc < r0 )); then
    result BANK-CLOSE-FULL FAIL "$d; the next chest opened before the reopen (it must arrive closed)"
  else
    result BANK-CLOSE-FULL PASS "$d$( [[ -z "$bp" ]] && echo ' (no pause logged on the close: COVER-SLOW-CLOSE judges that)')"
  fi
  shoot duo-h14b-bank-next-opened-165 inner
  hinge_sweep 150 1.5
fi

# ---- pass: the tabletop frames (closed 105, half 135, wide 160, cover shut, reopened) -----------------------------
if [[ " $PASSES " == *" frames "* ]]; then
  # Attract run on the real hinge (no pilot, the candle never burns, no bites), drawn turned round (the Duo default).
  # Slow sweeps (7–8°/s) keep the mimic asleep so the frames show the reveal, not the alarm.
  # R12: from 100° (openness 0), so duo-00 is the closed chest's cover (planks, bands, lock; Scene rule 5) and duo-01 at
  # 105° (openness 0.08) the cover lifting towards the hinge.
  # R13 (openness θ / 150): closed at 5° (0.03), cracking at 25° (0.17, above the 18° resume line, so the run plays),
  # half at 75° (0.5), wide at 150° (1.0); every sweep ≤ 20°/s physical (≤ 9 lid °/s). 5° is reached by a closing
  # sweep; on the sim its cover display is the lit panel at 5° (duo run 40725260104), and the inner one relights at
  # ~22° on the way up, so duo-00 may be the cover. R14: the run starts closed, as the founder wants; the chest opens
  # in these frames only once the App counts this closed start as seen shut (START-CLOSED says whether it does).
  hinge_sweep 5 8; hinge_set 5
  launch frames "screen=run;mode=attract;seed=7" 1
  FL="$OUT_ABS/logs/frames.txt"
  shoot duo-00-closed-5 inner
  hinge_sweep 25 2
  sleep 2.5; shoot duo-01-crack-25 inner
  hinge_sweep 75 3; sleep 2.5; shoot duo-02-half-75 inner
  hinge_sweep 150 4; sleep 2.5; shoot duo-03-wide-150 inner
  result TURNED INFO "$(canvas_line "$FL")"
  hinge_sweep 60 2; hinge_sweep 10 0.8; hinge_set 0; sleep 3; shoot duo-04-cover-shut cover
  result COVER INFO "paused-closing lines=$(count 'HUSH-T paused closing' "$FL"); last canvas: $(canvas_line "$FL")"
  o0=$(nlines "$FL")
  hinge_sweep 165 2.5; sleep 3
  # The reopen from the cover (REVIEW-1-duo P0-2's other half): where did the run resume? Evidence only (attract
  # never bites); the R2 rule was >= 95° and still for 0.3 s (R13: >= 18°, but the sim's cover relights only ~150°).
  orl=$(first_line "$FL" "HUSH-T resumed" "$o0")
  ora=""; [[ -n "$orl" ]] && { ora=$(sed -n "${orl}p" "$FL" | grep -oE "angle [0-9.]+" | awk '{print $2}'); [[ -n "$ora" ]] || ora=$(angle_before "$FL" "$orl"); }
  result COVER-REOPEN INFO "reopen 0 → 165° in 2.5 s: resumed@${orl:-none} angle ${ora:-none}°; maxNoise after=$(after "$FL" "${orl:-$o0}" | lid_vals noise | max_of)"
  shoot duo-05-reopened-165 inner
  hinge_sweep 120 1.5
  # The same half-open moment with "Turn the chest round" off, for comparison with duo-02. R13: from 25° to 75°
  # (openness 0.5). R14: 25° is reached from below (down to 5°, up to 25°): closing, the sim's cover takes over at ~70°.
  hinge_sweep 5 6; hinge_sweep 25 2; hinge_set 25
  launch frames-unturned "screen=run;mode=attract;seed=7;turn=0" 1
  hinge_sweep 75 3; sleep 2.5; shoot duo-06-half-75-unturned inner
  result UNTURNED INFO "$(canvas_line "$OUT_ABS/logs/frames-unturned.txt")"
fi

# ---- pass: UI frames -----------------------------------------------------------------------------------------------
if [[ " $PASSES " == *" ui "* ]]; then
  # Home's chest follows the hinge: shut-ish at 120, the little mimic peeks at 150. R13 (openness θ / 150): barely
  # open at 25° (0.17), the mimic peeking at 150°. R14: 25° is reached from below (5° first), so the inner panel is lit.
  hinge_sweep 5 6; hinge_sweep 25 2; hinge_set 25 || true
  launch ui-home "screen=home;progress=mid" 1; shoot duo-ui-home-25 inner
  hinge_sweep 150 6; sleep 2.5; shoot duo-ui-home-150 inner
  # Lesson step 1 (pose) at 150°, then into its R2 90–112° window (REVIEW-1-duo P1-6) for 0.5 s+ (the step should
  # pass by itself, and step 2 must not say "Ease the lid down first": 105° is already in the chest's shut zone).
  # R12 rule 7: at 150° step 1 should read "Close the lid to start" (never "open" an open lid), and after the close
  # step 2 "Now open it… slowly". Frames only (the copy is the App's; HushTests own it).
  # R13: the pose window is any open laptop pose, 45–150° (loose 30–165° after 4 s), and there is no shut-first gate:
  # the lesson's chest opens with the lid. 150° is the window's edge, so the "after" frame is at 100°, well inside.
  # R14: the lesson's pose step is gone (it starts at "open"), and its chest, like every first chest, waits for the
  # close: at 150° "Close the phone to start."; then closed to 5° and reopened to 100° ("Now open it… slowly.").
  launch ui-lesson "screen=lesson;lessonStep=1" 1; shoot duo-ui-lesson-1-150 inner
  hinge_sweep 5 6; hinge_wiggle 5 1; hinge_sweep 100 5; sleep 2.5; shoot duo-ui-lesson-after-close inner
  hinge_sweep 150 2
  launch ui-results "screen=results;seed=7;progress=mid;pilot=casual" 1; sleep 3; shoot duo-ui-results inner
  # R4 (NEEDS App R3: "Codex 9/24 vs 22/24"): the same `mid` preset as ui-home / ui-results, so the three agree.
  launch ui-codex "screen=codex;progress=mid" 1; sleep 2; shoot duo-ui-codex inner
  launch ui-settings "screen=settings" 1; sleep 2; shoot duo-ui-settings inner
  # Book pose: no orient request, so the sim keeps its own landscape inner canvas → the "Stand it up like a little
  # laptop" pose card (Brim's ui-book got its 2853 x 2007 book card the same way, after portrait launches).
  launch ui-pose-book "screen=home;progress=mid" 0; sleep 2; shoot duo-ui-pose-book inner
  wh=$(png_wh "$OUT_ABS/duo-ui-pose-book.png"); cl=$(canvas_line "$OUT_ABS/logs/ui-pose-book.txt")
  if [[ "$wh" != "?" ]] && ! is_portrait "$wh"; then result POSE-BOOK INFO "book pose (landscape) as expected: $wh; ${cl:-no canvas line}"
  else result POSE-BOOK INFO "portrait ($wh): the launch's automatic portrait ask (R3: only when the device orientation isn't landscape; the sim may read .unknown, REVIEW-2-duo P1-2); ${cl:-no canvas line}"; fi
  # R3: the card itself, held (`pose=book`: no automatic or lift portrait ask; `orient=landscape` keeps the sim's book
  # pose), so "Turn it sideways. Lift the glowing half." and its "Play anyway" way out are a frame.
  # R6 (founder's real-Duo P0, design/ROUND-6.md): the blocking book card is GONE. In landscape, Home is drawn the
  # right way up (k odd) and only a non-blocking tip may show (`HUSH-T pose tip shown`, needs UIDevice landscape,
  # which the sim may not report). FAIL only if anything still blocks (`pose standUp`).
  # R14: the pose tip never shows unless the demo forces it (`screen=pose`), and this launch doesn't: PASS = no block
  # and no tip; a tip shown unforced FAILs.
  launch ui-pose-card "screen=home;progress=mid;orient=landscape" 0; sleep 3; shoot duo-ui-pose-card inner
  PC="$OUT_ABS/logs/ui-pose-card.txt"
  wh=$(png_wh "$OUT_ABS/duo-ui-pose-card.png")
  pcl=$(grep -m1 -oE "HUSH-T pose standUp[^\r]*" "$PC" 2>/dev/null)
  tip=$(grep -m1 -oE "HUSH-T pose tip shown[^\r]*" "$PC" 2>/dev/null)
  d="frame $wh; tip: ${tip:-none}; standUp: ${pcl:-none}; $(canvas_line "$PC")"
  if [[ -n "$pcl" ]]; then result POSE-NO-BLOCK FAIL "$d (the blocking book card is back)"
  elif [[ -n "$tip" ]]; then result POSE-NO-BLOCK FAIL "$d (R14: the pose tip showed without the demo forcing it)"
  else result POSE-NO-BLOCK PASS "$d (no block, no tip: R14)"; fi
  hinge_sweep 40 1.5; hinge_set 0; sleep 3; shoot duo-ui-cover cover
  hinge_set 160 || true
fi

# ---- pass: the App Store Duo set (opt-in: PASSES=store, run by ci/store-capture.sh duo) ----------------------------
# One tabletop launch per line of STORE_LIST (ci/duo-store-scenarios.txt: name|demo args|wait|caption|expect|frame),
# the hinge held at STORE_ANGLE (150°: open, so no closing pause; the pilot or lid= drives the lid itself). A freezeOn=
# line waits for "HUSH-T freeze <tag>" (at least `wait`, at least 20 s), a freezeAfter= line for "HUSH-T freeze after",
# then 2 s for the held frame; others wait `wait` s. Writes store-<name>.png (the lit panel, normally the 2007 x 2853
# inner display) and logs/store-<name>.at-capture.txt (the log at capture; ci/store-set.sh checks it).
if [[ " $PASSES " == *" store "* ]]; then
  LIST="${STORE_LIST:-ci/duo-store-scenarios.txt}"
  SANGLE="${STORE_ANGLE:-150}"
  [[ -f "$LIST" ]] || log "WARN store list $LIST not found"
  [[ -f "$LIST" ]] && while IFS='|' read -r -u 3 name args wait _caption _expect _rest; do
    name="${name%$'\r'}"; args="${args%$'\r'}"; wait="${wait%$'\r'}"
    [[ -z "$name" || "$name" == \#* ]] && continue
    [[ "$name" =~ ${STORE_FILTER:-.} ]] || continue
    wait="${wait%%.*}"; [[ "$wait" =~ ^[0-9]+$ ]] || wait=6
    hinge_set "$SANGLE" || true
    launch "store-$name" "$args" 1
    SF="$OUT_ABS/logs/store-$name.txt"
    lim=$(( wait > 20 ? wait : 20 ))
    if [[ "$args" =~ freezeOn=([A-Za-z]+) ]]; then
      tag="${BASH_REMATCH[1]}"
      if wait_for "$SF" "HUSH-T freeze $tag" "$lim"; then sleep 2; else log "WARN store-$name: no 'HUSH-T freeze $tag' in ${lim} s (shooting anyway)"; fi
    elif [[ "$args" == *freezeAfter=* ]]; then
      if wait_for "$SF" "HUSH-T freeze after" "$lim"; then sleep 2; else log "WARN store-$name: no 'HUSH-T freeze after' in ${lim} s"; fi
    else
      sleep "$wait"
    fi
    shoot "store-$name" inner
    cp "$SF" "$OUT_ABS/logs/store-$name.at-capture.txt" 2>/dev/null || true
  done 3< "$LIST"
fi

ls -la "$OUT_ABS" | tee -a "$RUNLOG" >&2
log "checks: $(awk -F'\t' '$2=="PASS"' "$CHECKS" | wc -l | tr -d ' ') PASS, $(awk -F'\t' '$2=="FAIL"' "$CHECKS" | wc -l | tr -d ' ') FAIL, $(awk -F'\t' '$2=="INCONCLUSIVE"' "$CHECKS" | wc -l | tr -d ' ') INCONCLUSIVE"
grep -E $'\t(PASS|FAIL|INCONCLUSIVE)\t' "$CHECKS" | awk -F'\t' '{ printf "%s %s (%s)\n", $1, $2, $3 }' || true
write_summary
if [[ "$STRICT" == 1 ]] && grep -q $'\tFAIL\t' "$CHECKS"; then exit 1; fi
exit 0

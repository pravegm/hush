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
# PASSES=store (R3): the App Store Duo set (ci/store-capture.sh duo → ci/duo-store-scenarios.txt), one tabletop capture
# per line at STORE_ANGLE (150°): store-<name>.png + logs/store-<name>.at-capture.txt (ci/store-set.sh frames them).
#
# Env: UDID (required), OUT (duo-screens), PASSES ("hinge frames ui"; "store" is opt-in), ORIENT ("portrait"), STRICT
# (1 = exit 1 when a check FAILs; default 0: the frames and the PASS/FAIL table are the evidence), INNER_CANVAS
# ("669x951"), STORE_LIST / STORE_FILTER / STORE_ANGLE (the store pass); R6: FLAT_TOP (180), FLAT_GAP_MAX (1.2),
# WATCHDOG_REOPEN_S (14), WATCHDOG_LIMIT (8).
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
SLAM_MIN_PEAK="${SLAM_MIN_PEAK:-60}"

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

shoot() {   # shoot <name> <inner|cover>: both panels to raw/, the lit one (or the wanted one) to <name>.png
  local name="$1" want="$2" ib=-1 cb=-1 pick
  [[ -n "$INNER" ]] && to 30 xcrun simctl io "$UDID" screenshot --display="$INNER" "$OUT_ABS/raw/$name-inner.png" >/dev/null 2>>"$RUNLOG" && ib=$(brightness "$OUT_ABS/raw/$name-inner.png")
  [[ -n "$COVER" ]] && to 30 xcrun simctl io "$UDID" screenshot --display="$COVER" "$OUT_ABS/raw/$name-cover.png" >/dev/null 2>>"$RUNLOG" && cb=$(brightness "$OUT_ABS/raw/$name-cover.png")
  if [[ -z "$INNER$COVER" ]]; then to 30 xcrun simctl io "$UDID" screenshot "$OUT_ABS/$name.png" >/dev/null 2>>"$RUNLOG"; return; fi
  if (( ib > 6 && cb <= 6 )); then pick=inner; elif (( cb > 6 && ib <= 6 )); then pick=cover; else pick="$want"; fi
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
# slam_samples <file> <line> (R4): how many samples the app saw during a slam from ~150 to 104: the distinct lid angles
# logged after <line> that differ from the one before (starting from the hold's last angle, at or before <line>), up
# to the first angle <= 106°, and the raw HUSH-H lines in that span. Duo run 40533062342's failing slam reads 1
# (146.7 -> 136.0 -> 103.2); a streamed 0.3 s slam at 10 Hz lid lines reads 2-4.
slam_samples() {
  awk -v a="$2" '
    /HUSH-T lid / { v = ""; for (i = 1; i < NF; i++) if ($i == "angle" && $(i + 1) ~ /^[0-9.]+$/) v = $(i + 1) + 0 }
    !/HUSH-T lid / { v = "" }
    NR <= a + 0 { if (v != "") prev = v; next }
    /^HUSH-H / { h++ }
    v != "" { if (v <= 106) exit; if (prev == "" || v != prev) m++; prev = v }
    END { printf "%d (lid-angle changes before 106°), HUSH-H=%d\n", m, h }' "$1" 2>/dev/null
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
  # 1. SLOW-OPEN: shut zone 105°, attract run (never bites), sweep 105 → 160 over 7 s (7.9°/s, under the 8°/s creak
  #    floor). PASS: `event lidCracked` and the max logged noise < 0.35 (the mimic stays Asleep).
  # 3. STILL (same launch): hold 1.5 s at 160 after the sweep. PASS: the last logged lid speed in the hold is < 1.0
  #    (speed must decay when hinge samples stop: they arrive at 25–30 Hz moving and not at all while still).
  hinge_set 105
  launch slow-open "screen=run;mode=attract;seed=7" 1
  SL="$OUT_ABS/logs/slow-open.txt"
  # PORTRAIT: the inner-display capture is taller than wide (taken before the timed window; a shot takes ~15 s).
  shoot duo-h0-ready-105 inner
  wh=$(png_wh "$OUT_ABS/duo-h0-ready-105.png"); cl=$(canvas_line "$SL")
  d="inner frame $wh; ${cl:-no canvas line}; orient=${ORIENT:-none}; $(grep -m1 -oE 'HUSH-T orient [a-z]+ [a-z]+' "$SL" || echo 'no HUSH-T orient line')"
  # R6: a landscape inner display is playable too (drawn with odd k, the right way up for a tabletop Duo).
  if is_portrait "$wh"; then result PORTRAIT PASS "$d"
  elif k_odd "$cl"; then result PORTRAIT PASS "$d (landscape interface, drawn with odd k: playable since R6)"
  else result PORTRAIT FAIL "$d (neither portrait nor an odd-k landscape canvas)"; fi
  m0=$(nlines "$SL")
  hinge_sweep 160 7
  m1=$(nlines "$SL")
  sleep 1.5
  m2=$(nlines "$SL")
  cracked=$(count "HUSH-T event lidCracked" "$SL")
  maxn=$(after "$SL" "$m0" | lid_vals noise | max_of)
  maxv=$(between "$SL" "$m0" "$m1" | lid_vals speed | max_of)
  inp=$(grep -m1 -oE "HUSH-T input [a-z]+" "$SL" | awk '{print $3}')
  hl=$(count "HUSH-H" "$SL")
  d="lidCracked=$cracked maxNoise=$maxn peakSpeed=${maxv}°/s input=${inp:-none} HUSH-H=$hl"
  if (( cracked > 0 )) && lt "$maxn" 0.35; then result SLOW-OPEN PASS "$d"; else result SLOW-OPEN FAIL "$d"; fi
  hold=$(between "$SL" "$m1" "$m2" | lid_vals speed)
  last=$(echo "$hold" | grep -E '^-?[0-9.]+$' | tail -1)
  low=$(echo "$hold" | min_of)
  d="last speed in the 1.5 s hold=${last:-none} min=$low ($(echo "$hold" | grep -cE '^-?[0-9.]+$') lid lines)"
  if [[ -n "$last" ]] && lt "$last" 1.0; then result STILL PASS "$d"; else result STILL FAIL "$d"; fi
  shoot duo-h1-slow-open-160 inner

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
  hinge_set 105
  launch slam "screen=run;mode=run;seed=7;freezeOn=bite" 1
  SM="$OUT_ABS/logs/slam.txt"
  hinge_sweep 150 6
  h0=$(nlines "$SM"); sleep 1.5
  hl2=$(sed -n "$(( h0 + 1 )),\$p" "$SM" | lid_vals speed | grep -E '^-?[0-9.]+$' | tail -1)
  result STILL-RUN INFO "last speed 1.5 s into the hold at 150 (real run)=${hl2:-none}"
  attempt=1; froze=""; hit=""; bit=""; peak=none; pn=none; n0=none; ns=""
  while :; do
    hinge_wiggle 150 2
    n0=$(head -n "$(nlines "$SM")" "$SM" | lid_vals noise | grep -E '^-?[0-9.]+$' | tail -1)
    s0=$(nlines "$SM")
    hinge_sweep 104 0.3
    # The bite usually lands while the sweep call is still returning; catch the freeze line as soon as it is there.
    if wait_for "$SM" "HUSH-T freeze bite" 3; then shoot_now duo-h2-slam-bite; froze="froze on the bite"
    else froze="no 'HUSH-T freeze bite' within 3 s"; fi
    sleep 0.5
    hit=$(after "$SM" "$s0" | grep -m1 -E "HUSH-T (event bitten|event stageChanged .*to=(waking|biting)|lid .* stage (waking|biting))" | tr -d '\r')
    bit=$(after "$SM" "$s0" | grep -m1 -E "HUSH-T event bitten" | tr -d '\r')
    peak=$(after "$SM" "$s0" | lid_vals speed | max_of)
    pn=$(after "$SM" "$s0" | lid_vals noise | max_of)
    ns=$(slam_samples "$SM" "$s0")
    log "SLAM attempt $attempt: peakSpeed=${peak}°/s noise ${n0:-none} -> $pn; $ns; ${hit:-no hit}"
    [[ -n "$hit" ]] && break
    { [[ "$peak" == none ]] || lt "$peak" "$SLAM_MIN_PEAK"; } || break
    (( attempt >= 2 )) && break
    attempt=2
    log "SLAM: peak ${peak}°/s < ${SLAM_MIN_PEAK}°/s and no hit (the hinge tool under-delivered?): re-open gently and slam again"
    hinge_sweep 150 8
    sleep 1
  done
  rise=$(awk -v a="${n0:-0}" -v b="$pn" 'BEGIN { if (b !~ /^-?[0-9.]+$/) print "none"; else printf "%.2f\n", b - (a ~ /^-?[0-9.]+$/ ? a : 0) }')
  d="attempt $attempt/2; peakSpeed=${peak}°/s; slam samples: $ns; noise ${n0:-none} -> $pn (rise $rise); first: ${hit:-none}; bite: ${bit:-none}; $froze"
  # R7 (real hands: closing quiet 28 deg/s, 0.08 s onset): a sim slam (the tool's peak is ~80 deg/s) may only stir;
  # it must still register as clearly too loud (noise rise >= 0.35, i.e. Stirring).
  if [[ -n "$hit" ]]; then result SLAM PASS "$d"
  elif [[ "$rise" != none ]] && ge "$rise" 0.35; then result SLAM PASS "$d (registered as loud: rise $rise >= 0.35)"
  elif { [[ "$peak" == none ]] || lt "$peak" "$SLAM_MIN_PEAK"; } && { [[ "$rise" == none ]] || lt "$rise" 0.05; }; then
    result SLAM INCONCLUSIVE "$d (the hinge tool under-delivered the slam twice: peak < ${SLAM_MIN_PEAK}°/s, noise unchanged)"
  else result SLAM FAIL "$d"; fi
  [[ -f "$OUT_ABS/duo-h2-slam-bite.png" ]] || shoot_now duo-h2-slam-bite
  shoot duo-h2-after-slam inner

  # 2b. SLAM-CREAK (R3, tester 6): the same slam in attract mode (never bites), so the frame is the CREAK accent alone:
  #     the "CREAK!" shake and the red flash on the meter when the noise jumps > 0.25 in 0.3 s (Scene/Feel rule; the
  #     App logs it and freezes on `freezeOn=creak`, design/NEEDS.md CI R3). PASS: a creak line within 3 s of the
  #     slam. FAIL: no creak line although the logged noise rose > 0.25 over 3 lid samples. INFO otherwise (no line,
  #     no measurable jump: the App hook or the attract noise may be missing).
  hinge_set 105
  launch slam-creak "screen=run;mode=attract;seed=7;freezeOn=creak" 1
  SK="$OUT_ABS/logs/slam-creak.txt"
  hinge_sweep 150 6; sleep 2
  k0=$(nlines "$SK")
  hinge_sweep 104 0.3
  if wait_for "$SK" "HUSH-T (freeze creak|event creak|creak )" 3; then shoot_now duo-h2c-slam-creak; got="creak line seen"
  else shoot_now duo-h2c-slam-creak; got="no creak line within 3 s (shot anyway)"; fi
  sleep 0.5
  kl=$(after "$SK" "$k0" | grep -m1 -E "HUSH-T (freeze creak|event creak|creak )" | tr -d '\r')
  kj=$(after "$SK" "$k0" | lid_vals noise | max_jump)
  kp=$(after "$SK" "$k0" | lid_vals speed | max_of)
  d="peakSpeed=${kp}°/s noise jump(0.3 s)=$kj; first: ${kl:-none}; $got"
  if [[ -n "$kl" ]]; then result SLAM-CREAK PASS "$d"
  elif [[ "$kj" != none ]] && awk -v j="$kj" 'BEGIN { exit !(j + 0 > 0.25) }'; then result SLAM-CREAK FAIL "$d (the rule was met)"
  else result SLAM-CREAK INFO "$d (no line and no jump > 0.25 logged: App hook pending?)"; fi

  # 4a. UPRIGHT-NO-PAUSE (REVIEW-1-duo P1-4): the closing pause moved from 85° to 70° so a lid resting upright (90°,
  #     which the Duo can read as low as ~84°) never pauses. From 120, sweep to 78° and hold 2 s: no `paused closing`.
  # 4b. CLOSE-PAUSE: then on down to 55° (< 70° held 0.4 s pauses) → `paused closing`; back to 120 → `resumed`.
  hinge_set 120
  launch close-pause "screen=run;mode=attract;seed=7" 1
  CP="$OUT_ABS/logs/close-pause.txt"
  sleep 1
  u0=$(nlines "$CP")
  hinge_sweep 78 1.5; sleep 2
  u1=$(nlines "$CP")
  up=$(first_line "$CP" "HUSH-T paused closing" "$u0")
  d="held 78° for 2 s: $( [[ -n "$up" ]] && echo "paused at line $up (angle $(angle_before "$CP" "$up")°)" || echo "no pause" ); last angle $(angle_before "$CP" $(( u1 + 1 )))°"
  if [[ -z "$up" ]]; then result UPRIGHT-NO-PAUSE PASS "$d"; else result UPRIGHT-NO-PAUSE FAIL "$d (closing threshold still above 78°?)"; fi
  hinge_sweep 55 1; sleep 1.5
  p=$(first_line "$CP" "HUSH-T paused closing" "$u1")
  [[ -z "$p" && -n "$up" ]] && p="$up"
  shoot duo-h3-closing-card-55 inner
  hinge_sweep 120 1.5; sleep 2
  r=""
  [[ -n "$p" ]] && r=$(first_line "$CP" "HUSH-T resumed" "$p")
  d="paused@line ${p:-none} (angle $( [[ -n "$p" ]] && angle_before "$CP" "$p" || echo -)°), resumed@line ${r:-none} (angle $( [[ -n "$r" ]] && angle_before "$CP" "$r" || echo -)°); HUSH-H=$(count 'HUSH-H' "$CP")"
  if [[ -n "$p" && -n "$r" ]]; then result CLOSE-PAUSE PASS "$d"; else result CLOSE-PAUSE FAIL "$d"; fi
  shoot duo-h4-resumed-120 inner

  # 5. REOPEN-NO-BITE (REVIEW-1-duo P0-2, QA-1 P1-2): a real run (bites on) with the noise held at 0.6 until the pause
  #    (`noiseUntil=pause` releases the demo hold at the first pause and logs `HUSH-T noise released`). Open gently to
  #    130° (6°/s), lower gently to 60° (14°/s, under the closing creak), wait 2 s on the closing card, then reopen to
  #    120° in 0.4 s (~150°/s: the "normal" hand). PASS: no `event bitten` within 2 s of the reopen, no `resumed`
  #    while the lid was still low, and the first `resumed` after the reopen only once a logged angle is >= 95°.
  #    Without the release line the hold stays on all run (a bite is impossible), so a clean run is INFO, not PASS.
  hinge_set 105
  launch reopen "screen=run;mode=run;seed=7;noise=0.6;noiseUntil=pause" 1
  RO="$OUT_ABS/logs/reopen.txt"
  hinge_sweep 130 4; sleep 1
  c0=$(nlines "$RO")
  hinge_sweep 60 5; sleep 2
  p=$(first_line "$RO" "HUSH-T paused closing" "$c0")
  # (no shot here: a shot takes 3–15 s and the wait on the card must stay 2 s; duo-h3 already shows the closing card)
  r0=$(nlines "$RO")
  early=$(first_line "$RO" "HUSH-T resumed" "${p:-$c0}")
  [[ -n "$early" && "$early" -gt "$r0" ]] && early=""
  hinge_sweep 120 0.4
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
    p=$(first_line "$RO" "HUSH-T paused closing" "$c0")
    [[ -n "$p" && -n "$rl" && "$p" -gt "$rl" ]] && p=""
  fi
  pre=$( [[ -n "$p" ]] && angle_before "$RO" "$p" || echo -)
  maxn=$(after "$RO" "${rl:-$r0}" | lid_vals noise | max_of)
  d="paused@${p:-none} (${pre}°); resumed while low: ${early:-no}; resumed@${rl:-none} angle ${ra:-none}°; bitten≤2s: ${bitten:-none}; waking≤2s: ${waking:-none}; maxNoise after resume=$maxn; noise released=$released"
  verdict=PASS
  [[ -z "$p" ]] && { verdict=FAIL; d="$d; never paused at 60°"; }
  [[ -n "$early" ]] && { verdict=FAIL; d="$d; resumed before the reopen"; }
  [[ -n "$bitten" ]] && verdict=FAIL
  if [[ -z "$rl" ]]; then verdict=FAIL; d="$d; no resume within 5 s of the reopen"
  elif [[ "$ra" == none ]] || lt "$ra" 88; then verdict=FAIL; d="$d; resumed below 88° (R7: resume enters at 92°, hysteresis 88°)"; fi
  if [[ "$verdict" == PASS && "$released" == 0 ]]; then
    verdict=INFO; d="$d; INCONCLUSIVE: no 'HUSH-T noise released', so noise=0.6 was held all run (no bite possible). App: noiseUntil=pause (design/NEEDS.md)"
  fi
  result REOPEN-NO-BITE "$verdict" "$d"
  shoot duo-h6-reopened-120 inner

  # 6. COVER-SLOW-CLOSE (R3 decision 1, REVIEW-2-duo P0-1): the cover display is a pause, always. A real run with the
  #    noise held at 0.6 until the first pause (then frozen there, decision 2). From 120°, close gently to 40° over 6 s
  #    (13°/s, under the 18°/s closing creak: iOS hands the app to the cover display around 74–92° on the sim), then
  #    hold 3 s. PASS: a `HUSH-T paused` line, no `HUSH-T pose play` on a cover-sized canvas and no `small-canvas-open`
  #    (the deleted R2 fallback), and no `HUSH-T resumed` after the pause.
  hinge_set 120
  launch cover-slow "screen=run;mode=run;seed=7;noise=0.6;noiseUntil=pause" 1
  CS="$OUT_ABS/logs/cover-slow.txt"
  sleep 1
  k0=$(nlines "$CS")
  hinge_sweep 40 6; sleep 3
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
  #    impossible), as in REOPEN-NO-BITE.
  hinge_sweep 10 1.5; hinge_set 0; sleep 3
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
  if [[ -z "$rl" ]]; then verdict=FAIL; d="$d; no resume after the reopen (even at 165°)"
  else
    { [[ "$ra" == none ]] || lt "$ra" 88; } && { verdict=FAIL; d="$d; resumed below 88° (R7 hysteresis)"; }
    [[ "$rc" != "$INNER_CANVAS" ]] && { verdict=FAIL; d="$d; resumed on $rc, not the inner $INNER_CANVAS"; }
  fi
  [[ -n "$oncover" ]] && verdict=FAIL
  [[ -n "$bit" ]] && verdict=FAIL
  if [[ "$verdict" == PASS && "$released" == 0 ]]; then
    verdict=INFO; d="$d; INCONCLUSIVE: no 'HUSH-T noise released' (noise held all run, no bite possible)"
  fi
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
  FLAT_GAP_MAX="${FLAT_GAP_MAX:-1.2}"
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
  WD_REOPEN_S="${WATCHDOG_REOPEN_S:-14}"
  WD_LIMIT="${WATCHDOG_LIMIT:-8}"
  hinge_set 130
  launch watchdog "screen=run;mode=attract;seed=7" 1
  WD="$OUT_ABS/logs/watchdog.txt"
  sleep 1
  w0=$(nlines "$WD")
  hinge_sweep 60 5; hinge_wiggle 60 1; sleep 0.5
  wp=$(first_line "$WD" "HUSH-T paused" "$w0")
  wlow=$(angles "$WD" "$w0" "$(nlines "$WD")" | min_of)
  if [[ -z "$wp" ]] && ! le "$wlow" 70; then
    log "WATCHDOG: no pause and nothing ≤ 70° logged (lowest ${wlow}°): the hinge tool under-delivered? close again"
    hinge_set 60; hinge_wiggle 60 2; sleep 0.5
    wp=$(first_line "$WD" "HUSH-T paused" "$w0")
    wlow=$(angles "$WD" "$w0" "$(nlines "$WD")" | min_of)
  fi
  w1=$(nlines "$WD")
  wearly=""
  [[ -n "$wp" ]] && wearly=$(between "$WD" "$wp" "$w1" | grep -m1 -oE "HUSH-T (resumed|watchdog resume)[^\r]*")
  clock_start "$WD"
  hinge_sweep 130 "$WD_REOPEN_S"
  w2=$(nlines "$WD"); wt2=$(now_s)
  wr=""; wn=0
  while :; do
    wr=$(first_line "$WD" "HUSH-T (resumed|watchdog resume)" "$w1"); [[ -n "$wr" ]] && break
    awk -v a="$(now_s)" -v b="$wt2" -v l="$WD_LIMIT" 'BEGIN { exit !(a - b >= l + 0.5) }' && break
    hinge_wiggle 130 1; wn=$((wn + 1))
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
    if (( wr <= w2 )); then wwhen="during the reopen (${wdt} s vs reaching 130)"; wdt=on-the-way-up
    else wwhen="${wdt} s after reaching 130"; fi
  fi
  wtop=$(angles "$WD" "$w1" "$w3" | max_of)
  wpa=$( [[ -n "$wp" ]] && angle_before "$WD" "$wp" || echo - )
  d="paused@${wp:-none} (${wpa}°, lowest logged ${wlow}°); resumed before the reopen: ${wearly:-no}; reopen 60 → 130 over ${WD_REOPEN_S} s, top logged ${wtop}°, $wn wiggle(s) after; first resume@${wr:-none}: ${wline:-none} (angle ${wang:-none}°), $wwhen; watchdog lines: $(count 'HUSH-T watchdog resume' "$WD")"
  if [[ -z "$wp" ]]; then
    if le "$wlow" 65; then result WATCHDOG FAIL "$d; never paused although the lid went to ${wlow}°"
    else result WATCHDOG INCONCLUSIVE "$d (the hinge tool never delivered the close: nothing ≤ 70° logged)"; fi
  elif [[ -n "$wearly" ]]; then
    result WATCHDOG FAIL "$d; resumed while the lid was still at 60°"
  elif [[ -n "$wr" ]]; then
    if [[ "$wdt" == on* ]] || ! num "$wdt" || le "$wdt" "$(awk -v l="$WD_LIMIT" 'BEGIN { print l + 0.2 }')"; then
      result WATCHDOG PASS "$d$( num "$wdt" || [[ "$wdt" == on* ]] || echo ' (no line clock: within the wiggle loop)')"
    else result WATCHDOG FAIL "$d; resumed, but ${wdt} s after reaching 130 (> ${WD_LIMIT} s)"; fi
  elif ! ge "$wtop" 92; then
    result WATCHDOG INCONCLUSIVE "$d (the hinge tool never delivered the reopen: nothing ≥ 95° logged)"
  else
    result WATCHDOG FAIL "$d; STUCK: no resume within ${WD_LIMIT} s of reaching 130°"
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
  hinge_set 105
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
    hinge_wiggle 105 1
    l0=$(nlines "$LP")
    hinge_sweep 160 7
    sleep 1.5
    l1=$(nlines "$LP")
    ltop=$(angles "$LP" "$l0" "$l1" | max_of)
    log "LANDSCAPE-PLAY attempt $attempt: top logged angle ${ltop}°, HUSH-H=$(hh_count "$LP" "$l0" "$l1"), lid lines=$(lid_count "$LP" "$l0" "$l1")"
    ge "$ltop" 150 && break
    (( attempt >= 2 )) && break
    attempt=2
    log "LANDSCAPE-PLAY: the logged angle never reached 150° (the hinge tool under-delivered?): close gently and again"
    hinge_sweep 105 6; sleep 1
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
  lcr=$(head -n "$l1" "$LP" | grep -c "HUSH-T event lidCracked" | tr -d ' ')   # R7: the lid is already cracked at 105° (openness 0.06)
  linp=$(grep -oE "HUSH-T input [a-z]+" "$LP" | tail -1 | awk '{print $3}')
  shoot duo-h11-landscape-play-160 inner
  lwh=$(png_wh "$OUT_ABS/duo-h11-landscape-play-160.png")
  lland=0
  [[ "$lwh" != "?" ]] && ! is_portrait "$lwh" && lland=1
  d="canvas: ${lcl#HUSH-T canvas } ($lkhow: $lk); ${lor:-no 'orient landscape' line}; last pose ${lpose:-none}; standUp: ${lstand:-none}; paused pose: ${lpp:-none}; input ${linp:-none}; lid angle range ${lar}° openness range ${lorr} (top ${ltop}°, attempt $attempt/2); lidCracked=$lcr; frame $lwh (want landscape, the chest drawn sideways)"
  reached=0
  { [[ "$lor" == *" ok"* ]] || [[ "$lk" == odd ]] || (( lland )); } && reached=1
  why=""
  [[ -n "$lstand" ]] && why="$why; the standUp card came up"
  [[ -n "$lpp" ]] && why="$why; the run paused for the pose"
  [[ "$lk" == even ]] && why="$why; k is even in landscape"
  { [[ "$lar" == none ]] || lt "$lar" 30; } && why="$why; the lid angle didn't follow the hinge"
  { [[ "$lorr" == none ]] || lt "$lorr" 0.2; } && why="$why; the openness didn't move"
  (( lcr == 0 )) && why="$why; no lidCracked"
  if ! ge "$ltop" 150; then
    result LANDSCAPE-PLAY INCONCLUSIVE "$d (the hinge tool never delivered the open twice: no logged angle ≥ 150°)"
  elif (( ! reached )); then
    result LANDSCAPE-PLAY INCONCLUSIVE "$d (the sim never reached a landscape interface: nothing was tested)"
  elif [[ -n "$why" ]]; then
    result LANDSCAPE-PLAY FAIL "$d$why"
  elif [[ "$lk" == unknown ]]; then
    result LANDSCAPE-PLAY INCONCLUSIVE "$d (all else passed, but k is unreadable: no k= on the canvas line and a portrait-shaped size; App: add k=, design/NEEDS.md CI R6)"
  else
    result LANDSCAPE-PLAY PASS "$d"
  fi
  # The sim is landscape now: give the next tabletop launch the full portrait wait again if portrait ever worked.
  grep -q "HUSH-T orient portrait ok" "$OUT_ABS"/logs/*.txt 2>/dev/null && ORIENT_WAIT=25
fi

# ---- pass: the tabletop frames (closed 105, half 135, wide 160, cover shut, reopened) -----------------------------
if [[ " $PASSES " == *" frames "* ]]; then
  # Attract run on the real hinge (no pilot, the candle never burns, no bites), drawn turned round (the Duo default).
  # Slow sweeps (7–8°/s) keep the mimic asleep so the frames show the reveal, not the alarm.
  hinge_set 105
  launch frames "screen=run;mode=attract;seed=7" 1
  FL="$OUT_ABS/logs/frames.txt"
  shoot duo-01-closed-105 inner
  hinge_sweep 135 4; sleep 2.5; shoot duo-02-half-135 inner
  hinge_sweep 160 3.5; sleep 2.5; shoot duo-03-wide-160 inner
  result TURNED INFO "$(canvas_line "$FL")"
  hinge_sweep 60 2; hinge_sweep 10 0.8; hinge_set 0; sleep 3; shoot duo-04-cover-shut cover
  result COVER INFO "paused-closing lines=$(count 'HUSH-T paused closing' "$FL"); last canvas: $(canvas_line "$FL")"
  o0=$(nlines "$FL")
  hinge_sweep 165 2.5; sleep 3
  # The reopen from the cover (REVIEW-1-duo P0-2's other half): where did the run resume? Evidence only (attract
  # never bites); the R2 rule is >= 95° and still for 0.3 s.
  orl=$(first_line "$FL" "HUSH-T resumed" "$o0")
  ora=""; [[ -n "$orl" ]] && { ora=$(sed -n "${orl}p" "$FL" | grep -oE "angle [0-9.]+" | awk '{print $2}'); [[ -n "$ora" ]] || ora=$(angle_before "$FL" "$orl"); }
  result COVER-REOPEN INFO "reopen 0 → 165° in 2.5 s: resumed@${orl:-none} angle ${ora:-none}°; maxNoise after=$(after "$FL" "${orl:-$o0}" | lid_vals noise | max_of)"
  shoot duo-05-reopened-165 inner
  hinge_sweep 120 1.5
  # The same half-open moment with "Turn the chest round" off, for comparison with duo-02.
  hinge_set 105
  launch frames-unturned "screen=run;mode=attract;seed=7;turn=0" 1
  hinge_sweep 135 4; sleep 2.5; shoot duo-06-half-135-unturned inner
  result UNTURNED INFO "$(canvas_line "$OUT_ABS/logs/frames-unturned.txt")"
fi

# ---- pass: UI frames -----------------------------------------------------------------------------------------------
if [[ " $PASSES " == *" ui "* ]]; then
  # Home's chest follows the hinge: shut-ish at 120, the little mimic peeks at 150.
  hinge_set 120 || true
  launch ui-home "screen=home;progress=mid" 1; shoot duo-ui-home-120 inner
  hinge_sweep 150 3; sleep 2.5; shoot duo-ui-home-150 inner
  # Lesson step 1 (pose) at 150°, then into its R2 90–112° window (REVIEW-1-duo P1-6) for 0.5 s+ (the step should
  # pass by itself, and step 2 must not say "Ease the lid down first": 105° is already in the chest's shut zone).
  launch ui-lesson "screen=lesson;lessonStep=1" 1; shoot duo-ui-lesson-1-150 inner
  hinge_sweep 105 4; sleep 2.5; shoot duo-ui-lesson-after-pose inner
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
  launch ui-pose-card "screen=home;progress=mid;orient=landscape" 0; sleep 3; shoot duo-ui-pose-card inner
  PC="$OUT_ABS/logs/ui-pose-card.txt"
  wh=$(png_wh "$OUT_ABS/duo-ui-pose-card.png")
  pcl=$(grep -m1 -oE "HUSH-T pose standUp[^\r]*" "$PC" 2>/dev/null)
  tip=$(grep -m1 -oE "HUSH-T pose tip shown[^\r]*" "$PC" 2>/dev/null)
  d="frame $wh; tip: ${tip:-none}; standUp: ${pcl:-none}; $(canvas_line "$PC")"
  if [[ -n "$pcl" ]]; then result POSE-NO-BLOCK FAIL "$d (the blocking book card is back)"
  elif [[ -n "$tip" ]]; then result POSE-NO-BLOCK PASS "$d"
  else result POSE-NO-BLOCK INFO "$d (no block; the tip needs a landscape UIDevice reading the sim may not give)"; fi
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

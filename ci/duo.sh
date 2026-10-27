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
# Env: UDID (required), OUT (duo-screens), PASSES ("hinge frames ui"), ORIENT ("portrait"), STRICT (1 = exit 1 when a
# check FAILs; default 0: the frames and the PASS/FAIL table are the evidence).
# Writes: $OUT/*.png (lit panel), $OUT/raw/<shot>-inner|cover.png, $OUT/logs/<launch>.txt (app stdout+stderr),
# $OUT/logs/run.txt (this script), $OUT/checks.tsv (check <TAB> PASS|FAIL|INFO <TAB> detail) and, when
# $GITHUB_STEP_SUMMARY is set, a summary table.
set -uo pipefail

APP="build/Build/Products/Debug-iphonesimulator/Hush.app"
BUNDLE="com.pravegm.hush"
OUT="${OUT:-duo-screens}"
PASSES="${PASSES:-hinge frames ui}"
ORIENT="${ORIENT-portrait}"
STRICT="${STRICT:-0}"
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

# result <CHECK> <PASS|FAIL|INFO> <detail>: one line in the run log ("SLOW-OPEN PASS (…)") and in checks.tsv.
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

# png_wh <file>: "WxH" of a PNG, or "?". The Duo's inner-display capture follows the interface orientation (Brim:
# 2007 x 2853 in portrait, 2853 x 2007 for the book card), so it is the ground truth for PORTRAIT.
png_wh() {
  local w h
  w=$(to 20 sips -g pixelWidth "$1" 2>/dev/null | awk '/pixelWidth/ {print $2}')
  h=$(to 20 sips -g pixelHeight "$1" 2>/dev/null | awk '/pixelHeight/ {print $2}')
  if [[ -n "$w" && -n "$h" ]]; then echo "${w}x${h}"; else echo "?"; fi
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
  if is_portrait "$wh"; then result PORTRAIT PASS "$d"
  else result PORTRAIT FAIL "$d (the sim stayed in book pose: DemoMode needs Brim's orient=portrait)"; fi
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
  hinge_set 105
  launch slam "screen=run;mode=run;seed=7;freezeOn=bite" 1
  SM="$OUT_ABS/logs/slam.txt"
  hinge_sweep 150 6
  h0=$(nlines "$SM"); sleep 1.5
  hl2=$(sed -n "$(( h0 + 1 )),\$p" "$SM" | lid_vals speed | grep -E '^-?[0-9.]+$' | tail -1)
  result STILL-RUN INFO "last speed 1.5 s into the hold at 150 (real run)=${hl2:-none}"
  sleep 0.5
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
  d="peakSpeed=${peak}°/s maxNoise=$pn first: ${hit:-none}; bite: ${bit:-none}; $froze"
  if [[ -n "$hit" ]]; then result SLAM PASS "$d"; else result SLAM FAIL "$d"; fi
  [[ -f "$OUT_ABS/duo-h2-slam-bite.png" ]] || shoot_now duo-h2-slam-bite
  shoot duo-h2-after-slam inner

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
  pre=$( [[ -n "$p" ]] && angle_before "$RO" "$p" || echo -)
  maxn=$(after "$RO" "${rl:-$r0}" | lid_vals noise | max_of)
  d="paused@${p:-none} (${pre}°); resumed while low: ${early:-no}; resumed@${rl:-none} angle ${ra:-none}°; bitten≤2s: ${bitten:-none}; waking≤2s: ${waking:-none}; maxNoise after resume=$maxn; noise released=$released"
  verdict=PASS
  [[ -z "$p" ]] && { verdict=FAIL; d="$d; never paused at 60°"; }
  [[ -n "$early" ]] && { verdict=FAIL; d="$d; resumed before the reopen"; }
  [[ -n "$bitten" ]] && verdict=FAIL
  if [[ -z "$rl" ]]; then verdict=FAIL; d="$d; no resume within 5 s of the reopen"
  elif [[ "$ra" == none ]] || lt "$ra" 95; then verdict=FAIL; d="$d; resumed below 95°"; fi
  if [[ "$verdict" == PASS && "$released" == 0 ]]; then
    verdict=INFO; d="$d; INCONCLUSIVE: no 'HUSH-T noise released', so noise=0.6 was held all run (no bite possible). App: noiseUntil=pause (design/NEEDS.md)"
  fi
  result REOPEN-NO-BITE "$verdict" "$d"
  shoot duo-h6-reopened-120 inner
fi

# ---- pass: the tabletop frames (closed 105, half 135, wide 160, cover shut, reopened) -----------------------------
if [[ " $PASSES " == *" frames "* ]]; then
  # Attract run on the real hinge (no pilot, the torch never burns, no bites), drawn turned round (the Duo default).
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
  launch ui-codex "screen=codex;progress=late" 1; sleep 2; shoot duo-ui-codex inner
  launch ui-settings "screen=settings" 1; sleep 2; shoot duo-ui-settings inner
  # Book pose: no orient request, so the sim keeps its own landscape inner canvas → the "Stand it up like a little
  # laptop" pose card (Brim's ui-book got its 2853 x 2007 book card the same way, after portrait launches).
  launch ui-pose-book "screen=home;progress=mid" 0; sleep 2; shoot duo-ui-pose-book inner
  wh=$(png_wh "$OUT_ABS/duo-ui-pose-book.png"); cl=$(canvas_line "$OUT_ABS/logs/ui-pose-book.txt")
  if [[ "$wh" != "?" ]] && ! is_portrait "$wh"; then result POSE-BOOK INFO "book pose (landscape) as expected: $wh; ${cl:-no canvas line}"
  else result POSE-BOOK INFO "portrait ($wh), not the book card: with R2's automatic requestPortrait on the pose card (REVIEW-1-duo P0-1) that is the fix working; ${cl:-no canvas line}"; fi
  hinge_sweep 40 1.5; hinge_set 0; sleep 3; shoot duo-ui-cover cover
  hinge_set 160 || true
fi

ls -la "$OUT_ABS" | tee -a "$RUNLOG" >&2
log "checks: $(awk -F'\t' '$2=="PASS"' "$CHECKS" | wc -l | tr -d ' ') PASS, $(awk -F'\t' '$2=="FAIL"' "$CHECKS" | wc -l | tr -d ' ') FAIL"
grep -E $'\t(PASS|FAIL)\t' "$CHECKS" | awk -F'\t' '{ printf "%s %s (%s)\n", $1, $2, $3 }' || true
write_summary
if [[ "$STRICT" == 1 ]] && grep -q $'\tFAIL\t' "$CHECKS"; then exit 1; fi
exit 0

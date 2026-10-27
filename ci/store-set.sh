#!/usr/bin/env bash
# Assemble one Hush App Store screenshot set from a capture folder (ci/store-capture.sh → ci/screenshots.sh or ci/duo.sh
# output): frame every scenario of <scenarios> that matches <filter> under its caption (ci/store-frame.swift) and write
# <dir>/store/<name>.png, <dir>/store/MANIFEST.txt and <dir>/store/MANIFEST.tsv. Adapted from Swoop's ci/store-set.sh
# (landscape, book composite) for Hush: portrait slots, the tabletop composite, HUSH-T log checks, Hush's glossary.
#
#   bash ci/store-set.sh <dir> <label> "<slot sizes>" [scenarios] [filter] [raw prefix]
#   e.g. TABLETOP_DIR=raw-duo bash ci/store-set.sh raw-69 'iPhone 6.9-inch' "1320x2868" ci/store-scenarios.txt '^P[0-9]'
#        REQUIRE_CANVAS='669x951 fold=1 turned=0' \
#          bash ci/store-set.sh raw-duo 'iPhone Duo inner' "2007x2853" ci/duo-store-scenarios.txt '^D[0-9]' store-
#
#  <slot sizes>  the portrait WxH sizes App Store Connect accepts for this slot, space separated, the set's own device
#                size first. A flat frame is made at its raw capture's size when that is one of them; a raw capture of
#                any other size (wrong simulator, the Duo's cover display, a book-pose landscape capture) is FLAGGED
#                and not framed.
#  raw prefix    ci/duo.sh names captures store-<name>.png (logs/store-<name>.txt); ci/screenshots.sh uses none.
#
# Scenario lines: name|demo args|wait|caption|expect|frame   (the 6th column is optional; capture scripts ignore it)
#   frame = flat (default) | tabletop | tabletop:<duo scenario name>
#     tabletop         this set's own raw (a Duo inner capture) drawn as the tabletop composite (store-frame --tabletop).
#     tabletop:<name>  the composite made from another set's Duo capture: $TABLETOP_DIR/$TABLETOP_PREFIX<name>.png. The
#                      iPhone sets use this for frame 1 (D1's Duo capture). If that capture is missing or not
#                      $TABLETOP_SOURCE_SIZE, the frame falls back to this set's own flat capture and is FLAGGED.
#   A tabletop frame is made at the set's own raw size if that is a slot size, else at the first slot size.
#
# Checks per frame, against the app log snapshotted at capture (logs/<prefix><name>.at-capture.txt, else .txt; for a
# tabletop:<name> frame, the source capture's log): "HUSH-T demo '…' starts"; "HUSH-T freeze <tag>" for freezeOn=<tag>
# ("HUSH-T freeze after" for a freezeAfter= line without freezeOn); "HUSH-T skipped" for skipTo=; "golden=1" on a
# chestArrived line for golden=1; the expect regex (5th column); the LAST "HUSH-T canvas …" line against
# $REQUIRE_CANVAS (and, for every tabletop source, against $TABLETOP_REQUIRE, default the Duo's folded 669x951 canvas).
# Captions are linted: ≤ 6 words in the headline and ≤ 6 in the sub-line ("×1.5" is one word), "FREEZE" in capitals,
# "keep" (the verb is bank, decision 3), and $CAPTION_FORBID (the Duo set: the lever is a phone-only control). Output
# size and alpha are read back with sips. A frame that fails a check is still framed but goes to store/_flagged/, so
# store/ holds only clean frames. A caption with a banned word (store-frame.swift: "torch", "#1", "Made for iPhone
# Duo") is REJECTED: no frame at all.
# Never fails the job: always exits 0; every problem is a MANIFEST line and a ::warning::.
# Env: STORE_RADIUS (flat capture corner radius, a fraction of its shorter side; default 0.06), REQUIRE_CANVAS,
#      CAPTION_FORBID (regex), TABLETOP_DIR, TABLETOP_PREFIX (default store-), TABLETOP_SOURCE_SIZE (default 2007x2853),
#      TABLETOP_REQUIRE, TABLETOP_ANGLE (degrees, default 125), TABLETOP_ELEVATION (degrees, default 28), STORE_ROTATE
#      (90|270: rotate a capture whose size is a slot size turned sideways before framing; default off = FLAGGED),
#      STORE_FRAME_BIN (compiled compositor cache).
set -uo pipefail

DIR="${1:?usage: store-set.sh <dir> <label> <slot sizes> [scenarios] [filter] [raw prefix]}"
LABEL="${2:-store}"
SIZES="${3:?slot sizes, e.g. 1320x2868}"
SCEN="${4:-ci/store-scenarios.txt}"
FILTER="${5:-.}"
PREFIX="${6:-}"
RADIUS="${STORE_RADIUS:-0.06}"
REQUIRE_CANVAS="${REQUIRE_CANVAS:-}"
CAPTION_FORBID="${CAPTION_FORBID:-}"
TABLETOP_DIR="${TABLETOP_DIR:-}"
TABLETOP_PREFIX="${TABLETOP_PREFIX:-store-}"
TABLETOP_SOURCE_SIZE="${TABLETOP_SOURCE_SIZE:-2007x2853}"
TABLETOP_REQUIRE="${TABLETOP_REQUIRE:-669x951 fold=1}"
TABLETOP_ANGLE="${TABLETOP_ANGLE:-125}"
TABLETOP_ELEVATION="${TABLETOP_ELEVATION:-28}"
STORE_ROTATE="${STORE_ROTATE:-}"
FIRST_SIZE="${SIZES%% *}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/store-frame.swift"
CACHE="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
BIN="${STORE_FRAME_BIN:-${CACHE%/}/hush-store-frame}"

if [[ ! -d "$DIR" ]]; then
  echo "::warning::$LABEL: no capture folder $DIR (its capture job was skipped or failed); no set made"
  exit 0
fi
mkdir -p "$DIR/store/_flagged" "$DIR/logs" "$DIR/store/.work"
DIR="$(cd "$DIR" && pwd)"
STORE="$DIR/store"
WORK="$STORE/.work"
rm -f "$STORE"/*.png "$STORE"/_flagged/*.png "$WORK"/*
MANIFEST="$STORE/MANIFEST.txt"
TSV="$STORE/MANIFEST.tsv"
: > "$MANIFEST"
printf 'file\tsize\tstatus\tframe\tcaption\tnotes\n' > "$TSV"
TABLETOP_DIR_ABS=""
if [[ -n "$TABLETOP_DIR" && -d "$TABLETOP_DIR" ]]; then TABLETOP_DIR_ABS="$(cd "$TABLETOP_DIR" && pwd)"; fi

to() {
  local s="$1"; shift
  if command -v gtimeout >/dev/null 2>&1; then gtimeout -k 5 "$s" "$@"
  elif command -v timeout >/dev/null 2>&1; then timeout -k 5 "$s" "$@"
  else perl -e 'alarm shift; exec @ARGV or die "exec failed: $!\n"' "$s" "$@"; fi
}

note() { echo "$*" | tee -a "$MANIFEST"; }
warn() { echo "::warning::$LABEL: $*"; }
row() {   # row <file> <size> <slot> <alpha> <status> <frame> <caption> <notes>
  note "$(printf '%-26s %-10s %-5s %-6s %-8s %-9s %s' "$1" "$2" "$3" "$4" "$5" "$6" "$8")"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$5" "$6" "$7" "$8" >> "$TSV"
}

# png_info <file>: "WxH alpha=<yes|no|?>" via sips, or "? alpha=?".
png_info() {
  local out w h a
  out=$(to 20 sips -g pixelWidth -g pixelHeight -g hasAlpha "$1" 2>/dev/null || true)
  w=$(awk '/pixelWidth/ {print $2}' <<< "$out")
  h=$(awk '/pixelHeight/ {print $2}' <<< "$out")
  a=$(awk '/hasAlpha/ {print $2}' <<< "$out")
  if [[ -n "$w" && -n "$h" ]]; then echo "${w}x${h} alpha=${a:-?}"; else echo "? alpha=?"; fi
}
is_slot() { [[ " $SIZES " == *" $1 "* ]]; }
turned() { local w="${1%x*}" h="${1#*x}"; echo "${h}x${w}"; }

# The compositor: compiled once (cached across sets in one job), else interpreted with `xcrun swift`.
if [[ ! -x "$BIN" || "$SRC" -nt "$BIN" ]]; then
  built=0
  for attempt in 1 2; do
    if to 600 xcrun swiftc -O -swift-version 5 -module-name StoreFrame "$SRC" -o "$BIN" > "$DIR/logs/store-frame-build.log" 2>&1; then
      built=1; echo "compiled ci/store-frame.swift -> $BIN"; break
    fi
    echo "warning: compile attempt $attempt of ci/store-frame.swift failed"; sleep 3
  done
  if (( ! built )); then
    tail -40 "$DIR/logs/store-frame-build.log" || true
    warn "could not compile ci/store-frame.swift (see logs/store-frame-build.log); falling back to xcrun swift"
    BIN=""
  fi
fi
compose() {
  local status
  for attempt in 1 2; do
    if [[ -n "$BIN" ]]; then to 180 "$BIN" "$@"; else to 600 xcrun swift "$SRC" "$@"; fi
    status=$?
    (( status == 0 )) && return 0
    (( status == 1 || status == 2 )) && return "$status"   # its own error / a rejected caption: no retry
    sleep 2                                 # a timeout or a crash: one more try
  done
  return "$status"
}

problems=()
# last_canvas <log>: the last "HUSH-T canvas …" line (without the prefix), or "".
last_canvas() { grep -oE "HUSH-T canvas .*" "$1" 2>/dev/null | tail -1 | tr -d '\r' | sed 's/^HUSH-T canvas //'; }
# check_log <log> <demo args> <expect regex> <canvas regex…>: append every failed check to problems.
check_log() {
  local f="$1" a="$2" e="$3" fz c r
  shift 3
  if [[ ! -f "$f" ]]; then problems+=("no app log for this capture"); return 0; fi
  grep -q "HUSH-T demo '.*' starts" "$f" || problems+=("no \"HUSH-T demo '…' starts\" line (demo args not applied?)")
  if [[ "$a" =~ freezeOn=([A-Za-z]+) ]]; then
    fz="${BASH_REMATCH[1]}"
    grep -q "HUSH-T freeze $fz" "$f" || problems+=("never froze on $fz before the capture")
  elif [[ "$a" == *freezeAfter=* ]]; then
    grep -q "HUSH-T freeze after" "$f" || problems+=("never froze (freezeAfter) before the capture")
  fi
  if [[ "$a" == *skipTo=* ]]; then grep -q "HUSH-T skipped" "$f" || problems+=("no 'HUSH-T skipped' line"); fi
  if [[ "$a" =~ (^|;)golden=1 ]]; then
    grep -qE "HUSH-T event chestArrived .*golden=1" "$f" || problems+=("golden=1 but no golden chest arrived")
  fi
  if [[ -n "$e" ]] && ! grep -qE -- "$e" "$f"; then problems+=("log has no line matching '$e'"); fi
  c=$(last_canvas "$f")
  for r in "$@"; do
    if [[ -n "$r" ]] && ! grep -qE -- "$r" <<< "$c"; then problems+=("last canvas '${c:-none}' does not match '$r'"); fi
  done
  return 0
}

# words <text>: the word count ("×1.5" or "—" alone count as one token; `*` ignored).
words() { local t="${1//\*/}"; wc -w <<< "$t" | tr -d ' '; }
# lint_caption <caption>
lint_caption() {
  local c="$1" head sub hw sw
  [[ -z "${c// /}" ]] && { problems+=("empty caption"); return 0; }
  head="${c%% / *}"
  sub=""; [[ "$c" == *" / "* ]] && sub="${c#* / }"
  hw=$(words "$head"); sw=$(words "$sub")
  (( hw > 6 )) && problems+=("headline has $hw words (max 6)")
  (( sw > 6 )) && problems+=("sub-line has $sw words (max 6)")
  [[ "$c" == *FREEZE* ]] && problems+=("caption says FREEZE: the app shows \"Freeze!\"")
  shopt -s nocasematch
  [[ "$c" =~ (^|[^a-z])keep([^a-z]|$) ]] && problems+=("caption says 'keep': the verb is 'bank' (ROUND-3 decision 3)")
  shopt -u nocasematch
  if [[ -n "$CAPTION_FORBID" ]] && grep -qiE -- "$CAPTION_FORBID" <<< "$c"; then
    problems+=("caption matches '$CAPTION_FORBID' (not true of this set)")
  fi
  return 0
}

device="(see the capture log)"
if [[ -f "$DIR/device.txt" ]]; then
  device="$(sed -n 's/^name=//p' "$DIR/device.txt") [$(sed -n 's/^resolved=//p' "$DIR/device.txt")]"
fi
note "Hush App Store set: $LABEL"
note "slot sizes: $SIZES   device: $device   tabletop source: ${TABLETOP_DIR_ABS:-this set}"
note "built: $(date -u '+%Y-%m-%d %H:%M UTC')  commit: ${GITHUB_SHA:-local}  run: ${GITHUB_RUN_ID:-local}"
note "upload: store/*.png only, in name order. store/_flagged/ = framed but a check failed: fix or eyeball first."
note ""
note "$(printf '%-26s %-10s %-5s %-6s %-8s %-9s %s' frame size slot alpha status mode notes)"

ok=0; flagged=0; missing=0
while IFS= read -r -u 3 line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"
  [[ -z "${line// /}" || "$line" == \#* ]] && continue
  IFS='|' read -r name args wait caption expect frame <<< "$line"
  frame="${frame//[[:space:]]/}"; frame="${frame%%|*}"
  [[ -n "$name" && "$name" =~ $FILTER ]] || continue
  raw="$DIR/$PREFIX$name.png"
  applog="$DIR/logs/$PREFIX$name.at-capture.txt"
  [[ -f "$applog" ]] || applog="$DIR/logs/$PREFIX$name.txt"
  problems=()
  notes=()
  lint_caption "$caption"

  # Which picture, which mode.
  mode=flat; src="$raw"; srclog="$applog"; srcargs="$args"; srcexpect="$expect"
  if [[ "$frame" == tabletop || "$frame" == tabletop:* ]]; then
    tsrc="$raw"; tlog="$applog"; targs="$args"; texpect="$expect"
    if [[ "$frame" == tabletop:* ]]; then
      tname="${frame#tabletop:}"; targs=""; texpect=""
      if [[ -n "$TABLETOP_DIR_ABS" ]]; then
        tsrc="$TABLETOP_DIR_ABS/$TABLETOP_PREFIX$tname.png"
        tlog="$TABLETOP_DIR_ABS/logs/$TABLETOP_PREFIX$tname.at-capture.txt"
        [[ -f "$tlog" ]] || tlog="$TABLETOP_DIR_ABS/logs/$TABLETOP_PREFIX$tname.txt"
      else
        tsrc=""
      fi
    fi
    tdims="-"
    [[ -n "$tsrc" && -f "$tsrc" ]] && { tinfo=$(png_info "$tsrc"); tdims="${tinfo%% *}"; }
    if [[ "$tdims" == "$TABLETOP_SOURCE_SIZE" ]]; then
      mode=tabletop; src="$tsrc"; srclog="$tlog"; srcargs="$targs"; srcexpect="$texpect"
    elif [[ -z "$tsrc" || ! -f "$tsrc" ]]; then
      problems+=("tabletop source ${frame#tabletop:} missing (no Duo capture${TABLETOP_DIR:+ in $TABLETOP_DIR}): flat fallback; frame 1 must be the Duo")
    else
      problems+=("tabletop source is $tdims, not the Duo inner $TABLETOP_SOURCE_SIZE: flat fallback")
    fi
  fi

  if [[ "$mode" == flat && ! -f "$raw" ]]; then
    row "$name.png" - no - MISSING "$mode" "$caption" "no capture $PREFIX$name.png (launch or screenshot failed; see the capture log)"
    warn "$name MISSING (no capture)"
    missing=$((missing + 1))
    continue
  fi

  # Content checks against the log of the picture actually shown. A tabletop:<name> source is another set's Duo
  # capture: this set's REQUIRE_CANVAS (the iPhone's unfolded canvas) doesn't apply to it, only TABLETOP_REQUIRE.
  if [[ "$mode" == tabletop && "$frame" == tabletop:* ]]; then check_log "$srclog" "$srcargs" "$srcexpect" "$TABLETOP_REQUIRE"
  elif [[ "$mode" == tabletop ]]; then check_log "$srclog" "$srcargs" "$srcexpect" "$REQUIRE_CANVAS" "$TABLETOP_REQUIRE"
  else check_log "$srclog" "$srcargs" "$srcexpect" "$REQUIRE_CANVAS"; fi

  # Output size.
  if [[ "$mode" == tabletop ]]; then
    outsize="$FIRST_SIZE"
    if [[ -f "$raw" ]]; then rinfo=$(png_info "$raw"); is_slot "${rinfo%% *}" && outsize="${rinfo%% *}"; fi
    notes+=("tabletop from $(basename "$src") at ${TABLETOP_ANGLE}°")
  else
    rinfo=$(png_info "$raw"); rawdims="${rinfo%% *}"
    if ! is_slot "$rawdims"; then
      if [[ -n "$STORE_ROTATE" ]] && is_slot "$(turned "$rawdims")"; then
        if to 30 sips -r "$STORE_ROTATE" "$raw" --out "$WORK/$name.png" >/dev/null 2>&1; then
          src="$WORK/$name.png"; rawdims="$(turned "$rawdims")"; notes+=("raw turned ${STORE_ROTATE}°: eyeball the orientation")
        fi
      fi
    fi
    if ! is_slot "$rawdims"; then
      why="raw capture is $rawdims, not a slot size ($SIZES): not framed"
      [[ "$rawdims" != "?" ]] && is_slot "$(turned "$rawdims")" && why="raw capture is $rawdims, a slot size turned sideways (the sim stayed in book pose?); set STORE_ROTATE=90|270 or recapture: not framed"
      row "$name.png" "$rawdims" no - FLAGGED "$mode" "$caption" "$why"
      warn "$name: $why"
      flagged=$((flagged + 1))
      continue
    fi
    outsize="$rawdims"
  fi

  dest="$STORE/$name.png"
  (( ${#problems[@]} > 0 )) && dest="$STORE/_flagged/$name.png"
  cargs=(--in "$src" --out "$dest" --size "$outsize" --radius "$RADIUS" --caption "$caption")
  [[ "$mode" == tabletop ]] && cargs+=(--tabletop --angle "$TABLETOP_ANGLE" --elevation "$TABLETOP_ELEVATION")
  report=$(compose "${cargs[@]}" 2>&1)
  status=$?
  if (( status == 2 )); then
    row "$name.png" - no - REJECTED "$mode" "$caption" "$(tail -1 <<< "$report")"
    warn "$name: caption REJECTED ($(tail -1 <<< "$report"))"
    missing=$((missing + 1))
    continue
  fi
  if (( status != 0 )) || [[ ! -f "$dest" ]]; then
    row "$name.png" - no - FAILED "$mode" "$caption" "store-frame exit $status: $(tail -1 <<< "$report")"
    warn "$name: store-frame failed ($(tail -1 <<< "$report"))"
    missing=$((missing + 1))
    continue
  fi
  outinfo=$(png_info "$dest")
  outdims="${outinfo%% *}"
  alpha="${outinfo##*alpha=}"
  match=no
  is_slot "$outdims" && match=yes
  [[ "$match" == yes ]] || problems+=("output is $outdims, not a slot size")
  [[ "$alpha" == no ]] || problems+=("output alpha=$alpha (App Store Connect rejects alpha)")
  [[ "$report" == *"extent=mismatch"* ]] && problems+=("tabletop warp extent mismatch: eyeball the screen mapping")
  summary=$(grep -oE '(layout|cap|lines|rounded|warp)=[^ ]+' <<< "$report" | tr '\n' ' ' | sed 's/ $//')
  if (( ${#problems[@]} > 0 )); then
    if [[ "$dest" == "$STORE/$name.png" ]]; then mv -f "$dest" "$STORE/_flagged/$name.png"; fi
    joined=$(printf '%s; ' "${problems[@]}" ${notes[@]+"${notes[@]}"}); joined="${joined%; }"
    row "_flagged/$name.png" "$outdims" "$match" "$alpha" FLAGGED "$mode" "$caption" "$joined"
    warn "$name FLAGGED: $joined"
    flagged=$((flagged + 1))
  else
    joined=$(printf '%s; ' ${notes[@]+"${notes[@]}"} "$summary"); joined="${joined%; }"
    row "$name.png" "$outdims" "$match" "$alpha" OK "$mode" "$caption" "$joined"
    ok=$((ok + 1))
  fi
  note "    caption: $caption"
  facts=$(grep -oE "HUSH-T (freeze|skipped|canvas|event chestArrived|event chainUp|event bitten|event banked) .*" "$srclog" 2>/dev/null | sed 's/^HUSH-T //' | sort -u | head -6 | tr '\n' ';' | sed 's/;$//; s/;/; /g')
  [[ -n "$facts" ]] && note "    app log: $facts"
done 3< "$SCEN"

rm -rf "$WORK"
note ""
note "summary: ok $ok  flagged $flagged  missing $missing"
note "before upload (docs/appstore/screenshots.md): eyeball every frame. The checks read the app log, not the picture:"
note "the caption must be true of the frame, no stale hint text, nothing important in the crease band, no prices."

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  { echo "### $LABEL"; echo '```'; cat "$MANIFEST"; echo '```'; } >> "$GITHUB_STEP_SUMMARY" 2>/dev/null || true
fi
ls -la "$STORE" "$STORE/_flagged" 2>/dev/null || true
exit 0

#!/usr/bin/env bash
# Capture the raw frames of one App Store set, with retries (called by .github/workflows/store.yml). Adapted from
# Swoop's ci/store-capture.sh (proven on these runners), for Hush's portrait sets:
#
#   bash ci/store-capture.sh phone <out> <scenarios> <filter> "<expected sizes>"   # env DEVICE (ci/screenshots.sh syntax)
#   bash ci/store-capture.sh duo   <out> <scenarios> <filter> "<expected sizes>"   # env UDID (a booted iPhone Duo)
#
# phone: ci/screenshots.sh with SCENARIOS=<scenarios>, WAIT_FREEZE=1 → <out>/<name>.png, <out>/logs/<name>*.txt
# duo:   ci/duo.sh store pass (PASSES=store, STORE_LIST=<scenarios>) → <out>/store-<name>.png, <out>/logs/store-<name>*.txt
#        (each launch is tabletop: ci/duo.sh appends orient=portrait, so a MENU's inner capture is 2007 x 2853; a run
#        stays landscape, k=1, and ci/store-upright.sh turns its 2853 x 2007 capture upright after every pass, R11).
# After the first pass, every frame that is missing or not one of <expected sizes> (e.g. the Duo's cover display, or a
# book-pose landscape capture, was taken instead of the portrait inner one) is captured again, up to two more passes,
# each one only for those frames. Every pass has a timeout. Never fails: exits 0, and writes <out>/capture-report.txt
# (name, size, ok|missing|wrong-size).
set -uo pipefail

KIND="${1:?usage: store-capture.sh phone|duo <out> <scenarios> <filter> <expected sizes>}"
OUT="${2:?out dir}"
SCEN="${3:?scenario file}"
FILTER="${4:-.}"
EXPECT="${5:-}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$OUT/logs"

to() {
  local s="$1"; shift
  if command -v gtimeout >/dev/null 2>&1; then gtimeout -k 10 "$s" "$@"
  elif command -v timeout >/dev/null 2>&1; then timeout -k 10 "$s" "$@"
  else perl -e 'alarm shift; exec @ARGV or die "exec failed: $!\n"' "$s" "$@"; fi
}
dims() {
  local out w h
  out=$(to 20 sips -g pixelWidth -g pixelHeight "$1" 2>/dev/null || true)
  w=$(awk '/pixelWidth/ {print $2}' <<< "$out"); h=$(awk '/pixelHeight/ {print $2}' <<< "$out")
  if [[ -n "$w" && -n "$h" ]]; then echo "${w}x${h}"; else echo "?"; fi
}
names() {
  tr -d '\r' < "$SCEN" | grep -vE '^[[:space:]]*(#|$)' | cut -d'|' -f1 | grep -E -- "$FILTER" || true
}
raw_of() { if [[ "$KIND" == duo ]]; then echo "$OUT/store-$1.png"; else echo "$OUT/$1.png"; fi; }
# state <name>: ok | missing | wrong-size:<WxH>
state() {
  local f d
  f=$(raw_of "$1")
  [[ -f "$f" ]] || { echo missing; return; }
  [[ -z "$EXPECT" ]] && { echo ok; return; }
  d=$(dims "$f")
  if [[ " $EXPECT " == *" $d "* ]]; then echo ok; else echo "wrong-size:$d"; fi
}
pending() { local n; for n in $(names); do [[ "$(state "$n")" == ok ]] || echo "$n"; done; }

pass() {   # pass <name regex> <label>
  local re="$1" label="$2" count limit
  count=$(names | grep -cE -- "$re" || true)
  echo "== $KIND capture, $label: $count frame(s) ($re)"
  case "$KIND" in
    phone)
      limit=$(( 300 + count * 150 ))
      OUT="$OUT" SCENARIOS="$SCEN" SCENARIO_FILTER="$re" EXPECT_SIZE="$EXPECT" WAIT_FREEZE=1 \
        to "$limit" bash "$HERE/screenshots.sh" || echo "warning: ci/screenshots.sh exited $? ($label)"
      ;;
    duo)
      limit=$(( 300 + count * 150 ))
      OUT="$OUT" PASSES=store STORE_LIST="$SCEN" STORE_FILTER="$re" \
        to "$limit" bash "$HERE/duo.sh" || echo "warning: ci/duo.sh exited $? ($label)"
      ;;
    *) echo "unknown kind $KIND"; return 1 ;;
  esac
  # R11: a run screen can't turn portrait on the book-pose sim (the live run holds landscape; the app draws the
  # canvas with odd k), so its 2853 x 2007 capture is turned upright from the logged k (ci/store-upright.sh).
  [[ "$KIND" == duo ]] && bash "$HERE/store-upright.sh" "$OUT" store-
  return 0
}

if [[ ! -f "$SCEN" ]]; then echo "::warning::no scenario file $SCEN"; exit 0; fi
[[ -n "$(names)" ]] || { echo "::warning::no scenario in $SCEN matches $FILTER"; exit 0; }

pass "$FILTER" "first pass"
for attempt in 1 2; do
  left=$(pending)
  [[ -z "$left" ]] && break
  echo "retry $attempt for: $(tr '\n' ' ' <<< "$left")"
  [[ "$KIND" == phone ]] && { to 120 xcrun simctl shutdown all >/dev/null 2>&1 || true; }
  pass "^($(paste -s -d '|' - <<< "$left"))\$" "retry $attempt"
done

report="$OUT/capture-report.txt"
: > "$report"
bad=0
for n in $(names); do
  s=$(state "$n")
  f=$(raw_of "$n")
  printf '%-26s %-10s %s\n' "$n" "$([[ -f "$f" ]] && dims "$f" || echo -)" "$s" >> "$report"
  if [[ "$s" != ok ]]; then bad=$((bad + 1)); echo "::warning::$KIND capture: $n $s after retries"; fi
done
cat "$report"
echo "$KIND capture: $bad frame(s) still missing or wrong-sized (ci/store-set.sh lists them in MANIFEST.txt)"
exit 0

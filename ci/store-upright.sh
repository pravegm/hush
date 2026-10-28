#!/usr/bin/env bash
# R11 (store run 40668557600): turn the Duo's odd-k landscape captures upright, so they fill the 2007 x 2853 slot.
#
#   bash ci/store-upright.sh <dir> [raw prefix, default store-]
#
# Why: on the Duo simulator (book pose, landscape interface) `orient=portrait` only works on menus. A live run holds
# the interface it went live in (OrientationLock, R6/R8), so iOS refuses the portrait ask ("Supported: landscapeLeft"),
# and since R6 the app draws the same portrait canvas turned k quarter turns clockwise in the 951 x 669 window
# (`HUSH-T canvas 951x669 fold=1 turned=0 k=1`). The inner capture is then 2853 x 2007: the right picture, turned
# sideways (the fold is the vertical band in its middle). Undoing the logged turn (k=1: 270° clockwise, k=3: 90°)
# gives exactly the upright tabletop canvas: lid half on top, fold across the middle (y ≈ 1365–1482 px).
#
# Only a capture whose own app log (logs/<prefix><name>.at-capture.txt, else .txt) ends on a fold canvas with odd k
# and the capture's aspect is turned. Anything else is left alone (store-set.sh still flags it). Idempotent: a portrait
# capture is skipped, so it can run after every capture pass and again in the assemble job (duo_from_run reuse).
# The landscape original is kept as raw/<prefix><name>-landscape-k<k>.png; each turn is a line in <dir>/rotated.tsv
# (file, k, degrees cw, from, the canvas line), which store-set.sh reads to check the canvas as the upright one.
set -uo pipefail

DIR="${1:?usage: store-upright.sh <dir> [prefix]}"
PREFIX="${2-store-}"
[[ -d "$DIR" ]] || exit 0
REC="$DIR/rotated.tsv"
mkdir -p "$DIR/raw"

to() {
  local s="$1"; shift
  if command -v gtimeout >/dev/null 2>&1; then gtimeout -k 5 "$s" "$@"
  elif command -v timeout >/dev/null 2>&1; then timeout -k 5 "$s" "$@"
  else perl -e 'alarm shift; exec @ARGV or die "exec failed: $!\n"' "$s" "$@"; fi
}
dims() {
  local out w h
  out=$(to 20 sips -g pixelWidth -g pixelHeight "$1" 2>/dev/null || true)
  w=$(awk '/pixelWidth/ {print $2}' <<< "$out"); h=$(awk '/pixelHeight/ {print $2}' <<< "$out")
  if [[ -n "$w" && -n "$h" ]]; then echo "${w}x${h}"; else echo "?"; fi
}

shopt -s nullglob
for f in "$DIR/$PREFIX"*.png; do
  base=$(basename "$f" .png)
  [[ "$base" == *-landscape-k[0-9] ]] && continue
  d=$(dims "$f"); w="${d%x*}"; h="${d#*x}"
  [[ "$w" =~ ^[0-9]+$ && "$h" =~ ^[0-9]+$ ]] || continue
  (( w > h )) || continue
  log="$DIR/logs/$base.at-capture.txt"
  [[ -f "$log" ]] || log="$DIR/logs/$base.txt"
  c=$(grep -oE "HUSH-T canvas [0-9]+x[0-9]+.*" "$log" 2>/dev/null | tail -1 | tr -d '\r' | sed 's/^HUSH-T canvas //')
  k=$(grep -oE '(^| )k=[0-3]' <<< "$c" | head -1 | grep -oE '[0-3]$')
  cwh=$(grep -oE '^[0-9]+x[0-9]+' <<< "$c"); cw="${cwh%x*}"; ch="${cwh#*x}"
  if [[ -z "$k" || $(( k % 2 )) -ne 1 || "$c" != *"fold=1"* || ! "$cw" =~ ^[0-9]+$ || ! "$ch" =~ ^[0-9]+$ ]]; then
    echo "store-upright: $base is ${d} but its last canvas is '${c:-none}' (not a fold canvas with odd k): left as is"
    continue
  fi
  # The capture must be that window at some scale (2853 x 2007 = 951 x 669 at 3x).
  if (( cw <= ch || w * ch != h * cw )); then
    echo "store-upright: $base is ${d}, canvas '${c}' has another shape: left as is"
    continue
  fi
  deg=$(( k == 1 ? 270 : 90 ))
  keep="$DIR/raw/$base-landscape-k$k.png"
  cp -f "$f" "$keep"
  if ! to 60 sips -r "$deg" "$keep" --out "$f" >/dev/null 2>&1; then
    cp -f "$keep" "$f"; echo "store-upright: sips -r $deg failed on $base: left as is"; continue
  fi
  nd=$(dims "$f")
  if [[ "$nd" != "${h}x${w}" ]]; then
    cp -f "$keep" "$f"; echo "store-upright: $base turned to $nd, not ${h}x${w}: restored"; continue
  fi
  if [[ -f "$REC" ]]; then grep -v "^$base"$'\t' "$REC" > "$REC.tmp" || true; mv -f "$REC.tmp" "$REC"; fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$base" "$k" "$deg" "$d" "$c" >> "$REC"
  echo "store-upright: $base $d -> $nd (canvas '$c': drawn k=$k, turned ${deg}° cw; original raw/$(basename "$keep"))"
done
exit 0

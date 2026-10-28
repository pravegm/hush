#!/usr/bin/env bash
# R15: Hush's two optional App Store creative assets (iOS 27 App Store, Apple's "Prepare and submit your apps for
# iPhone Duo", 5 Oct 2026; App Store Connect Help, "Creative assets specifications"): the product page HEADER (21:9,
# 3840 x 1646) and the SEARCH RESULTS art (3:2, 3840 x 2560). Both are drawn by ci/store-frame.swift (`--banner`) from
# the Duo store pass's real D01 capture, as the same tabletop composite that is frame 1 of every screenshot set: only the
# app's pixels, warped onto a stylised iPhone Duo half open on a table. No hands, no price, no badge, no Apple logo.
#
#   bash ci/store-placements.sh <duo dir> <out dir>        # e.g. raw-duo store-placements (store.yml assemble job)
#
# <duo dir> is the folder ci/store-set.sh framed (store-<name>.png + logs/ + store/MANIFEST.txt). The hero is used only
# if it is clean: store-D01-hero-open.png is 2007 x 2853 (upright), its captioned frame passed every store-set check
# (<dir>/store/D01-hero-open.png exists, not _flagged/) and its log's last canvas is the folded inner one.
# Writes <out>/header-3840x1646.png, <out>/search-3840x2560.png (opaque sRGB PNG, no alpha) and <out>/MANIFEST.txt whose
# last line is `summary: ok <n>  problems <n>` (tools/appstore/asc.swift refuses a folder with problems), plus review
# thumbnails in <out>/review/ (the header at iPhone width, the search card at 365 pt). Upload only the two top files.
# Never fails the job: exits 0; every problem is a MANIFEST line and a ::warning::.
# Env: HERO (default D01-hero-open), TABLETOP_ANGLE (125), TABLETOP_ELEVATION (28), HEADER_CAPTION, SEARCH_CAPTION,
#      STORE_FRAME_BIN (the compiled compositor ci/store-set.sh left; compiled here if missing).
set -uo pipefail
DIR="${1:?usage: store-placements.sh <duo dir> <out dir>}"
OUT="${2:-store-placements}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/store-frame.swift"
CACHE="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
BIN="${STORE_FRAME_BIN:-${CACHE%/}/hush-store-frame}"
HERO="${HERO:-D01-hero-open}"
ANGLE="${TABLETOP_ANGLE:-125}"
ELEV="${TABLETOP_ELEVATION:-28}"
# The app's own words: the cover intro's headline (Hush/UI/PoseCards.swift CoverCard, R15c) and frame 1's caption.
# (Set apart from ${…:-…}: macOS bash 3.2 can't parse an apostrophe inside a quoted default, run 40782567781.)
if [[ -z "${HEADER_CAPTION:-}" ]]; then HEADER_CAPTION="*Hush* / Steal the mimic's gold while it sleeps."; fi
if [[ -z "${SEARCH_CAPTION:-}" ]]; then SEARCH_CAPTION="Open the chest. *Slowly.* / Steal the mimic's gold while it sleeps."; fi

mkdir -p "$OUT/review"
OUT="$(cd "$OUT" && pwd)"
rm -f "$OUT"/*.png "$OUT"/review/*.png
MANIFEST="$OUT/MANIFEST.txt"
: > "$MANIFEST"
to() {
  local s="$1"; shift
  if command -v gtimeout >/dev/null 2>&1; then gtimeout -k 5 "$s" "$@"
  elif command -v timeout >/dev/null 2>&1; then timeout -k 5 "$s" "$@"
  else perl -e 'alarm shift; exec @ARGV or die "exec failed: $!\n"' "$s" "$@"; fi
}
note() { echo "$*" | tee -a "$MANIFEST"; }
warn() { echo "::warning::store placements: $*"; }
finish() {
  note ""
  note "summary: ok $ok  problems $bad"
  note "before upload: eyeball both at full size and at review/ size, then in App Store Connect's product page preview"
  note "(crops differ by device). No prices, URLs, awards or badges."
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    { echo "### Store placements (header, search results)"; echo '```'; cat "$MANIFEST"; echo '```'; } >> "$GITHUB_STEP_SUMMARY" 2>/dev/null || true
  fi
  ls -la "$OUT" "$OUT/review" 2>/dev/null || true
  exit 0
}
png_info() {
  local out w h a
  out=$(to 20 sips -g pixelWidth -g pixelHeight -g hasAlpha "$1" 2>/dev/null || true)
  w=$(awk '/pixelWidth/ {print $2}' <<< "$out"); h=$(awk '/pixelHeight/ {print $2}' <<< "$out"); a=$(awk '/hasAlpha/ {print $2}' <<< "$out")
  if [[ -n "$w" && -n "$h" ]]; then echo "${w}x${h} alpha=${a:-?}"; else echo "? alpha=?"; fi
}

ok=0; bad=0
note "Hush App Store creative assets (product page header, search results)"
note "built: $(date -u '+%Y-%m-%d %H:%M UTC')  commit: ${GITHUB_SHA:-local}  run: ${GITHUB_RUN_ID:-local}"
note "upload: the two PNGs at the top of this folder only. review/ = thumbnails."
note ""

raw="$DIR/store-$HERO.png"
log="$DIR/logs/store-$HERO.at-capture.txt"; [[ -f "$log" ]] || log="$DIR/logs/store-$HERO.txt"
why=""
if [[ ! -f "$raw" ]]; then why="no capture store-$HERO.png in $DIR"
elif [[ "$(png_info "$raw" | cut -d' ' -f1)" != 2007x2853 ]]; then why="store-$HERO.png is $(png_info "$raw" | cut -d' ' -f1), not the upright Duo inner 2007x2853"
elif [[ ! -f "$DIR/store/$HERO.png" ]]; then why="its store frame is not clean (not in store/; see store/MANIFEST.txt)"
elif ! grep -qE "HUSH-T canvas (669x951|951x669) fold=1" "$log" 2>/dev/null; then why="its log has no folded inner canvas"
fi
if [[ -n "$why" ]]; then
  note "header-3840x1646.png  FAILED  no clean hero: $why"
  note "search-3840x2560.png  FAILED  no clean hero: $why"
  warn "no clean hero: $why"; bad=2; finish
fi
note "hero: store-$HERO.png (the Duo inner capture behind frame 1), tabletop at ${ANGLE}°"

if [[ ! -x "$BIN" || "$SRC" -nt "$BIN" ]]; then
  if ! to 600 xcrun swiftc -O -swift-version 5 -module-name StoreFrame "$SRC" -o "$BIN" > "$OUT/review/store-frame-build.log" 2>&1; then
    warn "could not compile ci/store-frame.swift; falling back to xcrun swift"; BIN=""
  fi
fi
render() { if [[ -n "$BIN" ]]; then to 300 "$BIN" "$@"; else to 900 xcrun swift "$SRC" "$@"; fi; }

one() {   # one <file> <WxH> <kind> <caption>
  local file="$1" want="$2" kind="$3" caption="$4" report status info dims alpha problems=()
  report=$(render --in "$raw" --out "$OUT/$file" --size "$want" --tabletop --angle "$ANGLE" --elevation "$ELEV" \
    --banner "$kind" --caption "$caption" 2>&1); status=$?
  if (( status != 0 )) || [[ ! -f "$OUT/$file" ]]; then
    note "$(printf '%-24s %-10s %-6s %-7s %s' "$file" - - FAILED "store-frame exit $status: $(tail -2 <<< "$report" | tr '\n' ' ')")"
    warn "$file: store-frame failed"; bad=$((bad + 1)); return
  fi
  info=$(png_info "$OUT/$file"); dims="${info%% *}"; alpha="${info##*alpha=}"
  [[ "$dims" == "$want" ]] || problems+=("is $dims, not $want")
  [[ "$alpha" == no ]] || problems+=("alpha=$alpha (App Store Connect rejects alpha)")
  grep -q "extent=ok" <<< "$report" || problems+=("tabletop warp extent mismatch: eyeball the screen mapping")
  if (( ${#problems[@]} > 0 )); then
    local j; j=$(printf '%s; ' "${problems[@]}"); j="${j%; }"
    note "$(printf '%-24s %-10s %-6s %-7s %s' "$file" "$dims" "$alpha" FLAGGED "$j")"; warn "$file FLAGGED: $j"; bad=$((bad + 1))
  else
    note "$(printf '%-24s %-10s %-6s %-7s %s' "$file" "$dims" "$alpha" OK "$(du -k "$OUT/$file" | cut -f1) KB")"; ok=$((ok + 1))
  fi
  note "    caption: $caption"
  note "    $(grep -m1 '^store-frame:' <<< "$report" | sed "s#$OUT/##")"
}

one header-3840x1646.png 3840x1646 header "$HEADER_CAPTION"
one search-3840x2560.png 3840x2560 search "$SEARCH_CAPTION"

thumb() { [[ -f "$1" ]] && to 30 sips --resampleWidth "$2" "$1" --out "$3" > /dev/null 2>&1; }
thumb "$OUT/header-3840x1646.png" 1206 "$OUT/review/header-402pt@3x.png"
thumb "$OUT/search-3840x2560.png" 1095 "$OUT/review/search-365pt@3x.png"
finish

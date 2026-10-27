#!/usr/bin/env bash
# App Store icon guard (design/ROUND-2.md "Everyone: QA-1", CI line; QA-1 P0-1). Called by testflight.yml (fatal) and
# ci.yml (WARN_ONLY=1). Checks Hush/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png:
#   1. it is not the R1 placeholder: SHA-256 of `git show d969f22:<icon>` (a flat gold rectangle on teal, 5,343 bytes),
#      computed with Node's crypto on 27 Oct and hardcoded below;
#   2. it is 1024 x 1024 (sips);
#   3. it is a real picture: >= MIN_COLOURS distinct colours (5 bits per channel) on a 64 x 64 sips downsample. A flat
#      placeholder has ~2 (the R1 one: 2; the rendered R2 icon: 115 at nearest-neighbour). Pixel VARIANCE is no use
#      here: the two-colour placeholder has a higher luma spread (52) than the real icon (35).
#   4. it has no alpha channel (App Store Connect refuses a 1024 icon with one: ITMS-90717). The committed R2 render is
#      RGBA, fully opaque. With FIX_ALPHA=1 the file is flattened IN THE WORKSPACE (never committed) before the archive,
#      losslessly through ImageIO (xcrun swift), else through a best-quality JPEG round trip; otherwise a warning.
# Exit 1 when 1–3 fail (or 4 can't be fixed with FIX_ALPHA=1), unless WARN_ONLY=1 (then warnings, exit 0).
set -uo pipefail

ICON="${1:-Hush/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png}"
PLACEHOLDER_SHA256="a29bfd3dc05dacdf9a148b7b61725d972764d78e456c5fdf79c9302903a5ee70"
MIN_COLOURS="${MIN_COLOURS:-40}"
FIX_ALPHA="${FIX_ALPHA:-0}"
WARN_ONLY="${WARN_ONLY:-0}"
TMP="${RUNNER_TEMP:-/tmp}/icon-check.$$"
mkdir -p "$TMP"
problems=0

bad() {   # bad <message>: an ::error:: (or a ::warning:: with WARN_ONLY=1)
  if [[ "$WARN_ONLY" == 1 ]]; then echo "::warning::app icon: $1"; else echo "::error::app icon: $1"; fi
  problems=$((problems + 1))
}
summary() { [[ -n "${GITHUB_STEP_SUMMARY:-}" ]] && echo "$1" >> "$GITHUB_STEP_SUMMARY"; return 0; }

if [[ ! -f "$ICON" ]]; then
  bad "$ICON is missing"
  summary "App icon check: **$ICON is missing**."
  [[ "$WARN_ONLY" == 1 ]] && exit 0 || exit 1
fi

sha=$(shasum -a 256 "$ICON" | awk '{print $1}')
bytes=$(wc -c < "$ICON" | tr -d ' ')
[[ "$sha" == "$PLACEHOLDER_SHA256" ]] && bad "$ICON is still the R1 placeholder (sha256 $sha). Commit the rendered icon (ci.yml artifact screenshots/app-icon-1024.png)."

w=$(sips -g pixelWidth "$ICON" 2>/dev/null | awk '/pixelWidth/ {print $2}')
h=$(sips -g pixelHeight "$ICON" 2>/dev/null | awk '/pixelHeight/ {print $2}')
[[ "$w" == 1024 && "$h" == 1024 ]] || bad "$ICON is ${w:-?} x ${h:-?}, not 1024 x 1024"

colours=-1
if sips -z 64 64 -s format bmp "$ICON" --out "$TMP/s.bmp" >/dev/null 2>&1; then
  colours=$(python3 -I - "$TMP/s.bmp" <<'PY' 2>/dev/null || echo -1
import struct, sys
b = open(sys.argv[1], "rb").read()
off = struct.unpack_from("<I", b, 10)[0]; w, h = struct.unpack_from("<ii", b, 18); bpp = struct.unpack_from("<H", b, 28)[0]
step = bpp // 8; row = (w * step + 3) & ~3; seen = set()
for y in range(abs(h)):
    for x in range(w):
        p = off + y * row + x * step
        seen.add((b[p] >> 3, b[p + 1] >> 3, b[p + 2] >> 3))
print(len(seen))
PY
)
fi
if [[ "$colours" =~ ^[0-9]+$ ]] && (( colours >= 0 )); then
  (( colours < MIN_COLOURS )) && bad "$ICON has only $colours distinct colours on a 64 x 64 sample (< $MIN_COLOURS): a flat placeholder, not the rendered icon"
else
  echo "::warning::app icon: could not count colours (sips/python3); relying on the hash and size checks"
fi

alpha=$(sips -g hasAlpha "$ICON" 2>/dev/null | awk '/hasAlpha/ {print $2}')
fixed=""
if [[ "$alpha" == yes ]]; then
  if [[ "$FIX_ALPHA" == 1 ]]; then
    cat > "$TMP/flatten.swift" <<'SWIFT'
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
// flatten <in.png> <out.png>: redraw onto an opaque RGB context (no alpha channel), lossless PNG out.
let a = CommandLine.arguments
guard a.count == 3,
      let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: a[1]) as CFURL, nil),
      let img = CGImageSourceCreateImageAtIndex(src, 0, nil),
      let ctx = CGContext(data: nil, width: img.width, height: img.height, bitsPerComponent: 8, bytesPerRow: 0,
                          space: img.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { exit(2) }
ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: img.width, height: img.height))
ctx.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
guard let out = ctx.makeImage(),
      let dst = CGImageDestinationCreateWithURL(URL(fileURLWithPath: a[2]) as CFURL, UTType.png.identifier as CFString, 1, nil)
else { exit(3) }
CGImageDestinationAddImage(dst, out, nil)
exit(CGImageDestinationFinalize(dst) ? 0 : 4)
SWIFT
    if xcrun swift "$TMP/flatten.swift" "$ICON" "$TMP/flat.png" >/dev/null 2>"$TMP/swift.err" \
       && [[ "$(sips -g hasAlpha "$TMP/flat.png" 2>/dev/null | awk '/hasAlpha/ {print $2}')" == no ]]; then
      cp "$TMP/flat.png" "$ICON"; fixed="flattened losslessly (ImageIO)"
    elif sips -s format jpeg -s formatOptions best "$ICON" --out "$TMP/flat.jpg" >/dev/null 2>&1 \
         && sips -s format png "$TMP/flat.jpg" --out "$TMP/flat2.png" >/dev/null 2>&1 \
         && [[ "$(sips -g hasAlpha "$TMP/flat2.png" 2>/dev/null | awk '/hasAlpha/ {print $2}')" == no ]]; then
      cp "$TMP/flat2.png" "$ICON"; fixed="flattened through a best-quality JPEG (ImageIO failed: $(head -c 200 "$TMP/swift.err" | tr '\n' ' '))"
    else
      bad "$ICON has an alpha channel and could not be flattened (App Store Connect would refuse it: ITMS-90717)"
    fi
    if [[ -n "$fixed" ]]; then
      echo "::warning::app icon had an alpha channel; $fixed for this build only. Commit an RGB (no alpha) AppIcon-1024.png."
      alpha="no ($fixed in the workspace)"
    fi
  else
    echo "::warning::app icon: $ICON has an alpha channel (fully opaque or not, App Store Connect refuses it: ITMS-90717). testflight.yml flattens it for its own build; commit an RGB PNG."
  fi
fi

line="App icon check: \`$ICON\` ${w:-?}x${h:-?}, $bytes bytes, sha256 \`${sha:0:12}…\`, $colours colours (64 px sample), hasAlpha=$alpha: $([[ $problems == 0 ]] && echo OK || echo "**$problems problem(s)**")."
echo "$line"
summary "$line"
rm -rf "$TMP"
if (( problems > 0 )) && [[ "$WARN_ONLY" != 1 ]]; then exit 1; fi
exit 0

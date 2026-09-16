#!/bin/bash
set -euo pipefail
STAR_MEMO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAR_MEMO_PLIST="$STAR_MEMO_ROOT/Sources/StarMemoUI/Resources/Info.plist"
STAR_MEMO_RESOURCES="$STAR_MEMO_ROOT/Sources/StarMemoUI/Resources"
if [[ $# -gt 0 ]]; then
    STAR_MEMO_PLIST="$1/Contents/Info.plist"
    STAR_MEMO_RESOURCES="$1/Contents/Resources"
fi
STAR_MEMO_ICON=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$STAR_MEMO_PLIST")
test "$STAR_MEMO_ICON" = 'StarMemo.icns'
test -s "$STAR_MEMO_RESOURCES/$STAR_MEMO_ICON"
STAR_MEMO_CHECK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/starmemo-icon-check.XXXXXX")
iconutil -c iconset "$STAR_MEMO_RESOURCES/$STAR_MEMO_ICON" -o "$STAR_MEMO_CHECK_DIR/StarMemo.iconset"
for size in 16 32 128 256 512; do
    for scale in 1 2; do
        suffix=''
        if [[ "$scale" = 2 ]]; then suffix='@2x'; fi
        icon="$STAR_MEMO_CHECK_DIR/StarMemo.iconset/icon_${size}x${size}${suffix}.png"
        test -s "$icon"
        actual=$(sips -g pixelWidth "$icon" | awk '/pixelWidth:/ {print $2}')
        test "$actual" = "$((size * scale))"
    done
done
printf 'PASS: app icon declaration and all 10 icon representations\n'

#!/bin/bash
set -euo pipefail
STAR_MEMO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAR_MEMO_SOURCE="$STAR_MEMO_ROOT/docs/assets/starmemo-icon.png"
mkdir -p "$STAR_MEMO_ROOT/.build"
STAR_MEMO_ICON_DIR=$(mktemp -d "$STAR_MEMO_ROOT/.build/app-icon.XXXXXX")
STAR_MEMO_ICONSET="$STAR_MEMO_ICON_DIR/StarMemo.iconset"
mkdir -p "$STAR_MEMO_ICONSET"
for size in 16 32 128 256 512; do
    for scale in 1 2; do
        suffix=''
        if [[ "$scale" = 2 ]]; then suffix='@2x'; fi
        sips -z "$((size * scale))" "$((size * scale))" "$STAR_MEMO_SOURCE" \
            --out "$STAR_MEMO_ICONSET/icon_${size}x${size}${suffix}.png" >/dev/null
    done
done
iconutil -c icns "$STAR_MEMO_ICONSET" \
    -o "$STAR_MEMO_ROOT/Sources/StarMemoUI/Resources/StarMemo.icns"
printf 'Built StarMemo.icns from the approved PNG\n'

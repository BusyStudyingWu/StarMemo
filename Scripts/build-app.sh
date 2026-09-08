#!/bin/bash
set -euo pipefail

STAR_MEMO_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STAR_MEMO_ROOT="$(dirname "$STAR_MEMO_SCRIPT_DIR")"
cd "$STAR_MEMO_ROOT"

if [[ -z "${SDKROOT:-}" && -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
    export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
fi

export CLANG_MODULE_CACHE_PATH="$STAR_MEMO_ROOT/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$STAR_MEMO_ROOT/.build/swiftpm-module-cache"

swift build -c release --product StarMemo

STAR_MEMO_APP="$STAR_MEMO_ROOT/dist/StarMemo.app"
mkdir -p "$STAR_MEMO_APP/Contents/MacOS" "$STAR_MEMO_APP/Contents/Resources"
cp "$STAR_MEMO_ROOT/.build/release/StarMemo" "$STAR_MEMO_APP/Contents/MacOS/StarMemo"
cp "$STAR_MEMO_ROOT/Sources/StarMemoUI/Resources/Info.plist" "$STAR_MEMO_APP/Contents/Info.plist"
STAR_MEMO_LICENSE_DIR="$STAR_MEMO_APP/Contents/Resources/ThirdPartyLicenses"
mkdir -p "$STAR_MEMO_LICENSE_DIR"
cp "$STAR_MEMO_ROOT/ThirdPartyLicenses/swift-markdown-engine-LICENSE" \
   "$STAR_MEMO_LICENSE_DIR/swift-markdown-engine-LICENSE"
chmod +x "$STAR_MEMO_APP/Contents/MacOS/StarMemo"

plutil -lint "$STAR_MEMO_APP/Contents/Info.plist"
test -x "$STAR_MEMO_APP/Contents/MacOS/StarMemo"
test -s "$STAR_MEMO_LICENSE_DIR/swift-markdown-engine-LICENSE"

printf 'Built %s\n' "$STAR_MEMO_APP"

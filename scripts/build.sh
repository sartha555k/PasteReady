#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p .build/cache/clang .build/cache/swiftpm build
export CLANG_MODULE_CACHE_PATH="$PWD/.build/cache/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/cache/clang"
swift build -c release --triple arm64-apple-macosx14.0 --disable-sandbox --cache-path "$PWD/.build/cache/swiftpm"
swift build -c release --triple x86_64-apple-macosx14.0 --disable-sandbox --cache-path "$PWD/.build/cache/swiftpm"
# Sign outside iCloud/Desktop file-provider metadata, which codesign rejects.
STAGING=$(mktemp -d /private/tmp/notchlinks-build.XXXXXX)
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/PasteReady.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create .build/arm64-apple-macosx/release/NotchLinks .build/x86_64-apple-macosx/release/NotchLinks -output "$APP/Contents/MacOS/NotchLinks"
cp scripts/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
ditto --norsrc -c -k --keepParent "$APP" "$PWD/build/PasteReady.zip"
# Replace the generated bundle rather than merge stale Finder metadata.
rm -rf "$PWD/build/PasteReady.app"
ditto --norsrc "$APP" "$PWD/build/PasteReady.app"
print "Built $PWD/build/PasteReady.app and build/PasteReady.zip"

# Keep archive links shared before the rename current.
cp "$PWD/build/PasteReady.zip" "$PWD/build/NotchLinks.zip"

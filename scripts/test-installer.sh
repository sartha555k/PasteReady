#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
[ -f build/PasteReady.zip ] || { printf 'Build the app first.\n' >&2; exit 1; }
fixture=$(mktemp -d "${TMPDIR:-/tmp}/pasteready-installer-test.XXXXXX")
trap 'rm -rf "$fixture"' EXIT HUP INT TERM
archive="$PWD/build/PasteReady.zip"
checksum=$(/usr/bin/shasum -a 256 "$archive" | cut -d ' ' -f1)
apps="$fixture/Applications with spaces"
run() { sh distribution/install.sh --archive "$archive" --sha256 "$checksum" --install-dir "$apps" --no-launch; }

run > "$fixture/output"
[ -x "$apps/PasteReady.app/Contents/MacOS/NotchLinks" ]
/usr/bin/codesign --verify --deep --strict "$apps/PasteReady.app"
printf 'PASS: fresh installation into a path containing spaces\n'

touch "$fixture/preserved-data"
touch "$apps/PasteReady.app/Contents/Resources/previous-marker"
run > "$fixture/output"
[ -f "$fixture/preserved-data" ]
[ ! -e "$apps/PasteReady.app/Contents/Resources/previous-marker" ]
/usr/bin/codesign --verify --deep --strict "$apps/PasteReady.app"
printf 'PASS: repeat installation replaces only the app\n'

before=$(/usr/bin/shasum -a 256 "$apps/PasteReady.app/Contents/MacOS/NotchLinks")
if sh distribution/install.sh --archive "$archive" --sha256 "$(printf '%064d' 0)" --install-dir "$apps" --no-launch > "$fixture/output" 2>&1; then
    printf 'FAIL: corrupt checksum was accepted\n' >&2; exit 1
fi
[ "$before" = "$(/usr/bin/shasum -a 256 "$apps/PasteReady.app/Contents/MacOS/NotchLinks")" ]
printf 'PASS: checksum mismatch leaves the installed app untouched\n'

mkdir -p "$fixture/Unexpected.app"
touch "$fixture/Unexpected.app/file"
/usr/bin/ditto -c -k --keepParent "$fixture/Unexpected.app" "$fixture/wrong.zip"
wrong_checksum=$(/usr/bin/shasum -a 256 "$fixture/wrong.zip" | cut -d ' ' -f1)
if sh distribution/install.sh --archive "$fixture/wrong.zip" --sha256 "$wrong_checksum" --install-dir "$apps" --no-launch > "$fixture/output" 2>&1; then
    printf 'FAIL: unexpected archive contents were accepted\n' >&2; exit 1
fi
[ "$before" = "$(/usr/bin/shasum -a 256 "$apps/PasteReady.app/Contents/MacOS/NotchLinks")" ]
printf 'PASS: unrelated archive contents are rejected\n'

/usr/bin/plutil -replace CFBundleIdentifier -string com.example.unrelated "$apps/PasteReady.app/Contents/Info.plist"
if run > "$fixture/output" 2>&1; then
    printf 'FAIL: unrelated destination was replaced\n' >&2; exit 1
fi
[ "$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$apps/PasteReady.app/Contents/Info.plist")" = com.example.unrelated ]
printf 'PASS: unrelated existing app cannot be overwritten\n'

if sh distribution/install.sh --repo '../invalid' --install-dir "$apps" --no-launch > "$fixture/output" 2>&1; then
    printf 'FAIL: invalid repository was accepted\n' >&2; exit 1
fi
printf 'PASS: invalid repository is rejected before downloading\n'

./scripts/prepare-release.sh sample-owner/pasteready "$fixture/release" > "$fixture/output"
sh -n "$fixture/release/install.sh"
(cd "$fixture/release" && /usr/bin/shasum -a 256 -c PasteReady.zip.sha256) > "$fixture/output"
/usr/bin/grep -Fq 'PASTEREADY_REPOSITORY:-sample-owner/pasteready' "$fixture/release/install.sh"
/usr/bin/grep -Fq 'https://github.com/sample-owner/pasteready/releases/latest/download/install.sh' "$fixture/release/RELEASE.md"
printf 'PASS: release preparation embeds the repository and matching checksum\n'
printf 'All 7 installer checks passed. No app was launched or installed outside temporary folders.\n'

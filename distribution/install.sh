#!/bin/sh
# PasteReady installer. Prepared release copies embed the hosting repository.
set -eu

repository=${PASTEREADY_REPOSITORY:-__PASTEREADY_REPOSITORY__}
version=latest
install_dir=${PASTEREADY_INSTALL_DIR:-"$HOME/Applications"}
archive=
expected_sha=
launch=1
workspace=
transaction=
destination=

fail() { printf 'PasteReady: %s\n' "$*" >&2; exit 1; }
usage() {
    cat <<'HELP'
Install PasteReady on macOS 14 or later (Apple Silicon and Intel).
  --repo OWNER/REPO      GitHub release repository
  --version TAG          Install a specific release (default: latest)
  --install-dir PATH     Destination folder (default: ~/Applications)
  --archive PATH         Install a local release ZIP instead of downloading
  --sha256 HASH          Required checksum when using --archive
  --no-launch           Install without opening the app
  --help                Show this help
HELP
}
cleanup() {
    result=$?
    trap - EXIT HUP INT TERM
    if [ -n "$transaction" ] && [ -d "$transaction" ]; then
        if [ ! -e "$destination" ] && [ -d "$transaction/previous.app" ]; then
            mv "$transaction/previous.app" "$destination" || printf 'Restore the previous app from %s\n' "$transaction/previous.app" >&2
        fi
        # Never remove the only recoverable copy after a failed restore.
        if [ -e "$destination" ] || [ ! -d "$transaction/previous.app" ]; then rm -rf "$transaction"; fi
    fi
    if [ -n "$workspace" ]; then rm -rf "$workspace"; fi
    exit "$result"
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM

while [ "$#" -gt 0 ]; do
    case "$1" in
        --repo|--version|--install-dir|--archive|--sha256)
            [ "$#" -ge 2 ] || fail "Missing value for $1"
            case "$1" in
                --repo) repository=$2 ;;
                --version) version=$2 ;;
                --install-dir) install_dir=$2 ;;
                --archive) archive=$2 ;;
                --sha256) expected_sha=$2 ;;
            esac
            shift 2 ;;
        --no-launch) launch=0; shift ;;
        --help|-h) usage; exit 0 ;;
        *) fail "Unknown option: $1" ;;
    esac
done

[ "$(uname -s)" = Darwin ] || fail 'This app requires macOS.'
case "$(uname -m)" in arm64|x86_64) ;; *) fail 'Unsupported Mac architecture.' ;; esac
major=$(/usr/bin/sw_vers -productVersion | cut -d. -f1)
[ "$major" -ge 14 ] || fail 'macOS 14 or later is required.'
case "$install_dir" in /*) ;; *) fail '--install-dir must be an absolute path.' ;; esac
workspace=$(mktemp -d "${TMPDIR:-/tmp}/pasteready-download.XXXXXX")

fetch() {
    /usr/bin/curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
        --connect-timeout 15 --max-time 300 --retry 2 --output "$2" "$1"
}
if [ -n "$archive" ]; then
    [ -f "$archive" ] || fail 'The local release ZIP does not exist.'
    [ -n "$expected_sha" ] || fail '--archive requires --sha256.'
    cp "$archive" "$workspace/PasteReady.zip"
else
    [ "$repository" != __PASTEREADY_REPOSITORY__ ] || fail 'Hosting is not configured. Use a prepared release installer or --repo OWNER/REPO.'
    case "$repository" in *[!A-Za-z0-9._/-]*|/*|*/|*../*) fail 'Invalid GitHub repository.' ;; esac
    owner=${repository%%/*}
    repo=${repository#*/}
    [ "$owner" != "$repository" ] && [ -n "$owner" ] && [ -n "$repo" ] || fail 'Repository must be OWNER/REPO.'
    case "$owner" in .|..) fail 'Invalid repository owner.' ;; esac
    case "$repo" in .|..|*/*) fail 'Repository must be OWNER/REPO.' ;; esac
    if [ "$version" = latest ]; then
        fetch "https://api.github.com/repos/$repository/releases/latest" "$workspace/release.json"
        version=$(/usr/bin/plutil -extract tag_name raw -o - "$workspace/release.json") || fail 'Could not read the latest release tag.'
    fi
    case "$version" in ''|*[!A-Za-z0-9._-]*|.|..) fail 'Invalid release tag.' ;; esac
    base="https://github.com/$repository/releases/download/$version"
    printf 'Downloading PasteReady %s…\n' "$version"
    fetch "$base/PasteReady.zip" "$workspace/PasteReady.zip"
    fetch "$base/PasteReady.zip.sha256" "$workspace/checksum"
    read -r expected_sha ignored < "$workspace/checksum" || [ -n "$expected_sha" ]
fi
case "$expected_sha" in ''|*[!0-9a-fA-F]*) fail 'Invalid SHA-256 checksum.' ;; esac
[ "${#expected_sha}" -eq 64 ] || fail 'Invalid SHA-256 checksum length.'
expected_sha=$(printf '%s' "$expected_sha" | tr 'A-F' 'a-f')
actual_sha=$(/usr/bin/shasum -a 256 "$workspace/PasteReady.zip" | cut -d ' ' -f1)
[ "$actual_sha" = "$expected_sha" ] || fail 'Download checksum mismatch; nothing was installed.'

# Validate archive paths before extracting anything.
/usr/bin/unzip -Z1 "$workspace/PasteReady.zip" > "$workspace/entries"
[ -s "$workspace/entries" ] || fail 'Empty release ZIP.'
while IFS= read -r entry; do
    case "$entry" in
        /*|..|../*|*/../*|*/..|*\\*) fail 'Unsafe path in release ZIP.' ;;
        PasteReady.app|PasteReady.app/*) ;;
        *) fail 'Unexpected content in release ZIP.' ;;
    esac
done < "$workspace/entries"
/usr/bin/ditto -x -k "$workspace/PasteReady.zip" "$workspace/extracted"
app="$workspace/extracted/PasteReady.app"
[ -d "$app" ] && [ ! -L "$app" ] || fail 'Release does not contain PasteReady.app.'
# This app has no symlinked frameworks; reject links rather than follow one out of the bundle.
[ -z "$(find "$app" -type l -print -quit)" ] || fail 'Unexpected symlink in app bundle.'
identifier=$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$app/Contents/Info.plist")
[ "$identifier" = com.sarthak.notchlinks ] || fail 'Unexpected app identity.'
/usr/bin/codesign --verify --deep --strict "$app" || fail 'App signature validation failed.'
app_version=$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$app/Contents/Info.plist")

mkdir -p "$install_dir" || fail 'Cannot create the install folder. Choose a writable --install-dir.'
[ -w "$install_dir" ] || fail 'Install folder is not writable. Use your user Applications folder.'
destination="$install_dir/PasteReady.app"
if [ -e "$destination" ] || [ -L "$destination" ]; then
    [ -d "$destination" ] && [ ! -L "$destination" ] || fail 'Install destination is not a regular app bundle.'
    old_identifier=$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$destination/Contents/Info.plist" 2>/dev/null) || fail 'Cannot identify the existing destination.'
    [ "$old_identifier" = "$identifier" ] || fail 'Refusing to replace an unrelated application.'
fi
transaction=$(mktemp -d "$install_dir/.pasteready-install.XXXXXX")
/usr/bin/ditto --norsrc "$app" "$transaction/new.app"
/usr/bin/codesign --verify --deep --strict "$transaction/new.app" || fail 'Staged app signature validation failed.'

# Quit only a running executable at this exact installation path.
for pid in $(/usr/bin/pgrep -x NotchLinks 2>/dev/null || true); do
    executable=$(/bin/ps -p "$pid" -o comm= 2>/dev/null || true)
    if [ "$executable" = "$destination/Contents/MacOS/NotchLinks" ]; then
        kill -TERM "$pid" || fail 'Could not quit the existing app.'
        attempts=0
        while kill -0 "$pid" 2>/dev/null; do
            attempts=$((attempts + 1))
            [ "$attempts" -lt 30 ] || fail 'Quit PasteReady, then run the installer again.'
            sleep 0.1
        done
    fi
done
if [ -d "$destination" ]; then mv "$destination" "$transaction/previous.app"; fi
mv "$transaction/new.app" "$destination"
printf 'Installed PasteReady %s at %s\n' "$app_version" "$destination"
printf 'Your saved clipboard history and pins are preserved.\n'
if [ "$launch" -eq 1 ]; then
    /usr/bin/open "$destination" || printf 'Open PasteReady from your Applications folder.\n'
fi

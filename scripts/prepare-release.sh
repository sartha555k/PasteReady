#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
repository=${1:-}
output=${2:-build/release}
case "$repository" in ''|*[!A-Za-z0-9._/-]*|/*|*/|*../*) printf 'Usage: %s OWNER/REPO [OUTPUT_DIRECTORY]\n' "$0" >&2; exit 1 ;; esac
owner=${repository%%/*}
repo=${repository#*/}
[ "$owner" != "$repository" ] && [ -n "$repo" ] || { printf 'Repository must be OWNER/REPO.\n' >&2; exit 1; }
case "$owner" in .|..) printf 'Invalid repository owner.\n' >&2; exit 1 ;; esac
case "$repo" in .|..|*/*) printf 'Repository must be OWNER/REPO.\n' >&2; exit 1 ;; esac
[ -f build/PasteReady.zip ] || { printf 'Run ./scripts/build.sh first.\n' >&2; exit 1; }
mkdir -p "$output"
cp build/PasteReady.zip "$output/PasteReady.zip"
python3 - "$repository" "$output" <<'PY'
from pathlib import Path
import sys
source = Path('distribution/install.sh').read_text()
source = source.replace('${PASTEREADY_REPOSITORY:-__PASTEREADY_REPOSITORY__}', '${PASTEREADY_REPOSITORY:-' + sys.argv[1] + '}')
(Path(sys.argv[2]) / 'install.sh').write_text(source)
PY
chmod +x "$output/install.sh"
(cd "$output" && /usr/bin/shasum -a 256 PasteReady.zip > PasteReady.zip.sha256)
version=$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - scripts/Info.plist)
cat > "$output/RELEASE.md" <<NOTES
# PasteReady $version

Upload install.sh, PasteReady.zip and PasteReady.zip.sha256 to a GitHub Release tagged v$version in $repository.

Once published, the installation command is:

\`\`\`sh
curl -fsSL --proto '=https' --proto-redir '=https' https://github.com/$repository/releases/latest/download/install.sh | sh
\`\`\`

The installer defaults to ~/Applications, verifies the release checksum and bundle signature, and preserves clipboard history and pins.
The current app build is locally signed. Public Developer ID signing and notarization are a separate release setup step; the installer does not disable or bypass Gatekeeper.
NOTES
printf 'Prepared release files in %s for %s (v%s). Nothing has been published.\n' "$output" "$repository" "$version"

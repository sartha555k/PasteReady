# Terminal installation

`curl` downloads files from a URL. PasteReady remains a native Mac app; the installer uses curl to download its release ZIP, verify it, and install it without a manual extraction step.

## Status

The installer and release preparation are implemented and locally tested. The hosting repository is `sartha555k/PasteReady`. The first public release must finish before the one-command URL is usable. Subsequent matching version tags are built and published by `.github/workflows/release.yml`.

## Prepare a release

After building the app, supply the actual repository:

```sh
./scripts/build.sh
./scripts/prepare-release.sh sartha555k/PasteReady
```

The script embeds this repository into the release installer.

Upload the three files under `build/release` to a GitHub Release matching the version in `scripts/Info.plist`:

- `install.sh`
- `PasteReady.zip`
- `PasteReady.zip.sha256`

`build/release/RELEASE.md` contains the exact installation command for the repository you supplied. It becomes usable after those assets are published.

## Installer behavior

- Requires macOS 14+ and an Apple Silicon or Intel Mac.
- Installs to `~/Applications/PasteReady.app` by default, without sudo.
- Supports `--install-dir /Applications` when that folder is writable.
- Resolves a concrete release tag before downloading the ZIP and its checksum.
- Uses HTTPS, rejects failed downloads and checksum mismatches, checks archive paths, app identity and bundle signature.
- Stages the replacement before touching an existing installation and keeps a backup until replacement succeeds.
- Stops a running executable only at the exact destination being replaced.
- Never changes clipboard history, pins, preferences or macOS security settings.
- Opens the app after installation; `--no-launch` skips opening it.
- Does not grant Accessibility permission. Users enable that in macOS themselves.

An older development copy at a different location is not stopped or removed. Quit that copy before launching an installation in Applications to avoid duplicate clipboard utilities. Keep Launch at login configured for the permanent app location.

## Local checks

```sh
./scripts/test-installer.sh
```

The checks use the real release archive and temporary install folders, including paths containing spaces. No app is launched or installed in your real Applications folders.

A local archive may also be installed explicitly:

```sh
sh distribution/install.sh --archive /absolute/path/PasteReady.zip --sha256 ACTUAL_SHA256 --no-launch
```

The checksum is mandatory for local archives. Replace `ACTUAL_SHA256` with the release's actual SHA-256 value.

## Release signing

Current builds use local ad-hoc signing. The installer verifies bundle integrity; this does not establish Developer ID publisher identity. Public Developer ID signing and Apple notarization need a separate release setup with the owner's Apple Developer credentials. The installer does not remove quarantine or disable Gatekeeper. Checksums fetched from the release protect download integrity, not against compromise of the release account.

References: [curl manual](https://curl.se/docs/manpage.html), [GitHub release download links](https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases).

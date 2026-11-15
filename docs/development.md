# Development

Run the commands below from the repository root.

## Build

Requires macOS 14 or later and Swift 5.9+ / Command Line Tools to build. The packaged app is universal: Apple Silicon (arm64) and Intel (x86_64). There are no external dependencies.

```sh
./scripts/build.sh
```

The script creates `build/PasteReady.app` and `build/PasteReady.zip`, signing the app locally before archiving. On iCloud-managed Desktop folders, Finder metadata can affect verification of the loose app; extract the ZIP to Applications for a clean copy. This is a local development build, not an Apple-notarized release. A distributable release requires Developer ID signing and notarization.


## Verify

```sh
./scripts/test.sh
```

Eleven executable checks cover exact text persistence/copying, deduplication, pinned retention, concealed and paused clipboard handling, filtering/search, size limits, preservation of a damaged history file, exact PNG/TIFF copying, image persistence and thumbnails, image retention/cleanup, private image skipping, and cancellation of pending image captures. The test runner uses a unique temporary pasteboard, not your general clipboard. It works with Command Line Tools without requiring XCTest/Xcode.

Preview renders under `.impeccable/review/` use illustrative data, not personal clipboard content. The renderer is a development tool and is not bundled into the app.

Native keyboard integration checks are available with `./scripts/test-interactions.sh`. They open temporary test windows, send keys only to the test app, and use a separate test pasteboard. They cover hover focus from an active text field and after app deactivation, Up/Down navigation without a click, Return to copy, Escape, shortcut search, interrupted close/reopen, caret placement at screen edges, shortcut paste routing, Paste on click routing (paste into a remembered text field, copy when off or with no field), no-notch geometry across laptop/external/portrait/offset displays, and a simulated no-notch controller with display-change dismissal. Paste delivery is mocked in those tests; live cross-app delivery requires Accessibility access and a manual check.

Run `./scripts/test-hover.sh` for six deterministic entry-trigger checks: immediate entry, fast landing, slow approach, dismissal rearming, display switching, and exit/reentry during closing.


## Publishing updates

Change the app version in `scripts/Info.plist`, commit, and push a matching tag such as `v0.3.2`. The Release PasteReady workflow builds both architectures, runs pointer and installer checks, and publishes `install.sh`, `PasteReady.zip`, and `PasteReady.zip.sha256`. It can also be started manually from GitHub Actions.

Current builds use local ad-hoc signing. Developer ID signing and Apple notarization are not configured yet; the installer does not disable macOS security protections.


[Installer details](../distribution/README.md)

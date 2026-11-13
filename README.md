# PasteReady

A native macOS clipboard shelf attached to your camera notch. Copy text or a URL once, then reuse it from the notch without finding the original page.

## Use

Extract **build/PasteReady.zip**, move **PasteReady.app** to Applications, and open it. It lives in the menu bar without a Dock icon.

1. Copy text or a web link anywhere with Command–C.
2. Hover over your notch, or press **Command–Shift–V**.
3. Click the **copy icon** beside an item. The picker stays open and confirms the copy. Clicking the row or pressing Return also copies and closes the picker.
4. Return to your form and press **Command–V**.

For direct paste, first put your cursor in a text field and press **Command–Shift–V**. Search or navigate with arrow keys, then press Return or click a row or its paste icon. The picker closes, restores the captured app and text selection, and sends one Command–V to that app. It waits for the app to regain focus and for shortcut modifiers to be released. Escape cancels without pasting. If permission is missing or the original destination is no longer available, the item is still copied and the app explains how to paste manually.

### Full preview

Press **Space** to open the selected item's complete text or URL. Press Space again, click **Space close preview**, or use the preview's close button to return to the list. **Escape** closes the preview first; a second Escape closes the picker. Long content scrolls vertically and can be selected, while preserving line breaks and tabs. Previewing does not copy, paste, edit the item, or load URLs from the network.

While typing a search phrase, Space inserts a normal space. Use Up/Down to select a result, then Space to preview it, or click **Space preview**. Holding Space does not repeatedly toggle the view. The original list remains in place behind the preview.

Use All, Links, or Pinned to narrow the list. Search names and content. Use Up/Down and Return to choose an item, Left/Right to switch All → Links → Pinned, and Escape to close. Horizontal arrows stop at the first and last filter. Search text is preserved across filters. Modified horizontal arrows retain normal text editing. Pin items you want to keep; right-click an item to rename or delete it.

On a display without a notch, hover at the center of the top screen edge for a moment. The 190pt-wide trigger uses only the top 4pt, leaving ordinary menu-bar movement alone. A rounded clipboard shelf opens below the menu bar, and stays open while you move from the edge into it. This works per display, including external monitors. Display rearrangement or disconnection dismisses the old picker so the next opening uses fresh geometry. The keyboard shortcut opens near your insertion caret when the app exposes its location; otherwise it opens near your pointer. The picker is kept inside its display. Hover opens on entry at any pointer speed, with no settling or dwell requirement. The exact top border is included so a cursor hidden behind the camera housing still triggers it. Opening uses one continuous damped reveal and respects Reduce Motion. After dismissal, hover must leave the trigger before it can reopen. Native mouse-movement events detect entry immediately; a 60Hz common-mode sampler also catches a stationary camera-obscured pointer. Trigger geometry is cached; native menus and sheets suspend hover dismissal. Arrow keys work immediately on hover, including when you were typing in another app. Hover gives keyboard focus to the picker without focusing its search field; Command–Shift–V focuses search. Leaving the picker or pressing Escape returns keyboard control to your previous app.

## Clipboard and privacy

History is captured while the app is running. It cannot recover things copied before launch. macOS may ask for clipboard access: allow it for continuous capture. Manage it in **System Settings → Privacy & Security → Paste from Other Apps** when available. Copy-only notch use needs no Accessibility permission. **Direct paste requires Accessibility access for PasteReady**. Enable it from the app’s Settings → Direct paste → Enable, then switch on PasteReady under System Settings → Privacy & Security → Accessibility. Input Monitoring is not required.

Text and URLs are supported; images, file copies, rich formatting, empty text, and individual text items larger than 100 KB are excluded. Password-manager entries marked concealed or transient are skipped. Ordinary text is otherwise captured, so use Pause clipboard history when needed.

History is stored as local JSON at `~/Library/Application Support/NotchLinks/history.json`, accessible only to your user account by file permissions. It is not encrypted. The app makes no network requests. Up to 20 unpinned items are retained; pins stay until removed. Repeated copies update recency without removing custom names or pins.

Settings are available from the menu bar icon or the gear. **Clear recent** keeps pins; **Delete all** asks for confirmation and removes pins too. Neither changes the current system clipboard. Launch at login is optional; put the app at its permanent location before enabling it.

If another utility owns Command–Shift–V, disable that utility’s shortcut and restart PasteReady, or use the menu bar entry.

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

Seven executable checks cover exact text persistence/copying, deduplication, pinned retention, concealed and paused clipboard handling, filtering/search, size limits, and preservation of a damaged history file. The test runner uses a unique temporary pasteboard, not your general clipboard. It works with Command Line Tools without requiring XCTest/Xcode.

Preview renders under `.impeccable/review/native/` use illustrative data, not personal clipboard content. The renderer is a development tool and is not bundled into the app.

Native keyboard integration checks are available with `./scripts/test-interactions.sh`. They open temporary test windows, send keys only to the test app, and use a separate test pasteboard. They cover hover focus from an active text field and after app deactivation, Up/Down navigation without a click, Return to copy, Escape, shortcut search, interrupted close/reopen, caret placement at screen edges, shortcut paste routing, no-notch geometry across laptop/external/portrait/offset displays, and a simulated no-notch controller with display-change dismissal. Paste delivery is mocked in those tests; live cross-app delivery requires Accessibility access and a manual check.

Run `./scripts/test-hover.sh` for six deterministic entry-trigger checks: immediate entry, fast landing, slow approach, dismissal rearming, display switching, and exit/reentry during closing.

## Updating

There is no automatic updater yet. Quit the running app, extract the newest ZIP, replace the existing PasteReady.app at its current location, and reopen it. History and pins live separately in Application Support and survive app replacement. During development, Codex can replace and restart the project’s running copy directly; that does not require manually reinstalling the ZIP.

Arrow-key scrolling leaves the viewport still while the selected row is visible. At the edge, the native scroll view glides just enough to reveal the next row. Held keys retarget the same motion without restarting it; trackpad input cancels the keyboard motion and uses native scrolling. Reduce Motion reveals the selected row immediately. Reopening or filtering resets list position.

## One-command terminal installation

Install the latest release with:

```sh
curl -fsSL --proto '=https' --proto-redir '=https' https://github.com/sartha555k/PasteReady/releases/latest/download/install.sh | sh
```

The installer downloads the universal app, checks its SHA-256 checksum and bundle signature, and installs it to `~/Applications/PasteReady.app` without sudo. Existing history and pins are preserved. Run the same command to update this installation.

The installer does not stop a development copy running from a different location. Quit that copy before opening the installed app. For direct paste, enable PasteReady under macOS Privacy & Security → Accessibility.

[Installer details](distribution/README.md)

## Publishing updates

Change the app version in `scripts/Info.plist`, commit, and push a matching tag such as `v0.3.2`. The Release PasteReady workflow builds both architectures, runs pointer and installer checks, and publishes `install.sh`, `PasteReady.zip`, and `PasteReady.zip.sha256`. It can also be started manually from GitHub Actions.

Current builds use local ad-hoc signing. Developer ID signing and Apple notarization are not configured yet; the installer does not disable macOS security protections.

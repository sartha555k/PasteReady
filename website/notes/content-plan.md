# PasteReady showcase content

Primary action: copy the installer command and run it in Terminal. ZIP download is secondary, per the user's answer.

Copy once. Keep it close.
A native Mac clipboard history for the links and words you use again and again.

Install command (exact):
`curl -fsSL --proto '=https' --proto-redir '=https' https://github.com/sartha555k/PasteReady/releases/latest/download/install.sh | sh`

Product proof:
- Native app captures of the populated list, full text preview, and detached shortcut picker, all using sample data.
- Last 20 recent text/link copies plus persistent pins.
- Hover at the notch or top-center edge to copy an item again.
- Command–Shift–V opens near the caret (pointer fallback), selects an item, then pastes to the previous app with Accessibility permission.
- Search, All / Links / Pinned, up/down selection, left/right filters, Return action, Space preview, Escape close.
- Local storage, no app network requests. History is not encrypted. Concealed/transient clipboard items skipped; ordinary text is captured while running; pause available.
- macOS 14+, universal Apple Silicon / Intel build; no-notch and external-display support.
- Manual updates by rerunning the command; history/pins preserved. No automatic updater.

Install steps:
Copy command → Open Terminal → Paste and press Return → Allow clipboard access if macOS asks.
Enable direct paste through Settings → Direct paste → Enable; grant Accessibility permission in System Settings.

Verified release on 2026-11-13: v0.4.0. Installer, ZIP and checksum present on GitHub. The premium UI is on main but not in a newer stable release yet.

Do not claim: cloud sync, image/file history, encryption, Apple notarization, App Store distribution, download/user counts, testimonials or automatic updates.

Links:
- Repository: https://github.com/sartha555k/PasteReady
- Latest ZIP: https://github.com/sartha555k/PasteReady/releases/latest/download/PasteReady.zip
- Latest installer: https://github.com/sartha555k/PasteReady/releases/latest/download/install.sh
- Usage/privacy: https://github.com/sartha555k/PasteReady/blob/main/docs/usage.md
- Releases: https://github.com/sartha555k/PasteReady/releases

## Final simplification

The user replaced the earlier notch-led concept with their own visual reference: a centered, high-contrast serif on a pale dotted white field. The current website follows that restraint. It uses one primary install-copy action, an inspectable command disclosure, one native gallery, a plain feature index, and concise FAQ. Bodoni Moda replaces the earlier sans display and intermediate Instrument Serif. Earlier mockups and build-state measurements are archived locally and are not shipping authority. Website-specific DESIGN.md and .impeccable/design.json record the final implementation. The native app's design system is unchanged.

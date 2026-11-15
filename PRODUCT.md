# PasteReady

<!-- impeccable:product-schema 1 -->

## Platform
macOS (native AppKit and SwiftUI).

## Stack
Swift + SwiftUI, packaged as a menu bar application using Swift Package Manager and a local build script. Native implementation as proposed; user confirmed text-plus-link capture. Shortcut selection pastes automatically. Notch hover choices paste into the remembered text field when Paste on click is on (default), and copy otherwise.

## Users
The Mac owner filling applications and forms, repeatedly reusing LinkedIn, Drive and other links.

## Product Purpose
Keep recently copied links available at the notch and through Command–Shift–V, so a previously copied link can be selected and pasted without finding it again.

## Operating Context
Development hardware: Apple Silicon M4 Mac with a camera notch. The app also supports displays without a notch and external monitors. Universal build targets Apple Silicon and Intel on macOS 14 or later; Intel runtime is not tested on physical hardware. Normal Command–V pastes the current clipboard.

## Capabilities and Constraints
Confirmed: hover at notch opens a popover; recently copied text and links are listed, each with a visible copy button; Command–Shift–V opens a searchable clipboard picker; shortcut selections paste at the original insertion point.
Confirmed: all copied text and links, hover selection copies; Command–Shift–V selection pastes into the previously focused app with Accessibility permission. Shortcut picker appears near the caret when exposed, otherwise near the pointer. User confirmed a limit of 20 recent copies. Pinned favorites are kept separately and do not expire with recent history. Local JSON persistence remains an implementation choice. No network fetching of links. App screens are implemented directly in code this session; no standing build-path preference is recorded.

## Brand Commitments
Black popover, native Apple-level visual restraint, smooth spring-like expansion with a small bubbly anticipation before opening. Confirmed product name: PasteReady.

## Product Principles
- Reuse links without breaking writing flow.
- Keep normal clipboard behavior intact.
- Make frequent links easy to retrieve.
- Store captured content locally.

## Preview and scope
Space or the visible preview control toggles a read-only full-content preview. Escape returns to the list first. Preview preserves all captured text, including line breaks and tabs, without fetching URLs or changing the clipboard. Spaces remain available while editing search. In-app update notifications are explicitly deferred by the user.

## Image history extension
Confirmed: copied PNG and TIFF images join the history with a small aspect-fit thumbnail and a Space-toggle image preview. Existing All/Links/Pinned filters, copy controls, pins, 20-recent limit, local-only storage, and keyboard paste behavior apply. Images are stored as local attachments alongside the existing JSON, preserving old history and the app identity. The website is explicitly outside this update.

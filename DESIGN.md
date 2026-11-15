---
name: PasteReady
description: Native clipboard history at the Mac notch.
colors:
  selection-blue: "rgb(5.5% 11.5% 20%)"
  notch-black: "#000000"
  primary-white: "#ffffff"
  secondary-white: "rgb(100% 100% 100% / 64%)"
  hint-white: "rgb(100% 100% 100% / 54%)"
  field-layer: "rgb(100% 100% 100% / 6.5%)"
  selected-chip-layer: "rgb(100% 100% 100% / 11%)"
  hover-layer: "rgb(100% 100% 100% / 4.5%)"
typography:
  settings-headline:
    fontFamily: "SF system"
    fontSize: "24pt"
    fontWeight: 600
  panel-title:
    fontFamily: "SF system"
    fontSize: "19pt"
    fontWeight: 600
  empty-title:
    fontFamily: "SF system"
    fontSize: "16pt"
    fontWeight: 500
  search:
    fontFamily: "SF system"
    fontSize: "13pt"
    fontWeight: 400
  row-title:
    fontFamily: "SF system"
    fontSize: "13pt"
    fontWeight: 500
  body:
    fontFamily: "SF system"
    fontSize: "12pt"
    fontWeight: 400
  label:
    fontFamily: "SF system"
    fontSize: "12pt"
    fontWeight: 500
  hint:
    fontFamily: "SF system"
    fontSize: "11pt"
    fontWeight: 400
rounded:
  row-icon: "9pt"
  search: "11pt"
  row: "12pt"
  settings-icon: "15pt"
  panel-bottom: "28pt"
spacing:
  text-gap: "4pt"
  control-gap: "5pt"
  row-inset-y: "10pt"
  row-inset-x: "9pt"
  row-gap: "10pt"
  field-inset-x: "12pt"
  content-gap: "12pt"
  panel-inset-x: "14pt"
  settings-inset: "28pt"
components:
  copy-button:
    textColor: "rgb(100% 100% 100% / 72%)"
    width: "26pt"
    height: "28pt"
  search-field:
    backgroundColor: "{colors.field-layer}"
    textColor: "{colors.primary-white}"
    rounded: "{rounded.search}"
    height: "32pt"
    padding: "0pt 10pt"
  selected-filter:
    backgroundColor: "{colors.selected-chip-layer}"
    textColor: "{colors.primary-white}"
    padding: "0pt 10pt"
  selected-row:
    backgroundColor: "{colors.selection-blue}"
    textColor: "{colors.primary-white}"
    rounded: "{rounded.row}"
    padding: "7pt 7pt"
  hover-row:
    backgroundColor: "{colors.hover-layer}"
    rounded: "{rounded.row}"
  notch-panel:
    backgroundColor: "{colors.notch-black}"
    width: "400pt"
---

# Design System: PasteReady

## Overview

Native Apple-level restraint: a black surface that feels continuous with the camera housing, compact SF text, and SF Symbols. Smooth, slightly bubbly anticipation supplies personality without decorative imagery. The user supplied this language; no additional named creative metaphor has been approved.

The picker uses tonal layers for structure and a blue row for selection. Settings use standard SwiftUI controls and semantic system materials. This is a code-led implementation, with no approved visual comp; native renders are illustrative review evidence. The premium refinement uses muted navy selection, grouped filters, keyboard keycaps, and aligned settings switches. Native captures provide review evidence; this feature branch awaits user review.

**Key Characteristics:**
- Black notch silhouette with softly rounded lower corners.
- Native system typography and SF Symbols.
- Visible copy action on every history row.
- Brief elastic anticipation; alpha fade with Reduce Motion.

## Colors

The picker combines pure black, translucent white structure, and a restrained blue selection accent. Frontmatter records source values; opacity is composited over the underlying surface.

### Primary
- **Selection Blue:** The active clipboard row, giving keyboard and pointer selection a stable location.

### Neutral
- **Notch Black:** The camera-connected panel silhouette.
- **Primary White:** Main text and selected labels.
- **Secondary White / Hint White:** Supporting text, filters, and keyboard guidance.
- **Field Layer / Selected Chip Layer / Hover Layer:** Translucent white tonal separation, never independent opaque swatches.

SwiftUI semantic orange communicates capture, storage, and shortcut issues; semantic green confirms copying. Sidecar tonal ramps are synthesized preview metadata, not additional shipping colors.

Settings use `.secondary` and `.quaternary`, standard dividers, switches, and destructive button roles. These platform-resolved colors are not fixed palette tokens.

**The Selection Rule.** Blue identifies the selected history row; filters use tonal white capsules.

## Typography

**Display Font:** Native SF system font, resolved by SwiftUI `.system`.
**Body Font:** Native SF system font, default design. The item count lives in the search placeholder. No bundled fonts or web font dependencies.

**Character:** Compact, familiar, and quiet. Semibold titles establish hierarchy while medium row titles and lighter secondary text support scanning.

### Hierarchy
- **Settings headline:** The large semibold introduction.
- **Panel title:** The semibold clipboard heading.
- **Empty title:** The medium-weight empty-state heading.
- **Search:** Regular text in the plain search field.
- **Row title:** Medium-weight single-line entry name.
- **Body / Label:** Supporting copy and medium filter labels.
- **Hint:** Row preview, permission messaging, and keyboard instructions.

Line height is system-resolved, not a custom scale. The locality label is uppercase at 9pt, medium, with 1pt tracking. Row previews truncate in the middle; titles truncate to one line. Empty-state body copy is centered with 4pt line spacing.

## Layout

Measurements are native macOS points, not browser pixels. All picker dimensions come from `PanelMetrics`. The borderless NSPanel host is 460pt × 458pt (30pt side and 102pt bottom shadow margins). The open black silhouette is 400pt wide and 356pt plus the measured notch height tall; its 346pt content block sits below the notch height plus 10pt. Horizontal panel inset and content spacing use the frontmatter tokens; the footer has a 12pt bottom inset.

The main flow is search (with the item count as its placeholder) beside the settings gear, the filter strip with the Paste on click switch, scrollable history or centered empty state, then keyboard hints. Rows are 42pt with 2pt stack spacing, a 28pt square symbol tile, and distinct copy and pin controls. The copy hit area is 26pt × 28pt; pin is 24pt × 28pt. Scroll indicators are hidden. The picker keeps a fixed width and follows the active display; there are no web-style responsive breakpoints. Displays without a notch use a 190pt × 4pt top-center edge trigger, immediate entry detection, and a detached rounded shelf positioned 8pt below the current visible frame’s top. There is no synthetic camera spacer. A narrow hover bridge keeps the shelf open while crossing the menu bar. Such shelves use a 120ms fade, preserving the notch spring on actual notched screens.

Settings use a native window content view of 480pt × 690pt, 28pt outer inset, and 22pt section spacing. Text paragraphs wrap intrinsically. No mobile layout is implemented.

## Elevation & Depth

The silhouette uses a structural SwiftUI shadow: black at 32% opacity, radius 24pt, x offset 0pt, y offset 14pt when expanded; it has no shadow when closed. The AppKit panel's own shadow is disabled. Fields, symbol tiles, filters, and hovered rows separate through translucent tonal layers rather than individual shadows.

**The Single Shadow Rule.** The expanded notch silhouette owns the custom shadow; its internal controls stay flat.

## Shapes

The panel is an uneven rounded rectangle: upper corners 9pt (22pt when detached), expanded lower corners using the panel-bottom token, collapsed lower corners 15pt. Anticipation adds 26pt to the measured notch width and 11pt to its height. Row, search, and symbol-tile radii are distinct small curves; filters share a 10pt rounded segmented container with 7pt selected segments. The count is unboxed. The settings app icon sits in a 54pt square with the settings-icon radius. Selected rows and focused search use a fine 0.7pt blue edge; idle search uses a faint white edge. Native settings controls retain platform geometry.

## Components

### Buttons

Plain, compact symbol controls in the picker; native buttons in settings. The visible `doc.on.doc` copy control appears in every row at 12pt. Settings uses a 14pt gear in a 30pt square. Icon actions have an 8pt hover surface and a short press response that respects Reduce Motion. Pin visibility strengthens on hover or selection; pinned state remains visible. Tooltips and accessibility labels identify icon actions. No custom focus-ring token is defined; focus uses native behavior.

### Chips

All, Links, and Pinned share a compact segmented container with 11pt medium labels in 20pt segments. Selected state uses the selected-filter token; inactive labels use Secondary White. Paste on click is a 22pt chip with a text-cursor symbol and a small switch; it shows only for hover-opened pickers, because the shortcut always pastes. Keyboard guidance uses small 17pt-high keycaps with 9pt labels and 10.5pt descriptions.

### Cards / Containers

The notch silhouette is the signature container; history rows form a compact list rather than independently elevated cards. Selection uses Selection Blue, hover uses Hover Layer, and resting rows are transparent. Each row contains a system symbol, title, preview, persistent copy icon, and pin action. Context menus expose copy, pin, rename, and delete through native menus.

### Inputs / Fields

The plain search field uses the search-field token with a magnifier and a conditional clear action. Keyboard-open gives search focus. Search, filter, and item mutations keep selection valid. Rename uses a standard SwiftUI alert text field; settings uses native switch toggles and confirmation alerts. Storage or permission issues appear inline in semantic orange.

### Navigation

Command–Shift–V opens the picker, Up/Down change the selected row; plain Left/Right switch All, Links, and Pinned without wrapping or clearing search, Return copies the selection, and Escape closes. Hover opens on the first sampled entry regardless of pointer speed, including the exact top screen border. Once opening begins it takes keyboard focus without entering search editing; leaving the region for 0.24s closes a hover-opened panel unless search has focus. Choosing a row (click or Return) is the primary action. A hover-opened picker remembers the app and text insertion point that had focus; with Paste on click on (the default) and Accessibility granted, choosing pastes there, and the footer reads “Paste into <app>”. With no insertion point, no Accessibility access, or the switch off, choosing copies, closes the picker and restores the previous app. The per-row copy icon always copies only and confirms in the footer while leaving the picker open. Command–Shift–V opens a detached, fully rounded picker near the captured caret (pointer fallback) and always pastes on Return. Shortcut selection restores the captured target and requests a single paste, subject to Accessibility access; Escape cancels.

### Notch expansion

Opening uses a single continuous spring (response 0.28s, damping fraction 0.92) without a separate anticipation timer. List layout stays mounted; opening resets the list position without animation. Keyboard navigation keeps visible rows still and reveals offscreen rows by the minimum distance. Normal close uses a 0.16s ease-in-out, and exit and reentry during collapse can reverse it without waiting for teardown. Dismissal requires a trigger exit before rearming. Reduce Motion opens directly at expanded geometry and animates panel alpha over 0.12s; close also fades alpha without geometry animation. Keyboard scrolling uses a native NSScrollView and a critically damped motion model (frequency parameter 28), preserving position and velocity between repeated keys. It follows the display refresh rate, yields to trackpad/wheel input, and jumps directly under Reduce Motion. Motion values are native animation parameters, not CSS easing equivalents.

## Do's and Don'ts

### Do:
- **Do** use native system fonts, SF Symbols, and platform settings controls.
- **Do** preserve a visible copy icon on every row, including unselected rows.
- **Do** show selected history rows in the extracted blue and hover through a quiet tonal layer.
- **Do** preserve all captured text and links as local history; hover choices paste only into a remembered text insertion point when Paste on click is on, and copy otherwise; shortcut selection pastes into the captured app.
- **Do** use the alpha-only opening and closing path when Reduce Motion is enabled.

### Don't:
- **Don't** paste after cancellation, into a changed destination, or from hover when no text insertion point was focused.
- **Don't** replace the black notch surface with remote imagery or fetched favicons.
- **Don't** invent fixed colors for native semantic settings materials.
- **Don't** treat illustrative renders or browser component previews as an approved native comp.

Preview uses the existing list region, keeping the list mounted underneath to preserve position. A compact title row contains the selected item name, the contextual Copy/Paste action, and a close button. A 12pt rounded tonal surface contains a read-only native NSTextView with 13pt SF text and 12pt insets. The footer exposes Space preview / Space close preview in the same position. Preview does not introduce another window, remote content, or a new visual identity.

## Premium refinement — November 2026

The `feat/premium-ui` pass preserves the black notch silhouette and interaction timings. The header pairs a 34pt symbol tile with a 19pt PasteReady title and secondary history label. Muted navy selection, a fine blue edge, aligned row actions, grouped filters, and reusable keycaps provide hierarchy without extra elevation. Rows retain the 52pt height and 55pt navigation stride. Settings groups its three preferences and aligns switches on the trailing edge. Native renders in `.impeccable/review/premium/` cover populated, preview, empty, search, shortcut, no-notch, and settings states.

## Compact picker and paste on click — November 2026

The `feat/paste-on-click-compact-panel` pass shrinks the picker from 480pt × 468pt to 400pt × 356pt (about 35% less area) while showing more rows: 42pt rows with a 44pt navigation stride. The 34pt symbol tile and PasteReady title header were removed; search leads, with the item count as its placeholder and the gear beside it. The “On this Mac” label moved out of the picker; Settings still explains local storage. Hover-opened pickers gain a Paste on click switch (default on, also in Settings) and a footer hint naming where Return or a click will paste. All existing actions — search, filters, preview, pin, rename, delete, copy-only, keyboard navigation — are unchanged.

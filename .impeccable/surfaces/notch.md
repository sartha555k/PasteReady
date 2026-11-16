# Notch popover
Mode: Operate. Native macOS utility for recalling and pasting links while filling forms.

## Direction contract
THESIS: A small extension of the camera housing, opening directly into a searchable clipboard list.
OWN-WORLD: User-pinned Apple-style black surface; SF typography, SF Symbols, white primary text, muted secondary text, blue selected rows. No remote favicons.
STORY: Copy a link during normal work; hover at the camera or press Command–Shift–V; search, pin, use the visible copy button for hover retrieval, or select through Command–Shift–V to paste at the saved insertion point.
FIRST VIEWPORT: 480pt black panel attached to the screen edge, safe spacing below the camera, title and item count, search field, All, Links and Pinned filters, 4–5 compact rows, and keyboard hints at the foot. Empty state explains copying a first item.
FORM: Brief-pinned native Apple utility, overriding alternate visual systems. seed:7db0785477cab1a2. The roll ran degraded; no challengers were available. Entry at any speed starts one continuous spring expansion; reduced motion uses a fade.
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Image clipboard extension

Keep the incumbent native black panel, SF type, row dimensions, and blue selection. Images join All and Pinned alongside text; Links stays link-only. Each image has a bounded aspect-fit thumbnail in the existing 32pt icon slot, a title, pixel dimensions and size, and the same copy/pin actions. Space toggles an aspect-fit image preview inside the existing preview area; Escape returns to the list. No website changes or update notifications. Finish with persistence/copy/retention regression checks, native render evidence, and an independent finish review.

## App enable setting
Add a native switch at the top of the existing Settings preferences group with a short enabled/disabled explanation. Keep existing SF typography and grouped surfaces; dim hover, paste-on-click and pause controls while disabled, preserve launch-at-login and history controls. Allow the Settings content to scroll inside the existing 480×690 window so the new row never clips lower settings. Menu bar reports disabled status and keeps Settings available.

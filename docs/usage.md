# Using PasteReady

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

On a display without a notch, hover at the center of the top screen edge. The 190pt-wide trigger uses only the top 4pt, leaving ordinary menu-bar movement alone. A rounded clipboard shelf opens below the menu bar, and stays open while you move from the edge into it. This works per display, including external monitors. Display rearrangement or disconnection dismisses the old picker so the next opening uses fresh geometry. The keyboard shortcut opens near your insertion caret when the app exposes its location; otherwise it opens near your pointer. The picker is kept inside its display. Hover opens on entry at any pointer speed, with no settling or dwell requirement. The exact top border is included so a cursor hidden behind the camera housing still triggers it. Opening uses one continuous damped reveal and respects Reduce Motion. After dismissal, hover must leave the trigger before it can reopen. Native mouse-movement events detect entry immediately; a 60Hz common-mode sampler also catches a stationary camera-obscured pointer. Trigger geometry is cached; native menus and sheets suspend hover dismissal. Arrow keys work immediately on hover, including when you were typing in another app. Hover gives keyboard focus to the picker without focusing its search field; Command–Shift–V focuses search. Leaving the picker or pressing Escape returns keyboard control to your previous app.


## Clipboard and privacy

History is captured while the app is running. It cannot recover things copied before launch. macOS may ask for clipboard access: allow it for continuous capture. Manage it in **System Settings → Privacy & Security → Paste from Other Apps** when available. Copy-only notch use needs no Accessibility permission. **Direct paste requires Accessibility access for PasteReady**. Enable it from the app’s Settings → Direct paste → Enable, then switch on PasteReady under System Settings → Privacy & Security → Accessibility. Input Monitoring is not required.

Text and URLs are supported; images, file copies, rich formatting, empty text, and individual text items larger than 100 KB are excluded. Password-manager entries marked concealed or transient are skipped. Ordinary text is otherwise captured, so use Pause clipboard history when needed.

History is stored as local JSON at `~/Library/Application Support/NotchLinks/history.json`, accessible only to your user account by file permissions. It is not encrypted. The app makes no network requests. Up to 20 unpinned items are retained; pins stay until removed. Repeated copies update recency without removing custom names or pins.

Settings are available from the menu bar icon or the gear. **Clear recent** keeps pins; **Delete all** asks for confirmation and removes pins too. Neither changes the current system clipboard. Launch at login is optional; put the app at its permanent location before enabling it.

If another utility owns Command–Shift–V, disable that utility’s shortcut and restart PasteReady, or use the menu bar entry.


## Updating

Run the install command in the [README](../README.md) again to get the latest release. History and pins are preserved. There is no automatic updater yet.

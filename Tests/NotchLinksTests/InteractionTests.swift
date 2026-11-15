import AppKit

private final class TestPasteHandler: PasteHandling {
    var pasted: [PasteDestination] = []
    var entries: [ClipboardEntry] = []
    var canPaste = true
    /// Hover pastes only into a text insertion point; tests opt in per case.
    var withTextSelection = false
    func capture() -> PasteDestination? {
        var destination = PasteDestination(app: .current)
        if withTextSelection {
            var range = CFRange(location: 0, length: 0)
            destination.selection = AXValueCreate(.cfRange, &range)
        }
        return destination
    }
    func cancel() {}
    func paste(to destination: PasteDestination, entry: ClipboardEntry, completion: @escaping (PasteOutcome) -> Void) {
        pasted.append(destination)
        entries.append(entry)
        completion(.sent)
    }
}

@main
struct InteractionTests {
    @MainActor static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pasteboard = NSPasteboard.withUniqueName()
        defer {
            pasteboard.releaseGlobally()
            try? FileManager.default.removeItem(at: directory)
        }
        let store = ClipboardStore(file: directory.appendingPathComponent("history.json"), monitoring: false, pasteboard: pasteboard)
        store.links = [ClipboardEntry(content: "first", title: "First"), ClipboardEntry(content: "second", title: "Second")]
        let sorted = store.sorted
        let inputWindow = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 400, height: 100),
            styleMask: [.titled], backing: .buffered, defer: false)
        let field = NSTextField(frame: NSRect(x: 20, y: 30, width: 360, height: 24))
        field.stringValue = "A form with its insertion caret active"
        inputWindow.contentView?.addSubview(field)
        app.activate(ignoringOtherApps: true)
        inputWindow.makeKeyAndOrderFront(nil)
        inputWindow.makeFirstResponder(field)
        pump(for: 0.1)
        let originalResponder = inputWindow.firstResponder
        let pasteHandler = TestPasteHandler()
        UserDefaults.standard.set(true, forKey: PanelState.pasteOnClickKey)
        defer { UserDefaults.standard.removeObject(forKey: PanelState.pasteOnClickKey) }
        let controller = NotchController(store: store, pasteHandler: pasteHandler)

        controller.open(keyboard: false)
        pump(for: 0.04) // AppKit activation settles on the next event-loop turn.
        precondition(controller.hasKeyboardFocus, "Hover must acquire keyboard focus immediately, before the spring completes")
        precondition(!controller.state.focusSearch, "Hover must not force search editing or disable hover dismissal")
        precondition(controller.state.selectedID == sorted[0].id)
        key(125, characters: "\u{F701}")
        precondition(controller.state.selectedID == sorted[1].id,
            "Down must navigate without a click; phase=\(controller.state.phase), focused=\(controller.hasKeyboardFocus)")
        key(126, characters: "\u{F700}")
        precondition(controller.state.selectedID == sorted[0].id, "Up must navigate without a click")
        print("PASS: hover takes keyboard focus and up/down navigate with no click")

        key(36, characters: "\r")
        precondition(pasteboard.string(forType: .string) == sorted[0].content, "Return must copy the selected item")
        pump(for: 0.2)
        precondition(!controller.hasKeyboardFocus, "Closing must release keyboard focus")
        precondition(inputWindow.firstResponder === originalResponder, "The form must retain its original text responder")
        print("PASS: Return copies to a temporary pasteboard and releases focus")
        precondition(pasteHandler.pasted.isEmpty, "Hover without a text insertion point must stay copy-only")
        precondition(controller.state.pasteTarget == nil)

        controller.open(keyboard: true)
        pump(for: 0.08)
        precondition(controller.hasKeyboardFocus && controller.state.focusSearch, "Shortcut must still focus search")
        key(53, characters: "\u{1B}")
        pump(for: 0.2)
        precondition(!controller.hasKeyboardFocus)
        print("PASS: shortcut search and Escape still work")

        controller.open(keyboard: true)
        pump(for: 0.08)
        precondition(controller.state.detached && controller.state.pastesSelection)
        key(125, characters: "\u{F701}")
        key(36, characters: "\r")
        pump(for: 0.2)
        precondition(pasteHandler.pasted.count == 1, "Shortcut selection must request exactly one paste")
        precondition(pasteHandler.pasted[0].app.processIdentifier == ProcessInfo.processInfo.processIdentifier,
            "The captured destination must survive opening and searching")
        precondition(pasteboard.string(forType: .string) == sorted[1].content)
        precondition(inputWindow.firstResponder === originalResponder)
        print("PASS: shortcut Return copies selected text and requests paste into the captured destination")

        // Paste on click: hover remembers the text field the user was typing in.
        pasteHandler.withTextSelection = true
        controller.open(keyboard: false)
        pump(for: 0.04)
        precondition(controller.state.pasteTarget != nil && !controller.state.pastesSelection,
            "Hover over a text insertion point must offer paste on click")
        key(36, characters: "\r")
        pump(for: 0.2)
        precondition(pasteHandler.pasted.count == 2, "Hover choice must paste into the remembered field when paste on click is on")
        precondition(pasteboard.string(forType: .string) == sorted[0].content)
        UserDefaults.standard.set(false, forKey: PanelState.pasteOnClickKey)
        controller.open(keyboard: false)
        pump(for: 0.04)
        key(125, characters: "\u{F701}")
        key(36, characters: "\r")
        pump(for: 0.2)
        precondition(pasteHandler.pasted.count == 2, "With paste on click off, a hover choice must only copy")
        precondition(pasteboard.string(forType: .string) == sorted[1].content)
        controller.open(keyboard: true)
        pump(for: 0.08)
        key(36, characters: "\r")
        pump(for: 0.2)
        precondition(pasteHandler.pasted.count == 3, "The paste on click toggle must not change the shortcut, which always pastes")
        UserDefaults.standard.set(true, forKey: PanelState.pasteOnClickKey)
        pasteHandler.withTextSelection = false
        print("PASS: paste on click pastes hover choices into the remembered field, copies when off, and leaves ⌘⇧V pasting")

        for screen in [CGRect(x: 0, y: 0, width: 1470, height: 920), CGRect(x: -1920, y: 200, width: 1920, height: 1080)] {
            for anchor in [screen.origin, CGPoint(x: screen.maxX - 1, y: screen.maxY - 1),
                           CGPoint(x: screen.midX, y: screen.midY)] {
                let origin = PickerPlacement.origin(anchor: CGRect(origin: anchor, size: .zero), visibleFrame: screen)
                let surface = CGRect(x: origin.x + PanelMetrics.sidePadding, y: origin.y + PanelMetrics.bottomPadding,
                    width: PanelMetrics.width, height: PanelMetrics.bodyHeight)
                precondition(screen.contains(surface), "Caret picker must fit on its display")
            }
        }
        print("PASS: caret picker stays on-screen at edges and on offset displays")

        controller.open(keyboard: false)
        controller.close()
        controller.open(keyboard: false)
        pump(for: 0.2) // Past close teardown, but before hover's 0.24s leave timeout.
        precondition(controller.hasKeyboardFocus && controller.state.phase == 2, "An old close callback must not hide a reopened panel")
        controller.close()
        pump(for: 0.2)
        app.deactivate()
        pump(for: 0.1)
        controller.open(keyboard: false)
        pump(for: 0.04)
        precondition(controller.hasKeyboardFocus, "Hover must take keyboard focus after app deactivation")
        key(125, characters: "\u{F701}")
        precondition(controller.state.selectedID == sorted[1].id,
            "Down must navigate after an app deactivation/reactivation handoff")
        controller.close()
        pump(for: 0.2)
        print("PASS: hover navigation works after app deactivation/reactivation")

        let layouts: [(CGRect, CGRect)] = [
            (CGRect(x: 0, y: 0, width: 1366, height: 768), CGRect(x: 0, y: 64, width: 1366, height: 680)),
            (CGRect(x: -1920, y: 200, width: 1920, height: 1080), CGRect(x: -1920, y: 200, width: 1856, height: 1056)),
            (CGRect(x: 1470, y: -300, width: 1080, height: 1920), CGRect(x: 1470, y: -236, width: 1080, height: 1832)),
            (CGRect(x: 0, y: 956, width: 1440, height: 900), CGRect(x: 0, y: 956, width: 1440, height: 900))
        ]
        for (frame, visible) in layouts {
            let geometry = DisplayGeometry(frame: frame, visibleFrame: visible)
            let edge = CGPoint(x: frame.midX, y: frame.maxY - 1)
            precondition(geometry.hoverTrigger.contains(edge))
            precondition(geometry.containsHoverPoint(CGPoint(x: frame.midX, y: frame.maxY)),
                "The exact top border must trigger even if the cursor is clamped there")
            precondition(!geometry.hoverTrigger.contains(CGPoint(x: frame.midX, y: frame.maxY - 12)),
                "Ordinary menu-bar movement must not trigger the shelf")
            precondition(visible.contains(geometry.hoverSurface), "Non-notch shelf must fit below menu bar and above Dock")
            precondition(geometry.keepsHoverOpen(at: edge), "Resting at the trigger must not repeatedly close the shelf")
            precondition(geometry.keepsHoverOpen(at: CGPoint(x: frame.midX, y: geometry.hoverSurface.maxY + 2)),
                "Pointer must be able to cross the menu-bar gap")
        }
        let notched = DisplayGeometry(frame: CGRect(x: 0, y: 0, width: 1470, height: 956),
            visibleFrame: CGRect(x: 0, y: 64, width: 1470, height: 855),
            notch: CGRect(x: 640, y: 919, width: 190, height: 37))
        precondition(notched.notch != nil && notched.hoverPanelOrigin.y == 956 - PanelMetrics.canvasHeight)
        precondition(notched.containsHoverPoint(CGPoint(x: 735, y: 956)))
        precondition(notched.keepsHoverOpen(at: CGPoint(x: 735, y: 956)))
        precondition(notched.hoverSurface.maxY == 956)
        print("PASS: no-notch geometry covers laptop, external, portrait, offset and hidden-menu layouts")

        if let screen = NSScreen.main {
            let geometry = DisplayGeometry(screen: screen)
            let inside = CGPoint(x: geometry.hoverTrigger.midX, y: geometry.frame.maxY)
            move(CGPoint(x: inside.x, y: geometry.hoverTrigger.minY - 100))
            move(inside)
            precondition(controller.state.phase == 2 && controller.hasKeyboardFocus,
                "A mouse event landing at the exact top border must open without a dwell or click")
            controller.close()
            pump(for: 0.2)
        }
        print("PASS: native mouse-event fast landing opens on the exact top border")

        let simulated = NotchController(store: store, pasteHandler: pasteHandler) { screen in
            DisplayGeometry(frame: screen.frame, visibleFrame: screen.visibleFrame)
        }
        simulated.open(keyboard: false)
        pump(for: 0.04)
        precondition(simulated.state.detached && simulated.state.notchHeight == 0 && !simulated.state.pastesSelection)
        precondition(simulated.hasKeyboardFocus)
        key(125, characters: "\u{F701}")
        precondition(simulated.state.selectedID == sorted[1].id)
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: app)
        pump(for: 0.2)
        precondition(!simulated.hasKeyboardFocus && simulated.state.phase == 0,
            "Display changes must dismiss a picker attached to the old display layout")
        print("PASS: simulated no-notch controller opens, navigates and dismisses on display change")

        precondition(KeyboardScrollMotion.reveal(index: 1, viewport: 250, contentHeight: 1097, from: 0) == 0,
            "Moving between visible rows must not recenter the list")
        var motion = KeyboardScrollMotion(target: 400)
        var prior: CGFloat = 0
        for _ in 0..<120 {
            motion.step(1.0 / 120)
            precondition(motion.position >= prior && motion.position <= 400,
                "Scroll motion must converge without bounce")
            prior = motion.position
        }
        precondition(abs(motion.position - 400) < 0.01)
        let velocity = motion.velocity
        let position = motion.position
        motion.target = 800
        precondition(motion.position == position && motion.velocity == velocity,
            "Retargeting must preserve position and velocity")
        print("PASS: scroll motion preserves continuity and only reveals offscreen rows")

        store.links = (0..<20).map { ClipboardEntry(content: "Scroll item \($0)", title: "Scroll item \($0)", copiedAt: Date(timeIntervalSince1970: Double($0))) }
        controller.open(keyboard: true)
        pump(for: 0.1)
        guard let content = NSApp.keyWindow?.contentView,
              let scroll = findScroll(in: content) else { preconditionFailure("No native clipboard scroll view") }
        key(125, characters: "\u{F701}")
        precondition(abs(scroll.contentView.bounds.minY) < 0.5, "Visible selection must leave the viewport still")
        controller.state.selectedID = store.sorted[7].id
        pump(for: 0.04)
        let listHeight = 20 * PanelMetrics.rowHeight + 19 * PanelMetrics.rowSpacing
        let target = KeyboardScrollMotion.reveal(index: 7, viewport: scroll.contentView.bounds.height,
            contentHeight: listHeight, from: 0)
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            precondition(scroll.contentView.bounds.minY > 0 && scroll.contentView.bounds.minY < target,
                "Offscreen selection should glide through intermediate positions")
        }
        pump(for: 0.4)
        for _ in 8..<20 { key(125, characters: "\u{F701}") }
        pump(for: 0.4)
        precondition(scroll.contentView.bounds.maxY >= listHeight - 1, "Held navigation must reveal the last row")
        controller.state.selectedID = store.sorted[0].id
        pump(for: 0.5)
        precondition(scroll.contentView.bounds.minY < 0.5, "Reversing direction must return smoothly to the first row")
        controller.close()
        pump(for: 0.2)
        print("PASS: native viewport glides, handles repeated arrows, and reverses to the first row")

        store.links = [
            ClipboardEntry(content: "A note", title: "Note"),
            ClipboardEntry(content: "https://example.com/one", title: "One"),
            ClipboardEntry(content: "https://example.com/pinned", title: "Pinned", pinned: true)
        ]
        controller.state.linksOnly = false
        controller.state.favoritesOnly = false
        controller.open(keyboard: true)
        pump(for: 0.05)
        key(124, characters: "\u{F703}")
        precondition(controller.state.linksOnly && !controller.state.favoritesOnly)
        precondition(controller.state.filtered(store.sorted).count == 2)
        key(125, characters: "\u{F701}")
        precondition(controller.state.selectedID == controller.state.filtered(store.sorted)[1].id)
        key(124, characters: "\u{F703}")
        precondition(controller.state.favoritesOnly && !controller.state.linksOnly)
        precondition(controller.state.filtered(store.sorted).count == 1)
        let pinnedID = controller.state.selectedID
        key(124, characters: "\u{F703}")
        precondition(controller.state.favoritesOnly && controller.state.selectedID == pinnedID)
        key(123, characters: "\u{F702}")
        precondition(controller.state.linksOnly && !controller.state.favoritesOnly)
        key(123, characters: "\u{F702}")
        precondition(!controller.state.linksOnly && !controller.state.favoritesOnly)
        controller.state.query = "not present"
        pump(for: 0.03)
        key(124, characters: "\u{F703}")
        precondition(controller.state.query == "not present" && controller.state.selectedID == nil)
        key(123, characters: "\u{F702}", modifiers: .shift)
        precondition(controller.state.linksOnly, "Modified arrows must not switch filters")
        controller.close()
        pump(for: 0.2)
        print("PASS: Left/Right switch All, Links and Pinned, preserving search and vertical navigation")

        let fullText = String(repeating: "A complete line with a tab\tand a link https://example.com/details.\n", count: 700)
        let longItem = ClipboardEntry(content: fullText, title: "Full text preview")
        store.links = [longItem, ClipboardEntry(content: "https://example.com/second", title: "Second")]
        controller.state.linksOnly = false
        controller.state.favoritesOnly = false
        controller.open(keyboard: true)
        pump(for: 0.08)
        controller.state.selectedID = longItem.id
        let clipboardBeforePreview = pasteboard.string(forType: .string)
        let pastesBeforePreview = pasteHandler.pasted.count
        key(49, characters: " ")
        precondition(controller.state.previewID == longItem.id && !controller.state.focusSearch)
        guard let previewRoot = NSApp.keyWindow?.contentView,
              let preview = findPreview(in: previewRoot) else { preconditionFailure("Missing read-only native preview") }
        precondition(preview.string == fullText && !preview.isEditable && preview.isSelectable,
            "Full preview must retain every line and tab without editing")
        key(49, characters: " ", repeating: true)
        precondition(controller.state.previewID == longItem.id, "Held Space must not flicker the preview")
        key(49, characters: " ")
        precondition(controller.state.previewID == nil && controller.hasKeyboardFocus)
        precondition(pasteboard.string(forType: .string) == clipboardBeforePreview && pasteHandler.pasted.count == pastesBeforePreview,
            "Preview must not copy or paste")
        print("PASS: Space toggles a full, read-only preview and ignores key repeats")

        controller.state.query = "Full"
        pump(for: 0.05)
        controller.state.focusSearch = true
        pump(for: 0.03)
        key(49, characters: " ")
        precondition(controller.state.previewID == nil && controller.state.query.contains(" ") && controller.state.query.count == 5,
            "Typing a space in a search must not open preview")
        controller.state.query = ""
        pump(for: 0.04)
        key(125, characters: "\u{F701}")
        key(49, characters: " ")
        precondition(controller.state.previewID != nil)
        key(53, characters: "\u{1B}")
        precondition(controller.state.previewID == nil && controller.hasKeyboardFocus,
            "First Escape must close only the preview")
        controller.state.togglePreview(links: store.sorted)
        precondition(controller.state.previewID != nil)
        controller.state.togglePreview(links: store.sorted)
        precondition(controller.state.previewID == nil, "The visible button's toggle action must close preview on the second click")
        controller.close()
        pump(for: 0.2)
        print("PASS: search spaces, Escape and the preview button retain the expected behavior")
        let pixels = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        memset(pixels.bitmapData!, 255, pixels.bytesPerRow * 2)
        let png = pixels.representation(using: .png, properties: [:])!
        store.clearAll()
        store.captureImage(png, metadata: ClipboardImageCodec.inspect(png, type: .png))
        let imageEntry = store.links[0]
        controller.state.query = ""
        controller.state.favoritesOnly = false; controller.state.linksOnly = false
        controller.open(keyboard: false); pump(for: 0.12)
        controller.state.selectedID = imageEntry.id
        let boardVersion = pasteboard.changeCount
        key(49, characters: " ")
        precondition(controller.state.previewID == imageEntry.id && pasteboard.changeCount == boardVersion,
            "Image preview must open without replacing the clipboard")
        key(53, characters: "\u{1B}")
        precondition(controller.state.previewID == nil)
        key(36, characters: "\r"); pump(for: 0.2)
        precondition(pasteboard.data(forType: .png) == png, "Hover selection must restore exact PNG bytes")
        controller.open(keyboard: true); pump(for: 0.1)
        controller.state.focusSearch = false; controller.state.selectedID = imageEntry.id
        key(36, characters: "\r"); pump(for: 0.25)
        precondition(pasteHandler.entries.last?.image == imageEntry.image,
            "Shortcut selection must route the image payload through direct paste")
        precondition(pasteboard.data(forType: .png) == png)
        print("PASS: image Space/Escape preview, hover copy, and shortcut paste routing")
        inputWindow.orderOut(nil)
        print("PASS: interrupted close/reopen stays open and keyboard ready")
        print("All 17 native interaction checks passed. Paste dispatch was mocked; no system keys were posted.")
    }

    @MainActor static func key(_ code: UInt16, characters: String, modifiers: NSEvent.ModifierFlags = [], repeating: Bool = false) {
        guard let window = NSApp.keyWindow,
              let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, characters: characters, charactersIgnoringModifiers: characters,
                isARepeat: repeating, keyCode: code) else { preconditionFailure("No key window for test event") }
        // Send only through this test application's queue, never the system event stream.
        NSApp.postEvent(event, atStart: false)
        pump(for: 0.06)
    }

    @MainActor static func move(_ point: CGPoint) {
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        guard let quartz = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
            mouseCursorPosition: CGPoint(x: point.x, y: top - point.y), mouseButton: .left),
              let event = NSEvent(cgEvent: quartz) else { preconditionFailure("No test mouse event") }
        // Queue inside this process; never move the user's real pointer.
        NSApp.postEvent(event, atStart: false)
        pump(for: 0.025)
    }

    @MainActor static func findScroll(in view: NSView) -> ClipboardScrollContainer? {
        if let scroll = view as? ClipboardScrollContainer { return scroll }
        for child in view.subviews { if let scroll = findScroll(in: child) { return scroll } }
        return nil
    }
    @MainActor static func findPreview(in view: NSView) -> NSTextView? {
        if let text = view as? NSTextView, !text.isEditable && text.isSelectable { return text }
        for child in view.subviews { if let text = findPreview(in: child) { return text } }
        return nil
    }

    @MainActor static func pump(for interval: TimeInterval) {
        let deadline = Date().addingTimeInterval(interval)
        while Date() < deadline {
            if let event = NSApp.nextEvent(matching: .any, until: deadline, inMode: .default, dequeue: true) {
                NSApp.sendEvent(event)
            }
        }
    }
}

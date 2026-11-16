import AppKit
import SwiftUI
import Carbon
import Combine

private final class ClipboardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class ClipboardHostingView: NSHostingView<PanelView> {
    override var acceptsFirstResponder: Bool { true }
}

final class NotchController {
    let state = PanelState()
    private let store: ClipboardStore
    private var appEnabled: Bool
    private var enabledObserver: AnyCancellable?
    private var panel: NSPanel!
    var hasKeyboardFocus: Bool { panel.isKeyWindow }
    private var timer: Timer?
    private var keyMonitor: Any?
    private var clickMonitor: Any?
    private var localClickMonitor: Any?
    private var mouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var hoverIntent = HoverIntent()
    private var hoverTargets: [(screen: NSScreen, trigger: CGRect, identifier: String)] = []
    private var isClosing = false
    private var isTrackingMenu = false
    private var menuObservers: [NSObjectProtocol] = []
    private var outsideSince: Date?
    private var openedByKeyboard = false
    private var generation = 0
    private var activeScreen: NSScreen?
    private var activeGeometry: DisplayGeometry?
    private let geometryForScreen: (NSScreen) -> DisplayGeometry
    private var displayObserver: NSObjectProtocol?
    private var previousApp: NSRunningApplication?
    private let pasteHandler: PasteHandling
    private var pasteDestination: PasteDestination?
    var onSettings: (() -> Void)?
    var shortcutAvailable = true

    init(store: ClipboardStore, pasteHandler: PasteHandling = PasteService(),
         geometryForScreen: @escaping (NSScreen) -> DisplayGeometry = { DisplayGeometry(screen: $0) }) {
        self.store = store
        appEnabled = store.enabled
        self.pasteHandler = pasteHandler
        self.geometryForScreen = geometryForScreen
        panel = ClipboardPanel(contentRect: NSRect(x: 0, y: 0, width: PanelMetrics.canvasWidth, height: PanelMetrics.canvasHeight),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.acceptsMouseMovedEvents = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        let hostingView = ClipboardHostingView(rootView: PanelView(store: store, state: state))
        panel.contentView = hostingView
        panel.initialFirstResponder = hostingView
        state.choose = { [weak self] in self?.choose($0) }
        state.dismiss = { [weak self] in self?.close() }
        state.settings = { [weak self] in
            self?.close(restorePreviousApp: false)
            self?.onSettings?()
        }
        refreshHoverTargets()
        if appEnabled { startHoverTimer() }
        let movement: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: movement) { [weak self] event in
            self?.trackMouse(at: event.cgEvent?.unflippedLocation ?? NSEvent.mouseLocation)
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: movement) { [weak self] event in
            self?.trackMouse(at: event.cgEvent?.unflippedLocation ?? NSEvent.mouseLocation)
            return event
        }
        menuObservers = [
            NotificationCenter.default.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { [weak self] _ in
                self?.isTrackingMenu = true
            },
            NotificationCenter.default.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) { [weak self] _ in
                self?.isTrackingMenu = false
            }
        ]
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, !self.isClosing, self.state.phase > 0, self.panel.isKeyWindow,
                  event.window === self.panel, self.panel.attachedSheet == nil else { return event }
            switch event.keyCode {
            case 53:
                if self.state.previewID != nil { self.state.closePreview() }
                else { self.close() }
                return nil
            case 49:
                guard event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty else { return event }
                // Preserve literal spaces during search editing. Arrow navigation
                // switches Space back to preview without clearing the query.
                guard self.state.previewID != nil || !self.state.focusSearch ||
                        self.state.query.isEmpty || self.state.navigatingItems else { return event }
                if !event.isARepeat { self.state.togglePreview(links: self.store.sorted) }
                return nil
            case 125: self.state.move(1, links: self.store.sorted); return nil
            case 126: self.state.move(-1, links: self.store.sorted); return nil
            case 123, 124:
                // Plain horizontal arrows navigate tabs. Modified arrows retain
                // normal text selection and word/caret navigation in search.
                guard event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty else { return event }
                self.state.moveFilter(event.keyCode == 124 ? 1 : -1, links: self.store.sorted)
                return nil
            case 36, 76:
                let items = self.state.filtered(self.store.sorted)
                if let item = items.first(where: { $0.id == self.state.selectedID }) ?? items.first { self.choose(item) }
                return nil
            default: return event
            }
        }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.panel.isVisible, self.state.phase > 0 else { return }
            if !self.visibleRect.contains(NSEvent.mouseLocation) { self.close() }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self, self.panel.isVisible, self.state.phase > 0, event.window !== self.panel { self.close() }
            return event
        }
        if appEnabled { installHotKey() }
        enabledObserver = store.$enabled.dropFirst().removeDuplicates().sink { [weak self] enabled in
            self?.setAppEnabled(enabled)
        }
        displayObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
                self?.close()
                self?.hoverIntent.blockUntilExit()
                self?.refreshHoverTargets()
                self?.activeGeometry = nil
            }
    }
    deinit {
        timer?.invalidate()
        if let displayObserver { NotificationCenter.default.removeObserver(displayObserver) }
        for observer in menuObservers { NotificationCenter.default.removeObserver(observer) }
        for monitor in [keyMonitor, clickMonitor, localClickMonitor, mouseMonitor, localMouseMonitor].compactMap({ $0 }) { NSEvent.removeMonitor(monitor) }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
    private func startHoverTimer() {
        guard timer == nil else { return }
        let hoverTimer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.trackMouse() }
        hoverTimer.tolerance = 0.003
        RunLoop.main.add(hoverTimer, forMode: .common)
        timer = hoverTimer
    }
    private func installHotKey() {
        if eventHandler == nil { installHotKeyHandler() }
        guard hotKey == nil else { return }
        let id = EventHotKeyID(signature: 0x4e4c4e4b, id: 1)
        let result = RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(cmdKey | shiftKey), id,
            GetApplicationEventTarget(), 0, &hotKey)
        shortcutAvailable = result == noErr
    }
    private func installHotKeyHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let controller = Unmanaged<NotchController>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { controller.toggle() }
            return noErr
        }, 1, &spec, context, &eventHandler)
    }
    private func setAppEnabled(_ enabled: Bool) {
        appEnabled = enabled
        if enabled {
            hoverIntent = HoverIntent()
            startHoverTimer()
            installHotKey()
        } else {
            timer?.invalidate()
            timer = nil
            // Cancel opening, closing, and pending paste completions immediately.
            pasteHandler.cancel()
            generation += 1
            panel.orderOut(nil)
            panel.alphaValue = 1
            isClosing = false
            state.phase = 0
            state.opening = false
            state.focusSearch = false
            state.previewID = nil
            pasteDestination = nil
            outsideSince = nil
            hoverIntent = HoverIntent()
            if let hotKey { UnregisterEventHotKey(hotKey); self.hotKey = nil }
        }
    }
    func toggle() {
        guard appEnabled else { return }
        if state.phase == 2 && !isClosing { close() } else { open(keyboard: true) }
    }
    private var visibleRect: NSRect {
        return NSRect(x: panel.frame.minX + PanelMetrics.sidePadding, y: panel.frame.maxY - state.notchHeight - PanelMetrics.bodyHeight,
            width: PanelMetrics.width, height: state.notchHeight + PanelMetrics.bodyHeight)
    }
    private func refreshHoverTargets() {
        // Trigger geometry depends on the physical display, not Dock/menu-bar
        // visibility. Query those system APIs on display changes, not at 60Hz.
        hoverTargets = NSScreen.screens.map { screen in
            (screen, geometryForScreen(screen).hoverTrigger,
             String(describing: screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]))
        }
    }
    private func trackMouse(at pointer: CGPoint? = nil) {
        let point = pointer ?? NSEvent.mouseLocation
        guard appEnabled, !isTrackingMenu, panel.attachedSheet == nil else { return }
        let target = hoverTargets.first {
            point.x >= $0.trigger.minX && point.x <= $0.trigger.maxX &&
            point.y >= $0.trigger.minY && point.y <= $0.trigger.maxY
        }
        if isClosing {
            // Observe exit even during collapse. A genuine quick reentry reverses
            // the animation; staying over the camera after Escape does not loop.
            if hoverIntent.sample(trigger: target?.identifier), let target,
               !UserDefaults.standard.bool(forKey: "disableHover") {
                open(keyboard: false, screen: target.screen)
            }
            return
        }
        if panel.isVisible, state.phase > 0 {
            if state.previewID != nil { outsideSince = nil; return }
            if visibleRect.insetBy(dx: -14, dy: -14).contains(point) ||
                (!openedByKeyboard && activeGeometry?.keepsHoverOpen(at: point) == true) {
                outsideSince = nil
            } else if !openedByKeyboard && !state.focusSearch {
                if outsideSince == nil { outsideSince = Date() }
                if let since = outsideSince, Date().timeIntervalSince(since) > 0.24 { close() }
            }
            return
        }
        guard !UserDefaults.standard.bool(forKey: "disableHover") else { return }
        if hoverIntent.sample(trigger: target?.identifier), let target {
            open(keyboard: false, screen: target.screen)
        }
    }
    func open(keyboard: Bool, screen: NSScreen? = nil) {
        guard appEnabled else { return }
        pasteHandler.cancel()
        generation += 1
        let token = generation
        let wasVisible = panel.isVisible
        isClosing = false
        state.opening = true
        state.previewID = nil
        state.navigatingItems = false
        state.scrollSession = UUID()
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = frontmost
        }
        openedByKeyboard = keyboard
        // Remember where the user was typing before the picker takes focus. A
        // hover click pastes only into a real text insertion point; otherwise it
        // copies, so browsing from Finder or a web page never sends Command-V.
        let pasteOnClick = PanelState.pasteOnClickEnabled
        pasteDestination = keyboard || pasteOnClick ? pasteHandler.capture() : nil
        state.pastesSelection = keyboard
        if let destination = pasteDestination, keyboard || destination.selection != nil {
            state.pasteTarget = destination.app.localizedName ?? "the previous app"
        } else {
            state.pasteTarget = nil
        }
        state.pasteNeedsAccess = !keyboard && pasteOnClick && pasteDestination != nil && !pasteHandler.canPaste
        outsideSince = nil
        let anchor = pasteDestination?.caret ?? CGRect(origin: NSEvent.mouseLocation, size: .zero)
        let display = screen ?? NSScreen.screens.first(where: { $0.frame.contains(keyboard ? anchor.origin : NSEvent.mouseLocation) }) ?? NSScreen.main!
        activeScreen = display
        let geometry = geometryForScreen(display)
        activeGeometry = geometry
        state.detached = keyboard || geometry.notch == nil
        state.notchWidth = max(160, geometry.notch?.width ?? 190)
        state.notchHeight = keyboard ? 0 : geometry.notch?.height ?? 0
        state.query = ""
        state.message = nil
        state.selectedID = state.filtered(store.sorted).first?.id
        state.focusSearch = false
        panel.setFrameOrigin(keyboard ? PickerPlacement.origin(anchor: anchor, visibleFrame: display.visibleFrame) :
            geometry.hoverPanelOrigin)
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let fadeOnly = reduced || state.detached
        if !wasVisible { state.phase = fadeOnly ? 2 : 0 }
        panel.alphaValue = fadeOnly && !wasVisible ? 0 : 1
        panel.orderFrontRegardless()
        // Hover is an explicit keyboard handoff. Activate before making the panel
        // key so an insertion caret in another app cannot retain the arrow keys.
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(panel.contentView)
        if fadeOnly {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().alphaValue = 1
            }
        } else {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.92)) { state.phase = 2 }
        }
        if fadeOnly { state.phase = 2 }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.generation == token else { return }
            if keyboard {
                self.state.focusSearch = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.generation == token else { return }
            self.state.opening = false
        }
    }
    func close(restorePreviousApp: Bool = true, completion: (() -> Void)? = nil) {
        pasteHandler.cancel()
        guard panel.isVisible, !isClosing else { return }
        isClosing = true
        hoverIntent.blockUntilExit()
        generation += 1
        let token = generation
        let destination = previousApp
        state.focusSearch = false
        state.opening = false
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || state.detached
        if reduced {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().alphaValue = 0
            }
        } else {
            withAnimation(.easeInOut(duration: 0.16)) { state.phase = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduced ? 0.13 : 0.18)) { [weak self] in
            guard let self, self.generation == token else { return }
            self.panel.orderOut(nil)
            self.isClosing = false
            self.state.phase = 0
            self.state.previewID = nil
            self.panel.alphaValue = 1
            // An outside click may already have focused a different app. Restore
            // only while we still own activation, and never when opening Settings.
            if restorePreviousApp,
               NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier {
                destination?.activate(options: [])
            }
            completion?()
        }
    }

    private func choose(_ link: ClipboardEntry) {
        guard appEnabled, !isClosing else { return }
        guard store.copy(link) else { return }
        let destination = state.pastes(pasteOnClick: PanelState.pasteOnClickEnabled) ? pasteDestination : nil
        if let destination {
            close(restorePreviousApp: false) { [weak self] in
                guard let self, self.appEnabled else { return }
                let token = self.generation
                self.pasteHandler.paste(to: destination, entry: link) { [weak self] outcome in
                    guard let self, self.generation == token else { return }
                    if case .sent = outcome { return }
                    self.showPasteFallback(outcome)
                }
            }
            return
        }
        close()
        if let previousApp, previousApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp.activate(options: [])
        }
    }

    private func showPasteFallback(_ outcome: PasteOutcome) {
        let alert = NSAlert()
        if case .needsPermission = outcome {
            alert.messageText = "Enable direct paste"
            alert.informativeText = "Enable PasteReady in System Settings → Privacy & Security → Accessibility to paste directly into your previous text field. This item is already copied; you can paste it with Command–V."
            alert.addButton(withTitle: "Enable direct paste…")
            alert.addButton(withTitle: "Copy only")
        } else {
            alert.messageText = "Couldn’t paste automatically"
            alert.informativeText = "The original field or clipboard is no longer ready. Copy the item again from PasteReady, place your cursor where you want it, and press Command–V."
            alert.addButton(withTitle: "OK")
        }
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn, case .needsPermission = outcome { PasteService.enable() }
        else { previousApp?.activate(options: []) }
    }
}

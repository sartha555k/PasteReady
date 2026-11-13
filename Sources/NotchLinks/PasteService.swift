import AppKit
import ApplicationServices
import Carbon

struct PasteDestination {
    let app: NSRunningApplication
    var element: AXUIElement?
    var selection: AXValue?
    var caret: CGRect?
}

enum PasteOutcome { case sent, needsPermission, unavailable }

protocol PasteHandling: AnyObject {
    func capture() -> PasteDestination?
    func cancel()
    func paste(to destination: PasteDestination, content: String, completion: @escaping (PasteOutcome) -> Void)
}

final class PasteService: PasteHandling {
    private var request = 0
    static var isEnabled: Bool { AXIsProcessTrusted() }
    static func enable() {
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    func cancel() { request += 1 }
    func capture() -> PasteDestination? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        var destination = PasteDestination(app: app)
        guard Self.isEnabled else { return destination }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.15)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return destination }
        let element = unsafeBitCast(value, to: AXUIElement.self)
        destination.element = element
        var range: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &range) == .success,
           let range, CFGetTypeID(range) == AXValueGetTypeID() {
            let selection = unsafeBitCast(range, to: AXValue.self)
            destination.selection = selection
            var bounds: CFTypeRef?
            if AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString,
                selection, &bounds) == .success, let bounds, CFGetTypeID(bounds) == AXValueGetTypeID() {
                var rect = CGRect.zero
                if AXValueGetValue(unsafeBitCast(bounds, to: AXValue.self), .cgRect, &rect), rect.height > 0 {
                    // Accessibility uses a top-left origin; AppKit uses bottom-left.
                    let top = NSScreen.screens.first?.frame.maxY ?? 0
                    destination.caret = CGRect(x: rect.minX, y: top - rect.maxY, width: max(rect.width, 1), height: rect.height)
                }
            }
        }
        return destination
    }
    func paste(to destination: PasteDestination, content: String, completion: @escaping (PasteOutcome) -> Void) {
        cancel()
        let token = request
        let clipboardVersion = NSPasteboard.general.changeCount
        guard Self.isEnabled else { completion(.needsPermission); return }
        guard NSPasteboard.general.string(forType: .string) == content else { completion(.unavailable); return }
        guard !destination.app.isTerminated else { completion(.unavailable); return }
        destination.app.activate(options: [])
        let deadline = Date().addingTimeInterval(0.8)
        func attempt() {
            guard self.request == token else { return }
            guard NSPasteboard.general.changeCount == clipboardVersion else { completion(.unavailable); return }
            guard !destination.app.isTerminated else { completion(.unavailable); return }
            let active = NSWorkspace.shared.frontmostApplication
            let modifiers = CGEventSource.flagsState(.combinedSessionState)
                .intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
            if active?.processIdentifier == destination.app.processIdentifier && modifiers.isEmpty {
                if let element = destination.element {
                    let application = AXUIElementCreateApplication(destination.app.processIdentifier)
                    AXUIElementSetMessagingTimeout(application, 0.15)
                    var focused: CFTypeRef?
                    AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &focused)
                    // Never redirect a paste into a field the user switched to meanwhile.
                    guard let focused, CFEqual(focused, element) else { completion(.unavailable); return }
                    if let selection = destination.selection {
                        AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, selection)
                    }
                }
                guard let down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
                      let up = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else {
                    completion(.unavailable); return
                }
                down.flags = .maskCommand
                up.flags = .maskCommand
                down.postToPid(destination.app.processIdentifier)
                up.postToPid(destination.app.processIdentifier)
                completion(.sent)
            } else if Date() < deadline {
                // Abort if the user deliberately switches to an unrelated application.
                if let active, active.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                   active.processIdentifier != destination.app.processIdentifier {
                    completion(.unavailable); return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02, execute: attempt)
            } else { completion(.unavailable) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: attempt)
    }
}

// Keyboard pickers stay near the insertion point, with a pointer fallback for
// applications that don't expose caret geometry. The whole visible panel fits.
enum PickerPlacement {
    static func origin(anchor: CGRect, visibleFrame: CGRect) -> CGPoint {
        let width: CGFloat = 480, height: CGFloat = 468, margin: CGFloat = 10
        let x = min(max(anchor.minX, visibleFrame.minX + margin), visibleFrame.maxX - width - margin)
        let below = anchor.minY - 8 - height
        let y = below >= visibleFrame.minY + margin ? below : min(anchor.maxY + 8, visibleFrame.maxY - height - margin)
        // The hosting canvas has 30pt side padding and 102pt below the surface.
        return CGPoint(x: x - 30, y: max(visibleFrame.minY + margin, y) - 102)
    }
}

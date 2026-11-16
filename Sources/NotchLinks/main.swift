import AppKit
import Combine
import SwiftUI
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    var store: ClipboardStore!
    var controller: NotchController!
    var statusItem: NSStatusItem!
    var pauseItem: NSMenuItem!
    var openItem: NSMenuItem!
    var settingsWindow: NSWindow?
    private var pausedObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UserDefaults.standard.register(defaults: [PanelState.pasteOnClickKey: true])
        store = ClipboardStore()
        controller = NotchController(store: store)
        controller.onSettings = { [weak self] in self?.showSettings() }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "PasteReady")
        let menu = NSMenu()
        menu.autoenablesItems = false
        openItem = NSMenuItem(title: "Open clipboard", action: #selector(openPicker), keyEquivalent: "")
        openItem.target = self; menu.addItem(openItem)
        pauseItem = NSMenuItem(title: "Pause clipboard history", action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self; menu.addItem(pauseItem)
        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self; menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit PasteReady", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        statusItem.menu = menu
        // Pausing is easy to forget. Keep it visible in the menu bar until resumed.
        pausedObserver = store.$paused.combineLatest(store.$enabled).sink { [weak self] paused, enabled in
            self?.showStatus(paused: paused, enabled: enabled)
        }
        if !UserDefaults.standard.bool(forKey: "hasLaunched") || !UserDefaults.standard.bool(forKey: "hasShownDirectPasteSetup") {
            UserDefaults.standard.set(true, forKey: "hasLaunched")
            UserDefaults.standard.set(true, forKey: "hasShownDirectPasteSetup")
            showSettings()
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }
    @objc func openPicker() { controller.open(keyboard: true) }
    @objc func togglePause() { guard store.enabled else { return }; store.paused.toggle() }
    private func showStatus(paused: Bool, enabled: Bool) {
        openItem.isEnabled = enabled
        pauseItem.isEnabled = enabled
        pauseItem.title = paused ? "Resume clipboard history" : "Pause clipboard history"
        let symbol = !enabled ? "power" : paused ? "pause.circle" : "doc.on.clipboard"
        statusItem.button?.image = NSImage(systemSymbolName: symbol,
            accessibilityDescription: !enabled ? "PasteReady, disabled" : paused ? "PasteReady, paused" : "PasteReady")
        statusItem.button?.toolTip = !enabled ? "PasteReady is disabled. Open Settings to enable it."
            : paused ? "PasteReady is paused. New copies aren’t being saved." : nil
    }
    @objc func showSettings() {
        if settingsWindow == nil {
            let root = SettingsView(store: store, shortcutAvailable: controller.shortcutAvailable,
                shortcutAvailability: { [weak controller = self.controller] in controller?.shortcutAvailable ?? false })
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 690),
                styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "PasteReady"
            window.contentView = NSHostingView(rootView: root)
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}


let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

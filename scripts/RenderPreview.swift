import AppKit
import SwiftUI

@main
struct RenderPreview {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = ClipboardStore(file: directory.appendingPathComponent("unused-history.json"), monitoring: false)
        let state = PanelState()
        state.phase = 2
        store.links = [
            ClipboardEntry(content: "https://www.linkedin.com/in/your-profile/", title: "My LinkedIn", pinned: true),
            ClipboardEntry(content: "https://drive.google.com/drive/folders/portfolio", title: "Portfolio & résumé", pinned: true),
            ClipboardEntry(content: "https://github.com/your-name/project", title: "your-name/project"),
            ClipboardEntry(content: "Hi! Thanks for taking the time to review my application.", title: "A quick introduction"),
            ClipboardEntry(content: "https://docs.google.com/document/d/example/edit", title: "Google Doc")
        ]
        state.selectedID = store.links.first?.id
        try render(PanelView(store: store, state: state), size: NSSize(width: 540, height: 570), to: directory.appendingPathComponent("populated.png"))
        state.detached = true
        state.pastesSelection = true
        state.notchHeight = 0
        try render(PanelView(store: store, state: state), size: NSSize(width: 540, height: 570), to: directory.appendingPathComponent("shortcut.png"))
        state.pastesSelection = false
        try render(PanelView(store: store, state: state), size: NSSize(width: 540, height: 570), to: directory.appendingPathComponent("no-notch.png"))
        state.detached = false
        state.pastesSelection = false
        state.notchHeight = 32
        state.query = "no-match"
        try render(PanelView(store: store, state: state), size: NSSize(width: 540, height: 570), to: directory.appendingPathComponent("search-empty.png"))
        state.query = ""
        store.links = []
        try render(PanelView(store: store, state: state), size: NSSize(width: 540, height: 570), to: directory.appendingPathComponent("empty.png"))
        try render(SettingsView(store: store, shortcutAvailable: true), size: NSSize(width: 480, height: 630), to: directory.appendingPathComponent("settings.png"))
        print("Rendered six native SwiftUI states to \(directory.path)")
    }
    @MainActor static func render<V: View>(_ view: V, size: NSSize, to file: URL) throws {
        let host = NSHostingView(rootView: view.background(Color(red: 0.13, green: 0.15, blue: 0.18)).environment(\.colorScheme, .dark))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = host
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        window.display()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("No bitmap") }
        host.cacheDisplay(in: host.bounds, to: rep)
        try rep.representation(using: .png, properties: [:])!.write(to: file)
        window.orderOut(nil)
    }
}

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
        // Optional source image is used only for local review renders, never shipped in the app.
        if CommandLine.arguments.count > 2 {
            let source = URL(fileURLWithPath: CommandLine.arguments[2])
            guard let preview = ClipboardImageCodec.preview(at: source, maxSize: 1200),
                  let tiff = preview.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else { fatalError("Cannot load sample image") }
            store.captureImage(png, metadata: ClipboardImageCodec.inspect(png, type: .png))
            let image = store.links.first { $0.isImage }!
            store.rename(image, title: "Sample image")
            state.selectedID = image.id
            try render(PanelView(store: store, state: state), size: NSSize(width: 540, height: 570), to: directory.appendingPathComponent("image-list.png"))
            state.previewID = image.id
            try render(PanelView(store: store, state: state), size: NSSize(width: 540, height: 570), to: directory.appendingPathComponent("image-preview.png"))
            state.detached = true; state.notchHeight = 0; state.pastesSelection = true
            try render(PanelView(store: store, state: state), size: NSSize(width: 540, height: 570), to: directory.appendingPathComponent("image-shortcut.png"))
            state.previewID = nil; state.detached = false; state.notchHeight = 32; state.pastesSelection = false
        }
        state.selectedID = store.links.first?.id
        try render(PanelView(store: store, state: state), size: NSSize(width: 540, height: 570), to: directory.appendingPathComponent("populated.png"))
        state.previewID = store.links.first?.id
        try render(PanelView(store: store, state: state), size: NSSize(width: 540, height: 570), to: directory.appendingPathComponent("preview-link.png"))
        let example = ClipboardEntry(content: "Hello,\n\nI’m interested in the software engineer role. I enjoy building tools that make everyday work simpler, with careful attention to keyboard access and interaction quality.\n\nPortfolio: https://example.com/portfolio\nCode: https://github.com/your-name\n\nI’d welcome an opportunity to discuss the role and share more about my work.\n\nThank you for your time.", title: "Sample introduction")
        store.links.append(example)
        state.selectedID = example.id
        state.previewID = example.id
        try render(PanelView(store: store, state: state), size: NSSize(width: 540, height: 570), to: directory.appendingPathComponent("preview-text.png"))
        store.links.removeAll { $0.id == example.id }
        state.previewID = nil
        state.selectedID = store.links.first?.id
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
        print("Rendered eight native SwiftUI states to \(directory.path)")
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

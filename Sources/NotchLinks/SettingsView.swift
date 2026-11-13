import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var store: ClipboardStore
    let shortcutAvailable: Bool
    @AppStorage("disableHover") private var disableHover = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var confirmClear = false
    @State private var pasteEnabled = PasteService.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(systemName: "doc.on.clipboard").font(.system(size: 31, weight: .light))
                    .frame(width: 60, height: 60).background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 5) {
                    Text("PasteReady").font(.system(size: 23, weight: .semibold))
                    Text("Clipboard history, within reach.").foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Label("Copy text or a link anywhere on your Mac.", systemImage: "doc.on.doc")
                Label("Hover at the notch or top-center screen edge.", systemImage: "cursorarrow")
                Label("With ⌘⇧V, choose an item to paste at your cursor.", systemImage: "return")
            }.font(.system(size: 13)).foregroundStyle(.secondary)
            Divider()
            VStack(alignment: .leading, spacing: 15) {
                Toggle("Open at notch or top screen edge", isOn: Binding(get: { !disableHover }, set: { disableHover = !$0 }))
                Toggle("Pause clipboard history", isOn: $store.paused)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
                        catch { loginError = "Couldn’t update login settings. Try System Settings → General → Login Items."; launchAtLogin = SMAppService.mainApp.status == .enabled }
                    }
            }.toggleStyle(.switch).font(.system(size: 13))
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Direct paste").font(.system(size: 13, weight: .medium))
                    Text(pasteEnabled ? "Accessibility access enabled" : "Requires Accessibility access")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(pasteEnabled ? "Settings…" : "Enable…") { PasteService.enable() }
            }
            if !shortcutAvailable {
                Text("⌘⇧V is in use by another app. Open the picker from the menu bar, or disable the other app’s shortcut and restart PasteReady.")
                    .font(.caption).foregroundStyle(.orange)
            }
            if let loginError { Text(loginError).font(.caption).foregroundStyle(.orange) }
            VStack(alignment: .leading, spacing: 8) {
                Text("Local clipboard history").font(.system(size: 13, weight: .semibold))
                Text("Up to 20 recent text items, plus your pins. Stored on this Mac, with no network requests. Images and files aren’t captured. Items marked private by password managers are skipped.")
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text("If macOS asks to read your clipboard, choose Allow. You can change this in Privacy & Security → Paste from Other Apps.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            HStack {
                Text("\(store.links.count) saved items").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Clear recent") { store.clearRecent() }.disabled(store.links.allSatisfy(\.pinned))
                Button("Delete all…", role: .destructive) { confirmClear = true }.disabled(store.links.isEmpty)
            }
        }.padding(28).frame(width: 480, height: 630)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            pasteEnabled = PasteService.isEnabled
        }
        .alert("Delete all clipboard history?", isPresented: $confirmClear) {
            Button("Cancel", role: .cancel) {}
            Button("Delete all", role: .destructive) { store.clearAll() }
        } message: { Text("This also deletes pinned items. Your current system clipboard stays as it is.") }
    }
}


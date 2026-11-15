import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var store: ClipboardStore
    let shortcutAvailable: Bool
    @AppStorage("disableHover") private var disableHover = false
    @AppStorage(PanelState.pasteOnClickKey) private var pasteOnClick = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var confirmClear = false
    @State private var pasteEnabled = PasteService.isEnabled

    private func preference(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            Toggle(title, isOn: isOn).labelsHidden().accessibilityLabel(title)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(systemName: "doc.on.clipboard").font(.system(size: 27, weight: .regular))
                    .frame(width: 54, height: 54).background(.quaternary, in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 5) {
                    Text("PasteReady").font(.system(size: 24, weight: .semibold))
                    Text("Clipboard history, within reach.").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Label("Copy text, a link, or an image on your Mac.", systemImage: "doc.on.doc")
                Label("Hover at the notch or top-center screen edge.", systemImage: "cursorarrow")
                Label("Click an item, or use ⌘⇧V, to paste it at your cursor.", systemImage: "return")
            }.font(.system(size: 13)).foregroundStyle(.secondary)
            Divider()
            VStack(alignment: .leading, spacing: 14) {
                preference("Open at notch or top screen edge", isOn: Binding(get: { !disableHover }, set: { disableHover = !$0 }))
                VStack(alignment: .leading, spacing: 3) {
                    preference("Paste on click", isOn: $pasteOnClick)
                    Text(pasteOnClick ? "Clicking an item at the notch pastes it where your cursor was. With no text field active, it copies."
                         : "Clicking an item at the notch only copies it.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                preference("Pause clipboard history", isOn: $store.paused)
                preference("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
                        catch { loginError = "Couldn’t update login settings. Try System Settings → General → Login Items."; launchAtLogin = SMAppService.mainApp.status == .enabled }
                    }
            }.toggleStyle(.switch).font(.system(size: 13))
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
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
                Label("Local clipboard history", systemImage: "internaldrive").font(.system(size: 13, weight: .semibold))
                Text("Up to 20 recent copies, plus your pins. Text, links, and PNG/TIFF images up to 20 MB are stored on this Mac. File copies aren’t captured. Items marked private by password managers are skipped.")
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
        }.padding(28).frame(width: 480, height: 690)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            pasteEnabled = PasteService.isEnabled
        }
        .alert("Delete all clipboard history?", isPresented: $confirmClear) {
            Button("Cancel", role: .cancel) {}
            Button("Delete all", role: .destructive) { store.clearAll() }
        } message: { Text("This also deletes pinned items. Your current system clipboard stays as it is.") }
    }
}


import SwiftUI
import AppKit

final class PanelState: ObservableObject {
    @Published var phase = 0
    @Published var query = ""
    @Published var favoritesOnly = false
    @Published var linksOnly = false
    @Published var selectedID: UUID?
    @Published var focusSearch = false
    @Published var message: String?
    @Published var notchWidth: CGFloat = 190
    @Published var notchHeight: CGFloat = 32
    @Published var detached = false
    @Published var pastesSelection = false
    @Published var opening = false
    @Published var scrollSession = UUID()
    @Published var previewID: UUID?
    @Published var navigatingItems = false
    /// App that a choice pastes into. Hover sets it only when that app had a
    /// text insertion point; the shortcut always targets the captured app.
    @Published var pasteTarget: String?
    /// Paste on click is on, but Accessibility access is missing.
    @Published var pasteNeedsAccess = false
    static let pasteOnClickKey = "pasteOnClick"
    static var pasteOnClickEnabled: Bool { UserDefaults.standard.object(forKey: pasteOnClickKey) as? Bool ?? true }
    /// Whether clicking a row or pressing Return pastes rather than only copies.
    func pastes(pasteOnClick: Bool) -> Bool { pastesSelection || (pasteOnClick && pasteTarget != nil) }
    private var searchFocusBeforePreview = false
    var choose: ((ClipboardEntry) -> Void)?
    var dismiss: (() -> Void)?
    var settings: (() -> Void)?
    var filtered: ([ClipboardEntry]) -> [ClipboardEntry] {
        { links in links.filter {
            (!self.favoritesOnly || $0.pinned) && (!self.linksOnly || $0.isLink) &&
            (self.query.isEmpty || "\($0.title) \($0.content)".localizedCaseInsensitiveContains(self.query))
        } }
    }
    func move(_ offset: Int, links: [ClipboardEntry]) {
        let items = filtered(links)
        guard !items.isEmpty else { return }
        let current = items.firstIndex { $0.id == selectedID } ?? (offset > 0 ? -1 : items.count)
        selectedID = items[min(max(current + offset, 0), items.count - 1)].id
        navigatingItems = true
        if previewID != nil { previewID = selectedID }
    }
    func moveFilter(_ offset: Int, links: [ClipboardEntry]) {
        let current = favoritesOnly ? 2 : linksOnly ? 1 : 0
        let next = min(max(current + offset, 0), 2)
        guard next != current else { return }
        if previewID != nil { closePreview() }
        favoritesOnly = next == 2
        linksOnly = next == 1
        selectedID = filtered(links).first?.id
        scrollSession = UUID()
        navigatingItems = true
    }
    func togglePreview(links: [ClipboardEntry]) {
        if previewID != nil { closePreview(); return }
        let items = filtered(links)
        guard let item = items.first(where: { $0.id == selectedID }) ?? items.first else { return }
        searchFocusBeforePreview = focusSearch
        focusSearch = false
        navigatingItems = true
        selectedID = item.id
        previewID = item.id
    }
    func closePreview() {
        guard previewID != nil else { return }
        previewID = nil
        focusSearch = searchFocusBeforePreview
    }
}

struct PanelView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var state: PanelState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var searchFocused: Bool
    @State private var hoveredID: UUID?
    @State private var editing: ClipboardEntry?
    @State private var editedTitle = ""
    @AppStorage(PanelState.pasteOnClickKey) private var pasteOnClick = true

    private var items: [ClipboardEntry] { state.filtered(store.sorted) }
    private var previewItem: ClipboardEntry? { items.first { $0.id == state.previewID } }
    private var expanded: Bool { state.phase == 2 }
    private var pastes: Bool { state.pastes(pasteOnClick: pasteOnClick) }
    private var surfaceHeight: CGFloat { PanelMetrics.bodyHeight + state.notchHeight }
    private var shapeWidth: CGFloat { expanded ? PanelMetrics.width : state.notchWidth }
    private var shapeHeight: CGFloat { expanded ? surfaceHeight : state.notchHeight }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                silhouette.fill(.black)
                    .frame(width: shapeWidth, height: shapeHeight)
                    .shadow(color: .black.opacity(expanded ? 0.32 : 0), radius: 24, x: 0, y: 14)
                // Keep text and controls at their final size throughout the reveal.
                // Only the silhouette and its mask resize, avoiding list construction
                // and repeated text layout on the opening animation's critical path.
                VStack(spacing: 0) {
                    Color.clear.frame(height: state.notchHeight + 10)
                    content.opacity(expanded ? 1 : 0)
                        .offset(y: expanded || reduceMotion ? 0 : -3)
                    Spacer(minLength: 0)
                }
                .frame(width: PanelMetrics.width, height: surfaceHeight, alignment: .top)
                .mask(alignment: .top) {
                    silhouette.frame(width: shapeWidth, height: shapeHeight)
                }
                .allowsHitTesting(expanded)
                .accessibilityHidden(!expanded)
            }
            .frame(width: PanelMetrics.width, height: surfaceHeight, alignment: .top)
            Spacer(minLength: 0)
        }
        .frame(width: PanelMetrics.canvasWidth, height: PanelMetrics.canvasHeight, alignment: .top)
        .preferredColorScheme(.dark)
        .onChange(of: state.focusSearch) { _, value in searchFocused = value }
        .onChange(of: searchFocused) { _, value in state.focusSearch = value }
        .onChange(of: state.query) { _, _ in
            state.closePreview()
            state.navigatingItems = false
            state.selectedID = items.first?.id
        }
        .onChange(of: state.linksOnly) { _, _ in state.closePreview(); state.selectedID = items.first?.id }
        .onChange(of: state.favoritesOnly) { _, _ in state.closePreview(); state.selectedID = items.first?.id }
        .onChange(of: items.map(\.id)) { _, ids in
            if !ids.contains(state.selectedID ?? UUID()) { state.selectedID = ids.first }
            if let id = state.previewID, !ids.contains(id) { state.closePreview() }
        }
        .alert("Rename item", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
            TextField("Name", text: $editedTitle)
            Button("Cancel", role: .cancel) { editing = nil }
            Button("Save") { if let link = editing { store.rename(link, title: editedTitle) }; editing = nil }
        } message: { Text("Give this item a name you’ll recognize.") }
    }

    private var silhouette: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: state.detached ? 22 : 9, bottomLeadingRadius: expanded ? 22 : 15,
            bottomTrailingRadius: expanded ? 22 : 15, topTrailingRadius: state.detached ? 22 : 9)
    }

    private var content: some View {
        VStack(spacing: 0) {
            header.padding(.bottom, 8)
            filterBar.padding(.bottom, 8)
            if let error = store.storageError {
                Label(error, systemImage: "exclamationmark.triangle").font(.system(size: 11))
                    .foregroundStyle(.orange).padding(.bottom, 10)
            } else if store.clipboardDenied {
                Button("Allow clipboard access in System Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Pasteboard")!)
                }.font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(.orange).padding(.bottom, 10)
            }
            // While paused, an empty or unchanged list looks like a broken app.
            // Say so where people look for their copies, with a way out.
            if store.paused { pausedNotice.padding(.bottom, 10) }
            if let notice = store.captureNotice {
                HStack(alignment: .top, spacing: 8) {
                    Text(notice).font(.system(size: 11)).foregroundStyle(.orange)
                    Spacer(minLength: 0)
                    Button { store.captureNotice = nil } label: { Image(systemName: "xmark").frame(width: 22, height: 22) }
                        .buttonStyle(PanelIconButtonStyle()).accessibilityLabel("Dismiss clipboard notice")
                }.padding(.bottom, 8)
            }
            ZStack {
                if items.isEmpty { emptyState }
                else {
                    ClipboardScrollView(ids: items.map(\.id), selectedID: state.selectedID,
                        session: state.scrollSession, reduceMotion: reduceMotion) {
                        VStack(spacing: PanelMetrics.rowSpacing) {
                            ForEach(items) { link in row(link).frame(height: PanelMetrics.rowHeight) }
                        }
                    }
                    .opacity(previewItem == nil ? 1 : 0)
                    .allowsHitTesting(previewItem == nil)
                    .accessibilityHidden(previewItem != nil)
                }
                if let link = previewItem { fullPreview(link) }
            }.frame(maxHeight: .infinity).padding(.bottom, 8)
            footer
        }
        .padding(.horizontal, 14).padding(.bottom, 12)
        .frame(width: PanelMetrics.width, height: PanelMetrics.bodyHeight - 10)
    }
    /// Search leads: the app's name and item count fold into the field itself.
    private var header: some View {
        HStack(spacing: 6) {
            searchField
            Button { state.settings?() } label: {
                Image(systemName: "gearshape").font(.system(size: 13)).frame(width: 30, height: 32)
            }.buttonStyle(PanelIconButtonStyle()).foregroundStyle(PanelPalette.secondary).help("PasteReady settings")
                .accessibilityLabel("Open settings")
        }
    }
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 12, weight: .medium))
                .foregroundStyle(searchFocused ? PanelPalette.accent : PanelPalette.secondary)
            TextField(store.links.isEmpty ? "Search clipboard" : "Search \(store.links.count) \(store.links.count == 1 ? "item" : "items")", text: $state.query)
                .textFieldStyle(.plain).font(.system(size: 12.5)).focused($searchFocused)
                .onSubmit { chooseSelected() }.accessibilityLabel("Search clipboard")
            if !state.query.isEmpty {
                Button { state.query = "" } label: {
                    Image(systemName: "xmark.circle.fill").frame(width: 22, height: 22)
                }.buttonStyle(PanelIconButtonStyle()).foregroundStyle(PanelPalette.secondary).accessibilityLabel("Clear search")
            } else if !searchFocused { PanelKeycap(key: "⌘⇧V") }
        }
        .padding(.horizontal, 10).frame(height: 32)
        .background(PanelPalette.field, in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9).strokeBorder(searchFocused ? PanelPalette.selectionEdge : .white.opacity(0.075), lineWidth: 0.7)
        }
    }
    private var filterBar: some View {
        HStack(spacing: 5) {
            HStack(spacing: 1) {
                filterButton("All", favorites: false)
                Button { state.favoritesOnly = false; state.linksOnly.toggle() } label: {
                    filterLabel("Links", selected: state.linksOnly)
                }.buttonStyle(.plain).accessibilityAddTraits(state.linksOnly ? .isSelected : [])
                filterButton("Pinned", favorites: true)
            }.padding(2).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
            Spacer(minLength: 6)
            // The shortcut always pastes; the toggle governs hover clicks.
            if !state.pastesSelection { pasteToggle }
        }.foregroundStyle(PanelPalette.hint)
    }
    private var pasteToggle: some View {
        Button { pasteOnClick.toggle() } label: {
            HStack(spacing: 5) {
                Image(systemName: "text.cursor").font(.system(size: 10, weight: .semibold))
                Text("Paste on click").font(.system(size: 10.5, weight: .medium))
                Capsule().fill(pasteOnClick ? PanelPalette.accent : .white.opacity(0.18))
                    .frame(width: 20, height: 12)
                    .overlay(alignment: pasteOnClick ? .trailing : .leading) {
                        Circle().fill(.white).frame(width: 9, height: 9).padding(.horizontal, 1.5)
                    }
            }
            .foregroundStyle(pasteOnClick ? .white.opacity(0.85) : PanelPalette.hint)
            .padding(.horizontal, 8).frame(height: 22)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .help(pasteOnClick ? "Clicking an item pastes it where your cursor was. Click to copy only." : "Clicking an item copies it. Click to paste where your cursor was.")
        .accessibilityLabel("Paste on click")
        .accessibilityValue(pasteOnClick ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }
    /// Footer always says what Return or a click will do, and where.
    private var actionHint: String {
        if pastes { return "Paste into \(state.pasteTarget ?? "your app")" }
        if !state.pastesSelection && pasteOnClick && state.pasteNeedsAccess { return "Copy · allow Accessibility to paste" }
        return "Copy"
    }
    private var footer: some View {
        HStack(spacing: 9) {
            if let message = state.message {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(.green)
                Text(message).font(.system(size: 10.5)).foregroundStyle(PanelPalette.secondary)
            } else {
                PanelKeycap(key: "arrow.up.arrow.down", symbol: true)
                PanelShortcut(key: "return", title: actionHint, symbol: true)
            }
            Spacer(minLength: 4)
            Button { state.togglePreview(links: store.sorted) } label: {
                PanelShortcut(key: "Space", title: state.previewID == nil ? "Preview" : "Close")
            }.buttonStyle(.plain).disabled(items.isEmpty)
                .help(state.previewID == nil ? "Show full preview" : "Close full preview")
                .accessibilityLabel(state.previewID == nil ? "Show full preview" : "Close full preview")
            PanelShortcut(key: "esc", title: state.previewID == nil ? "Close" : "Back")
        }
    }
    private func fullPreview(_ link: ClipboardEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: link.symbol).foregroundStyle(PanelPalette.accent)
                Text(link.title).font(.system(size: 13, weight: .medium)).lineLimit(2)
                Spacer(minLength: 5)
                Button(pastes ? "Paste" : "Copy") { state.choose?(link) }
                    .buttonStyle(.plain).font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                Button { state.closePreview() } label: {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).frame(width: 28, height: 28)
                }.buttonStyle(PanelIconButtonStyle()).foregroundStyle(PanelPalette.secondary).accessibilityLabel("Close full preview")
            }
            Group {
                if link.isImage {
                    VStack(spacing: 6) {
                        if let image = store.imagePreview(link, fullSize: true) {
                            Image(nsImage: image).resizable().scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .accessibilityLabel("Full image preview: \(link.title)")
                            Text(link.preview).font(.system(size: 10.5)).foregroundStyle(PanelPalette.secondary)
                        } else {
                            Image(systemName: "photo").font(.system(size: 24)).foregroundStyle(PanelPalette.secondary)
                            Text("Image unavailable").font(.system(size: 13, weight: .medium))
                            Text("Copy the original image again.").font(.system(size: 11)).foregroundStyle(PanelPalette.secondary)
                        }
                    }.padding(10).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else { ClipboardPreviewText(id: link.id, text: link.content) }
            }
                .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(.black)
    }
    private func filterButton(_ name: String, favorites: Bool) -> some View {
        Button { state.favoritesOnly = favorites; state.linksOnly = false } label: {
            filterLabel(name, selected: state.favoritesOnly == favorites && !state.linksOnly)
        }.buttonStyle(.plain).accessibilityAddTraits(state.favoritesOnly == favorites && !state.linksOnly ? .isSelected : [])
    }
    private func filterLabel(_ title: String, selected: Bool) -> some View {
        Text(title).font(.system(size: 11, weight: .medium))
            .foregroundStyle(selected ? .white : PanelPalette.secondary)
            .padding(.horizontal, 10).frame(height: 20)
            .background(.white.opacity(selected ? 0.11 : 0), in: RoundedRectangle(cornerRadius: 6))
    }
    private func row(_ link: ClipboardEntry) -> some View {
        let selected = state.selectedID == link.id
        return HStack(spacing: 4) {
            // The row is the primary action: paste when a target is ready, else copy.
            Button { state.choose?(link) } label: {
                HStack(spacing: 9) {
                    Group {
                        if link.isImage, let thumbnail = store.imagePreview(link) {
                            Image(nsImage: thumbnail).resizable().scaledToFit().padding(2)
                        } else {
                            Image(systemName: link.symbol).font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(selected ? PanelPalette.accent : .white.opacity(0.72))
                        }
                    }
                    .frame(width: 28, height: 28)
                    .background(selected ? PanelPalette.accent.opacity(0.09) : .white.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(link.title).font(.system(size: 12.5, weight: .medium)).lineLimit(1)
                        Text(link.preview).font(.system(size: 10)).foregroundStyle(.white.opacity(selected ? 0.72 : 0.56))
                            .lineLimit(1).truncationMode(.middle)
                    }
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).help(pastes ? "Paste into \(state.pasteTarget ?? "your app")" : "Copy")
                .accessibilityLabel("\(link.title), \(link.isImage ? link.preview : link.content)")
                .accessibilityHint(pastes ? "Pastes into \(state.pasteTarget ?? "your app")" : "Copies to the clipboard")
            // Always copy-only, so there's a way to copy without pasting.
            Button { if store.copy(link) { state.message = "Copied to clipboard" } } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11)).frame(width: 26, height: 28).foregroundStyle(.white.opacity(0.72))
            }.buttonStyle(PanelIconButtonStyle()).help("Copy only")
                .accessibilityLabel("Copy \(link.title)")
            Button { store.togglePin(link) } label: {
                Image(systemName: link.pinned ? "pin.fill" : "pin").font(.system(size: 10))
                    .frame(width: 24, height: 28)
                    .foregroundStyle(.white.opacity(link.pinned ? 0.72 : hoveredID == link.id || selected ? 0.55 : 0))
            }.buttonStyle(PanelIconButtonStyle()).help(link.pinned ? "Unpin item" : "Pin item")
                .accessibilityLabel(link.pinned ? "Unpin \(link.title)" : "Pin \(link.title)")
        }
        .padding(.horizontal, 7).padding(.vertical, 7)
        .background(selected ? PanelPalette.selection : .white.opacity(hoveredID == link.id ? 0.045 : 0),
            in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? PanelPalette.selectionEdge : .clear, lineWidth: 0.7)
                .allowsHitTesting(false)
        }
        .onHover { over in hoveredID = over ? link.id : nil }
        .contextMenu {
            Button("Copy item") { if store.copy(link) { state.message = "Copied to clipboard" } }
            Button(link.pinned ? "Unpin" : "Pin") { store.togglePin(link) }
            Button("Rename…") { editedTitle = link.title; editing = link }
            Divider()
            Button("Delete item", role: .destructive) { store.remove(link) }
        }
    }
    private var pausedNotice: some View {
        HStack(spacing: 8) {
            Label("Paused. New copies aren’t being saved.", systemImage: "pause.circle.fill")
                .font(.system(size: 11)).foregroundStyle(.orange)
            Spacer(minLength: 0)
            Button("Resume") { store.paused = false }
                .buttonStyle(.plain).font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
                .help("Resume clipboard history")
                .accessibilityLabel("Resume clipboard history")
        }
    }
    private var emptyMessage: (symbol: String, title: String, detail: String) {
        if !state.query.isEmpty { return ("magnifyingglass", "No matching items", "Try a different word or part of the address.") }
        if state.favoritesOnly { return ("pin", "No pinned items", "Pin an item from All to keep it close.") }
        // Never promise that new copies will be waiting while capture is off.
        if store.paused { return ("pause.circle", "Clipboard history is paused", "Copies you make now aren’t saved.\nResume to start saving them again.") }
        if state.linksOnly { return ("doc.on.clipboard", "No links yet", "Copy a web address to find it here.\nYour other copies stay in All.") }
        return ("doc.on.clipboard", "No clipboard history yet", "Copy text, a link, or an image.\nIt’ll be waiting here when you need it.")
    }
    private var emptyState: some View {
        let message = emptyMessage
        return VStack(spacing: 9) {
            Spacer()
            Image(systemName: message.symbol)
                .font(.system(size: 24, weight: .light)).foregroundStyle(.white.opacity(0.7))
            Text(message.title)
                .font(.system(size: 14.5, weight: .medium))
            Text(message.detail)
                .font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center).lineSpacing(3)
            Spacer()
        }.frame(maxWidth: .infinity)
    }
    private func chooseSelected() {
        if let link = items.first(where: { $0.id == state.selectedID }) ?? items.first { state.choose?(link) }
    }
}

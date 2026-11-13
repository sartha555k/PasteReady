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

    private var items: [ClipboardEntry] { state.filtered(store.sorted) }
    private var previewItem: ClipboardEntry? { items.first { $0.id == state.previewID } }
    private var expanded: Bool { state.phase == 2 }
    private var shapeWidth: CGFloat { expanded ? 480 : state.notchWidth }
    private var shapeHeight: CGFloat { expanded ? 468 + state.notchHeight : state.notchHeight }

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
                    Color.clear.frame(height: state.notchHeight + 13)
                    content.opacity(expanded ? 1 : 0)
                        .offset(y: expanded || reduceMotion ? 0 : -3)
                    Spacer(minLength: 0)
                }
                .frame(width: 480, height: 468 + state.notchHeight, alignment: .top)
                .mask(alignment: .top) {
                    silhouette.frame(width: shapeWidth, height: shapeHeight)
                }
                .allowsHitTesting(expanded)
                .accessibilityHidden(!expanded)
            }
            .frame(width: 480, height: 468 + state.notchHeight, alignment: .top)
            Spacer(minLength: 0)
        }
        .frame(width: 540, height: 570, alignment: .top)
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
        } message: { Text("Give this link a name you’ll recognize.") }
    }

    private var silhouette: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: state.detached ? 28 : 9, bottomLeadingRadius: expanded ? 28 : 15,
            bottomTrailingRadius: expanded ? 28 : 15, topTrailingRadius: state.detached ? 28 : 9)
    }

    private var content: some View {
        VStack(spacing: 0) {
            header.padding(.bottom, 16)
            searchField.padding(.bottom, 12)
            filterBar.padding(.bottom, 12)
            if let error = store.storageError {
                Label(error, systemImage: "exclamationmark.triangle").font(.system(size: 11))
                    .foregroundStyle(.orange).padding(.bottom, 10)
            } else if store.clipboardDenied {
                Button("Allow clipboard access in System Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Pasteboard")!)
                }.font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(.orange).padding(.bottom, 10)
            }
            ZStack {
                if items.isEmpty { emptyState }
                else {
                    ClipboardScrollView(ids: items.map(\.id), selectedID: state.selectedID,
                        session: state.scrollSession, reduceMotion: reduceMotion) {
                        VStack(spacing: 3) {
                            ForEach(items) { link in row(link).frame(height: 52) }
                        }
                    }
                    .opacity(previewItem == nil ? 1 : 0)
                    .allowsHitTesting(previewItem == nil)
                    .accessibilityHidden(previewItem != nil)
                }
                if let link = previewItem { fullPreview(link) }
            }.frame(maxHeight: .infinity).padding(.bottom, 12)
            footer
        }
        .padding(.horizontal, 22).padding(.bottom, 18)
        .frame(width: 480, height: 448)
    }
    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard").font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.85)).frame(width: 34, height: 34)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text("PasteReady").font(.system(size: 19, weight: .semibold)).tracking(-0.35)
                Text("Clipboard history").font(.system(size: 10.5)).foregroundStyle(PanelPalette.secondary)
            }
            Spacer()
            Text("\(store.links.count) \(store.links.count == 1 ? "item" : "items")")
                .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(PanelPalette.secondary)
                .padding(.trailing, 5)
            if store.paused {
                Image(systemName: "pause.circle.fill").foregroundStyle(.orange).help("Clipboard capture paused")
            }
            Button { state.settings?() } label: {
                Image(systemName: "gearshape").font(.system(size: 14)).frame(width: 30, height: 30)
            }.buttonStyle(PanelIconButtonStyle()).foregroundStyle(PanelPalette.secondary).help("Settings")
                .accessibilityLabel("Open settings")
        }
    }
    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").font(.system(size: 13, weight: .medium))
                .foregroundStyle(searchFocused ? PanelPalette.accent : PanelPalette.secondary)
            TextField("Search your clipboard", text: $state.query)
                .textFieldStyle(.plain).font(.system(size: 13)).focused($searchFocused)
                .onSubmit { chooseSelected() }.accessibilityLabel("Search clipboard")
            if !state.query.isEmpty {
                Button { state.query = "" } label: {
                    Image(systemName: "xmark.circle.fill").frame(width: 24, height: 24)
                }.buttonStyle(PanelIconButtonStyle()).foregroundStyle(PanelPalette.secondary).accessibilityLabel("Clear search")
            } else if !searchFocused { PanelKeycap(key: "⌘⇧V") }
        }
        .padding(.horizontal, 12).frame(height: 40)
        .background(PanelPalette.field, in: RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11).strokeBorder(searchFocused ? PanelPalette.selectionEdge : .white.opacity(0.075), lineWidth: 0.7)
        }
    }
    private var filterBar: some View {
        HStack(spacing: 5) {
            HStack(spacing: 2) {
                filterButton("All", favorites: false)
                Button { state.favoritesOnly = false; state.linksOnly.toggle() } label: {
                    filterLabel("Links", selected: state.linksOnly)
                }.buttonStyle(.plain).accessibilityAddTraits(state.linksOnly ? .isSelected : [])
                filterButton("Pinned", favorites: true)
            }.padding(3).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
            Spacer()
            Image(systemName: "internaldrive").font(.system(size: 10))
            Text("On this Mac").font(.system(size: 10.5))
        }.foregroundStyle(PanelPalette.hint)
    }
    private var footer: some View {
        HStack(spacing: 10) {
            if let message = state.message {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text(message).font(.system(size: 10.5)).foregroundStyle(PanelPalette.secondary)
            } else {
                PanelShortcut(key: "arrow.up.arrow.down", title: "Navigate", symbol: true)
                PanelShortcut(key: "return", title: state.pastesSelection ? "Paste" : "Copy", symbol: true)
            }
            Spacer(minLength: 4)
            Button { state.togglePreview(links: store.sorted) } label: {
                PanelShortcut(key: "Space", title: state.previewID == nil ? "Preview" : "Close preview")
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
                Button(state.pastesSelection ? "Paste" : "Copy") { state.choose?(link) }
                    .buttonStyle(.plain).font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                Button { state.closePreview() } label: {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).frame(width: 28, height: 28)
                }.buttonStyle(PanelIconButtonStyle()).foregroundStyle(PanelPalette.secondary).accessibilityLabel("Close full preview")
            }
            ClipboardPreviewText(id: link.id, text: link.content)
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
        Text(title).font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(selected ? .white : PanelPalette.secondary)
            .padding(.horizontal, 13).frame(height: 25)
            .background(.white.opacity(selected ? 0.11 : 0), in: RoundedRectangle(cornerRadius: 7))
    }
    private func row(_ link: ClipboardEntry) -> some View {
        let selected = state.selectedID == link.id
        return HStack(spacing: 10) {
            Button { state.choose?(link) } label: {
                HStack(spacing: 11) {
                    Image(systemName: link.symbol).font(.system(size: 15, weight: .medium))
                        .foregroundStyle(selected ? PanelPalette.accent : .white.opacity(0.72))
                        .frame(width: 32, height: 32)
                        .background(selected ? PanelPalette.accent.opacity(0.09) : .white.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(link.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                        Text(link.preview).font(.system(size: 10.5)).foregroundStyle(.white.opacity(selected ? 0.72 : 0.58))
                            .lineLimit(1).truncationMode(.middle)
                    }
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("\(link.title), \(link.content)")
            Button {
                if state.pastesSelection { state.choose?(link) }
                else { store.copy(link); state.message = "Copied to clipboard" }
            } label: {
                Image(systemName: state.pastesSelection ? "arrow.turn.down.left" : "doc.on.doc")
                    .font(.system(size: 12)).frame(width: 28, height: 30).foregroundStyle(.white.opacity(0.76))
            }.buttonStyle(PanelIconButtonStyle()).help(state.pastesSelection ? "Paste item" : "Copy item")
                .accessibilityLabel("\(state.pastesSelection ? "Paste" : "Copy") \(link.title)")
            Button { store.togglePin(link) } label: {
                Image(systemName: link.pinned ? "pin.fill" : "pin").font(.system(size: 11))
                    .frame(width: 26, height: 30)
                    .foregroundStyle(.white.opacity(link.pinned ? 0.72 : hoveredID == link.id || selected ? 0.55 : 0))
            }.buttonStyle(PanelIconButtonStyle()).help(link.pinned ? "Unpin link" : "Pin link")
                .accessibilityLabel(link.pinned ? "Unpin \(link.title)" : "Pin \(link.title)")
        }
        .padding(.horizontal, 9).padding(.vertical, 10)
        .background(selected ? PanelPalette.selection : .white.opacity(hoveredID == link.id ? 0.045 : 0),
            in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? PanelPalette.selectionEdge : .clear, lineWidth: 0.7)
                .allowsHitTesting(false)
        }
        .onHover { over in hoveredID = over ? link.id : nil }
        .contextMenu {
            Button("Copy item") { store.copy(link); state.message = "Copied to clipboard" }
            Button(link.pinned ? "Unpin" : "Pin") { store.togglePin(link) }
            Button("Rename…") { editedTitle = link.title; editing = link }
            Divider()
            Button("Delete item", role: .destructive) { store.remove(link) }
        }
    }
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: state.query.isEmpty ? (state.favoritesOnly ? "pin" : "doc.on.clipboard") : "magnifyingglass")
                .font(.system(size: 29, weight: .light)).foregroundStyle(.white.opacity(0.7))
            Text(state.query.isEmpty ? (state.favoritesOnly ? "No pinned items" : state.linksOnly ? "No links yet" : "No clipboard history yet") : "No matching items")
                .font(.system(size: 16, weight: .medium))
            Text(state.query.isEmpty ? (state.favoritesOnly ? "Pin an item from All to keep it close." : state.linksOnly ? "Copy a web address to find it here.\nYour other text stays in All." : "Copy a profile link, a note, or any text.\nIt’ll be waiting here when you need it.") : "Try a different word or part of the address.")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center).lineSpacing(4)
            Spacer()
        }.frame(maxWidth: .infinity)
    }
    private func chooseSelected() {
        if let link = items.first(where: { $0.id == state.selectedID }) ?? items.first { state.choose?(link) }
    }
}

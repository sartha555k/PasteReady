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
    }
    func moveFilter(_ offset: Int, links: [ClipboardEntry]) {
        let current = favoritesOnly ? 2 : linksOnly ? 1 : 0
        let next = min(max(current + offset, 0), 2)
        guard next != current else { return }
        favoritesOnly = next == 2
        linksOnly = next == 1
        selectedID = filtered(links).first?.id
        scrollSession = UUID()
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
        .onChange(of: state.query) { _, _ in state.selectedID = items.first?.id }
        .onChange(of: state.linksOnly) { _, _ in state.selectedID = items.first?.id }
        .onChange(of: state.favoritesOnly) { _, _ in state.selectedID = items.first?.id }
        .onChange(of: items.map(\.id)) { _, ids in
            if !ids.contains(state.selectedID ?? UUID()) { state.selectedID = ids.first }
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
        VStack(spacing: 14) {
            HStack(alignment: .center) {
                Image(systemName: "link").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                Text("Clipboard").font(.system(size: 20, weight: .semibold))
                Text("\(store.links.count)").font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65)).padding(.horizontal, 7).padding(.vertical, 3)
                    .background(.white.opacity(0.09), in: Capsule())
                Spacer()
                if store.paused {
                    Image(systemName: "pause.circle.fill").foregroundStyle(.orange).help("Clipboard capture paused")
                }
                Button { state.settings?() } label: {
                    Image(systemName: "gearshape").font(.system(size: 15)).frame(width: 28, height: 28)
                }.buttonStyle(.plain).foregroundStyle(.white.opacity(0.65)).help("Settings")
                .accessibilityLabel("Open settings")
            }
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.55))
                TextField("Search your clipboard", text: $state.query)
                    .textFieldStyle(.plain).font(.system(size: 14)).focused($searchFocused)
                    .onSubmit { chooseSelected() }
                    .accessibilityLabel("Search clipboard")
                if !state.query.isEmpty {
                    Button { state.query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.white.opacity(0.55)).accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12).frame(height: 39)
            .background(.white.opacity(0.085), in: RoundedRectangle(cornerRadius: 11))
            HStack(spacing: 5) {
                filterButton("All", favorites: false)
                Button { state.favoritesOnly = false; state.linksOnly.toggle() } label: {
                    Text("Links").font(.system(size: 12, weight: .medium)).padding(.horizontal, 10).padding(.vertical, 6)
                        .foregroundStyle(.white.opacity(state.linksOnly ? 1 : 0.6))
                        .background(.white.opacity(state.linksOnly ? 0.13 : 0), in: Capsule())
                }.buttonStyle(.plain)
                filterButton("Pinned", favorites: true)
                Spacer()
                Text("ON THIS MAC").font(.system(size: 9, weight: .medium)).tracking(1)
                    .foregroundStyle(.white.opacity(0.5))
            }
            if let error = store.storageError {
                Label(error, systemImage: "exclamationmark.triangle").font(.system(size: 11)).foregroundStyle(.orange)
            } else if store.clipboardDenied {
                Button("Allow clipboard access in System Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Pasteboard")!)
                }.font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(.orange)
            }
            Group {
                if items.isEmpty { emptyState }
                else {
                    ClipboardScrollView(ids: items.map(\.id), selectedID: state.selectedID,
                        session: state.scrollSession, reduceMotion: reduceMotion) {
                        VStack(spacing: 3) {
                            ForEach(items) { link in row(link).frame(height: 52) }
                        }
                    }
                }
            }.frame(maxHeight: .infinity)
            HStack(spacing: 5) {
                if let message = state.message {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text(message)
                } else {
                    Image(systemName: "arrow.up.arrow.down").font(.system(size: 10))
                    Text("navigate")
                    Text("·").padding(.horizontal, 3)
                    Image(systemName: "return").font(.system(size: 10))
                    Text(state.pastesSelection ? "paste" : "copy")
                }
                Spacer()
                Text("esc to close")
            }.font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
        }
        .padding(.horizontal, 22).padding(.bottom, 19)
        .frame(width: 480, height: 448)
    }
    private func filterButton(_ name: String, favorites: Bool) -> some View {
        Button { state.favoritesOnly = favorites; state.linksOnly = false } label: {
            HStack(spacing: 5) {
                if favorites { Image(systemName: "pin.fill").font(.system(size: 10)) }
                Text(name).font(.system(size: 12, weight: .medium))
            }.padding(.horizontal, 10).padding(.vertical, 6)
                .foregroundStyle(.white.opacity(state.favoritesOnly == favorites && !state.linksOnly ? 1 : 0.6))
                .background(.white.opacity(state.favoritesOnly == favorites && !state.linksOnly ? 0.13 : 0), in: Capsule())
        }.buttonStyle(.plain).accessibilityAddTraits(state.favoritesOnly == favorites && !state.linksOnly ? .isSelected : [])
    }
    private func row(_ link: ClipboardEntry) -> some View {
        let selected = state.selectedID == link.id
        return HStack(spacing: 10) {
            Button { state.choose?(link) } label: {
                HStack(spacing: 11) {
                    Image(systemName: link.symbol).font(.system(size: 17, weight: .medium))
                        .foregroundStyle(selected ? .white : .white.opacity(0.75))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(selected ? 0.13 : 0.065), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(link.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                        Text(link.preview).font(.system(size: 11)).foregroundStyle(.white.opacity(selected ? 0.8 : 0.58))
                            .lineLimit(1).truncationMode(.middle)
                    }
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("\(link.title), \(link.content)")
            Button {
                if state.pastesSelection { state.choose?(link) }
                else { store.copy(link); state.message = "Copied to clipboard" }
            } label: {
                Image(systemName: state.pastesSelection ? "arrow.turn.down.left" : "doc.on.doc").font(.system(size: 13)).frame(width: 28, height: 32)
                    .foregroundStyle(.white.opacity(0.8))
            }.buttonStyle(.plain).help(state.pastesSelection ? "Paste item" : "Copy item")
                .accessibilityLabel("\(state.pastesSelection ? "Paste" : "Copy") \(link.title)")
            Button { store.togglePin(link) } label: {
                Image(systemName: link.pinned ? "pin.fill" : "pin")
                    .font(.system(size: 12)).frame(width: 26, height: 32)
                    .foregroundStyle(link.pinned ? .white.opacity(0.85) : .white.opacity(hoveredID == link.id || selected ? 0.6 : 0))
            }.buttonStyle(.plain).help(link.pinned ? "Unpin link" : "Pin link")
                .accessibilityLabel(link.pinned ? "Unpin \(link.title)" : "Pin \(link.title)")
        }
        .padding(.horizontal, 9).padding(.vertical, 8)
        .background(selected ? Color(red: 0.12, green: 0.32, blue: 0.66) : .white.opacity(hoveredID == link.id ? 0.07 : 0),
            in: RoundedRectangle(cornerRadius: 12))
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

import AppKit
import Combine

struct ClipboardEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var content: String
    var title: String
    var copiedAt = Date()
    var pinned = false

    var isLink: Bool {
        let value = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return false }
        return !value.contains(where: { $0.isWhitespace })
    }
    var host: String { isLink ? URL(string: content.trimmingCharacters(in: .whitespacesAndNewlines))?.host ?? "" : "" }
    var preview: String { content.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\t", with: " ") }
    var symbol: String {
        if host.contains("linkedin.com") { return "person.crop.square" }
        if host.contains("drive.google.com") { return "externaldrive" }
        if host.contains("github.com") { return "chevron.left.forwardslash.chevron.right" }
        if host.contains("docs.google.com") { return "doc.text" }
        return isLink ? "link" : "text.alignleft"
    }
}

enum LinkParser {
    static func urls(in text: String) -> [String] {
        guard text.utf8.count <= 100_000,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        var seen = Set<String>()
        return detector.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let url = match.url, ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  url.host != nil, url.user == nil, url.password == nil,
                  seen.insert(url.absoluteString).inserted else { return nil }
            return url.absoluteString
        }
    }
    static func title(for value: String) -> String {
        guard let url = URL(string: value), let host = url.host else { return value }
        let parts = url.pathComponents.filter { $0 != "/" }
        if host.contains("linkedin.com"), parts.first == "in", let name = parts.dropFirst().first {
            return "LinkedIn · " + name.replacingOccurrences(of: "-", with: " ").capitalized
        }
        if host == "drive.google.com" { return parts.contains("folders") ? "Google Drive folder" : "Google Drive file" }
        if host == "docs.google.com" { return "Google " + (parts.first == "spreadsheets" ? "Sheet" : parts.first == "presentation" ? "Slides" : "Doc") }
        if host == "github.com", parts.count >= 2 { return parts.prefix(2).joined(separator: "/") }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}

final class ClipboardStore: ObservableObject {
    @Published var links: [ClipboardEntry] = []
    @Published var paused = false
    @Published var storageError: String?
    @Published var clipboardDenied = false
    private let file: URL
    private var timer: Timer?
    private var changeCount: Int
    private let pasteboard: NSPasteboard
    private let limit = 20

    init(file: URL? = nil, monitoring: Bool = true, pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        self.file = file ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NotchLinks/history.json")
        changeCount = pasteboard.changeCount
        if FileManager.default.fileExists(atPath: self.file.path) {
            do {
                links = try JSONDecoder().decode([ClipboardEntry].self, from: Data(contentsOf: self.file))
                let previousCount = links.count
                trimRecent()
                if links.count != previousCount { save() }
            }
            catch { storageError = "History couldn’t be read. Your saved file has been kept." }
        }
        if monitoring {
            timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in self?.poll() }
        }
    }
    deinit { timer?.invalidate() }
    var sorted: [ClipboardEntry] {
        links.sorted { $0.pinned != $1.pinned ? $0.pinned : $0.copiedAt > $1.copiedAt }
    }
    func capture(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.utf8.count <= 100_000 else { return }
        if let index = links.firstIndex(where: { $0.content == text }) { links[index].copiedAt = Date() }
        else {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let urls = LinkParser.urls(in: trimmed)
            let isURL = urls.count == 1 && urls[0] == trimmed
            let title = isURL ? LinkParser.title(for: trimmed) : String(trimmed.split(whereSeparator: \.isNewline).first.map(String.init)?.prefix(80) ?? "Text".prefix(80))
            links.append(ClipboardEntry(content: text, title: title))
        }
        trimRecent()
        save()
    }
    func poll() {
        guard pasteboard.changeCount != changeCount else { return }
        changeCount = pasteboard.changeCount
        guard !paused else { return }
        let privateTypes = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType", "org.nspasteboard.AutoGeneratedType", "com.agilebits.onepassword"]
        guard !(pasteboard.types ?? []).contains(where: { privateTypes.contains($0.rawValue) }) else { return }
        if #available(macOS 15.4, *) {
            clipboardDenied = pasteboard.accessBehavior == .alwaysDeny
            if clipboardDenied { return }
        }
        if let value = pasteboard.string(forType: .string) ?? pasteboard.string(forType: .URL) { capture(value) }
    }
    func copy(_ link: ClipboardEntry) {
        pasteboard.clearContents()
        pasteboard.setString(link.content, forType: .string)
        changeCount = pasteboard.changeCount
    }
    func togglePin(_ link: ClipboardEntry) {
        guard let index = links.firstIndex(where: { $0.id == link.id }) else { return }
        links[index].pinned.toggle()
        trimRecent()
        save()
    }
    func rename(_ link: ClipboardEntry, title: String) {
        guard let index = links.firstIndex(where: { $0.id == link.id }) else { return }
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        links[index].title = cleaned.isEmpty ? String(link.content.prefix(80)) : String(cleaned.prefix(100))
        save()
    }
    func remove(_ link: ClipboardEntry) { links.removeAll { $0.id == link.id }; save() }
    func clearRecent() { links.removeAll { !$0.pinned }; save() }
    func clearAll() { links.removeAll(); save() }
    private func trimRecent() {
        let recent = links.filter { !$0.pinned }.sorted { $0.copiedAt > $1.copiedAt }
        let retained = Set(recent.prefix(limit).map(\.id))
        links.removeAll { !$0.pinned && !retained.contains($0.id) }
    }
    private func save() {
        // Preserve a damaged file rather than silently overwrite it.
        guard storageError == nil else { return }
        do {
            let directory = file.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            let data = try JSONEncoder().encode(links)
            try data.write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        } catch { storageError = "History couldn’t be saved. Check available storage and restart PasteReady." }
    }
}

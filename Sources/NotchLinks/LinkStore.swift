import AppKit
import Combine

struct ClipboardEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var content: String
    var title: String
    var copiedAt = Date()
    var pinned = false
    var image: ClipboardImage?

    var isImage: Bool { image != nil }

    var isLink: Bool {
        guard !isImage else { return false }
        let value = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return false }
        return !value.contains(where: { $0.isWhitespace })
    }
    var host: String { isLink ? URL(string: content.trimmingCharacters(in: .whitespacesAndNewlines))?.host ?? "" : "" }
    var preview: String { image?.detail ?? content.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\t", with: " ") }
    var symbol: String {
        if isImage { return "photo" }
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
    @Published var paused = false { didSet { if paused { imageGeneration += 1 } } }
    @Published var storageError: String?
    @Published var clipboardDenied = false
    @Published var captureNotice: String?
    private let imageQueue = DispatchQueue(label: "com.sarthak.notchlinks.images", qos: .userInitiated)
    private let imageCache = NSCache<NSString, NSImage>()
    private var imageGeneration = 0
    private var imageDirectory: URL { file.deletingLastPathComponent().appendingPathComponent("images", isDirectory: true) }
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
        imageCache.totalCostLimit = 24 * 1024 * 1024
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
        if let index = links.firstIndex(where: { $0.image == nil && $0.content == text }) { links[index].copiedAt = Date() }
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
        // Finder file copies can advertise a file icon as TIFF; do not capture those icons.
        guard !(pasteboard.types ?? []).contains(.fileURL) else { return }
        if let type = pasteboard.availableType(from: [.png, .tiff]), let data = pasteboard.data(forType: type) {
            let generation = imageGeneration
            let copiedAt = Date()
            imageQueue.async { [weak self] in
                let image = ClipboardImageCodec.inspect(data, type: type)
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.imageGeneration == generation, !self.paused else { return }
                    self.captureImage(data, metadata: image, copiedAt: copiedAt)
                }
            }
        } else if let value = pasteboard.string(forType: .string) ?? pasteboard.string(forType: .URL) { capture(value) }
    }
    /// Returns false without clearing the clipboard when an image attachment is unavailable.
    @discardableResult func copy(_ link: ClipboardEntry) -> Bool {
        if let image = link.image {
            guard image.isValid, let data = try? Data(contentsOf: imageDirectory.appendingPathComponent(image.filename)) else {
                captureNotice = "This image is no longer available. Copy the original image again."
                return false
            }
            pasteboard.clearContents()
            guard pasteboard.setData(data, forType: .init(image.pasteboardType)) else { return false }
        } else {
            pasteboard.clearContents()
            guard pasteboard.setString(link.content, forType: .string) else { return false }
        }
        changeCount = pasteboard.changeCount
        captureNotice = nil
        return true
    }
    func imagePreview(_ entry: ClipboardEntry, fullSize: Bool = false) -> NSImage? {
        guard let image = entry.image, image.isValid else { return nil }
        let key = "\(image.digest)-\(fullSize)" as NSString
        if let cached = imageCache.object(forKey: key) { return cached }
        guard let preview = ClipboardImageCodec.preview(at: imageDirectory.appendingPathComponent(image.filename), maxSize: fullSize ? 1200 : 96) else { return nil }
        imageCache.setObject(preview, forKey: key, cost: Int(preview.size.width * preview.size.height) * 4)
        return preview
    }
    func captureImage(_ data: Data, metadata: ClipboardImage?, copiedAt: Date = Date()) {
        guard let image = metadata, image.isValid else {
            captureNotice = "Image skipped. Use a PNG or TIFF up to 20 MB and 40 megapixels."
            return
        }
        // Never replace a damaged history file or leave new attachments beside it.
        guard storageError == nil else { return }
        do {
            try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let target = imageDirectory.appendingPathComponent(image.filename)
            if !FileManager.default.fileExists(atPath: target.path) { try data.write(to: target, options: .atomic) }
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
            if let index = links.firstIndex(where: { $0.image?.digest == image.digest }) { links[index].copiedAt = copiedAt }
            else { links.append(ClipboardEntry(content: "", title: "Image", copiedAt: copiedAt, image: image)) }
            captureNotice = nil
            trimRecent()
            save()
        } catch { captureNotice = "Image couldn’t be saved. Check available storage and copy it again." }
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
        links[index].title = cleaned.isEmpty ? (link.isImage ? "Image" : String(link.content.prefix(80))) : String(cleaned.prefix(100))
        save()
    }
    func remove(_ link: ClipboardEntry) { links.removeAll { $0.id == link.id }; save() }
    func clearRecent() { imageGeneration += 1; links.removeAll { !$0.pinned }; save() }
    func clearAll() { imageGeneration += 1; links.removeAll(); save() }
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
            // Clean up only after the JSON was saved, so failed saves never delete persisted attachments.
            let retained = Set(links.compactMap { $0.image?.filename })
            for url in (try? FileManager.default.contentsOfDirectory(at: imageDirectory, includingPropertiesForKeys: nil)) ?? [] {
                if url.pathExtension == "image", !retained.contains(url.lastPathComponent) { try? FileManager.default.removeItem(at: url) }
            }
            imageCache.removeAllObjects()
        } catch { storageError = "History couldn’t be saved. Check available storage and restart PasteReady." }
    }
}

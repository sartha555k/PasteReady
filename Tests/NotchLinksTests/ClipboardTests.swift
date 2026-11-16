import Foundation
import AppKit


private func XCTAssertTrue(_ value: @autoclosure () -> Bool, file: StaticString = #file, line: UInt = #line) { precondition(value(), "Expected true", file: file, line: line) }
private func XCTAssertFalse(_ value: @autoclosure () -> Bool, file: StaticString = #file, line: UInt = #line) { precondition(!value(), "Expected false", file: file, line: line) }
private func XCTAssertNotNil<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) { precondition(value != nil, "Expected non-nil", file: file, line: line) }
private func XCTAssertEqual<T: Equatable>(_ left: T, _ right: T, file: StaticString = #file, line: UInt = #line) { precondition(left == right, "Values differ", file: file, line: line) }

@main
final class ClipboardTests {
    static func main() throws {
        let tests = ClipboardTests()
        let cases: [(String, () throws -> Void)] = [
            ("exact text persists and copies", tests.testExactTextSurvivesPersistenceAndCopy),
            ("deduplication preserves pins and names", tests.testRecopyPreservesPinAndCustomName),
            ("private and paused items are skipped", tests.testPrivateAndPausedClipboardNotCaptured),
            ("retention protects pins", tests.testRetentionProtectsPins),
            ("link filtering and search", tests.testClassificationAndSearch),
            ("empty and oversized text is ignored", tests.testEmptyAndOversizedTextIgnored),
            ("damaged history is preserved", tests.testDamagedHistoryIsPreserved),
            ("PNG and TIFF persist and copy exact bytes", tests.testImagePersistence),
            ("image pins deduplication and retention", tests.testImageRetention),
            ("image polling privacy and precedence", tests.testImagePolling),
            ("invalid images and missing attachments", tests.testImageFailures),
            ("enable preference preserves history and skips disabled copies", tests.testEnablePreference)
        ]
        for (name, test) in cases {
            tests.setUp()
            defer { tests.tearDown() }
            try test()
            print("PASS: \(name)")
        }
        print("All \(cases.count) checks passed.")
    }
    var directory: URL!
    var file: URL!
    var board: NSPasteboard!
    var preferences: UserDefaults!
    var preferencesName: String!
    func setUp() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        file = directory.appendingPathComponent("history.json")
        board = NSPasteboard.withUniqueName()
        preferencesName = "PasteReady.Tests." + UUID().uuidString
        preferences = UserDefaults(suiteName: preferencesName)!
    }
    func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        board.releaseGlobally()
        preferences.removePersistentDomain(forName: preferencesName)
    }
    func makeStore() -> ClipboardStore { ClipboardStore(file: file, monitoring: false, pasteboard: board, preferences: preferences) }
    func testExactTextSurvivesPersistenceAndCopy() {
        let store = makeStore()
        let value = "  A note\nwith a second line\tand spacing.  "
        store.capture(value)
        let restored = makeStore()
        XCTAssertEqual(restored.links.first?.content, value)
        restored.copy(restored.links[0])
        XCTAssertEqual(board.string(forType: .string), value)
    }
    func testRecopyPreservesPinAndCustomName() {
        let store = makeStore()
        store.capture("https://www.linkedin.com/in/sample-person/")
        store.togglePin(store.links[0])
        store.rename(store.links[0], title: "My profile")
        store.capture("https://www.linkedin.com/in/sample-person/")
        XCTAssertEqual(store.links.count, 1)
        XCTAssertTrue(store.links[0].pinned)
        XCTAssertEqual(store.links[0].title, "My profile")
        store.clearRecent()
        XCTAssertEqual(makeStore().links.count, 1)
    }
    func testPrivateAndPausedClipboardNotCaptured() {
        let store = makeStore()
        board.clearContents()
        board.setString("private content", forType: .string)
        board.setData(Data(), forType: .init("org.nspasteboard.ConcealedType"))
        store.poll()
        XCTAssertTrue(store.links.isEmpty)
        store.paused = true
        board.clearContents()
        board.setString("paused content", forType: .string)
        store.poll()
        store.paused = false
        store.poll()
        XCTAssertTrue(store.links.isEmpty)
        board.clearContents()
        board.setString("normal content", forType: .string)
        store.poll()
        XCTAssertEqual(store.links.first?.content, "normal content")
    }
    func testRetentionProtectsPins() {
        let store = makeStore()
        store.capture("keep me")
        store.togglePin(store.links[0])
        for index in 0..<25 { store.capture("note \(index)") }
        XCTAssertEqual(store.links.count, 21)
        XCTAssertTrue(store.links.contains { $0.content == "keep me" && $0.pinned })
        XCTAssertFalse(store.links.contains { $0.content == "note 0" })
        XCTAssertTrue(store.links.contains { $0.content == "note 24" })
        store.togglePin(store.links.first { $0.pinned }!)
        XCTAssertEqual(store.links.count, 20)
        XCTAssertFalse(store.links.contains { $0.content == "keep me" })
        // A pre-update history is trimmed immediately on launch, not next copy.
        let oldHistory = (0..<30).map { index in
            ClipboardEntry(content: "old \(index)", title: "Old", copiedAt: Date(timeIntervalSince1970: Double(index)), pinned: index == 0)
        }
        try! JSONEncoder().encode(oldHistory).write(to: file)
        let migrated = makeStore()
        XCTAssertEqual(migrated.links.count, 21)
        XCTAssertTrue(migrated.links.contains { $0.content == "old 0" && $0.pinned })
        XCTAssertFalse(migrated.links.contains { $0.content == "old 1" })
        XCTAssertEqual(makeStore().links.count, 21)
        store.clearAll()
        XCTAssertTrue(makeStore().links.isEmpty)
    }
    func testClassificationAndSearch() {
        let store = makeStore()
        store.capture("https://drive.google.com/drive/folders/example")
        store.capture("Some text with https://example.com inside it")
        XCTAssertTrue(store.links[0].isLink)
        XCTAssertFalse(store.links[1].isLink)
        let state = PanelState()
        state.linksOnly = true
        XCTAssertEqual(state.filtered(store.sorted).count, 1)
        state.query = "GOOGLE"
        XCTAssertEqual(state.filtered(store.sorted).count, 1)
        state.query = "missing"
        XCTAssertTrue(state.filtered(store.sorted).isEmpty)
    }
    func testEmptyAndOversizedTextIgnored() {
        let store = makeStore()
        store.capture(" \n ")
        store.capture(String(repeating: "a", count: 100_001))
        XCTAssertTrue(store.links.isEmpty)
    }
    func testDamagedHistoryIsPreserved() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let damaged = Data("not json".utf8)
        try damaged.write(to: file)
        let store = makeStore()
        XCTAssertNotNil(store.storageError)
        store.capture("a new entry")
        XCTAssertEqual(try Data(contentsOf: file), damaged)
    }
    func sampleImage(_ type: NSBitmapImageRep.FileType = .png) -> Data {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 80, pixelsHigh: 50,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let pixels = bitmap.bitmapData!
        for y in 0..<50 { for x in 0..<80 {
            let offset = y * bitmap.bytesPerRow + x * 4
            pixels[offset] = UInt8(x * 255 / 80); pixels[offset + 1] = 102
            pixels[offset + 2] = 179; pixels[offset + 3] = x < 20 ? 102 : 255
        } }
        return bitmap.representation(using: type, properties: [:])!
    }
    func pump() { RunLoop.main.run(until: Date().addingTimeInterval(0.2)) }
    func testImagePersistence() throws {
        for (format, type) in [(NSBitmapImageRep.FileType.png, NSPasteboard.PasteboardType.png), (.tiff, .tiff)] {
            let store = makeStore(), data = sampleImage(format)
            let image = ClipboardImageCodec.inspect(data, type: type)
            XCTAssertNotNil(image)
            store.captureImage(data, metadata: image)
            let restored = makeStore(), entry = restored.links.first { $0.image?.pasteboardType == type.rawValue }!
            XCTAssertTrue(entry.isImage)
            XCTAssertFalse(entry.isLink)
            XCTAssertEqual(entry.image?.width, 80)
            XCTAssertEqual(entry.image?.height, 50)
            XCTAssertNotNil(restored.imagePreview(entry))
            XCTAssertNotNil(restored.imagePreview(entry, fullSize: true))
            XCTAssertTrue(restored.copy(entry))
            XCTAssertEqual(board.data(forType: type), data)
            restored.poll()
            XCTAssertEqual(restored.links.count, store.links.count)
        }
    }
    func testImageRetention() throws {
        let store = makeStore(), data = sampleImage(), image = ClipboardImageCodec.inspect(sampleImage(), type: .png)!
        store.captureImage(data, metadata: image)
        let entry = store.links[0]
        store.togglePin(entry)
        store.rename(entry, title: "My screenshot")
        store.captureImage(data, metadata: image)
        XCTAssertEqual(store.links.count, 1)
        XCTAssertEqual(store.links[0].title, "My screenshot")
        for index in 0..<25 { store.capture("Note \(index)") }
        XCTAssertEqual(store.links.count, 21)
        let attachment = directory.appendingPathComponent("images/" + image.filename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: attachment.path))
        store.clearRecent()
        XCTAssertEqual(makeStore().links.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: attachment.path))
        store.remove(entry)
        XCTAssertFalse(FileManager.default.fileExists(atPath: attachment.path))
        store.captureImage(data, metadata: image)
        for index in 0..<21 { store.capture("New \(index)") }
        XCTAssertEqual(store.links.count, 20)
        XCTAssertFalse(FileManager.default.fileExists(atPath: attachment.path))
        store.captureImage(data, metadata: image)
        store.clearAll()
        XCTAssertFalse(FileManager.default.fileExists(atPath: attachment.path))
    }
    func testImagePolling() {
        let store = makeStore(), data = sampleImage()
        board.clearContents(); board.setData(data, forType: .png); board.setString("image alt text", forType: .string)
        store.poll(); pump()
        XCTAssertEqual(store.links.count, 1)
        XCTAssertTrue(store.links[0].isImage)
        let state = PanelState()
        state.linksOnly = true
        XCTAssertTrue(state.filtered(store.sorted).isEmpty)
        state.linksOnly = false; state.query = "image"
        XCTAssertEqual(state.filtered(store.sorted).count, 1)
        store.clearAll()
        for privateType in ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"] {
            board.clearContents(); board.setData(data, forType: .png); board.setData(Data(), forType: .init(privateType))
            store.poll(); pump(); XCTAssertTrue(store.links.isEmpty)
        }
        board.clearContents(); board.setData(data, forType: .png); board.setString("file:///tmp/example.png", forType: .fileURL)
        store.poll(); pump(); XCTAssertTrue(store.links.isEmpty)
        board.clearContents(); board.setData(data, forType: .png)
        store.poll(); store.clearAll(); pump(); XCTAssertTrue(store.links.isEmpty)
        board.clearContents(); board.setData(data, forType: .png)
        store.poll(); store.paused = true; store.paused = false; pump(); XCTAssertTrue(store.links.isEmpty)
    }
    func testImageFailures() throws {
        let store = makeStore()
        XCTAssertTrue(ClipboardImageCodec.inspect(Data("invalid".utf8), type: .png) == nil)
        XCTAssertTrue(ClipboardImageCodec.inspect(Data(repeating: 0, count: ClipboardImageCodec.maxBytes + 1), type: .png) == nil)
        store.captureImage(Data(), metadata: nil)
        XCTAssertTrue(store.links.isEmpty)
        XCTAssertNotNil(store.captureNotice)
        let data = sampleImage(), image = ClipboardImageCodec.inspect(sampleImage(), type: .png)!
        store.captureImage(data, metadata: image)
        let entry = store.links[0]
        try FileManager.default.removeItem(at: directory.appendingPathComponent("images/" + image.filename))
        board.clearContents(); board.setString("Keep the current clipboard", forType: .string)
        XCTAssertFalse(store.copy(entry))
        XCTAssertEqual(board.string(forType: .string), "Keep the current clipboard")
        let permissions = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as! NSNumber
        XCTAssertEqual(permissions.intValue, 0o600)
    }

    func testEnablePreference() {
        let store = makeStore()
        XCTAssertTrue(store.enabled)
        store.capture("Saved favorite")
        store.togglePin(store.links[0])
        store.paused = true
        store.enabled = false
        XCTAssertFalse(makeStore().enabled)
        XCTAssertTrue(store.paused)
        board.clearContents(); board.setString("Copied while disabled", forType: .string)
        store.poll()
        store.capture("Direct capture while disabled")
        let data = sampleImage(), metadata = ClipboardImageCodec.inspect(data, type: .png)
        store.captureImage(data, metadata: metadata)
        XCTAssertEqual(store.links.count, 1)
        XCTAssertFalse(store.copy(store.links[0]))
        XCTAssertEqual(board.string(forType: .string), "Copied while disabled")
        store.enabled = true
        XCTAssertTrue(makeStore().enabled)
        XCTAssertTrue(store.paused) // Master switch does not overwrite the separate pause preference.
        store.paused = false
        store.poll()
        XCTAssertEqual(store.links.count, 1) // No backfill of disabled clipboard contents.
        board.clearContents(); board.setData(data, forType: .png)
        store.poll(); store.enabled = false; store.enabled = true; pump()
        XCTAssertEqual(store.links.count, 1) // In-flight image capture must be cancelled too.
        board.clearContents(); board.setString("New copy after enabling", forType: .string)
        store.poll()
        XCTAssertEqual(store.links.count, 2)
        XCTAssertTrue(makeStore().links.contains { $0.pinned && $0.content == "Saved favorite" })
    }

}

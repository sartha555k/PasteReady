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
            ("damaged history is preserved", tests.testDamagedHistoryIsPreserved)
        ]
        for (name, test) in cases {
            tests.setUp()
            defer { tests.tearDown() }
            try test()
            print("PASS: \(name)")
        }
        print("All 7 checks passed.")
    }
    var directory: URL!
    var file: URL!
    var board: NSPasteboard!
    func setUp() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        file = directory.appendingPathComponent("history.json")
        board = NSPasteboard.withUniqueName()
    }
    func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        board.releaseGlobally()
    }
    func makeStore() -> ClipboardStore { ClipboardStore(file: file, monitoring: false, pasteboard: board) }
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
}

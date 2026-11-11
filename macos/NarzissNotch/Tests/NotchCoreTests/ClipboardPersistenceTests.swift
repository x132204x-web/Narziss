import XCTest
import AppKit
@testable import NarzissNotch
@testable import NotchCore

@MainActor
final class ClipboardPersistenceTests: XCTestCase {
    func testCapturedAndStarredClipsSurviveStopAndRelaunch() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "clipboard-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let pasteboard = NSPasteboard.withUniqueName()
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: suite)
            pasteboard.releaseGlobally()
        }
        let store = ClipboardStore(directory: root, defaults: defaults, pasteboard: pasteboard, isPreview: false)
        XCTAssertTrue(store.isEnabled)
        for text in ["first clip", "second clip"] {
            pasteboard.clearContents(); pasteboard.setString(text, forType: .string)
            store.capture()
        }
        XCTAssertEqual(store.history.items.count, 2)
        let ids = store.history.items.map(\.id)
        XCTAssertTrue(store.save(title: "A star", text: "saved clip"))
        store.stop()
        XCTAssertEqual(store.history.items.count, 2)
        let reloaded = ClipboardStore(directory: root, defaults: defaults, pasteboard: pasteboard, isPreview: false)
        XCTAssertEqual(reloaded.history.items.map(\.text), ["second clip", "first clip"])
        XCTAssertEqual(reloaded.history.items.map(\.id), ids)
        XCTAssertEqual(reloaded.saved.map(\.text), ["saved clip"])
    }
    func testLimitsDeletionAndCapturePreferencePersist() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "clipboard-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let pasteboard = NSPasteboard.withUniqueName()
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: suite)
            pasteboard.releaseGlobally()
        }
        let fixtures = (0..<150).map { Clip(text: "clip \($0)") }
        try ClipboardArchive.write(fixtures, to: root.appendingPathComponent("clipboard-history.json"))
        let store = ClipboardStore(directory: root, defaults: defaults, pasteboard: pasteboard, isPreview: false)
        XCTAssertEqual(store.history.items.count, 150)
        store.historyLimit = 100
        XCTAssertEqual(store.history.items.count, 100)
        store.remove(try XCTUnwrap(store.history.items.first))
        store.isEnabled = false
        store.stop()
        let reloaded = ClipboardStore(directory: root, defaults: defaults, pasteboard: pasteboard, isPreview: false)
        XCTAssertEqual(reloaded.history.items.count, 99)
        XCTAssertEqual(reloaded.history.items.first?.text, "clip 1")
        XCTAssertEqual(reloaded.historyLimit, 100)
        XCTAssertFalse(reloaded.isEnabled)
        reloaded.clearAll()
        let empty = ClipboardStore(directory: root, defaults: defaults, pasteboard: pasteboard, isPreview: false)
        XCTAssertTrue(empty.history.items.isEmpty)
        XCTAssertFalse(empty.isEnabled)
    }

    func testUnreadableHistoryIsPreservedAndConcealedCopiesAreSkipped() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "clipboard-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let pasteboard = NSPasteboard.withUniqueName()
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: suite)
            pasteboard.releaseGlobally()
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("clipboard-history.json")
        let corrupt = Data("unreadable fixture".utf8)
        try corrupt.write(to: url)
        let store = ClipboardStore(directory: root, defaults: defaults, pasteboard: pasteboard, isPreview: false)
        XCTAssertNotNil(store.storageError)
        pasteboard.declareTypes([.string, .init("org.nspasteboard.ConcealedType")], owner: nil)
        pasteboard.setString("excluded fixture", forType: .string)
        store.capture()
        XCTAssertTrue(store.history.items.isEmpty)
        pasteboard.clearContents(); pasteboard.setString("ordinary fixture", forType: .string)
        store.capture()
        XCTAssertEqual(store.history.items.count, 1)
        store.stop()
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
    }

}

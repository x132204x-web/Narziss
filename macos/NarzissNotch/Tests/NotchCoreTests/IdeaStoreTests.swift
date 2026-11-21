import XCTest
@testable import NarzissNotch
@testable import NotchCore

@MainActor
final class IdeaStoreTests: XCTestCase {
    func testAddingCompletingMarkingAndEditingSurviveRelaunch() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("ideas.json")
        let store = IdeaStore(url: url)
        XCTAssertTrue(store.add("  Remember this idea  "))
        let id = try XCTUnwrap(store.items.first?.id)
        store.toggleDone(id)
        store.toggleMarked(id)
        XCTAssertTrue(store.edit(id, text: "A clearer idea"))
        let reloaded = IdeaStore(url: url)
        XCTAssertEqual(reloaded.items, [Idea(id: id, text: "A clearer idea", isDone: true, isMarked: true)])
        XCTAssertEqual(reloaded.remainingCount, 0)
        reloaded.toggleDone(id)
        XCTAssertEqual(IdeaStore(url: url).remainingCount, 1)
        reloaded.remove(id)
        XCTAssertTrue(IdeaStore(url: url).items.isEmpty)
    }
    func testImportantOpenIdeasComeFirstAndCompletedIdeasStayAvailable() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = IdeaStore(url: root.appendingPathComponent("ideas.json"))
        XCTAssertTrue(store.add("Important"))
        let important = try XCTUnwrap(store.items.first?.id)
        store.toggleMarked(important)
        XCTAssertTrue(store.add("Done"))
        let done = try XCTUnwrap(store.items.first?.id)
        store.toggleDone(done)
        XCTAssertTrue(store.add("Newest"))
        XCTAssertEqual(store.orderedItems.map(\.text), ["Important", "Newest", "Done"])
        XCTAssertEqual(store.remainingCount, 2)
        XCTAssertFalse(store.add(" \n "))
        XCTAssertFalse(store.edit(important, text: ""))
        XCTAssertEqual(store.items.count, 3)
    }
    func testUnreadableIdeaListCannotBeOverwritten() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let original = Data("unreadable fixture".utf8)
        try original.write(to: url)
        let store = IdeaStore(url: url)
        XCTAssertTrue(store.isReadOnly)
        XCTAssertNotNil(store.error)
        XCTAssertFalse(store.add("New idea"))
        store.remove(UUID())
        XCTAssertEqual(try Data(contentsOf: url), original)
    }
    func testFailedSaveDoesNotDisplayAnUnsavedIdea() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("a file, not a folder".utf8).write(to: root)
        let store = IdeaStore(url: root.appendingPathComponent("ideas.json"))
        XCTAssertFalse(store.add("Will not save"))
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertNotNil(store.error)
    }
}

import XCTest
@testable import NotchCore

final class ClipboardHistoryTests: XCTestCase {
    func testDeduplicatingPreservesPinAndPromotesItem() {
        var history = ClipboardHistory()
        history.record("first")
        let id = history.items[0].id
        history.togglePin(id)
        history.record("second")
        history.record("first")
        XCTAssertEqual(history.items.count, 2)
        XCTAssertEqual(history.items[0].id, id)
        XCTAssertTrue(history.items[0].isPinned)
    }
    func testCapacityEvictsOldestUnpinnedAndNeverPinned() {
        var history = ClipboardHistory(limit: 2)
        history.record("pinned")
        history.togglePin(history.items[0].id)
        history.record("old")
        history.record("new")
        XCTAssertEqual(Set(history.items.map(\.text)), ["pinned", "new"])
        history.togglePin(history.items[0].id)
        history.record("overflow")
        XCTAssertEqual(history.items.count, 2)
        XCTAssertFalse(history.items.contains { $0.text == "overflow" })
    }
    func testSearchAndClearing() {
        var history = ClipboardHistory()
        history.record("A pinned Note")
        history.togglePin(history.items[0].id)
        history.record("Another note")
        history.record("Different")
        XCTAssertEqual(history.matching("NOTE").map(\.text), ["A pinned Note", "Another note"])
        history.clearRecents()
        XCTAssertEqual(history.items.map(\.text), ["A pinned Note"])
        history.clearAll()
        XCTAssertTrue(history.items.isEmpty)
    }
    func testRejectsBlankAndOversizePreservesWhitespaceInValidText() {
        var history = ClipboardHistory()
        history.record(" \n\t")
        history.record(String(repeating: "a", count: 100_001))
        XCTAssertTrue(history.items.isEmpty)
        history.record("  formatted\n")
        XCTAssertEqual(history.items.first?.text, "  formatted\n")
    }
}

final class CalendarMonthTests: XCTestCase {
    func testLeapYearGridContainsAllDaysAndRespectsFirstWeekday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        calendar.firstWeekday = 2
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 2, day: 10)))
        let days = CalendarMonth.days(containing: date, calendar: calendar)
        XCTAssertEqual(days.count, 42)
        XCTAssertEqual(calendar.component(.weekday, from: days[0]), 2)
        XCTAssertEqual(days.filter { calendar.component(.month, from: $0) == 2 }.count, 29)
    }
    func testGridStaysAtMidnightAcrossDaylightSavingChange() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 15)))
        let days = CalendarMonth.days(containing: date, calendar: calendar)
        XCTAssertTrue(days.allSatisfy { calendar.component(.hour, from: $0) == 0 })
        for pair in zip(days, days.dropFirst()) {
            XCTAssertEqual(calendar.dateComponents([.day], from: pair.0, to: pair.1).day, 1)
        }
    }
}

final class CountdownTests: XCTestCase {
    func testPauseResumePreservesRemainingTime() {
        let start = Date(timeIntervalSince1970: 1_000)
        var timer = Countdown()
        timer.start(seconds: 300, at: start)
        timer.pause(at: start.addingTimeInterval(42))
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(900)), 258)
        XCTAssertTrue(timer.isPaused)
        timer.resume(at: start.addingTimeInterval(1_000))
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(1_010)), 248)
    }
    func testFinishesExactlyOnceAfterSleep() {
        let start = Date(timeIntervalSince1970: 1_000)
        var timer = Countdown()
        timer.start(seconds: 60, at: start)
        XCTAssertTrue(timer.finishIfNeeded(at: start.addingTimeInterval(3_600)))
        XCTAssertTrue(timer.isFinished)
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.remaining(at: start), 0)
        XCTAssertFalse(timer.finishIfNeeded(at: start.addingTimeInterval(3_601)))
        timer.reset()
        XCTAssertFalse(timer.isFinished)
    }
}

final class SavedLibraryTests: XCTestCase {
    func testSavedStoriesSurviveReloadAndEdits() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("snippets.json")
        XCTAssertEqual(try SavedLibrary.load(from: url), [])
        var snippet = SavedSnippet(title: "An example story", text: "Long text\nWith preserved whitespace.  ")
        try SavedLibrary.write([snippet], to: url)
        XCTAssertEqual(try SavedLibrary.load(from: url), [snippet])
        snippet.text = "Edited story"
        try SavedLibrary.write([snippet], to: url)
        XCTAssertEqual(try SavedLibrary.load(from: url).first?.text, "Edited story")
        try SavedLibrary.write([], to: url)
        XCTAssertTrue(try SavedLibrary.load(from: url).isEmpty)
    }
    func testCorruptLibraryDoesNotSilentlyBecomeEmpty() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not valid JSON".utf8).write(to: url)
        XCTAssertThrowsError(try SavedLibrary.load(from: url))
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "not valid JSON")
    }
}


final class TimerDurationTests: XCTestCase {
    func testHoursAndMinutesMakeTheExpectedCountdown() {
        XCTAssertEqual(TimerDuration(hours: "6", minutes: "0")?.seconds, 21_600)
        XCTAssertEqual(TimerDuration(hours: "1", minutes: "30")?.seconds, 5_400)
        XCTAssertEqual(TimerDuration(hours: "", minutes: "25")?.seconds, 1_500)
        XCTAssertEqual(TimerDuration(hours: "0", minutes: "0")?.seconds, 0)
    }
    func testInvalidDraftCannotStartADifferentTimer() {
        for fields in [("-1", "0"), ("100", "0"), ("1.5", "0"), ("one", "0"), ("0", "60"), ("0", "-5")] {
            XCTAssertNil(TimerDuration(hours: fields.0, minutes: fields.1))
        }
    }
    func testFormattingChangesAtTheHourBoundary() {
        XCTAssertEqual(TimerDuration.format(seconds: 21_600), "6:00:00")
        XCTAssertEqual(TimerDuration.format(seconds: 5_400), "1:30:00")
        XCTAssertEqual(TimerDuration.format(seconds: 3_600), "1:00:00")
        XCTAssertEqual(TimerDuration.format(seconds: 3_599), "59:59")
        XCTAssertEqual(TimerDuration.format(seconds: 59.2), "01:00")
        XCTAssertEqual(TimerDuration.format(seconds: 0), "00:00")
    }
}

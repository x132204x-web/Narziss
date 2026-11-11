import XCTest
@testable import NarzissNotch

@MainActor
final class CountdownPresetTests: XCTestCase {
    func testPresetsUpdateDisplayImmediatelyAfterCompletionWithoutStarting() async {
        let timer = CountdownStore()
        let start = Date(timeIntervalSince1970: 1_000)
        for minutes in [5, 15, 25] {
            timer.countdown.start(seconds: 1, at: start)
            timer.tick(at: start.addingTimeInterval(1))
            XCTAssertEqual(timer.displayLabel(at: start), "00:00")
            timer.preset(minutes)
            XCTAssertEqual(timer.displayLabel(at: start), String(format: "%02d:00", minutes))
            XCTAssertFalse(timer.countdown.isFinished)
            XCTAssertFalse(timer.countdown.isRunning)
        }
    }

    func testEditingDurationAfterCompletionShowsTheDraftImmediately() async {
        let timer = CountdownStore()
        let start = Date(timeIntervalSince1970: 1_000)
        timer.countdown.start(seconds: 1, at: start)
        timer.tick(at: start.addingTimeInterval(1))
        timer.hoursInput = "1"
        timer.minutesInput = "30"
        XCTAssertEqual(timer.displayLabel(at: start), "1:30:00")
        XCTAssertFalse(timer.countdown.isFinished)
        XCTAssertFalse(timer.countdown.isRunning)
    }
}

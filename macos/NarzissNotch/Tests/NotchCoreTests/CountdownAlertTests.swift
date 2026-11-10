import XCTest
@testable import NarzissNotch

final class CountdownAlertTests: XCTestCase {
    func testExpiryShowsAlertExactlyOnceEvenWhenFolded() async {
        await MainActor.run {
            let state = NotchState()
            state.tab = .music
            let timer = CountdownStore()
            var alerts = 0
            timer.onFinished = {
                alerts += 1
                state.showTimerFinished()
            }
            let start = Date(timeIntervalSince1970: 1_000)
            timer.countdown.start(seconds: 60, at: start)
            timer.tick(at: start.addingTimeInterval(59))
            XCTAssertEqual(alerts, 0)
            timer.tick(at: start.addingTimeInterval(3_600))
            XCTAssertEqual(alerts, 1)
            XCTAssertTrue(state.expanded)
            XCTAssertTrue(state.pinned)
            XCTAssertEqual(state.tab, .clock)
            timer.tick(at: start.addingTimeInterval(3_601))
            XCTAssertEqual(alerts, 1)
        }
    }
    func testPausedAndResetTimersDoNotAlert() async {
        await MainActor.run {
            let timer = CountdownStore()
            var alerts = 0
            timer.onFinished = { alerts += 1 }
            let start = Date(timeIntervalSince1970: 1_000)
            timer.countdown.start(seconds: 60, at: start)
            timer.pause(at: start.addingTimeInterval(30))
            timer.tick(at: start.addingTimeInterval(3_600))
            XCTAssertEqual(alerts, 0)
            timer.countdown.resume(at: start.addingTimeInterval(3_600))
            timer.tick(at: start.addingTimeInterval(3_630))
            XCTAssertEqual(alerts, 1)
            timer.countdown.start(seconds: 60, at: start)
            timer.countdown.reset()
            timer.tick(at: start.addingTimeInterval(3_600))
            XCTAssertEqual(alerts, 1)
        }
    }

    func testPauseAtDeadlineStillDeliversAlert() async {
        await MainActor.run {
            let timer = CountdownStore()
            var alerts = 0
            timer.onFinished = { alerts += 1 }
            let start = Date(timeIntervalSince1970: 1_000)
            timer.countdown.start(seconds: 60, at: start)
            timer.pause(at: start.addingTimeInterval(60))
            timer.tick(at: start.addingTimeInterval(61))
            XCTAssertTrue(timer.countdown.isFinished)
            XCTAssertEqual(alerts, 1)
        }
    }

    func testStartPreparesNotificationsAndRequestHasSound() async {
        await MainActor.run {
            let timer = CountdownStore()
            var requests = 0
            timer.onStart = { requests += 1 }
            timer.minutesInput = "invalid"
            timer.start()
            XCTAssertEqual(requests, 0)
            timer.minutesInput = "1"
            timer.start()
            XCTAssertEqual(requests, 1)
            XCTAssertTrue(timer.countdown.isRunning)
            let request = TimerNotifications.finishedRequest()
            XCTAssertEqual(request.content.title, "Time’s up")
            XCTAssertFalse(request.content.body.isEmpty)
            XCTAssertNotNil(request.content.sound)
            XCTAssertNil(request.trigger)
        }
    }

}

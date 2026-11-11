import XCTest
@testable import NarzissNotch

@MainActor
private final class TestAlarmPlayer: AlarmSoundPlaying {
    var played: [(AlarmTone, Bool)] = []
    var stopped = false
    func play(_ tone: AlarmTone, repeating: Bool) -> Bool {
        played.append((tone, repeating)); stopped = false; return true
    }
    func stop() { stopped = true }
}

@MainActor
final class TimerAlarmTests: XCTestCase {
    func testTimerRingsWithoutBannersAndStopsOnNewDurationOrMute() async throws {
        let suite = "timer-alarm-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let player = TestAlarmPlayer()
        let alarm = TimerAlarm(defaults: defaults, player: player)
        alarm.tone = .hero
        XCTAssertFalse(alarm.showBanner)
        let timer = CountdownStore()
        timer.onFinished = { alarm.start() }
        timer.onDismissAlarm = { alarm.stop() }
        let start = Date(timeIntervalSince1970: 1_000)
        timer.countdown.start(seconds: 1, at: start)
        timer.tick(at: start.addingTimeInterval(1))
        XCTAssertTrue(alarm.isRinging)
        XCTAssertEqual(player.played.count, 1)
        XCTAssertEqual(player.played[0].0, .hero)
        XCTAssertTrue(player.played[0].1)
        timer.tick(at: start.addingTimeInterval(2))
        XCTAssertEqual(player.played.count, 1)
        timer.preset(5)
        XCTAssertFalse(alarm.isRinging)
        XCTAssertTrue(player.stopped)
        alarm.start()
        alarm.isMuted = true
        XCTAssertFalse(alarm.isRinging)
        alarm.start()
        alarm.preview()
        XCTAssertEqual(player.played.count, 2)
        let reloaded = TimerAlarm(defaults: defaults, player: player)
        XCTAssertEqual(reloaded.tone, .hero)
        XCTAssertTrue(reloaded.isMuted)
    }

    func testPreviewDoesNotLoopAndResetStopsAlarm() async throws {
        let suite = "timer-alarm-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let player = TestAlarmPlayer()
        let alarm = TimerAlarm(defaults: defaults, player: player)
        alarm.preview()
        XCTAssertFalse(try XCTUnwrap(player.played.last).1)
        XCTAssertFalse(alarm.isRinging)
        alarm.start()
        let timer = CountdownStore()
        timer.onDismissAlarm = { alarm.stop() }
        timer.reset()
        XCTAssertTrue(player.stopped)
        XCTAssertFalse(alarm.isRinging)
    }
}

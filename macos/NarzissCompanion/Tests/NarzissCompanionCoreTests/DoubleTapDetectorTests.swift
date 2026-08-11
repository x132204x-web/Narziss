import XCTest
@testable import NarzissCompanionCore

final class DoubleTapDetectorTests: XCTestCase {
    func testTriggersForTwoTapsWithinMaximumInterval() {
        var detector = DoubleTapDetector(maximumInterval: 0.4)

        XCTAssertFalse(detector.registerTap(at: 1.0))
        XCTAssertTrue(detector.registerTap(at: 1.35))
    }

    func testDoesNotTriggerForSlowDoubleTap() {
        var detector = DoubleTapDetector(maximumInterval: 0.4)

        XCTAssertFalse(detector.registerTap(at: 1.0))
        XCTAssertFalse(detector.registerTap(at: 1.5))
    }

    func testResetsAfterRecognizedDoubleTap() {
        var detector = DoubleTapDetector(maximumInterval: 0.4)

        XCTAssertFalse(detector.registerTap(at: 1.0))
        XCTAssertTrue(detector.registerTap(at: 1.2))
        XCTAssertFalse(detector.registerTap(at: 1.3))
    }
}

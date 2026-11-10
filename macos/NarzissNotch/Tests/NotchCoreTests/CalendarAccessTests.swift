import XCTest
import EventKit
@testable import NarzissNotch

private final class EmptyEventStore: EKEventStore {
    override func events(matching predicate: NSPredicate) -> [EKEvent] { [] }
}

@MainActor
final class CalendarAccessTests: XCTestCase {
    func testGrantedCalendarDoesNotAskAgainOnRepeatedVisitsOrRelaunch() async {
        var requests = 0
        let request: () async throws -> Bool = { requests += 1; return true }
        let first = CalendarStore(store: EmptyEventStore(), readAuthorization: { .fullAccess }, requestAccess: request, isPreview: false)
        await first.activate()
        await first.activate()
        let relaunched = CalendarStore(store: EmptyEventStore(), readAuthorization: { .fullAccess }, requestAccess: request, isPreview: false)
        await relaunched.activate()
        XCTAssertEqual(requests, 0)
        XCTAssertTrue(relaunched.hasAccess)
    }
    func testFirstGrantIsReusedWithoutAnotherRequest() async {
        var status: EKAuthorizationStatus = .notDetermined
        var requests = 0
        let calendar = CalendarStore(store: EmptyEventStore(), readAuthorization: { status }, requestAccess: {
            requests += 1; status = .fullAccess; return true
        }, isPreview: false)
        await calendar.activate()
        await calendar.activate()
        XCTAssertEqual(requests, 1)
        XCTAssertTrue(calendar.hasAccess)
        XCTAssertFalse(calendar.isRequestingAccess)
    }
    func testDenialIsRespectedOnSubsequentVisits() async {
        var status: EKAuthorizationStatus = .notDetermined
        var requests = 0
        let calendar = CalendarStore(store: EmptyEventStore(), readAuthorization: { status }, requestAccess: {
            requests += 1; status = .denied; return false
        }, isPreview: false)
        await calendar.activate()
        await calendar.activate()
        XCTAssertEqual(requests, 1)
        XCTAssertTrue(calendar.isDenied)
    }
    func testPreviewDoesNotRequestCalendarAccess() async {
        var requests = 0
        let calendar = CalendarStore(store: EmptyEventStore(), readAuthorization: { .notDetermined }, requestAccess: {
            requests += 1; return true
        }, isPreview: true)
        await calendar.activate()
        XCTAssertEqual(requests, 0)
    }
}

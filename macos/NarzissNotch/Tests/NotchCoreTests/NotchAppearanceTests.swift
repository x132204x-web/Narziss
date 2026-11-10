import XCTest
@testable import NarzissNotch

@MainActor
final class NotchAppearanceTests: XCTestCase {
    func testAppearancePersistsAndResetSurvivesRelaunch() async throws {
        let suite = "notch-appearance-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let appearance = NotchAppearance(defaults: defaults)
        appearance.font = .georgia
        appearance.textScale = 1.25
        appearance.width = 560
        let reloaded = NotchAppearance(defaults: defaults)
        XCTAssertEqual(reloaded.font, .georgia)
        XCTAssertEqual(reloaded.textScale, 1.25)
        XCTAssertEqual(reloaded.width, 560)
        reloaded.reset()
        let reset = NotchAppearance(defaults: defaults)
        XCTAssertEqual(reset.font, .system)
        XCTAssertEqual(reset.textScale, 1)
        XCTAssertEqual(reset.width, 380)
    }

    func testInvalidSavedValuesKeepLayoutWithinSupportedBounds() async throws {
        let suite = "notch-appearance-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("Missing font", forKey: "notch.font")
        defaults.set(20.0, forKey: "notch.textScale")
        defaults.set(-100.0, forKey: "notch.width")
        let appearance = NotchAppearance(defaults: defaults)
        XCTAssertEqual(appearance.font, .system)
        XCTAssertEqual(appearance.textScale, 1.4)
        XCTAssertEqual(appearance.width, 380)
        appearance.textScale = .nan
        appearance.width = .infinity
        XCTAssertEqual(appearance.textScale, 1)
        XCTAssertEqual(appearance.width, 380)
    }

    func testLargerTextExpandsPanelButPreservesFoldedCameraArea() async throws {
        let suite = "notch-appearance-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let appearance = NotchAppearance(defaults: defaults)
        let state = NotchState(appearance: appearance)
        state.cameraWidth = 180
        state.topHeight = 38
        state.expanded = true
        XCTAssertEqual(state.width, 380)
        XCTAssertEqual(state.height, 238)
        appearance.textScale = 1.4
        XCTAssertEqual(state.width, 532, accuracy: 0.001)
        XCTAssertEqual(state.height, 318, accuracy: 0.001)
        appearance.width = 680
        XCTAssertEqual(state.width, 680)
        state.close()
        XCTAssertEqual(state.width, 180)
        XCTAssertEqual(state.height, 38)
    }
}

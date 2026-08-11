import XCTest
@testable import NarzissCompanionCore

final class CompanionProfileTests: XCTestCase {
    func testInstructionsIncludeNamesAndVoiceGuidance() {
        let profile = CompanionProfile(
            assistantName: "小水仙",
            userName: "Ashley",
            personality: "热情但克制",
            voice: "marin"
        )

        XCTAssertTrue(profile.instructions.contains("小水仙"))
        XCTAssertTrue(profile.instructions.contains("Ashley"))
        XCTAssertTrue(profile.instructions.contains("热情但克制"))
        XCTAssertTrue(profile.instructions.contains("2 到 5 句"))
    }

    func testBlankValuesUseFriendlyFallbacks() {
        let profile = CompanionProfile(assistantName: " ", userName: "", personality: "\n")

        XCTAssertTrue(profile.instructions.contains("Narziss"))
        XCTAssertTrue(profile.instructions.contains("朋友"))
        XCTAssertTrue(profile.instructions.contains("热情、真诚"))
    }
}

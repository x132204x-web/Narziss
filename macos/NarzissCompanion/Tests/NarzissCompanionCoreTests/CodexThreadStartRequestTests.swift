import XCTest
@testable import NarzissCompanionCore

final class CodexThreadStartRequestTests: XCTestCase {
    func testRequestDoesNotReplaceConfiguredMCPTransports() throws {
        let request = CodexThreadStartRequest.make(
            profile: CompanionProfile(),
            cwd: "/tmp"
        )
        let params = try XCTUnwrap(request["params"] as? [String: Any])

        XCTAssertNil(
            params["config"],
            "An enabled-only mcp_servers override replaces the server transport and makes thread/start fail."
        )
    }
}

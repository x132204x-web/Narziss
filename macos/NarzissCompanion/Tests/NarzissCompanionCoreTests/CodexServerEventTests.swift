import XCTest
@testable import NarzissCompanionCore

final class CodexServerEventTests: XCTestCase {
    func testDecodesAssistantDelta() {
        let json = #"{"method":"item/agentMessage/delta","params":{"delta":"你好"}}"#.data(using: .utf8)!

        XCTAssertEqual(CodexServerEvent.decode(json: json), .assistantDelta("你好"))
    }

    func testDecodesSuccessfulTurnCompletion() {
        let json = #"{"method":"turn/completed","params":{"turn":{"status":"completed","error":null}}}"#.data(using: .utf8)!

        XCTAssertEqual(CodexServerEvent.decode(json: json), .turnCompleted(error: nil))
    }

    func testDecodesJSONRPCError() {
        let json = #"{"id":2,"error":{"code":-32600,"message":"not logged in"}}"#.data(using: .utf8)!

        XCTAssertEqual(CodexServerEvent.decode(json: json), .error("not logged in"))
    }
}

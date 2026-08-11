import XCTest
@testable import NarzissCompanionCore

final class RealtimeServerEventTests: XCTestCase {
    func testDecodesAudioDelta() {
        let bytes = Data([0, 1, 2, 3])
        let json = #"{"type":"response.output_audio.delta","delta":"\#(bytes.base64EncodedString())"}"#.data(using: .utf8)!

        XCTAssertEqual(RealtimeServerEvent.decode(json: json), .audio(bytes))
    }

    func testDecodesServerErrorMessage() {
        let json = #"{"type":"error","error":{"message":"bad key"}}"#.data(using: .utf8)!

        XCTAssertEqual(RealtimeServerEvent.decode(json: json), .error("bad key"))
    }

    func testUnknownEventIsIgnored() {
        let json = #"{"type":"rate_limits.updated"}"#.data(using: .utf8)!

        XCTAssertEqual(RealtimeServerEvent.decode(json: json), .ignored("rate_limits.updated"))
    }
}

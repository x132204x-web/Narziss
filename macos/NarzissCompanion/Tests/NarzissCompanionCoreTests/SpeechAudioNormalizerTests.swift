import AVFoundation
import XCTest
@testable import NarzissCompanionCore

final class SpeechAudioNormalizerTests: XCTestCase {
    func testRecognitionFormatDownmixesVoiceProcessedInputToMono16kHz() throws {
        let sevenChannelLayout = try XCTUnwrap(AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_AAC_7_0))
        let inputFormat = try XCTUnwrap(
            AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 48_000,
                interleaved: false,
                channelLayout: sevenChannelLayout
            )
        )

        let outputFormat = SpeechAudioNormalizer.recognitionFormat(for: inputFormat)

        XCTAssertEqual(outputFormat.channelCount, 1)
        XCTAssertEqual(outputFormat.sampleRate, 16_000, accuracy: 0.1)
        XCTAssertFalse(outputFormat.isInterleaved)
    }

    func testConverterProducesNonEmptyMonoRecognitionBuffer() throws {
        let sevenChannelLayout = try XCTUnwrap(AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_AAC_7_0))
        let inputFormat = try XCTUnwrap(
            AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 48_000,
                interleaved: false,
                channelLayout: sevenChannelLayout
            )
        )
        let inputBuffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: 4_800))
        inputBuffer.frameLength = 4_800
        for channel in 0..<Int(inputFormat.channelCount) {
            for frame in 0..<Int(inputBuffer.frameLength) {
                inputBuffer.floatChannelData?[channel][frame] = sin(Float(frame) * 0.05)
            }
        }
        let outputFormat = SpeechAudioNormalizer.recognitionFormat(for: inputFormat)
        let converter = try XCTUnwrap(AVAudioConverter(from: inputFormat, to: outputFormat))

        let outputBuffer = try XCTUnwrap(
            SpeechAudioNormalizer.convert(inputBuffer, using: converter, to: outputFormat)
        )

        XCTAssertEqual(outputBuffer.format.channelCount, 1)
        XCTAssertEqual(outputBuffer.format.sampleRate, 16_000, accuracy: 0.1)
        XCTAssertGreaterThan(outputBuffer.frameLength, 0)
        XCTAssertGreaterThan(SpeechAudioNormalizer.normalizedLevel(in: outputBuffer), 0)
    }
}

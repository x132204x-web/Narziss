import AVFoundation

public enum SpeechAudioNormalizer {
    public static func recognitionFormat(for inputFormat: AVAudioFormat) -> AVAudioFormat {
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ) ?? inputFormat
    }

    public static func convert(
        _ inputBuffer: AVAudioPCMBuffer,
        using converter: AVAudioConverter,
        to outputFormat: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let ratio = outputFormat.sampleRate / inputBuffer.format.sampleRate
        let estimatedFrames = ceil(Double(inputBuffer.frameLength) * ratio) + 32
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: AVAudioFrameCount(estimatedFrames)
        ) else { return nil }

        var conversionError: NSError?
        var suppliedInput = false
        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, inputStatus in
            guard !suppliedInput else {
                inputStatus.pointee = .noDataNow
                return nil
            }
            suppliedInput = true
            inputStatus.pointee = .haveData
            return inputBuffer
        }
        guard conversionError == nil else { return nil }
        guard status == .haveData || status == .inputRanDry else { return nil }
        return outputBuffer.frameLength > 0 ? outputBuffer : nil
    }

    public static func normalizedLevel(in buffer: AVAudioPCMBuffer) -> Float {
        guard
            buffer.frameLength > 0,
            let channels = buffer.floatChannelData
        else { return 0 }

        let sampleCount = Int(buffer.frameLength)
        var sum: Float = 0
        for index in 0..<sampleCount {
            let sample = channels[0][index]
            sum += sample * sample
        }
        let rootMeanSquare = sqrt(sum / Float(sampleCount))
        let decibels = 20 * log10(max(rootMeanSquare, 0.000_001))
        return min(max((decibels + 60) / 60, 0), 1)
    }
}

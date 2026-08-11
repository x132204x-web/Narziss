import AVFoundation
import Foundation

final class AudioIO: @unchecked Sendable {
    var onCapturedAudio: (@Sendable (Data) -> Void)?

    private let captureEngine = AVAudioEngine()
    private let playbackEngine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let playbackFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 24_000,
        channels: 1,
        interleaved: false
    )!
    private let lock = NSLock()
    private var converter: AVAudioConverter?
    private var playbackStartedAt: DispatchTime?
    private var scheduledMilliseconds = 0

    init() {
        playbackEngine.attach(player)
        playbackEngine.connect(player, to: playbackEngine.mainMixerNode, format: playbackFormat)
    }

    func requestMicrophoneAccess() async -> Bool {
        if #available(macOS 14.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        }
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { continuation.resume(returning: $0) }
        }
    }

    func startCapture() throws {
        guard !captureEngine.isRunning else { return }
        let input = captureEngine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw AudioError.noInputDevice
        }
        guard let converter = AVAudioConverter(from: inputFormat, to: playbackFormat) else {
            throw AudioError.converterUnavailable
        }
        self.converter = converter

        input.installTap(onBus: 0, bufferSize: 2_400, format: inputFormat) { [weak self] buffer, _ in
            self?.convertAndEmit(buffer)
        }
        captureEngine.prepare()
        try captureEngine.start()
    }

    func stopCapture() {
        guard captureEngine.isRunning else { return }
        captureEngine.inputNode.removeTap(onBus: 0)
        captureEngine.stop()
        converter = nil
    }

    func enqueuePlayback(_ data: Data) throws {
        guard data.count >= MemoryLayout<Int16>.size else { return }
        let frameCount = AVAudioFrameCount(data.count / MemoryLayout<Int16>.size)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: playbackFormat, frameCapacity: frameCount) else {
            throw AudioError.playbackBufferUnavailable
        }
        buffer.frameLength = frameCount
        guard let destination = buffer.int16ChannelData?[0] else {
            throw AudioError.playbackBufferUnavailable
        }
        _ = data.copyBytes(to: UnsafeMutableBufferPointer(start: destination, count: Int(frameCount)))

        if !playbackEngine.isRunning {
            playbackEngine.prepare()
            try playbackEngine.start()
        }
        lock.lock()
        if playbackStartedAt == nil { playbackStartedAt = .now() }
        scheduledMilliseconds += Int((Double(frameCount) / playbackFormat.sampleRate) * 1_000)
        lock.unlock()

        player.scheduleBuffer(buffer)
        if !player.isPlaying { player.play() }
    }

    @discardableResult
    func stopPlayback() -> Int {
        player.stop()
        return lock.withLock {
            guard let startedAt = playbackStartedAt else { return 0 }
            let elapsedNanos = DispatchTime.now().uptimeNanoseconds - startedAt.uptimeNanoseconds
            let elapsedMs = Int(elapsedNanos / 1_000_000)
            let played = min(elapsedMs, scheduledMilliseconds)
            playbackStartedAt = nil
            scheduledMilliseconds = 0
            return played
        }
    }

    private func convertAndEmit(_ inputBuffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        let ratio = playbackFormat.sampleRate / inputBuffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(inputBuffer.frameLength) * ratio).rounded(.up)) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: playbackFormat, frameCapacity: capacity) else { return }

        var supplied = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, outStatus in
            if supplied {
                outStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            outStatus.pointee = .haveData
            return inputBuffer
        }

        guard
            status != .error,
            conversionError == nil,
            output.frameLength > 0,
            let samples = output.int16ChannelData?[0]
        else { return }

        let data = Data(bytes: samples, count: Int(output.frameLength) * MemoryLayout<Int16>.size)
        onCapturedAudio?(data)
    }

    enum AudioError: LocalizedError {
        case noInputDevice
        case converterUnavailable
        case playbackBufferUnavailable

        var errorDescription: String? {
            switch self {
            case .noInputDevice: return "没有可用的麦克风输入设备。"
            case .converterUnavailable: return "无法初始化 24 kHz 语音转换器。"
            case .playbackBufferUnavailable: return "无法创建语音播放缓冲区。"
            }
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}

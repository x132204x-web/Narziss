import AVFoundation
import NarzissCompanionCore
import OSLog
import Speech

final class SystemSpeechIO: NSObject, @unchecked Sendable, AVSpeechSynthesizerDelegate {
    var onPartialTranscript: (@Sendable (String) -> Void)?
    var onFinalTranscript: (@Sendable (String) -> Void)?
    var onAudioLevel: (@Sendable (Float) -> Void)?
    var onSpeakingFinished: (@Sendable () -> Void)?
    var onError: (@Sendable (String) -> Void)?

    private lazy var audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private let synthesizer = AVSpeechSynthesizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceTask: Task<Void, Never>?
    private var currentTranscript = ""
    private var recognitionGeneration = 0
    private var hasInstalledInputTap = false
    private(set) var isListening = false
    private let logger = Logger(subsystem: "com.narziss.companion", category: "Speech")

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func requestPermissions() async -> Bool {
        let microphoneAllowed: Bool
        if #available(macOS 14.0, *) {
            microphoneAllowed = await AVAudioApplication.requestRecordPermission()
        } else {
            microphoneAllowed = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { continuation.resume(returning: $0) }
            }
        }
        guard microphoneAllowed else { return false }

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    @MainActor
    func startListening() throws {
        guard !isListening else { return }
        guard recognizer?.isAvailable == true else { throw SpeechError.recognizerUnavailable }

        recognitionGeneration += 1
        let generation = recognitionGeneration
        currentTranscript = ""
        silenceTask?.cancel()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.addsPunctuation = true
        recognitionRequest = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw SpeechError.noInputDevice }
        let recognitionFormat = SpeechAudioNormalizer.recognitionFormat(for: format)
        guard let converter = AVAudioConverter(from: format, to: recognitionFormat) else {
            throw SpeechError.unsupportedInputFormat
        }
        input.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
            guard let normalizedBuffer = SpeechAudioNormalizer.convert(
                buffer,
                using: converter,
                to: recognitionFormat
            ) else { return }
            request.append(normalizedBuffer)
            let level = SpeechAudioNormalizer.normalizedLevel(in: normalizedBuffer)
            self.onAudioLevel?(level)
        }
        hasInstalledInputTap = true

        isListening = true
        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                self?.handleRecognition(result: result, error: error, generation: generation)
            }
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
            logger.info(
                "Recognition started: input=\(format.channelCount)ch/\(format.sampleRate, format: .fixed(precision: 0))Hz output=1ch/16000Hz"
            )
        } catch {
            input.removeTap(onBus: 0)
            hasInstalledInputTap = false
            isListening = false
            recognitionRequest = nil
            recognitionTask = nil
            throw error
        }
    }

    @MainActor
    func stopListening() {
        recognitionGeneration += 1
        silenceTask?.cancel()
        silenceTask = nil
        if hasInstalledInputTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledInputTap = false
        }
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        currentTranscript = ""
        isListening = false
        onAudioLevel?(0)
    }

    @MainActor
    func speak(_ text: String, voiceIdentifier: String?) {
        stopSpeaking()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            onSpeakingFinished?()
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voiceIdentifier.flatMap(AVSpeechSynthesisVoice.init(identifier:))
            ?? AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.03
        synthesizer.speak(utterance)
    }

    @MainActor
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    @MainActor
    private func handleRecognition(
        result: SFSpeechRecognitionResult?,
        error: Error?,
        generation: Int
    ) {
        guard generation == recognitionGeneration else { return }
        if let error {
            logger.error("Recognition failed: \(error.localizedDescription, privacy: .public)")
            stopListening()
            onError?(error.localizedDescription)
            return
        }
        guard isListening else { return }
        if let result {
            let transcript = result.bestTranscription.formattedString
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !transcript.isEmpty {
                currentTranscript = transcript
                logger.info("Recognition produced \(transcript.count) characters")
                onPartialTranscript?(transcript)
                scheduleSilenceTimeout(generation: generation)
            }
            if result.isFinal { finishCurrentUtterance() }
        }
    }

    @MainActor
    private func scheduleSilenceTimeout(generation: Int) {
        silenceTask?.cancel()
        silenceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1_100))
            guard !Task.isCancelled, let self, generation == self.recognitionGeneration else { return }
            self.finishCurrentUtterance()
        }
    }

    @MainActor
    private func finishCurrentUtterance() {
        let transcript = currentTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        stopListening()
        if !transcript.isEmpty { onFinalTranscript?(transcript) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in self?.onSpeakingFinished?() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in self?.onSpeakingFinished?() }
    }

    enum SpeechError: LocalizedError {
        case recognizerUnavailable
        case noInputDevice
        case unsupportedInputFormat

        var errorDescription: String? {
            switch self {
            case .recognizerUnavailable: return "当前无法使用 macOS 语音识别。"
            case .noInputDevice: return "没有可用的麦克风输入设备。"
            case .unsupportedInputFormat: return "无法转换当前麦克风的音频格式。"
            }
        }
    }
}

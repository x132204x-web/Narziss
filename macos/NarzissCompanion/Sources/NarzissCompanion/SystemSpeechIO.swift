import AVFoundation
import Speech

final class SystemSpeechIO: NSObject, @unchecked Sendable, AVSpeechSynthesizerDelegate {
    var onPartialTranscript: (@Sendable (String) -> Void)?
    var onFinalTranscript: (@Sendable (String) -> Void)?
    var onSpeakingFinished: (@Sendable () -> Void)?
    var onError: (@Sendable (String) -> Void)?

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private let synthesizer = AVSpeechSynthesizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceTask: Task<Void, Never>?
    private var currentTranscript = ""
    private var recognitionGeneration = 0
    private(set) var isListening = false

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
        recognitionRequest = request

        let input = audioEngine.inputNode
        try? input.setVoiceProcessingEnabled(true)
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw SpeechError.noInputDevice }
        input.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                self?.handleRecognition(result: result, error: error, generation: generation)
            }
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
        } catch {
            input.removeTap(onBus: 0)
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
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        currentTranscript = ""
        isListening = false
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
        guard generation == recognitionGeneration, isListening else { return }
        if let result {
            let transcript = result.bestTranscription.formattedString
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !transcript.isEmpty {
                currentTranscript = transcript
                onPartialTranscript?(transcript)
                scheduleSilenceTimeout(generation: generation)
            }
            if result.isFinal { finishCurrentUtterance() }
        } else if let error {
            stopListening()
            onError?(error.localizedDescription)
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

        var errorDescription: String? {
            switch self {
            case .recognizerUnavailable: return "当前无法使用 macOS 语音识别。"
            case .noInputDevice: return "没有可用的麦克风输入设备。"
            }
        }
    }
}

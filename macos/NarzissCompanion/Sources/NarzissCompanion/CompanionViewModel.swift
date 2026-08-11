import Foundation
import NarzissCompanionCore

@MainActor
final class CompanionViewModel: ObservableObject {
    enum SubtitleStyle: Equatable {
        case status
        case user
        case assistant
        case error
    }

    enum ConnectionState: Equatable {
        case offline
        case connecting
        case ready
        case listening
        case thinking
        case speaking
        case failed(String)

        var label: String {
            switch self {
            case .offline: return "尚未连接"
            case .connecting: return "正在连接 Codex"
            case .ready: return "Codex 已连接"
            case .listening: return "我在听"
            case .thinking: return "Codex 正在想"
            case .speaking: return "正在回应"
            case .failed: return "需要处理"
            }
        }
    }

    @Published var messages: [CompanionMessage]
    @Published var draft = ""
    @Published var state: ConnectionState = .offline
    @Published var isShowingSettings = false
    @Published private(set) var isConversationActive = false
    @Published private(set) var subtitleText = ""
    @Published private(set) var subtitleStyle: SubtitleStyle = .status
    @Published private(set) var audioLevel: Float = 0

    let settings: CompanionSettings
    private let codex = CodexAppServerClient()
    private let speech = SystemSpeechIO()
    private var currentAssistantMessageID: UUID?
    private var currentVoiceMessageID: UUID?
    private var pendingText: String?
    private var shouldStartConversationWhenReady = false

    init(settings: CompanionSettings) {
        self.settings = settings
        self.messages = [
            CompanionMessage(
                role: .assistant,
                text: "嗨，我是 \(settings.profile.assistantName) 🌼 我会直接使用你已登录的 Codex，不需要 API Key。"
            )
        ]

        codex.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in self?.handleCodex(event) }
        }
        speech.onPartialTranscript = { [weak self] transcript in
            Task { @MainActor [weak self] in self?.showPartialTranscript(transcript) }
        }
        speech.onFinalTranscript = { [weak self] transcript in
            Task { @MainActor [weak self] in self?.submitVoiceTranscript(transcript) }
        }
        speech.onAudioLevel = { [weak self] level in
            Task { @MainActor [weak self] in self?.audioLevel = level }
        }
        speech.onSpeakingFinished = { [weak self] in
            Task { @MainActor [weak self] in self?.resumeListeningAfterSpeech() }
        }
        speech.onError = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.isConversationActive = false
                self?.state = .failed(message)
                self?.showSubtitle(message, style: .error)
            }
        }
    }

    func connect() {
        speech.stopListening()
        speech.stopSpeaking()
        isConversationActive = false
        subtitleText = ""
        audioLevel = 0
        state = .connecting
        codex.connect(profile: settings.profile)
    }

    func disconnect() {
        speech.stopListening()
        speech.stopSpeaking()
        isConversationActive = false
        subtitleText = ""
        audioLevel = 0
        codex.disconnect()
        state = .offline
    }

    func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        messages.append(CompanionMessage(role: .user, text: text))
        currentAssistantMessageID = nil
        submit(text)
    }

    func toggleVoiceConversation() {
        if isConversationActive {
            stopVoiceConversation()
        } else {
            startVoiceConversation()
        }
    }

    func startVoiceConversation() {
        guard state != .connecting else {
            shouldStartConversationWhenReady = true
            return
        }
        guard state != .offline, !isFailure else {
            shouldStartConversationWhenReady = true
            connect()
            return
        }

        showSubtitle("正在准备麦克风…", style: .status)
        Task {
            guard await speech.requestPermissions() else {
                let message = "请在系统设置中同时允许麦克风和语音识别。"
                state = .failed(message)
                showSubtitle(message, style: .error)
                return
            }
            do {
                isConversationActive = true
                try speech.startListening()
                state = .listening
                showSubtitle("我在听…", style: .status)
            } catch {
                isConversationActive = false
                state = .failed(error.localizedDescription)
                showSubtitle(error.localizedDescription, style: .error)
            }
        }
    }

    func stopVoiceConversation() {
        guard isConversationActive else { return }
        isConversationActive = false
        currentVoiceMessageID = nil
        speech.stopListening()
        speech.stopSpeaking()
        codex.interrupt()
        subtitleText = ""
        audioLevel = 0
        state = .ready
    }

    func stopResponse() {
        speech.stopSpeaking()
        codex.interrupt()
        if isConversationActive {
            resumeListeningAfterSpeech()
        } else {
            state = .ready
        }
    }

    func reconnectAfterSettings() {
        settings.save()
        connect()
    }

    func showSubtitlePreview() {
        state = .speaking
        showSubtitle("我会在这里显示正在说的话，不再打开聊天窗口。", style: .assistant)
    }

    var failureMessage: String? {
        if case .failed(let message) = state { return message }
        return nil
    }

    private var isFailure: Bool {
        if case .failed = state { return true }
        return false
    }

    private func submit(_ text: String) {
        speech.stopListening()
        speech.stopSpeaking()
        switch state {
        case .offline, .failed:
            pendingText = text
            connect()
        case .connecting:
            pendingText = text
        default:
            state = .thinking
            codex.sendText(text)
        }
    }

    private func handleCodex(_ event: CodexAppServerClient.Event) {
        switch event {
        case .ready:
            state = .ready
            if shouldStartConversationWhenReady {
                shouldStartConversationWhenReady = false
                startVoiceConversation()
            }
            if let pendingText {
                self.pendingText = nil
                state = .thinking
                codex.sendText(pendingText)
            }
        case .responseStarted:
            currentAssistantMessageID = nil
            state = .thinking
        case .assistantDelta(let delta):
            appendAssistantText(delta)
        case .responseFinished:
            guard
                isConversationActive,
                let id = currentAssistantMessageID,
                let message = messages.first(where: { $0.id == id })
            else {
                state = .ready
                return
            }
            state = .speaking
            speech.speak(message.text, voiceIdentifier: settings.profile.voice)
        case .error(let message):
            speech.stopListening()
            speech.stopSpeaking()
            isConversationActive = false
            state = .failed(message)
            showSubtitle(message, style: .error)
        }
    }

    private func showPartialTranscript(_ transcript: String) {
        guard isConversationActive else { return }
        state = .listening
        showSubtitle(transcript, style: .user)
        if
            let id = currentVoiceMessageID,
            let index = messages.firstIndex(where: { $0.id == id })
        {
            messages[index].text = "🎙️ \(transcript)"
        } else {
            let message = CompanionMessage(role: .user, text: "🎙️ \(transcript)")
            currentVoiceMessageID = message.id
            messages.append(message)
        }
    }

    private func submitVoiceTranscript(_ transcript: String) {
        guard isConversationActive else { return }
        showSubtitle("收到，正在想…", style: .status)
        if
            let id = currentVoiceMessageID,
            let index = messages.firstIndex(where: { $0.id == id })
        {
            messages[index].text = transcript
        } else {
            messages.append(CompanionMessage(role: .user, text: transcript))
        }
        currentVoiceMessageID = nil
        currentAssistantMessageID = nil
        submit(transcript)
    }

    private func resumeListeningAfterSpeech() {
        guard isConversationActive else {
            state = .ready
            return
        }
        do {
            try speech.startListening()
            state = .listening
            showSubtitle("我在听…", style: .status)
        } catch {
            isConversationActive = false
            state = .failed(error.localizedDescription)
            showSubtitle(error.localizedDescription, style: .error)
        }
    }

    private func appendAssistantText(_ delta: String) {
        guard !delta.isEmpty else { return }
        if
            let id = currentAssistantMessageID,
            let index = messages.firstIndex(where: { $0.id == id })
        {
            messages[index].text += delta
            showSubtitle(messages[index].text, style: .assistant)
        } else {
            let message = CompanionMessage(role: .assistant, text: delta)
            currentAssistantMessageID = message.id
            messages.append(message)
            showSubtitle(delta, style: .assistant)
        }
    }

    private func showSubtitle(_ text: String, style: SubtitleStyle) {
        subtitleText = text
        subtitleStyle = style
    }
}

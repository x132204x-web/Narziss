import Foundation
import NarzissCompanionCore

@MainActor
final class CompanionViewModel: ObservableObject {
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
            case .connecting: return "正在连接"
            case .ready: return "随时可以聊"
            case .listening: return "我在听"
            case .thinking: return "想一想"
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

    let settings: CompanionSettings
    private let realtime = RealtimeClient()
    private let audio = AudioIO()
    private var currentAssistantMessageID: UUID?
    private var currentResponseItemID: String?
    private var pendingText: String?
    private var shouldStartConversationWhenReady = false

    init(settings: CompanionSettings) {
        self.settings = settings
        self.messages = [
            CompanionMessage(
                role: .assistant,
                text: "嗨，我是 \(settings.profile.assistantName) 🌼 点一下开始语音对话，之后自然说话就好；你也可以随时插话。"
            )
        ]

        realtime.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handle(event)
            }
        }
        audio.onCapturedAudio = { [weak self] data in
            self?.realtime.appendAudio(data)
        }
    }

    func connect() {
        guard let key = settings.apiKey(), !key.isEmpty else {
            state = .failed("请先保存 OpenAI API Key")
            isShowingSettings = true
            return
        }
        audio.stopCapture()
        audio.stopPlayback()
        isConversationActive = false
        state = .connecting
        realtime.connect(apiKey: key, profile: settings.profile)
    }

    func disconnect() {
        audio.stopCapture()
        audio.stopPlayback()
        isConversationActive = false
        realtime.disconnect()
        state = .offline
    }

    func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        messages.append(CompanionMessage(role: .user, text: text))
        currentAssistantMessageID = nil

        switch state {
        case .ready, .listening, .speaking, .thinking:
            interruptPlaybackIfNeeded()
            state = .thinking
            realtime.sendText(text)
        default:
            pendingText = text
            connect()
        }
    }

    func toggleVoiceConversation() {
        if isConversationActive {
            stopVoiceConversation()
        } else {
            startVoiceConversation()
        }
    }

    func startVoiceConversation() {
        guard state != .connecting else { return }
        guard settings.hasAPIKey else {
            state = .failed("请先保存 OpenAI API Key")
            isShowingSettings = true
            return
        }
        guard state != .offline, !isFailure else {
            shouldStartConversationWhenReady = true
            connect()
            return
        }

        Task {
            guard await audio.requestMicrophoneAccess() else {
                state = .failed("请在系统设置中允许 Narziss 使用麦克风")
                return
            }
            do {
                realtime.startContinuousAudio()
                try audio.startCapture()
                currentAssistantMessageID = nil
                isConversationActive = true
                state = .ready
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func stopVoiceConversation() {
        guard isConversationActive else { return }
        audio.stopCapture()
        let played = audio.stopPlayback()
        realtime.cancelResponse(
            lastItemID: currentResponseItemID,
            playedMilliseconds: played
        )
        realtime.stopContinuousAudio()
        isConversationActive = false
        state = .ready
    }

    func stopResponse() {
        let played = audio.stopPlayback()
        realtime.cancelResponse(lastItemID: currentResponseItemID, playedMilliseconds: played)
        state = .ready
    }

    func reconnectAfterSettings() {
        settings.save()
        if settings.hasAPIKey { connect() }
    }

    var failureMessage: String? {
        if case .failed(let message) = state { return message }
        return nil
    }

    private var isFailure: Bool {
        if case .failed = state { return true }
        return false
    }

    private func interruptPlaybackIfNeeded() {
        let played = audio.stopPlayback()
        if played > 0 {
            realtime.cancelResponse(lastItemID: currentResponseItemID, playedMilliseconds: played)
        }
    }

    private func handle(_ event: RealtimeServerEvent) {
        switch event {
        case .sessionReady:
            state = .ready
            if shouldStartConversationWhenReady {
                shouldStartConversationWhenReady = false
                startVoiceConversation()
            }
            if let pendingText {
                self.pendingText = nil
                state = .thinking
                realtime.sendText(pendingText)
            }
        case .responseStarted:
            state = .thinking
            currentAssistantMessageID = nil
        case .responseItem(let id):
            if !id.isEmpty { currentResponseItemID = id }
        case .audio(let data):
            do {
                try audio.enqueuePlayback(data)
                state = .speaking
            } catch {
                state = .failed(error.localizedDescription)
            }
        case .assistantTranscriptDelta(let delta):
            appendAssistantText(delta)
        case .assistantTranscriptDone(let transcript):
            if currentAssistantMessageID == nil, !transcript.isEmpty {
                appendAssistantText(transcript)
            }
        case .userTranscriptDone(let transcript):
            guard !transcript.isEmpty else { return }
            if let index = messages.lastIndex(where: { $0.role == .user && $0.text.hasPrefix("🎙️") }) {
                messages[index].text = transcript
            }
        case .speechStarted:
            let played = audio.stopPlayback()
            realtime.truncateResponse(
                lastItemID: currentResponseItemID,
                playedMilliseconds: played
            )
            currentAssistantMessageID = nil
            if isConversationActive {
                messages.append(CompanionMessage(role: .user, text: "🎙️ 正在聆听…"))
                state = .listening
            }
        case .speechStopped:
            if isConversationActive { state = .thinking }
        case .responseFinished:
            if state != .listening { state = .ready }
        case .error(let message):
            if message.localizedCaseInsensitiveContains("no active response") { return }
            audio.stopCapture()
            audio.stopPlayback()
            isConversationActive = false
            state = .failed(message)
        case .ignored:
            break
        }
    }

    private func appendAssistantText(_ delta: String) {
        guard !delta.isEmpty else { return }
        if
            let id = currentAssistantMessageID,
            let index = messages.firstIndex(where: { $0.id == id })
        {
            messages[index].text += delta
        } else {
            let message = CompanionMessage(role: .assistant, text: delta)
            currentAssistantMessageID = message.id
            messages.append(message)
        }
    }
}

import SwiftUI
import NarzissCompanionCore

private extension Color {
    static let narzissBlue = Color(red: 0.42, green: 0.50, blue: 0.58)
    static let narzissBlueActive = Color(red: 0.32, green: 0.41, blue: 0.50)
}

struct FloatingCompanionView: View {
    let openChat: () -> Void

    var body: some View {
        Button(action: openChat) {
            ZStack {
                Circle()
                    .fill(Color.narzissBlue)

                Image(systemName: "staroflife.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(width: 58, height: 58)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("打开 Narziss Companion")
    }
}

struct SubtitleOverlayView: View {
    @ObservedObject var viewModel: CompanionViewModel
    @ObservedObject var settings: CompanionSettings

    var body: some View {
        ZStack(alignment: .bottom) {
            if !viewModel.subtitleText.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: iconName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: 24, height: 24)
                        .scaleEffect(viewModel.state == .listening ? 0.9 + CGFloat(viewModel.audioLevel) * 0.2 : 1)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(speakerLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(viewModel.subtitleText)
                            .font(.system(size: 19, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: 680)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(20)
        .animation(.spring(response: 0.3, dampingFraction: 0.86), value: viewModel.subtitleText)
    }

    private var speakerLabel: String {
        switch viewModel.subtitleStyle {
        case .user: return "你"
        case .assistant: return settings.profile.assistantName.isEmpty ? "Narziss" : settings.profile.assistantName
        case .error: return "需要处理"
        case .status: return viewModel.state.label
        }
    }

    private var iconName: String {
        switch viewModel.subtitleStyle {
        case .user: return "waveform"
        case .assistant: return "staroflife.fill"
        case .error: return "exclamationmark.circle.fill"
        case .status: return viewModel.state == .listening ? "mic.fill" : "ellipsis.bubble.fill"
        }
    }

    private var iconColor: Color {
        viewModel.subtitleStyle == .error ? .red : .narzissBlue
    }
}

struct CompanionChatView: View {
    @ObservedObject var viewModel: CompanionViewModel
    @ObservedObject var settings: CompanionSettings

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            conversation
            if let failure = viewModel.failureMessage {
                Text(failure)
                    .font(.caption)
                    .foregroundStyle(Color.narzissBlueActive)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            composer
        }
        .frame(minWidth: 390, idealWidth: 430, minHeight: 520, idealHeight: 600)
        .background(.regularMaterial)
        .tint(Color.narzissBlue)
        .sheet(isPresented: $viewModel.isShowingSettings) {
            SettingsView(viewModel: viewModel, settings: settings)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.narzissBlue)
                Image(systemName: "staroflife.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(settings.profile.assistantName.isEmpty ? "Narziss" : settings.profile.assistantName)
                    .font(.headline)
                Text(viewModel.state.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.state == .speaking || viewModel.state == .thinking {
                Button("停止", systemImage: "stop.fill") { viewModel.stopResponse() }
                    .labelStyle(.iconOnly)
                    .help("停止当前回复")
            }
            Button("设置", systemImage: "gearshape") { viewModel.isShowingSettings = true }
                .labelStyle(.iconOnly)
                .help("个性化设置")
        }
        .padding(16)
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(16)
            }
            .onChange(of: viewModel.messages) { _, messages in
                if let id = messages.last?.id {
                    withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                TextField("想聊点什么？", text: $viewModel.draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .onSubmit { viewModel.sendDraft() }

                Button("发送", systemImage: "arrow.up.circle.fill") { viewModel.sendDraft() }
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .disabled(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))

            Button(action: viewModel.toggleVoiceConversation) {
                Label(
                    viewModel.isConversationActive ? "结束语音对话" : "开始语音对话",
                    systemImage: viewModel.isConversationActive ? "waveform.circle.fill" : "mic.circle.fill"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isConversationActive ? Color.narzissBlueActive : Color.narzissBlue)

            Text("开启后可连续自然对话 · 双击右 Option 开始 / 结束")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}

private struct MessageBubble: View {
    let message: CompanionMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 50) }
            Text(message.text)
                .textSelection(.enabled)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(background, in: RoundedRectangle(cornerRadius: 15))
                .foregroundStyle(message.role == .user ? .white : .primary)
            if message.role != .user { Spacer(minLength: 50) }
        }
    }

    private var background: Color {
        message.role == .user ? .narzissBlue : Color(nsColor: .controlBackgroundColor)
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: CompanionViewModel
    @ObservedObject var settings: CompanionSettings
    var onClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    init(
        viewModel: CompanionViewModel,
        settings: CompanionSettings,
        onClose: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.settings = settings
        self.onClose = onClose
    }

    var body: some View {
        Form {
            Section("称呼") {
                TextField("助手名字", text: $settings.profile.assistantName)
                TextField("怎么称呼你", text: $settings.profile.userName)
            }

            Section("性格") {
                TextEditor(text: $settings.profile.personality)
                    .frame(minHeight: 120)
            }

            Section("连接与声音") {
                Text("使用当前已登录的 Codex 订阅额度；语音识别与朗读由 macOS 系统完成，不需要 API Key。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !settings.saveMessage.isEmpty {
                Text(settings.saveMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .tint(Color.narzissBlue)
        .padding()
        .frame(width: 460, height: 520)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { close() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    viewModel.reconnectAfterSettings()
                    close()
                }
            }
        }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}

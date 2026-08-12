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

struct MemeReminderView: View {
    @ObservedObject var reminder: MemeReminderController

    var body: some View {
        ZStack {
            if reminder.currentMeme != nil {
                ZStack {
                    if let image = reminder.image {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.medium)
                            .scaledToFit()
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { reminder.showAnother() }
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .frame(width: 220, height: 170)
                .background(Color.black.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(12)
                .frame(width: 244, height: 194)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Button("关闭", systemImage: "xmark.circle.fill") { reminder.dismiss() }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                        .padding(9)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
            }
        }
        .frame(width: 260, height: 218)
    }
}

struct SubtitleOverlayView: View {
    @ObservedObject var viewModel: CompanionViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            if !viewModel.subtitleText.isEmpty {
                Text(viewModel.subtitleText)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 700)
                    .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .frame(width: 760, height: 120, alignment: .bottom)
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

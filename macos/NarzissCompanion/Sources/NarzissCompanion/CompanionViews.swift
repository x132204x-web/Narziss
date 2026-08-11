import SwiftUI
import NarzissCompanionCore

struct FloatingCompanionView: View {
    @ObservedObject var viewModel: CompanionViewModel
    let openChat: () -> Void
    @State private var breathing = false

    var body: some View {
        Button(action: openChat) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.yellow.opacity(0.95), .orange.opacity(0.88), .pink.opacity(0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .orange.opacity(0.38), radius: breathing ? 18 : 8)
                    .scaleEffect(breathing ? 1.04 : 0.96)

                Circle()
                    .strokeBorder(.white.opacity(0.75), lineWidth: 2)
                    .padding(5)

                VStack(spacing: -5) {
                    Text("✦")
                        .font(.system(size: 21, weight: .bold))
                    Text("N")
                        .font(.system(size: 25, weight: .black, design: .rounded))
                }
                .foregroundStyle(.white)

                statusDot
                    .offset(x: 28, y: -28)
            }
            .frame(width: 76, height: 76)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("打开 Narziss Companion")
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 13, height: 13)
            .overlay(Circle().stroke(.white, lineWidth: 2))
    }

    private var statusColor: Color {
        switch viewModel.state {
        case .ready: return .green
        case .listening: return .red
        case .thinking, .speaking, .connecting: return .yellow
        case .failed: return .orange
        case .offline: return .gray
        }
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
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            composer
        }
        .frame(minWidth: 390, idealWidth: 430, minHeight: 520, idealHeight: 600)
        .background(.regularMaterial)
        .sheet(isPresented: $viewModel.isShowingSettings) {
            SettingsView(viewModel: viewModel, settings: settings)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(.orange.gradient)
                Text("N").font(.title3.bold()).foregroundStyle(.white)
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
                .help("个性化与连接设置")
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
            .tint(viewModel.isConversationActive ? .red : .orange)

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
        message.role == .user ? .orange : Color(nsColor: .controlBackgroundColor)
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: CompanionViewModel
    @ObservedObject var settings: CompanionSettings
    @Environment(\.dismiss) private var dismiss

    private let voices = ["marin", "cedar", "coral", "sage", "shimmer", "verse"]

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

            Section("声音") {
                Picker("Voice", selection: $settings.profile.voice) {
                    ForEach(voices, id: \.self) { Text($0).tag($0) }
                }
            }

            Section("OpenAI API") {
                SecureField(settings.hasAPIKey ? "已保存在 Keychain（输入可替换）" : "sk-…", text: $settings.apiKeyDraft)
                if settings.hasAPIKey {
                    Button("删除已保存的 API Key", role: .destructive) { settings.removeAPIKey() }
                }
                Text("密钥仅保存在这台 Mac 的 Keychain，不会写入 Narziss 文件。Realtime API 会产生独立用量。")
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
        .padding()
        .frame(width: 460, height: 520)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存并连接") {
                    viewModel.reconnectAfterSettings()
                    dismiss()
                }
            }
        }
    }
}

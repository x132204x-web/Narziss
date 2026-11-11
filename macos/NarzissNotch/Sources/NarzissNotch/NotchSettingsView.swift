import AppKit
import SwiftUI

struct NotchSettingsView: View {
    @ObservedObject var notifications: TimerNotifications
    @ObservedObject var appearance: NotchAppearance
    @ObservedObject var clipboard: ClipboardStore
    @ObservedObject var alarm: TimerAlarm
    @State private var testResult: String?
    @State private var testing = false

    var body: some View {
        TabView {
            appearancePane.tabItem { Label("Appearance", systemImage: "textformat.size") }
            clipboardPane.tabItem { Label("Clipboard", systemImage: "doc.on.clipboard") }
            timerPane.tabItem { Label("Timer", systemImage: "alarm") }
        }
        .padding(16).frame(width: 520, height: 500)
    }

    private var appearancePane: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Make it yours").font(.headline)
                Text("Changes apply immediately and are saved for next time.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Narziss", systemImage: "gearshape")
                    Spacer()
                    Text("25:00").monospacedDigit()
                }
                .font(appearance.font.font(size: 15 * appearance.textScale, weight: .medium))
                Text("Your day, a little clearer.")
                    .font(appearance.font.font(size: 12 * appearance.textScale))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(20).frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            .foregroundStyle(.white).background(.black, in: RoundedRectangle(cornerRadius: 18))
            Picker("Font", selection: $appearance.font) {
                ForEach(NotchFont.allCases) { font in
                    Text(font.rawValue).font(font.font(size: 13)).tag(font)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack { Text("Text size"); Spacer(); Text("\(Int((appearance.textScale * 100).rounded()))%").monospacedDigit().foregroundStyle(.secondary) }
                Slider(value: $appearance.textScale, in: 0.8...1.4, step: 0.05) {
                    Text("Text size")
                }.labelsHidden().accessibilityValue("\(Int((appearance.textScale * 100).rounded())) percent")
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack { Text("Notch width"); Spacer(); Text("\(Int(appearance.width)) pt").monospacedDigit().foregroundStyle(.secondary) }
                Slider(value: $appearance.width, in: 380...680, step: 10) {
                    Text("Notch width")
                }.labelsHidden()
                Text("Larger text also enlarges controls and the panel to keep them readable.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Reset to Defaults") { appearance.reset() }
            }
            Spacer(minLength: 0)
        }.padding(20)
    }

    private var clipboardPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Clipboard history", systemImage: "doc.on.clipboard").font(.headline)
            Toggle("Capture new text copies", isOn: $clipboard.isEnabled)
            Picker("Keep up to", selection: $clipboard.historyLimit) {
                ForEach(ClipboardStore.historyLimits, id: \.self) { limit in
                    Text("\(limit) clips").tag(limit)
                }
            }
            Text(clipboard.isPreview ? "Preview uses temporary sample clips. Relaunch normally for your saved history." : "Recent and starred clips are saved locally and restored after quitting or restarting. Lowering the limit removes the oldest recent clips.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("\(clipboard.history.items.count) recent clips · \(clipboard.saved.count) starred")
                .font(.caption).foregroundStyle(.secondary)
            if let error = clipboard.storageError {
                Text(error).font(.caption).foregroundStyle(.orange)
            }
            Spacer(minLength: 0)
        }.padding(24)
    }

    private var timerPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("Timer alarm", systemImage: "alarm").font(.headline)
                Text("Choose the sound that plays when the countdown reaches zero.")
                    .font(.callout).foregroundStyle(.secondary)
                Picker("Alarm sound", selection: $alarm.tone) {
                    ForEach(AlarmTone.allCases) { tone in Text(tone.rawValue).tag(tone) }
                }
                .pickerStyle(.radioGroup)
                Toggle("Mute alarm", isOn: $alarm.isMuted)
                HStack {
                    Button("Preview Sound") { alarm.preview() }.disabled(alarm.isMuted)
                    if alarm.isRinging { Button("Stop Alarm") { alarm.stop() } }
                }
                Text("The selected sound repeats until you stop the alarm, reset the timer, or choose a new duration. Your Mac’s system mute and volume still apply.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let error = alarm.error { Text(error).font(.caption).foregroundStyle(.orange) }
                Divider()
                Toggle("Show notification banner", isOn: $alarm.showBanner)
                Text("The alarm works without notification permission. The notch also opens to Time’s up.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if alarm.showBanner {
                    Text(notifications.permissionStatus).font(.subheadline)
                    if notifications.canRequestPermission {
                        Button("Enable Notifications") { Task { await notifications.requestPermission() } }
                    }
                    Button("macOS Notification Settings…") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=app.narziss.notch") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    Button("Send Test Notification") {
                        testing = true
                        Task { testResult = await notifications.sendTest(); testing = false }
                    }.disabled(testing)
                    if let testResult { Text(testResult).font(.caption).foregroundStyle(.secondary) }
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
        }
        .task { await notifications.refreshSettings() }
        .onChange(of: alarm.showBanner) { _, enabled in
            if enabled { Task { await notifications.requestPermission() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await notifications.refreshSettings() }
        }
    }
}

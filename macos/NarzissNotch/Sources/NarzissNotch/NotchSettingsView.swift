import AppKit
import SwiftUI

struct NotchSettingsView: View {
    @ObservedObject var notifications: TimerNotifications
    @ObservedObject var appearance: NotchAppearance
    @State private var testResult: String?
    @State private var testing = false

    var body: some View {
        TabView {
            appearancePane.tabItem { Label("Appearance", systemImage: "textformat.size") }
            notificationPane.tabItem { Label("Notifications", systemImage: "bell") }
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

    private var notificationPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Timer notifications", systemImage: "bell.badge")
                .font(.headline)
            Text(notifications.permissionStatus)
                .font(.subheadline).accessibilityIdentifier("notificationPermissionStatus")
            Text("Get a banner and sound when your timer finishes. The notch also opens to Time’s up.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                if notifications.canRequestPermission {
                    Button("Enable Notifications") {
                        Task { await notifications.requestPermission() }
                    }
                }
                Button("macOS Notification Settings…") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=app.narziss.notch") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            Divider()
            HStack(alignment: .top, spacing: 12) {
                Button("Send Test Notification") {
                    testing = true
                    Task {
                        testResult = await notifications.sendTest()
                        testing = false
                    }
                }
                .disabled(testing)
                if testing { ProgressView().controlSize(.small) }
            }
            if let testResult {
                Text(testResult).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .task { await notifications.refreshSettings() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await notifications.refreshSettings() }
        }
    }
}

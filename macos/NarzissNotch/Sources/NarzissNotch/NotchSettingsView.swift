import AppKit
import SwiftUI

struct NotchSettingsView: View {
    @ObservedObject var notifications: TimerNotifications
    @State private var testResult: String?
    @State private var testing = false

    var body: some View {
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
        .padding(24).frame(width: 420, height: 360, alignment: .topLeading)
        .task { await notifications.refreshSettings() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await notifications.refreshSettings() }
        }
    }
}

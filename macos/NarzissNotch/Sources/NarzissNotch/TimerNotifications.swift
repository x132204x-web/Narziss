import AppKit
import Combine
import UserNotifications

@MainActor
final class TimerNotifications: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private var authorization: Task<Bool, Never>?
    var onOpen: (() -> Void)?
    @Published private(set) var permissionStatus = "Checking…"
    @Published private(set) var canRequestPermission = false

    override init() {
        super.init()
        center.delegate = self
    }

    func prepare() {
        // Ask when the user starts a timer, and await any in-flight permission prompt
        // before delivering an alert for a short countdown.
        authorization = Task { [center] in
            do { return try await center.requestAuthorization(options: [.alert, .sound]) }
            catch { return false }
        }
    }

    func refreshSettings() async {
        let settings = await center.notificationSettings()
        canRequestPermission = settings.authorizationStatus == .notDetermined
        switch settings.authorizationStatus {
        case .notDetermined: permissionStatus = "Not enabled yet"
        case .denied: permissionStatus = "Notifications are disabled"
        case .authorized, .provisional, .ephemeral:
            permissionStatus = settings.alertSetting == .enabled ? "Notifications are enabled" : "Notification banners are disabled"
        @unknown default: permissionStatus = "Check macOS notification settings"
        }
    }

    func requestPermission() async {
        prepare()
        _ = await authorization?.value
        await refreshSettings()
    }

    func sendTest() async -> String {
        prepare()
        guard await authorization?.value == true else {
            await refreshSettings()
            return "Enable notifications in macOS Settings, then try again."
        }
        let content = UNMutableNotificationContent()
        content.title = "Narziss Notch"
        content.body = "Notifications are working. Your timer will alert you here."
        content.sound = .default
        do {
            try await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
            await refreshSettings()
            return "Test sent. If it doesn’t appear, check banner settings and Focus."
        } catch { return "Couldn’t send the test: \(error.localizedDescription)" }
    }

    static func finishedRequest() -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.userInfo = ["timerFinished": true]
        content.title = "Time’s up"
        content.body = "Your Narziss Notch timer has finished."
        content.sound = .default
        return UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    }

    func showFinished() {
        Task {
            guard await authorization?.value == true else { NSSound.beep(); return }
            do { try await center.add(Self.finishedRequest()) }
            catch { NSSound.beep() }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) {
        guard response.notification.request.content.userInfo["timerFinished"] as? Bool == true else {
            completionHandler(); return
        }
        Task { @MainActor [weak self] in self?.onOpen?(); completionHandler() }
    }
}

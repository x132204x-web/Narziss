import AppKit
import UserNotifications

@MainActor
final class TimerNotifications: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private var authorization: Task<Bool, Never>?
    var onOpen: (() -> Void)?

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

    static func finishedRequest() -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
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
        Task { @MainActor [weak self] in self?.onOpen?(); completionHandler() }
    }
}

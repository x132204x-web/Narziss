import AppKit
import SwiftUI
import NotchCore

@MainActor
final class CountdownStore: ObservableObject {
    @Published var countdown = Countdown()
    @Published var hoursInput = "0"
    @Published var minutesInput = "25"
    var duration: TimerDuration? { TimerDuration(hours: hoursInput, minutes: minutesInput) }
    func preset(_ minutes: Int) { hoursInput = "0"; minutesInput = String(minutes) }
    private var ticker: Timer?
    var onStart: (() -> Void)?
    var onFinished: (() -> Void)?
    init() {
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
    }
    func tick(at date: Date = Date()) {
        if countdown.finishIfNeeded(at: date) { onFinished?() }
    }
    func start() {
        guard let duration, duration.seconds > 0 else { return }
        onStart?()
        countdown.start(seconds: duration.seconds)
    }
    func pause(at date: Date = Date()) {
        tick(at: date)
        countdown.pause(at: date)
    }
    func label(at date: Date) -> String {
        TimerDuration.format(seconds: countdown.remaining(at: date))
    }
    func compactLabel(at date: Date) -> String? {
        if countdown.isFinished { return "Done" }
        return countdown.isRunning || countdown.isPaused ? label(at: date) : nil
    }
    deinit { ticker?.invalidate() }
}


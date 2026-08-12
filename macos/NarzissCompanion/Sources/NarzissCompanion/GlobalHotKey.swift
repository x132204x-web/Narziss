import CoreGraphics
import Foundation
import NarzissCompanionCore

final class GlobalHotKey {
    private static let rightOptionKeyCode: CGKeyCode = 61
    private static let pollingInterval: TimeInterval = 0.025

    private var timer: Timer?
    private var isRightOptionDown = false
    private var doubleTapDetector = DoubleTapDetector(maximumInterval: 0.4)
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        startPolling()
    }

    deinit {
        timer?.invalidate()
    }

    private func startPolling() {
        let timer = Timer(timeInterval: Self.pollingInterval, repeats: true) { [weak self] _ in
            self?.pollRightOptionState()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func pollRightOptionState() {
        let rightOptionIsPressed = CGEventSource.keyState(
            .combinedSessionState,
            key: Self.rightOptionKeyCode
        )
        guard rightOptionIsPressed != isRightOptionDown else { return }
        isRightOptionDown = rightOptionIsPressed
        guard rightOptionIsPressed else { return }

        let flags = CGEventSource.flagsState(.combinedSessionState)
        let conflictingModifiers: CGEventFlags = [.maskCommand, .maskControl, .maskShift]
        guard flags.intersection(conflictingModifiers).isEmpty else { return }

        if doubleTapDetector.registerTap(at: ProcessInfo.processInfo.systemUptime) {
            DispatchQueue.main.async { [weak self] in self?.action() }
        }
    }
}

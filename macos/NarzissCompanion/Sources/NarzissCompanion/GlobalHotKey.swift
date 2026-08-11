import AppKit
import ApplicationServices
import NarzissCompanionCore

final class GlobalHotKey {
    private static let rightOptionKeyCode: UInt16 = 61

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isRightOptionDown = false
    private var doubleTapDetector = DoubleTapDetector(maximumInterval: 0.4)
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        requestAccessibilityPermission()
        installMonitors()
    }

    deinit {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }

    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private func installMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    private func handle(_ event: NSEvent) {
        guard event.keyCode == Self.rightOptionKeyCode else { return }

        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let rightOptionIsPressed = modifierFlags.contains(.option)
        guard rightOptionIsPressed != isRightOptionDown else { return }
        isRightOptionDown = rightOptionIsPressed
        guard rightOptionIsPressed else { return }

        let conflictingModifiers: NSEvent.ModifierFlags = [.command, .control, .shift]
        guard modifierFlags.intersection(conflictingModifiers).isEmpty else { return }

        if doubleTapDetector.registerTap(at: event.timestamp) {
            DispatchQueue.main.async { [weak self] in self?.action() }
        }
    }
}

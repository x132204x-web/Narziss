import AppKit
import SwiftUI

@main
struct NarzissNotchApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        if let existing = NSRunningApplication.runningApplications(withBundleIdentifier: "app.narziss.notch")
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            existing.activate(options: [])
            return
        }
        let delegate = NotchDelegate()
        app.delegate = delegate
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let settingsItem = appMenu.addItem(withTitle: "Settings…", action: #selector(NotchDelegate.showSettings), keyEquivalent: ",")
        settingsItem.target = delegate
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Narziss Notch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        menu.addItem(editItem)
        app.mainMenu = menu
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

enum NotchTab: String, CaseIterable, Identifiable {
    case clock = "Clock", calendar = "Calendar", clipboard = "Clipboard", music = "Media"
    var id: Self { self }
    var symbol: String {
        switch self {
        case .clock: "clock"
        case .calendar: "calendar"
        case .clipboard: "doc.on.clipboard"
        case .music: "music.note"
        }
    }
}

@MainActor
final class NotchState: ObservableObject {
    @Published var expanded = false { didSet { if oldValue != expanded { resize?() } } }
    @Published var pinned = false
    var interacting = false
    @Published var tab: NotchTab = .clock { didSet { if oldValue != tab { resize?() } } }
    @Published var cameraWidth: CGFloat = 180
    @Published var topHeight: CGFloat = 38
    @Published var reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    var resize: (() -> Void)?
    let appearance: NotchAppearance
    init(appearance: NotchAppearance? = nil) { self.appearance = appearance ?? NotchAppearance() }
    var contentScale: CGFloat { appearance.textScale }
    var width: CGFloat {
        expanded ? max(appearance.width, 380 * contentScale, cameraWidth + 180 * contentScale) : cameraWidth
    }
    var height: CGFloat {
        guard expanded else { return topHeight }
        switch tab {
        case .clock: return topHeight + 200 * contentScale
        case .calendar: return topHeight + 280 * contentScale
        case .clipboard: return topHeight + 250 * contentScale
        case .music: return topHeight + 266 * contentScale
        }
    }
    private var collapseTask: Task<Void, Never>?
    func hover(_ inside: Bool) {
        if inside {
            collapseTask?.cancel(); collapseTask = nil
            expanded = true
        } else if !pinned && !interacting && collapseTask == nil {
            collapseTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                if self?.interacting == false && self?.pinned == false { self?.expanded = false }
                self?.collapseTask = nil
            }
        }
    }
    func showTimerFinished() {
        collapseTask?.cancel()
        collapseTask = nil
        tab = .clock
        pinned = true
        expanded = true
    }
    func close() { collapseTask?.cancel(); collapseTask = nil; pinned = false; expanded = false }

}

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class NotchDelegate: NSObject, NSApplicationDelegate {
    private let appearance = NotchAppearance()
    private lazy var state = NotchState(appearance: appearance)
    private let clipboard = ClipboardStore()
    private let calendar = CalendarStore()
    private let music = MusicStore()
    private let timer = CountdownStore()
    private let timerNotifications = TimerNotifications()
    private let alarm = TimerAlarm()
    private var panel: NotchPanel?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var screenObserver: NSObjectProtocol?
    private var activeObserver: NSObjectProtocol?
    private var refreshTimer: Timer?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        timer.onStart = { [weak self] in
            guard let self, self.alarm.showBanner else { return }
            self.timerNotifications.prepare()
        }
        timer.onDismissAlarm = { [weak self] in self?.alarm.stop() }
        timer.onFinished = { [weak self] in
            self?.state.showTimerFinished()
            self?.alarm.start()
            if self?.alarm.showBanner == true { self?.timerNotifications.showFinished() }
        }
        timerNotifications.onOpen = { [weak self] in self?.state.showTimerFinished() }
        let preview = ProcessInfo.processInfo.arguments.contains("--preview")
        if preview {
            clipboard.loadPreview(); music.loadPreview()
            state.expanded = true; state.pinned = true
        } else { clipboard.start(); music.start(); calendar.refresh() }
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--tab"),
           ProcessInfo.processInfo.arguments.count > index + 1,
           let tab = NotchTab(rawValue: ProcessInfo.processInfo.arguments[index + 1]) { state.tab = tab }
        let panel = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: NotchView(state: state, clipboard: clipboard, calendar: calendar, music: music, timer: timer, appearance: appearance, alarm: alarm, onSettings: { [weak self] in self?.showSettings() }))
        self.panel = panel
        state.resize = { [weak self] in self?.position(animated: true) }
        position(animated: false)
        panel.orderFrontRegardless()
        makeMenu()
        // A transparent folded window still needs an activation area. Mouse monitors
        // observe movement only; no Accessibility or Input Monitoring access is needed.
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseMoved() }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            MainActor.assumeIsolated { self?.mouseMoved() }
            return event
        }
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.position(animated: false) }
        }
        activeObserver = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification,
                                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.calendar.refresh() }
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.calendar.refresh() }
        }
    }
    private func mouseMoved() {
        guard let panel else { return }
        let region = state.expanded ? panel.frame : panel.frame.insetBy(dx: -8, dy: -8)
        state.hover(region.contains(NSEvent.mouseLocation))
    }
    private func position(animated: Bool) {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.screens.first,
              let panel else { return }
        panel.hasShadow = state.expanded
        let top = screen.safeAreaInsets.top
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea, top > 0 {
            state.cameraWidth = max(160, right.minX - left.maxX)
        } else { state.cameraWidth = 160 }
        state.topHeight = max(38, top)
        let size = NSSize(width: min(state.width, screen.frame.width - 24), height: state.height)
        let frame = NSRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height,
                           width: size.width, height: size.height)
        if animated && !state.reduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                panel.animator().setFrame(frame, display: true)
            }
        } else { panel.setFrame(frame, display: true) }
    }
    private func makeMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "Narziss Notch")
        let menu = NSMenu()
        menu.addItem(withTitle: "Show / Hide Notch", action: #selector(toggle), keyEquivalent: "n")
        menu.addItem(withTitle: "Keep Open", action: #selector(pin), keyEquivalent: "p")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Narziss Notch", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }
    @objc func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 500),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = clipboard.isPreview ? "Narziss Notch Settings (Preview)" : "Narziss Notch Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: NotchSettingsView(notifications: timerNotifications, appearance: appearance, clipboard: clipboard, alarm: alarm))
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func toggle() { if state.expanded { state.close() } else { state.expanded = true } }
    @objc private func pin() { state.expanded = true; state.pinned.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) {
        clipboard.stop(); music.stop(); alarm.stop(); refreshTimer?.invalidate()
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let activeObserver { NotificationCenter.default.removeObserver(activeObserver) }
    }
}

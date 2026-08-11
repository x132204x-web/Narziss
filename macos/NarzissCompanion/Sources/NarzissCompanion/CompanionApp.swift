import AppKit
import SwiftUI

@main
struct NarzissCompanionApp: App {
    @NSApplicationDelegateAdaptor(CompanionAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class CompanionAppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: CompanionWindowCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        coordinator = CompanionWindowCoordinator()
        coordinator?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
    }
}

@MainActor
final class CompanionWindowCoordinator: NSObject, NSWindowDelegate {
    private let settings = CompanionSettings()
    private lazy var viewModel = CompanionViewModel(settings: settings)
    private var petPanel: NSPanel?
    private var subtitlePanel: NSPanel?
    private var settingsPanel: NSPanel?
    private var statusItem: NSStatusItem?
    private var hotKey: GlobalHotKey?

    func start() {
        buildPetPanel()
        buildSubtitlePanel()
        buildSettingsPanel()
        buildMenuBarItem()
        hotKey = GlobalHotKey { [weak self] in self?.handleVoiceHotKey() }
        petPanel?.orderFrontRegardless()
        subtitlePanel?.orderFrontRegardless()
        if ProcessInfo.processInfo.arguments.contains("--preview-subtitle") {
            viewModel.showSubtitlePreview()
        } else {
            viewModel.connect()
            if ProcessInfo.processInfo.arguments.contains("--start-voice") {
                handleVoiceHotKey()
            }
        }
    }

    func stop() {
        viewModel.disconnect()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    private func buildPetPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 40, y: 160, width: 86, height: 86),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(
            rootView: FloatingCompanionView { [weak self] in
                self?.handleVoiceHotKey()
            }
        )
        petPanel = panel
    }

    private func buildSubtitlePanel() {
        let size = NSSize(width: 760, height: 120)
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1_440, height: 900)
        let panel = NSPanel(
            contentRect: NSRect(
                x: visibleFrame.midX - size.width / 2,
                y: visibleFrame.minY + 34,
                width: size.width,
                height: size.height
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let hostingView = NSHostingView(
            rootView: SubtitleOverlayView(viewModel: viewModel)
        )
        hostingView.frame = NSRect(origin: .zero, size: size)
        panel.contentView = hostingView
        panel.setContentSize(size)
        subtitlePanel = panel
    }

    private func buildSettingsPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 220, y: 180, width: 460, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Narziss 设置"
        panel.titlebarAppearsTransparent = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.contentView = NSHostingView(
            rootView: SettingsView(
                viewModel: viewModel,
                settings: settings,
                onClose: { [weak panel] in panel?.orderOut(nil) }
            )
        )
        settingsPanel = panel
    }

    private func buildMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "staroflife.fill", accessibilityDescription: "Narziss Companion")
        let menu = NSMenu()
        menu.addItem(withTitle: "开始 / 结束语音对话", action: #selector(toggleVoiceFromMenu), keyEquivalent: " ")
        menu.addItem(withTitle: "个性化设置…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出", action: #selector(quit), keyEquivalent: "q")
        for menuItem in menu.items { menuItem.target = self }
        item.menu = menu
        statusItem = item
    }

    private func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        settingsPanel?.makeKeyAndOrderFront(nil)
    }

    private func handleVoiceHotKey() {
        viewModel.toggleVoiceConversation()
    }

    @objc private func openSettingsFromMenu() { showSettings() }
    @objc private func toggleVoiceFromMenu() { handleVoiceHotKey() }
    @objc private func quit() { NSApp.terminate(nil) }
}

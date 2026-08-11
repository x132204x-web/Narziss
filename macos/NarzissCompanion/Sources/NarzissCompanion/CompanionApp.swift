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
    private var chatPanel: NSPanel?
    private var statusItem: NSStatusItem?
    private var hotKey: GlobalHotKey?

    func start() {
        buildPetPanel()
        buildChatPanel()
        buildMenuBarItem()
        hotKey = GlobalHotKey { [weak self] in self?.handleVoiceHotKey() }
        petPanel?.orderFrontRegardless()
        if settings.hasAPIKey { viewModel.connect() }
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
            rootView: FloatingCompanionView(viewModel: viewModel) { [weak self] in
                self?.toggleChat()
            }
        )
        petPanel = panel
    }

    private func buildChatPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 140, y: 160, width: 430, height: 600),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Narziss Companion"
        panel.titlebarAppearsTransparent = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.contentView = NSHostingView(
            rootView: CompanionChatView(viewModel: viewModel, settings: settings)
        )
        chatPanel = panel
    }

    private func buildMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Narziss Companion")
        let menu = NSMenu()
        menu.addItem(withTitle: "打开 Companion", action: #selector(openChatFromMenu), keyEquivalent: "o")
        menu.addItem(withTitle: "开始 / 结束说话", action: #selector(toggleVoiceFromMenu), keyEquivalent: " ")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出", action: #selector(quit), keyEquivalent: "q")
        for menuItem in menu.items { menuItem.target = self }
        item.menu = menu
        statusItem = item
    }

    private func toggleChat() {
        guard let chatPanel else { return }
        if chatPanel.isVisible {
            chatPanel.orderOut(nil)
        } else {
            showChat()
        }
    }

    private func showChat() {
        NSApp.activate(ignoringOtherApps: true)
        chatPanel?.makeKeyAndOrderFront(nil)
    }

    private func handleVoiceHotKey() {
        showChat()
        viewModel.toggleVoiceCapture()
    }

    @objc private func openChatFromMenu() { showChat() }
    @objc private func toggleVoiceFromMenu() { handleVoiceHotKey() }
    @objc private func quit() { NSApp.terminate(nil) }
}

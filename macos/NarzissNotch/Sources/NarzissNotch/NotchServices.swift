import AppKit
import Combine
import EventKit
import NotchCore

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var history: ClipboardHistory
    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: "clipboardEnabled")
            lastChange = pasteboard.changeCount
        }
    }
    static let historyLimits = [100, 500, 1_000, 5_000]
    @Published var historyLimit: Int {
        didSet {
            if !Self.historyLimits.contains(historyLimit) { historyLimit = 500; return }
            defaults.set(historyLimit, forKey: "clipboardHistoryLimit")
            history.setLimit(historyLimit)
            persistHistory()
        }
    }
    @Published var query = ""
    @Published var copiedID: UUID?
    @Published private(set) var saved: [SavedSnippet] = []
    @Published var storageError: String?
    @Published var showingSaved = false
    private var libraryReadable = true
    private var historyReadable = true
    private let libraryURL: URL
    private let historyURL: URL
    private let defaults: UserDefaults
    private let pasteboard: NSPasteboard
    let isPreview: Bool
    init(directory: URL? = nil, defaults: UserDefaults? = nil, pasteboard: NSPasteboard = .general,
         isPreview: Bool = ProcessInfo.processInfo.arguments.contains("--preview")) {
        self.isPreview = isPreview
        self.defaults = defaults ?? (isPreview ? UserDefaults(suiteName: "NarzissNotch.Preview.\(ProcessInfo.processInfo.processIdentifier)")! : .standard)
        self.pasteboard = pasteboard
        lastChange = pasteboard.changeCount
        isEnabled = self.defaults.object(forKey: "clipboardEnabled") as? Bool ?? true
        let storedLimit = self.defaults.integer(forKey: "clipboardHistoryLimit")
        let limit = Self.historyLimits.contains(storedLimit) ? storedLimit : 500
        historyLimit = limit
        history = ClipboardHistory(limit: limit)
        let root = directory ?? (isPreview
            ? FileManager.default.temporaryDirectory.appendingPathComponent("NarzissNotch-preview-\(ProcessInfo.processInfo.processIdentifier)")
            : FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Narziss Notch"))
        libraryURL = root.appendingPathComponent("snippets.json")
        historyURL = root.appendingPathComponent("clipboard-history.json")
        do { history = ClipboardHistory(limit: limit, items: try ClipboardArchive.load(from: historyURL)) }
        catch { historyReadable = false; storageError = "Could not read clipboard history. The file has been preserved: \(error.localizedDescription)" }
        do { saved = try SavedLibrary.load(from: libraryURL) }
        catch { libraryReadable = false; storageError = "Could not read starred clips. The file has been preserved: \(error.localizedDescription)" }
    }
    var filteredSaved: [SavedSnippet] {
        saved.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.text.localizedCaseInsensitiveContains(query) }
    }
    @discardableResult func save(title: String, text: String, id: UUID? = nil) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        // Do not overwrite an unreadable existing library.
        guard libraryReadable else { storageError = "The saved library could not be read. Restore snippets.json from a backup before saving new clips."; return false }
        var updated = saved
        let snippet = SavedSnippet(id: id ?? UUID(), title: title.isEmpty ? String(text.prefix(45)) : title, text: text)
        if let index = updated.firstIndex(where: { $0.id == snippet.id }) { updated[index] = snippet }
        else { updated.insert(snippet, at: 0) }
        return persist(updated)
    }
    func isStarred(_ clip: Clip) -> Bool { saved.contains { $0.text == clip.text } }
    func toggleStar(_ clip: Clip) {
        if let existing = saved.first(where: { $0.text == clip.text }) { deleteSaved(existing) }
        else { _ = save(title: String(clip.text.prefix(45)), text: clip.text) }
    }
    func deleteSaved(_ snippet: SavedSnippet) { _ = persist(saved.filter { $0.id != snippet.id }) }
    func copySaved(_ snippet: SavedSnippet) {
        pasteboard.clearContents()
        pasteboard.setString(snippet.text, forType: .string)
        lastChange = pasteboard.changeCount
        copiedID = snippet.id
    }
    private func persist(_ updated: [SavedSnippet]) -> Bool {
        guard libraryReadable else { return false }
        do {
            try SavedLibrary.write(updated, to: libraryURL)
            saved = updated
            return true
        } catch { storageError = "Could not save starred clips: \(error.localizedDescription)"; return false }
    }

    private var timer: Timer?
    private var lastChange: Int
    private let excludedTypes = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType",
                                 "org.nspasteboard.AutoGeneratedType", "com.agilebits.onepassword"]
    var filtered: [Clip] { history.matching(query) }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.capture() }
        }
    }
    func stop() { timer?.invalidate(); timer = nil; persistHistory() }
    private func persistHistory() {
        guard historyReadable else { return }
        do { try ClipboardArchive.write(history.items, to: historyURL) }
        catch { storageError = "Could not save clipboard history: \(error.localizedDescription)" }
    }
    func capture() {
        guard isEnabled, pasteboard.changeCount != lastChange else { return }
        lastChange = pasteboard.changeCount
        guard !excludedTypes.contains(where: { pasteboard.types?.contains(.init($0)) == true }),
              let text = pasteboard.string(forType: .string) else { return }
        history.record(text)
        persistHistory()
    }
    func copy(_ clip: Clip) {
        pasteboard.clearContents()
        pasteboard.setString(clip.text, forType: .string)
        lastChange = pasteboard.changeCount
        copiedID = clip.id
    }
    func pin(_ clip: Clip) { history.togglePin(clip.id); persistHistory() }
    func remove(_ clip: Clip) { history.remove(clip.id); persistHistory() }
    func clearRecents() { history.clearRecents(); persistHistory() }
    func clearAll() { history.clearAll(); persistHistory() }
    func loadPreview() {
        history.record("The best ideas need a little room to breathe.")
        history.record("https://developer.apple.com/swiftui/")
        history.record("Meeting notes\nKeep the first version focused. Ship the useful things.")
    }
}

@MainActor
final class CalendarStore: ObservableObject {
    @Published var selectedDate = Date()
    @Published var month = Date()
    @Published private(set) var events: [EKEvent] = []
    @Published private(set) var authorization: EKAuthorizationStatus
    @Published private(set) var message: String?
    @Published private(set) var isRequestingAccess = false
    private let store: EKEventStore
    private let readAuthorization: () -> EKAuthorizationStatus
    private let requestAccess: () async throws -> Bool
    private let isPreview: Bool
    private var observer: NSObjectProtocol?
    var hasAccess: Bool { authorization == .fullAccess }
    var isDenied: Bool { authorization == .denied || authorization == .restricted }

    init(store: EKEventStore = EKEventStore(),
         readAuthorization: @escaping () -> EKAuthorizationStatus = { EKEventStore.authorizationStatus(for: .event) },
         requestAccess: (() async throws -> Bool)? = nil,
         isPreview: Bool = ProcessInfo.processInfo.arguments.contains("--preview")) {
        self.store = store
        self.readAuthorization = readAuthorization
        self.requestAccess = requestAccess ?? { try await store.requestFullAccessToEvents() }
        self.isPreview = isPreview
        authorization = readAuthorization()
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }
    /// Reuse the OS grant; never re-prompt a granted or denied calendar on tab visits.
    func activate() async {
        refresh()
        guard !isPreview, !isRequestingAccess,
              authorization == .notDetermined || authorization == .writeOnly else { return }
        isRequestingAccess = true
        message = nil
        defer { isRequestingAccess = false }
        do { _ = try await requestAccess() }
        catch { message = error.localizedDescription }
        refresh()
    }
    func connect() { Task { await activate() } }
    func refresh() {
        authorization = readAuthorization()
        guard hasAccess else { events = []; return }
        let start = Calendar.current.startOfDay(for: selectedDate)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return }
        events = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
            .sorted { $0.startDate < $1.startDate }
    }
    func select(_ day: Date) { selectedDate = day; refresh() }
    func moveMonth(_ delta: Int) {
        month = Calendar.current.date(byAdding: .month, value: delta, to: month) ?? month
    }
    func today() { month = Date(); select(Date()) }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
}

struct NowPlaying: Sendable {
    var title: String
    var artist: String
    var duration: Double
    var position: Double
    var playing: Bool
    var bundleID: String
    var appName: String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}

/// Bundled BSD-licensed adapter, supporting any source that reports a macOS media session.
actor PlayerBridge {
    func read() async throws -> NowPlaying? {
        let data = try await run(["get", "--now", "--no-artwork"])
        guard let payload = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? [String: Any],
              let bundle = payload["bundleIdentifier"] as? String else { return nil }
        return NowPlaying(title: payload["title"] as? String ?? "Untitled media",
                          artist: payload["artist"] as? String ?? "", duration: payload["duration"] as? Double ?? 0,
                          position: payload["elapsedTimeNow"] as? Double ?? payload["elapsedTime"] as? Double ?? 0,
                          playing: payload["playing"] as? Bool ?? false, bundleID: bundle)
    }
    func command(_ action: String) async throws {
        let commands = ["playpause": "2", "next track": "4", "previous track": "5"]
        guard let command = commands[action] else { return }
        _ = try await run(["send", command])
    }
    private func run(_ arguments: [String]) async throws -> Data {
        guard let resources = Bundle.main.resourceURL,
              let frameworks = Bundle.main.privateFrameworksURL else {
            throw NSError(domain: "NotchMedia", code: 1, userInfo: [NSLocalizedDescriptionKey: "Build the app bundle with npm run package:notch to enable media."])
        }
        let script = resources.appendingPathComponent("MediaRemote/mediaremote-adapter.pl")
        let framework = frameworks.appendingPathComponent("MediaRemoteAdapter.framework")
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
                process.arguments = [script.path, framework.path] + arguments
                let output = Pipe()
                process.standardOutput = output
                process.standardError = FileHandle.nullDevice
                do {
                    try process.run()
                    let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 4, execute: timeout)
                    let data = output.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    timeout.cancel()
                    guard process.terminationStatus == 0 else {
                        throw NSError(domain: "NotchMedia", code: Int(process.terminationStatus),
                                      userInfo: [NSLocalizedDescriptionKey: "Media isn’t responding. Try playing a video or track again."])
                    }
                    continuation.resume(returning: data)
                } catch { continuation.resume(throwing: error) }
            }
        }
    }
}

@MainActor
final class MusicStore: ObservableObject {
    @Published private(set) var track: NowPlaying?
    @Published private(set) var message: String?
    private let bridge = PlayerBridge()
    private var task: Task<Void, Never>?
    private var preview = false
    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
    func stop() { task?.cancel(); task = nil }
    func refresh() async {
        guard !preview, !Task.isCancelled else { return }
        do {
            let value = try await bridge.read()
            guard !Task.isCancelled else { return }
            track = value; message = nil
        } catch {
            guard !Task.isCancelled else { return }
            track = nil; message = error.localizedDescription
        }
    }
    func send(_ action: String) {
        guard track != nil, !preview else { return }
        Task {
            do { try await bridge.command(action); await refresh() }
            catch { message = error.localizedDescription }
        }
    }
    func loadPreview() {
        preview = true
        track = NowPlaying(title: "A little space", artist: "Your daily soundtrack", duration: 245,
                           position: 87, playing: true, bundleID: "com.apple.Music")
    }
}

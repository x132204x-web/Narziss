import Combine
import Foundation
import NotchCore

@MainActor
final class IdeaStore: ObservableObject {
    @Published private(set) var items: [Idea] = []
    @Published var error: String?
    private(set) var isReadOnly = false
    private let url: URL
    var remainingCount: Int { items.filter { !$0.isDone }.count }
    var orderedItems: [Idea] {
        items.filter { !$0.isDone && $0.isMarked } + items.filter { !$0.isDone && !$0.isMarked }
            + items.filter { $0.isDone && $0.isMarked } + items.filter { $0.isDone && !$0.isMarked }
    }
    init(url: URL? = nil, isPreview: Bool = ProcessInfo.processInfo.arguments.contains("--preview")) {
        let root = isPreview
            ? FileManager.default.temporaryDirectory.appendingPathComponent("NarzissNotch-preview-\(ProcessInfo.processInfo.processIdentifier)")
            : FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Narziss Notch")
        self.url = url ?? root.appendingPathComponent("ideas.json")
        do { items = try IdeaLibrary.load(from: self.url) }
        catch {
            isReadOnly = true
            self.error = "Could not read your ideas. The existing file has been preserved: \(error.localizedDescription)"
        }
    }
    @discardableResult func add(_ text: String) -> Bool {
        guard let text = validText(text) else { return false }
        return persist([Idea(text: text)] + items)
    }
    @discardableResult func edit(_ id: UUID, text: String) -> Bool {
        guard let text = validText(text), let index = items.firstIndex(where: { $0.id == id }) else { return false }
        var updated = items; updated[index].text = text
        return persist(updated)
    }
    func toggleDone(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var updated = items; updated[index].isDone.toggle(); _ = persist(updated)
    }
    func toggleMarked(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var updated = items; updated[index].isMarked.toggle(); _ = persist(updated)
    }
    func remove(_ id: UUID) { _ = persist(items.filter { $0.id != id }) }
    private func validText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count <= 2_000 else { error = "Keep each idea under 2,000 characters."; return nil }
        return trimmed
    }
    private func persist(_ updated: [Idea]) -> Bool {
        guard !isReadOnly else { error = "Restore ideas.json from a backup before changing this list."; return false }
        do { try IdeaLibrary.write(updated, to: url); items = updated; error = nil; return true }
        catch { self.error = "Could not save your ideas: \(error.localizedDescription)"; return false }
    }
    func loadPreview() {
        guard items.isEmpty else { return }
        _ = persist([
            Idea(text: "A small idea worth remembering", isMarked: true),
            Idea(text: "Try a new focus routine"),
            Idea(text: "Write down the first idea", isDone: true)
        ])
    }
}

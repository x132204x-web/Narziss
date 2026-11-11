import Foundation

public struct Clip: Identifiable, Codable, Equatable {
    public let id: UUID
    public let text: String
    public var isPinned: Bool
    public init(text: String, isPinned: Bool = false) {
        id = UUID()
        self.text = text
        self.isPinned = isPinned
    }
}

/// Bounded clipboard history. Pinned items count toward the cap and survive clearing recents.
public struct ClipboardHistory {
    public private(set) var items: [Clip] = []
    public private(set) var limit: Int
    public init(limit: Int = 500, items: [Clip] = []) {
        self.limit = max(1, limit)
        var seen = Set<String>()
        self.items = items.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            $0.text.utf8.count <= 100_000 && seen.insert($0.text).inserted
        }
        setLimit(limit)
    }
    public mutating func setLimit(_ limit: Int) {
        self.limit = max(1, limit)
        while items.count > self.limit {
            guard let index = items.lastIndex(where: { !$0.isPinned }) else { break }
            items.remove(at: index)
        }
    }

    public mutating func record(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text.utf8.count <= 100_000 else { return }
        if let index = items.firstIndex(where: { $0.text == text }) {
            let existing = items.remove(at: index)
            items.insert(existing, at: 0)
            return
        }
        if items.count >= limit {
            guard let index = items.lastIndex(where: { !$0.isPinned }) else { return }
            items.remove(at: index)
        }
        items.insert(Clip(text: text), at: 0)
    }

    public mutating func togglePin(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned.toggle()
    }
    public mutating func remove(_ id: UUID) { items.removeAll { $0.id == id } }
    public mutating func clearRecents() { items.removeAll { !$0.isPinned } }
    public mutating func clearAll() { items.removeAll() }
    public func matching(_ query: String) -> [Clip] {
        let filtered = items.filter { query.isEmpty || $0.text.localizedCaseInsensitiveContains(query) }
        return filtered.filter(\.isPinned) + filtered.filter { !$0.isPinned }
    }
}

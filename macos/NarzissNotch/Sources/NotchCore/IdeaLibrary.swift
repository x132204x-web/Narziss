import Foundation

public struct Idea: Identifiable, Codable, Equatable {
    public let id: UUID
    public var text: String
    public var isDone: Bool
    public var isMarked: Bool
    public init(id: UUID = UUID(), text: String, isDone: Bool = false, isMarked: Bool = false) {
        self.id = id; self.text = text; self.isDone = isDone; self.isMarked = isMarked
    }
}

public enum IdeaLibrary {
    public static func load(from url: URL) throws -> [Idea] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([Idea].self, from: Data(contentsOf: url))
    }
    public static func write(_ ideas: [Idea], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(ideas).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

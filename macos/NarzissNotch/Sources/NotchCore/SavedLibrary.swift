import Foundation

public struct SavedSnippet: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var text: String
    public init(id: UUID = UUID(), title: String, text: String) {
        self.id = id; self.title = title; self.text = text
    }
}

public enum SavedLibrary {
    public static func load(from url: URL) throws -> [SavedSnippet] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([SavedSnippet].self, from: Data(contentsOf: url))
    }
    public static func write(_ snippets: [SavedSnippet], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(snippets).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

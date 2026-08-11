import Foundation

public struct CompanionMessage: Identifiable, Equatable, Sendable {
    public enum Role: Sendable {
        case user
        case assistant
        case system
    }

    public let id: UUID
    public let role: Role
    public var text: String
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

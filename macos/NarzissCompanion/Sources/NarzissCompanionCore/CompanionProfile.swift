import Foundation

public struct CompanionProfile: Codable, Equatable, Sendable {
    public var assistantName: String
    public var userName: String
    public var personality: String
    public var voice: String

    public init(
        assistantName: String = "Narziss",
        userName: String = "朋友",
        personality: String = CompanionProfile.defaultPersonality,
        voice: String = "marin"
    ) {
        self.assistantName = assistantName
        self.userName = userName
        self.personality = personality
        self.voice = voice
    }

    public static let defaultPersonality = """
    你是一位热情、真诚、有活力的桌面伙伴。主动回应用户的情绪，但不要夸张、油腻或连续堆叠感叹号。
    默认使用简洁自然的中文，像熟悉的朋友一样交流。先回应用户真正关心的事，再提供清晰可执行的帮助。
    在语音交流中使用短句，避免长篇朗读；不确定时坦率说明，不虚构事实。
    """

    public var instructions: String {
        """
        你的名字是\(normalized(assistantName, fallback: "Narziss"))。用户希望被称为\(normalized(userName, fallback: "朋友"))。

        \(normalized(personality, fallback: Self.defaultPersonality))

        这是桌面语音对话。回复应适合直接说出来，通常控制在 2 到 5 句；只有用户明确要求时才展开。
        """
    }

    private func normalized(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

import Foundation

public enum CodexThreadStartRequest {
    public static func make(
        profile: CompanionProfile,
        cwd: String
    ) -> [String: Any] {
        let instructions = """
        \(profile.instructions)

        你现在是一个纯对话桌面伙伴。直接回答用户，不要读取文件、执行命令、修改代码、调用工具或要求审批。
        """
        return [
            "method": "thread/start",
            "id": 1,
            "params": [
                "cwd": cwd,
                "approvalPolicy": "never",
                "sandbox": "read-only",
                "personality": "friendly",
                "baseInstructions": "你是 Narziss 桌面对话助手。只进行简洁、自然、友好的对话；不要使用任何工具。",
                "developerInstructions": instructions,
                "ephemeral": true,
                "serviceName": "narziss_companion"
            ]
        ]
    }
}

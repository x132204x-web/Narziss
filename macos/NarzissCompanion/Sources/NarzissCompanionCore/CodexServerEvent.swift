import Foundation

public enum CodexServerEvent: Equatable, Sendable {
    case assistantDelta(String)
    case turnCompleted(error: String?)
    case error(String)
    case ignored(String?)

    public static func decode(json: Data) -> CodexServerEvent {
        guard let object = try? JSONSerialization.jsonObject(with: json) as? [String: Any] else {
            return .error("Codex 返回了无法解析的数据。")
        }

        if let error = object["error"] as? [String: Any] {
            return .error(error["message"] as? String ?? "Codex 请求失败。")
        }

        let method = object["method"] as? String
        let params = object["params"] as? [String: Any]
        switch method {
        case "item/agentMessage/delta":
            return .assistantDelta(params?["delta"] as? String ?? "")
        case "turn/completed":
            let turn = params?["turn"] as? [String: Any]
            let error = turn?["error"] as? [String: Any]
            return .turnCompleted(error: error?["message"] as? String)
        case "error":
            let nested = params?["error"] as? [String: Any]
            return .error(
                nested?["message"] as? String
                    ?? params?["message"] as? String
                    ?? "Codex 发生错误。"
            )
        default:
            return .ignored(method)
        }
    }
}

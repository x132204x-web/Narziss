import Foundation

public enum RealtimeServerEvent: Equatable, Sendable {
    case sessionReady
    case responseStarted
    case responseItem(id: String)
    case audio(Data)
    case assistantTranscriptDelta(String)
    case assistantTranscriptDone(String)
    case userTranscriptDone(String)
    case speechStarted
    case responseFinished
    case error(String)
    case ignored(String)

    public static func decode(json: Data) -> RealtimeServerEvent {
        guard
            let object = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
            let type = object["type"] as? String
        else {
            return .error("收到无法解析的 Realtime 事件")
        }

        switch type {
        case "session.created", "session.updated":
            return .sessionReady
        case "response.created":
            return .responseStarted
        case "response.output_item.added":
            let item = object["item"] as? [String: Any]
            return .responseItem(id: item?["id"] as? String ?? "")
        case "response.output_audio.delta":
            guard
                let encoded = object["delta"] as? String,
                let audio = Data(base64Encoded: encoded)
            else { return .error("收到无效的语音数据") }
            return .audio(audio)
        case "response.output_audio_transcript.delta":
            return .assistantTranscriptDelta(object["delta"] as? String ?? "")
        case "response.output_audio_transcript.done":
            return .assistantTranscriptDone(object["transcript"] as? String ?? "")
        case "conversation.item.input_audio_transcription.completed":
            return .userTranscriptDone(object["transcript"] as? String ?? "")
        case "input_audio_buffer.speech_started":
            return .speechStarted
        case "response.done", "response.cancelled":
            return .responseFinished
        case "error":
            let error = object["error"] as? [String: Any]
            return .error(error?["message"] as? String ?? "Realtime 服务返回错误")
        default:
            return .ignored(type)
        }
    }
}

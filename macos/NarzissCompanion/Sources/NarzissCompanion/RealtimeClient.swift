import Foundation
import NarzissCompanionCore

final class RealtimeClient: @unchecked Sendable {
    var onEvent: (@Sendable (RealtimeServerEvent) -> Void)?

    private let lock = NSLock()
    private var session: URLSession?
    private var socket: URLSessionWebSocketTask?
    private var isConfigured = false
    private var profile = CompanionProfile()
    private var outboundMessages: [String] = []
    private var isSending = false

    func connect(apiKey: String, profile: CompanionProfile) {
        disconnect()
        self.profile = profile

        var components = URLComponents(string: "wss://api.openai.com/v1/realtime")!
        components.queryItems = [URLQueryItem(name: "model", value: "gpt-realtime-2.1")]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .ephemeral)
        let socket = session.webSocketTask(with: request)
        lock.withLock {
            self.session = session
            self.socket = socket
            self.isConfigured = false
            self.outboundMessages = []
            self.isSending = false
        }
        socket.resume()
        receiveNext()
    }

    func disconnect() {
        let resources = lock.withLock { () -> (URLSessionWebSocketTask?, URLSession?) in
            let resources = (socket, session)
            socket = nil
            session = nil
            isConfigured = false
            outboundMessages = []
            isSending = false
            return resources
        }
        resources.0?.cancel(with: .goingAway, reason: nil)
        resources.1?.invalidateAndCancel()
    }

    func sendText(_ text: String) {
        send([
            "type": "conversation.item.create",
            "item": [
                "type": "message",
                "role": "user",
                "content": [["type": "input_text", "text": text]]
            ]
        ])
        send(["type": "response.create"])
    }

    func appendAudio(_ data: Data) {
        send(["type": "input_audio_buffer.append", "audio": data.base64EncodedString()])
    }

    func startContinuousAudio() {
        send(["type": "input_audio_buffer.clear"])
    }

    func stopContinuousAudio() {
        send(["type": "input_audio_buffer.clear"])
    }

    func cancelResponse(lastItemID: String?, playedMilliseconds: Int?) {
        send(["type": "response.cancel"])
        truncateResponse(lastItemID: lastItemID, playedMilliseconds: playedMilliseconds)
    }

    func truncateResponse(lastItemID: String?, playedMilliseconds: Int?) {
        if let lastItemID, !lastItemID.isEmpty, let playedMilliseconds, playedMilliseconds > 0 {
            send([
                "type": "conversation.item.truncate",
                "item_id": lastItemID,
                "content_index": 0,
                "audio_end_ms": playedMilliseconds
            ])
        }
    }

    private func configureSession() {
        let shouldConfigure = lock.withLock { () -> Bool in
            guard !isConfigured else { return false }
            isConfigured = true
            return true
        }
        guard shouldConfigure else { return }

        send([
            "type": "session.update",
            "session": [
                "type": "realtime",
                "model": "gpt-realtime-2.1",
                "instructions": profile.instructions,
                "output_modalities": ["audio"],
                "audio": [
                    "input": [
                        "format": ["type": "audio/pcm", "rate": 24_000],
                        "transcription": ["model": "gpt-4o-mini-transcribe", "language": "zh"],
                        "turn_detection": [
                            "type": "semantic_vad",
                            "eagerness": "auto",
                            "create_response": true,
                            "interrupt_response": true
                        ]
                    ],
                    "output": [
                        "format": ["type": "audio/pcm"],
                        "voice": profile.voice
                    ]
                ]
            ]
        ])
    }

    private func send(_ event: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(event) else { return }
        do {
            let data = try JSONSerialization.data(withJSONObject: event)
            guard let text = String(data: data, encoding: .utf8) else { return }
            let shouldDrain = lock.withLock { () -> Bool in
                outboundMessages.append(text)
                guard !isSending else { return false }
                isSending = true
                return true
            }
            if shouldDrain { drainOutboundMessages() }
        } catch {
            onEvent?(.error(error.localizedDescription))
        }
    }

    private func drainOutboundMessages() {
        let next = lock.withLock { () -> (URLSessionWebSocketTask?, String?) in
            (socket, outboundMessages.first)
        }
        guard let socket = next.0, let message = next.1 else {
            lock.withLock { isSending = false }
            return
        }

        Task { [weak self] in
            do {
                try await socket.send(.string(message))
                guard let self else { return }
                let hasMore = self.lock.withLock { () -> Bool in
                    if !self.outboundMessages.isEmpty { self.outboundMessages.removeFirst() }
                    if self.outboundMessages.isEmpty {
                        self.isSending = false
                        return false
                    }
                    return true
                }
                if hasMore { self.drainOutboundMessages() }
            } catch {
                guard let self else { return }
                self.lock.withLock {
                    self.outboundMessages = []
                    self.isSending = false
                }
                self.onEvent?(.error(error.localizedDescription))
            }
        }
    }

    private func receiveNext() {
        let socket = lock.withLock { self.socket }
        Task { [weak self, weak socket] in
            guard let self, let socket else { return }
            do {
                let message = try await socket.receive()
                let data: Data
                switch message {
                case .data(let value): data = value
                case .string(let value): data = Data(value.utf8)
                @unknown default: return
                }

                let rawType = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["type"] as? String
                if rawType == "session.created" {
                    configureSession()
                } else {
                    onEvent?(RealtimeServerEvent.decode(json: data))
                }
                receiveNext()
            } catch {
                if socket.closeCode == .invalid {
                    onEvent?(.error(error.localizedDescription))
                }
            }
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}

import Foundation
import NarzissCompanionCore

final class CodexAppServerClient: @unchecked Sendable {
    enum Event: Sendable {
        case ready
        case responseStarted
        case assistantDelta(String)
        case responseFinished
        case error(String)
    }

    var onEvent: (@Sendable (Event) -> Void)?

    private let queue = DispatchQueue(label: "com.narziss.companion.codex-app-server")
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var outputBuffer = Data()
    private var errorBuffer = Data()
    private var threadID: String?
    private var turnID: String?
    private var turnRequestIDs = Set<Int>()
    private var nextRequestID = 100
    private var pendingText: String?
    private var profile = CompanionProfile()
    private var intentionalShutdown = false

    func connect(profile: CompanionProfile) {
        queue.async { [weak self] in
            guard let self else { return }
            self.stopProcess()
            self.profile = profile
            self.startProcess()
        }
    }

    func disconnect() {
        queue.async { [weak self] in self?.stopProcess() }
    }

    func sendText(_ text: String) {
        queue.async { [weak self] in
            guard let self else { return }
            guard self.threadID != nil else {
                self.pendingText = text
                return
            }
            if self.turnID != nil {
                self.pendingText = text
                self.interruptCurrentTurn()
            } else {
                self.startTurn(text)
            }
        }
    }

    func interrupt() {
        queue.async { [weak self] in self?.interruptCurrentTurn() }
    }

    private func startProcess() {
        guard let executableURL = Self.findCodexExecutable() else {
            emit(.error("没有找到 Codex。请先安装并登录 Codex，然后重新打开 Narziss。"))
            return
        }

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = executableURL
        process.arguments = Self.leanAppServerArguments()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.queue.async { self?.consumeOutput(data) }
        }
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.queue.async { self?.consumeError(data) }
        }
        process.terminationHandler = { [weak self] terminated in
            self?.queue.async { self?.processDidTerminate(terminated) }
        }

        do {
            try process.run()
            self.process = process
            self.inputPipe = inputPipe
            self.outputPipe = outputPipe
            self.errorPipe = errorPipe
            intentionalShutdown = false
            send([
                "method": "initialize",
                "id": 0,
                "params": [
                    "clientInfo": [
                        "name": "narziss_companion",
                        "title": "Narziss Companion",
                        "version": "0.11.6"
                    ]
                ]
            ])
        } catch {
            emit(.error("无法启动 Codex：\(error.localizedDescription)"))
            stopProcess()
        }
    }

    private func stopProcess() {
        intentionalShutdown = true
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminationHandler = nil
        if process?.isRunning == true { process?.terminate() }
        try? inputPipe?.fileHandleForWriting.close()
        process = nil
        inputPipe = nil
        outputPipe = nil
        errorPipe = nil
        outputBuffer.removeAll(keepingCapacity: false)
        errorBuffer.removeAll(keepingCapacity: false)
        threadID = nil
        turnID = nil
        turnRequestIDs.removeAll()
        pendingText = nil
    }

    private func consumeOutput(_ data: Data) {
        outputBuffer.append(data)
        while let newlineIndex = outputBuffer.firstIndex(of: 0x0A) {
            let line = outputBuffer[..<newlineIndex]
            outputBuffer.removeSubrange(...newlineIndex)
            guard !line.isEmpty else { continue }
            handleMessage(Data(line))
        }
    }

    private func consumeError(_ data: Data) {
        errorBuffer.append(data)
        if errorBuffer.count > 8_192 {
            errorBuffer.removeFirst(errorBuffer.count - 8_192)
        }
    }

    private func handleMessage(_ data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            emit(.error("Codex 返回了无法解析的数据。"))
            return
        }

        if let id = object["id"] as? Int {
            if let error = object["error"] as? [String: Any] {
                emit(.error(friendlyError(error["message"] as? String ?? "Codex 请求失败。")))
                return
            }
            if id == 0 {
                send(["method": "initialized", "params": [:]])
                startThread()
                return
            }
            if id == 1,
               let result = object["result"] as? [String: Any],
               let thread = result["thread"] as? [String: Any],
               let id = thread["id"] as? String
            {
                threadID = id
                emit(.ready)
                if let pendingText {
                    self.pendingText = nil
                    startTurn(pendingText)
                }
                return
            }
            if turnRequestIDs.remove(id) != nil,
               let result = object["result"] as? [String: Any],
               let turn = result["turn"] as? [String: Any]
            {
                turnID = turn["id"] as? String
                emit(.responseStarted)
                return
            }
        }

        switch CodexServerEvent.decode(json: data) {
        case .assistantDelta(let delta):
            if !delta.isEmpty { emit(.assistantDelta(delta)) }
        case .turnCompleted(let error):
            turnID = nil
            if let error {
                emit(.error(friendlyError(error)))
            } else {
                emit(.responseFinished)
            }
            if let pendingText {
                self.pendingText = nil
                startTurn(pendingText)
            }
        case .error(let message):
            emit(.error(friendlyError(message)))
        case .ignored:
            break
        }
    }

    private func startThread() {
        send(CodexThreadStartRequest.make(
            profile: profile,
            cwd: NSTemporaryDirectory()
        ))
    }

    private func startTurn(_ text: String) {
        guard let threadID else {
            pendingText = text
            return
        }
        let id = nextRequestID
        nextRequestID += 1
        turnRequestIDs.insert(id)
        send([
            "method": "turn/start",
            "id": id,
            "params": [
                "threadId": threadID,
                "input": [["type": "text", "text": text]],
                "approvalPolicy": "never",
                "sandboxPolicy": ["type": "readOnly", "networkAccess": false],
                "personality": "friendly",
                "effort": "low",
                "summary": "none"
            ]
        ])
    }

    private func interruptCurrentTurn() {
        guard let threadID, let turnID else { return }
        let id = nextRequestID
        nextRequestID += 1
        send([
            "method": "turn/interrupt",
            "id": id,
            "params": ["threadId": threadID, "turnId": turnID]
        ])
    }

    private func send(_ message: [String: Any]) {
        guard
            JSONSerialization.isValidJSONObject(message),
            var data = try? JSONSerialization.data(withJSONObject: message)
        else { return }
        data.append(0x0A)
        do {
            try inputPipe?.fileHandleForWriting.write(contentsOf: data)
        } catch {
            emit(.error("无法与 Codex 通信：\(error.localizedDescription)"))
        }
    }

    private func processDidTerminate(_ terminated: Process) {
        guard process === terminated else { return }
        let detail = String(data: errorBuffer, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        process = nil
        guard !intentionalShutdown else { return }
        emit(.error(detail?.isEmpty == false ? detail! : "Codex 连接已中断。"))
    }

    private func friendlyError(_ message: String) -> String {
        let lowercase = message.lowercased()
        if lowercase.contains("unauthorized") || lowercase.contains("not logged") || lowercase.contains("authentication") {
            return "Codex 尚未登录。请先在 Codex 中使用 ChatGPT 登录。"
        }
        if lowercase.contains("usage limit") || lowercase.contains("rate limit") {
            return "你的 Codex 额度暂时已用完，请在额度恢复后再试。"
        }
        return message
    }

    private func emit(_ event: Event) {
        onEvent?(event)
    }

    private static func findCodexExecutable() -> URL? {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path
        let pathCandidates = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map { "\($0)/codex" }
        let candidates = [
            "\(home)/.local/bin/codex",
            "\(home)/.codex/packages/standalone/current/bin/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ] + pathCandidates

        for path in candidates where fileManager.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    private static func leanAppServerArguments() -> [String] {
        [
            "app-server",
            "--disable", "plugins",
            "--disable", "apps",
            "--disable", "browser_use",
            "--disable", "computer_use",
            "--disable", "hooks",
            "--disable", "image_generation",
            "--disable", "multi_agent",
            "--disable", "shell_tool",
            "--disable", "skill_search",
            "--disable", "unified_exec",
            "--disable", "view_image",
            "--disable", "workspace_dependencies",
            "-c", "agents.enabled=false",
            "-c", "project_doc_max_bytes=0"
        ]
    }

}

import Foundation

public struct Countdown {
    public private(set) var deadline: Date?
    public private(set) var pausedRemaining: TimeInterval = 0
    public private(set) var isFinished = false
    public var isRunning: Bool { deadline != nil }
    public var isPaused: Bool { deadline == nil && pausedRemaining > 0 }
    public init() {}
    public func remaining(at date: Date) -> TimeInterval {
        max(0, deadline.map { $0.timeIntervalSince(date) } ?? pausedRemaining)
    }
    public mutating func start(seconds: TimeInterval, at date: Date = Date()) {
        guard seconds.isFinite, seconds > 0 else { return }
        pausedRemaining = 0
        isFinished = false
        deadline = date.addingTimeInterval(seconds)
    }
    public mutating func pause(at date: Date = Date()) {
        guard deadline != nil else { return }
        pausedRemaining = remaining(at: date)
        deadline = nil
        isFinished = pausedRemaining == 0
    }
    public mutating func resume(at date: Date = Date()) {
        guard isPaused else { return }
        start(seconds: pausedRemaining, at: date)
    }
    /// Returns true exactly once per completed countdown, including after sleep/wake.
    public mutating func finishIfNeeded(at date: Date = Date()) -> Bool {
        guard let deadline, date >= deadline else { return false }
        self.deadline = nil
        pausedRemaining = 0
        isFinished = true
        return true
    }
    public mutating func reset() { self = Countdown() }
}

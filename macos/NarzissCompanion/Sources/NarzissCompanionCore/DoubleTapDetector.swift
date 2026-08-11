import Foundation

public struct DoubleTapDetector: Sendable {
    private let maximumInterval: TimeInterval
    private var firstTapTimestamp: TimeInterval?

    public init(maximumInterval: TimeInterval = 0.4) {
        self.maximumInterval = maximumInterval
    }

    public mutating func registerTap(at timestamp: TimeInterval) -> Bool {
        guard let firstTapTimestamp else {
            self.firstTapTimestamp = timestamp
            return false
        }

        let interval = timestamp - firstTapTimestamp
        guard interval >= 0, interval <= maximumInterval else {
            self.firstTapTimestamp = timestamp
            return false
        }

        self.firstTapTimestamp = nil
        return true
    }
}

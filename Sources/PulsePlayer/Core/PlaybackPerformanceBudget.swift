import Foundation

/// Optional runtime quality gates. `nil` disables an individual threshold.
public struct PlaybackPerformanceBudget: Sendable, Equatable {
    public var maximumTTFFMilliseconds: Double?
    public var maximumRebufferCount: Int?
    public var maximumTotalRebufferMilliseconds: Double?

    public init(
        maximumTTFFMilliseconds: Double? = nil,
        maximumRebufferCount: Int? = nil,
        maximumTotalRebufferMilliseconds: Double? = nil
    ) {
        self.maximumTTFFMilliseconds = maximumTTFFMilliseconds
        self.maximumRebufferCount = maximumRebufferCount
        self.maximumTotalRebufferMilliseconds = maximumTotalRebufferMilliseconds
    }

    public static let disabled = PlaybackPerformanceBudget()
}

public enum PerformanceBudgetViolation: Sendable, Equatable {
    case timeToFirstFrame(actualMilliseconds: Double, maximumMilliseconds: Double)
    case rebufferCount(actual: Int, maximum: Int)
    case totalRebuffer(actualMilliseconds: Double, maximumMilliseconds: Double)
}

/// Typed player errors with recoverability for host + auto-retry.
public enum PlayerError: Error, Sendable, Equatable {
    case invalidSource(String)
    case assetLoadFailed(underlying: String, recoverable: Bool)
    case itemFailed(domain: String, code: Int, message: String, recoverable: Bool)
    case startupTimedOut
    case stalledExhausted(attempts: Int)
    case networkUnavailable
    case cancelled
    case sessionInvalidated
    case unknown(String, recoverable: Bool)

    public var isRecoverable: Bool {
        switch self {
        case .cancelled, .invalidSource, .sessionInvalidated:
            return false
        case .startupTimedOut, .stalledExhausted, .networkUnavailable:
            return true
        case .assetLoadFailed(_, let r),
             .itemFailed(_, _, _, let r),
             .unknown(_, let r):
            return r
        }
    }
}

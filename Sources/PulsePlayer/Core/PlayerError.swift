import Foundation

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

    /// Short message for UI (not the raw enum dump).
    public var userMessage: String {
        switch self {
        case .invalidSource(let reason):
            return reason
        case .assetLoadFailed(let underlying, _):
            return friendlyNetworkOrAccess(underlying)
        case .itemFailed(let domain, let code, let message, _):
            return friendlyItemFailed(domain: domain, code: code, message: message)
        case .startupTimedOut:
            return "Playback took too long to start. Check the network and try again."
        case .stalledExhausted(let attempts):
            return "Playback stalled after \(attempts) retries."
        case .networkUnavailable:
            return "Network unavailable."
        case .cancelled:
            return "Cancelled."
        case .sessionInvalidated:
            return "Player session was closed."
        case .unknown(let message, _):
            return message
        }
    }

    /// Host guidance for recovery UX.
    public var suggestedAction: PlayerErrorAction {
        switch self {
        case .sessionInvalidated:
            return .recreateSession
        case .cancelled, .invalidSource:
            return .changeSource
        case .networkUnavailable:
            return .checkNetwork
        case .startupTimedOut, .stalledExhausted:
            return .retry
        case .assetLoadFailed(_, let recoverable),
             .itemFailed(_, _, _, let recoverable),
             .unknown(_, let recoverable):
            if !recoverable { return .changeSource }
            return .retry
        }
    }
}

extension PlayerError: LocalizedError {
    public var errorDescription: String? { userMessage }
}

private func friendlyItemFailed(domain: String, code: Int, message: String) -> String {
    if domain == "NSURLErrorDomain" {
        switch code {
        case -1009:
            return "No internet connection."
        case -1001:
            return "The request timed out."
        case -1003, -1004:
            return "Could not find the media server."
        case -1102:
            // NSURLErrorNoPermissionsToReadFile — also seen on blocked remote assets.
            return "No permission to access this media (blocked URL, expired link, or restricted file)."
        case -999:
            return "Request cancelled."
        default:
            break
        }
    }
    if domain == "CoreMediaErrorDomain" {
        switch code {
        case -16044, -16045, -16046:
            // Common HLS playlist / segment open failures on sim or bad manifests.
            return "Could not open this HLS stream (playlist or segment error). Try another source."
        case -12880, -12881:
            return "HLS playlist parse failed."
        case -12642, -12643, -12645:
            return "HLS media segment error."
        default:
            return "Media engine error (\(code))."
        }
    }
    if domain == "AVFoundationErrorDomain" {
        switch code {
        case -11828, -11829:
            return "Unsupported or corrupt media format."
        case -11800:
            return "Media playback failed."
        default:
            break
        }
    }
    let clean = message.trimmingCharacters(in: .whitespacesAndNewlines)
    if clean.isEmpty {
        return "Playback failed (\(domain) \(code))."
    }
    return clean
}

private func friendlyNetworkOrAccess(_ message: String) -> String {
    let lower = message.lowercased()
    if lower.contains("permission") {
        return "No permission to access this media."
    }
    if lower.contains("timed out") || lower.contains("timeout") {
        return "The request timed out."
    }
    if lower.contains("offline") || lower.contains("internet") {
        return "No internet connection."
    }
    return message
}

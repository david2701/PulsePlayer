import Foundation

/// Optional host log sink. Default uses `os.Logger` via internal `PulseLog`.
public protocol PulsePlayerLogHandler: Sendable {
    func log(level: PulsePlayerLogLevel, message: String)
}

public enum PulsePlayerLogLevel: Sendable {
    case debug
    case info
    case error
}

public struct DefaultPulsePlayerLogHandler: PulsePlayerLogHandler {
    public init() {}

    public func log(level: PulsePlayerLogLevel, message: String) {
        let safe = URLSanitizer.sanitizeMessage(message)
        switch level {
        case .debug: PulseLog.debug(safe)
        case .info: PulseLog.info(safe)
        case .error: PulseLog.error(safe)
        }
    }
}

/// Maps CoreMedia / AVFoundation domain+code pairs to recoverability.
public enum CoreMediaErrorMap: Sendable {
    /// Unknown codes default to recoverable so the host/session can budget retries.
    public static func recoverability(domain: String, code: Int) -> Bool {
        // Fatal-ish media format / decode failures
        let fatalCodes: Set<Int> = [
            -11800, // AVErrorUnknown
            -11819, // AVErrorMediaServicesWereReset — recoverable actually
            -11828, // AVErrorFileFormatNotRecognized
            -11829, // AVErrorFileFailedToParse
            -11833, // content not authorized
            -11853, // content is unavailable
        ]
        // Treat media services reset as recoverable
        if domain == "AVFoundationErrorDomain" && code == -11819 {
            return true
        }
        if domain == "AVFoundationErrorDomain" && fatalCodes.contains(code) {
            // -11819 already returned
            if code == -11828 || code == -11829 || code == -11833 || code == -11853 {
                return false
            }
        }
        // Network-ish CoreMedia
        if domain == "CoreMediaErrorDomain" {
            // Common transient segment failures tend to be negative; default recoverable.
            if code == -12660 || code == -12938 { // example auth / format
                return false
            }
            return true
        }
        if domain == "NSURLErrorDomain" {
            // Cancelled
            if code == -999 { return false }
            return true
        }
        return true
    }

    public static func makeItemFailed(
        domain: String,
        code: Int,
        message: String
    ) -> PlayerError {
        let sanitized = URLSanitizer.sanitizeMessage(message)
        return .itemFailed(
            domain: domain,
            code: code,
            message: sanitized,
            recoverable: recoverability(domain: domain, code: code)
        )
    }
}

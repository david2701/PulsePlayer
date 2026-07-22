import Foundation
import os

enum PulseLog {
    private static let logger = Logger(
        subsystem: "com.pulseplayer",
        category: "PulsePlayer"
    )

    static func debug(_ message: String) {
        #if DEBUG
        logger.debug("\(message, privacy: .public)")
        #endif
    }

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }

    static func url(_ url: URL) -> String {
        URLSanitizer.sanitizeURL(url)
    }
}

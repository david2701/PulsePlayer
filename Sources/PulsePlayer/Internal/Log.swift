import Foundation
import os

enum PulseLog {
    private static let logger = Logger(
        subsystem: "com.pulseplayer",
        category: "PulsePlayer"
    )

    static func debug(_ message: String) {
        #if DEBUG
        logger.debug("\(message, privacy: .private(mask: .hash))")
        #endif
    }

    static func info(_ message: String) {
        logger.info("\(message, privacy: .private(mask: .hash))")
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .private(mask: .hash))")
    }

    static func url(_ url: URL) -> String {
        URLSanitizer.sanitizeURL(url)
    }
}

import Foundation

/// Sanitized AVFoundation diagnostic suitable for logs and telemetry export.
public enum PlaybackDiagnostic: Sendable, Equatable {
    case accessLog(
        indicatedBitrate: Double?,
        observedBitrate: Double?,
        droppedVideoFrames: Int,
        stalls: Int,
        segmentsDownloaded: Int
    )
    case errorLog(domain: String, statusCode: Int, comment: String?)
}

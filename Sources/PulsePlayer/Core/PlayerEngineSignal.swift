import Foundation

/// Engine → session signals. Package-visible; session maps to `PlayerEvent` / SM.
package enum PlayerEngineSignal: Sendable, Equatable {
    case itemStatusReady
    case itemFailed(domain: String, code: Int, message: String)
    case bufferEmpty
    case bufferHealthy
    case didPlayToEnd
    case timeControlPlaying
    case timeControlWaiting
    case timeControlPaused
    case readyForDisplay
    case accessLog(indicatedBps: Double?, observedBps: Double?)
    case externalPlayback(Bool)
    case timeObserved(TimeInterval)
    case durationKnown(TimeInterval?)
    case bufferProgress(Double?)
}

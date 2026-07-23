import Foundation

/// Additive production signals kept separate from the SemVer-frozen `PlayerEvent`.
public enum ProductionPlayerEvent: Sendable, Equatable {
    case credentialRefreshStarted(reason: PlaybackCredentialRefreshReason)
    case credentialRefreshSucceeded(reason: PlaybackCredentialRefreshReason)
    case credentialRefreshFailed(reason: PlaybackCredentialRefreshReason, message: String)
    case sourceFallback(fromIndex: Int, toIndex: Int)
    case liveLatencyChanged(seconds: TimeInterval)
    case liveCatchUpChanged(active: Bool)
    case audioSession(AudioSessionEvent)
    case applicationLifecycle(ApplicationLifecycleEvent)
    case interstitialStarted(id: String)
    case interstitialEnded(id: String)
    case interstitialSkippable(id: String, canSkip: Bool)
    case editorialMarkerChanged(id: String?)
    case upNextPresented(id: String)
    case upNextAccepted(id: String)
    case upNextDismissed(id: String)
    case performanceBudgetExceeded(PerformanceBudgetViolation)
    case persistableContentKeyStored(assetID: String)
    case diagnostic(PlaybackDiagnostic)
}
@MainActor
final class ProductionPlayerEventBus {
    private struct Subscriber {
        let id: UUID
        let continuation: AsyncStream<ProductionPlayerEvent>.Continuation
    }

    private var subscribers: [Subscriber] = []

    func makeStream() -> AsyncStream<ProductionPlayerEvent> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(256)) { continuation in
            subscribers.append(Subscriber(id: id, continuation: continuation))
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor in
                    self?.subscribers.removeAll { $0.id == id }
                }
            }
        }
    }

    func yield(_ event: ProductionPlayerEvent) {
        for subscriber in subscribers {
            subscriber.continuation.yield(event)
        }
    }

    func finish() {
        let snapshot = subscribers
        subscribers = []
        for subscriber in snapshot {
            subscriber.continuation.finish()
        }
    }
}

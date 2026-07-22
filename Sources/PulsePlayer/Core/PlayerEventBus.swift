import Foundation

/// Multi-subscriber live-only event fan-out. Drop-oldest per subscriber (buffer 64).
@MainActor
public final class PlayerEventBus {
    public static let defaultBufferSize = 64

    private struct Subscriber {
        let id: UUID
        let continuation: AsyncStream<PlayerEvent>.Continuation
    }

    private var subscribers: [Subscriber] = []
    private let bufferSize: Int

    public init(bufferSize: Int = PlayerEventBus.defaultBufferSize) {
        self.bufferSize = max(1, bufferSize)
    }

    /// New live-only subscription. Prior events are not replayed.
    public func makeStream() -> AsyncStream<PlayerEvent> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(bufferSize)) { continuation in
            let sub = Subscriber(id: id, continuation: continuation)
            self.subscribers.append(sub)
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor in
                    self?.remove(id: id)
                }
            }
        }
    }

    public func yield(_ event: PlayerEvent) {
        // Copy to avoid mutation during iteration edge cases.
        let snapshot = subscribers
        for sub in snapshot {
            sub.continuation.yield(event)
        }
    }

    public func finish() {
        let snapshot = subscribers
        subscribers.removeAll()
        for sub in snapshot {
            sub.continuation.finish()
        }
    }

    private func remove(id: UUID) {
        subscribers.removeAll { $0.id == id }
    }
}

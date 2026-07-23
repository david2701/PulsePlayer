import Foundation
@testable import PulsePlayer

actor CredentialProvider: PlaybackCredentialProviding {
    private var count = 0

    func credentials(
        for source: MediaSource,
        reason: PlaybackCredentialRefreshReason
    ) async throws -> PlaybackCredentials {
        _ = source
        _ = reason
        count += 1
        return PlaybackCredentials(headers: ["Authorization": "Bearer token-\(count)"])
    }
}

actor ExpiringCredentialProvider: PlaybackCredentialProviding {
    private var count = 0

    func credentials(
        for source: MediaSource,
        reason: PlaybackCredentialRefreshReason
    ) async throws -> PlaybackCredentials {
        _ = source
        _ = reason
        count += 1
        return PlaybackCredentials(
            headers: ["Authorization": "Bearer proactive-\(count)"],
            refreshAfter: count == 1 ? .milliseconds(2) : nil
        )
    }
}

actor TelemetrySink: PlaybackTelemetrySink {
    private var values: [PlaybackTelemetryRecord] = []

    func record(_ record: PlaybackTelemetryRecord) async {
        values.append(record)
    }

    func records() -> [PlaybackTelemetryRecord] {
        values
    }
}

@MainActor
final class EventAudioSession: AudioSessionConfiguring {
    private var continuation: AsyncStream<AudioSessionEvent>.Continuation?

    func activateForPlayback(background: Bool) throws {
        _ = background
    }

    func deactivate() throws {}

    func makeEventStream() -> AsyncStream<AudioSessionEvent> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    func emit(_ event: AudioSessionEvent) {
        continuation?.yield(event)
    }
}

@MainActor
final class EventApplicationLifecycle: ApplicationLifecycleObserving {
    private var continuation: AsyncStream<ApplicationLifecycleEvent>.Continuation?

    func makeEventStream() -> AsyncStream<ApplicationLifecycleEvent> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    func emit(_ event: ApplicationLifecycleEvent) {
        continuation?.yield(event)
    }
}

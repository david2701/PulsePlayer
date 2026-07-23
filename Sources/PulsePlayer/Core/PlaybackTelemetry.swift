import Foundation

/// A single ordered observation emitted by a playback session.
public struct PlaybackTelemetryRecord: Sendable, Equatable {
    public let sessionID: UUID
    public let playbackID: UUID
    public let sourceID: String?
    public let timestamp: Date
    public let event: PlayerEvent

    public init(
        sessionID: UUID,
        playbackID: UUID,
        sourceID: String?,
        timestamp: Date = Date(),
        event: PlayerEvent
    ) {
        self.sessionID = sessionID
        self.playbackID = playbackID
        self.sourceID = sourceID
        self.timestamp = timestamp
        self.event = event
    }
}

/// Export target for QoE, lifecycle, recovery, DRM, and editorial events.
public protocol PlaybackTelemetrySink: Sendable {
    func record(_ record: PlaybackTelemetryRecord) async
    func recordProduction(_ record: ProductionPlaybackTelemetryRecord) async
}

public extension PlaybackTelemetrySink {
    func recordProduction(_ record: ProductionPlaybackTelemetryRecord) async {
        _ = record
    }
}

public struct NoOpPlaybackTelemetrySink: PlaybackTelemetrySink {
    public init() {}
    public func record(_ record: PlaybackTelemetryRecord) async {
        _ = record
    }
}

public struct ProductionPlaybackTelemetryRecord: Sendable, Equatable {
    public let sessionID: UUID
    public let playbackID: UUID
    public let sourceID: String?
    public let timestamp: Date
    public let event: ProductionPlayerEvent

    public init(
        sessionID: UUID,
        playbackID: UUID,
        sourceID: String?,
        timestamp: Date = Date(),
        event: ProductionPlayerEvent
    ) {
        self.sessionID = sessionID
        self.playbackID = playbackID
        self.sourceID = sourceID
        self.timestamp = timestamp
        self.event = event
    }
}

@MainActor
final class PlaybackTelemetryDispatcher {
    private enum Item: Sendable {
        case player(PlaybackTelemetryRecord)
        case production(ProductionPlaybackTelemetryRecord)
    }

    private let continuation: AsyncStream<Item>.Continuation
    private let task: Task<Void, Never>

    init(sink: any PlaybackTelemetrySink, bufferingLimit: Int = 512) {
        let pair = AsyncStream.makeStream(
            of: Item.self,
            bufferingPolicy: .bufferingNewest(max(1, bufferingLimit))
        )
        continuation = pair.continuation
        task = Task {
            for await item in pair.stream {
                guard !Task.isCancelled else { return }
                switch item {
                case .player(let record):
                    await sink.record(record)
                case .production(let record):
                    await sink.recordProduction(record)
                }
            }
        }
    }

    func submit(_ record: PlaybackTelemetryRecord) {
        continuation.yield(.player(record))
    }

    func submit(_ record: ProductionPlaybackTelemetryRecord) {
        continuation.yield(.production(record))
    }

    func finish() {
        continuation.finish()
    }
}

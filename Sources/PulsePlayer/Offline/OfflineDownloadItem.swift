import Foundation

public enum OfflineDownloadState: String, Sendable, Equatable {
    case queued
    case downloading
    case completed
    case failed
    case cancelled
}

/// Persisted metadata for an offline asset.
public struct OfflineDownloadItem: Sendable, Equatable, Identifiable, Codable {
    public let id: String
    public var sourceURL: URL
    public var title: String?
    public var state: OfflineDownloadState
    public var progress: Double
    public var localFileURL: URL?
    public var errorMessage: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        sourceURL: URL,
        title: String? = nil,
        state: OfflineDownloadState = .queued,
        progress: Double = 0,
        localFileURL: URL? = nil,
        errorMessage: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.title = title
        self.state = state
        self.progress = progress
        self.localFileURL = localFileURL
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var isPlayableOffline: Bool {
        state == .completed && localFileURL != nil
    }

    /// Build a `MediaSource` pointing at the downloaded asset when ready.
    public func mediaSource(isLive: Bool = false) -> MediaSource? {
        guard let localFileURL else { return nil }
        return MediaSource(
            id: id,
            url: localFileURL,
            isLive: isLive,
            title: title
        )
    }
}

// OfflineDownloadState is Codable via raw value.
extension OfflineDownloadState: Codable {}

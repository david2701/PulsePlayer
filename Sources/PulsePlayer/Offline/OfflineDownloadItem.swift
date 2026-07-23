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
    public var contentKeyAssetId: String?
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
        contentKeyAssetId: String? = nil,
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
        self.contentKeyAssetId = contentKeyAssetId
        self.state = state
        self.progress = progress
        self.localFileURL = localFileURL
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Source-compatible 1.0 initializer.
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
        self.init(
            id: id,
            sourceURL: sourceURL,
            title: title,
            contentKeyAssetId: nil,
            state: state,
            progress: progress,
            localFileURL: localFileURL,
            errorMessage: errorMessage,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    public var isPlayableOffline: Bool {
        guard state == .completed, let localFileURL else { return false }
        return FileManager.default.fileExists(atPath: localFileURL.path)
    }

    /// Build a `MediaSource` pointing at the downloaded asset when ready.
    public func mediaSource(isLive: Bool = false) -> MediaSource? {
        guard isPlayableOffline, let localFileURL else { return nil }
        return MediaSource(
            id: id,
            url: localFileURL,
            isLive: isLive,
            title: title,
            contentKeyAssetId: contentKeyAssetId,
            requestsPersistableContentKey: contentKeyAssetId != nil
        )
    }
}

// OfflineDownloadState is Codable via raw value.
extension OfflineDownloadState: Codable {}

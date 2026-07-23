import Foundation

@MainActor
extension OfflineDownloadManager {
    /// Maximum bytes of completed offline assets. `nil` = unlimited.
    public static var storageLimitBytes: Int64? = 2_000_000_000 // 2 GB

    /// Human-readable used storage.
    public var usedStorageDisplay: String {
        ByteCountFormatter.string(fromByteCount: usedStorageBytes(), countStyle: .file)
    }

    public var storageLimitDisplay: String? {
        guard let limit = Self.storageLimitBytes else { return nil }
        return ByteCountFormatter.string(fromByteCount: limit, countStyle: .file)
    }

    /// Retry a failed/cancelled download (re-enqueues same id).
    @discardableResult
    public func retry(id: String) throws -> OfflineDownloadItem {
        guard let existing = item(id: id) else {
            throw PlayerError.invalidSource("Unknown offline id \(id)")
        }
        if existing.isPlayableOffline {
            return existing
        }
        if let url = existing.localFileURL {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
        try store.removePersisting(id: id)
        refreshItems()
        return try enqueue(
            sourceURL: existing.sourceURL,
            id: existing.id,
            title: existing.title,
            contentKeyAssetId: existing.contentKeyAssetId
        )
    }

    /// Resume: if completed return source; if failed retry; if missing enqueue.
    @discardableResult
    public func resumeOrEnqueue(
        sourceURL: URL,
        id: String,
        title: String? = nil
    ) throws -> OfflineDownloadItem {
        if let existing = item(id: id) {
            switch existing.state {
            case .completed:
                return existing.isPlayableOffline ? existing : try retry(id: id)
            case .downloading, .queued:
                return existing
            case .failed, .cancelled:
                return try retry(id: id)
            }
        }
        return try enqueue(sourceURL: sourceURL, id: id, title: title)
    }

    public func usedStorageBytes() -> Int64 {
        storageEntries().reduce(0) { $0 + $1.bytes }
    }

    private func storageEntries() -> [(item: OfflineDownloadItem, bytes: Int64)] {
        store.all().compactMap { item in
            guard item.state == .completed, let url = item.localFileURL else {
                return nil
            }
            return (item, Self.allocatedBytes(at: url))
        }
    }

    private static func allocatedBytes(at url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .fileSizeKey,
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            let values = try? url.resourceValues(forKeys: keys)
            return Int64(
                values?.totalFileAllocatedSize
                    ?? values?.fileAllocatedSize
                    ?? values?.fileSize
                    ?? 0
            )
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isRegularFile == true
            else { continue }
            total += Int64(
                values.totalFileAllocatedSize
                    ?? values.fileAllocatedSize
                    ?? values.fileSize
                    ?? 0
            )
        }
        return total
    }

    public func enforceStorageLimit() throws {
        guard let limit = Self.storageLimitBytes else { return }
        var entries = storageEntries().sorted {
            $0.item.createdAt < $1.item.createdAt
        }
        var total = entries.reduce(Int64(0)) { $0 + $1.bytes }
        while total > limit, let oldest = entries.first {
            try remove(id: oldest.item.id)
            total -= oldest.bytes
            entries.removeFirst()
        }
    }
}

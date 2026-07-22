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
        if existing.state == .completed, existing.localFileURL != nil {
            return existing
        }
        store.remove(id: id)
        if let url = existing.localFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        refreshItems()
        return try enqueue(
            sourceURL: existing.sourceURL,
            id: existing.id,
            title: existing.title
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
                return existing
            case .downloading, .queued:
                return existing
            case .failed, .cancelled:
                return try retry(id: id)
            }
        }
        return try enqueue(sourceURL: sourceURL, id: id, title: title)
    }

    public func usedStorageBytes() -> Int64 {
        var total: Int64 = 0
        for item in store.all() where item.state == .completed {
            guard let url = item.localFileURL else { continue }
            if let values = try? url.resourceValues(forKeys: [
                .totalFileAllocatedSizeKey, .fileSizeKey,
            ]) {
                total += Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
            }
        }
        return total
    }

    public func enforceStorageLimit() throws {
        guard let limit = Self.storageLimitBytes else { return }
        var completed = store.all()
            .filter { $0.state == .completed }
            .sorted { $0.createdAt < $1.createdAt }
        while usedStorageBytes() > limit, let oldest = completed.first {
            try remove(id: oldest.id)
            completed.removeFirst()
        }
    }
}

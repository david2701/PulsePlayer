import Foundation

public enum OfflineAssetStoreError: Error, Sendable, Equatable {
    case directoryCreation(String)
    case read(String)
    case decode(String)
    case write(String)
}

/// Versioned JSON catalog of offline downloads under Application Support.
///
/// `@unchecked Sendable` is safe here because every mutable field and every disk
/// transaction is protected by the same lock; no mutable reference escapes it.
public final class OfflineAssetStore: @unchecked Sendable {
    public static let shared = OfflineAssetStore()

    private struct Catalog: Codable {
        static let currentVersion = 1
        var version: Int
        var items: [OfflineDownloadItem]
    }

    private let fileURL: URL
    private let lock = NSLock()
    private var items: [String: OfflineDownloadItem] = [:]
    private var _lastError: OfflineAssetStoreError?

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
            let directory = base.appendingPathComponent(
                "PulsePlayer/Offline",
                isDirectory: true
            )
            self.fileURL = directory.appendingPathComponent("catalog.json")
        }
        prepareDirectory()
        load()
    }

    public var lastError: OfflineAssetStoreError? {
        lock.withLock { _lastError }
    }

    public func all() -> [OfflineDownloadItem] {
        lock.withLock {
            items.values.sorted { $0.createdAt > $1.createdAt }
        }
    }

    public func item(id: String) -> OfflineDownloadItem? {
        lock.withLock { items[id] }
    }

    public func upsert(_ item: OfflineDownloadItem) {
        do {
            try upsertPersisting(item)
        } catch {
            // `lastError` carries the failure for the source-compatible API.
        }
    }

    public func remove(id: String) {
        do {
            try removePersisting(id: id)
        } catch {
            // `lastError` carries the failure for the source-compatible API.
        }
    }

    package func upsertPersisting(_ item: OfflineDownloadItem) throws {
        try lock.withLock {
            let previous = items[item.id]
            items[item.id] = item
            do {
                try persistLocked()
                _lastError = nil
            } catch {
                items[item.id] = previous
                let storeError = mapWriteError(error)
                _lastError = storeError
                throw storeError
            }
        }
    }

    package func removePersisting(id: String) throws {
        try lock.withLock {
            let previous = items.removeValue(forKey: id)
            do {
                try persistLocked()
                _lastError = nil
            } catch {
                items[id] = previous
                let storeError = mapWriteError(error)
                _lastError = storeError
                throw storeError
            }
        }
    }

    private func prepareDirectory() {
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            lock.withLock {
                _lastError = .directoryCreation(
                    URLSanitizer.sanitizeMessage(error.localizedDescription)
                )
            }
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded: [OfflineDownloadItem]
            if let catalog = try? JSONDecoder().decode(Catalog.self, from: data) {
                guard catalog.version <= Catalog.currentVersion else {
                    throw OfflineAssetStoreError.decode(
                        "Unsupported offline catalog version \(catalog.version)"
                    )
                }
                decoded = catalog.items
            } else {
                // Migration from the 1.0 array-only catalog.
                decoded = try JSONDecoder().decode(
                    [OfflineDownloadItem].self,
                    from: data
                )
            }
            lock.withLock {
                items = Dictionary(
                    uniqueKeysWithValues: decoded.map { ($0.id, $0) }
                )
                _lastError = nil
            }
        } catch let storeError as OfflineAssetStoreError {
            lock.withLock { _lastError = storeError }
        } catch let decodingError as DecodingError {
            lock.withLock {
                _lastError = .decode(
                    URLSanitizer.sanitizeMessage(String(describing: decodingError))
                )
            }
        } catch {
            lock.withLock {
                _lastError = .read(
                    URLSanitizer.sanitizeMessage(error.localizedDescription)
                )
            }
        }
    }

    /// Called with `lock` held so two snapshots can never overwrite out of order.
    private func persistLocked() throws {
        let catalog = Catalog(
            version: Catalog.currentVersion,
            items: Array(items.values)
        )
        let data = try JSONEncoder().encode(catalog)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func mapWriteError(_ error: Error) -> OfflineAssetStoreError {
        if let storeError = error as? OfflineAssetStoreError {
            return storeError
        }
        return .write(URLSanitizer.sanitizeMessage(error.localizedDescription))
    }
}

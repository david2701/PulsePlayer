import Foundation

/// JSON catalog of offline downloads under Application Support.
public final class OfflineAssetStore: @unchecked Sendable {
    public static let shared = OfflineAssetStore()

    private let fileURL: URL
    private let lock = NSLock()
    private var items: [String: OfflineDownloadItem] = [:]

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let dir = base.appendingPathComponent("PulsePlayer/Offline", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("catalog.json")
        }
        load()
    }

    public func all() -> [OfflineDownloadItem] {
        lock.lock()
        defer { lock.unlock() }
        return items.values.sorted { $0.createdAt > $1.createdAt }
    }

    public func item(id: String) -> OfflineDownloadItem? {
        lock.lock()
        defer { lock.unlock() }
        return items[id]
    }

    public func upsert(_ item: OfflineDownloadItem) {
        lock.lock()
        items[item.id] = item
        lock.unlock()
        save()
    }

    public func remove(id: String) {
        lock.lock()
        items.removeValue(forKey: id)
        lock.unlock()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([OfflineDownloadItem].self, from: data)
        else { return }
        lock.lock()
        items = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
        lock.unlock()
    }

    private func save() {
        lock.lock()
        let snapshot = Array(items.values)
        lock.unlock()
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

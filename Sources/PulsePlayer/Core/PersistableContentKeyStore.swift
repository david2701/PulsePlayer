import CryptoKit
import Foundation

/// Async storage used for FairPlay persistable content keys.
public protocol PersistableContentKeyStoring: Sendable {
    func contentKey(for assetID: String) async throws -> Data?
    func storeContentKey(_ data: Data, for assetID: String) async throws
    func removeContentKey(for assetID: String) async throws
}

/// File-backed key store with opaque filenames and atomic writes.
public actor PersistableContentKeyFileStore: PersistableContentKeyStoring {
    private let directory: URL
    private let fileManager: FileManager

    public init(directory: URL? = nil) throws {
        let manager = FileManager.default
        let root = try directory ?? manager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let resolved = root.appendingPathComponent(
            "PulsePlayer/PersistableContentKeys",
            isDirectory: true
        )
        try manager.createDirectory(
            at: resolved,
            withIntermediateDirectories: true
        )
        self.directory = resolved
        self.fileManager = manager
    }

    public func contentKey(for assetID: String) async throws -> Data? {
        let url = keyURL(for: assetID)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    public func storeContentKey(_ data: Data, for assetID: String) async throws {
        guard !data.isEmpty else {
            throw PlayerError.invalidSource("Persistable FairPlay key is empty")
        }
        let url = keyURL(for: assetID)
        try data.write(to: url, options: .atomic)
        #if os(iOS) || os(tvOS)
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        #endif
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }

    public func removeContentKey(for assetID: String) async throws {
        let url = keyURL(for: assetID)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    private func keyURL(for assetID: String) -> URL {
        let digest = SHA256.hash(data: Data(assetID.utf8))
        let filename = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(filename).appendingPathExtension("key")
    }
}

import Foundation
import Testing
@testable import PulsePlayer

@Suite("Offline asset store")
struct OfflineStoreTests {
    @Test func upsertAndLoadCatalog() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-offline-\(UUID().uuidString).json")
        let asset = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-asset-\(UUID().uuidString).movpkg")
        try FileManager.default.createDirectory(
            at: asset,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: tmp)
            try? FileManager.default.removeItem(at: asset)
        }

        let store = OfflineAssetStore(fileURL: tmp)
        let item = OfflineDownloadItem(
            id: "ep1",
            sourceURL: URL(string: "https://example.com/a.m3u8")!,
            title: "Episode 1",
            state: .completed,
            progress: 1,
            localFileURL: asset
        )
        store.upsert(item)

        let reloaded = OfflineAssetStore(fileURL: tmp)
        #expect(reloaded.item(id: "ep1")?.title == "Episode 1")
        #expect(reloaded.item(id: "ep1")?.isPlayableOffline == true)
        #expect(reloaded.item(id: "ep1")?.mediaSource()?.url == asset)

        reloaded.remove(id: "ep1")
        #expect(reloaded.item(id: "ep1") == nil)
    }

    @Test @MainActor
    func offlineManagerUnsupportedOnMacThrows() throws {
        #if os(macOS)
        let manager = OfflineDownloadManager(store: OfflineAssetStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("pulse-off-\(UUID().uuidString).json")
        ))
        #expect(throws: PlayerError.self) {
            try manager.enqueue(sourceURL: URL(string: "https://example.com/a.m3u8")!)
        }
        #endif
    }

    @Test func corruptCatalogIsReportedInsteadOfSilentlyOverwritten() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-corrupt-\(UUID().uuidString)", isDirectory: true)
        let catalog = directory.appendingPathComponent("catalog.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{not-json".utf8).write(to: catalog)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = OfflineAssetStore(fileURL: catalog)
        guard case .decode = store.lastError else {
            Issue.record("Expected a decode error for a corrupt catalog")
            return
        }
        #expect(store.all().isEmpty)
    }

    @Test func legacyArrayCatalogStillLoads() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-legacy-\(UUID().uuidString)", isDirectory: true)
        let catalog = directory.appendingPathComponent("catalog.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let item = OfflineDownloadItem(
            id: "legacy",
            sourceURL: URL(string: "https://example.com/legacy.m3u8")!,
            title: "Legacy"
        )
        try JSONEncoder().encode([item]).write(to: catalog)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = OfflineAssetStore(fileURL: catalog)
        #expect(store.lastError == nil)
        #expect(store.item(id: "legacy")?.title == "Legacy")
    }

    @Test func failedWriteRollsBackTheInMemoryMutation() throws {
        let marker = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-not-directory-\(UUID().uuidString)")
        try Data("file".utf8).write(to: marker)
        defer { try? FileManager.default.removeItem(at: marker) }
        let store = OfflineAssetStore(
            fileURL: marker.appendingPathComponent("catalog.json")
        )
        let item = OfflineDownloadItem(
            id: "rollback",
            sourceURL: URL(string: "https://example.com/a.m3u8")!
        )

        #expect(throws: OfflineAssetStoreError.self) {
            try store.upsertPersisting(item)
        }
        #expect(store.item(id: "rollback") == nil)
        guard case .write = store.lastError else {
            Issue.record("Expected the write failure to remain observable")
            return
        }
    }

    @Test func completedItemRequiresItsDownloadedFile() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).movpkg")
        let item = OfflineDownloadItem(
            sourceURL: URL(string: "https://example.com/a.m3u8")!,
            state: .completed,
            progress: 1,
            localFileURL: missing
        )
        #expect(!item.isPlayableOffline)
        #expect(item.mediaSource() == nil)
    }

    @Test @MainActor
    func storageUsageIncludesFilesInsideDownloadedPackages() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-size-\(UUID().uuidString)", isDirectory: true)
        let package = directory.appendingPathComponent("asset.movpkg", isDirectory: true)
        let nested = package.appendingPathComponent("segments", isDirectory: true)
        let catalog = directory.appendingPathComponent("catalog.json")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data(repeating: 7, count: 8_192).write(
            to: nested.appendingPathComponent("segment")
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = OfflineAssetStore(fileURL: catalog)
        try store.upsertPersisting(
            OfflineDownloadItem(
                id: "package",
                sourceURL: URL(string: "https://example.com/a.m3u8")!,
                state: .completed,
                progress: 1,
                localFileURL: package
            )
        )
        let manager = OfflineDownloadManager(store: store)
        #expect(manager.usedStorageBytes() >= 8_192)
    }
}

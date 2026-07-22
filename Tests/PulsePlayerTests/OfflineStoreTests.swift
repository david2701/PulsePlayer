import Foundation
import Testing
@testable import PulsePlayer

@Suite("Offline asset store")
struct OfflineStoreTests {
    @Test func upsertAndLoadCatalog() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-offline-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let store = OfflineAssetStore(fileURL: tmp)
        let item = OfflineDownloadItem(
            id: "ep1",
            sourceURL: URL(string: "https://example.com/a.m3u8")!,
            title: "Episode 1",
            state: .completed,
            progress: 1,
            localFileURL: URL(fileURLWithPath: "/tmp/a.movpkg")
        )
        store.upsert(item)

        let reloaded = OfflineAssetStore(fileURL: tmp)
        #expect(reloaded.item(id: "ep1")?.title == "Episode 1")
        #expect(reloaded.item(id: "ep1")?.isPlayableOffline == true)
        #expect(reloaded.item(id: "ep1")?.mediaSource()?.url.path == "/tmp/a.movpkg")

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
}

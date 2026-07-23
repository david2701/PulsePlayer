#if os(iOS)
import AVFoundation
import Foundation

@MainActor
extension OfflineDownloadManager {
    func restorePersistableKeyLoaders() {
        guard let provider = contentKeyProvider,
              let keyStore = persistableContentKeyStore
        else { return }

        for (id, task) in tasks {
            guard keyLoaders[id] == nil,
                  let assetID = store.item(id: id)?.contentKeyAssetId,
                  let assetTask = task as? AVAssetDownloadTask
            else { continue }
            let loader = FairPlayContentKeyLoader(
                provider: provider,
                assetId: assetID,
                persistableStore: keyStore,
                logHandler: DefaultPulsePlayerLogHandler()
            )
            loader.attach(to: assetTask.urlAsset)
            keyLoaders[id] = loader
        }
    }
}
#endif

import AVFoundation
import Foundation

/// Downloads media for offline playback using `AVAssetDownloadURLSession` (iOS/tvOS).
@MainActor
public final class OfflineDownloadManager: NSObject {
    public static let shared = OfflineDownloadManager()

    public private(set) var items: [OfflineDownloadItem] = []
    public var onChange: (([OfflineDownloadItem]) -> Void)?

    let store: OfflineAssetStore
    private var urlSession: AVAssetDownloadURLSession?
    private var tasks: [String: URLSessionTask] = [:]
    private let sessionIdentifier = "com.pulseplayer.offline.download"

    public init(store: OfflineAssetStore = .shared) {
        self.store = store
        super.init()
        self.items = store.all()
        #if os(iOS) || os(tvOS)
        let config = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        urlSession = AVAssetDownloadURLSession(
            configuration: config,
            assetDownloadDelegate: self,
            delegateQueue: .main
        )
        #endif
    }

    /// Enqueue HLS/progressive download. Returns catalog item (may already exist).
    @discardableResult
    public func enqueue(
        sourceURL: URL,
        id: String = UUID().uuidString,
        title: String? = nil
    ) throws -> OfflineDownloadItem {
        #if os(iOS) || os(tvOS)
        if let existing = store.item(id: id),
           existing.state == .downloading || existing.state == .completed
        {
            return existing
        }

        var item = OfflineDownloadItem(
            id: id,
            sourceURL: sourceURL,
            title: title,
            state: .queued
        )
        store.upsert(item)
        refreshItems()

        guard let session = urlSession else {
            throw PlayerError.unknown("Offline session unavailable", recoverable: false)
        }

        let asset = AVURLAsset(url: sourceURL)
        guard let task = session.makeAssetDownloadTask(
            asset: asset,
            assetTitle: title ?? id,
            assetArtworkData: nil,
            options: [AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: NSNumber(value: 0)]
        ) else {
            item.state = .failed
            item.errorMessage = "Could not create download task"
            store.upsert(item)
            refreshItems()
            throw PlayerError.unknown("Could not create offline download task", recoverable: true)
        }

        task.taskDescription = id
        tasks[id] = task
        item.state = .downloading
        item.updatedAt = Date()
        store.upsert(item)
        refreshItems()
        task.resume()
        return item
        #else
        throw PlayerError.unknown("Offline downloads require iOS/tvOS", recoverable: false)
        #endif
    }

    public func cancel(id: String) {
        tasks[id]?.cancel()
        tasks[id] = nil
        updateItem(id: id) { item in
            item.state = .cancelled
        }
    }

    public func remove(id: String) throws {
        cancel(id: id)
        if let item = store.item(id: id), let url = item.localFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        store.remove(id: id)
        refreshItems()
    }

    public func item(id: String) -> OfflineDownloadItem? {
        store.item(id: id)
    }

    public func playableSource(id: String) -> MediaSource? {
        store.item(id: id)?.mediaSource()
    }

    func refreshItems() {
        items = store.all()
        onChange?(items)
    }

    func updateItem(id: String, mutate: (inout OfflineDownloadItem) -> Void) {
        guard var item = store.item(id: id) else { return }
        mutate(&item)
        item.updatedAt = Date()
        store.upsert(item)
        refreshItems()
    }
}

#if os(iOS) || os(tvOS)
extension OfflineDownloadManager: AVAssetDownloadDelegate {
    public nonisolated func urlSession(
        _ session: URLSession,
        assetDownloadTask: AVAssetDownloadTask,
        didLoad timeRange: CMTimeRange,
        totalTimeRangesLoaded loadedTimeRanges: [NSValue],
        timeRangeExpectedToLoad: CMTimeRange
    ) {
        let id = assetDownloadTask.taskDescription ?? ""
        var loaded: Double = 0
        for value in loadedTimeRanges {
            loaded += value.timeRangeValue.duration.seconds
        }
        let expected = max(0.001, timeRangeExpectedToLoad.duration.seconds)
        let progress = min(1, max(0, loaded / expected))
        Task { @MainActor in
            self.updateItem(id: id) { item in
                item.progress = progress
                item.state = .downloading
            }
        }
    }

    public nonisolated func urlSession(
        _ session: URLSession,
        assetDownloadTask: AVAssetDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let id = assetDownloadTask.taskDescription ?? ""
        Task { @MainActor in
            self.tasks[id] = nil
            self.updateItem(id: id) { item in
                item.localFileURL = location
                item.progress = 1
                item.state = .completed
                item.errorMessage = nil
            }
            try? self.enforceStorageLimit()
        }
    }

    public nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        let id = task.taskDescription ?? ""
        Task { @MainActor in
            self.tasks[id] = nil
            guard let error else { return }
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled {
                self.updateItem(id: id) { $0.state = .cancelled }
                return
            }
            self.updateItem(id: id) { item in
                item.state = .failed
                item.errorMessage = URLSanitizer.sanitizeMessage(error.localizedDescription)
            }
        }
    }
}
#endif

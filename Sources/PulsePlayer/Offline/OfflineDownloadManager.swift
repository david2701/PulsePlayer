import AVFoundation
import Foundation

/// Downloads media for offline playback using `AVAssetDownloadURLSession` (**iOS only**).
/// Catalog APIs compile on all platforms; enqueue is unsupported on tvOS/macOS.
@MainActor
public final class OfflineDownloadManager: NSObject {
    public static let shared = OfflineDownloadManager()

    public private(set) var items: [OfflineDownloadItem] = []
    public var onChange: (([OfflineDownloadItem]) -> Void)?
    /// FairPlay provider used while downloading protected HLS.
    public var contentKeyProvider: (any ContentKeyProviding)? {
        didSet {
            #if os(iOS)
            restorePersistableKeyLoaders()
            #endif
        }
    }
    /// Required with `contentKeyProvider` for protected offline downloads.
    public var persistableContentKeyStore: (any PersistableContentKeyStoring)? {
        didSet {
            #if os(iOS)
            restorePersistableKeyLoaders()
            #endif
        }
    }

    let store: OfflineAssetStore
    #if os(iOS)
    private var urlSession: AVAssetDownloadURLSession?
    var tasks: [String: URLSessionTask] = [:]
    var keyLoaders: [String: FairPlayContentKeyLoader] = [:]
    private let delegateQueue: OperationQueue
    private var pendingProgress: [String: Double] = [:]
    private var progressFlushTask: Task<Void, Never>?
    private var backgroundEventsCompletionHandler: (@MainActor () -> Void)?
    #endif
    private let sessionIdentifier: String

    public convenience init(store: OfflineAssetStore = .shared) {
        self.init(store: store, sessionIdentifier: nil)
    }

    public init(
        store: OfflineAssetStore,
        sessionIdentifier: String?
    ) {
        self.store = store
        let bundleID = Bundle.main.bundleIdentifier ?? "com.pulseplayer.host"
        self.sessionIdentifier = sessionIdentifier
            ?? "\(bundleID).pulseplayer.offline.download"
        #if os(iOS)
        let queue = OperationQueue()
        queue.name = "\(self.sessionIdentifier).delegate"
        queue.maxConcurrentOperationCount = 1
        self.delegateQueue = queue
        #endif
        super.init()
        self.items = store.all()
        #if os(iOS)
        let config = URLSessionConfiguration.background(
            withIdentifier: self.sessionIdentifier
        )
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        urlSession = AVAssetDownloadURLSession(
            configuration: config,
            assetDownloadDelegate: self,
            delegateQueue: delegateQueue
        )
        restoreOutstandingTasks()
        #endif
    }

    /// Source-compatible 1.0 enqueue surface.
    @discardableResult
    public func enqueue(
        sourceURL: URL,
        id: String = UUID().uuidString,
        title: String? = nil
    ) throws -> OfflineDownloadItem {
        try enqueue(
            sourceURL: sourceURL,
            id: id,
            title: title,
            headers: [:],
            cookies: [],
            contentKeyAssetId: nil
        )
    }

    /// Enqueue an HLS asset download. Returns the catalog item when already active.
    @discardableResult
    public func enqueue(
        sourceURL: URL,
        id: String = UUID().uuidString,
        title: String? = nil,
        headers: [String: String] = [:],
        cookies: [HTTPCookieValue] = [],
        contentKeyAssetId: String? = nil
    ) throws -> OfflineDownloadItem {
        #if os(iOS)
        if let existing = store.item(id: id),
           existing.state == .downloading || existing.state == .completed
        {
            return existing
        }
        if contentKeyAssetId != nil,
           (contentKeyProvider == nil || persistableContentKeyStore == nil)
        {
            throw PlayerError.invalidSource(
                "Protected offline downloads require a FairPlay provider and key store"
            )
        }

        var item = OfflineDownloadItem(
            id: id,
            sourceURL: sourceURL,
            title: title,
            contentKeyAssetId: contentKeyAssetId,
            state: .queued
        )
        try store.upsertPersisting(item)
        refreshItems()

        guard let session = urlSession else {
            throw PlayerError.unknown("Offline session unavailable", recoverable: false)
        }

        let source = MediaSource(
            id: id,
            url: sourceURL,
            headers: headers,
            cookies: cookies,
            title: title,
            contentKeyAssetId: contentKeyAssetId,
            requestsPersistableContentKey: contentKeyAssetId != nil
        )
        let asset = AssetFactory.makeURLAsset(from: source)
        if let assetID = contentKeyAssetId {
            guard let provider = contentKeyProvider,
                  let keyStore = persistableContentKeyStore
            else { preconditionFailure("FairPlay dependencies were validated") }
            let loader = FairPlayContentKeyLoader(
                provider: provider,
                assetId: assetID,
                persistableStore: keyStore,
                logHandler: DefaultPulsePlayerLogHandler()
            )
            loader.attach(to: asset)
            keyLoaders[id] = loader
        }
        let downloadConfiguration = AVAssetDownloadConfiguration(
            asset: asset,
            title: title ?? id
        )
        let task = session.makeAssetDownloadTask(
            downloadConfiguration: downloadConfiguration
        )

        task.taskDescription = id
        tasks[id] = task
        item.state = .downloading
        item.updatedAt = Date()
        try store.upsertPersisting(item)
        refreshItems()
        task.resume()
        return item
        #else
        throw PlayerError.unknown(
            "Offline asset downloads require iOS (AVAssetDownloadURLSession)",
            recoverable: false
        )
        #endif
    }

    public func cancel(id: String) {
        #if os(iOS)
        tasks[id]?.cancel()
        tasks[id] = nil
        keyLoaders[id]?.tearDown()
        keyLoaders[id] = nil
        #endif
        updateItem(id: id) { item in
            item.state = .cancelled
        }
    }

    public func remove(id: String) throws {
        let removedItem = store.item(id: id)
        cancel(id: id)
        if let url = removedItem?.localFileURL {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
        try store.removePersisting(id: id)
        if let assetID = removedItem?.contentKeyAssetId,
           let keyStore = persistableContentKeyStore
        {
            Task {
                try? await keyStore.removeContentKey(for: assetID)
            }
        }
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
        do {
            try store.upsertPersisting(item)
        } catch {
            PulseLog.error("Offline catalog update failed: \(error.localizedDescription)")
            return
        }
        refreshItems()
    }

    #if os(iOS)
    /// Forward the app delegate's background URL-session completion handler here.
    public func handleBackgroundEvents(
        completionHandler: @escaping @MainActor () -> Void
    ) {
        backgroundEventsCompletionHandler = completionHandler
    }

    private func restoreOutstandingTasks() {
        urlSession?.getAllTasks { [weak self] tasks in
            let box = OfflineTaskList(tasks)
            Task { @MainActor in
                self?.reconcileRestoredTasks(box.tasks)
            }
        }
    }

    private func reconcileRestoredTasks(_ restored: [URLSessionTask]) {
        var activeIDs = Set<String>()
        for task in restored {
            guard let id = task.taskDescription, !id.isEmpty else { continue }
            activeIDs.insert(id)
            tasks[id] = task
            updateItem(id: id) { item in
                item.state = task.state == .suspended ? .queued : .downloading
            }
        }
        for item in store.all()
        where (item.state == .queued || item.state == .downloading)
            && !activeIDs.contains(item.id)
        {
            updateItem(id: item.id) { stale in
                stale.state = .failed
                stale.errorMessage = "Download was interrupted before completion"
            }
        }
        restorePersistableKeyLoaders()
    }

    private func queueProgress(id: String, progress: Double) {
        pendingProgress[id] = progress
        guard progressFlushTask == nil else { return }
        progressFlushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard let self, !Task.isCancelled else { return }
            self.flushProgress()
        }
    }

    private func flushProgress() {
        let updates = pendingProgress
        pendingProgress.removeAll()
        progressFlushTask = nil
        for (id, progress) in updates {
            updateItem(id: id) { item in
                item.progress = progress
                item.state = .downloading
            }
        }
    }
    #endif
}

#if os(iOS)
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
            self.queueProgress(id: id, progress: progress)
        }
    }

    public nonisolated func urlSession(
        _ session: URLSession,
        assetDownloadTask: AVAssetDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let id = assetDownloadTask.taskDescription ?? ""
        Task { @MainActor in
            self.pendingProgress[id] = nil
            self.tasks[id] = nil
            self.keyLoaders[id]?.tearDown()
            self.keyLoaders[id] = nil
            self.updateItem(id: id) { item in
                item.localFileURL = location
                item.progress = 1
                item.state = .completed
                item.errorMessage = nil
            }
            do {
                try self.enforceStorageLimit()
            } catch {
                PulseLog.error(
                    "Offline storage enforcement failed: \(error.localizedDescription)"
                )
            }
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
            self.keyLoaders[id]?.tearDown()
            self.keyLoaders[id] = nil
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

    public nonisolated func urlSessionDidFinishEvents(
        forBackgroundURLSession session: URLSession
    ) {
        Task { @MainActor in
            let completion = self.backgroundEventsCompletionHandler
            self.backgroundEventsCompletionHandler = nil
            completion?()
        }
    }
}

/// Foundation's task classes predate full Sendable annotations. The list only
/// crosses to the main actor, where the manager owns and mutates the tasks.
private final class OfflineTaskList: @unchecked Sendable {
    let tasks: [URLSessionTask]

    init(_ tasks: [URLSessionTask]) {
        self.tasks = tasks
    }
}
#endif

import AVFoundation
import Foundation

/// Bridges `ContentKeyProviding` to `AVContentKeySession`.
@MainActor
final class FairPlayContentKeyLoader: NSObject, AVContentKeySessionDelegate {
    private let providerBox: UncheckedContentKeyProvider
    private let assetId: String
    private let persistableStore: (any PersistableContentKeyStoring)?
    private let logHandler: any PulsePlayerLogHandler
    private let keySession: AVContentKeySession
    private weak var asset: AVURLAsset?
    var onPersistableKeyStored: ((String) -> Void)?

    init(
        provider: any ContentKeyProviding,
        assetId: String,
        persistableStore: (any PersistableContentKeyStoring)? = nil,
        logHandler: any PulsePlayerLogHandler
    ) {
        self.providerBox = UncheckedContentKeyProvider(provider)
        self.assetId = assetId
        self.persistableStore = persistableStore
        self.logHandler = logHandler
        self.keySession = AVContentKeySession(keySystem: .fairPlayStreaming)
        super.init()
        keySession.setDelegate(self, queue: .main)
    }

    func attach(to asset: AVURLAsset) {
        self.asset = asset
        keySession.addContentKeyRecipient(asset)
    }

    func tearDown() {
        if let asset {
            keySession.removeContentKeyRecipient(asset)
        }
        keySession.setDelegate(nil, queue: nil)
        asset = nil
    }

    nonisolated func contentKeySession(
        _ session: AVContentKeySession,
        didProvide keyRequest: AVContentKeyRequest
    ) {
        Task { @MainActor in
            if self.persistableStore != nil {
                do {
                    try self.requestPersistableKey(for: keyRequest)
                } catch {
                    keyRequest.processContentKeyResponseError(error)
                }
            } else {
                await self.handleStreaming(keyRequest: keyRequest)
            }
        }
    }

    nonisolated func contentKeySession(
        _ session: AVContentKeySession,
        didProvideRenewingContentKeyRequest keyRequest: AVContentKeyRequest
    ) {
        Task { @MainActor in
            await self.handleStreaming(keyRequest: keyRequest)
        }
    }

    nonisolated func contentKeySession(
        _ session: AVContentKeySession,
        didProvide keyRequest: AVPersistableContentKeyRequest
    ) {
        Task { @MainActor in
            await self.handlePersistable(keyRequest: keyRequest)
        }
    }

    nonisolated func contentKeySession(
        _ session: AVContentKeySession,
        didUpdatePersistableContentKey persistableContentKey: Data,
        forContentKeyIdentifier keyIdentifier: Any
    ) {
        Task { @MainActor in
            guard let store = self.persistableStore else { return }
            do {
                try await store.storeContentKey(persistableContentKey, for: self.assetId)
                self.onPersistableKeyStored?(self.assetId)
            } catch {
                self.logHandler.log(
                    level: .error,
                    message: "FairPlay key update could not be persisted: "
                        + URLSanitizer.sanitizeMessage(error.localizedDescription)
                )
            }
        }
    }

    nonisolated func contentKeySession(
        _ session: AVContentKeySession,
        contentKeyRequest keyRequest: AVContentKeyRequest,
        didFailWithError err: Error
    ) {
        let msg = URLSanitizer.sanitizeMessage(err.localizedDescription)
        Task { @MainActor in
            self.logHandler.log(level: .error, message: "FairPlay key request failed: \(msg)")
        }
    }

    nonisolated func contentKeySession(
        _ session: AVContentKeySession,
        shouldRetry keyRequest: AVContentKeyRequest,
        reason retryReason: AVContentKeyRequest.RetryReason
    ) -> Bool {
        retryReason == .timedOut
            || retryReason == .receivedResponseWithExpiredLease
            || retryReason == .receivedObsoleteContentKey
    }

    private func handleStreaming(keyRequest: AVContentKeyRequest) async {
        do {
            let spc = try await makeSPC(for: keyRequest)
            let ckc = try await providerBox.contentKey(spcData: spc, assetId: assetId)
            let response = AVContentKeyResponse(fairPlayStreamingKeyResponseData: ckc)
            keyRequest.processContentKeyResponse(response)
        } catch {
            keyRequest.processContentKeyResponseError(error)
        }
    }

    private func handlePersistable(keyRequest: AVPersistableContentKeyRequest) async {
        do {
            guard let store = persistableStore else {
                await handleStreaming(keyRequest: keyRequest)
                return
            }
            if let existing = try await store.contentKey(for: assetId) {
                keyRequest.processContentKeyResponse(
                    AVContentKeyResponse(fairPlayStreamingKeyResponseData: existing)
                )
                return
            }

            let spc = try await makeSPC(for: keyRequest)
            let ckc = try await providerBox.contentKey(spcData: spc, assetId: assetId)
            let key = try keyRequest.persistableContentKey(
                fromKeyVendorResponse: ckc,
                options: nil
            )
            try await store.storeContentKey(key, for: assetId)
            onPersistableKeyStored?(assetId)
            keyRequest.processContentKeyResponse(
                AVContentKeyResponse(fairPlayStreamingKeyResponseData: key)
            )
        } catch {
            keyRequest.processContentKeyResponseError(error)
        }
    }

    private func makeSPC(for keyRequest: AVContentKeyRequest) async throws -> Data {
        let cert = try await providerBox.certificateData()
        let contentIdData = Data(assetId.utf8)
        return try await withCheckedThrowingContinuation { continuation in
            keyRequest.makeStreamingContentKeyRequestData(
                forApp: cert,
                contentIdentifier: contentIdData,
                options: nil
            ) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(
                        throwing: PlayerError.unknown(
                            "Empty FairPlay SPC",
                            recoverable: false
                        )
                    )
                }
            }
        }
    }

    /// Calls the non-deprecated NSError-returning selector. Swift's importer
    /// otherwise picks the deprecated void overload on iOS where both exist.
    private func requestPersistableKey(for keyRequest: AVContentKeyRequest) throws {
        let selector = NSSelectorFromString(
            "respondByRequestingPersistableContentKeyRequestAndReturnError:"
        )
        guard keyRequest.responds(to: selector) else {
            throw PlayerError.unknown(
                "Persistable FairPlay keys are unavailable",
                recoverable: false
            )
        }
        typealias Implementation = @convention(c) (
            AnyObject,
            Selector,
            UnsafeMutablePointer<NSError?>?
        ) -> Bool
        let implementation = unsafeBitCast(
            keyRequest.method(for: selector),
            to: Implementation.self
        )
        var error: NSError?
        guard implementation(keyRequest, selector, &error) else {
            throw error ?? PlayerError.unknown(
                "FairPlay rejected the persistable-key request",
                recoverable: false
            )
        }
    }
}

/// `@unchecked Sendable` box so host key providers need not be formally Sendable.
struct UncheckedContentKeyProvider: @unchecked Sendable {
    private let base: any ContentKeyProviding

    init(_ base: any ContentKeyProviding) {
        self.base = base
    }

    func certificateData() async throws -> Data {
        try await base.certificateData()
    }

    func contentKey(spcData: Data, assetId: String) async throws -> Data {
        try await base.contentKey(spcData: spcData, assetId: assetId)
    }
}

import AVFoundation
import Foundation

/// Bridges `ContentKeyProviding` to `AVContentKeySession`.
@MainActor
final class FairPlayContentKeyLoader: NSObject, AVContentKeySessionDelegate {
    private let providerBox: UncheckedContentKeyProvider
    private let assetId: String
    private let keySession: AVContentKeySession
    private weak var asset: AVURLAsset?

    init(provider: any ContentKeyProviding, assetId: String) {
        self.providerBox = UncheckedContentKeyProvider(provider)
        self.assetId = assetId
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
            await self.handle(keyRequest: keyRequest)
        }
    }

    nonisolated func contentKeySession(
        _ session: AVContentKeySession,
        didProvideRenewingContentKeyRequest keyRequest: AVContentKeyRequest
    ) {
        Task { @MainActor in
            await self.handle(keyRequest: keyRequest)
        }
    }

    nonisolated func contentKeySession(
        _ session: AVContentKeySession,
        contentKeyRequest keyRequest: AVContentKeyRequest,
        didFailWithError err: Error
    ) {
        let msg = URLSanitizer.sanitizeMessage(err.localizedDescription)
        Task { @MainActor in
            PulseLog.error("FairPlay key request failed: \(msg)")
        }
    }

    private func handle(keyRequest: AVContentKeyRequest) async {
        do {
            let cert = try await providerBox.certificateData()
            let contentIdData = Data(assetId.utf8)
            let spc: Data = try await withCheckedThrowingContinuation { cont in
                do {
                    try keyRequest.makeStreamingContentKeyRequestData(
                        forApp: cert,
                        contentIdentifier: contentIdData,
                        options: nil
                    ) { data, error in
                        if let error {
                            cont.resume(throwing: error)
                        } else if let data {
                            cont.resume(returning: data)
                        } else {
                            cont.resume(
                                throwing: PlayerError.unknown(
                                    "Empty FairPlay SPC",
                                    recoverable: false
                                )
                            )
                        }
                    }
                } catch {
                    cont.resume(throwing: error)
                }
            }
            let ckc = try await providerBox.contentKey(spcData: spc, assetId: assetId)
            let response = AVContentKeyResponse(fairPlayStreamingKeyResponseData: ckc)
            keyRequest.processContentKeyResponse(response)
        } catch {
            keyRequest.processContentKeyResponseError(error)
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

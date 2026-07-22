import Foundation

/// FairPlay Streaming key provider. Host implements certificate + CKC exchange.
public protocol ContentKeyProviding: AnyObject {
    /// App certificate (FairPlay application certificate bytes).
    func certificateData() async throws -> Data
    /// Exchange SPC for CKC. `assetId` is typically the content identifier.
    func contentKey(spcData: Data, assetId: String) async throws -> Data
}

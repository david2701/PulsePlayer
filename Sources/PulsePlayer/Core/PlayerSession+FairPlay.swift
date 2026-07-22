import Foundation

@MainActor
extension PlayerSession {
    /// Host FairPlay key provider. Applied on next `load`.
    public var contentKeyProvider: (any ContentKeyProviding)? {
        get { _contentKeyProvider }
        set {
            _contentKeyProvider = newValue
            if let engine = engine as? AVPlayerEngine {
                engine.contentKeyProvider = newValue
            }
        }
    }
}

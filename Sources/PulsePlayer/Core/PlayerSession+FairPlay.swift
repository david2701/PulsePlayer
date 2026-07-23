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

    /// Store used to acquire and reuse offline FairPlay keys.
    public var persistableContentKeyStore: (any PersistableContentKeyStoring)? {
        get { _persistableContentKeyStore }
        set {
            _persistableContentKeyStore = newValue
            if let engine = engine as? AVPlayerEngine {
                engine.persistableContentKeyStore = newValue
            }
        }
    }
}

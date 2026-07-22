import AVFoundation

@MainActor
extension PlayerSession {
    /// UI targets only. Forwards to `AVPlayerEngine` when available.
    package func attachPlayerLayer(_ layer: AVPlayerLayer?) {
        if let bridge = engine as? any AVPlayerEngineUIBridging {
            bridge.attachPlayerLayer(layer)
        }
        attachPiP(to: layer)
    }
}

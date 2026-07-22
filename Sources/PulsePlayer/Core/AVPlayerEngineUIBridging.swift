import AVFoundation

/// AV-only UI attachment. Implemented only by `AVPlayerEngine`.
@MainActor
package protocol AVPlayerEngineUIBridging: AnyObject {
    var avPlayer: AVPlayer { get }
    func attachPlayerLayer(_ layer: AVPlayerLayer?)
}

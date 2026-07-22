import Foundation

/// Package control surface for playback. **No AVFoundation types.**
@MainActor
package protocol PlaybackControlling: AnyObject {
    func applyConfiguration(_ config: PlayerConfiguration)
    func replaceCurrentItem(with source: MediaSource) async throws
    func play()
    func pause()
    func seek(to time: TimeInterval) async throws
    func setRate(_ rate: Float)
    func setMuted(_ muted: Bool)
    func setVolume(_ volume: Float)
    func currentTime() -> TimeInterval
    func duration() -> TimeInterval?
    func tearDown()

    var onSignal: ((PlayerEngineSignal) -> Void)? { get set }
}

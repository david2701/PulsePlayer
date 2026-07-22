import AVFoundation
import Foundation

/// Activates `AVAudioSession` for video/audio playback (background capable).
@MainActor
public final class SystemAudioSession: AudioSessionConfiguring {
    public init() {}

    public func activateForPlayback(background: Bool) throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        // `.playback` allows silent-switch audio; host must enable background audio capability.
        _ = background
        try session.setCategory(.playback, mode: .moviePlayback)
        try session.setActive(true, options: [])
        #elseif os(tvOS)
        let session = AVAudioSession.sharedInstance()
        _ = background
        try session.setCategory(.playback, mode: .moviePlayback)
        try session.setActive(true, options: [])
        #else
        _ = background
        #endif
    }

    public func deactivate() throws {
        #if os(iOS) || os(tvOS)
        try AVAudioSession.sharedInstance().setActive(
            false,
            options: [.notifyOthersOnDeactivation]
        )
        #endif
    }
}

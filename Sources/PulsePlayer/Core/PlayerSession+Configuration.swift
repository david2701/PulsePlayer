import Foundation

@MainActor
extension PlayerSession {
    /// Applies configuration mutations. Returns snapshot after reapply.
    @discardableResult
    public func updateConfiguration(
        _ mutate: (inout PlayerConfiguration) -> Void
    ) -> PlayerConfiguration {
        var next = configuration
        mutate(&next)
        configuration = next
        reapplyConfiguration()
        return configuration
    }

    func reapplyConfiguration() {
        engine.applyConfiguration(configuration)
        engine.setMuted(configuration.isMuted)
        if !configuration.updatesNowPlayingInfo {
            clearNowPlaying()
        } else {
            refreshNowPlaying()
        }
        if !configuration.allowsPictureInPicture {
            pipController.tearDown()
        }
    }
}

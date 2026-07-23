import AVFoundation
import Foundation

@MainActor
extension PlayerSession {
    /// Whether PiP can start with the current layer/configuration.
    public var isPictureInPicturePossible: Bool {
        configuration.allowsPictureInPicture && pipController.isPossible
    }

    public var isPictureInPictureActive: Bool {
        pipController.isActive
    }

    public func startPictureInPicture() {
        guard configuration.allowsPictureInPicture else { return }
        pipController.start()
    }

    public func stopPictureInPicture() {
        pipController.stop()
    }

    /// Called when PiP asks the host to restore its playback UI.
    public var pictureInPictureRestoreHandler: (@MainActor @Sendable () async -> Bool)? {
        get { pipController.restoreUserInterface }
        set { pipController.restoreUserInterface = newValue }
    }

    func configurePlatformHooks() {
        pipController.onEvent = { [weak self] event in
            self?.emit(.pictureInPicture(event))
        }

        if let np = dependencies.nowPlaying as? SystemNowPlayingCenter {
            np.register(
                owner: id,
                handlers:
                .init(
                    play: { [weak self] in self?.play() },
                    pause: { [weak self] in self?.pause() },
                    togglePlayPause: { [weak self] in self?.togglePlayPause() },
                    seek: { [weak self] time in
                        Task { await self?.seek(to: time) }
                    },
                    skipForward: { [weak self] interval in
                        Task { await self?.seek(relative: interval) }
                    },
                    skipBackward: { [weak self] interval in
                        Task { await self?.seek(relative: -interval) }
                    }
                )
            )
        }
    }

    func claimNowPlayingOwnership() {
        guard configuration.updatesNowPlayingInfo else { return }
        (dependencies.nowPlaying as? SystemNowPlayingCenter)?.activate(owner: id)
    }

    func releaseNowPlayingOwnership(clear: Bool) {
        if let center = dependencies.nowPlaying as? SystemNowPlayingCenter {
            center.deactivate(owner: id, clear: clear)
        } else if clear {
            dependencies.nowPlaying.clear()
        }
    }

    func unregisterNowPlayingOwnership(clear: Bool) {
        if let center = dependencies.nowPlaying as? SystemNowPlayingCenter {
            center.unregister(owner: id, clear: clear)
        } else if clear {
            dependencies.nowPlaying.clear()
        }
    }

    func activateAudioIfNeeded() {
        guard configuration.managesAudioSession, !audioSessionActivated else { return }
        do {
            try dependencies.audioSession.activateForPlayback(
                background: configuration.prefersBackgroundAudio
            )
            audioSessionActivated = true
            lifetimeCleanup.setAudioSessionActive(true)
        } catch {
            emit(.warning(URLSanitizer.sanitizeMessage(error.localizedDescription)))
        }
    }

    func deactivateAudioIfNeeded() {
        guard audioSessionActivated else { return }
        do {
            try dependencies.audioSession.deactivate()
        } catch {
            emit(.warning(URLSanitizer.sanitizeMessage(error.localizedDescription)))
        }
        audioSessionActivated = false
        lifetimeCleanup.setAudioSessionActive(false)
    }

    func refreshNowPlaying(rate: Float? = nil) {
        guard configuration.updatesNowPlayingInfo else { return }
        let playingRate: Float
        if let rate {
            playingRate = rate
        } else {
            playingRate = (status == .playing || status == .buffering)
                ? playbackRate
                : 0
        }
        if let center = dependencies.nowPlaying as? SystemNowPlayingCenter {
            center.update(
                owner: id,
                title: currentSource?.title,
                subtitle: currentSource?.subtitle,
                elapsed: engine.currentTime(),
                duration: engine.duration(),
                rate: playingRate
            )
        } else {
            dependencies.nowPlaying.update(
                title: currentSource?.title,
                subtitle: currentSource?.subtitle,
                elapsed: engine.currentTime(),
                duration: engine.duration(),
                rate: playingRate
            )
        }
    }

    func clearNowPlaying() {
        releaseNowPlayingOwnership(clear: true)
    }

    func attachPiP(to layer: AVPlayerLayer?) {
        guard configuration.allowsPictureInPicture else {
            pipController.tearDown()
            return
        }
        pipController.attach(playerLayer: layer)
    }
}

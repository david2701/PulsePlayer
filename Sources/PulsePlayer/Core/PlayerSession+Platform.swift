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

    func configurePlatformHooks() {
        pipController.onEvent = { [weak self] event in
            self?.emit(.pictureInPicture(event))
        }

        if let np = dependencies.nowPlaying as? SystemNowPlayingCenter {
            np.setCommandHandlers(
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

    func activateAudioIfNeeded() {
        do {
            try dependencies.audioSession.activateForPlayback(
                background: configuration.prefersBackgroundAudio
            )
        } catch {
            emit(.warning(URLSanitizer.sanitizeMessage(error.localizedDescription)))
        }
    }

    func refreshNowPlaying(rate: Float? = nil) {
        guard configuration.updatesNowPlayingInfo else { return }
        let playingRate: Float
        if let rate {
            playingRate = rate
        } else {
            playingRate = (status == .playing || status == .buffering) ? 1 : 0
        }
        dependencies.nowPlaying.update(
            title: currentSource?.title,
            subtitle: currentSource?.subtitle,
            elapsed: engine.currentTime(),
            duration: engine.duration(),
            rate: playingRate
        )
    }

    func clearNowPlaying() {
        dependencies.nowPlaying.clear()
    }

    func attachPiP(to layer: AVPlayerLayer?) {
        guard configuration.allowsPictureInPicture else {
            pipController.tearDown()
            return
        }
        pipController.attach(playerLayer: layer)
    }
}

import Foundation

@MainActor
extension PlayerSession {
    func startApplicationLifecycleObservation() {
        lifecycleEventTask?.cancel()
        let stream = dependencies.applicationLifecycle.makeEventStream()
        lifecycleEventTask = Task { @MainActor [weak self] in
            for await event in stream {
                guard let self, !Task.isCancelled else { return }
                self.handleApplicationLifecycleEvent(event)
            }
        }
    }

    func handleApplicationLifecycleEvent(_ event: ApplicationLifecycleEvent) {
        guard status != .invalidated else { return }
        emitProduction(.applicationLifecycle(event))

        switch event {
        case .willResignActive:
            break

        case .didEnterBackground:
            guard configuration.pausesWhenBackgrounded,
                  !configuration.prefersBackgroundAudio,
                  !isPictureInPictureActive,
                  wantsPlaying,
                  isPlaying
            else { return }
            resumeAfterForeground = configuration.resumesPlaybackAfterForeground
            engine.pause()
            _ = apply(.pause)
            refreshNowPlaying(rate: 0)

        case .willEnterForeground:
            break

        case .didBecomeActive:
            guard resumeAfterForeground else { return }
            resumeAfterForeground = false
            play()

        case .memoryWarning:
            thumbnailGeneration &+= 1
            thumbnailTask?.cancel()
            thumbnailTask = nil
            (engine as? any ManagedPlaybackControlling)?.cancelThumbnailGeneration()
            scrubPreviewImage = nil
        }
    }
}

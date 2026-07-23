import Foundation

@MainActor
extension PlayerSession {
    func startAudioSessionObservation() {
        audioEventTask?.cancel()
        let stream = dependencies.audioSession.makeEventStream()
        audioEventTask = Task { @MainActor [weak self] in
            for await event in stream {
                guard let self, !Task.isCancelled else { return }
                self.handleAudioSessionEvent(event)
            }
        }
    }

    func handleAudioSessionEvent(_ event: AudioSessionEvent) {
        guard status != .invalidated else { return }
        emitProduction(.audioSession(event))

        switch event {
        case .interruptionBegan:
            resumeAfterAudioInterruption = wantsPlaying && isPlaying
            engine.pause()
            _ = apply(.pause)
            refreshNowPlaying(rate: 0)

        case .interruptionEnded(let shouldResume):
            let shouldRestart = resumeAfterAudioInterruption && shouldResume
            resumeAfterAudioInterruption = false
            if shouldRestart {
                audioSessionActivated = false
                lifetimeCleanup.setAudioSessionActive(false)
                play()
            }

        case .routeChanged(let reason):
            if reason == .oldDeviceUnavailable, isPlaying {
                pause()
            }

        case .mediaServicesLost:
            resumeAfterAudioInterruption = wantsPlaying
            engine.pause()
            _ = apply(.pause)
            audioSessionActivated = false
            lifetimeCleanup.setAudioSessionActive(false)
            refreshNowPlaying(rate: 0)

        case .mediaServicesReset:
            engine.applyConfiguration(configuration)
            engine.setMuted(configuration.isMuted)
            engine.setVolume(volume)
            if resumeAfterAudioInterruption {
                resumeAfterAudioInterruption = false
                play()
            }
        }
    }
}

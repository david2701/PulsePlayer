import AVFoundation
import Foundation

@MainActor
extension AVPlayerEngine {
    func installPlayerObservations() {
        timeControlObs = avPlayer.observe(\.timeControlStatus, options: [.new, .initial]) {
            [weak self] player, _ in
            Task { @MainActor in
                guard let self else { return }
                switch player.timeControlStatus {
                case .playing:
                    self.emit(.timeControlPlaying)
                case .waitingToPlayAtSpecifiedRate:
                    self.emit(.timeControlWaiting)
                case .paused:
                    self.emit(.timeControlPaused)
                @unknown default:
                    break
                }
            }
        }

        externalPlaybackObs = avPlayer.observe(\.isExternalPlaybackActive, options: [.new]) {
            [weak self] player, _ in
            Task { @MainActor in
                self?.emit(.externalPlayback(player.isExternalPlaybackActive))
            }
        }
    }

    func tearDownPlayerObservations() {
        timeControlObs?.invalidate()
        externalPlaybackObs?.invalidate()
        timeControlObs = nil
        externalPlaybackObs = nil
    }

    func reinstallTimeObserver() {
        removeTimeObserver()
        let interval = max(0.1, configuration.positionUpdateInterval)
        let cm = CMTime(seconds: interval, preferredTimescale: 600)
        timeObserver = avPlayer.addPeriodicTimeObserver(
            forInterval: cm,
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                let seconds = time.seconds
                guard seconds.isFinite else { return }
                if abs(seconds - self.lastEmittedTime) > 0.01 {
                    self.lastEmittedTime = seconds
                    self.emit(.timeObserved(seconds))
                    self.emitBufferProgress()
                }
            }
        }
    }

    func removeTimeObserver() {
        if let timeObserver {
            avPlayer.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        lastEmittedTime = -1
    }

    private func emitBufferProgress() {
        guard let item = currentItem else {
            emitBufferProgressIfChanged(nil)
            return
        }
        let current = currentTime()
        let dur = duration()
        guard let dur, dur > 0 else {
            emitBufferProgressIfChanged(nil)
            return
        }
        guard let range = item.loadedTimeRanges
            .compactMap({ $0.timeRangeValue })
            .first(where: {
                let start = $0.start.seconds
                let end = start + $0.duration.seconds
                return current >= start && current <= end + 0.5
        })
        else {
            emitBufferProgressIfChanged(0)
            return
        }
        let end = range.start.seconds + range.duration.seconds
        let remainingWindow = max(0.001, min(dur - current, configuration.preferredForwardBufferDuration > 0
            ? configuration.preferredForwardBufferDuration
            : 30))
        let bufferedAhead = max(0, end - current)
        let progress = min(1, max(0, bufferedAhead / remainingWindow))
        emitBufferProgressIfChanged(progress)
    }

    private func emitBufferProgressIfChanged(_ progress: Double?) {
        if hasEmittedBufferProgress {
            switch (lastBufferProgress, progress) {
            case (nil, nil):
                return
            case let (previous?, current?) where abs(previous - current) < 0.02:
                return
            default:
                break
            }
        }
        hasEmittedBufferProgress = true
        lastBufferProgress = progress
        emit(.bufferProgress(progress))
    }
}

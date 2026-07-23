import AVFoundation
import Foundation

@MainActor
extension AVPlayerEngine {
    func installItemObservers(item: AVPlayerItem, generation gen: UInt64) {
        itemStatusObs = item.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self, gen == self.currentGeneration else { return }
                switch item.status {
                case .readyToPlay:
                    self.emit(.itemStatusReady)
                    self.emit(.durationKnown(self.duration()))
                    self.probeAccessLog(item)
                case .failed:
                    let err = item.error as NSError?
                    self.emit(.itemFailed(
                        domain: err?.domain ?? "AVFoundationErrorDomain",
                        code: err?.code ?? -1,
                        message: URLSanitizer.sanitizeMessage(
                            err?.localizedDescription ?? "Item failed"
                        )
                    ))
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }

        bufferEmptyObs = item.observe(\.isPlaybackBufferEmpty, options: [.new]) {
            [weak self] item, _ in
            Task { @MainActor in
                guard let self, gen == self.currentGeneration else { return }
                if item.isPlaybackBufferEmpty {
                    self.emit(.bufferEmpty)
                }
            }
        }

        keepUpObs = item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) {
            [weak self] item, _ in
            Task { @MainActor in
                guard let self, gen == self.currentGeneration else { return }
                if item.isPlaybackLikelyToKeepUp {
                    self.emit(.bufferHealthy)
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, gen == self.currentGeneration else { return }
                self.emit(.didPlayToEnd)
            }
        }

        failedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: nil
        ) { [weak self] note in
            let err = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError
            let domain = err?.domain ?? "AVFoundationErrorDomain"
            let code = err?.code ?? -1
            let message = URLSanitizer.sanitizeMessage(
                err?.localizedDescription ?? "Failed to play to end"
            )
            Task { @MainActor in
                guard let self, gen == self.currentGeneration else { return }
                self.emit(.itemFailed(domain: domain, code: code, message: message))
            }
        }

        accessLogObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemNewAccessLogEntry,
            object: item,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, gen == self.currentGeneration else { return }
                self.probeAccessLog(item)
            }
        }

        errorLogObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemNewErrorLogEntry,
            object: item,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, gen == self.currentGeneration,
                      let event = item.errorLog()?.events.last
                else { return }
                let comment = event.errorComment.map(URLSanitizer.sanitizeMessage)
                self.emitProduction(.diagnostic(.errorLog(
                    domain: event.errorDomain,
                    statusCode: event.errorStatusCode,
                    comment: comment
                )))
            }
        }
    }

    func tearDownItemObservers() {
        itemStatusObs?.invalidate()
        bufferEmptyObs?.invalidate()
        keepUpObs?.invalidate()
        itemStatusObs = nil
        bufferEmptyObs = nil
        keepUpObs = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        if let failedObserver {
            NotificationCenter.default.removeObserver(failedObserver)
            self.failedObserver = nil
        }
        if let accessLogObserver {
            NotificationCenter.default.removeObserver(accessLogObserver)
            self.accessLogObserver = nil
        }
        if let errorLogObserver {
            NotificationCenter.default.removeObserver(errorLogObserver)
            self.errorLogObserver = nil
        }
    }

    private func probeAccessLog(_ item: AVPlayerItem) {
        guard let event = item.accessLog()?.events.last else { return }
        let indicated = event.indicatedBitrate >= 0 ? event.indicatedBitrate : nil
        let observed = event.observedBitrate >= 0 ? event.observedBitrate : nil
        let changed: Bool
        if let i = indicated, let li = lastIndicatedBps {
            changed = abs(i - li) / max(li, 1) > 0.01 || observed != lastObservedBps
        } else {
            changed = indicated != lastIndicatedBps || observed != lastObservedBps
        }
        if changed {
            lastIndicatedBps = indicated
            lastObservedBps = observed
            emit(.accessLog(indicatedBps: indicated, observedBps: observed))
        }
        emitProduction(.diagnostic(.accessLog(
            indicatedBitrate: indicated,
            observedBitrate: observed,
            droppedVideoFrames: event.numberOfDroppedVideoFrames,
            stalls: event.numberOfStalls,
            segmentsDownloaded: event.numberOfMediaRequests
        )))
    }
}

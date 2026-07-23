import AVFoundation
import Foundation

@MainActor
extension AVPlayerEngine {
    func configureInterstitials(
        for source: MediaSource,
        primaryItem: AVPlayerItem,
        generation: UInt64
    ) {
        tearDownInterstitials()

        let controller = AVPlayerInterstitialEventController(primaryPlayer: avPlayer)
        interstitialController = controller
        interstitialMonitor = controller
        if !source.interstitials.isEmpty {
            interstitialDescriptorByID = Dictionary(
                uniqueKeysWithValues: source.interstitials.map { ($0.id, $0) }
            )
            controller.events = source.interstitials.map { descriptor in
                makeInterstitialEvent(
                    descriptor,
                    source: source,
                    primaryItem: primaryItem
                )
            }
            if #available(iOS 26, tvOS 26, macOS 26, *) {
                controller.localizedStringsBundle = .module
                controller.localizedStringsTableName = "Localizable"
            }
        }

        guard let monitor = interstitialMonitor else { return }
        let center = NotificationCenter.default
        interstitialObservers.append(center.addObserver(
            forName: AVPlayerInterstitialEventMonitor.currentEventDidChangeNotification,
            object: monitor,
            queue: nil
        ) { [weak self, weak monitor] _ in
            Task { @MainActor in
                guard let self,
                      generation == self.currentGeneration,
                      let monitor
                else { return }
                self.emitProduction(
                    .interstitialChanged(id: monitor.currentEvent?.identifier)
                )
                self.probeInterstitialSkipState(monitor)
            }
        })

        if #available(iOS 26, tvOS 26, macOS 26, *) {
            interstitialObservers.append(center.addObserver(
                forName: AVPlayerInterstitialEventMonitor
                    .currentEventSkippableStateDidChangeNotification,
                object: monitor,
                queue: nil
            ) { [weak self, weak monitor] _ in
                Task { @MainActor in
                    guard let self,
                          generation == self.currentGeneration,
                          let monitor
                    else { return }
                    self.probeInterstitialSkipState(monitor)
                }
            })
        }

        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        interstitialTimeObserver = monitor.interstitialPlayer.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self, weak monitor] _ in
            Task { @MainActor in
                guard let self,
                      generation == self.currentGeneration,
                      let monitor
                else { return }
                self.probeInterstitialSkipState(monitor)
            }
        }
    }

    func tearDownInterstitials() {
        if let observer = interstitialTimeObserver, let monitor = interstitialMonitor {
            monitor.interstitialPlayer.removeTimeObserver(observer)
        }
        interstitialTimeObserver = nil
        for observer in interstitialObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        interstitialObservers = []
        interstitialController?.events = nil
        interstitialController = nil
        interstitialMonitor = nil
        interstitialDescriptorByID = [:]
    }

    private func makeInterstitialEvent(
        _ descriptor: InterstitialDescriptor,
        source: MediaSource,
        primaryItem: AVPlayerItem
    ) -> AVPlayerInterstitialEvent {
        let event = AVPlayerInterstitialEvent(
            primaryItem: primaryItem,
            time: CMTime(seconds: descriptor.time, preferredTimescale: 600)
        )
        event.identifier = descriptor.id
        event.templateItems = descriptor.assetURLs.map { url in
            AVPlayerItem(asset: AssetFactory.makeURLAsset(from: source.replacingURL(url)))
        }
        var restrictions: AVPlayerInterstitialEvent.Restrictions = []
        if descriptor.restrictions.contains(.constrainsSeekingForward) {
            restrictions.insert(.constrainsSeekingForwardInPrimaryContent)
        }
        if descriptor.restrictions.contains(.requiresPreferredRate) {
            restrictions.insert(.requiresPlaybackAtPreferredRateForAdvancement)
        }
        event.restrictions = restrictions
        event.resumptionOffset = CMTime(
            seconds: descriptor.resumptionOffset,
            preferredTimescale: 600
        )
        event.playoutLimit = descriptor.playoutLimit.map {
            CMTime(seconds: $0, preferredTimescale: 600)
        } ?? .invalid
        event.willPlayOnce = descriptor.willPlayOnce
        event.alignsStartWithPrimarySegmentBoundary = descriptor.alignsToSegmentBoundaries
        event.alignsResumptionWithPrimarySegmentBoundary = descriptor.alignsToSegmentBoundaries
        if #available(iOS 26, tvOS 26, macOS 26, *), let skipAfter = descriptor.skipAfter {
            event.skipControlTimeRange = CMTimeRange(
                start: CMTime(seconds: max(0, skipAfter), preferredTimescale: 600),
                duration: .positiveInfinity
            )
            event.skipControlLocalizedLabelBundleKey = "skip_ad"
        }
        return event
    }

    private func probeInterstitialSkipState(_ monitor: AVPlayerInterstitialEventMonitor) {
        guard let event = monitor.currentEvent else { return }
        let canSkip: Bool
        if #available(iOS 26, tvOS 26, macOS 26, *) {
            canSkip = monitor.currentEventSkippableState == .eligible
        } else if let delay = interstitialDescriptorByID[event.identifier]?.skipAfter {
            canSkip = monitor.interstitialPlayer.currentTime().seconds >= delay
        } else {
            canSkip = false
        }
        emitProduction(.interstitialSkippable(id: event.identifier, canSkip: canSkip))
    }
}

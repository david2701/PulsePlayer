import PulsePlayer
import SwiftUI

/// Full-screen proof that the same production chrome ships on iOS and tvOS.
struct PlayerScreen: View {
    let item: CatalogItem

    @State private var session = Self.makeSession()

    var body: some View {
        PulsePlayerView(
            session: session,
            videoGravity: .resizeAspect,
            showsSubtitles: true,
            chrome: .full,
            theme: .pulse,
            enableGestures: false,
            allowsFullscreen: false,
            showsEditorialOverlays: true
        )
        .ignoresSafeArea()
        .background(Color.black)
        .task {
            if let next = DemoMedia.next(after: item) {
                session.nextContentProposal = NextContentProposal(
                    id: next.id,
                    sourceURL: next.url,
                    title: next.title,
                    subtitle: next.subtitle,
                    automaticAcceptanceInterval: 10
                )
            }
            await session.load(DemoMedia.source(from: item))
        }
        .onDisappear {
            session.pause()
        }
    }

    private static func makeSession() -> PlayerSession {
        var configuration = PlayerConfiguration(
            autoplay: true,
            isMuted: false,
            allowsPictureInPicture: false,
            updatesNowPlayingInfo: true,
            preferHardQualityLock: true
        )
        configuration.liveLatencyPolicy = .lowLatency
        configuration.performanceBudget = PlaybackPerformanceBudget(
            maximumTTFFMilliseconds: 8_000,
            maximumRebufferCount: 3,
            maximumTotalRebufferMilliseconds: 8_000
        )
        return PlayerSession(configuration: configuration)
    }
}

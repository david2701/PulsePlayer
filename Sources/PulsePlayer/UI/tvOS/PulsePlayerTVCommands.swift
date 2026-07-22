import Foundation

#if os(tvOS)
import SwiftUI

/// tvOS remote helpers: skip intervals and play/pause mapping for Siri Remote.
@MainActor
public enum PulsePlayerTVCommands {
    public static let defaultSkip: TimeInterval = 10

    public static func handlePlayPause(session: PlayerSession) {
        session.togglePlayPause()
    }

    public static func skipForward(session: PlayerSession, interval: TimeInterval = defaultSkip) {
        Task { await session.seek(relative: interval) }
    }

    public static func skipBackward(session: PlayerSession, interval: TimeInterval = defaultSkip) {
        Task { await session.seek(relative: -interval) }
    }
}

/// Simple focusable transport row for tvOS.
public struct PulsePlayerTVControls: View {
    let session: PlayerSession
    let skipInterval: TimeInterval

    public init(session: PlayerSession, skipInterval: TimeInterval = PulsePlayerTVCommands.defaultSkip) {
        self.session = session
        self.skipInterval = skipInterval
    }

    public var body: some View {
        HStack(spacing: 36) {
            Button {
                PulsePlayerTVCommands.skipBackward(session: session, interval: skipInterval)
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.title2)
                    .frame(minWidth: 72, minHeight: 48)
            }

            Button {
                PulsePlayerTVCommands.handlePlayPause(session: session)
            } label: {
                Image(systemName: session.isPlaying ? "pause.fill" : "play.fill")
                    .font(.largeTitle)
                    .frame(minWidth: 96, minHeight: 64)
            }

            Button {
                PulsePlayerTVCommands.skipForward(session: session, interval: skipInterval)
            } label: {
                Image(systemName: "goforward.10")
                    .font(.title2)
                    .frame(minWidth: 72, minHeight: 48)
            }
        }
        .buttonStyle(.card)
        .padding()
        .accessibilityElement(children: .contain)
    }
}
#endif

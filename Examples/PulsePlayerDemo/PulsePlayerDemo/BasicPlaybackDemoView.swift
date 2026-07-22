import PulsePlayer
import SwiftUI

struct BasicPlaybackDemoView: View {
    @State private var session = PlayerSession(
        configuration: PlayerConfiguration(
            autoplay: true,
            isMuted: false,
            allowsPictureInPicture: true,
            updatesNowPlayingInfo: true
        )
    )
    @State private var statusText = "idle"
    @State private var position: TimeInterval = 0
    @State private var duration: TimeInterval?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                PulsePlayerView(session: session)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                Text(statusText)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                if let duration, duration > 0 {
                    ProgressView(value: position, total: duration)
                        .padding(.horizontal)
                    Text(timeLabel(position) + " / " + timeLabel(duration))
                        .font(.caption2.monospaced())
                }

                HStack(spacing: 20) {
                    Button("Play", systemImage: "play.fill") { session.play() }
                    Button("Pause", systemImage: "pause.fill") { session.pause() }
                    Button("-10s", systemImage: "gobackward.10") {
                        Task { await session.seek(relative: -10) }
                    }
                    Button("+10s", systemImage: "goforward.10") {
                        Task { await session.seek(relative: 10) }
                    }
                }
                .buttonStyle(.bordered)

                HStack {
                    Button("PiP", systemImage: "pip.enter") {
                        session.startPictureInPicture()
                    }
                    .disabled(!session.isPictureInPicturePossible)

                    Button("Reload HLS") {
                        Task { await loadBipBop() }
                    }
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .navigationTitle("Playback")
            .task {
                await loadBipBop()
                listenEvents()
            }
            .onDisappear { session.pause() }
        }
    }

    private func loadBipBop() async {
        await session.load(
            DemoMedia.source(url: DemoMedia.bipbopHLS, title: "BipBop HLS")
        )
    }

    private func listenEvents() {
        Task {
            for await event in session.makeEventStream() {
                await MainActor.run {
                    switch event {
                    case .stateChanged(_, let to):
                        statusText = to.rawValue
                    case .position(let t):
                        position = t
                        duration = session.duration
                    case .duration(let d):
                        duration = d
                    case .failed(let err):
                        statusText = "failed: \(err)"
                    case .firstFrame(let elapsed):
                        statusText = "firstFrame \(String(format: "%.2fs", elapsed.timeInterval))"
                    default:
                        break
                    }
                }
            }
        }
    }

    private func timeLabel(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let c = components
        return TimeInterval(c.seconds) + TimeInterval(c.attoseconds) / 1e18
    }
}

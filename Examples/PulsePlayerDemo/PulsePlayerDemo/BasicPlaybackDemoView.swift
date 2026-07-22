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

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    PulsePlayerView(
                        session: session,
                        showsSubtitles: false,
                        showsControls: true
                    )
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    metaPanel
                    Spacer(minLength: 0)
                }
            }
            .navigationTitle("Playback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Source") {
                        Button("BipBop HLS") {
                            Task { await load(DemoMedia.bipbopHLS, title: "BipBop HLS") }
                        }
                        Button("Big Buck Bunny") {
                            Task { await load(DemoMedia.bigBuckBunnyMP4, title: "Big Buck Bunny") }
                        }
                        Button("Elephants Dream") {
                            Task { await load(DemoMedia.elephantsDreamMP4, title: "Elephants Dream") }
                        }
                    }
                }
            }
            .task { await load(DemoMedia.bipbopHLS, title: "BipBop HLS") }
            .onDisappear { session.pause() }
        }
    }

    private var metaPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                statusChip
                Spacer()
                if session.isPictureInPicturePossible {
                    Button {
                        session.startPictureInPicture()
                    } label: {
                        Label("PiP", systemImage: "pip.enter")
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text(session.currentSource?.title ?? "No source")
                .font(.headline)

            Text("Tap video for chrome · drag scrubber to seek · volume on the right")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private var statusChip: some View {
        Text(session.status.rawValue.uppercased())
            .font(.caption2.weight(.bold).monospaced())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.1), in: Capsule())
    }

    private func load(_ url: URL, title: String) async {
        await session.load(DemoMedia.source(url: url, id: title, title: title))
        session.play()
    }
}

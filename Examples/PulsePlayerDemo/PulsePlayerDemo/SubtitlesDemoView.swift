import PulsePlayer
import SwiftUI

struct SubtitlesDemoView: View {
    @State private var session = PlayerSession(
        configuration: PlayerConfiguration(autoplay: true, isMuted: true)
    )
    @State private var offset: Double = 0
    @State private var subsOn = true
    @State private var message = "Load video + SRT"

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                PulsePlayerView(session: session, showsSubtitles: true)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                Text(session.currentSubtitleText ?? "—")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)

                Toggle("Subtitles enabled", isOn: $subsOn)
                    .padding(.horizontal)
                    .onChange(of: subsOn) { _, on in
                        session.selectSubtitle(id: on ? "en" : nil)
                    }

                VStack(alignment: .leading) {
                    Text("Offset: \(String(format: "%+.1fs", offset))")
                        .font(.caption)
                    Slider(value: $offset, in: -3...3, step: 0.1)
                        .onChange(of: offset) { _, value in
                            session.setSubtitleOffset(value, trackID: "en")
                        }
                }
                .padding(.horizontal)

                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()
            }
            .navigationTitle("Subtitles")
            .task {
                await session.load(
                    DemoMedia.source(url: DemoMedia.bigBuckBunnyMP4, title: "BBB + SRT")
                )
                do {
                    _ = try session.addSubtitle(
                        content: DemoMedia.sampleSRT,
                        id: "en",
                        languageCode: "en",
                        label: "English",
                        format: .srt,
                        select: true
                    )
                    message = "SRT loaded (\(session.subtitleTracks.first?.cues.count ?? 0) cues)"
                } catch {
                    message = "Subtitle error: \(error.localizedDescription)"
                }
            }
            .onDisappear { session.pause() }
        }
    }
}

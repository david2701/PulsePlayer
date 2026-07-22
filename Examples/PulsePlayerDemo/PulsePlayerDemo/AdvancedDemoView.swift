import PulsePlayer
import SwiftUI

/// Quality, tracks, playlist queue, continue watching, FairPlay wiring.
struct AdvancedDemoView: View {
    @State private var session = PlayerSession(
        configuration: PlayerConfiguration(autoplay: true, isMuted: false)
    )
    @State private var queue = PlaybackQueue(items: [], autoplayNext: true)
    @State private var message = ""
    @State private var certURL = ""
    @State private var licenseURL = ""
    @State private var drmAssetURL = ""
    @State private var contentId = "asset-1"

    private let episodes: [MediaSource] = [
        MediaSource(id: "adv", url: DemoMedia.bipbopAdvanced, title: "1 · Advanced"),
        MediaSource(id: "16x9", url: DemoMedia.bipbop16x9, title: "2 · 16:9"),
        MediaSource(id: "4x3", url: DemoMedia.bipbop4x3, title: "3 · 4:3"),
        MediaSource(id: "basic", url: DemoMedia.bipbopBasic, title: "4 · Basic"),
    ]

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let h = min(max(geo.size.width * 9 / 16, 240), geo.size.height * 0.40)
                VStack(spacing: 0) {
                    PulsePlayerView(
                        session: session,
                        chrome: .full,
                        enableGestures: true
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: h)
                    .background(Color.black)

                    List {
                        Section("Playlist") {
                            Text("Item \(queue.currentIndex + 1)/\(max(queue.items.count, 1)) · \(queue.current?.title ?? "—")")
                                .font(.subheadline)
                            HStack {
                                Button("Prev") { Task { await queue.previous() } }
                                    .disabled(!queue.hasPrevious)
                                Button("Play queue") { Task { await startQueue() } }
                                Button("Next") { Task { await queue.next() } }
                                    .disabled(!queue.hasNext)
                            }
                            .buttonStyle(.bordered)
                        }

                        Section("Quality") {
                            Button("Auto") { session.setQualityAuto() }
                            ForEach(session.availableQualities) { q in
                                Button {
                                    session.setQuality(q)
                                } label: {
                                    HStack {
                                        Text(q.label)
                                        Text("\(q.bandwidth / 1000) kbps")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        if session.selectedQualityId == q.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                            if session.availableQualities.isEmpty {
                                Text("Load an HLS source to parse ladder")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Section("Tracks") {
                            ForEach(session.availableAudioTracks) { t in
                                Button(t.displayName) {
                                    session.selectAudioTrack(id: t.id)
                                }
                            }
                            ForEach(session.availableTextTracks) { t in
                                Button("\(t.displayName)\(t.isExternal ? " (ext)" : "")") {
                                    session.selectTextTrack(id: t.id)
                                }
                            }
                            if session.availableAudioTracks.isEmpty && session.availableTextTracks.isEmpty {
                                Text("No alternate tracks on this stream")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Section("Continue watching") {
                            if let id = session.currentSource?.id,
                               let pos = session.continueStore.position(for: id)
                            {
                                Text("Saved \(String(format: "%.0fs", pos)) for \(id)")
                                Button("Clear saved position") {
                                    session.continueStore.remove(sourceId: id)
                                }
                            } else {
                                Text("Pause mid-video to save resume point")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Section("FairPlay (real HTTP, not mock)") {
                            Text(fairPlayExplainer)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Certificate URL", text: $certURL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            TextField("License URL", text: $licenseURL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            TextField("Encrypted HLS URL", text: $drmAssetURL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            TextField("Content key asset id", text: $contentId)
                                .textInputAutocapitalization(.never)
                            Button("Wire HTTPContentKeyProvider + load") {
                                Task { await loadFairPlay() }
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        if !message.isEmpty {
                            Section("Status") {
                                Text(message)
                                    .font(.footnote)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Advanced")
            .navigationBarTitleDisplayMode(.inline)
            .task { await startQueue() }
            .onDisappear {
                queue.saveProgress()
                session.pause()
            }
        }
    }

    private var fairPlayExplainer: String {
        """
        No public free FairPlay stream exists. Real playback needs Apple FPS cert + key server + encrypted HLS.
        Paste your cert/license endpoints (from FairPlay Streaming Server SDK or a multi-DRM vendor). Uses HTTPContentKeyProvider — real network, not a mock CKC.
        """
    }

    private func startQueue() async {
        queue.setItems(episodes, startAt: 0)
        queue.session = session
        session.playbackQueue = queue
        session.continueWatchingEnabled = true
        await queue.playCurrent()
        message = "Queue playing · qualities load after ready"
    }

    private func loadFairPlay() async {
        guard let cert = URL(string: certURL), let lic = URL(string: licenseURL),
              let asset = URL(string: drmAssetURL), !contentId.isEmpty
        else {
            message = "Fill certificate, license, asset URL and content id"
            return
        }
        let provider = HTTPContentKeyProvider(
            configuration: .init(
                certificateURL: cert,
                licenseURL: lic,
                licenseBody: .jsonBase64SPC
            )
        )
        session.contentKeyProvider = provider
        let source = MediaSource(
            id: contentId,
            url: asset,
            title: "FairPlay asset",
            contentKeyAssetId: contentId
        )
        await session.load(source)
        session.play()
        message = "FairPlay provider wired — playback needs valid cert+CKC+encrypted media"
    }
}

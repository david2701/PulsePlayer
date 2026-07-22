import PulsePlayer
import SwiftUI

struct OfflineDemoView: View {
    @State private var session = PlayerSession(
        configuration: PlayerConfiguration(autoplay: false, isMuted: false)
    )
    @State private var items: [OfflineDownloadItem] = []
    @State private var message = "Download, then play with full controls."
    @State private var isEnqueueing = false

    private let downloadID = "demo-bipbop"

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let playerHeight = min(geo.size.width * 9 / 16, geo.size.height * 0.38)
                VStack(spacing: 0) {
                    PulsePlayerView(
                        session: session,
                        videoGravity: .resizeAspect,
                        showsSubtitles: false,
                        chrome: .full
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: playerHeight)
                    .background(Color.black)

                    List {
                        Section("Status") {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Section("Catalog") {
                            if items.isEmpty {
                                Text("No downloads")
                            } else {
                                ForEach(items) { item in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(item.title ?? item.id)
                                            Spacer()
                                            Text(item.state.rawValue)
                                                .font(.caption.monospaced())
                                                .foregroundStyle(.secondary)
                                        }
                                        ProgressView(value: item.progress)
                                    }
                                }
                            }
                        }
                        Section {
                            Button {
                                Task { await enqueue() }
                            } label: {
                                Label(
                                    isEnqueueing ? "Starting…" : "Download BipBop HLS",
                                    systemImage: "arrow.down.circle"
                                )
                            }
                            .disabled(isEnqueueing)

                            Button {
                                Task { await playOffline() }
                            } label: {
                                Label("Play offline", systemImage: "play.circle")
                            }

                            Button("Remove", role: .destructive) {
                                removeDownload()
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Offline")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                refresh()
                OfflineDownloadManager.shared.onChange = { items = $0 }
            }
            .onDisappear { session.pause() }
        }
    }

    private func refresh() {
        items = OfflineDownloadManager.shared.items
    }

    private func enqueue() async {
        isEnqueueing = true
        defer { isEnqueueing = false }
        do {
            _ = try OfflineDownloadManager.shared.enqueue(
                sourceURL: DemoMedia.bipbopHLS,
                id: downloadID,
                title: "BipBop offline"
            )
            message = "Downloading…"
            refresh()
        } catch {
            message = error.localizedDescription
        }
    }

    private func playOffline() async {
        guard let source = OfflineDownloadManager.shared.playableSource(id: downloadID) else {
            message = "Not ready yet"
            return
        }
        await session.load(source)
        session.play()
        message = "Playing offline"
    }

    private func removeDownload() {
        try? OfflineDownloadManager.shared.remove(id: downloadID)
        message = "Removed"
        refresh()
    }
}

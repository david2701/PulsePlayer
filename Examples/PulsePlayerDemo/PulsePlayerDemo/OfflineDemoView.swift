import PulsePlayer
import SwiftUI

struct OfflineDemoView: View {
    @State private var session = PlayerSession(
        configuration: PlayerConfiguration(autoplay: false, isMuted: true)
    )
    @State private var items: [OfflineDownloadItem] = []
    @State private var message = "Offline works on iOS/tvOS device or simulator."
    @State private var isEnqueueing = false

    private let downloadID = "demo-bipbop"

    var body: some View {
        NavigationStack {
            List {
                Section("Catalog") {
                    if items.isEmpty {
                        Text("No downloads yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title ?? item.id)
                                    .font(.headline)
                                Text(item.state.rawValue)
                                    .font(.caption.monospaced())
                                ProgressView(value: item.progress)
                                if let err = item.errorMessage {
                                    Text(err).font(.caption2).foregroundStyle(.red)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Actions") {
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
                        Label("Play offline if ready", systemImage: "play.circle")
                    }

                    Button(role: .destructive) {
                        removeDownload()
                    } label: {
                        Label("Remove download", systemImage: "trash")
                    }
                }

                Section("Player") {
                    PulsePlayerView(session: session)
                        .frame(height: 200)
                        .listRowInsets(EdgeInsets())
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Offline")
            .onAppear {
                refresh()
                OfflineDownloadManager.shared.onChange = { list in
                    items = list
                }
            }
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
            message = "Download enqueued / in progress"
            refresh()
        } catch {
            message = "Enqueue failed: \(error.localizedDescription)"
        }
    }

    private func playOffline() async {
        guard let source = OfflineDownloadManager.shared.playableSource(id: downloadID) else {
            message = "Not ready yet (state: \(OfflineDownloadManager.shared.item(id: downloadID)?.state.rawValue ?? "none"))"
            return
        }
        await session.load(source)
        session.play()
        message = "Playing offline asset"
    }

    private func removeDownload() {
        do {
            try OfflineDownloadManager.shared.remove(id: downloadID)
            message = "Removed"
            refresh()
        } catch {
            message = "Remove failed: \(error.localizedDescription)"
        }
    }
}

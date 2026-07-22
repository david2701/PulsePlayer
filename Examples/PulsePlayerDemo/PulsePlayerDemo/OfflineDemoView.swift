import PulsePlayer
import SwiftUI

struct OfflineDemoView: View {
    @State private var session = PlayerSession(
        configuration: PlayerConfiguration(autoplay: false, isMuted: false)
    )
    @State private var items: [OfflineDownloadItem] = []
    @State private var message = "Download on device/simulator, then play with full controls."
    @State private var isEnqueueing = false

    private let downloadID = "demo-bipbop"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    PulsePlayerView(
                        session: session,
                        showsSubtitles: false,
                        showsControls: true
                    )
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16)

                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)

                    GroupBox("Downloads") {
                        if items.isEmpty {
                            Text("No items")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(items) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(item.title ?? item.id)
                                            .font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Text(item.state.rawValue)
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)
                                    }
                                    ProgressView(value: item.progress)
                                    if let err = item.errorMessage {
                                        Text(err)
                                            .font(.caption2)
                                            .foregroundStyle(.red)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    VStack(spacing: 10) {
                        Button {
                            Task { await enqueue() }
                        } label: {
                            Label(
                                isEnqueueing ? "Starting…" : "Download BipBop HLS",
                                systemImage: "arrow.down.circle.fill"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isEnqueueing)

                        Button {
                            Task { await playOffline() }
                        } label: {
                            Label("Play offline asset", systemImage: "play.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button(role: .destructive) {
                            removeDownload()
                        } label: {
                            Label("Remove download", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 24)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Offline")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                refresh()
                OfflineDownloadManager.shared.onChange = { list in
                    items = list
                }
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
            message = "Download enqueued — watch progress below"
            refresh()
        } catch {
            message = "Enqueue failed: \(error.localizedDescription)"
        }
    }

    private func playOffline() async {
        guard let source = OfflineDownloadManager.shared.playableSource(id: downloadID) else {
            let state = OfflineDownloadManager.shared.item(id: downloadID)?.state.rawValue ?? "none"
            message = "Not ready (state: \(state)). Wait until completed."
            return
        }
        await session.load(source)
        session.play()
        message = "Playing offline — use on-video controls to seek / pause / volume"
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

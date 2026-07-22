import PulsePlayer
import SwiftUI

struct FeedDemoView: View {
    @State private var pool = PlayerPool(
        size: 3,
        configuration: PlayerConfiguration(
            autoplay: false,
            isMuted: true,
            updatesNowPlayingInfo: false
        )
    )
    @State private var visibleID: String?

    private let items = DemoMedia.feedItems

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        FeedCellView(item: item, pool: pool)
                            .containerRelativeFrame(.vertical)
                            .id(item.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $visibleID)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: visibleID) {
                await onVisibleChanged()
            }
            .onAppear {
                if visibleID == nil {
                    visibleID = items.first?.id
                }
            }
            .onDisappear {
                pool.shutdown()
            }
        }
    }

    private func onVisibleChanged() async {
        guard let visibleID,
              let item = items.first(where: { $0.id == visibleID })
        else { return }

        _ = await pool.acquire(
            source: MediaSource(id: item.id, url: item.url, title: item.title),
            priority: .visible
        )

        let idx = items.firstIndex(where: { $0.id == visibleID }) ?? 0
        let next = items.dropFirst(idx + 1).prefix(2).map {
            MediaSource(id: $0.id, url: $0.url, title: $0.title)
        }
        await pool.prewarm(Array(next))
        await pool.rebalance(visibleIDs: [visibleID] + next.map(\.id))
    }
}

private struct FeedCellView: View {
    let item: FeedItem
    let pool: PlayerPool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.black
            if let session = pool.session(for: item.id) {
                PulsePlayerView(session: session, showsSubtitles: false)
            } else {
                ProgressView()
                    .tint(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.title3.bold())
                Text(item.id)
                    .font(.caption.monospaced())
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

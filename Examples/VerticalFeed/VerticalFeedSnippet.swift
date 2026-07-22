// Example: vertical feed using PlayerPool (0.3.0).
// Copy into an iOS app target that depends on PulsePlayer.

import PulsePlayer
import SwiftUI

struct FeedItem: Identifiable {
    let id: String
    let url: URL
    let title: String
}

struct VerticalFeedView: View {
    private let items: [FeedItem]
    @State private var pool = PlayerPool(
        size: 3,
        configuration: PlayerConfiguration(
            autoplay: false,
            isMuted: true,
            updatesNowPlayingInfo: false
        )
    )
    @State private var visibleID: String?

    init(items: [FeedItem]) {
        self.items = items
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    FeedCell(item: item, pool: pool)
                        .containerRelativeFrame(.vertical)
                        .id(item.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $visibleID)
        .ignoresSafeArea()
        .task(id: visibleID) {
            await onVisibleChanged()
        }
        .onDisappear {
            pool.shutdown()
        }
    }

    private func onVisibleChanged() async {
        guard let visibleID else { return }
        guard let item = items.first(where: { $0.id == visibleID }) else { return }

        _ = await pool.acquire(
            source: MediaSource(id: item.id, url: item.url, title: item.title),
            priority: .visible
        )

        // Prewarm next two.
        let idx = items.firstIndex(where: { $0.id == visibleID }) ?? 0
        let next = items.dropFirst(idx + 1).prefix(2).map {
            MediaSource(id: $0.id, url: $0.url, title: $0.title)
        }
        await pool.prewarm(Array(next))

        let order = [visibleID] + next.map(\.id)
        await pool.rebalance(visibleIDs: order)
    }
}

private struct FeedCell: View {
    let item: FeedItem
    let pool: PlayerPool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let session = pool.session(for: item.id) {
                PulsePlayerView(session: session)
            } else {
                Color.black
                ProgressView()
            }
            Text(item.title)
                .font(.headline)
                .foregroundStyle(.white)
                .padding()
        }
    }
}

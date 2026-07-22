import PulsePlayer
import SwiftUI

/// Page-based feed (more reliable than LazyVStack + scrollPosition for session binding).
struct FeedDemoView: View {
    @State private var pool = PlayerPool(
        size: 3,
        configuration: PlayerConfiguration(
            autoplay: false,
            isMuted: true,
            updatesNowPlayingInfo: false,
            pauseWhenDetached: true
        )
    )
    @State private var index = 0
    @State private var readyIDs: Set<String> = []

    private let items = DemoMedia.feedItems

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                TabView(selection: $index) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                        // Read revision so pages refresh when pool acquires sessions.
                        let _ = pool.revision
                        FeedPage(
                            item: item,
                            session: pool.session(for: item.id),
                            isActive: i == index
                        )
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .ignoresSafeArea(edges: .bottom)

                VStack {
                    HStack {
                        Text("\(index + 1)/\(items.count)")
                            .font(.caption.weight(.bold).monospaced())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                        Spacer()
                    }
                    .padding()
                    Spacer()
                }
            }
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: index) {
                await activate(index: index)
            }
            .onDisappear {
                pool.shutdown()
                readyIDs = []
            }
        }
    }

    private func activate(index: Int) async {
        guard items.indices.contains(index) else { return }
        let item = items[index]

        _ = await pool.acquire(
            source: MediaSource(id: item.id, url: item.url, title: item.title),
            priority: .visible
        )
        readyIDs.insert(item.id)

        // Prewarm neighbors.
        var neighbors: [MediaSource] = []
        if index + 1 < items.count {
            let n = items[index + 1]
            neighbors.append(MediaSource(id: n.id, url: n.url, title: n.title))
        }
        if index + 2 < items.count {
            let n = items[index + 2]
            neighbors.append(MediaSource(id: n.id, url: n.url, title: n.title))
        }
        await pool.prewarm(neighbors)

        var order = [item.id]
        order.append(contentsOf: neighbors.map(\.id))
        await pool.rebalance(visibleIDs: order)
        readyIDs.formUnion(order)
    }
}

private struct FeedPage: View {
    let item: FeedItem
    let session: PlayerSession?
    let isActive: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.black
            if let session {
                PulsePlayerView(
                    session: session,
                    videoGravity: .resizeAspectFill,
                    showsSubtitles: false,
                    showsControls: isActive
                )
                .id(session.id)
            } else {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.85)],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.title2.bold())
                Text(item.id)
                    .font(.caption.monospaced())
                    .opacity(0.7)
                Text(isActive ? "Swipe for next · use controls to seek" : "Inactive")
                    .font(.footnote)
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .padding(20)
            .padding(.bottom, 28)
        }
    }
}

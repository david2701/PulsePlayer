import PulsePlayer
import SwiftUI

/// Vertical short-form feed (swipe up/down). Uses **minimal** chrome, not full transport.
struct FeedDemoView: View {
    @State private var pool = PlayerPool(
        size: 3,
        configuration: PlayerConfiguration(
            autoplay: true,
            isMuted: true,
            updatesNowPlayingInfo: false,
            pauseWhenDetached: true
        )
    )
    @State private var index = 0

    private let items = DemoMedia.feedItems

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                        let _ = pool.revision
                        FeedPage(
                            item: item,
                            session: pool.session(for: item.id),
                            isActive: i == index,
                            size: geo.size
                        )
                        .frame(width: geo.size.width, height: geo.size.height)
                        .id(i)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: Binding(
                get: { index },
                set: { if let v = $0 { index = v } }
            ))
            .scrollIndicators(.hidden)
            .ignoresSafeArea()
            .background(Color.black)
            .task(id: index) {
                await activate(index: index)
            }
            .onAppear {
                Task { await activate(index: index) }
            }
            .onDisappear {
                pool.shutdown()
            }
            .overlay(alignment: .topLeading) {
                Text("\(index + 1)/\(items.count)")
                    .font(.caption.weight(.bold).monospaced())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 56)
                    .padding(.leading, 16)
            }
            .overlay(alignment: .top) {
                Text("Feed")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.top, 56)
            }
        }
        .ignoresSafeArea()
    }

    private func activate(index: Int) async {
        guard items.indices.contains(index) else { return }
        let item = items[index]

        let session = await pool.acquire(
            source: MediaSource(id: item.id, url: item.url, title: item.title),
            priority: .visible
        )
        // Ensure play for visible page (pool may leave paused after rebalance race).
        session.setMuted(true)
        session.play()

        var neighbors: [MediaSource] = []
        if index + 1 < items.count {
            let n = items[index + 1]
            neighbors.append(MediaSource(id: n.id, url: n.url, title: n.title))
        }
        if index > 0 {
            let n = items[index - 1]
            neighbors.append(MediaSource(id: n.id, url: n.url, title: n.title))
        }
        await pool.prewarm(neighbors)

        var order = [item.id]
        order.append(contentsOf: neighbors.map(\.id))
        await pool.rebalance(visibleIDs: order)
        // Rebalance may pause non-visible; force visible playing again.
        pool.session(for: item.id)?.play()
    }
}

private struct FeedPage: View {
    let item: FeedItem
    let session: PlayerSession?
    let isActive: Bool
    let size: CGSize

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.black

            if let session {
                PulsePlayerView(
                    session: session,
                    videoGravity: .resizeAspectFill,
                    showsSubtitles: false,
                    chrome: .minimal
                )
                .frame(width: size.width, height: size.height)
                .id("\(item.id)-\(session.id)")
            } else {
                ProgressView()
                    .tint(.white)
            }

            // Soft gradient for title readability (doesn't block taps on center).
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 180)
                .allowsHitTesting(false)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.title2.bold())
                Text("Swipe ↑↓ · tap to play/pause")
                    .font(.footnote)
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .padding(20)
            .padding(.bottom, 28)
            .allowsHitTesting(false)
        }
        .frame(width: size.width, height: size.height)
    }
}

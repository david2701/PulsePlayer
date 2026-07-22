import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            BasicPlaybackDemoView()
                .tabItem { Label("Play", systemImage: "play.rectangle.fill") }

            SubtitlesDemoView()
                .tabItem { Label("Subs", systemImage: "captions.bubble.fill") }

            FeedDemoView()
                .tabItem { Label("Feed", systemImage: "rectangle.stack.fill") }

            OfflineDemoView()
                .tabItem { Label("Offline", systemImage: "arrow.down.circle.fill") }
        }
        .tint(.cyan)
        .preferredColorScheme(.dark)
    }
}

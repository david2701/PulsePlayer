import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            BasicPlaybackDemoView()
                .tabItem { Label("Play", systemImage: "play.rectangle.fill") }

            SubtitlesDemoView()
                .tabItem { Label("Subs", systemImage: "captions.bubble") }

            FeedDemoView()
                .tabItem { Label("Feed", systemImage: "rectangle.stack") }

            OfflineDemoView()
                .tabItem { Label("Offline", systemImage: "arrow.down.circle") }
        }
    }
}

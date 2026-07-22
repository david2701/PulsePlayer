import PulsePlayer
import SwiftUI

/// Living-room entry: catalog → full-screen player.
struct RootView: View {
    @State private var path = NavigationPath()
    @State private var selected: CatalogItem?

    var body: some View {
        NavigationStack(path: $path) {
            CatalogView { item in
                selected = item
                path.append(item)
            }
            .navigationDestination(for: CatalogItem.self) { item in
                PlayerScreen(item: item)
            }
        }
    }
}

struct CatalogView: View {
    let onSelect: (CatalogItem) -> Void
    @FocusState private var focusedID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            VStack(alignment: .leading, spacing: 12) {
                Text("PulsePlayer")
                    .font(.largeTitle.bold())
                Text("tvOS demo · focus the remote · select a stream")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 48)
            .padding(.top, 48)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 28) {
                    ForEach(DemoMedia.catalog) { item in
                        CatalogCard(item: item, isFocused: focusedID == item.id) {
                            onSelect(item)
                        }
                        .focused($focusedID, equals: item.id)
                    }
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 24)
            }

            Spacer(minLength: 0)

            Text(PulsePlayerInfo.attribution + " · v\(PulsePlayerInfo.version)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 48)
                .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.92).ignoresSafeArea())
        .onAppear {
            if focusedID == nil {
                focusedID = DemoMedia.catalog.first?.id
            }
        }
    }
}

private struct CatalogCard: View {
    let item: CatalogItem
    let isFocused: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.12, green: 0.28, blue: 0.42),
                                Color(red: 0.06, green: 0.1, blue: 0.16),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 420, height: 236)
                    .overlay {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 54))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isFocused ? Color.cyan : Color.white.opacity(0.12), lineWidth: isFocused ? 4 : 1)
                    }

                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 420, alignment: .leading)
        }
        .buttonStyle(.card)
        .scaleEffect(isFocused ? 1.04 : 1)
        .animation(.easeOut(duration: 0.18), value: isFocused)
    }
}

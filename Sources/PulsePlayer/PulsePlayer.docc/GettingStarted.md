# Getting started

Integrate PulsePlayer with Swift Package Manager and a long-lived session.

## Install

```swift
dependencies: [
    .package(url: "https://github.com/david2701/PulsePlayer.git", from: "0.9.0")
]
```

## Minimal SwiftUI player

Own ``PlayerSession`` outside `body` so SwiftUI does not recreate the engine:

```swift
import PulsePlayer
import SwiftUI

struct PlayerScreen: View {
    @State private var session = PlayerSession(
        configuration: PlayerConfiguration(autoplay: true)
    )

    var body: some View {
        PulsePlayerView(
            session: session,
            showsSubtitles: true,
            chrome: .full,
            theme: .pulse
        )
        .aspectRatio(16 / 9, contentMode: .fit)
        .task {
            let url = URL(string:
                "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
            )!
            await session.load(MediaSource(url: url, title: "Sample"))
        }
        .onDisappear { session.pause() }
    }
}
```

## Headless events

```swift
let session = PlayerSession()
Task {
    for await event in session.makeEventStream() {
        // firstFrame, rebuffer, bitrateChanged, failed, …
    }
}
await session.load(MediaSource(url: url))
session.play()
```

## Platforms

- iOS / iPadOS / tvOS **17+**
- Swift **6.3+** (`swift-tools-version: 6.3`)
- MIT — Copyright David Villegas

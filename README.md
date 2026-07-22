# PulsePlayer

Production-oriented video player toolkit for **Apple platforms**, built on **AVPlayer**.

- **Platforms:** iOS 17+, iPadOS 17+, tvOS 17+ (macOS for development / `swift test`)
- **Swift:** 6.2+ (strict concurrency)
- **License:** MIT
- **Install:** Swift Package Manager

Not an FFmpeg media center. Not a one-file demo wrapper.  
Focus: **stable lifecycle**, **typed state**, **QoE events**, **easy SPM integration**.

## Features

| Area | Support |
| --- | --- |
| Playback | HLS, progressive MP4 |
| Lifecycle | Long-lived `PlayerSession` (`@Observable`) — not recreated by SwiftUI `body` |
| State | Public state machine + recoverable `PlayerError` |
| Auth media | HTTP headers / cookies on the **initial** asset request |
| Resilience | Stall recovery, startup timeout, retry policy |
| Observability | `makeEventStream()` (first frame, rebuffer, bitrate, …) |
| UI | Zero-chrome `PulsePlayerView` + `PulsePlayerViewController` |
| System | Picture in Picture, Now Playing, audio session |
| Feeds | `PlayerPool` — prewarm / rebalance for vertical lists |

**Not included (yet):** FairPlay, offline HLS downloads, subtitles, ad SDK.

## Install

### Xcode

**File → Add Package Dependencies…**  
`https://github.com/david2701/PulsePlayer.git`

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/david2701/PulsePlayer.git", from: "0.3.0")
]
```

```swift
.target(name: "MyApp", dependencies: ["PulsePlayer"])
```

## Quick start

```swift
import PulsePlayer
import SwiftUI

struct PlayerScreen: View {
    @State private var session = PlayerSession(
        configuration: PlayerConfiguration(autoplay: true)
    )

    var body: some View {
        PulsePlayerView(session: session)
            .task {
                let url = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8")!
                await session.load(MediaSource(url: url, title: "Sample"))
            }
            .onDisappear { session.pause() }
    }
}
```

**Important:** keep `PlayerSession` in `@State` (or equivalent). Do not create the session inside `body` without stable storage.

### Headless / events

```swift
let session = PlayerSession()

Task {
    for await event in session.makeEventStream() {
        // .firstFrame, .failed, .rebufferStarted, …
    }
}

await session.load(
    MediaSource(
        url: url,
        headers: ["Authorization": "Bearer …"]
    )
)
session.play()
```

## Headers & cookies

| Behavior | Contract |
| --- | --- |
| Headers | Applied on the **initial** `AVURLAsset` request |
| HLS segments | Often **do not** inherit those headers (AVFoundation limit) |
| Cookies | Via `HTTPCookieValue` → `Cookie` header on the initial request |
| Token refresh | Your job: call `load` again with new headers |

PulsePlayer redacts common secrets from logs and warning events.

## Picture in Picture & background

```swift
var config = PlayerConfiguration()
config.allowsPictureInPicture = true
config.updatesNowPlayingInfo = true
config.prefersBackgroundAudio = true

let session = PlayerSession(configuration: config)
// Attach UI (PulsePlayerView), then:
session.startPictureInPicture()
```

In the **host app**: enable Background Modes → Audio (and PiP if needed).

## Vertical feeds (`PlayerPool`)

```swift
let pool = PlayerPool(size: 3, configuration: PlayerConfiguration(isMuted: true))

let session = await pool.acquire(
    source: MediaSource(id: "1", url: url),
    priority: .visible
)
await pool.prewarm([MediaSource(id: "2", url: nextURL)])
await pool.rebalance(visibleIDs: ["1", "2"])

pool.shutdown()
```

Snippets: `Examples/BasicPlayback`, `Examples/VerticalFeed`.

## Requirements

- Xcode with Swift 6.2+ toolchain
- iOS / tvOS 17+ deployment target for apps

```bash
swift test
./Scripts/check-line-count.sh   # optional: max 400 lines per Swift file
```

## Version

`PulsePlayerInfo.version` → **0.3.0**

## License

MIT. See [LICENSE](LICENSE).

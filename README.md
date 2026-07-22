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
| Subtitles | External **SRT / WebVTT**, offset, style, enable/disable, overlay |
| Controls | Built-in chrome: **play/pause, scrub/seek, skip, mute, volume** |
| Offline | **HLS/progressive download** (iOS/tvOS) → play from local asset |

## Install

### Xcode

**File → Add Package Dependencies…**  
`https://github.com/david2701/PulsePlayer.git`

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/david2701/PulsePlayer.git", from: "0.4.1")
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
        // showsControls: play/pause · scrubber · skip · mute · volume
        PulsePlayerView(session: session, showsSubtitles: true, showsControls: true)
            .aspectRatio(16/9, contentMode: .fit)
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

## Subtitles (SRT / VTT)

```swift
try session.addSubtitle(
    content: srtString,
    id: "en",
    languageCode: "en",
    format: .srt
)

try await session.addSubtitle(from: subtitleURL, languageCode: "es", label: "Español")

session.setSubtitleOffset(0.3)
session.selectSubtitle(id: nil) // hide
session.setSubtitlesEnabled(true)
session.applySubtitleStyle(.large) // or custom SubtitleStyle
// session.currentSubtitleText + playbackTime drive the overlay
```

## Built-in controls

```swift
PulsePlayerView(session: session, showsControls: true)
// or
PulsePlayerControls(session: session)
```

Uses observed `playbackTime` / `playbackDuration` so the scrubber seeks for real (not a decorative progress bar).

## Offline downloads (iOS / tvOS)

```swift
let manager = OfflineDownloadManager.shared
_ = try manager.enqueue(sourceURL: hlsURL, id: "episode-1", title: "Episode 1")

if let source = manager.playableSource(id: "episode-1") {
    await session.load(source)
    session.play()
}
```

Not available on macOS. Use a device/simulator for real downloads.

## Demo app

```bash
cd Examples/PulsePlayerDemo
xcodegen generate   # if the .xcodeproj is missing
open PulsePlayerDemo.xcodeproj
```

Tabs: **Play** (HLS), **Subs** (SRT), **Feed** (PlayerPool), **Offline**.

## Requirements

- Xcode with Swift 6.2+ toolchain
- iOS / tvOS 17+ deployment target for apps

```bash
swift test
./Scripts/check-line-count.sh   # optional: max 400 lines per Swift file
```


## Version

`PulsePlayerInfo.version` → **0.4.1**

## License

MIT. See [LICENSE](LICENSE).

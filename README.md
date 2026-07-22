# PulsePlayer

**Production AVPlayer toolkit** for Apple platforms — Swift Package (MIT).

Stable session lifecycle · typed state · real transport chrome · SPM-first.

| | |
| --- | --- |
| **Platforms** | iOS 17+, iPadOS 17+, tvOS 17+ |
| **Swift** | 6.2+ (strict concurrency) |
| **Version** | `0.7.2` (`PulsePlayerInfo.version`) |
| **License** | [MIT](LICENSE) |

Not an FFmpeg media center. Not a toy `VideoPlayer` wrapper.

---

## Install

**Xcode:** *File → Add Package Dependencies…*

```
https://github.com/david2701/PulsePlayer.git
```

**Package.swift:**

```swift
dependencies: [
    .package(url: "https://github.com/david2701/PulsePlayer.git", from: "0.7.2")
]
```

```swift
.target(name: "MyApp", dependencies: ["PulsePlayer"])
```

---

## Quick start

```swift
import PulsePlayer
import SwiftUI

struct PlayerScreen: View {
    // Own the session outside `body` — never recreate it on every render.
    @State private var session = PlayerSession(
        configuration: PlayerConfiguration(autoplay: true)
    )

    var body: some View {
        PulsePlayerView(
            session: session,
            showsSubtitles: true,
            chrome: .full   // .full | .lite | .minimal | .none
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

### Headless + events

```swift
let session = PlayerSession()

Task {
    for await event in session.makeEventStream() {
        // .firstFrame, .failed, .rebufferStarted, .bitrateChanged, …
    }
}

await session.load(MediaSource(
    url: url,
    headers: ["Authorization": "Bearer …"]
))
session.play()
```

---

## Features

| Area | What you get |
| --- | --- |
| **Playback** | HLS + progressive MP4 |
| **Lifecycle** | Long-lived `PlayerSession` (`@Observable`) |
| **State** | Public state machine + recoverable `PlayerError` |
| **Chrome** | `.none` · `.minimal` · `.lite` · `.full` |
| **Transport** | Seek scrubber with **current / duration** labels, ±10s, mute, volume menu |
| **Gestures** | Double-tap left −10s / right +10s |
| **Tracks** | Audio + text (HLS embedded and external SRT/VTT) |
| **Quality** | HLS ladder parse · Auto / manual peak bitrate |
| **Subtitles** | External SRT/VTT, offset, style, overlay |
| **System** | PiP, Now Playing, audio session, AirPlay picker |
| **Feeds** | `PlayerPool` prewarm / rebalance |
| **Offline** | Download, resume/retry, storage limit (iOS/tvOS) |
| **Playlist** | `PlaybackQueue` + continue watching |
| **Live** | Seekable DVR window + seek to live edge |
| **DRM** | FairPlay via `ContentKeyProviding` / `HTTPContentKeyProvider` |
| **Ads** | `AdCue` markers + host `AdCueHandling` plugin |
| **QoE** | Events: first frame, rebuffer, bitrate, buffer |

---

## Chrome modes

| Mode | Best for | UI |
| --- | --- | --- |
| `.full` | Detail / offline | Scrubber + times + transport + overflow menu (tracks, quality, volume) |
| `.lite` | Inline cards | Scrubber + times + play + mute |
| `.minimal` | Vertical feed | Tap play/pause · double-tap seek · mute |
| `.none` | Custom UI | Video surface only |

```swift
PulsePlayerView(session: session, chrome: .full)
PulsePlayerView(session: session, chrome: .minimal)
```

Scrubber layout (full / lite):

```text
0:06  ————●————————  10:00
[▶] [−10] [+10]          [⋯] [AirPlay] [mute] [⛶]
```

---

## Common recipes

### Headers & cookies

| Behavior | Contract |
| --- | --- |
| Headers | Applied on the **initial** `AVURLAsset` request only |
| HLS segments | Often **do not** inherit those headers (AVFoundation) |
| Cookies | `HTTPCookieValue` → `Cookie` header on the initial request |
| Token refresh | Host: call `load` again with new headers |

Secrets are redacted in logs and warning events.

### Picture in Picture & background

```swift
var config = PlayerConfiguration()
config.allowsPictureInPicture = true
config.updatesNowPlayingInfo = true
config.prefersBackgroundAudio = true

let session = PlayerSession(configuration: config)
// After PulsePlayerView attaches the layer:
session.startPictureInPicture()
```

Host app: **Background Modes → Audio** (and PiP capability if needed).

### Vertical feed

```swift
let pool = PlayerPool(size: 3, configuration: PlayerConfiguration(isMuted: true))

let session = await pool.acquire(
    source: MediaSource(id: "1", url: url, title: "Clip"),
    priority: .visible
)
await pool.prewarm([MediaSource(id: "2", url: nextURL)])
await pool.rebalance(visibleIDs: ["1", "2"])
pool.shutdown()
```

Use `PulsePlayerView(session:session, chrome: .minimal)` in cells.

### Subtitles

```swift
try session.addSubtitle(content: srt, id: "en", languageCode: "en", format: .srt)
try await session.addSubtitle(from: vttURL, languageCode: "es", label: "Español")

session.setSubtitleOffset(0.3)
session.applySubtitleStyle(.large)
session.selectSubtitle(id: nil) // hide
```

### Offline (iOS / tvOS)

```swift
let item = try OfflineDownloadManager.shared.resumeOrEnqueue(
    sourceURL: hlsURL,
    id: "episode-1",
    title: "E1"
)

if let source = OfflineDownloadManager.shared.playableSource(id: "episode-1") {
    await session.load(source)
    session.play()
}

try OfflineDownloadManager.shared.retry(id: "episode-1")
try OfflineDownloadManager.shared.enforceStorageLimit()
```

Not available on macOS.

### Quality, tracks, playlist, live, FairPlay

```swift
// Quality
session.setQualityAuto()
if let q = session.availableQualities.first {
    session.setQuality(q)
}

// Tracks
session.selectAudioTrack(id: audioId)
session.selectTextTrack(id: textId) // or "ext-\(subtitleId)"

// Playlist
let queue = PlaybackQueue(items: episodes, autoplayNext: true)
queue.session = session
session.playbackQueue = queue
await queue.play(at: 0)

// Live
await session.load(MediaSource(url: liveURL, isLive: true, dvrWindow: 3600))
await session.seekToLiveEdge()

// FairPlay (needs Apple FPS cert + your key server — not a mock)
session.contentKeyProvider = HTTPContentKeyProvider(
    configuration: .init(
        certificateURL: certURL,
        licenseURL: licenseURL,
        licenseBody: .jsonBase64SPC // or .rawSPC
    )
)
await session.load(MediaSource(url: drmURL, contentKeyAssetId: "asset-1"))

// Ads (host plugin)
session.adCueHandler = self
await session.load(MediaSource(url: vod, adCues: [AdCue(start: 30, duration: 15)]))
```

> **FairPlay:** there is no free public test stream. You need Apple’s [FairPlay Streaming](https://developer.apple.com/streaming/fps/) materials (certificate + test content + key server).

---

## Demo app

Interactive iOS demo (Play · Subs · Feed · Pro · Offline):

```bash
cd Examples/PulsePlayerDemo
xcodegen generate    # if needed
open PulsePlayerDemo.xcodeproj
# Run on iPhone Simulator
```

Details: [Examples/PulsePlayerDemo/README.md](Examples/PulsePlayerDemo/README.md)

---

## Development

```bash
swift test
./Scripts/check-line-count.sh   # fails if any .swift file > 400 lines
```

CI: GitHub Actions on `main` (tests + demo build).

Full integration notes: [Documentation/INTEGRATION.md](Documentation/INTEGRATION.md)

---

## Requirements

- Xcode with **Swift 6.2+**
- App deployment target **iOS / tvOS 17+**

---

## License

MIT — see [LICENSE](LICENSE).

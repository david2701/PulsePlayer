# PulsePlayer

[![CI](https://github.com/david2701/PulsePlayer/actions/workflows/ci.yml/badge.svg)](https://github.com/david2701/PulsePlayer/actions/workflows/ci.yml)
[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](Package.swift)
[![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20iPadOS%20%7C%20tvOS%2017%2B-black)](Package.swift)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](Package.swift)

**Production AVPlayer toolkit** for Apple platforms — one Swift Package, MIT licensed.

Long-lived session · typed state machine · real transport chrome · offline · FairPlay hooks · feed pool.

Not an FFmpeg media center. Not a toy `VideoPlayer` wrapper.

| | |
| --- | --- |
| **Product focus** | iOS 17+, iPadOS 17+, tvOS 17+ |
| **Swift** | 6.3+ · language mode 6 · strict concurrency |
| **Version** | `0.9.0` (`PulsePlayerInfo.version`) |
| **Install** | SPM only — no CocoaPods / Carthage |

---

## Why PulsePlayer

Shipping video on Apple usually means either raw `AVPlayer` glue or a heavy commercial SDK. Open-source options are often abandoned wrappers, GPL decoders, or incomplete UI.

PulsePlayer sits in the middle:

| You get | Without |
| --- | --- |
| Stable `PlayerSession` lifecycle | Recreating the player every SwiftUI render |
| Public state machine + `PlayerError` | Ad-hoc `Bool` flags |
| Chrome modes for feed / detail / custom | One fixed control bar |
| Offline, queue, live DVR, FairPlay provider | Starting from zero for each product feature |
| DI seams (`PlayerDependencies`) | Hard-wired system services |
| Unit tests + CI | “Works on my machine” |

**AVPlayer-first.** Hardware decode, AirPlay, PiP, and HLS stay on Apple’s stack.

---

## Install

**Xcode:** *File → Add Package Dependencies…*

```
https://github.com/david2701/PulsePlayer.git
```

**Package.swift:**

```swift
dependencies: [
    .package(url: "https://github.com/david2701/PulsePlayer.git", from: "0.9.0")
]
```

```swift
.target(name: "MyApp", dependencies: ["PulsePlayer"])
```

---

## Quick start

Own the session **outside** `body`. Never create `PlayerSession` inside a computed view tree.

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
            chrome: .full,          // .full | .lite | .minimal | .none
            theme: .pulse           // .default | .pulse | .cinema | custom
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
| **Playback** | HLS + progressive MP4 via `AVPlayer` |
| **Lifecycle** | Long-lived `PlayerSession` (`@MainActor`, `@Observable`) |
| **State** | Public state machine + recoverable `PlayerError` |
| **Chrome** | `.none` · `.minimal` · `.lite` · `.full` |
| **Transport** | Scrubber with fixed current / duration labels, ±10s, mute, volume menu |
| **Gestures** | Double-tap left −10s / right +10s |
| **Tracks** | Audio + text (HLS embedded and external SRT/VTT) |
| **Quality** | HLS ladder · **hard lock** (variant playlist) · soft peak bitrate fallback |
| **Theming** | `PlayerChromeTheme` (accent, scrims, scrub preview, auto-hide) |
| **Scrub preview** | Thumbnail while scrubbing (when asset supports image generation) |
| **Subtitles** | External SRT/VTT, offset, style, overlay |
| **System** | PiP, Now Playing, audio session, AirPlay picker |
| **Feeds** | `PlayerPool` acquire / prewarm / rebalance |
| **Offline** | Download, resume/retry, storage limit (**iOS**; catalog APIs elsewhere) |
| **Playlist** | `PlaybackQueue` + continue watching |
| **Live** | Seekable DVR window + seek to live edge |
| **DRM** | FairPlay via `ContentKeyProviding` / `HTTPContentKeyProvider` |
| **Ads** | `AdCue` markers + host `AdCueHandling` plugin |
| **QoE** | Events: first frame, rebuffer, bitrate, buffer |

---

## Chrome modes

| Mode | Best for | UI |
| --- | --- | --- |
| `.full` | Detail / offline / long-form | Scrubber + times + transport + overflow menu (tracks, quality, volume) |
| `.lite` | Inline cards | Scrubber + times + play + mute |
| `.minimal` | Vertical feed | Tap play/pause · double-tap seek · mute |
| `.none` | Custom UI | Video surface only |

```swift
PulsePlayerView(session: session, chrome: .full)
PulsePlayerView(session: session, chrome: .minimal)
```

Scrubber layout (full / lite) — times use fixed monospaced widths so labels do not jump:

```text
0:06  ————●————————  10:00
[▶] [−10] [+10]          [⋯] [AirPlay] [mute] [⛶]
```

---

## Architecture (mental model)

```text
MediaSource ──► PlayerSession ──► PlaybackControlling (AVPlayerEngine)
                    │                    │
                    │ events             │ layer / PiP / tracks
                    ▼                    ▼
              PlayerEventBus      PulsePlayerView + chrome
                    │
              Offline / Queue / Pool / FairPlay (optional)
```

- **`PlayerSession`** — host-facing API; `@MainActor` orchestration.
- **`PlaybackControlling`** — engine protocol (production: `AVPlayerEngine`; tests: mock).
- **`PlayerDependencies`** — clock, network path, audio session, Now Playing, logging.
- **UI is optional** — use headless session + your own chrome, or `PulsePlayerView`.

Files stay under **400 lines**; CI enforces it.

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

Use `PulsePlayerView(session: session, chrome: .minimal)` in cells.

### Subtitles

```swift
try session.addSubtitle(content: srt, id: "en", languageCode: "en", format: .srt)
try await session.addSubtitle(from: vttURL, languageCode: "es", label: "Español")

session.setSubtitleOffset(0.3)
session.applySubtitleStyle(.large)
session.selectSubtitle(id: nil) // hide
```

### Offline (iOS)

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

Offline **downloads** require iOS (`AVAssetDownloadURLSession`). tvOS/macOS compile the catalog APIs but `enqueue` throws.

### Quality, tracks, playlist, live, FairPlay

```swift
// Quality — hard lock reloads the media playlist when playlistURL is known
await session.setQualityAuto()
if let q = session.availableQualities.first {
    await session.setQuality(q)   // isQualityHardLocked == true when locked
}
// Soft-only: PlayerConfiguration(preferHardQualityLock: false)

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

// FairPlay (Apple FPS cert + your key server — real HTTP path, not a mock)
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

## Demo apps

### iOS — Play · Subs · Feed · Pro · Offline

```bash
cd Examples/PulsePlayerDemo
xcodegen generate
open PulsePlayerDemo.xcodeproj
```

Details: [Examples/PulsePlayerDemo/README.md](Examples/PulsePlayerDemo/README.md)

### tvOS — catalog + remote (0.9)

```bash
cd Examples/PulsePlayerTVDemo
xcodegen generate
open PulsePlayerTVDemo.xcodeproj
# Destination: Apple TV Simulator
```

Focusable catalog, `onPlayPauseCommand`, quality hard lock, cinema chrome.  
Details: [Examples/PulsePlayerTVDemo/README.md](Examples/PulsePlayerTVDemo/README.md)

Use Apple’s HLS samples (third-party progressive MP4s often fail on simulator).

---

## Development

```bash
swift test
./Scripts/check-line-count.sh   # fails if any .swift file > 400 lines
./Scripts/generate-docc.sh ./docs   # DocC HTML (Xcode / docc)
```

CI (GitHub Actions on `main`): `swift test` · line-count · **iOS demo** · **tvOS demo**.

- Integration: [Documentation/INTEGRATION.md](Documentation/INTEGRATION.md)
- Changelog: [CHANGELOG.md](CHANGELOG.md)
- DocC catalog: `Sources/PulsePlayer/PulsePlayer.docc`

---

## Requirements

- Xcode with **Swift 6.3+**
- App deployment target **iOS / tvOS 17+**
- Optional host entitlements: Background Audio, Picture in Picture

---

## Not included (yet)

Honest scope for integrators evaluating the package:

| Topic | Status |
| --- | --- |
| Native HLS interstitial ad parse | Host `AdCue` plugin only |
| Real AV integration tests | Mock engine today; planned 1.0 |
| FairPlay end-to-end without Apple FPS package | Not possible publicly |

---

## License

**MIT** — Copyright © 2026 **David Villegas**. Full text: [LICENSE](LICENSE).

A short permissive license: free use (including commercial), with credit via the copyright notice. No warranty; no liability for the author.

| | What it means |
| --- | --- |
| **Permissions** | Commercial use · Modification · Distribution · Private use |
| **Conditions** | Must keep the **license and copyright notice** in copies / substantial portions |
| **Limitations** | **No warranty** — software is provided “AS IS” · **No liability** — author is not responsible for damages from use |

### Attribution (your credit)

Users may ship PulsePlayer in apps and products without royalties.
They **must** retain the copyright and permission text from [LICENSE](LICENSE).

When practical, please also credit:

> PulsePlayer by David Villegas — https://github.com/david2701/PulsePlayer

Examples: app About screen, OSS credits list, or project README.

```swift
// Optional helper for host UI
Text(PulsePlayerInfo.attribution) // "PulsePlayer by David Villegas"
```

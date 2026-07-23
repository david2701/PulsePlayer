# PulsePlayer integration guide

## Install

```swift
.package(url: "https://github.com/david2701/PulsePlayer.git", from: "1.0.0")
```

## Minimal playback

```swift
@State private var session = PlayerSession(
    configuration: PlayerConfiguration(autoplay: true)
)

PulsePlayerView(session: session, chrome: .full)
    .task {
        await session.load(MediaSource(url: hlsURL, title: "Episode 1"))
    }
```

## Chrome modes

| Mode | When |
| --- | --- |
| `.full` | Detail / offline / long-form |
| `.lite` | Inline cards |
| `.minimal` | Vertical feed |
| `.none` | Fully custom UI |

Gestures: **double-tap left −10s / right +10s** (minimal & full/lite zones).

## Tracks & quality

```swift
session.selectAudioTrack(id: …)
session.selectTextTrack(id: …)          // or "ext-\(subtitleId)"
await session.setQualityAuto()
await session.setQuality(session.availableQualities[0])
// Hard lock reloads the HLS media playlist when `playlistURL` is known.
```

Chrome `.full` includes track + quality sheets.

## Theme

```swift
PulsePlayerView(session: session, chrome: .full, theme: .pulse)
// or custom PlayerChromeTheme(accent: .orange, showsScrubPreview: true)
```

## Offline

```swift
let item = try OfflineDownloadManager.shared.resumeOrEnqueue(
    sourceURL: hlsURL, id: "ep1", title: "E1"
)
// progress via manager.items / onChange
if let source = OfflineDownloadManager.shared.playableSource(id: "ep1") {
    await session.load(source)
}
try OfflineDownloadManager.shared.enforceStorageLimit()
```

## FairPlay

Requires Apple FPS certificate + key server. Use `HTTPContentKeyProvider` (real HTTP, not a mock):

```swift
session.contentKeyProvider = HTTPContentKeyProvider(
    configuration: .init(certificateURL: cert, licenseURL: license)
)
await session.load(MediaSource(url: encryptedHLS, contentKeyAssetId: "id"))
```

## Playlist

```swift
let queue = PlaybackQueue(items: episodes, autoplayNext: true)
queue.session = session
session.playbackQueue = queue
await queue.play(at: 0)
```

## Live

```swift
await session.load(MediaSource(url: liveURL, isLive: true, dvrWindow: 3600))
await session.seekToLiveEdge()
```

## Metrics & errors

```swift
let m = session.metricsSnapshot
// m.ttffMilliseconds, m.rebufferCount, m.qualitySwitchCount, m.errorCount

if let err = session.currentError {
    switch err.suggestedAction {
    case .retry: Task { await session.retry() }
    case .checkNetwork: break
    case .reauthenticate: break // reload with new headers
    case .changeSource, .recreateSession, .none: break
    }
}
```

## Host entitlements

- Background Modes → Audio (Now Playing / offline)
- Picture in Picture capability (optional)

Stability contract: [API_STABILITY.md](API_STABILITY.md)

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
// Soft cap is the safe default. Set preferHardQualityLock = true to opt in.
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

On iOS, forward background URL-session completion so the system can suspend the
app only after PulsePlayer has reconciled its catalog:

```swift
func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
) {
    OfflineDownloadManager.shared.handleBackgroundEvents(
        completionHandler: completionHandler
    )
}
```

`enqueue` accepts headers and cookies. Cookies are filtered by domain, path,
expiry, and secure transport. PulsePlayer restores outstanding background tasks
after relaunch and marks orphaned queued/downloading catalog entries as failed.

## FairPlay

Requires Apple FPS certificate + key server. Use `HTTPContentKeyProvider` (real HTTP, not a mock):

```swift
session.contentKeyProvider = HTTPContentKeyProvider(
    configuration: .init(certificateURL: cert, licenseURL: license)
)
await session.load(MediaSource(url: encryptedHLS, contentKeyAssetId: "id"))
```

For offline FairPlay, share one encrypted persistable store between playback
and the download manager:

```swift
let keyStore = try PersistableContentKeyFileStore()
session.persistableContentKeyStore = keyStore
OfflineDownloadManager.shared.contentKeyProvider = session.contentKeyProvider
OfflineDownloadManager.shared.persistableContentKeyStore = keyStore

try OfflineDownloadManager.shared.enqueue(
    sourceURL: encryptedHLS,
    id: "ep1",
    title: "Episode 1",
    contentKeyAssetId: "content-key-id"
)
```

Keys use opaque SHA-256 filenames, atomic writes, backup exclusion and Apple
file protection. Removing the offline item also removes its stored key.

## Playlist

```swift
let queue = PlaybackQueue(items: episodes, autoplayNext: true)
queue.session = session
session.playbackQueue = queue
await queue.play(at: 0)
```

## Live

```swift
session.updateConfiguration {
    $0.liveLatencyPolicy = .lowLatency
}
await session.load(MediaSource(url: liveURL, isLive: true, dvrWindow: 3600))
await session.seekToLiveEdge()
```

PulsePlayer configures AVFoundation's native live offset, preserves the offset
through rebuffering and applies a bounded catch-up rate only when measured
latency exceeds policy. LL-HLS packaging and CDN support remain origin concerns.

## Renewable credentials and fallback origins

Set `session.credentialProvider` before load. The provider is called for initial
credentials, proactive expiry refresh and 401/403 recovery. Reload preserves
time, selected tracks and play/pause intent.

```swift
session.credentialProvider = tokenProvider
await session.load(MediaSource(
    id: "ep1",
    url: primaryURL,
    fallbackURLs: [backupURL]
))
```

## Native interstitials and editorial UI

`MediaSource.interstitials` creates client-scheduled
`AVPlayerInterstitialEvent` entries. With an empty array, the same native
controller monitors and handles server-side HLS directives.

Use `editorialMarkers` for chapters and skippable intro/recap/credits ranges.
Set `session.nextContentProposal` or attach a `PlaybackQueue`; reaching credits
presents Up Next automatically. `PulsePlayerView` includes accessible controls
and defaults tvOS focus to **Play now**.

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

For an exportable signal stream, inject a `PlaybackTelemetrySink` through the
extended `PlayerDependencies` initializer. Stable events arrive via `record`;
production lifecycle/DRM/credential/interstitial/editorial/diagnostic events
arrive via `recordProduction`. All records carry session, playback and source
IDs. Configure `PlaybackPerformanceBudget` to turn QoE thresholds into events.

## Host entitlements

- Background Modes → Audio (Now Playing / offline)
- Picture in Picture capability (optional)

If the host already coordinates `AVAudioSession`, set
`PlayerConfiguration.managesAudioSession = false`. For PiP restoration, set
`session.pictureInPictureRestoreHandler` and return only after the host UI has
actually been restored.

Stability contract: [API_STABILITY.md](API_STABILITY.md)
Release evidence: [PRODUCTION_CERTIFICATION.md](PRODUCTION_CERTIFICATION.md)

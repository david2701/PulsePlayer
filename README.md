# PulsePlayer

[![CI](https://github.com/david2701/PulsePlayer/actions/workflows/ci.yml/badge.svg)](https://github.com/david2701/PulsePlayer/actions/workflows/ci.yml)
[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](Package.swift)
[![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20iPadOS%20%7C%20tvOS%2017%2B-black)](Package.swift)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](Package.swift)

**Production AVPlayer toolkit** for Apple platforms — one Swift Package, MIT licensed.

Long-lived session · typed state machine · renewable auth · native HLS interstitials ·
low-latency live · persistable FairPlay · editorial timeline · production telemetry.

Not an FFmpeg media center. Not a toy `VideoPlayer` wrapper.

| | |
| --- | --- |
| **Product focus** | iOS 17+, iPadOS 17+, tvOS 17+ |
| **Swift** | 6.3+ · language mode 6 · strict concurrency |
| **Version** | `1.0.0` (`PulsePlayerInfo.version`) |
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
    .package(url: "https://github.com/david2701/PulsePlayer.git", from: "1.0.0")
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

await session.load(
    MediaSource(url: url, headers: ["Authorization": "Bearer …"]),
    startAt: 30,                    // optional
    resumeContinueWatching: false
)
session.play()

let qoe = session.metricsSnapshot
// qoe.ttffMilliseconds, qoe.rebufferCount, qoe.qualitySwitchCount
// session.currentError?.suggestedAction → .retry / .checkNetwork / …
```

---

## Features

| Area | What you get |
| --- | --- |
| **Playback** | HLS + progressive MP4 via `AVPlayer` |
| **Lifecycle** | Long-lived `PlayerSession` + audio interruption, route, foreground/background and memory-pressure handling |
| **State** | Public state machine + recoverable `PlayerError` |
| **Chrome** | `.none` · `.minimal` · `.lite` · `.full` |
| **Transport** | Compact/cinematic adaptive chrome, scrubber, ±10s, playback speed, mute and volume |
| **Gestures** | Double-tap left −10s / right +10s |
| **Tracks** | Audio + text (HLS embedded and external SRT/VTT) |
| **Quality** | HLS ladder · soft ABR cap by default · optional variant-playlist hard lock |
| **Theming** | `PlayerChromeTheme` (accent, scrims, scrub preview, auto-hide) |
| **Scrub preview** | Thumbnail while scrubbing (when asset supports image generation) |
| **Subtitles** | External SRT/VTT, offset, style, overlay |
| **System** | PiP, Now Playing, audio session, AirPlay picker |
| **Feeds** | `PlayerPool` acquire / prewarm / rebalance |
| **Offline** | Download, background restore, resume/retry, storage limit and persistable FairPlay keys (**iOS**) |
| **Playlist** | `PlaybackQueue` + continue watching |
| **Live** | DVR + native live offset + measured LL-HLS catch-up policy |
| **DRM** | Online and persistable/offline FairPlay keys with renewal/reuse hooks |
| **Interstitials** | Server-side HLS interstitial monitoring + client native AVFoundation schedules and skip state |
| **Editorial** | Chapters, skip intro/recap/credits and Up Next with tvOS-first focus |
| **QoE** | Correlated telemetry, AV access/error diagnostics, TTFF/rebuffer/quality/auth/fallback metrics and budgets |
| **Recovery** | Renewable credentials, 401/403 reauthentication, retry and ordered alternate origins |

---

## Chrome modes

| Mode | Best for | UI |
| --- | --- | --- |
| `.full` | Detail / offline / long-form | Adaptive compact/center transport + timeline + overflow menu |
| `.lite` | Inline cards | Scrubber + times + play + mute |
| `.minimal` | Vertical feed | Tap play/pause · double-tap seek · mute |
| `.none` | Custom UI | Video surface only |

```swift
PulsePlayerView(session: session, chrome: .full)
PulsePlayerView(session: session, chrome: .minimal)
```

Scrubber layout (full / lite) — times use adaptive monospaced widths so labels stay stable without clipping:

```text
0:06  ————●————————  10:00
[▶] [−10] [+10]          [⋯] [AirPlay] [mute] [⛶]
```

On wide/full-screen surfaces, the primary controls move to a cinematic center
cluster while title, quality/live state and contextual playback metadata remain
separate from the timeline. tvOS uses this same chrome with focus-native
targets instead of a demo-specific implementation.

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
| Headers | Applied to `AVURLAsset` and PulsePlayer-owned HLS/subtitle/offline requests |
| HLS segments | Propagation remains controlled by AVFoundation and the origin server |
| Cookies | Filtered by domain, path, expiry, and secure transport before each owned request |
| Token refresh | `PlaybackCredentialProviding` refreshes before expiry and on 401/403 while preserving position, tracks and playback intent |

Secrets are redacted in logs and warning events.

### Production resilience & telemetry

```swift
actor TokenProvider: PlaybackCredentialProviding {
    func credentials(
        for source: MediaSource,
        reason: PlaybackCredentialRefreshReason
    ) async throws -> PlaybackCredentials {
        let token = try await authClient.token(for: source.id)
        return PlaybackCredentials(
            headers: ["Authorization": "Bearer \(token.value)"],
            refreshAfter: .seconds(token.secondsUntilRefresh)
        )
    }
}

actor TelemetrySink: PlaybackTelemetrySink {
    func record(_ record: PlaybackTelemetryRecord) async {
        await analytics.send(record)
    }

    func recordProduction(_ record: ProductionPlaybackTelemetryRecord) async {
        await analytics.send(record)
    }
}

var config = PlayerConfiguration.default
config.performanceBudget = PlaybackPerformanceBudget(
    maximumTTFFMilliseconds: 2_000,
    maximumRebufferCount: 2,
    maximumTotalRebufferMilliseconds: 5_000
)
config.pausesWhenBackgrounded = true
config.resumesPlaybackAfterForeground = false

let dependencies = PlayerDependencies(
    telemetry: TelemetrySink(),
    applicationLifecycle: SystemApplicationLifecycle.shared
)
let session = PlayerSession(configuration: config, dependencies: dependencies)
session.credentialProvider = TokenProvider()

await session.load(MediaSource(
    id: "episode-1",
    url: primaryOrigin,
    fallbackURLs: [secondaryOrigin]
))
```

Use `makeEventStream()` for the stable 1.0 event contract and
`makeProductionEventStream()` for credential, lifecycle, diagnostics,
interstitial, editorial, live-latency and performance-budget events. Every
telemetry record includes session, playback and source correlation identifiers.

### Picture in Picture & background

```swift
var config = PlayerConfiguration()
config.allowsPictureInPicture = true
config.updatesNowPlayingInfo = true
config.prefersBackgroundAudio = true

let session = PlayerSession(configuration: config)
// After PulsePlayerView attaches the layer:
session.startPictureInPicture()

session.pictureInPictureRestoreHandler = {
    // Restore/present the host playback screen, then report the real result.
    true
}
```

Host app: **Background Modes → Audio** (and PiP capability if needed).
Set `managesAudioSession = false` if the host already owns the shared
`AVAudioSession`.

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
try await session.addSubtitle(
    from: vttURL,
    languageCode: "es",
    label: "Español",
    headers: ["Authorization": "Bearer …"],
    cookies: cookies
)

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
Forward background session completion from the app delegate:

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

Protected downloads use an app-owned FPS provider plus the encrypted,
file-protected persistable key store:

```swift
let keyStore = try PersistableContentKeyFileStore()
let provider = HTTPContentKeyProvider(
    configuration: .init(certificateURL: certURL, licenseURL: licenseURL)
)

session.contentKeyProvider = provider
session.persistableContentKeyStore = keyStore
OfflineDownloadManager.shared.contentKeyProvider = provider
OfflineDownloadManager.shared.persistableContentKeyStore = keyStore

try OfflineDownloadManager.shared.enqueue(
    sourceURL: encryptedHLS,
    id: "protected-episode",
    title: "Protected episode",
    contentKeyAssetId: "asset-42"
)
```

### Quality, tracks, playlist, live, FairPlay

```swift
// Quality — soft ABR cap by default
await session.setQualityAuto()
if let q = session.availableQualities.first {
    await session.setQuality(q)
}
// Opt in only when dropping alternate master-playlist groups is acceptable:
// PlayerConfiguration(preferHardQualityLock: true)

// Tracks
session.selectAudioTrack(id: audioId)
session.selectTextTrack(id: textId) // or "ext-\(subtitleId)"

// Playlist
let queue = PlaybackQueue(items: episodes, autoplayNext: true)
queue.session = session
session.playbackQueue = queue
await queue.play(at: 0)

// LL-HLS: AVPlayer handles EXT-X-PART; PulsePlayer configures native offset,
// preserves it after stalls and uses bounded catch-up when latency drifts.
var liveConfig = PlayerConfiguration.default
liveConfig.liveLatencyPolicy = .lowLatency
session.updateConfiguration { $0.liveLatencyPolicy = .lowLatency }
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

### Native interstitials and editorial timeline

```swift
let source = MediaSource(
    id: "episode-1",
    url: vod,
    interstitials: [
        InterstitialDescriptor(
            id: "midroll-1",
            time: 600,
            assetURLs: [adHLS],
            skipAfter: 5
        ),
    ],
    editorialMarkers: [
        EditorialMarker(kind: .intro, title: "Intro", start: 0, end: 75),
        EditorialMarker(kind: .chapter, title: "Chapter 1", start: 75, end: 600),
        EditorialMarker(kind: .credits, title: "Credits", start: 2_700, end: 2_760),
    ]
)
session.nextContentProposal = NextContentProposal(
    id: "episode-2",
    sourceURL: nextEpisodeURL,
    title: "Episode 2",
    subtitle: "Next episode",
    previewImageURL: artworkURL,
    automaticAcceptanceInterval: 10
)
await session.load(source)
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

### tvOS — catalog + remote

```bash
cd Examples/PulsePlayerTVDemo
xcodegen generate
open PulsePlayerTVDemo.xcodeproj
# Destination: Apple TV Simulator
```

Focusable catalog, `onPlayPauseCommand`, quality selection, cinema chrome.
Details: [Examples/PulsePlayerTVDemo/README.md](Examples/PulsePlayerTVDemo/README.md)

Use Apple’s HLS samples (third-party progressive MP4s often fail on simulator).

---

## Development

```bash
swift test
./Scripts/check-coverage.sh 70 # tests + portable-core coverage gate
./Scripts/check-line-count.sh   # fails if any .swift file > 400 lines
./Scripts/generate-docc.sh ./docs   # symbol-linked DocC HTML
swift package diagnose-api-breaking-changes v1.0.0
PULSEPLAYER_RUN_NETWORK_TESTS=1 swift test --filter AVIntegrationTests
```

CI (GitHub Actions on `main`): tests + coverage · Thread Sanitizer · DocC
warnings-as-errors · line-count · **iOS demo** · **tvOS demo**. Real Apple-HLS
integration runs are explicit and scheduled, never silent passes.

- Integration: [Documentation/INTEGRATION.md](Documentation/INTEGRATION.md)
- API stability (1.0): [Documentation/API_STABILITY.md](Documentation/API_STABILITY.md)
- Production certification matrix: [Documentation/PRODUCTION_CERTIFICATION.md](Documentation/PRODUCTION_CERTIFICATION.md)
- Changelog: [CHANGELOG.md](CHANGELOG.md)
- Contributing: [CONTRIBUTING.md](CONTRIBUTING.md)
- Security policy: [SECURITY.md](SECURITY.md)
- Support: [SUPPORT.md](SUPPORT.md)
- Code of Conduct: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- DocC catalog: `Sources/PulsePlayer/PulsePlayer.docc`

---

## Requirements

- Xcode with **Swift 6.3+**
- App deployment target **iOS / tvOS 17+**
- Optional host entitlements: Background Audio, Picture in Picture

---

## Externally gated validation

Honest scope for integrators evaluating the package:

| Topic | Status |
| --- | --- |
| Public Apple-HLS integration | Opt-in locally and scheduled in CI; network failures fail the run |
| FairPlay end-to-end | Requires the host’s Apple FPS certificate, encrypted asset, license service and signed physical-device run |
| Store/device certification | Follow the versioned evidence matrix; no package can fabricate host entitlements, CDN behavior or FPS credentials |

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

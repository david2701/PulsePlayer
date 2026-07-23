# Production playback

Build resilient playback with renewable credentials, alternate origins,
correlated telemetry, persistable FairPlay, native HLS interstitials,
low-latency live policy, and editorial overlays.

## Credentials and origin recovery

Implement ``PlaybackCredentialProviding`` and assign it before loading. The
provider receives initial, expiry, manual, and reauthentication reasons.
PulsePlayer preserves position, selected tracks, and playback intent when it
refreshes credentials.

```swift
session.credentialProvider = tokenProvider
await session.load(MediaSource(
    id: "episode-1",
    url: primaryOrigin,
    fallbackURLs: [secondaryOrigin]
))
```

An alternate origin is selected only after the retry budget for the active
origin is exhausted.

## Telemetry and budgets

Inject a ``PlaybackTelemetrySink`` with the extended ``PlayerDependencies``
initializer. Stable ``PlayerEvent`` values and additive
``ProductionPlayerEvent`` values are exported separately, each with session,
playback, and source correlation identifiers.

```swift
var configuration = PlayerConfiguration.default
configuration.performanceBudget = PlaybackPerformanceBudget(
    maximumTTFFMilliseconds: 2_000,
    maximumRebufferCount: 2,
    maximumTotalRebufferMilliseconds: 5_000
)
```

AVFoundation access logs report observed and indicated bitrate, dropped frames,
stalls, and request counts. Error logs feed typed authentication recovery
without exporting secret URLs or headers.

## Low-latency live

```swift
session.updateConfiguration {
    $0.liveLatencyPolicy = .lowLatency
}
await session.load(MediaSource(url: liveURL, isLive: true))
```

The policy configures AVFoundation's native live offset, asks it to preserve the
offset after buffering, and applies a bounded catch-up rate only when measured
latency drifts beyond the threshold. The origin still needs valid LL-HLS
packaging and CDN support.

## Interstitials and editorial timeline

An empty interstitial schedule leaves intrinsic HLS directives in control.
Provide ``InterstitialDescriptor`` values for a client schedule:

```swift
let source = MediaSource(
    url: episodeURL,
    interstitials: [
        InterstitialDescriptor(
            time: 600,
            assetURLs: [advertURL],
            skipAfter: 5
        ),
    ],
    editorialMarkers: [
        EditorialMarker(kind: .intro, title: "Intro", start: 0, end: 70),
        EditorialMarker(kind: .credits, title: "Credits", start: 2_700, end: 2_760),
    ]
)
```

``PulsePlayerView`` displays eligible skip controls, chapter information, live
latency, and ``NextContentProposal``. On tvOS, Up Next forms a focus section and
focuses **Play now** by default.

## Persistable FairPlay

Share one ``PersistableContentKeyFileStore`` with the session and
``OfflineDownloadManager``. Configure the same ``ContentKeyProviding`` instance
for online playback and download acquisition. Offline catalog removal also
removes its persistable key.

Real FPS certification requires the host's Apple certificate, encrypted HLS,
license service, entitlements, lease policy, and a signed physical-device run.

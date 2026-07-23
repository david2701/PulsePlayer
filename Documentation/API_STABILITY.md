# API stability (1.0)

PulsePlayer **1.0** freezes the core integration surface under SemVer.

## Stable (safe for production hosts)

Breaking changes here require a **major** version bump.

| Area | Types / APIs |
| --- | --- |
| Session | `PlayerSession`, `load` / `play` / `pause` / `seek` / `retry` / `invalidate` |
| Source & config | `MediaSource`, `PlayerConfiguration`, `HTTPCookieValue` |
| State | `PlayerStatus`, `PlayerStateMachine`, `PlayerError`, `PlayerErrorAction` |
| Events | `PlayerEvent`, `makeEventStream()` |
| Metrics | `PlaybackMetrics`, `metrics` / `metricsSnapshot` |
| UI | `PulsePlayerView`, `PlayerChromeMode`, `PlayerChromeTheme`, `PulsePlayerControls` |
| Quality | `StreamQuality`, `setQuality` / `setQualityAuto`, `preferHardQualityLock` |
| Tracks / subs | `MediaTrackInfo`, subtitle add/select/style APIs |
| Pool / queue | `PlayerPool`, `PlaybackQueue` |
| Platform | PiP / Now Playing configuration flags |
| Metadata | `PulsePlayerInfo` |

## Stable with platform limits

| Area | Notes |
| --- | --- |
| Offline | `OfflineDownloadManager` — **download** requires **iOS**. Catalog APIs compile elsewhere. |
| FairPlay | `ContentKeyProviding`, `HTTPContentKeyProvider` — host must supply FPS materials. |
| tvOS UI | `PulsePlayerTVCommands`, `PulsePlayerTVControls` — living-room helpers. |

## Experimental / evolving (may change in minors)

Documented as best-effort; prefer isolating behind your own wrappers if you need stricter guarantees.

- Ad cue plugin surface (`AdCue`, `AdCueHandling`) — host-driven only
- Live DVR edge heuristics
- Scrub thumbnail availability (asset-dependent)
- Exact quality ladder parsing edge cases (master playlist variants)
- Internal engine protocol `PlaybackControlling` (package-level)

## Guarantees

1. **MIT** — Copyright David Villegas; preserve license/copyright notice.
2. **Swift 6.3+**, language mode 6, iOS/tvOS 17+.
3. **AVPlayer-first** — no FFmpeg in core.
4. Session is **long-lived**; do not recreate inside SwiftUI `body`.
5. Headers/cookies apply to the **initial asset request** (AVFoundation limitation).

## Migration from 0.x

- Prefer `from: "1.0.0"` in SPM.
- `setQuality` / `setQualityAuto` are `async` (since 0.8).
- Use `metricsSnapshot` instead of parsing only `PlayerEvent.metrics`.
- Offline downloads: expect failure on non-iOS when calling `enqueue`.

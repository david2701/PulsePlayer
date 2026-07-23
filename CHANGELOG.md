# Changelog

All notable changes to PulsePlayer are documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [SemVer](https://semver.org/).

## [Unreleased]

### Added

- Renewable playback credentials with proactive/manual refresh, 401/403
  reauthentication and position/track/intent-preserving reload
- Ordered origin fallback after retry exhaustion
- Audio interruption, route-change, media-services and app
  background/foreground/memory-pressure lifecycle handling
- Correlated production telemetry, AV access/error diagnostics and configurable
  TTFF/rebuffer performance budgets
- Persistable FairPlay acquisition, reuse, renewal, file-protected storage,
  restored background-download loaders and key deletion with offline assets
- Native server/client HLS interstitial monitoring, client schedules and
  eligible skip controls
- Native live time offset plus measured bounded LL-HLS catch-up
- Editorial chapters, skip intro/recap/credits and Up Next with accessible,
  focus-correct tvOS presentation
- CI gate for breaking public API changes against `v1.0.0`

### Changed

- Full chrome is now a single adaptive, cinematic implementation across iOS
  and tvOS, with compact embedding, center transport on large surfaces,
  playback-speed controls, live-aware time labels and production metadata
- iOS and tvOS demos now exercise the package UI directly; the Pro demo exposes
  fallback, telemetry, performance-budget, native interstitial and editorial
  state instead of hiding production features behind configuration
- Manual quality selection now defaults to a soft ABR cap; hard variant-playlist
  locking is explicit so alternate audio/subtitle groups are not dropped
- Position and buffer events are coalesced to reduce avoidable UI/event pressure
- Now Playing ownership, audio-session activation, and pool prewarm are coordinated
  across long-lived/multiple sessions
- Demo projects and documentation now track the stable `1.0.0` package contract

### Fixed

- Session reset/invalidation now cancel work, clear the real player item, detach
  platform resources, and remain safely reusable/idempotent
- Startup timeout cancels and clears the pending asset; overlapping loads and seeks
  are generation-safe with latest-wins behavior
- PiP layer attachment/restoration, Now Playing metadata cleanup, and playback-rate
  reporting
- Authenticated HLS parsing, external subtitles, and offline downloads now preserve
  scoped headers/cookies without leaking secrets into logs
- Offline catalogs are transactional/versioned, restore background tasks, validate
  local files, propagate storage failures, and account for nested package contents
- Subtitle lookup is indexed and handles overlapping cues without linear scans
- Fullscreen configuration, tvOS focus/remote handling, 44-point controls,
  localization, Dynamic Type, VoiceOver actions, Reduce Motion, and transparency

### Security

- URL/header/token logging is privacy-redacted; cookie domain/path/expiry/secure
  scope is enforced for PulsePlayer-owned requests

### Quality

- 100+ deterministic tests with an enforced portable-core coverage floor
- Thread Sanitizer, DocC warning validation, warnings-as-errors iOS/tvOS builds,
  and explicit scheduled network integration tests

## [1.0.0] - 2026-07-23

### Added

- **`PlaybackMetrics` / `metricsSnapshot`** — TTFF, rebuffer count/duration,
  quality switches, bitrates, error count
- **`PlayerError.suggestedAction`** — host recovery guidance
  (`.retry`, `.checkNetwork`, `.reauthenticate`, …)
- **`load(_:startAt:resumeContinueWatching:)`** — resume helpers
- Real **AV integration tests** (Apple sample HLS; explicit opt-in)
- Unit tests for metrics, error actions, concurrent quality lock
- **`Documentation/API_STABILITY.md`** — 1.0 freeze surface

### Changed

- Quality hard-lock coalesces concurrent `setQuality` (latest wins)
- Quality reload no longer emits a full `loadStarted` lifecycle spam
- Version **1.0.0** — core integration API considered stable under SemVer

## [0.9.0] - 2026-07-22

### Added

- **tvOS demo** (`Examples/PulsePlayerTVDemo`) — focusable catalog, full-screen
  player, `onPlayPauseCommand`, quality menu, cinema layout
- **DocC** articles: Getting Started, Chrome & Themes, Quality Lock
- `Scripts/generate-docc.sh` for static DocC HTML
- CI job **build tvOS demo**

### Changed

- Version `0.9.0`
- `PulsePlayerTVControls` larger hit targets for remote focus
- Offline downloads scoped to **iOS only** (`AVAssetDownloadURLSession` unavailable on tvOS)
- tvOS chrome uses `ProgressView` instead of unavailable `Slider`
- Fullscreen container skips `statusBarHidden` on tvOS

## [0.8.0] - 2026-07-22

### Added

- **Hard quality lock**: manual quality reloads the HLS media playlist when
  `StreamQuality.playlistURL` is known (`preferHardQualityLock`, default `true`).
  Soft peak-bitrate / max-resolution caps still apply as fallback.
- `PlayerChromeTheme` with presets `.default`, `.pulse`, `.cinema`
- Scrub preview polish: accent border + time label under thumbnail
- `MediaSource.replacingURL(_:)`, `StreamQuality.playlistURL` / `supportsHardLock`
- `PulsePlayerInfo.author` / `attribution` (from 0.7.x docs pass)

### Changed

- `setQuality` / `setQualityAuto` are `async` (await hard lock reload)
- HLS master parser resolves relative variant URIs and stable quality ids
- README / MIT attribution for David Villegas
- CI: Swift **6.3** tools, `macos-26` + Xcode 26.6

### Fixed

- CI failure from Swift tools 6.2/6.1 mismatch on default runner Xcode

## [0.7.2] - 2026-07-22

### Fixed

- Scrubber current / duration labels with fixed monospaced widths
- Full chrome clipping on iPhone
- README rewrite for integrators

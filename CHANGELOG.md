# Changelog

All notable changes to PulsePlayer are documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [SemVer](https://semver.org/).

## [Unreleased]

### Planned (0.9)

- Dedicated tvOS demo app (focus / Siri Remote)
- DocC catalog site
- GitHub release tags

### Planned (1.0)

- Hardening pass
- Real AVFoundation integration tests (device / simulator where stable)
- Stable public API freeze notes

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

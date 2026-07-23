# Production certification

PulsePlayer's automated gates validate portable logic, strict concurrency,
API compatibility, documentation, and simulator builds. A production host must
also validate the combinations that depend on its CDN, entitlements, account,
FairPlay deployment, physical hardware, and app lifecycle.

Do not mark a release certified without attaching evidence for every applicable
row below.

## Automated release gates

Run from the package root:

```bash
swift test --parallel
swift test --sanitize=thread
./Scripts/check-coverage.sh 70
./Scripts/check-line-count.sh
./Scripts/generate-docc.sh ./docs
swift package diagnose-api-breaking-changes v1.0.0
```

Build both demos with `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`. CI performs the same
checks and scheduled Apple-HLS network integration.

## Device and OS matrix

Record device model, OS build, app commit, package version, asset ID, CDN
environment, network profile, start/end timestamp, result, and evidence link.

| Platform | Minimum evidence |
| --- | --- |
| iPhone | Oldest supported iOS, current iOS, current iOS on a low-memory device |
| iPad | Current iPadOS in portrait, landscape, Split View and external display if supported |
| Apple TV | Oldest supported tvOS and current tvOS with Siri Remote |
| External routes | AirPlay receiver and one Bluetooth audio route used by the host |

## Playback and lifecycle

- Cold load, warm load, play/pause, seeks, end, loop, track changes, quality
  changes, PiP start/restore, Now Playing commands and external playback.
- Background/foreground with background audio enabled and disabled.
- Audio interruption begin/end with and without system resume permission.
- Headphone/Bluetooth removal pauses; route replacement continues according to
  host policy.
- Media services loss/reset recovers configuration and playback intent.
- Memory warning cancels thumbnail work without invalidating the session.
- Network offline during startup, mid-playback, recovery, retry exhaustion and
  alternate-origin failover.

## Authentication and privacy

- Initial credential acquisition, proactive expiry refresh, manual refresh,
  401 and 403 recovery, provider failure, cancellation and session invalidation.
- Confirm refresh preserves playback time, selected audio/text tracks and
  play/pause intent.
- Inspect exported logs and analytics: no bearer token, cookie, signed query,
  certificate body, SPC, CKC or complete private URL.
- Confirm all telemetry records include session, playback and source
  correlation IDs and the backend handles duplicates/out-of-order delivery.

## Live and interstitials

- LL-HLS stream with parts at healthy, constrained and recovered bandwidth.
- Validate configured target latency, bounded catch-up, stall recovery, DVR
  seeking, live-edge action, AirPlay, foreground recovery and clock drift.
- Server-side HLS interstitials: schedule updates, transition, restrictions,
  skip eligibility, completion, failure and return to primary content.
- Client schedule: multiple assets, coincident events, playout limit, resumption
  offset, one-time behavior and localized skip label.

## Editorial and tvOS

- Chapters update at boundaries; intro, recap and credits skip to exact end.
- Up Next derived from a queue and explicitly supplied proposals.
- Accept, dismiss and automatic countdown cancellation.
- Siri Remote play/pause and Back behavior; predictable initial focus, focus
  restoration and no focus trap in Up Next.
- VoiceOver labels/actions, Full Keyboard Access where applicable, Reduce Motion,
  Reduce Transparency, increased contrast and Dynamic Type on iOS.

## FairPlay online and offline

Requires the host's FPS package and signed physical devices.

- Certificate acquisition, SPC/CKC exchange, invalid certificate, invalid CKC,
  expired lease, renewal, server 401/403/429/5xx, timeout and offline startup.
- Persistable key acquisition and reuse after relaunch and device reboot.
- Background protected download followed by process termination and restoration.
- Playback in airplane mode after download; audio/subtitle selections included
  by the download configuration.
- Removal deletes media and its key. Key files use opaque names, backup exclusion
  and Apple file protection.
- Validate lease/expiration rules with the content owner. PulsePlayer must not
  extend rights beyond the CKC policy.

## Performance evidence

- Capture Instruments/ETTrace on representative devices for cold start, first
  frame, 10-minute playback, repeated seek, quality switching and a 30-minute
  feed session.
- Record TTFF p50/p95/p99, rebuffer ratio, dropped frames, peak memory, steady
  memory, CPU, energy and thermal state.
- Configure `PlaybackPerformanceBudget` from product SLOs and fail the host's
  release dashboard when violations regress.
- Capture a memgraph after repeated present/dismiss and verify sessions, player
  items, observers, content-key loaders, download delegates and thumbnails are
  released.

## Release sign-off

The release owner signs only after:

1. Automated gates are green for the exact commit.
2. Every applicable device-matrix row has current evidence.
3. FairPlay/CDN owners approve DRM and live/interstitial results.
4. Accessibility and privacy evidence is attached.
5. Known limitations have an owner, severity, mitigation and release decision.

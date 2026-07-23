# Quality lock

How manual quality selection works in PulsePlayer.

## Ladder

After loading an HLS master playlist, ``PlayerSession`` parses variants via ``HLSMasterParser`` into ``StreamQuality`` values (bandwidth, resolution, playlist URL).

## Hard lock (opt-in)

When `PlayerConfiguration.preferHardQualityLock` is `true` and the selected quality has a `playlistURL`, PulsePlayer **reloads that media playlist** so ABR cannot jump away:

```swift
var config = PlayerConfiguration()
config.preferHardQualityLock = true

if let q = session.availableQualities.first {
    await session.setQuality(q)
}
// session.isQualityHardLocked == true
await session.setQualityAuto() // reloads master, unlocks
```

Playback position and play/pause intent are preserved across the reload.

Hard lock can remove alternate audio, subtitle, or timed-metadata groups declared
only by the master playlist. Enable it only when that tradeoff is acceptable.

## Soft cap (default)

If the variant URL is unknown, or hard lock is disabled:

```swift
var config = PlayerConfiguration()
config.preferHardQualityLock = false // default
```

selection only applies `preferredPeakBitRate` / `preferredMaximumResolution` (ABR soft ceiling).

## UI

Chrome `.full` exposes a quality sheet. Labels reflect whether hard lock is enabled
for variants that support it.

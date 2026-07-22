# Quality lock

How manual quality selection works in PulsePlayer.

## Ladder

After loading an HLS master playlist, ``PlayerSession`` parses variants via ``HLSMasterParser`` into ``StreamQuality`` values (bandwidth, resolution, playlist URL).

## Hard lock (default)

When `PlayerConfiguration.preferHardQualityLock` is `true` (default) and the selected quality has a `playlistURL`, PulsePlayer **reloads that media playlist** so ABR cannot jump away:

```swift
if let q = session.availableQualities.first {
    await session.setQuality(q)
}
// session.isQualityHardLocked == true
await session.setQualityAuto() // reloads master, unlocks
```

Playback position and play/pause intent are preserved across the reload.

## Soft cap (fallback)

If the variant URL is unknown, or hard lock is disabled:

```swift
var config = PlayerConfiguration()
config.preferHardQualityLock = false
```

selection only applies `preferredPeakBitRate` / `preferredMaximumResolution` (ABR soft ceiling).

## UI

Chrome `.full` exposes a quality sheet. Labels show **Hard lock** vs **Soft cap** per variant.

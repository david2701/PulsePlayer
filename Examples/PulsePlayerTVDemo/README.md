# PulsePlayerTVDemo

Living-room sample for **tvOS 17+** using local PulsePlayer.

## Features

- Horizontal catalog with focus rings (Siri Remote)
- The package's shared adaptive `.full` chrome (no demo-only transport)
- Siri Remote play/pause, focused center transport and directional seek
- Quality, tracks, speed and volume menu
- Ordered origin fallbacks and production performance budgets
- Native client interstitial with eligible skip
- Chapters, skip intro/credits and Up Next
- Pulse theme, content-first layout

## Run

```bash
cd Examples/PulsePlayerTVDemo
xcodegen generate
open PulsePlayerTVDemo.xcodeproj
# Destination: Apple TV Simulator
```

Or:

```bash
xcodegen generate
xcodebuild \
  -project PulsePlayerTVDemo.xcodeproj \
  -scheme PulsePlayerTVDemo \
  -destination 'platform=tvOS Simulator,name=Apple TV' \
  build CODE_SIGNING_ALLOWED=NO
```

## Remote

| Input | Action |
| --- | --- |
| Play/Pause | Toggle playback |
| Select on center transport | Skip ±10s / play-pause |
| Left/right on timeline | Seek ±10s |
| Menu | System back / exit |
| Focus + Select on catalog | Open stream |

Needs network for Apple sample HLS.

# PulsePlayerTVDemo

Living-room sample for **tvOS 17+** using local PulsePlayer.

## Features

- Horizontal catalog with focus rings (Siri Remote)
- Full-screen player + `onPlayPauseCommand`
- Focusable transport (`PulsePlayerTVControls`)
- Quality menu (hard lock when variants are known)
- Cinema theme, content-first layout

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
| Select on transport | Skip ±10s / play-pause |
| Menu | System back / exit |
| Focus + Select on catalog | Open stream |

Needs network for Apple sample HLS.

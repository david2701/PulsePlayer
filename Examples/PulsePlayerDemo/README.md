# PulsePlayerDemo

iOS app that exercises the local `PulsePlayer` package.

## Tabs

1. **Play** — HLS (BipBop), seek, PiP, status / first-frame
2. **Subs** — Big Buck Bunny + in-memory SRT, offset slider
3. **Feed** — vertical paging + `PlayerPool` prewarm
4. **Offline** — enqueue HLS download (simulator/device)

## Run

```bash
cd Examples/PulsePlayerDemo
xcodegen generate          # requires xcodegen
open PulsePlayerDemo.xcodeproj
# or:
xcodebuild -project PulsePlayerDemo.xcodeproj -scheme PulsePlayerDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl install booted DerivedData/Build/Products/Debug-iphonesimulator/PulsePlayerDemo.app
xcrun simctl launch booted com.pulseplayer.demo
```

Needs network for sample streams.

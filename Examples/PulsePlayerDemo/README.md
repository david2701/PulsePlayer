# PulsePlayerDemo

iOS app that exercises the local `PulsePlayer` package.

## Tabs

1. **Play** — HLS, chrome modes, seek, PiP
2. **Subs** — external SRT, style, offset
3. **Feed** — vertical paging + `PlayerPool` + minimal chrome
4. **Pro** — queue, native interstitial, editorial/Up Next, origin fallback,
   quality, production event cockpit, performance budgets and FairPlay HTTP
   wiring
5. **Offline** — download / retry / play local, plus real persistable FairPlay
   wiring for protected offline assets

## FairPlay: can you test without a mock?

**Short answer: not fully without Apple materials.**

| What you need | Free public? |
| --- | --- |
| Encrypted FairPlay HLS | No (Apple FPS Test Streams zip requires SDK access) |
| Application certificate | No — [Apple FPS](https://developer.apple.com/streaming/fps/) deployment package |
| Key server (SPC→CKC) | You build KSM from **FairPlay Streaming Server SDK**, or use a multi-DRM vendor |

PulsePlayer ships **`HTTPContentKeyProvider`**: real certificate download + license POST (not a fake CKC).  
In **Pro** tab, paste your cert URL, license URL, and encrypted asset URL.

Steps for real end-to-end:

1. Request FPS access (Apple Developer → FairPlay Streaming)
2. Download **FairPlay Streaming Server SDK** + **Test Streams**
3. Run sample KSM / vendor key server
4. Point Pro tab fields at those endpoints

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

The embedded player uses the compact full chrome. Presenting it full-screen
automatically switches to the cinematic center transport; no demo-only player
UI is involved.

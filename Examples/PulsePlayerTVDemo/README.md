# PulsePlayer tvOS Demo (0.9)

Scaffold for a living-room sample app.

## Status

- Package already compiles for **tvOS 17+**
- API helpers: `PulsePlayerTVCommands`, `PulsePlayerTVControls`
- Full XcodeGen target + focus polish ships in **0.9.0**

## Planned layout

```text
Examples/PulsePlayerTVDemo/
  project.yml
  PulsePlayerTVDemo/
    App.swift
    RootView.swift   // focusable transport + full chrome
```

Until 0.9, use the iOS demo (`Examples/PulsePlayerDemo`) and exercise tvOS via SPM dependency in a blank tvOS app:

```swift
import PulsePlayer

struct ContentView: View {
    @State private var session = PlayerSession(
        configuration: PlayerConfiguration(autoplay: true)
    )

    var body: some View {
        PulsePlayerView(session: session, chrome: .full, theme: .cinema)
            .task {
                await session.load(MediaSource(
                    url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8")!,
                    title: "BipBop"
                ))
            }
            .focusable()
    }
}
```

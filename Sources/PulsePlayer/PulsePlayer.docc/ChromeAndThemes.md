# Chrome and themes

Built-in transport density and visual tokens for ``PulsePlayerView``.

## Chrome modes

| Mode | Use when |
| --- | --- |
| ``PlayerChromeMode/full`` | Detail / long-form |
| ``PlayerChromeMode/lite`` | Inline cards |
| ``PlayerChromeMode/minimal`` | Vertical feed |
| ``PlayerChromeMode/none`` | Custom UI (tvOS demo uses this + remote chrome) |

```swift
PulsePlayerView(session: session, chrome: .minimal)
```

## Themes

``PlayerChromeTheme`` controls accent color, scrim opacity, scrub preview, bitrate chip, and auto-hide delay.

```swift
PulsePlayerView(
    session: session,
    chrome: .full,
    theme: .pulse   // or .cinema, .default, or custom
)
```

Presets:

- `.default` — neutral white accent
- `.pulse` — cyan accent, softer scrims
- `.cinema` — darker, no bitrate chip, faster auto-hide

## Scrub preview

While scrubbing (full / lite), ``PlayerSession/scrubPreviewImage`` shows a thumbnail when the asset supports image generation. Disable with:

```swift
var theme = PlayerChromeTheme.default
theme.showsScrubPreview = false
```

## tvOS

Prefer ``PlayerChromeMode/none`` plus ``PulsePlayerTVControls`` and `onPlayPauseCommand` for living-room focus. See `Examples/PulsePlayerTVDemo`.

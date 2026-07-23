# Chrome and themes

Built-in transport density and visual tokens for ``PulsePlayerView``.

## Chrome modes

| Mode | Use when |
| --- | --- |
| ``PlayerChromeMode/full`` | Detail / long-form |
| ``PlayerChromeMode/lite`` | Inline cards |
| ``PlayerChromeMode/minimal`` | Vertical feed |
| ``PlayerChromeMode/none`` | A host-owned custom UI |

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

## Adaptive full chrome

The full chrome has two layouts without requiring host breakpoints:

- Embedded/compact players keep transport actions in the bottom bar so the
  content is not covered.
- Wide or full-screen players use a cinematic center transport, keep metadata
  and live/quality state at the top, and reserve the bottom surface for the
  timeline and secondary actions.

The overflow menu exposes audio/subtitles, quality, playback speed, mute and
volume. Live playback replaces VOD duration labels with live-edge context.
Interstitial, editorial, live-latency and Up Next overlays share the same
visual hierarchy.

## Scrub preview

While scrubbing (full / lite), ``PlayerSession/scrubPreviewImage`` shows a thumbnail when the asset supports image generation. Disable with:

```swift
var theme = PlayerChromeTheme.default
theme.showsScrubPreview = false
```

## tvOS

Use ``PlayerChromeMode/full`` for the same production chrome on iOS and tvOS.
On tvOS it supplies larger focus targets, default focus on play/pause, Siri
Remote play/pause and directional seeking on the timeline. Use
`PulsePlayerTVControls` only when building a fully host-owned chrome with
``PlayerChromeMode/none``.

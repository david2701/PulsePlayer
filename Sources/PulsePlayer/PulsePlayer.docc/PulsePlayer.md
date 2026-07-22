# ``PulsePlayer``

Production AVPlayer toolkit for Apple platforms — Swift Package (MIT).

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

## Overview

PulsePlayer is a long-lived, testable playback stack on top of `AVPlayer`:

- ``PlayerSession`` — orchestration, state machine, events
- ``PulsePlayerView`` — optional SwiftUI surface + chrome
- Offline, FairPlay hooks, feed ``PlayerPool``, quality hard lock

## Topics

### Essentials

- <doc:GettingStarted>
- ``PlayerSession``
- ``MediaSource``
- ``PlayerConfiguration``
- ``PlayerEvent``
- ``PlayerError``

### Chrome & UI

- <doc:ChromeAndThemes>
- ``PulsePlayerView``
- ``PlayerChromeMode``
- ``PlayerChromeTheme``
- ``PulsePlayerControls``
- ``PulsePlayerTVControls``

### Quality & tracks

- <doc:QualityLock>
- ``StreamQuality``
- ``MediaTrackInfo``
- ``HLSMasterParser``

### Offline & DRM

- ``OfflineDownloadManager``
- ``ContentKeyProviding``
- ``HTTPContentKeyProvider``

### Feeds & playlist

- ``PlayerPool``
- ``PlaybackQueue``
- ``ContinueWatchingStore``

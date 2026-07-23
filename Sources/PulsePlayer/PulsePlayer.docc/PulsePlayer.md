# ``PulsePlayer``

Production AVPlayer toolkit for Apple platforms — Swift Package (MIT).

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

## Overview

PulsePlayer is a long-lived, testable playback stack on top of `AVPlayer`:

- ``PlayerSession`` — orchestration, state machine, events
- ``PulsePlayerView`` — optional SwiftUI surface + chrome
- Offline, FairPlay hooks, feed ``PlayerPool``, safe ABR caps and optional quality hard lock

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:ProductionPlayback>
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

The shared full chrome is focus-native on tvOS. The optional tvOS-only
`PulsePlayerTVControls` surface for fully custom hosts is documented in
<doc:ChromeAndThemes>; it is not symbol-linked in this iOS-generated catalog.

### Quality & tracks

- <doc:QualityLock>
- ``StreamQuality``
- ``MediaTrackInfo``
- ``HLSMasterParser``

### Offline & DRM

- ``OfflineDownloadManager``
- ``ContentKeyProviding``
- ``HTTPContentKeyProvider``
- ``PersistableContentKeyStoring``
- ``PersistableContentKeyFileStore``

### Feeds & playlist

- ``PlayerPool``
- ``PlaybackQueue``
- ``ContinueWatchingStore``

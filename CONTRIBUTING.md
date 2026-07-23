# Contributing to PulsePlayer

Thanks for helping improve PulsePlayer. Changes should preserve its focus: a
high-quality, AVPlayer-first package for iOS, iPadOS, and tvOS.

## Before opening a change

- Search existing issues and pull requests.
- Use a discussion or issue for API-breaking changes before implementation.
- Keep unrelated refactors out of a focused fix.
- Never commit media credentials, bearer tokens, cookies, FairPlay material, or
  private stream URLs.

## Local validation

PulsePlayer requires Xcode with Swift 6.3 or newer.

```bash
swift test --parallel
./Scripts/check-coverage.sh 70
./Scripts/check-line-count.sh
./Scripts/generate-docc.sh /tmp/PulsePlayerDocs
```

Build both examples with warnings treated as errors:

```bash
xcodebuild \
  -project Examples/PulsePlayerDemo/PulsePlayerDemo.xcodeproj \
  -scheme PulsePlayerDemo \
  -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES

xcodebuild \
  -project Examples/PulsePlayerTVDemo/PulsePlayerTVDemo.xcodeproj \
  -scheme PulsePlayerTVDemo \
  -destination 'generic/platform=tvOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
```

Network integration is explicit:

```bash
PULSEPLAYER_RUN_NETWORK_TESTS=1 swift test --filter AVIntegrationTests
```

## Pull requests

- Add a regression test for behavioral fixes.
- Document public API or integration-contract changes.
- Update `CHANGELOG.md` under `Unreleased`.
- Preserve Swift 6 strict-concurrency correctness and MainActor ownership.
- Keep source files below the repository line-count limit.
- Explain device-only validation when PiP, FairPlay, background downloads, or
  audio interruptions cannot be fully proven on Simulator.

By contributing, you agree that your contribution is licensed under the
repository's MIT license.

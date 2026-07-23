#!/usr/bin/env bash
# Enforce coverage for portable, deterministic player logic.
# AVFoundation delegates, Apple platform controllers, and SwiftUI are validated
# separately by iOS/tvOS builds because macOS SwiftPM cannot execute those paths.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MINIMUM="${1:-70}"
swift test --enable-code-coverage --parallel

TEST_BINARY="$(find .build -type f \
  -path '*/debug/PulsePlayerPackageTests.xctest/Contents/MacOS/PulsePlayerPackageTests' \
  -print -quit)"
PROFILE="$(find .build -type f -path '*/debug/codecov/default.profdata' -print -quit)"

if [[ -z "$TEST_BINARY" || -z "$PROFILE" ]]; then
  echo "error: Swift coverage artifacts were not found." >&2
  exit 1
fi

IGNORE='Tests/|\.build/|resource_bundle_accessor\.swift'
IGNORE+='|Core/AVPlayerEngine|Core/AssetFactory|Core/FairPlayContentKeyLoader'
IGNORE+='|Core/HTTPContentKeyProvider|Core/ThumbnailGenerator'
IGNORE+='|Core/PlayerSession\+(Platform|FairPlay|Tracks|UIBridge)\.swift'
IGNORE+='|Offline/OfflineDownloadManager|Platform/|UI/'

REPORT="$(xcrun llvm-cov report "$TEST_BINARY" \
  -instr-profile "$PROFILE" \
  -ignore-filename-regex="$IGNORE")"
echo "$REPORT"

COVERAGE="$(awk '/^TOTAL/{gsub("%", "", $10); print $10}' <<<"$REPORT")"
if [[ -z "$COVERAGE" ]]; then
  echo "error: Could not parse line coverage." >&2
  exit 1
fi

if ! awk -v coverage="$COVERAGE" -v minimum="$MINIMUM" \
  'BEGIN { exit(coverage + 0 >= minimum + 0 ? 0 : 1) }'
then
  echo "error: Portable-core line coverage ${COVERAGE}% is below ${MINIMUM}%." >&2
  exit 1
fi

echo "Portable-core line coverage ${COVERAGE}% (minimum ${MINIMUM}%)."

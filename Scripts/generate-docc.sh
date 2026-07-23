#!/usr/bin/env bash
# Generate DocC HTML for PulsePlayer (requires Xcode / docc).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="${1:-./docs}"
DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"

echo "Building symbol graph + DocC → $OUT"
swift package --allow-writing-to-directory "$OUT" generate-documentation \
  --target PulsePlayer \
  --disable-indexing \
  --transform-for-static-hosting \
  --hosting-base-path PulsePlayer \
  --output-path "$OUT" \
  2>/dev/null || {
  # Fallback: xcodebuild docbuild when SPM plugin unavailable
  echo "SPM generate-documentation unavailable; trying docc convert of catalog only..."
  DOCC="$(xcrun --find docc)"
  "$DOCC" convert \
    "Sources/PulsePlayer/PulsePlayer.docc" \
    --fallback-display-name PulsePlayer \
    --fallback-bundle-identifier com.pulseplayer.docs \
    --fallback-bundle-version 1.0.0 \
    --output-path "$OUT" \
    --transform-for-static-hosting \
    --hosting-base-path PulsePlayer
}

echo "Done: $OUT"

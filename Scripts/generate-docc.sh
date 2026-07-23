#!/usr/bin/env bash
# Generate and validate DocC HTML for PulsePlayer (requires Xcode).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="${1:-./docs}"
DERIVED="$(mktemp -d "${TMPDIR:-/tmp}/PulsePlayerDocBuild.XXXXXX")"
LOG="$DERIVED/docbuild.log"
trap 'rm -rf "$DERIVED"' EXIT

echo "Building symbol graph + DocC → $OUT"
set +e
xcodebuild docbuild \
  -quiet \
  -scheme PulsePlayer \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  DOCC_TREAT_WARNINGS_AS_ERRORS=YES 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}
set -e

if (( status != 0 )); then
  exit "$status"
fi

if grep -Eiq '(^|: )[Ww]arning:' "$LOG"; then
  echo "error: documentation build emitted warnings." >&2
  exit 1
fi

ARCHIVE="$(find "$DERIVED/Build/Products" -name 'PulsePlayer.doccarchive' -print -quit)"
if [[ -z "$ARCHIVE" || ! -f "$ARCHIVE/index.html" ]]; then
  echo "error: PulsePlayer.doccarchive was not produced." >&2
  exit 1
fi

mkdir -p "$OUT"
ditto "$ARCHIVE" "$OUT"

echo "Done: $OUT"

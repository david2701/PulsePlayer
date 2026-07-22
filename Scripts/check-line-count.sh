#!/usr/bin/env bash
# Fails if any .swift file under Sources/ or Tests/ exceeds 400 lines.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIMIT=400
failed=0

while IFS= read -r -d '' file; do
  lines=$(wc -l < "$file" | tr -d ' ')
  if (( lines > LIMIT )); then
    echo "FAIL: $file has $lines lines (limit $LIMIT)"
    failed=1
  fi
done < <(find "$ROOT/Sources" "$ROOT/Tests" -name '*.swift' -print0 2>/dev/null)

if (( failed )); then
  exit 1
fi

echo "OK: all Swift files ≤ ${LIMIT} lines"

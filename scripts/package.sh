#!/usr/bin/env bash
# Zip the channel with manifest at the archive root. Roku rejects a zip that
# wraps the channel in an extra folder.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHANNEL="$ROOT/channel"
OUT="$ROOT/dist"
ZIP="$OUT/eaglewood.zip"
LIMIT=$((4 * 1024 * 1024))

mkdir -p "$OUT"
rm -f "$ZIP"

(
    cd "$CHANNEL"
    zip -r -X -D "$ZIP" manifest source components images -x '*.DS_Store' -x '*/.DS_Store'
)

bytes="$(wc -c < "$ZIP" | tr -d ' ')"
echo "Packaged ${ZIP} (${bytes} bytes)"
if (( bytes > LIMIT )); then
    echo "Package is ${bytes} bytes, over the 4 MB certification limit (${LIMIT})." >&2
    exit 1
fi

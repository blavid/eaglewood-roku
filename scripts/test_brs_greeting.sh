#!/usr/bin/env bash
# Run the channel's SanitizeFirstName on the brs interpreter.
# brs 0.45 does not draw SceneGraph, so this checks the greeting logic only.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
output="$(npx --yes brs@0.45.0 \
    --root "$ROOT/channel" \
    "$ROOT/channel/components/MainScene.brs" \
    "$ROOT/scripts/brs_greeting_check.brs")"
printf '%s\n' "$output"
if ! printf '%s\n' "$output" | grep -q "brs greeting checks passed"; then
    echo "brs greeting checks did not pass" >&2
    exit 1
fi
if printf '%s\n' "$output" | grep -q "not yet implemented"; then
    echo "brs is missing a runtime call the channel uses" >&2
    exit 1
fi

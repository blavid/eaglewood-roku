#!/usr/bin/env bash
# Pre-TV pass: run the channel in the free brs-engine CLI and save 1920x1080 frames.
# https://github.com/lvcabral/brs-engine
# SceneGraph is on by default (docs/limitations.md). The CLI device defaults to
# 720p (docs/customization.md); this script switches that copy to 1080p because
# the channel manifest is FHD only.
#
# No guest path key and no real Wi-Fi secret. The QR shot uses a local server
# and the placeholders SSID TestNet / password placeholder.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-/opt/cursor/artifacts/emu-final}"
INSTALL="${BRS_EMU_PREFIX:-/tmp/brs-emu}"
PORT="${BRS_ECP_PORT:-8060}"
WIFI_PORT="${EMU_WIFI_PORT:-8765}"
SESSION="${EMU_TMUX_SESSION:-emu-eaglewood}"
IDLE_SECONDS="${EMU_IDLE_SECONDS:-8}"

mkdir -p "$OUT"
rm -f "$OUT"/*.png "$OUT"/index.tsv

if [[ ! -x "$INSTALL/node_modules/.bin/brs-cli" ]]; then
  echo "Installing brs-node into $INSTALL"
  npm install --prefix "$INSTALL" brs-node@2.6.2
fi

# The CLI resolves ./brs.node.js beside this file, so the patch stays in the package.
CLI_JS="$INSTALL/node_modules/brs-node/bin/brs.cli.js"
python3 - "$CLI_JS" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
old = 'displayMode:"720p"'
new = 'displayMode:"1080p"'
if old not in text and new not in text:
    raise SystemExit("brs-cli has no displayMode default to switch to 1080p")
if old in text:
    path.write_text(text.replace(old, new, 1), encoding="utf-8")
PY

STAGE="$(mktemp -d)"
cp -a "$ROOT/channel/." "$STAGE/"
python3 "$ROOT/scripts/write_guest_secrets.py" --dest "$STAGE/components/secrets.brs" --no-guest
# Shorter idle only in this staged copy so the return-home frame can be captured.
# The file in git stays at 600 seconds.
python3 - "$STAGE" "$IDLE_SECONDS" <<'PY'
import pathlib, sys
stage, seconds = pathlib.Path(sys.argv[1]), sys.argv[2]
xml = stage / "components" / "MainScene.xml"
xml.write_text(xml.read_text(encoding="utf-8").replace('duration="600"', f'duration="{seconds}"', 1), encoding="utf-8")
scene = stage / "components" / "MainScene.brs"
updated = scene.read_text(encoding="utf-8").replace("m.idleTimer.duration = 600", f"m.idleTimer.duration = {seconds}", 1)
if f"m.idleTimer.duration = {seconds}" not in updated:
    raise SystemExit("idle timer was not shortened in the staged copy")
scene.write_text(updated, encoding="utf-8")
PY

MOCK="$STAGE/emu-wifi"
mkdir -p "$MOCK"
python3 - "$MOCK" <<'PY'
import json, pathlib, sys
out = pathlib.Path(sys.argv[1])
(out / "wifi.json").write_text(json.dumps({"ssid": "TestNet", "password": "placeholder"}), encoding="utf-8")
try:
    import qrcode
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "qrcode", "pillow", "-q"])
    import qrcode
img = qrcode.make("WIFI:T:WPA;S:TestNet;P:placeholder;;").convert("RGB")
img.save(out / "wifi.png")
PY

export EMU_STAGE="$STAGE"
export EMU_OUT="$OUT"
export EMU_CLI="$INSTALL/node_modules/.bin/brs-cli"
export EMU_NODE_PATH="$INSTALL/node_modules"
export EMU_PORT="$PORT"
export EMU_WIFI_PORT="$WIFI_PORT"
export EMU_SESSION="$SESSION"
export EMU_IDLE_SECONDS="$IDLE_SECONDS"
export EMU_WIFI_DIR="$MOCK"
export BRS_NO_UPDATE_CHECK=1

python3 "$ROOT/scripts/emu_tour.py"
echo "frames in $OUT"

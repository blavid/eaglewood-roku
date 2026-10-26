#!/usr/bin/env bash
# Zip the channel with manifest at the archive root. Roku rejects a zip that
# wraps the channel in an extra folder.
# The guest path key is written only into the staged copy of secrets.brs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHANNEL="$ROOT/channel"
OUT="$ROOT/dist"
ZIP="$OUT/eaglewood.zip"
LIMIT=$((4 * 1024 * 1024))

NO_GUEST=0
STUB_URL=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-guest)
            NO_GUEST=1
            shift
            ;;
        --stub)
            if [[ $# -lt 2 ]]; then
                echo "--stub requires a guest.json URL." >&2
                exit 2
            fi
            STUB_URL="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument." >&2
            exit 2
            ;;
    esac
done

if [[ "$NO_GUEST" -eq 1 && -n "$STUB_URL" ]]; then
    echo "Use either --no-guest or --stub, not both." >&2
    exit 2
fi

python3 "$ROOT/scripts/check_tracked_guest_key.py"

STAGE="$(mktemp -d)"
cleanup() {
    rm -rf "$STAGE"
}
trap cleanup EXIT

mkdir -p "$STAGE"
cp -a "$CHANNEL/." "$STAGE/"
rm -f "$STAGE/components/secrets.brs"

if [[ "$NO_GUEST" -eq 1 ]]; then
    python3 "$ROOT/scripts/write_guest_secrets.py" --dest "$STAGE/components/secrets.brs" --no-guest
elif [[ -n "$STUB_URL" ]]; then
    GUEST_STUB_URL="$STUB_URL" python3 "$ROOT/scripts/write_guest_secrets.py" \
        --dest "$STAGE/components/secrets.brs" \
        --stub-from-env
else
    python3 "$ROOT/scripts/write_guest_secrets.py" --dest "$STAGE/components/secrets.brs" --key-from-env
fi

mkdir -p "$OUT"
rm -f "$ZIP"
(
    cd "$STAGE"
    zip -r -X -D "$ZIP" manifest source components images -x '*.DS_Store' -x '*/.DS_Store'
)

python3 - "$ZIP" <<'PY'
import sys
import zipfile

path = sys.argv[1]
with zipfile.ZipFile(path) as archive:
    names = archive.namelist()
missing = [name for name in ("manifest", "components/secrets.brs") if name not in names]
if missing:
    sys.stderr.write("Package is missing " + ", ".join(missing) + ".\n")
    sys.exit(1)
if any(name.startswith("channel/") for name in names):
    sys.stderr.write("Package wraps the channel in an extra folder.\n")
    sys.exit(1)
PY

bytes="$(wc -c < "$ZIP" | tr -d ' ')"
echo "Packaged ${ZIP} (${bytes} bytes)"
if (( bytes > LIMIT )); then
    echo "Package is ${bytes} bytes, over the 4 MB certification limit (${LIMIT})." >&2
    exit 1
fi

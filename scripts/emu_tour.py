#!/usr/bin/env python3
"""Drive the staged channel in brs-cli and save one PNG per screen.

The CLI must already be patched to displayMode 1080p. Keys go through ECP.
Ctrl+S (tmux) saves the PNG named by --snapshot. See docs/run-as-cli.md.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.request import Request, urlopen

STAGE = Path(os.environ["EMU_STAGE"])
OUT = Path(os.environ["EMU_OUT"])
CLI = os.environ["EMU_CLI"]
NODE_PATH = os.environ["EMU_NODE_PATH"]
PORT = os.environ["EMU_PORT"]
WIFI_PORT = int(os.environ["EMU_WIFI_PORT"])
SESSION = os.environ["EMU_SESSION"]
IDLE_SECONDS = int(os.environ["EMU_IDLE_SECONDS"])
WIFI_DIR = Path(os.environ["EMU_WIFI_DIR"])
TMUX = ["tmux", "-f", "/exec-daemon/tmux.portal.conf"]
SNAP = Path("/tmp/emu-eaglewood-snap.png")
LOG = Path("/tmp/emu-eaglewood.log")
INDEX = OUT / "index.tsv"

ROWS: list[tuple[str, str]] = []
SEEN: dict[str, str] = {}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        name = self.path.split("?", 1)[0].rstrip("/").split("/")[-1]
        path = WIFI_DIR / name
        if not path.is_file():
            self.send_response(404)
            self.end_headers()
            return
        body = path.read_bytes()
        kind = "application/json" if name.endswith(".json") else "image/png"
        self.send_response(200)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt: str, *args: object) -> None:
        return


def serve() -> None:
    ThreadingHTTPServer(("127.0.0.1", WIFI_PORT), Handler).serve_forever()


def tmux(*args: str) -> None:
    subprocess.check_call([*TMUX, *args], stdout=subprocess.DEVNULL)


def launch() -> None:
    if LOG.exists():
        LOG.unlink()
    if SNAP.exists():
        SNAP.unlink()
    subprocess.run([*TMUX, "kill-session", "-t", SESSION], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    tmux("new-session", "-d", "-s", SESSION, "-c", "/tmp")
    cmd = (
        f"export BRS_NO_UPDATE_CHECK=1 BRS_ECP_PORT={PORT} NODE_PATH={NODE_PATH}; "
        f"{CLI} --root {STAGE} --snapshot {SNAP} --ecp --log {LOG} --colors 0"
    )
    tmux("send-keys", "-t", f"{SESSION}:0.0", cmd, "C-m")
    wait_log("zone=prompt", 40)


def wait_log(text: str, seconds: float) -> None:
    deadline = time.time() + seconds
    while time.time() < deadline:
        if LOG.exists() and text in LOG.read_text(encoding="utf-8", errors="replace"):
            return
        time.sleep(0.2)
    raise SystemExit(f"emulator did not log {text!r}\n{LOG.read_text(encoding='utf-8', errors='replace')[-2000:] if LOG.exists() else 'no log'}")


def stop() -> None:
    subprocess.run([*TMUX, "send-keys", "-t", f"{SESSION}:0.0", "C-c"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(0.4)
    subprocess.run([*TMUX, "kill-session", "-t", SESSION], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def key(name: str, pause: float = 0.7) -> None:
    request = Request(f"http://127.0.0.1:{PORT}/keypress/{name}", data=b"", method="POST")
    with urlopen(request, timeout=5) as response:
        response.read()
    time.sleep(pause)


def stable_png() -> bytes:
    last = b""
    for _ in range(8):
        tmux("send-keys", "-t", f"{SESSION}:0.0", "C-s")
        time.sleep(0.25)
        if not SNAP.exists() or SNAP.stat().st_size < 1000:
            continue
        data = SNAP.read_bytes()
        if data.startswith(b"\x89PNG") and data.endswith(b"IEND\xaeB`\x82") and data == last:
            return data
        last = data
    if last.startswith(b"\x89PNG"):
        return last
    raise SystemExit("snapshot was not a finished PNG")


def shot(slug: str, description: str, pause: float = 0.6) -> None:
    time.sleep(pause)
    data = stable_png()
    dest = OUT / f"{slug}.png"
    dest.write_bytes(data)
    digest = __import__("hashlib").sha256(data).hexdigest()
    note = description
    if digest in SEEN:
        note = f"Same pixels as {SEEN[digest]}. The emulator framebuffer had not advanced. Intended view: {description}"
    else:
        SEEN[digest] = slug
    ROWS.append((slug, dest.name, note))
    print(f"shot {dest.name}")


def enable_mock_wifi() -> None:
    path = STAGE / "components" / "GuestConfig.brs"
    text = path.read_text(encoding="utf-8")
    start = text.find("function WifiAssetUrl(")
    end = text.find("end function", start)
    if start < 0 or end < 0:
        raise SystemExit("WifiAssetUrl was not found in the staged channel")
    replacement = (
        "function WifiAssetUrl(name as string) as string\n"
        f'    return "http://127.0.0.1:{WIFI_PORT}/" + name\n'
        "end function"
    )
    path.write_text(text[:start] + replacement + text[end + len("end function") :], encoding="utf-8")


def tour(wifi_slug: str, wifi_text: str) -> None:
    launch()
    shot("home-prompt-focus", "Home, Book Direct strip focused, corner badge area")
    key("Left")
    shot("home-rail-focus", "Home row focused on the top rail")
    key("Down")
    shot("rail-wifi-focus", "Wi-Fi row focused")
    key("Select", 1.4)
    shot(wifi_slug, wifi_text)
    key("Back")
    key("Down", 0.7)
    shot("rail-todo-focus", "Things to Do row focused")
    key("Select", 0.8)
    categories = ["dining", "hiking", "winter", "summer", "fishing", "biking"]
    for index, name in enumerate(categories):
        if index:
            key("Down", 0.45)
        shot(f"todo-{name}-focus", f"Things to Do submenu, {name} focused")
    key("Back", 0.6)
    key("Down", 0.45)
    shot("rail-rules-focus", "House Rules row focused")
    key("Select", 0.7)
    shot("house-rules", "House Rules page")
    key("Back", 0.45)
    key("Down", 0.4)
    key("Down", 0.4)
    shot("rail-book-focus", "Book Direct row focused")
    key("Select", 0.7)
    shot("book-direct", "Book Direct page")
    key("Back", 0.45)
    key("Down", 0.4)
    shot("rail-checkout-focus", "Checkout Instructions row focused")
    key("Select", 0.6)
    shot("checkout", "Checkout Instructions page")
    key("Back", 0.4)
    for _ in range(4):
        key("Up", 0.3)
    key("Select", 0.7)
    for _ in categories[:-1]:
        key("Up", 0.35)
    opens = {
        "dining": "Dining activity cards",
        "hiking": "Hiking activity cards",
        "winter": "Winter activity cards",
        "summer": "Summer activity cards",
        "fishing": "Fishing empty state",
        "biking": "Biking activity cards",
    }
    for index, name in enumerate(categories):
        if index:
            key("Down", 0.4)
        key("Select", 0.8)
        shot(f"{name}-grid", opens[name])
        if name != "fishing":
            key("Select", 0.8)
            shot(f"{name}-detail", f"First {name} activity detail")
            if name == "dining":
                key("Back", 0.5)
                key("Right", 0.4)
                key("Select", 0.8)
                shot("dining-detail-second", "Second Dining activity detail")
            key("Back", 0.5)
        key("Back", 0.6)
    key("Back", 0.6)
    key("Down", 0.5)
    shot("rail-rules-focus", "House Rules row focused")
    key("Select", 0.6)
    shot("house-rules", "House Rules page")
    key("Back", 0.5)
    key("Down", 0.5)
    shot("rail-fixes-focus", "Quick Fixes row focused")
    key("Select", 0.8)
    shot("fixes-list", "Quick Fixes list, first issue focused")
    titles = [
        "Circuit breaker tripped",
        "Hot tub too hot or too cold",
        "How do I change the thermostat temperature?",
        "Where do I put the trash and recycling?",
        "BBQ grill not working",
        "How do I use the dishwasher?",
        "Smart lights not working",
        "How do I lock the bikes?",
        "How do I do laundry?",
        "Hot tub is dirty or has a strange smell",
        "Hot tub not heating",
        "TV or streaming not working",
    ]
    for index, title in enumerate(titles):
        key("Select", 0.7)
        shot(f"fixes-detail-{index + 1:02d}", f"Quick Fixes detail: {title}")
        if index in (2, 11):
            for _ in range(8):
                key("Down", 0.2)
            shot(f"fixes-detail-{index + 1:02d}-scrolled", f"Quick Fixes detail scrolled: {title}")
        key("Back", 0.45)
        if index < len(titles) - 1:
            key("Down", 0.4)
    key("Back", 0.6)
    for _ in range(6):
        key("Up", 0.25)
    key("Select", 0.4)
    key("Down", 0.4)
    shot("home-tile-wifi-focus", "Home tile Wi-Fi focused")
    key("Right", 0.35)
    shot("home-tile-todo-focus", "Home tile Things to Do focused")
    key("Right", 0.35)
    shot("home-tile-dining-focus", "Home tile Dining focused")
    key("Down", 0.35)
    shot("home-tile-checkout-focus", "Home tile Checkout Instructions focused")
    print(f"waiting {IDLE_SECONDS + 2}s for idle return")
    time.sleep(IDLE_SECONDS + 2)
    shot("home-after-idle", "Home after the idle timer returned from the tiles")
    stop()


def main() -> None:
    thread = threading.Thread(target=serve, daemon=True)
    thread.start()
    try:
        launch()
        key("Left")
        key("Down")
        key("Select", 1.2)
        shot("wifi-error", "Wi-Fi with no guest key: message, no blank white square")
        stop()
        enable_mock_wifi()
        tour("wifi-with-qr", "Wi-Fi with the local TestNet placeholder QR")
    finally:
        lines = ["slug\tfilename\tshows\n"]
        for slug, filename, description in ROWS:
            lines.append(f"{slug}\t{filename}\t{description}\n")
        INDEX.write_text("".join(lines), encoding="utf-8")
        stop()


if __name__ == "__main__":
    main()

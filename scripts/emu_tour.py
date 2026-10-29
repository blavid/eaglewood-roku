#!/usr/bin/env python3
"""Open each screen in a fresh brs-cli process and save one PNG per screen.

Each capture launches the staged channel with --deep-link emuKeys=<keys>. The
scene replays those keys before the frame is saved, so no capture depends on
the state of an earlier one. Ctrl+S (tmux) saves the PNG named by --snapshot.
Every PNG must hash differently; a repeat fails the run.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(os.environ["EMU_ROOT"])
WORK = Path(os.environ["EMU_WORK"])
OUT = Path(os.environ["EMU_OUT"])
CLI = os.environ["EMU_CLI"]
NODE_PATH = os.environ["EMU_NODE_PATH"]
PORT = os.environ["EMU_PORT"]
FIX_PORT = int(os.environ["EMU_FIXTURE_PORT"])
SESSION = os.environ["EMU_SESSION"]
IDLE_SECONDS = int(os.environ["EMU_IDLE_SECONDS"])
ONLY = [s for s in os.environ.get("EMU_ONLY", "").split(",") if s]
TMUX = ["tmux", "-f", "/exec-daemon/tmux.portal.conf"]
SNAP = WORK / "snap.png"
LOG = WORK / "emu.log"
ORIGIN = f"http://127.0.0.1:{FIX_PORT}"
FAKE_KEY = "emu-fixture-key"
IMAGE_CACHE = Path(os.environ.get("EMU_IMAGE_CACHE", "/tmp/emu-eaglewood-images"))
FIX = WORK / "fixtures"

# Rail rows, from menu.json order. Keys start on Home with the Book Direct strip focused.
RAIL = {"home": 0, "wifi": 1, "todo": 2, "rules": 3, "fixes": 4, "book": 5, "checkout": 6}
TODO = ["dining", "hiking", "winter", "summer", "biking"]


def rail(section: str) -> list[str]:
    return ["Left"] + ["Down"] * RAIL[section]


def fy() -> list[str]:
    return rail("todo") + ["Right"]


def screens() -> list[dict]:
    s: list[dict] = []

    def add(slug: str, keys: list[str], shows: str, stage: str = "key", wait: float = 0.0, need: str = "", same_as: str = "", ecp: list[str] | None = None, visits: list[str] | None = None, card: str = "") -> None:
        if not card and (slug.startswith(("home-", "rail-", "ad-")) and slug != "home-after-idle" or slug == "blake-path-focus"):
            card = "qr"
        s.append({"slug": slug, "keys": keys, "shows": shows, "stage": stage, "wait": wait, "need": need, "same_as": same_as, "ecp": ecp or [], "visits": visits or [], "card": card})

    add("home-prompt-focus", [], "Home, Book Direct strip focused, QR card and badge")
    add("home-rail-focus", rail("home"), "Home, rail Home row focused")
    add("home-tile-wifi-focus", ["Down"], "Home, Wi-Fi tile focused")
    add("home-tile-todo-focus", ["Down", "Right"], "Home, Things to Do tile focused")
    add("home-tile-dining-focus", ["Down", "Right", "Right"], "Home, Dining tile focused")
    add("home-tile-hiking-focus", ["Down", "Down"], "Home, Hiking tile focused (bottom row)")
    add("home-tile-fixes-focus", ["Down", "Down", "Right"], "Home, Quick Fixes tile focused")
    add("home-tile-checkout-focus", ["Down", "Down", "Right", "Right"], "Home, Checkout tile focused")
    add("rail-wifi-focus", rail("wifi"), "Rail Wi-Fi row focused, Wi-Fi preview")
    add("wifi-with-qr", rail("wifi") + ["Select"], "Wi-Fi with the local TestNet placeholder QR", need="qr wifi")
    add("wifi-error", rail("wifi") + ["Select"], "Wi-Fi with no guest key: status panel, Password Unavailable", stage="nokey")
    # Build 34: Things to Do is the Roku "For You" grid: one card row per
    # non-empty category (Fishing has none, so it has no row).
    add("rail-todo-focus", rail("todo"), "Rail Things to Do focused: For You rows preview beside the expanded rail")
    add("fy-grid", fy(), "For You grid: rail collapsed to icons, Dining row first card focused, 1 of N; corner ad hidden", card="hidden")
    add("fy-move-right", fy() + ["Right"], "For You grid, second Dining card focused, 2 of N", card="hidden")
    add("fy-move-right3", fy() + ["Right"] * 3, "For You grid, fourth Dining card, row scrolled", card="hidden")
    for k, child in enumerate(TODO[1:], 1):
        add(f"fy-row-{child}", fy() + ["Down"] * k, f"For You grid, {child.title()} row focused at the top slot", card="hidden")
    add("fy-left-to-rail", fy() + ["Left"], "Left from the first card returns to the expanded rail on Things to Do", same_as="rail-todo-focus")
    add("fy-detail", fy() + ["Select"], "Card detail (first Dining) with its QR", need="qr detail")
    add("fy-detail-second", fy() + ["Right", "Select"], "Second Dining card detail")
    add("fy-detail-summer", fy() + ["Down"] * TODO.index("summer") + ["Select"], "First Summer card detail with its QR", need="qr detail")
    add("fy-detail-scrolled", fy() + ["Down"] * TODO.index("summer") + ["Select"] + ["Down"] * 3, "First Summer detail, body scrolled")
    add("fy-detail-qr-blocked", fy() + ["Down"] * TODO.index("summer") + ["Select"], "Summer detail with the QR fetch blocked: no-link layout", stage="qrblocked", wait=7)
    add("fy-detail-back", fy() + ["Right", "Select", "Back"], "Back from the card detail returns to the grid on card 2", same_as="fy-move-right")
    add("fy-back-to-rail", fy() + ["Down", "Back"], "Back from the grid returns to the expanded rail", same_as="rail-todo-focus")
    add("rail-rules-focus", rail("rules"), "Rail House Rules focused")
    add("house-rules", rail("rules") + ["Select"], "House Rules page")
    # Build 34: Quick Fixes is the Roku Settings pattern.
    add("rail-fixes-focus", rail("fixes"), "Rail Quick Fixes focused: fix list column shown beside the rail")
    add("fx-list", rail("fixes") + ["Right"], "Fix list focused: rail row reads < Quick Fixes, issue 1 steps preview")
    for index in range(1, 12):
        add(f"fx-list-{index + 1:02d}", rail("fixes") + ["Right"] + ["Down"] * index, f"Fix list, issue {index + 1} focused with its steps preview")
    add("fx-steps", rail("fixes") + ["Right", "Right"], "Issue 1 steps: rail slid off, list is the < breadcrumb column")
    add("fx-steps-03", rail("fixes") + ["Right", "Down", "Down", "Right"], "Issue 3 steps, breadcrumb column", card="hidden")
    add("fx-steps-long", rail("fixes") + ["Right", "Right"], "Fixture long fix steps, top", stage="longfix", card="hidden")
    add("fx-steps-scrolled", rail("fixes") + ["Right", "Right", "Down", "Down", "Down"], "Fixture long fix steps scrolled", stage="longfix", card="hidden")
    add("fx-steps-back", rail("fixes") + ["Right", "Down", "Right", "Left"], "Left from the steps slides back to the fix list on issue 2", same_as="fx-list-02")
    add("fx-list-back", rail("fixes") + ["Right", "Down", "Back"], "Back from the fix list returns to the rail on Quick Fixes", same_as="rail-fixes-focus")
    # Build 32: Blake's TV path, sent as real ECP key presses so they go
    # through roSGScreen focus and onKeyEvent. Each press must log focus=scene.
    blake = ["Left", "Down", "Down", "Select", "Down", "Down", "Up", "Up", "Right", "Right", "Down", "Up", "Left", "Left", "Down", "Up", "Back",
             "Down", "Select", "Back", "Down", "Select", "Down", "Down", "Right", "Down", "Back", "Up", "Back",
             "Down", "Select", "Back", "Down", "Select", "Back", "Up", "Up", "Up", "Up", "Up", "Up", "Select", "Back", "Up", "Up"]
    add("blake-path-focus", [], "Blake's TV path (Things to Do, Dining, moves, back out, every section) as ECP keys; ends on Home rail", ecp=blake, same_as="home-rail-focus",
        visits=["todo", "rules", "fixes", "book", "checkout", "home"])
    # Build 33: Home badge QR host unreachable; the card keeps its frame and
    # caption and shows the no-link text after the 5 s deadline.
    # Build 34: the corner ad replaces the Home QR card and badge.
    add("ad-2", ["adnext"], "Home with the second corner ad (rotation frame 2)")
    add("ad-3", ["adnext", "adnext"], "Home with the third corner ad (rotation frame 3)")
    add("wifi-stale-etag", rail("wifi") + ["Select"], "Stale etags seeded, cache files missing: 304 refetches without the etag, TestNet shown", stage="staleetag", need="qr wifi", same_as="wifi-with-qr")
    add("rail-book-focus", rail("book"), "Rail Book Direct focused")
    add("book-direct", rail("book") + ["Select"], "Book Direct page")
    add("rail-checkout-focus", rail("checkout"), "Rail Checkout focused")
    add("checkout", rail("checkout") + ["Select"], "Checkout Instructions page")
    add("home-after-idle", rail("book") + ["Select"], "Home after the idle timer fired on Book Direct", wait=IDLE_SECONDS + 3, same_as="book-direct")
    return s


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        path = self.path.split("?", 1)[0]
        if path.startswith("/blocked-qr/"):
            # Network blocked: drop the connection with no response.
            self.close_connection = True
            return
        if self.headers.get("If-None-Match") == STALE_ETAG:
            # Stale etag seeded by stage "staleetag": answer 304 although the
            # channel's cache file is missing (the tv-b33 case).
            self.send_response(304)
            self.end_headers()
            return
        target = FIX / path.lstrip("/")
        if not target.is_file():
            self.send_response(404)
            self.end_headers()
            return
        body = target.read_bytes()
        kind = {".json": "application/json", ".png": "image/png", ".jpg": "image/jpeg"}.get(target.suffix, "application/octet-stream")
        self.send_response(200)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt: str, *args: object) -> None:
        return


def qr_png(text: str, dest: Path) -> None:
    try:
        import qrcode
    except ImportError:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "qrcode", "pillow", "-q"])
        import qrcode
    dest.parent.mkdir(parents=True, exist_ok=True)
    qrcode.make(text, border=2).convert("RGB").save(dest)


def public_image(path: str, dest: Path) -> None:
    """Public site photos, cached once. Falls back to the packaged placeholder."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    cached = IMAGE_CACHE / path.lstrip("/")
    if not cached.is_file():
        try:
            request = Request("https://sunrivertownhome.com" + path, headers={"User-Agent": "Mozilla/5.0 (eaglewood-emu)"})
            with urlopen(request, timeout=10) as response:
                data = response.read()
            cached.parent.mkdir(parents=True, exist_ok=True)
            cached.write_bytes(data)
        except Exception:
            shutil.copy(ROOT / "channel/images/tv-placeholder.jpg", dest)
            return
    shutil.copy(cached, dest)


def build_fixtures() -> None:
    data = FIX / "data"
    data.mkdir(parents=True, exist_ok=True)
    for name in ["guide.json", "checkout.json", "activities.json", "menu.json"]:
        text = (ROOT / "channel/data" / name).read_text(encoding="utf-8")
        (data / name).write_text(text.replace("https://sunrivertownhome.com", ORIGIN), encoding="utf-8")
    blob = "\n".join((ROOT / "channel" / p).read_text(encoding="utf-8") for p in ["data/guide.json", "data/activities.json", "components/Season.brs"])
    for path in sorted(set(re.findall(r'(?:https://sunrivertownhome\.com)?(/(?:data/qr|images)/[A-Za-z0-9_./-]+\.(?:png|jpg|jpeg))', blob))):
        if "/data/qr/" in path:
            qr_png("EMU TEST QR " + Path(path).stem, FIX / path.lstrip("/"))
        else:
            public_image(path, FIX / path.lstrip("/"))
    wifi = FIX / "tv" / FAKE_KEY
    wifi.mkdir(parents=True, exist_ok=True)
    (wifi / "wifi.json").write_text(json.dumps({"ssid": "TestNet", "password": "placeholder"}), encoding="utf-8")
    qr_png("WIFI:T:WPA;S:TestNet;P:placeholder;;", wifi / "wifi.png")


STALE_ETAG = '"emu-stale"'
LONG_FIX_PATH = "/data-longfix/guide.json"
BADGE_BLOCKED_PATH = "/data-badgeblocked/guide.json"
BADGE_QR = "/data/qr/book-direct-booking.png"


def long_fix_guide() -> str:
    """guide.json with one emulator-only fix first whose steps overflow the panel."""
    guide = json.loads((ROOT / "channel/data/guide.json").read_text(encoding="utf-8"))
    steps = []
    for issue in guide.get("troubleshooting") or []:
        steps += issue.get("steps") or []
    guide["troubleshooting"].insert(0, {"issue": "Emulator fixture: long steps", "steps": [" ".join(steps[i:i + 3]) for i in range(0, 24, 3)]})
    return json.dumps(guide, ensure_ascii=False).replace("https://sunrivertownhome.com", ORIGIN)


def build_stage(name: str, key: str) -> Path:
    stage = WORK / f"stage-{name}"
    shutil.copytree(ROOT / "channel", stage)
    if name == "longfix":
        (stage / "data" / "guide.json").write_text(long_fix_guide(), encoding="utf-8")
        (FIX / LONG_FIX_PATH.lstrip("/")).parent.mkdir(parents=True, exist_ok=True)
        (FIX / LONG_FIX_PATH.lstrip("/")).write_text(long_fix_guide(), encoding="utf-8")
        task = stage / "components" / "GuideTask.brs"
        task.write_text(task.read_text(encoding="utf-8").replace("https://sunrivertownhome.com/data/guide.json", "https://sunrivertownhome.com" + LONG_FIX_PATH, 1), encoding="utf-8")
    if name == "badgeblocked":
        blocked = BADGE_QR.replace("/data/qr/", "/blocked-qr/")
        served = FIX / BADGE_BLOCKED_PATH.lstrip("/")
        served.parent.mkdir(parents=True, exist_ok=True)
        served.write_text((FIX / "data" / "guide.json").read_text(encoding="utf-8").replace(BADGE_QR, blocked), encoding="utf-8")
        for path in [stage / "data" / "guide.json", stage / "components" / "Season.brs"]:
            path.write_text(path.read_text(encoding="utf-8").replace(BADGE_QR, blocked), encoding="utf-8")
        task = stage / "components" / "GuideTask.brs"
        task.write_text(task.read_text(encoding="utf-8").replace("https://sunrivertownhome.com/data/guide.json", "https://sunrivertownhome.com" + BADGE_BLOCKED_PATH, 1), encoding="utf-8")
    if name == "qrblocked":
        acts = stage / "data" / "activities.json"
        acts.write_text(acts.read_text(encoding="utf-8").replace("/data/qr/", "/blocked-qr/"), encoding="utf-8")
        served = FIX / "data-qrblocked" / "activities.json"
        served.parent.mkdir(parents=True, exist_ok=True)
        served.write_text((FIX / "data" / "activities.json").read_text(encoding="utf-8").replace("/data/qr/", "/blocked-qr/"), encoding="utf-8")
        task = stage / "components" / "GuideTask.brs"
        task.write_text(task.read_text(encoding="utf-8").replace("https://sunrivertownhome.com/data/activities.json", "https://sunrivertownhome.com/data-qrblocked/activities.json", 1), encoding="utf-8")
    if name == "staleetag":
        seed = "".join(f'    seed.Write("{p}Etag", Chr(34) + "emu-stale" + Chr(34))\n' for p in ["wifiJson", "wifiPng", "guide", "checkout", "activities", "menu"])
        block = '    seed = CreateObject("roRegistrySection", "EaglewoodGuide")\n' + seed + '    seed.Flush()\n    print "Eaglewood: emu seeded stale etags"\n'
        for file, head in [("WifiTask.brs", "sub fetchWifi()\n"), ("GuideTask.brs", "sub fetchGuideBundle()\n")]:
            task = stage / "components" / file
            text = task.read_text(encoding="utf-8")
            if head not in text:
                raise SystemExit(f"{file}: fetch sub not found")
            task.write_text(text.replace(head, head + block, 1), encoding="utf-8")
    (stage / "emu").mkdir()
    (stage / "emu" / "enabled").write_text("screenshot harness\n", encoding="utf-8")
    (stage / "components" / "secrets.brs").write_text(
        "' emulator fixture only\n"
        f'function GuestPathKey() as string\n    return "{key}"\nend function\n\n'
        'function GuestStubUrl() as string\n    return ""\nend function\n',
        encoding="utf-8",
    )
    for path in list((stage / "components").glob("*.brs")) + list((stage / "data").glob("*.json")):
        text = path.read_text(encoding="utf-8")
        path.write_text(text.replace("https://sunrivertownhome.com", ORIGIN), encoding="utf-8")
    xml = stage / "components" / "MainScene.xml"
    xml.write_text(xml.read_text(encoding="utf-8").replace('duration="600"', f'duration="{IDLE_SECONDS}"', 1), encoding="utf-8")
    scene = stage / "components" / "MainScene.brs"
    text = scene.read_text(encoding="utf-8")
    if "m.idleTimer.duration = 600" not in text:
        raise SystemExit("idle timer was not found in the staged copy")
    scene.write_text(text.replace("m.idleTimer.duration = 600", f"m.idleTimer.duration = {IDLE_SECONDS}", 1), encoding="utf-8")
    return stage


def tmux(*args: str) -> None:
    subprocess.check_call([*TMUX, *args], stdout=subprocess.DEVNULL)


def stop() -> None:
    subprocess.run([*TMUX, "send-keys", "-t", f"{SESSION}:0.0", "C-c"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(0.3)
    subprocess.run([*TMUX, "kill-session", "-t", SESSION], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["pkill", "-f", "brs.cli.js --root"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(0.3)


def log_text() -> str:
    return LOG.read_text(encoding="utf-8", errors="replace") if LOG.exists() else ""


def wait_log(text: str, seconds: float) -> None:
    deadline = time.time() + seconds
    while time.time() < deadline:
        if text in log_text():
            return
        time.sleep(0.2)
    raise RuntimeError(f"emulator did not log {text!r}\n{log_text()[-1500:]}")


def launch(stage: Path, keys: list[str], ecp: bool = False) -> None:
    stop()
    for f in (LOG, SNAP):
        if f.exists():
            f.unlink()
    tmux("new-session", "-d", "-s", SESSION, "-x", "200", "-y", "50", "-c", str(WORK))
    link = f" --deep-link emuKeys={'-'.join(keys)}" if keys else ""
    cmd = (
        f"export BRS_NO_UPDATE_CHECK=1 BRS_ECP_PORT={PORT} NODE_PATH={NODE_PATH}; "
        f"{CLI} --root {stage} --snapshot {SNAP} --log {LOG} --colors 0{link}{' --ecp' if ecp else ''}{os.environ.get('EMU_CLI_EXTRA', '')}"
    )
    tmux("send-keys", "-t", f"{SESSION}:0.0", cmd, "C-m")
    wait_log("zone=prompt", 60)
    if keys:
        wait_log("emu keys done", 60)


ECP_NAMES = {"Left": "Left", "Right": "Right", "Up": "Up", "Down": "Down", "Select": "Select", "Back": "Back"}


def send_ecp(keys: list[str]) -> None:
    # The ECP listener can come up a few seconds after zone=prompt.
    deadline = time.time() + 30
    while True:
        try:
            urlopen(f"http://127.0.0.1:{PORT}/query/device-info", timeout=3).read()
            break
        except Exception:
            if time.time() > deadline:
                raise
            time.sleep(1)
    for key in keys:
        urlopen(Request(f"http://127.0.0.1:{PORT}/keypress/{ECP_NAMES[key]}", data=b"", method="POST"), timeout=5).read()
        time.sleep(float(os.environ.get("EMU_ECP_GAP", "1.6")))


def focus_problems(keys: list[str], visits: list[str]) -> str:
    """Every ECP press must reach the scene with focus=scene, and the path must visit each section in order."""
    lines = log_text().splitlines()
    presses = [l for l in lines if re.search(r"Eaglewood: key \S+ press=true", l)]
    if len(presses) != len(keys):
        return f"{len(presses)} of {len(keys)} key presses reached onKeyEvent"
    stuck = [l for l in presses if "focus=scene" not in l]
    if stuck:
        return f"{len(stuck)} press(es) without scene focus: {stuck[0].strip()}"
    if any("Eaglewood: key error" in l for l in lines):
        return "key error logged"
    screens = [m.group(1) for m in (re.search(r"Eaglewood: screen=(\S+)", l) for l in lines) if m]
    at = 0
    for want in visits:
        while at < len(screens) and screens[at] != want:
            at += 1
        if at == len(screens):
            return f"path never reached {want} in order"
    return ""


# Build 34 corner ad, from NavV2 AdRect (FHD): x 96-536, y 822-984.
CARD_BOX = (96, 822, 536, 984)


def card_problem(data: bytes, want: str) -> str:
    """want "qr": the corner ad is drawn and its QR has ink (not blank).
    want "hidden": the ad is gone (rail collapsed), so no QR modules there."""
    from io import BytesIO
    from PIL import Image
    px = list(Image.open(BytesIO(data)).convert("RGB").crop(CARD_BOX).getdata())
    black = sum(1 for r, g, b in px if r + g + b < 60) / len(px)
    white = sum(1 for r, g, b in px if r + g + b > 700) / len(px)
    bright = sum(1 for r, g, b in px if max(r, g, b) > 140) / len(px)
    stats = f"black {black:.3f} white {white:.3f} bright {bright:.2f}"
    if want == "qr" and (black < 0.02 or white < 0.02 or bright < 0.15):
        return f"corner ad blank or missing its QR ({stats})"
    if want == "hidden" and (black > 0.01 and white > 0.02):
        return f"corner ad still drawn with the rail collapsed ({stats})"
    return ""


def qr_ready(tag: str) -> bool:
    """The emulator's cross-thread cachefs read is racy; a ready line proves the QR drew."""
    return any(tag in line and "status=ready" in line.replace(" ", "") for line in log_text().splitlines())


def snapshot() -> bytes:
    last = b""
    for _ in range(10):
        if SNAP.exists():
            SNAP.unlink()
        tmux("send-keys", "-t", f"{SESSION}:0.0", "C-s")
        deadline = time.time() + 5
        while time.time() < deadline and not (SNAP.exists() and SNAP.read_bytes().endswith(b"IEND\xaeB`\x82")):
            time.sleep(0.1)
        if not SNAP.exists():
            continue
        data = SNAP.read_bytes()
        if data == last:
            return data
        last = data
        time.sleep(0.5)
    if last:
        return last
    raise RuntimeError("snapshot was not saved")


def launch_retrying(stage, keys, ecp: bool = False) -> None:
    # brs-node sometimes stalls before the key timer runs; a fresh process fixes it.
    for attempt in range(3):
        try:
            launch(stage, keys, ecp)
            return
        except RuntimeError as err:
            if "did not log" not in str(err) or attempt == 2:
                raise
            print(f"retry    launch stalled: {err}", flush=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    build_fixtures()
    stages = {"key": build_stage("key", FAKE_KEY), "nokey": build_stage("nokey", ""), "longfix": build_stage("longfix", FAKE_KEY), "qrblocked": build_stage("qrblocked", FAKE_KEY), "badgeblocked": build_stage("badgeblocked", FAKE_KEY), "staleetag": build_stage("staleetag", FAKE_KEY)}
    threading.Thread(target=ThreadingHTTPServer(("127.0.0.1", FIX_PORT), Handler).serve_forever, daemon=True).start()
    rows = []
    seen: dict[str, str] = {}
    failed = 0
    plan = [s for s in screens() if not ONLY or s["slug"] in ONLY]
    try:
        for item in plan:
            note = ""
            digest = ""
            try:
                tries = 0
                while True:
                    tries += 1
                    launch_retrying(stages[item["stage"]], item["keys"], bool(item["ecp"]))
                    if item["ecp"]:
                        time.sleep(4)
                        send_ecp(item["ecp"])
                    time.sleep(float(os.environ.get("EMU_SETTLE", "12")) + item["wait"])
                    if not item["need"] or qr_ready(item["need"]) or tries >= 4:
                        break
                if item["need"]:
                    note = f"qr ready after {tries} launch(es)" if qr_ready(item["need"]) else f"qr not ready after {tries} launches"
                data = snapshot()
                digest = hashlib.sha256(data).hexdigest()
                (OUT / f"{item['slug']}.png").write_bytes(data)
                (OUT / f"{item['slug']}.log").write_text(log_text(), encoding="utf-8")
                if os.environ.get("EMU_PANE"):
                    pane = subprocess.run([*TMUX, "capture-pane", "-p", "-S", "-5000", "-t", f"{SESSION}:0.0"], capture_output=True, text=True).stdout
                    (OUT / f"{item['slug']}.pane").write_text(pane, encoding="utf-8")
                if digest in seen and seen[digest] == item["same_as"]:
                    status, note = "captured", f"expected: same pixels as {seen[digest]}"
                elif digest in seen:
                    status, note = "fail", f"same pixels as {seen[digest]}"
                else:
                    seen[digest] = item["slug"]
                    status = "captured"
                if item["card"] and status != "fail":
                    problem = card_problem(data, item["card"])
                    if problem:
                        status, note = "fail", problem
                if item["ecp"] and status != "fail":
                    problem = focus_problems(item["ecp"], item["visits"])
                    note = problem or f"{len(item['ecp'])} ECP presses, every one focus=scene; visited {', '.join(item['visits'])}"
                    if problem:
                        status = "fail"
                if item["stage"] == "staleetag" and status != "fail":
                    want = ["emu seeded stale etags", "wifi cache-miss refetch", "guide cache-miss refetch", "checkout cache-miss refetch", "ssid len= 7"]
                    missing = [w for w in want if w not in log_text()]
                    if missing:
                        status, note = "fail", "stale-etag log missing: " + ", ".join(missing)
                    else:
                        note = "304 on stale etag with no cache: wifi, guide and checkout refetched; " + note
                errors = [l for l in log_text().splitlines() if "error" in l.lower() and "Eaglewood" in l]
                if errors:
                    status, note = "fail", "; ".join(errors[:2])
            except Exception as err:  # keep going; the row records it
                status, note = "fail", str(err).splitlines()[0]
                (OUT / f"{item['slug']}.log").write_text(log_text(), encoding="utf-8")
            if status == "fail":
                failed += 1
            sha = digest if status != "fail" or "same pixels" in note else ""
            rows.append((item["slug"], f"{item['slug']}.png", item["shows"], "-".join(item["keys"]) or "(none)", status, note, sha))
            print(f"{status:8} {item['slug']} {note}", flush=True)
    finally:
        stop()
        index = OUT / ("index.tsv" if not ONLY else "index-partial.tsv")
        lines = ["screen\tfile\tshows\tkeys\tstatus\tnotes\tsha256\n"]
        lines += ["\t".join(r) + "\n" for r in rows]
        index.write_text("".join(lines), encoding="utf-8")
    print(f"{len(rows)} screens, {len(seen)} unique, {failed} failed")
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

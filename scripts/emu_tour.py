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


def todo(child: str) -> list[str]:
    return rail("todo") + ["Select"] + ["Down"] * TODO.index(child)


def screens() -> list[dict]:
    s: list[dict] = []

    def add(slug: str, keys: list[str], shows: str, stage: str = "key", wait: float = 0.0, need: str = "", same_as: str = "") -> None:
        s.append({"slug": slug, "keys": keys, "shows": shows, "stage": stage, "wait": wait, "need": need, "same_as": same_as})

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
    add("rail-todo-focus", rail("todo"), "Rail Things to Do focused, category preview row")
    for child in TODO:
        add(f"todo-{child}-focus", todo(child), f"Things to Do submenu, {child.title()} focused")
    # Fishing has no cards yet, so Right keeps focus in the submenu and its
    # grid is the same picture as todo-fishing-focus.
    for child in [c for c in TODO if c != "fishing"]:
        add(f"{child}-grid", todo(child) + ["Right"], f"{child.title()} activity grid")
    add("dining-grid-card2", todo("dining") + ["Right", "Right"], "Dining grid, second card focused")
    add("dining-grid-row2", todo("dining") + ["Right", "Down"], "Dining grid, second row focused")
    add("dining-grid-deep", todo("dining") + ["Right"] + ["Down"] * 4, "Dining grid scrolled to a later row")
    for child in ["dining", "hiking", "winter", "summer", "biking"]:
        add(f"{child}-detail", todo(child) + ["Right", "Select"], f"First {child.title()} activity detail", need="qr detail" if child == "summer" else "")
    # Build 30: Summer sorts by seasonRank.summer; Web's seven picks each get
    # a detail capture with its QR.
    add("summer-grid-row2", todo("summer") + ["Right", "Down"], "Summer grid, second row focused")
    add("summer-grid-row3", todo("summer") + ["Right", "Down", "Down"], "Summer grid, third row focused")
    for k in range(1, 7):
        add(f"summer-detail-{k + 1:02d}", todo("summer") + ["Right"] + ["Right"] * (k % 3) + ["Down"] * (k // 3) + ["Select"], f"Summer pick {k + 1} detail with its QR", need="qr detail")
    add("dining-detail-second", todo("dining") + ["Right", "Right", "Select"], "Second Dining activity detail")
    # Build 29: the detail body shows 5 lines and scrolls; Winter overflows.
    # Build 30: at 28px the Winter body fits, so the scroll proof uses Summer's float.
    add("summer-detail-scrolled", todo("summer") + ["Right", "Select"] + ["Down"] * 3, "First Summer detail (float), body scrolled")
    add("summer-detail-nolink", todo("summer") + ["Right"] + ["Down"] * 3 + ["Select"], "Elk Lake (no link): QR column collapsed, photo and body 1128px")
    add("rail-rules-focus", rail("rules"), "Rail House Rules focused")
    add("house-rules", rail("rules") + ["Select"], "House Rules page")
    # All six rules fit on one page, so there is no scrolled House Rules screen.
    add("rail-fixes-focus", rail("fixes"), "Rail Quick Fixes focused")
    for index in range(12):
        add(f"fixes-detail-{index + 1:02d}", rail("fixes") + ["Select"] + ["Down"] * index, f"Quick Fixes issue {index + 1} with its steps")
    # Build 29: the steps panel grows to y 960 and every issue fits (the
    # longest, issue 12, is 13 lines in a 14-line viewport), so a scrolled frame
    # is the same picture. Scrolling is covered by winter-detail-scrolled.
    # Build 30: an emulator-only fixture fix (stage "longfix") is long enough
    # to overflow, so these prove Right then Down scroll inside a fix.
    add("fixes-long-top", rail("fixes") + ["Select"], "Fixture long fix, list zone: Right Scroll steps keycap and scrollbar", stage="longfix")
    add("fixes-long-detail", rail("fixes") + ["Select", "Right"], "Fixture long fix after Right: detail zone hint Up/Down Scroll", stage="longfix")
    add("fixes-long-scrolled", rail("fixes") + ["Select", "Right", "Down", "Down", "Down"], "Fixture long fix after Right then Down x3: steps scrolled", stage="longfix")
    add("fixes-long-left", rail("fixes") + ["Select", "Right", "Down", "Left"], "Fixture long fix, Left from the steps returns to the fix list", stage="longfix")
    add("rail-book-focus", rail("book"), "Rail Book Direct focused")
    add("book-direct", rail("book") + ["Select"], "Book Direct page")
    add("rail-checkout-focus", rail("checkout"), "Rail Checkout focused")
    add("checkout", rail("checkout") + ["Select"], "Checkout Instructions page")
    add("home-after-idle", rail("book") + ["Select"], "Home after the idle timer fired on Book Direct", wait=IDLE_SECONDS + 3, same_as="book-direct")
    return s


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        path = self.path.split("?", 1)[0]
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


LONG_FIX_PATH = "/data-longfix/guide.json"


def long_fix_guide() -> str:
    """guide.json with one emulator-only fix first whose steps overflow the panel."""
    guide = json.loads((ROOT / "channel/data/guide.json").read_text(encoding="utf-8"))
    steps = []
    for issue in guide.get("troubleshooting") or []:
        steps += issue.get("steps") or []
    guide["troubleshooting"].insert(0, {"issue": "Emulator fixture: long steps", "steps": steps[:14]})
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


def launch(stage: Path, keys: list[str]) -> None:
    stop()
    for f in (LOG, SNAP):
        if f.exists():
            f.unlink()
    tmux("new-session", "-d", "-s", SESSION, "-x", "200", "-y", "50", "-c", str(WORK))
    link = f" --deep-link emuKeys={'-'.join(keys)}" if keys else ""
    cmd = (
        f"export BRS_NO_UPDATE_CHECK=1 BRS_ECP_PORT={PORT} NODE_PATH={NODE_PATH}; "
        f"{CLI} --root {stage} --snapshot {SNAP} --log {LOG} --colors 0{link}"
    )
    tmux("send-keys", "-t", f"{SESSION}:0.0", cmd, "C-m")
    wait_log("zone=prompt", 60)
    if keys:
        wait_log("emu keys done", 60)


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


def launch_retrying(stage, keys) -> None:
    # brs-node sometimes stalls before the key timer runs; a fresh process fixes it.
    for attempt in range(3):
        try:
            launch(stage, keys)
            return
        except RuntimeError as err:
            if "did not log" not in str(err) or attempt == 2:
                raise
            print(f"retry    launch stalled: {err}", flush=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    build_fixtures()
    stages = {"key": build_stage("key", FAKE_KEY), "nokey": build_stage("nokey", ""), "longfix": build_stage("longfix", FAKE_KEY)}
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
                    launch_retrying(stages[item["stage"]], item["keys"])
                    time.sleep(float(os.environ.get("EMU_SETTLE", "12")) + item["wait"])
                    if not item["need"] or qr_ready(item["need"]) or tries >= 4:
                        break
                if item["need"]:
                    note = f"qr ready after {tries} launch(es)" if qr_ready(item["need"]) else f"qr not ready after {tries} launches"
                data = snapshot()
                digest = hashlib.sha256(data).hexdigest()
                (OUT / f"{item['slug']}.png").write_bytes(data)
                (OUT / f"{item['slug']}.log").write_text(log_text(), encoding="utf-8")
                if digest in seen and seen[digest] == item["same_as"]:
                    status, note = "captured", f"expected: same pixels as {seen[digest]}"
                elif digest in seen:
                    status, note = "fail", f"same pixels as {seen[digest]}"
                else:
                    seen[digest] = item["slug"]
                    status = "captured"
                errors = [l for l in log_text().splitlines() if "error" in l.lower() and "Eaglewood" in l]
                if errors:
                    status, note = "fail", "; ".join(errors[:2])
            except Exception as err:  # keep going; the row records it
                status, note = "fail", str(err).splitlines()[0]
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

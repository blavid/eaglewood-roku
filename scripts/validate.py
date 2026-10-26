#!/usr/bin/env python3
"""Check the manifest, image sizes, greeting rules, secret handling, and zip."""

from __future__ import annotations

import re
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from greeting import FONT_SIZES, build_greeting, sanitize_name_part, wrap_by_width  # noqa: E402

MANIFEST = ROOT / "channel" / "manifest"
IMAGES = ROOT / "channel" / "images"
SCENE_BRS = ROOT / "channel" / "components" / "MainScene.brs"
RULES_BRS = ROOT / "channel" / "components" / "GuestRules.brs"
TASK_BRS = ROOT / "channel" / "components" / "GuestTask.brs"
CONFIG_BRS = ROOT / "channel" / "components" / "GuestConfig.brs"
ZIP_PATH = ROOT / "dist" / "eaglewood.zip"
LIMIT = 4 * 1024 * 1024
ORIGIN = "https://sunrivertownhome.com/tv/"

REQUIRED = {
    "title": "Eaglewood",
    "major_version": "1",
    "minor_version": "0",
    "build_version": "5",
    "mm_icon_focus_fhd": "pkg:/images/icon_fhd.jpg",
    "mm_icon_focus_hd": "pkg:/images/icon_hd.jpg",
    "splash_screen_fhd": "pkg:/images/splash_fhd.jpg",
    "splash_screen_hd": "pkg:/images/splash_hd.jpg",
    "splash_screen_sd": "pkg:/images/splash_sd.jpg",
    "ui_resolutions": "fhd",
    "rsg_version": "1.3",
    "network_not_required": "1",
    "supports_input_launch": "1",
    "splash_min_time": "0",
}

IMAGE_SPECS = {
    "background.jpg": (1920, 1080),
    "splash_fhd.jpg": (1920, 1080),
    "splash_hd.jpg": (1280, 720),
    "splash_sd.jpg": (720, 480),
    "icon_fhd.jpg": (540, 405),
    "icon_hd.jpg": (290, 218),
    "scrim.png": (4, 1080),
}

GREETING_CASES = [
    ("", "", "Welcome to Eaglewood"),
    ("   ", "", "Welcome to Eaglewood"),
    ("Alex", "", "Welcome, Alex"),
    ("Alex", "Rivera", "Welcome, Alex Rivera"),
    ("Alex", "R2", "Welcome, Alex"),
    ("R2", "Rivera", "Welcome to Eaglewood"),
    ("Mary-Jane", "O'Brien", "Welcome, Mary-Jane O'Brien"),
    ("José", "García", "Welcome, José García"),
    ("Ann  Marie", "van  Horn", "Welcome, Ann Marie van Horn"),
    ("St. James", "Park", "Welcome, St. James Park"),
    ("Alex123", "Lee", "Welcome to Eaglewood"),
    ("A" * 40, "Lee", "Welcome, " + ("A" * 32) + " Lee"),
    (None, "Lee", "Welcome to Eaglewood"),
]


def fail(message: str) -> None:
    print(f"FAIL {message}")
    raise SystemExit(1)


def print_lines(path: Path) -> list[str]:
    lines = []
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped.startswith("print "):
            lines.append(stripped)
    return lines


def check_debug_prints(path: Path, required: list[str]) -> None:
    lines = print_lines(path)
    for line in lines:
        if not line.startswith('print "Eaglewood:'):
            fail(f"debug print must start with Eaglewood: {path.name}: {line}")
        if "GuestPathKey()" in line:
            fail(f"debug print must not read the path key in {path.name}")
    for needle in required:
        if not any(needle in line for line in lines):
            fail(f"{path.name} is missing a debug print containing {needle!r}")


def parse_manifest() -> dict[str, str]:
    text = MANIFEST.read_text(encoding="utf-8")
    if not text.endswith("\n"):
        fail("manifest must end with a newline")
    if "\r" in text:
        fail("manifest must use LF line endings")
    values: dict[str, str] = {}
    for line in text.splitlines():
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            fail(f"manifest line is not name=value: {line}")
        key, value = line.split("=", 1)
        values[key] = value
    return values


def check_manifest(values: dict[str, str]) -> None:
    for key, expected in REQUIRED.items():
        if values.get(key) != expected:
            fail(f"manifest {key}={values.get(key)!r}, expected {expected!r}")
    if "roku" in values["title"].lower():
        fail("title must not contain Roku")
    for key, uri in values.items():
        if not uri.startswith("pkg:/"):
            continue
        path = ROOT / "channel" / uri.removeprefix("pkg:/")
        if not path.is_file():
            fail(f"{key} points at missing {path}")


def check_images() -> None:
    from PIL import Image

    for name, size in IMAGE_SPECS.items():
        path = IMAGES / name
        with Image.open(path) as image:
            if image.size != size:
                fail(f"{name} is {image.size}, expected {size}")
            if name == "scrim.png" and image.mode != "RGBA":
                fail(f"scrim mode is {image.mode}")
            if name != "scrim.png" and image.mode not in ("RGB", "L"):
                fail(f"{name} mode is {image.mode}; icons and photos must be opaque")


def channel_text_files() -> list[Path]:
    files: list[Path] = []
    for path in (ROOT / "channel").rglob("*"):
        if not path.is_file() or path.suffix.lower() in {".jpg", ".png", ".jpeg"}:
            continue
        if path.name == "secrets.brs":
            continue
        files.append(path)
    return files


def check_greeting_rules() -> None:
    rules = RULES_BRS.read_text(encoding="utf-8")
    if f"return [{', '.join(str(size) for size in FONT_SIZES)}]" not in rules:
        fail("BrightScript font ladder does not match scripts/greeting.py")
    if "function NamePartLimit()" not in rules or "return 32" not in rules:
        fail("name parts must be capped at 32 characters")
    for first, last, expected in GREETING_CASES:
        actual = build_greeting(first, last)
        if actual != expected:
            fail(f"greeting {(first, last)!r} -> {actual!r}, expected {expected!r}")
    if build_greeting("Alex", "Lee", current=False) != "Welcome to Eaglewood":
        fail("a stay that is not current must use the fallback greeting")
    if sanitize_name_part("O\u2019Brien") != "O'Brien":
        fail("curly apostrophe was not normalized")
    wrapped = wrap_by_width("hello world", 50, 10)
    if wrapped != ["hello", "world"]:
        fail(f"wrap on space returned {wrapped!r}")


def check_greeting_draws() -> None:
    xml = (ROOT / "channel" / "components" / "MainScene.xml").read_text(encoding="utf-8")
    source = SCENE_BRS.read_text(encoding="utf-8")
    if 'uri="font:' in xml:
        fail("a Font uri cannot load a system font; the label draws no glyphs")
    if 'font="font:LargeBoldSystemFont"' not in xml:
        fail("greeting Label must set font:LargeBoldSystemFont")
    if xml.find('id="background"') > xml.find('id="greeting"'):
        fail("greeting Label must come after the background Poster")
    if 'width="1760"' not in xml or 'wrap="true"' not in xml or 'maxLines="2"' not in xml:
        fail("greeting Label must wrap to two lines inside 1760px")
    if 'm.greeting.font = "font:LargeBoldSystemFont"' not in source:
        fail("init must select the system font in BrightScript")
    if "m.greeting.text = text" not in source:
        fail("greeting text must be assigned on the label")
    if "Eaglewood: greeting = " not in source:
        fail("debug port must print the greeting")
    if "sub init()" not in source or source.find("ShowGreeting(FallbackGreeting())") > source.find("end sub"):
        fail("init() must show the fallback greeting before the first end sub")
    check_debug_prints(
        SCENE_BRS,
        [
            "Eaglewood: greeting = ",
            "Eaglewood: ui = ",
            "Eaglewood: task created",
            "Eaglewood: task started",
            "Eaglewood: relaunch",
            "skip reason=",
            "generation missing",
        ],
    )


def check_guest_fetch() -> None:
    task = TASK_BRS.read_text(encoding="utf-8")
    config = CONFIG_BRS.read_text(encoding="utf-8")
    rules = RULES_BRS.read_text(encoding="utf-8")
    if 'SetCertificatesFile("common:/certs/ca-bundle.crt")' not in task:
        fail("guest fetch must set the CA bundle")
    if "InitClientCertificates()" not in task:
        fail("guest fetch must call InitClientCertificates")
    if "wait(3000, port)" not in task:
        fail("guest fetch timeout must be 3 seconds")
    if "AsyncGetToString" not in task or "AsyncCancel" not in task:
        fail("guest fetch must use one async request and cancel it on timeout")
    if "EnableEncodings(true)" not in task or "RetainBodyOnError(true)" not in task:
        fail("guest fetch must decode gzip and keep an error body for the log")
    if "ReadGeneration()" not in task:
        fail("guest fetch must re-read generation before publishing the result")
    main = (ROOT / "channel" / "source" / "main.brs").read_text(encoding="utf-8")
    if "PrepareGuestCertificates()" not in main or 'SetCertificatesFile("common:/certs/ca-bundle.crt")' not in main:
        fail("main thread must initialize the HTTPS certificate bundle")
    check_debug_prints(
        TASK_BRS,
        [
            "key loaded",
            "url = ",
            "request sent",
            "response code=",
            "failure reason=",
            "snippet=",
            "parse ok=",
            "checkout decision=",
            "skip reason=",
            "RedactSecret(",
        ],
    )
    if print_lines(CONFIG_BRS) or print_lines(RULES_BRS):
        fail("guest config and name rules must not print")
    if task.count(ORIGIN) or rules.count(ORIGIN):
        fail("the guest origin belongs only in GuestConfig.brs")
    if config.count(ORIGIN) != 1:
        fail("GuestConfig.brs must contain the guest origin once")
    origin_hits = []
    for path in channel_text_files():
        hits = path.read_text(encoding="utf-8", errors="replace").count(ORIGIN)
        if hits:
            origin_hits.append((path, hits))
    if origin_hits != [(CONFIG_BRS, 1)]:
        fail(f"guest origin appears outside GuestConfig.brs: {origin_hits}")
    if "GuestPathKey()" not in config or "GuestStubUrl()" not in config:
        fail("the live URL must be built from the generated key and optional stub")
    task_xml = (ROOT / "channel" / "components" / "GuestTask.xml").read_text(encoding="utf-8")
    if "pkg:/components/secrets.brs" not in task_xml:
        fail("GuestTask must include secrets.brs so the path key is in task scope")
    if 'extends="Task"' not in task_xml:
        fail("guest fetch must run on a Task node")


def check_secret_file_is_untracked() -> None:
    ignore = (ROOT / ".gitignore").read_text(encoding="utf-8")
    if "channel/components/secrets.brs" not in ignore:
        fail(".gitignore must exclude channel/components/secrets.brs")
    result = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "check_tracked_guest_key.py")],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        fail(detail or "tracked guest-key check failed")


def check_no_secrets() -> None:
    banned = re.compile(r"\b(?:\d{3}[-. ]\d{3}[-. ]\d{4}|\d{16}|WIFI_PASSWORD|DOOR_CODE|HOST_CONTACT)\b")
    for path in channel_text_files():
        text = path.read_text(encoding="utf-8", errors="replace")
        found = banned.search(text)
        if found:
            fail(f"unexpected sensitive token {found.group(0)!r} in {path}")


def check_zip() -> None:
    if not ZIP_PATH.is_file():
        print("skip zip (dist/eaglewood.zip not built)")
        return
    size = ZIP_PATH.stat().st_size
    if size > LIMIT:
        fail(f"zip is {size} bytes, over 4 MB")
    with zipfile.ZipFile(ZIP_PATH) as archive:
        names = archive.namelist()
    if "manifest" not in names:
        fail("zip is missing manifest at the archive root")
    if "components/secrets.brs" not in names:
        fail("zip is missing components/secrets.brs")
    if any(name.startswith("/") or name.startswith("\\") or ".." in name.split("/") for name in names):
        fail(f"zip has unsafe entry names: {names}")
    if any(name.startswith("channel/") for name in names):
        fail("zip wraps the channel in an extra folder")
    print(f"zip {size} bytes, {len(names)} entries")


def main() -> None:
    check_manifest(parse_manifest())
    check_images()
    check_greeting_rules()
    check_greeting_draws()
    check_guest_fetch()
    check_secret_file_is_untracked()
    check_no_secrets()
    check_zip()
    print("validate ok")


if __name__ == "__main__":
    main()

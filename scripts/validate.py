#!/usr/bin/env python3
"""Check the manifest, image sizes, greeting rules, and optional package zip."""

from __future__ import annotations

import re
import sys
import zipfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from greeting import NAME_PATTERN, build_greeting, sanitize_first_name  # noqa: E402

MANIFEST = ROOT / "channel" / "manifest"
IMAGES = ROOT / "channel" / "images"
SCENE_BRS = ROOT / "channel" / "components" / "MainScene.brs"
ZIP_PATH = ROOT / "dist" / "eaglewood.zip"
LIMIT = 4 * 1024 * 1024

REQUIRED = {
    "title": "Eaglewood",
    "major_version": "1",
    "minor_version": "0",
    "build_version": "2",
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

GREETING_CASES = {
    "": "Welcome to Eaglewood",
    "   ": "Welcome to Eaglewood",
    "Alex": "Welcome, Alex",
    "Alex Rivera": "Welcome, Alex",
    "Mary-Jane": "Welcome, Mary-Jane",
    "O'Brien": "Welcome, O'Brien",
    "A": "Welcome, A",
    "Alex123": "Welcome to Eaglewood",
    "-Alex": "Welcome to Eaglewood",
    "Alex-": "Welcome to Eaglewood",
    "O'": "Welcome to Eaglewood",
    "José": "Welcome to Eaglewood",
    "A" * 25: "Welcome, " + ("A" * 20),
    "Mary-Jane-ExtraLong!!": "Welcome to Eaglewood",
    "ABCDEFGHIJKLMNOPQRS-X": "Welcome, ABCDEFGHIJKLMNOPQRS",
}


def fail(message: str) -> None:
    print(f"FAIL {message}")
    raise SystemExit(1)


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
    for name, size in IMAGE_SPECS.items():
        path = IMAGES / name
        with Image.open(path) as image:
            if image.size != size:
                fail(f"{name} is {image.size}, expected {size}")
            if name == "scrim.png" and image.mode != "RGBA":
                fail(f"scrim mode is {image.mode}")
            if name != "scrim.png" and image.mode not in ("RGB", "L"):
                fail(f"{name} mode is {image.mode}; icons and photos must be opaque")


def check_greeting_rules() -> None:
    source = SCENE_BRS.read_text(encoding="utf-8")
    match = re.search(r'CreateObject\("roRegex", "(\^\[A-Za-z\].*?)", ""\)', source)
    if match is None:
        fail("could not find the first-name regex in MainScene.brs")
    if match.group(1) != NAME_PATTERN.pattern:
        fail("BrightScript name regex does not match scripts/greeting.py")
    if 'return ""' not in source.split("function GuestFirstName", 1)[1].split("end function", 1)[0]:
        fail("GuestFirstName() must ship empty")
    for raw, expected in GREETING_CASES.items():
        actual = build_greeting(raw)
        if actual != expected:
            fail(f"greeting {raw!r} -> {actual!r}, expected {expected!r}")
    if sanitize_first_name("  Mary-Jane  Extra") != "Mary-Jane":
        fail("first-token trim failed")


def check_greeting_draws() -> None:
    xml = (ROOT / "channel" / "components" / "MainScene.xml").read_text(encoding="utf-8")
    source = SCENE_BRS.read_text(encoding="utf-8")
    if 'uri="font:' in xml:
        fail("a Font uri cannot load a system font; the label draws no glyphs")
    if 'font="font:LargeBoldSystemFont"' not in xml:
        fail("greeting Label must set font:LargeBoldSystemFont")
    if xml.find('id="background"') > xml.find('id="greeting"'):
        fail("greeting Label must come after the background Poster")
    if "m.greeting.font = \"font:LargeBoldSystemFont\"" not in source:
        fail("init must select the system font in BrightScript")
    if "m.greeting.text = text" not in source:
        fail("greeting text must be assigned on the label")
    if "Eaglewood: greeting = " not in source:
        fail("debug port must print the greeting")
    if "sub init()" not in source or source.find("applyGreeting()") > source.find("end sub"):
        fail("init() must apply the greeting before the first end sub")


def check_no_secrets() -> None:
    banned = re.compile(r"\b(?:\d{3}[-. ]\d{3}[-. ]\d{4}|\d{16}|WIFI_PASSWORD|DOOR_CODE|HOST_CONTACT)\b")
    for path in (ROOT / "channel").rglob("*"):
        if not path.is_file() or path.suffix.lower() in {".jpg", ".png", ".jpeg"}:
            continue
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
    check_no_secrets()
    check_zip()
    print("validate ok")


if __name__ == "__main__":
    main()

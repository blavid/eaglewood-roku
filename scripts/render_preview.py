#!/usr/bin/env python3
"""Draw 1920x1080 layout previews from the packaged assets and MainScene.xml.

These are not Roku captures. The typeface is Inter Bold standing in for
font:LargeBoldSystemFont. Positions, colors, and the scrim file come from
the channel.
"""

from __future__ import annotations

import re
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from greeting import build_greeting  # noqa: E402

SCENE = ROOT / "channel" / "components" / "MainScene.xml"
IMAGES = ROOT / "channel" / "images"
OUT = ROOT / "docs" / "screenshots"
ARTIFACTS = Path("/opt/cursor/artifacts/screenshots")
FONT = "/usr/share/fonts/truetype/macos/Inter-Bold.ttf"
BADGE_FONT = "/usr/share/fonts/truetype/macos/Inter-SemiBold.ttf"


def parse_label(xml: str, node_id: str) -> dict[str, str]:
    match = re.search(
        rf'<Label\s+id="{node_id}"([^>]*)>(.*?)</Label>',
        xml,
        re.DOTALL,
    )
    if match is None:
        raise SystemExit(f"label {node_id} not found")
    attrs = dict(re.findall(r'(\w+)="([^"]*)"', match.group(1)))
    font = re.search(r'<Font\b([^>]*)/>', match.group(2))
    if font is None:
        raise SystemExit(f"font for {node_id} not found")
    attrs.update(dict(re.findall(r'(\w+)="([^"]*)"', font.group(1))))
    return attrs


def box(translation: str, width: str, height: str) -> tuple[int, int, int, int]:
    pair = translation.strip("[]").split(",")
    return int(pair[0]), int(pair[1]), int(width), int(height)


def color(value: str) -> tuple[int, int, int, int]:
    hex_digits = value.removeprefix("0x")
    if len(hex_digits) != 8:
        raise SystemExit(f"expected RRGGBBAA color, got {value}")
    red = int(hex_digits[0:2], 16)
    green = int(hex_digits[2:4], 16)
    blue = int(hex_digits[4:6], 16)
    alpha = int(hex_digits[6:8], 16)
    return red, green, blue, alpha


def render(greeting: str, badge: str) -> Image.Image:
    xml = SCENE.read_text(encoding="utf-8")
    greeting_attrs = parse_label(xml, "greeting")
    shadow_attrs = parse_label(xml, "greetingShadow")
    gx, gy, gw, gh = box(greeting_attrs["translation"], greeting_attrs["width"], greeting_attrs["height"])
    sx, sy, sw, sh = box(shadow_attrs["translation"], shadow_attrs["width"], shadow_attrs["height"])
    size = int(greeting_attrs["size"])
    font = ImageFont.truetype(FONT, size)

    background = Image.open(IMAGES / "background.jpg").convert("RGBA")
    scrim = Image.open(IMAGES / "scrim.png").convert("RGBA").resize(background.size, Image.Resampling.BILINEAR)
    image = Image.alpha_composite(background, scrim)
    draw = ImageDraw.Draw(image)
    draw.text(
        (sx + sw / 2, sy + sh / 2),
        greeting,
        font=font,
        fill=color(shadow_attrs["color"]),
        anchor="mm",
    )
    draw.text(
        (gx + gw / 2, gy + gh / 2),
        greeting,
        font=font,
        fill=color(greeting_attrs["color"]),
        anchor="mm",
    )
    draw_badge(image, badge)
    return image.convert("RGB")


def draw_badge(image: Image.Image, label: str) -> None:
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(BADGE_FONT, 22)
    text = "PREVIEW — not a device capture · " + label
    left, top, right, bottom = font.getbbox(text)
    text_w = right - left
    text_h = bottom - top
    x, y = 36, 32
    pad_x, pad_y = 16, 10
    rect = (x, y, x + text_w + pad_x * 2, y + text_h + pad_y * 2)
    draw.rounded_rectangle(rect, radius=8, fill=(245, 196, 81, 235))
    draw.text((x + pad_x, y + pad_y - top), text, font=font, fill=(26, 20, 12, 255))


def save(image: Image.Image, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    image.save(path, format="JPEG", quality=92, optimize=True, progressive=False, subsampling=0)
    shutil.copyfile(path, ARTIFACTS / name)
    print(f"{path} {path.stat().st_size} bytes")


def main() -> None:
    save(render(build_greeting(""), "fallback greeting"), "welcome-fallback-preview.jpg")
    save(
        render(build_greeting("Mary-Jane"), 'named greeting "Mary-Jane"'),
        "welcome-named-preview.jpg",
    )


if __name__ == "__main__":
    main()

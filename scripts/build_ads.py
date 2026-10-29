#!/usr/bin/env python3
"""Build 34: render the lower-left Book Direct ads (one full-bleed PNG each).

Each ad is 776x324 (2x the 388x162 on-screen slot) with the text baked in:
house photo, "Book direct & save" / "up to about 10% less", the site QR and
sunrivertownhome.com under the QR in a second palette color. Photos are the
house photos from the site (/workspace/bookdirect/site). Free tools only:
Pillow + qrcode. The list the channel rotates is channel/data/ads.json.
"""
from __future__ import annotations
import json, sys
from pathlib import Path
import qrcode
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
PHOTOS = Path(sys.argv[1] if len(sys.argv) > 1 else "/workspace/bookdirect/site")
W, H = 776, 324
SITE = "https://sunrivertownhome.com"
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
ADS = [
    {"id": "living", "photo": "living-room-1.jpg", "bg": (27, 42, 68), "accent": (242, 169, 59)},
    {"id": "exterior", "photo": "exterior-front-1.jpg", "bg": (32, 58, 46), "accent": (232, 194, 122)},
    {"id": "kitchen", "photo": "kitchen-dining.jpg", "bg": (58, 38, 26), "accent": (242, 169, 59)},
]

def qr_img(size: int) -> Image.Image:
    q = qrcode.QRCode(border=2, box_size=10, error_correction=qrcode.constants.ERROR_CORRECT_M)
    q.add_data(SITE); q.make(fit=True)
    return q.make_image(fill_color="black", back_color="white").convert("RGB").resize((size, size), Image.NEAREST)

def render(ad: dict) -> Image.Image:
    im = Image.new("RGB", (W, H), ad["bg"])
    photo = Image.open(PHOTOS / ad["photo"]).convert("RGB")
    pw = 300
    ratio = max(pw / photo.width, H / photo.height)
    photo = photo.resize((int(photo.width * ratio) + 1, int(photo.height * ratio) + 1), Image.LANCZOS)
    left = (photo.width - pw) // 2; top = (photo.height - H) // 2
    im.paste(photo.crop((left, top, left + pw, top + H)), (0, 0))
    # fade the photo's right edge into the panel color
    fade = Image.new("L", (W, H), 0); d = ImageDraw.Draw(fade)
    for x in range(200, pw):
        d.line([(x, 0), (x, H)], fill=int(255 * (x - 200) / (pw - 200)))
    d.rectangle([pw, 0, W, H], fill=255)
    im = Image.composite(Image.new("RGB", (W, H), ad["bg"]), im, fade)
    dr = ImageDraw.Draw(im)
    qs = 196
    qx, qy = W - qs - 24, 20
    im.paste(qr_img(qs), (qx, qy))
    tx = 262; tw = qx - tx - 18
    f1 = ImageFont.truetype(BOLD, 36); f2 = ImageFont.truetype(REG, 28); f3 = ImageFont.truetype(BOLD, 24)
    dr.text((tx, 40), "Book direct", font=f1, fill=(255, 255, 255))
    dr.text((tx, 84), "& save", font=f1, fill=(255, 255, 255))
    dr.text((tx, 150), "up to about", font=f2, fill=(213, 219, 232))
    dr.text((tx, 186), "10% less", font=f2, fill=(213, 219, 232))
    dom = "sunrivertownhome.com"
    dw = dr.textlength(dom, font=f3)
    dx = min(qx + qs / 2 - dw / 2, W - 16 - dw)
    dr.text((dx, qy + qs + 30), dom, font=f3, fill=ad["accent"])
    assert tx + max(dr.textlength(s, font=f) for s, f in [("Book direct", f1), ("& save", f1), ("up to about", f2), ("10% less", f2)]) <= qx - 8
    return im

def main() -> None:
    entries = []
    for ad in ADS:
        out = ROOT / "channel" / "images" / f"ad-{ad['id']}.png"
        render(ad).save(out, optimize=True)
        entries.append({"id": ad["id"], "image": f"pkg:/images/ad-{ad['id']}.png", "alt": "Book direct and save up to about 10% less. sunrivertownhome.com"})
    data = {"version": 1, "rotateSeconds": 50, "fadeSeconds": 1, "ads": entries}
    (ROOT / "channel" / "data" / "ads.json").write_text(json.dumps(data, indent=2) + "\n")
    print("wrote", len(entries), "ads")

if __name__ == "__main__":
    main()

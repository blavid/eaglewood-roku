#!/usr/bin/env python3
"""Build 34: render the lower-left Book Direct ads (one full-bleed PNG each).

Each ad is 438x214, drawn 1:1 in the on-screen slot, with the text baked in:
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
W, H = 438, 214
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
    """Build 35: baked 1:1 at 438x214 (FHD x 96-534, y 758-972).

    Pixel review: headline 30px bold #FFFFFF, subline 24px #F4EFE3, domain
    24px bold #F2A93B, QR >= 150px on white. The photo is full bleed under a
    panel-colored scrim so the text keeps contrast."""
    photo = Image.open(PHOTOS / ad["photo"]).convert("RGB")
    ratio = max(W / photo.width, H / photo.height)
    photo = photo.resize((int(photo.width * ratio) + 1, int(photo.height * ratio) + 1), Image.LANCZOS)
    left = (photo.width - W) // 2; top = (photo.height - H) // 2
    im = photo.crop((left, top, left + W, top + H))
    # Scrim: light over the photo's left third, solid behind text and QR.
    scrim = Image.new("L", (W, H), 0); d = ImageDraw.Draw(scrim)
    for x in range(W):
        d.line([(x, 0), (x, H)], fill=int(150 + 85 * min(1.0, x / 200)))
    d.rectangle([0, 166, W, H], fill=225)
    im = Image.composite(Image.new("RGB", (W, H), ad["bg"]), im, scrim)
    dr = ImageDraw.Draw(im)
    qs = 152
    qx, qy = W - qs - 14, 10
    im.paste(qr_img(qs), (qx, qy))
    tx = 16
    f1 = ImageFont.truetype(BOLD, 30); f2 = ImageFont.truetype(REG, 24); f3 = ImageFont.truetype(BOLD, 24)
    dr.text((tx, 14), "Book direct", font=f1, fill=(255, 255, 255))
    dr.text((tx, 52), "& save", font=f1, fill=(255, 255, 255))
    dr.text((tx, 98), "up to about", font=f2, fill=(0xF4, 0xEF, 0xE3))
    dr.text((tx, 128), "10% less", font=f2, fill=(0xF4, 0xEF, 0xE3))
    dom = "sunrivertownhome.com"
    dw = dr.textlength(dom, font=f3)
    dx = W - 14 - dw
    dr.text((dx, 174), dom, font=f3, fill=(0xF2, 0xA9, 0x3B))
    widest = max(dr.textlength(t, font=f) for t, f in [("Book direct", f1), ("& save", f1), ("up to about", f2), ("10% less", f2)])
    assert tx + widest <= qx - 8, "headline runs into the QR"
    assert dx >= tx and 174 + 30 <= H, "domain does not fit"
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, W - 1, H - 1], 12, fill=255)
    out = im.convert("RGBA"); out.putalpha(mask)
    return out

def shadow() -> Image.Image:
    pad = 24
    sh = Image.new("RGBA", (W + pad * 2, H + pad * 2), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([pad, pad + 6, pad + W, pad + H + 6], 12, fill=(0, 0, 0, 150))
    return sh.filter(ImageFilter.GaussianBlur(10))

def main() -> None:
    shadow().save(ROOT / "channel" / "images" / "ad-shadow.png", optimize=True)
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

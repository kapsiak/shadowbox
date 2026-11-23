"""Bakes Outfit's digits into a distance-field strip for the walls: view/digits.png.
Usage: python3 tools/make_digits.py (needs Pillow, numpy and scipy).

Slot i of 16 (each SLOT px square) holds digit i; slots 10-15 are free for later glyphs.
Every channel holds the distance to the glyph's edge, 0.5 on the edge and rising inside,
with SPREAD px of slot space mapped to 0.5."""
import pathlib
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import distance_transform_edt

SLOT = 64
SLOTS = 16
SS = 8
SPREAD = 8
HEIGHT = 0.62
ROOT = pathlib.Path(__file__).resolve().parent.parent
FONT = ROOT / "assets" / "fonts" / "Outfit-Medium.ttf"
OUT = ROOT / "view" / "digits.png"


def glyph(ch, font):
    big = SLOT * SS
    img = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = d.textbbox((0, 0), ch, font=font)
    d.text(((big - (x1 - x0)) / 2 - x0, (big - (y1 - y0)) / 2 - y0), ch, font=font, fill=255)
    inside = np.array(img) > 127
    signed = distance_transform_edt(inside) - distance_transform_edt(~inside)
    field = np.clip(0.5 + signed / (2 * SPREAD * SS), 0, 1)
    small = field.reshape(SLOT, SS, SLOT, SS).mean(axis=(1, 3))
    return (small * 255 + 0.5).astype(np.uint8)


def main():
    probe = ImageFont.truetype(str(FONT), 100)
    x0, y0, x1, y1 = probe.getbbox("0123456789")
    font = ImageFont.truetype(str(FONT), int(100 * HEIGHT * SLOT * SS / (y1 - y0)))
    strip = np.zeros((SLOT, SLOT * SLOTS), np.uint8)
    for i in range(10):
        strip[:, i * SLOT:(i + 1) * SLOT] = glyph(str(i), font)
    rgba = np.dstack([strip] * 4)
    Image.fromarray(rgba, "RGBA").save(OUT)


main()

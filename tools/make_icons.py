"""Generates the HUD icon images into ui/icons/. Usage: python3 tools/make_icons.py"""
import math
import pathlib
from PIL import Image, ImageDraw

SIZE = 96
SS = 4
STROKE = 7
OUT = pathlib.Path(__file__).resolve().parent.parent / "ui" / "icons"
WHITE = (255, 255, 255, 255)


def canvas():
    img = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def save(img, name):
    img.resize((SIZE, SIZE), Image.LANCZOS).save(OUT / f"{name}.png")


def s(v):
    return v * SS


def line(d, points, width=STROKE):
    pts = [(s(x), s(y)) for x, y in points]
    d.line(pts, fill=WHITE, width=s(width), joint="curve")
    r = s(width) / 2
    for x, y in (pts[0], pts[-1]):
        d.ellipse((x - r, y - r, x + r, y + r), fill=WHITE)


def arrowhead(d, tip, angle, length=16, spread=0.55):
    pts = [tip]
    for sign in (-1, 1):
        a = angle + math.pi + sign * spread
        pts.append((tip[0] + length * math.cos(a), tip[1] + length * math.sin(a)))
    d.polygon([(s(x), s(y)) for x, y in pts], fill=WHITE)


def arc(d, cx, cy, r, start, end, steps=40):
    pts = [(cx + r * math.cos(math.radians(start + (end - start) * i / steps)),
            cy + r * math.sin(math.radians(start + (end - start) * i / steps))) for i in range(steps + 1)]
    line(d, pts)
    return pts


def curved_arrow(name, mirror=False):
    img, d = canvas()
    pts = arc(d, 50, 58, 26, -10, -190)
    tip, prev = pts[-1], pts[-3]
    arrowhead(d, tip, math.atan2(tip[1] - prev[1], tip[0] - prev[0]), length=20)
    if mirror:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    save(img, name)


def turn(name, mirror=False):
    img, d = canvas()
    line(d, [(48, 22), (48, 74)], width=4)
    steps = 40
    pts = [(48 + 32 * math.cos(math.radians(160 + 230 * i / steps)),
            50 + 14 * math.sin(math.radians(160 + 230 * i / steps))) for i in range(steps + 1)]
    line(d, pts)
    tip, prev = pts[-1], pts[-3]
    arrowhead(d, tip, math.atan2(tip[1] - prev[1], tip[0] - prev[0]), length=18)
    if mirror:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    save(img, name)


def cube_points(c, r):
    top = (c[0], c[1] - r)
    ul, ur = (c[0] - r * 0.87, c[1] - r * 0.5), (c[0] + r * 0.87, c[1] - r * 0.5)
    ll, lr = (c[0] - r * 0.87, c[1] + r * 0.5), (c[0] + r * 0.87, c[1] + r * 0.5)
    bottom = (c[0], c[1] + r)
    return {"top": [top, ur, c, ul], "front": [ul, c, bottom, ll], "side": [c, ur, lr, bottom]}


def cube(d, c, r, alphas):
    """An isometric cube whose faces are filled at the given alphas, with crisp edges."""
    faces = cube_points(c, r)
    for face, alpha in alphas.items():
        d.polygon([(s(x), s(y)) for x, y in faces[face]], fill=(255, 255, 255, alpha))
    t, ur, c_, ul = faces["top"]
    _, _, lr, bottom = faces["side"]
    _, _, _, ll = faces["front"]
    line(d, [t, ur, lr, bottom, ll, ul, t], width=4)
    line(d, [ul, c_, ur], width=4)
    line(d, [c_, bottom], width=4)


# Where each view's camera looks from, as the face it sees and a unit direction on screen
# from that face's centre out towards the camera.
VIEWS = {
    "front": ((58, 40), (-0.87, 0.5)),
    "side": ((38, 40), (0.87, 0.5)),
    "top": ((48, 60), (0.0, -1.0)),
}


def view_cube(name, face):
    img = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    if face is None:
        cube(d, (48, 49), 36, {"top": 255, "side": 150, "front": 80})
        save(img, name)
        return
    centre, (dx, dy) = VIEWS[face]
    r = 27
    cube(d, centre, r, {k: 255 if k == face else 60 for k in ("top", "front", "side")})
    pts = cube_points(centre, r)[face]
    fx, fy = sum(p[0] for p in pts) / 4, sum(p[1] for p in pts) / 4
    tip = (fx + dx * 15, fy + dy * 15)
    line(d, [(fx + dx * 42, fy + dy * 42), (tip[0] + dx * 10, tip[1] + dy * 10)], width=7)
    arrowhead(d, tip, math.atan2(-dy, -dx), length=19, spread=0.6)
    save(img, name)


def straight_arrow(name, direction):
    img, d = canvas()
    line(d, [(48, 76), (48, 30)])
    arrowhead(d, (48, 18), -math.pi / 2, length=22, spread=0.6)
    line(d, [(26, 84), (70, 84)], width=5)
    if direction == "down":
        img = img.transpose(Image.FLIP_TOP_BOTTOM)
    save(img, name)


def tip_away():
    img, d = canvas()
    pts = arc(d, 48, 54, 26, 180, 360 - 10)
    tip, prev = pts[-1], pts[-3]
    arrowhead(d, (tip[0], tip[1] + 2), math.atan2(tip[1] - prev[1], tip[0] - prev[0]) + 0.3)
    line(d, [(30, 70), (66, 70)], width=5)
    save(img, "tip_away")


def roll():
    img, d = canvas()
    d.rounded_rectangle((s(34), s(34), s(62), s(62)), radius=s(5), outline=WHITE, width=s(5))
    pts = arc(d, 48, 48, 30, 120, 400)
    tip, prev = pts[-1], pts[-3]
    arrowhead(d, tip, math.atan2(tip[1] - prev[1], tip[0] - prev[0]))
    save(img, "roll_right")


def stow():
    img, d = canvas()
    line(d, [(48, 16), (48, 52)])
    arrowhead(d, (48, 62), math.pi / 2, length=20, spread=0.6)
    line(d, [(18, 56), (18, 80), (78, 80), (78, 56)], width=6)
    save(img, "stow")


def menu():
    img, d = canvas()
    for y in (30, 48, 66):
        line(d, [(24, y), (72, y)])
    save(img, "menu")


def next_arrow():
    img, d = canvas()
    line(d, [(22, 48), (66, 48)])
    arrowhead(d, (78, 48), 0, length=24, spread=0.62)
    save(img, "next")


def back_arrow():
    img, d = canvas()
    line(d, [(30, 48), (74, 48)])
    arrowhead(d, (18, 48), math.pi, length=24, spread=0.62)
    save(img, "back")


def chevron(name, mirror=False):
    """A chevron pointing right, or left when mirrored: turns a page."""
    img, d = canvas()
    line(d, [(38, 24), (62, 48), (38, 72)], width=9)
    if mirror:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    save(img, name)


def check():
    img, d = canvas()
    line(d, [(22, 50), (40, 68), (74, 30)], width=9)
    save(img, "check")


def lock():
    img, d = canvas()
    d.rounded_rectangle((s(24), s(44), s(72), s(80)), radius=s(7), fill=WHITE)
    d.arc((s(32), s(18), s(64), s(58)), 180, 360, fill=WHITE, width=s(7))
    line(d, [(32, 38), (32, 46)])
    line(d, [(64, 38), (64, 46)])
    save(img, "lock")


def dot():
    img, d = canvas()
    d.ellipse((s(2), s(2), s(94), s(94)), fill=WHITE)
    save(img, "dot")


def key():
    """A flat key with chamfered corners, like a bevelled cube; also its solid lip. 9-sliced at 30."""
    img, d = canvas()
    lo, hi, c = 4, 92, 18
    d.polygon([(s(x), s(y)) for x, y in ((lo + c, lo), (hi - c, lo), (hi, lo + c), (hi, hi - c), (hi - c, hi), (lo + c, hi), (lo, hi - c), (lo, lo + c))], fill=WHITE)
    save(img, "key")


def mark():
    """The wordmark's mark: the third-angle projection symbol drawn for a block. A square frustum
    seen end on (two nested squares) beside its front view (a trapezoid, narrow end towards the
    squares), on a shared centre line. Twice as wide as tall; the inner square is a separate
    image so it can take the accent colour."""
    w, h = SIZE * 2, SIZE
    ink = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    accent = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    d, a = ImageDraw.Draw(ink), ImageDraw.Draw(accent)
    cy, big, small, stroke = 48, 34, 16, 10
    sq = 52
    d.rectangle((s(sq - big), s(cy - big), s(sq + big), s(cy + big)), outline=WHITE, width=s(stroke))
    a.rectangle((s(sq - small), s(cy - small), s(sq + small), s(cy + small)), fill=WHITE)
    left, right = 112, 180
    trapezoid = [(left, cy - small), (right, cy - big), (right, cy + big), (left, cy + small)]
    d.polygon([(s(x), s(y)) for x, y in trapezoid], outline=WHITE, width=s(stroke))
    for x0, x1 in ((4, 12), (92, 104), (186, 191)):
        d.rectangle((s(x0), s(cy - 1.5), s(x1), s(cy + 1.5)), fill=WHITE)
    ink.resize((w, h), Image.LANCZOS).save(OUT / "mark.png")
    accent.resize((w, h), Image.LANCZOS).save(OUT / "mark_accent.png")
    return ink, accent


def splash(ink, accent):
    """The web build's loading image: the mark in the interface ink and accent, centred on a clear
    square (the page scales it to fit the canvas, so a square suits both orientations)."""
    side = 1600
    img = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    at = ((side - ink.width) // 2, (side - ink.height) // 2)
    for layer, rgb in ((ink, (33, 33, 38)), (accent, (237, 84, 69))):
        img.paste(Image.new("RGBA", layer.size, rgb + (255,)), at, layer)
    img.save(OUT.parent.parent / "web" / "splash.png")


def app_icon(ink, accent):
    """The desktop app icon: the mark across a light tile with chamfered corners, like the keys."""
    side, cut = 1024, 160
    img = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    ImageDraw.Draw(img).polygon([(cut, 0), (side - cut, 0), (side, cut), (side, side - cut),
                                 (side - cut, side), (cut, side), (0, side - cut), (0, cut)], fill=(233, 231, 227, 255))
    w = int(side * 0.84)
    h = w * ink.height // ink.width
    at = ((side - w) // 2, (side - h) // 2)
    for layer, rgb in ((ink, (33, 33, 38)), (accent, (237, 84, 69))):
        layer = layer.resize((w, h), Image.LANCZOS)
        img.paste(Image.new("RGBA", layer.size, rgb + (255,)), at, layer)
    out = OUT.parent.parent / "assets" / "app_icons"
    save_ico(img, out / "appicon.ico")
    img.save(out / "appicon.icns")


def save_ico(img, path):
    """Bob replaces the Windows exe's icons only with entries of the same size and layout as its
    own: these eight sizes, each an uncompressed 32-bit bitmap with its transparency mask."""
    import struct
    sizes = (16, 24, 32, 48, 64, 96, 128, 256)
    entries = []
    for n in sizes:
        px = img.resize((n, n), Image.LANCZOS).load()
        rows = [px[x, y] for y in reversed(range(n)) for x in range(n)]
        colour = b"".join(struct.pack("4B", b, g, r, a) for r, g, b, a in rows)
        stride = (n + 31) // 32 * 4
        mask = bytearray(stride * n)
        for i, (_, _, _, a) in enumerate(rows):
            if a == 0:
                mask[i // n * stride + i % n // 8] |= 0x80 >> (i % 8)
        header = struct.pack("<IiiHHIIiiII", 40, n, n * 2, 1, 32, 0, len(colour) + len(mask), 0, 0, 0, 0)
        entries.append((n, header + colour + bytes(mask)))
    offset = 6 + 16 * len(entries)
    directory = struct.pack("<HHH", 0, 1, len(entries))
    for n, data in entries:
        directory += struct.pack("<BBBBHHII", n % 256, n % 256, 0, 0, 1, 32, len(data), offset)
        offset += len(data)
    path.write_bytes(directory + b"".join(data for _, data in entries))


def peek():
    """An open eye: hold to see the walls through the pieces."""
    img, d = canvas()
    half, sag = 32, 17
    r = (half * half + sag * sag) / (2 * sag)
    spread = math.degrees(math.asin(half / r))
    arc(d, 48, 48 + r - sag, r, -90 - spread, -90 + spread)
    arc(d, 48, 48 - r + sag, r, 90 - spread, 90 + spread)
    d.ellipse((s(38), s(38), s(58), s(58)), fill=WHITE)
    save(img, "peek")


def rules():
    """A question mark in the interface face, for the Rules list."""
    from PIL import ImageFont
    img, d = canvas()
    font = ImageFont.truetype(str(OUT.parent.parent / "assets" / "fonts" / "Outfit-Bold.ttf"), s(78))
    x0, y0, x1, y1 = d.textbbox((0, 0), "?", font=font)
    d.text(((s(SIZE) - (x1 - x0)) / 2 - x0, (s(SIZE) - (y1 - y0)) / 2 - y0), "?", font=font, fill=WHITE)
    save(img, "rules")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    marks = mark()
    splash(*marks)
    app_icon(*marks)
    menu()
    curved_arrow("undo")
    curved_arrow("redo", mirror=True)
    view_cube("view_front", "front")
    view_cube("view_side", "side")
    view_cube("view_top", "top")
    view_cube("view_iso", None)
    turn("turn_left")
    turn("turn_right", mirror=True)
    tip_away()
    roll()
    straight_arrow("lift", "up")
    straight_arrow("lower", "down")
    stow()
    rules()
    peek()
    next_arrow()
    back_arrow()
    chevron("page_next")
    chevron("page_prev", mirror=True)
    check()
    lock()
    dot()
    key()


if __name__ == "__main__":
    main()

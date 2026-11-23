"""Generates the HUD icon images into ui/icons/. Usage: python3 tools/make_icons.py"""
import math
import pathlib
from PIL import Image, ImageDraw, ImageFilter

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


def cube_points():
    c = (48, 50)
    r = 26
    top = (c[0], c[1] - r)
    ul, ur = (c[0] - r * 0.87, c[1] - r * 0.5), (c[0] + r * 0.87, c[1] - r * 0.5)
    ll, lr = (c[0] - r * 0.87, c[1] + r * 0.5), (c[0] + r * 0.87, c[1] + r * 0.5)
    bottom = (c[0], c[1] + r)
    return c, top, ul, ur, ll, lr, bottom


def view_cube(name, face):
    img, d = canvas()
    c, top, ul, ur, ll, lr, bottom = cube_points()
    faces = {"top": [top, ur, c, ul], "front": [ul, c, bottom, ll], "side": [c, ur, lr, bottom]}
    if face in faces:
        d.polygon([(s(x), s(y)) for x, y in faces[face]], fill=WHITE)
    line(d, [top, ur, lr, bottom, ll, ul, top], width=5)
    line(d, [ul, c, ur], width=5)
    line(d, [c, bottom], width=5)
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


def paper_outline(inset, radius, wobble, seed):
    """Points around a rounded square (96-unit space), pushed in and out a little like a torn edge."""
    import random
    rng = random.Random(seed)
    lo, hi = inset, SIZE - inset
    pts = []
    corners = [(hi - radius, lo + radius, -90), (hi - radius, hi - radius, 0), (lo + radius, hi - radius, 90), (lo + radius, lo + radius, 180)]
    for cx, cy, start in corners:
        for i in range(12):
            a = math.radians(start + 90 * i / 11)
            pts.append((cx + radius * math.cos(a), cy + radius * math.sin(a)))
    out, offset = [], 0.0
    for i, (x, y) in enumerate(pts):
        nx, ny = pts[(i + 1) % len(pts)]
        offset = offset * 0.6 + rng.uniform(-wobble, wobble)
        dx, dy = ny - y, x - nx
        length = math.hypot(dx, dy) or 1
        out.append((s(x + dx / length * offset), s(y + dy / length * offset)))
    return out


def button():
    """A paper card: off-white with a faintly darker, slightly deckled edge. 9-sliced at 30."""
    mask = Image.new("L", (SIZE * SS, SIZE * SS), 0)
    ImageDraw.Draw(mask).polygon(paper_outline(5, 8, 0.7, 7), fill=255)
    soft = mask.filter(ImageFilter.GaussianBlur(s(2.5)))
    shade = soft.point(lambda v: int(232 + 23 * min(1.0, max(0.0, (v / 255 - 0.5) * 2))))
    img = Image.merge("RGBA", (shade, shade, shade, mask))
    save(img, "button")
    shadow = Image.new("L", (SIZE * SS, SIZE * SS), 0)
    ImageDraw.Draw(shadow).polygon(paper_outline(9, 10, 0.0, 7), fill=255)
    shadow = shadow.resize((SIZE, SIZE), Image.LANCZOS).filter(ImageFilter.GaussianBlur(4))
    white = Image.new("L", (SIZE, SIZE), 255)
    Image.merge("RGBA", (white, white, white, shadow)).save(OUT / "button_shadow.png")


def tile():
    """A lacquered tile: a lit top rim, a body darkening a little downward and a shaded foot.
    Greyscale, tinted by the theme. 9-sliced at 30."""
    mask = Image.new("L", (SIZE * SS, SIZE * SS), 0)
    ImageDraw.Draw(mask).rounded_rectangle((s(5), s(5), s(91), s(91)), radius=s(14), fill=255)
    shade = Image.new("L", (SIZE * SS, SIZE * SS), 0)
    sd = ImageDraw.Draw(shade)
    for y in range(SIZE * SS):
        t = y / (SIZE * SS)
        sd.line((0, y, SIZE * SS, y), fill=int(255 * (0.9 - 0.12 * t)))
    rim = Image.new("L", (SIZE * SS, SIZE * SS), 0)
    ImageDraw.Draw(rim).rounded_rectangle((s(5), s(5), s(91), s(91)), radius=s(14), outline=255, width=6)
    top = Image.new("L", (SIZE * SS, SIZE * SS), 0)
    ImageDraw.Draw(top).rectangle((0, 0, SIZE * SS, s(30)), fill=255)
    lit = Image.composite(Image.new("L", shade.size, 255), shade, Image.composite(rim, Image.new("L", rim.size, 0), top))
    foot = Image.new("L", (SIZE * SS, SIZE * SS), 0)
    ImageDraw.Draw(foot).rectangle((0, s(86), SIZE * SS, SIZE * SS), fill=255)
    lit = Image.composite(Image.new("L", shade.size, 150), lit, Image.composite(rim, Image.new("L", rim.size, 0), foot))
    save(Image.merge("RGBA", (lit, lit, lit, mask)), "tile")
    shadow = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(shadow).rounded_rectangle((10, 12, 86, 90), radius=16, fill=255)
    shadow = shadow.filter(ImageFilter.GaussianBlur(5))
    white = Image.new("L", (SIZE, SIZE), 255)
    Image.merge("RGBA", (white, white, white, shadow)).save(OUT / "tile_shadow.png")


def key():
    """A flat key with chamfered corners, like a bevelled cube; also its solid lip. 9-sliced at 30."""
    img, d = canvas()
    lo, hi, c = 4, 92, 18
    d.polygon([(s(x), s(y)) for x, y in ((lo + c, lo), (hi - c, lo), (hi, lo + c), (hi, hi - c), (hi - c, hi), (lo + c, hi), (lo, hi - c), (lo, lo + c))], fill=WHITE)
    save(img, "key")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
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
    next_arrow()
    back_arrow()
    check()
    lock()
    dot()
    button()
    tile()
    key()


if __name__ == "__main__":
    main()

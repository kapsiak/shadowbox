"""Merges overlapping outlines in the game's fonts in place. Defold's distance-field fonts show
seams where a glyph's contours overlap (Outfit's crossbars do). Needs fonttools and
skia-pathops. Usage: python3 tools/merge_font_overlaps.py"""
import pathlib

from fontTools.ttLib import TTFont
from fontTools.ttLib.removeOverlaps import removeOverlaps

FONTS = pathlib.Path(__file__).resolve().parent.parent / "assets" / "fonts"

for path in sorted(FONTS.glob("*.ttf")):
    font = TTFont(path)
    removeOverlaps(font)
    font.save(path)
    print("merged", path.name)

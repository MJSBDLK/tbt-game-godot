#!/usr/bin/env python3
"""Redraw pixel glyphs inside the project's TTF fonts.

The two pixel fonts are third-party TTFs. When a glyph needs to be ours —
NotJamPixel5 shipped a B and an 8 that were the only 4-wide letters in a
3-wide font, with self-crossing outlines that rendered as noise; the 8px
font had no arrow for the StatUp preview's `15 → 17` — the replacement is
drawn HERE as a pixel grid and written straight into the .ttf. Edit a grid,
run the script, done. Godot re-imports on its next launch (or
`godot-4 --headless --import`).

Grid rules: `#` is ink, `.` is empty; rows run top to bottom; the last
`baseline_rows` rows sit below the baseline (the 5px font has exactly one
such row, the lowercase descender). The advance is in pixels; the glyph's
left edge is x = 0.

    python3 tools/fonts/patch_pixel_glyphs.py
"""
import sys
from pathlib import Path

from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[2]

# One entry per font. units_per_px is unitsPerEm / the font's pixel size.
FONTS = {
    "fonts/NotJamPixel5.ttf": {
        "units_per_px": 200,  # 1000 upem, 5 px em
        "glyphs": {
            # 3×4 like every other capital. The filled second row is the
            # font's own "two bowls" mark: D is ##./#.#/#.#/##., 0 is
            # .#./#.#/#.#/.#., and B / 8 are those with the waist pinched.
            "B": {"advance_px": 4, "rows": [
                "##.",
                "###",
                "#.#",
                "##.",
            ]},
            # 8 borrows the descender row (g, p, q and y already live
            # there): two real loops need five rows, and the 4-row version
            # read as a 6.
            "8": {"advance_px": 4, "baseline_rows": 1, "rows": [
                ".#.",
                "#.#",
                ".#.",
                "#.#",
                ".#.",
            ]},
        },
    },
    "fonts/UndeadPixelLight8.ttf": {
        "units_per_px": 128,  # 1024 upem, 8 px em
        "glyphs": {
            # U+2192 RIGHTWARDS ARROW. Shaft on the hyphen's row, one pixel
            # of air on the right like the digits.
            "→": {"advance_px": 6, "rows": [
                "..#..",
                "...#.",
                "#####",
                "...#.",
                "..#..",
            ]},
        },
    },
}


def glyph_from_rows(rows, units_per_px, baseline_rows=0):
    """One clockwise square contour per ink pixel; nonzero fill unions them."""
    pen = TTGlyphPen(None)
    height = len(rows)
    for row_index, row in enumerate(rows):
        for column, cell in enumerate(row):
            if cell != "#":
                continue
            x0 = column * units_per_px
            x1 = x0 + units_per_px
            y0 = (height - baseline_rows - row_index - 1) * units_per_px
            y1 = y0 + units_per_px
            pen.moveTo((x0, y1))
            pen.lineTo((x1, y1))
            pen.lineTo((x1, y0))
            pen.lineTo((x0, y0))
            pen.closePath()
    return pen.glyph()


def glyph_name_for(font, character):
    """The existing glyph name for `character`, or a new uniXXXX one."""
    code = ord(character)
    for table in font["cmap"].tables:
        if table.isUnicode() and code in table.cmap:
            return table.cmap[code], False
    return "uni%04X" % code, True


def patch(font_path, spec):
    font = TTFont(ROOT / font_path)
    for character, glyph in spec["glyphs"].items():
        name, is_new = glyph_name_for(font, character)
        if is_new:
            # The glyph order must know the name BEFORE the outline goes in;
            # the glyf table keeps its own copy of the list.
            order = font.getGlyphOrder() + [name]
            font.setGlyphOrder(order)
            font["glyf"].glyphOrder = order
            for table in font["cmap"].tables:
                if table.isUnicode():
                    table.cmap[ord(character)] = name
        font["glyf"][name] = glyph_from_rows(
            glyph["rows"], spec["units_per_px"], glyph.get("baseline_rows", 0))
        font["hmtx"][name] = (glyph["advance_px"] * spec["units_per_px"], 0)
        print("%s: %s %r -> %s" % (font_path, "added" if is_new else "redrew", character, name))
    font.save(ROOT / font_path)


def main():
    for font_path, spec in FONTS.items():
        patch(font_path, spec)
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Extract move chip colors from Lawrence's mockup image.

Reads the mockup PNG, finds each chip by scanning for row boundaries,
samples 5 pixel locations per chip, and snaps each to the nearest
palette color from the GPL file.

Usage:
    python3 scripts/tools/extract_chip_colors.py <mockup.png>

Output: GDScript-ready color definitions for game_colors.gd
"""

import sys
from pathlib import Path
from PIL import Image

GPL_PATH = Path(__file__).resolve().parents[2] / "art/colors/SpacemanColorPalette_v1.41.gpl"

RAMP_NAMES = [
    "RedViolet", "Magenta", "Violet", "Purple", "Blue", "Azure", "Cyan",
    "Teal", "Green", "Chartreuse", "Yellow", "YellowOrange", "Orange",
    "PoppyRed", "Red", "Gray", "Eggshell", "TealGray", "S1", "S2",
    "Straw", "Tan2", "Tan1", "Eggplant", "StylizedVillage",
    "PastelleSunset", "PastelleSky", "StylizedSunset", "DappledCool",
    "WarmNature", "WarmBackground", "Straw2",
]

# Elemental types in the order they appear top-to-bottom in the mockup
CHIP_TYPES = [
    "AIR", "CHIVALRIC", "COLD", "ELECTRIC", "FIRE", "GENTRY", "GRAVITY",
    "HERALDIC", "OCCULT", "PLANT", "ROBO", "SIMPLE", "VOID", "OBSIDIAN",
]


def load_palette():
    """Load GPL palette into dict of {(ramp_name, index): (r, g, b)}."""
    colors = []
    with open(GPL_PATH) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith(("GIMP", "Name:", "Columns:", "Channels:", "#")):
                continue
            parts = line.split()
            if len(parts) >= 3 and parts[0].isdigit():
                r, g, b = int(parts[0]), int(parts[1]), int(parts[2])
                colors.append((r, g, b))

    palette = {}
    for i, (r, g, b) in enumerate(colors):
        ramp_idx = i // 11
        shade = i % 11
        if ramp_idx < len(RAMP_NAMES):
            palette[(RAMP_NAMES[ramp_idx], shade)] = (r, g, b)
    return palette


def nearest_palette(rgb, palette):
    """Find the nearest palette entry by Euclidean distance."""
    best_dist = float("inf")
    best_key = None
    r, g, b = rgb
    for key, (pr, pg, pb) in palette.items():
        dist = (r - pr) ** 2 + (g - pg) ** 2 + (b - pb) ** 2
        if dist < best_dist:
            best_dist = dist
            best_key = key
    ramp, shade = best_key
    pr, pg, pb = palette[best_key]
    hex_sampled = f"#{r:02x}{g:02x}{b:02x}"
    hex_palette = f"#{pr:02x}{pg:02x}{pb:02x}"
    exact = " EXACT" if best_dist == 0 else f" (dist={best_dist:.0f}, palette={hex_palette})"
    return ramp, shade, hex_sampled, exact


def _color_dist(a, b):
    return sum((x - y) ** 2 for x, y in zip(a, b))


def find_chip_rows(img):
    """Scan to find chip start/end Y positions.

    Layout: 10px left margin, 6px border, then chip content.
    Scan at x=13 (inside border) to distinguish chip rows from
    12px negative-space gaps (which match the panel background).
    """
    w, h = img.size
    # Sample the panel background color from top-left corner
    bg_color = img.getpixel((2, 2))[:3]

    chips = []
    in_chip = False
    start_y = 0

    for y in range(h):
        px = img.getpixel((13, y))[:3]
        is_gap = _color_dist(px, bg_color) < 100

        if not in_chip and not is_gap:
            in_chip = True
            start_y = y
        elif in_chip and is_gap:
            in_chip = False
            chips.append((start_y, y - 1))

    if in_chip:
        chips.append((start_y, h - 1))

    return chips


def sample_chip(img, y_start, y_end):
    """Sample 5 color regions from a chip.

    Layout per chip (horizontal):
      10px margin | 6px border | foreground fill (with text/glow) | background fill | 6px border | margin

    The diagonal goes from upper-right to lower-left, so:
      - Top-left corner (inside border) = always foreground
      - Bottom-right corner (inside border) = always background

    Returns dict with keys: foreground, background, border, font_color, glow_color
    """
    w = img.size[0]
    mid_y = (y_start + y_end) // 2
    chip_h = y_end - y_start
    inner_left = 16  # past 10px margin + 6px border
    inner_right = w - 16

    # Border: sample from the border zone (x=11, well inside the 6px border band)
    border = img.getpixel((11, mid_y))[:3]

    # Foreground: top-left corner of inner area (always foreground side of diagonal)
    fg_x = inner_left + 4
    fg_y = y_start + 8  # just inside top border
    foreground = img.getpixel((fg_x, fg_y))[:3]

    # Background: bottom-right corner of inner area (always background side of diagonal)
    bg_x = inner_right - 4
    bg_y = y_end - 8  # just inside bottom border
    background = img.getpixel((bg_x, bg_y))[:3]

    # Font color: brightest pixel in text region that isn't foreground or border
    font_color = _find_text_pixel(img, y_start, y_end, w, foreground, border)

    # Glow color: pixels adjacent to font pixels that aren't fg/border/font
    glow_color = _find_glow_pixel(img, y_start, y_end, w, foreground, border, font_color, background)

    return {
        "foreground": foreground,
        "background": background,
        "border": border,
        "font_color": font_color,
        "glow_color": glow_color,
    }


def _find_text_pixel(img, y_start, y_end, w, foreground, border):
    """Find the brightest non-foreground, non-border pixel in the text region."""
    best = None
    best_brightness = -1
    # Text is in left ~50% of chip, scan the inner area (past border)
    x_start = 16
    x_end = int(w * 0.45)
    y_mid = (y_start + y_end) // 2

    for x in range(x_start, x_end):
        for y in range(y_start + 6, y_end - 6):  # skip border rows
            px = img.getpixel((x, y))[:3]
            if _color_dist(px, foreground) < 300:
                continue
            if _color_dist(px, border) < 300:
                continue
            brightness = sum(px)
            if brightness > best_brightness:
                best_brightness = brightness
                best = px
    return best or (230, 230, 230)


def _find_glow_pixel(img, y_start, y_end, w, foreground, border, font_color, background):
    """Find glow pixels — pixels adjacent to font-colored pixels.

    Strategy: first find all font pixel locations, then check their
    neighbors for pixels that aren't font/foreground/border/background.
    """
    x_start = 16
    x_end = int(w * 0.45)

    # Step 1: find font pixel locations
    font_pixels = set()
    for x in range(x_start, x_end):
        for y in range(y_start + 6, y_end - 6):
            px = img.getpixel((x, y))[:3]
            if _color_dist(px, font_color) < 200:
                font_pixels.add((x, y))

    # Step 2: check neighbors of font pixels for glow color
    known_colors = [foreground, border, font_color, background]
    candidates = {}
    for fx, fy in font_pixels:
        for dx in range(-2, 3):
            for dy in range(-2, 3):
                if dx == 0 and dy == 0:
                    continue
                nx, ny = fx + dx, fy + dy
                if (nx, ny) in font_pixels:
                    continue
                if nx < x_start or nx >= x_end:
                    continue
                if ny < y_start + 6 or ny >= y_end - 6:
                    continue
                px = img.getpixel((nx, ny))[:3]
                # Skip if it matches any known color
                is_known = False
                for kc in known_colors:
                    if _color_dist(px, kc) < 200:
                        is_known = True
                        break
                if is_known:
                    continue
                # This is a candidate glow pixel
                key = (px[0] // 4, px[1] // 4, px[2] // 4)
                if key not in candidates:
                    candidates[key] = [0, px]
                candidates[key][0] += 1

    if candidates:
        best = max(candidates.values(), key=lambda x: x[0])
        return best[1]
    return (128, 128, 128)


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <mockup.png>")
        sys.exit(1)

    img = Image.open(sys.argv[1]).convert("RGB")
    palette = load_palette()

    print(f"Image size: {img.size}")
    chip_rows = find_chip_rows(img)
    print(f"Found {len(chip_rows)} chips\n")

    if len(chip_rows) != len(CHIP_TYPES):
        print(f"WARNING: Expected {len(CHIP_TYPES)} chips, found {len(chip_rows)}")
        print(f"Chip Y ranges: {chip_rows}")

    properties = ["background", "foreground", "border", "font_color", "glow_color"]

    # Print results grouped by property (ready to paste into game_colors.gd)
    for prop in properties:
        func_name = f"get_move_chip_{prop}"
        print(f"\nstatic func {func_name}(element_type: Enums.ElementalType) -> Color:")
        print(f"\tmatch element_type:")

        for i, (y_start, y_end) in enumerate(chip_rows):
            if i >= len(CHIP_TYPES):
                break
            type_name = CHIP_TYPES[i]
            colors = sample_chip(img, y_start, y_end)
            ramp, shade, hex_val, note = nearest_palette(colors[prop], palette)
            print(f'\t\tEnums.ElementalType.{type_name:10s} return GameColorPalette.get_color("{ramp}", {shade})  # {hex_val}{note}')

        ramp, shade = "Gray", 5
        print(f'\t\t{"_":10s}                             return GameColorPalette.get_color("{ramp}", {shade})')

    # Also print a raw summary table
    print("\n\n# ── RAW SAMPLE TABLE ──")
    print(f"{'Type':<12} {'Background':<20} {'Foreground':<20} {'Border':<20} {'FontColor':<20} {'GlowColor':<20}")
    for i, (y_start, y_end) in enumerate(chip_rows):
        if i >= len(CHIP_TYPES):
            break
        type_name = CHIP_TYPES[i]
        colors = sample_chip(img, y_start, y_end)
        parts = []
        for prop in properties:
            ramp, shade, hex_val, note = nearest_palette(colors[prop], palette)
            parts.append(f"{ramp} {shade} {hex_val}")
        print(f"{type_name:<12} {'  '.join(parts)}")


if __name__ == "__main__":
    main()

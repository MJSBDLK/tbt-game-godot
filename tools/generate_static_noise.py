#!/usr/bin/env python3
"""Generates static_noise.png for the Hypoesthesia censor effect.

Output: 16x640 PNG (4 frames of 4x640 stacked vertically).
Palette: weighted samples from the robo (gray) ramp with sparse warm accents.
Import this with TEXTURE_FILTER_NEAREST in Godot so horizontal downscale preserves
the pixelly static look.
"""
import random
from PIL import Image

WIDTH = 640
FRAME_HEIGHT = 4
FRAMES = 4
HEIGHT = FRAME_HEIGHT * FRAMES

# (r, g, b, weight)
PALETTE = [
    (0, 0, 0, 2),          # Gray 0
    (26, 26, 26, 4),       # Gray 1
    (51, 51, 51, 6),       # Gray 2
    (77, 77, 77, 8),       # Gray 3
    (102, 102, 102, 8),    # Gray 4
    (128, 128, 128, 6),    # Gray 5
    (153, 153, 153, 4),    # Gray 6
    (204, 204, 204, 2),    # Gray 8
    (255, 255, 255, 1),    # Gray 10 (sparkle)
    (185, 66, 49, 1),      # Red 5
    (207, 117, 66, 1),     # PoppyRed 6
    (201, 141, 71, 1),     # Orange 6
]

colors = [(r, g, b) for (r, g, b, _) in PALETTE]
weights = [w for (*_, w) in PALETTE]

random.seed(0xC0DE)  # deterministic output

img = Image.new("RGB", (WIDTH, HEIGHT))
pixels = img.load()
for y in range(HEIGHT):
    for x in range(WIDTH):
        pixels[x, y] = random.choices(colors, weights=weights, k=1)[0]

out_path = "art/sprites/ui/static_noise.png"
img.save(out_path)
print(f"wrote {out_path} ({WIDTH}x{HEIGHT})")

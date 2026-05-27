#!/usr/bin/env python3
"""Apply pivot.y deltas to character idle.json sidecars.

Usage:
    tools/pivot_nudge.py <char>=<delta> [...]

Examples:
    tools/pivot_nudge.py knight=+4 thumps=-2
    tools/pivot_nudge.py mystic=-3
    tools/pivot_nudge.py --dx ogre=+1 ogre_squire=-1   # also nudge pivot.x

<delta> is signed. Positive y shifts the rendered sprite UP, negative shifts DOWN
(pivot.y is in image coords; the engine maps pivot to tile-center, so higher
pivot.y = pivot deeper in the image = sprite hangs higher above tile).

Use --dx to nudge pivot.x instead of (or in addition to) pivot.y by writing
character=delta after --dx for the x-axis pass.
"""
import json
import os
import sys

ROOT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "art", "sprites", "characters",
)
ROOT = os.path.normpath(ROOT)


def parse_args(argv):
    """Returns (y_shifts: dict[str,int], x_shifts: dict[str,int])."""
    y_shifts, x_shifts = {}, {}
    target = y_shifts
    for arg in argv:
        if arg == "--dx":
            target = x_shifts
            continue
        if arg == "--dy":
            target = y_shifts
            continue
        if "=" not in arg:
            print(f"skipping malformed arg: {arg!r}", file=sys.stderr)
            continue
        name, delta = arg.split("=", 1)
        try:
            target[name] = int(delta)
        except ValueError:
            print(f"skipping non-integer delta: {arg!r}", file=sys.stderr)
    return y_shifts, x_shifts


def apply_shift(char_name: str, dy: int, dx: int) -> bool:
    char_dir = os.path.join(ROOT, char_name)
    if not os.path.isdir(char_dir):
        print(f"  {char_name}: NO DIR at {char_dir}")
        return False
    json_path = os.path.join(char_dir, "idle.json")
    if not os.path.exists(json_path):
        print(f"  {char_name}: NO idle.json")
        return False
    with open(json_path) as f:
        data = json.load(f)
    piv = data.setdefault("pivot", {"x": 0, "y": 0})
    old = (piv.get("x", 0), piv.get("y", 0))
    piv["x"] = old[0] + dx
    piv["y"] = old[1] + dy
    with open(json_path, "w") as f:
        json.dump(data, f)
    print(f"  {char_name}: pivot ({old[0]},{old[1]}) -> ({piv['x']},{piv['y']})  [dx={dx:+d} dy={dy:+d}]")
    return True


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        print(__doc__)
        return 0

    y_shifts, x_shifts = parse_args(sys.argv[1:])
    names = set(y_shifts) | set(x_shifts)
    if not names:
        print("no shifts supplied")
        return 1

    for name in sorted(names):
        apply_shift(name, y_shifts.get(name, 0), x_shifts.get(name, 0))
    return 0


if __name__ == "__main__":
    sys.exit(main())

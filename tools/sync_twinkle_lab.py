#!/usr/bin/env python3
"""Copies the [shared] GLSL section of shaders/star_twinkle.gdshader into
data/design/mockups/skybox_twinkle_lab.html so the lab page runs the real
shader. Run after any edit to that section:  python3 tools/sync_twinkle_lab.py
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHADER = ROOT / "shaders/star_twinkle.gdshader"
PAGE = ROOT / "data/design/mockups/skybox_twinkle_lab.html"
SECTION = re.compile(r"// \[shared-begin\]\n(.*?)// \[shared-end\]", re.S)

shared = SECTION.search(SHADER.read_text()).group(1)
page = PAGE.read_text()
updated, count = SECTION.subn(lambda _: "// [shared-begin]\n" + shared + "// [shared-end]", page)
assert count == 1, "lab page must contain exactly one [shared] section"
PAGE.write_text(updated)
print("synced", len(shared.splitlines()), "lines")

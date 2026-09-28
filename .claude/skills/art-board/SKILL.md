---
name: art-board
description: Syncs Lawrence's art board (tools/art_dashboard/) with the art on disk — wires in new art, follows up his renames, answers his notes, flags anomalies. Use when user says "/art-board", "sync the art board", "check Lawrence's notes", or after pulling lod--main.
---

# Art board sync

The board (`tools/art_dashboard/index.html`) reads art presence live; this
skill does the parts a page can't. How the page decides things:
`dashboard.js` header. The data file and tier rules:
`game_data_generator.gd` header. Specs: `.claude/todo.md`
"TRACKING ART AND ANIMATION WORK".

## 1. See what the board sees

```
env -u LD_LIBRARY_PATH node tools/art_dashboard/check_on_disk.js
```

Each character's tier and what its next tier needs, art that's drawn but not
wired in ("new, not wired"), and pending renames: the page's own logic.

## 2. Wire in new art (a "new" badge on the board)

A convention file exists but the character JSON doesn't declare it:

- Clip: add `animations.<key>` = `{path, frames, fps}`, with frames = width ÷
  height. The sidecar holds timing and the hit frame; no sidecar means ask
  Lawrence to re-export with the tag exporter.
- Idle: point `sprite.sheetPath` at it. The sidecar must have `pivot` and
  `art_bounds`, or the unit floats: check with `tools/pivot_nudge.py`.
- Line art: set `lineartPath`, set `mipmaps/generate=true` in its `.import`,
  and make a square `<id>_portrait.tres` crop (view the image, pick the face).
  RQD eyeballs new crops.

## 3. Follow up renames Lawrence did

A declared path is gone and its convention twin exists: repoint the JSON,
then grep the old name. Tests and tools hard-code a few paths
(`test_combat_presenter.gd`, `test_animation_coverage.gd`, `pivot_nudge.py`,
`combat_backdrop_template.lua`). Delete the old exported PNG/JSON pair only
once nothing references it.

## 4. Answer notes

`tools/art_dashboard/notes/*.json` (format: that folder's README). For each:
make a judgment call, act if it's in reach, and append a reply
`{"author": "Claude", "text", "date"}` so Lawrence sees the answer on the
board. Never require anything of him. Anything that needs RQD goes in
`.claude/todo.md` "# Claude" too.

## 5. Regenerate, test, report

```
godot-4 --headless --path . -s tools/art_dashboard/game_data_generator.gd
env -u LD_LIBRARY_PATH node --test tools/art_dashboard/dashboard_test.js
```

Then GUT (`test_art_dashboard_data`, `test_character_art_wiring`,
`test_animation_coverage`). Report to RQD: tier changes, what you wired,
notes answered. Flag anything odd rather than fixing it silently: strays
(`IMG_*`, `Untitled_Artwork*`), strips without sidecars, and art for
characters with no JSON. Don't flag unused line art for mounts (battle chicken).
Commit only when RQD asks.

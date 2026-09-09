# Character Asset Checklist & File Hierarchy

*One copy-paste checklist per character = "everything we need before this
character is DONE." Grounded in the conventions actually shipped as of
2026-07 — where a convention is still unsettled it's marked **TBD** (same
policy as the UI style guide).*

## File hierarchy (per character, `<id>` = snake_case character id)

```
art/
  sprites/characters/
    <id>.aseprite              # Lawrence's source. Canvas expanded so the FEET
                               #   land at canvas center (96×96 → pivot 48,48).
                               #   One tag per animation, from the clip
                               #   vocabulary: idle, melee, ranged, dodge,
                               #   hurt, death, cast, ... (side view, LEFT-facing)
    <id>/                      # Tag-exporter output (right-click .aseprite in
      idle.png                 #   FileSystem dock → "Export Tags as PNGs")
      idle.json                # Sidecar: pivot + frame metadata. Never hand-edit
      melee.png / melee.json   #   — it's overwritten on re-export.
      ...
  portraits/
    <id>_portrait.png          # Pixel portrait (source can be hi-res; NN-scaled
                               #   in HUD). Naming: UNDERSCORE, not hyphen —
                               #   grasker-portrait.png predates the rule.
  lineart_fullres/
    <id>.png                   # Full-res line art (HD pipeline, HDLayer).
                               #   .import needs mipmaps/generate=true.
    <id>_portrait.tres         # AtlasTexture crop of the line art used as the
                               #   HD portrait region.
data/characters/
  <id>.json                    # All gameplay data (schema below).
```

Legacy stragglers that don't follow this (`.js` files, `grasker-portrait.png`,
`napdawg` vs `napdog`) get renamed opportunistically, not urgently.

## The checklist (copy per character)

```markdown
### <Character Name> (`<id>`)

**Art — sprites**
- [ ] `<id>.aseprite` with expanded canvas (feet at canvas center)
- [ ] `idle` tag exported (`<id>/idle.png` + `idle.json` sidecar)
- [ ] Pivot verified in-game (stands centered on its tile, no float/sink)
- [ ] Attack animations exported — SIDE VIEW, LEFT-FACING, tagged from the
      clip vocabulary (header of `scripts/units/unit_animation_resolver.gd`).
      The minimum useful set:
  - [ ] `melee` side-swing
  - [ ] `ranged` side-shot — only if the kit has ranged moves
  - [ ] optional reactions `dodge`, `hurt`, `death`; `cast` for support;
        refinements (`melee_special`, …) only when a look must differ
  - [ ] NO up/down variants — the combat scene has one facing; on the map a
        due-vertical attack falls back to the boop nudge

**Art — portraits**
- [ ] 92×92 portrait (unit detail / prep panels)
- [ ] 32×32 portrait (map-side chips) — TBD whether we ship this or keep the
      sprite-head crop fallback permanently
- [ ] Full-res line art (`lineart_fullres/<id>.png`, mipmaps ON in .import)
- [ ] Line-art portrait atlas (`<id>_portrait.tres`)
- [ ] Fallback check: with any of the above missing, the chain
      portraitPath → sprite-crop head → default_portrait.png still renders

**Data — `data/characters/<id>.json`**
- [ ] `characterId`, `characterName` (display name ≤ panel width — see
      "Phoenix Pirate")
- [ ] `primaryType` / `secondaryType`
- [ ] `currentClass` (+ `specialization` if any)
- [ ] `baseStats` — maxHP, strength, special, skill, agility, athleticism,
      defense, resistance
- [ ] `growthRates` — same 8 axes, percentages (see growth-rate-tiers.md)
- [ ] `physicalAttributes` — moveDistance, constitution, carry
- [ ] `basePoolMoves` — target ≥ 9 (alpha goal)
- [ ] `basePoolPassives` — target ≥ 9 (alpha goal; Maximum/Stellar stay
      Max-only)
- [ ] `sprite` block (sheetPath → exported idle.png)
- [ ] `animations` block keyed by vocabulary name (path/frames; fps/hit_frame
      are fallbacks — the strip's sidecar wins); `animation_overrides` only for
      exceptions (`"melee_special": "ranged"`, `"move:Uppercut": "ranged"`)
- [ ] `portraitPath`, `lineartPath`, `lineartAtlases.portrait`

**Wiring**
- [ ] Faction decided (see the faction table in `.claude/todo-archive.md`, Meeting 20260531)
- [ ] Added to `RECRUIT_POOL` (player) or `enemy_spawn_pool` (enemy)
      — ally/neutral spawn infra doesn't exist yet (post-alpha)

**Verify**
- [ ] `godot-4 --headless --import` clean (no missing-resource warnings)
- [ ] Spawns in a test battle: idle plays, level label right, health bar sized
- [ ] Attacks adjacent + at range: correct clip style (melee vs ranged)
- [ ] Detail panel: portrait, types, stats, moves, passives all populated
```

## Notes

- **Pivots**: the exporter's no-slice fallback emits canvas-center, which is
  correct *because* the canvas is expanded. Older sprites with tight canvases
  (grunt-era) get fixed by resizing the canvas in Aseprite and re-exporting —
  never by hand-tuning the sidecar.
- **Animation taxonomy**: a clip is chosen by reach (melee when the target
  is adjacent, ranged from two tiles; a move's `animationStyle` tag forces
  it) × kind (physical/special) — never by direction. A missing refinement
  falls back along an explicit chain, same reach first
  (`melee_special → melee → melee_physical → ranged_special → …`), that ends in
  a procedural nudge, so a character with only `idle` is always playable.
  `tools/diag/animation_coverage_probe.gd` prints who plays what. Design:
  `.claude/battle-animations.md`.
- **The `.aseprite` file is the source of truth** for all sprite art; the
  exported PNGs are build artifacts and safe to regenerate at any time.

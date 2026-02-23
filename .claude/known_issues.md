# Known Issues

## Format

Each issue uses structured metadata for tracking. Priority: P0 (critical) → P5 (backlog).

**Status**: `OPEN` | `IN_PROGRESS` | `BLOCKED` | `RESOLVED` | `WONT_FIX`

---

## Quick Stats

- **Total Open Issues**: 0
- **Critical (P0)**: 0
- **Last Updated**: 2026-02-22

---

## Open Issues

*None yet — fresh project.*

---

## Inherited from Unity (may recur during port)

These issues existed in the Unity version. Watch for them during porting:

### Flood Fill Shows Unreachable Tile as Reachable
- **Unity status**: OPEN (MINOR-005)
- **Risk**: May port the same bug if GridManager BFS logic is copied directly
- **Mitigation**: When porting `GridManagerV2.cs`, compare flood-fill visualization with actual pathfinding validation

### Status Effect Icons Not Appearing
- **Unity status**: OPEN (MAJOR-002)
- **Risk**: N/A — building status effect UI fresh in Godot
- **Mitigation**: Design the icon system properly from the start in Phase 3

### Special Attack Animation Invisible
- **Unity status**: OPEN (MINOR-004)
- **Risk**: N/A — Unity used 3D primitives in a 2D game. Godot port will use Sprite2D/Tweens.
- **Mitigation**: Build proper 2D projectile animations in Phase 3

### Unit Darkens Before Attack Completes
- **Unity status**: OPEN (MINOR-003)
- **Risk**: May recur if `set_acted()` timing isn't handled in combat sequence
- **Mitigation**: In `execute_combat_sequence()`, call `set_acted()` AFTER `await` combat animation

---

## Resolved Issues

*None yet.*

---

## Issue Template

```markdown
### [CATEGORY-###] Short Title

- **Status**: `OPEN`
- **Affected Systems**: `SystemName`
- **Introduced**: YYYY-MM-DD
- **Description**: What's wrong
- **Expected**: What should happen
- **Actual**: What actually happens
- **Related Files**: `path/to/file.gd`
- **Priority**: P0-P5
```

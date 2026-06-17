# Move & Passive Templates

Field reference derived from the actual parsers:
- Moves → [scripts/combat/move_data.gd](../scripts/combat/move_data.gd) (`_parse_move_entry`) + [scripts/combat/move.gd](../scripts/combat/move.gd) (the `Move` resource)
- Passives → [scripts/combat/passive_data.gd](../scripts/combat/passive_data.gd)

JSON has no comments — the `//` notes below are documentation only. Strip them before pasting into a real bank file.

---

## Move template

Add the entry to [data/moves/basic_move_bank.json](../data/moves/basic_move_bank.json).
The **JSON key is the move's display name** (and the default `moveId`). Every other
field has a default (shown), so an entry can be as small as a name + a few fields.

```jsonc
"Move Name": {                      // top-level key = display name; required
  // ---- Identity ----
  "abbrevName": "Mv Nm",            // short label for chips/UI. Default: full name. Keep ≲9 chars
  "moveId": "move_name",            // stable id. Default: name lowercased, spaces→underscores
  "description": "What it does.",   // flavor/help text. Default: ""

  // ---- Targeting ----
  "range": 1,                       // tiles. 0 = self-only. Default: 1
  "areaOfEffect": 0,                // AoE radius in tiles. 0 = single tile. Default: 0
  "targetType": "Single",           // Single | Self | AOE | Ally | AllyNotSelf. Default: Single

  // ---- Damage ----
  "basePower": 5,                   // 0 for pure support/status moves. Default: 0
  "damageType": "Physical",         // Physical | Special | Support. Default: Physical
  "elementType": "Simple",          // see element list below. Default: None
  "accuracy": 90,                   // base hit %, before skill/agility/passives. Default: 90

  // ---- PP / usages (optional) ----
  // max_uses is derived from basePower tier: ≤3→30, ≤7→15, ≤11→8, else→5.
  "usagesOffset": 0,                // added to the tier value, clamped 1..99. Default: 0

  // ---- Healing (optional) ----
  "heal": false,                    // true → heals target for (caster.special + basePower)
                                    //         instead of dealing damage. Default: false

  // ---- Status effect (optional; omit the whole object for none) ----
  "statusEffect": {
    "effect": "Burn",               // StatusEffectType name (see list). Required inside this object
    "chance": 0.3,                  // proc probability 0.0–1.0. Default: 0.0
    "stacks": 1,                    // stacks applied on proc. 0 = effect's own default. Default: 0
    "replaces": false,              // true → overwrite existing buff/debuff, bypass category immunity. Default: false
    "target": "target"              // "target" or "self" (rider buff on the caster). Default: target
  },

  // ---- On-hit instant effects (optional; omit the whole object for none) ----
  "onHit": {
    "cleanse": ["Bleed"],           // status names removed from the target on hit (case-insensitive)
    "displace": {                   // knockback/pull, resolved after damage
      "distance": 1,                // tiles to move the target. 0 = no displacement
      "vector": "away_from_attacker", // away_from_attacker | toward_attacker | attacker_facing | from_aoe_center
      "on_blocked": "stop",         // stop | bonus_damage | swap | fall_through. Default: stop
      "save": {                     // optional resist roll; omit to always displace
        "vs": "constitution",       // CharacterData stat the target resists with (e.g. constitution, athleticism)
        "dc": "damage"              // what the displacement is checked against: "damage" or "base_power"
      }
    },
    "script": ""                    // escape hatch: res:// path to a static resolve() script. Default: "" (not yet wired)
  }
}
```

### Minimal damage move

```jsonc
"Cyclone": {
  "description": "A concentrated vortex of cutting air.",
  "abbrevName": "Cyclone",
  "range": 2,
  "areaOfEffect": 0,
  "basePower": 8,
  "accuracy": 80,
  "damageType": "Special",
  "elementType": "Air",
  "targetType": "Single"
}
```

### Valid enum values

- **elementType**: `None`, `Air`, `Chivalric`, `Cold`, `Electric`, `Fire`, `Gentry`,
  `Gravity`, `Heraldic`, `Occult`, `Plant`, `Robo`, `Simple`, `Void`, `Obsidian` (enemies only)
- **damageType**: `Physical`, `Special`, `Support`
- **targetType**: `Single`, `Self`, `AOE`, `Ally`, `AllyNotSelf`
- **statusEffect.effect**: `Bellows`, `Critical`, `Rallied`, `Fortified`, `Hasted`,
  `Focused`, `Regen`, `Bleed`, `Bugle`, `Burn`, `Chain_Lightning`, `Challenged`,
  `Freeze`, `Gravity`, `Poison`, `Rooted`, `Shocked`, `Subversion`, `Void`, `Vulnerable`

> Note: `priority` (the "attacks before the opponent" move in your needs list) and
> a position-swap on-hit are **not yet fields** — they'd need parser + combat support.

---

## Passive template

Add the entry to [data/passives.json](../data/passives.json). Passives are currently
**data-light**: only `abbrevName` + `description` are parsed. The actual effect is
implemented in code keyed by the passive's name (StatusEffectSystem, PassiveEffectsSystem,
EnemyAI, DamageCalculator, etc.) — adding the JSON entry alone does **not** make it do anything.

```jsonc
"Passive Name": {                   // top-level key = display name; required
  "abbrevName": "Psv Nm",           // short label for UI chips. Default: full name. Keep ≲9 chars
  "description": "What it does."     // shown in unit detail / equipment picker. Default: ""
}
```

### Example

```jsonc
"Extendo": {
  "abbrevName": "Extendo",
  "description": "Physical moves have +1 range, but not through impassable terrain"
}
```

> When you add a passive that needs new behavior, the JSON entry is step 1 of 2 —
> step 2 is wiring the effect in the relevant system by its name. See existing wired
> passives (e.g. `Bellows`, `Ghost`, `Protector`) for where hooks live.

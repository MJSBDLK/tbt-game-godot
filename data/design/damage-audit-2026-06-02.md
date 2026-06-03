# Damage Calculation Audit (2026-06-02)

Audit of [scripts/combat/damage_calculator.gd](../../scripts/combat/damage_calculator.gd) prompted by recurring "damage feels off" / "Ogre overpowered" / "Backhand too strong" reports. **No code changes made yet — this is a findings doc to inform a future design call.**

## Formula in code

Matches the [character-system.md](character-system.md) spec exactly:

```
base_damage = (move.base_power × attack_stat / 5) - defense_stat
final_damage = max(1, round(base_damage × type_multiplier × bellows_multiplier))
```

Athleticism-based multi-hit:

```
ratio = attacker.athleticism / defender.athleticism
4× → 4 hits, 3× → 3, 2× → 2, else 1
```

Faithful port. No port bug. The "feels off" complaints are properties of the formula itself.

## Structural properties that produce the symptoms

### 1. Attack stat scales hard via the `/5` divisor

Each 5 atk-points adds a full move-power's worth of damage. At higher levels, stats double or triple — and damage scales linearly with that.

| Move | atk=10 base | atk=20 base | atk=30 base |
|------|------------:|------------:|------------:|
| Backhand (power 8) | 16 | 32 | 48 |
| Bonk (power 3)     | 6  | 12 | 18 |

A 3× stat advantage → 3× damage advantage. Stacks with multi-hit cliffs (see #3).

### 2. Defense is flat subtraction, not multiplicative

`- defense_stat` after the multiplication. So defense provides constant absolute reduction regardless of attacker strength. Effect on % damage taken depends entirely on raw attack output.

| Move | vs def=5 | vs def=15 |
|------|---------:|----------:|
| Bonk (power 3) at atk=10    | 1 dmg (capped) | 1 dmg (capped) |
| Megaton (power 11) at atk=10 | 17 dmg | 7 dmg (33% reduction) |

**This explains the Ogre.** Most weak attacks bounce off entirely (min-clamped to 1 — so 25 chip damage stacks slowly), but he still eats burst from high-power moves. A multiplicative defense (e.g. `power × atk / (5 + def)`) would make high-def units consistently durable without making them immortal to low-power chip.

### 3. Multi-hit cliffs at integer ATH ratios

`1.99× ATH = 1 hit; 2.00× ATH = 2 hits = double damage`. One stat point can swing combat. Design doc says "multiple attack **chance**" but code is deterministic threshold.

Two ways to soften:
- **Lower thresholds**: 1.5× / 2.5× / 3.5× (multi-hit kicks in sooner, still cliff but less swingy)
- **Convert to chance-based** per the design doc's wording: each unit of ATH advantage = N% chance of an extra hit, capped at +3.

### 4. Backhand is a real data outlier

basePower 8 puts it at the top of the 1-range physical curve. Most peer 1-range physical moves are 3–7. Ernesto has the str + str-growth to weaponize it especially well. By level 5: Backhand deals ~13 dmg/hit vs def-5; Bonk on the same setup deals 2.

## Likely landing zone: Radiant Dawn formula

User's instinct (2026-06-02): "we're going to end up copying Radiant Dawn's damage calculation formula. IIRC we tried to reinvent the wheel but it's clearly not working." That reads true given the findings above.

Radiant Dawn (Fire Emblem) formula:

```
damage = (attack_stat + weapon_might) - defense_stat
hits   = 2 if attacker_speed >= defender_speed + 4 else 1
```

Key differences from current:

| Property | Current | Radiant Dawn |
|---|---|---|
| Stat scaling | multiplicative (× `power / 5`) | additive |
| Defense | flat subtract | flat subtract (same) |
| Multi-hit | continuous ratio cliffs (2×, 3×, 4×) | binary, +4 speed threshold |
| Crit | not implemented | ×3 final damage |
| Outlier-move risk | huge (power × big stat) | bounded (power additive only) |

**Why this addresses all three "feels off" findings at once:**

1. **Attack snowball goes away.** Stat growth still matters (you ADD it to damage) but doesn't compound with weapon power. A high-stat unit doesn't 3× a low-stat one in raw damage; they do `(20-10) = +10 damage`, which is meaningful but not lopsided.
2. **Defense becomes more meaningful relative to attacks.** Since attacker's contribution is bounded (`atk + might` is ~25-35 for most units), a def of 15 cuts attacks roughly in half — not "1 dmg vs 30 dmg" cliff-edges.
3. **Multi-hit is a clean binary.** Either you double or you don't. The +4 speed threshold is well-tuned by 30+ years of FE iteration.

## Recommended order of operations

Knowing the destination, the order shifts:

1. **Port the Radiant Dawn formula.** ~10-line change to `calculate_damage` + `calculate_attack_count`. Bigger conceptual swing but smaller code surface than tweaking the current formula three different ways.
2. **Rebalance move base_powers.** Current values were calibrated for the multiplicative formula (where power=8 → ~32 dmg at str=20). Under additive math, power directly = added damage. Likely need to bump base values up (e.g. ×3-5) to compensate, AND make outlier moves (Backhand power 8) less outlier-y proportionally.
3. **Rebalance unit stats.** Less critical — additive formula naturally compresses stat-spread impact. Probably fine to keep current spread for first pass.
4. **Add crit.** ×3 final-damage crit (per RD) is a nice variance source once the base formula stabilizes.

Numbers above are based on static analysis; **validate against actual playtest data before tuning.** The combat-preview log line in [damage_calculator.gd:49](../../scripts/combat/damage_calculator.gd#L49) prints the full breakdown — drop a few enemies of varying def with `DebugConfig.log_combat` on to see real distributions.

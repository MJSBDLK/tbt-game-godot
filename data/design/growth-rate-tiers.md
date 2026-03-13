# Growth Rate Tier Reference

**Baseline**: Fire Emblem: Radiant Dawn
**Last Updated**: 2026-01-15

This document defines what qualitative growth rate labels (e.g., "medium", "high") mean in terms of actual percentages for each stat. Use this as a reference when designing character growth profiles.

---

## Quick Reference Tables

### Health Points (HP)

HP growth rates tend to run higher than other stats.

| Tier | Growth % | Description |
|------|----------|-------------|
| Nonexistent | 0-15% | Glass cannon, will barely gain HP |
| Very Low | 15-30% | Fragile, needs protection |
| Low | 30-45% | Below average durability |
| Below Average | 45-55% | Slightly squishy |
| **Average** | **55-65%** | Typical frontliner |
| Above Average | 65-75% | Solid health pool |
| High | 75-85% | Tanky |
| Very High | 85-95% | Meat wall |

**RD Examples**: Micaiah 40%, Ike 60%, Volug 95%

---

### Strength

Physical attack power. Mid-range stat distribution.

| Tier | Growth % | Description |
|------|----------|-------------|
| Nonexistent | 0-10% | Cannot deal physical damage effectively |
| Very Low | 10-20% | Physical attacks are a last resort |
| Low | 20-30% | Weak physical presence |
| Below Average | 30-40% | Not their forte |
| **Average** | **40-50%** | Competent physical attacker |
| Above Average | 50-60% | Hits hard |
| High | 60-70% | Primary physical damage dealer |
| Very High | 70-80% | Exceptional strength growth |

**RD Examples**: Micaiah 15%, Ike 55%, Nolan 65%

---

### Special (Magic)

Magical/special attack power. High variance - many characters have 0%.

| Tier | Growth % | Description |
|------|----------|-------------|
| Nonexistent | 0-5% | No magical aptitude whatsoever |
| Very Low | 5-15% | Negligible magical growth |
| Low | 15-25% | Minor magical capability |
| Below Average | 25-35% | Some magical potential |
| **Average** | **35-50%** | Competent magic user |
| Above Average | 50-60% | Strong magical growth |
| High | 60-70% | Primary magical damage dealer |
| Very High | 70-85% | Exceptional magical aptitude |

**RD Examples**: Ike 20%, Soren 55%, Micaiah 80%

---

### Skill

Accuracy and critical hit chance. Tends to run higher than most stats.

| Tier | Growth % | Description |
|------|----------|-------------|
| Nonexistent | 0-15% | Wildly inaccurate |
| Very Low | 15-25% | Unreliable hits |
| Low | 25-35% | Below average precision |
| Below Average | 35-45% | Somewhat imprecise |
| **Average** | **45-55%** | Reliable accuracy |
| Above Average | 55-65% | Precise attacker |
| High | 65-75% | Very accurate, good crit chance |
| Very High | 75-85% | Surgical precision |

**RD Examples**: Meg 35%, Ike 50%, Sothe 80%

---

### Agility (Speed)

Evasion and initiative. Moderate distribution.

| Tier | Growth % | Description |
|------|----------|-------------|
| Nonexistent | 0-10% | Sitting duck |
| Very Low | 10-20% | Very slow, easy to hit |
| Low | 20-30% | Sluggish |
| Below Average | 30-40% | A bit slow |
| **Average** | **40-50%** | Adequate speed |
| Above Average | 50-60% | Quick |
| High | 60-70% | Very fast, hard to hit |
| Very High | 70-80% | Blazing speed |

**RD Examples**: Aran 25%, Ike 40%, Mia 65%

---

### Athleticism

Multi-attack chance and movement efficiency. (Custom stat - use Agility/Speed as baseline)

| Tier | Growth % | Description |
|------|----------|-------------|
| Nonexistent | 0-10% | Single actions only |
| Very Low | 10-20% | Rarely gets extra actions |
| Low | 20-30% | Occasional bonus actions |
| Below Average | 30-40% | Below average follow-ups |
| **Average** | **40-50%** | Moderate multi-attack potential |
| Above Average | 50-60% | Regular extra actions |
| High | 60-70% | Frequent multi-attacks |
| Very High | 70-80% | Action economy monster |

**Note**: No direct RD equivalent. Baseline derived from Speed distribution.

---

### Defense

Physical damage resistance. Tends to run lower than offensive stats.

| Tier | Growth % | Description |
|------|----------|-------------|
| Nonexistent | 0-10% | Paper-thin, avoid all combat |
| Very Low | 10-20% | Very fragile to physical |
| Low | 20-30% | Takes significant physical damage |
| Below Average | 30-40% | Somewhat vulnerable |
| **Average** | **35-45%** | Adequate physical bulk |
| Above Average | 45-55% | Solid physical defense |
| High | 55-65% | Tanky against physical |
| Very High | 65-75% | Armored unit |

**RD Examples**: Sothe 20%, Ike 40%, Haar 70%

---

### Resistance

Special/magical damage resistance. Highly variable, often a dump stat.

| Tier | Growth % | Description |
|------|----------|-------------|
| Nonexistent | 0-10% | Mages are your worst nightmare |
| Very Low | 10-20% | Very vulnerable to magic |
| Low | 20-30% | Weak magical defense |
| Below Average | 30-40% | Below average magic bulk |
| **Average** | **35-45%** | Moderate magic resistance |
| Above Average | 45-55% | Decent against magic |
| High | 55-70% | Strong magical defense |
| Very High | 70-90% | Magic bounces off |

**RD Examples**: Skrimir 5%, Ike 25%, Micaiah 90%

---

## Stat Distribution Patterns

### Typical Archetypes

**Balanced Fighter** (e.g., Ike)
- HP: Average (60%)
- Str: Above Average (55%)
- Skl: Average (50%)
- Agi: Average (40%)
- Def: Average (40%)
- Res: Low (25%)

**Glass Cannon Mage** (e.g., Micaiah)
- HP: Below Average (40%)
- Str: Nonexistent (15%)
- Spc: Very High (80%)
- Skl: Average (45%)
- Agi: Below Average (35%)
- Def: Very Low (20%)
- Res: Very High (90%)

**Tank/Armor** (e.g., Haar)
- HP: Above Average (70%)
- Str: Above Average (55%)
- Skl: Average (50%)
- Agi: Low (25%)
- Def: Very High (70%)
- Res: Low (25%)

**Speedy Rogue** (e.g., Sothe)
- HP: Average (55%)
- Str: Average (45%)
- Skl: Very High (80%)
- Agi: Above Average (55%)
- Def: Very Low (20%)
- Res: Below Average (35%)

---

## Design Guidelines

### Total Growth Budget

In Radiant Dawn, character total growths (sum of all stats) typically range from **250% to 400%**. This provides a rough budget when designing characters:

- **Low-tier unit**: ~250-300% total
- **Average unit**: ~300-350% total
- **High-tier unit**: ~350-400% total

### Narrative Considerations

Growth rates should reflect character background and training:

- A scholarly character should have low Str but high Spc/Skl
- A berserker type should have high Str/HP but low Skl/Res
- A veteran should have above-average growths across the board
- A young prodigy might have very high growths but low bases

### Balance Notes

- HP growth tends to be the highest stat for most characters
- Resistance is often a dump stat for physical units
- Skill tends to be middle-high for most units
- Very few characters excel in both Str AND Spc (pick a damage type)

---

## References

- [Serenes Forest - Radiant Dawn Growth Rates](https://serenesforest.net/radiant-dawn/characters/growth-rates/)
- [Fire Emblem Wiki - Growth Rate](https://fireemblemwiki.org/wiki/Growth_rate)

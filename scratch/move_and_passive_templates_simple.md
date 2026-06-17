# Move & Passive Templates (simple)

## Move

| Field | Required? | Default | Notes |
|---|---|---|---|
| *(JSON key)* | yes | — | Display name |
| `abbrevName` | no | name | Short UI label, ≲9 chars |
| `description` | no | "" | Help text |
| `range` | no | 1 | Tiles; 0 = self |
| `areaOfEffect` | no | 0 | AoE radius |
| `targetType` | no | Single | Single / Self / AOE / Ally / AllyNotSelf |
| `basePower` | no | 0 | 0 for pure support |
| `damageType` | no | Physical | Physical / Special / Support |
| `elementType` | no | None | See list below |
| `accuracy` | no | 90 | Base hit % |
| `usagesOffset` | no | 0 | Added to auto PP tier |
| `heal` | no | false | Heals target instead of damaging |
| `statusEffect` | no | — | Object, see below |
| `onHit` | no | — | Object: `cleanse`, `displace`, `script` |

`statusEffect`: `{ "effect": "Burn", "chance": 0.3, "stacks": 1, "replaces": false, "target": "target" }`
(`target` = "target" or "self")

**Copy-paste:**

```json
"Move Name": {
  "abbrevName": "Mv Nm",
  "description": "What it does.",
  "range": 1,
  "areaOfEffect": 0,
  "targetType": "Single",
  "basePower": 5,
  "damageType": "Physical",
  "elementType": "Simple",
  "accuracy": 90
}
```

**Enums:**
- `elementType`: None, Air, Chivalric, Cold, Electric, Fire, Gentry, Gravity, Heraldic, Occult, Plant, Robo, Simple, Void, Obsidian
- `statusEffect.effect`: Bellows, Critical, Rallied, Fortified, Hasted, Focused, Regen, Bleed, Bugle, Burn, Chain_Lightning, Challenged, Freeze, Gravity, Poison, Rooted, Shocked, Subversion, Void, Vulnerable

---

## Passive

| Field | Required? | Default | Notes |
|---|---|---|---|
| *(JSON key)* | yes | — | Display name |
| `abbrevName` | no | name | Short UI label |
| `description` | no | "" | Shown in UI |

**Copy-paste:**

```json
"Passive Name": {
  "abbrevName": "Psv Nm",
  "description": "What it does."
}
```

> JSON entry only shows text — the actual effect is coded separately by passive name.


## Moves needed (rework descriptions, status effects, and unique move scripts as appropriate):

```json
"Peck": {
  "abbrevName": "Peck",
  "description": "Basic pecking move.",
  "range": 1,
  "areaOfEffect": 0,
  "targetType": "Single",
  "basePower": 3,
  "damageType": "Physical",
  "elementType": "Air",
  "accuracy": 100,
  "distributionNotes": "only units with beaks"
}
```

```json
"Big Beak": {
  "abbrevName": "Big Beak",
  "description": "More brutal pecking move from a creature with a large beak.",
  "range": 1,
  "areaOfEffect": 0,
  "targetType": "Single",
  "basePower": 6,
  "damageType": "Physical",
  "elementType": "Air",
  "accuracy": 85,
  "distributionNotes": "only units with *large* beaks"
}
```

```json
"Stampede": {
  "abbrevName": "Stampede",
  "description": "Tramples the enemy underfoot.",
  "range": 1,
  "areaOfEffect": 0,
  "targetType": "Single",
  "basePower": 5,
  "damageType": "Physical",
  "elementType": "Simple",
  "accuracy": 70,
  "specialEffect": "If the space behind the target is available, move the attacker there and this move automatically crits",
  "distributionNotes": "for large bois who could plausibly trample things"
}
```

```json
"Razor Wing": {
  "abbrevName": "Rzr Wing",
  "description": "Flies through the target with razor-sharp wings.",
  "range": 1,
  "areaOfEffect": 0,
  "targetType": "Single",
  "basePower": 5,
  "damageType": "Physical",
  "elementType": "Air",
  "accuracy": 80,
  "specialEffect": "If the space behind the target is available, move the attacker there and this move applies the bleed debuff.",
  "distributionNotes": "units with wings"
}
```

```json
"Soar": {
  "abbrevName": "Soar",
  "description": "Flies through the sky like an early dream of mankind.",
  "range": 3,
  "areaOfEffect": 0,
  "targetType": "Self",
  "basePower": 0,
  "damageType": "Support/None",
  "elementType": "Air",
  "accuracy": 100,
  "specialEffect": "Repositions the unit up to 3 spaces away, ignoring terrain statuses of any terrain traversed.",
  "distributionNotes": "Fliers only"
}
```

```json
"Club": {
  "abbrevName": "Club",
  "description": "Go smash.",
  "range": 1,
  "areaOfEffect": 0,
  "targetType": "Single",
  "basePower": 3,
  "damageType": "Physical",
  "elementType": "Simple",
  "accuracy": 90,
  "specialEffect": "",
  "distributionNotes": "units with dull weapons or appendages which would conceivably act as a club",
  "notes": "low power so the unit relies on its own strength - maybe this should also apply a status"
}
```

```json
"Tummy Bounce": {
  "abbrevName": "Tum Bnc",
  "description": "Bounces the target out.",
  "range": 1,
  "areaOfEffect": 0,
  "targetType": "Single",
  "basePower": 2,
  "damageType": "Physical",
  "elementType": "Simple",
  "accuracy": 90,
  "specialEffect": "displace 1",
  "distributionNotes": "large bois, usually with a large gut",
  "notes": "when I was a kid I thought bouncers used their belly to literally 'bounce' you away. Maybe this needs a better name, not sure I like 'tummy' - suggest alternatives please"
}
```

```json
"Hook": {
  "abbrevName": "Hook",
  "description": "",
  "range": 1,
  "areaOfEffect": 0,
  "targetType": "",
  "basePower": 3,
  "damageType": "",
  "elementType": "Simple",
  "accuracy": 75,
  "specialEffect": "",
  "distributionNotes": "any unit which has a hook",
  "notes": "signature of the ogre with its hook hand - chance to root enemy on hit"
}

```json
"Thump Chest": {
  "abbrevName": "",
  "description": "",
  "range": 1,
  "areaOfEffect": 0,
  "targetType": "",
  "basePower": 3,
  "damageType": "Support",
  "elementType": "Simple",
  "accuracy": 90,
  "specialEffect": "",
  "distributionNotes": "",
  "notes": ""
}
```

```json
"Roar": {
  "abbrevName": "",
  "description": "",
  "range": 1,
  "areaOfEffect": 0,
  "targetType": "",
  "basePower": 3,
  "damageType": "Support",
  "elementType": "Simple",
  "accuracy": 90,
  "specialEffect": "",
  "distributionNotes": "",
  "notes": ""
}
```

```json
"Template": {
  "abbrevName": "",
  "description": "",
  "range": 1,
  "areaOfEffect": 0,
  "targetType": "",
  "basePower": 3,
  "damageType": "",
  "elementType": "Simple",
  "accuracy": 90,
  "specialEffect": "",
  "distributionNotes": "",
  "notes": ""
}
```

## Passives Needed

```json
"Regenerator": {
  "abbrevName": "Regen",
  "description": "Regenerates health each turn",
  "distributionNotes": "Ogre gets this",
}
```


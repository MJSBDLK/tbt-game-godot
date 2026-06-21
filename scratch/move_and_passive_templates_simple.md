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
  "description": "Damned hooks for hands...",
  "range": 1,
  "areaOfEffect": 0,
  "targetType": "",
  "basePower": 2,
  "damageType": "",
  "elementType": "Simple",
  "accuracy": 75,
  "specialEffect": "Root",
  "secondaryChance": 30,
  "distributionNotes": "any unit which has a hook",
  "notes": "signature of the ogre with its hook hand - chance to root enemy on hit"
}

```json
"Thump Chest": {
  "abbrevName": "Thump Chest",
  "description": "",
  "range": 0,
  "areaOfEffect": 0,
  "targetType": "Self",
  "basePower": 0,
  "damageType": "Support",
  "elementType": "Simple",
  "accuracy": 90,
  "specialEffect": "Buff on self",
  "distributionNotes": "",
  "notes": "Unit beats his chest to apply a buff to himself - possibly other units in the area but I haven't really thought that through. Ideas?"
}
```

```json
"Roar": {
  "abbrevName": "Roar",
  "description": "",
  "range": 0,
  "areaOfEffect": 2,
  "targetType": "Point?",
  "basePower": 0,
  "damageType": "Support",
  "elementType": "Simple",
  "accuracy": "Can't miss",
  "specialEffect": "",
  "distributionNotes": "",
  "notes": ""
}
```

```json
"Shriek of the Damned": {
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
  "notes": "I haven't thought about this very hard I just really like the name"
}
```

```json
"Clobber": {
  "abbrevName": "",
  "description": "",
  "range": 1,
  "areaOfEffect": 0,
  "targetType": "",
  "basePower": 7,
  "damageType": "",
  "elementType": "Simple",
  "accuracy": 85,
  "specialEffect": "",
  "distributionNotes": "Brute force units get this, but it's probably too powerful for early game",
  "notes": "Simple, devastating move"
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
  "distributionNotes": "Ogre gets this"
}
```

> NOTE: Regenerator must be a **separate heal channel**, NOT "apply the REGEN
> status." If it just applied REGEN, an Ogre that also has the REGEN *buff* would
> hit the same-type stack cap and heal once, not twice. Coded as its own
> turn-start heal, the passive heal and the buff heal are independent → "regen
> twice" works as intended.

---

## Passive Implementation Status

Which passives in `data/passives.json` actually have code vs. which are
description-only placeholders. (Snapshot 2026-06-20 — re-verify against source.)

### Coded
| Passive | Where it lives | Hook it uses |
|---|---|---|
| Ghost | `grid_manager.gd` pathfinding | movement / pathfinding |
| Capricious | `unit.gd` + `enemy_ai.gd` move selection | AI move-pick |
| Competitive | `passive_effects_system.gd` stat aura | turn-start aura recompute |
| Reliable | `damage_calculator.gd` | accuracy calc |
| Bellows | `status_effect_system.gd` on-hit | on-take-damage (air) |

### Not yet coded (description only)
| Passive | Effect | Hook(s) it will need |
|---|---|---|
| Anti-Gravity | 50% chance to clear a debuff each tick | turn-start (on debuff tick) |
| Cavalier | attacking stats immune to buff/debuff | stat-calc / status-apply guard |
| Extendo | physical moves +1 range (not through walls) | range calc + targeting |
| Flippant | super-effective vs it: −acc, +dmg | defender damage + accuracy calc |
| Glib | bonus/penalty vs target's special | attacker damage calc |
| Impetuous | +20% dmg first hit/turn, −10% each after | attacker damage calc (per-turn counter) |
| Impulsive | first attack +20% acc; enemies +20% acc vs it | accuracy calc (attacker + defender) |
| Jury Rig | heal adjacent robo allies at turn start | turn-start |
| Low Profile | ranged attacks vs it: reduced acc | defender accuracy calc + targeting |
| Maximum | statuses can't drop stats below base | stat-calc floor |
| Protector | ranged attacks hit it, not units behind it | targeting redirect |
| Reckless | terrain bonuses & penalties amplified | stat/damage calc (terrain) |
| Stellar | grants Maximum to allies within 2 | turn-start aura |
| Waste Not | recover move PP on kill | on-kill |
| Zone Control | enemies penalized / allies buffed within 3 | turn-start aura + movement/acc |
| **Regenerator** (new) | independent turn-start heal (stacks w/ REGEN) | turn-start (separate heal channel) |

### Proposed architecture (when we code these)
An **event/hook dispatcher** — not the scattered `has_equipped_passive("X")`
checks the 5 coded ones use today (doesn't scale to 20). Shape:

1. A `PassiveHandler` base (one script per passive) with optional overrides for a
   fixed set of hook points.
2. A registry `{ "Bellows": BellowsHandler.new(), ... }` keyed by name.
3. Existing managers call the dispatcher at each phase; it loops a unit's equipped
   passives and invokes whichever hooks they implement.

The hooks above collapse to ~7 points: `on_turn_start`, `modify_stats` (auras +
floors), `modify_outgoing_damage`, `modify_accuracy`, `modify_range`,
`redirect_target`, `on_kill` (+ the existing `on_take_damage` Bellows uses). That
hook list IS the design; everything else is filling in handlers.

---

### Reply:

1. I want the displacement to be a standard mechanic for both the attacker and the defender - so we don't need unique per-move scripts. That said, these need to be fairly robust. Some other examples of displacement I have planned:
+ displace the target by moving it backwards if it fails a constitution check
+ displace the attacker backwards one space, if available
+ swap positions with the unit behind the attacker if there's a friendly unit there
+ displace enemies back 1 space in a row of three
+ spin units around the target tile (point target)
So basically "displace" is its own mechanic, and it has different patterns, can be AOE, etc. One of the parts I haven't tackled yet.
Gravity moves are weaker offensively but will have really powerful CC effects.
Constitution will also play a major role in resisting displace effects.
We may want to open a feature branch to flesh this out - it's a major step, but needs to happen eventually.

2. Correct. If a unit attacks a target to the right, "behind" that unit is one space to the right of the target. We don't need to program in any "facing" mechanics - everything is calculated from the units' positions. Did that answer your question?

3. That's not how crit is supposed to work, actually! We need to fix that. I thought crit was just an X damage multiplier. We were going to start at 1.5 and playtest. We probably need some visual feedback on that map to make it clear what happened.

4. Correct - this is buried in a design doc somewhere, but targets can be: enemy, friend, unit, self, point, and I think one more I'm forgetting. In this case it uses on self, and it's a support type move - not an attack. And yes. It occupies a move slot. Terrain Status is another mechanic we're yet to implement (there's a design doc about it somewhere). Plant tiles can catch fire, water can get electrified, "rain" is a terrain status within the game's mechanics (maybe it's a bit weird if units ignore this, so maybe rain is purely cosmetic - we'll playtest). No "utility" movetype needed, we already have "support" for moves that don't deal damage.

5. Roar: I think it's a support move with target: self, AOE of 2. For "can't miss," maybe we just give it an accuracy rating of 255 and don't worry about adding mechanics. I need some inspo about what type of debuff to apply. I want it to be lore appropriate but I don't want to add any debuffs unless we have a really interesting mechanic gameplay-wise.

6. I think for Tummy Bounce, we just make success (attacker CONST - target CONST > 1). 

7. We should just specify all of this per-move. For "Hook," we only need to apply one stack. IIRC we encountered a design challenge where debuffs cleared at the beginning of the units' turns, but this creates weirdness where if the status gets applied during the enemy's turn, the status functionally never applies. That said, debuffs don't necessarily apply during the enemy's turn, as counterattacks can apply the debuff as well. After thinking all of that through, what makes sense for our game's design if we want "Hook" to effectively cost the target exactly one turn's movement? If it gets hooked twice, it might proc twice and apply two stacks, fine, but let's start by reasoning our way around this design problem. I hope I've adequately identified the problem, now let's figure out a solution!

8a Club: probably a chance to apply a debuff
8b Thump chest: applies a buff to self but I haven't thought through what. Need to brainstorm.

9. I put this on there because it needed somewhere to go, but this isn't making it into the real move JSON, obviously. Since I'm leaning on you to actually run the first pass of the move distribution, you need to know who gets the moves and why. This field is for your sake (I'm communicating my preferences), and for mine (helps to remind myself for later)

10a. Regen: this is a really good point. Let me think for a minute...
I think these should stack. If a unit has that passive assigned, and that buff applied, they'd regenerate twice at the beginning of each turn.

10b. Coding the passives - can you add a section to this document which lists the passives which have entries but no code yet? We'll code them next. Let me know what you think the best design for this is. I'm thinking it's a per-passive script which hooks into the phases of the game when they apply, but there's probably a "best practice" way to do this. Please walk me through it when it's time - this is a game design blind spot for me.

11. This derivation was meant to be a default, so that we didn't have to use brainpower to determine a move's usage limit. In general, more powerful moves should get less usage. This was always meant to be overridable. For moves without a power rating, 30 is *probably fine*, but I'm sure we'll need to apply offsets to some of the more overpowered ones.

12a. Tummy Bounce: I'm set on "bounce," but I don't like "tummy." Might literally just call it "bounce," but idk because that's what a basketball does too... Out of what's on offer, "tummy bounce" is still the best I think.
12b. Shriek of the Damned: I love the Void or Occult thing. Probably occult. Lock that in. Void can have a "deafening silence" version or something. I would love for it to have a nonstandard/unique effect. For the moment, let's think outside of the game's mechanics - what would a "shriek of the damned" do? Once we get some ideas, we can figure out how to express that within the game's mechanics. This is that merger of gameplay and narrative I like!

### Reply

1. Can you please add a detailed entry about the requirements here to todo.md? We'll tackle that branch once we're done here.

3. Oh it's coming back to me... that 2x was put in place after playtesting revealed that 1.5 wasn't enough. MAy end up switching it back. But for now, let's refactor with 2x. Certain moves have a "chance to apply secondary," and that secondary can be "crit." So e.g. some moves have "30% chance to apply BURN," some moves have "30% chance to apply CRIT." The main difference is that Crit is a one-time damage bonus, not a debuff that gets applied to the unit. Does that make sense? Because moves have only one secondaryEffect, they can only have one of these effects unless there's a custom script. Am I making sense?

5. YOU'VE GOT ME THINKING - What if it applies SHOCKED, but works differently for Chivalric units: applies CHALLENGED. I love that.

6. I want to call it "Bounce Out". Constitution is indeed a CharacterData field, but it doesn't increase at level up. There will be other means but a unit is broadly stuck with their constitution rating until changing class.

7. This fix sounds correct. Let's implement.

8b Thump Chest - I agree - apply RALLIED to self.

10b hook dispatcher. Same as #1, let's add a detailed implementation plan in todo.md, and we'll tackle that very soon.

12a. Changing it to "Bounce Out"!

12b. I like the crowd control angle. Chivalric types immune. I also kinda like the idea of making it AOD - target self, AOE = 5 (needs playtest) and after one turn, any non-Chivalric units get Chain Lightning'd.
12b.a. I think I want a "Bravery" passive that grants all of Chivalric's mecahnical properties without it actually being the Chivalric type (so it would not get Chivalric's weaknesses/resistances, but it'd be challenged by "Roar" and immune to "Shriek of the Damned")



<!-- NOTE FOR AI AGENTS: Move Naming Conventions
This game uses a specific naming style for moves that is simple, nonpretentious, and borders on ironically simple.

TONE GUIDELINES:
- Simple and direct (usually 1-2 words)
- Functional/descriptive - the name tells you what the move does
- Nonpretentious - no flowery fantasy language ("Guard Break" not "Radiant Celestial Cleave of the Eternal Dawn")
- Bordering on ironically simple - people might go "wait, 'Bonk'? seriously?" but we're NOT going full comedy/cringe
- Can sound cool as long as it doesn't violate the above rules ("Singularity" works because it's still just descriptive)
- This is a fun idiosyncrasy of the game that matches the protagonist's character, not a joke

GOOD EXAMPLES: Bonk, Klunk, Zap, Singularity, Guard Break, Snap Freeze, Dropkick
BAD EXAMPLES: Supreme Devastating Ultra Punch, Blade of Eternal Shadows, Mega Death Strike 9000

Think: what would a practical person call this move? What's the most straightforward name that still sounds decent?
-->

# Moves & Passives

Every move and passive idea in one place: what's shipped, what's spec'd, what's
only a name. Consolidated from move-list.md, the design-side BasicMoveBank.json,
scratch/moves_and_passives_needed.md and the move-template stubs — all four are
gone; nothing was dropped.

Reading a row:
- `[shipped — Elem/Dmg pN rN, rider]` is live in data/moves/basic_move_bank.json
  (passives: a handler in PassiveRegistry). The live file wins over anything
  written here; "early spec" notes are ideas the build didn't take.
- A bare `pN` is the old design-bank power tier (3 / 7 / 11 / 13 = weak / mid /
  strong / heavy). A number, not a promise.
- No tag = a name and nothing else.
- `→ Class` = the class tree that claims it (.claude/todo.md class sketches).
- `(needs X)` = a mechanic from the list below.

JSON field reference: the `MoveData` and `PassiveData` class headers.

## Rules

- A move has ONE element. A "dual-typed" idea becomes that element plus the
  other type's status as its secondary, Scald style: Fire→Burn, Cold→Freeze,
  Electric→Shocked, Air→Hasted, Plant→Rooted, Occult→Vulnerable,
  Gravity→Gravity, Void→Void.
- A passive's JSON entry is names + descriptions only. It does nothing until a
  handler is registered by name in PassiveRegistry — step 2 of 2.

## Mechanics no move can use yet

Each needs parser + combat support before the moves that want it can ship.

- **Move priority** — attacks before the opponent unless theirs also has
  priority: the Cold priority move. Riposte is the inverse (always moves last).
- **Lifesteal** — Siphon.
- **Defense-pierce %** — Ice Pick, Epée, Plasma Cutter, Turret attack,
  Monomolecular Edge. Early specs for Lance and Laser had it too.
- **Splash %** around the target — Vortex.
- **Pass-through** — on hit the attacker moves to the tile behind the target:
  Stampede, Razor Wing. The needs list also wanted "an attack which swaps the
  user's position with the tile behind it"; Switcheroo (shipped, "for testing")
  swaps with the target instead.
- **Self-reposition** — Soar (up to 3 tiles, free), Whirlicopter (3 tiles in
  one direction, healing the tiles beneath).
- **Terrain statuses** — data/terrain_data.json names nine (Rain, Scorch, Flood,
  Snow, Wind, Tornado, Electric, GravityWell, Distortion) but the engine only
  reads per-terrain immunity lists; nothing applies one to a tile. Wanted by
  Sunflower's rain clause, Pod, Soar's ignore clause, and two immunity passives.
- **Indirect damage** as a category — for the immunity passive.
- **Free attack on approach** — Zone Control.
- One needs-list line was never finished: "attack which …". Kept so it isn't
  mistaken for a deletion.

## Moves

### Air/Physical
+ Peck — p3 acc100, knockback 1. Only units with beaks.
+ Big Beak — p6 acc85. More brutal pecking move from a creature with a large beak. Only units with *large* beaks.
+ Razor Wing — p5 acc80. Flies through the target: if the tile behind is free the attacker moves there and the hit applies Bleed. Units with wings. (needs pass-through)

### Air/Special
+ Compressed Air — [shipped — Air/Special p4 r2, Hasted 30% self, displace 1 self] — (early spec: knockback 1) // Ernesto et al, basic air attack
+ Cyclone — [shipped — Air/Special p8 r2]
+ Lashing Vortex
+ Tailwind
+ Updraft
+ Vacuum — p11, pull then knockback 2 — net 1-tile pull.
+ Vortex — p7, splash radius 1 at 50% damage.
+ Whirlwind
+ Soar — Support, self, range 3. Repositions the unit up to 3 spaces away, ignoring terrain statuses of any terrain traversed. Fliers only. (needs self-reposition)

### Chivalric/Physical
+ Charge — p11, knockback 2.
+ Deft Blow // Weak attack, buff agility (priority move?)
+ Guard Break — [shipped — Chivalric/Physical p5 r1, Vulnerable 30%] // pure damage/ignores all modifiers/debuffs enemy defenses
+ Joust — p3
+ Lance — [shipped — Chivalric/Physical p7 r2] — (early spec: ignores 30% of defense)
+ Rend — p13
+ Rush
+ True Shot // ranged attack

### Chivalric/Special
+ Challenge
+ Knight's Honor
+ Wrath
+ Vigilance
+ Fortify — [shipped — Chivalric/Support p0 r0, Fortified 100% self] // Plants the feet and braces for incoming damage.

### Cold/Physical
+ Cold Hands — p3
+ Crystallize
+ Frost Bite // literal biting move
+ Ice Pick — p7, ignores 30% of defense.
+ Shatter — p11
+ (unnamed priority move) — p4 r1 acc100, 15 uses. Attacks before the opponent unless their move also has priority. (needs move priority)

### Cold/Special
+ Coolant — p3 // Robots/Engineers - basic cold attack
+ Freeze — p7
+ Glacier — [shipped — Cold/Special p9 r1, Freeze 30%]
+ Permafrost — p11
+ Snap Freeze — [shipped — Cold/Special p5 r2, Freeze 50%]
+ (unnamed) — p9 r1 acc100, 10 uses. No effect written down yet.

### Electric/Physical
+ Direct Current — p7
+ ESD — p3, electrostatic discharge.

### Electric/Special
+ Alternating Current
+ Arc Lightning — p11, chain lightning magnitude 3.
+ Arc Weld // applies burn status
+ Overload — [shipped — Robo/Special p9 r1, Shocked 60%]
+ Shock — [shipped — Electric/Special p6 r2, Shocked 50%]
+ Short Circuit
+ Voltage Surge
+ Zap — [shipped — Electric/Special p4 r2, Shocked 30%] — (early spec: p7) // workhorse electric attack, medium damage, good status chance
+ Thunder Bolt — [shipped — Electric/Special p9 r3] // A long-range bolt of lightning. No frills.

### Fire/Physical
+ Plasma — p11, chain lightning magnitude 2. // Applies ChainLightning status
+ Plasma Cutter — p7, ignores 50% of defense. Robo/Engineer. // Robo/Engineer -
+ Weld — p3
+ Flame Strike — [shipped — Fire/Physical p8 r1, Burn 50%] // A fiery physical attack that may burn the target.

### Fire/Special
+ Blaze — [shipped — Fire/Special p11 r2, Burn 40%]
+ Immolate — p11
+ Inferno
+ Scorch — [shipped — Fire/Special p5 r2, Burn 30%]

### Gentry/Physical
+ Backstab — [shipped — Gentry/Physical p9 r1]
+ Disarm
+ Epée — p7, ignores 50% of defense.
+ En Garde
+ Feint — [shipped — Gentry/Physical p4 r1, Focused 40% self]
+ Fisticuffs — p3
+ Flintlocks
+ Flourish
+ Lunge
+ Riposte — p11. Always moves second; critical damage if the enemy misses. (needs move priority)

### Gentry/Special
+ Conspire
+ Extort — p7
+ Leverage
+ Maneuver
+ Negotiate
+ Provoke
+ Scheme
+ Subversion
+ Focus — [shipped — Gentry/Support p0 r0, Critical 100% self] // A breath of concentration. Sharpens the user's next strike.

### Heraldic/Physical
+ Advance
+ Charge
+ March — [shipped — Heraldic/Physical p5 r1, Rallied 30% self]
+ Flank — p7 // +50% for side attack, +100% for backstab
+ Phalanx
+ Press
+ Swarm // Low damage, applies Bugle effect to single target
+ Trample
+ Volley — [shipped — Heraldic/Physical p6 r3] // coordinated ranged attack
+ Wedge

### Heraldic/Special
+ Bugle // applies Bugle in AoE
+ Retreat
+ Sacrifice
+ Standard // Buffs nearby friendlies, increased buff for heraldic types
+ Battle Cry — [shipped — Heraldic/Support p0 r0, Rallied 100% self] // A rousing shout that bolsters the user's resolve.

### Gravity/Physical
+ Crush
+ Impact — [shipped — Gravity/Physical p9 r1]
+ Meteor
+ Meteorite — p11
+ Slam
+ Spatial Collapse // Heavy damage to single enemy
+ Mass Drive — [shipped — Gravity/Physical p5 r1, displace 2] // A wall of leaden force. Whatever it hits, hits the next thing over.
+ Shockwave — [shipped — Gravity/Physical p4 r1, displace 1] // A flat slab of force that bowls over the whole rank.
+ Switcheroo — [shipped — Gravity/Physical p1 r1, displace 1 self] // Tap and trade — the universe briefly loses track of who was where. For testing.

### Gravity/Special
+ Anchor
+ Gravitate
+ Gravity Well — [shipped — Gravity/Special p5 r2, Gravity 50%] // Low damage, crowd control
+ Lash — p7
+ Orbit — [shipped — Gravity/Special p2 r2, displace 1]
+ Pull — p3, movement/repositioning.
+ Singularity — p11 // Low damage, wide AoE crowd control - heavy damage at epicenter
+ Tether
+ Yank
+ Grav Hook — [shipped — Gravity/Special p3 r3, displace 2] // A tether of collapsing space that reels the target in.
+ Slingshot — [shipped — Gravity/Special p3 r2, displace 3] // Flings the target along a gravity assist — clean over anyone in the way.

### Occult/Physical
+ Leech — [shipped — Occult/Physical p6 r1]
+ Pinprick — p3
+ Rust
+ Siphon — p7, lifesteal 50% of damage dealt; drains stats/resources. (needs lifesteal)
+ Wither — [shipped — Occult/Special p4 r2, Vulnerable 50%]

### Occult/Special
+ Bleed
+ Blight
+ Blood Magic
+ Haunt
+ Hemorrhage — p11
+ Hex — p7 // Apply random status
+ Jinx
+ Locusts
+ Omen
+ Screech — p3
+ Sigil
+ Wail
+ Shriek of the Damned — [shipped — Occult/Support p0 r0 aoe5, delayed chain_lightning_strike] // A scream from somewhere no one living should have stood. The marked are struck by chain lightning one turn later — cleanse the mark to defuse it. The brave do not flinch, and are passed over.

### Plant/Physical
+ Club — [shipped — Simple/Physical p5 r1] — (stub note: low power so the unit relies on its own strength — maybe it should also apply a status)
+ Ensnare
+ Root — [shipped — Plant/Special p5 r2, Rooted 50%] — (early spec: Physical p3)
+ Strangle — [shipped — Plant/Physical p9 r1, Rooted 40%]
+ Thorns
+ Vines — p7. Early-game workhorse Plant damage move — the name stays, plain is the tone (may need a more specific name later). Vine Lash (shipped) is the closest existing.

### Plant/Special
+ Acid — p11
+ Photosynthesis
+ Sap — p3, drains/weakens.
+ Spores — p7
+ Wilt
+ Sunflower — ranged beam, medium power, Burn secondary (the Scald rule) → Pyracantha. Huge power cut while the user stands on a Rain tile. (needs terrain statuses)
+ Whirlicopter — Support, late game, 2–3 uses: repositions the user 3 tiles in one direction, healing the tiles beneath (units on them, or a healing plant terrain status — ties to Pod) → Samara. "OP as fuck" by design. Has its own todo entry. (needs self-reposition)
+ Pod — applies a plant-based terrain status; shape TBD → Plant Healer. (needs terrain statuses)
+ Vine Lash — [shipped — Plant/Special p4 r1, Rooted 30%] // Lashing vines that may root the target in place.
+ Bloom — [shipped — Plant/Support p0 r0, Regen 100% self] // Calls forth a brief regenerative bloom around the user.

### Robo/Physical
+ Backhand — [shipped — Robo/Physical p8 r1] — (early spec: knockback 1) // Ernesto's robo-fist, hits the space in front and two adjacent cells with reduced damage.

### Robo/Special
+ Laser — [shipped — Robo/Special p4 r3, Focused 30% self] — (early spec: ignores 20% of defense) // basic robotic attack
+ Deploy Turret // Ernesto's toolbox. Sets down a powerful turret but disables ALL special moves (for the rest of the battle? while it's active?). Max one deployment.
+ Turret attack — p7, ignores 30% of defense; fires a laser from the deployed turret. // fires a laser out of a turret

### Simple/Physical
+ Bonk — [shipped — Simple/Physical p3 r1] // Default/basic attack with infinite uses
+ Dropkick — p11 // Heavy attack, applys one turn vulnerable to self
+ Elbow
+ Hook — design bank p7; the stub says p2 acc75, 30% Rooted on hit — the ogre's hook hand, any unit with a hook. → shipped as Hook Swipe ("a raking hook that can snag the target in place").
+ Klunk — [shipped — Simple/Physical p7 r1] // overhead fist slam
+ Slash
+ Stab
+ Throttle
+ Uppercut — [shipped — Simple/Physical p5 r1, Critical 25% self]
+ Stampede — p5 acc70. If the tile behind the target is free the attacker moves there and the move auto-crits. For large bois who could plausibly trample things. (needs pass-through)
+ Clobber — p7 acc85. Simple, devastating. Brute-force units get it, but it's probably too powerful for early game.
+ Tummy Bounce → shipped as Bounce Out (p2 displace 1 in the stub; the belly body-check for large bois with a large gut — RQD wanted a better name than "tummy").
+ Hook Swipe — [shipped — Simple/Physical p3 r1, Rooted 40%] // A raking hook that can snag the target in place.
+ Colossus Punch — [shipped — Simple/Physical p11 r1, Shocked 100%] // A massive wind-up haymaker. Often misses — but on impact, the blow rattles the target senseless.
+ Bounce Out — [shipped — Simple/Physical p4 r1, displace 2] // A belly-first body check that bounces the target away — into a wall, if one obliges. Stout foes stand their ground.
+ Megaton Punch — [shipped — Simple/Physical p50 r1] // A devastating blow. For testing only.

### Simple/Special
+ Covering Fire // enemies in AoE suffer accuracy penalty, chance for damage if they move
+ Focus — [shipped — Gentry/Support p0 r0, Critical 100% self]
+ Fortify — [shipped — Chivalric/Support p0 r0, Fortified 100% self]
+ Klaxon
+ Sharpen // Buff Attack
+ Thump Chest — Support, self. Unit beats his chest to apply a buff to himself — possibly other units in the area, not thought through; ideas wanted. Battle Cry (shipped) may cover it.
+ Sidearm — [shipped — Simple/Special p4 r3, Focused 30% self] // A practiced shot from a service pistol. Reliable at range.
+ First Aid — [shipped — Simple/Support p2 r1, heals, cleanses Bleed] // Patches up a wounded ally and stems any bleeding.
+ Steady — [shipped — Simple/Support p0 r1, cleanses Chain_Lightning/Shocked] // A firm hand and a steadying word. Grounds out lightning marks and settles rattled nerves.
+ Roar — [shipped — Simple/Support p0 r0 aoe2] // A challenge bellowed across the field. Nearby foes are rattled — but the brave hear an invitation.

### Void/Physical
+ Blink
+ Collapse
+ Dissolve — p11
+ Null Zone // AoE, removes effects off all passives and injuries
+ Tear — p7
+ Void Fissure // Pure Damage/Ignores Defense
+ Shear — p6

### Void/Special
+ Distort — p7
+ Erase — [shipped — Void/Special p8 r2]
+ Flicker
+ Fizzle
+ Roil
+ Silence
+ Void Touch — [shipped — Void/Special p4 r1, Void 40%] // A touch that disrupts the target's abilities.

### Obsidian/Physical
+ Impenetrable
+ Mass Shift — [shipped — Obsidian/Physical p7 r1]
+ Monomolecular Edge — p11, ignores 100% of defense.
+ Phase Shift

### Obsidian/Special
+ Dark Energy — [shipped — Obsidian/Special p11 r2]
+ Matter Reconstruct
+ Nano Mesh

## Passives

### Shipped (handler in PassiveRegistry)

Anti-Gravity, Bellows, Bravery, Capricious, Competitive, Extendo, Flippant,
Ghost, Glib, Impetuous, Impulsive, Jury Rig, Low Profile, Protector,
Regenerator, Reliable, Stellar, Waste Not. Maximum is a stat-calc rule, not a
handler. Descriptions live in data/passives.json.

### In data/passives.json, no handler yet

+ Cavalier — attacking stats cannot be buffed or debuffed by moves
+ Reckless — increased terrain bonuses and penalties
+ Zone Control — enemies that move within this unit's attack range trigger an
  immediate free attack (needs free attack on approach)

### Wanted — the needs list

+ Immune to specific terrain status effects (needs terrain statuses)
+ Immune to ALL terrain status effects (needs terrain statuses)
+ Immune to indirect damage (needs indirect damage as a category)
+ Recovers HP when displaced — playtest, thinking 25% to start
+ Recovers HP at the start of each turn — shipped as Regenerator (8%, not the
  6.25% first written)
+ +30% move damage, spends 10% HP when attacking, can't use support moves
+ Lowers the enemy's physical attack when moving to an adjacent space
+ Physical attacks from adjacent spaces against this unit have a chance to
  cause … (the line was never finished)
+ 10% chance to heal each adjacent unit's status at the end of each turn
+ Recovers HP when ending its turn without attacking — playtest, 25% to start
+ Heals status effects when healing on a healing tile
+ Ignores the enemy's stat buffs (Cavalier is the mirror: own attacking stats
  can't be buffed or debuffed)
+ When hit by a move of type X, gains a resistance to X until the player's next
  turn, whereupon the passive is disabled for the rest of the fight
+ [Ernesto] ranged attacks hit everything between him and the target for
  reduced damage (including friendly units?)

### Wanted — Plant Healer tree (Lawrence's list)

+ Turgor — DEF and RES up while above 80% HP → Taproot. Turgor pressure: a
  hydrated plant is rigid, a wilted one is limp. A conditional stat modifier
  like Maximum; the stat recompute must also fire on HP change (today it runs
  on turn start, movement and defeat only).
+ Stolon — if this unit starts its turn on a Plant tile, every Plant tile
  within 3 spaces heals player units on it 10% per turn → Taproot. A turn-start
  handler like Regenerator plus a terrain query. "Plant tile" = terrain_type
  Plant / VolcanicPlant (Plant units already get +20% attack and move cost 1
  there).
+ Clover — boosts all dice rolls → Bulb pool. Rolls the engine makes: hit,
  crit, status chance, friendly fire, level-up growths. Decide whether "all"
  reaches growths — that would make it a growth passive as well as a combat one.

# Factions
## "Court Jester" themed knight tribe
+ Knights ride "battle chickens" that are more like battle ostrichs
  - protagonist actually refers to them as "battle chickens," other characters use their real name
### Evil 12yo kid ruler sociopath guy
## Spaceman Faction
### Protagonist
  - "what happens if I shoot it?"
  - opening scene: he's sneaking up on Ernesto to do some prank and BAM - alarms on the space ship - Ernesto asks "WHAT DID YOU DO" and he says "NOTHING YET" - then the ship emergency lands
  - 
### Tall spaceman (Ernesto)
 - power fist style signature weapon
 - ship engineer
 - taciturn
 - gets along well with commander
 - generally competent
 - likes the protagonist, even likes his antics but doesn't encourage them
 - 
### Mentor female commander character ("Ma'am")
 - reached rank of major/colonel, unusual for a woman
 - light, not physically imposing
 - crafty and ruthless
 - wise, informed, hardheaded, determined, driven, has naturally good instincts from experience
 - dies early on in the story, leaving your squad at a loss of what to do
  -- immediately, they start having bad ideas that backfire
 - pragmatic, sound reasoning, *you should feel safe around this character* so when she dies you get that feeling of being lost
 - she should like the main character but also be hard on him, doesn't put up with his bullshit
 - maybe she doesn't need a space suit because she got the implant
 - 
## Mercs
## More neutral knight tribe
+ Casts the squad out, refusing to help
### Ogre squire
- helps out the squad when the locals won't
- points them to the mountain village (or whatever) and joins their squad
- literally pops out of a bush
## Plant zombies
## Insectoids
## Malfunctioning AI robots
+ why the locals don't like the protagonists ("you offworlders brought the machines")
+ fractal design, they're malfunctioning so their designs don't have to make sense

# Characters
### Sniper character with Squig-hopper-like companion
 - can't move and shoot sniper in same turn
 - Squig thing will go rogue if it isn't within X spaces of its master

### Ancient multi-eyed gravity commander guy
- you let him out of a black hole
- 

### Elf thief/pirate who likes treasure
 - loves treasure
 - rejected her elf ways
 - will cut you to get the treasure
 - gullible and/or anxious?

## Line-art batch of 2026-09-07 (Lawrence), roles decided 2026-09-12
Finished ink is in `art/lineart_fullres/`. Characters that fight have a JSON
stub (provisional stats, 16px `placeholder_unit` sprite, in no spawn pool) and
a `_portrait.tres` crop. NPCs are art only until ally/neutral spawn wiring and
a dialogue system exist. Seven more sheets in that batch are opaque paper
roughs of shipped characters, tracked in `.claude/todo.md` §4.

### Thief (`assassin.png`)
- Homeless on purpose: see the Thief class tree in `.claude/todo.md`. Player
  status undecided, no sprite, no data.

### Ex-gentry swordsman (`ex_gentry_swordsman.json`, placeholder name "Swordsman")
- Defected from his fiefdom after realizing the depth of the corruption among
  the nobility
- Does not trust offworlders and reacts violently; some series of events (TBD)
  wins him over to the squad's cause
- Data: Gentry / Duelist. Starts hostile, recruitable later.

### Ex-plant cultist (`ex-plant_cultist.png`), NPC
- A Creeper by design (the Cultist tree's 2B)
- Has a unique perspective for the player sometime in the midgame, after the
  first encounter with the plant cultists
- Suggestion: the reserved name "Host" fits a body that a plant moved into

### Gentry prince (`gentry_prince.json`), enemy
- Similar deal to Pierre: somewhat pompous, skilled
- Better people skills: charming, studied, familiar with galactic affairs
  beyond his fiefdom
- Data: Gentry / Noble

### Old creature (`old_creature.png`), NPC probably
- Old, wise

### Pica's sister (`pica's_sister.png`), NPC; might be playable very late
- Pica doesn't like people to know that she comes from nobility; all of her
  pirate friends turned to piracy because of poor material circumstances
- Her sister finds her situation both amusing and concerning

### Tipsy goblin (`tipsy_goblin.json`), ally probably
- A goblin who enjoys a drink a little too much
- Poor combat skills; gotta find some other use for him
- Data: Monster / Engineer. Ally spawn wiring doesn't exist yet.

### Wooly beast (`wooly_beast.json`), enemy
- Similar to the Ogre, less strong, much more mobile: an extreme threat
- Data: Beast / Cold, Heavy. Kept out of `enemy_spawn_pool` on purpose; it
  would wreck the level-1 mix.

### Pirate boss (`pirate_boss.png`, paper rough only)
- Eyepatch, bandana, poncho, cutlass. Lore TBD. Pica's old captain?

# Mechanics
## Primary Stats
+ HP (Heft? Size?)
+ Strength
+ SpAtk (Wisdom?)
+ Defense (Constitution?)
+ SpDef (Reistance? "Heft?")
+ Athleticism (chance for enemy to miss/chance for double/triple attacks - do we want to split this into two)
  - num attacks = unit_ath%enemy_ath, but at least 1 
+ Skill (chance to hit)
+ Luck?

## Secondary Stats
+ Move
+ Constitution
+ Rescue

## "Evolutions"
+ Class up for spacemen: jump-packs: stats go down, but they can move far and go through enemy units
+ 

## Combat
### Need five sprites ~~per character~~ per class (class variants should be more or less minor variations on established sprites)
+ Idle
+ Attack1
+ Attack2
+ SpAtk1
+ SpAtk2



### Fire Emblem mixed with Pokemon
+ Instead of weapons they have four slots for moves (attacks/active abilities)
+ Attacks have types with weaknesses/resistances
+ Speed is buffed - can triple, quad attack, etc if spe%enemy_spe >= 3 or 4
+ Four-slot passive abilities

## Class Up
+ Units can "evolve" into one of two second-tier units
+ Do we want a third tier? We'd need 7 sprites per character at that point :/
  - That said they could be variations on the other units

## Injury System
 - a character "dying" in a mission will give them an injury that takes X amount of time to recover from
 - injuries reduce stats
 - injuries can become permanent and take up 1-2 slots
 - if you get 4 slots worth of injuries, your character dies permanently
 - injuries are VERY crippling until recovered from, then only slightly crippling

## Damage System
+ See first draft of damage triangle in this directory (image)
+ Replace "electric" with "robot" or "biomech" or something. and that encompasses steel/electric
+ "Dimensional" magic? (gravity)
+ 

# Lore
## Setting - the Milky Way, year 36 PEE (ok we definitely need a better phrase for that)
+ Humans had joined the interstellar community and prospered for centuries
+ AI had been developed, gone rogue, and been re-wrangled by better AI. AI going rogue is just an accepted part of technological progress at this point. And it goes rogue in weird, unexpected ways.
+ FTL travel exists, but requires mass (waves can't travel faster than light) so you need courier vessels
+ Generic FTL (allowing rapid travel within a star system) is available on almost all space vessels
+ For near-instant interstellar travel, you need to enter the slipspace network, and you need a large massive object (usually a star) to enter slipspace
+ Relays allowing entry to slipspace constituted the interstellar network which allowed near-instantaneous interstellar travel. One or more of the key relays was destroyed during the Equinox event, dramatically reducing the size of the interstellar network. (We don't know because you'd have to go through that relay and come back to find out)
+ Reconstruction of the network is a key priority of all interstellar civilizations, but it will likely take centuries if not millenia to rebuild
### ((The Planet))
#### ((Court Jester Knights))
+ Dominant species on the planet are humanoids with a feudal/medieval society.
+ They are luddites and distrustful of tech and anyone from offworld because "they brought the machines" - some rogue AI bots
+ Their tech is a mix of high-and-low-tech, mainly swords, lances etc
### The Equinox Event
+ cataclysmic event that took out slipspace relays in the galaxy
+ 
#### Obsidian
- A rogue AI colloquially referred to as "Obsidian" expanded throughout the galaxy, creating megastructures and taking out most, if not all of the slipspace relay network nodes
- Its intentions are unknown, it just seems to expand as it sees fit, creating megastructures
- It is called "Obsidian" because of the appearance of its megastructures. Inspired by that concept art from Overgrowth but much more square and obsidian-textured
- There probably shouldn't be any on ((The Planet)) but maybe one in this star system?
- Attempts to interface with Obsidian have yielded confusing and mysterious results.
- Most people advise to steer clear of it, but people just accept it existing, at a distance
- The megastructure is extremely, almost impossibly, light and durable

## Per-class stat ceilings, and the global ceiling they sit under.
##
## TWO ceilings, and every cap readout in the game needs both:
##
##   GLOBAL     the highest any unit could ever reach, at any class, at Lv 60.
##              Fixed. Sets the SCALE that every bar is drawn against, so bar
##              lengths mean the same thing on every unit on every screen.
##   BY_CLASS   this class's ceiling. Always <= GLOBAL. Sets how far along that
##              global scale a given unit is allowed to travel.
##
## A bar drawn from these reads two facts at once: fill length is proportional
## to the raw stat (so units are directly comparable), and track length shows
## how much headroom the class has left. See [StatCapBar].
##
## GLOBAL is deliberately fixed rather than derived from "the highest class cap
## in the table". Deriving it would mean tuning any single class silently
## rescales every bar in the game, and a balance pass on Void Knight would move
## a Lv 3 Grunt's bar for no reason the player could ever see.
##
## Caps are what LEVEL-UPS AND GROWTHS respect. Allocated StatUps are allowed
## to exceed them — see [CharacterData.is_at_stat_cap], which reads
## get_base_plus_growth() and never the allocated total. That is the rule, not
## an oversight: a cap bounds what a unit GROWS into, while StatUps are a
## deliberate player investment on top.
##
## THE TIER LADDER (how these numbers were derived). Levels run 1-60 across
## three tiers of 20. A unit should bump its class caps near the top of its
## tier, which is what makes promotion feel necessary rather than automatic.
## With growth rates around 40-60%, twenty levels adds roughly 8-12 to a good
## stat, so each tier's caps sit about one tier's growth above the last:
##
##   tier 1   HP 34-48    other stats 8-23
##   tier 2   HP 58-70    other stats 16-34
##   tier 3   HP 85-95    other stats 28-48   (approaching GLOBAL)
##
## EVERY NUMBER BELOW IS PROVISIONAL. They are archetype-shaped guesses with
## arithmetic behind them, not measurements — authored 2026-08-06 so the cap
## UI has real data to render, and expected to move in balance passes. What is
## settled is the SHAPE: the ladder above, and that class identity shows up as
## which stats are allowed to get tall.
class_name ClassStatCaps


## The order every table below uses. Also the canonical stat-name list for
## anything iterating caps.
const STAT_NAMES: Array[String] = [
	"max_hp", "strength", "special", "skill",
	"agility", "athleticism", "defense", "resistance",
]

## The tier-3 ceiling. HP runs 2:1 against every other stat, matching the
## ratio StatFingerprint already draws with.
const GLOBAL: Dictionary = {
	"max_hp": 100,
	"strength": 50,
	"special": 50,
	"skill": 50,
	"agility": 50,
	"athleticism": 50,
	"defense": 50,
	"resistance": 50,
}

# Row order: HP, STR, SPC, SKL, AGL, ATH, DEF, RES.
const BY_CLASS: Dictionary = {
	# --- Tier 1 -------------------------------------------------------------
	# Starter classes. Generalists cap low everywhere; specialists buy one or
	# two tall stats by giving up the rest.
	Enums.CharacterClass.SPACEMAN:
		{"max_hp": 44, "strength": 18, "special": 15, "skill": 17,
		 "agility": 17, "athleticism": 15, "defense": 16, "resistance": 14},
	Enums.CharacterClass.MERCENARY:
		{"max_hp": 44, "strength": 20, "special": 11, "skill": 19,
		 "agility": 15, "athleticism": 14, "defense": 17, "resistance": 11},
	Enums.CharacterClass.SQUIRE:
		{"max_hp": 42, "strength": 16, "special": 12, "skill": 15,
		 "agility": 14, "athleticism": 13, "defense": 18, "resistance": 12},
	Enums.CharacterClass.NOBLE:
		{"max_hp": 42, "strength": 17, "special": 16, "skill": 18,
		 "agility": 16, "athleticism": 14, "defense": 15, "resistance": 17},
	Enums.CharacterClass.ENGINEER:
		{"max_hp": 46, "strength": 18, "special": 11, "skill": 17,
		 "agility": 11, "athleticism": 13, "defense": 19, "resistance": 10},
	Enums.CharacterClass.PIRATE:
		{"max_hp": 42, "strength": 19, "special": 10, "skill": 16,
		 "agility": 18, "athleticism": 17, "defense": 12, "resistance": 10},
	Enums.CharacterClass.FIGHTER:
		{"max_hp": 46, "strength": 22, "special": 9, "skill": 15,
		 "agility": 14, "athleticism": 16, "defense": 13, "resistance": 9},
	Enums.CharacterClass.ENIGMA:
		{"max_hp": 36, "strength": 10, "special": 21, "skill": 16,
		 "agility": 15, "athleticism": 12, "defense": 10, "resistance": 20},
	Enums.CharacterClass.SKULK:
		{"max_hp": 38, "strength": 13, "special": 13, "skill": 20,
		 "agility": 20, "athleticism": 16, "defense": 11, "resistance": 13},
	Enums.CharacterClass.DUELIST:
		{"max_hp": 38, "strength": 15, "special": 12, "skill": 22,
		 "agility": 19, "athleticism": 15, "defense": 11, "resistance": 12},
	Enums.CharacterClass.MAGE:
		{"max_hp": 34, "strength": 9, "special": 23, "skill": 17,
		 "agility": 14, "athleticism": 11, "defense": 9, "resistance": 19},
	Enums.CharacterClass.HEAVY:
		{"max_hp": 48, "strength": 19, "special": 9, "skill": 12,
		 "agility": 8, "athleticism": 10, "defense": 22, "resistance": 13},
	Enums.CharacterClass.GRUNT:
		{"max_hp": 38, "strength": 15, "special": 10, "skill": 13,
		 "agility": 12, "athleticism": 12, "defense": 13, "resistance": 10},
	Enums.CharacterClass.KEENER:
		{"max_hp": 36, "strength": 10, "special": 20, "skill": 15,
		 "agility": 14, "athleticism": 12, "defense": 10, "resistance": 22},
	Enums.CharacterClass.BANDIT:
		{"max_hp": 46, "strength": 21, "special": 9, "skill": 12,
		 "agility": 14, "athleticism": 16, "defense": 14, "resistance": 8},

	# --- Tier 2 -------------------------------------------------------------
	# First promotion. Roughly one tier of growth above tier 1, and the
	# archetype gets sharper rather than merely bigger.
	Enums.CharacterClass.JETPACK:
		{"max_hp": 60, "strength": 27, "special": 20, "skill": 28,
		 "agility": 32, "athleticism": 30, "defense": 20, "resistance": 20},
	Enums.CharacterClass.HARDCASE:
		{"max_hp": 68, "strength": 31, "special": 16, "skill": 24,
		 "agility": 20, "athleticism": 22, "defense": 32, "resistance": 20},
	Enums.CharacterClass.KNIGHT:
		{"max_hp": 66, "strength": 29, "special": 18, "skill": 25,
		 "agility": 19, "athleticism": 20, "defense": 34, "resistance": 24},

	# --- Tier 3 -------------------------------------------------------------
	# Endgame. Approaches GLOBAL on the class's defining stats and stays
	# visibly short of it everywhere else — nobody caps the whole board.
	Enums.CharacterClass.EVA:
		{"max_hp": 92, "strength": 44, "special": 30, "skill": 40,
		 "agility": 38, "athleticism": 40, "defense": 42, "resistance": 32},
	Enums.CharacterClass.TOPDOG:
		{"max_hp": 88, "strength": 42, "special": 38, "skill": 44,
		 "agility": 42, "athleticism": 38, "defense": 38, "resistance": 38},
	Enums.CharacterClass.VOID_KNIGHT:
		{"max_hp": 90, "strength": 36, "special": 46, "skill": 38,
		 "agility": 32, "athleticism": 32, "defense": 40, "resistance": 48},
}


## This class's ceiling for `stat_name`. Falls back to GLOBAL for any class
## missing from the table — a new enum entry then behaves as "uncapped below
## the global ceiling" rather than silently capping at zero and freezing every
## growth roll for that class.
static func for_class(character_class: Enums.CharacterClass, stat_name: String) -> int:
	var caps: Dictionary = BY_CLASS.get(character_class, {})
	return caps.get(stat_name, global_cap(stat_name))


## The fixed ceiling every bar is scaled against. 20 for an unknown stat name
## matches the old CharacterData.get_stat_cap fallback.
static func global_cap(stat_name: String) -> int:
	return GLOBAL.get(stat_name, 20)

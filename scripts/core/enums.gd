## Single source of truth for all game enums.
## Usage: Enums.ElementalType.FIRE, Enums.DamageType.PHYSICAL, etc.
class_name Enums


# =============================================================================
# ELEMENTAL TYPE SYSTEM
# =============================================================================
# The ElementalType enum is the SINGLE SOURCE OF TRUTH for valid types.
# The TYPE CHART must be updated SEPARATELY when adding/removing/renaming types.
# The TypeChart uses STRING-BASED storage (not enum indices) to prevent
# data corruption when enum values change order.

enum ElementalType {
	NONE,
	AIR,
	CHIVALRIC,
	COLD,       # Freezing, ice-based attacks
	ELECTRIC,
	FIRE,
	GENTRY,
	GRAVITY,
	HERALDIC,
	OCCULT,
	PLANT,
	ROBO,
	SIMPLE,
	VOID,
	OBSIDIAN,   # Enemies only, highly resistant to everything
}

enum DamageType {
	PHYSICAL,
	SPECIAL,
}

enum StatusEffectType {
	NONE = 0,
	BLEED,            # DoT, damage over time
	BUGLE,            # Take +1 damage from heraldic moves
	BURN,             # DoT, lower attack, stacks increase damage and spread fire
	CHAIN_LIGHTNING,  # .5 dmg to adjacent, .25 to next, until <1 damage
	CHALLENGED,       # Draws aggro, can't target weaker units if near challenger
	CRITICAL,         # Double damage from this attack
	FREEZE,           # Immobilized, can't act
	GRAVITY,          # Hampers movement and attacks
	POISON,           # DoT, damage over time
	ROOTED,           # Stops movement
	SHOCKED,          # Reduced accuracy, chance to skip turn
	SUBVERSION,       # Lowers defenses by 1/3, allies' by 1/4 in range. Nullifies support bonuses
	VOID,             # Locks a random move or passive per stack, up to 3
	VULNERABLE,       # Takes increased damage
	WITHER,           # Reduced stats, weakened
}

enum TerrainStatus {
	NONE = 0,
	DEPLETED = 1,  # e.g. a burned forest
	DISTORTION,    # Void effect
	FLOOD,
	FOG,           # Conceals position
	RAIN,
	SCORCH,
	SINGULARITY,   # Black hole
	TORNADO,
	WIND_NORTH,
	WIND_EAST,
	WIND_SOUTH,
	WIND_WEST,
	ZAP,           # e.g. electrified water
}


# =============================================================================
# CHARACTER SYSTEM
# =============================================================================

enum CharacterClass {
	# Tier 1
	SPACEMAN,
	MERCENARY,
	SQUIRE,
	NOBLE,
	ENGINEER,
	PIRATE,
	FIGHTER,
	ENIGMA,
	SKULK,    # Sneaky militia type
	MAGE,
	HEAVY,
	# Tier 2
	JETPACK,
	HARDCASE,
	KNIGHT,
	# Tier 3
	EVA,
	TOPDOG,
	VOID_KNIGHT,
}

# Class metadata: tier and display name per class
const CLASS_INFO: Dictionary = {
	CharacterClass.SPACEMAN:    { "tier": 1, "display_name": "Spaceman" },
	CharacterClass.MERCENARY:   { "tier": 1, "display_name": "Mercenary" },
	CharacterClass.SQUIRE:      { "tier": 1, "display_name": "Squire" },
	CharacterClass.NOBLE:       { "tier": 1, "display_name": "Noble" },
	CharacterClass.ENGINEER:    { "tier": 1, "display_name": "Engineer" },
	CharacterClass.PIRATE:      { "tier": 1, "display_name": "Pirate" },
	CharacterClass.FIGHTER:     { "tier": 1, "display_name": "Fighter" },
	CharacterClass.ENIGMA:      { "tier": 1, "display_name": "Enigma" },
	CharacterClass.SKULK:       { "tier": 1, "display_name": "Skulk" },
	CharacterClass.MAGE:        { "tier": 1, "display_name": "Mage" },
	CharacterClass.HEAVY:       { "tier": 1, "display_name": "Heavy" },
	CharacterClass.JETPACK:     { "tier": 2, "display_name": "Jetpack" },
	CharacterClass.HARDCASE:    { "tier": 2, "display_name": "Hardcase" },
	CharacterClass.KNIGHT:      { "tier": 2, "display_name": "Knight" },
	CharacterClass.EVA:         { "tier": 3, "display_name": "EVA" },
	CharacterClass.TOPDOG:      { "tier": 3, "display_name": "Topdog" },
	CharacterClass.VOID_KNIGHT: { "tier": 3, "display_name": "Void Knight" },
}

enum Specialization {
	NONE,
	TANK,
	WALL,
	GLASS_CANNON,
	SCOUT,
	BERSERKER,
}

enum RewardType {
	STAT_UP,
	MOVE,
	PASSIVE,
}

enum SupportLevel {
	NONE,
	C,
	B,
	A,
}


# =============================================================================
# UNIT & FACTION
# =============================================================================

enum UnitFaction {
	PLAYER,
	ENEMY,
	NEUTRAL,
	ALLY,
}


# =============================================================================
# INPUT & GAME STATE
# =============================================================================

enum InputState {
	DEFAULT,
	UNIT_SELECTED,
	MOVEMENT_PLANNING,
	ACTION_MENU_OPEN,
	ATTACK_TARGETING,
	DIALOGUE,
	PAUSED,
}

enum TurnPhase {
	PLAYER_PHASE,
	ENEMY_PHASE,
	BATTLE_END,
}

enum AIBehaviorType {
	AGGRESSIVE,
	TACTICAL,
	DEFENSIVE,
}

enum TargetType {
	SINGLE,
	SELF,
	AOE,
}


# =============================================================================
# OVERLAY & UI
# =============================================================================

enum OverlayTintType {
	NONE,
	VICTORY,
	DEFEAT,
	MENU,
}


# =============================================================================
# DECORATIONS
# =============================================================================

enum DecorationType {
	TREE,       # Blocks movement and vision, provides defense
	ROCK,       # Blocks movement, provides some defense
	GRASS,      # Cosmetic ground cover
	BUSH,       # Blocks vision, minor defense
	RUINS,      # Strong defense, blocks movement
	FLOWER,     # Pure cosmetic
	MUSHROOM,   # Potential for special effects
	CRYSTAL,    # Sci-fi decoration, potential mana effects
	SCRAP,      # Post-apocalyptic clutter
	PILLAR,     # Architectural elements
}

enum DecorationCategory {
	NATURAL,        # Trees, grass, rocks
	ARCHITECTURAL,  # Ruins, pillars, structures
	MYSTICAL,       # Crystals, magical elements
	INDUSTRIAL,     # Scrap, machinery
	ORGANIC,        # Mushrooms, flowers, plants
}

enum DecorationRenderPriority {
	GROUND = 0,      # Grass, flowers, low ground cover
	LOW = 3,          # Bushes, small rocks
	MEDIUM = 6,       # Medium rocks, ruins
	HIGH = 10,        # Trees, tall structures
	VERY_HIGH = 15,   # Towers, large ruins, special structures
}


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

static func get_class_tier(character_class: CharacterClass) -> int:
	if CLASS_INFO.has(character_class):
		return CLASS_INFO[character_class]["tier"]
	return 1


static func get_class_display_name(character_class: CharacterClass) -> String:
	if CLASS_INFO.has(character_class):
		return CLASS_INFO[character_class]["display_name"]
	return "Unknown"


static func elemental_type_to_string(type: ElementalType) -> String:
	return ElementalType.keys()[type]


static func string_to_elemental_type(type_name: String) -> ElementalType:
	var upper := type_name.to_upper()
	for key in ElementalType.keys():
		if key == upper:
			return ElementalType[key]
	return ElementalType.NONE

## Game-specific UI colors built on top of GameColorPalette.
## Usage: GameColors.TILE_HOVERED, GameColors.get_health_color(0.5), etc.
class_name GameColors


# =============================================================================
# TILE COLORS
# =============================================================================

static var TILE_DEFAULT: Color:
	get: return Color.WHITE
static var TILE_HOVERED: Color:
	get: return GameColorPalette.get_color("Gray", 8)
static var TILE_SELECTED: Color:
	get: return GameColorPalette.get_color("Yellow", 8)
static var MOVEMENT_RANGE: Color:
	get: return GameColorPalette.get_color("Azure", 5)
static var MOVEMENT_RANGE_HOVERED: Color:
	get: return GameColorPalette.get_color("Azure", 7)
static var ATTACK_RANGE: Color:
	get: return GameColorPalette.get_color("Red", 6)
static var ATTACK_RANGE_HOVERED: Color:
	get: return GameColorPalette.get_color("Red", 7)


# =============================================================================
# UNIT COLORS BY FACTION
# =============================================================================

static var PLAYER_UNIT: Color:
	get: return Color(0.45, 0.65, 1.0)  # Bright blue
static var ENEMY_UNIT: Color:
	get: return Color(1.0, 0.4, 0.35)  # Bright red
static var NEUTRAL_UNIT: Color:
	get: return Color(0.75, 0.75, 0.75)  # Light gray
static var ALLY_UNIT: Color:
	get: return Color(1.0, 0.95, 0.4)  # Bright yellow

# Dimmed versions for units that have acted (desaturated + darker)
static var PLAYER_UNIT_ACTED: Color:
	get: return Color(0.3, 0.35, 0.45)  # Dark muted blue
static var ENEMY_UNIT_ACTED: Color:
	get: return Color(0.45, 0.28, 0.28)  # Dark muted red
static var ALLY_UNIT_ACTED: Color:
	get: return Color(0.4, 0.4, 0.28)  # Dark muted yellow


# =============================================================================
# FACTION HEALTH BAR BACKGROUNDS
# =============================================================================

static var FACTION_HEALTHBAR_PLAYER: Color:
	get: return GameColorPalette.get_color("Azure", 6)
static var FACTION_HEALTHBAR_ENEMY: Color:
	get: return GameColorPalette.get_color("Red", 5)
static var FACTION_HEALTHBAR_NEUTRAL: Color:
	get: return GameColorPalette.get_color("Green", 6)
static var FACTION_HEALTHBAR_ALLY: Color:
	get: return GameColorPalette.get_color("Yellow", 7)


# =============================================================================
# UNIT SELECTION STATES
# =============================================================================

static var UNIT_SELECTED: Color:
	get: return GameColorPalette.get_color("Green", 7)
static var UNIT_HOVERED: Color:
	get: return GameColorPalette.get_color("Blue", 9)
static var UNIT_ACTED: Color:
	get: return Color(0.35, 0.35, 0.35)  # Generic fallback gray


# =============================================================================
# UI COLORS
# =============================================================================

static var HUD_PANEL_BACKGROUND: Color:
	get: return Color("#302d27d9")  # #302d27 @ 85% — standard background for all HUD panels
static var MENU_BACKGROUND: Color:
	get: return with_alpha(GameColorPalette.get_color("Blue", 3), 0.9)
static var MENU_BORDER: Color:
	get: return GameColorPalette.get_color("Blue", 9)
static var UI_BACKDROP: Color:
	get: return with_alpha(GameColorPalette.get_color("Eggshell", 1), 0.85)
static var BUTTON_NORMAL: Color:
	get: return GameColorPalette.get_color("Blue", 5)
static var BUTTON_HOVERED: Color:
	get: return GameColorPalette.get_color("Blue", 7)
static var BUTTON_PRESSED: Color:
	get: return GameColorPalette.get_color("Blue", 4)


# =============================================================================
# TEXT COLORS
# =============================================================================

static var TEXT_PRIMARY: Color:
	get: return GameColorPalette.get_color("Azure", 9)   # #dbf3ff
static var TEXT_PRIMARY_GLOW: Color:
	get: return GameColorPalette.get_color("Azure", 5)   # #4c8cbb
static var TEXT_SECONDARY: Color:
	get: return GameColorPalette.get_color("YellowOrange", 8)  # #ffe797
static var TEXT_SECONDARY_GLOW: Color:
	get: return GameColorPalette.get_color("Magenta", 4)  # #7d4181
static var TEXT_SUCCESS: Color:
	get: return GameColorPalette.get_color("Green", 6)
static var TEXT_WARNING: Color:
	get: return GameColorPalette.get_color("Yellow", 5)
static var TEXT_DANGER: Color:
	get: return GameColorPalette.get_color("Red", 5)


# =============================================================================
# HEALTH BAR COLORS
# =============================================================================

static var HEALTH_FULL: Color:
	get: return GameColorPalette.get_color("Green", 6)
static var HEALTH_HALF: Color:
	get: return GameColorPalette.get_color("Yellow", 5)
static var HEALTH_LOW: Color:
	get: return GameColorPalette.get_color("Orange", 5)
static var HEALTH_CRITICAL: Color:
	get: return GameColorPalette.get_color("Red", 5)

# Glow variants for the health pip bar
static var HEALTH_FULL_GLOW: Color:
	get: return GameColorPalette.get_color("Green", 3)
static var HEALTH_HALF_GLOW: Color:
	get: return GameColorPalette.get_color("Yellow", 3)
static var HEALTH_LOW_GLOW: Color:
	get: return GameColorPalette.get_color("Orange", 3)
static var HEALTH_CRITICAL_GLOW: Color:
	get: return GameColorPalette.get_color("Red", 3)

# Damage preview section (pulsing zone in combat preview)
static var HEALTH_DAMAGE_PREVIEW: Color:
	get: return GameColorPalette.get_color("Gray", 6)
static var HEALTH_DAMAGE_PREVIEW_GLOW: Color:
	get: return GameColorPalette.get_color("Gray", 3)


# =============================================================================
# STATUS EFFECT COLORS
# =============================================================================

static var STATUS_BURN: Color:
	get: return GameColorPalette.get_color("Orange", 6)
static var STATUS_POISON: Color:
	get: return GameColorPalette.get_color("Purple", 6)
static var STATUS_BUFF: Color:
	get: return GameColorPalette.get_color("Blue", 6)
static var STATUS_DEBUFF: Color:
	get: return GameColorPalette.get_color("Magenta", 5)


# =============================================================================
# WAYPOINT/PATH COLORS
# =============================================================================

static var WAYPOINT_INDICATOR: Color:
	get: return with_alpha(GameColorPalette.get_color("Yellow", 6), 0.8)
static var PATH_ARROW: Color:
	get: return with_alpha(GameColorPalette.get_color("Blue", 6), 0.7)


# =============================================================================
# PDA PANEL COLORS
# =============================================================================

static var PDA_BACKGROUND: Color:
	get: return with_alpha(GameColorPalette.get_color("Azure", 1), 0.92)
static var PDA_BORDER_GLOW: Color:
	get: return with_alpha(GameColorPalette.get_color("Azure", 3), 0.3)
static var PDA_TEXT_PRIMARY: Color:
	get: return GameColorPalette.get_color("Azure", 2)
static var PDA_TEXT_PLAYER: Color:
	get: return GameColorPalette.get_color("Azure", 2)
static var PDA_TEXT_ENEMY: Color:
	get: return GameColorPalette.get_color("Red", 6)
static var PDA_TEXT_NEUTRAL: Color:
	get: return GameColorPalette.get_color("Gray", 8)
static var PDA_TEXT_HIGHLIGHT: Color:
	get: return GameColorPalette.get_color("Yellow", 5)


# =============================================================================
# DAMAGE MULTIPLIER COLORS
# =============================================================================

static var MULTIPLIER_X4_LIGHT: Color:
	get: return GameColorPalette.get_color("Red", 6)
static var MULTIPLIER_X4_DARK: Color:
	get: return GameColorPalette.get_color("Red", 2)
static var MULTIPLIER_X3_LIGHT: Color:
	get: return GameColorPalette.get_color("Orange", 6)
static var MULTIPLIER_X3_DARK: Color:
	get: return GameColorPalette.get_color("Orange", 3)
static var MULTIPLIER_X2_LIGHT: Color:
	get: return GameColorPalette.get_color("YellowOrange", 7)
static var MULTIPLIER_X2_DARK: Color:
	get: return GameColorPalette.get_color("YellowOrange", 3)
static var MULTIPLIER_X1_LIGHT: Color:
	get: return GameColorPalette.get_color("Yellow", 7)
static var MULTIPLIER_X1_DARK: Color:
	get: return GameColorPalette.get_color("Yellow", 4)
static var MULTIPLIER_HALF_LIGHT: Color:
	get: return GameColorPalette.get_color("Green", 7)
static var MULTIPLIER_HALF_DARK: Color:
	get: return GameColorPalette.get_color("Green", 3)
static var MULTIPLIER_X0_LIGHT: Color:
	get: return GameColorPalette.get_color("Cyan", 7)
static var MULTIPLIER_X0_DARK: Color:
	get: return GameColorPalette.get_color("Cyan", 3)


# =============================================================================
# MOVE CHIP COLORS (fill = bright portion, empty = dark background)
# =============================================================================

static func get_move_chip_fill(element_type: Enums.ElementalType) -> Color:
	match element_type:
		Enums.ElementalType.FIRE:      return GameColorPalette.get_color("Orange", 4)
		Enums.ElementalType.ELECTRIC:  return GameColorPalette.get_color("Yellow", 4)
		Enums.ElementalType.PLANT:     return GameColorPalette.get_color("Green", 4)
		Enums.ElementalType.COLD:      return GameColorPalette.get_color("Blue", 5)
		Enums.ElementalType.AIR:       return GameColorPalette.get_color("Cyan", 4)
		Enums.ElementalType.GRAVITY:   return GameColorPalette.get_color("Purple", 4)
		Enums.ElementalType.VOID:      return GameColorPalette.get_color("Eggplant", 4)
		Enums.ElementalType.OCCULT:    return GameColorPalette.get_color("Violet", 4)
		Enums.ElementalType.CHIVALRIC: return GameColorPalette.get_color("Azure", 4)
		Enums.ElementalType.HERALDIC:  return GameColorPalette.get_color("YellowOrange", 4)
		Enums.ElementalType.GENTRY:    return GameColorPalette.get_color("Eggshell", 4)
		Enums.ElementalType.ROBO:      return GameColorPalette.get_color("TealGray", 4)
		Enums.ElementalType.OBSIDIAN:  return GameColorPalette.get_color("Gray", 2)
		Enums.ElementalType.SIMPLE:    return GameColorPalette.get_color("Gray", 4)
		_:                             return GameColorPalette.get_color("Gray", 4)


static func get_move_chip_empty(element_type: Enums.ElementalType) -> Color:
	match element_type:
		Enums.ElementalType.FIRE:      return GameColorPalette.get_color("Red", 1)
		Enums.ElementalType.ELECTRIC:  return GameColorPalette.get_color("Purple", 1)
		Enums.ElementalType.PLANT:     return GameColorPalette.get_color("Teal", 1)
		Enums.ElementalType.COLD:      return GameColorPalette.get_color("Purple", 1)
		Enums.ElementalType.AIR:       return GameColorPalette.get_color("Blue", 1)
		Enums.ElementalType.GRAVITY:   return GameColorPalette.get_color("Gray", 1)
		Enums.ElementalType.VOID:      return GameColorPalette.get_color("Gray", 0)
		Enums.ElementalType.OCCULT:    return GameColorPalette.get_color("RedViolet", 1)
		Enums.ElementalType.CHIVALRIC: return GameColorPalette.get_color("Blue", 1)
		Enums.ElementalType.HERALDIC:  return GameColorPalette.get_color("Orange", 1)
		Enums.ElementalType.GENTRY:    return GameColorPalette.get_color("Straw", 1)
		Enums.ElementalType.ROBO:      return GameColorPalette.get_color("Gray", 1)
		Enums.ElementalType.OBSIDIAN:  return GameColorPalette.get_color("Gray", 0)
		Enums.ElementalType.SIMPLE:    return GameColorPalette.get_color("Blue", 1)
		_:                             return GameColorPalette.get_color("Blue", 1)


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

## Returns a copy of the color with the specified alpha.
static func with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))


## Returns a brightened copy of the color.
static func brightened(color: Color, factor: float = 1.2) -> Color:
	return Color(
		minf(1.0, color.r * factor),
		minf(1.0, color.g * factor),
		minf(1.0, color.b * factor),
		color.a
	)


## Returns a health bar color based on current HP percentage.
static func get_health_color(health_percent: float) -> Color:
	if health_percent >= 0.75:
		return HEALTH_FULL
	elif health_percent >= 0.5:
		return HEALTH_HALF
	elif health_percent >= 0.25:
		return HEALTH_LOW
	else:
		return HEALTH_CRITICAL


## Returns the appropriate color for a type effectiveness multiplier.
static func get_effectiveness_color(effectiveness: float, is_heal: bool = false) -> Color:
	if is_heal:
		return HEALTH_FULL
	if effectiveness >= 4.0:
		return MULTIPLIER_X4_LIGHT
	elif effectiveness >= 3.0:
		return MULTIPLIER_X3_LIGHT
	elif effectiveness >= 2.0:
		return MULTIPLIER_X2_LIGHT
	elif effectiveness == 1.0:
		return MULTIPLIER_X1_LIGHT
	elif effectiveness > 0.0:
		return MULTIPLIER_HALF_LIGHT
	else:
		return MULTIPLIER_X0_LIGHT


## Returns text color based on damage amount.
static func get_damage_text_color(damage: int, is_critical: bool = false) -> Color:
	if is_critical:
		return brightened(TEXT_DANGER, 1.3)
	if damage >= 10:
		return TEXT_DANGER
	elif damage >= 5:
		return TEXT_WARNING
	else:
		return TEXT_PRIMARY
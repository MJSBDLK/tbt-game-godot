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
	get: return Color.WHITE
static var ENEMY_UNIT: Color:
	get: return GameColorPalette.get_color("Red", 8)
static var NEUTRAL_UNIT: Color:
	get: return GameColorPalette.get_color("Gray", 8)


# =============================================================================
# UNIT SELECTION STATES
# =============================================================================

static var UNIT_SELECTED: Color:
	get: return GameColorPalette.get_color("Green", 7)
static var UNIT_HOVERED: Color:
	get: return GameColorPalette.get_color("Blue", 9)
static var UNIT_ACTED: Color:
	get: return GameColorPalette.get_color("Gray", 6)


# =============================================================================
# UI COLORS
# =============================================================================

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
	get: return GameColorPalette.get_color("Gray", 10)
static var TEXT_SECONDARY: Color:
	get: return GameColorPalette.get_color("Gray", 7)
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
	get: return GameColorPalette.get_color("Red", 9)
static var MULTIPLIER_X4_DARK: Color:
	get: return GameColorPalette.get_color("Red", 4)
static var MULTIPLIER_X2_LIGHT: Color:
	get: return GameColorPalette.get_color("Orange", 9)
static var MULTIPLIER_X2_DARK: Color:
	get: return GameColorPalette.get_color("Orange", 5)
static var MULTIPLIER_X1_LIGHT: Color:
	get: return GameColorPalette.get_color("Gray", 9)
static var MULTIPLIER_X1_DARK: Color:
	get: return GameColorPalette.get_color("Gray", 5)
static var MULTIPLIER_HALF_LIGHT: Color:
	get: return GameColorPalette.get_color("Cyan", 9)
static var MULTIPLIER_HALF_DARK: Color:
	get: return GameColorPalette.get_color("Cyan", 5)
static var MULTIPLIER_X0_LIGHT: Color:
	get: return GameColorPalette.get_color("Gray", 9)
static var MULTIPLIER_X0_DARK: Color:
	get: return GameColorPalette.get_color("Gray", 3)


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

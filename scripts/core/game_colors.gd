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
# PHASE TRANSITION BANNER COLORS
# =============================================================================
# CIELAB luminance matched across factions (L*≈88 / 45 / 14).

static var PHASE_PLAYER_TEXT: Color:
	get: return GameColorPalette.get_color("Azure", 8)              # #b7e5ff
static var PHASE_PLAYER_ACCENT: Color:
	get: return GameColorPalette.get_color("Azure", 4)              # #2d6b9c
static var PHASE_PLAYER_GLOW: Color:
	get: return GameColorPalette.get_color("StylizedVillage", 2)    # #1b1d3d

static var PHASE_ENEMY_TEXT: Color:
	get: return GameColorPalette.get_color("Red", 9)                # #fbd5ce
static var PHASE_ENEMY_ACCENT: Color:
	get: return GameColorPalette.get_color("Red", 5)                # #b94231
static var PHASE_ENEMY_GLOW: Color:
	get: return GameColorPalette.get_color("RedViolet", 2)          # #3f1525

static var PHASE_NEUTRAL_TEXT: Color:
	get: return GameColorPalette.get_color("TealGray", 8)           # #c3e6dc
static var PHASE_NEUTRAL_ACCENT: Color:
	get: return GameColorPalette.get_color("WarmNature", 4)         # #59754c
static var PHASE_NEUTRAL_GLOW: Color:
	get: return GameColorPalette.get_color("Teal", 2)               # #102e25

static var PHASE_ALLY_TEXT: Color:
	get: return GameColorPalette.get_color("Straw2", 8)             # #e7dfb0
static var PHASE_ALLY_ACCENT: Color:
	get: return GameColorPalette.get_color("Yellow", 4)             # #7e6d24
static var PHASE_ALLY_GLOW: Color:
	get: return GameColorPalette.get_color("Straw", 2)              # #322317


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
static var ACTION_BUTTON_BORDER: Color:
	get: return GameColorPalette.get_color("Gray", 7)
static var ACTION_BUTTON_BG_NORMAL: Color:
	get: return with_alpha(GameColorPalette.get_color("Gray", 2), 0.3)
static var ACTION_BUTTON_BG_HOVERED: Color:
	get: return with_alpha(GameColorPalette.get_color("Gray", 3), 0.5)
static var ACTION_BUTTON_BG_PRESSED: Color:
	get: return with_alpha(GameColorPalette.get_color("Gray", 1), 0.4)


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
# HEALTH BAR COLORS — 11-step ramp from critical (0%) to full (100%)
# =============================================================================

# Index 0 = 0% HP (critical), index 10 = 100% HP (full)
# Lawrence's blended hex values (may revisit):
#   0: #6e150d, 1: #8e371e, 2: #a7532d, 3: #c17b3e, 4: #dca452,
#   5: #f4cc65, 6: #d3cc72, 7: #afcb80, 8: #8cc991, 9: #6dcbac, 10: #45cbce
static var HEALTH_RAMP: Array[Color] = [
	GameColorPalette.get_color("Red", 3),           # 0  — critical red
	GameColorPalette.get_color("PoppyRed", 4),      # 1
	GameColorPalette.get_color("PoppyRed", 5),      # 2
	GameColorPalette.get_color("PoppyRed", 6),      # 3
	GameColorPalette.get_color("PoppyRed", 7),      # 4
	GameColorPalette.get_color("YellowOrange", 7),  # 5  — mid yellow
	GameColorPalette.get_color("Yellow", 7),         # 6
	GameColorPalette.get_color("Chartreuse", 7),     # 7
	GameColorPalette.get_color("Green", 7),          # 8
	GameColorPalette.get_color("Teal", 7),           # 9
	GameColorPalette.get_color("Cyan", 7),           # 10 — full health teal
]

# Background/glow colors for each health ramp step (placeholder — Lawrence to finalize)
# Placeholder hex values (not in palette):
#   0: #2d0805, 1: #3d1508, 2: #4d200e, 3: #5c3012, 4: #6b4518,
#   5: #6b5a10, 6: #4a4a15, 7: #3a5c1e, 8: #1e5c38, 9: #0e5c52, 10: #006971
static var HEALTH_RAMP_BG: Array[Color] = [
	GameColorPalette.get_color("Red", 1),            # 0  — deep blood red
	GameColorPalette.get_color("PoppyRed", 2),       # 1
	GameColorPalette.get_color("Orange", 3),         # 2
	GameColorPalette.get_color("YellowOrange", 3),   # 3
	GameColorPalette.get_color("Yellow", 3),         # 4
	GameColorPalette.get_color("Yellow", 3),         # 5  — dark gold (same as 4, nearest match)
	GameColorPalette.get_color("Chartreuse", 3),     # 6
	GameColorPalette.get_color("Green", 3),          # 7
	GameColorPalette.get_color("Green", 3),          # 8  — (same as 7, nearest match)
	GameColorPalette.get_color("Cyan", 3),           # 9
	GameColorPalette.get_color("Cyan", 4),           # 10 — confirmed dark teal (EXACT)
]

# Legacy accessors for code that references specific thresholds
static var HEALTH_FULL: Color:
	get: return HEALTH_RAMP[10]
static var HEALTH_HALF: Color:
	get: return HEALTH_RAMP[5]
static var HEALTH_LOW: Color:
	get: return HEALTH_RAMP[2]
static var HEALTH_CRITICAL: Color:
	get: return HEALTH_RAMP[0]

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
static var STATUS_ICON_BACKGROUND: Color:
	get: return Color("#40230a")
static var STATUS_TEXT: Color:
	get: return GameColorPalette.get_color("YellowOrange", 7)
static var STATUS_TEXT_GLOW: Color:
	get: return GameColorPalette.get_color("Red", 4)


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
	get: return GameColorPalette.get_color("Red", 7)
static var MULTIPLIER_X4_DARK: Color:
	get: return GameColorPalette.get_color("Red", 2)
static var MULTIPLIER_X3_LIGHT: Color:
	get: return GameColorPalette.get_color("Orange", 7)
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
static var MULTIPLIER_QUARTER_LIGHT: Color:
	get: return GameColorPalette.get_color("Teal", 7)
static var MULTIPLIER_QUARTER_DARK: Color:
	get: return GameColorPalette.get_color("Teal", 3)
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
# TERRAIN MODIFIER COLORS — uses HEALTH_RAMP with non-linear thresholds
# =============================================================================

# Thresholds for terrain multiplier → ramp index mapping.
# Fine detail around 1.0 (neutral), wider steps at extremes.
const TERRAIN_MODIFIER_THRESHOLDS: Array[float] = [
	0.0, 0.5, 0.7, 0.85, 0.95, 1.0, 1.05, 1.15, 1.3, 1.5, 2.0,
]

## Returns a color from the health ramp based on a terrain modifier value.
## Values near 1.0 (neutral) get fine-grained color steps.
## Below 1.0 = red/orange (bad), 1.0 = yellow (neutral), above 1.0 = green/teal (good).
static func get_terrain_modifier_color(value: float) -> Color:
	for i: int in range(TERRAIN_MODIFIER_THRESHOLDS.size() - 1, -1, -1):
		if value >= TERRAIN_MODIFIER_THRESHOLDS[i]:
			return HEALTH_RAMP[i]
	return HEALTH_RAMP[0]


## Returns the background/glow color matching a terrain modifier value.
static func get_terrain_modifier_bg_color(value: float) -> Color:
	for i: int in range(TERRAIN_MODIFIER_THRESHOLDS.size() - 1, -1, -1):
		if value >= TERRAIN_MODIFIER_THRESHOLDS[i]:
			return HEALTH_RAMP_BG[i]
	return HEALTH_RAMP_BG[0]


## Returns a color for movement cost (inverted: lower cost = better/teal).
## 0.5 = index 10, 1 = index 5, 2 = index 4, 3 = index 3, 4 = index 2, 5+ = index 0.
static func get_movement_cost_color(cost: float) -> Color:
	if cost <= 0.5:
		return HEALTH_RAMP[10]
	elif cost <= 1.0:
		return HEALTH_RAMP[5]
	elif cost <= 2.0:
		return HEALTH_RAMP[4]
	elif cost <= 3.0:
		return HEALTH_RAMP[3]
	elif cost <= 4.0:
		return HEALTH_RAMP[2]
	elif cost <= 5.0:
		return HEALTH_RAMP[1]
	return HEALTH_RAMP[0]


## Returns the background/glow color for movement cost.
static func get_movement_cost_bg_color(cost: float) -> Color:
	if cost <= 0.5:
		return HEALTH_RAMP_BG[10]
	elif cost <= 1.0:
		return HEALTH_RAMP_BG[5]
	elif cost <= 2.0:
		return HEALTH_RAMP_BG[4]
	elif cost <= 3.0:
		return HEALTH_RAMP_BG[3]
	elif cost <= 4.0:
		return HEALTH_RAMP_BG[2]
	elif cost <= 5.0:
		return HEALTH_RAMP_BG[1]
	return HEALTH_RAMP_BG[0]


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


## 0 = snap to nearest ramp step, 1 = smooth interpolation between steps.
static var smooth_health_ramp: int = 0

## Returns a health bar color from the 11-step ramp.
## 0.0 = critical (index 0), 1.0 = full (index 10).
static func get_health_color(health_percent: float) -> Color:
	var clamped: float = clampf(health_percent, 0.0, 1.0)
	var index: float = clamped * 10.0
	var lower: int = int(index)
	if smooth_health_ramp:
		var upper: int = mini(lower + 1, 10)
		var t: float = index - float(lower)
		return HEALTH_RAMP[lower].lerp(HEALTH_RAMP[upper], t)
	return HEALTH_RAMP[mini(lower, 10)]


## Returns the background color for the health bar at the given HP percentage.
static func get_health_bg_color(health_percent: float) -> Color:
	var clamped: float = clampf(health_percent, 0.0, 1.0)
	var index: float = clamped * 10.0
	var lower: int = int(index)
	if smooth_health_ramp:
		var upper: int = mini(lower + 1, 10)
		var t: float = index - float(lower)
		return HEALTH_RAMP_BG[lower].lerp(HEALTH_RAMP_BG[upper], t)
	return HEALTH_RAMP_BG[mini(lower, 10)]


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
	elif effectiveness >= 0.5:
		return MULTIPLIER_HALF_LIGHT
	elif effectiveness > 0.0:
		return MULTIPLIER_QUARTER_LIGHT
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
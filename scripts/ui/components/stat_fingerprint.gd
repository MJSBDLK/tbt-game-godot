## Hyper-concise stat readout — one 1px-tall bar per stat, length proportional
## to the stat value (HP /20, every other stat /10). Renders as a 12×7px grid
## of bars: 4 rows, 2 columns. Designed to read like morse code at a distance:
## power users decode it, novices gloss past it.
##
## Layout matches the squad-manager design discussion:
##   HP  ── ── ──    AGL ── ──
##   STR ── ──       ATH ── ──
##   SPC ── ──       DEF ── ──
##   SKL ── ──       RES ── ──
##
## Bar length tiers drive color so a glance tells you the unit's standout
## stats without having to count pixels: short = weak, mid = average, long
## = strong. Divisors are tuned to DEFAULT_STAT_CAPS (HP 100, others 50)
## so a maxed stat is the longest bar (5px).
class_name StatFingerprint
extends Control


# --- layout constants --------------------------------------------------------
const _BAR_HEIGHT_PX: int = 1
const _ROW_GAP_PX: int = 1
const _COL_GAP_PX: int = 2
const _ROWS: int = 4
const _MAX_BAR_PX: int = 5
const _COL_WIDTH_PX: int = _MAX_BAR_PX
const _TOTAL_WIDTH_PX: int = _COL_WIDTH_PX * 2 + _COL_GAP_PX
const _TOTAL_HEIGHT_PX: int = _ROWS * _BAR_HEIGHT_PX + (_ROWS - 1) * _ROW_GAP_PX

# Stat order per row: left = identity/offense, right = mobility/defense.
const _LEFT_STATS: Array[String] = ["max_hp", "strength", "special", "skill"]
const _RIGHT_STATS: Array[String] = ["agility", "athleticism", "defense", "resistance"]


# --- tier colors -------------------------------------------------------------
# Keyed off the bar's pixel length. Pulled from GameColorPalette so the
# fingerprint stays in palette if the project's color tokens shift later.
static var _COLOR_WEAK: Color:
	get: return GameColorPalette.get_color("Red", 5)
static var _COLOR_AVG: Color:
	get: return GameColorPalette.get_color("Straw2", 6)
static var _COLOR_STRONG: Color:
	get: return GameColorPalette.get_color("Green", 6)


var _character_data: CharacterData = null


func _init() -> void:
	custom_minimum_size = Vector2(_TOTAL_WIDTH_PX, _TOTAL_HEIGHT_PX)
	# Fixed-size widget — don't let parents stretch us; the morse-code reading
	# breaks if bars get scaled non-integer.
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_character(data: CharacterData) -> void:
	_character_data = data
	queue_redraw()


func _draw() -> void:
	if _character_data == null:
		return
	for row: int in range(_ROWS):
		var y: int = row * (_BAR_HEIGHT_PX + _ROW_GAP_PX)
		_draw_bar(0, y, _LEFT_STATS[row])
		_draw_bar(_COL_WIDTH_PX + _COL_GAP_PX, y, _RIGHT_STATS[row])


func _draw_bar(x: int, y: int, stat_name: String) -> void:
	var stat_value: int = _character_data.get_stat(stat_name)
	if stat_value <= 0:
		return
	var divisor: float = 20.0 if stat_name == "max_hp" else 10.0
	# ceil so any nonzero stat shows at least one pixel — morse code needs
	# the dots, not just the dashes.
	var length_px: int = int(ceil(float(stat_value) / divisor))
	draw_rect(Rect2(x, y, length_px, _BAR_HEIGHT_PX), _color_for_length(length_px), true)


func _color_for_length(length_px: int) -> Color:
	if length_px <= 1:
		return _COLOR_WEAK
	if length_px <= 3:
		return _COLOR_AVG
	return _COLOR_STRONG

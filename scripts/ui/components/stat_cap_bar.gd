## One stat's progress toward its CLASS ceiling, drawn as a single bar.
##
##   track (dim)   0 .. class_cap / global_cap   how much headroom this class has
##   fill  (lit)   0 .. level_stat / global_cap  where this unit is now
##   bonus         appended past the fill        allocation / bond / passive / status
##
## Because both are scaled against the same global ceiling, the FILLED pixels
## are always proportional to the raw stat — so two units side by side are
## directly comparable on fill length, while track length separately says how
## far each is allowed to go. Nothing is drawn past the class cap, so the
## track ENDING is what reads as "this is as far as this class gets".
##
## At the cap the bar goes success-green and [is_at_cap] returns true, which
## callers use to recolour the number beside it. A colour on the number alone
## is easy to miss in a block of eight rows; the bar is what the eye scans.
##
## WHAT COUNTS AS PROGRESS. Fill reads get_base_plus_growth() — base plus
## growth-roll gains — NOT the displayed stat. Allocated StatUps are excluded
## deliberately: they may push the number past the class cap, and the bar does
## not follow. Buffs, injuries and passives are excluded for the same reason,
## with a stronger one: they are temporary, and a bar that moved when a debuff
## landed would read as permanent progress being lost.
##
## THE BONUS SEGMENT is everything get_bonus_total reports — allocated StatUps,
## bond, passives, injuries, statuses — drawn past the end of the fill, and
## deliberately NOT clamped to the class cap. StatUps are allowed to exceed the
## ceiling, so the bar has to be able to show a stat sticking out past its own
## track. A negative total (injury, debuff) is carved back out of the fill in
## the danger colour instead, so a hobbled unit visibly shrinks rather than
## silently reading as healthy.
##
## Single shared component by design (RQD 2026-08-06). CharacterSheetPanel,
## UnitDetailPanel and EquipmentPicker all want the same picture, so they all
## instantiate this rather than each growing its own cap rendering — three
## copies would drift the moment one of them got a tweak. It replaces the
## hand-rolled base+bonus bar CharacterSheetPanel used to carry, which scaled
## every stat against a flat STAT_DISPLAY_MAX = 60 that matched no actual
## ceiling in the game.
##
## Ratio math is exposed as pure statics ([track_ratio], [fill_ratio],
## [bonus_span]) so the geometry can be tested without standing up a Control
## or a viewport.
class_name StatCapBar
extends Control


const DEFAULT_HEIGHT_PX: int = 1

## Unfilled remainder of the class's allowance. Dim enough to read as "not yet"
## rather than as a second value.
static var COLOR_TRACK: Color:
	get: return GameColorPalette.get_color("Straw2", 2)
static var COLOR_FILL: Color:
	get: return GameColorPalette.get_color("Azure", 7)
static var COLOR_AT_CAP: Color:
	get: return GameColorPalette.get_color("Green", 6)
## Positive bonus rides past the fill; negative is carved back out of it.
static var COLOR_BONUS: Color:
	get: return GameColorPalette.get_color("Yellow", 5)
static var COLOR_PENALTY: Color:
	get: return GameColorPalette.get_color("Red", 5)


var _character_data: CharacterData = null
var _stat_name: String = ""
## Panels that already spell the modifier out in text can turn the segment off.
var show_bonus: bool = true


func _init(stat_name: String = "", bar_height_px: int = DEFAULT_HEIGHT_PX) -> void:
	_stat_name = stat_name
	custom_minimum_size = Vector2(0, bar_height_px)
	# PASS, not IGNORE: the bar is a readout and must never swallow a click
	# meant for the +/- buttons beside it, but IGNORE would also suppress its
	# tooltip — and the tooltip is where the three numbers behind the drawing
	# (grown / class cap / game max) are actually spelled out.
	mouse_filter = Control.MOUSE_FILTER_PASS


func set_character(data: CharacterData) -> void:
	_character_data = data
	queue_redraw()


func set_stat_name(stat_name: String) -> void:
	_stat_name = stat_name
	queue_redraw()


## Refresh both at once — the common case after an allocation or a level-up.
func set_stat(data: CharacterData, stat_name: String) -> void:
	_character_data = data
	_stat_name = stat_name
	queue_redraw()


func _draw() -> void:
	if _character_data == null or _stat_name.is_empty():
		return
	var full_width: float = size.x
	if full_width <= 0.0:
		return
	var bar_height: float = maxf(float(DEFAULT_HEIGHT_PX), size.y)
	var capped: bool = is_at_cap(_character_data, _stat_name)

	# Track first, fill over it — the fill can equal the track at cap, and
	# drawing in this order means the green simply covers it.
	var track_width: float = track_ratio(_character_data, _stat_name) * full_width
	if track_width > 0.0:
		draw_rect(Rect2(0.0, 0.0, track_width, bar_height), COLOR_TRACK, true)

	var fill_width: float = fill_ratio(_character_data, _stat_name) * full_width
	if fill_width > 0.0:
		draw_rect(Rect2(0.0, 0.0, fill_width, bar_height),
				COLOR_AT_CAP if capped else COLOR_FILL, true)

	if not show_bonus:
		return
	# Bonus rides PAST the fill and past the track — StatUps are allowed over
	# the class ceiling. A penalty is drawn back over the fill instead, so an
	# injured unit's bar visibly shrinks.
	var span: Vector2 = bonus_span(_character_data, _stat_name)
	var bonus_start: float = span.x * full_width
	var bonus_width: float = (span.y - span.x) * full_width
	if bonus_width > 0.0:
		var is_penalty: bool = _character_data.get_bonus_total(_stat_name) < 0
		draw_rect(Rect2(bonus_start, 0.0, bonus_width, bar_height),
				COLOR_PENALTY if is_penalty else COLOR_BONUS, true)


# =============================================================================
# PURE MATH — no node state, so it can be tested directly
# =============================================================================

## Class ceiling as a fraction of the global ceiling. This is the bar's TRACK
## length: 1.0 means the class can reach the game's maximum for this stat.
static func track_ratio(data: CharacterData, stat_name: String) -> float:
	if data == null:
		return 0.0
	var global_cap: int = data.get_global_stat_cap(stat_name)
	if global_cap <= 0:
		return 0.0
	return clampf(float(data.get_stat_cap(stat_name)) / float(global_cap), 0.0, 1.0)


## Grown value as a fraction of the GLOBAL ceiling — not of the class cap.
## Scaling both against the same maximum is what makes fill length comparable
## across units of different classes. Clamped to the track so a stat that
## somehow exceeded its class cap can't draw past the end of its own allowance.
static func fill_ratio(data: CharacterData, stat_name: String) -> float:
	if data == null:
		return 0.0
	var global_cap: int = data.get_global_stat_cap(stat_name)
	if global_cap <= 0:
		return 0.0
	var grown: float = float(data.get_base_plus_growth(stat_name))
	return clampf(grown / float(global_cap), 0.0, track_ratio(data, stat_name))


## Where the bonus segment starts and ends, as fractions of the widget width.
## Returns Vector2(start, end); an empty span has start == end.
##
## A POSITIVE bonus runs from the fill outward and is clamped only by the
## GLOBAL ceiling, never by the class cap — StatUps are supposed to stick out
## past the track, and hiding that would contradict the rule the bar exists to
## illustrate. A NEGATIVE bonus runs backwards from the fill, so it overdraws
## the part of the stat the injury or debuff has taken away.
static func bonus_span(data: CharacterData, stat_name: String) -> Vector2:
	if data == null:
		return Vector2.ZERO
	var global_cap: int = data.get_global_stat_cap(stat_name)
	if global_cap <= 0:
		return Vector2.ZERO
	var bonus: int = data.get_bonus_total(stat_name)
	if bonus == 0:
		return Vector2.ZERO
	var grown: float = clampf(float(data.get_base_plus_growth(stat_name)) / float(global_cap), 0.0, 1.0)
	var shifted: float = clampf(
			float(data.get_base_plus_growth(stat_name) + bonus) / float(global_cap), 0.0, 1.0)
	return Vector2(minf(grown, shifted), maxf(grown, shifted))


## True when growth has reached the class ceiling. Thin passthrough to
## CharacterData so callers colouring a label next to the bar can't accidentally
## use a different rule than the bar does.
static func is_at_cap(data: CharacterData, stat_name: String) -> bool:
	if data == null:
		return false
	return data.is_at_stat_cap(stat_name)

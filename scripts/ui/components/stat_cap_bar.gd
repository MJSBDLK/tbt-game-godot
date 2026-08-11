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
## UnitDetailPanel and UnitSheet all want the same picture, so they all
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
const GLOW_MATERIAL_PATH: String = "res://resources/hud_glow.tres"

## The RENDER VOCABULARY (RQD 2026-08-10): every segment is a GlowColorRect
## wearing a body color + its orthogonal-glow partner, the same recipe the
## pre-refactor UnitDetailPanel bars shipped (stat_container.tscn). Where the
## old bars used a semantic voice, the pairing is taken from GameColors so the
## bar and the text beside it can never disagree:
##
##   track    Azure 3 body / Azure 1 halo — the old StatBarBackground pair.
##            Dim enough to read as "not yet", lit enough to clear the panel.
##   fill     the PRIMARY voice — this is the unit's actual stat, i.e. content.
##   at cap   the SUCCESS voice, bar and number together (a color on the
##            number alone is easy to miss in a block of eight rows).
##   bonus    the SECONDARY voice — the same pale-gold/violet pair the old
##            panel's "+N" modifier text wore. Applied StatUps are modifiers,
##            so segment and tally share one voice.
##   penalty  the DANGER voice.
static var COLOR_TRACK: Color:
	get: return GameColorPalette.get_color("Azure", 3)
static var COLOR_TRACK_GLOW: Color:
	get: return GameColorPalette.get_color("Azure", 1)
static var COLOR_FILL: Color:
	get: return GameColors.TEXT_PRIMARY
static var COLOR_FILL_GLOW: Color:
	get: return GameColors.TEXT_PRIMARY_GLOW
static var COLOR_AT_CAP: Color:
	get: return GameColors.TEXT_SUCCESS
static var COLOR_AT_CAP_GLOW: Color:
	get: return GameColors.TEXT_SUCCESS_GLOW
## Positive bonus rides past the fill; negative is carved back out of it.
static var COLOR_BONUS: Color:
	get: return GameColors.TEXT_SECONDARY
static var COLOR_BONUS_GLOW: Color:
	get: return GameColors.TEXT_SECONDARY_GLOW
static var COLOR_PENALTY: Color:
	get: return GameColors.TEXT_DANGER
static var COLOR_PENALTY_GLOW: Color:
	get: return GameColors.TEXT_DANGER_GLOW


var _character_data: CharacterData = null
var _stat_name: String = ""
## Panels that already spell the modifier out in text can turn the segment off.
var show_bonus: bool = true

## Body height in pixels. The glow shader spends the outer 1px ring of each
## rect on the halo, so segments are built body+2 tall and overhang the
## control by 1px above and below — exactly how the old scene's 4px bars sat
## in their 2px container. Layouts keep their metrics; the halo is overdraw.
var _body_height_px: int = DEFAULT_HEIGHT_PX

var _track_rect: GlowColorRect = null
var _fill_rect: GlowColorRect = null
var _bonus_rect: GlowColorRect = null


func _init(stat_name: String = "", bar_height_px: int = DEFAULT_HEIGHT_PX) -> void:
	_stat_name = stat_name
	_body_height_px = maxi(1, bar_height_px)
	custom_minimum_size = Vector2(0, _body_height_px)
	# PASS, not IGNORE: the bar is a readout and must never swallow a click
	# meant for the +/- buttons beside it, but IGNORE would also suppress its
	# tooltip — and the tooltip is where the three numbers behind the drawing
	# (grown / class cap / game max) are actually spelled out.
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	_track_rect = _make_segment(COLOR_TRACK, COLOR_TRACK_GLOW)
	_fill_rect = _make_segment(COLOR_FILL, COLOR_FILL_GLOW)
	_bonus_rect = _make_segment(COLOR_BONUS, COLOR_BONUS_GLOW)
	_relayout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_relayout()


func set_character(data: CharacterData) -> void:
	_character_data = data
	_relayout()


func set_stat_name(stat_name: String) -> void:
	_stat_name = stat_name
	_relayout()


## Refresh both at once — the common case after an allocation or a level-up.
func set_stat(data: CharacterData, stat_name: String) -> void:
	_character_data = data
	_stat_name = stat_name
	_relayout()


func _make_segment(body: Color, glow: Color) -> GlowColorRect:
	var segment := GlowColorRect.new()
	segment.material = (load(GLOW_MATERIAL_PATH) as Material).duplicate()
	segment.color = body
	segment.glow_color = glow
	segment.visible = false
	segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(segment)
	return segment


## Position the three segments from the pure ratios. Widths pixel-snap so the
## 1px halo ring stays crisp; a segment under 1px of body hides entirely
## rather than rendering as a floating halo blob.
func _relayout() -> void:
	if _track_rect == null:
		return
	if _character_data == null or _stat_name.is_empty() or size.x <= 0.0:
		_track_rect.visible = false
		_fill_rect.visible = false
		_bonus_rect.visible = false
		return

	var full_width: float = size.x
	var capped: bool = is_at_cap(_character_data, _stat_name)

	var track_px: float = roundf(track_ratio(_character_data, _stat_name) * full_width)
	_place_segment(_track_rect, 0.0, track_px)

	var fill_px: float = roundf(fill_ratio(_character_data, _stat_name) * full_width)
	_fill_rect.color = COLOR_AT_CAP if capped else COLOR_FILL
	_fill_rect.glow_color = COLOR_AT_CAP_GLOW if capped else COLOR_FILL_GLOW
	_place_segment(_fill_rect, 0.0, fill_px)

	if not show_bonus:
		_bonus_rect.visible = false
		return
	# Bonus rides PAST the fill and past the track — StatUps are allowed over
	# the class ceiling. A penalty is drawn back over the fill instead, so an
	# injured unit's bar visibly shrinks.
	var span: Vector2 = bonus_span(_character_data, _stat_name)
	var bonus_start: float = roundf(span.x * full_width)
	var bonus_end: float = roundf(span.y * full_width)
	var is_penalty: bool = _character_data.get_bonus_total(_stat_name) < 0
	_bonus_rect.color = COLOR_PENALTY if is_penalty else COLOR_BONUS
	_bonus_rect.glow_color = COLOR_PENALTY_GLOW if is_penalty else COLOR_BONUS_GLOW
	_place_segment(_bonus_rect, bonus_start, bonus_end - bonus_start)


## Body geometry in, halo margin out: the rect is grown 1px on every side so
## the shader's edge ring lands OUTSIDE the body pixels the ratio math asked
## for — segment bodies stay exactly comparable across bars.
func _place_segment(segment: GlowColorRect, body_x: float, body_width: float) -> void:
	if body_width < 1.0:
		segment.visible = false
		return
	segment.visible = true
	segment.position = Vector2(body_x - 1.0, (size.y - _body_height_px) / 2.0 - 1.0)
	segment.size = Vector2(body_width + 2.0, _body_height_px + 2.0)


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

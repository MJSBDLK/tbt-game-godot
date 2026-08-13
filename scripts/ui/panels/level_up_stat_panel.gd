## Mid-battle level-up celebration (RQD 2026-08-11) — the dopamine beat,
## in-combat edition. When a player unit levels during battle, this pops a
## stats-exclusive cut of the detail panel: ident line, then the eight stat
## rows in the shared vocabulary (SECONDARY key · StatCapBar · value), with
## the stats that grew revealing "+1" one beat at a time.
##
## REUSE IS THE POINT (RQD: "which is why I keep pushing for these components
## to be reusable"): rows are built from UnitSheet's public statics and the
## shared StatCapBar — the bar arrives already knowing caps, at-cap SUCCESS,
## and injury penalties, so this screen can never disagree with the sheet or
## the detail panel about what a stat looks like.
##
## FLOW: Unit._flush_xp_feedback awaits UIManager.show_level_up_celebration,
## which awaits [signal finished] — so the battle holds its breath while the
## reveal plays (FE-style). Click anywhere to skip; auto-dismisses after the
## last reveal. Reduced motion (Settings.ui_motion_enabled = false) shows
## everything at once and only keeps the reading pause.
##
## The end-of-mission LevelUpReportPanel still owns the AGGREGATE celebration
## (per-mission deltas + stat-up spending pointer); this screen is the
## in-the-moment single-level beat.
class_name LevelUpStatPanel
extends Control


signal finished


## Stagger between consecutive "+1" reveals — matches LevelUpReportPanel's
## beat so the two celebrations feel like one system.
const REVEAL_STAGGER_SECONDS: float = 0.18
const REVEAL_PUNCH_SECONDS: float = 0.28
## Breath after the last reveal before auto-dismiss — long enough to read
## eight rows, short enough that the battle doesn't feel paused.
const LINGER_SECONDS: float = 1.2

const STAT_BAR_WIDTH: float = 64.0
const STAT_BAR_HEIGHT: int = 3


var _character: CharacterData = null
var _before: Dictionary = {}
var _plus_labels: Array[GlowLabel] = []
var _finished: bool = false


## Everything the reveal needs to diff against, captured BEFORE grant_xp rolls
## growths: per-stat grown values, the level, and the spendable stat-up pool.
static func stat_snapshot(character: CharacterData) -> Dictionary:
	var stats: Dictionary = {}
	for entry: Array in UnitSheet.STAT_ROWS:
		var stat_name: String = str(entry[0])
		stats[stat_name] = character.get_base_plus_growth(stat_name)
	return {
		"level": character.level,
		"stat_ups": character.available_stat_ups,
		"stats": stats,
	}


## The stats whose GROWN value rose since the snapshot, in display order.
static func grown_stats(before: Dictionary, character: CharacterData) -> Array[String]:
	var grown: Array[String] = []
	var stats: Dictionary = before.get("stats", {})
	for entry: Array in UnitSheet.STAT_ROWS:
		var stat_name: String = str(entry[0])
		if character.get_base_plus_growth(stat_name) > int(stats.get(stat_name, 0)):
			grown.append(stat_name)
	return grown


## Newly awarded spendable points since the snapshot (level milestones).
static func stat_ups_gained(before: Dictionary, character: CharacterData) -> int:
	return maxi(0, character.available_stat_ups - int(before.get("stat_ups", 0)))


func present(character: CharacterData, before: Dictionary) -> void:
	_character = character
	_before = before
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_run_reveal()


func _gui_input(event: InputEvent) -> void:
	# Click anywhere = skip. The reveal is a gift, not a toll.
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_finish()


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# The sheet's panel chrome (UnitSheet._ready's recipe), so the celebration
	# reads as the same surface family as the screen it's a cut of.
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = GameColors.HUD_PANEL_BACKGROUND
	style.border_color = GameColorPalette.get_color("Straw2", 3)
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	column.add_child(header)
	header.add_child(UnitSheet.dim_label(_character.character_name.to_upper()))
	var level_label := GlowLabel.styled(
			"Lv %d → %d" % [int(_before.get("level", _character.level)), _character.level],
			UIManager.font_8px, 8, GameColors.TEXT_INFO, GameColors.TEXT_INFO_GLOW)
	header.add_child(level_label)

	var grown: Array[String] = grown_stats(_before, _character)
	var show_deltas_immediately: bool = not Settings.ui_motion_enabled
	for entry: Array in UnitSheet.STAT_ROWS:
		column.add_child(_stat_row(str(entry[0]), str(entry[1]),
				grown.has(str(entry[0])), show_deltas_immediately))

	var new_stat_ups: int = stat_ups_gained(_before, _character)
	if new_stat_ups > 0:
		var badge := GlowLabel.styled("+%d STAT UP%s" % [new_stat_ups,
				"" if new_stat_ups == 1 else "S"],
				UIManager.font_8px, 8, GameColors.TEXT_INFO, GameColors.TEXT_INFO_GLOW)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(badge)


## LABEL · GAUGE · VALUE · [+1] — the sheet's row shape, celebration cut.
## The bar reads post-level state through the shared component, so caps,
## at-cap SUCCESS and injury penalties all render exactly as everywhere else.
func _stat_row(stat_name: String, abbrev: String, grew: bool,
		show_delta: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)

	var key := UnitSheet.dim_label(abbrev)
	key.custom_minimum_size.x = 22
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(key)

	var bar := StatCapBar.new(stat_name, STAT_BAR_HEIGHT)
	bar.custom_minimum_size = Vector2(STAT_BAR_WIDTH, STAT_BAR_HEIGHT)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.set_stat(_character, stat_name)
	row.add_child(bar)

	var capped: bool = StatCapBar.is_at_cap(_character, stat_name)
	var value_color: Color = GameColors.TEXT_SUCCESS if capped else GameColors.TEXT_PRIMARY
	var value_glow: Color = GameColors.TEXT_SUCCESS_GLOW if capped else GameColors.TEXT_PRIMARY_GLOW
	var value := GlowLabel.styled(str(_character.get_stat(stat_name)),
			UIManager.font_8px, 8, value_color, value_glow)
	value.custom_minimum_size.x = 16
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)

	# The "+1" seat exists on every row so the columns line up; only grown
	# rows ever show theirs. SUCCESS voice: growth is the win condition.
	var plus := GlowLabel.styled("+1", UIManager.font_8px, 8,
			GameColors.TEXT_SUCCESS, GameColors.TEXT_SUCCESS_GLOW)
	plus.custom_minimum_size.x = 14
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.visible = grew and show_delta
	row.add_child(plus)
	if grew:
		_plus_labels.append(plus)

	return row


func _run_reveal() -> void:
	if Settings.ui_motion_enabled:
		for plus: GlowLabel in _plus_labels:
			if _finished:
				return
			await get_tree().create_timer(REVEAL_STAGGER_SECONDS).timeout
			if _finished or not is_instance_valid(plus):
				return
			plus.visible = true
			plus.pivot_offset = plus.size / 2.0
			plus.scale = Vector2(1.6, 1.6)
			var tween := create_tween()
			tween.tween_property(plus, "scale", Vector2.ONE,
					REVEAL_PUNCH_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if _finished:
		return
	await get_tree().create_timer(LINGER_SECONDS).timeout
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	# Skip-click while mid-reveal: everything the reveal was going to show
	# becomes visible before the panel leaves, so a skip never hides a gain.
	for plus: GlowLabel in _plus_labels:
		if is_instance_valid(plus):
			plus.visible = true
			plus.scale = Vector2.ONE
	finished.emit()

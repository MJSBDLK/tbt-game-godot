## Mid-battle level-up celebration (RQD 2026-08-11) — the dopamine beat,
## in-combat edition. When a player unit levels during battle, this pops a
## stats-exclusive cut of the detail panel: ident line, then the shared
## LevelUpStatBlock revealing the stats that grew one beat at a time.
##
## THIN MODAL HOST: the rows, the snapshot/diff math, and the reveal
## choreography all live in LevelUpStatBlock — the same component the
## intermission bEXP spend panel embeds — so the two celebrations can't
## drift. This class owns only the battle framing: backdrop, header,
## stat-up badge, skip-click, and the awaited [signal finished].
##
## FLOW: Unit._flush_xp_feedback awaits UIManager.show_level_up_celebration,
## which awaits [signal finished] — so the battle holds its breath while the
## reveal plays (FE-style). Click anywhere to skip; auto-dismisses after the
## last reveal. Reduced motion (Settings.ui_motion_enabled = false) shows
## everything at once and only keeps the reading pause.
##
## The block renders MODIFIER-STRIPPED here (raw grown values, no bonus
## segments): the celebration tells the growth story, and there is no
## at-rest state to restore to — the panel leaves when the beat ends.
class_name LevelUpStatPanel
extends Control


signal finished


## Breath after the last reveal before auto-dismiss — long enough to read
## eight rows, short enough that the battle doesn't feel paused.
const LINGER_SECONDS: float = 1.2


var _character: CharacterData = null
var _before: Dictionary = {}
var _block: LevelUpStatBlock = null
var _finished: bool = false

## Test/back-compat seam: the reveal seats live on the block now.
var _plus_labels: Array[GlowLabel]:
	get: return _block._plus_labels if _block != null else ([] as Array[GlowLabel])


## Delegates — the math moved to LevelUpStatBlock with the extraction
## (RQD 2026-08-11); these keep the battle-side call sites and the shipped
## test surface stable.
static func stat_snapshot(character: CharacterData) -> Dictionary:
	return LevelUpStatBlock.stat_snapshot(character)


static func grown_stats(before: Dictionary, character: CharacterData) -> Array[String]:
	return LevelUpStatBlock.grown_stats(before, character)


static func stat_ups_gained(before: Dictionary, character: CharacterData) -> int:
	return LevelUpStatBlock.stat_ups_gained(before, character)


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

	_block = LevelUpStatBlock.new()
	_block.build(_character, _before, not Settings.ui_motion_enabled, false)
	column.add_child(_block)

	var new_stat_ups: int = LevelUpStatBlock.stat_ups_gained(_before, _character)
	if new_stat_ups > 0:
		var badge := GlowLabel.styled("+%d STAT UP%s" % [new_stat_ups,
				"" if new_stat_ups == 1 else "S"],
				UIManager.font_8px, 8, GameColors.TEXT_INFO, GameColors.TEXT_INFO_GLOW)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(badge)


func _run_reveal() -> void:
	if Settings.ui_motion_enabled:
		await _block.play_reveal()
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
	if _block != null:
		_block.abort_reveal()
	finished.emit()

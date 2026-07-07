## Victory/defeat overlay with battle stats and Continue button.
## Shown at the end of battle, persists until player clicks Continue.
class_name BattleResultOverlay
extends Control


signal continue_pressed()

## How far above its rest position the stats content starts its slide-in.
const SLIDE_IN_DISTANCE: float = 40.0
const SLIDE_IN_DURATION: float = 0.35

var _background: ColorRect = null
var _content: VBoxContainer = null
# The content container's at-rest anchor offsets, captured at build time so the
# slide-in can displace and restore them without assuming they were zero.
var _content_rest_top: float = 0.0
var _content_rest_bottom: float = 0.0
var _header_label: Label = null
var _stats_label: Label = null
var _continue_button: Button = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_content()


# =============================================================================
# PUBLIC API
# =============================================================================

func show_result(is_victory: bool, turn_count: int, player_units_lost: int,
		enemies_defeated: int, total_players: int, total_enemies: int) -> void:
	var result_text := "VICTORY!" if is_victory else "DEFEAT!"
	var result_color := GameColors.TEXT_SUCCESS if is_victory else GameColors.TEXT_DANGER
	var bg_color := Color(0.05, 0.15, 0.05, 0.85) if is_victory else Color(0.2, 0.05, 0.05, 0.85)

	_background.color = bg_color
	_header_label.text = result_text
	_header_label.add_theme_color_override("font_color", result_color)

	_stats_label.text = "Turns: %d\nUnits Lost: %d/%d\nEnemies Defeated: %d/%d" % [
		turn_count, player_units_lost, total_players,
		enemies_defeated, total_enemies]

	# Banner-first flow: the bare VICTORY/DEFEAT banner has already played by
	# the time this shows (UIManager awaits it), so the panel doesn't repeat
	# that reveal — the background fades up while the stats content slides
	# down into place from just above its rest position.
	visible = true
	modulate.a = 1.0
	_background.modulate.a = 0.0
	_content.modulate.a = 0.0
	_content.offset_top = _content_rest_top - SLIDE_IN_DISTANCE
	_content.offset_bottom = _content_rest_bottom - SLIDE_IN_DISTANCE
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_background, "modulate:a", 1.0, 0.3)
	tween.tween_property(_content, "modulate:a", 1.0, SLIDE_IN_DURATION)
	tween.tween_property(_content, "offset_top", _content_rest_top, SLIDE_IN_DURATION) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_content, "offset_bottom", _content_rest_bottom, SLIDE_IN_DURATION) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func hide_result() -> void:
	visible = false


# =============================================================================
# INPUT
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		continue_pressed.emit()
		get_viewport().set_input_as_handled()


# =============================================================================
# BUILD CONTENT
# =============================================================================

func _build_content() -> void:
	var ui_manager: Node = UIManager

	# Dark semi-transparent background
	_background = ColorRect.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.color = Color(0.0, 0.0, 0.0, 0.85)
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_background)

	# Centered content container
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.anchor_left = 0.25
	center.anchor_right = 0.75
	center.anchor_top = 0.3
	center.anchor_bottom = 0.7
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 8)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_content = center
	_content_rest_top = center.offset_top
	_content_rest_bottom = center.offset_bottom

	# VICTORY / DEFEAT header
	_header_label = Label.new()
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ui_manager != null:
		_header_label.add_theme_font_override("font", ui_manager.font_11px)
		_header_label.add_theme_font_size_override("font_size", 11)
	_header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_header_label)

	# Stats
	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ui_manager != null:
		_stats_label.add_theme_font_override("font", ui_manager.font_8px)
		_stats_label.add_theme_font_size_override("font_size", 8)
	_stats_label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_stats_label)

	# Continue button
	_continue_button = Button.new()
	_continue_button.text = "Continue"
	_continue_button.custom_minimum_size = Vector2(80, 20)
	_continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	center.add_child(_continue_button)

## Animated phase transition banner shown between turns.
## Fades in, holds, fades out with faction-colored background.
class_name PhaseTransitionOverlay
extends Control


var _banner_background: ColorRect = null
var _phase_label: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_content()


# =============================================================================
# PUBLIC API
# =============================================================================

## Show the phase transition banner. Async — caller must await.
func show_transition(text: String, color: Color) -> void:
	_phase_label.text = text
	_banner_background.color = GameColors.with_alpha(color, 0.7)
	_phase_label.add_theme_color_override("font_color", Color.WHITE)

	visible = true
	modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_interval(0.7)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	visible = false


# =============================================================================
# BUILD CONTENT
# =============================================================================

func _build_content() -> void:
	var ui_manager: Node = get_node_or_null("/root/UIManager")

	# Semi-transparent banner across the center of the screen
	_banner_background = ColorRect.new()
	_banner_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner_background.anchor_top = 0.35
	_banner_background.anchor_bottom = 0.65
	_banner_background.color = Color(0.1, 0.1, 0.3, 0.7)
	_banner_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner_background)

	# Phase text centered in the banner
	_phase_label = Label.new()
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phase_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_phase_label.anchor_top = 0.35
	_phase_label.anchor_bottom = 0.65
	if ui_manager != null:
		_phase_label.add_theme_font_override("font", ui_manager.font_11px)
		_phase_label.add_theme_font_size_override("font_size", 11)
	_phase_label.add_theme_color_override("font_color", Color.WHITE)
	_phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_phase_label)

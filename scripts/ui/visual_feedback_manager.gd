## Manages visual feedback effects on game nodes: pulse, flash, cancel hint.
## Registered as Autoload "VisualFeedbackManager".
extends Node


var _active_tweens: Dictionary = {}  # Node -> Tween
var _cancel_hint_label: Label = null
var _cancel_hint_layer: CanvasLayer = null


func _ready() -> void:
	_build_cancel_hint()


# =============================================================================
# PULSE EFFECT — looping modulate pulse for selected/valid targets
# =============================================================================

func apply_pulse(target: Node2D, base_color: Color, speed: float = 2.0, intensity: float = 0.3) -> void:
	if target == null:
		return
	clear_feedback(target)

	var bright_color := GameColors.brightened(base_color, 1.0 + intensity)
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(target, "modulate", bright_color, 0.5 / speed)
	tween.tween_property(target, "modulate", base_color, 0.5 / speed)
	_active_tweens[target] = tween


# =============================================================================
# FLASH EFFECT — one-shot color flash
# =============================================================================

func apply_flash(target: Node2D, flash_color: Color, duration: float = 0.2) -> void:
	if target == null:
		return
	clear_feedback(target)

	var original_modulate := target.modulate
	var tween := create_tween()
	tween.tween_property(target, "modulate", flash_color, duration * 0.3)
	tween.tween_property(target, "modulate", original_modulate, duration * 0.7)
	tween.finished.connect(func() -> void:
		_active_tweens.erase(target))
	_active_tweens[target] = tween


# =============================================================================
# CLEAR FEEDBACK — stop active effect on a node
# =============================================================================

func clear_feedback(target: Node2D) -> void:
	if target == null:
		return
	if _active_tweens.has(target):
		var tween: Tween = _active_tweens[target]
		if tween != null and tween.is_valid():
			tween.kill()
		_active_tweens.erase(target)


# =============================================================================
# CANCEL HINT — bottom-of-screen ESC label
# =============================================================================

func show_cancel_hint(text: String = "ESC: Cancel") -> void:
	_cancel_hint_label.text = text
	_cancel_hint_label.visible = true


func hide_cancel_hint() -> void:
	_cancel_hint_label.visible = false


func _build_cancel_hint() -> void:
	_cancel_hint_layer = CanvasLayer.new()
	_cancel_hint_layer.layer = 10
	add_child(_cancel_hint_layer)

	_cancel_hint_label = Label.new()
	_cancel_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cancel_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_cancel_hint_label.offset_top = -20
	_cancel_hint_label.offset_bottom = 0

	var ui_manager: Node = get_node_or_null("/root/UIManager")
	if ui_manager != null and ui_manager.font_5px != null:
		_cancel_hint_label.add_theme_font_override("font", ui_manager.font_5px)
		_cancel_hint_label.add_theme_font_size_override("font_size", 5)
	_cancel_hint_label.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	_cancel_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cancel_hint_label.visible = false
	_cancel_hint_layer.add_child(_cancel_hint_label)

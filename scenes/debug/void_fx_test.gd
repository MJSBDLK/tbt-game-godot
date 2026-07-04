## Debug harness for the void-lock effect. Run this scene (F6, or set
## DebugConfig.dev_launch_scene = "res://scenes/debug/void_fx_test.tscn").
##   R    — re-roll / restart both effects
##   ESC  — quit
## Two sample styleboxes are authored in REFERENCE pixels and drawn at SCALE×, so
## the effect (which is reference-native — the smoke is 1-reference-pixel dots)
## previews the way it will look once the HUD upscales it in-game. Panels are sized
## like the real preview-panel and a move/passive chip so proportions match.
extends Control

const SCALE := 4

var _effects: Array[VoidLockEffect] = []
var _label: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.10, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_make_sample(Vector2(60, 70), Vector2(130, 100))   # preview-panel sized (ref px)
	_make_sample(Vector2(60, 520), Vector2(113, 14))    # move/passive chip sized (ref px)

	_label = Label.new()
	_label.position = Vector2(20, 16)
	_label.text = "void-lock fx — programmatic smoke + baked bubbles/stars\n[R] re-roll   [ESC] quit"
	add_child(_label)

	await get_tree().process_frame
	for fx: VoidLockEffect in _effects:
		_play(fx)


func _make_sample(screen_pos: Vector2, ref_size: Vector2) -> void:
	var panel := Panel.new()
	panel.position = screen_pos
	panel.size = ref_size * SCALE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.15, 0.20)
	sb.border_color = Color(0.45, 0.42, 0.55)
	sb.set_border_width_all(SCALE)
	sb.set_corner_radius_all(SCALE)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var fx := VoidLockEffect.new()
	fx.scale = Vector2(SCALE, SCALE)   # reference-native content, upscaled like the HUD
	panel.add_child(fx)
	_effects.append(fx)


func _play(fx: VoidLockEffect) -> void:
	var ref_size: Vector2 = (fx.get_parent() as Control).size / SCALE
	fx.play(Rect2(Vector2.ZERO, ref_size))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_R:
			for fx: VoidLockEffect in _effects:
				_play(fx)
		KEY_ESCAPE:
			get_tree().quit()

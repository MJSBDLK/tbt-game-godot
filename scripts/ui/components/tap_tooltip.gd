extends Control
class_name TapTooltip

## Add as a child of any Control to show its tooltip_text on click/tap.
## Stretches to fill the parent and intercepts clicks.
## Uses the game theme's TooltipPanel/TooltipLabel styling.

static var _active_popup: PanelContainer = null
static var _active_dimmer: Control = null
static var _dismissing: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var parent_control := get_parent() as Control
		if parent_control and not parent_control.tooltip_text.is_empty():
			if _active_popup and is_instance_valid(_active_popup):
				dismiss()
			else:
				_show_tooltip(parent_control)
			get_viewport().set_input_as_handled()


func _show_tooltip(target: Control) -> void:
	dismiss()

	# Find the CanvasLayer ancestor (UIManager) to add dimmer and popup in screen space
	var ui_layer := _find_canvas_layer(self)

	# Dimmer overlay with cutout around the target element
	var dimmer := _TooltipDimmer.new()
	dimmer.cutout_rect = target.get_global_rect()
	dimmer.position = Vector2.ZERO
	dimmer.size = get_viewport_rect().size
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.gui_input.connect(_on_dimmer_input)
	ui_layer.add_child(dimmer)
	_active_dimmer = dimmer

	# Tooltip popup
	var popup := PanelContainer.new()
	popup.theme = preload("res://resources/game_theme.tres")
	popup.theme_type_variation = "TooltipPanel"

	var label := GlowLabel.new()
	label.theme_type_variation = "TooltipLabel"
	label.text = target.tooltip_text
	label.material = preload("res://resources/hud_glow.tres").duplicate()
	label.glow_color = GameColors.TEXT_PRIMARY_GLOW
	popup.add_child(label)

	ui_layer.add_child(popup)

	# Position above the target
	var global_rect := target.get_global_rect()
	await get_tree().process_frame
	var popup_size := popup.size
	var pos := Vector2(
		global_rect.position.x + (global_rect.size.x - popup_size.x) / 2.0,
		global_rect.position.y - popup_size.y - 2.0
	)

	# Clamp to screen edges
	var screen_size := get_viewport_rect().size
	pos.x = clampf(pos.x, 2.0, screen_size.x - popup_size.x - 2.0)
	if pos.y < 2.0:
		pos.y = global_rect.position.y + global_rect.size.y + 2.0
	popup.position = pos

	_active_popup = popup


func _on_dimmer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		dismiss()


static func dismiss() -> void:
	if _dismissing:
		return
	_dismissing = true

	if _active_popup and is_instance_valid(_active_popup):
		_active_popup.queue_free()
	_active_popup = null

	if _active_dimmer and is_instance_valid(_active_dimmer):
		_active_dimmer.queue_free()
	_active_dimmer = null

	_dismissing = false


static func _find_canvas_layer(node: Node) -> CanvasLayer:
	var current := node.get_parent()
	while current:
		if current is CanvasLayer:
			return current
		current = current.get_parent()
	return null


class _TooltipDimmer extends Control:
	var cutout_rect: Rect2
	var dim_color := Color(0, 0, 0, 0.5)

	func _draw() -> void:
		var full := get_rect()
		# Top strip
		draw_rect(Rect2(0, 0, full.size.x, cutout_rect.position.y), dim_color)
		# Bottom strip
		var bottom_y := cutout_rect.end.y
		draw_rect(Rect2(0, bottom_y, full.size.x, full.size.y - bottom_y), dim_color)
		# Left strip (between top and bottom)
		draw_rect(Rect2(0, cutout_rect.position.y, cutout_rect.position.x, cutout_rect.size.y), dim_color)
		# Right strip (between top and bottom)
		var right_x := cutout_rect.end.x
		draw_rect(Rect2(right_x, cutout_rect.position.y, full.size.x - right_x, cutout_rect.size.y), dim_color)

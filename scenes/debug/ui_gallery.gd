## In-engine twin of the border-vocabulary mockup (ui-style-guide.md §14,
## data/design/mockups/border-vocabulary.html). Run this scene (F6) to eyeball
## every InteractiveButton state with the real component — if this scene and
## the style guide disagree, the code is wrong.
##
## Left: one specimen per state. Right: the "snugness rig" — an action-menu
## shaped column at real spacing where clicking moves the selection, Ember is
## disabled (press it for the deny), and End Turn carries the call to action.
extends ColorRect

var _why_label: Label = null
var _why_timer: SceneTreeTimer = null


func _ready() -> void:
	var root := HBoxContainer.new()
	root.position = Vector2(16, 16)
	root.add_theme_constant_override("separation", 32)
	add_child(root)

	root.add_child(_build_specimen_column())
	root.add_child(_build_snug_rig())
	root.add_child(_build_controls())


func _build_specimen_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)

	_add_heading(column, "STATES — lit border means you can press it")

	_add_labeled(column, "Interactive idle (hover/focus me for the backlight)",
			_make_button("Items"))

	var disabled_button := _make_button("Ember  (0 uses)")
	disabled_button.disabled = true
	disabled_button.denied.connect(_show_why)
	_add_labeled(column, "Disabled — press it to ask why", disabled_button)

	var selected_button := _make_button("Attack")
	selected_button.selected = true
	_add_labeled(column, "Selected — snapping corner ticks, 1.25 Hz", selected_button)

	var cta_button := _make_button("End Turn")
	cta_button.call_to_action = true
	_add_labeled(column, "Call to action — converging rings (max ONE on screen)",
			cta_button)

	_why_label = Label.new()
	_why_label.text = ""
	_why_label.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	column.add_child(_why_label)
	return column


func _build_snug_rig() -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 10)
	_add_heading(wrap, "SNUGNESS RIG — click around, selection follows")

	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 2)  # action-menu spacing
	wrap.add_child(menu)

	for label_text: String in ["Attack", "Move", "Items"]:
		var button := _make_button(label_text)
		button.pressed.connect(_on_rig_pressed.bind(button, menu))
		menu.add_child(button)
	var ember := _make_button("Ember  (0 uses)")
	ember.disabled = true
	ember.denied.connect(_show_why)
	menu.add_child(ember)
	var end_turn := _make_button("End Turn")
	end_turn.call_to_action = true
	menu.add_child(end_turn)

	(menu.get_child(0) as InteractiveButton).selected = true
	return wrap


func _build_controls() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_add_heading(column, "TOGGLES")

	var motion := CheckButton.new()
	motion.text = "UI motion"
	motion.button_pressed = Settings.ui_motion_enabled
	# Direct var write, NOT the setter — a debug scene shouldn't persist into
	# the player's settings.cfg.
	motion.toggled.connect(func(on: bool) -> void: Settings.ui_motion_enabled = on)
	column.add_child(motion)
	return column


func _on_rig_pressed(pressed_button: InteractiveButton, menu: VBoxContainer) -> void:
	for child: Node in menu.get_children():
		var button := child as InteractiveButton
		if button != null and not button.disabled and not button.call_to_action:
			button.selected = (button == pressed_button)


func _show_why() -> void:
	_why_label.text = "NO USES REMAINING"
	_why_timer = get_tree().create_timer(1.3)
	_why_timer.timeout.connect(func() -> void: _why_label.text = "")


func _make_button(label_text: String) -> InteractiveButton:
	var button := InteractiveButton.new()
	button.text = label_text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(120, 14)  # action-menu dimensions
	return button


func _add_heading(parent: Container, heading: String) -> void:
	var label := Label.new()
	label.text = heading
	label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	parent.add_child(label)


func _add_labeled(parent: Container, caption: String, button: InteractiveButton) -> void:
	var label := Label.new()
	label.text = caption
	label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY_GLOW)
	parent.add_child(label)
	parent.add_child(button)

## In-engine twin of the border-vocabulary mockup (ui-style-guide.md §14,
## data/design/mockups/border-vocabulary.html). Run this scene (F6) to eyeball
## every InteractiveButton state with the real component — if this scene and
## the style guide disagree, the code is wrong.
##
## Renders on the game's 640x360 design canvas with INTEGER window scaling
## (the same rule the real HUD pipeline uses: 4x on a 1440p/1600p monitor,
## 6x on 4K), and the game's UndeadPixelLight8 font — so 1 design px is a
## crisp NxN screen block, exactly like in-game.
##
## Left: the full state ladder, static furniture included. Middle: the
## "snugness rig" — an action-menu shaped column at real spacing where
## clicking moves the selection, Ember is disabled (press it for the deny),
## and End Turn carries the call to action.
extends ColorRect

const DESIGN_RESOLUTION := Vector2i(640, 360)
const FONT_8PX: FontFile = preload("res://fonts/UndeadPixelLight8.ttf")

var _why_label: Label = null


func _ready() -> void:
	# Debug scenes run standalone (no GameRoot/HUDViewport), so opt this window
	# into the design canvas + integer stretch directly.
	var window := get_window()
	window.content_scale_size = DESIGN_RESOLUTION
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER

	# Game font for everything in the scene (labels, buttons, toggles).
	var gallery_theme := Theme.new()
	gallery_theme.default_font = FONT_8PX
	gallery_theme.default_font_size = 8
	theme = gallery_theme

	var root := HBoxContainer.new()
	root.position = Vector2(12, 12)
	root.add_theme_constant_override("separation", 24)
	add_child(root)

	root.add_child(_build_specimen_column())
	root.add_child(_build_snug_rig())
	root.add_child(_build_controls())

	# Floating deny readout — positioned next to whichever button was pressed.
	_why_label = Label.new()
	_why_label.add_theme_color_override("font_color", GameColors.TEXT_SECONDARY)
	_why_label.top_level = true
	_why_label.visible = false
	add_child(_why_label)


func _build_specimen_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)

	_add_heading(column, "STATES — lit border = pressable")

	# Static: furniture, not an InteractiveButton — flat dark border, never
	# moves, never lights. Here for ladder contrast (disabled must read darker).
	var static_panel := PanelContainer.new()
	var static_style := StyleBoxFlat.new()
	static_style.bg_color = GameColors.HUD_PANEL_BACKGROUND
	static_style.border_color = GameColorPalette.get_color("Gray", 5)
	static_style.set_border_width_all(1)
	static_style.content_margin_left = 4
	static_style.content_margin_top = 2
	static_style.content_margin_bottom = 2
	static_panel.add_theme_stylebox_override("panel", static_style)
	static_panel.custom_minimum_size = Vector2(120, 14)
	var static_label := Label.new()
	static_label.text = "Terrain Info"
	static_label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	static_panel.add_child(static_label)
	_add_labeled(column, "Static — furniture, not pressable", static_panel)

	_add_labeled(column, "Idle (hover/focus me: backlight)", _make_button("Items"))

	var disabled_button := _make_button("Ember  (0 uses)")
	disabled_button.disabled = true
	disabled_button.denied.connect(_show_why.bind(disabled_button))
	_add_labeled(column, "Disabled — press it to ask why", disabled_button)

	var selected_button := _make_button("Attack")
	selected_button.selected = true
	_add_labeled(column, "Selected — snapping ticks, 1.25 Hz", selected_button)

	var cta_button := _make_button("End Turn")
	cta_button.call_to_action = true
	_add_labeled(column, "Call to action — converging rings", cta_button)
	return column


func _build_snug_rig() -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	_add_heading(wrap, "SNUG RIG — click around")

	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 2)  # action-menu spacing
	wrap.add_child(menu)

	for label_text: String in ["Attack", "Move", "Items"]:
		var button := _make_button(label_text)
		button.pressed.connect(_on_rig_pressed.bind(button, menu))
		menu.add_child(button)
	var ember := _make_button("Ember  (0 uses)")
	ember.disabled = true
	ember.denied.connect(_show_why.bind(ember))
	menu.add_child(ember)
	var end_turn := _make_button("End Turn")
	end_turn.call_to_action = true
	menu.add_child(end_turn)

	(menu.get_child(0) as InteractiveButton).selected = true
	return wrap


func _build_controls() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
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


## Deny readout appears right beside the button that refused, tooltip-style.
func _show_why(source: InteractiveButton) -> void:
	_why_label.text = "NO USES REMAINING"
	var rect := source.get_global_rect()
	_why_label.global_position = Vector2(rect.position.x + 4, rect.position.y - 11)
	_why_label.visible = true
	var timer := get_tree().create_timer(1.3)
	timer.timeout.connect(func() -> void: _why_label.visible = false)


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


func _add_labeled(parent: Container, caption: String, specimen: Control) -> void:
	var label := Label.new()
	label.text = caption
	label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY_GLOW)
	parent.add_child(label)
	parent.add_child(specimen)

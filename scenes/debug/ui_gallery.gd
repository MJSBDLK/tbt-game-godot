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
const GLOW_MATERIAL: ShaderMaterial = preload("res://resources/hud_glow.tres")
const GAME_THEME: Theme = preload("res://resources/game_theme.tres")

var _why_popup: PanelContainer = null
## The states-list CTA specimen — the rig's End Turn borrows the (unique)
## call-to-action flag from it and returns it on a second press.
var _specimen_cta: InteractiveButton = null
## Every button in the gallery, for scene-wide A/B toggles.
var _all_buttons: Array[InteractiveButton] = []


func _ready() -> void:
	# Debug scenes run standalone (no GameRoot/HUDViewport), so opt this window
	# into the design canvas + integer stretch directly. VIEWPORT mode (not
	# CANVAS_ITEMS): render at 640x360 and upscale the texture, exactly like
	# the real HUDViewport pipeline — CANVAS_ITEMS scales draw calls at native
	# resolution, which left 1-design-px shader effects (the orthogonal text
	# glow) rendering as 1 NATIVE px hairlines at 4x/6x.
	var window := get_window()
	window.content_scale_size = DESIGN_RESOLUTION
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
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
	static_panel.add_child(_make_glow_label("Terrain Info",
			GameColors.TEXT_PRIMARY, GameColors.TEXT_PRIMARY_GLOW))
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
	_specimen_cta = cta_button
	_add_labeled(column, "Call to action — converging rings", cta_button)
	return column


func _build_snug_rig() -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	_add_heading(wrap, "SNUG RIG — click around")

	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 2)  # action-menu spacing
	wrap.add_child(menu)

	# Real action-menu shape: move chips on top, text buttons below.
	# Ember holds the cursor at start; Frost Lance is the ASSIGNED move
	# (parked brackets); Spark is depleted; Gloom is Void-locked.
	var chip_specs: Array[Array] = [
		# [name, element, uses, max, assigned, locked]
		["Ember", Enums.ElementalType.FIRE, 3, 5, false, false],
		["Frost Lance", Enums.ElementalType.COLD, 2, 3, true, false],
		["Spark", Enums.ElementalType.ELECTRIC, 0, 4, false, false],
		["Gloom", Enums.ElementalType.VOID, 2, 2, false, true],
	]
	for spec: Array in chip_specs:
		var chip_button := _make_chip(spec[0], spec[1], spec[2], spec[3], spec[4], spec[5])
		# setup() runs deferred (on ready), so disabled isn't known yet — connect
		# both: pressed only ever fires enabled, denied only ever fires disabled.
		chip_button.denied.connect(_show_why.bind(chip_button))
		chip_button.pressed.connect(_on_rig_pressed.bind(chip_button, menu))
		menu.add_child(chip_button)

	for label_text: String in ["Unit Info", "Wait"]:
		var button := _make_button(label_text)
		button.pressed.connect(_on_rig_pressed.bind(button, menu))
		menu.add_child(button)
	# Only ONE call to action may exist (scarcity rule) — the specimen column
	# holds it; pressing End Turn here borrows it into the snug rig so the
	# rings can be judged crossing 2px gaps, and returns it on a second press.
	var end_turn := _make_button("End Turn")
	end_turn.pressed.connect(_on_rig_end_turn_pressed.bind(end_turn))
	menu.add_child(end_turn)
	wrap.add_child(_make_glow_label("(press End Turn to move the CTA here)",
			GameColors.TEXT_SECONDARY, GameColors.TEXT_SECONDARY_GLOW))

	(menu.get_child(0) as InteractiveButton).selected = true
	return wrap


func _on_rig_end_turn_pressed(end_turn: InteractiveButton) -> void:
	if end_turn.call_to_action:
		end_turn.call_to_action = false
		_specimen_cta.call_to_action = true
	else:
		# Claiming steals from the specimen (the scarcity guard logs the theft).
		end_turn.call_to_action = true


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


## Deny readout: the game's styled tooltip (game_theme TooltipPanel + GlowLabel,
## same recipe as TapTooltip) floated just above the button that refused.
func _show_why(source: InteractiveButton) -> void:
	if _why_popup != null and is_instance_valid(_why_popup):
		_why_popup.queue_free()
	var reason := "NO USES REMAINING"
	var chip := source as MoveChipButton
	if chip != null and chip.disabled_reason != "":
		reason = chip.disabled_reason
	var popup := PanelContainer.new()
	popup.theme = GAME_THEME
	popup.theme_type_variation = "TooltipPanel"
	popup.top_level = true
	var label := _make_glow_label(reason,
			GameColors.TEXT_PRIMARY, GameColors.TEXT_PRIMARY_GLOW)
	label.theme_type_variation = "TooltipLabel"
	label.add_theme_font_override("font", FONT_8PX)
	label.add_theme_font_size_override("font_size", 8)
	popup.add_child(label)
	add_child(popup)
	_why_popup = popup
	# Size lands a frame later; then center it above the refusing button.
	await get_tree().process_frame
	if not is_instance_valid(popup):
		return
	var rect := source.get_global_rect()
	popup.position = Vector2(
			rect.position.x + (rect.size.x - popup.size.x) / 2.0,
			rect.position.y - popup.size.y - 2.0)
	var timer := get_tree().create_timer(1.3)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(popup):
			popup.queue_free())


## Real MoveChipButton from a throwaway Move resource — the gallery exercises
## the same component the action menu will adopt.
func _make_chip(move_name: String, element: Enums.ElementalType, uses: int,
		max_uses: int, is_assigned: bool, locked: bool) -> MoveChipButton:
	var move := Move.new()
	move.move_name = move_name
	move.element_type = element
	move.current_uses = uses
	move.max_uses = max_uses
	var chip_button := MoveChipButton.new()
	chip_button.custom_minimum_size = Vector2(120, 14)
	_all_buttons.append(chip_button)
	# setup() needs the chip child from _ready — defer until it's in the tree.
	chip_button.ready.connect(chip_button.setup.bind(move, is_assigned, locked))
	return chip_button


func _make_button(label_text: String) -> InteractiveButton:
	var button := InteractiveButton.new()
	button.text = label_text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(120, 14)  # action-menu dimensions
	_all_buttons.append(button)
	return button


## GlowLabel with the panel-text identity glow — every label in the gallery is
## a GlowLabel, same as every label in a real panel (style guide §3).
func _make_glow_label(label_text: String, font_color: Color, glow: Color) -> GlowLabel:
	var label := GlowLabel.new()
	label.text = label_text
	label.add_theme_color_override("font_color", font_color)
	label.material = GLOW_MATERIAL.duplicate()
	label.glow_color = glow
	return label


func _add_heading(parent: Container, heading: String) -> void:
	parent.add_child(_make_glow_label(heading,
			GameColors.TEXT_PRIMARY, GameColors.TEXT_PRIMARY_GLOW))


func _add_labeled(parent: Container, caption: String, specimen: Control) -> void:
	parent.add_child(_make_glow_label(caption,
			GameColors.TEXT_SECONDARY, GameColors.TEXT_SECONDARY_GLOW))
	parent.add_child(specimen)

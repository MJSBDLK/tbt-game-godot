## UnitPreviewPanel after the chip adoption (2026-07-19): the moves list is
## real MoveChipButtons in display mode — same component as the action menu,
## no interactivity (the preview is a passive readout). The assigned move
## carries the orbit here too (2026-07-29): unlike the parked brackets it
## replaced, the orbit can't read as the cursor, so the display-venue ban
## retired with them.
extends GutTest


func test_moves_become_display_mode_chips() -> void:
	var scene: PackedScene = load(
			"res://scenes/ui/panels/unit_preview_panel/unit_preview_panel.tscn")
	var panel := scene.instantiate() as UnitPreviewPanel
	add_child_autofree(panel)

	var ember := Move.new()
	ember.move_name = "Ember"
	ember.element_type = Enums.ElementalType.FIRE
	ember.current_uses = 3
	ember.max_uses = 5
	var spark := Move.new()
	spark.move_name = "Spark"
	spark.element_type = Enums.ElementalType.ELECTRIC
	spark.current_uses = 2
	spark.max_uses = 4
	var unit := Unit.new()
	autofree(unit)
	var data := CharacterData.new()
	data.equipped_moves = [ember, spark]
	unit.character_data = data
	unit.assigned_move = ember

	panel._update_moves(unit)

	var chips: Array[MoveChipButton] = []
	for child: Node in panel._moves_container.get_children():
		if child is MoveChipButton:
			chips.append(child)
	assert_eq(chips.size(), 2, "one chip per equipped move")
	assert_true(chips[0].assigned,
			"the armed move carries the orbit in the readout too — the orbit"
			+ " can't read as the cursor, so the old display-venue ban retired")
	assert_false(chips[1].assigned, "only the armed move orbits")
	assert_eq(chips[0].mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"display mode: the preview is a readout, not a menu")
	assert_eq(chips[0]._name_label.text, "Ember")
	assert_false(chips[0]._scheme_glyph.visible,
			"preview field set: identity + uses — scheme/range stay in the menu")
	assert_true(chips[0]._uses_label.visible)


## Touch-only hold-to-peek (ui-style-guide.md §14): the panel watches for
## genuine touch holds itself, because the chips' MOUSE_FILTER_IGNORE is
## load-bearing — mouse events must keep falling through to the map tiles,
## whose hover flips the panel away (the M&K/controller displacement).
func test_touch_hold_on_a_chip_peeks_but_the_mouse_passes_through() -> void:
	var scene: PackedScene = load(
			"res://scenes/ui/panels/unit_preview_panel/unit_preview_panel.tscn")
	var panel := scene.instantiate() as UnitPreviewPanel
	add_child_autofree(panel)
	panel.visible = true

	var ember := Move.new()
	ember.move_name = "Ember"
	ember.element_type = Enums.ElementalType.FIRE
	ember.current_uses = 3
	ember.max_uses = 5
	var unit := Unit.new()
	autofree(unit)
	var data := CharacterData.new()
	data.equipped_moves = [ember]
	unit.character_data = data
	panel._update_moves(unit)
	await wait_process_frames(2)

	var chip: MoveChipButton = null
	for child: Node in panel._moves_container.get_children():
		if child is MoveChipButton and child.visible:
			chip = child
			break
	assert_not_null(chip, "the display chip exists")
	var center: Vector2 = chip.get_global_rect().get_center()

	var saved_hold_ms: int = Settings.tooltip_hold_ms
	Settings.tooltip_hold_ms = 200

	# A REAL mouse press on the chip never arms — the panel dodges instead.
	var mouse_press := InputEventMouseButton.new()
	mouse_press.button_index = MOUSE_BUTTON_LEFT
	mouse_press.pressed = true
	mouse_press.position = center
	panel._input(mouse_press)
	assert_null(panel._peek_chip,
			"a real mouse never arms the hold — displacement is its answer")

	# A genuine touch press (emulated device) arms; the hold matures to a card.
	var touch_press := InputEventMouseButton.new()
	touch_press.button_index = MOUSE_BUTTON_LEFT
	touch_press.pressed = true
	touch_press.device = InputEvent.DEVICE_ID_EMULATION
	touch_press.position = center
	panel._input(touch_press)
	assert_eq(panel._peek_chip, chip, "the hold armed on the touched chip")
	await wait_seconds(0.3)
	assert_true(MoveTooltip.is_open_for(chip),
			"touch is the one input that peeks in the readout venue")

	var touch_release := InputEventMouseButton.new()
	touch_release.button_index = MOUSE_BUTTON_LEFT
	touch_release.pressed = false
	touch_release.device = InputEvent.DEVICE_ID_EMULATION
	touch_release.position = center
	panel._input(touch_release)
	assert_false(MoveTooltip.is_open_for(chip), "release dismisses")

	Settings.tooltip_hold_ms = saved_hold_ms
	MoveTooltip.dismiss()


func test_hiding_the_panel_abandons_an_armed_hold() -> void:
	var scene: PackedScene = load(
			"res://scenes/ui/panels/unit_preview_panel/unit_preview_panel.tscn")
	var panel := scene.instantiate() as UnitPreviewPanel
	add_child_autofree(panel)
	panel._peek_hold_start_ms = Time.get_ticks_msec()
	panel.hide_panel()
	assert_eq(panel._peek_hold_start_ms, -1,
			"hide_panel ends the peek — no card matures over a closed panel")
	assert_null(panel._peek_chip)

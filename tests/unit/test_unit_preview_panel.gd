## UnitPreviewPanel after the chip adoption (2026-07-19): the moves list is
## real MoveChipButtons in display mode — same component as the action menu,
## no interactivity (the preview is a passive readout), assigned move keeps
## its parked brackets in this venue too.
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
	var unit := Unit.new()
	autofree(unit)
	var data := CharacterData.new()
	data.equipped_moves = [ember]
	unit.character_data = data
	unit.assigned_move = ember

	panel._update_moves(unit)

	var chips: Array[MoveChipButton] = []
	for child: Node in panel._moves_container.get_children():
		if child is MoveChipButton:
			chips.append(child)
	assert_eq(chips.size(), 1, "one chip per equipped move")
	assert_false(chips[0].assigned,
			"NO assigned brackets in a static readout — they read as 'selected'"
			+ " (RQD 2026-07-19); a display-safe marker is a mockup question")
	assert_eq(chips[0].mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"display mode: the preview is a readout, not a menu")
	assert_eq(chips[0]._name_label.text, "Ember")

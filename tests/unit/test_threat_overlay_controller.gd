## Phase: threat-overlay controller. The renderer is visual (eyeball-tested in
## game); what's unit-testable here is the controller's on/off state machine. The
## controller's _ready spins up its renderer and pulls enemies from TurnManager
## (empty in tests -> empty danger map), so toggling is safe without a grid.
extends GutTest


func _controller() -> ThreatOverlayController:
	var controller := ThreatOverlayController.new()
	add_child_autofree(controller)
	return controller


func test_starts_hidden() -> void:
	assert_false(_controller().is_showing(), "overlay is off until toggled")


func test_toggle_shows_then_hides() -> void:
	var controller := _controller()
	controller.toggle_all_enemies()
	assert_true(controller.is_showing(), "first toggle turns the all-enemies zone on")
	controller.toggle_all_enemies()
	assert_false(controller.is_showing(), "second toggle turns it back off")


func test_refresh_is_safe_with_no_enemies() -> void:
	# No grid, no enemies registered: refreshing the live overlay must not error.
	var controller := _controller()
	controller.toggle_all_enemies()
	controller.refresh()
	assert_true(controller.is_showing(), "refresh leaves the mode untouched")


# =============================================================================
# Individual pins (toggle_unit) — persist-until-toggled-off semantics
# =============================================================================

func _enemy(hp: int = 10) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.faction = Enums.UnitFaction.ENEMY
	unit.current_hp = hp
	unit.character_data = CharacterData.new()
	return unit


func test_toggle_unit_pins_and_unpins() -> void:
	var controller := _controller()
	var enemy := _enemy()
	controller.toggle_unit(enemy)
	assert_true(controller.is_unit_shown(enemy), "first toggle pins the enemy's zone")
	assert_true(controller.is_showing(), "a pin turns the overlay on")
	controller.toggle_unit(enemy)
	assert_false(controller.is_unit_shown(enemy), "second toggle unpins")
	assert_false(controller.is_showing(), "last pin removed turns the overlay off")


func test_pins_are_additive_across_enemies() -> void:
	var controller := _controller()
	var enemy_a := _enemy()
	var enemy_b := _enemy()
	controller.toggle_unit(enemy_a)
	controller.toggle_unit(enemy_b)
	assert_true(controller.is_unit_shown(enemy_a), "first pin survives adding a second")
	assert_true(controller.is_unit_shown(enemy_b), "second pin added")
	controller.toggle_unit(enemy_a)
	assert_false(controller.is_unit_shown(enemy_a), "unpinning one leaves the other")
	assert_true(controller.is_unit_shown(enemy_b), "unpinning one leaves the other")


func test_global_toggle_is_show_all_or_clear_all() -> void:
	var controller := _controller()
	var enemy := _enemy()
	controller.toggle_unit(enemy)
	# Anything lit -> the global toggle clears EVERYTHING (the touch-friendly
	# "toggle all off"), it does not switch to the army-wide zone.
	controller.toggle_all_enemies()
	assert_false(controller.is_showing(), "global toggle with pins lit = clear all")
	assert_false(controller.is_unit_shown(enemy), "pins cleared too")
	# From a clean board it shows the whole army.
	controller.toggle_all_enemies()
	assert_true(controller.is_showing(), "global toggle from clean board = show all")


func test_pinning_replaces_army_wide_zone() -> void:
	var controller := _controller()
	var enemy := _enemy()
	controller.toggle_all_enemies()
	controller.toggle_unit(enemy)
	assert_true(controller.is_unit_shown(enemy),
			"pinning while ALL is shown switches to just that pin")


func test_clear_all_empties_everything() -> void:
	var controller := _controller()
	controller.toggle_unit(_enemy())
	controller.clear_all()
	assert_false(controller.is_showing(), "clear_all turns the overlay off")


func test_defeated_pin_is_pruned_on_refresh() -> void:
	var controller := _controller()
	var enemy := _enemy(0)  # is_defeated() == true
	controller.toggle_unit(enemy)
	controller.refresh()
	assert_false(controller.is_unit_shown(enemy), "a dead enemy's pin is dropped")
	assert_false(controller.is_showing(), "sole pin dying turns the overlay off")


func test_pinned_and_army_zones_use_distinct_render_styles() -> void:
	# The player must always be able to tell "one enemy's zone" from "the whole
	# army" — the controller selects the renderer palette per mode.
	var controller := _controller()
	var renderer: ThreatOverlayRenderer = controller.get_node("ThreatOverlayRenderer")
	controller.toggle_all_enemies()
	assert_eq(renderer._style, ThreatOverlayRenderer.Style.ARMY,
			"army-wide zone renders in the ARMY palette")
	controller.clear_all()
	controller.toggle_unit(_enemy())
	assert_eq(renderer._style, ThreatOverlayRenderer.Style.PINNED,
			"pinned zones render in the PINNED palette")


func test_changed_signal_fires_on_state_transitions() -> void:
	var controller := _controller()
	watch_signals(controller)
	var enemy := _enemy()
	controller.toggle_unit(enemy)
	controller.toggle_all_enemies()  # clear-all path
	controller.toggle_all_enemies()  # show-all path
	assert_signal_emit_count(controller, "changed", 3,
			"pin, clear-all, and show-all each notify UI chips")

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
	controller.toggle_army_zone()
	assert_true(controller.is_showing(), "first toggle turns the army zone on")
	controller.toggle_army_zone()
	assert_false(controller.is_showing(), "second toggle turns it back off")


func test_refresh_is_safe_with_no_enemies() -> void:
	# No grid, no enemies registered: refreshing the live overlay must not error.
	var controller := _controller()
	controller.toggle_army_zone()
	controller.refresh()
	assert_true(controller.is_showing(), "refresh leaves what's shown untouched")


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


func test_pins_and_the_army_zone_stack() -> void:
	var controller := _controller()
	var enemy := _enemy()
	controller.toggle_unit(enemy)
	controller.toggle_army_zone()
	assert_true(controller._army_shown, "the army zone joins the pin")
	assert_true(controller.is_unit_shown(enemy), "and the pin stays")
	controller.toggle_army_zone()
	assert_false(controller._army_shown)
	assert_true(controller.is_unit_shown(enemy), "hiding the army zone leaves the pins up")


func test_pinning_keeps_the_army_zone() -> void:
	var controller := _controller()
	var enemy := _enemy()
	controller.toggle_army_zone()
	controller.toggle_unit(enemy)
	assert_true(controller._army_shown, "a pin goes on top of the army zone, not instead of it")
	assert_true(controller.is_unit_shown(enemy))


func test_red_wins_where_the_layers_overlap() -> void:
	var army := {Vector2i(0, 0): 2, Vector2i(1, 0): 1}
	var pinned := {Vector2i(1, 0): 1}
	assert_eq(ThreatOverlayController.army_layer(army, pinned), {Vector2i(0, 0): 2},
			"the army layer leaves the pinned cell to the red")
	assert_eq(army.size(), 2, "the army map itself is untouched")


func test_defeated_pin_is_pruned_on_refresh() -> void:
	var controller := _controller()
	var enemy := _enemy(0)  # is_defeated() == true
	controller.toggle_unit(enemy)
	controller.refresh()
	assert_false(controller.is_unit_shown(enemy), "a dead enemy's pin is dropped")
	assert_false(controller.is_showing(), "sole pin dying turns the overlay off")


func test_pinned_and_army_zones_use_distinct_render_styles() -> void:
	# The player must always be able to tell "one enemy's zone" from "the whole
	# army": each layer has its own renderer and palette, the pins on top.
	var controller := _controller()
	var army: ThreatOverlayRenderer = controller.get_node("ArmyZoneRenderer")
	var pinned: ThreatOverlayRenderer = controller.get_node("PinnedZoneRenderer")
	controller.toggle_army_zone()
	controller.toggle_unit(_enemy())
	assert_eq(army._style, ThreatOverlayRenderer.Style.ARMY, "the army zone in the ARMY palette")
	assert_eq(pinned._style, ThreatOverlayRenderer.Style.PINNED, "pins in the PINNED palette")
	assert_gt(pinned.get_index(), army.get_index(), "the pins draw on top")


func test_changed_signal_fires_on_state_transitions() -> void:
	var controller := _controller()
	watch_signals(controller)
	var enemy := _enemy()
	controller.toggle_unit(enemy)
	controller.toggle_army_zone()
	controller.toggle_army_zone()
	assert_signal_emit_count(controller, "changed", 3,
			"a pin and the army zone on and off each notify UI chips")


# =============================================================================
# Enemy phase — the zone stands down, mode and pins survive
# =============================================================================

## One armed enemy standing still on a 3×3 grid, so its zone has cells to draw.
func _armed_enemy_on_grid() -> Unit:
	GridManager.clear_grid()
	for x: int in range(3):
		for y: int in range(3):
			var tile := Tile.new()
			var sprite := Sprite2D.new()
			sprite.name = "Sprite2D"
			tile.add_child(sprite)
			add_child_autofree(tile)
			tile.grid_x = x
			tile.grid_y = y
			tile.terrain_type_name = "Plains"
			GridManager.register_tile(tile)
	var enemy := _enemy()
	enemy.can_move = false
	var bonk := Move.new()
	bonk.damage_type = Enums.DamageType.PHYSICAL
	bonk.attack_range = 1
	var moves: Array[Move] = [bonk]
	enemy.character_data.equipped_moves = moves
	var tile: Tile = GridManager.get_tile(1, 1)
	enemy.current_tile = tile
	tile.current_unit = enemy
	return enemy


func test_the_zone_stands_down_for_the_enemy_phase() -> void:
	var controller := _controller()
	var renderer: ThreatOverlayRenderer = controller.get_node("PinnedZoneRenderer")
	var enemy := _armed_enemy_on_grid()
	controller.toggle_unit(enemy)
	assert_false(renderer._centers.is_empty(), "precondition: the pinned zone is drawn")
	controller._on_enemy_phase_started()
	assert_true(renderer._centers.is_empty(), "nothing drawn on the enemy's turn")
	controller._on_board_changed(enemy)
	assert_true(renderer._centers.is_empty(), "an enemy step mid-phase doesn't repaint it")
	assert_true(controller.is_unit_shown(enemy), "the pin survives the enemy phase")
	controller._on_player_phase_started(2)
	assert_false(renderer._centers.is_empty(), "and the zone is back for the player's turn")
	GridManager.clear_grid()


func test_a_pinned_enemy_paints_red_over_the_army_zone() -> void:
	var controller := _controller()
	var enemy := _armed_enemy_on_grid()
	var roster_before: Array[Unit] = TurnManager._enemy_units
	TurnManager._enemy_units = [enemy] as Array[Unit]
	var army: ThreatOverlayRenderer = controller.get_node("ArmyZoneRenderer")
	var pinned: ThreatOverlayRenderer = controller.get_node("PinnedZoneRenderer")
	controller.toggle_army_zone()
	assert_false(army._centers.is_empty(), "precondition: the army zone is drawn")
	controller.toggle_unit(enemy)
	assert_false(pinned._centers.is_empty(), "the pin is drawn")
	assert_true(army._centers.is_empty(), "its cells are the pin's now: no amber under the red")
	TurnManager._enemy_units = roster_before
	GridManager.clear_grid()


func test_phase_handlers_ride_the_turn_manager_signals() -> void:
	var controller := _controller()
	assert_true(TurnManager.enemy_phase_started.is_connected(controller._on_enemy_phase_started))
	assert_true(TurnManager.player_phase_started.is_connected(controller._on_player_phase_started))


func test_the_toggle_key_is_ignored_on_the_enemy_turn() -> void:
	var controller := _controller()
	controller._on_enemy_phase_started()
	var press := InputEventAction.new()
	press.action = "toggle_threat_zones"
	press.pressed = true
	controller._unhandled_input(press)
	assert_false(controller.is_showing(), "V on the enemy's turn changes a zone nobody could see")


# =============================================================================
# The zone button (V / RT): over an enemy it pins, anywhere else it's the army's
# =============================================================================

func after_each() -> void:
	InputSource.last_device = InputSource.Device.MOUSE
	InputSource.last_kind = InputSource.Kind.POINTER
	InputSource._held_axis_actions.clear()


func _tile_with(unit: Unit) -> Tile:
	var tile: Tile = autofree(Tile.new())
	tile.current_unit = unit
	return tile


func test_the_next_press_follows_whats_lit() -> void:
	# The hint bar names this, so it must be what press_zone_button does.
	var controller := _controller()
	var on_enemy := _tile_with(_enemy())
	var empty := _tile_with(null)
	InputSource.last_device = InputSource.Device.JOYPAD
	assert_eq(controller.zone_press_for(empty), ThreatOverlayController.Press.SHOW_ARMY)
	assert_eq(controller.zone_press_for(on_enemy), ThreatOverlayController.Press.PIN)
	controller.press_zone_button(on_enemy)
	assert_eq(controller.zone_press_for(on_enemy), ThreatOverlayController.Press.UNPIN)
	assert_eq(controller.zone_press_for(empty), ThreatOverlayController.Press.SHOW_ARMY,
			"a pin up: off the enemy the button is still the army zone's")
	controller.press_zone_button(empty)
	assert_true(controller._army_shown)
	assert_true(controller.is_unit_shown(on_enemy.current_unit), "and the pin stayed")
	assert_eq(controller.zone_press_for(empty), ThreatOverlayController.Press.HIDE_ARMY)
	assert_eq(controller.zone_press_for(on_enemy), ThreatOverlayController.Press.UNPIN,
			"the army zone up: a pinned enemy's press still unpins it")
	InputSource.last_device = InputSource.Device.TOUCH
	assert_eq(controller.zone_press_for(on_enemy), ThreatOverlayController.Press.HIDE_ARMY,
			"touch's button is always the army's")


func test_the_zone_button_over_an_enemy_pins_its_zone() -> void:
	var controller := _controller()
	var enemy := _enemy()
	InputSource.last_device = InputSource.Device.JOYPAD
	controller.press_zone_button(_tile_with(enemy))
	assert_true(controller.is_unit_shown(enemy), "RT over an enemy pins that enemy")
	controller.press_zone_button(_tile_with(enemy))
	assert_false(controller.is_showing(), "and again unpins it")


func test_the_zone_button_anywhere_else_is_the_armys() -> void:
	var controller := _controller()
	var own := _enemy()
	own.faction = Enums.UnitFaction.PLAYER
	InputSource.last_device = InputSource.Device.JOYPAD
	controller.press_zone_button(_tile_with(own))
	assert_true(controller.is_showing(), "over your own unit: the army zone on")
	assert_false(controller.is_unit_shown(own))
	controller.press_zone_button(_tile_with(null))
	assert_false(controller.is_showing(), "over an empty tile: off again")


func test_touchs_zone_button_is_always_the_armys() -> void:
	var controller := _controller()
	var enemy := _enemy()
	InputSource.last_device = InputSource.Device.TOUCH
	controller.press_zone_button(_tile_with(enemy))
	assert_false(controller.is_unit_shown(enemy), "touch has no cursor: its last tap isn't an aim")
	assert_true(controller.is_showing())


func _squeeze(controller: ThreatOverlayController, values: Array) -> void:
	for value: float in values:
		var motion := InputEventJoypadMotion.new()
		motion.axis = JOY_AXIS_TRIGGER_RIGHT
		motion.axis_value = value
		controller._unhandled_input(motion)


func test_a_trigger_squeeze_toggles_once() -> void:
	InputManager._hovered_tile = null
	var controller := _controller()
	_squeeze(controller, [0.2, 0.6, 0.9, 1.0, 0.8])
	assert_true(controller.is_showing(), "one squeeze, one toggle: a second would turn it off again")
	_squeeze(controller, [0.3, 0.0, 0.7, 0.0])
	assert_false(controller.is_showing(), "back at rest, a new squeeze toggles again")

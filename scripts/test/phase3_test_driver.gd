## Temporary test driver for Phase 3 combat system.
## Left-click: select player unit, add waypoint, or attack enemy.
## Click existing waypoint: confirm and execute movement.
## Key 1-4: assign move by index on selected unit.
## Key S: apply burn to selected unit and process turn effects.
## Key T: print type chart test matchups.
## Escape: cancel / snap back to turn start.
## Replaced by InputManager in Phase 4.
extends Node2D


var _unit_scene: PackedScene = preload("res://scenes/battle/unit.tscn")
var _selected_unit: Unit = null
var _units_container: Node2D = null
var _all_units: Array[Unit] = []
var _battle_hud: Node = null
var _hovered_tile: Tile = null
var _unit_has_moved: bool = false  # true after movement, before acting


func _ready() -> void:
	_units_container = Node2D.new()
	_units_container.name = "Units"
	add_child(_units_container)

	var hud_script: GDScript = load("res://scripts/ui/battle_hud.gd")
	_battle_hud = hud_script.new()
	add_child(_battle_hud)

	if GridManager.is_grid_ready():
		_spawn_test_units()
	else:
		GridManager.grid_ready.connect(_spawn_test_units)


func _spawn_test_units() -> void:
	var offset_x: int = GridManager.grid_offset_x
	var offset_y: int = GridManager.grid_offset_y

	# 2 player units (Spaceman) near bottom-left
	var player_tile_1 := GridManager.get_tile(offset_x + 1, offset_y + 1)
	if player_tile_1 != null:
		var unit := _create_unit("res://data/characters/spaceman.json", Enums.UnitFaction.PLAYER, player_tile_1)
		unit.auto_assign_first_usable_move()
		print("Phase3Test: Spawned player '%s' at %s" % [unit.unit_name, player_tile_1.get_coordinates()])

	var player_tile_2 := GridManager.get_tile(offset_x + 1, offset_y + 3)
	if player_tile_2 != null:
		var unit := _create_unit("res://data/characters/spaceman.json", Enums.UnitFaction.PLAYER, player_tile_2)
		unit.auto_assign_first_usable_move()
		print("Phase3Test: Spawned player '%s' at %s" % [unit.unit_name, player_tile_2.get_coordinates()])

	# 2 enemy units (Fire Warrior) — first one adjacent to player for combat testing
	var enemy_tile_1 := GridManager.get_tile(offset_x + 2, offset_y + 1)
	if enemy_tile_1 != null:
		var unit := _create_unit("res://data/characters/grunt.json", Enums.UnitFaction.ENEMY, enemy_tile_1)
		unit.auto_assign_first_usable_move()
		print("Phase3Test: Spawned enemy '%s' at %s" % [unit.unit_name, enemy_tile_1.get_coordinates()])

	var enemy_tile_2 := GridManager.get_tile(offset_x + 3, offset_y + 3)
	if enemy_tile_2 != null:
		var unit := _create_unit("res://data/characters/grunt.json", Enums.UnitFaction.ENEMY, enemy_tile_2)
		unit.auto_assign_first_usable_move()
		print("Phase3Test: Spawned enemy '%s' at %s" % [unit.unit_name, enemy_tile_2.get_coordinates()])


func _create_unit(json_path: String, faction: Enums.UnitFaction, tile: Tile) -> Unit:
	var unit: Unit = _unit_scene.instantiate() as Unit
	unit.character_json_path = json_path
	unit.faction = faction
	_units_container.add_child(unit)
	unit.initialize(tile)
	_all_units.append(unit)
	return unit


func _input(event: InputEvent) -> void:
	# Tile hover tracking
	if event is InputEventMouseMotion:
		var world_position := get_global_mouse_position()
		var tile := GridManager.get_tile_at_position(world_position)
		if tile != _hovered_tile:
			_hovered_tile = tile
			if _battle_hud != null:
				_battle_hud.show_terrain_info(tile)
		return

	if event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		var world_position := get_global_mouse_position()
		var clicked_tile := GridManager.get_tile_at_position(world_position)

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(clicked_tile)
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click()

	elif event is InputEventKey and event.pressed:
		var key_event := event as InputEventKey
		_handle_key_press(key_event)


func _handle_left_click(clicked_tile: Tile) -> void:
	if clicked_tile == null:
		return

	if clicked_tile.current_unit != null and clicked_tile.current_unit is Unit:
		var clicked_unit := clicked_tile.current_unit as Unit

		# Click enemy while unit selected -> combat
		if _selected_unit != null and clicked_unit.faction != _selected_unit.faction:
			if not clicked_unit.is_defeated():
				_initiate_combat(clicked_unit)
				return

		# Click any unit -> show info, select if player
		if clicked_unit.faction == Enums.UnitFaction.PLAYER and clicked_unit.can_act:
			_select_unit(clicked_unit)
		else:
			# Show enemy/neutral info without selecting
			if _battle_hud != null:
				_battle_hud.show_unit_info(clicked_unit)
		return

	# Click tile while unit selected -> waypoint or confirm movement
	if _selected_unit != null and _selected_unit.can_act and not _unit_has_moved:
		# Check if clicking on an existing waypoint -> execute movement
		if _is_waypoint_tile(clicked_tile):
			_execute_movement()
			return

		# Otherwise add waypoint if in range
		if GridManager.is_in_current_movement_range(clicked_tile):
			var success := _selected_unit.add_waypoint(clicked_tile)
			if success:
				GridManager.display_movement_range(_selected_unit)


func _handle_right_click() -> void:
	if _selected_unit != null:
		_cancel_and_deselect()


func _handle_key_press(event: InputEventKey) -> void:
	# Escape: snap back if moved, otherwise cancel/deselect
	if event.keycode == KEY_ESCAPE:
		if _selected_unit != null:
			_cancel_and_deselect()
		return

	# T: type chart test (works without selection)
	if event.keycode == KEY_T:
		_print_type_chart_tests()
		return

	if _selected_unit == null:
		return

	# Key 1-4: assign move by index
	var move_index := -1
	match event.keycode:
		KEY_1: move_index = 0
		KEY_2: move_index = 1
		KEY_3: move_index = 2
		KEY_4: move_index = 3

	if move_index >= 0 and _selected_unit.character_data != null:
		var moves := _selected_unit.character_data.equipped_moves
		if move_index < moves.size():
			_selected_unit.assign_move(moves[move_index])
			if _battle_hud != null:
				_battle_hud.update_move_list(_selected_unit)
				_battle_hud.refresh()
		return

	# Key S: apply burn + process turn effects
	if event.keycode == KEY_S:
		var status_system: Node = get_node("/root/StatusEffectSystem")
		status_system.apply_status_effect_by_name(_selected_unit, _selected_unit, "BURN")
		status_system.process_turn_start_effects(_selected_unit)
		if _battle_hud != null:
			_battle_hud.refresh()
		return


func _initiate_combat(target: Unit) -> void:
	if _selected_unit == null or _selected_unit.assigned_move == null:
		print("Phase3Test: No move assigned! Press 1-4 to assign a move first.")
		return

	var distance := DamageCalculator.get_manhattan_distance(_selected_unit, target)
	if distance > _selected_unit.assigned_move.attack_range:
		print("Phase3Test: Target out of range (distance=%d, range=%d)" % [
			distance, _selected_unit.assigned_move.attack_range])
		return

	GridManager.clear_movement_range()

	await _selected_unit.execute_combat_sequence(target, _selected_unit.assigned_move)

	if _battle_hud != null:
		_battle_hud.refresh()

	_selected_unit.set_acted()
	_selected_unit.set_selected(false)
	_selected_unit = null
	_unit_has_moved = false
	if _battle_hud != null:
		_battle_hud.hide_unit_info()


func _select_unit(unit: Unit) -> void:
	if _selected_unit != null:
		_cancel_and_deselect()
	_selected_unit = unit
	_unit_has_moved = false
	_selected_unit.set_selected(true)
	GridManager.display_movement_range(_selected_unit)

	if _battle_hud != null:
		_battle_hud.show_unit_info(unit)


func _deselect_unit() -> void:
	if _selected_unit == null:
		return
	_selected_unit.set_selected(false)
	_selected_unit.clear_waypoints()
	GridManager.clear_movement_range()
	_selected_unit = null
	if _battle_hud != null:
		_battle_hud.hide_unit_info()


func _is_waypoint_tile(tile: Tile) -> bool:
	if _selected_unit == null:
		return false
	for waypoint: Variant in _selected_unit.planned_waypoints:
		if waypoint.tile == tile:
			return true
	return false


func _execute_movement() -> void:
	if _selected_unit == null:
		return
	GridManager.clear_movement_range()
	await _selected_unit.execute_planned_movement()
	_unit_has_moved = true
	# Unit stays selected — player can now attack or press Escape to snap back
	if _battle_hud != null:
		_battle_hud.refresh()


func _cancel_and_deselect() -> void:
	if _selected_unit == null:
		return
	if _unit_has_moved:
		# Snap back to turn-start position
		_selected_unit.cancel_movement()
		_unit_has_moved = false
	_deselect_unit()


func _print_type_chart_tests() -> void:
	print("--- Type Chart Tests ---")
	var test_matchups := [
		[Enums.ElementalType.FIRE, Enums.ElementalType.PLANT],
		[Enums.ElementalType.PLANT, Enums.ElementalType.ELECTRIC],
		[Enums.ElementalType.ELECTRIC, Enums.ElementalType.FIRE],
		[Enums.ElementalType.ELECTRIC, Enums.ElementalType.VOID],
		[Enums.ElementalType.SIMPLE, Enums.ElementalType.ROBO],
		[Enums.ElementalType.GRAVITY, Enums.ElementalType.OBSIDIAN],
		[Enums.ElementalType.FIRE, Enums.ElementalType.FIRE],
	]
	var type_chart: Node = get_node("/root/TypeChartManager")
	for matchup in test_matchups:
		var attacking: Enums.ElementalType = matchup[0]
		var defending: Enums.ElementalType = matchup[1]
		var mult: float = type_chart.get_type_effectiveness(attacking, defending)
		var text: String = type_chart.get_effectiveness_text(mult)
		print("  %s vs %s = %.2fx %s" % [
			Enums.elemental_type_to_string(attacking),
			Enums.elemental_type_to_string(defending),
			mult, text])
	print("--- End Type Chart Tests ---")

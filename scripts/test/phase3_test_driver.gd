## Temporary test driver for Phase 3 combat system.
## Left-click: select player unit, add waypoint, or attack enemy.
## Right-click: execute movement or deselect.
## Key 1-4: assign move by index on selected unit.
## Key S: apply burn to selected unit and process turn effects.
## Key T: print type chart test matchups.
## Replaced by InputManager in Phase 4.
extends Node2D


var _unit_scene: PackedScene = preload("res://scenes/battle/unit.tscn")
var _selected_unit: Unit = null
var _units_container: Node2D = null
var _all_units: Array[Unit] = []


func _ready() -> void:
	_units_container = Node2D.new()
	_units_container.name = "Units"
	add_child(_units_container)

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
		var unit := _create_unit("res://data/characters/fire_warrior.json", Enums.UnitFaction.ENEMY, enemy_tile_1)
		unit.auto_assign_first_usable_move()
		print("Phase3Test: Spawned enemy '%s' at %s" % [unit.unit_name, enemy_tile_1.get_coordinates()])

	var enemy_tile_2 := GridManager.get_tile(offset_x + 3, offset_y + 3)
	if enemy_tile_2 != null:
		var unit := _create_unit("res://data/characters/fire_warrior.json", Enums.UnitFaction.ENEMY, enemy_tile_2)
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
	if event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		var world_position := get_global_mouse_position()
		var clicked_tile := GridManager.get_tile_at_position(world_position)

		var tile_info := "NULL"
		var unit_info := "N/A"
		if clicked_tile != null:
			tile_info = clicked_tile.get_coordinates()
			unit_info = str(clicked_tile.current_unit != null)
		print("Phase3Test: Click at world %s -> tile %s (has_unit=%s)" % [world_position, tile_info, unit_info])

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(clicked_tile)
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click()

	elif event is InputEventKey and event.pressed:
		var key_event := event as InputEventKey
		var sel_name := _selected_unit.unit_name if _selected_unit != null else "none"
		print("Phase3Test: Key pressed: %d (selected=%s)" % [key_event.keycode, sel_name])
		_handle_key_press(key_event)


func _handle_left_click(clicked_tile: Tile) -> void:
	if clicked_tile == null:
		print("Phase3Test: clicked_tile is null, ignoring")
		return

	if clicked_tile.current_unit != null and clicked_tile.current_unit is Unit:
		var clicked_unit := clicked_tile.current_unit as Unit

		# Click enemy while unit selected -> combat
		if _selected_unit != null and clicked_unit.faction != _selected_unit.faction:
			if not clicked_unit.is_defeated():
				_initiate_combat(clicked_unit)
				return

		# Click player unit -> select
		if clicked_unit.faction == Enums.UnitFaction.PLAYER and clicked_unit.can_act:
			_select_unit(clicked_unit)
			return

	# Click movement range tile -> add waypoint
	if _selected_unit != null and _selected_unit.can_act:
		if GridManager.is_in_current_movement_range(clicked_tile):
			var success := _selected_unit.add_waypoint(clicked_tile)
			if success:
				GridManager.display_movement_range(_selected_unit)
				print("Phase3Test: Waypoint added at %s" % clicked_tile.get_coordinates())


func _handle_right_click() -> void:
	if _selected_unit == null:
		return

	if not _selected_unit.planned_waypoints.is_empty():
		_selected_unit.movement_completed.connect(
			_on_movement_completed.bind(_selected_unit), CONNECT_ONE_SHOT)
		_selected_unit.execute_planned_movement()
		GridManager.clear_movement_range()
		print("Phase3Test: Executing movement")
	else:
		_deselect_unit()


func _handle_key_press(event: InputEventKey) -> void:
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
			print("Phase3Test: Assigned move '%s' to '%s'" % [
				moves[move_index].move_name, _selected_unit.unit_name])
		return

	# Key S: apply burn + process turn effects
	if event.keycode == KEY_S:
		print("Phase3Test: Applying BURN to '%s' and processing turn effects" % _selected_unit.unit_name)
		var status_system: Node = get_node("/root/StatusEffectSystem")
		status_system.apply_status_effect_by_name(_selected_unit, _selected_unit, "BURN")
		status_system.process_turn_start_effects(_selected_unit)
		return

	# Key T: print type chart test
	if event.keycode == KEY_T:
		_print_type_chart_tests()
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

	print("Phase3Test: Initiating combat: %s vs %s" % [_selected_unit.unit_name, target.unit_name])
	GridManager.clear_movement_range()

	await _selected_unit.execute_combat_sequence(target, _selected_unit.assigned_move)

	_selected_unit.set_acted()
	_selected_unit.set_selected(false)
	_selected_unit = null
	print("Phase3Test: Combat complete")


func _select_unit(unit: Unit) -> void:
	if _selected_unit != null:
		_deselect_unit()
	_selected_unit = unit
	_selected_unit.set_selected(true)
	GridManager.display_movement_range(_selected_unit)

	var move_info := ""
	if unit.assigned_move != null:
		move_info = " | move='%s'" % unit.assigned_move.move_name
	print("Phase3Test: Selected '%s' (HP=%d/%d%s)" % [
		unit.unit_name, unit.current_hp, unit.character_data.max_hp, move_info])


func _deselect_unit() -> void:
	if _selected_unit == null:
		return
	_selected_unit.set_selected(false)
	_selected_unit.clear_waypoints()
	GridManager.clear_movement_range()
	_selected_unit = null


func _on_movement_completed(unit: Unit) -> void:
	unit.set_acted()
	_selected_unit = null
	print("Phase3Test: Movement complete, unit acted")


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

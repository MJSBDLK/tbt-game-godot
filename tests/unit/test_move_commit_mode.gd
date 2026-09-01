## Settings.move_commit_mode (todo 4A, RQD 2026-08-31): WHEN a confirmed move
## plan actually walks. WALK_THEN_ACT = the shipped behavior (walk on plan
## confirm, then choose an action). ACT_THEN_WALK = logic commits instantly —
## current_tile, occupancy, every movement_completed listener — while the
## sprite stays at the origin behind the PathVisualizer's staged ghost until
## the action commits, then play_deferred_walk() replays the captured path.
## Pins the logic/visual split, the ghost hand-off, the clean cancel (the
## sprite never moved, so nothing teleports), the player-only gate, and the
## hint bar's mode-aware planning copy.
extends GutTest


const UNIT_SCENE: String = "res://scenes/battle/unit.tscn"
const SPACEMAN_PATH: String = "res://data/characters/spaceman.json"
const GRUNT_PATH: String = "res://data/characters/grunt.json"

var _mode_before: int = Settings.MoveCommitMode.WALK_THEN_ACT
var _motion_before: bool = true


func before_each() -> void:
	GridManager.clear_grid()
	_mode_before = Settings.move_commit_mode
	_motion_before = Settings.ui_motion_enabled
	Settings.ui_motion_enabled = true


func after_each() -> void:
	Settings.move_commit_mode = _mode_before
	Settings.ui_motion_enabled = _motion_before


func after_all() -> void:
	GridManager.clear_grid()


## A grid with REAL pixel spread (16px cells) and two rows, so "the sprite
## stayed" and "z follows the visible row" are falsifiable — coincident tiles
## would make every position assertion vacuously true.
func _grid_tile(x: int, y: int) -> void:
	var tile := Tile.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	tile.add_child(sprite)
	add_child_autofree(tile)
	tile.position = Vector2(x * 16, y * 16)
	tile.grid_x = x
	tile.grid_y = y
	tile.terrain_type_name = "Plains"
	GridManager.register_tile(tile)


func _open_grid(max_x: int, max_y: int = 0) -> void:
	for y: int in range(max_y + 1):
		for x: int in range(max_x + 1):
			_grid_tile(x, y)


func _spawn_scene_unit(json_path: String, faction: Enums.UnitFaction, x: int, y: int) -> Unit:
	var unit: Unit = (load(UNIT_SCENE) as PackedScene).instantiate() as Unit
	unit.character_json_path = json_path
	unit.faction = faction
	add_child_autofree(unit)
	unit.initialize(GridManager.get_tile(x, y))
	return unit


func _visualizer(unit: Unit) -> PathVisualizer:
	return unit._path_visualizer as PathVisualizer


# =============================================================================
# THE SETTING
# =============================================================================

func test_default_mode_is_walk_then_act() -> void:
	assert_eq(_mode_before, Settings.MoveCommitMode.WALK_THEN_ACT,
			"the shipped behavior stays the default — ACT_THEN_WALK is the playtest option")


func test_setter_clamps_to_the_enum() -> void:
	Settings.set_move_commit_mode(99)
	assert_eq(Settings.move_commit_mode, Settings.MoveCommitMode.ACT_THEN_WALK)
	Settings.set_move_commit_mode(-5)
	assert_eq(Settings.move_commit_mode, Settings.MoveCommitMode.WALK_THEN_ACT)


# =============================================================================
# WALK_THEN_ACT — the shipped behavior, pinned against regression
# =============================================================================

func test_walk_then_act_moves_sprite_and_logic_together() -> void:
	Settings.move_commit_mode = Settings.MoveCommitMode.WALK_THEN_ACT
	_open_grid(2)
	var unit := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var destination := GridManager.get_tile(2, 0)
	assert_true(unit.add_waypoint(destination), "precondition: the plan is legal")
	await unit.execute_planned_movement()
	assert_eq(unit.current_tile, destination)
	assert_lt(unit.global_position.distance_to(destination.global_position), 0.5,
			"the sprite walked")
	assert_false(unit.has_deferred_walk(), "nothing staged in the classic mode")


# =============================================================================
# ACT_THEN_WALK — stage
# =============================================================================

func test_staging_commits_logic_but_not_the_sprite() -> void:
	Settings.move_commit_mode = Settings.MoveCommitMode.ACT_THEN_WALK
	_open_grid(2)
	var unit := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var origin := GridManager.get_tile(0, 0)
	var destination := GridManager.get_tile(2, 0)
	var sprite_position_before: Vector2 = unit.global_position
	watch_signals(unit)
	assert_true(unit.add_waypoint(destination))
	await unit.execute_planned_movement()

	assert_eq(unit.current_tile, destination, "logic is at the destination")
	assert_eq(destination.current_unit, unit, "…and owns its tile")
	assert_null(origin.current_unit, "the origin tile is free — occupancy is logic")
	assert_lt(unit.global_position.distance_to(sprite_position_before), 0.5,
			"the sprite has not moved")
	assert_true(unit.has_deferred_walk(), "the walk is staged, not lost")
	assert_true(unit.planned_waypoints.is_empty(), "the plan is consumed")
	assert_signal_emitted(unit, "movement_completed",
			"auras/threat listeners recompute off logic positions — they must fire now")


func test_staging_hands_the_beacons_over_to_a_lone_ghost() -> void:
	Settings.move_commit_mode = Settings.MoveCommitMode.ACT_THEN_WALK
	_open_grid(2)
	var unit := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var destination := GridManager.get_tile(2, 0)
	var sprite := unit.get_node("Sprite2D") as Sprite2D
	var anchor: Vector2 = sprite.global_position - GridManager.get_tile(0, 0).global_position
	unit.add_waypoint(destination)
	await unit.execute_planned_movement()

	var visualizer := _visualizer(unit)
	assert_true(visualizer.has_destination_ghost(), "the ghost holds the spot")
	assert_true(visualizer._beacon_sprites.is_empty(), "the path is spent — beacons clear")
	assert_lt(visualizer._ghost.global_position.distance_to(
			destination.global_position + anchor), 0.5,
			"parked where the sprite will stand — anchored against the ORIGIN, "
			+ "measured before logic claimed the destination")


func test_staging_keeps_the_visual_row_z() -> void:
	Settings.move_commit_mode = Settings.MoveCommitMode.ACT_THEN_WALK
	_open_grid(0, 1)
	# Back row (higher grid_y) → front row: the rows have different z.
	var unit := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 1)
	var origin_z: int = unit.z_index
	unit.add_waypoint(GridManager.get_tile(0, 0))
	await unit.execute_planned_movement()
	assert_eq(unit.z_index, origin_z,
			"z follows the SPRITE's row, not current_tile — the sprite hasn't moved")
	await unit.play_deferred_walk()
	assert_ne(unit.z_index, origin_z, "…and restamps once the walk actually happens")


func test_act_then_walk_is_player_only() -> void:
	Settings.move_commit_mode = Settings.MoveCommitMode.ACT_THEN_WALK
	_open_grid(2)
	var enemy := _spawn_scene_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY, 0, 0)
	var destination := GridManager.get_tile(2, 0)
	assert_true(enemy.add_waypoint(destination))
	await enemy.execute_planned_movement()
	assert_false(enemy.has_deferred_walk(), "the AI's walk is its telegraph — never staged")
	assert_lt(enemy.global_position.distance_to(destination.global_position), 0.5,
			"the enemy walked immediately")


# =============================================================================
# ACT_THEN_WALK — commit and cancel
# =============================================================================

func test_play_deferred_walk_delivers_the_sprite_and_clears_the_stage() -> void:
	Settings.move_commit_mode = Settings.MoveCommitMode.ACT_THEN_WALK
	_open_grid(2)
	var unit := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var destination := GridManager.get_tile(2, 0)
	unit.add_waypoint(destination)
	await unit.execute_planned_movement()
	await unit.play_deferred_walk()

	assert_lt(unit.global_position.distance_to(destination.global_position), 0.5,
			"the sprite arrived")
	assert_false(unit.has_deferred_walk(), "the stage is spent")
	assert_false(unit.is_moving)
	assert_false(_visualizer(unit).has_destination_ghost(),
			"the ghost yields to the real sprite")
	await wait_process_frames(1)  # queue_free lands


func test_play_deferred_walk_is_a_no_op_when_nothing_is_staged() -> void:
	Settings.move_commit_mode = Settings.MoveCommitMode.WALK_THEN_ACT
	_open_grid(1)
	var unit := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var position_before: Vector2 = unit.global_position
	await unit.play_deferred_walk()
	assert_lt(unit.global_position.distance_to(position_before), 0.5,
			"safe to await unconditionally on every commit path")


func test_cancel_returns_logic_without_ever_having_moved_the_sprite() -> void:
	Settings.move_commit_mode = Settings.MoveCommitMode.ACT_THEN_WALK
	_open_grid(2)
	var unit := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var origin := GridManager.get_tile(0, 0)
	var destination := GridManager.get_tile(2, 0)
	var sprite_position_before: Vector2 = unit.global_position
	unit.add_waypoint(destination)
	await unit.execute_planned_movement()
	unit.cancel_movement()

	assert_eq(unit.current_tile, origin, "logic re-seats at the origin")
	assert_eq(origin.current_unit, unit)
	assert_null(destination.current_unit, "the destination is released")
	assert_lt(unit.global_position.distance_to(sprite_position_before), 0.5,
			"the honesty win: cancel never teleports — the sprite never moved")
	assert_false(unit.has_deferred_walk(), "the staged walk dies with the plan")
	assert_false(_visualizer(unit).has_destination_ghost(), "the ghost dies with it")


func test_set_acted_after_the_walk_lays_the_full_track() -> void:
	Settings.move_commit_mode = Settings.MoveCommitMode.ACT_THEN_WALK
	_open_grid(2)
	var unit := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	unit.add_waypoint(GridManager.get_tile(2, 0))
	await unit.execute_planned_movement()
	await unit.play_deferred_walk()
	watch_signals(unit)
	unit.set_acted()
	assert_signal_emitted(unit, "path_traversed",
			"the traversed tiles captured at stage time survive to the commit")


# =============================================================================
# HINT BAR COPY — the planning press must not promise movement it won't make
# =============================================================================

func test_planning_copy_swaps_under_act_then_walk() -> void:
	var state := Enums.InputState.MOVEMENT_PLANNING
	assert_eq(HintBarCommands.step_text_for(state, HintBarCommands.Model.KEYBOARD_MOUSE, false, true),
			"Select the marker again to confirm")
	assert_eq(HintBarCommands.step_text_for(state, HintBarCommands.Model.TOUCH, false, true),
			"Tap the marker again to confirm")
	assert_eq(HintBarCommands.confirm_label_for(state, false, true), "Confirm path")


func test_planning_copy_is_unchanged_in_walk_then_act() -> void:
	var state := Enums.InputState.MOVEMENT_PLANNING
	assert_eq(HintBarCommands.step_text_for(state, HintBarCommands.Model.KEYBOARD_MOUSE, false, false),
			"Select the marker again to move")
	assert_eq(HintBarCommands.confirm_label_for(state, false, false), "Move here")


func test_states_without_act_copy_ignore_the_flag() -> void:
	assert_eq(HintBarCommands.step_text_for(Enums.InputState.DEFAULT,
			HintBarCommands.Model.KEYBOARD_MOUSE, false, true),
			HintBarCommands.step_text_for(Enums.InputState.DEFAULT,
			HintBarCommands.Model.KEYBOARD_MOUSE, false, false))

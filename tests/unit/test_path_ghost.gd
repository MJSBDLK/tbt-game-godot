## PathVisualizer's destination ghost (RQD 2026-08-21, todo #4; ride upgrade
## RQD 2026-08-31): while a player unit has a move plan, a UnitGhost
## projection RIDES the planned path — origin to destination, hold, loop —
## and reduce-motion parks it at the landing state (ghost on the
## destination). Beacons stay the path either way; the trailing arrow is
## DISABLED (RIDE_ARROW_ENABLED), its math kept pinned. Pins WHAT spawns,
## where the ride starts and lands, the pure ride math, and the anchor/z/
## player-only/cleared-with-the-plan rules — the shader flicker and ride
## pacing are eyeball territory.
## Also pins that the extracted UnitGhost builder still feeds the displacement
## renderer the same silhouette (its own tests cover the arrows/loop).
extends GutTest


const UNIT_SCENE: String = "res://scenes/battle/unit.tscn"
const SPACEMAN_PATH: String = "res://data/characters/spaceman.json"
const GRUNT_PATH: String = "res://data/characters/grunt.json"

var _motion_before: bool = true


func before_each() -> void:
	GridManager.clear_grid()
	_motion_before = Settings.ui_motion_enabled
	Settings.ui_motion_enabled = true


func after_each() -> void:
	Settings.ui_motion_enabled = _motion_before


func after_all() -> void:
	GridManager.clear_grid()


func _grid_tile(x: int, y: int) -> void:
	var tile := Tile.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	tile.add_child(sprite)
	add_child_autofree(tile)
	# Real 16px spread: a zero-length board would make the ride degenerate
	# (coincident tiles → no trail) and every position assert vacuous.
	tile.position = Vector2(x * 16, y * 16)
	tile.grid_x = x
	tile.grid_y = y
	tile.terrain_type_name = "Plains"
	GridManager.register_tile(tile)


func _open_row(max_x: int) -> void:
	for x: int in range(max_x + 1):
		_grid_tile(x, 0)


func _spawn_scene_unit(json_path: String, faction: Enums.UnitFaction, x: int, y: int) -> Unit:
	var unit: Unit = (load(UNIT_SCENE) as PackedScene).instantiate() as Unit
	unit.character_json_path = json_path
	unit.faction = faction
	add_child_autofree(unit)
	unit.initialize(GridManager.get_tile(x, y))
	return unit


func _visualizer(unit: Unit) -> PathVisualizer:
	return unit._path_visualizer as PathVisualizer


func _ghost_count(visualizer: PathVisualizer) -> int:
	var count := 0
	for child: Node in visualizer.get_children():
		if child is Sprite2D and (child as Sprite2D).material is ShaderMaterial \
				and ((child as Sprite2D).material as ShaderMaterial).shader == UnitGhost.GHOST_SHADER:
			count += 1
	return count


# =============================================================================
# UNITGHOST BUILDER
# =============================================================================

func test_unit_ghost_clones_the_live_frame_and_wears_the_projection_shader() -> void:
	_open_row(1)
	var unit := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var material := UnitGhost.make_material()
	var ghost := UnitGhost.build(unit, material)
	assert_not_null(ghost, "a textured unit yields a ghost")
	autofree(ghost)
	var source := unit.get_node("Sprite2D") as Sprite2D
	assert_eq(ghost.texture, source.texture)
	assert_eq(ghost.frame, source.frame)
	assert_eq(ghost.offset, source.offset)
	assert_eq(ghost.material, material, "the owner's shared material")
	assert_eq(material.shader, UnitGhost.GHOST_SHADER)
	assert_almost_eq(float(material.get_shader_parameter("animate")), 1.0, 0.001, "motion on → animated")


func test_unit_ghost_needs_a_textured_sprite() -> void:
	var bare := Unit.new()
	autofree(bare)
	assert_null(UnitGhost.build(bare, UnitGhost.make_material()), "no Sprite2D, no ghost")
	assert_null(UnitGhost.build(null, UnitGhost.make_material()))
	assert_eq(UnitGhost.anchor_offset(bare), Vector2.ZERO)


func test_unit_ghost_material_follows_reduce_motion() -> void:
	Settings.ui_motion_enabled = false
	var material := UnitGhost.make_material()
	assert_almost_eq(float(material.get_shader_parameter("animate")), 0.0, 0.001, "made under reduce-motion: frozen")
	UnitGhost.set_animated(material, true)
	assert_almost_eq(float(material.get_shader_parameter("animate")), 1.0, 0.001)


# =============================================================================
# DESTINATION GHOST
# =============================================================================

func test_planning_a_move_starts_the_ghost_riding_from_the_origin() -> void:
	_open_row(3)
	var unit := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	assert_true(unit.add_waypoint(GridManager.get_tile(2, 0)), "precondition: the plan is legal")
	var visualizer := _visualizer(unit)
	assert_true(visualizer.has_destination_ghost(), "a plan has a ghost")
	assert_eq(_ghost_count(visualizer), 1, "exactly one")
	assert_false(visualizer._beacon_sprites.is_empty(), "the beacons still draw the path")
	assert_true(visualizer._walking, "motion on: the ghost rides the plan")
	var sprite := unit.get_node("Sprite2D") as Sprite2D
	assert_lt(visualizer._ghost.global_position.distance_to(sprite.global_position), 0.5,
			"the ride opens at the origin — where the sprite stands")


func test_the_ride_lands_on_the_last_waypoint() -> void:
	_open_row(3)
	var unit := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	unit.add_waypoint(GridManager.get_tile(2, 0))
	var visualizer := _visualizer(unit)
	visualizer._apply_walk_progress(visualizer._walk_total_px)  # deterministic landing
	var sprite := unit.get_node("Sprite2D") as Sprite2D
	var expected: Vector2 = GridManager.get_tile(2, 0).global_position \
			+ (sprite.global_position - GridManager.get_tile(0, 0).global_position)
	assert_lt(visualizer._ghost.global_position.distance_to(expected), 0.5,
			"lands on the destination, sprite anchor preserved")


func test_the_trailing_arrow_stays_disabled() -> void:
	# RQD 2026-08-31: the beacons already carry the path — the trail
	# double-marked it. Disabled (RIDE_ARROW_ENABLED), not deleted: the pure
	# ride math below stays pinned so a flip re-auditions cleanly.
	assert_false(PathVisualizer.RIDE_ARROW_ENABLED)
	_open_row(3)
	var unit := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	unit.add_waypoint(GridManager.get_tile(2, 0))
	var visualizer := _visualizer(unit)
	assert_true(visualizer._walking, "the ghost still rides")
	assert_null(visualizer._arrow_line, "…but draws no trail")
	assert_null(visualizer._arrow_head)


func test_reduce_motion_parks_at_the_landing_state() -> void:
	Settings.ui_motion_enabled = false
	_open_row(3)
	var unit := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	unit.add_waypoint(GridManager.get_tile(2, 0))
	var visualizer := _visualizer(unit)
	assert_false(visualizer._walking, "no ride under reduce-motion")
	var sprite := unit.get_node("Sprite2D") as Sprite2D
	var expected: Vector2 = GridManager.get_tile(2, 0).global_position \
			+ (sprite.global_position - GridManager.get_tile(0, 0).global_position)
	assert_lt(visualizer._ghost.global_position.distance_to(expected), 0.5,
			"parked on the destination — the pre-ride contract survives as the landing state")


func test_the_ghost_sits_above_the_whole_board() -> void:
	_open_row(2)
	var unit := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	unit.add_waypoint(GridManager.get_tile(1, 0))
	var ghost: Sprite2D = _visualizer(unit)._ghost
	assert_false(ghost.z_as_relative, "absolute z — the visualizer's own row-based z would bury it")
	assert_eq(ghost.z_index, DisplacementPreviewRenderer.OVERLAY_Z_INDEX,
			"same rule as the displacement ghosts: above the board max (998)")
	assert_gt(ghost.z_index, ZIndexCalculator.calculate_sorting_order(
			0, 100, ZIndexCalculator.ZIndexLayer.UNITS), "…including a front-row unit")


func test_extending_the_plan_restarts_the_ride_and_keeps_one_ghost() -> void:
	_open_row(3)
	var unit := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	unit.add_waypoint(GridManager.get_tile(1, 0))
	unit.add_waypoint(GridManager.get_tile(2, 0))
	await wait_process_frames(1)  # let the replaced ghost's queue_free land
	var visualizer := _visualizer(unit)
	assert_eq(_ghost_count(visualizer), 1, "the old ghost is freed, one remains")
	visualizer._apply_walk_progress(visualizer._walk_total_px)
	var sprite := unit.get_node("Sprite2D") as Sprite2D
	var expected: Vector2 = GridManager.get_tile(2, 0).global_position \
			+ (sprite.global_position - GridManager.get_tile(0, 0).global_position)
	assert_lt(visualizer._ghost.global_position.distance_to(expected), 0.5,
			"…and the ride now lands on the new last waypoint")


func test_clearing_the_plan_clears_the_ghost_and_the_trail() -> void:
	_open_row(2)
	var unit := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	unit.add_waypoint(GridManager.get_tile(1, 0))
	unit.clear_waypoints()
	var visualizer := _visualizer(unit)
	assert_false(visualizer.has_destination_ghost(), "no plan, no ghost")
	assert_null(visualizer._arrow_line, "no plan, no trail")
	assert_false(visualizer._walking)
	await wait_process_frames(1)
	assert_eq(_ghost_count(visualizer), 0)


# =============================================================================
# RIDE MATH — pure, pinned
# =============================================================================

func test_walk_sample_interpolates_and_clamps() -> void:
	var points := PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(16, 16)])
	assert_eq(PathVisualizer.walk_sample(points, 0.0).position as Vector2, Vector2(0, 0))
	assert_eq(PathVisualizer.walk_sample(points, 8.0).position as Vector2, Vector2(8, 0))
	assert_eq(int(PathVisualizer.walk_sample(points, 8.0).segment), 0)
	assert_eq(PathVisualizer.walk_sample(points, 24.0).position as Vector2, Vector2(16, 8))
	assert_eq(int(PathVisualizer.walk_sample(points, 24.0).segment), 1)
	assert_eq(PathVisualizer.walk_sample(points, 999.0).position as Vector2, Vector2(16, 16),
			"clamps at the destination")
	assert_eq(PathVisualizer.walk_sample(points, -5.0).position as Vector2, Vector2(0, 0),
			"clamps at the origin")
	assert_eq(PathVisualizer.path_length(points), 32.0)


func test_trail_points_end_at_the_rider() -> void:
	var points := PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(16, 16)])
	var trail := PathVisualizer.trail_points(points, 24.0)
	assert_eq(trail.size(), 3)
	assert_eq(trail[0], Vector2(0, 0))
	assert_eq(trail[1], Vector2(16, 0), "corners already passed stay in the trail")
	assert_eq(trail[2], Vector2(16, 8), "…and the tip is wherever the rider is")


func test_enemy_plans_keep_beacons_but_spawn_no_ghost() -> void:
	_open_row(2)
	var enemy := _spawn_scene_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY, 0, 0)
	assert_true(enemy.add_waypoint(GridManager.get_tile(1, 0)))
	var visualizer := _visualizer(enemy)
	assert_false(visualizer._beacon_sprites.is_empty(), "the AI's route still shows")
	assert_false(visualizer.has_destination_ghost(),
			"player-only: the AI's walk is already animated — the ghost is a planning aid")

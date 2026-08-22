## PathVisualizer's destination ghost (RQD 2026-08-21, todo #4): while a player
## unit has a move plan, a UnitGhost projection parks on the last waypoint.
## Beacons stay the path; the ghost is the destination. Pins WHAT spawns and
## WHERE it parks (sprite-space anchor, above-board z, player-only, cleared
## with the plan) — the shader flicker is eyeball territory. Also pins that the
## extracted UnitGhost builder still feeds the displacement renderer the same
## silhouette (its own tests cover the arrows/loop).
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

func test_planning_a_move_parks_a_ghost_on_the_last_waypoint() -> void:
	_open_row(3)
	var unit := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	assert_true(unit.add_waypoint(GridManager.get_tile(2, 0)), "precondition: the plan is legal")
	var visualizer := _visualizer(unit)
	assert_true(visualizer.has_destination_ghost(), "a plan has a ghost")
	assert_eq(_ghost_count(visualizer), 1, "exactly one")
	assert_false(visualizer._beacon_sprites.is_empty(), "the beacons still draw the path")
	var sprite := unit.get_node("Sprite2D") as Sprite2D
	var expected: Vector2 = GridManager.get_tile(2, 0).global_position \
			+ (sprite.global_position - GridManager.get_tile(0, 0).global_position)
	assert_lt(visualizer._ghost.global_position.distance_to(expected), 0.5,
			"parked on the destination, sprite anchor preserved")


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


func test_extending_the_plan_moves_the_ghost_and_keeps_one() -> void:
	_open_row(3)
	var unit := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	unit.add_waypoint(GridManager.get_tile(1, 0))
	unit.add_waypoint(GridManager.get_tile(2, 0))
	await wait_process_frames(1)  # let the replaced ghost's queue_free land
	var visualizer := _visualizer(unit)
	assert_eq(_ghost_count(visualizer), 1, "the old ghost is freed, one remains")
	var sprite := unit.get_node("Sprite2D") as Sprite2D
	var expected: Vector2 = GridManager.get_tile(2, 0).global_position \
			+ (sprite.global_position - GridManager.get_tile(0, 0).global_position)
	assert_lt(visualizer._ghost.global_position.distance_to(expected), 0.5, "…on the new last waypoint")


func test_clearing_the_plan_clears_the_ghost() -> void:
	_open_row(2)
	var unit := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	unit.add_waypoint(GridManager.get_tile(1, 0))
	unit.clear_waypoints()
	assert_false(_visualizer(unit).has_destination_ghost(), "no plan, no ghost")
	await wait_process_frames(1)
	assert_eq(_ghost_count(_visualizer(unit)), 0)


func test_enemy_plans_keep_beacons_but_spawn_no_ghost() -> void:
	_open_row(2)
	var enemy := _spawn_scene_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY, 0, 0)
	assert_true(enemy.add_waypoint(GridManager.get_tile(1, 0)))
	var visualizer := _visualizer(enemy)
	assert_false(visualizer._beacon_sprites.is_empty(), "the AI's route still shows")
	assert_false(visualizer.has_destination_ghost(),
			"player-only: the AI's walk is already animated — the ghost is a planning aid")

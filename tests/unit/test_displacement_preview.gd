## Displacement preview arc: the pure counter-fate query, collision cell
## records, and the DisplacementPreviewRenderer's ghost/arrow/mark spawning.
## Grid + bare units for the pure layer (protector-test style); real unit.tscn
## instances where ghosts need a Sprite2D to silhouette. The loop animation
## itself is eyeball territory — these tests pin WHAT gets spawned and WHERE
## ghosts park, not the tween choreography.
extends GutTest


const UNIT_SCENE: String = "res://scenes/battle/unit.tscn"
const SPACEMAN_PATH: String = "res://data/characters/spaceman.json"
const GRUNT_PATH: String = "res://data/characters/grunt.json"

var _motion_before: bool = true


func before_each() -> void:
	GridManager.clear_grid()
	_motion_before = Settings.ui_motion_enabled


func after_each() -> void:
	Settings.ui_motion_enabled = _motion_before


func after_all() -> void:
	GridManager.clear_grid()


# =============================================================================
# HELPERS
# =============================================================================

func _grid_tile(x: int, y: int, terrain: String = "Plains") -> void:
	var tile := Tile.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	tile.add_child(sprite)
	add_child_autofree(tile)
	tile.grid_x = x
	tile.grid_y = y
	tile.terrain_type_name = terrain
	GridManager.register_tile(tile)


func _open_grid(min_x: int, max_x: int, min_y: int, max_y: int) -> void:
	for x: int in range(min_x, max_x + 1):
		for y: int in range(min_y, max_y + 1):
			_grid_tile(x, y)


func _unit(label: String, constitution: int = 5) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.unit_name = label
	unit.current_hp = 20
	var data := CharacterData.new()
	data.constitution = constitution
	unit.character_data = data
	return unit


func _place(unit: Unit, x: int, y: int) -> void:
	var tile := GridManager.get_tile(x, y)
	unit.current_tile = tile
	tile.current_unit = unit


func _displace_move(distance: int, vector: String = "away_from_attacker",
		subject: String = "target", on_blocked: String = "stop") -> Move:
	var move := Move.new()
	move.move_name = "Preview Probe"
	move.base_power = 3
	move.displace_distance = distance
	move.displace_vector = vector
	move.displace_subject = subject
	move.displace_on_blocked = on_blocked
	return move


func _counter_move(range_value: int) -> Move:
	var move := Move.new()
	move.move_name = "Counter Probe"
	move.base_power = 3
	move.damage_type = Enums.DamageType.PHYSICAL
	move.attack_range = range_value
	move.max_uses = 5
	move.current_uses = 5
	return move


func _spawn_scene_unit(json_path: String, faction: Enums.UnitFaction,
		x: int, y: int) -> Unit:
	var unit: Unit = (load(UNIT_SCENE) as PackedScene).instantiate() as Unit
	unit.character_json_path = json_path
	unit.faction = faction
	add_child_autofree(unit)
	unit.initialize(GridManager.get_tile(x, y))
	return unit


func _make_renderer() -> DisplacementPreviewRenderer:
	var renderer := DisplacementPreviewRenderer.new()
	add_child_autofree(renderer)
	return renderer


func _count_children(renderer: Node, type: Variant) -> int:
	var count := 0
	for child: Node in renderer.get_children():
		if is_instance_of(child, type):
			count += 1
	return count


# =============================================================================
# COUNTER-FATE QUERY (pure)
# =============================================================================

func test_counter_denied_when_shoved_past_counter_range() -> void:
	_open_grid(0, 6, 0, 0)
	var attacker := _unit("attacker")
	var defender := _unit("defender")
	_place(attacker, 1, 0)
	_place(defender, 2, 0)
	defender.assigned_move = _counter_move(1)
	assert_false(
		DisplacementSystem.counter_survives_displacement(attacker, defender, _displace_move(2)),
		"knocked to distance 3 with a range-1 counter — denied")


func test_counter_survives_when_still_in_reach() -> void:
	_open_grid(0, 6, 0, 0)
	var attacker := _unit("attacker")
	var defender := _unit("defender")
	_place(attacker, 1, 0)
	_place(defender, 2, 0)
	defender.assigned_move = _counter_move(2)
	assert_true(
		DisplacementSystem.counter_survives_displacement(attacker, defender, _displace_move(1)),
		"distance 2 is inside the range-2 counter — the narrow rule holds in preview too")


func test_counter_survives_a_resisted_shove() -> void:
	_open_grid(0, 6, 0, 0)
	var attacker := _unit("attacker", 5)
	var defender := _unit("defender", 9)
	_place(attacker, 1, 0)
	_place(defender, 2, 0)
	defender.assigned_move = _counter_move(1)
	var move := _displace_move(2)
	move.displace_contest_stat = "constitution"
	assert_true(DisplacementSystem.counter_survives_displacement(attacker, defender, move),
		"the shove is resisted — nobody moves, the counter stands")


func test_counter_query_trivially_true_without_displacement_or_counter() -> void:
	_open_grid(0, 4, 0, 0)
	var attacker := _unit("attacker")
	var defender := _unit("defender")
	_place(attacker, 1, 0)
	_place(defender, 2, 0)
	var plain := Move.new()
	plain.base_power = 3
	assert_true(DisplacementSystem.counter_survives_displacement(attacker, defender, plain),
		"no displacement, nothing to deny")
	defender.assigned_move = null
	assert_true(DisplacementSystem.counter_survives_displacement(attacker, defender, _displace_move(2)),
		"no counter move — can_counter_attack owns that case, not this query")


func test_recoil_denies_the_counter_from_the_other_side() -> void:
	# Compressed Air's shoot-and-scoot: the ATTACKER recoils out of a range-1
	# counter's reach. Relative distance is what the rule measures.
	_open_grid(0, 6, 0, 0)
	var attacker := _unit("attacker")
	var defender := _unit("defender")
	_place(attacker, 2, 0)
	_place(defender, 3, 0)
	defender.assigned_move = _counter_move(1)
	var recoil := _displace_move(1, "away_from_target", "self")
	assert_false(DisplacementSystem.counter_survives_displacement(attacker, defender, recoil),
		"the attacker stepped back — the range-1 counter can no longer reach")


func test_pull_grants_the_counter_it_reels_into_range() -> void:
	# The mirror of the denial rule (RQD 2026-08-03): a defender out of counter
	# range at planning gets reeled to distance 1 — execution re-checks range
	# before every counter, so the grant query lets the preview predict the
	# retaliation instead of promising a free hit.
	_open_grid(0, 6, 0, 0)
	var attacker := _unit("attacker")
	var defender := _unit("defender")
	_place(attacker, 0, 0)
	_place(defender, 3, 0)
	defender.assigned_move = _counter_move(1)
	assert_true(DisplacementSystem.counter_granted_by_displacement(
			attacker, defender, _displace_move(2, "toward_attacker")),
		"reeled from distance 3 to 1 — the range-1 counter reaches now")


func test_pull_that_leaves_the_defender_short_grants_nothing() -> void:
	_open_grid(0, 8, 0, 0)
	var attacker := _unit("attacker")
	var defender := _unit("defender")
	_place(attacker, 0, 0)
	_place(defender, 5, 0)
	defender.assigned_move = _counter_move(1)
	assert_false(DisplacementSystem.counter_granted_by_displacement(
			attacker, defender, _displace_move(2, "toward_attacker")),
		"distance 5 pulled to 3 — still outside the range-1 counter")


func test_grant_query_trivially_false_without_displacement_or_counter() -> void:
	_open_grid(0, 4, 0, 0)
	var attacker := _unit("attacker")
	var defender := _unit("defender")
	_place(attacker, 0, 0)
	_place(defender, 3, 0)
	defender.assigned_move = _counter_move(1)
	var plain := Move.new()
	plain.base_power = 3
	assert_false(DisplacementSystem.counter_granted_by_displacement(attacker, defender, plain),
		"no displacement, nothing granted")
	defender.assigned_move = null
	assert_false(DisplacementSystem.counter_granted_by_displacement(
			attacker, defender, _displace_move(2, "toward_attacker")),
		"no counter move — nothing to grant")


func test_resisted_pull_grants_nothing() -> void:
	_open_grid(0, 6, 0, 0)
	var attacker := _unit("attacker", 5)
	var defender := _unit("defender", 9)
	_place(attacker, 0, 0)
	_place(defender, 3, 0)
	defender.assigned_move = _counter_move(1)
	var pull := _displace_move(2, "toward_attacker")
	pull.displace_contest_stat = "constitution"
	assert_false(DisplacementSystem.counter_granted_by_displacement(attacker, defender, pull),
		"the pull is resisted — nobody moves, no counter appears")


# =============================================================================
# COLLISION RECORDS CARRY THEIR CELLS
# =============================================================================

func test_collision_records_place_the_impact() -> void:
	_open_grid(0, 3, 0, 0)
	_grid_tile(4, 0, "Wall")
	var attacker := _unit("attacker")
	var defender := _unit("defender")
	var obstacle := _unit("obstacle")
	_place(attacker, 0, 0)
	_place(defender, 1, 0)
	_place(obstacle, 3, 0)
	var plan := DisplacementSystem.build_plan(attacker, defender,
			_displace_move(2, "away_from_attacker", "target", "bonus_damage"))
	assert_eq(plan.collisions.size(), 2)
	for collision: Dictionary in plan.collisions:
		if collision.unit == defender:
			assert_eq(collision.cell, Vector2i(2, 0), "subject's impact at its landing cell")
		else:
			assert_eq(collision.cell, Vector2i(3, 0), "obstacle's impact at its own cell")


# =============================================================================
# RENDERER — what gets spawned, where ghosts park
# =============================================================================

func test_preview_spawns_ghost_and_arrow_for_a_knockback() -> void:
	_open_grid(0, 5, 0, 0)
	var attacker := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var target := _spawn_scene_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	var renderer := _make_renderer()
	renderer.show_preview(attacker, target, _displace_move(2))
	assert_true(renderer.has_preview(), "a displacing move previews")
	assert_eq(_count_children(renderer, Sprite2D), 1, "one ghost for the one mover")
	assert_eq(_count_children(renderer, Line2D), 1, "a straight arrow shaft")
	assert_eq(_count_children(renderer, Polygon2D), 1, "one arrowhead")
	renderer.clear()
	assert_false(renderer.has_preview(), "clear() empties the board")


func test_reduce_motion_parks_the_ghost_at_its_destination() -> void:
	Settings.ui_motion_enabled = false
	_open_grid(0, 5, 0, 0)
	var attacker := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var target := _spawn_scene_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	var renderer := _make_renderer()
	renderer.show_preview(attacker, target, _displace_move(2))
	var ghost: Sprite2D = null
	for child: Node in renderer.get_children():
		if child is Sprite2D:
			ghost = child
	assert_not_null(ghost, "ghost spawned")
	if ghost != null:
		var sprite := target.get_node("Sprite2D") as Sprite2D
		var expected: Vector2 = sprite.global_position \
				+ (GridManager.get_tile(3, 0).global_position - GridManager.get_tile(1, 0).global_position)
		assert_lt(ghost.global_position.distance_to(expected), 0.5,
			"reduce-motion: ghost parks at the destination, sprite anchor preserved")


func test_resisted_shove_draws_braces_not_ghosts() -> void:
	_open_grid(0, 5, 0, 0)
	var attacker := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var target := _spawn_scene_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	attacker.character_data.constitution = 1
	target.character_data.constitution = 9
	var move := _displace_move(2)
	move.displace_contest_stat = "constitution"
	var renderer := _make_renderer()
	renderer.show_preview(attacker, target, move)
	assert_eq(_count_children(renderer, Sprite2D), 0, "a resisted subject casts no ghost")
	assert_eq(_count_children(renderer, Line2D), 2, "the stands-firm brace is two bars")


func test_wall_slam_previews_the_star_and_the_damage() -> void:
	_grid_tile(0, 0)
	_grid_tile(1, 0)
	_grid_tile(2, 0, "Wall")
	var attacker := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var target := _spawn_scene_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	var renderer := _make_renderer()
	renderer.show_preview(attacker, target,
			_displace_move(2, "away_from_attacker", "target", "bonus_damage"))
	assert_eq(_count_children(renderer, Polygon2D), 1, "impact star (no movement = no arrowhead)")
	var label: Label = null
	for child: Node in renderer.get_children():
		if child is Label:
			label = child
	assert_not_null(label, "slam damage label spawned")
	if label != null:
		assert_eq(label.text, "-%d" % (DisplacementSystem.COLLISION_DAMAGE_PER_TILE * 2),
			"previews the full untraveled-distance slam")


func test_non_displacing_move_previews_nothing() -> void:
	_open_grid(0, 4, 0, 0)
	var attacker := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var target := _spawn_scene_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	var renderer := _make_renderer()
	var plain := Move.new()
	plain.base_power = 3
	renderer.show_preview(attacker, target, plain)
	assert_false(renderer.has_preview(), "no displacement, no ghosts")

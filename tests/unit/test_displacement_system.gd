## Phase 3 displacement — the generalized shove engine. Most tests drive the
## PURE layer (DisplacementSystem.build_plan → DisplacePlan) on a real
## GridManager grid with bare out-of-tree Units, protector-test style: vectors,
## shapes, the constitution contest, and every on_blocked policy. A small
## integration tail uses real unit.tscn instances to pin the execution half
## (parallel animation → batch occupancy commit) and the tactical payoff:
## knockback denies the counter.
extends GutTest


const UNIT_SCENE: String = "res://scenes/battle/unit.tscn"
const SPACEMAN_PATH: String = "res://data/characters/spaceman.json"
const GRUNT_PATH: String = "res://data/characters/grunt.json"


func before_each() -> void:
	GridManager.clear_grid()


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


func _unit(label: String, constitution: int = 5, hp: int = 20) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.unit_name = label
	unit.current_hp = hp
	var data := CharacterData.new()
	data.constitution = constitution
	unit.character_data = data
	return unit


func _place(unit: Unit, x: int, y: int) -> void:
	var tile := GridManager.get_tile(x, y)
	unit.current_tile = tile
	tile.current_unit = unit


func _displace_move(distance: int, vector: String = "away_from_attacker",
		subject: String = "target", shape: String = "single",
		on_blocked: String = "stop") -> Move:
	var move := Move.new()
	move.move_name = "Test Shove"
	move.displace_distance = distance
	move.displace_vector = vector
	move.displace_subject = subject
	move.displace_shape = shape
	move.displace_on_blocked = on_blocked
	return move


func _final_cell(plan: DisplacementSystem.DisplacePlan, unit: Unit) -> Vector2i:
	var mover: Dictionary = plan.mover_for(unit)
	if mover.is_empty():
		return Vector2i(-999, -999)
	var tile: Tile = (mover.path as Array[Tile]).back()
	return Vector2i(tile.grid_x, tile.grid_y)


# =============================================================================
# VECTORS + BASIC WALKS
# =============================================================================

func test_push_away_walks_the_full_distance() -> void:
	_open_grid(0, 6, 0, 2)
	var caster := _unit("caster")
	var target := _unit("target")
	_place(caster, 1, 1)
	_place(target, 2, 1)
	var plan := DisplacementSystem.build_plan(caster, target, _displace_move(2))
	assert_eq(_final_cell(plan, target), Vector2i(4, 1), "pushed 2 east, away from the caster")
	assert_eq((plan.mover_for(target).path as Array[Tile]).size(), 2, "one tile per step")


func test_diagonal_push_uses_dominant_axis_and_ties_break_to_x() -> void:
	_open_grid(0, 6, 0, 6)
	var caster := _unit("caster")
	var dominant_y := _unit("dominant_y")
	_place(caster, 3, 3)
	_place(dominant_y, 4, 5)  # dy 2 beats dx 1 → push north
	var plan := DisplacementSystem.build_plan(caster, dominant_y, _displace_move(1))
	assert_eq(_final_cell(plan, dominant_y), Vector2i(4, 6), "dominant Y axis wins")

	GridManager.clear_grid()
	_open_grid(0, 6, 0, 6)
	var caster_2 := _unit("caster2")
	var tied := _unit("tied")
	_place(caster_2, 3, 3)
	_place(tied, 4, 4)  # perfect diagonal → tie breaks to X
	var plan_2 := DisplacementSystem.build_plan(caster_2, tied, _displace_move(1))
	assert_eq(_final_cell(plan_2, tied), Vector2i(5, 4), "diagonal tie breaks to the X axis")


func test_pull_toward_attacker_stops_before_the_attacker() -> void:
	_open_grid(0, 6, 0, 2)
	var caster := _unit("caster")
	var target := _unit("target")
	_place(caster, 1, 1)
	_place(target, 5, 1)
	var plan := DisplacementSystem.build_plan(caster, target, _displace_move(4, "toward_attacker"))
	assert_eq(_final_cell(plan, target), Vector2i(2, 1),
		"pulled adjacent — the caster's own tile blocks the last step")


func test_wall_and_map_edge_stop_a_push() -> void:
	_open_grid(0, 3, 0, 0)
	_grid_tile(4, 0, "Wall")
	var caster := _unit("caster")
	var into_wall := _unit("into_wall")
	_place(caster, 1, 0)
	_place(into_wall, 2, 0)
	var plan := DisplacementSystem.build_plan(caster, into_wall, _displace_move(3))
	assert_eq(_final_cell(plan, into_wall), Vector2i(3, 0), "stops short of the Wall tile")

	GridManager.clear_grid()
	_open_grid(0, 3, 0, 0)
	var caster_2 := _unit("caster2")
	var into_edge := _unit("into_edge")
	_place(caster_2, 1, 0)
	_place(into_edge, 2, 0)
	var plan_2 := DisplacementSystem.build_plan(caster_2, into_edge, _displace_move(5))
	assert_eq(_final_cell(plan_2, into_edge), Vector2i(3, 0), "map edge stops the shove")


# =============================================================================
# SAVE CONTEST
# =============================================================================

func test_contest_is_strictly_greater_than_margin() -> void:
	_open_grid(0, 5, 0, 0)
	var caster := _unit("caster", 7)
	var target := _unit("target", 5)
	_place(caster, 0, 0)
	_place(target, 1, 0)
	var move := _displace_move(1)
	move.displace_contest_stat = "constitution"
	move.displace_contest_margin = 1
	var plan := DisplacementSystem.build_plan(caster, target, move)
	assert_eq(_final_cell(plan, target), Vector2i(2, 0), "7 − 5 = 2 > margin 1 → displaced")

	move.displace_contest_margin = 2
	var held := DisplacementSystem.build_plan(caster, target, move)
	assert_true(held.mover_for(target).is_empty(), "2 > 2 is false → the shove is resisted")
	assert_true(held.resisted.has(target), "resisted subjects are reported for feedback")


func test_no_save_key_always_displaces() -> void:
	_open_grid(0, 3, 0, 0)
	var caster := _unit("caster", 1)
	var target := _unit("target", 99)
	_place(caster, 0, 0)
	_place(target, 1, 0)
	var plan := DisplacementSystem.build_plan(caster, target, _displace_move(1))
	assert_eq(_final_cell(plan, target), Vector2i(2, 0),
		"no contest stat set — even a boulder gets moved")


func test_unknown_contest_stat_refuses_to_displace() -> void:
	_open_grid(0, 3, 0, 0)
	var caster := _unit("caster")
	var target := _unit("target")
	_place(caster, 0, 0)
	_place(target, 1, 0)
	var move := _displace_move(1)
	move.displace_contest_stat = "charisma"
	var plan := DisplacementSystem.build_plan(caster, target, move)
	assert_true(plan.mover_for(target).is_empty(), "typo'd stat fails safe: no displacement")


# =============================================================================
# SUBJECT: SELF (recoil)
# =============================================================================

func test_self_recoil_moves_the_caster_away_from_the_target() -> void:
	_open_grid(0, 4, 0, 0)
	var caster := _unit("caster", 1)
	var target := _unit("target", 99)
	_place(caster, 2, 0)
	_place(target, 3, 0)
	var move := _displace_move(1, "away_from_target", "self")
	# A contest the caster would badly lose — self-displacement skips it.
	move.displace_contest_stat = "constitution"
	var plan := DisplacementSystem.build_plan(caster, target, move)
	assert_eq(_final_cell(plan, caster), Vector2i(1, 0), "recoil kicks the caster back west")
	assert_true(plan.mover_for(target).is_empty(), "the target holds still")


# =============================================================================
# ON_BLOCKED POLICIES
# =============================================================================

func test_swap_trades_places_with_the_unit_behind() -> void:
	_open_grid(0, 4, 0, 0)
	var caster := _unit("caster")
	var target := _unit("target", 99)
	var ally := _unit("ally")
	_place(caster, 2, 0)
	_place(target, 3, 0)
	_place(ally, 1, 0)
	var move := _displace_move(1, "away_from_target", "self", "single", "swap")
	var plan := DisplacementSystem.build_plan(caster, target, move)
	assert_eq(_final_cell(plan, caster), Vector2i(1, 0), "caster takes the ally's tile")
	assert_eq(_final_cell(plan, ally), Vector2i(2, 0), "ally lands where the caster stood")
	assert_eq(int(plan.mover_for(ally).start_step), 0, "swap partners cross on the same beat")


func test_bonus_damage_wall_slam_hurts_only_the_subject() -> void:
	_grid_tile(0, 0)
	_grid_tile(1, 0)
	_grid_tile(2, 0, "Wall")
	var caster := _unit("caster")
	var target := _unit("target")
	_place(caster, 0, 0)
	_place(target, 1, 0)
	var plan := DisplacementSystem.build_plan(caster, target,
			_displace_move(2, "away_from_attacker", "target", "single", "bonus_damage"))
	assert_true(plan.mover_for(target).is_empty(), "slammed straight into the wall — no movement")
	assert_eq(plan.collisions.size(), 1, "one collision record")
	assert_eq(plan.collisions[0].unit, target)
	assert_eq(int(plan.collisions[0].damage), DisplacementSystem.COLLISION_DAMAGE_PER_TILE * 2,
		"full untraveled distance scales the slam")


func test_bonus_damage_unit_collision_hurts_both() -> void:
	_open_grid(0, 4, 0, 0)
	var caster := _unit("caster")
	var target := _unit("target")
	var obstacle := _unit("obstacle")
	_place(caster, 0, 0)
	_place(target, 1, 0)
	_place(obstacle, 3, 0)
	var plan := DisplacementSystem.build_plan(caster, target,
			_displace_move(2, "away_from_attacker", "target", "single", "bonus_damage"))
	assert_eq(_final_cell(plan, target), Vector2i(2, 0), "one step traveled before impact")
	assert_eq(plan.collisions.size(), 2, "thrown unit AND the one it hit")
	for collision: Dictionary in plan.collisions:
		assert_eq(int(collision.damage), DisplacementSystem.COLLISION_DAMAGE_PER_TILE,
			"one untraveled tile → one tile's worth of hurt for %s" % collision.unit.unit_name)


func test_fall_through_sails_over_a_unit() -> void:
	_open_grid(0, 4, 0, 0)
	var caster := _unit("caster")
	var target := _unit("target")
	var bystander := _unit("bystander")
	_place(caster, 0, 0)
	_place(target, 1, 0)
	_place(bystander, 2, 0)
	var plan := DisplacementSystem.build_plan(caster, target,
			_displace_move(2, "away_from_attacker", "target", "single", "fall_through"))
	assert_eq(_final_cell(plan, target), Vector2i(3, 0),
		"flies over the bystander and lands beyond")
	assert_eq((plan.mover_for(target).path as Array[Tile]).size(), 2,
		"the overflown cell still costs a step (and animates through)")


func test_fall_through_backs_up_when_distance_ends_over_a_unit() -> void:
	_open_grid(0, 4, 0, 0)
	var caster := _unit("caster")
	var target := _unit("target")
	var bystander := _unit("bystander")
	_place(caster, 0, 0)
	_place(target, 1, 0)
	_place(bystander, 2, 0)
	var plan := DisplacementSystem.build_plan(caster, target,
			_displace_move(1, "away_from_attacker", "target", "single", "fall_through"))
	assert_true(plan.mover_for(target).is_empty(),
		"distance 1 ends mid-air over the bystander — backs up to the start, no move")


func test_push_chain_shoves_the_train_along() -> void:
	_open_grid(0, 5, 0, 0)
	var caster := _unit("caster")
	var target := _unit("target")
	var chained := _unit("chained")
	_place(caster, 0, 0)
	_place(target, 1, 0)
	_place(chained, 2, 0)
	var plan := DisplacementSystem.build_plan(caster, target,
			_displace_move(2, "away_from_attacker", "target", "single", "push_chain"))
	assert_eq(_final_cell(plan, target), Vector2i(3, 0), "subject rides the full distance")
	assert_eq(_final_cell(plan, chained), Vector2i(4, 0), "the blocker is dominoed ahead")
	assert_eq(int(plan.mover_for(chained).start_step), 0,
		"contact on step one — the train moves from the first beat")


func test_push_chain_jams_when_the_front_hits_a_wall() -> void:
	_open_grid(0, 3, 0, 0)
	_grid_tile(4, 0, "Wall")
	var caster := _unit("caster")
	var target := _unit("target")
	var chained := _unit("chained")
	_place(caster, 0, 0)
	_place(target, 1, 0)
	_place(chained, 2, 0)
	var plan := DisplacementSystem.build_plan(caster, target,
			_displace_move(3, "away_from_attacker", "target", "single", "push_chain"))
	assert_eq(_final_cell(plan, target), Vector2i(2, 0), "one step, then the train jams")
	assert_eq(_final_cell(plan, chained), Vector2i(3, 0), "front car stops at the wall")


# =============================================================================
# SHAPES + MULTI-SUBJECT
# =============================================================================

func test_row_shape_pushes_three_abreast() -> void:
	_open_grid(0, 5, 0, 4)
	var caster := _unit("caster")
	var target := _unit("target")
	var north_neighbor := _unit("north")
	var south_neighbor := _unit("south")
	_place(caster, 1, 2)
	_place(target, 3, 2)
	_place(north_neighbor, 3, 3)
	_place(south_neighbor, 3, 1)
	var plan := DisplacementSystem.build_plan(caster, target,
			_displace_move(1, "away_from_attacker", "others_in_shape", "row(3)"))
	assert_eq(_final_cell(plan, target), Vector2i(4, 2), "epicenter unit pushed east")
	assert_eq(_final_cell(plan, north_neighbor), Vector2i(4, 3), "row-mate above pushed east")
	assert_eq(_final_cell(plan, south_neighbor), Vector2i(4, 1), "row-mate below pushed east")


func test_push_wave_resolves_front_most_first_regardless_of_order() -> void:
	# line(2) enumerates the epicenter FIRST — the rear unit would walk into the
	# front unit if resolution were naive. Deferral lets the front unit vacate.
	_open_grid(0, 6, 0, 0)
	var caster := _unit("caster")
	var rear := _unit("rear")
	var front := _unit("front")
	_place(caster, 0, 0)
	_place(rear, 1, 0)
	_place(front, 2, 0)
	var plan := DisplacementSystem.build_plan(caster, rear,
			_displace_move(2, "away_from_attacker", "others_in_shape", "line(2)"))
	assert_eq(_final_cell(plan, front), Vector2i(4, 0), "front unit clears out first")
	assert_eq(_final_cell(plan, rear), Vector2i(3, 0), "rear unit slides into the vacated lane")


func test_ring_shape_gathers_the_perimeter_only() -> void:
	_open_grid(0, 6, 0, 6)
	var caster := _unit("caster")
	var target := _unit("target")
	var on_ring := _unit("on_ring")
	var outside := _unit("outside")
	_place(caster, 3, 1)   # adjacent to the epicenter — on the ring, but exempt
	_place(target, 3, 2)   # epicenter: Chebyshev 0, NOT on ring(1)
	_place(on_ring, 4, 3)  # diagonal neighbor — Chebyshev 1
	_place(outside, 3, 4)  # Chebyshev 2 — beyond the ring
	var plan := DisplacementSystem.build_plan(caster, target,
			_displace_move(1, "away_from_point", "others_in_shape", "ring(1)"))
	assert_false(plan.mover_for(on_ring).is_empty(), "ring cell occupant is blasted")
	assert_eq(_final_cell(plan, on_ring), Vector2i(5, 3),
		"radial blast: diagonal offset's tie breaks to X → pushed east")
	assert_true(plan.mover_for(target).is_empty(), "the epicenter unit is not on the ring")
	assert_true(plan.mover_for(outside).is_empty(), "Chebyshev 2 is outside ring(1)")
	assert_true(plan.mover_for(caster).is_empty(), "the caster never displaces itself via shape")


# =============================================================================
# ROTATION
# =============================================================================

func test_rotate_cw_walks_the_ring_clockwise() -> void:
	_open_grid(0, 6, 0, 6)
	var caster := _unit("caster")
	var target := _unit("target")
	var spun := _unit("spun")
	_place(caster, 1, 3)
	_place(target, 3, 3)
	_place(spun, 3, 4)  # due north of the epicenter
	var plan := DisplacementSystem.build_plan(caster, target,
			_displace_move(1, "rotate_cw", "others_in_shape", "ring(1)"))
	assert_eq(_final_cell(plan, spun), Vector2i(4, 4),
		"north cell heads east along the ring (Y-up clockwise)")


func test_rotate_ccw_walks_the_other_way() -> void:
	_open_grid(0, 6, 0, 6)
	var caster := _unit("caster")
	var target := _unit("target")
	var spun := _unit("spun")
	_place(caster, 1, 3)
	_place(target, 3, 3)
	_place(spun, 3, 4)
	var plan := DisplacementSystem.build_plan(caster, target,
			_displace_move(1, "rotate_ccw", "others_in_shape", "ring(1)"))
	assert_eq(_final_cell(plan, spun), Vector2i(2, 4), "counter-clockwise heads west")


func test_rotate_multi_step_turns_the_corner() -> void:
	_open_grid(0, 6, 0, 6)
	var caster := _unit("caster")
	var target := _unit("target")
	var spun := _unit("spun")
	_place(caster, 1, 3)
	_place(target, 3, 3)
	_place(spun, 3, 4)
	var plan := DisplacementSystem.build_plan(caster, target,
			_displace_move(2, "rotate_cw", "others_in_shape", "ring(1)"))
	assert_eq(_final_cell(plan, spun), Vector2i(4, 3),
		"two perimeter steps: north → NE corner → east")


func test_rotation_train_moves_simultaneously() -> void:
	# Two adjacent ring units rotate as a train — the leader vacates the cell
	# the follower needs on the SAME step.
	_open_grid(0, 6, 0, 6)
	var caster := _unit("caster")
	var target := _unit("target")
	var leader := _unit("leader")
	var follower := _unit("follower")
	_place(caster, 1, 3)
	_place(target, 3, 3)
	_place(leader, 4, 4)    # NE corner
	_place(follower, 3, 4)  # north — wants the corner
	var plan := DisplacementSystem.build_plan(caster, target,
			_displace_move(1, "rotate_cw", "others_in_shape", "ring(1)"))
	assert_eq(_final_cell(plan, leader), Vector2i(4, 3), "leader turns the corner")
	assert_eq(_final_cell(plan, follower), Vector2i(4, 4), "follower takes the vacated corner")


func test_rotation_jams_behind_a_bystander() -> void:
	_open_grid(0, 6, 0, 6)
	var caster := _unit("caster")
	var target := _unit("target")
	var spun := _unit("spun")
	var bystander := _unit("bystander", 5, 20)
	_place(caster, 1, 3)
	_place(target, 3, 3)
	_place(spun, 3, 4)
	_place(bystander, 4, 4)  # sits on the next ring cell, NOT a subject... but it IS on the ring
	# Restrict the shape to a cell set that catches only `spun`: use ring(1) and
	# make the bystander a non-subject by parking it OFF the ring is impossible
	# here — instead give the move a contest the bystander wins.
	var move := _displace_move(1, "rotate_cw", "others_in_shape", "ring(1)")
	move.displace_contest_stat = "constitution"
	move.displace_contest_margin = 0
	caster.character_data.constitution = 6  # beats spun's 5, loses to bystander's 9
	bystander.character_data.constitution = 9
	var plan := DisplacementSystem.build_plan(caster, target, move)
	assert_true(plan.mover_for(bystander).is_empty(), "bystander resisted the spin")
	assert_true(plan.mover_for(spun).is_empty(),
		"the resister blocks the ring — the spun unit jams behind it")


# =============================================================================
# JSON PARSING
# =============================================================================

func test_move_data_parses_the_displace_schema() -> void:
	var move := MoveData._parse_move_entry("Schema Probe", {
		"basePower": 3,
		"onHit": {
			"displace": {
				"subject": "others_in_shape",
				"shape": "row(3)",
				"vector": "toward_point",
				"distance": 2,
				"save": {"contest": "constitution", "margin": 1},
				"on_blocked": "push_chain",
			},
		},
	})
	assert_eq(move.displace_subject, "others_in_shape")
	assert_eq(move.displace_shape, "row(3)")
	assert_eq(move.displace_vector, "toward_point")
	assert_eq(move.displace_distance, 2)
	assert_eq(move.displace_contest_stat, "constitution")
	assert_eq(move.displace_contest_margin, 1)
	assert_eq(move.displace_on_blocked, "push_chain")


func test_move_data_save_defaults_to_constitution_margin_zero() -> void:
	var move := MoveData._parse_move_entry("Default Probe", {
		"onHit": {"displace": {"distance": 1, "save": {}}},
	})
	assert_eq(move.displace_contest_stat, "constitution",
		"a bare save block contests the universal resist stat")
	assert_eq(move.displace_contest_margin, 0)
	assert_eq(move.displace_subject, "target", "subject defaults to the struck unit")
	assert_eq(move.displace_on_blocked, "stop")


func test_authored_moves_carry_their_displacement() -> void:
	var bounce_out: Move = MoveData.get_move("Bounce Out")
	assert_not_null(bounce_out, "Bounce Out is in the bank")
	assert_eq(bounce_out.displace_distance, 2)
	assert_eq(bounce_out.displace_contest_stat, "constitution")
	assert_eq(bounce_out.displace_contest_margin, 1)
	assert_eq(bounce_out.displace_on_blocked, "bonus_damage")

	var compressed_air: Move = MoveData.get_move("Compressed Air")
	assert_eq(compressed_air.displace_subject, "self",
		"the recoil the flavor text always promised")
	assert_eq(compressed_air.displace_vector, "away_from_target")
	assert_eq(compressed_air.displace_distance, 1)


func test_debug_displacement_kit_resolves_and_covers_everything() -> void:
	# DebugConfig.testing_displacement_moves hands these out — a typo'd name or
	# a bank rename would silently shrink the kit. And the kit's whole job is
	# coverage: every subject and every on_blocked policy must be represented.
	var subjects := {}
	var policies := {}
	var rotations := 0
	for kit_name: String in Unit.DEBUG_DISPLACEMENT_KIT:
		var move: Move = MoveData.get_move(kit_name)
		assert_not_null(move, "kit move '%s' exists in the bank" % kit_name)
		if move == null:
			continue
		assert_gt(move.displace_distance, 0, "'%s' actually displaces" % kit_name)
		subjects[move.displace_subject] = true
		policies[move.displace_on_blocked] = true
		if move.displace_vector.begins_with("rotate_"):
			rotations += 1
	for subject: String in ["target", "self", "others_in_shape"]:
		assert_true(subjects.has(subject), "kit covers subject '%s'" % subject)
	for policy: String in ["stop", "swap", "bonus_damage", "fall_through", "push_chain"]:
		assert_true(policies.has(policy), "kit covers on_blocked '%s'" % policy)
	assert_gt(rotations, 0, "kit includes a rotation move")


# =============================================================================
# INTEGRATION — execution half (animation, commit) + combat wiring
# =============================================================================

func _spawn_scene_unit(json_path: String, faction: Enums.UnitFaction,
		x: int, y: int) -> Unit:
	var unit: Unit = (load(UNIT_SCENE) as PackedScene).instantiate() as Unit
	unit.character_json_path = json_path
	unit.faction = faction
	add_child_autofree(unit)
	unit.initialize(GridManager.get_tile(x, y))
	return unit


func test_resolve_animates_and_commits_occupancy() -> void:
	_open_grid(0, 5, 0, 0)
	var caster := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var target := _spawn_scene_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	await DisplacementSystem.resolve(caster, target, _displace_move(2))
	var landing := GridManager.get_tile(3, 0)
	assert_eq(target.current_tile, landing, "unit's tile pointer moved")
	assert_eq(landing.current_unit, target, "destination tile registers the unit")
	assert_null(GridManager.get_tile(1, 0).current_unit, "origin tile is vacated")
	assert_eq(target.global_position, landing.global_position, "sprite arrived too")


func test_resolve_commits_a_swap_without_clobbering() -> void:
	# The batch commit's reason to exist: sequential move_to_tile on a swap
	# wipes one unit's registration. Both tiles must end correctly owned.
	_open_grid(0, 3, 0, 0)
	var caster := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 1, 0)
	var target := _spawn_scene_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY, 2, 0)
	var ally := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	await DisplacementSystem.resolve(caster, target,
			_displace_move(1, "away_from_target", "self", "single", "swap"))
	assert_eq(caster.current_tile, GridManager.get_tile(0, 0), "caster took the ally's tile")
	assert_eq(ally.current_tile, GridManager.get_tile(1, 0), "ally took the caster's tile")
	assert_eq(GridManager.get_tile(0, 0).current_unit, caster)
	assert_eq(GridManager.get_tile(1, 0).current_unit, ally)


func test_knockback_denies_the_counter_and_refunds_nothing() -> void:
	# The tactical payoff: shove the defender out of range-1 counter reach and
	# the counter never happens — and never costs PP (paid at counter time now).
	_open_grid(0, 7, 0, 2)
	var attacker := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 2, 1)
	var defender := _spawn_scene_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY, 3, 1)
	# Deterministic single hits, guaranteed connect, nobody dies.
	attacker.character_data.agility = 5
	defender.character_data.agility = 5
	attacker.character_data.strength = 1
	defender.character_data.max_hp = 50
	defender.current_hp = 50
	var attacker_hp_before := attacker.current_hp

	var shove := _displace_move(2)
	shove.base_power = 1
	shove.accuracy = 500  # clamped to 100 — never miss
	shove.damage_type = Enums.DamageType.PHYSICAL
	shove.attack_range = 1
	shove.max_uses = 5
	shove.current_uses = 5

	var counter_move := Move.new()
	counter_move.move_name = "Counter Probe"
	counter_move.base_power = 5
	counter_move.damage_type = Enums.DamageType.PHYSICAL
	counter_move.attack_range = 1
	counter_move.max_uses = 5
	counter_move.current_uses = 5
	defender.assigned_move = counter_move

	await attacker.execute_combat_sequence(defender, shove)

	assert_eq(defender.current_tile, GridManager.get_tile(5, 1), "defender knocked 2 east")
	assert_eq(attacker.current_hp, attacker_hp_before,
		"no counter landed — the defender was out of reach when its turn came")
	assert_eq(counter_move.current_uses, counter_move.max_uses,
		"a counter that never fires costs no PP")


func test_callout_spawns_above_the_unit_not_at_host_origin() -> void:
	# Regression (RQD 2026-08-01 playtest): _host_popup positioned the popup
	# AFTER add_child, but DamagePopup._ready anchors its rise animation to
	# the position it wakes up with — so every damage number and callout
	# snapped to the host's origin (center screen in game).
	_open_grid(0, 3, 0, 0)
	var unit := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 2, 0)
	unit.spawn_text_callout("PROBE", Color.WHITE)
	var popup: DamagePopup = null
	for child: Node in unit.get_parent().get_children():
		if child is DamagePopup:
			popup = child
	assert_not_null(popup, "callout spawned into the fallback host")
	if popup != null:
		var expected: Vector2 = unit.global_position + Vector2(0, -20)
		assert_lt(popup.global_position.distance_to(expected), 1.0,
			"callout anchors above the unit, not at the host origin")
		popup.queue_free()


func test_knockback_within_counter_range_still_counters() -> void:
	# The denial rule is NARROW (RQD 2026-08-01): a counter is lost ONLY when
	# the defender's own selected move can no longer reach from the new
	# positions. A 1-tile shove against a range-2 counter changes nothing —
	# the counter fires and pays its PP.
	_open_grid(0, 7, 0, 2)
	var attacker := _spawn_scene_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 2, 1)
	var defender := _spawn_scene_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY, 3, 1)
	attacker.character_data.agility = 5
	defender.character_data.agility = 5
	attacker.character_data.strength = 1
	attacker.character_data.max_hp = 50
	attacker.current_hp = 50
	defender.character_data.max_hp = 50
	defender.current_hp = 50
	var attacker_hp_before := attacker.current_hp

	var shove := _displace_move(1)
	shove.base_power = 1
	shove.accuracy = 500  # clamped to 100 — never miss
	shove.damage_type = Enums.DamageType.PHYSICAL
	shove.attack_range = 1
	shove.max_uses = 5
	shove.current_uses = 5

	var counter_move := Move.new()
	counter_move.move_name = "Reach Counter"
	counter_move.base_power = 3
	counter_move.accuracy = 500
	counter_move.damage_type = Enums.DamageType.PHYSICAL
	counter_move.attack_range = 2
	counter_move.max_uses = 5
	counter_move.current_uses = 5
	defender.assigned_move = counter_move

	await attacker.execute_combat_sequence(defender, shove)

	assert_eq(defender.current_tile, GridManager.get_tile(4, 1), "defender knocked 1 east")
	assert_lt(attacker.current_hp, attacker_hp_before,
		"distance 2 is still inside the range-2 counter — it fires")
	assert_eq(counter_move.current_uses, counter_move.max_uses - 1,
		"a counter that fires pays its PP")

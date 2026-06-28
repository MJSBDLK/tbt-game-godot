## Phase: threat-overlay model. ThreatCalculator computes the danger zone (move +
## attack) for any unit list as pure data. Integration tests build a real
## GridManager grid (tiles in-tree so terrain/passability resolve) with real
## Units. Movement is pinned to 0 (can_move = false) so the "stand" set is just
## the unit's current tile, making the threatened cells deterministic — the
## move-flood itself is covered by GridManager's own tests.
extends GutTest


func before_each() -> void:
	GridManager.clear_grid()


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


func _open_grid(min_x: int, max_x: int, min_y: int, max_y: int) -> void:
	for x: int in range(min_x, max_x + 1):
		for y: int in range(min_y, max_y + 1):
			_grid_tile(x, y)


func _move(damage_type: Enums.DamageType, attack_range: int) -> Move:
	var move := Move.new()
	move.damage_type = damage_type
	move.attack_range = attack_range
	move.base_power = 10
	return move


# `moves` typed as Array so we can build the typed equipped_moves array safely.
func _unit(moves: Array, passives: Array = [], can_move: bool = false) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.current_hp = 10
	unit.can_move = can_move  # false -> max_movement_range 0 -> stand set = current tile only
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	var typed_moves: Array[Move] = []
	for m: Move in moves:
		typed_moves.append(m)
	data.equipped_moves = typed_moves
	unit.character_data = data
	return unit


func _place(unit: Unit, x: int, y: int) -> void:
	var tile := GridManager.get_tile(x, y)
	unit.current_tile = tile
	tile.current_unit = unit


# =============================================================================
# max_damaging_reach
# =============================================================================

func test_reach_is_max_over_damaging_moves() -> void:
	var unit := _unit([_move(Enums.DamageType.PHYSICAL, 1), _move(Enums.DamageType.SPECIAL, 3)])
	assert_eq(ThreatCalculator.max_damaging_reach(unit), 3, "takes the longest damaging reach")


func test_support_only_unit_has_no_reach() -> void:
	var unit := _unit([_move(Enums.DamageType.SUPPORT, 2)])
	assert_eq(ThreatCalculator.max_damaging_reach(unit), 0, "support moves don't threaten")


func test_reach_honors_extendo() -> void:
	var unit := _unit([_move(Enums.DamageType.PHYSICAL, 1)], ["Extendo"])
	assert_eq(ThreatCalculator.max_damaging_reach(unit), 2, "Extendo widens the danger zone by 1")


func test_reach_zero_without_data() -> void:
	assert_eq(ThreatCalculator.max_damaging_reach(null), 0)


# =============================================================================
# threatened_cells (movement pinned to 0)
# =============================================================================

func test_threatened_cells_is_attack_ring() -> void:
	_open_grid(0, 4, 0, 4)
	var unit := _unit([_move(Enums.DamageType.PHYSICAL, 1)])
	_place(unit, 2, 2)
	var cells := ThreatCalculator.threatened_cells(unit)
	assert_true(cells.has(Vector2i(1, 2)) and cells.has(Vector2i(3, 2)) \
			and cells.has(Vector2i(2, 1)) and cells.has(Vector2i(2, 3)),
			"all four orthogonal neighbors are threatened at range 1")
	assert_false(cells.has(Vector2i(2, 2)), "the unit's own tile isn't self-threatened")
	assert_false(cells.has(Vector2i(1, 1)), "a diagonal (Manhattan distance 2) is out of range 1")


func test_support_only_unit_threatens_nothing() -> void:
	_open_grid(0, 4, 0, 4)
	var unit := _unit([_move(Enums.DamageType.SUPPORT, 2)])
	_place(unit, 2, 2)
	assert_eq(ThreatCalculator.threatened_cells(unit).size(), 0)


# =============================================================================
# compute_danger_zone — aggregation across a list
# =============================================================================

func test_overlapping_zones_accumulate_count() -> void:
	_open_grid(0, 4, 0, 6)
	var a := _unit([_move(Enums.DamageType.PHYSICAL, 1)])
	var b := _unit([_move(Enums.DamageType.PHYSICAL, 1)])
	_place(a, 2, 2)
	_place(b, 2, 4)
	var units: Array[Unit] = [a, b]
	var danger := ThreatCalculator.compute_danger_zone(units)
	assert_eq(int(danger.get(Vector2i(2, 3), 0)), 2, "(2,3) is in reach of both units")
	assert_eq(int(danger.get(Vector2i(2, 1), 0)), 1, "(2,1) is only in reach of A")


func test_defeated_unit_contributes_no_threat() -> void:
	_open_grid(0, 4, 0, 4)
	var alive := _unit([_move(Enums.DamageType.PHYSICAL, 1)])
	var dead := _unit([_move(Enums.DamageType.PHYSICAL, 1)])
	dead.current_hp = 0
	_place(alive, 2, 2)
	_place(dead, 0, 2)
	var units: Array[Unit] = [alive, dead]
	var danger := ThreatCalculator.compute_danger_zone(units)
	# (1,2) is in range of both positions; if the dead unit counted it would be 2.
	assert_eq(int(danger.get(Vector2i(1, 2), 0)), 1, "only the living unit threatens (1,2)")
	# (0,1) is reachable only from the dead unit's tile — so it must be absent.
	assert_false(danger.has(Vector2i(0, 1)), "a cell only the dead unit could hit is unthreatened")

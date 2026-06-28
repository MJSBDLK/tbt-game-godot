## Phase 2: Extendo — +1 attack range for PHYSICAL moves, and the targeting
## scaffolding it rides on (MoveTargeting.effective_attack_range + can_target +
## is_reach_clear). Bonus tiles past the move's base range require an
## unobstructed forgiving reach that can't cross terrain impassable for the
## attacker's type.
##
## Unit-level tests cover the hook + range helper with no grid. Integration tests
## build a real GridManager grid (tiles IN the tree so Tile.can_unit_move_to can
## reach TerrainDataManager, which the reach predicate calls); an impassable
## "Wall" terrain type models a blocked cell. They exercise the full
## can_target / get_valid_target_tiles path.
extends GutTest


func before_each() -> void:
	GridManager.clear_grid()


func after_all() -> void:
	GridManager.clear_grid()


func _unit(faction: Enums.UnitFaction = Enums.UnitFaction.PLAYER, passives: Array = []) -> Unit:
	# Real Unit (not TestFakeUnit): MoveTargeting.can_target is typed to Unit and
	# get_valid_target_tiles filters on `current_unit is Unit`. Kept off-tree —
	# can_target reads fields + the GridManager autoload, never the unit's tree.
	var unit := Unit.new()
	autofree(unit)
	unit.faction = faction
	unit.current_hp = 10
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	return unit


func _move(damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL, base_power: int = 10,
		attack_range: int = 1) -> Move:
	var move := Move.new()
	move.damage_type = damage_type
	move.base_power = base_power
	move.attack_range = attack_range
	move.target_type = Enums.TargetType.SINGLE
	return move


# Tiles must be IN the tree so Tile.can_unit_move_to can reach TerrainDataManager
# (the reach predicate calls it). The Sprite2D child satisfies Tile._ready's
# $Sprite2D lookup.
func _grid_tile(x: int, y: int, terrain: String) -> void:
	var tile := Tile.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	tile.add_child(sprite)
	add_child_autofree(tile)
	tile.grid_x = x
	tile.grid_y = y
	tile.terrain_type_name = terrain
	GridManager.register_tile(tile)


# Fill an inclusive rectangle of open ("Plains") tiles so reach paths and range
# scans have registered cells to walk over.
func _open_grid(min_x: int, max_x: int, min_y: int, max_y: int) -> void:
	for x: int in range(min_x, max_x + 1):
		for y: int in range(min_y, max_y + 1):
			_grid_tile(x, y, "Plains")


# "Wall" terrain is impassable to grounded (non-Air) types, so our NONE-typed
# test units can't reach through it.
func _wall(x: int, y: int) -> void:
	GridManager.get_tile(x, y).terrain_type_name = "Wall"


func _place(unit: Unit, x: int, y: int) -> void:
	var tile := GridManager.get_tile(x, y)
	unit.current_tile = tile
	tile.current_unit = unit


# =============================================================================
# Hook + registry (no grid)
# =============================================================================

func test_extra_range_for_physical() -> void:
	assert_eq(ExtendoPassive.new().extra_attack_range(_move(Enums.DamageType.PHYSICAL)), 1)


func test_no_extra_range_for_special() -> void:
	assert_eq(ExtendoPassive.new().extra_attack_range(_move(Enums.DamageType.SPECIAL)), 0,
			"Extendo is physical-only")


func test_no_extra_range_for_support() -> void:
	assert_eq(ExtendoPassive.new().extra_attack_range(_move(Enums.DamageType.SUPPORT)), 0)


func test_no_extra_range_for_null_move() -> void:
	assert_eq(ExtendoPassive.new().extra_attack_range(null), 0)


func test_base_does_not_extend_range() -> void:
	assert_eq(CombatEffect.new().extra_attack_range(_move()), 0, "default hook adds nothing")


func test_registry_resolves_extendo() -> void:
	assert_true(PassiveRegistry.get_handler("Extendo") is ExtendoPassive)


# =============================================================================
# effective_attack_range
# =============================================================================

func test_effective_range_adds_extendo_for_physical() -> void:
	var unit := _unit(Enums.UnitFaction.PLAYER, ["Extendo"])
	assert_eq(MoveTargeting.effective_attack_range(unit, _move(Enums.DamageType.PHYSICAL, 10, 1)), 2)


func test_effective_range_unchanged_without_extendo() -> void:
	var unit := _unit()
	assert_eq(MoveTargeting.effective_attack_range(unit, _move(Enums.DamageType.PHYSICAL, 10, 1)), 1)


func test_effective_range_ignores_special_for_extendo() -> void:
	var unit := _unit(Enums.UnitFaction.PLAYER, ["Extendo"])
	assert_eq(MoveTargeting.effective_attack_range(unit, _move(Enums.DamageType.SPECIAL, 10, 2)), 2,
			"special move keeps its base range under Extendo")


# =============================================================================
# Integration: can_target — straight line
# =============================================================================

func test_extendo_reaches_two_tiles_straight() -> void:
	_open_grid(0, 3, 0, 0)
	var attacker := _unit(Enums.UnitFaction.PLAYER, ["Extendo"])
	var target := _unit(Enums.UnitFaction.ENEMY)
	_place(attacker, 0, 0)
	_place(target, 2, 0)
	assert_true(MoveTargeting.can_target(attacker, target, _move()),
			"range-1 physical + Extendo reaches an enemy 2 tiles away over open ground")


func test_without_extendo_cannot_reach_two_tiles() -> void:
	_open_grid(0, 3, 0, 0)
	var attacker := _unit(Enums.UnitFaction.PLAYER)
	var target := _unit(Enums.UnitFaction.ENEMY)
	_place(attacker, 0, 0)
	_place(target, 2, 0)
	assert_false(MoveTargeting.can_target(attacker, target, _move()),
			"a plain range-1 unit can't reach 2 tiles")


func test_extendo_blocked_by_wall_straight() -> void:
	_open_grid(0, 3, 0, 0)
	_wall(1, 0)  # the only cell between attacker and target
	var attacker := _unit(Enums.UnitFaction.PLAYER, ["Extendo"])
	var target := _unit(Enums.UnitFaction.ENEMY)
	_place(attacker, 0, 0)
	_place(target, 2, 0)
	assert_false(MoveTargeting.can_target(attacker, target, _move()),
			"an impassable wall on the only intervening cell stops the extended reach")


# =============================================================================
# Integration: can_target — diagonal (forgiving reach-around)
# =============================================================================

func test_extendo_diagonal_one_corner_open_reaches() -> void:
	_open_grid(0, 2, 0, 2)
	_wall(1, 0)  # one corner of the (0,0)->(1,1) diagonal; (0,1) stays open
	var attacker := _unit(Enums.UnitFaction.PLAYER, ["Extendo"])
	var target := _unit(Enums.UnitFaction.ENEMY)
	_place(attacker, 0, 0)
	_place(target, 1, 1)
	assert_true(MoveTargeting.can_target(attacker, target, _move()),
			"one open corner is enough to poke around (forgiving reach-around)")


func test_extendo_diagonal_both_corners_walled_blocked() -> void:
	_open_grid(0, 2, 0, 2)
	_wall(1, 0)
	_wall(0, 1)
	var attacker := _unit(Enums.UnitFaction.PLAYER, ["Extendo"])
	var target := _unit(Enums.UnitFaction.ENEMY)
	_place(attacker, 0, 0)
	_place(target, 1, 1)
	assert_false(MoveTargeting.can_target(attacker, target, _move()),
			"a fully-walled corner blocks the diagonal reach")


# =============================================================================
# Integration: get_valid_target_tiles + special-move guard
# =============================================================================

func test_valid_target_tiles_includes_bonus_tile() -> void:
	_open_grid(0, 3, 0, 0)
	var attacker := _unit(Enums.UnitFaction.PLAYER, ["Extendo"])
	var target := _unit(Enums.UnitFaction.ENEMY)
	_place(attacker, 0, 0)
	_place(target, 2, 0)
	var tiles := MoveTargeting.get_valid_target_tiles(attacker, _move())
	assert_true(tiles.has(target.current_tile),
			"the enemy on the +1 bonus tile is a highlighted, selectable target")


func test_special_move_gets_no_bonus_tile() -> void:
	_open_grid(0, 3, 0, 0)
	var attacker := _unit(Enums.UnitFaction.PLAYER, ["Extendo"])
	var target := _unit(Enums.UnitFaction.ENEMY)
	_place(attacker, 0, 0)
	_place(target, 2, 0)
	# A range-1 SPECIAL move: Extendo doesn't extend it, so distance 2 is unreachable.
	assert_false(MoveTargeting.can_target(attacker, target, _move(Enums.DamageType.SPECIAL, 10, 1)),
			"Extendo never extends special-move range")

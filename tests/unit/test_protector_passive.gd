## Phase 2: Protector — a unit body-blocks ranged offensive attacks aimed at an
## ally further along its row/column/diagonal. The brain is
## MoveTargeting.resolve_actual_target; these tests drive it directly with a real
## GridManager grid (tiles in-tree, real Units so faction/is_defeated resolve).
## The one-line wiring into Unit.execute_combat_sequence + the combat preview is
## not re-tested here (same as friendly-fire's retarget) — the redirect decision
## is what's worth pinning.
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


func _unit(faction: Enums.UnitFaction, passives: Array = [], hp: int = 10) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.faction = faction
	unit.current_hp = hp
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	return unit


func _place(unit: Unit, x: int, y: int) -> void:
	var tile := GridManager.get_tile(x, y)
	unit.current_tile = tile
	tile.current_unit = unit


func _move(target_type: Enums.TargetType = Enums.TargetType.SINGLE) -> Move:
	var move := Move.new()
	move.target_type = target_type
	move.base_power = 10
	move.damage_type = Enums.DamageType.PHYSICAL
	move.attack_range = 4
	return move


# =============================================================================
# Hook + registry
# =============================================================================

func test_protector_intercepts() -> void:
	assert_true(ProtectorPassive.new().intercepts_attack(null, null, null, null),
			"Protector intercepts unconditionally (resolver does the pre-filter)")


func test_base_does_not_intercept() -> void:
	assert_false(CombatEffect.new().intercepts_attack(null, null, null, null))


func test_registry_resolves_protector() -> void:
	assert_true(PassiveRegistry.get_handler("Protector") is ProtectorPassive)


# =============================================================================
# resolve_actual_target — redirect happens
# =============================================================================

func test_redirects_to_protector_in_line() -> void:
	_open_grid(0, 3, 0, 0)
	var attacker := _unit(Enums.UnitFaction.PLAYER)
	var guard := _unit(Enums.UnitFaction.ENEMY, ["Protector"])
	var target := _unit(Enums.UnitFaction.ENEMY)
	_place(attacker, 0, 0)
	_place(guard, 1, 0)
	_place(target, 3, 0)
	assert_eq(MoveTargeting.resolve_actual_target(attacker, target, _move()), guard,
			"a Protector in the line of fire takes the hit")


func test_diagonal_redirect() -> void:
	_open_grid(0, 2, 0, 2)
	var attacker := _unit(Enums.UnitFaction.PLAYER)
	var guard := _unit(Enums.UnitFaction.ENEMY, ["Protector"])
	var target := _unit(Enums.UnitFaction.ENEMY)
	_place(attacker, 0, 0)
	_place(guard, 1, 1)
	_place(target, 2, 2)
	assert_eq(MoveTargeting.resolve_actual_target(attacker, target, _move()), guard,
			"works along a 45-degree diagonal too")


func test_nearest_protector_wins() -> void:
	_open_grid(0, 3, 0, 0)
	var attacker := _unit(Enums.UnitFaction.PLAYER)
	var near := _unit(Enums.UnitFaction.ENEMY, ["Protector"])
	var far := _unit(Enums.UnitFaction.ENEMY, ["Protector"])
	var target := _unit(Enums.UnitFaction.ENEMY)
	_place(attacker, 0, 0)
	_place(near, 1, 0)
	_place(far, 2, 0)
	_place(target, 3, 0)
	assert_eq(MoveTargeting.resolve_actual_target(attacker, target, _move()), near,
			"the bodyguard nearest the attacker is hit first")


# =============================================================================
# resolve_actual_target — no redirect
# =============================================================================

func test_no_redirect_without_protector() -> void:
	_open_grid(0, 3, 0, 0)
	var attacker := _unit(Enums.UnitFaction.PLAYER)
	var bystander := _unit(Enums.UnitFaction.ENEMY)  # no Protector
	var target := _unit(Enums.UnitFaction.ENEMY)
	_place(attacker, 0, 0)
	_place(bystander, 1, 0)
	_place(target, 3, 0)
	assert_eq(MoveTargeting.resolve_actual_target(attacker, target, _move()), target,
			"a plain unit in the way doesn't block — only Protector does")


func test_adjacent_target_never_redirects() -> void:
	_open_grid(0, 2, 0, 0)
	var attacker := _unit(Enums.UnitFaction.PLAYER)
	var target := _unit(Enums.UnitFaction.ENEMY)
	_place(attacker, 0, 0)
	_place(target, 1, 0)  # adjacent: no cell between -> naturally ranged-only
	assert_eq(MoveTargeting.resolve_actual_target(attacker, target, _move()), target)


func test_off_axis_never_redirects() -> void:
	_open_grid(0, 2, 0, 1)
	var attacker := _unit(Enums.UnitFaction.PLAYER)
	var guard := _unit(Enums.UnitFaction.ENEMY, ["Protector"])
	var target := _unit(Enums.UnitFaction.ENEMY)
	_place(attacker, 0, 0)
	_place(guard, 1, 0)
	_place(target, 2, 1)  # knight's-move offset: no well-defined "behind"
	assert_eq(MoveTargeting.resolve_actual_target(attacker, target, _move()), target)


func test_attacker_ally_does_not_block() -> void:
	# A Protector on the attacker's OWN side standing in the line shields nobody —
	# it's not an ally of the enemy target. Allies-only.
	_open_grid(0, 3, 0, 0)
	var attacker := _unit(Enums.UnitFaction.PLAYER)
	var own_guard := _unit(Enums.UnitFaction.PLAYER, ["Protector"])
	var target := _unit(Enums.UnitFaction.ENEMY)
	_place(attacker, 0, 0)
	_place(own_guard, 1, 0)
	_place(target, 3, 0)
	assert_eq(MoveTargeting.resolve_actual_target(attacker, target, _move()), target,
			"a bodyguard only shields its own faction (the target's)")


func test_defeated_protector_skipped() -> void:
	_open_grid(0, 3, 0, 0)
	var attacker := _unit(Enums.UnitFaction.PLAYER)
	var dead_guard := _unit(Enums.UnitFaction.ENEMY, ["Protector"], 0)  # defeated
	var target := _unit(Enums.UnitFaction.ENEMY)
	_place(attacker, 0, 0)
	_place(dead_guard, 1, 0)
	_place(target, 3, 0)
	assert_eq(MoveTargeting.resolve_actual_target(attacker, target, _move()), target,
			"a downed Protector can't body-block")


func test_ally_targeting_move_never_redirects() -> void:
	_open_grid(0, 3, 0, 0)
	var attacker := _unit(Enums.UnitFaction.PLAYER)
	var guard := _unit(Enums.UnitFaction.ENEMY, ["Protector"])
	var target := _unit(Enums.UnitFaction.ENEMY)
	_place(attacker, 0, 0)
	_place(guard, 1, 0)
	_place(target, 3, 0)
	assert_eq(MoveTargeting.resolve_actual_target(attacker, target, _move(Enums.TargetType.ALLY)), target,
			"healing/buffing moves never redirect")

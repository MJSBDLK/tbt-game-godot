## Phase 4 arc, part 1: the self-cast targeting fix, the support execution
## path, AoE victim gathering, CombatPredicates/Bravery, and Roar's
## conditional affliction. Protector-style grid (registered bare tiles) +
## in-tree bare units so popups/callouts have a tree to land in.
extends GutTest


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


func _unit(label: String, faction: Enums.UnitFaction,
		primary_type: Enums.ElementalType = Enums.ElementalType.SIMPLE) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.unit_name = label
	unit.faction = faction
	unit.current_hp = 20
	var data := CharacterData.new()
	data.primary_type = primary_type
	unit.character_data = data
	return unit


func _place(unit: Unit, x: int, y: int) -> void:
	var tile := GridManager.get_tile(x, y)
	unit.current_tile = tile
	tile.current_unit = unit


func _self_aoe_move(radius: int, affects: String = "enemies", immune: String = "") -> Move:
	var move := Move.new()
	move.move_name = "AoE Probe"
	move.damage_type = Enums.DamageType.SUPPORT
	move.target_type = Enums.TargetType.SELF
	move.area_of_effect = radius
	move.aoe_affects = affects
	move.immune_predicate = immune
	move.max_uses = 5
	move.current_uses = 5
	return move


func _stacks(unit: Unit, effect_name: String) -> int:
	return StatusEffectSystem.get_effect_stacks(unit, effect_name)


# =============================================================================
# SELF-CAST TARGETING (the four dead buffs come back to life)
# =============================================================================

func test_self_move_targets_only_its_caster() -> void:
	_open_grid(0, 2, 0, 0)
	var caster := _unit("caster", Enums.UnitFaction.PLAYER)
	var ally := _unit("ally", Enums.UnitFaction.PLAYER)
	_place(caster, 0, 0)
	_place(ally, 1, 0)
	var focus: Move = MoveData.get_move("Focus")
	assert_true(MoveTargeting.is_valid_target(caster, caster, focus),
		"a SELF move's caster is a legal recipient — this was the dead-buff bug")
	assert_false(MoveTargeting.is_valid_target(ally, caster, focus),
		"a SELF move can't be aimed at anyone else, ally included")


func test_self_buffs_light_up_their_own_tile() -> void:
	_open_grid(0, 2, 0, 0)
	var caster := _unit("caster", Enums.UnitFaction.PLAYER)
	_place(caster, 1, 0)
	var tiles := MoveTargeting.get_valid_target_tiles(caster, MoveData.get_move("Fortify"))
	assert_eq(tiles.size(), 1, "exactly one legal tile")
	assert_eq(tiles[0], caster.current_tile, "and it's the caster's own")


func test_fortify_self_cast_applies_its_buff() -> void:
	_open_grid(0, 1, 0, 0)
	var caster := _unit("caster", Enums.UnitFaction.PLAYER)
	_place(caster, 0, 0)
	var fortify: Move = MoveData.get_move("Fortify")
	var pp_before: int = fortify.current_uses
	await caster.execute_combat_sequence(caster, fortify)
	assert_eq(_stacks(caster, "FORTIFIED"), 4, "Fortified landed at its authored 4 stacks")
	assert_eq(fortify.current_uses, pp_before - 1, "the cast cost one use")


# =============================================================================
# AOE VICTIM GATHERING
# =============================================================================

func test_area_victims_respect_radius_and_faction() -> void:
	_open_grid(0, 6, 0, 0)
	var caster := _unit("caster", Enums.UnitFaction.PLAYER)
	var near_enemy := _unit("near", Enums.UnitFaction.ENEMY)
	var edge_enemy := _unit("edge", Enums.UnitFaction.ENEMY)
	var far_enemy := _unit("far", Enums.UnitFaction.ENEMY)
	var ally := _unit("ally", Enums.UnitFaction.PLAYER)
	_place(caster, 2, 0)
	_place(near_enemy, 1, 0)   # distance 1
	_place(edge_enemy, 4, 0)   # distance 2 — inside
	_place(far_enemy, 5, 0)    # distance 3 — outside
	_place(ally, 3, 0)         # ally — filtered by the "enemies" default
	var victims := MoveTargeting.get_area_victims(caster, caster.current_tile, _self_aoe_move(2))
	assert_true(near_enemy in victims and edge_enemy in victims, "both in-radius enemies")
	assert_false(far_enemy in victims, "distance 3 is past an AoE of 2")
	assert_false(ally in victims, "allies are exempt under aoe_affects=enemies")
	assert_false(caster in victims, "your own shout never hits you")


func test_area_victims_all_still_spares_the_immune() -> void:
	_open_grid(0, 4, 0, 0)
	var caster := _unit("caster", Enums.UnitFaction.ENEMY)
	var ally := _unit("ally", Enums.UnitFaction.ENEMY)
	var meek := _unit("meek", Enums.UnitFaction.PLAYER)
	var brave := _unit("brave", Enums.UnitFaction.PLAYER, Enums.ElementalType.CHIVALRIC)
	_place(caster, 0, 0)
	_place(ally, 1, 0)
	_place(meek, 2, 0)
	_place(brave, 3, 0)
	var victims := MoveTargeting.get_area_victims(
		caster, caster.current_tile, _self_aoe_move(5, "all", "brave"))
	assert_true(ally in victims, "aoe_affects=all pulls the caster's own side in")
	assert_true(meek in victims, "ordinary opponents are fair game")
	assert_false(brave in victims, "the brave are passed over entirely")


func test_self_aoe_is_pointless_with_no_audience() -> void:
	_open_grid(0, 6, 0, 0)
	var caster := _unit("caster", Enums.UnitFaction.PLAYER)
	var enemy := _unit("enemy", Enums.UnitFaction.ENEMY)
	_place(caster, 0, 0)
	_place(enemy, 5, 0)
	var roar: Move = MoveData.get_move("Roar")
	assert_false(roar.has_meaningful_effect_on(caster),
		"nobody within earshot — the chip should grey out")
	var near_enemy := _unit("near", Enums.UnitFaction.ENEMY)
	_place(near_enemy, 2, 0)
	assert_true(roar.has_meaningful_effect_on(caster),
		"an enemy at distance 2 makes the roar worth bellowing")


# =============================================================================
# PREDICATES + BRAVERY
# =============================================================================

func test_bravery_comes_from_type_or_passive() -> void:
	var chivalric := _unit("knightly", Enums.UnitFaction.ENEMY, Enums.ElementalType.CHIVALRIC)
	assert_true(CombatPredicates.is_brave(chivalric), "Chivalric primary = brave")

	var passive_brave := _unit("stouthearted", Enums.UnitFaction.PLAYER)
	passive_brave.character_data.equipped_passives = ["Bravery"]
	assert_true(CombatPredicates.is_brave(passive_brave), "the Bravery passive grants courage")
	assert_true(passive_brave.is_brave(), "the Unit convenience agrees")

	var meek := _unit("meek", Enums.UnitFaction.PLAYER)
	assert_false(CombatPredicates.is_brave(meek), "no type, no passive, no courage")


# =============================================================================
# ROAR — conditional affliction, end to end
# =============================================================================

func test_roar_parses_its_conditional_schema() -> void:
	var roar: Move = MoveData.get_move("Roar")
	assert_eq(roar.target_type, Enums.TargetType.SELF)
	assert_eq(roar.area_of_effect, 2)
	assert_eq(roar.aoe_affects, "enemies")
	assert_eq(roar.status_conditional.get("predicate"), "brave")
	assert_eq(roar.status_conditional.get("then", {}).get("effect"), "CHALLENGED")
	assert_eq(roar.status_conditional.get("else", {}).get("effect"), "SHOCKED")
	assert_eq(roar.status_effect_type, Enums.StatusEffectType.NONE,
		"conditional and flat status forms are mutually exclusive")


func test_roar_shocks_the_meek_and_challenges_the_brave() -> void:
	_open_grid(0, 6, 0, 0)
	var caster := _unit("roarer", Enums.UnitFaction.PLAYER)
	var brave := _unit("brave", Enums.UnitFaction.ENEMY, Enums.ElementalType.CHIVALRIC)
	var meek := _unit("meek", Enums.UnitFaction.ENEMY)
	var far := _unit("far", Enums.UnitFaction.ENEMY)
	_place(caster, 2, 0)
	_place(brave, 1, 0)
	_place(meek, 4, 0)
	_place(far, 6, 0)
	await caster.execute_combat_sequence(caster, MoveData.get_move("Roar"))
	assert_eq(_stacks(brave, "CHALLENGED"), 3, "the brave accept the challenge (config default 3)")
	assert_eq(_stacks(brave, "SHOCKED"), 0, "…and are NOT rattled")
	assert_eq(_stacks(meek, "SHOCKED"), 2, "the meek are rattled (config default 2)")
	assert_eq(_stacks(far, "SHOCKED"), 0, "distance 4 is out of earshot")
	assert_eq(_stacks(caster, "SHOCKED"), 0, "the roarer never shocks themselves")
	assert_eq(caster.current_hp, 20, "a shout draws no blood")
	assert_eq(brave.current_hp, 20, "…on either side")


func test_roar_leaves_counters_unfired() -> void:
	_open_grid(0, 2, 0, 0)
	var caster := _unit("roarer", Enums.UnitFaction.PLAYER)
	var enemy := _unit("enemy", Enums.UnitFaction.ENEMY)
	_place(caster, 0, 0)
	_place(enemy, 1, 0)
	var counter: Move = MoveData.get_move("Bonk")
	enemy.assigned_move = counter
	var counter_pp: int = counter.current_uses
	await caster.execute_combat_sequence(caster, MoveData.get_move("Roar"))
	assert_eq(caster.current_hp, 20, "a support cast is not an exchange — no counter damage")
	assert_eq(counter.current_uses, counter_pp, "and no counter PP was paid")

## Phase 2: Stellar — grants Maximum (the stat-floor protection) to allied units
## within 2 tiles, including itself. A stat aura that sets maximum_from_aura;
## PassiveEffectsSystem.recompute_faction then re-runs the status recalc so the
## clamp picks up the flag.
extends GutTest


func _effect(name: String, affected_stat: String, stacks: int) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.effect_type_name = name
	effect.affected_stat = affected_stat
	effect.stacks = stacks
	return effect


func _unit_at(grid_x: int, grid_y: int, passives: Array = []) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.current_hp = 100
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	var tile := Tile.new()
	autofree(tile)
	tile.grid_x = grid_x
	tile.grid_y = grid_y
	unit.current_tile = tile
	return unit


# =============================================================================
# Aura flag
# =============================================================================

func test_flags_allies_within_range_and_self() -> void:
	var star := _unit_at(0, 0, ["Stellar"])
	var near := _unit_at(2, 0)   # distance 2, in range
	var far := _unit_at(5, 0)    # out of range
	var allies: Array[Unit] = [star, near, far]
	StellarPassive.new().apply_stat_aura(star, allies)
	assert_true(near.character_data.maximum_from_aura, "ally within 2 is protected")
	assert_true(star.character_data.maximum_from_aura, "the Stellar unit protects itself")
	assert_false(far.character_data.maximum_from_aura, "ally out of range is not")


func test_registry_resolves_stellar() -> void:
	assert_true(PassiveRegistry.get_handler("Stellar") is StellarPassive)


# =============================================================================
# End to end: recompute_faction → flag → Maximum clamp
# =============================================================================

func test_stellar_protects_ally_debuff_via_recompute() -> void:
	var star := _unit_at(0, 0, ["Stellar"])
	var ally := _unit_at(1, 0)
	ally.active_status_effects = [_effect("BURN", "strength", 4)]
	var units: Array[Unit] = [star, ally]
	PassiveEffectsSystem.recompute_faction(units)
	assert_true(ally.character_data.maximum_from_aura, "Stellar flagged the ally")
	assert_eq(ally.character_data.status_modifier_strength, 0,
			"the granted Maximum clamped the ally's debuff")


func test_out_of_range_ally_keeps_its_debuff() -> void:
	var star := _unit_at(0, 0, ["Stellar"])
	var ally := _unit_at(5, 0)  # out of range
	ally.active_status_effects = [_effect("BURN", "strength", 4)]
	var units: Array[Unit] = [star, ally]
	PassiveEffectsSystem.recompute_faction(units)
	assert_false(ally.character_data.maximum_from_aura)
	assert_lt(ally.character_data.status_modifier_strength, 0, "no protection → debuff applies")

## Phase 2 slice 3: Competitive migrated to a CompetitivePassive stat-aura handler,
## dispatched from PassiveEffectsSystem.recompute via apply_stat_aura.
##
## Uses Unit.new() + Tile.new() (no _ready) so we can place units on a grid and
## read stats without a live scene.
extends GutTest


func _make_unit(grid_x: int, grid_y: int, passives: Array = []) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	unit.current_hp = 100  # alive — is_defeated() is current_hp <= 0, and the aura skips defeated allies
	var tile := Tile.new()
	autofree(tile)
	tile.grid_x = grid_x
	tile.grid_y = grid_y
	unit.current_tile = tile
	return unit


# =============================================================================
# CompetitivePassive.apply_stat_aura
# =============================================================================

func test_copies_nearby_allys_highest_stat() -> void:
	var unit := _make_unit(0, 0, ["Competitive"])
	var ally := _make_unit(1, 0)              # 1 tile away, in range
	ally.character_data.base_strength = 20    # clearly the highest stat
	CompetitivePassive.new().apply_stat_aura(unit, [unit, ally])
	assert_eq(unit.character_data.passive_bonus_strength, CompetitivePassive.BONUS,
			"+3 to the ally's highest stat (strength)")


func test_no_bonus_when_no_ally_in_range() -> void:
	var unit := _make_unit(0, 0, ["Competitive"])
	var ally := _make_unit(10, 0)             # well outside range 3
	ally.character_data.base_strength = 20
	CompetitivePassive.new().apply_stat_aura(unit, [unit, ally])
	assert_eq(unit.character_data.passive_bonus_strength, 0, "out-of-range ally grants nothing")


func test_tie_breaks_by_comparable_stats_order() -> void:
	var unit := _make_unit(0, 0, ["Competitive"])
	var ally := _make_unit(1, 0)
	ally.character_data.base_strength = 20
	ally.character_data.base_special = 20     # tie; strength precedes special
	CompetitivePassive.new().apply_stat_aura(unit, [unit, ally])
	assert_eq(unit.character_data.passive_bonus_strength, CompetitivePassive.BONUS, "strength wins the tie")
	assert_eq(unit.character_data.passive_bonus_special, 0, "special not boosted")


# =============================================================================
# Registry + recompute dispatch
# =============================================================================

func test_registry_resolves_competitive() -> void:
	assert_true(PassiveRegistry.get_handler("Competitive") is CompetitivePassive)


func test_recompute_applies_competitive_and_zeroes_first() -> void:
	var unit := _make_unit(0, 0, ["Competitive"])
	var ally := _make_unit(1, 0)
	ally.character_data.base_defense = 30
	# Stale bonus from a previous recompute must be cleared before re-applying.
	unit.character_data.passive_bonus_strength = 99
	var units: Array[Unit] = [unit, ally]
	PassiveEffectsSystem.recompute_faction(units)
	assert_eq(unit.character_data.passive_bonus_strength, 0, "recompute zeroes stale bonuses")
	assert_eq(unit.character_data.passive_bonus_defense, CompetitivePassive.BONUS, "defense copied from ally")


func test_recompute_no_passive_grants_nothing() -> void:
	var unit := _make_unit(0, 0, [])          # no Competitive
	var ally := _make_unit(1, 0)
	ally.character_data.base_strength = 30
	var units: Array[Unit] = [unit, ally]
	PassiveEffectsSystem.recompute_faction(units)
	assert_eq(unit.character_data.passive_bonus_strength, 0, "no Competitive → no aura")

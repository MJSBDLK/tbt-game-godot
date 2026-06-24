## Phase 2: Regenerator — heals 8% of max HP at turn start, its own channel
## (stacks with the REGEN boost), can't overheal.
extends GutTest


var _no_allies: Array[Unit] = []


func _unit(max_hp_base: int, current_hp: int) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	var data := CharacterData.new()
	data.base_max_hp = max_hp_base
	unit.character_data = data
	unit.current_hp = current_hp
	return unit


func test_regenerates_a_slice_of_max_hp() -> void:
	var unit := _unit(100, 50)
	var expected: int = maxi(1, int(floor(unit.character_data.max_hp * RegeneratorPassive.HEAL_PCT_OF_MAX_HP)))
	RegeneratorPassive.new().on_turn_start(unit, _no_allies)
	assert_eq(unit.current_hp, 50 + expected, "healed ~8% of max HP")


func test_no_overheal_at_full_hp() -> void:
	var unit := _unit(100, 1)
	unit.current_hp = unit.character_data.max_hp  # full
	RegeneratorPassive.new().on_turn_start(unit, _no_allies)
	assert_eq(unit.current_hp, unit.character_data.max_hp, "no overheal at full HP")


func test_registry_resolves_regenerator() -> void:
	assert_true(PassiveRegistry.get_handler("Regenerator") is RegeneratorPassive)

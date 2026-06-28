## Phase 2: Anti-Gravity — each active debuff has a 50% chance to clear at turn
## start; buffs are untouched. First consumer of the turn-start dispatch.
##
## The 50% roll can't be asserted in one shot, so the "clears" tests run the hook
## up to 50 times and assert it cleared by then (P(miss) ~ 0.5^50). The invariant
## that matters — buffs never clear — is fully deterministic.
extends GutTest


var _no_allies: Array[Unit] = []


func _effect(name: String, category: Enums.EffectCategory) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.effect_type_name = name
	effect.category = category
	effect.stacks = 1
	return effect


func _unit_with(effects: Array, passives: Array = []) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.current_hp = 100
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	unit.active_status_effects = effects
	return unit


func _has(unit: Unit, name: String) -> bool:
	for effect: StatusEffect in unit.active_status_effects:
		if effect.effect_type_name == name:
			return true
	return false


# =============================================================================
# Handler
# =============================================================================

func test_buffs_are_never_cleared() -> void:
	var unit := _unit_with([_effect("RALLIED", Enums.EffectCategory.BUFF)])
	var handler := AntiGravityPassive.new()
	for i: int in 25:
		handler.on_turn_start(unit, _no_allies)
	assert_true(_has(unit, "RALLIED"), "buffs are immune to Anti-Gravity")


func test_debuff_clears_within_many_turns() -> void:
	var unit := _unit_with([_effect("BURN", Enums.EffectCategory.DEBUFF)])
	var handler := AntiGravityPassive.new()
	var cleared := false
	for i: int in 50:
		handler.on_turn_start(unit, _no_allies)
		if not _has(unit, "BURN"):
			cleared = true
			break
	assert_true(cleared, "a debuff clears within 50 turns")


func test_only_debuffs_clear_buffs_persist() -> void:
	var unit := _unit_with([
		_effect("RALLIED", Enums.EffectCategory.BUFF),
		_effect("BURN", Enums.EffectCategory.DEBUFF),
	])
	var handler := AntiGravityPassive.new()
	for i: int in 50:
		handler.on_turn_start(unit, _no_allies)
		if not _has(unit, "BURN"):
			break
	assert_false(_has(unit, "BURN"), "debuff cleared")
	assert_true(_has(unit, "RALLIED"), "buff survived")


# =============================================================================
# Registry + turn-start dispatch (TurnManager → handler)
# =============================================================================

func test_registry_resolves_anti_gravity() -> void:
	assert_true(PassiveRegistry.get_handler("Anti-Gravity") is AntiGravityPassive)


func test_turn_start_dispatch_clears_debuff() -> void:
	# Drive the real TurnManager pass to prove on_turn_start is wired through it.
	var unit := _unit_with([_effect("BURN", Enums.EffectCategory.DEBUFF)], ["Anti-Gravity"])
	var units: Array[Unit] = [unit]
	for i: int in 50:
		TurnManager._process_passive_turn_start(units)
		if not _has(unit, "BURN"):
			break
	assert_false(_has(unit, "BURN"), "turn-start dispatch ran Anti-Gravity")

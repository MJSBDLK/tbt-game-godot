## VOID now locks a random move OR passive per stack, drawn from a single
## combined pool (was move-only). Covers slot assignment across the pool, the
## move/passive query helpers, the most-recent-pops-first decrement, and the
## PassiveRegistry chokepoint that makes a locked passive's handler go inert.
extends GutTest


func _unit_with(moves: int, passives: Array = []) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	var data := CharacterData.new()
	var move_list: Array[Move] = []
	for i: int in range(moves):
		move_list.append(Move.new())
	data.equipped_moves = move_list
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	return unit


## Build a VOID effect with explicit locked slots, mirroring how the system
## stores them — used where the test needs determinism instead of random picks.
func _void_effect(stacks: int, slots: Array[Dictionary]) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.effect_type_name = "VOID"
	effect.stacks = stacks
	effect.locked_slots = slots
	return effect


# =============================================================================
# Slot assignment — combined move + passive pool
# =============================================================================

func test_lock_count_matches_stacks() -> void:
	var unit := _unit_with(2, ["Bellows", "Ghost"])
	StatusEffectSystem.apply_status_effect_by_name(null, unit, "VOID", 3)
	var effect: StatusEffect = unit.active_status_effects[0]
	assert_eq(effect.locked_slots.size(), 3, "3 stacks lock 3 slots from the move+passive pool")


func test_lock_saturates_at_total_slots() -> void:
	# 1 move + 1 passive = 2 lockable slots; asking for 4 can only lock 2.
	var unit := _unit_with(1, ["Bellows"])
	StatusEffectSystem.apply_status_effect_by_name(null, unit, "VOID", 4)
	var effect: StatusEffect = unit.active_status_effects[0]
	assert_eq(effect.locked_slots.size(), 2, "can't lock more slots than exist")


func test_passives_are_lockable_when_no_moves() -> void:
	var unit := _unit_with(0, ["Bellows", "Ghost"])
	StatusEffectSystem.apply_status_effect_by_name(null, unit, "VOID", 2)
	assert_true(StatusEffectSystem.is_passive_locked(unit, 0), "passive slot 0 locked")
	assert_true(StatusEffectSystem.is_passive_locked(unit, 1), "passive slot 1 locked")
	assert_false(StatusEffectSystem.is_move_locked(unit, 0), "no move slots to lock")


func test_each_slot_locked_at_most_once() -> void:
	# Two passives, two stacks → both passives, no duplicate index.
	var unit := _unit_with(0, ["Bellows", "Ghost"])
	StatusEffectSystem.apply_status_effect_by_name(null, unit, "VOID", 2)
	var effect: StatusEffect = unit.active_status_effects[0]
	var seen := {}
	for slot: Dictionary in effect.locked_slots:
		var key: String = "%s:%d" % [slot.kind, slot.index]
		assert_false(seen.has(key), "slot %s locked twice" % key)
		seen[key] = true


# =============================================================================
# Query helpers distinguish move vs passive
# =============================================================================

func test_is_move_locked_and_is_passive_locked_are_distinct() -> void:
	var unit := _unit_with(2, ["Bellows", "Ghost"])
	# Lock move slot 1 and passive slot 0 — same numeric index space, different kinds.
	unit.active_status_effects = [_void_effect(2, [
		{"kind": StatusEffect.SLOT_MOVE, "index": 1},
		{"kind": StatusEffect.SLOT_PASSIVE, "index": 0},
	])]
	assert_true(StatusEffectSystem.is_move_locked(unit, 1), "move slot 1 locked")
	assert_false(StatusEffectSystem.is_move_locked(unit, 0), "move slot 0 free")
	assert_true(StatusEffectSystem.is_passive_locked(unit, 0), "passive slot 0 locked")
	assert_false(StatusEffectSystem.is_passive_locked(unit, 1), "passive slot 1 free")


func test_unit_is_passive_index_locked_delegates() -> void:
	var unit := _unit_with(0, ["Bellows"])
	unit.active_status_effects = [_void_effect(1, [{"kind": StatusEffect.SLOT_PASSIVE, "index": 0}])]
	assert_true(unit.is_passive_index_locked(0), "Unit-level query mirrors the system")
	assert_false(unit.is_passive_index_locked(1))


# =============================================================================
# Decrement pops the most-recently-locked slot first
# =============================================================================

func test_turn_start_pops_most_recent_slot() -> void:
	var unit := _unit_with(0, ["Bellows", "Ghost"])
	var first := {"kind": StatusEffect.SLOT_PASSIVE, "index": 0}
	var second := {"kind": StatusEffect.SLOT_PASSIVE, "index": 1}
	unit.active_status_effects = [_void_effect(2, [first, second])]

	StatusEffectSystem.process_turn_start_effects(unit)
	var effect: StatusEffect = unit.active_status_effects[0]
	assert_eq(effect.stacks, 1, "one stack consumed")
	assert_eq(effect.locked_slots.size(), 1, "one slot released")
	assert_eq(effect.locked_slots[0], first, "the earlier-locked slot survives; the latest popped")

	StatusEffectSystem.process_turn_start_effects(unit)
	assert_eq(unit.active_status_effects.size(), 0, "VOID expires when the last stack clears")


# =============================================================================
# PassiveRegistry chokepoint — locked passive handler goes inert
# =============================================================================

func test_get_handlers_for_skips_locked_passive() -> void:
	var unit := _unit_with(0, ["Bellows", "Ghost"])
	# Lock passive slot 0 (Bellows); Ghost (slot 1) stays active.
	unit.active_status_effects = [_void_effect(1, [{"kind": StatusEffect.SLOT_PASSIVE, "index": 0}])]

	var handlers := PassiveRegistry.get_handlers_for(unit.character_data, unit)
	assert_false(handlers.has(PassiveRegistry.get_handler("Bellows")), "locked Bellows excluded")
	assert_true(handlers.has(PassiveRegistry.get_handler("Ghost")), "unlocked Ghost still gathered")


func test_get_handlers_for_without_unit_ignores_locks() -> void:
	# Backward-compat: the many non-combat callers pass only character_data and
	# must still see every coded handler.
	var unit := _unit_with(0, ["Bellows", "Ghost"])
	unit.active_status_effects = [_void_effect(1, [{"kind": StatusEffect.SLOT_PASSIVE, "index": 0}])]

	var handlers := PassiveRegistry.get_handlers_for(unit.character_data)
	assert_true(handlers.has(PassiveRegistry.get_handler("Bellows")), "no gating without a unit")
	assert_true(handlers.has(PassiveRegistry.get_handler("Ghost")))

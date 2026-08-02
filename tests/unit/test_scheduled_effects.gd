## Phase 4 arc, part 2: Shriek of the Damned and the scheduled-effect queue —
## marking, the caster-faction tick clock, cleanse-defusal, the chain-lightning
## strike + splash, defeats, and the save round-trip. Same grid/unit helpers as
## test_phase4_conditional.
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


func _stacks(unit: Unit, effect_name: String) -> int:
	return StatusEffectSystem.get_effect_stacks(unit, effect_name)


func _marked(unit: Unit) -> bool:
	return _stacks(unit, "CHAIN_LIGHTNING") > 0 and unit.scheduled_effects.size() > 0


# =============================================================================
# SCHEMA + MARKING
# =============================================================================

func test_shriek_parses_its_scheduled_schema() -> void:
	var shriek: Move = MoveData.get_move("Shriek of the Damned")
	assert_eq(shriek.target_type, Enums.TargetType.SELF)
	assert_eq(shriek.area_of_effect, 5)
	assert_eq(shriek.aoe_affects, "all")
	assert_eq(shriek.immune_predicate, "brave")
	assert_eq(shriek.scheduled_effect.get("effect"), "chain_lightning_strike")
	assert_eq(shriek.scheduled_effect.get("delay"), 1)
	assert_eq(shriek.scheduled_effect.get("marker"), "CHAIN_LIGHTNING")
	assert_eq(int(shriek.scheduled_effect.get("params", {}).get("power", 0)), 6)


func test_shriek_marks_the_field_but_never_the_brave() -> void:
	_open_grid(0, 8, 0, 0)
	var caster := _unit("shrieker", Enums.UnitFaction.ENEMY, Enums.ElementalType.OCCULT)
	var own_ally := _unit("own ally", Enums.UnitFaction.ENEMY)
	var meek := _unit("meek", Enums.UnitFaction.PLAYER)
	var brave := _unit("brave", Enums.UnitFaction.PLAYER, Enums.ElementalType.CHIVALRIC)
	var far := _unit("far", Enums.UnitFaction.PLAYER)
	_place(caster, 0, 0)
	_place(own_ally, 1, 0)
	_place(meek, 2, 0)
	_place(brave, 3, 0)
	_place(far, 8, 0)
	await caster.execute_combat_sequence(caster, MoveData.get_move("Shriek of the Damned"))
	assert_true(_marked(meek), "an opponent in the scream's radius is marked")
	assert_true(_marked(own_ally), "the damned don't discriminate — the caster's own side too")
	assert_false(_marked(brave), "the brave do not flinch, and are passed over")
	assert_false(_marked(far), "distance 8 is beyond an AoE of 5")
	assert_false(_marked(caster), "the shrieker never marks themselves")
	assert_eq(int(meek.scheduled_effects[0].get("faction")), int(Enums.UnitFaction.ENEMY),
		"the entry carries the CASTER's faction — that's the tick clock")


func test_occupied_debuff_slot_blocks_the_mark_and_the_strike() -> void:
	_open_grid(0, 2, 0, 0)
	var caster := _unit("shrieker", Enums.UnitFaction.ENEMY)
	var victim := _unit("victim", Enums.UnitFaction.PLAYER)
	_place(caster, 0, 0)
	_place(victim, 1, 0)
	StatusEffectSystem.apply_status_effect_by_name(caster, victim, "SHOCKED")
	var queued: bool = ScheduledEffects.schedule(
		caster, victim, MoveData.get_move("Shriek of the Damned"))
	assert_false(queued, "the mark can't take hold through an occupied debuff slot")
	assert_eq(victim.scheduled_effects.size(), 0, "…so nothing is pending either")


# =============================================================================
# THE TICK CLOCK + THE STRIKE
# =============================================================================

func test_strike_fires_on_the_casters_clock_only() -> void:
	_open_grid(0, 3, 0, 0)
	var caster := _unit("shrieker", Enums.UnitFaction.ENEMY)
	var victim := _unit("victim", Enums.UnitFaction.PLAYER)
	_place(caster, 0, 0)
	_place(victim, 2, 0)
	ScheduledEffects.schedule(caster, victim, MoveData.get_move("Shriek of the Damned"))

	await ScheduledEffects.tick_faction_phase(Enums.UnitFaction.PLAYER, [caster, victim])
	assert_eq(victim.current_hp, 20, "the PLAYER phase is not the enemy shriek's clock")
	assert_eq(victim.scheduled_effects.size(), 1, "still pending")

	await ScheduledEffects.tick_faction_phase(Enums.UnitFaction.ENEMY, [caster, victim])
	assert_eq(victim.current_hp, 14, "delay 1 → the strike lands next enemy phase (power 6)")
	assert_eq(victim.scheduled_effects.size(), 0, "the entry is consumed")
	assert_eq(_stacks(victim, "CHAIN_LIGHTNING"), 0, "and the mark is spent with it")


func test_cleansing_the_mark_defuses_the_strike() -> void:
	_open_grid(0, 3, 0, 0)
	var caster := _unit("shrieker", Enums.UnitFaction.ENEMY)
	var victim := _unit("victim", Enums.UnitFaction.PLAYER)
	var medic := _unit("medic", Enums.UnitFaction.PLAYER)
	_place(caster, 0, 0)
	_place(victim, 2, 0)
	_place(medic, 3, 0)
	ScheduledEffects.schedule(caster, victim, MoveData.get_move("Shriek of the Damned"))
	assert_true(_marked(victim), "marked and pending")

	await medic.execute_combat_sequence(victim, MoveData.get_move("Steady"))
	assert_eq(_stacks(victim, "CHAIN_LIGHTNING"), 0, "Steady grounds out the mark")

	await ScheduledEffects.tick_faction_phase(Enums.UnitFaction.ENEMY, [caster, victim, medic])
	assert_eq(victim.current_hp, 20, "no mark at fire time = no strike — cleanse IS the counterplay")
	assert_eq(victim.scheduled_effects.size(), 0, "the dud entry is discarded, not re-armed")


func test_splash_zaps_neighbors_but_spares_the_brave_and_the_distant() -> void:
	_open_grid(0, 4, 0, 1)
	var caster := _unit("shrieker", Enums.UnitFaction.ENEMY)
	var victim := _unit("victim", Enums.UnitFaction.PLAYER)
	var neighbor := _unit("neighbor", Enums.UnitFaction.PLAYER)
	var brave_neighbor := _unit("brave", Enums.UnitFaction.PLAYER, Enums.ElementalType.CHIVALRIC)
	var bystander := _unit("bystander", Enums.UnitFaction.PLAYER)
	_place(caster, 0, 1)
	_place(victim, 2, 0)
	_place(neighbor, 1, 0)        # orthogonal — splashed
	_place(brave_neighbor, 3, 0)  # orthogonal but brave — spared
	_place(bystander, 4, 0)       # distance 2 — untouched
	ScheduledEffects.schedule(caster, victim, MoveData.get_move("Shriek of the Damned"))

	await ScheduledEffects.tick_faction_phase(Enums.UnitFaction.ENEMY,
			[caster, victim, neighbor, brave_neighbor, bystander])
	assert_eq(victim.current_hp, 14, "the marked unit takes the full 6")
	assert_eq(neighbor.current_hp, 17, "adjacency costs half, rounded up (3)")
	assert_eq(brave_neighbor.current_hp, 20, "brave-immunity covers the splash too")
	assert_eq(bystander.current_hp, 20, "two tiles away is out of the arc")


func test_strike_can_finish_a_wounded_unit() -> void:
	_open_grid(0, 3, 0, 0)
	var caster := _unit("shrieker", Enums.UnitFaction.ENEMY)
	var victim := _unit("victim", Enums.UnitFaction.PLAYER)
	_place(caster, 0, 0)
	_place(victim, 2, 0)
	victim.current_hp = 5
	ScheduledEffects.schedule(caster, victim, MoveData.get_move("Shriek of the Damned"))
	await ScheduledEffects.tick_faction_phase(Enums.UnitFaction.ENEMY, [caster, victim])
	assert_true(victim.is_defeated(), "6 damage through 5 HP is a defeat")
	assert_eq(victim.scheduled_effects.size(), 0, "no dangling entries on the fallen")


# =============================================================================
# SAVE ROUND-TRIP
# =============================================================================

func test_scheduled_queue_survives_the_save_round_trip() -> void:
	_open_grid(0, 3, 0, 0)
	var caster := _unit("shrieker", Enums.UnitFaction.ENEMY)
	var victim := _unit("victim", Enums.UnitFaction.PLAYER)
	_place(caster, 0, 0)
	_place(victim, 2, 0)
	ScheduledEffects.schedule(caster, victim, MoveData.get_move("Shriek of the Damned"))

	var entry: Dictionary = SaveManager._unit_to_save_dict(victim)
	var round_tripped: Dictionary = JSON.parse_string(JSON.stringify(entry))

	var restored := _unit("restored", Enums.UnitFaction.PLAYER)
	SaveManager.apply_unit_state(restored, round_tripped)
	assert_eq(restored.scheduled_effects.size(), 1, "the pending strike rode the save")
	var pending: Dictionary = restored.scheduled_effects[0]
	assert_eq(pending.get("effect"), "chain_lightning_strike")
	assert_eq(pending.get("faction"), int(Enums.UnitFaction.ENEMY), "faction re-coerced to int")
	assert_eq(pending.get("turns_remaining"), 1, "turns re-coerced to int")
	assert_eq(pending.get("marker"), "CHAIN_LIGHTNING")
	assert_eq(_stacks(restored, "CHAIN_LIGHTNING"), 1, "the visible mark restored with it")

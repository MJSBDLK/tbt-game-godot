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
	assert_eq(shriek.scheduled_effect.get("stacks"), 2, "Shriek marks arc twice")
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


# =============================================================================
# THE CHAIN (RQD 2026-08-03 design: stacks = arcs, halving damage, no revisits,
# electric immune, longest-path threading)
# =============================================================================

func test_chain_arcs_halve_and_stop_at_the_budget() -> void:
	_open_grid(0, 5, 0, 0)
	var caster := _unit("shrieker", Enums.UnitFaction.ENEMY)
	var victim := _unit("victim", Enums.UnitFaction.PLAYER)
	var first_arc := _unit("first arc", Enums.UnitFaction.PLAYER)
	var second_arc := _unit("second arc", Enums.UnitFaction.PLAYER)
	var beyond := _unit("beyond", Enums.UnitFaction.PLAYER)
	_place(caster, 0, 0)      # Chebyshev 2 from the victim — out of arc reach
	_place(victim, 2, 0)
	_place(first_arc, 3, 0)
	_place(second_arc, 4, 0)
	_place(beyond, 5, 0)
	ScheduledEffects.schedule(caster, victim, MoveData.get_move("Shriek of the Damned"))

	await ScheduledEffects.tick_faction_phase(Enums.UnitFaction.ENEMY,
			[caster, victim, first_arc, second_arc, beyond])
	assert_eq(victim.current_hp, 14, "the marked unit takes the full 6")
	assert_eq(first_arc.current_hp, 17, "arc 1 takes half (3)")
	assert_eq(second_arc.current_hp, 19, "arc 2 takes a quarter, floored (1)")
	assert_eq(beyond.current_hp, 20, "two stacks = two arcs — the budget is spent")
	assert_eq(caster.current_hp, 20, "nobody was in reach of the shrieker")


func test_chain_never_strikes_the_same_unit_twice() -> void:
	_open_grid(0, 3, 0, 0)
	var caster := _unit("shrieker", Enums.UnitFaction.ENEMY)
	var victim := _unit("victim", Enums.UnitFaction.PLAYER)
	var only_neighbor := _unit("only neighbor", Enums.UnitFaction.PLAYER)
	_place(caster, 0, 0)
	_place(victim, 2, 0)
	_place(only_neighbor, 3, 0)
	ScheduledEffects.schedule(caster, victim, MoveData.get_move("Shriek of the Damned"))

	await ScheduledEffects.tick_faction_phase(Enums.UnitFaction.ENEMY,
			[caster, victim, only_neighbor])
	assert_eq(victim.current_hp, 14, "no ping-pong back onto the origin")
	assert_eq(only_neighbor.current_hp, 17, "one arc, one hit — the second arc finds nobody new")


func test_chain_threads_the_cluster_instead_of_dying_in_a_dead_end() -> void:
	# The RQD clustering rule: (1,0) is a dead end (its only neighbor is the
	# victim), and it sorts FIRST in candidate order — a greedy chain would
	# jump there and strand its second arc. The longest-path search must
	# thread (3,0) → (4,0) instead.
	_open_grid(0, 4, 0, 2)
	var caster := _unit("shrieker", Enums.UnitFaction.ENEMY)
	var victim := _unit("victim", Enums.UnitFaction.PLAYER)
	var dead_end := _unit("dead end", Enums.UnitFaction.PLAYER)
	var through := _unit("through", Enums.UnitFaction.PLAYER)
	var far_link := _unit("far link", Enums.UnitFaction.PLAYER)
	_place(caster, 0, 2)
	_place(victim, 2, 0)
	_place(dead_end, 1, 0)
	_place(through, 3, 0)
	_place(far_link, 4, 0)
	ScheduledEffects.schedule(caster, victim, MoveData.get_move("Shriek of the Damned"))

	await ScheduledEffects.tick_faction_phase(Enums.UnitFaction.ENEMY,
			[caster, victim, dead_end, through, far_link])
	assert_eq(victim.current_hp, 14, "origin takes the full 6")
	assert_eq(dead_end.current_hp, 20, "the dead end is passed over for the longer path")
	assert_eq(through.current_hp, 17, "arc 1 threads the cluster (3)")
	assert_eq(far_link.current_hp, 19, "arc 2 reaches the far link (1)")


func test_diagonals_are_within_arc_reach() -> void:
	_open_grid(0, 3, 0, 1)
	var caster := _unit("shrieker", Enums.UnitFaction.ENEMY)
	var victim := _unit("victim", Enums.UnitFaction.PLAYER)
	var diagonal := _unit("diagonal", Enums.UnitFaction.PLAYER)
	_place(caster, 0, 0)
	_place(victim, 2, 0)
	_place(diagonal, 3, 1)
	ScheduledEffects.schedule(caster, victim, MoveData.get_move("Shriek of the Damned"))

	await ScheduledEffects.tick_faction_phase(Enums.UnitFaction.ENEMY,
			[caster, victim, diagonal])
	assert_eq(diagonal.current_hp, 17, "touching at the corner is touching — the bolt jumps")


func test_electric_units_break_the_circuit_and_cannot_be_marked() -> void:
	_open_grid(0, 4, 0, 0)
	var caster := _unit("shrieker", Enums.UnitFaction.ENEMY)
	var victim := _unit("victim", Enums.UnitFaction.PLAYER)
	var charged := _unit("charged", Enums.UnitFaction.PLAYER, Enums.ElementalType.ELECTRIC)
	var behind := _unit("behind", Enums.UnitFaction.PLAYER)
	_place(caster, 0, 0)
	_place(victim, 2, 0)
	_place(charged, 3, 0)
	_place(behind, 4, 0)
	var shriek: Move = MoveData.get_move("Shriek of the Damned")
	assert_false(ScheduledEffects.schedule(caster, charged, shriek),
		"lightning can't take hold on the already-charged — no mark, no entry")
	ScheduledEffects.schedule(caster, victim, shriek)

	await ScheduledEffects.tick_faction_phase(Enums.UnitFaction.ENEMY,
			[caster, victim, charged, behind])
	assert_eq(victim.current_hp, 14, "the marked unit still takes its 6")
	assert_eq(charged.current_hp, 20, "electric types are immune to every hop")
	assert_eq(behind.current_hp, 20, "…and the broken circuit can't reach past them")


func test_brave_units_are_skipped_by_arcs() -> void:
	_open_grid(0, 4, 0, 0)
	var caster := _unit("shrieker", Enums.UnitFaction.ENEMY)
	var victim := _unit("victim", Enums.UnitFaction.PLAYER)
	var brave := _unit("brave", Enums.UnitFaction.PLAYER, Enums.ElementalType.CHIVALRIC)
	_place(caster, 0, 0)
	_place(victim, 2, 0)
	_place(brave, 3, 0)
	ScheduledEffects.schedule(caster, victim, MoveData.get_move("Shriek of the Damned"))

	await ScheduledEffects.tick_faction_phase(Enums.UnitFaction.ENEMY, [caster, victim, brave])
	assert_eq(brave.current_hp, 20, "the move's brave-immunity rides every arc")


func test_tied_chains_pick_one_fork_not_both() -> void:
	# A symmetric fork: budget 2 but only single-hop paths exist on each side,
	# so the longest chains are [victim, left] and [victim, right] — GameRng
	# picks ONE. Whichever it is, exactly one fork takes the arc.
	_open_grid(0, 4, 0, 2)
	var caster := _unit("shrieker", Enums.UnitFaction.ENEMY)
	var victim := _unit("victim", Enums.UnitFaction.PLAYER)
	var left := _unit("left", Enums.UnitFaction.PLAYER)
	var right := _unit("right", Enums.UnitFaction.PLAYER)
	_place(caster, 0, 2)  # Chebyshev 2 from everyone — never a link in the chain
	_place(victim, 2, 0)
	_place(left, 1, 0)
	_place(right, 3, 0)
	ScheduledEffects.schedule(caster, victim, MoveData.get_move("Shriek of the Damned"))

	await ScheduledEffects.tick_faction_phase(Enums.UnitFaction.ENEMY,
			[caster, victim, left, right])
	assert_eq(victim.current_hp, 14, "the marked unit always takes the full 6")
	var left_struck: bool = left.current_hp < 20
	var right_struck: bool = right.current_hp < 20
	assert_ne(left_struck, right_struck,
		"exactly one fork is struck — the bolt picks a path, it doesn't split")
	assert_eq(mini(left.current_hp, right.current_hp), 17,
		"the struck fork takes arc-1 damage (3) — the second arc had nowhere to go")


func test_tied_chains_replay_identically_under_the_seeded_die() -> void:
	# Save-determinism contract: restore the SAME GameRng state, refire the
	# same tied strike, get the same fork. (Seeded reloads replay the bolt.)
	_open_grid(0, 4, 0, 2)
	var caster := _unit("shrieker", Enums.UnitFaction.ENEMY)
	var victim := _unit("victim", Enums.UnitFaction.PLAYER)
	var left := _unit("left", Enums.UnitFaction.PLAYER)
	var right := _unit("right", Enums.UnitFaction.PLAYER)
	_place(caster, 0, 2)
	_place(victim, 2, 0)
	_place(left, 1, 0)
	_place(right, 3, 0)
	var shriek: Move = MoveData.get_move("Shriek of the Damned")
	var dice: Dictionary = GameRng.capture_state()

	ScheduledEffects.schedule(caster, victim, shriek)
	await ScheduledEffects.tick_faction_phase(Enums.UnitFaction.ENEMY,
			[caster, victim, left, right])
	var left_struck_first_run: bool = left.current_hp < 20

	victim.current_hp = 20
	left.current_hp = 20
	right.current_hp = 20
	GameRng.restore_state(dice)
	ScheduledEffects.schedule(caster, victim, shriek)
	await ScheduledEffects.tick_faction_phase(Enums.UnitFaction.ENEMY,
			[caster, victim, left, right])
	assert_eq(left.current_hp < 20, left_struck_first_run,
		"same dice state, same bolt — the tie-break replays identically")


func test_double_shriek_arcs_deeper_instead_of_striking_twice() -> void:
	_open_grid(0, 6, 0, 0)
	var caster := _unit("shrieker", Enums.UnitFaction.ENEMY)
	var victim := _unit("victim", Enums.UnitFaction.PLAYER)
	var chain_units: Array[Unit] = []
	_place(caster, 0, 0)
	_place(victim, 2, 0)
	for i: int in range(4):
		var link := _unit("link %d" % i, Enums.UnitFaction.PLAYER)
		_place(link, 3 + i, 0)
		chain_units.append(link)
	var shriek: Move = MoveData.get_move("Shriek of the Damned")
	ScheduledEffects.schedule(caster, victim, shriek)
	ScheduledEffects.schedule(caster, victim, shriek)
	assert_eq(_stacks(victim, "CHAIN_LIGHTNING"), 4, "re-marking restacks (2+2, capped at 4)")
	assert_eq(victim.scheduled_effects.size(), 2, "both entries queue…")

	var all_units: Array[Unit] = [caster, victim]
	all_units.append_array(chain_units)
	await ScheduledEffects.tick_faction_phase(Enums.UnitFaction.ENEMY, all_units)
	assert_eq(victim.current_hp, 14,
		"…but only ONE strike lands (the second finds no marker) — at the deeper budget")
	assert_eq(chain_units[0].current_hp, 17, "arc 1: half (3)")
	assert_eq(chain_units[1].current_hp, 19, "arc 2: quarter, floored (1)")
	assert_eq(chain_units[2].current_hp, 19, "arc 3: floored to the minimum (1)")
	assert_eq(chain_units[3].current_hp, 19, "arc 4: still minimum 1 — four stacks, five targets")
	assert_eq(victim.scheduled_effects.size(), 0, "both entries consumed")


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
	assert_eq(pending.get("stacks"), 2, "the arc budget re-coerced to int")
	assert_eq(_stacks(restored, "CHAIN_LIGHTNING"), 2, "the visible mark restored, stacks intact")

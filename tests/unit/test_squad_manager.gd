## Tests for SquadManager autoload — battle-start / battle-end hooks that
## mutate persistent CharacterData state across missions.
extends GutTest


# =============================================================================
# Battle-start move PP reset
# =============================================================================
# Regression: Move.reset_uses() existed but no caller — player units carried
# depleted PP from one mission into the next. SquadManager._on_battle_started
# now loops each player unit's equipped_moves and calls reset_uses().

func _make_move_at_uses(max_uses: int, current_uses: int) -> Move:
	var move := Move.new()
	move.max_uses = max_uses
	move.current_uses = current_uses
	return move


func _make_unit_with_moves(moves: Array) -> TestFakeUnit:
	var unit := TestFakeUnit.new()
	add_child_autofree(unit)
	var data := CharacterData.new()
	data.character_id = "test_subject"
	for move: Variant in moves:
		data.equipped_moves.append(move)
	unit.character_data = data
	return unit


func test_battle_start_refills_depleted_moves_to_max() -> void:
	var move := _make_move_at_uses(5, 1)  # depleted
	var unit := _make_unit_with_moves([move])

	SquadManager._on_battle_started([unit])

	assert_eq(move.current_uses, 5,
			"Depleted move refilled to max_uses at battle start")


func test_battle_start_refills_all_equipped_moves_independently() -> void:
	var move_a := _make_move_at_uses(3, 0)
	var move_b := _make_move_at_uses(8, 2)
	var move_c := _make_move_at_uses(10, 10)  # already full
	var unit := _make_unit_with_moves([move_a, move_b, move_c])

	SquadManager._on_battle_started([unit])

	assert_eq(move_a.current_uses, 3, "Move A refilled from 0")
	assert_eq(move_b.current_uses, 8, "Move B refilled from 2")
	assert_eq(move_c.current_uses, 10, "Move C unchanged (already full)")


func test_battle_start_handles_null_move_in_equipped_list() -> void:
	# Some character configs may have empty slots (Move.EMPTY or actual null).
	# The reset loop guards against null so a sparse list doesn't crash.
	var move := _make_move_at_uses(4, 1)
	var unit := _make_unit_with_moves([null, move])

	SquadManager._on_battle_started([unit])

	assert_eq(move.current_uses, 4,
			"Null slot skipped, valid move still refilled")


func test_battle_start_skips_units_without_character_data() -> void:
	# A unit whose character_data is null shouldn't crash the loop or block
	# subsequent units from being processed.
	var move := _make_move_at_uses(5, 0)
	var data_unit := _make_unit_with_moves([move])
	var null_unit := TestFakeUnit.new()
	add_child_autofree(null_unit)
	null_unit.character_data = null

	SquadManager._on_battle_started([null_unit, data_unit])

	assert_eq(move.current_uses, 5,
			"Subsequent unit's moves still refilled after null character_data")


func test_battle_start_handles_null_unit_in_list() -> void:
	# Defensive: a null entry in the units array shouldn't crash either.
	var move := _make_move_at_uses(5, 0)
	var unit := _make_unit_with_moves([move])

	SquadManager._on_battle_started([null, unit])

	assert_eq(move.current_uses, 5,
			"Null unit skipped, valid unit still processed")


# =============================================================================
# Battle-end injury tick ordering
# =============================================================================
# Regression: _on_battle_ended used to commit pending injuries and THEN tick
# recovery in the same pass, so the just-earned injury lost a recovery battle
# immediately — a 1-battle injury (same-type Minor) expired before the next
# mission ever started and was never seen in a fight. Recovery must tick on
# pre-existing injuries only, i.e. tick BEFORE commit.

const _TEST_CHARACTER_ID: String = "__test_injury_tick_ordering"


func after_each() -> void:
	SquadManager._roster_by_id.erase(_TEST_CHARACTER_ID)
	SquadManager._permadead_ids.erase(_TEST_CHARACTER_ID)


func _roster_character_with_pending_injury(battles_remaining: int) -> CharacterData:
	var data := CharacterData.new()
	data.character_id = _TEST_CHARACTER_ID
	data.character_name = "Tick Ordering Subject"
	var injury := Injury.new()
	injury.injury_id = "burn_scar"
	injury.severity = Enums.InjurySeverity.MINOR
	injury.battles_remaining = battles_remaining
	data.pending_injuries.append(injury)
	SquadManager._roster_by_id[_TEST_CHARACTER_ID] = data
	return data


func test_fresh_injury_is_not_ticked_in_the_battle_it_was_earned() -> void:
	var data := _roster_character_with_pending_injury(1)

	SquadManager._on_battle_ended(false)

	assert_eq(data.current_injuries.size(), 1,
			"Injury earned this battle committed and survives the same battle_ended pass")
	assert_eq(data.current_injuries[0].battles_remaining, 1,
			"Recovery counter untouched in the battle the injury was earned")


func test_one_battle_injury_recovers_after_exactly_one_more_battle() -> void:
	var data := _roster_character_with_pending_injury(1)

	SquadManager._on_battle_ended(false)
	SquadManager._on_battle_ended(false)

	assert_eq(data.current_injuries.size(), 0,
			"1-battle injury expires at the end of the NEXT battle, having been active in it")


func test_multi_battle_injury_counts_down_once_per_subsequent_battle() -> void:
	var data := _roster_character_with_pending_injury(4)

	SquadManager._on_battle_ended(false)
	assert_eq(data.current_injuries[0].battles_remaining, 4,
			"No tick on the earning battle")
	SquadManager._on_battle_ended(false)
	assert_eq(data.current_injuries[0].battles_remaining, 3,
			"One tick per battle after the earning one")


# =============================================================================
# Battle-end bEXP income (flat 150 retired 2026-08-03)
# =============================================================================
# Income is itemized award lines from MissionCatalog (par bands + objectives),
# summed into the pool. Outside a campaign the mission path is "" and the
# catalog serves defaults — ad-hoc battles still pay.

func _with_income_state_reset(callable: Callable) -> void:
	var saved_pool: int = SquadManager.bonus_xp_pool
	var saved_lines: Array[Dictionary] = SquadManager.last_mission_award_lines
	var saved_turns: int = TurnManager.turn_count
	callable.call()
	SquadManager.bonus_xp_pool = saved_pool
	SquadManager.last_mission_award_lines = saved_lines
	TurnManager.turn_count = saved_turns


func test_fast_victory_banks_both_par_bands_into_the_pool() -> void:
	_with_income_state_reset(func() -> void:
		SquadManager.bonus_xp_pool = 0
		TurnManager.turn_count = 1  # under any par
		SquadManager._on_battle_ended(true)
		assert_eq(SquadManager.bonus_xp_pool,
				MissionCatalog.NO_DAWDLING_BEXP + MissionCatalog.ABOVE_PAR_BEXP,
				"victory income = sum of the itemized lines, not a flat grant")
		assert_eq(SquadManager.last_mission_award_lines.size(), 2,
				"itemized lines kept for the result screen to render verbatim"))


# =============================================================================
# bEXP level pricing (price-tag model, 2026-08-03)
# =============================================================================
# Cost = BASE × level ÷ squad_max_level, rounded to COST_STEP, floor MIN.
# Continuous — no threshold cliff — and the player only ever sees the price.

const _ANCHOR_ID: String = "__test_bexp_anchor"
const _SUBJECT_ID: String = "__test_bexp_subject"


func _roster_pair(anchor_level: int, subject_level: int) -> CharacterData:
	# The anchor dominates any realistic level in the default roster, making
	# the squad-max term deterministic without emptying the real roster.
	var anchor := CharacterData.new()
	anchor.character_id = _ANCHOR_ID
	anchor.level = anchor_level
	SquadManager._roster_by_id[_ANCHOR_ID] = anchor
	var subject := CharacterData.new()
	subject.character_id = _SUBJECT_ID
	subject.level = subject_level
	SquadManager._roster_by_id[_SUBJECT_ID] = subject
	return subject


func _cleanup_roster_pair() -> void:
	SquadManager._roster_by_id.erase(_ANCHOR_ID)
	SquadManager._roster_by_id.erase(_SUBJECT_ID)


func test_bexp_price_scales_with_level_relative_to_squad_max() -> void:
	var subject := _roster_pair(100, 60)
	assert_eq(SquadManager.bexp_level_cost(subject), 60,
			"60% of the squad max pays 60% of base price")
	var anchor: CharacterData = SquadManager._roster_by_id[_ANCHOR_ID]
	assert_eq(SquadManager.bexp_level_cost(anchor), SquadManager.BEXP_BASE_LEVEL_COST,
			"the squad's top unit always pays full price")
	_cleanup_roster_pair()


func test_bexp_price_rounds_to_clean_steps_and_floors() -> void:
	var subject := _roster_pair(100, 33)
	assert_eq(SquadManager.bexp_level_cost(subject), 35,
			"33 rounds to the nearest clean 5 — a price tag, not arithmetic soup")
	subject.level = 10
	assert_eq(SquadManager.bexp_level_cost(subject), SquadManager.BEXP_MIN_LEVEL_COST,
			"deep underlevel hits the floor — catching up is cheap, never free")
	_cleanup_roster_pair()


func test_buying_a_level_charges_the_price_and_levels_once() -> void:
	_with_income_state_reset(func() -> void:
		var subject := _roster_pair(100, 60)
		SquadManager.bonus_xp_pool = 100
		subject.experience = 40
		assert_true(SquadManager.buy_bexp_level(subject), "pool 100 covers price 60")
		assert_eq(SquadManager.bonus_xp_pool, 40, "exactly the price deducted")
		assert_eq(subject.level, 61, "one whole level bought")
		assert_eq(subject.experience, 40,
				"partial combat XP untouched — 40/100 carries into the new level")
		_cleanup_roster_pair())


func test_buying_beyond_the_pool_is_refused() -> void:
	_with_income_state_reset(func() -> void:
		var subject := _roster_pair(100, 60)
		SquadManager.bonus_xp_pool = 59
		assert_false(SquadManager.buy_bexp_level(subject), "pool 59 can't cover price 60")
		assert_eq(SquadManager.bonus_xp_pool, 59, "refused purchase deducts nothing")
		assert_eq(subject.level, 60, "refused purchase levels nothing")
		_cleanup_roster_pair())


func test_defeat_banks_nothing_and_clears_the_award_lines() -> void:
	_with_income_state_reset(func() -> void:
		SquadManager.bonus_xp_pool = 40
		SquadManager.last_mission_award_lines = [{"label": "stale", "amount": 1}] as Array[Dictionary]
		TurnManager.turn_count = 1
		SquadManager._on_battle_ended(false)
		assert_eq(SquadManager.bonus_xp_pool, 40, "defeat adds no income")
		assert_eq(SquadManager.last_mission_award_lines.size(), 0,
				"stale lines from the previous mission can't leak into this result screen"))

## CombatXpCalculator + the Unit-side award paths. The RD hit formula
## predates the tests policy — pinned here for the first time alongside the
## 2026-08-03 additions (support-cast XP, survival XP). Doctrine:
## [.claude/mission_objectives.md] "XP Economy".
extends GutTest


const SPACEMAN_PATH: String = "res://data/characters/spaceman.json"
const GRUNT_PATH: String = "res://data/characters/grunt.json"

var _saved_motion: bool = true


func before_each() -> void:
	_saved_motion = Settings.ui_motion_enabled


func after_each() -> void:
	Settings.ui_motion_enabled = _saved_motion


func _data(level: int) -> CharacterData:
	var data := CharacterData.new()
	data.level = level
	return data


# =============================================================================
# HIT FORMULA (exponential decay — the field rubber band)
# =============================================================================
# xp = base * 2 ^ ((their_level - your_level) / K), floored at MIN_XP.
# These assert the SHAPE, not the dials — every constant below is provisional
# and expected to move in playtest, so tests read them from the calculator
# rather than hardcoding numbers that would turn every tuning pass into a
# test-fixing pass.

func test_an_even_fight_pays_exactly_the_base() -> void:
	assert_eq(CombatXpCalculator.compute_combat_xp(_data(15), _data(15), true),
			CombatXpCalculator.KILL_BASE_XP,
			"on-level kill pays the kill base — true at every level, which is what")
	assert_eq(CombatXpCalculator.compute_combat_xp(_data(50), _data(50), true),
			CombatXpCalculator.KILL_BASE_XP,
			"makes on-level pacing independent of where you are on the curve")
	assert_eq(CombatXpCalculator.compute_combat_xp(_data(15), _data(15), false),
			CombatXpCalculator.HIT_BASE_XP,
			"a chip hit pays the hit base")


func test_the_gap_that_doubles_actually_doubles() -> void:
	# The defining property of the formula. One K of gap up = 2x, one K down =
	# half. If someone swaps the exponential back for a difference or a ratio,
	# this is the test that catches it.
	var gap: int = int(CombatXpCalculator.LEVEL_GAP_TO_DOUBLE)
	var even: int = CombatXpCalculator.compute_combat_xp(_data(30), _data(30), true)
	assert_eq(CombatXpCalculator.compute_combat_xp(_data(30 - gap), _data(30), true),
			even * 2,
			"a rookie K levels down earns double")
	assert_eq(CombatXpCalculator.compute_combat_xp(_data(30 + gap), _data(30), true),
			even / 2,
			"the carry K levels up earns half")


func test_the_rookie_premium_is_the_funnel() -> void:
	# The argument that chose exponential over the difference formula it
	# replaced: at squad mean 25, the spread between rookie and carry has to be
	# wide enough to pay for a rookie's real cost — fewer kills, injury risk.
	# The difference formula only managed 1.5x. Assert the multiple, not the
	# XP values, so tuning K keeps this honest without rewriting it.
	var rookie: int = CombatXpCalculator.compute_combat_xp(_data(10), _data(25), true)
	var carry: int = CombatXpCalculator.compute_combat_xp(_data(40), _data(25), true)
	assert_gt(float(rookie) / float(carry), 3.0,
			"a 15-down rookie earns >3x a 15-up carry from the same enemy")


func test_overleveled_gains_decay_hard_but_never_to_zero() -> void:
	# Note the floor is DECORATIVE at K=15: the steepest decay the level range
	# allows (Lv 60 farming Lv 1) still pays 5 on a kill, never reaching MIN_XP.
	# So "the carry stalls" means ~20 kills a level, not zero — real diminishing
	# returns, not a wall. If a K change ever makes MIN_XP bind, that's a signal
	# the curve got steep enough to feel like punishment.
	var worst_kill: int = CombatXpCalculator.compute_combat_xp(_data(60), _data(1), true)
	var even_kill: int = CombatXpCalculator.compute_combat_xp(_data(60), _data(60), true)
	assert_gte(worst_kill, CombatXpCalculator.MIN_XP,
			"every action pays something — the you-did-something floor holds")
	assert_lt(float(worst_kill) / float(even_kill), 0.1,
			"but farming scrubs pays under a tenth of a fair fight")


func test_a_kill_outpays_a_chip_hit_at_the_same_gap() -> void:
	assert_gt(CombatXpCalculator.compute_combat_xp(_data(5), _data(15), true),
			CombatXpCalculator.compute_combat_xp(_data(5), _data(15), false),
			"the same decay applies to both bases, so a kill always wins")


func test_the_jackpot_is_bounded_by_the_level_range_alone() -> void:
	# MAX_XP was retired on the grounds that 1-60 bounds the formula on its
	# own. This pins the most extreme kill in the game so a future K change
	# can't quietly turn one boss kill into a full 60-level unit.
	var jackpot: int = CombatXpCalculator.compute_combat_xp(_data(1), _data(60), true)
	assert_lt(jackpot, 6000, "the biggest possible kill is under 60 levels' worth")
	assert_gt(jackpot, 100, "but it is still a jackpot — more than one level")


func test_tier_never_touches_the_award() -> void:
	# TIER_LEVEL_BOOST was deleted because our levels are continuous 1-60 with
	# no reset on promotion; the FE-style internal-level term would have cut
	# kill XP ~70% at levels 21 and 41. Class choice is a build decision, never
	# a leveling one — so tier must stay out of this math permanently.
	var low_tier: CharacterData = _data(25)
	low_tier.tier = 1
	var high_tier: CharacterData = _data(25)
	high_tier.tier = 3
	assert_eq(CombatXpCalculator.compute_combat_xp(high_tier, _data(25), true),
			CombatXpCalculator.compute_combat_xp(low_tier, _data(25), true),
			"promoting must not change what a unit earns from the same enemy")


# =============================================================================
# SUPPORT XP (once per cast — participation without harm's way)
# =============================================================================

func test_support_cast_pays_the_flat_heal_sized_rate() -> void:
	assert_eq(CombatXpCalculator.compute_support_xp(_data(10), null),
			CombatXpCalculator.SUPPORT_XP,
			"buff/cleanse casts pay the same flat rate as a staff heal")


# =============================================================================
# SURVIVAL XP (level-diff scaled, clamped small)
# =============================================================================

func test_survival_xp_scales_with_attacker_scariness() -> void:
	assert_eq(CombatXpCalculator.compute_survival_xp(_data(10), _data(10)),
			CombatXpCalculator.SURVIVAL_BASE_XP,
			"an on-level enemy pays the survival base")
	assert_eq(CombatXpCalculator.compute_survival_xp(_data(10), _data(16)), 11,
			"a scarier enemy pays base + diff")
	assert_eq(CombatXpCalculator.compute_survival_xp(_data(10), _data(40)),
			CombatXpCalculator.SURVIVAL_MAX_XP,
			"terror caps well under a hit award")
	assert_eq(CombatXpCalculator.compute_survival_xp(_data(30), _data(5)),
			CombatXpCalculator.MIN_XP,
			"a harmless enemy decays to the floor — stall fuel is ~1 XP, once")


# =============================================================================
# UNIT AWARD PATHS (first-engagement memory, faction guards)
# =============================================================================

func _spawn_unit(json_path: String, faction: Enums.UnitFaction) -> Unit:
	var unit: Unit = (load("res://scenes/battle/unit.tscn") as PackedScene).instantiate() as Unit
	unit.character_json_path = json_path
	unit.faction = faction
	# Each unit gets its own parent container so popup scans (_callout_texts
	# walks the unit's parent) can't see callouts spawned by a previous test
	# in this script — popups outlive their test by ~a second.
	var container := Node2D.new()
	add_child_autofree(container)
	container.add_child(unit)
	var tile: Tile = autofree(Tile.new())
	tile.grid_x = 0
	tile.grid_y = 0
	unit.initialize(tile)
	return unit


func test_survival_xp_pays_the_first_engagement_only() -> void:
	var survivor := _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER)
	var enemy := _spawn_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY)
	var expected: int = CombatXpCalculator.compute_survival_xp(
			survivor.character_data, enemy.character_data)

	survivor._award_survival_xp(enemy)
	assert_eq(survivor.character_data.experience, expected,
			"first engagement from this enemy pays")
	survivor._award_survival_xp(enemy)
	assert_eq(survivor.character_data.experience, expected,
			"the same enemy can't teach the same lesson twice — no stall farming")


func test_survival_xp_pays_again_for_a_new_attacker() -> void:
	var survivor := _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER)
	var first := _spawn_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY)
	var second := _spawn_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY)

	survivor._award_survival_xp(first)
	var after_first: int = survivor.character_data.experience
	survivor._award_survival_xp(second)
	assert_gt(survivor.character_data.experience, after_first,
			"a NEW enemy engaging is a new lesson — farming more requires the fight to advance")


func test_survival_xp_ignores_enemy_defenders_and_friendly_attackers() -> void:
	var enemy := _spawn_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY)
	var player := _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER)
	enemy._award_survival_xp(player)
	assert_eq(enemy.character_data.experience, 0, "enemies never earn XP")

	var ally_target := _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER)
	ally_target._award_survival_xp(player)
	assert_eq(ally_target.character_data.experience, 0,
			"a friendly attacker (corruption redirect) isn't an enemy engagement")


func test_support_award_is_player_only() -> void:
	var caster := _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER)
	caster._award_support_xp(null)
	assert_eq(caster.character_data.experience, CombatXpCalculator.SUPPORT_XP,
			"player support cast pays flat")

	var enemy := _spawn_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY)
	enemy._award_support_xp(null)
	assert_eq(enemy.character_data.experience, 0, "enemy casts pay nothing")


# =============================================================================
# XP FEEDBACK (batched "+N XP" callout + LEVEL UP! beat)
# =============================================================================

func _callout_texts(unit: Unit) -> Array:
	var texts: Array = []
	for child: Node in unit.get_parent().get_children():
		if child is DamagePopup and child._damage_label != null:
			texts.append(child._damage_label.text)
	return texts


func test_xp_feedback_batches_the_whole_combat_into_one_popup() -> void:
	var unit := _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER)
	unit._grant_combat_xp(12)
	unit._grant_combat_xp(5)
	assert_eq(unit._combat_xp_gained, 17, "grants accumulate across the sequence")

	await unit._flush_xp_feedback()
	assert_has(_callout_texts(unit), "+17 XP",
			"ONE gold callout for the whole combat — a 4-hit chain doesn't spam four")
	assert_eq(unit._combat_xp_gained, 0, "flush resets the accumulator")


func test_level_up_gets_its_own_callout_beat() -> void:
	var unit := _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER)
	unit._grant_combat_xp(100)
	assert_eq(unit._combat_levels_gained, 1, "the 100-XP threshold leveled mid-combat")

	# Fire-and-forget: the flush now ALSO awaits the LevelUpStatPanel reveal
	# (RQD 2026-08-11), which outlives the callouts' float animation — waiting
	# for the whole flush finds only freed popups. Sample at the callout beat.
	unit._flush_xp_feedback()
	await get_tree().create_timer(0.7).timeout
	var texts: Array = _callout_texts(unit)
	assert_has(texts, "+100 XP")
	assert_has(texts, "LEVEL UP!",
			"the callout still lands its beat before the stat reveal takes over")


func test_flush_with_nothing_earned_stays_silent() -> void:
	var unit := _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER)
	await unit._flush_xp_feedback()
	assert_eq(_callout_texts(unit).size(), 0, "no XP, no popup — enemies' combats stay quiet")


# =============================================================================
# ON-MAP XP BAR (RQD 2026-08-21, todo #1)
# =============================================================================
# A yellow-on-black bar the health bar's size, one pixel beneath it, that
# fades in, sweeps from the pre-combat XP to the new total (wrapping with a
# flash on a level-up), holds, fades out. The sweep plan is pure; the
# renderer is probed under reduce-motion where it parks deterministically.

func test_xp_threshold_is_one_constant_everywhere() -> void:
	# grant_xp, the bar, the sheet, and the bEXP screen used to each hardcode
	# 100 with a "keep in sync" comment. Now there is one owner.
	assert_eq(CharacterData.XP_PER_LEVEL, 100, "RD's flat threshold")
	assert_eq(BexpSpendPanel.XP_PER_LEVEL, CharacterData.XP_PER_LEVEL,
			"the bEXP screen reads the same constant")
	var data := CharacterData.new()
	assert_eq(data.grant_xp(CharacterData.XP_PER_LEVEL), 1, "exactly one threshold = one level")
	assert_eq(data.experience, 0)


func test_xp_bar_sweep_plan_without_a_level_is_one_segment() -> void:
	var segments := Unit.xp_bar_fill_segments(40, 65, 0)
	assert_eq(segments.size(), 1)
	assert_almost_eq(segments[0][0], 0.40, 0.001, "starts at the pre-combat fraction")
	assert_almost_eq(segments[0][1], 0.65, 0.001, "lands on the new fraction")


func test_xp_bar_sweep_plan_wraps_once_per_level_gained() -> void:
	var one := Unit.xp_bar_fill_segments(90, 20, 1)
	assert_eq(one.size(), 2, "fill to full, then restart to the remainder")
	assert_almost_eq(one[0][0], 0.90, 0.001)
	assert_almost_eq(one[0][1], 1.0, 0.001, "first segment fills the bar")
	assert_almost_eq(one[1][0], 0.0, 0.001, "second starts from empty")
	assert_almost_eq(one[1][1], 0.20, 0.001)

	var two := Unit.xp_bar_fill_segments(90, 5, 2)
	assert_eq(two.size(), 3, "a double level-up sweeps a whole extra bar")
	assert_almost_eq(two[1][0], 0.0, 0.001)
	assert_almost_eq(two[1][1], 1.0, 0.001)
	assert_almost_eq(two[2][1], 0.05, 0.001)


func test_xp_bar_sweep_plan_clamps_garbage() -> void:
	var segments := Unit.xp_bar_fill_segments(-5, 250, 0)
	assert_almost_eq(segments[0][0], 0.0, 0.001)
	assert_almost_eq(segments[0][1], 1.0, 0.001)


func test_xp_bar_is_built_under_the_health_bar_and_hidden_at_rest() -> void:
	var unit := _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER)
	assert_not_null(unit._xp_bar, "the bar exists from initialize")
	assert_eq(unit._xp_bar.get_parent(), unit._health_bar, "it rides the health bar")
	assert_false(unit._xp_bar.visible, "…and shows nothing until XP lands")
	assert_gt(unit._xp_bar_fill.position.y, 1.0,
			"parked BENEATH the health bar (which spans y -1..1) — RQD's call")
	assert_eq(unit._xp_bar_fill.size, Vector2(Unit.XP_BAR_WIDTH, Unit.XP_BAR_HEIGHT),
			"same footprint as the health bar")


func test_xp_bar_remembers_where_the_sequence_started() -> void:
	var unit := _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER)
	unit.character_data.experience = 40
	assert_eq(unit._xp_before_sequence, -1, "no sequence open yet")
	unit._grant_combat_xp(12)
	unit._grant_combat_xp(5)
	assert_eq(unit._xp_before_sequence, 40,
			"first grant opens the sequence; later grants don't move the start")
	unit._flush_xp_feedback()
	assert_eq(unit._xp_before_sequence, -1, "flush closes the sequence")


func test_xp_bar_parks_on_the_landing_fraction_under_reduce_motion() -> void:
	Settings.ui_motion_enabled = false
	var unit := _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER)
	unit.character_data.experience = 40
	unit._grant_combat_xp(25)
	unit._flush_xp_feedback()
	assert_true(unit._xp_bar.visible, "the bar shows for the hold")
	assert_almost_eq(unit._xp_bar_fill.scale.x, 0.65, 0.001,
			"reduce-motion snaps straight to 65/100 — no sweep")
	await wait_seconds(Unit.XP_BAR_HOLD_SECONDS + 0.15)
	assert_false(unit._xp_bar.visible, "…then hides")


func test_xp_bar_sweeps_and_fades_with_motion_on() -> void:
	Settings.ui_motion_enabled = true
	var unit := _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER)
	unit.character_data.experience = 10
	unit._grant_combat_xp(60)
	unit._flush_xp_feedback()
	assert_true(unit._xp_bar.visible)
	assert_almost_eq(unit._xp_bar_fill.scale.x, 0.10, 0.001, "the sweep begins where the unit stood")
	var total: float = Unit.XP_BAR_FADE_IN_SECONDS + Unit.XP_BAR_FILL_SECONDS_PER_LEVEL \
			+ Unit.XP_BAR_HOLD_SECONDS + Unit.XP_BAR_FADE_OUT_SECONDS
	await wait_seconds(total + 0.3)
	assert_almost_eq(unit._xp_bar_fill.scale.x, 0.70, 0.001, "landed on 70/100")
	assert_false(unit._xp_bar.visible, "faded out and hidden")


func test_a_newer_xp_bar_play_takes_over_the_older_one() -> void:
	Settings.ui_motion_enabled = true
	var unit := _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER)
	unit._play_xp_bar(0, 50, 0)
	var first_serial: int = unit._xp_bar_serial
	unit._play_xp_bar(50, 80, 0)
	assert_eq(unit._xp_bar_serial, first_serial + 1, "each play bumps the serial")
	assert_true(unit._xp_bar.visible)
	await wait_seconds(Unit.XP_BAR_FADE_IN_SECONDS + Unit.XP_BAR_FILL_SECONDS_PER_LEVEL + 0.2)
	assert_almost_eq(unit._xp_bar_fill.scale.x, 0.80, 0.001,
			"the second play owns the bar — the first tween was killed")


# =============================================================================
# XP FEEDBACK ON EARLY-ENDED EXCHANGES (found building the presenter seam)
# =============================================================================
# A kill on hit 1 or counter 1 ends the exchange early — no bonus hits, no
# survival XP. The killer's XP feedback must still flush THEN: before this
# was pinned, the most common kill shape hid its +XP callout and level-up
# celebration until the killer's next exchange.

func _lethal_probe(power: int) -> Move:
	var move := Move.new()
	move.move_name = "Probe"
	move.base_power = power
	move.accuracy = 500  # clamps to 100 — always lands
	move.damage_type = Enums.DamageType.PHYSICAL
	move.attack_range = 1
	move.max_uses = 5
	move.current_uses = 5
	return move


func test_a_first_hit_kill_flushes_the_killers_xp_in_the_same_exchange() -> void:
	var killer := _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER)
	var victim := _spawn_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY)
	victim.current_hp = 1
	var expected: int = CombatXpCalculator.compute_combat_xp(
			killer.character_data, victim.character_data, true)
	await killer.execute_combat_sequence(victim, _lethal_probe(5), RecordingPresenter.new())
	assert_true(victim.is_defeated(), "precondition: the first hit killed")
	assert_eq(killer._combat_xp_gained, 0, "the kill's XP flushed at the end of THIS exchange")
	assert_has(_callout_texts(killer), "+%d XP" % expected,
			"the +XP callout floats now, not after the killer's next fight")


func test_a_counter_kill_flushes_the_defenders_xp_in_the_same_exchange() -> void:
	var attacker := _spawn_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY)
	var defender := _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER)
	attacker.current_hp = 1
	defender.assigned_move = _lethal_probe(5)
	var expected: int = CombatXpCalculator.compute_combat_xp(
			defender.character_data, attacker.character_data, true)
	await attacker.execute_combat_sequence(defender, _lethal_probe(1), RecordingPresenter.new())
	assert_true(attacker.is_defeated(), "precondition: counter 1 killed the attacker")
	assert_false(defender.is_defeated(), "precondition: the defender survived hit 1")
	assert_eq(defender._combat_xp_gained, 0, "the counter-kill's XP flushed at the end of THIS exchange")
	assert_has(_callout_texts(defender), "+%d XP" % expected)

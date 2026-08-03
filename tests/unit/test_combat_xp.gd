## CombatXpCalculator + the Unit-side award paths. The RD hit formula
## predates the tests policy — pinned here for the first time alongside the
## 2026-08-03 additions (support-cast XP, survival XP). Doctrine:
## [.claude/mission_objectives.md] "XP Economy".
extends GutTest


const SPACEMAN_PATH: String = "res://data/characters/spaceman.json"
const GRUNT_PATH: String = "res://data/characters/grunt.json"


func _data(level: int) -> CharacterData:
	var data := CharacterData.new()
	data.level = level
	return data


# =============================================================================
# HIT FORMULA (RD differential — the field rubber band)
# =============================================================================

func test_hit_xp_scales_with_level_differential() -> void:
	assert_eq(CombatXpCalculator.compute_combat_xp(_data(5), _data(15), false), 20,
			"underleveled attacker earns base + diff (10 + 10)")
	assert_eq(CombatXpCalculator.compute_combat_xp(_data(15), _data(15), false), 10,
			"even match earns base")
	assert_eq(CombatXpCalculator.compute_combat_xp(_data(20), _data(15), false), 5,
			"overleveled attacker earns base - diff")


func test_overleveled_gains_decay_to_the_floor_never_zero() -> void:
	assert_eq(CombatXpCalculator.compute_combat_xp(_data(40), _data(5), false),
			CombatXpCalculator.MIN_XP,
			"the carry one-shotting scrubs earns the you-did-something floor")


func test_kill_bonus_stacks_on_the_differential() -> void:
	assert_eq(CombatXpCalculator.compute_combat_xp(_data(5), _data(15), true), 40,
			"kill adds +20 on top of base + diff")


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

	await unit._flush_xp_feedback()
	var texts: Array = _callout_texts(unit)
	assert_has(texts, "+100 XP")
	assert_has(texts, "LEVEL UP!",
			"mid-battle level-ups announce themselves — the full stat reveal still waits for mission end")


func test_flush_with_nothing_earned_stays_silent() -> void:
	var unit := _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER)
	await unit._flush_xp_feedback()
	assert_eq(_callout_texts(unit).size(), 0, "no XP, no popup — enemies' combats stay quiet")

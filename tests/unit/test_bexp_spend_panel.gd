## BexpSpendPanel — the POUR spec (todo.md subtask + the mockup's "amounts"
## style, restored RQD 2026-08-13): [-100][-10][-1][+1][+10][99][+100] stage
## refundable arithmetic per unit; CONFIRM is the one commit and rolls each
## crossed level with bEXP mechanics; the remainder persists as real XP
## (the 99 brink button's whole reason to exist). Leaving discards the stage.
extends GutTest


var _saved_pool: int = 0
var _saved_motion: bool = true


func before_each() -> void:
	_saved_pool = SquadManager.bonus_xp_pool
	_saved_motion = Settings.ui_motion_enabled
	# Reduced motion keeps the awaited confirm path fast under GUT.
	Settings.ui_motion_enabled = false


func after_each() -> void:
	SquadManager.bonus_xp_pool = _saved_pool
	Settings.ui_motion_enabled = _saved_motion


func _unit(id: String = "pour_test") -> CharacterData:
	var data := CharacterData.new()
	data.character_id = id
	data.character_name = "Bench Test"
	data.level = 3
	data.base_max_hp = 20
	return data


func _bound_panel(unit: CharacterData) -> BexpSpendPanel:
	var panel := BexpSpendPanel.new()
	add_child_autofree(panel)
	panel.bind(unit)
	return panel


# =============================================================================
# PURE POUR MATH
# =============================================================================

func test_clamp_pour_floors_refunds_and_ceilings_at_the_pool() -> void:
	assert_eq(BexpSpendPanel.clamp_pour(0, 10, 250), 10)
	assert_eq(BexpSpendPanel.clamp_pour(5, -100, 250), 0, "refunds floor at zero staged")
	assert_eq(BexpSpendPanel.clamp_pour(40, 100, 30), 70,
			"a pour past the pool takes what's actually left")
	assert_eq(BexpSpendPanel.clamp_pour(40, -10, 0), 30,
			"refunds work even with the pool preview at zero")


func test_the_brink_parks_the_gauge_at_99() -> void:
	assert_eq(BexpSpendPanel.brink_amount(0), 99)
	assert_eq(BexpSpendPanel.brink_amount(40), 59)
	assert_eq(BexpSpendPanel.brink_amount(99), 0, "already at the brink")


func test_previews_wrap_levels_and_remainder() -> void:
	assert_eq(BexpSpendPanel.preview_levels(40, 160), 2)
	assert_eq(BexpSpendPanel.preview_xp(40, 160), 0)
	assert_eq(BexpSpendPanel.preview_levels(40, 59), 0)
	assert_eq(BexpSpendPanel.preview_xp(40, 59), 99)


# =============================================================================
# STAGING — arithmetic only, nothing commits
# =============================================================================

func test_pouring_stages_a_preview_and_touches_nothing_real() -> void:
	SquadManager.bonus_xp_pool = 250
	var unit := _unit()
	var panel := _bound_panel(unit)
	panel._on_pour_pressed(10)
	panel._on_pour_pressed(1)
	assert_eq(panel._staged_for_bound(), 11)
	assert_eq(SquadManager.bonus_xp_pool, 250, "the real pool is untouched until CONFIRM")
	assert_eq(unit.level, 3)
	assert_eq(unit.experience, 0)
	assert_eq(panel._pool_value_label.text, "239", "the readout shows the preview pool")
	assert_eq(panel._xp_value_label.text, "11/100")


func test_the_brink_button_stages_exactly_to_99() -> void:
	SquadManager.bonus_xp_pool = 250
	var unit := _unit()
	unit.experience = 40
	var panel := _bound_panel(unit)
	panel._on_brink_pressed()
	assert_eq(panel._staged_for_bound(), 59)
	assert_eq(panel._xp_value_label.text, "99/100")


func test_a_staged_level_previews_on_the_ident_line() -> void:
	SquadManager.bonus_xp_pool = 250
	var panel := _bound_panel(_unit())
	panel._on_pour_pressed(100)
	assert_eq(panel._level_value_label.text, "Lv 3 → 4",
			"the will-be level, marked uncommitted")


func test_leaving_discards_the_stage() -> void:
	SquadManager.bonus_xp_pool = 250
	var unit := _unit()
	var panel := _bound_panel(unit)
	panel._on_pour_pressed(100)
	panel.discard_stage()
	assert_eq(panel._staged_for_bound(), 0)
	assert_eq(SquadManager.bonus_xp_pool, 250)
	assert_eq(unit.level, 3, "nothing rolled — the stage was only ever arithmetic")


# =============================================================================
# CONFIRM — the one commit
# =============================================================================

func test_confirm_rolls_the_level_and_keeps_the_remainder_as_real_xp() -> void:
	SquadManager.bonus_xp_pool = 250
	var unit := _unit()
	unit.experience = 40
	var panel := _bound_panel(unit)
	watch_signals(panel)
	panel._on_pour_pressed(100)
	panel._on_pour_pressed(10)
	await panel._on_confirm_pressed()
	assert_eq(unit.level, 4, "one crossed threshold, one bEXP-mechanics level")
	assert_eq(unit.experience, 50, "the remainder persists as REAL XP — RD semantics")
	assert_eq(SquadManager.bonus_xp_pool, 140)
	assert_eq(panel._staged_for_bound(), 0)
	assert_signal_emitted(panel, "changed")
	assert_false(panel._revealing)


func test_confirm_commits_every_staged_unit_not_just_the_bound_one() -> void:
	SquadManager.bonus_xp_pool = 300
	var bound := _unit("pour_bound")
	var other := _unit("pour_other")
	# The other unit must resolve through SquadManager for its silent commit
	# (get_active_roster returns a copy, so register on the real index).
	SquadManager._roster_by_id[other.character_id] = other
	var panel := _bound_panel(other)
	panel._on_pour_pressed(100)
	panel.bind(bound)
	panel._on_pour_pressed(50)
	assert_eq(panel._pool_value_label.text, "150",
			"the preview pool carries every unit's stage")
	await panel._on_confirm_pressed()
	assert_eq(other.level, 4, "the off-screen unit's level landed silently")
	assert_eq(bound.experience, 50)
	assert_eq(SquadManager.bonus_xp_pool, 150)
	SquadManager._roster_by_id.erase(other.character_id)


func test_parked_at_99_commits_without_a_level() -> void:
	SquadManager.bonus_xp_pool = 250
	var unit := _unit()
	unit.experience = 40
	var panel := _bound_panel(unit)
	panel._on_brink_pressed()
	await panel._on_confirm_pressed()
	assert_eq(unit.level, 3, "no threshold crossed")
	assert_eq(unit.experience, 99,
			"parked at the brink — the next combat action takes the level with full rolls")
	assert_eq(SquadManager.bonus_xp_pool, 191)


# =============================================================================
# THE POUR API (SquadManager)
# =============================================================================

func test_commit_bexp_pour_cascades_and_respects_the_pool() -> void:
	SquadManager.bonus_xp_pool = 250
	var unit := _unit()
	unit.experience = 50
	assert_eq(SquadManager.commit_bexp_pour(unit, 160), 2,
			"50 + 160 crosses two thresholds")
	assert_eq(unit.level, 5)
	assert_eq(unit.experience, 10)
	assert_eq(SquadManager.bonus_xp_pool, 90)
	assert_eq(SquadManager.commit_bexp_pour(unit, 91), 0,
			"a pour past the pool refuses whole — no partial silent spend")
	assert_eq(SquadManager.bonus_xp_pool, 90)

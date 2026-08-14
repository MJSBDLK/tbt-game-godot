## BexpSpendPanel — the pour spec, single-level-cap revision (RQD 2026-08-13,
## pivot 2A): [+1][+10][99][100] square buttons + CONFIRM on one row. Staging
## is per-unit arithmetic that can never cross more than one level boundary;
## CONFIRM is the one commit; leaving discards. The remainder persisting as
## real XP is the 99 brink's whole reason to exist.
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


func _action_button(panel: BexpSpendPanel, label: String) -> Button:
	# Last match wins — the action row rebuilds per refresh and queue_freed
	# buttons linger until frame end.
	var found: Button = null
	for button: Node in panel._actions_row.get_children():
		if button is Button and (button as Button).text == label:
			found = button
	return found


# =============================================================================
# PURE POUR MATH
# =============================================================================

func test_clamp_pour_floors_ceilings_at_pool_and_caps_at_one_level() -> void:
	assert_eq(BexpSpendPanel.clamp_pour(0, 10, 250, 0), 10)
	assert_eq(BexpSpendPanel.clamp_pour(5, -100, 250, 0), 0, "refunds floor at zero")
	assert_eq(BexpSpendPanel.clamp_pour(40, 100, 30, 0), 70,
			"a pour past the pool takes what's actually left")
	assert_eq(BexpSpendPanel.clamp_pour(0, 200, 500, 40), 60,
			"pivot 2A: the stage stops at ONE level — staged + XP never passes 100")
	assert_eq(BexpSpendPanel.clamp_pour(60, 10, 500, 40), 60,
			"already at the level boundary: nothing more fits")


func test_the_brink_parks_the_gauge_at_99() -> void:
	assert_eq(BexpSpendPanel.brink_amount(0), 99)
	assert_eq(BexpSpendPanel.brink_amount(40), 59)
	assert_eq(BexpSpendPanel.brink_amount(99), 0, "already at the brink")


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


func test_the_stage_never_crosses_a_level_boundary() -> void:
	SquadManager.bonus_xp_pool = 500
	var unit := _unit()
	unit.experience = 40
	var panel := _bound_panel(unit)
	panel._on_pour_pressed(100)
	panel._on_pour_pressed(100)
	assert_eq(panel._staged_for_bound(), 60,
			"[100] fills TO the level and further presses change nothing (2A)")
	assert_eq(panel._xp_value_label.text, "100/100")
	assert_eq(panel._level_value_label.text, "Lv 3 → 4")


func test_the_staged_segment_extends_the_committed_fill() -> void:
	# RQD: 25 committed XP stays its normal gold; the staged extension is its
	# own segment in the preview voice. The geometry is the testable half.
	SquadManager.bonus_xp_pool = 250
	var unit := _unit()
	unit.experience = 25
	var panel := _bound_panel(unit)
	panel._on_pour_pressed(10)
	panel._on_pour_pressed(10)
	panel._on_pour_pressed(10)
	panel._on_pour_pressed(10)
	panel._on_pour_pressed(10)
	assert_almost_eq(panel._xp_committed_fill.anchor_right, 0.25, 0.001,
			"committed gold ends where it always did")
	assert_almost_eq(panel._xp_staged_fill.anchor_left, 0.25, 0.001,
			"the staged segment begins exactly there")
	assert_almost_eq(panel._xp_staged_fill.anchor_right, 0.75, 0.001)
	assert_eq(panel._xp_staged_fill.color, GameColors.TEXT_PRIMARY,
			"staged wears the PRIMARY preview pair, not another gold")
	assert_true(panel._xp_committed_fill.visible)


func test_the_brink_button_stages_exactly_to_99() -> void:
	SquadManager.bonus_xp_pool = 250
	var unit := _unit()
	unit.experience = 40
	var panel := _bound_panel(unit)
	panel._on_brink_pressed()
	assert_eq(panel._staged_for_bound(), 59)
	assert_eq(panel._xp_value_label.text, "99/100")


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
# THE ACTION ROW — square buttons, StatUp scheme, built in their state
# =============================================================================

func test_buttons_go_muted_when_the_press_would_change_nothing() -> void:
	SquadManager.bonus_xp_pool = 0
	var panel := _bound_panel(_unit())
	assert_true(_action_button(panel, "+1").disabled, "no pool, nothing to pour")
	assert_true(_action_button(panel, "CONFIRM").disabled, "nothing staged")
	SquadManager.bonus_xp_pool = 250
	panel.bind(_unit("pour_rich"))
	assert_false(_action_button(panel, "+1").disabled)
	panel._on_pour_pressed(10)
	assert_false(_action_button(panel, "CONFIRM").disabled)


func test_square_buttons_wear_the_statup_scheme() -> void:
	SquadManager.bonus_xp_pool = 250
	var panel := _bound_panel(_unit())
	var enabled_ring: StyleBoxFlat = \
			_action_button(panel, "+1").get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(enabled_ring.border_color, GameColors.TEXT_PRIMARY,
			"ring and glyph share the PRIMARY identity")
	assert_eq(enabled_ring.border_width_left, 1)
	SquadManager.bonus_xp_pool = 0
	panel.bind(_unit("pour_broke"))
	var muted_ring: StyleBoxFlat = \
			_action_button(panel, "+1").get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(muted_ring.border_color, GameColors.TEXT_MUTED,
			"a press that would do nothing drops the whole button to MUTED")


# =============================================================================
# CONFIRM — the one commit
# =============================================================================

func test_confirm_below_the_boundary_banks_real_xp_without_a_level() -> void:
	SquadManager.bonus_xp_pool = 250
	var unit := _unit()
	unit.experience = 40
	var panel := _bound_panel(unit)
	watch_signals(panel)
	panel._on_pour_pressed(10)
	panel._on_pour_pressed(10)
	await panel._on_confirm_pressed()
	assert_eq(unit.level, 3, "no threshold crossed")
	assert_eq(unit.experience, 60, "poured XP persists as REAL experience")
	assert_eq(SquadManager.bonus_xp_pool, 230)
	assert_signal_emitted(panel, "changed")
	assert_false(panel._revealing)


func test_confirm_at_the_boundary_rolls_exactly_one_level() -> void:
	SquadManager.bonus_xp_pool = 250
	var unit := _unit()
	unit.experience = 40
	var panel := _bound_panel(unit)
	panel._on_pour_pressed(100)
	assert_eq(panel._staged_for_bound(), 60)
	await panel._on_confirm_pressed()
	assert_eq(unit.level, 4)
	assert_eq(unit.experience, 0, "the gauge resets — exactly one level, no spill")
	assert_eq(SquadManager.bonus_xp_pool, 190)


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


# =============================================================================
# THE POUR API (SquadManager)
# =============================================================================

func test_commit_bexp_pour_cascades_and_respects_the_pool() -> void:
	# The API still cascades multi-level pours (it serves more callers than
	# the panel); the panel's single-level cap lives in the STAGING math.
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

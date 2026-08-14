## BexpSpendPanel — slice 4's spend view (RQD 2026-08-11). One press = one
## committed, celebrated level: snapshot → buy_bexp_level → the shared
## LevelUpStatBlock reveals the growth → modifiers restore. No staging layer
## needed because nothing here is refundable by design.
extends GutTest


var _saved_pool: int = 0
var _saved_motion: bool = true


func before_each() -> void:
	_saved_pool = SquadManager.bonus_xp_pool
	_saved_motion = Settings.ui_motion_enabled
	# Reduced motion: the reveal collapses to build + restore pause, so the
	# awaited buy path stays fast under GUT.
	Settings.ui_motion_enabled = false


func after_each() -> void:
	SquadManager.bonus_xp_pool = _saved_pool
	Settings.ui_motion_enabled = _saved_motion


func _unit() -> CharacterData:
	var data := CharacterData.new()
	data.character_name = "Bench Test"
	data.level = 3
	data.base_max_hp = 20
	return data


func _bound_panel(unit: CharacterData) -> BexpSpendPanel:
	var panel := BexpSpendPanel.new()
	add_child_autofree(panel)
	panel.bind(unit)
	return panel


func test_a_purchase_commits_a_level_and_pays_from_the_pool() -> void:
	SquadManager.bonus_xp_pool = 250
	var unit := _unit()
	var panel := _bound_panel(unit)
	watch_signals(panel)
	await panel._on_buy_pressed()
	assert_eq(unit.level, 4, "one press = one committed level")
	assert_eq(SquadManager.bonus_xp_pool, 250 - SquadManager.BEXP_LEVEL_COST)
	assert_signal_emitted(panel, "changed",
			"rail badges and the pool readout hang off this")
	assert_false(panel._revealing, "the panel is ready for the next press")


func test_an_unaffordable_press_changes_nothing() -> void:
	SquadManager.bonus_xp_pool = SquadManager.BEXP_LEVEL_COST - 1
	var unit := _unit()
	var panel := _bound_panel(unit)
	watch_signals(panel)
	assert_true(panel._buy_button.disabled, "the button already says no")
	await panel._on_buy_pressed()
	assert_eq(unit.level, 3)
	assert_eq(SquadManager.bonus_xp_pool, SquadManager.BEXP_LEVEL_COST - 1)
	assert_signal_not_emitted(panel, "changed")


func test_binding_shows_the_live_pool_and_ident() -> void:
	SquadManager.bonus_xp_pool = 340
	var unit := _unit()
	var panel := _bound_panel(unit)
	assert_eq(panel._pool_value_label.text, "340")
	assert_eq(panel._name_label.text, "BENCH TEST")
	assert_eq(panel._level_value_label.text, "Lv 3")


func test_the_close_glyph_emits_closed() -> void:
	SquadManager.bonus_xp_pool = 0
	var panel := _bound_panel(_unit())
	watch_signals(panel)
	var close: Button = null
	for button: Node in panel.find_children("*", "Button", true, false):
		if (button as Button).text == "✕":
			close = button
	assert_not_null(close, "the ✕ affordance exists")
	close.pressed.emit()
	assert_signal_emitted(panel, "closed", "the screen swaps the sheet back on this")

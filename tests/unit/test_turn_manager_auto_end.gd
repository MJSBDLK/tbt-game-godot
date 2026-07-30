## The auto-end-turn gate (Options toggle, meeting ask 2026-06-28, built
## 2026-07-29): with Settings.auto_end_turn ON a spent player phase hands off
## to the enemy immediately (the long-standing behavior); OFF, the phase
## WAITS and TurnManager emits `player_phase_spent` — the End Turn CTA's
## trigger. Runs against the live TurnManager autoload; every test restores
## the roster, the phase, and the setting.
extends GutTest


func before_each() -> void:
	# The suite shares the live autoload; earlier battle-flow tests can leave
	# _is_processing_phase latched true, which gates check_end_player_turn
	# AND is_player_phase(). Start every test from a clean idle player phase.
	TurnManager._is_processing_phase = false
	TurnManager.current_phase = Enums.TurnPhase.PLAYER_PHASE


func after_each() -> void:
	Settings.auto_end_turn = true  # direct write — tests must not persist
	_set_roster([])


## Roster poked directly, NOT via initialize_battle: that call launches the
## full start_player_phase pipeline, whose deferred _refresh_units resets
## every unit's can_act on a later frame — quietly un-spending the phase the
## test just arranged. These tests pin state math, not the phase pipeline.
func _set_roster(units: Array[Unit]) -> void:
	TurnManager._player_units = units


func _make_unit(acted: bool) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.character_data = CharacterData.new()
	unit.current_hp = 1  # bare units default to 0 HP = defeated
	unit.can_act = not acted
	return unit


func test_all_player_units_acted_tracks_the_roster() -> void:
	var fresh := _make_unit(false)
	var spent := _make_unit(true)
	_set_roster([fresh, spent])
	assert_false(TurnManager.all_player_units_acted(), "a unit can still act")
	fresh.can_act = false
	assert_true(TurnManager.all_player_units_acted(), "now the phase is spent")


func test_auto_end_off_waits_and_signals_instead_of_advancing() -> void:
	_set_roster([_make_unit(true)])
	Settings.auto_end_turn = false
	watch_signals(TurnManager)
	TurnManager.check_end_player_turn()
	assert_eq(TurnManager.current_phase, Enums.TurnPhase.PLAYER_PHASE,
			"manual mode: the spent phase waits for End Turn")
	assert_signal_emitted(TurnManager, "player_phase_spent",
			"the wait is announced — this is what lights the End Turn CTA")


func test_unspent_phase_never_signals() -> void:
	_set_roster([_make_unit(false)])
	Settings.auto_end_turn = false
	watch_signals(TurnManager)
	TurnManager.check_end_player_turn()
	assert_signal_emit_count(TurnManager, "player_phase_spent", 0,
			"a unit can still act — nothing to announce, phase keeps waiting quietly")
	assert_eq(TurnManager.current_phase, Enums.TurnPhase.PLAYER_PHASE)

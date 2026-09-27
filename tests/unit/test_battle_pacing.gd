## Battle pacing, so a new player can read an exchange.
## Every seam of an exchange is a `breath`:
## FAST keeps the shipped timings, RELAXED holds each seam for
## CombatPresenter.RELAXED_BREATH_SECONDS and any press ends that one breath —
## on the map by a press edge, on the stage by the scene's own press, which
## must NOT skip the exchange while a breath is parked.
extends GutTest


const UNIT_SCENE: String = "res://scenes/battle/unit.tscn"
const SPACEMAN_PATH: String = "res://data/characters/spaceman.json"
const GRUNT_PATH: String = "res://data/characters/grunt.json"

var _pacing_before: int = 0


func before_each() -> void:
	_pacing_before = Settings.battle_pacing
	GridManager.clear_grid()


func after_each() -> void:
	Settings.battle_pacing = _pacing_before
	Input.action_release(&"ui_accept")
	GridManager.clear_grid()


# =============================================================================
# HELPERS
# =============================================================================

func _grid_tile(x: int, y: int) -> void:
	var tile := Tile.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	tile.add_child(sprite)
	add_child_autofree(tile)
	tile.grid_x = x
	tile.grid_y = y
	tile.terrain_type_name = "Plains"
	GridManager.register_tile(tile)


func _spawn(json_path: String, label: String, x: int) -> Unit:
	_grid_tile(x, 0)
	var unit: Unit = (load(UNIT_SCENE) as PackedScene).instantiate() as Unit
	unit.character_json_path = json_path
	unit.faction = Enums.UnitFaction.ENEMY  # XP feedback is player-only and off-presenter
	add_child_autofree(unit)
	unit.initialize(GridManager.get_tile(x, 0))
	unit.unit_name = label
	unit.character_data.base_athleticism = 4
	unit.character_data.base_agility = 5
	unit.character_data.base_skill = 5
	unit.character_data.base_strength = 3
	unit.character_data.base_max_hp = 50
	unit.current_hp = 50
	return unit


func _strike_move(label: String = "Probe") -> Move:
	var move := Move.new()
	move.move_name = label
	move.base_power = 2
	move.accuracy = 500
	move.damage_type = Enums.DamageType.PHYSICAL
	move.attack_range = 1
	move.max_uses = 5
	move.current_uses = 5
	return move


## Runs `hold` (a coroutine that takes no arguments) in the background and
## reports through the returned flag when it returns.
func _start(hold: Callable) -> Array[bool]:
	var done: Array[bool] = [false]
	var run := func() -> void:
		await hold.call()
		done[0] = true
	run.call()
	return done


# =============================================================================
# THE BEAT
# =============================================================================

func test_fast_pacing_is_the_shipped_snap() -> void:
	Settings.battle_pacing = Settings.BattlePacing.FAST
	var presenter := RecordingPresenter.new()
	await presenter.breath(Unit.HIT_DELAY)
	var hold: Dictionary = presenter.beats_named("hold")[0]
	assert_almost_eq(float(hold["seconds"]), Unit.HIT_DELAY, 0.0001)
	assert_false(hold.has("press_ends"), "a plain hold — nothing to press through")


func test_relaxed_pacing_holds_the_long_breath_a_press_can_end() -> void:
	Settings.battle_pacing = Settings.BattlePacing.RELAXED
	var presenter := RecordingPresenter.new()
	await presenter.breath(Unit.HIT_DELAY)
	var hold: Dictionary = presenter.beats_named("hold")[0]
	assert_almost_eq(float(hold["seconds"]), CombatPresenter.RELAXED_BREATH_SECONDS, 0.0001)
	assert_true(hold.get("press_ends", false))


func test_a_relaxed_exchange_breathes_between_strikes_in_the_same_order() -> void:
	Settings.battle_pacing = Settings.BattlePacing.RELAXED
	var attacker := _spawn(SPACEMAN_PATH, "Att", 1)
	var defender := _spawn(GRUNT_PATH, "Def", 2)
	defender.assigned_move = _strike_move("Riposte")
	var presenter := RecordingPresenter.new()
	await attacker.execute_combat_sequence(defender, _strike_move(), presenter)
	assert_eq(",".join(presenter.beat_names()),
			"open,strike,hold,release,impact,damage,hold,strike,hold,release,impact,damage,close",
			"pacing changes timing only — the beat order is FAST's")
	var before_counter: Dictionary = presenter.beats_named("hold")[1]
	assert_almost_eq(float(before_counter["seconds"]), CombatPresenter.RELAXED_BREATH_SECONDS, 0.0001,
			"the gap before the counter is the relaxed breath")
	assert_true(before_counter.get("press_ends", false))
	assert_false(presenter.beats_named("hold")[0].has("press_ends"), "hitlag is not a seam")


# =============================================================================
# MAP — a press edge ends the breath
# =============================================================================

func test_an_unpressed_breath_runs_its_length() -> void:
	var presenter := CombatPresenter.new()
	var started: int = Time.get_ticks_msec()
	await presenter.hold_until_press(0.2)
	assert_gte(Time.get_ticks_msec() - started, 180)


func test_a_press_ends_the_breath_early() -> void:
	var presenter := CombatPresenter.new()
	var started: int = Time.get_ticks_msec()
	var done := _start(presenter.hold_until_press.bind(2.0))
	await wait_process_frames(2)
	assert_false(done[0], "still breathing")
	Input.action_press(&"ui_accept")
	await wait_process_frames(2)
	assert_true(done[0], "the press moved it on")
	assert_lt(Time.get_ticks_msec() - started, 1000)
	assert_false(presenter.is_skipping(), "one breath, not the exchange")


func test_a_button_still_held_from_the_confirm_does_not_count() -> void:
	# The attack starts on a press; the player may still be holding it.
	Input.action_press(&"ui_accept")
	var presenter := CombatPresenter.new()
	var started: int = Time.get_ticks_msec()
	await presenter.hold_until_press(0.2)
	assert_gte(Time.get_ticks_msec() - started, 180, "a held button is not a fresh press")


func test_skip_ends_a_breath() -> void:
	var presenter := CombatPresenter.new()
	var done := _start(presenter.hold_until_press.bind(2.0))
	await wait_process_frames(2)
	presenter.request_skip()
	await wait_process_frames(2)
	assert_true(done[0])


func test_the_map_breathes_after_the_last_strike_only_when_relaxed() -> void:
	var presenter := MapPresenter.new()
	Settings.battle_pacing = Settings.BattlePacing.FAST
	presenter.open(null, null, null)
	var started: int = Time.get_ticks_msec()
	await presenter.close()
	assert_lt(Time.get_ticks_msec() - started, 50, "FAST: close is instant, as shipped")
	Settings.battle_pacing = Settings.BattlePacing.RELAXED
	presenter.open(null, null, null)
	started = Time.get_ticks_msec()
	await presenter.close()
	assert_gte(Time.get_ticks_msec() - started, int(CombatPresenter.RELAXED_BREATH_SECONDS * 1000) - 20,
			"RELAXED: the result sits for a breath")


# =============================================================================
# STAGE — the scene's press ends the breath instead of skipping
# =============================================================================

func _mounted_presenter() -> ScenePresenter:
	var attacker := _spawn(SPACEMAN_PATH, "Att", 0)
	var defender := _spawn(GRUNT_PATH, "Def", 1)
	var presenter := ScenePresenter.new()
	presenter.scene = CombatScene.new()
	presenter.scene.skip_requested.connect(presenter.request_skip)
	UIManager.get_overlay_layer().add_child(presenter.scene)
	autofree(presenter.scene)
	presenter.scene.setup(attacker, defender, _strike_move())
	return presenter


func _press(scene: CombatScene) -> void:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	scene._gui_input(event)


func test_a_stage_press_during_a_breath_advances_without_skipping() -> void:
	var presenter := _mounted_presenter()
	var done := _start(presenter.hold_until_press.bind(2.0))
	await wait_process_frames(2)
	assert_true(presenter.scene.is_waiting_for_press(), "the stage is parked on the breath")
	assert_eq((presenter.scene.get_node("Stage/SkipHint") as Label).text, CombatScene.SKIP_HINT_TEXT,
			"a timed breath keeps the hint still — only the debug park rewrites it")
	_press(presenter.scene)
	await wait_process_frames(2)
	assert_true(done[0], "the press ended the breath")
	assert_false(presenter.is_skipping(), "…and did not skip the exchange")
	_press(presenter.scene)
	assert_true(presenter.is_skipping(), "outside a breath a press still skips")


func test_a_stage_breath_runs_out_on_its_own() -> void:
	var presenter := _mounted_presenter()
	var started: int = Time.get_ticks_msec()
	await presenter.scene.wait_for_press(0.2)
	assert_gte(Time.get_ticks_msec() - started, 180)
	assert_false(presenter.scene.is_waiting_for_press())

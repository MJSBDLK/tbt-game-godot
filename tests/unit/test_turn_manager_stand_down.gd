## The acted gray belongs to the side whose phase it is. At each phase start
## the side that just moved stands down: ready again and in full color, so
## enemies that acted never look spent on the player's turn, and the player's
## units don't on the enemy's. Drives the live TurnManager through real phase
## starts, with the phase banner switched off so they run without its 3 s.
extends GutTest


const SPACEMAN_PATH: String = "res://data/characters/spaceman.json"
const GRUNT_PATH: String = "res://data/characters/grunt.json"

var _pristine_campaign: Dictionary = {}
var _banner: Node = null


func before_all() -> void:
	# A phase start emits player_phase_started, the autosave trigger: keep the
	# campaign inactive and saves in a scratch folder, never the player's rings.
	_pristine_campaign = CampaignManager.capture_save_state()
	CampaignManager.restore_save_state({})
	SaveManager.save_root = "user://test_saves_stand_down"
	_banner = UIManager._phase_transition_overlay
	UIManager._phase_transition_overlay = null


func after_all() -> void:
	UIManager._phase_transition_overlay = _banner
	CampaignManager.restore_save_state(_pristine_campaign)
	SaveManager.save_root = SaveManager.DEFAULT_SAVE_ROOT


func after_each() -> void:
	TurnManager._player_units = ([] as Array[Unit])
	TurnManager._enemy_units = ([] as Array[Unit])
	TurnManager._battle_ended = false
	TurnManager._is_processing_phase = false
	TurnManager.turn_count = 0
	TurnManager.current_phase = Enums.TurnPhase.PLAYER_PHASE


func _spawn_unit(json_path: String, faction: Enums.UnitFaction, grid_x: int) -> Unit:
	var unit: Unit = (load("res://scenes/battle/unit.tscn") as PackedScene).instantiate() as Unit
	unit.character_json_path = json_path
	unit.faction = faction
	add_child_autofree(unit)
	var tile: Tile = autofree(Tile.new())
	tile.grid_x = grid_x
	unit.initialize(tile)
	return unit


func _battle() -> Array[Unit]:
	var player := _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0)
	var enemy := _spawn_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY, 4)
	TurnManager._player_units = [player] as Array[Unit]
	TurnManager._enemy_units = [enemy] as Array[Unit]
	return [player, enemy] as Array[Unit]


func test_enemies_that_acted_look_ready_on_the_players_turn() -> void:
	# Regression: only the player side was refreshed at the player phase, so
	# every enemy that acted stayed gray through the player's whole turn.
	var enemy: Unit = _battle()[1]
	enemy.set_acted()
	assert_eq(enemy._sprite.material, Unit.acted_material(), "precondition: gray after acting")
	await TurnManager.start_player_phase()
	assert_null(enemy._sprite.material, "the player's turn shows the enemy in full color")
	enemy.set_selected(false)  # repaints from the latch, like a hit flash ending
	assert_null(enemy._sprite.material, "and nothing repaints it gray before its own turn")


func test_your_units_stand_down_when_the_enemy_moves() -> void:
	var player: Unit = _battle()[0]
	player.set_acted()
	TurnManager.start_enemy_phase()
	assert_null(player._sprite.material, "the enemy's turn shows your units in full color")
	assert_true(player.can_act)
	# Let the enemy phase run out (its timers and the hand back to the player)
	# so nothing is left running after the test.
	await wait_for_signal(TurnManager.player_phase_started, 5)


func test_a_resumed_battle_shows_the_enemy_ready() -> void:
	var units := _battle()
	var enemy: Unit = units[1]
	SaveManager.apply_unit_state(enemy, {"can_act": false})  # a save that carries the latch
	TurnManager.resume_battle([units[0]] as Array[Unit], [enemy] as Array[Unit], 3)
	assert_true(enemy.can_act)
	assert_null(enemy._sprite.material, "a load lands on the player's turn: the enemy looks ready")

## Save system stage 3: the mid-battle layer — unit snapshots and the resume
## path. Uses REAL unit.tscn instances (the proven spawn pattern from
## test_unit_shadow): tiles are bare autofree Tile.new()s because move_to_tile
## never needs them in the tree.
##
## The resume-semantics test pins the load-bearing negative space: resume must
## NOT re-emit battle_started (SquadManager's listener refills PP) and must
## NOT re-run phase upkeep (snapshots are captured post-upkeep; the acted
## latches carry as saved).
extends GutTest


const SPACEMAN_PATH: String = "res://data/characters/spaceman.json"
const GRUNT_PATH: String = "res://data/characters/grunt.json"

var _pristine_campaign: Dictionary = {}


func before_all() -> void:
	# Force the campaign inactive and point saves at a scratch dir so the
	# autosave trigger (listening to player_phase_started, which the resume
	# test emits) can never write into the player's real save rings.
	_pristine_campaign = CampaignManager.capture_save_state()
	CampaignManager.restore_save_state({})
	SaveManager.save_root = "user://test_saves_battle"


func after_all() -> void:
	CampaignManager.restore_save_state(_pristine_campaign)
	SaveManager.save_root = SaveManager.DEFAULT_SAVE_ROOT


func after_each() -> void:
	# Reset TurnManager's battle state directly — initialize_battle([], [])
	# would emit battle_started and run a victory check, dragging SquadManager
	# and the UI into a fake mission end.
	TurnManager._player_units = ([] as Array[Unit])
	TurnManager._enemy_units = ([] as Array[Unit])
	TurnManager._battle_ended = false
	TurnManager._is_processing_phase = false
	TurnManager.turn_count = 0
	TurnManager.current_phase = Enums.TurnPhase.PLAYER_PHASE


func _spawn_unit(json_path: String, faction: Enums.UnitFaction,
		grid_x: int, grid_y: int) -> Unit:
	var unit: Unit = (load("res://scenes/battle/unit.tscn") as PackedScene).instantiate() as Unit
	unit.character_json_path = json_path
	unit.faction = faction
	add_child_autofree(unit)
	# autofree, NOT add_child_autofree: a bare Tile's _ready expects scene
	# children; move_to_tile doesn't need the tile in the tree.
	var tile: Tile = autofree(Tile.new())
	tile.grid_x = grid_x
	tile.grid_y = grid_y
	unit.initialize(tile)
	return unit


func _json_round_trip(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data)) as Dictionary


func _make_status(type_name: String) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.effect_type_name = type_name
	effect.category = Enums.EffectCategory.DEBUFF
	effect.stacks = 2
	effect.caster_level = 4
	effect.dot_damage_per_tick = 3
	effect.source_element = Enums.ElementalType.FIRE
	effect.locked_slots.append({"kind": StatusEffect.SLOT_MOVE, "index": 2})
	return effect


# =============================================================================
# UNIT SNAPSHOT ROUND TRIP
# =============================================================================

func test_unit_state_round_trips_through_json() -> void:
	var original: Unit = _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 4, 3)
	assert_true(original.character_data.equipped_moves.size() > 0,
		"precondition: spaceman brings moves")
	original.can_act = false
	original.can_move = false
	original.pending_crit = true
	original.last_used_move_index = 0
	original.assigned_move = original.character_data.equipped_moves[0]
	original.current_hp = 5
	original.active_status_effects.append(_make_status("SHOCKED"))

	var entry: Dictionary = _json_round_trip(SaveManager._unit_to_save_dict(original))
	assert_eq(int(entry["grid_x"]), 4, "board position captures")
	assert_eq(int(entry["grid_y"]), 3)
	assert_eq(str(entry["character_id"]), "spaceman",
		"player units store a roster POINTER, not a character copy")
	assert_false(entry.has("character"), "no delta dict for roster-backed units")

	var restored: Unit = _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 4, 3)
	SaveManager.apply_unit_state(restored, entry)

	assert_false(restored.can_act, "acted latch restores (mid-phase manual saves)")
	assert_false(restored.can_move, "movement latch restores")
	assert_true(restored.pending_crit, "banked crit restores")
	assert_eq(restored.last_used_move_index, 0, "Capricious bookkeeping restores")
	assert_eq(restored.assigned_move, restored.character_data.equipped_moves[0],
		"assigned move re-resolves by index")
	assert_eq(restored.current_hp, 5, "HP restores")

	assert_eq(restored.active_status_effects.size(), 1, "status comes back")
	var effect: StatusEffect = restored.active_status_effects[0]
	assert_eq(effect.effect_type_name, "SHOCKED")
	assert_eq(effect.stacks, 2)
	assert_eq(effect.caster_level, 4)
	assert_eq(effect.dot_damage_per_tick, 3, "cached DoT magnitude restores")
	assert_eq(effect.source_element, Enums.ElementalType.FIRE)
	assert_true(effect.is_move_slot_locked(2),
		"void-lock slot indices survive JSON's float laundering")


func test_restored_hp_clamps_to_max() -> void:
	var unit: Unit = _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	SaveManager.apply_unit_state(unit, {"current_hp": 9999})
	assert_eq(unit.current_hp, unit.character_data.max_hp,
		"a save from before a max-HP rebalance can't overfill the unit")


func test_enemy_entry_carries_its_own_character_deltas() -> void:
	var enemy: Unit = _spawn_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY, 7, 2)
	enemy.character_data.simulate_levels_up_to(3)
	enemy.current_hp = 4

	var entry: Dictionary = _json_round_trip(SaveManager._unit_to_save_dict(enemy))
	assert_eq(str(entry["json_path"]), GRUNT_PATH, "enemies reconstruct from JSON")
	assert_false(entry.has("character_id"), "enemies aren't roster-backed")
	assert_eq(int(entry["ai_behavior"]), int(Enums.AIBehaviorType.AGGRESSIVE),
		"missing EnemyAI child defaults to aggressive")

	# Reconstruct the way BattleScene._resume_from_snapshot does.
	var rebuilt: CharacterData = CharacterDataLoader.load_character(GRUNT_PATH)
	rebuilt.apply_save_dict(entry["character"])
	assert_eq(rebuilt.level, 3, "enemy auto-leveled state survives WITHOUT re-rolling growths")
	for stat: String in ["hp", "strength", "defense"]:
		assert_eq(int(rebuilt.get("growth_gains_%s" % stat)),
			int(enemy.character_data.get("growth_gains_%s" % stat)),
			"enemy growth_gains_%s restores exactly — stats can't reshuffle on reload" % stat)


# =============================================================================
# RESUME SEMANTICS
# =============================================================================

func test_resume_battle_restores_turn_state_without_upkeep() -> void:
	var player: Unit = _spawn_unit(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 1, 1)
	var enemy: Unit = _spawn_unit(GRUNT_PATH, Enums.UnitFaction.ENEMY, 5, 5)
	player.can_act = false  # saved mid-phase after acting
	player.character_data.equipped_moves[0].current_uses = 2  # depleted PP

	watch_signals(TurnManager)
	TurnManager.resume_battle([player] as Array[Unit], [enemy] as Array[Unit], 7)

	assert_eq(TurnManager.turn_count, 7, "turn counter resumes where it left off")
	assert_true(TurnManager.is_player_phase(), "resume always lands in the player phase")
	assert_signal_emitted_with_parameters(TurnManager, "player_phase_started", [7])
	assert_signal_not_emitted(TurnManager, "battle_started",
		"battle_started must NOT re-fire — SquadManager's listener would refill PP")
	assert_false(player.can_act,
		"no refresh pass — the saved acted-latch carries (upkeep already ran pre-capture)")
	assert_eq(player.character_data.equipped_moves[0].current_uses, 2,
		"depleted PP survives the resume")

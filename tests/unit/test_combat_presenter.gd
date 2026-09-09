## The CombatPresenter seam (Phase 0 of .claude/todo-archive.md ("Battle animations plan")): the
## combat loop in Unit owns every roll and number, and narrates each visual
## moment as a BEAT on a presenter. These tests drive real exchanges with a
## RecordingPresenter — no tweens, no timers, no sprites — and pin the beat
## ORDER for the shapes the exchange can take: a plain hit, a counter, a
## multi-hit chain, a miss, a first-hit kill, a shove-denied counter, a heal.
## The skip test proves request_skip changes timing only, never order.
extends GutTest


const UNIT_SCENE: String = "res://scenes/battle/unit.tscn"
const SPACEMAN_PATH: String = "res://data/characters/spaceman.json"
const GRUNT_PATH: String = "res://data/characters/grunt.json"


func before_each() -> void:
	GridManager.clear_grid()


func after_all() -> void:
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


func _open_grid(min_x: int, max_x: int, min_y: int, max_y: int) -> void:
	for x: int in range(min_x, max_x + 1):
		for y: int in range(min_y, max_y + 1):
			_grid_tile(x, y)


## Real unit.tscn instances so every null guard in the loop is the real one.
## Both sides are ENEMY faction: XP is player-only, and XP feedback is a map
## beat outside the presenter — keeping it out keeps these tests about order.
func _spawn(json_path: String, label: String, x: int, y: int) -> Unit:
	var unit: Unit = (load(UNIT_SCENE) as PackedScene).instantiate() as Unit
	unit.character_json_path = json_path
	unit.faction = Enums.UnitFaction.ENEMY
	add_child_autofree(unit)
	unit.initialize(GridManager.get_tile(x, y))
	unit.unit_name = label
	# Deterministic exchange: equal athleticism (single hits), nobody dies,
	# everything connects unless a test says otherwise. The stat properties
	# are computed getters — only the base_* fields take an assignment.
	unit.character_data.base_athleticism = 4
	unit.character_data.base_agility = 5
	unit.character_data.base_skill = 5
	unit.character_data.base_strength = 3
	unit.character_data.base_max_hp = 50
	unit.current_hp = 50
	assert(unit.character_data.max_hp == 50, "fixture: base_max_hp must be the whole max_hp at level 1")
	return unit


func _strike_move(label: String = "Probe") -> Move:
	var move := Move.new()
	move.move_name = label
	move.base_power = 2
	move.accuracy = 500  # clamps to 100 — always lands
	move.damage_type = Enums.DamageType.PHYSICAL
	move.attack_range = 1
	move.max_uses = 5
	move.current_uses = 5
	return move


func _pair() -> Array:
	_open_grid(0, 3, 0, 0)
	var attacker := _spawn(SPACEMAN_PATH, "Att", 1, 0)
	var defender := _spawn(GRUNT_PATH, "Def", 2, 0)
	return [attacker, defender]


func _names(presenter: RecordingPresenter) -> String:
	return ",".join(presenter.beat_names())


# =============================================================================
# SELECTION + MATH
# =============================================================================

func test_phase_zero_always_presents_on_the_map() -> void:
	var presenter := CombatPresenter.for_exchange(null, null, null)
	assert_true(presenter is MapPresenter, "Phase 0: every exchange is the in-place presentation")


func test_hitlag_scales_with_impact_and_clamps() -> void:
	assert_almost_eq(CombatPresenter.hitlag_seconds(0.0), CombatPresenter.HITLAG_MIN, 0.0001)
	assert_almost_eq(CombatPresenter.hitlag_seconds(1.0), CombatPresenter.HITLAG_MAX, 0.0001)
	assert_almost_eq(CombatPresenter.hitlag_seconds(5.0), CombatPresenter.HITLAG_MAX, 0.0001, "over 1 clamps")
	assert_true(CombatPresenter.hitlag_seconds(0.5) > CombatPresenter.HITLAG_MIN)


func test_open_and_close_balance() -> void:
	var presenter := RecordingPresenter.new()
	assert_false(presenter.is_open())
	presenter.open(null, null, null)
	assert_true(presenter.is_open())
	presenter.close()
	assert_false(presenter.is_open())


# =============================================================================
# BEAT ORDER
# =============================================================================

func test_a_plain_hit_is_strike_hold_release_impact_damage() -> void:
	var pair := _pair()
	var attacker: Unit = pair[0]
	var defender: Unit = pair[1]
	var presenter := RecordingPresenter.new()
	await attacker.execute_combat_sequence(defender, _strike_move(), presenter)
	assert_eq(_names(presenter), "open,strike,hold,release,impact,damage,close")
	assert_false(presenter.is_open(), "closed when the exchange ends")
	var strike: Dictionary = presenter.beats_named("strike")[0]
	assert_eq(strike["actor"], "Att")
	assert_eq(strike["target"], "Def")
	var hold: Dictionary = presenter.beats_named("hold")[0]
	assert_almost_eq(float(hold["seconds"]), CombatPresenter.hitlag_seconds(
			DamageCalculator.calculate_impact_weight(int(presenter.beats_named("damage")[0]["damage"]),
					defender.character_data.max_hp)),
			0.0001, "the hold is the hitlag for that damage")
	assert_eq(defender.current_hp, 50 - int(presenter.beats_named("damage")[0]["damage"]),
			"the number shown is the number that landed")


func test_a_counter_follows_hit_one_after_the_hit_delay() -> void:
	var pair := _pair()
	var attacker: Unit = pair[0]
	var defender: Unit = pair[1]
	defender.assigned_move = _strike_move("Riposte")
	var presenter := RecordingPresenter.new()
	await attacker.execute_combat_sequence(defender, _strike_move(), presenter)
	assert_eq(_names(presenter),
			"open,strike,hold,release,impact,damage,hold,strike,hold,release,impact,damage,close")
	var strikes := presenter.beats_named("strike")
	assert_eq(strikes[1]["actor"], "Def", "the second strike is the counter")
	assert_eq(strikes[1]["target"], "Att")
	assert_eq(strikes[1]["move"], "Riposte")
	assert_almost_eq(float(presenter.beats_named("hold")[1]["seconds"]), Unit.HIT_DELAY, 0.0001,
			"the pause before the counter is the inter-hit delay")


func test_multi_hit_chains_strikes_with_pauses() -> void:
	var pair := _pair()
	var attacker: Unit = pair[0]
	var defender: Unit = pair[1]
	attacker.character_data.base_athleticism = 8  # 2x the defender's 4 → two hits
	var presenter := RecordingPresenter.new()
	await attacker.execute_combat_sequence(defender, _strike_move(), presenter)
	assert_eq(_names(presenter),
			"open,strike,hold,release,impact,damage,hold,strike,hold,release,impact,damage,close")
	for strike: Dictionary in presenter.beats_named("strike"):
		assert_eq(strike["actor"], "Att", "both strikes are the attacker's")


func test_a_miss_is_a_single_beat_with_no_impact() -> void:
	var pair := _pair()
	var attacker: Unit = pair[0]
	var defender: Unit = pair[1]
	var whiff := _strike_move("Whiff")
	whiff.accuracy = -1000  # clamps to 0 — never lands
	var presenter := RecordingPresenter.new()
	await attacker.execute_combat_sequence(defender, whiff, presenter)
	assert_eq(_names(presenter), "open,miss,close")
	assert_eq(defender.current_hp, 50, "no damage on a miss")


func test_a_first_hit_kill_plays_death_and_ends_the_exchange() -> void:
	var pair := _pair()
	var attacker: Unit = pair[0]
	var defender: Unit = pair[1]
	defender.assigned_move = _strike_move("Never")  # would counter if alive
	defender.current_hp = 1
	var presenter := RecordingPresenter.new()
	await attacker.execute_combat_sequence(defender, _strike_move(), presenter)
	assert_eq(_names(presenter), "open,strike,hold,release,impact,damage,death,close")
	assert_eq(presenter.beats_named("death")[0]["unit"], "Def")
	assert_true(defender.is_defeated())
	assert_null(defender.current_tile, "the logic half of defeat still cleared the tile")
	assert_eq(presenter.count("strike"), 1, "a dead defender never counters")


func test_a_shove_out_of_reach_announces_the_denied_counter() -> void:
	_open_grid(0, 7, 0, 2)
	var attacker := _spawn(SPACEMAN_PATH, "Att", 2, 1)
	var defender := _spawn(GRUNT_PATH, "Def", 3, 1)
	defender.assigned_move = _strike_move("Riposte")
	var shove := _strike_move("Shove")
	shove.displace_distance = 2
	shove.displace_vector = "away_from_attacker"
	shove.displace_subject = "target"
	shove.displace_shape = "single"
	shove.displace_on_blocked = "stop"
	var presenter := RecordingPresenter.new()
	await attacker.execute_combat_sequence(defender, shove, presenter)
	assert_eq(_names(presenter), "open,strike,hold,release,impact,damage,displace,out_of_range,close")
	assert_eq(presenter.beats_named("out_of_range")[0]["unit"], "Def")
	assert_eq(defender.current_tile, GridManager.get_tile(5, 1), "the shove itself still happened")


func test_a_heal_nudges_and_never_swings() -> void:
	var pair := _pair()
	var healer: Unit = pair[0]
	var ally: Unit = pair[1]
	ally.current_hp = 20
	var mend := Move.new()
	mend.move_name = "Mend"
	mend.heals = true
	mend.base_power = 3
	mend.target_type = Enums.TargetType.ALLY
	mend.damage_type = Enums.DamageType.SUPPORT
	mend.attack_range = 1
	mend.max_uses = 5
	mend.current_uses = 5
	var presenter := RecordingPresenter.new()
	await healer.execute_combat_sequence(ally, mend, presenter)
	assert_eq(_names(presenter), "open,nudge,hold,release,heal,close")
	assert_eq(presenter.count("strike"), 0, "a heal is a friendly contact, not a strike")
	assert_true(ally.current_hp > 20, "the heal landed")
	assert_eq(int(presenter.beats_named("heal")[0]["amount"]), ally.current_hp - 20)


func test_skip_changes_timing_only_never_order() -> void:
	var pair := _pair()
	var attacker: Unit = pair[0]
	var defender: Unit = pair[1]
	defender.assigned_move = _strike_move("Riposte")
	var presenter := RecordingPresenter.new()
	presenter.request_skip()
	await attacker.execute_combat_sequence(defender, _strike_move(), presenter)
	assert_eq(_names(presenter),
			"open,strike,hold,release,impact,damage,hold,strike,hold,release,impact,damage,close",
			"identical beat order to the unskipped counter exchange")
	for hold: Dictionary in presenter.beats_named("hold"):
		assert_true(hold["skipped"], "every hold saw the skip flag")


# =============================================================================
# CLIP PLAYER — the strip contract survived the extraction
# =============================================================================

func test_clip_playback_reads_sidecar_durations_and_clip_hit_frame() -> void:
	var clip := { "frames": 8, "fps": 5, "hit_frame": 4 }
	var playback := ClipPlayer.resolve_playback(
			"res://art/sprites/characters/max/meleeside.png", clip, 8)
	var durations: Array[float] = playback["durations_s"]
	assert_eq(durations.size(), 8)
	assert_almost_eq(durations[0], 0.2, 0.0001, "sidecar says 200 ms per frame")
	assert_eq(int(playback["hit_frame"]), 4, "sidecar has no hit_frame → the clip's wins")


func test_clip_playback_falls_back_to_fps_without_a_sidecar() -> void:
	var clip := { "frames": 4, "fps": 8 }
	var playback := ClipPlayer.resolve_playback("res://nope/missing.png", clip, 4)
	var durations: Array[float] = playback["durations_s"]
	assert_almost_eq(durations[2], 0.125, 0.0001)
	assert_eq(int(playback["hit_frame"]), 2, "no hit_frame anywhere → frames / 2")


func test_clip_player_begin_refuses_a_missing_strip() -> void:
	var sprite := Sprite2D.new()
	autofree(sprite)
	var player := ClipPlayer.new(sprite)
	assert_false(player.begin({ "path": "res://nope/missing.png", "frames": 3 }, false))
	assert_false(player.is_playing())
	assert_false(sprite.region_enabled, "an unloadable strip touches nothing")

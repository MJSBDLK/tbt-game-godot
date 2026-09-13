## The combat scene end to end (Phase 2 of .claude/todo-archive.md ("Battle animations plan")):
## the factory's admission rules (setting × initiator × move shape × real
## units), the stage's sides (player RIGHT, left puppet mirrored), and a
## whole exchange driven through a ScenePresenter in headless — mounts in
## UIManager's overlay, hosts its popups on the stage (not the map), closes
## and unmounts, and fast-forwards under skip. The suite runs in MAP mode
## (tests/gut_pre_run.gd); these tests flip the setting and restore it.
extends GutTest


const UNIT_SCENE: String = "res://scenes/battle/unit.tscn"
const SPACEMAN_PATH: String = "res://data/characters/spaceman.json"
const GRUNT_PATH: String = "res://data/characters/grunt.json"

var _setting_before: int = Settings.BattleAnimations.MAP
var _motion_before: bool = true
# Set from a signal handler — a member, because GDScript lambdas capture
# locals by VALUE and a flag flipped inside one never reaches the test.
var _saw_stage_popups: bool = false


func before_each() -> void:
	_setting_before = Settings.battle_animations
	_motion_before = Settings.ui_motion_enabled
	Settings.battle_animations = Settings.BattleAnimations.ALWAYS
	Settings.ui_motion_enabled = true
	GridManager.clear_grid()


func after_each() -> void:
	Settings.battle_animations = _setting_before
	Settings.ui_motion_enabled = _motion_before
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


func _spawn(json_path: String, faction: Enums.UnitFaction, x: int, y: int) -> Unit:
	_grid_tile(x, y)
	var unit: Unit = (load(UNIT_SCENE) as PackedScene).instantiate() as Unit
	unit.character_json_path = json_path
	unit.faction = faction
	var container := Node2D.new()
	add_child_autofree(container)
	container.add_child(unit)
	unit.initialize(GridManager.get_tile(x, y))
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


func _heal_move() -> Move:
	var move := Move.new()
	move.move_name = "Mend"
	move.heals = true
	move.target_type = Enums.TargetType.ALLY
	move.damage_type = Enums.DamageType.SUPPORT
	move.attack_range = 1
	return move


func _popups_under(node: Node) -> int:
	var count := 0
	for child: Node in node.get_children():
		if child is DamagePopup:
			count += 1
		count += _popups_under(child)
	return count


# =============================================================================
# FACTORY
# =============================================================================

func test_the_scene_is_chosen_for_a_player_attack_when_always() -> void:
	var attacker := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	assert_true(CombatPresenter.for_exchange(attacker, defender, _strike_move()) is ScenePresenter)


func test_map_mode_never_picks_the_scene() -> void:
	Settings.battle_animations = Settings.BattleAnimations.MAP
	var attacker := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	assert_true(CombatPresenter.for_exchange(attacker, defender, _strike_move()) is MapPresenter)


func test_player_phase_only_gates_on_who_initiates() -> void:
	Settings.battle_animations = Settings.BattleAnimations.PLAYER_PHASE_ONLY
	var player := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var enemy := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	assert_true(CombatPresenter.for_exchange(player, enemy, _strike_move()) is ScenePresenter,
			"the player attacking → scene")
	assert_true(CombatPresenter.for_exchange(enemy, player, _strike_move()) is MapPresenter,
			"the enemy attacking → map")


func test_friendly_casts_stay_on_the_map() -> void:
	var healer := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var ally := _spawn(GRUNT_PATH, Enums.UnitFaction.PLAYER, 1, 0)
	assert_true(CombatPresenter.for_exchange(healer, ally, _heal_move()) is MapPresenter, "heal → map (D3)")
	var roar := _strike_move("Roar")
	roar.target_type = Enums.TargetType.SELF
	assert_true(CombatPresenter.for_exchange(healer, healer, roar) is MapPresenter, "self-cast → map (D3)")


func test_bare_units_stay_on_the_map() -> void:
	var bare_attacker := Unit.new()
	var bare_defender := Unit.new()
	autofree(bare_attacker)
	autofree(bare_defender)
	assert_true(CombatPresenter.for_exchange(bare_attacker, bare_defender, _strike_move()) is MapPresenter,
			"no tree, no sprite, no character → nothing to stand on stage")
	assert_true(CombatPresenter.for_exchange(null, bare_defender, _strike_move()) is MapPresenter)


# =============================================================================
# STAGE
# =============================================================================

func test_the_player_stands_on_the_right_and_the_left_puppet_is_mirrored() -> void:
	var enemy := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 0, 0)
	var player := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 1, 0)
	var scene := CombatScene.new()
	UIManager.get_overlay_layer().add_child(scene)
	autofree(scene)
	# The ENEMY initiates; the player must still take the right (D2).
	scene.setup(enemy, player, _strike_move())
	var player_puppet := scene.puppet_for(player)
	var enemy_puppet := scene.puppet_for(enemy)
	assert_not_null(player_puppet)
	assert_not_null(enemy_puppet)
	assert_false(player_puppet.mirrored, "player puppet keeps the authored left-facing art")
	assert_true(enemy_puppet.mirrored, "left puppet mirrors everything it plays")
	assert_true(player_puppet.position.x > enemy_puppet.position.x, "player on the right")
	assert_true(player_puppet.sprite.flip_h == false and enemy_puppet.sprite.flip_h == true,
			"idle frames already wear the side's mirror")
	assert_eq(player_puppet.scale, Vector2(CombatScene.PUPPET_SCALE, CombatScene.PUPPET_SCALE))


func test_enemy_versus_enemy_puts_the_attacker_on_the_right() -> void:
	var attacker := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 0, 0)
	var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	var scene := CombatScene.new()
	UIManager.get_overlay_layer().add_child(scene)
	autofree(scene)
	scene.setup(attacker, defender, _strike_move())
	assert_false(scene.puppet_for(attacker).mirrored)
	assert_true(scene.puppet_for(defender).mirrored)


func test_puppets_stand_with_their_feet_on_the_ground_line() -> void:
	var enemy := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 0, 0)
	var player := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 1, 0)
	var scene := CombatScene.new()
	UIManager.get_overlay_layer().add_child(scene)
	autofree(scene)
	scene.setup(enemy, player, _strike_move())
	for puppet: CombatPuppet in scene.puppets():
		var feet_y: float = puppet.position.y + puppet.feet_drop * CombatScene.PUPPET_SCALE
		assert_almost_eq(feet_y, scene.core_origin().y + CombatScene.GROUND_Y, 1.0,
				"%s: feet meet the ground line" % puppet.name)


# =============================================================================
# A WHOLE EXCHANGE THROUGH THE SCENE
# =============================================================================

func test_an_exchange_mounts_plays_and_unmounts_the_scene() -> void:
	# Two ENEMY grunts: no clips (quick lunges), and no player XP — the +XP
	# callout is a MAP beat by design and would count as a map popup below.
	var attacker := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 0, 0)
	var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	defender.assigned_move = _strike_move("Riposte")
	var presenter := ScenePresenter.new()
	var overlay := UIManager.get_overlay_layer()
	var scenes_before: int = overlay.get_child_count()
	_saw_stage_popups = false
	attacker.combat_hit.connect(func(_a: Unit, _d: Unit, _dmg: int) -> void:
		# show_damage follows this signal by one call; look a frame later.
		await get_tree().process_frame
		if presenter.scene != null and _popups_under(presenter.scene) > 0:
			_saw_stage_popups = true)
	await attacker.execute_combat_sequence(defender, _strike_move(), presenter)
	assert_false(presenter.is_open(), "closed")
	assert_null(presenter.scene, "the scene is released")
	await get_tree().process_frame  # queue_free lands
	assert_eq(overlay.get_child_count(), scenes_before, "nothing left in the overlay layer")
	assert_true(defender.current_hp < 50, "the hit landed")
	assert_true(attacker.current_hp < 50, "the counter landed")
	assert_true(_saw_stage_popups, "damage popups were hosted on the stage")
	assert_eq(_popups_under(attacker.get_parent()) + _popups_under(defender.get_parent()), 0,
			"…and not on the map beside the units")


func test_a_skipped_exchange_still_lands_every_result_fast() -> void:
	var attacker := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)  # has 8-frame clips
	var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	defender.assigned_move = _strike_move("Riposte")
	var presenter := ScenePresenter.new()
	presenter.request_skip()
	var started := Time.get_ticks_msec()
	await attacker.execute_combat_sequence(defender, _strike_move(), presenter)
	var elapsed_ms := Time.get_ticks_msec() - started
	assert_true(defender.current_hp < 50 and attacker.current_hp < 50, "both hits landed under skip")
	assert_true(elapsed_ms < 1500, "skip fast-forwards the whole exchange (took %d ms)" % elapsed_ms)
	assert_null(presenter.scene)


func test_a_kill_on_stage_still_clears_the_tile() -> void:
	var attacker := _spawn(GRUNT_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	defender.current_hp = 1
	var presenter := ScenePresenter.new()
	presenter.request_skip()
	await attacker.execute_combat_sequence(defender, _strike_move(), presenter)
	assert_true(defender.is_defeated())
	assert_null(defender.current_tile, "the logic half of defeat ran around the stage death")
	assert_null(GridManager.get_tile(1, 0).current_unit)


func test_the_default_factory_path_uses_the_scene_end_to_end() -> void:
	# No presenter passed: for_exchange picks the scene under ALWAYS, and the
	# whole sequence still completes with the results on the units.
	var attacker := _spawn(GRUNT_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	Settings.ui_motion_enabled = false  # instant wipes keep the test quick
	await attacker.execute_combat_sequence(defender, _strike_move())
	assert_true(defender.current_hp < 50)
	await get_tree().process_frame
	var lingering := 0
	for child: Node in UIManager.get_overlay_layer().get_children():
		if child is CombatScene:
			lingering += 1
	assert_eq(lingering, 0, "no CombatScene left mounted")


# =============================================================================
# PLAYBACK HUD (D7, locked 2026-09-07)
# =============================================================================

func _mounted_scene(attacker: Unit, defender: Unit, move: Move) -> CombatScene:
	var scene := CombatScene.new()
	UIManager.get_overlay_layer().add_child(scene)
	autofree(scene)
	scene.setup(attacker, defender, move)
	return scene


func test_hud_shows_name_types_and_the_attackers_move_at_open() -> void:
	var attacker := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)  # Simple type
	var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	var move := _strike_move("Bonk")
	move.element_type = Enums.ElementalType.SIMPLE
	var scene := _mounted_scene(attacker, defender, move)
	var attacker_hud := scene.hud_for(attacker)
	var defender_hud := scene.hud_for(defender)
	assert_false(attacker_hud.is_empty())
	assert_eq((attacker_hud["name"] as Label).text, attacker.unit_name)
	assert_true((attacker_hud["primary_icon"] as TextureRect).visible, "the unit's primary type icon shows")
	assert_not_null((attacker_hud["primary_icon"] as TextureRect).texture)
	assert_eq((attacker_hud["move"] as Label).text, "Bonk", "the attacker's move is known at open")
	assert_true((attacker_hud["element_icon"] as TextureRect).visible, "move element icon")
	assert_true((attacker_hud["type_icon"] as TextureRect).visible, "damage-type icon")
	assert_eq((defender_hud["move"] as Label).text, "—", "the defender's row waits for its counter")
	assert_true((scene.get_node("Stage/SkipHint") as Label).text.length() > 0, "a skip hint is on stage")


func test_a_strike_projects_its_loss_then_the_hit_spends_it() -> void:
	var attacker := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	var move := _strike_move()
	var scene := _mounted_scene(attacker, defender, move)
	var hud := scene.hud_for(defender)
	var fill: ColorRect = hud["hp_fill"]
	var loss: ColorRect = hud["hp_loss"]
	assert_almost_eq(fill.size.x, CombatScene.HP_BAR_SIZE.x, 0.5, "full bar before anything happens")
	assert_almost_eq(loss.size.x, 0.0, 0.5, "no projection before a strike")

	scene.show_strike(attacker, defender, move)
	var projected: int = DamageCalculator.calculate_damage(attacker, defender, move)
	var expected_remaining: float = roundf(CombatScene.HP_BAR_SIZE.x * float(50 - projected) / 50.0)
	assert_almost_eq(fill.size.x, expected_remaining, 0.5, "the fill drops to the projected remainder")
	assert_almost_eq(loss.size.x, CombatScene.HP_BAR_SIZE.x - expected_remaining, 0.5,
			"the band covers exactly the projected loss")
	assert_almost_eq(loss.position.x, fill.size.x, 0.5, "the band starts where the fill ends")
	var attacker_hud := scene.hud_for(attacker)
	assert_eq((attacker_hud["hit"] as Label).text, "%d%%" % DamageCalculator.hit_chance_pct(attacker, defender, move))
	assert_false((attacker_hud["multiplier"] as Label).visible, "neutral matchup shows no multiplier")

	defender.take_damage(projected)
	scene.update_hp(defender)
	assert_almost_eq(loss.size.x, 0.0, 0.5, "the hit spent the projection")
	assert_almost_eq(fill.size.x, expected_remaining, 0.5, "and the fill is the real HP")


func test_a_miss_clears_the_projection_without_draining() -> void:
	var attacker := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	var move := _strike_move()
	var scene := _mounted_scene(attacker, defender, move)
	scene.show_strike(attacker, defender, move)
	var hud := scene.hud_for(defender)
	assert_true((hud["hp_loss"] as ColorRect).size.x > 0.0, "precondition: a band is showing")
	scene.clear_projection(defender)
	assert_almost_eq((hud["hp_loss"] as ColorRect).size.x, 0.0, 0.5)
	assert_almost_eq((hud["hp_fill"] as ColorRect).size.x,
			roundf(CombatScene.HP_BAR_SIZE.x * (50.0 - DamageCalculator.calculate_damage(attacker, defender, move)) / 50.0), 0.5,
			"clear_projection leaves the fill where the strike put it; update_hp is what restores")
	scene.update_hp(defender)
	assert_almost_eq((hud["hp_fill"] as ColorRect).size.x, CombatScene.HP_BAR_SIZE.x, 0.5, "HP untouched by a miss")


func test_the_counter_fills_in_its_own_row_when_it_swings() -> void:
	var attacker := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	var riposte := _strike_move("Riposte")
	riposte.element_type = Enums.ElementalType.FIRE
	var scene := _mounted_scene(attacker, defender, _strike_move())
	scene.show_strike(defender, attacker, riposte)
	var hud := scene.hud_for(defender)
	assert_eq((hud["move"] as Label).text, "Riposte")
	assert_true((hud["element_icon"] as TextureRect).visible)
	assert_eq((hud["hit"] as Label).text, "%d%%" % DamageCalculator.hit_chance_pct(defender, attacker, riposte))
	assert_true((scene.hud_for(attacker)["hp_loss"] as ColorRect).size.x > 0.0,
			"the attacker's bar now carries the counter's projected loss")


func test_multiplier_formatting_and_visibility() -> void:
	assert_eq(CombatScene.format_multiplier(1.0), "", "neutral hides")
	assert_eq(CombatScene.format_multiplier(2.0), "×2")
	assert_eq(CombatScene.format_multiplier(4.0), "×4")
	assert_eq(CombatScene.format_multiplier(0.5), "×½")
	assert_eq(CombatScene.format_multiplier(0.25), "×¼")
	assert_eq(CombatScene.format_multiplier(0.0), "×0")


func test_hud_shows_portrait_level_and_pp_at_open() -> void:
	var attacker := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)  # has HD line art
	var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)      # pixel portrait only
	var scene := _mounted_scene(attacker, defender, _strike_move("Bonk"))  # 5/5 uses
	var attacker_hud := scene.hud_for(attacker)
	var defender_hud := scene.hud_for(defender)
	assert_eq((attacker_hud["level"] as Label).text, "Lv.%d" % attacker.character_data.level)
	assert_eq((defender_hud["level"] as Label).text, "Lv.%d" % defender.character_data.level)
	for pair: Array in [[attacker, attacker_hud], [defender, defender_hud]]:
		var unit: Unit = pair[0]
		var portrait: TextureRect = pair[1]["portrait"]
		if CharacterPortrait.has_hd_art(unit.character_data):
			assert_not_null(portrait.get_node_or_null("_HDPortraitSlot"),
					"%s: HD art → an HDPortraitSlot mirrors the frame" % unit.unit_name)
		else:
			assert_not_null(portrait.texture, "%s: no HD art → the pixel portrait" % unit.unit_name)
	assert_true((attacker_hud["uses"] as Label).visible, "the attacker's PP shows at open")
	assert_eq((attacker_hud["uses"] as Label).text, "5/5", "pre-spend at open — consume_use runs after open")
	assert_false((defender_hud["uses"] as Label).visible, "the defender's PP waits for its counter")


func test_pp_ticks_down_as_the_strike_row_fills_in() -> void:
	var attacker := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	var move := _strike_move()
	var scene := _mounted_scene(attacker, defender, move)
	move.consume_use()  # the exchange pays before hit 1
	scene.show_strike(attacker, defender, move)
	assert_eq((scene.hud_for(attacker)["uses"] as Label).text, "4/5")

	var basic := _strike_move("Struggle")
	basic.max_uses = 0
	basic.current_uses = 0
	scene.show_strike(defender, attacker, basic)
	var defender_hud := scene.hud_for(defender)
	assert_eq((defender_hud["move"] as Label).text, "Struggle")
	assert_false((defender_hud["uses"] as Label).visible, "no PP pool → no counter")


func test_status_chips_follow_the_units_effects_live() -> void:
	var attacker := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	var scene := _mounted_scene(attacker, defender, _strike_move())
	var hud := scene.hud_for(defender)
	var buff_chip: Dictionary = hud["chips"][Enums.EffectCategory.BUFF]
	var debuff_chip: Dictionary = hud["chips"][Enums.EffectCategory.DEBUFF]
	assert_false((hud["status_row"] as Control).visible, "no statuses → no chip row")

	StatusEffectSystem.apply_status_effect_by_name(null, defender, "BELLOWS")
	assert_true((hud["status_row"] as Control).visible)
	assert_true((buff_chip["root"] as Control).visible, "the buff slot lights up")
	assert_eq((buff_chip["name"] as Label).text, "Bellows")
	assert_eq((buff_chip["stacks"] as Label).text, "1")
	assert_not_null((buff_chip["icon"] as TextureRect).texture, "the 6×6 status icon")
	assert_false((debuff_chip["root"] as Control).visible, "the debuff slot stays empty")
	assert_true(_popups_under(scene) > 0, "the status name floats over the puppet")

	StatusEffectSystem.apply_status_effect_by_name(null, defender, "BELLOWS")
	assert_eq((buff_chip["stacks"] as Label).text, "2", "a restack counts up")

	StatusEffectSystem.remove_status_effect(defender, "BELLOWS")
	assert_false((buff_chip["root"] as Control).visible, "removal clears the chip")
	assert_false((hud["status_row"] as Control).visible)


func test_portraits_pop_in_after_the_wipe_and_out_before_it() -> void:
	var attacker := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	var scene := _mounted_scene(attacker, defender, _strike_move())
	var frame: Control = scene.hud_for(attacker)["portrait_frame"]
	assert_false(frame.visible, "hidden until the stage is fully in — the HD mirror can't fade")
	await scene.wipe_in(true)
	assert_true(frame.visible, "pops in once the reveal lands")
	await scene.wipe_out(true)
	assert_false(frame.visible, "pops out before the conceal starts")


func test_the_stage_settles_for_a_beat_at_open_and_at_close() -> void:
	# RQD 2026-09-08: "it whips by before my brain can process it."
	var attacker := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	var presenter := ScenePresenter.new()
	var started: int = Time.get_ticks_msec()
	await presenter.open(attacker, defender, _strike_move())
	var open_ms: int = Time.get_ticks_msec() - started
	assert_true(open_ms >= int(ScenePresenter.OPEN_SETTLE_SECONDS * 1000) - 20,
			"open holds for the settle after the wipe-in (%d ms)" % open_ms)
	started = Time.get_ticks_msec()
	await presenter.close()
	var close_ms: int = Time.get_ticks_msec() - started
	assert_true(close_ms >= int(ScenePresenter.CLOSE_SETTLE_SECONDS * 1000) - 20,
			"close holds for the settle before the wipe-out (%d ms)" % close_ms)


func test_skip_removes_both_settles() -> void:
	var attacker := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	var presenter := ScenePresenter.new()
	presenter.request_skip()
	var started: int = Time.get_ticks_msec()
	await presenter.open(attacker, defender, _strike_move())
	await presenter.close()
	var total_ms: int = Time.get_ticks_msec() - started
	assert_true(total_ms < int((ScenePresenter.OPEN_SETTLE_SECONDS + ScenePresenter.CLOSE_SETTLE_SECONDS) * 1000),
			"a skipped open+close never waits out the settles (%d ms)" % total_ms)


func _press(scene: CombatScene) -> void:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	scene._gui_input(event)


func test_the_debug_step_pause_parks_the_stage_until_a_press() -> void:
	# RQD 2026-09-08: "so I can sit there indefinitely, examining the scene."
	var attacker := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	var flag_before: bool = DebugConfig.combat_scene_step_pauses
	DebugConfig.combat_scene_step_pauses = true
	var presenter := ScenePresenter.new()
	var opened: Array[bool] = [false]
	var run_open := func() -> void:
		await presenter.open(attacker, defender, _strike_move())
		opened[0] = true
	run_open.call()
	await get_tree().create_timer(0.5).timeout  # well past the wipe-in and the 250 ms settle
	assert_false(opened[0], "open does not return on its own")
	assert_true(presenter.scene.is_waiting_for_press(), "the stage is parked at the open settle")
	assert_eq((presenter.scene.get_node("Stage/SkipHint") as Label).text, CombatScene.ADVANCE_HINT_TEXT)
	_press(presenter.scene)
	await get_tree().process_frame
	assert_true(opened[0], "the press advanced the open")
	assert_false(presenter.scene.is_waiting_for_press())
	assert_false(presenter.is_skipping(), "a press at a pause advances — it does not skip the exchange")
	assert_eq((presenter.scene.get_node("Stage/SkipHint") as Label).text, CombatScene.SKIP_HINT_TEXT)

	var closed: Array[bool] = [false]
	var run_close := func() -> void:
		await presenter.close()
		closed[0] = true
	run_close.call()
	await get_tree().create_timer(0.4).timeout
	assert_false(closed[0], "close parks at the end settle")
	assert_true(presenter.scene.is_waiting_for_press())
	_press(presenter.scene)
	await get_tree().create_timer(0.4).timeout  # the wipe-out
	assert_true(closed[0], "the press released the close")
	DebugConfig.combat_scene_step_pauses = flag_before


func test_the_suite_hook_disarms_the_step_pause() -> void:
	# The working tree may carry combat_scene_step_pauses = true (it is a dev
	# toggle); the hook must neutralize it or every scene test parks forever.
	assert_false(DebugConfig.combat_scene_step_pauses,
			"tests/gut_pre_run.gd must reset DebugConfig.combat_scene_step_pauses")


func test_backdrop_art_anchors_its_core_rectangle_on_the_core() -> void:
	# Lawrence's brief (plan §7): a 288×134 sprite-px canvas whose core
	# rectangle sits at (37, 7). The art's top-left therefore lands 37×3 left
	# and 7×3 above the core origin, on the puppets' pixel grid.
	assert_eq(CombatScene.backdrop_position(Vector2(100, 20)), Vector2(100 - 111, 20 - 21))
	assert_eq(int(CombatScene.GROUND_Y) % CombatScene.PUPPET_SCALE, 0, "feet line on the 3-px grid")
	assert_eq(int(CombatScene.SKY_BOTTOM) % CombatScene.PUPPET_SCALE, 0, "horizon on the 3-px grid")
	assert_eq(int(CombatScene.STAGE_CENTRE_X) % CombatScene.PUPPET_SCALE, 0, "stage centre on the grid")
	assert_eq(int(CombatScene.puppet_x(true, 1)) % CombatScene.PUPPET_SCALE, 0, "adjacent left centre on the grid")
	assert_eq(int(CombatScene.puppet_x(false, 3)) % CombatScene.PUPPET_SCALE, 0, "distance-3 right centre on the grid")
	assert_eq(int(CombatScene.SKY_BOTTOM) / CombatScene.PUPPET_SCALE + int(CombatScene.BACKDROP_CORE_OFFSET.y), 86,
			"the brief's horizon row")
	assert_eq(int(CombatScene.GROUND_Y) / CombatScene.PUPPET_SCALE + int(CombatScene.BACKDROP_CORE_OFFSET.y), 91,
			"the brief's feet row")


func test_without_backdrop_art_the_stage_shows_the_palette_bands_only() -> void:
	var attacker := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	var scene := _mounted_scene(attacker, defender, _strike_move())
	var has_art: bool = ResourceLoader.exists(CombatScene.BACKDROP_DIRECTORY + CombatScene.BACKDROP_SKY_FILE)
	var backdrops := 0
	for child: Node in scene.get_node("Stage").get_children():
		if child.name.begins_with("Backdrop_"):
			backdrops += 1
	if has_art:
		assert_true(backdrops >= 1, "art present → drawn")
	else:
		assert_eq(backdrops, 0, "no art → no backdrop nodes, bands carry the stage")
	assert_not_null(scene.get_node("Stage/Sky"))
	assert_not_null(scene.get_node("Stage/Ground"))


# =============================================================================
# SPACING FOLLOWS THE MAP (RQD 2026-09-08): the clips were authored for tile
# spacing — Ernesto's thrust reaches 58 px, exactly two 32-px tiles — so the
# puppets stand 32 sprite px apart per tile of map distance, symmetric about
# the stage centre, capped at 4 tiles (128 sprite px). No panning or zoom.
# (RQD 2026-09-09: "Are our tiles not 32x32?" — they are; 16 was GridManager's
# unregistered default.)
# =============================================================================

func test_puppets_stand_one_tile_apart_per_tile_of_map_distance() -> void:
	assert_eq(CombatScene.TILE_SPRITE_PX, 32, "battle_tileset.tres tiles are 32×32")
	assert_eq(CombatScene.spread_for(1), 96.0, "one tile = 32 sprite px = 96 design px")
	assert_eq(CombatScene.spread_for(3), 288.0)
	assert_eq(CombatScene.spread_for(4), 384.0, "the cap: 128 sprite px")
	assert_eq(CombatScene.spread_for(11), 384.0, "beyond the cap stays at the cap")
	assert_eq(CombatScene.spread_for(0), 96.0, "no distance known → adjacent")
	for pair: Array in [[1, 1], [3, 3], [2, 2], [12, 12]]:  # the true distance is kept; only the SPREAD caps
		var attacker := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
		var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, pair[0], 0)
		var scene := _mounted_scene(attacker, defender, _strike_move())
		var right := scene.puppet_for(attacker)
		var left := scene.puppet_for(defender)
		assert_eq(scene.distance_tiles(), pair[1], "distance %d reads as %d" % [pair[0], pair[1]])
		assert_almost_eq(right.position.x - left.position.x, CombatScene.spread_for(pair[1]), 0.5,
				"distance %d: centres %s apart" % [pair[0], CombatScene.spread_for(pair[1])])
		assert_almost_eq((right.position.x + left.position.x) / 2.0,
				scene.core_origin().x + CombatScene.STAGE_CENTRE_X, 0.5, "symmetric about the stage centre")
		GridManager.clear_grid()
	# RQD's screenshot (2026-09-08): a diagonal Compressed Air drew the pair
	# adjacent. Gameplay range is Manhattan — a diagonal neighbour is 2 away.
	var attacker := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 1)
	var scene := _mounted_scene(attacker, defender, _strike_move())
	assert_eq(scene.distance_tiles(), 2, "a diagonal neighbour is two tiles apart, as the range rules say")
	assert_almost_eq(scene.puppet_for(attacker).position.x - scene.puppet_for(defender).position.x,
			CombatScene.spread_for(2), 0.5, "and stands two tiles apart on stage")


func test_a_shove_respaces_the_shoved_puppet_by_whole_tiles() -> void:
	var attacker := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	var scene := _mounted_scene(attacker, defender, _strike_move())
	var left := scene.puppet_for(defender)
	var right := scene.puppet_for(attacker)
	var right_before: float = right.position.x
	var left_before: float = left.position.x
	await scene.respace(3, defender, true)  # knocked from 1 to 3 tiles
	assert_eq(scene.distance_tiles(), 3)
	assert_almost_eq(left_before - left.position.x, 2.0 * CombatScene.spread_for(1), 0.5,
			"the shoved (left) puppet travels the two tiles outward")
	assert_almost_eq(right.position.x, right_before, 0.5, "the attacker holds its ground")
	await scene.respace(1, defender, true)  # pulled back adjacent
	assert_almost_eq(left.position.x, left_before, 0.5, "and comes back")
	assert_almost_eq(right.position.x, right_before, 0.5)


func test_a_shove_past_the_safe_margin_hands_the_rest_to_the_other_puppet() -> void:
	var attacker := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	var scene := _mounted_scene(attacker, defender, _strike_move())
	var left := scene.puppet_for(defender)
	var right := scene.puppet_for(attacker)
	await scene.respace(8, defender, true)  # adjacent → the cap in one shove
	assert_almost_eq(left.stage_x, CombatScene.PUPPET_SAFE_MARGIN, 0.5, "the mover stops at the safe margin")
	assert_almost_eq(right.stage_x - left.stage_x, CombatScene.spread_for(8), 0.5,
			"the full capped spread is still shown — the attacker gave way")
	assert_true(right.stage_x <= CombatScene.CORE.x - CombatScene.PUPPET_SAFE_MARGIN, "and stays inside the core")


func test_the_tile_strip_shows_one_tile_per_map_tile_under_the_pair() -> void:
	# RQD's screenshot (2026-09-09): two tiles apart LOOKED adjacent — bodies
	# are wider than tiles and the stage had no tiles to read against.
	for distance: int in [1, 2, 3, 8, 11]:
		var attacker := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
		var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, distance, 0)
		var scene := _mounted_scene(attacker, defender, _strike_move())
		var expected: int = mini(distance, CombatScene.MAX_SPREAD_TILES) + 1
		assert_eq(scene.tile_strip_count(), expected, "distance %d → %d tiles (standing tiles + the ones between)" % [distance, expected])
		var first: ColorRect = scene.get_node("Stage/TileStrip/Tile0")
		var tile_px: float = float(CombatScene.TILE_SPRITE_PX * CombatScene.PUPPET_SCALE)
		assert_almost_eq(first.position.x + tile_px / 2.0, scene.puppet_for(defender).position.x, 1.0,
				"tile 0 is centred under the left puppet")
		assert_almost_eq(first.position.y, scene.core_origin().y + CombatScene.GROUND_Y, 0.5, "sits on the feet line")
		GridManager.clear_grid()


func test_a_respace_rebuilds_the_strip_for_the_new_distance() -> void:
	var attacker := _spawn(SPACEMAN_PATH, Enums.UnitFaction.PLAYER, 0, 0)
	var defender := _spawn(GRUNT_PATH, Enums.UnitFaction.ENEMY, 1, 0)
	var scene := _mounted_scene(attacker, defender, _strike_move())
	assert_eq(scene.tile_strip_count(), 2)
	await scene.respace(3, defender, true)
	assert_eq(scene.tile_strip_count(), 4, "1 → 3 tiles apart: four tiles now")
	var last: ColorRect = scene.get_node("Stage/TileStrip/Tile3")
	assert_almost_eq(last.position.x + CombatScene.TILE_SPRITE_PX * CombatScene.PUPPET_SCALE / 2.0,
			scene.puppet_for(attacker).position.x, 1.0, "the last tile is under the right puppet")

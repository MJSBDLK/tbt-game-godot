## Tantrum: a self-cast whose three hits each land on a random unit next to
## the user, friends included (Move.random_targets, Unit._execute_random_area_hits).
## Nobody counters, and hitting your own side pays no XP. Thumps is the
## enemy in the foe-hitting tests: a player-side level-up would wait for a
## press that never comes.
extends GutTest


const UNIT_SCENE: String = "res://scenes/battle/unit.tscn"
const SPACEMAN_PATH: String = "res://data/characters/spaceman.json"


func before_each() -> void:
	GridManager.clear_grid()


func after_all() -> void:
	GridManager.clear_grid()


func _open_grid(width: int, height: int = 1) -> void:
	for x: int in range(width):
		for y: int in range(height):
			var tile := Tile.new()
			var sprite := Sprite2D.new()
			sprite.name = "Sprite2D"
			tile.add_child(sprite)
			add_child_autofree(tile)
			tile.grid_x = x
			tile.grid_y = y
			tile.terrain_type_name = "Plains"
			GridManager.register_tile(tile)


func _scene_unit(label: String, faction: Enums.UnitFaction, cell: Vector2i) -> Unit:
	var unit: Unit = (load(UNIT_SCENE) as PackedScene).instantiate() as Unit
	unit.character_json_path = SPACEMAN_PATH
	unit.faction = faction
	add_child_autofree(unit)
	unit.initialize(GridManager.get_tile(cell.x, cell.y))
	unit.unit_name = label
	unit.character_data.equipped_passives = []
	unit.character_data.base_max_hp += 200
	unit.current_hp = unit.character_data.max_hp
	return unit


func _tantrum() -> Move:
	var tantrum := MoveData.get_move("Tantrum")
	tantrum.accuracy = 500
	return tantrum


func _damaged(presenter: RecordingPresenter) -> Array[String]:
	var names: Array[String] = []
	for entry: Dictionary in presenter.beats_named("damage"):
		names.append(entry["target"])
	return names


func test_tantrum_flails_at_everyone_around() -> void:
	var tantrum := MoveData.get_move("Tantrum")
	assert_eq([tantrum.target_type, tantrum.area_of_effect, tantrum.attack_range],
			[Enums.TargetType.SELF, 1, 0])
	assert_eq([tantrum.hits, tantrum.random_targets, tantrum.aoe_affects], [3, true, "all"])
	assert_eq(tantrum.animation_clip, "tantrum", "its own clip, once Lawrence draws it")


func test_alone_with_one_foe_every_hit_lands_on_it() -> void:
	_open_grid(3)
	var thumps := _scene_unit("thumps", Enums.UnitFaction.ENEMY, Vector2i(1, 0))
	var foe := _scene_unit("foe", Enums.UnitFaction.PLAYER, Vector2i(2, 0))
	foe.assigned_move = MoveData.get_move("Bonk")
	var thumps_hp := thumps.current_hp
	var tantrum := _tantrum()
	var presenter := RecordingPresenter.new()

	await thumps.execute_combat_sequence(thumps, tantrum, presenter)

	assert_eq(_damaged(presenter), ["foe", "foe", "foe"] as Array[String])
	assert_eq(thumps.current_hp, thumps_hp, "nobody counters a tantrum")
	assert_eq(tantrum.current_uses, tantrum.max_uses - 1)


func test_a_friend_alongside_takes_the_blows() -> void:
	_open_grid(3)
	var thumps := _scene_unit("thumps", Enums.UnitFaction.PLAYER, Vector2i(1, 0))
	var friend := _scene_unit("friend", Enums.UnitFaction.PLAYER, Vector2i(0, 0))
	var friend_hp := friend.current_hp
	var experience_before := thumps.character_data.experience
	var presenter := RecordingPresenter.new()

	await thumps.execute_combat_sequence(thumps, _tantrum(), presenter)

	assert_eq(_damaged(presenter), ["friend", "friend", "friend"] as Array[String])
	assert_lt(friend.current_hp, friend_hp)
	assert_eq(thumps.character_data.experience, experience_before, "beating a friend teaches nothing")


func test_every_hit_lands_on_a_neighbor() -> void:
	_open_grid(5)
	var thumps := _scene_unit("thumps", Enums.UnitFaction.ENEMY, Vector2i(2, 0))
	_scene_unit("left", Enums.UnitFaction.PLAYER, Vector2i(1, 0))
	_scene_unit("right", Enums.UnitFaction.PLAYER, Vector2i(3, 0))
	var far := _scene_unit("far", Enums.UnitFaction.PLAYER, Vector2i(4, 0))
	var far_hp := far.current_hp
	var presenter := RecordingPresenter.new()

	await thumps.execute_combat_sequence(thumps, _tantrum(), presenter)

	var damaged := _damaged(presenter)
	assert_eq(damaged.size(), 3)
	for target: String in damaged:
		assert_has(["left", "right"], target)
	assert_eq(far.current_hp, far_hp)


func test_outburst_adds_a_blow_when_he_is_crowded() -> void:
	_open_grid(3)
	var thumps := _scene_unit("thumps", Enums.UnitFaction.ENEMY, Vector2i(1, 0))
	thumps.character_data.equipped_passives = ["Outburst"]
	_scene_unit("left", Enums.UnitFaction.PLAYER, Vector2i(0, 0))
	_scene_unit("right", Enums.UnitFaction.PLAYER, Vector2i(2, 0))
	var presenter := RecordingPresenter.new()

	await thumps.execute_combat_sequence(thumps, _tantrum(), presenter)

	assert_eq(presenter.count("damage"), 4)


func test_tantrum_greys_out_with_nobody_close() -> void:
	_open_grid(4)
	var thumps := _scene_unit("thumps", Enums.UnitFaction.PLAYER, Vector2i(0, 0))
	_scene_unit("far", Enums.UnitFaction.ENEMY, Vector2i(3, 0))
	var tantrum := MoveData.get_move("Tantrum")
	assert_false(tantrum.has_meaningful_effect_on(thumps))
	_scene_unit("friend", Enums.UnitFaction.PLAYER, Vector2i(1, 0))
	assert_true(tantrum.has_meaningful_effect_on(thumps), "a friend in reach is a target too")

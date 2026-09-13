## MapPresenter's half of clip selection: WHETHER side art may play for an
## attack direction (the in-place rule the FE7 scene doesn't need), layered
## on the resolver's WHICH. Replaces the direction tests from test_unit.gd:
## a diagonal shows the side-swing mirrored, a due-vertical attack boops.
extends GutTest


func _character(keys: Array, overrides: Dictionary = {}) -> CharacterData:
	var character := CharacterData.new()
	character.character_id = "probe"
	for key: String in keys:
		character.attack_animations[key] = { "path": "res://stub/%s.png" % key, "frames": 1, "key": key }
	character.animation_overrides = overrides
	return character


func _move(range_value: int, damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL,
		style: String = "auto") -> Move:
	var move := Move.new()
	move.move_name = "Probe"
	move.attack_range = range_value
	move.damage_type = damage_type
	move.animation_style = style
	return move


func _picked(character: CharacterData, delta: Vector2i, move: Move) -> String:
	return str(MapPresenter.pick_clip(character, delta, move).get("key", ""))


func test_side_clips_play_for_horizontal_and_diagonal_attacks() -> void:
	assert_true(MapPresenter.DIAGONAL_USES_SIDE_ANIMATION, "the shipped setting")
	assert_true(MapPresenter.side_clip_allowed(Vector2i(1, 0)), "due east")
	assert_true(MapPresenter.side_clip_allowed(Vector2i(-2, 0)), "due west at range")
	assert_true(MapPresenter.side_clip_allowed(Vector2i(1, 1)), "diagonal counts as side")
	assert_true(MapPresenter.side_clip_allowed(Vector2i(-1, 2)), "knight's-move-ish diagonal too")


func test_due_vertical_attacks_boop() -> void:
	assert_false(MapPresenter.side_clip_allowed(Vector2i(0, 1)), "due north/south has no side art")
	assert_false(MapPresenter.side_clip_allowed(Vector2i(0, -3)))
	assert_false(MapPresenter.side_clip_allowed(Vector2i.ZERO), "on top of each other: nudge")
	var character := _character(["melee", "ranged"])
	assert_true(MapPresenter.pick_clip(character, Vector2i(0, 1), _move(1)).is_empty(),
			"vertical → {} → the presenter boops")


func test_pick_clip_follows_the_distance_unless_the_move_is_tagged() -> void:
	var character := _character(["melee", "ranged"])
	assert_eq(_picked(character, Vector2i(1, 0), _move(3)), "melee",
			"a range-3 move fired at an adjacent target swings (the use_when-era rule)")
	assert_eq(_picked(character, Vector2i(2, 0), _move(3)), "ranged", "and shoots at range")
	assert_eq(_picked(character, Vector2i(1, 0), _move(3, Enums.DamageType.SPECIAL, "ranged")), "ranged",
			"animationStyle=ranged forces the shot point-blank")
	assert_eq(_picked(character, Vector2i(2, 0), _move(3, Enums.DamageType.PHYSICAL, "melee")), "melee",
			"animationStyle=melee forces the swing at distance 2")
	assert_eq(_picked(character, Vector2i(1, 1), _move(2)), "ranged",
			"a diagonal neighbour is TWO tiles away in this game (Manhattan) — it takes a range-2 move and reads as a shot")
	assert_eq(_picked(character, Vector2i(2, 1), _move(3)), "ranged", "Manhattan 3 → the shot")
	assert_eq(MapPresenter.attack_distance(Vector2i(-2, 2)), 4, "Manhattan — the gameplay metric, never Chebyshev")
	assert_eq(MapPresenter.attack_distance(Vector2i(1, 1)), 2)


func test_pick_clip_falls_back_within_the_table_before_booping() -> void:
	var melee_only := _character(["melee"])
	assert_eq(_picked(melee_only, Vector2i(2, 0), _move(3)), "melee",
			"no ranged clip → the swing at range, not a boop (Grasker)")
	var bow_only := _character(["ranged"])
	assert_eq(_picked(bow_only, Vector2i(1, 0), _move(1)), "ranged",
			"no melee clip → the shot, point-blank (the archer)")
	var idle_only := _character([])
	assert_true(MapPresenter.pick_clip(idle_only, Vector2i(1, 0), _move(1)).is_empty(),
			"no clips at all → boop")


func test_pick_clip_applies_character_overrides() -> void:
	var character := _character(["melee", "ranged"], { "melee_special": "ranged" })
	assert_eq(_picked(character, Vector2i(-1, 0), _move(1, Enums.DamageType.SPECIAL)), "ranged")
	assert_eq(_picked(character, Vector2i(-1, 0), _move(1)), "melee", "physical untouched")


func test_pick_clip_survives_null_inputs() -> void:
	assert_true(MapPresenter.pick_clip(null, Vector2i(1, 0), _move(1)).is_empty())
	var character := _character(["melee"])
	assert_eq(_picked(character, Vector2i(1, 0), null), "melee", "null move = a plain swing")

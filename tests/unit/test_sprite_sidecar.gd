## An idle PNG is one square frame or a strip of them, and every reader of
## the idle (map unit, combat puppet, portrait crop) stands on frame 0 until
## idles play. Grasker's 3-frame melee strip stands in for the first idle
## strip the art board asks Lawrence for.
extends GutTest


const UNIT_SCENE: String = "res://scenes/battle/unit.tscn"
const GRASKER_PATH: String = "res://data/characters/grasker.json"
const GRASKER_IDLE: String = "res://art/sprites/characters/grasker/idle.png"  # sidecar pivot (32, 32)
const STRIP_PATH: String = "res://art/sprites/characters/grasker/melee.png"  # 3 frames of 64×64
const FRAME_SIZE: int = 64


func after_each() -> void:
	GridManager.clear_grid()


func _spawn_grasker_on_the_strip() -> Unit:
	var tile := Tile.new()
	var tile_sprite := Sprite2D.new()
	tile_sprite.name = "Sprite2D"
	tile.add_child(tile_sprite)
	add_child_autofree(tile)
	tile.terrain_type_name = "Plains"
	GridManager.register_tile(tile)
	var unit: Unit = (load(UNIT_SCENE) as PackedScene).instantiate() as Unit
	unit.character_json_path = GRASKER_PATH
	var container := Node2D.new()
	add_child_autofree(container)
	container.add_child(unit)
	unit.initialize(tile)
	unit.character_data.sprite_sheet_path = STRIP_PATH
	return unit


func test_a_square_sheet_is_its_own_frame() -> void:
	assert_eq(SpriteSidecar.idle_frame_rect(Vector2i(64, 64)), Rect2i(0, 0, 64, 64))


func test_a_strip_stands_on_its_first_square() -> void:
	assert_eq(SpriteSidecar.idle_frame_rect(Vector2i(256, 64)), Rect2i(0, 0, 64, 64))


func test_a_wide_single_frame_is_not_cut() -> void:
	assert_eq(SpriteSidecar.idle_frame_rect(Vector2i(96, 64)), Rect2i(0, 0, 96, 64),
			"under two squares wide: one non-square frame")
	assert_eq(SpriteSidecar.idle_frame_rect(Vector2i(160, 64)), Rect2i(0, 0, 160, 64),
			"not a whole number of squares: one frame")


func test_a_single_frame_texture_comes_back_untouched() -> void:
	var texture: Texture2D = load(GRASKER_IDLE)
	assert_same(SpriteSidecar.idle_frame(texture), texture)


func test_the_pivot_reads_in_one_frame_not_the_whole_strip() -> void:
	var strip: Texture2D = load(STRIP_PATH)
	var frame: Texture2D = SpriteSidecar.idle_frame(strip)
	assert_eq(frame.get_size(), Vector2(FRAME_SIZE, FRAME_SIZE))
	assert_eq(SpriteSidecar.read(GRASKER_IDLE, frame)["offset"], Vector2.ZERO,
			"pivot (32, 32) is the frame's centre: no offset")
	assert_ne(SpriteSidecar.read(GRASKER_IDLE, strip)["offset"], Vector2.ZERO,
			"read against the whole strip, the same pivot lands a frame off")


func test_the_map_unit_stands_on_frame_zero() -> void:
	var unit := _spawn_grasker_on_the_strip()
	unit._load_character_sprite()
	assert_eq(unit._sprite.texture.get_size(), Vector2(FRAME_SIZE, FRAME_SIZE),
			"one frame, not the row of three")


func test_the_combat_puppet_stands_on_frame_zero() -> void:
	var unit := _spawn_grasker_on_the_strip()
	var puppet := CombatPuppet.new()
	add_child_autofree(puppet)
	puppet.setup(unit, false, 3)
	assert_eq(puppet.sprite.texture.get_size(), Vector2(FRAME_SIZE, FRAME_SIZE))


func test_the_fallback_portrait_crops_inside_frame_zero() -> void:
	var character := CharacterData.new()
	character.sprite_sheet_path = STRIP_PATH
	var portrait := CharacterPortrait._derive_from_sprite(character) as AtlasTexture
	assert_not_null(portrait)
	assert_lte(portrait.region.end.x, float(FRAME_SIZE), "the crop stays inside the first frame")

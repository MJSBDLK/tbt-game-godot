## Combat stage viewer: the fight's stage held up to look at. Spaceman faces
## the grunt with every scenery layer showing; no exchange plays, so the stars
## twinkle and the smoke drifts for as long as you watch. The ` console turns
## the star_* and smoke_* dials live.
##   F      fade the stage out and back in
##   S      scenery near both fighters: all of it / none
##   1 - 4  tiles between the fighters
##
## Launch (HUD scene, routed into HUDViewport like the combat sandbox):
##   godot-4 --path . -- --map=scenes/debug/combat_stage_viewer.tscn
## or set DebugConfig.dev_launch_scene to that path and press F5.
extends Control


const UNIT_SCENE: String = "res://scenes/battle/unit.tscn"
const ATTACKER_PATH: String = "res://data/characters/spaceman.json"
const DEFENDER_PATH: String = "res://data/characters/grunt.json"
const MOVE_NAME: String = "Bonk"
const START_DISTANCE: int = 2
const KEYS_HINT: String = "F fade · S scenery · 1-4 distance"
const FADE_PAUSE_SECONDS: float = 0.4

var scene: CombatScene = null
var _arena: Node2D = null
var _attacker: Unit = null
var _defender: Unit = null
var _all_scenery: bool = true
var _fading: bool = false


func _ready() -> void:
	# Off-canvas home for the throwaway units, so their map-side bits never show.
	_arena = Node2D.new()
	_arena.name = "Arena"
	_arena.position = Vector2(-4000, -4000)
	add_child(_arena)
	GridManager.clear_grid()
	for x: int in range(-2, 9):
		for y: int in range(-2, 3):
			_tile(x, y)
	_set_scenery(true)
	_attacker = _spawn(ATTACKER_PATH, Enums.UnitFaction.PLAYER, GridManager.get_tile(0, 0))
	_defender = _spawn(DEFENDER_PATH, Enums.UnitFaction.ENEMY, GridManager.get_tile(START_DISTANCE, 0))
	scene = CombatScene.new()
	UIManager.get_overlay_layer().add_child(scene)
	scene.setup(_attacker, _defender, MoveData.get_move(MOVE_NAME))
	(scene.get_node("Stage/SkipHint") as Label).text = KEYS_HINT
	await scene.wipe_in(false)


# The stage lives in UIManager's overlay, not under this scene: take it along.
func _exit_tree() -> void:
	if is_instance_valid(scene):
		scene.queue_free()
	GridManager.clear_grid()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or scene == null:
		return
	match key.keycode:
		KEY_F:
			_fade()
		KEY_S:
			_set_scenery(not _all_scenery)
			# Left is the defender: the player's unit stands on the right.
			(scene.get_node("Stage/Backdrop") as CombatBackdrop).choose_layers(_defender, _attacker)
		KEY_1, KEY_2, KEY_3, KEY_4:
			scene.respace(key.keycode - KEY_0, _defender, false)
		_:
			return
	get_viewport().set_input_as_handled()


func _fade() -> void:
	if _fading:
		return
	_fading = true
	await scene.wipe_out(false)
	await get_tree().create_timer(FADE_PAUSE_SECONDS).timeout
	await scene.wipe_in(false)
	_fading = false


## Every tile names every scenery the backdrop knows, or none.
func _set_scenery(all: bool) -> void:
	_all_scenery = all
	var names := PackedStringArray(CombatBackdrop.scenery_names().keys()) if all else PackedStringArray()
	for tile: Node in _arena.get_children():
		if tile is Tile:
			(tile as Tile).scenery = names


func _tile(x: int, y: int) -> Tile:
	var tile := Tile.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	tile.add_child(sprite)
	_arena.add_child(tile)
	tile.grid_x = x
	tile.grid_y = y
	tile.terrain_type_name = "Plains"
	tile.position = Vector2(x, y) * CombatScene.TILE_SPRITE_PX
	GridManager.register_tile(tile)
	return tile


func _spawn(json_path: String, faction: Enums.UnitFaction, tile: Tile) -> Unit:
	var unit: Unit = (load(UNIT_SCENE) as PackedScene).instantiate() as Unit
	unit.character_json_path = json_path
	unit.faction = faction
	_arena.add_child(unit)
	unit.initialize(tile)
	return unit

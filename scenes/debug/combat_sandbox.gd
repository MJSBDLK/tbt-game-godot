## Combat sandbox — Lawrence's review tool for the combat scene. Pick two
## characters and a move, press Fight, watch the exchange play in the
## CombatScene; tick Loop to replay until you stop it. Nothing here touches
## the campaign: two throwaway units live off-canvas on a two-tile grid and
## are rebuilt every round.
##
## Launch (HUD scene — SceneRouter routes Controls into HUDViewport):
##   godot-4 --path . -- --map=scenes/debug/combat_sandbox.tscn
## or set DebugConfig.dev_launch_scene to that path.
##
## The attacker is PLAYER faction so it stands on the right (plan D2); the
## defender is ENEMY and counters with its own move when it has one.
extends Control


const UNIT_SCENE: String = "res://scenes/battle/unit.tscn"
const CHARACTERS_DIRECTORY: String = "res://data/characters/"
const LOOP_PAUSE_SECONDS: float = 0.6

var _attacker_picker: OptionButton = null
var _defender_picker: OptionButton = null
var _move_picker: OptionButton = null
var _counter_picker: OptionButton = null
var _distance_picker: SpinBox = null
var _loop_toggle: CheckBox = null
var _fight_button: Button = null
var _status: Label = null
var _arena: Node2D = null
var _character_paths: Array[String] = []
var _fighting: bool = false
var _stop_requested: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_character_paths = _list_characters()
	_build_ui()
	# Off-canvas home for the throwaway units so their map-side popups (XP)
	# never land on top of the stage.
	_arena = Node2D.new()
	_arena.name = "Arena"
	_arena.position = Vector2(-4000, -4000)
	add_child(_arena)


func _build_ui() -> void:
	var column := VBoxContainer.new()
	column.position = Vector2(12, 12)
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	var title := Label.new()
	title.text = "COMBAT SANDBOX — pick two, press Fight; any press during the scene skips"
	column.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)

	_attacker_picker = _character_picker("spaceman")
	row.add_child(_labelled("Attacker (right)", _attacker_picker))
	_move_picker = _move_picker_for("Bonk")
	row.add_child(_labelled("Move", _move_picker))
	_defender_picker = _character_picker("grunt")
	row.add_child(_labelled("Defender (left)", _defender_picker))
	_counter_picker = _move_picker_for("Bonk")
	_counter_picker.add_item("(no counter)", 0)
	row.add_child(_labelled("Counter", _counter_picker))
	_distance_picker = SpinBox.new()
	_distance_picker.min_value = 1
	_distance_picker.max_value = CombatScene.MAX_SPREAD_TILES + 1  # one past the cap, to see it clamp
	_distance_picker.value = 1
	row.add_child(_labelled("Distance (tiles)", _distance_picker))

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	column.add_child(controls)
	_loop_toggle = CheckBox.new()
	_loop_toggle.text = "Loop"
	controls.add_child(_loop_toggle)
	_fight_button = Button.new()
	_fight_button.text = "Fight"
	_fight_button.pressed.connect(_on_fight_pressed)
	controls.add_child(_fight_button)
	var stop := Button.new()
	stop.text = "Stop loop"
	stop.pressed.connect(func() -> void: _stop_requested = true)
	controls.add_child(stop)

	_status = Label.new()
	_status.text = "Ready."
	column.add_child(_status)


func _labelled(text: String, control: Control) -> Control:
	var box := VBoxContainer.new()
	var label := Label.new()
	label.text = text
	box.add_child(label)
	box.add_child(control)
	return box


func _character_picker(default_id: String) -> OptionButton:
	var picker := OptionButton.new()
	for index: int in _character_paths.size():
		var id: String = _character_paths[index].get_file().get_basename()
		picker.add_item(id, index)
		if id == default_id:
			picker.select(index)
	return picker


func _move_picker_for(default_name: String) -> OptionButton:
	var picker := OptionButton.new()
	var names: Array[String] = MoveData.get_move_names()
	for index: int in names.size():
		picker.add_item(names[index], index + 1)
		if names[index] == default_name:
			picker.select(index)
	return picker


func _list_characters() -> Array[String]:
	var files: Array[String] = []
	var directory := DirAccess.open(CHARACTERS_DIRECTORY)
	if directory == null:
		return files
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			files.append(CHARACTERS_DIRECTORY + file_name)
		file_name = directory.get_next()
	directory.list_dir_end()
	files.sort()
	return files


# =============================================================================
# FIGHT
# =============================================================================

func _on_fight_pressed() -> void:
	if _fighting:
		return
	_fighting = true
	_stop_requested = false
	_fight_button.disabled = true
	var round_index := 0
	while true:
		round_index += 1
		_status.text = "Round %d…" % round_index
		await _one_exchange()
		if not _loop_toggle.button_pressed or _stop_requested or not is_inside_tree():
			break
		await get_tree().create_timer(LOOP_PAUSE_SECONDS).timeout
	_status.text = "Done (%d round%s)." % [round_index, "" if round_index == 1 else "s"]
	_fight_button.disabled = false
	_fighting = false


func _one_exchange() -> void:
	_clear_arena()
	GridManager.clear_grid()
	# A row of tiles from the attacker to the defender: the stage spaces the
	# puppets by this distance (Lawrence's reach check) and shoves have room.
	var distance: int = int(_distance_picker.value)
	var attacker_tile := _tile(0, 0)
	var defender_tile: Tile = null
	for x: int in range(1, distance + 3):
		var tile := _tile(x, 0)
		if x == distance:
			defender_tile = tile
	var attacker := _spawn(_character_paths[_attacker_picker.get_selected_id()], Enums.UnitFaction.PLAYER, attacker_tile)
	var defender := _spawn(_character_paths[_defender_picker.get_selected_id()], Enums.UnitFaction.ENEMY, defender_tile)
	var move: Move = MoveData.get_move(_move_picker.get_item_text(_move_picker.selected))
	if move == null:
		_status.text = "No such move."
		return
	if _counter_picker.get_selected_id() != 0:
		defender.assigned_move = MoveData.get_move(_counter_picker.get_item_text(_counter_picker.selected))
	# Straight to the scene regardless of the setting — this IS the review tool.
	await attacker.execute_combat_sequence(defender, move, ScenePresenter.new())


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


func _clear_arena() -> void:
	for child: Node in _arena.get_children():
		_arena.remove_child(child)
		child.queue_free()

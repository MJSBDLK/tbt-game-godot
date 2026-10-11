## Headless probe: press pad buttons on a live battle board and print what the
## hint bar named before each press next to what the press actually did. A
## "bar before" that disagrees with the "now" line under it is a lying bar.
## Run from the project root:
##   godot-4 --headless --path . -s tools/diag/button_map_probe.gd [-- --map=<token>]
## Presses go in through the root viewport's push_input: the same _input / GUI
## / _unhandled_input path a pad press takes, but Input's held-action state
## never sees them, so nothing here exercises hold-to-repeat.
## Settings persistence is switched off first, so a press that flips a setting
## never reaches the player's settings.cfg. Same -s rules as hint_bar_probe:
## autoloads are fetched by path, class_name scripts are loaded at run time.
extends SceneTree

const SETTLE_FRAMES: int = 30
const BATTLE_FRAMES: int = 120

var _commands: GDScript = null
var _enums: GDScript = null


func _auto(autoload_name: String) -> Node:
	return get_root().get_node_or_null(NodePath(autoload_name))


func _initialize() -> void:
	get_root().size = Vector2i(1920, 1080)
	var game_root: Node = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	get_root().add_child(game_root)
	_run()


func _run() -> void:
	_auto("Settings").persistence_enabled = false
	for i: int in SETTLE_FRAMES:
		await process_frame
	_commands = load("res://scripts/ui/components/hint_bar_commands.gd")
	_enums = load("res://scripts/core/enums.gd")
	var phase_started: Array[bool] = [false]
	_auto("TurnManager").player_phase_started.connect(func(_turn: int) -> void: phase_started[0] = true)
	_auto("SceneRouter").change_scene_to(_pick_map())
	# The player phase starts when the opening banner ends, on a wall-clock
	# timer that headless frames outrun: wait for the phase, not for frames.
	var deadline: int = Time.get_ticks_msec() + 20000
	while not (phase_started[0] and _auto("InputManager").input_enabled) \
			and Time.get_ticks_msec() < deadline:
		await process_frame
	for i: int in BATTLE_FRAMES:
		await process_frame
	print("[probe] player phase started=", phase_started[0], " input_enabled=", _auto("InputManager").input_enabled)
	await _scenario()
	quit()


func _pick_map() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			return _auto("SceneRouter").resolve_scene_path(arg.trim_prefix("--map="))
	return "res://scenes/battle/maps/test_map_01.tscn"


func _scenario() -> void:
	var turn_manager: Node = _auto("TurnManager")
	var enemy: Node = turn_manager._enemy_units[0]
	var ally: Node = turn_manager._player_units[0]
	print("[probe] map up: %d players, %d enemies; enemy %s at %s, ally %s at %s" % [
			turn_manager._player_units.size(), turn_manager._enemy_units.size(),
			enemy.unit_name, _cell(enemy.current_tile), ally.unit_name, _cell(ally.current_tile)])
	_report("boot (mouse)")

	await _press_button(JOY_BUTTON_DPAD_RIGHT, "D-Right (summon the cursor)")
	await _aim(enemy.current_tile, "cursor onto the enemy")
	await _press_trigger("RT over the enemy")
	await _aim(_empty_tile(), "cursor off the enemy, its pin still up")
	await _press_trigger("RT over empty ground")
	await _press_trigger("RT over empty ground, again")
	await _aim(enemy.current_tile, "cursor onto the enemy, the army zone up")
	await _press_trigger("RT over the enemy")
	await _press_trigger("RT over the enemy, again")
	await _aim(_empty_tile(), "cursor onto empty ground")
	await _press_button(JOY_BUTTON_Y, "Y over empty ground")
	await _press_button(JOY_BUTTON_Y, "Y over empty ground, again")
	await _aim(ally.current_tile, "cursor onto our unit")
	await _press_button(JOY_BUTTON_Y, "Y over our unit")
	await _press_button(JOY_BUTTON_B, "B (close what Y opened)")
	await _press_button(JOY_BUTTON_RIGHT_SHOULDER, "RB")
	await _press_trigger("RT with a unit selected")
	await _press_button(JOY_BUTTON_B, "B")
	await _press_button(JOY_BUTTON_X, "X")
	await _press_button(JOY_BUTTON_B, "B")
	await _press_button(JOY_BUTTON_B, "B on the open board")
	await _press_button(JOY_BUTTON_B, "B")


func _press_button(button: JoyButton, what: String) -> void:
	_report_before(what)
	var press := InputEventJoypadButton.new()
	press.button_index = button
	press.pressed = true
	get_root().push_input(press)
	await _frames(3)
	var release := InputEventJoypadButton.new()
	release.button_index = button
	release.pressed = false
	get_root().push_input(release)
	await _frames(3)
	_report(what)


func _press_trigger(what: String) -> void:
	_report_before(what)
	for value: float in [0.3, 0.7, 1.0, 0.6, 0.2, 0.0]:
		var motion := InputEventJoypadMotion.new()
		motion.axis = JOY_AXIS_TRIGGER_RIGHT
		motion.axis_value = value
		get_root().push_input(motion)
		await _frames(1)
	await _frames(2)
	_report(what)


func _aim(tile: Node, what: String) -> void:
	_auto("InputManager")._cursor.place_free(tile)
	await _frames(3)
	_report(what)


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _empty_tile() -> Node:
	var grid_manager: Node = _auto("GridManager")
	for y: int in range(0, 12):
		for x: int in range(0, 20):
			var tile: Node = grid_manager.get_tile(x, y)
			if tile != null and tile.current_unit == null:
				return tile
	return null


func _cell(tile: Node) -> String:
	return "-" if tile == null or not is_instance_valid(tile) else "(%d,%d)" % [tile.grid_x, tile.grid_y]


var _bar_before: String = ""


func _report_before(_what: String) -> void:
	_bar_before = _bar_text()


func _report(what: String) -> void:
	var state_manager: Node = _auto("GameStateManager")
	var input_manager: Node = _auto("InputManager")
	var selected: Node = input_manager.get_selected_unit()
	var controller: Node = get_first_node_in_group("threat_overlay_controller")
	var zone := "?"
	if controller != null:
		var pinned: PackedStringArray = []
		for unit: Node in controller._pinned:
			pinned.append(unit.unit_name)
		zone = ("ARMY" if controller._army_shown else "-") + ("" if pinned.is_empty() else " PINNED " + ",".join(pinned))
	print("[probe] %s" % what)
	if not _bar_before.is_empty():
		print("          bar before: %s" % _bar_before)
		_bar_before = ""
	print("          now: input=%s state=%s selected=%s hovered=%s zone=%s type_icons=%s" % [
			input_manager.input_enabled,
			_enums.InputState.keys()[state_manager.current_state],
			"-" if selected == null else selected.unit_name,
			_cell(input_manager.get_hovered_tile()), zone,
			_auto("Settings").unit_type_icons_enabled])
	print("          bar now:    %s" % _bar_text())


func _bar_text() -> String:
	var bar: Node = get_root().find_child("HintBar", true, false)
	if bar == null:
		return "(no bar)"
	var parts: PackedStringArray = []
	for item: Node in bar._items_box.get_children():
		if item.is_queued_for_deletion():
			continue
		var verb: Node = item.get_node_or_null("Verb")
		parts.append("%s %s" % [_glyph_text(item.get_node_or_null("Glyph")),
				"?" if verb == null else verb.text])
	var models: Array = _commands.Model.keys()
	var hovers: Array = _commands.Hover.keys()
	return "[%s hover=%s] %s" % [models[bar.last_model], hovers[bar.last_hover], " | ".join(parts)]


func _glyph_text(glyph: Node) -> String:
	if glyph == null:
		return "(none)"
	if glyph is Label:
		return glyph.text
	if glyph is TextureRect:
		return "<%s>" % (glyph as TextureRect).texture.resource_path.get_file().get_basename()
	var character: Node = glyph.get_node_or_null("Char")
	if character is TextureRect:
		return "<%s>" % (character as TextureRect).texture.resource_path.get_file().get_basename()
	return "(%s)" % glyph.get_class()

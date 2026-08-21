## Headless probe: boot GameRoot, route into a battle map, wait, and dump
## everything about the HintBar — armed? visible in tree? where is its rect?
## what's in it? Run from the project root:
##   godot-4 --headless --path . -s tools/diag/hint_bar_probe.gd [-- --map=<token>]
## Kept as a diagnostic tool — it found the 0×0-bar bug (2026-08-21) that the
## unit tests missed: the bar was armed, visible, populated, and anchored off
## the top of the screen. Rect dumps beat theories.
##
## -s gotchas: autoload names are NOT identifiers at main-script compile time
## (fetch by path), and naming a class_name whose script references an
## autoload (HintBar → UIManager) compiles it too early and poisons it for
## the whole run ("Nonexistent function 'new'") — type those as Control/Node.
extends SceneTree

const SETTLE_FRAMES: int = 30
const BATTLE_FRAMES: int = 120


## Autoloads are not compile-time identifiers in a -s main script; fetch by path.
func _auto(autoload_name: String) -> Node:
	return get_root().get_node_or_null(NodePath(autoload_name))


## UIManager is reparented into HUDViewport by GameRoot — /root/UIManager won't
## resolve; search for it.
func _ui_manager() -> Node:
	return get_root().find_child("UIManager", true, false)


func _initialize() -> void:
	# A real window, or the HUD canvas is 2×2 and every rect is meaningless.
	get_root().size = Vector2i(1920, 1080)
	var game_root: Node = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	get_root().add_child(game_root)
	_run()


func _run() -> void:
	for i: int in SETTLE_FRAMES:
		await process_frame
	var scene_router: Node = _auto("SceneRouter")
	print("[probe] after boot: scene=", scene_router.get_current_scene())
	var map_path := _pick_map()
	print("[probe] routing to ", map_path)
	scene_router.change_scene_to(map_path)
	for i: int in BATTLE_FRAMES:
		await process_frame
	_dump()
	quit()


func _pick_map() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			return _auto("SceneRouter").resolve_scene_path(arg.trim_prefix("--map="))
	var dir := DirAccess.open("res://scenes/battle/maps/")
	if dir != null:
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if name.ends_with(".tscn"):
				return "res://scenes/battle/maps/" + name
			name = dir.get_next()
	return ""


func _dump() -> void:
	var scene_router: Node = _auto("SceneRouter")
	var grid_manager: Node = _auto("GridManager")
	var turn_manager: Node = _auto("TurnManager")
	var state_manager: Node = _auto("GameStateManager")
	var settings: Node = _auto("Settings")
	var input_source: Node = _auto("InputSource")
	print("[probe] scene now=", scene_router.get_current_scene(),
			" grid_ready=", grid_manager.is_grid_ready(),
			" TurnManager phase=", turn_manager.current_phase, " turn=", turn_manager.turn_count,
			" is_player_phase=", turn_manager.is_player_phase())
	print("[probe] state=", Enums.InputState.keys()[state_manager.current_state],
			" show_control_hints=", settings.show_control_hints,
			" last_device=", input_source.last_device)
	var ui_manager: Node = _ui_manager()
	print("[probe] UIManager=", ui_manager, " path=", ui_manager.get_path() if ui_manager else "null")
	var bar: Control = ui_manager.get_hint_bar() if ui_manager != null else null
	print("[probe] bar=", bar)
	if bar == null:
		return
	print("[probe] battle_active=", bar.battle_active, " enemy_phase=", bar.enemy_phase,
			" last_model=", bar.last_model, " visible=", bar.visible,
			" visible_in_tree=", bar.is_visible_in_tree())
	print("[probe] step='", bar._step_label.text, "' step.visible=", bar._step_label.visible,
			" items=", bar._items_box.get_child_count())
	print("[probe] bar rect=", bar.get_global_rect(), " row rect=", bar._row.get_global_rect(),
			" row min=", bar._row.custom_minimum_size)
	print("[probe] step rect=", bar._step_label.get_global_rect(),
			" items rect=", bar._items_box.get_global_rect())
	for child: Node in bar._items_box.get_children():
		print("[probe]   item ", child.name, " rect=", (child as Control).get_global_rect())
	var hud_size: Vector2 = Vector2(scene_router.get_hud_viewport().size)
	print("[probe] hud viewport size=", hud_size)
	var row_rect: Rect2 = bar._row.get_global_rect()
	print("[probe] ROW ON CANVAS: ", Rect2(Vector2.ZERO, hud_size).encloses(row_rect),
			"  (row must lie inside ", Rect2(Vector2.ZERO, hud_size), ")")
	var node: Node = bar
	while node != null:
		var vis: String = "n/a"
		if node is CanvasItem:
			vis = str((node as CanvasItem).visible)
		elif node is CanvasLayer:
			vis = str((node as CanvasLayer).visible)
		print("[probe]   ^ ", node.get_path(), " (", node.get_class(), ") visible=", vis)
		node = node.get_parent()

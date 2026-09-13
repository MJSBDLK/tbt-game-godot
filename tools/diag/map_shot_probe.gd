## Screenshot probe: boot GameRoot, route into a battle map, pin the camera,
## save the root viewport to a PNG. Needs a real display (the headless
## renderer draws nothing). Run from the project root:
##
##   DISPLAY=:0 godot-4 --path . --resolution 1280x720 -s tools/diag/map_shot_probe.gd \
##       -- --map=lawrence_test_map --out=res://_shot.png --zoom=2 --focus=decor
##
##   --map    a SceneRouter dev-launch token (bare map name, project path, or res://)
##   --out    where the PNG lands (default res://_shot.png — delete it after)
##   --zoom   screen pixels per world pixel (1 = whole map on a 1280x720 window)
##   --focus  all (map center) | decor (center of the DecorationTileLayer's cells)
##
## Used 2026-09-07 for the terrain-stack before/after (the decoration layer
## fix) by running it in a `git worktree` of the old branch and diffing the
## PNGs — cheaper than describing pixels. The HUD is hidden so the board is
## unobstructed. -s gotchas: autoload names are NOT identifiers at
## main-script compile time (fetch by path); the camera controller lerps
## toward its own private targets every frame, so pin `_target_position` and
## `_target_zoom` too or the shot drifts.
extends SceneTree

const SETTLE_FRAMES := 30
const BATTLE_FRAMES := 90
const PIN_FRAMES := 12


func _auto(autoload_name: String) -> Node:
	return get_root().get_node_or_null(NodePath(autoload_name))


func _arg(key: String, fallback: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.substr(key.length() + 3)
	return fallback


func _initialize() -> void:
	var game_root: Node = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	get_root().add_child(game_root)
	_run()


func _run() -> void:
	for i in SETTLE_FRAMES:
		await process_frame
	var router: Node = _auto("SceneRouter")
	var map_path: String = router.resolve_scene_path(_arg("map", "lawrence_test_map"))
	router.change_scene_to(map_path)
	for i in BATTLE_FRAMES:
		await process_frame
	var hud: Node = get_root().find_child("HUDDisplay", true, false)
	if hud != null:
		hud.visible = false
	var cam: Camera2D = router.get_world_camera()
	var zoom := float(_arg("zoom", "2"))
	cam.position_smoothing_enabled = false
	cam.set("_target_zoom", zoom)
	cam.zoom = Vector2(zoom, zoom)
	var target: Vector2 = _auto("GridManager").get_map_world_rect().get_center()
	if _arg("focus", "all") == "decor":
		var scene: Node = router.get_current_scene()
		var layer: TileMapLayer = scene.find_child("DecorationTileLayer", true, false)
		if layer != null and not layer.get_used_cells().is_empty():
			var cells := layer.get_used_cells()
			var lo := Vector2(layer.map_to_local(cells[0]))
			var hi := lo
			for c: Vector2i in cells:
				var p := layer.map_to_local(c)
				lo = lo.min(p)
				hi = hi.max(p)
			target = (lo + hi) / 2.0
	cam.global_position = target.round()
	cam.set("_target_position", target.round())
	cam.force_update_scroll()
	for i in PIN_FRAMES:
		await process_frame
	var img := get_root().get_texture().get_image()
	var out := _arg("out", "res://_shot.png")
	img.save_png(out)
	print("[shot] saved %s %s cam=%s zoom=%s" % [out, img.get_size(), cam.global_position, cam.zoom])
	quit()

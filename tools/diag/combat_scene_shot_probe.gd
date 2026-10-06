## Screenshot probe for the CombatScene HUD: boot GameRoot, route into the
## combat sandbox, stand two throwaway units with its own helpers, mount a
## CombatScene straight onto the overlay layer, freeze it mid-strike (move
## row filled, projection band showing, optional statuses on both sides) and
## save the root viewport. Needs a real display. Run from the project root:
##
##   DISPLAY=:0 godot-4 --path . --resolution 1280x720 -s tools/diag/combat_scene_shot_probe.gd \
##       -- --attacker=spaceman --defender=grunt --move=Bonk --counter=Bonk \
##          --defender_status=BELLOWS,BELLOWS --attacker_status=BURN --out=res://_shot.png
##
##   --distance         map tiles between the pair (default 1; the stage spaces by it)
##   --counter          also fill the defender's row (as if its counter were swinging)
##   --defender_status  comma list applied to the defender before the shot (restacks count up)
##   --attacker_status  same for the attacker
##   --fade             shoot a frame mid-wipe at this alpha (0..1); portraits
##                      hide, as they do during a real wipe
##   --defender_scenery comma list of scenery names put on the defender's tile
##                      (CombatBackdrop shows the layers they call for)
##   --attacker_scenery same for the attacker
##   --smoke_frames     also save this many consecutive smoke frames, frozen a
##                      step apart, as <out>_0.png, <out>_1.png, ...
##
## For eyeballing the stage and its HUD without a hand on the build.
## -s gotchas: autoload names and class_names
## whose scripts touch autoloads are NOT identifiers at main-script compile
## time — everything here is fetched by path and typed as Node/Control.
extends SceneTree

const SETTLE_FRAMES := 30
const ROUTE_FRAMES := 60
const SHOW_FRAMES := 12


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
	router.change_scene_to(router.resolve_scene_path("scenes/debug/combat_sandbox.tscn"))
	for i in ROUTE_FRAMES:
		await process_frame
	var sandbox: Control = router.get_current_scene()
	var enums: GDScript = load("res://scripts/core/enums.gd")
	_auto("GridManager").clear_grid()
	var distance: int = maxi(1, int(_arg("distance", "1")))
	var attacker: Node2D = sandbox._spawn("res://data/characters/%s.json" % _arg("attacker", "spaceman"),
			enums.UnitFaction.PLAYER, sandbox._tile(0, 0))
	var defender_tile: Node = null
	for x: int in range(1, distance + 1):
		defender_tile = sandbox._tile(x, 0)
	var defender: Node2D = sandbox._spawn("res://data/characters/%s.json" % _arg("defender", "grunt"),
			enums.UnitFaction.ENEMY, defender_tile)
	var move_data: GDScript = load("res://scripts/combat/move_data.gd")
	var move: Resource = move_data.get_move(_arg("move", "Bonk"))
	var counter_name: String = _arg("counter", "")
	var counter: Resource = null if counter_name.is_empty() else move_data.get_move(counter_name)

	for scenery_name: String in _arg("defender_scenery", "").split(",", false):
		defender.current_tile.scenery.append(scenery_name)
	for scenery_name: String in _arg("attacker_scenery", "").split(",", false):
		attacker.current_tile.scenery.append(scenery_name)

	var scene: Control = load("res://scripts/combat/scene/combat_scene.gd").new()
	# UIManager is reparented into HUDViewport by GameRoot — not at /root/UIManager.
	var ui_manager: Node = get_root().find_child("UIManager", true, false)
	ui_manager.get_overlay_layer().add_child(scene)
	scene.setup(attacker, defender, move)
	await scene.wipe_in(true)
	move.consume_use()  # the exchange pays before hit 1
	scene.show_strike(attacker, defender, move)
	if counter != null:
		counter.consume_use()
		scene.show_strike(defender, attacker, counter)
	var statuses: Node = _auto("StatusEffectSystem")
	for effect_name: String in _arg("defender_status", "").split(",", false):
		statuses.apply_status_effect_by_name(null, defender, effect_name)
	for effect_name: String in _arg("attacker_status", "").split(",", false):
		statuses.apply_status_effect_by_name(null, attacker, effect_name)
	var fade: String = _arg("fade", "")
	if not fade.is_empty():
		scene.call("_set_portraits_visible", false)
		scene.call("_set_wipe_alpha", float(fade))
	for i in SHOW_FRAMES:
		await process_frame
	var img := get_root().get_texture().get_image()
	var out := _arg("out", "res://_shot.png")
	img.save_png(out)
	print("[shot] saved %s %s" % [out, img.get_size()])
	var plumes: Array[ShaderMaterial] = []
	for node: Node in scene.find_children("*", "TextureRect", true, false):
		var material := (node as CanvasItem).material as ShaderMaterial
		if material != null and material.shader.resource_path.ends_with("smoke_plume.gdshader"):
			plumes.append(material)
	for frame_index: int in int(_arg("smoke_frames", "0")):
		for material: ShaderMaterial in plumes:
			material.set_shader_parameter("time_scale", 0.0)
			material.set_shader_parameter("time_offset",
					(frame_index + 0.5) * float(material.get_shader_parameter("step_seconds")))
		for i in 3:
			await process_frame
		var frame_path := out.get_basename() + "_%d.png" % frame_index
		get_root().get_texture().get_image().save_png(frame_path)
		print("[shot] saved %s" % frame_path)
	quit()

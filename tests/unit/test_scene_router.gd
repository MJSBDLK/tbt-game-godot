## Tests for SceneRouter.resolve_scene_path — the dev-launch token -> scene path
## expansion behind `--map=` / DebugConfig.dev_launch_scene.
extends GutTest


func test_bare_map_name_expands_to_battle_maps() -> void:
	assert_eq(SceneRouter.resolve_scene_path("empty_test_map"),
			"res://scenes/battle/maps/empty_test_map.tscn",
			"bare name -> battle maps dir, .tscn appended")


func test_bare_name_with_suffix_not_doubled() -> void:
	assert_eq(SceneRouter.resolve_scene_path("empty_test_map.tscn"),
			"res://scenes/battle/maps/empty_test_map.tscn",
			"an existing .tscn isn't doubled")


func test_full_res_path_passthrough() -> void:
	assert_eq(SceneRouter.resolve_scene_path("res://scenes/ui/start_screen.tscn"),
			"res://scenes/ui/start_screen.tscn",
			"a full res:// path is used as-is")


func test_project_relative_path_gets_res_prefix() -> void:
	assert_eq(SceneRouter.resolve_scene_path("scenes/ui/start_screen.tscn"),
			"res://scenes/ui/start_screen.tscn",
			"a path containing / is treated as project-relative")


func test_empty_or_blank_token_returns_empty() -> void:
	assert_eq(SceneRouter.resolve_scene_path(""), "", "empty -> empty")
	assert_eq(SceneRouter.resolve_scene_path("   "), "", "blank -> empty")


## A mid-battle Load swaps a battle for a battle: the old scene's _exit_tree
## (BattleScene clears GridManager) must run before the new scene's _ready
## builds the grid, or the old battle wipes the new one's board.
func test_the_old_scene_leaves_the_tree_before_the_new_one_enters() -> void:
	var saved_world: Node2D = SceneRouter._world_root
	var saved_hud: SubViewport = SceneRouter._hud_viewport
	var saved_scene: Node = SceneRouter._current_scene
	var world := Node2D.new()
	add_child_autofree(world)
	var hud := SubViewport.new()
	add_child_autofree(hud)
	SceneRouter._world_root = world
	SceneRouter._hud_viewport = hud
	var old_scene := Node2D.new()
	world.add_child(old_scene)
	SceneRouter._current_scene = old_scene
	var world_children_at_exit: Array[int] = []
	old_scene.tree_exiting.connect(func() -> void:
		world_children_at_exit.append(world.get_child_count()))
	SceneRouter._swap_scene("res://scenes/battle/unit.tscn")  # any Node2D scene
	assert_eq(world_children_at_exit, [1], "the old scene was alone in the world when it left")
	assert_eq(world.get_child_count(), 1, "the new scene took its place")
	SceneRouter._world_root = saved_world
	SceneRouter._hud_viewport = saved_hud
	SceneRouter._current_scene = saved_scene

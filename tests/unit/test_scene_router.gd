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

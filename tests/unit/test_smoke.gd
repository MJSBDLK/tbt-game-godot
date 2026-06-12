## Smoke test — proves the GUT harness loads and runs.
## If this fails, the test runner setup is broken, not your code.
extends GutTest


# Compile-guard the autoload-dependent scripts that don't have their own unit
# test loading them. preload() forces a full compile at this script's load time
# (autoloads are already registered by then), so a parse error in any of these
# fails this test script to load — a clear signal in CI even though these are
# Control/Camera scripts that need a scene tree to actually run.
const _OptionsMenuPanel: GDScript = preload("res://scripts/ui/panels/options_menu_panel.gd")
const _HDPortraitSlot: GDScript = preload("res://scripts/ui/hd_portrait_slot.gd")
const _CameraController: GDScript = preload("res://scripts/managers/camera_controller.gd")
const _Settings: GDScript = preload("res://scripts/core/settings.gd")


func test_harness_is_alive() -> void:
	assert_true(true, "GutTest base class loaded and assert_true works")


func test_autoload_dependent_scripts_compile() -> void:
	for script: GDScript in [_OptionsMenuPanel, _HDPortraitSlot, _CameraController, _Settings]:
		assert_not_null(script, "script preloaded and compiled cleanly")


func test_basic_math() -> void:
	assert_eq(2 + 2, 4, "GDScript arithmetic still works")

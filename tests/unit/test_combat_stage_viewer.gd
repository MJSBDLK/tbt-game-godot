## The combat stage viewer (scenes/debug): opens straight onto the stage with
## Lawrence's whole painting showing, and takes the stage along when it goes
## (the stage lives in UIManager's overlay, not under the viewer).
extends GutTest


const VIEWER_SCENE: String = "res://scenes/debug/combat_stage_viewer.tscn"

var _motion_before: bool = true


func before_each() -> void:
	_motion_before = Settings.ui_motion_enabled
	Settings.ui_motion_enabled = false  # an instant wipe: nothing left awaiting when the viewer goes


func after_each() -> void:
	Settings.ui_motion_enabled = _motion_before
	GridManager.clear_grid()


func test_the_viewer_holds_up_the_stage_with_every_layer_showing() -> void:
	var viewer: Node = (load(VIEWER_SCENE) as PackedScene).instantiate()
	add_child(viewer)
	var scene: CombatScene = viewer.get("scene")
	assert_not_null(scene)
	assert_true(scene.is_inside_tree(), "mounted on the overlay")
	var backdrop: CombatBackdrop = scene.get_node("Stage/Backdrop")
	assert_gt(backdrop.floor_layers().size(), 0)
	for art: TextureRect in backdrop.floor_layers():
		assert_true(art.visible, "%s shows: every scenery is near" % art.name)
	viewer.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(scene), "the stage goes with the viewer")

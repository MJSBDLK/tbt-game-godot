## The board cursor's camera courtesy: ensure_point_visible pans the camera
## minimally when the cursor nears the view edge. The math lives in the pure
## static point_visibility_shift — pinned here; the instance method just adds
## viewport/zoom lookup and tween cancellation on top.
extends GutTest


func test_no_shift_while_the_point_is_comfortably_inside() -> void:
	assert_eq(
			CameraController.point_visibility_shift(
					Vector2.ZERO, Vector2(100, 60), Vector2(20, 10), 16.0),
			Vector2.ZERO,
			"mid-screen cursor never drags the camera")


func test_each_edge_shifts_minimally_back_inside_the_margin() -> void:
	var half := Vector2(100, 60)
	assert_eq(
			CameraController.point_visibility_shift(Vector2.ZERO, half, Vector2(90, 0), 16.0),
			Vector2(6, 0),
			"right edge: inner limit is 84, point at 90 needs exactly +6")
	assert_eq(
			CameraController.point_visibility_shift(Vector2.ZERO, half, Vector2(-95, 0), 16.0),
			Vector2(-11, 0),
			"left edge: inner limit is -84, point at -95 needs exactly -11")
	assert_eq(
			CameraController.point_visibility_shift(Vector2.ZERO, half, Vector2(0, 55), 16.0),
			Vector2(0, 11),
			"bottom edge: inner limit is 44")
	assert_eq(
			CameraController.point_visibility_shift(Vector2.ZERO, half, Vector2(0, -50), 16.0),
			Vector2(0, -6),
			"top edge: inner limit is -44")


func test_offcenter_view_uses_its_own_center() -> void:
	assert_eq(
			CameraController.point_visibility_shift(
					Vector2(200, 0), Vector2(100, 60), Vector2(90, 0), 16.0),
			Vector2(-26, 0),
			"point left of a right-shifted view: low edge is 200-100+16=116, 90 needs -26")


func test_margin_caps_at_half_the_half_extent() -> void:
	assert_eq(
			CameraController.point_visibility_shift(
					Vector2.ZERO, Vector2(20, 20), Vector2(15, 0), 16.0),
			Vector2(5, 0),
			"deep zoom-in: margin capped to 10 so opposite edges can't both claim the point")


# =============================================================================
# follow_target — the enemy phase's walking-unit follow
# =============================================================================

func _free_camera() -> CameraController:
	var camera := CameraController.new()
	camera.constrain_to_bounds = false
	add_child_autofree(camera)
	return camera


func test_follow_pans_toward_an_off_screen_node() -> void:
	var camera := _free_camera()
	var walker := Node2D.new()
	add_child_autofree(walker)
	walker.global_position = Vector2(100000, 100000)
	camera.follow_target = walker
	camera._process(0.016)
	assert_gt(camera.target_position.x, 0.0, "the camera heads for the walker")
	assert_gt(camera.target_position.y, 0.0, "the camera heads for the walker")


func test_follow_leaves_a_view_that_already_shows_the_node() -> void:
	var camera := _free_camera()
	var walker := Node2D.new()
	add_child_autofree(walker)
	walker.global_position = camera.target_position
	camera.follow_target = walker
	var before := camera.target_position
	camera._process(0.016)
	assert_eq(camera.target_position, before, "minimal pan: an on-screen walker drags nothing")


func test_a_freed_follow_target_is_ignored() -> void:
	var camera := _free_camera()
	var walker := Node2D.new()
	camera.follow_target = walker
	walker.free()
	var before := camera.target_position
	camera._process(0.016)
	assert_eq(camera.target_position, before, "a freed walker is dropped, not dereferenced")

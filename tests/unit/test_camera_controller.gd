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


# =============================================================================
# framing — the End Turn warning's look at the units still waiting
# =============================================================================
# A 1920×1080 view at zoom 3 shows 640×360 world px, x in [-320, 320] around
# the origin. Margin 48 = 1.5 tiles.

const VIEW := Vector2(1920, 1080)
const WHOLE_VIEW := Rect2(Vector2.ZERO, VIEW)

var _root_size_before := Vector2i.ZERO


func after_each() -> void:
	if _root_size_before != Vector2i.ZERO:
		get_tree().root.size = _root_size_before
		_root_size_before = Vector2i.ZERO


## Headless GUT runs a 64×64 window; the instance tests want a real one.
func _full_hd_camera() -> CameraController:
	_root_size_before = get_tree().root.size
	get_tree().root.size = Vector2i(VIEW)
	return _free_camera()


func _frame(points: Array[Vector2], free_region: Rect2 = WHOLE_VIEW,
		center: Vector2 = Vector2.ZERO, whole_steps: bool = true) -> Dictionary:
	return CameraController.framing(PackedVector2Array(points), 48.0, VIEW,
			free_region, center, 3.0, 1.0, whole_steps)


func test_a_group_already_on_screen_moves_nothing() -> void:
	var framed := _frame([Vector2(0, 0), Vector2(100, 50)])
	assert_eq(framed.position, Vector2.ZERO)
	assert_eq(framed.zoom, 3.0)


func test_a_unit_past_the_edge_pans_just_far_enough() -> void:
	var framed := _frame([Vector2(300, 0)])
	assert_eq(framed.position, Vector2(28, 0), "box edge 348 vs view edge 320")
	assert_eq(framed.zoom, 3.0, "a pan does it — no zoom")


func test_a_unit_under_the_menu_counts_as_hidden() -> void:
	# A 140 px HUD column at ×3 covers screen x 0–420: world x < -180 here.
	# The unit at -250 is on screen (world view edge -320) but under the panel.
	var beside_menu := Rect2(420, 0, 1500, 1080)
	var framed := _frame([Vector2(-250, 0)], beside_menu)
	assert_eq(framed.position, Vector2(-118, 0), "box edge -298 vs the column's edge -180")


func test_a_spread_too_wide_zooms_out_a_whole_step() -> void:
	var framed := _frame([Vector2(-400, 0), Vector2(400, 0)])
	assert_eq(framed.zoom, 2.0, "896 px of box fits 1920 px at 2.14 — whole steps floor it")
	assert_eq(framed.position, Vector2.ZERO, "at 2× the box already shows")


func test_smooth_zoom_takes_the_exact_fit() -> void:
	var framed := _frame([Vector2(-400, 0), Vector2(400, 0)], WHOLE_VIEW, Vector2.ZERO, false)
	assert_almost_eq(framed.zoom as float, 1920.0 / 896.0, 0.0001)


func test_framing_never_zooms_in() -> void:
	var framed := CameraController.framing(PackedVector2Array([Vector2.ZERO]), 48.0,
			VIEW, WHOLE_VIEW, Vector2.ZERO, 1.0, 1.0, true)
	assert_eq(framed.zoom, 1.0, "a lone unit at 1× stays at 1× — the player's zoom, not ours")


func test_past_the_lowest_zoom_the_group_centers() -> void:
	var framed := _frame([Vector2(-2000, 0), Vector2(2000, 0)], WHOLE_VIEW, Vector2(500, 0))
	assert_eq(framed.zoom, 1.0, "the floor")
	assert_eq(framed.position, Vector2(0, 0), "too wide even there: centered on the group")


func test_return_to_view_undoes_a_framing() -> void:
	var camera := _full_hd_camera()
	camera.set_zoom_level(4.0, false)
	var before := camera.current_view()
	var view := camera.get_viewport_rect().size
	camera.frame_points(PackedVector2Array([Vector2.ZERO, Vector2(view.x * 2.0, 0)]),
			Rect2(Vector2.ZERO, view))
	assert_lt(camera.current_view().zoom as float, 4.0, "a spread two views wide zooms out")
	assert_ne(camera.target_position, before.position, "and moves")
	camera.return_to_view(before)
	assert_eq(camera.target_position, before.position)
	assert_eq(camera.current_view().zoom, 4.0)


func test_framing_stops_at_the_map_edge() -> void:
	var camera := _full_hd_camera()
	camera.constrain_to_bounds = true
	camera.follow_margin_tiles = 4.0  # a margin wider than the 32 px edge buffer
	camera._map_pixel_origin = Vector2.ZERO
	camera._map_pixel_size = Vector2(4000, 4000)
	camera.set_zoom_level(2.0, false)
	camera._update_bounds_for_zoom()
	camera.center_on(Vector2(2000, 2000), false)
	camera.frame_points(PackedVector2Array([Vector2(0, 2000)]),
			Rect2(Vector2.ZERO, camera.get_viewport_rect().size))
	assert_eq(camera.target_position.x, camera._bounds_at_zoom(2.0).position.x,
			"a unit on the map's edge: the camera stops at the bound, not past it")

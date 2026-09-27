## UIManager's left column. Its two frames are fixed art (218 + 140 on a 360
## canvas): the unit preview hugs the top, the terrain preview is LOCKED to
## the bottom corner and grows upward, so it can't run off the screen the
## way the old stack did (RQD 2026-09-13, "pushed 1-2 px off the bottom").
extends GutTest


func before_each() -> void:
	UIManager._unit_info_panel.visible = true
	UIManager._terrain_info_panel.visible = true


func after_each() -> void:
	UIManager._terrain_info_panel.custom_minimum_size = Vector2(140, 140)
	UIManager._unit_info_panel.visible = false
	UIManager._terrain_info_panel.visible = false


func _bottom(control: Control) -> float:
	return control.position.y + control.size.y


func test_the_terrain_panel_is_locked_to_the_bottom_corner() -> void:
	await wait_process_frames(2)
	var column: Control = UIManager._left_panel
	var terrain: Control = UIManager._terrain_info_panel
	assert_eq(_bottom(terrain), column.size.y, "bottom edge on the column's bottom edge")
	assert_eq(terrain.position.x, 0.0)
	assert_eq(terrain.size, Vector2(140, 140))
	assert_eq(UIManager._unit_info_panel.position.y, 0.0, "the unit preview hugs the top")


func test_the_two_frames_never_touch_on_the_reference_canvas() -> void:
	var unit_height: float = UIManager._unit_info_panel.get_combined_minimum_size().y
	var terrain_height: float = UIManager._terrain_info_panel.get_combined_minimum_size().y
	assert_true(unit_height + terrain_height < 360.0,
			"pinned to opposite edges at 640×360 they still clear each other: %d + %d" % [
					int(unit_height), int(terrain_height)])


func test_extra_terrain_rows_grow_the_panel_upward() -> void:
	await wait_process_frames(2)
	var column: Control = UIManager._left_panel
	var terrain: Control = UIManager._terrain_info_panel
	var short_top: float = terrain.position.y
	terrain.custom_minimum_size = Vector2(140, 200)
	await wait_process_frames(2)
	assert_eq(_bottom(terrain), column.size.y, "the bottom edge stays on the screen edge")
	assert_eq(terrain.position.y, short_top - 60.0, "the header rises to make room")
	terrain.custom_minimum_size = Vector2(140, 140)
	await wait_process_frames(2)
	assert_eq(terrain.position.y, short_top, "and comes back down for a plain terrain")

## Native `tooltip_text` inside the HUD (RQD 2026-09-22: "I'm not seeing the
## tooltips"). Two engine facts this rests on, both pinned here so the fix
## can't quietly rot:
##   1. A viewport only starts a tooltip timer once it has been told the
##      mouse is inside it, and Godot never propagates that notification into
##      a nested SubViewport (a SubViewportContainer is expected to; the HUD
##      has none). InputRouter mirrors the root's enter/exit into HUDViewport.
##   2. The popup is a Window; unless the SubViewport embeds its own
##      subwindows it opens in the root at unscaled coordinates, i.e. in the
##      wrong place and tiny. game_root.tscn sets gui_embed_subwindows.
extends GutTest


func _tooltip_control(host: Viewport) -> Control:
	var control := Control.new()
	control.tooltip_text = "hello"
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(control)
	return control


func _hover(host: Viewport, at: Vector2) -> void:
	for i: int in 3:
		var motion := InputEventMouseMotion.new()
		motion.position = at + Vector2(i * 4, 0)
		motion.global_position = motion.position
		motion.relative = Vector2(4, 0)
		host.push_input(motion, true)
		await wait_process_frames(1)
	# Past the engine's tooltip delay (gui/timers/tooltip_delay_sec, 0.5).
	await wait_seconds(0.8)


func _popup_under(control: Control) -> Window:
	for child: Node in control.get_children():
		if child is Window:
			return child
	return null


func _sub_viewport() -> SubViewport:
	var sub := SubViewport.new()
	sub.size = Vector2i(200, 200)
	sub.gui_embed_subwindows = true
	add_child_autofree(sub)
	return sub


func test_a_viewport_never_entered_never_tooltips() -> void:
	var sub := _sub_viewport()
	var control := _tooltip_control(sub)
	await _hover(sub, Vector2(50, 50))
	assert_eq(sub.gui_get_hovered_control(), control, "hover itself works without the notification")
	assert_null(_popup_under(control), "but no tooltip timer ever starts")


func test_the_mouse_enter_notification_is_what_starts_tooltips() -> void:
	var sub := _sub_viewport()
	var control := _tooltip_control(sub)
	sub.propagate_notification(Node.NOTIFICATION_VP_MOUSE_ENTER)
	await _hover(sub, Vector2(50, 50))
	var popup: Window = _popup_under(control)
	assert_not_null(popup, "the tooltip popup opens under the hovered control")
	if popup != null:
		assert_true(popup.is_embedded())
		assert_eq(popup.get_parent().get_viewport(), sub, "and lives in the HUD's own viewport")


func test_input_router_mirrors_enter_and_exit_into_the_hud() -> void:
	# The router's siblings, as game_root.tscn lays them out.
	var game_root := Node.new()
	add_child_autofree(game_root)
	var hud := SubViewport.new()
	hud.name = "HUDViewport"
	hud.size = Vector2i(200, 200)
	hud.gui_embed_subwindows = true
	game_root.add_child(hud)
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	game_root.add_child(hud_layer)
	var hud_display := TextureRect.new()
	hud_display.name = "HUDDisplay"
	hud_layer.add_child(hud_display)
	var tap_feedback := TapFeedbackLayer.new()
	tap_feedback.name = "TapFeedbackLayer"
	game_root.add_child(tap_feedback)
	var router := InputRouter.new()
	router.name = "InputRouter"
	game_root.add_child(router)
	var control := _tooltip_control(hud)

	router.notification(Node.NOTIFICATION_VP_MOUSE_ENTER)
	await _hover(hud, Vector2(50, 50))
	assert_not_null(_popup_under(control), "the root's mouse-enter reaches the HUD, so tooltips start")

	# The exit is mirrored too: the HUD goes back to "never entered", so a
	# fresh hover starts nothing until the mouse comes back in.
	router.notification(Node.NOTIFICATION_VP_MOUSE_EXIT)
	control.queue_free()
	await wait_process_frames(2)
	var later := _tooltip_control(hud)
	await _hover(hud, Vector2(60, 60))
	assert_null(_popup_under(later), "after the mouse leaves the window no HUD tooltip starts")


func test_the_hud_viewport_embeds_its_popups() -> void:
	# Read from the scene file, not a booted game: the flag is authored there.
	var state: SceneState = (load("res://scenes/game_root.tscn") as PackedScene).get_state()
	var embeds: bool = false
	for node_index: int in state.get_node_count():
		if state.get_node_name(node_index) != &"HUDViewport":
			continue
		for property_index: int in state.get_node_property_count(node_index):
			if state.get_node_property_name(node_index, property_index) == &"gui_embed_subwindows":
				embeds = bool(state.get_node_property_value(node_index, property_index))
	assert_true(embeds, "without this the tooltip opens in the root window at HUD coordinates: wrong place, unscaled")

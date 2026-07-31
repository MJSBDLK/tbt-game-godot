## The split-viewport event route the menus' keyboard/controller UX rides on:
## InputRouter pushes root-viewport events into HUDViewport via push_input,
## and quiet-open adoption (InputSource, 2026-07-29) only works if a pushed
## key traverses the SubViewport's FULL local pipeline — _input, GUI focus
## handling, and _unhandled_input of nodes INSIDE the viewport. Godot changed
## these semantics before (push_unhandled_input deprecation); if an engine
## update regresses them, arrow keys silently die in every menu. Pinned here
## against a real SubViewport (diagnosed during the invisible-cursor bug hunt,
## RQD 2026-07-30).
extends GutTest


class Probe:
	extends Node
	var got_input: bool = false
	var got_unhandled: bool = false

	func _input(_event: InputEvent) -> void:
		got_input = true

	func _unhandled_input(_event: InputEvent) -> void:
		got_unhandled = true


func after_each() -> void:
	InputSource.last_kind = InputSource.Kind.POINTER  # the boot default
	GridManager.clear_move_range_preview()


func _key(keycode: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.physical_keycode = keycode
	key.pressed = true
	return key


func test_pushed_key_traverses_the_subviewport_pipeline() -> void:
	var sub := SubViewport.new()
	sub.size = Vector2i(320, 180)
	add_child_autofree(sub)
	var probe := Probe.new()
	sub.add_child(probe)
	await wait_process_frames(1)

	var event := _key(KEY_DOWN)
	sub.push_input(event, true)
	assert_true(probe.got_input, "_input inside the SubViewport sees a pushed key")
	assert_true(probe.got_unhandled,
			"_unhandled_input inside the SubViewport sees it too — adoption depends on this")
	assert_true(event.is_action_pressed("ui_down"), "a bare arrow key IS ui_down")


func test_pushed_arrow_key_summons_the_menu_cursor_in_a_subviewport() -> void:
	# The full in-game route: pointer-quiet menu inside a SubViewport, then a
	# pushed arrow key (what InputRouter forwards) adopts focus onto item one.
	InputSource.last_kind = InputSource.Kind.POINTER
	var sub := SubViewport.new()
	sub.size = Vector2i(640, 360)
	add_child_autofree(sub)
	var panel := ActionMenuPanel.new()
	sub.add_child(panel)
	var unit := Unit.new()
	autofree(unit)
	unit.character_data = CharacterData.new()
	panel.show_menu(unit)
	await wait_process_frames(2)
	var first := panel._content_container.get_child(0) as InteractiveButton
	assert_false(first.selected, "quiet open precondition: no cursor yet")

	sub.push_input(_key(KEY_DOWN), true)
	await wait_process_frames(2)
	assert_true(first.selected, "the pushed arrow key summons the cursor in-viewport")

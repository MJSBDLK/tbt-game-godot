## Headless probe: what joypads does THIS Godot see, and how does the hint bar
## name them? Run from the project root:
##   godot-4 --headless --path . -s tools/diag/joypad_probe.gd
## Snap note (2026-08-21): the godot-4 snap needs `sudo snap connect
## godot-4:joystick` or no pad is ever visible, paired or not.
extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	for i: int in 30:
		await process_frame
	var pads: Array[int] = Input.get_connected_joypads()
	print("[joy] connected=", pads)
	for id: int in pads:
		var joy_name: String = Input.get_joy_name(id)
		print("[joy]   ", id, " name='", joy_name, "' guid=", Input.get_joy_guid(id),
				" known=", Input.is_joy_known(id),
				" skin=", HintBarCommands.JoySkin.keys()[HintBarCommands.joy_skin_for_name(joy_name)])
	if pads.is_empty():
		quit()
		return
	# Event phase: 15 seconds of listening — MASH BUTTONS AND WIGGLE STICKS.
	# Polls the mapped (SDL-layout) surface, so a press seen here is exactly
	# what InputMap actions receive in-game.
	print("[joy] listening 15s — press buttons / move sticks NOW")
	var id0: int = pads[0]
	var seen: Dictionary = {}
	var frames: int = int(15.0 * 60)
	for i: int in frames:
		await process_frame
		for button: int in JOY_BUTTON_MAX:
			if Input.is_joy_button_pressed(id0, button) and not seen.has(button):
				seen[button] = true
				print("[joy] BUTTON ", button, " (",
						HintBarCommands.joy_button_label(button, HintBarCommands.JoySkin.XBOX), ")")
		for axis: int in JOY_AXIS_MAX:
			var value: float = Input.get_joy_axis(id0, axis)
			var axis_key: String = "axis%d" % axis
			if absf(value) > 0.5 and not seen.has(axis_key):
				seen[axis_key] = true
				print("[joy] AXIS ", axis, " -> ", "%.2f" % value)
	print("[joy] done — distinct inputs seen: ", seen.size(),
			" (0 means events are NOT reaching Godot)")
	quit()

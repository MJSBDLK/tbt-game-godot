## Measures how often frames actually reach the screen, next to what Godot and
## the phase banner believe the refresh rate is. Proves a custom xrandr mode
## really runs at its rate. Needs the real display, not --headless:
##   godot-4 --path . --resolution 320x180 -s tools/diag/refresh_probe.gd
## Add `-- uncapped` to lift the player's FPS cap for the run.
extends SceneTree

## Startup (autoloads, first draws) hitches; skip it.
const WARMUP_SECONDS: float = 1.5
const MEASURE_SECONDS: float = 4.0

var _launch_usec: int = 0
var _start_usec: int = 0
var _measured_frames: int = 0


func _process(_delta: float) -> bool:
	var now: int = Time.get_ticks_usec()
	if _launch_usec == 0:
		_launch_usec = now
		# Settings applies the saved cap during startup, so lift it after that.
		if OS.get_cmdline_user_args().has("uncapped"):
			Engine.max_fps = 0
		return false
	if _start_usec == 0:
		if now - _launch_usec >= WARMUP_SECONDS * 1000000.0:
			_start_usec = now
		return false
	_measured_frames += 1
	var elapsed: float = (now - _start_usec) / 1000000.0
	if elapsed < MEASURE_SECONDS:
		return false
	# Loaded at runtime: an -s script can't name a class_name at compile time.
	var overlay: Script = load("res://scripts/ui/overlays/phase_transition_overlay.gd")
	print("REFRESH_PROBE measured %.2f fps over %.0f s | screen reports %.2f Hz | banner fits %.2f Hz | max_fps %d" % [
			_measured_frames / elapsed, elapsed, DisplayServer.screen_get_refresh_rate(),
			overlay.effective_refresh_rate(), Engine.max_fps])
	return true

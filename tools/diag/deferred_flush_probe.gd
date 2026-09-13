## Probe: does a call_deferred issued FROM a deferred call run in the same
## flush (same frame) or the next frame? Run:
##   godot-4 --headless --path . -s tools/diag/deferred_flush_probe.gd
extends SceneTree

var count := 0
var frame := 0


func _init() -> void:
	process_frame.connect(func() -> void: frame += 1)
	call_deferred("_tick")


func _tick() -> void:
	count += 1
	print("tick %d at frame %d" % [count, frame])
	if count < 5:
		call_deferred("_tick")
	else:
		quit()

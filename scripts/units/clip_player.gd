## ClipPlayer — plays an attack-clip strip on any Sprite2D, frame by frame,
## honouring the exporter's per-frame durations and hit marker. Extracted
## from Unit (Phase 0 of .claude/todo-archive.md ("Battle animations plan")) so the same playback
## drives a unit on the map AND, later, a puppet in the combat scene.
##
## Strip contract (unchanged): N frames of equal width concatenated left to
## right; the sidecar `<strip>.json` may carry `frame_durations_ms` (one per
## frame) and `hit_frame`; the clip dict may carry `fps` / `hit_frame` as
## fallbacks (see resolve_playback).
##
## Two-phase playback mirrors the combat beat: begin() + play_to_hit() run
## frames 0..hit_frame while the logic waits for contact; play_after_hit()
## runs the tail and restores the idle frame, fire-and-forget while damage
## popups/shake play. A generation counter lets a newer clip cancel an older
## tail on the same sprite — which is why there is ONE ClipPlayer per sprite,
## owned by the sprite's unit, never one per presenter.
##
## Sprite ownership: begin() takes over texture/region/flip; the tail hands
## them back through `restore_idle` (Unit._load_character_sprite), which also
## re-derives the pivot offset. Assumes the clip's pivot.x is at frame center
## — an off-center pivot would visibly jump on flip.
class_name ClipPlayer
extends RefCounted


const DEFAULT_FPS: int = 12  # Fallback when a clip omits "fps" and has no sidecar

var sprite: Sprite2D = null
## Called at the end of a clip tail to put the idle texture + offset back.
var restore_idle: Callable = Callable()

var _generation: int = 0
var _clip: Dictionary = {}
var _durations_s: Array[float] = []
var _hit_frame: int = 0
var _frames: int = 1
var _frame_size: Vector2 = Vector2.ZERO


func _init(target_sprite: Sprite2D, idle_restorer: Callable = Callable()) -> void:
	sprite = target_sprite
	restore_idle = idle_restorer


## Load the strip, show frame 0 mirrored per `flip_h`, arm the generation.
## Returns false (touching nothing) when there is no sprite or the strip
## can't be loaded.
func begin(clip: Dictionary, flip_h: bool) -> bool:
	if sprite == null or clip.is_empty():
		return false
	var strip_path: String = clip.get("path", "")
	# Existence check first: load() on a missing path logs an engine error,
	# and a character JSON pointing at an unexported strip should degrade to
	# the boop nudge quietly (the coverage probe is where that gets reported).
	if strip_path.is_empty() or not ResourceLoader.exists(strip_path):
		return false
	var strip_texture: Texture2D = load(strip_path) as Texture2D
	if strip_texture == null:
		return false
	_generation += 1
	_clip = clip
	_frames = maxi(1, int(clip.get("frames", 1)))
	var playback: Dictionary = resolve_playback(strip_path, clip, _frames)
	_hit_frame = playback["hit_frame"]
	_durations_s = playback["durations_s"]
	_frame_size = Vector2(float(strip_texture.get_width()) / float(_frames),
			float(strip_texture.get_height()))
	sprite.flip_h = flip_h
	sprite.texture = strip_texture
	sprite.region_enabled = true
	_show_frame(0)
	return true


func is_playing() -> bool:
	return not _clip.is_empty()


func hit_frame() -> int:
	return _hit_frame


## Frames 0..hit_frame, awaiting each frame's duration. `instant` jumps
## straight to the hit frame (skip). Returns early if a newer clip began.
func play_to_hit(instant: bool = false) -> void:
	if not is_playing():
		return
	var generation: int = _generation
	if instant:
		_show_frame(_hit_frame)
		return
	for frame_index: int in range(0, _hit_frame):
		await _wait(_durations_s[frame_index])
		if _generation != generation or sprite == null:
			return
		_show_frame(frame_index + 1)


## Frames hit_frame+1..last, a hold on the last frame, then idle restore.
## `instant` restores idle immediately. Bails silently if a newer clip began
## — that clip's own tail restores idle.
func play_after_hit(instant: bool = false) -> void:
	if not is_playing():
		return
	var generation: int = _generation
	if not instant:
		for frame_index: int in range(_hit_frame + 1, _frames):
			await _wait(_durations_s[frame_index])
			if _generation != generation or sprite == null:
				return
			_show_frame(frame_index)
		# Brief hold on the final frame before resetting to idle.
		await _wait(_durations_s[_frames - 1])
		if _generation != generation or sprite == null:
			return
	_finish_idle()


func _finish_idle() -> void:
	_clip = {}
	if sprite == null:
		return
	sprite.region_enabled = false
	sprite.flip_h = false
	if restore_idle.is_valid():
		restore_idle.call()


func _show_frame(frame_index: int) -> void:
	sprite.region_rect = Rect2(frame_index * _frame_size.x, 0.0, _frame_size.x, _frame_size.y)


func _wait(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	await tree.create_timer(seconds).timeout


## Resolves both per-frame durations (seconds) and hit_frame for a clip.
## Both are sourced from the sidecar JSON when present (the exporter writes
## them from Lawrence's authored timings and `hit` marker tags). Falls back
## to the clip JSON's `fps` / `hit_frame` when absent — so clips authored
## before the exporter update still play.
## Returns: { "durations_s": Array[float], "hit_frame": int }.
static func resolve_playback(strip_path: String, clip: Dictionary, frames: int) -> Dictionary:
	var durations_s: Array[float] = []
	var hit_frame_index: int = int(clip.get("hit_frame", frames / 2))
	var sidecar_path: String = strip_path.trim_suffix(".png") + ".json"
	if FileAccess.file_exists(sidecar_path):
		var content := FileAccess.get_file_as_string(sidecar_path)
		if not content.is_empty():
			var parsed: Variant = JSON.parse_string(content)
			if parsed is Dictionary:
				if parsed.has("frame_durations_ms"):
					var ms_array: Array = parsed["frame_durations_ms"]
					if ms_array.size() == frames:
						for ms: Variant in ms_array:
							durations_s.append(float(ms) / 1000.0)
				if parsed.has("hit_frame"):
					hit_frame_index = int(parsed["hit_frame"])
	if durations_s.is_empty():
		var fps: int = maxi(1, int(clip.get("fps", DEFAULT_FPS)))
		var dt: float = 1.0 / float(fps)
		for _i in range(frames):
			durations_s.append(dt)
	hit_frame_index = clampi(hit_frame_index, 0, frames - 1)
	return { "durations_s": durations_s, "hit_frame": hit_frame_index }

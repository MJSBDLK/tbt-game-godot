@tool
extends EditorContextMenuPlugin

const ASEPRITE_COMMAND_KEY := "aseprite/general/command_path"
const ASE_MAGIC := 0xA5E0
const FRAME_MAGIC := 0xF1FA
const TAGS_CHUNK_TYPE := 0x2018
const SLICES_CHUNK_TYPE := 0x2022


func _popup_menu(paths: PackedStringArray) -> void:
	# Only show for .aseprite/.ase files
	for path in paths:
		if path.ends_with(".aseprite") or path.ends_with(".ase"):
			add_context_menu_item("Export Tags as PNGs", _export_tags)
			return


func _export_tags(_paths: Array) -> void:
	var lowercase_names := true

	for path in _paths:
		if not path.ends_with(".aseprite") and not path.ends_with(".ase"):
			continue
		_export_file(path, lowercase_names)

	EditorInterface.get_resource_filesystem().scan()


func _export_file(aseprite_file_path: String, lowercase_names: bool) -> void:
	var global_source := ProjectSettings.globalize_path(aseprite_file_path)
	if not FileAccess.file_exists(global_source):
		printerr("AsepriteTagExporter: Source file not found: %s" % aseprite_file_path)
		return

	# Output to sibling directory named after the file
	var base_name := aseprite_file_path.get_file().get_basename()
	var output_directory := aseprite_file_path.get_base_dir() + "/" + base_name + "/"

	if not DirAccess.dir_exists_absolute(output_directory):
		DirAccess.make_dir_recursive_absolute(output_directory)

	var aseprite_command := _get_aseprite_command()

	# Parse tags from .aseprite binary
	var tags := _parse_tags(global_source)
	if tags.is_empty():
		printerr("AsepriteTagExporter: No tags found in %s" % aseprite_file_path)
		return

	print("AsepriteTagExporter: Found %d tags in %s" % [tags.size(), aseprite_file_path])

	# Resolve pivot. Prefer an explicit slice (with pivot flag) for off-center
	# anchors. If none, fall back to canvas center — Lawrence's convention is
	# pivot=canvas center on every animation, so the slice is only needed for
	# the rare off-center case. Either way, has_pivot becomes true and the
	# exporter keeps PNGs canvas-sized so the pivot's coords stay valid.
	var pivot: Variant = _parse_pivot(global_source)
	if pivot == null:
		var canvas_size := _parse_canvas_size(global_source)
		if canvas_size != Vector2i.ZERO:
			pivot = { "x": canvas_size.x / 2, "y": canvas_size.y / 2 }
			print("  Pivot: (%d, %d) — auto-inferred from canvas center" % [pivot.x, pivot.y])
	else:
		print("  Pivot: (%d, %d) — from slice" % [pivot.x, pivot.y])
	var has_pivot := pivot != null

	# Capture per-frame durations from the .aseprite header so unit.gd can
	# honor Lawrence's pacing (e.g. slow windup → fast impact → long hold)
	# without per-frame timings being lost to a uniform-fps assumption.
	var frame_durations_ms := _parse_frame_durations(global_source)

	# Partition tags: any tag whose name matches the marker convention
	# (`hit`, `hit_<clip>`, `<clip>_hit`) is metadata — it pins the impact
	# frame inside a clip but doesn't get exported as a PNG itself. Build
	# a map of clip_name -> hit_frame (relative to clip start) so the
	# sidecar write below can include it.
	var clip_tags: Array[Dictionary] = []
	var marker_tags: Array[Dictionary] = []
	for tag in tags:
		if _is_marker_tag(tag.name):
			marker_tags.append(tag)
		else:
			clip_tags.append(tag)
	var hit_frame_for_clip: Dictionary = {}
	for marker in marker_tags:
		var matched_clip: Variant = _find_clip_for_marker(marker, clip_tags)
		if matched_clip != null:
			hit_frame_for_clip[matched_clip.name] = int(marker.from_frame) - int(matched_clip.from_frame)
			print("  Marker '%s' -> clip '%s' hit_frame=%d" % [marker.name, matched_clip.name, hit_frame_for_clip[matched_clip.name]])
		else:
			print("  Marker '%s' did not match any clip — ignored" % marker.name)

	# Pass A: trimmed numbered frames — only when no pivot. Trimming would
	# invalidate canvas-space pivot coords, so we skip it whenever a pivot exists.
	var temp_trimmed := OS.get_cache_dir() + "/aseprite_tag_export/"
	if not has_pivot:
		DirAccess.make_dir_recursive_absolute(temp_trimmed)

		var trimmed_arguments := PackedStringArray([
			"-b",
			global_source,
			"--trim",
			"--save-as",
			temp_trimmed + "{frame0000}.png",
		])
		var trimmed_output := []
		var trimmed_exit := OS.execute(aseprite_command, trimmed_arguments, trimmed_output, true, true)
		if trimmed_exit != 0:
			printerr("AsepriteTagExporter: Aseprite trimmed export failed (exit %d)" % trimmed_exit)
			if not trimmed_output.is_empty():
				printerr("  %s" % trimmed_output[0])
			_cleanup_temp(temp_trimmed)
			return

	# Pass B: untrimmed canvas-size frames — needed if pivot exists, or any tag
	# is multi-frame (we filter per-tag in GDScript because aseprite's
	# `--tag <name>` filter on `--sheet` is broken in some builds).
	var temp_aligned := OS.get_cache_dir() + "/aseprite_tag_export_aligned/"
	var has_multi_frame_tag := false
	for tag in tags:
		if tag.to_frame > tag.from_frame:
			has_multi_frame_tag = true
			break

	var needs_aligned_pass := has_pivot or has_multi_frame_tag
	if needs_aligned_pass:
		DirAccess.make_dir_recursive_absolute(temp_aligned)
		var aligned_arguments := PackedStringArray([
			"-b",
			global_source,
			"--save-as",
			temp_aligned + "{frame0000}.png",
		])
		var aligned_output := []
		var aligned_exit := OS.execute(aseprite_command, aligned_arguments, aligned_output, true, true)
		if aligned_exit != 0:
			printerr("AsepriteTagExporter: Aseprite untrimmed export failed (exit %d)" % aligned_exit)
			if not aligned_output.is_empty():
				printerr("  %s" % aligned_output[0])
			if not has_pivot:
				_cleanup_temp(temp_trimmed)
			_cleanup_temp(temp_aligned)
			return

	var global_output := ProjectSettings.globalize_path(output_directory)
	var exported_count := 0
	for tag in clip_tags:
		var output_name := _sanitize_filename(tag.name, lowercase_names)
		var output_path := global_output + output_name + ".png"
		var frames_in_tag: int = tag.to_frame - tag.from_frame + 1

		# Source temp dir for single-frame tags: aligned (untrimmed) when pivot
		# exists, trimmed otherwise. Multi-frame tags always pull from aligned.
		var single_frame_source_dir := temp_aligned if has_pivot else temp_trimmed

		if frames_in_tag == 1:
			var numbered_filename := "%04d.png" % tag.from_frame
			var numbered_path := single_frame_source_dir + numbered_filename
			if not FileAccess.file_exists(numbered_path):
				printerr("  Warning: Missing frame file for tag '%s': %s" % [tag.name, numbered_filename])
				continue

			var source_file := FileAccess.open(numbered_path, FileAccess.READ)
			var data := source_file.get_buffer(source_file.get_length())
			source_file.close()

			var destination_file := FileAccess.open(output_path, FileAccess.WRITE)
			destination_file.store_buffer(data)
			destination_file.close()
		else:
			var first_frame_path := temp_aligned + "%04d.png" % tag.from_frame
			var first_image := Image.load_from_file(first_frame_path)
			if first_image == null:
				printerr("  Warning: Cannot load first frame for tag '%s': %s" % [tag.name, first_frame_path])
				continue
			var canvas_w := first_image.get_width()
			var canvas_h := first_image.get_height()
			var strip := Image.create(canvas_w * frames_in_tag, canvas_h, false, Image.FORMAT_RGBA8)
			strip.blit_rect(first_image, Rect2i(0, 0, canvas_w, canvas_h), Vector2i(0, 0))
			var stitched_count := 1
			for i in range(1, frames_in_tag):
				var frame_path := temp_aligned + "%04d.png" % (tag.from_frame + i)
				var frame_image := Image.load_from_file(frame_path)
				if frame_image == null:
					printerr("  Warning: Missing frame %d for tag '%s'" % [tag.from_frame + i, tag.name])
					continue
				strip.blit_rect(frame_image, Rect2i(0, 0, canvas_w, canvas_h), Vector2i(i * canvas_w, 0))
				stitched_count += 1
			var save_error := strip.save_png(output_path)
			if save_error != OK:
				printerr("  Failed to write strip for tag '%s' (error %d)" % [tag.name, save_error])
				continue
			print("  Strip: %s (%d frames, %dx%d)" % [output_name, stitched_count, canvas_w * frames_in_tag, canvas_h])

		# Emit sidecar JSON next to the PNG. Contains per-frame durations
		# (always) and pivot (when a pivot slice exists). MERGES into any
		# existing sidecar so hand-authored / bootstrap-script fields
		# (e.g. art_bounds for healthbar positioning) survive re-export.
		# Durations are sliced to the tag's frame range so each clip's
		# sidecar holds only its own timings.
		var sidecar_path := global_output + output_name + ".json"
		var sidecar_data: Dictionary = {}
		if FileAccess.file_exists(sidecar_path):
			var existing := FileAccess.get_file_as_string(sidecar_path)
			if not existing.is_empty():
				var parsed: Variant = JSON.parse_string(existing)
				if parsed is Dictionary:
					sidecar_data = parsed
		if has_pivot:
			sidecar_data["pivot"] = { "x": pivot.x, "y": pivot.y }
		if not frame_durations_ms.is_empty():
			var clip_durations: Array[int] = []
			for fi in range(tag.from_frame, tag.to_frame + 1):
				if fi < frame_durations_ms.size():
					clip_durations.append(frame_durations_ms[fi])
			sidecar_data["frame_durations_ms"] = clip_durations
		if hit_frame_for_clip.has(tag.name):
			sidecar_data["hit_frame"] = hit_frame_for_clip[tag.name]
		var sidecar_file := FileAccess.open(sidecar_path, FileAccess.WRITE)
		if sidecar_file == null:
			printerr("  Failed to open sidecar for write: %s (FileAccess error %d)" % [sidecar_path, FileAccess.get_open_error()])
		else:
			sidecar_file.store_string(JSON.stringify(sidecar_data))
			sidecar_file.close()
			var pivot_note := "pivot %d,%d" % [pivot.x, pivot.y] if has_pivot else "no pivot"
			var hit_note := ", hit_frame=%d" % hit_frame_for_clip[tag.name] if hit_frame_for_clip.has(tag.name) else ""
			print("  Sidecar: %s.json (%s, %d frame durations%s)" % [output_name, pivot_note, frames_in_tag, hit_note])

		exported_count += 1

	if not has_pivot:
		_cleanup_temp(temp_trimmed)
	if needs_aligned_pass:
		_cleanup_temp(temp_aligned)
	print("AsepriteTagExporter: Exported %d tag(s) to %s" % [exported_count, output_directory])


func _get_aseprite_command() -> String:
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings.has_setting(ASEPRITE_COMMAND_KEY):
		var command: String = editor_settings.get(ASEPRITE_COMMAND_KEY)
		if command != "":
			return command
	return "aseprite"


func _parse_tags(global_path: String) -> Array[Dictionary]:
	var tags: Array[Dictionary] = []
	var file := FileAccess.open(global_path, FileAccess.READ)
	if file == null:
		printerr("AsepriteTagExporter: Cannot open file: %s" % global_path)
		return tags

	# File header (128 bytes)
	var _file_size := file.get_32()
	var magic := file.get_16()
	if magic != ASE_MAGIC:
		printerr("AsepriteTagExporter: Not a valid .aseprite file (bad magic: 0x%04X)" % magic)
		return tags

	var frame_count := file.get_16()
	file.seek(128)

	# Walk frames looking for the tags chunk
	for frame_index in range(frame_count):
		var frame_start := file.get_position()
		var frame_size := file.get_32()
		var frame_magic := file.get_16()
		if frame_magic != FRAME_MAGIC:
			printerr("AsepriteTagExporter: Bad frame magic at offset %d" % frame_start)
			return tags

		var old_chunk_count := file.get_16()
		file.get_16()  # duration
		file.get_buffer(2)  # reserved
		var new_chunk_count := file.get_32()
		var chunk_count: int = new_chunk_count if new_chunk_count != 0 else old_chunk_count

		for chunk_index in range(chunk_count):
			var chunk_start := file.get_position()
			var chunk_size := file.get_32()
			var chunk_type := file.get_16()

			if chunk_type == TAGS_CHUNK_TYPE:
				var tag_count := file.get_16()
				file.get_buffer(8)  # reserved

				for tag_index in range(tag_count):
					var from_frame := file.get_16()
					var to_frame := file.get_16()
					file.get_8()  # direction
					file.get_16()  # repeat
					file.get_buffer(6)  # reserved
					file.get_buffer(3)  # RGB color
					file.get_8()  # extra byte
					var name_length := file.get_16()
					var tag_name := file.get_buffer(name_length).get_string_from_utf8()

					tags.append({
						"name": tag_name,
						"from_frame": from_frame,
						"to_frame": to_frame,
					})

				return tags

			file.seek(chunk_start + chunk_size)

		file.seek(frame_start + frame_size)

	return tags


## Returns null if no slice has a pivot, otherwise the canvas-space pivot
## coordinates of the first such slice as { "x": int, "y": int }. The pivot
## uses pixel-corner coordinates with (0, 0) at the canvas top-left, matching
## Aseprite's internal representation.
func _parse_pivot(global_path: String) -> Variant:
	var file := FileAccess.open(global_path, FileAccess.READ)
	if file == null:
		return null

	var _file_size := file.get_32()
	var magic := file.get_16()
	if magic != ASE_MAGIC:
		return null

	var frame_count := file.get_16()
	file.seek(128)

	for frame_index in range(frame_count):
		var frame_start := file.get_position()
		var frame_size := file.get_32()
		var frame_magic := file.get_16()
		if frame_magic != FRAME_MAGIC:
			return null

		var old_chunk_count := file.get_16()
		file.get_16()  # duration
		file.get_buffer(2)  # reserved
		var new_chunk_count := file.get_32()
		var chunk_count: int = new_chunk_count if new_chunk_count != 0 else old_chunk_count

		for chunk_index in range(chunk_count):
			var chunk_start := file.get_position()
			var chunk_size := file.get_32()
			var chunk_type := file.get_16()

			if chunk_type == SLICES_CHUNK_TYPE:
				var key_count := file.get_32()
				var flags := file.get_32()
				file.get_32()  # reserved
				var name_length := file.get_16()
				file.get_buffer(name_length)  # name (skip)

				var has_9patch := (flags & 0x1) != 0
				var has_pivot := (flags & 0x2) != 0

				if has_pivot and key_count > 0:
					file.get_32()  # frame number
					var slice_x := file.get_32()
					var slice_y := file.get_32()
					file.get_32()  # slice width
					file.get_32()  # slice height
					if has_9patch:
						file.get_32()  # center x
						file.get_32()  # center y
						file.get_32()  # center width
						file.get_32()  # center height
					var pivot_x := file.get_32()
					var pivot_y := file.get_32()
					return { "x": slice_x + pivot_x, "y": slice_y + pivot_y }

			file.seek(chunk_start + chunk_size)

		file.seek(frame_start + frame_size)

	return null


## Reads canvas width/height from the .aseprite header. Returns ZERO on
## parse failure. Header layout: 4B file_size, 2B magic, 2B frame_count,
## 2B width, 2B height (offsets 8 and 10).
func _parse_canvas_size(global_path: String) -> Vector2i:
	var file := FileAccess.open(global_path, FileAccess.READ)
	if file == null:
		return Vector2i.ZERO
	var _file_size := file.get_32()
	var magic := file.get_16()
	if magic != ASE_MAGIC:
		return Vector2i.ZERO
	var _frame_count := file.get_16()
	var width := file.get_16()
	var height := file.get_16()
	return Vector2i(width, height)


## True if a tag name represents a frame marker (e.g. impact frame) rather
## than a clip. Convention: name is exactly "hit", or starts with "hit_",
## or ends with "_hit" (case-insensitive). Markers don't get exported as
## PNGs; they contribute hit_frame metadata to the matching clip's sidecar.
func _is_marker_tag(tag_name: String) -> bool:
	var lower := str(tag_name).strip_edges().to_lower()
	return lower == "hit" or lower.begins_with("hit_") or lower.ends_with("_hit")


## Find the clip a marker tag should attach to. Matching rules:
##   1. Explicit name: "<clip>_hit" or "hit_<clip>" matches a clip named "<clip>".
##   2. Frame containment: marker's frames fully inside a clip's range.
## Returns the matched clip dict or null. Name match wins over containment.
func _find_clip_for_marker(marker: Dictionary, clips: Array[Dictionary]) -> Variant:
	var lower_name: String = str(marker.name).strip_edges().to_lower()
	var name_hint := ""
	if lower_name.begins_with("hit_"):
		name_hint = lower_name.substr(4)
	elif lower_name.ends_with("_hit"):
		name_hint = lower_name.substr(0, lower_name.length() - 4)
	if not name_hint.is_empty():
		for clip in clips:
			if str(clip.name).strip_edges().to_lower() == name_hint:
				return clip
	for clip in clips:
		if int(marker.from_frame) >= int(clip.from_frame) and int(marker.to_frame) <= int(clip.to_frame):
			return clip
	return null


## Walks every frame header and collects each frame's duration_ms. Returns an
## array of length == frame_count where the i-th entry is frame i's duration.
## Empty on parse failure (caller falls back to clip's JSON-declared fps).
func _parse_frame_durations(global_path: String) -> Array[int]:
	var durations: Array[int] = []
	var file := FileAccess.open(global_path, FileAccess.READ)
	if file == null:
		return durations

	var _file_size := file.get_32()
	var magic := file.get_16()
	if magic != ASE_MAGIC:
		return durations

	var frame_count := file.get_16()
	file.seek(128)

	for frame_index in range(frame_count):
		var frame_start := file.get_position()
		var frame_size := file.get_32()
		var frame_magic := file.get_16()
		if frame_magic != FRAME_MAGIC:
			# Bail and return what we've got — partial is better than empty if
			# only a late frame is corrupt.
			return durations
		file.get_16()  # old_chunk_count
		var duration := file.get_16()
		durations.append(duration)
		file.seek(frame_start + frame_size)

	return durations


func _sanitize_filename(tag_name: String, lowercase: bool) -> String:
	var result := tag_name.strip_edges()
	if lowercase:
		result = result.to_lower()
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9_-]")
	result = regex.sub(result, "_", true)
	return result


func _cleanup_temp(temp_directory: String) -> void:
	var directory := DirAccess.open(temp_directory)
	if directory == null:
		return
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if not directory.current_is_dir():
			directory.remove(file_name)
		file_name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(temp_directory)

@tool
extends EditorContextMenuPlugin

const ASEPRITE_COMMAND_KEY := "aseprite/general/command_path"
const ASE_MAGIC := 0xA5E0
const FRAME_MAGIC := 0xF1FA
const LAYERS_CHUNK_TYPE := 0x2004
const TAGS_CHUNK_TYPE := 0x2018
const SLICES_CHUNK_TYPE := 0x2022

# Tile cells are 32x32 pixels. Used to derive a tag's footprint from its
# content bbox when no explicit `footprint` slice is present.
const TILE_SIZE_PX := 32

# Shadow-layer detection tolerances. A layer is treated as a shadow when
# every non-transparent pixel matches pure-black at ~40% alpha. Lawrence's
# current convention emits exactly RGB(0,0,0) / A=102, but allow small
# wiggle for any future anti-aliasing.
const SHADOW_RGB_MAX := 13         # 5% of 255
const SHADOW_ALPHA_TARGET := 102   # 40% of 255
const SHADOW_ALPHA_TOLERANCE := 13 # ±5% of 255
const SHADOW_ALPHA_MIN_OPAQUE := 5 # treat alpha <=5 as fully transparent


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

	# Detect shadow handling: parse layer names, then pick the shadow layer
	# (if any) by suffix convention or content-signature scan. Files with a
	# shadow layer skip the trim/aligned dance below and run dedicated
	# Passes C/D instead, so main and shadow strips align frame-for-frame.
	var layer_names := _parse_layers(global_source)
	var shadow_layer_name := ""
	if not layer_names.is_empty():
		shadow_layer_name = _detect_shadow_layer(layer_names, global_source, aseprite_command)
	var has_shadow_layer := shadow_layer_name != ""
	if has_shadow_layer:
		print("  Shadow layer: '%s'" % shadow_layer_name)

	# Optional explicit footprint slice (in tile cells). Falls through to
	# per-tag bbox-derived footprint when absent.
	var footprint_from_slice := _parse_footprint_slice(global_source)

	var temp_trimmed := OS.get_cache_dir() + "/aseprite_tag_export/"
	var temp_aligned := OS.get_cache_dir() + "/aseprite_tag_export_aligned/"
	var temp_main_no_shadow := OS.get_cache_dir() + "/aseprite_tag_export_main/"
	var temp_shadow_only := OS.get_cache_dir() + "/aseprite_tag_export_shadow/"
	var has_multi_frame_tag := false
	for tag in tags:
		if tag.to_frame > tag.from_frame:
			has_multi_frame_tag = true
			break
	var needs_aligned_pass := has_pivot or has_multi_frame_tag

	if has_shadow_layer:
		# Pass C: main composite with shadow layer hidden — canvas-aligned per
		# frame so per-tag bbox cropping (below) keeps main + shadow in sync.
		DirAccess.make_dir_recursive_absolute(temp_main_no_shadow)
		var main_args := PackedStringArray([
			"-b", global_source,
			"--ignore-layer", shadow_layer_name,
			"--save-as", temp_main_no_shadow + "{frame0000}.png",
		])
		var main_output := []
		var main_exit := OS.execute(aseprite_command, main_args, main_output, true, true)
		if main_exit != 0:
			printerr("AsepriteTagExporter: main-without-shadow export failed (exit %d)" % main_exit)
			if not main_output.is_empty():
				printerr("  %s" % main_output[0])
			_cleanup_temp(temp_main_no_shadow)
			return

		# Pass D: shadow layer only — canvas-aligned, same frame indices as Pass C.
		DirAccess.make_dir_recursive_absolute(temp_shadow_only)
		var shadow_args := PackedStringArray([
			"-b", global_source,
			"--layer", shadow_layer_name,
			"--save-as", temp_shadow_only + "{frame0000}.png",
		])
		var shadow_output := []
		var shadow_exit := OS.execute(aseprite_command, shadow_args, shadow_output, true, true)
		if shadow_exit != 0:
			printerr("AsepriteTagExporter: shadow-only export failed (exit %d)" % shadow_exit)
			if not shadow_output.is_empty():
				printerr("  %s" % shadow_output[0])
			_cleanup_temp(temp_main_no_shadow)
			_cleanup_temp(temp_shadow_only)
			return
	else:
		# Existing two-pass flow for files without a shadow layer.
		# Pass A: trimmed numbered frames — only when no pivot. Trimming would
		# invalidate canvas-space pivot coords, so we skip it whenever a pivot exists.
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
		var shadow_output_path := global_output + output_name + "_shadow.png"
		var frames_in_tag: int = tag.to_frame - tag.from_frame + 1

		# Per-tag footprint defaults to the explicit slice if one was authored,
		# otherwise gets recomputed from the cropped bbox in the shadow-aware
		# branch. The no-shadow branch leaves it as the slice value (or zero).
		var footprint_for_tag := footprint_from_slice
		var shadow_emitted := false

		if has_shadow_layer:
			# Shadow-aware path: load all frames of main + shadow, compute a
			# shared bbox (union across both layers and all frames), pad to
			# 32-px cells, crop both to that rect, stitch if multi-frame.
			var main_frames: Array[Image] = []
			var shadow_frames: Array[Image] = []
			for fi in range(frames_in_tag):
				var src_idx: int = int(tag.from_frame) + fi
				var main_img := Image.load_from_file(temp_main_no_shadow + "%04d.png" % src_idx)
				var shadow_img := Image.load_from_file(temp_shadow_only + "%04d.png" % src_idx)
				if main_img == null:
					printerr("  Warning: Missing main frame %d for tag '%s'" % [src_idx, tag.name])
					continue
				main_frames.append(main_img)
				if shadow_img != null:
					shadow_frames.append(shadow_img)
			if main_frames.is_empty():
				continue
			var canvas_w := main_frames[0].get_width()
			var canvas_h := main_frames[0].get_height()
			var canvas_size := Vector2i(canvas_w, canvas_h)

			# Union bbox across all frames of both layers.
			var union_bbox := Rect2i()
			for img in main_frames:
				union_bbox = _bbox_union(union_bbox, _content_bbox(img))
			var shadow_total_bbox := Rect2i()
			for img in shadow_frames:
				shadow_total_bbox = _bbox_union(shadow_total_bbox, _content_bbox(img))
			union_bbox = _bbox_union(union_bbox, shadow_total_bbox)
			if union_bbox.size.x <= 0 or union_bbox.size.y <= 0:
				printerr("  Warning: Tag '%s' is empty across all frames — skipping" % tag.name)
				continue

			var crop_rect := _pad_bbox_to_cells(union_bbox, canvas_size)
			var cell_w: int = crop_rect.size.x / TILE_SIZE_PX
			var cell_h: int = crop_rect.size.y / TILE_SIZE_PX
			if footprint_for_tag == Vector2i.ZERO:
				footprint_for_tag = Vector2i(cell_w, cell_h)

			# Stitch main strip from cropped frames.
			var main_strip := Image.create(crop_rect.size.x * frames_in_tag, crop_rect.size.y, false, Image.FORMAT_RGBA8)
			for fi in range(frames_in_tag):
				main_strip.blit_rect(main_frames[fi], crop_rect, Vector2i(fi * crop_rect.size.x, 0))
			var main_save_err := main_strip.save_png(output_path)
			if main_save_err != OK:
				printerr("  Failed to write main PNG for tag '%s' (error %d)" % [tag.name, main_save_err])
				continue

			# Stitch shadow strip the same way; skip emission if every cropped
			# frame is transparent (shadow layer present but no content in this
			# tag's frame range).
			if shadow_frames.size() == frames_in_tag:
				var shadow_strip := Image.create(crop_rect.size.x * frames_in_tag, crop_rect.size.y, false, Image.FORMAT_RGBA8)
				var any_shadow := false
				for fi in range(frames_in_tag):
					shadow_strip.blit_rect(shadow_frames[fi], crop_rect, Vector2i(fi * crop_rect.size.x, 0))
					if _content_bbox(shadow_frames[fi]).size.x > 0:
						any_shadow = true
				if any_shadow:
					var shadow_save_err := shadow_strip.save_png(shadow_output_path)
					if shadow_save_err == OK:
						shadow_emitted = true
					else:
						printerr("  Failed to write shadow PNG for tag '%s' (error %d)" % [tag.name, shadow_save_err])

			print("  Strip: %s (%d frames, %dx%d → cells %dx%d%s)" % [
				output_name, frames_in_tag, crop_rect.size.x, crop_rect.size.y,
				cell_w, cell_h, ", +shadow" if shadow_emitted else ""])
		else:
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
				var canvas_w_no_shadow := first_image.get_width()
				var canvas_h_no_shadow := first_image.get_height()
				var strip := Image.create(canvas_w_no_shadow * frames_in_tag, canvas_h_no_shadow, false, Image.FORMAT_RGBA8)
				strip.blit_rect(first_image, Rect2i(0, 0, canvas_w_no_shadow, canvas_h_no_shadow), Vector2i(0, 0))
				var stitched_count := 1
				for i in range(1, frames_in_tag):
					var frame_path := temp_aligned + "%04d.png" % (tag.from_frame + i)
					var frame_image := Image.load_from_file(frame_path)
					if frame_image == null:
						printerr("  Warning: Missing frame %d for tag '%s'" % [tag.from_frame + i, tag.name])
						continue
					strip.blit_rect(frame_image, Rect2i(0, 0, canvas_w_no_shadow, canvas_h_no_shadow), Vector2i(i * canvas_w_no_shadow, 0))
					stitched_count += 1
				var save_error := strip.save_png(output_path)
				if save_error != OK:
					printerr("  Failed to write strip for tag '%s' (error %d)" % [tag.name, save_error])
					continue
				print("  Strip: %s (%d frames, %dx%d)" % [output_name, stitched_count, canvas_w_no_shadow * frames_in_tag, canvas_h_no_shadow])

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
		if footprint_for_tag != Vector2i.ZERO:
			sidecar_data["footprint"] = [footprint_for_tag.x, footprint_for_tag.y]
		if shadow_emitted:
			sidecar_data["shadow_path"] = output_name + "_shadow.png"
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

	# Cleanup. Only the temp dirs we actually created.
	if has_shadow_layer:
		_cleanup_temp(temp_main_no_shadow)
		_cleanup_temp(temp_shadow_only)
	else:
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


# =============================================================================
# LAYER + SHADOW DETECTION
# =============================================================================

## Parses Layer Chunks (0x2004) from the .aseprite binary. Returns the layer
## names in file order (bottom to top in visual stacking). Used by shadow
## detection so we can route per-layer Aseprite CLI passes without depending
## on the (broken in this build) `--list-layers` listing command.
static func _parse_layers(global_path: String) -> Array[String]:
	var names: Array[String] = []
	var file := FileAccess.open(global_path, FileAccess.READ)
	if file == null:
		printerr("AsepriteTagExporter: Cannot open file for layer parse: %s" % global_path)
		return names

	var _file_size := file.get_32()
	var magic := file.get_16()
	if magic != ASE_MAGIC:
		return names

	var frame_count := file.get_16()
	file.seek(128)

	for frame_index in range(frame_count):
		var frame_start := file.get_position()
		var frame_size := file.get_32()
		var frame_magic := file.get_16()
		if frame_magic != FRAME_MAGIC:
			return names

		var old_chunk_count := file.get_16()
		file.get_16()  # duration
		file.get_buffer(2)  # reserved
		var new_chunk_count := file.get_32()
		var chunk_count: int = new_chunk_count if new_chunk_count != 0 else old_chunk_count

		for chunk_index in range(chunk_count):
			var chunk_start := file.get_position()
			var chunk_size := file.get_32()
			var chunk_type := file.get_16()

			if chunk_type == LAYERS_CHUNK_TYPE:
				# Layer Chunk: flags(W) + type(W) + child_level(W) + width(W) + height(W)
				#            + blend(W) + opacity(B) + reserved(3) + name(STRING)
				file.get_16()         # flags
				var layer_type := file.get_16()
				file.get_16()         # child_level
				file.get_16()         # default width
				file.get_16()         # default height
				file.get_16()         # blend mode
				file.get_8()          # opacity
				file.get_buffer(3)    # reserved
				var name_length := file.get_16()
				var layer_name := file.get_buffer(name_length).get_string_from_utf8()
				# Skip group layers (type 1) for shadow detection — only leaf
				# image layers can be filtered by --layer/--ignore-layer flags.
				if layer_type != 1:
					names.append(layer_name)

			file.seek(chunk_start + chunk_size)

		file.seek(frame_start + frame_size)

	return names


## True if the layer name self-identifies as a shadow by convention. Matches:
##   - exact name "shadow" (case-insensitive)
##   - name ending in "_shadow" (case-insensitive)
## Lawrence's current source uses "Shadow"; the "_shadow" suffix is the
## escape hatch for sprites where a layer must be marked explicitly (e.g.
## an animated shadow with some empty frames where the content scan
## couldn't otherwise confirm).
static func _is_shadow_layer_by_name(layer_name: String) -> bool:
	var lower := layer_name.strip_edges().to_lower()
	return lower == "shadow" or lower.ends_with("_shadow")


## True if every non-transparent pixel in the image matches the shadow
## signature (pure black @ ~40% alpha within tolerance). An image with
## zero non-transparent pixels returns false — empty isn't a shadow, it's
## empty.
static func _image_matches_shadow_signature(img: Image) -> bool:
	if img == null:
		return false
	var w := img.get_width()
	var h := img.get_height()
	var any_opaque := false
	for y in range(h):
		for x in range(w):
			var px := img.get_pixel(x, y)
			var a := int(round(px.a * 255.0))
			if a <= SHADOW_ALPHA_MIN_OPAQUE:
				continue
			any_opaque = true
			var r := int(round(px.r * 255.0))
			var g := int(round(px.g * 255.0))
			var b := int(round(px.b * 255.0))
			if r > SHADOW_RGB_MAX or g > SHADOW_RGB_MAX or b > SHADOW_RGB_MAX:
				return false
			if abs(a - SHADOW_ALPHA_TARGET) > SHADOW_ALPHA_TOLERANCE:
				return false
	return any_opaque


## Pick the shadow layer (if any) from a file's layer list. Tries name-based
## detection first (cheap); falls back to a content scan by exporting each
## candidate layer's first frame and checking the pixel signature. Returns
## the matching layer name, or "" if no shadow layer is present.
static func _detect_shadow_layer(layer_names: Array[String], global_source: String, aseprite_command: String) -> String:
	# Name-based first — no Aseprite invocations needed.
	for name in layer_names:
		if _is_shadow_layer_by_name(name):
			return name
	# Content-based fallback: export each layer's first frame and scan.
	# Only useful when Lawrence neglected the naming convention AND the
	# layer happens to match the signature.
	var probe_dir := OS.get_cache_dir() + "/aseprite_shadow_probe/"
	DirAccess.make_dir_recursive_absolute(probe_dir)
	var matched := ""
	for name in layer_names:
		_cleanup_temp(probe_dir)
		DirAccess.make_dir_recursive_absolute(probe_dir)
		var args := PackedStringArray([
			"-b", global_source,
			"--layer", name,
			"--frame-range", "0,0",
			"--save-as", probe_dir + "probe.png",
		])
		var output := []
		var exit := OS.execute(aseprite_command, args, output, true, true)
		if exit != 0:
			continue
		var img := Image.load_from_file(probe_dir + "probe.png")
		if _image_matches_shadow_signature(img):
			matched = name
			break
	_cleanup_temp(probe_dir)
	return matched


# =============================================================================
# FOOTPRINT SLICE
# =============================================================================

## Parses Slice Chunks (0x2022) looking for a slice named "footprint". When
## present, the slice's pixel dimensions define the tag's gameplay footprint
## in tile cells (slice_w/32 × slice_h/32). When absent, the caller falls
## back to computing footprint from the tag's image bbox.
static func _parse_footprint_slice(global_path: String) -> Vector2i:
	var file := FileAccess.open(global_path, FileAccess.READ)
	if file == null:
		return Vector2i.ZERO

	var _file_size := file.get_32()
	var magic := file.get_16()
	if magic != ASE_MAGIC:
		return Vector2i.ZERO

	var frame_count := file.get_16()
	file.seek(128)

	for frame_index in range(frame_count):
		var frame_start := file.get_position()
		var frame_size := file.get_32()
		var frame_magic := file.get_16()
		if frame_magic != FRAME_MAGIC:
			return Vector2i.ZERO

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
				var slice_name := file.get_buffer(name_length).get_string_from_utf8()

				var has_9patch := (flags & 0x1) != 0
				var has_pivot := (flags & 0x2) != 0

				if slice_name.strip_edges().to_lower() == "footprint" and key_count > 0:
					file.get_32()  # frame number
					file.get_32()  # slice x (ignored — we just want size)
					file.get_32()  # slice y
					var slice_w := file.get_32()
					var slice_h := file.get_32()
					# Pixel dims → tile cells, rounded up so a 33-px-wide slice
					# still resolves to 2 cells rather than 1.
					var fw := int(ceil(float(slice_w) / float(TILE_SIZE_PX)))
					var fh := int(ceil(float(slice_h) / float(TILE_SIZE_PX)))
					return Vector2i(maxi(1, fw), maxi(1, fh))
				# Skip the rest of this slice key entry by seeking to next chunk.
				_unused(has_9patch)
				_unused(has_pivot)

			file.seek(chunk_start + chunk_size)

		file.seek(frame_start + frame_size)

	return Vector2i.ZERO


# Placeholder to silence "unused variable" warnings inside the slice parser
# without restructuring the read pattern.
static func _unused(_v) -> void:
	pass


# =============================================================================
# IMAGE BBOX + CROP
# =============================================================================

## Returns the tight bounding rect of non-transparent pixels in `img`, or
## Rect2i(0,0,0,0) if the image is entirely transparent. Caller pads to
## 32-px multiples separately.
static func _content_bbox(img: Image) -> Rect2i:
	if img == null:
		return Rect2i()
	var w := img.get_width()
	var h := img.get_height()
	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1
	for y in range(h):
		for x in range(w):
			var px := img.get_pixel(x, y)
			if int(round(px.a * 255.0)) <= SHADOW_ALPHA_MIN_OPAQUE:
				continue
			if x < min_x: min_x = x
			if y < min_y: min_y = y
			if x > max_x: max_x = x
			if y > max_y: max_y = y
	if max_x < 0:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


## Expand a bbox to the smallest axis-aligned rect whose dimensions are
## multiples of TILE_SIZE_PX, bottom-aligned (preserves the bottom edge so
## sprites with vertical canvas overhang anchor to their gameplay tile).
static func _pad_bbox_to_cells(bbox: Rect2i, canvas: Vector2i) -> Rect2i:
	if bbox.size.x <= 0 or bbox.size.y <= 0:
		return bbox
	var padded_w: int = int(ceil(float(bbox.size.x) / float(TILE_SIZE_PX))) * TILE_SIZE_PX
	var padded_h: int = int(ceil(float(bbox.size.y) / float(TILE_SIZE_PX))) * TILE_SIZE_PX
	# Center horizontally within the padded width, but anchor bottom edge.
	var new_x: int = bbox.position.x - int(floor(float(padded_w - bbox.size.x) / 2.0))
	var new_y: int = bbox.position.y + bbox.size.y - padded_h
	# Clamp to canvas — don't extend past the source image.
	new_x = clampi(new_x, 0, canvas.x - padded_w)
	new_y = clampi(new_y, 0, canvas.y - padded_h)
	return Rect2i(new_x, new_y, padded_w, padded_h)


## Returns the union of two bboxes. Either may be empty (size <= 0); in
## that case the other is returned. Used to crop main + shadow to a shared
## rect that holds both.
static func _bbox_union(a: Rect2i, b: Rect2i) -> Rect2i:
	if a.size.x <= 0 or a.size.y <= 0:
		return b
	if b.size.x <= 0 or b.size.y <= 0:
		return a
	var x0 := mini(a.position.x, b.position.x)
	var y0 := mini(a.position.y, b.position.y)
	var x1 := maxi(a.position.x + a.size.x, b.position.x + b.size.x)
	var y1 := maxi(a.position.y + a.size.y, b.position.y + b.size.y)
	return Rect2i(x0, y0, x1 - x0, y1 - y0)


static func _cleanup_temp(temp_directory: String) -> void:
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

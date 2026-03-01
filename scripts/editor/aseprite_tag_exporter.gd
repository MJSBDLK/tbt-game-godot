## @tool EditorScript to export tagged frames from an .aseprite file as individual PNGs.
## Run from Editor > Script > Run in Godot.
##
## Select an .aseprite file in the FileSystem dock, then run this script.
## Each Aseprite tag becomes a separate PNG named after the tag, exported to a
## sibling directory with the same name as the file (e.g. icons.aseprite -> icons/).
##
## Reads the Aseprite command path from Editor Settings (same as Aseprite Wizard).
## Parses the .aseprite binary directly for tag names (works around broken --list-tags).
@tool
extends EditorScript

const ASEPRITE_COMMAND_KEY := "aseprite/general/command_path"
const ASE_MAGIC := 0xA5E0
const FRAME_MAGIC := 0xF1FA
const TAGS_CHUNK_TYPE := 0x2018


func _run() -> void:
	var lowercase_names := true  # "Air" -> "air.png"

	# Get selected file from FileSystem dock
	var selected_paths := EditorInterface.get_selected_paths()
	if selected_paths.is_empty():
		printerr("AsepriteTagExporter: Select an .aseprite file in the FileSystem dock first.")
		return

	var aseprite_file_path := selected_paths[0]
	if not aseprite_file_path.ends_with(".aseprite") and not aseprite_file_path.ends_with(".ase"):
		printerr("AsepriteTagExporter: Selected file is not an .aseprite file: %s" % aseprite_file_path)
		return

	# Output to sibling directory named after the file (without extension)
	var base_name := aseprite_file_path.get_file().get_basename()
	var output_directory := aseprite_file_path.get_base_dir() + "/" + base_name + "/"

	# Validate source file
	var global_source := ProjectSettings.globalize_path(aseprite_file_path)
	if not FileAccess.file_exists(global_source):
		printerr("AsepriteTagExporter: Source file not found: %s" % aseprite_file_path)
		return

	# Ensure output directory exists
	if not DirAccess.dir_exists_absolute(output_directory):
		DirAccess.make_dir_recursive_absolute(output_directory)

	# Get aseprite command
	var aseprite_command := _get_aseprite_command()

	# Parse tags from .aseprite binary
	var tags := _parse_tags(global_source)
	if tags.is_empty():
		printerr("AsepriteTagExporter: No tags found in %s" % aseprite_file_path)
		return

	print("AsepriteTagExporter: Found %d tags in %s" % [tags.size(), aseprite_file_path])
	for tag in tags:
		print("  %s (frame %d)" % [tag.name, tag.from_frame])

	# Export all frames to temp directory
	var temp_directory := OS.get_cache_dir() + "/aseprite_tag_export/"
	DirAccess.make_dir_recursive_absolute(temp_directory)

	var arguments := PackedStringArray([
		"-b",
		global_source,
		"--save-as",
		temp_directory + "{frame0000}.png",
	])
	var output := []
	var exit_code := OS.execute(aseprite_command, arguments, output, true, true)
	if exit_code != 0:
		printerr("AsepriteTagExporter: Aseprite export failed (exit code %d)" % exit_code)
		if not output.is_empty():
			printerr("  %s" % output[0])
		_cleanup_temp(temp_directory)
		return

	# Copy numbered frames to output directory with tag names
	var global_output := ProjectSettings.globalize_path(output_directory)
	var exported_count := 0
	for tag in tags:
		var numbered_filename := "%04d.png" % tag.from_frame
		var numbered_path := temp_directory + numbered_filename
		if not FileAccess.file_exists(numbered_path):
			printerr("  Warning: Missing frame file for tag '%s': %s" % [tag.name, numbered_filename])
			continue

		var output_name := _sanitize_filename(tag.name, lowercase_names)
		var output_path := global_output + output_name + ".png"

		var source_file := FileAccess.open(numbered_path, FileAccess.READ)
		var data := source_file.get_buffer(source_file.get_length())
		source_file.close()

		var destination_file := FileAccess.open(output_path, FileAccess.WRITE)
		destination_file.store_buffer(data)
		destination_file.close()

		exported_count += 1

	# Clean up
	_cleanup_temp(temp_directory)

	# Trigger reimport
	EditorInterface.get_resource_filesystem().scan()

	print("AsepriteTagExporter: Exported %d icons to %s" % [exported_count, output_directory])


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
	var file_size := file.get_32()
	var magic := file.get_16()
	if magic != ASE_MAGIC:
		printerr("AsepriteTagExporter: Not a valid .aseprite file (bad magic: 0x%04X)" % magic)
		return tags

	var frame_count := file.get_16()
	file.seek(128)  # Skip rest of header

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

				return tags  # Found tags, no need to continue

			# Skip to next chunk
			file.seek(chunk_start + chunk_size)

		# Seek to next frame
		file.seek(frame_start + frame_size)

	return tags


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

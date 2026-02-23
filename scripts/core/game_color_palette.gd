## Static accessor for the game's color palette system.
## Loads colors from the artist's GIMP .GPL palette file at startup.
## Provides ramp-based color access: GameColorPalette.get_color("Azure", 5)
##
## The GPL file contains 32 ramps of 11 colors each (0=darkest, 10=lightest).
class_name GameColorPalette

# Ramp name mapping — order matches the GPL file rows (groups of 11)
const RAMP_NAMES: Array[String] = [
	"RedViolet",       # 0
	"Magenta",         # 1
	"Violet",          # 2
	"Purple",          # 3
	"Blue",            # 4
	"Azure",           # 5 - PDA text color
	"Cyan",            # 6
	"Teal",            # 7
	"Green",           # 8
	"Chartreuse",      # 9
	"Yellow",          # 10
	"YellowOrange",    # 11
	"Orange",          # 12
	"PoppyRed",        # 13
	"Red",             # 14
	"Gray",            # 15
	"Eggshell",        # 16
	"TealGray",        # 17
	"S1",              # 18
	"S2",              # 19
	"Straw",           # 20
	"Tan2",            # 21
	"Tan1",            # 22
	"Eggplant",        # 23
	"StylizedVillage", # 24
	"PastelleSunset",  # 25
	"PastelleSky",     # 26
	"StylizedSunset",  # 27
	"DappledCool",     # 28
	"WarmNature",      # 29
	"WarmBackground",  # 30
	"Straw2",          # 31
]

const GPL_PATH: String = "res://art/colors/SpacemanColorPalette_v1.41.gpl"

# Dictionary[String, Array[Color]] — ramp_name -> array of 11 colors
static var _ramps: Dictionary = {}
static var _loaded: bool = false


## Load the palette from the GPL file. Call once at startup.
static func load_palette() -> void:
	_ramps.clear()

	if not FileAccess.file_exists(GPL_PATH):
		push_warning("GameColorPalette: GPL file not found at %s" % GPL_PATH)
		_loaded = true
		return

	var file := FileAccess.open(GPL_PATH, FileAccess.READ)
	if file == null:
		push_error("GameColorPalette: Failed to open %s" % GPL_PATH)
		_loaded = true
		return

	var all_colors: Array[Color] = []

	while not file.eof_reached():
		var line := file.get_line().strip_edges()

		# Skip header and comments
		if line.begins_with("GIMP Palette") or line.begins_with("Name:") \
				or line.begins_with("Columns:") or line.begins_with("Channels:") \
				or line.begins_with("#") or line.is_empty():
			continue

		# Parse: "R G B A\tName" or "R G B\tName"
		var parts := line.split(" ", false)
		# Also handle tab separation
		if parts.size() < 3:
			parts = line.split("\t", false)
		if parts.size() < 3:
			continue

		var r_str := parts[0].strip_edges()
		var g_str := parts[1].strip_edges()
		var b_str := parts[2].strip_edges()

		if not r_str.is_valid_int() or not g_str.is_valid_int() or not b_str.is_valid_int():
			continue

		var r := r_str.to_int()
		var g := g_str.to_int()
		var b := b_str.to_int()
		var a := 255

		if parts.size() >= 4:
			var a_str := parts[3].strip_edges()
			if a_str.is_valid_int():
				a = a_str.to_int()

		all_colors.append(Color(r / 255.0, g / 255.0, b / 255.0, a / 255.0))

	file.close()

	# Assign colors to ramps in groups of 11
	var ramp_idx := 0
	for i in range(0, all_colors.size(), 11):
		if ramp_idx >= RAMP_NAMES.size():
			break
		var ramp_colors: Array[Color] = []
		var count := mini(11, all_colors.size() - i)
		for j in range(count):
			ramp_colors.append(all_colors[i + j])
		# Pad to 11 if incomplete
		while ramp_colors.size() < 11:
			ramp_colors.append(Color.MAGENTA)
		_ramps[RAMP_NAMES[ramp_idx].to_lower()] = ramp_colors
		ramp_idx += 1

	_loaded = true
	print("GameColorPalette: Loaded %d ramps from GPL file" % ramp_idx)


## Get a color from a named ramp at the specified index (0-10).
static func get_color(ramp_name: String, index: int) -> Color:
	if not _loaded:
		load_palette()

	var key := ramp_name.to_lower()
	if _ramps.has(key):
		index = clampi(index, 0, 10)
		return _ramps[key][index]

	push_warning("GameColorPalette: Ramp '%s' not found" % ramp_name)
	return Color.MAGENTA


## Get interpolated color between two indices on a ramp.
static func get_color_interpolated(ramp_name: String, index: float) -> Color:
	if not _loaded:
		load_palette()

	var key := ramp_name.to_lower()
	if not _ramps.has(key):
		push_warning("GameColorPalette: Ramp '%s' not found" % ramp_name)
		return Color.MAGENTA

	index = clampf(index, 0.0, 10.0)
	var lower := floori(index)
	var upper := ceili(index)
	if lower == upper:
		return _ramps[key][lower]
	var t := index - lower
	return _ramps[key][lower].lerp(_ramps[key][upper], t)


## Get the color associated with an elemental type.
static func get_elemental_type_color(element_type: Enums.ElementalType, intensity: int = 5) -> Color:
	match element_type:
		Enums.ElementalType.FIRE: return get_color("Orange", 5)
		Enums.ElementalType.ELECTRIC: return get_color("Yellow", 6)
		Enums.ElementalType.PLANT: return get_color("Green", 6)
		Enums.ElementalType.COLD: return get_color("Blue", 7)
		Enums.ElementalType.AIR: return get_color("Cyan", intensity)
		Enums.ElementalType.GRAVITY: return get_color("Purple", 4)
		Enums.ElementalType.VOID: return get_color("Purple", 8)
		Enums.ElementalType.OCCULT: return get_color("Purple", 6)
		Enums.ElementalType.CHIVALRIC: return get_color("Blue", 5)
		Enums.ElementalType.HERALDIC: return get_color("YellowOrange", intensity)
		Enums.ElementalType.GENTRY: return get_color("Gray", intensity)
		Enums.ElementalType.ROBO: return get_color("TealGray", intensity)
		Enums.ElementalType.OBSIDIAN: return get_color("Gray", 1)
		Enums.ElementalType.SIMPLE: return get_color("Gray", 5)
		_: return get_color("Gray", 5)


## Force reload the palette (useful after updating the GPL file).
static func reload_palette() -> void:
	_loaded = false
	_ramps.clear()

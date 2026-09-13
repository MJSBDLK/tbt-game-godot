## Dumps 6×6 status icons as ASCII + their palette, so a placeholder can be
## drawn in the same colours without opening Aseprite.
##   godot-4 --headless --path . -s tools/art/status_icon_probe.gd -- name [name…]
extends SceneTree


const ICON_DIR: String = "res://art/sprites/ui/status_effect_icons_6x6_v2/"


func _init() -> void:
	var names: PackedStringArray = OS.get_cmdline_user_args()
	if names.is_empty():
		names = PackedStringArray(["rallied", "focused", "bellows", "shocked"])
	for icon_name: String in names:
		_dump(icon_name)
	quit()


func _dump(icon_name: String) -> void:
	var image := Image.load_from_file(ICON_DIR + icon_name + "_0000.png")
	if image == null:
		print("%s: missing" % icon_name)
		return
	print("== %s %dx%d" % [icon_name, image.get_width(), image.get_height()])
	var palette: Dictionary = {}
	var glyphs: String = "#*+=-:."
	for y: int in image.get_height():
		var row: String = ""
		for x: int in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a < 0.01:
				row += " "
				continue
			var key: String = color.to_html(false)
			if not palette.has(key):
				palette[key] = glyphs[mini(palette.size(), glyphs.length() - 1)]
			row += palette[key]
		print("|%s|" % row)
	print("palette: %s" % [palette])

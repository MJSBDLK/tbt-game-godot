## Mints a PLACEHOLDER 6×6 status icon from an inline pixel map, in the
## palette of a shipped icon, so a new status never logs a missing-resource
## error while it waits for Lawrence's real art (same-name replacement, like
## the placeholder SFX). Run once per icon, then `godot-4 --headless --import`
## so the PNG gets its .import:
##   godot-4 --headless --path . -s tools/art/placeholder_status_icon.gd -- hasted
## Add a new map to MAPS to mint another. Letters index PALETTE; space = clear.
extends SceneTree


const ICON_DIR: String = "res://art/sprites/ui/status_effect_icons_6x6_v2/"

## Rallied's ramps — the buff family's ink on the contact sheet: gold for
## the stat-ups, its olive greens for the heal-over-time.
const PALETTE: Dictionary = {
	"h": Color("dace9f"),  # cream highlight
	"g": Color("e2ad37"),  # gold body
	"d": Color("b37d25"),  # dark gold
	"s": Color("875516"),  # shadow
	"G": Color("6b7c3c"),  # olive green body
	"D": Color("515d29"),  # dark olive
}

## hasted: two right-pointing chevrons — "faster" in the smallest vocabulary
## that reads at 6 px; lit top edges, shaded lower legs.
## fortified: a shield, lit rim on the left, shaded right.
## regen: a plus — the heal mark — in the olive ramp, cream on the top arm.
const MAPS: Dictionary = {
	"hasted": [
		"h  h  ",
		" g  g ",
		"  h  h",
		" d  d ",
		"s  s  ",
		"      ",
	],
	"fortified": [
		" hggd ",
		"hg  gd",
		"hg  gd",
		" g  d ",
		"  gd  ",
		"      ",
	],
	"regen": [
		"  hG  ",
		"  GG  ",
		"hGGGGD",
		"GGGGDD",
		"  GD  ",
		"  DD  ",
	],
}


func _init() -> void:
	for icon_name: String in OS.get_cmdline_user_args():
		_mint(icon_name)
	quit()


func _mint(icon_name: String) -> void:
	if not MAPS.has(icon_name):
		push_error("placeholder_status_icon: no map for '%s' (have %s)" % [icon_name, MAPS.keys()])
		return
	var rows: Array = MAPS[icon_name]
	var image := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in row.length():
			var key: String = row[x]
			if key != " ":
				assert(PALETTE.has(key), "unknown palette key '%s'" % key)
				image.set_pixel(x, y, PALETTE[key])
	var path: String = ICON_DIR + icon_name + "_0000.png"
	var err: int = image.save_png(path)
	print("placeholder_status_icon: %s → %s (%s)" % [icon_name, path, error_string(err)])

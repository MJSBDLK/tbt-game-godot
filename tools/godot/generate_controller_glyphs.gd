## Generates the 1-bit controller button glyphs (white on transparent, 10x10)
## into art/sprites/ui/controller_glyphs/. Design brief + naming convention:
## data/design/art-requests/controller-glyphs.html — sprites are named by what
## they DEPICT (letter_a, shape_cross, label_lb), never by which button they
## sit on; HintBarCommands maps skin+button -> sprite.
##
## These are the in-house defaults (RQD 2026-09-02: "this is just doable on
## our end"). Lawrence's pass is a veto/redraw of any glyph that reads wrong —
## replace the PNG, keep the name, nothing else moves.
##
## Run from the project root:
##   godot-4 --headless --path . -s tools/godot/generate_controller_glyphs.gd
## Also emits .claude/controller_glyphs_contact.png — every glyph at 8x on a
## dark plate — for eyeballing without booting the game.
extends SceneTree

const OUTPUT_DIRECTORY: String = "res://art/sprites/ui/controller_glyphs/"
const CONTACT_SHEET_PATH: String = "res://.claude/controller_glyphs_contact.png"
const CANVAS_SIZE: int = 10

## 5x7 capitals — single-stroke, matching the house pixel-font weight.
## Used solo for face letters (Xbox/Steam A B X Y, Switch shoulders L R).
const LETTERS_5X7: Dictionary = {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
}

## 4x5 mini font — two of these side by side make the shoulder/trigger/stick
## labels (LB, R1, ZR, L3...). Same trade as the game's 5px mini font: only
## legible because the vocabulary is tiny and expected.
const MINI_4X5: Dictionary = {
	"L": ["#...", "#...", "#...", "#...", "####"],
	"B": ["###.", "#..#", "###.", "#..#", "###."],
	"R": ["###.", "#..#", "###.", "#.#.", "#..#"],
	"T": ["####", ".#..", ".#..", ".#..", ".#.."],
	"Z": ["####", "..#.", ".#..", "#...", "####"],
	"1": [".#..", "##..", ".#..", ".#..", "####"],
	"2": ["###.", "...#", ".##.", "#...", "####"],
	"3": ["###.", "...#", ".##.", "...#", "###."],
}

## Whole-canvas or fixed-size art, centered by _blit at the offset given below.
const ART: Dictionary = {
	"shape_cross": [
		"#......#", ".#....#.", "..#..#..", "...##...",
		"...##...", "..#..#..", ".#....#.", "#......#"],
	"shape_circle": [
		"..####..", ".#....#.", "#......#", "#......#",
		"#......#", "#......#", ".#....#.", "..####.."],
	"shape_square": [
		"########", "#......#", "#......#", "#......#",
		"#......#", "#......#", "#......#", "########"],
	"shape_triangle": [
		"...##...", "...##...", "..#..#..", "..#..#..",
		".#....#.", ".#....#.", "#......#", "########"],
	"icon_menu": [
		"########", "........", "########", "........", "########"],
	"icon_view": [
		"######..", "#....#..", "#..#####", "#..#...#",
		"#..#...#", "####...#", "...#...#", "...#####"],
	"label_plus": [
		"..#..", "..#..", "#####", "..#..", "..#.."],
	"label_minus": [
		".....", ".....", "#####", ".....", "....."],
}

## The d-pad cross outline with the UP arm filled; the other three directions
## are derived (flip / transpose), so the silhouette can't drift between them.
const DPAD_UP: Array[String] = [
	"...####...",
	"...####...",
	"...####...",
	"####..####",
	"#........#",
	"#........#",
	"####..####",
	"...#..#...",
	"...#..#...",
	"...####...",
]


func _initialize() -> void:
	_run()
	quit()


func _run() -> void:
	var sprites: Dictionary = _build_all_sprites()
	var output_dir: String = ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var names: Array = sprites.keys()
	names.sort()
	for sprite_name: String in names:
		var image: Image = _rows_to_image(sprites[sprite_name])
		var error: Error = image.save_png(output_dir + sprite_name + ".png")
		assert(error == OK, "failed to write %s" % sprite_name)
		print("[glyphs] wrote ", sprite_name, ".png")
	_write_contact_sheet(sprites, names)
	print("[glyphs] done — ", names.size(), " sprites")


## Every sprite as an Array[String] of CANVAS_SIZE rows ('#' = white pixel).
func _build_all_sprites() -> Dictionary:
	var sprites: Dictionary = {}
	# Face letters + Switch shoulder letters: one 5x7 capital, centered.
	for letter: String in ["A", "B", "X", "Y", "L", "R"]:
		sprites["letter_" + letter.to_lower()] = _compose([[LETTERS_5X7[letter], 2, 1]])
	# Two-character labels from the mini font: char 1 at x=0, char 2 at x=5.
	var labels: Array[String] = ["LB", "RB", "L1", "R1", "LT", "RT", "L2", "R2", "ZL", "ZR"]
	for label: String in labels:
		sprites["label_" + label.to_lower()] = _compose_mini_pair(label)
	sprites["stick_l3"] = _compose_mini_pair("L3")
	sprites["stick_r3"] = _compose_mini_pair("R3")
	# Fixed art, centered on the canvas by its own size.
	for art_name: String in ART:
		var rows: Array = ART[art_name]
		var x_offset: int = (CANVAS_SIZE - String(rows[0]).length()) / 2
		var y_offset: int = (CANVAS_SIZE - rows.size()) / 2
		sprites[art_name] = _compose([[rows, x_offset, y_offset]])
	# D-pad: author UP once, derive the rest.
	sprites["dpad_up"] = DPAD_UP.duplicate()
	sprites["dpad_down"] = _flip_vertical(DPAD_UP)
	sprites["dpad_left"] = _transpose(DPAD_UP)
	sprites["dpad_right"] = _flip_horizontal(_transpose(DPAD_UP))
	return sprites


## Stamp [rows, x, y] blocks onto a blank CANVAS_SIZE canvas.
func _compose(blocks: Array) -> Array[String]:
	var canvas: Array[String] = []
	for y: int in CANVAS_SIZE:
		canvas.append(".".repeat(CANVAS_SIZE))
	for block: Array in blocks:
		var rows: Array = block[0]
		var x_offset: int = block[1]
		var y_offset: int = block[2]
		for row_index: int in rows.size():
			var row: String = rows[row_index]
			var canvas_row: String = canvas[y_offset + row_index]
			for column_index: int in row.length():
				if row[column_index] == "#":
					var x: int = x_offset + column_index
					canvas_row = canvas_row.substr(0, x) + "#" + canvas_row.substr(x + 1)
			canvas[y_offset + row_index] = canvas_row
	return canvas


func _compose_mini_pair(label: String) -> Array[String]:
	assert(label.length() == 2 and MINI_4X5.has(label[0]) and MINI_4X5.has(label[1]),
			"mini pair needs two chars from MINI_4X5: " + label)
	return _compose([[MINI_4X5[label[0]], 0, 2], [MINI_4X5[label[1]], 5, 2]])


func _flip_vertical(rows: Array) -> Array[String]:
	var out: Array[String] = []
	for index: int in range(rows.size() - 1, -1, -1):
		out.append(rows[index])
	return out


func _flip_horizontal(rows: Array) -> Array[String]:
	var out: Array[String] = []
	for row: String in rows:
		out.append(row.reverse())
	return out


func _transpose(rows: Array) -> Array[String]:
	var out: Array[String] = []
	for y: int in CANVAS_SIZE:
		var row: String = ""
		for x: int in CANVAS_SIZE:
			row += String(rows[x])[y]
		out.append(row)
	return out


func _rows_to_image(rows: Array) -> Image:
	var image: Image = Image.create(CANVAS_SIZE, CANVAS_SIZE, false, Image.FORMAT_RGBA8)
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in row.length():
			if row[x] == "#":
				image.set_pixel(x, y, Color.WHITE)
	return image


## All glyphs at 8x on a dark plate, 6 per row, labeled columns skipped —
## purely for human eyeballing (Read the PNG, or open it in an image viewer).
func _write_contact_sheet(sprites: Dictionary, names: Array) -> void:
	var scale: int = 8
	var cell: int = CANVAS_SIZE * scale + 16
	var columns: int = 6
	var rows_needed: int = ceili(float(names.size()) / columns)
	var sheet: Image = Image.create(columns * cell, rows_needed * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("1a212c"))
	for index: int in names.size():
		var source: Image = _rows_to_image(sprites[names[index]])
		var scaled: Image = source.duplicate()
		scaled.resize(CANVAS_SIZE * scale, CANVAS_SIZE * scale, Image.INTERPOLATE_NEAREST)
		var cell_x: int = (index % columns) * cell + 8
		var cell_y: int = (index / columns) * cell + 8
		sheet.blend_rect(scaled, Rect2i(0, 0, scaled.get_width(), scaled.get_height()),
				Vector2i(cell_x, cell_y))
	var error: Error = sheet.save_png(ProjectSettings.globalize_path(CONTACT_SHEET_PATH))
	assert(error == OK, "failed to write contact sheet")
	print("[glyphs] contact sheet: ", CONTACT_SHEET_PATH, " (order: alphabetical)")

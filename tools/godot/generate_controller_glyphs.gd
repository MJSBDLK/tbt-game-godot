## Generates the 1-bit controller button glyphs (white on transparent, 12x12)
## into art/sprites/ui/controller_glyphs/. Design brief + naming convention:
## data/design/art-requests/controller-glyphs.html — sprites are named by what
## they DEPICT (letter_a, shape_cross, label_lb), never by which button they
## sit on; HintBarCommands maps skin+button -> sprite.
##
## BUTTON-FORMAT (RQD 2026-09-02): each sprite carries its own button
## silhouette — face letters sit in a circle, shoulder/trigger labels ride a
## bumper pill rounded on the correct outer corner, sticks and back grips get
## a rounded square, the d-pad is its own cross. The engine draws NO plate
## behind these; the silhouette is the chrome.
##
## These are the in-house defaults ("this is just doable on our end").
## Lawrence's pass is a veto/redraw of any glyph that reads wrong — replace
## the PNG, keep the name, nothing else moves.
##
## Run from the project root:
##   godot-4 --headless --path . -s tools/godot/generate_controller_glyphs.gd
## Also emits .claude/controller_glyphs_contact.png — every glyph at 8x on a
## dark plate — for eyeballing without booting the game.
extends SceneTree

const OUTPUT_DIRECTORY: String = "res://art/sprites/ui/controller_glyphs/"
const CONTACT_SHEET_PATH: String = "res://.claude/controller_glyphs_contact.png"
const CANVAS_SIZE: int = 12

## 5x7 capitals — single-stroke, matching the house pixel-font weight. Sit
## inside CIRCLE_12 for the face buttons (Xbox/Steam A B X Y; Switch reuses
## them in swapped positions).
const LETTERS_5X7: Dictionary = {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
}

## 4x5 mini font — pairs make the shoulder/trigger/stick/grip labels
## (LB, R1, ZR, L3, P4...), singles make Switch's shoulder L/R. Same trade as
## the game's 5px mini font: only legible because the vocabulary is expected.
const MINI_4X5: Dictionary = {
	"A": [".##.", "#..#", "####", "#..#", "#..#"],
	"B": ["###.", "#..#", "###.", "#..#", "###."],
	"C": [".###", "#...", "#...", "#...", ".###"],
	"E": ["####", "#...", "###.", "#...", "####"],
	"L": ["#...", "#...", "#...", "#...", "####"],
	"P": ["###.", "#..#", "###.", "#...", "#..."],
	"R": ["###.", "#..#", "###.", "#.#.", "#..#"],
	"S": [".###", "#...", ".##.", "...#", "###."],
	"T": ["####", ".#..", ".#..", ".#..", ".#.."],
	"Z": ["####", "..#.", ".#..", "#...", "####"],
	"1": [".#..", "##..", ".#..", ".#..", "####"],
	"2": ["###.", "...#", ".##.", "#...", "####"],
	"3": ["###.", "...#", ".##.", "...#", "###."],
	"4": ["#..#", "#..#", "####", "...#", "...#"],
	"5": ["####", "#...", "###.", "...#", "###."],
}

# ---- button silhouettes ------------------------------------------------------

## Flatter-shouldered than a true circle: the shoulder pixels of the round
## version sat orthogonally above the letters' top row, breaking the 1px
## text-clearance rule (RQD 2026-09-02) — this curve keeps rows 1/10 clear of
## the letter columns.
const CIRCLE_12: Array[String] = [
	"...######...",
	".##......##.",
	"#..........#",
	"#..........#",
	"#..........#",
	"#..........#",
	"#..........#",
	"#..........#",
	"#..........#",
	"#..........#",
	".##......##.",
	"...######...",
]

## Left bumper/trigger pill (15x10, stamped at y=1): swept round on the outer
## (top-left) corner, tight radius everywhere else. Right side is the mirror.
## 15 wide and 10 tall — narrower/shorter versions put the sweep or an edge
## orthogonally against the label (the 1px text-clearance rule).
const BUMPER_WIDTH: int = 15
const BUMPER_LEFT_15X10: Array[String] = [
	"....###########",
	"..##..........#",
	".#............#",
	"#.............#",
	"#.............#",
	"#.............#",
	"#.............#",
	"#.............#",
	"#.............#",
	".#############.",
]

## Sticks + back grips (no distinctive silhouette worth the pixels): rounded
## square, 13 wide so the label's right column keeps its 1px clearance.
const ROUNDED_SQUARE_WIDTH: int = 13
const ROUNDED_SQUARE_13: Array[String] = [
	".###########.",
	"#...........#",
	"#...........#",
	"#...........#",
	"#...........#",
	"#...........#",
	"#...........#",
	"#...........#",
	"#...........#",
	"#...........#",
	"#...........#",
	".###########.",
]

# ---- inner marks (6x6 centers exactly in the 12 circle) ----------------------

const INNER_6X6: Dictionary = {
	"cross": ["#....#", ".#..#.", "..##..", "..##..", ".#..#.", "#....#"],
	"circle": [".####.", "#....#", "#....#", "#....#", "#....#", ".####."],
	"square": ["######", "#....#", "#....#", "#....#", "#....#", "######"],
	"triangle": ["..##..", "..##..", ".#..#.", ".#..#.", "#....#", "######"],
	"plus": ["..##..", "..##..", "######", "######", "..##..", "..##.."],
	"minus": ["......", "......", "######", "######", "......", "......"],
	# Two overlapping 4x4 square outlines — the Xbox View glyph.
	"view": ["####..", "#..#..", "#.####", "####.#", "..#..#", "..####"],
}

const MENU_BAR_6: Array[String] = ["######"]

## The d-pad cross outline (10x10, centered on the canvas) with the UP arm
## filled; the other three directions are derived (flip / transpose), so the
## silhouette can't drift between them.
const DPAD_UP_10: Array[String] = [
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
	var bumper_right: Array[String] = _flip_horizontal(BUMPER_LEFT_15X10)
	# Face buttons: 5x7 capital in the circle.
	for letter: String in ["A", "B", "X", "Y"]:
		sprites["letter_" + letter.to_lower()] = _compose_button(
				[[CIRCLE_12, 0, 0]], [[LETTERS_5X7[letter], 3, 2]])
	# Switch shoulders: single mini letter on the correctly-swept bumper.
	sprites["letter_l"] = _compose_button(
			[[BUMPER_LEFT_15X10, 0, 1]], [[MINI_4X5["L"], 6, 4]], BUMPER_WIDTH)
	sprites["letter_r"] = _compose_button(
			[[bumper_right, 0, 1]], [[MINI_4X5["R"], 5, 4]], BUMPER_WIDTH)
	# Shoulder/trigger pairs ride the bumper swept toward their side.
	for label: String in ["LB", "L1", "LT", "L2", "ZL"]:
		sprites["label_" + label.to_lower()] = _compose_button(
				[[BUMPER_LEFT_15X10, 0, 1]], _mini_pair_blocks(label, 3, 4), BUMPER_WIDTH)
	for label: String in ["RB", "R1", "RT", "R2", "ZR"]:
		sprites["label_" + label.to_lower()] = _compose_button(
				[[bumper_right, 0, 1]], _mini_pair_blocks(label, 3, 4), BUMPER_WIDTH)
	# Stick clicks + back grips + Elite paddles: rounded square.
	for label: String in ["L3", "R3"]:
		sprites["stick_" + label.to_lower()] = _compose_button(
				[[ROUNDED_SQUARE_13, 0, 0]], _mini_pair_blocks(label, 2, 4),
				ROUNDED_SQUARE_WIDTH)
	for label: String in ["L4", "L5", "R4", "R5", "P1", "P2", "P3", "P4"]:
		sprites["label_" + label.to_lower()] = _compose_button(
				[[ROUNDED_SQUARE_13, 0, 0]], _mini_pair_blocks(label, 2, 4),
				ROUNDED_SQUARE_WIDTH)
	# PS faces, Switch +/-, Xbox View: mark inside the circle button.
	for inner_name: String in ["cross", "circle", "square", "triangle"]:
		sprites["shape_" + inner_name] = _compose([
			[CIRCLE_12, 0, 0], [INNER_6X6[inner_name], 3, 3]])
	sprites["label_plus"] = _compose([[CIRCLE_12, 0, 0], [INNER_6X6["plus"], 3, 3]])
	sprites["label_minus"] = _compose([[CIRCLE_12, 0, 0], [INNER_6X6["minus"], 3, 3]])
	# Hardware-accurate Xbox-era system icons — generated but currently
	# UNMAPPED (RQD 2026-09-02: "three lines and overlapping squares have
	# always made me look at the controller"). Kept for a cheap re-audition.
	sprites["icon_view"] = _compose([[CIRCLE_12, 0, 0], [INNER_6X6["view"], 3, 3]])
	sprites["icon_menu"] = _compose([[CIRCLE_12, 0, 0],
			[MENU_BAR_6, 3, 4], [MENU_BAR_6, 3, 6], [MENU_BAR_6, 3, 8]])
	# The retro-universal system buttons: the era this audience learned pads
	# in printed the WORDS on pill buttons, so the word-on-a-pill IS the
	# universal glyph. Wide sprites — the chip-expands-to-fit rule covers it.
	sprites["label_start"] = _pill_label("START")
	sprites["label_select"] = _pill_label("SELECT")
	# LAYER SPLIT for color identities (RQD 2026-09-02): face buttons also
	# emit form + character as SEPARATE layers so the engine can tint them
	# independently — Xbox colors the skittle (green A, red B, blue X, gold Y),
	# PlayStation colors the mark on a dark button, per hardware. One shared
	# filled disc serves all eight; each char layer matches its merged sprite's
	# glyph position. 1px padding on every side gives the runtime glow shader
	# its halo room (files are 14x14; the merged 12-tall sprites are untouched).
	sprites["face_form"] = _pad(_fill_rows(_compose([[CIRCLE_12, 0, 0]])))
	for letter: String in ["A", "B", "X", "Y"]:
		sprites["letter_" + letter.to_lower() + "_char"] = _pad(
				_compose([[LETTERS_5X7[letter], 3, 2]]))
	for inner_name: String in ["cross", "circle", "square", "triangle"]:
		sprites["shape_" + inner_name + "_char"] = _pad(
				_compose([[INNER_6X6[inner_name], 3, 3]]))
	# D-pad: author UP once, derive the rest, center on the canvas.
	var dpad_variants: Dictionary = {
		"dpad_up": DPAD_UP_10,
		"dpad_down": _flip_vertical(DPAD_UP_10),
		"dpad_left": _transpose(DPAD_UP_10),
		"dpad_right": _flip_horizontal(_transpose(DPAD_UP_10)),
	}
	for dpad_name: String in dpad_variants:
		sprites[dpad_name] = _compose([[dpad_variants[dpad_name], 1, 1]])
	return sprites


## A pill button carrying a whole mini-font word — the retro START/SELECT
## format. Height 9 (centered on the 12-row canvas), width sized to the text.
func _pill_label(word: String) -> Array[String]:
	var text_width: int = word.length() * 5 - 1
	var width: int = text_width + 4
	var pill: Array[String] = [
		"." + "#".repeat(width - 2) + ".",
	]
	for y: int in 7:
		pill.append("#" + ".".repeat(width - 2) + "#")
	pill.append("." + "#".repeat(width - 2) + ".")
	var text_blocks: Array = []
	for index: int in word.length():
		assert(MINI_4X5.has(word[index]), "mini font lacks '%s'" % word[index])
		text_blocks.append([MINI_4X5[word[index]], 2 + index * 5, 3])
	return _compose_button([[pill, 0, 1]], text_blocks, width)


## The 1px breathing-room rule (RQD 2026-09-02): every letter/digit pixel
## keeps its four ORTHOGONAL neighbors free of silhouette pixels — diagonal
## contact is fine. Text and silhouette compose on separate layers so the
## rule is ASSERTED, not eyeballed: a reshaped silhouette that pinches a
## label fails generation instead of shipping.
func _compose_button(silhouette_blocks: Array, text_blocks: Array,
		width: int = CANVAS_SIZE) -> Array[String]:
	var silhouette: Array[String] = _compose(silhouette_blocks, width)
	var text: Array[String] = _compose(text_blocks, width)
	for y: int in text.size():
		for x: int in width:
			if text[y][x] != "#":
				continue
			assert(silhouette[y][x] != "#",
					"text overlaps silhouette at (%d,%d)" % [x, y])
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var neighbor_x: int = x + offset.x
				var neighbor_y: int = y + offset.y
				if neighbor_x < 0 or neighbor_y < 0 or neighbor_x >= width or neighbor_y >= text.size():
					continue
				assert(silhouette[neighbor_y][neighbor_x] != "#",
						"text pixel (%d,%d) touches silhouette orthogonally at (%d,%d)" % [
							x, y, neighbor_x, neighbor_y])
	var merged: Array[String] = []
	for y: int in text.size():
		var row: String = ""
		for x: int in width:
			row += "#" if (silhouette[y][x] == "#" or text[y][x] == "#") else "."
		merged.append(row)
	return merged


## Stamp [rows, x, y] blocks onto a blank width x CANVAS_SIZE canvas.
func _compose(blocks: Array, width: int = CANVAS_SIZE) -> Array[String]:
	var canvas: Array[String] = []
	for y: int in CANVAS_SIZE:
		canvas.append(".".repeat(width))
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


## The two [rows, x, y] blocks of a 2-char mini-font label (chars at x, x+5).
func _mini_pair_blocks(label: String, x: int, y: int) -> Array:
	assert(label.length() == 2 and MINI_4X5.has(label[0]) and MINI_4X5.has(label[1]),
			"mini pair needs two chars from MINI_4X5: " + label)
	return [[MINI_4X5[label[0]], x, y], [MINI_4X5[label[1]], x + 5, y]]


## Row-span fill: every pixel between a row's first and last outline pixel
## becomes solid. Correct for per-row-convex forms (the circle is).
func _fill_rows(rows: Array) -> Array[String]:
	var out: Array[String] = []
	for row: String in rows:
		var first: int = row.find("#")
		var last: int = row.rfind("#")
		if first < 0:
			out.append(row)
		else:
			out.append(row.substr(0, first) + "#".repeat(last - first + 1) + row.substr(last + 1))
	return out


## 1px transparent border on all sides — halo room for the glow shader, which
## can only paint inside the texture rect.
func _pad(rows: Array) -> Array[String]:
	var width: int = String(rows[0]).length()
	var out: Array[String] = [".".repeat(width + 2)]
	for row: String in rows:
		out.append("." + row + ".")
	out.append(".".repeat(width + 2))
	return out


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
	for y: int in String(rows[0]).length():
		var row: String = ""
		for x: int in rows.size():
			row += String(rows[x])[y]
		out.append(row)
	return out


func _rows_to_image(rows: Array) -> Image:
	var image: Image = Image.create(String(rows[0]).length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in row.length():
			if row[x] == "#":
				image.set_pixel(x, y, Color.WHITE)
	return image


## All glyphs at 8x on a dark plate, 6 per row — purely for human eyeballing
## (Read the PNG, or open it in an image viewer).
func _write_contact_sheet(sprites: Dictionary, names: Array) -> void:
	var scale: int = 8
	var widest: int = CANVAS_SIZE
	for sprite_name: String in names:
		widest = maxi(widest, String(sprites[sprite_name][0]).length())
	var cell: int = widest * scale + 16
	var cell_height: int = CANVAS_SIZE * scale + 16
	var columns: int = 6
	var rows_needed: int = ceili(float(names.size()) / columns)
	var sheet: Image = Image.create(columns * cell, rows_needed * cell_height, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("1a212c"))
	for index: int in names.size():
		var source: Image = _rows_to_image(sprites[names[index]])
		var scaled: Image = source.duplicate()
		scaled.resize(source.get_width() * scale, source.get_height() * scale, Image.INTERPOLATE_NEAREST)
		var cell_x: int = (index % columns) * cell + 8
		var cell_y: int = (index / columns) * cell_height + 8
		sheet.blend_rect(scaled, Rect2i(0, 0, scaled.get_width(), scaled.get_height()),
				Vector2i(cell_x, cell_y))
	var error: Error = sheet.save_png(ProjectSettings.globalize_path(CONTACT_SHEET_PATH))
	assert(error == OK, "failed to write contact sheet")
	print("[glyphs] contact sheet: ", CONTACT_SHEET_PATH, " (order: alphabetical)")

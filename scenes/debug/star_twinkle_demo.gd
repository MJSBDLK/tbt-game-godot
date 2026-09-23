## Debug harness for StarSky / shaders/star_twinkle.gdshader. Run this scene
## (F6). Dials come from ArtVariables, so edit that file and F5 to compare.
##   R    — re-roll the random star field
##   ESC  — quit
## Stands in for Lawrence's skybox_twinkle layer: a near-black canvas with
## single-pixel dots — red X, green +, yellow alternating, blue-only blinkers,
## blue mixed in for cadence — drawn at SCALE× so the 1-px tails read the way
## the HUD upscale will show them. The top row is a fixed anatomy strip so the
## probe can flipbook known stars; the field below is random.
extends Control

const SCALE := 4
const MAP_SIZE := Vector2i(320, 180)
const FIELD_TOP := 20
const FIELD_STAR_COUNT := 220
const FIELD_MIN_SPACING := 4
const BACKGROUND := Color8(6, 7, 12)

## Anatomy strip stars, spaced so 7×7 footprints never touch. Reach ramps
## for X and +, then cadence examples: blue 0 / 170 / 255 divide the probe's
## 8 s capture evenly so its loop closes.
const ANATOMY_Y := 8
const ANATOMY_X0 := 8
const ANATOMY_STEP := 12
const ANATOMY_COLORS: Array[Color] = [
	Color8(255, 0, 0), Color8(221, 0, 0), Color8(136, 0, 0), Color8(68, 0, 0),
	Color8(0, 255, 0), Color8(0, 221, 0), Color8(0, 136, 0), Color8(0, 68, 0),
	Color8(255, 255, 170), Color8(255, 255, 255),
	Color8(255, 0, 170), Color8(0, 255, 255), Color8(0, 0, 255),
]
## Cadence levels the random field paints into blue (see above for why these).
const FIELD_CADENCES: Array[int] = [0, 0, 0, 170, 170, 255]

var _sky: StarSky = null
var _seed: int = 1
var _label: Label = null


static func anatomy_positions() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in ANATOMY_COLORS.size():
		out.append(Vector2i(ANATOMY_X0 + i * ANATOMY_STEP, ANATOMY_Y))
	return out


## The stand-in skybox_twinkle layer. Transparent except for the star dots —
## the near-black ground is the layer beneath, as it will be in the real stage.
static func make_star_map(seed_value: int) -> Image:
	var image := Image.create(MAP_SIZE.x, MAP_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var positions := anatomy_positions()
	for i in positions.size():
		image.set_pixelv(positions[i], ANATOMY_COLORS[i])

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var placed: Array[Vector2i] = []
	var attempts := 0
	while placed.size() < FIELD_STAR_COUNT and attempts < FIELD_STAR_COUNT * 40:
		attempts += 1
		var candidate := Vector2i(
				rng.randi_range(3, MAP_SIZE.x - 4), rng.randi_range(FIELD_TOP, MAP_SIZE.y - 4))
		var crowded := false
		for other in placed:
			if maxi(absi(other.x - candidate.x), absi(other.y - candidate.y)) < FIELD_MIN_SPACING:
				crowded = true
				break
		if crowded:
			continue
		placed.append(candidate)
		var brightness := rng.randi_range(40, 255)
		var cadence: int = FIELD_CADENCES[rng.randi_range(0, FIELD_CADENCES.size() - 1)]
		var roll := rng.randf()
		var color := Color8(brightness, 0, 0, 255)           # X
		if roll > 0.42:
			color = Color8(0, brightness, 0, 255)            # +
		if roll > 0.84:
			color = Color8(brightness, brightness, 0, 255)   # alternating
		if roll > 0.94:
			color = Color8(0, 0, 255, 255)                   # blinker
		color.b8 = maxi(color.b8, cadence)
		image.set_pixelv(candidate, color)
	return image


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BACKGROUND
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_sky = StarSky.new()
	_sky.scale = Vector2(SCALE, SCALE)
	add_child(_sky)
	_reroll()

	_label = Label.new()
	_label.position = Vector2(16, MAP_SIZE.y * SCALE - 28)
	_label.text = "R re-roll   ESC quit"
	add_child(_label)


func _reroll() -> void:
	_sky.set_star_map(ImageTexture.create_from_image(make_star_map(_seed)))


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match (event as InputEventKey).keycode:
		KEY_R:
			_seed += 1
			_reroll()
		KEY_ESCAPE:
			get_tree().quit()

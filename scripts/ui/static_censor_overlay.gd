## Pixel-noise censor overlay used by Hypoesthesia to obscure HP readouts.
## Drop it into any Control parent; call set_censored(true) to show and animate.
class_name StaticCensorOverlay
extends TextureRect


const _NOISE_TEX: Texture2D = preload("res://art/sprites/ui/static_noise.png")
const _TICK_INTERVAL: float = 0.12

var _atlas: AtlasTexture = null
var _tick_accum: float = 0.0
var _targets: Array[Control] = []  # Union rect of these controls determines overlay extent


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true  # Escape BoxContainer layout so we can size ourselves.
	visible = false


func _ready() -> void:
	_atlas = AtlasTexture.new()
	_atlas.atlas = _NOISE_TEX
	texture = _atlas
	if _targets.is_empty():
		var parent := get_parent() as Control
		if parent != null:
			_targets = [parent]
	set_process(true)


func set_target(target: Control) -> void:
	_targets = [target]


func set_targets(targets: Array[Control]) -> void:
	_targets = targets


func set_censored(value: bool) -> void:
	visible = value
	if value:
		_sync_rect()
		_randomize_region()


func _process(delta: float) -> void:
	if not visible or _atlas == null:
		return
	_sync_rect()
	_tick_accum += delta
	if _tick_accum < _TICK_INTERVAL:
		return
	_tick_accum = 0.0
	_randomize_region()


func _randomize_region() -> void:
	# Sample exactly as many source pixels as we display, so nearest-neighbor
	# scaling is 1:1 with no uneven blocks.
	var region_w: int = maxi(1, int(size.x))
	var region_h: int = maxi(1, int(size.y))
	var tex_size: Vector2i = _NOISE_TEX.get_size()
	region_w = mini(region_w, tex_size.x)
	region_h = mini(region_h, tex_size.y)
	var max_x: int = tex_size.x - region_w
	var max_y: int = tex_size.y - region_h
	var rx: int = 0 if max_x <= 0 else randi() % (max_x + 1)
	var ry: int = 0 if max_y <= 0 else randi() % (max_y + 1)
	_atlas.region = Rect2(rx, ry, region_w, region_h)


func _sync_rect() -> void:
	if _targets.is_empty():
		return
	var union := Rect2()
	var initialized := false
	for target: Control in _targets:
		if target == null or not is_instance_valid(target):
			continue
		var r := Rect2(target.global_position, target.size)
		if not initialized:
			union = r
			initialized = true
		else:
			union = union.merge(r)
	if not initialized:
		return
	global_position = union.position
	size = union.size

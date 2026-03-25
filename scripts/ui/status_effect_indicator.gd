## Displays a row of status effect icons below a unit's health bar.
## Up to 4 icons, 6x6 each with 2px gaps, centered on the unit.
class_name StatusEffectIndicator
extends Node2D


const ICON_SIZE: int = 6
const ICON_GAP: int = 2
const MAX_ICONS: int = 4

var _icon_sprites: Array[Sprite2D] = []
var _icon_cache: Dictionary = {}  # path -> Texture2D


func update_icons(active_effects: Array) -> void:
	_clear_icons()

	if active_effects.is_empty():
		visible = false
		return

	visible = true
	var configs := StatusEffectData.get_default_configs()
	var icon_count := mini(active_effects.size(), MAX_ICONS)
	var total_width := icon_count * ICON_SIZE + (icon_count - 1) * ICON_GAP
	var start_x := -total_width / 2.0 + ICON_SIZE / 2.0

	for i: int in range(icon_count):
		var effect: StatusEffect = active_effects[i]
		var config: StatusEffectData = configs.get(effect.effect_type_name, null)
		if config == null or config.icon_path == "":
			continue

		var texture := _load_icon(config.icon_path)
		if texture == null:
			continue

		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position.x = start_x + i * (ICON_SIZE + ICON_GAP)
		add_child(sprite)
		_icon_sprites.append(sprite)


func _clear_icons() -> void:
	for sprite: Sprite2D in _icon_sprites:
		sprite.queue_free()
	_icon_sprites.clear()


func _load_icon(path: String) -> Texture2D:
	if _icon_cache.has(path):
		return _icon_cache[path]
	var texture := load(path) as Texture2D
	if texture != null:
		_icon_cache[path] = texture
	return texture

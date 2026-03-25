## Displays a row of status effect icons below a unit's health bar.
## Up to 4 icons, 6x6 each with 2px gaps, centered on the unit.
class_name StatusEffectIndicator
extends Node2D


const ICON_SIZE: int = 6
const ICON_GAP: int = 2
const MAX_ICONS: int = 4
const MAX_TURNS: int = 4
const PIP_BAR_WIDTH: int = 4  # 4 pips at 1px each
const PIP_BAR_Y_OFFSET: int = 4  # 1px below the bottom edge of the 6x6 icon

var _icon_sprites: Array[Sprite2D] = []
var _pip_bars: Array[Node2D] = []
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

		var icon_x: float = start_x + i * (ICON_SIZE + ICON_GAP)

		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position.x = icon_x
		add_child(sprite)
		_icon_sprites.append(sprite)

		# Turn pip bar below the icon
		var pip_bar := _create_pip_bar(effect.remaining_turns, config.duration)
		pip_bar.position = Vector2(icon_x - PIP_BAR_WIDTH / 2.0, PIP_BAR_Y_OFFSET)
		add_child(pip_bar)
		_pip_bars.append(pip_bar)


func _create_pip_bar(remaining_turns: int, max_duration: int) -> Node2D:
	var bar := Node2D.new()
	var pip_count: int = clampi(max_duration, 1, MAX_TURNS)
	var filled: int = clampi(remaining_turns, 0, pip_count)

	for j: int in range(pip_count):
		var pip := ColorRect.new()
		pip.size = Vector2(1, 1)
		pip.position = Vector2(j, 0)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if j < filled:
			pip.color = Color(1.0, 1.0, 1.0, 0.9)
		else:
			pip.color = Color(0.3, 0.3, 0.3, 0.6)
		bar.add_child(pip)
	return bar


func _clear_icons() -> void:
	for sprite: Sprite2D in _icon_sprites:
		sprite.queue_free()
	_icon_sprites.clear()
	for bar: Node2D in _pip_bars:
		bar.queue_free()
	_pip_bars.clear()


func _load_icon(path: String) -> Texture2D:
	if _icon_cache.has(path):
		return _icon_cache[path]
	var texture := load(path) as Texture2D
	if texture != null:
		_icon_cache[path] = texture
	return texture

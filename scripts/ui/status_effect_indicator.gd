## Displays the unit's active buff and debuff icons above its health bar.
## Two slots: buff on the left, debuff on the right (each is 6x6 with a 2px gap).
## Pip bars sit inline with the top pixel of the health bar.
class_name StatusEffectIndicator
extends Node2D


const ICON_SIZE: int = 6
const ICON_GAP: int = 2
const MAX_SLOTS: int = 2  # 1 buff + 1 debuff
const MAX_PIPS: int = 4
const PIP_BAR_WIDTH: int = 4  # 4 pips at 1px each
const PIP_BAR_Y_OFFSET: int = 4  # Icon center is at y=0; bottom edge at +3; 1px gap; pip bar starts at +4

var _icon_sprites: Array[Sprite2D] = []
# Parallel to _icon_sprites: which effect each drawn icon stands for, so
# pop_icon can find the one that just changed.
var _icon_effect_types: Array[String] = []
var _pip_bars: Array[Node2D] = []
# Scale pop on a freshly applied/restacked icon — "this one just changed."
const POP_SCALE: float = 1.6
const POP_SECONDS: float = 0.18
var _icon_cache: Dictionary = {}  # path -> Texture2D


func update_icons(active_effects: Array) -> void:
	_clear_icons()

	# Pick the first buff and the first debuff (slot model — usually only one each).
	var buff: StatusEffect = null
	var debuff: StatusEffect = null
	for entry: StatusEffect in active_effects:
		if entry.category == Enums.EffectCategory.BUFF and buff == null:
			buff = entry
		elif entry.category == Enums.EffectCategory.DEBUFF and debuff == null:
			debuff = entry
		if buff != null and debuff != null:
			break

	var slot_effects: Array[StatusEffect] = [buff, debuff]
	var visible_count: int = 0
	for entry: StatusEffect in slot_effects:
		if entry != null:
			visible_count += 1

	if visible_count == 0:
		visible = false
		return
	visible = true

	var configs := StatusEffectData.get_default_configs()
	var total_width := visible_count * ICON_SIZE + (visible_count - 1) * ICON_GAP
	var start_x := -total_width / 2.0 + ICON_SIZE / 2.0

	var draw_index: int = 0
	for effect: StatusEffect in slot_effects:
		if effect == null:
			continue
		var config: StatusEffectData = configs.get(effect.effect_type_name, null)
		if config == null or config.icon_path == "":
			draw_index += 1
			continue

		var texture := _load_icon(config.icon_path)
		if texture == null:
			draw_index += 1
			continue

		var icon_x: float = start_x + draw_index * (ICON_SIZE + ICON_GAP)

		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position.x = icon_x
		add_child(sprite)
		_icon_sprites.append(sprite)
		_icon_effect_types.append(effect.effect_type_name)

		# Stack pip bar below the icon
		var pip_bar := _create_pip_bar(effect.stacks, config.max_stacks)
		pip_bar.position = Vector2(icon_x - PIP_BAR_WIDTH / 2.0, PIP_BAR_Y_OFFSET)
		add_child(pip_bar)
		_pip_bars.append(pip_bar)
		draw_index += 1


func _create_pip_bar(current_stacks: int, max_stacks: int) -> Node2D:
	var bar := Node2D.new()
	var pip_count: int = clampi(max_stacks, 1, MAX_PIPS)
	var filled: int = clampi(current_stacks, 0, pip_count)

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


## Pop the icon for `effect_type_name` (RQD 2026-08-21, todo #2A): it snaps
## to POP_SCALE and eases back, so a status landing on a unit that already
## showed the icon still reads as an event — the pips alone are one pixel.
## No-op under reduce-motion, or when the effect isn't in a drawn slot.
func pop_icon(effect_type_name: String) -> void:
	var index: int = _icon_effect_types.find(effect_type_name)
	if index < 0 or index >= _icon_sprites.size():
		return
	var sprite: Sprite2D = _icon_sprites[index]
	if Settings != null and not Settings.ui_motion_enabled:
		return
	sprite.scale = Vector2(POP_SCALE, POP_SCALE)
	if not is_inside_tree():
		sprite.scale = Vector2.ONE
		return
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2.ONE, POP_SECONDS).set_ease(Tween.EASE_OUT)


func _clear_icons() -> void:
	for sprite: Sprite2D in _icon_sprites:
		sprite.queue_free()
	_icon_sprites.clear()
	_icon_effect_types.clear()
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

## Animated phase transition banner with parallax star field.
## Text slides in from left, decelerates to center, holds, then accelerates off right.
## Star layers scroll in parallax, speed tracking text velocity.
class_name PhaseTransitionOverlay
extends Control

const BANNER_TEXTURE: CompressedTexture2D = preload("res://art/sprites/ui/turn_transition_overlay_stars/banner.png")
const STAR1_TEXTURE: CompressedTexture2D = preload("res://art/sprites/ui/turn_transition_overlay_stars/star1.png")
const STAR2_TEXTURE: CompressedTexture2D = preload("res://art/sprites/ui/turn_transition_overlay_stars/star2.png")
const STAR3_TEXTURE: CompressedTexture2D = preload("res://art/sprites/ui/turn_transition_overlay_stars/star3.png")
const GLOW_MATERIAL: ShaderMaterial = preload("res://resources/hud_glow.tres")

## Width of the star textures in pixels.
const TEXTURE_WIDTH: int = 640

## Banner height in pixels (matches the exported asset).
const BANNER_HEIGHT: int = 64
## Vertical center of the banner within the 360px viewport.
const BANNER_Y: int = (360 - BANNER_HEIGHT) / 2  # 148

## Per-layer scroll speeds in pixels/second at full speed (_speed_factor = 1.0).
## At half speed (_speed_factor = 0.5), each layer runs at half these values.
## star1(bright)=360, star2(mid)=240, star3(dim)=120 → at 60fps: 6/4/2 fast, 3/2/1 slow.
const STAR_FAST_SPEEDS: Array[float] = [360.0, 240.0, 120.0]

## Timing (seconds).
const FADE_IN_DURATION: float = 0.45
const SLIDE_IN_DURATION: float = 1.35
const HOLD_DURATION: float = 1.8
const SLIDE_OUT_DURATION: float = 1.05
const FADE_OUT_DURATION: float = 0.45

## How far offscreen the text starts/ends (pixels).
const TEXT_OFFSCREEN: float = 700.0

var _banner: TextureRect = null
## Each star layer has two TextureRects placed side by side for seamless wrap.
var _star_pairs: Array[Array] = []
var _phase_label: Label = null
var _scroll_offsets: Array[float] = [0.0, 0.0, 0.0]
## 1.0 = full speed, 0.5 = slow (hold). Tweened by the animation sequence.
var _speed_factor: float = 1.0
var _is_animating: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_content()


func _process(delta: float) -> void:
	if not _is_animating:
		return
	# Advance each star layer's scroll offset and position both copies.
	for i: int in range(_star_pairs.size()):
		_scroll_offsets[i] += STAR_FAST_SPEEDS[i] * _speed_factor * delta
		# Wrap offset to stay within one texture width.
		_scroll_offsets[i] = fmod(_scroll_offsets[i], float(TEXTURE_WIDTH))
		# Snap to whole pixels so single-pixel stars don't vanish.
		var snapped_offset: float = floorf(_scroll_offsets[i])
		var pair: Array = _star_pairs[i]
		(pair[0] as TextureRect).position.x = -snapped_offset
		(pair[1] as TextureRect).position.x = -snapped_offset + TEXTURE_WIDTH


# =============================================================================
# PUBLIC API
# =============================================================================

## Show the phase transition banner. Async — caller must await.
## color is the faction color (GameColors.PLAYER_UNIT / ENEMY_UNIT).
func show_transition(text: String, color: Color) -> void:
	var colors: Dictionary = _get_phase_colors(color)
	_phase_label.text = text
	_phase_label.add_theme_color_override("font_color", colors.text)

	# Set glow color on label material.
	if _phase_label.material and _phase_label.material is ShaderMaterial:
		(_phase_label.material as ShaderMaterial).set_shader_parameter("glow_color", colors.glow)

	# Tint star layers to faction accent color (subtle).
	var star_tint: Color = Color(1.0, 1.0, 1.0, 1.0).lerp(colors.accent, 0.4)
	for pair: Array in _star_pairs:
		for star_rect: TextureRect in pair:
			star_rect.modulate = star_tint

	# Reset state.
	_scroll_offsets = [0.0, 0.0, 0.0]
	_speed_factor = 1.0
	_is_animating = true
	visible = true
	modulate.a = 0.0

	# Position text offscreen left.
	_phase_label.position.x = -TEXT_OFFSCREEN

	# -- Animation sequence --
	var tween := create_tween()
	tween.set_parallel(false)

	# 1. Fade in the whole overlay.
	tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION)

	# 2. Slide text from left to center with deceleration.
	#    Simultaneously ramp star speed from 1.0 (fast) to 0.5 (slow).
	tween.set_parallel(true)
	tween.tween_property(_phase_label, "position:x", 0.0, SLIDE_IN_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tween.tween_property(self, "_speed_factor", 0.5, SLIDE_IN_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tween.set_parallel(false)

	# 3. Hold at center (slow-drifting stars, text stationary).
	tween.tween_interval(HOLD_DURATION)

	# 4. Slide text off to the right with acceleration.
	#    Simultaneously ramp star speed from 0.5 back to 1.0.
	tween.set_parallel(true)
	tween.tween_property(_phase_label, "position:x", TEXT_OFFSCREEN, SLIDE_OUT_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	tween.tween_property(self, "_speed_factor", 1.0, SLIDE_OUT_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	tween.set_parallel(false)

	# 5. Fade out.
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION)

	await tween.finished
	_is_animating = false
	visible = false


# =============================================================================
# BUILD CONTENT
# =============================================================================

func _build_content() -> void:
	var ui_manager: Node = get_node_or_null("/root/UIManager")

	# Clip container — limits visible area to the banner strip.
	var clip_container := Control.new()
	clip_container.position = Vector2(0, BANNER_Y)
	clip_container.size = Vector2(640, BANNER_HEIGHT)
	clip_container.clip_contents = true
	clip_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip_container)

	# Banner background.
	_banner = TextureRect.new()
	_banner.texture = BANNER_TEXTURE
	_banner.position = Vector2.ZERO
	_banner.size = Vector2(640, BANNER_HEIGHT)
	_banner.stretch_mode = TextureRect.STRETCH_KEEP
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_container.add_child(_banner)

	# Star layers (back to front: star1 = farthest, star3 = nearest).
	# Each layer gets two TextureRects side by side for seamless pixel-snapped wrap.
	var star_textures: Array[CompressedTexture2D] = [STAR1_TEXTURE, STAR2_TEXTURE, STAR3_TEXTURE]
	for i: int in range(star_textures.size()):
		var pair: Array = []
		for copy_index: int in range(2):
			var star_rect := TextureRect.new()
			star_rect.texture = star_textures[i]
			star_rect.position = Vector2(copy_index * TEXTURE_WIDTH, 0)
			star_rect.size = Vector2(TEXTURE_WIDTH, BANNER_HEIGHT)
			star_rect.stretch_mode = TextureRect.STRETCH_KEEP
			star_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			clip_container.add_child(star_rect)
			pair.append(star_rect)
		_star_pairs.append(pair)

	# Phase text label — centered vertically in the banner.
	_phase_label = Label.new()
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phase_label.position = Vector2(0, 0)
	_phase_label.size = Vector2(640, BANNER_HEIGHT)
	if ui_manager != null:
		_phase_label.add_theme_font_override("font", ui_manager.font_11px)
		_phase_label.add_theme_font_size_override("font_size", 48)
	_phase_label.add_theme_color_override("font_color", Color.WHITE)
	_phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_label.uppercase = true
	# Apply glow material with double glow for thicker outline at this size.
	var label_material: ShaderMaterial = GLOW_MATERIAL.duplicate()
	label_material.set_shader_parameter("double_glow", true)
	_phase_label.material = label_material
	clip_container.add_child(_phase_label)


## Resolve faction color into a text/accent/glow trio for the phase banner.
func _get_phase_colors(faction_color: Color) -> Dictionary:
	if faction_color == GameColors.PLAYER_UNIT:
		return { text = GameColors.PHASE_PLAYER_TEXT, accent = GameColors.PHASE_PLAYER_ACCENT, glow = GameColors.PHASE_PLAYER_GLOW }
	elif faction_color == GameColors.ENEMY_UNIT:
		return { text = GameColors.PHASE_ENEMY_TEXT, accent = GameColors.PHASE_ENEMY_ACCENT, glow = GameColors.PHASE_ENEMY_GLOW }
	elif faction_color == GameColors.ALLY_UNIT:
		return { text = GameColors.PHASE_ALLY_TEXT, accent = GameColors.PHASE_ALLY_ACCENT, glow = GameColors.PHASE_ALLY_GLOW }
	elif faction_color == GameColors.NEUTRAL_UNIT:
		return { text = GameColors.PHASE_NEUTRAL_TEXT, accent = GameColors.PHASE_NEUTRAL_ACCENT, glow = GameColors.PHASE_NEUTRAL_GLOW }
	# Fallback — use the raw color.
	return { text = faction_color, accent = faction_color, glow = Color.BLACK }

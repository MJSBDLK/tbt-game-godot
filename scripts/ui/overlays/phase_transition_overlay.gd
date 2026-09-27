## Animated phase transition banner with parallax star field.
## Text slides in from left, decelerates to center, holds, then accelerates off right.
## Star layers scroll in parallax, speed tracking text velocity. Their speeds
## are designed at 60 fps and refitted to each display's refresh rate so every
## layer steps evenly there (see even_layer_steps).
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

## Per-layer scroll at full speed, in pixels per 60 fps frame (star1 bright,
## star2 mid, star3 dim), fastest first. The hold runs at HOLD_SPEED_FACTOR.
const STAR_PIXELS_PER_FRAME: Array[float] = [6.0, 4.0, 2.0]
const HOLD_SPEED_FACTOR: float = 0.5

## Lifts thirds that sum to 0.9999… onto the pixel they add up to.
const PIXEL_SNAP_TOLERANCE: float = 0.000001
## A frame within this fraction of a whole number of refreshes counts as
## exactly that many; see _process.
const REFRESH_SNAP: float = 0.05

## Timing (seconds).
const FADE_IN_DURATION: float = 0.2
const SLIDE_IN_DURATION: float = 0.8
const HOLD_DURATION: float = 1.0
const SLIDE_OUT_DURATION: float = 0.8
const FADE_OUT_DURATION: float = 0.2

## How far offscreen the text starts/ends (pixels).
const TEXT_OFFSCREEN: float = 700.0

var _banner: TextureRect = null
## Each star layer has two TextureRects placed side by side for seamless wrap.
var _star_pairs: Array[Array] = []
var _phase_label: Label = null
var _scroll_offsets: Array[float] = [0.0, 0.0, 0.0]
## Pixels per refresh for each layer at full speed and at hold speed, fitted to
## _refresh_rate by _start_scroll.
var _full_speed_steps: Array[float] = []
var _hold_steps: Array[float] = []
var _refresh_rate: float = 60.0
## Refreshes that have elapsed but haven't been scrolled yet.
var _refresh_clock: float = 0.0
## 0 = full speed, 1 = hold speed. Tweened by the animation sequence.
var _hold_blend: float = 0.0
var _is_animating: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_content()


func _process(delta: float) -> void:
	if not _is_animating:
		return
	# Count whole refreshes, not delta × speed: flooring accumulated px/s turns
	# delta's wobble into 1-px hitches. A vsync'd frame is a whole number of
	# refreshes even when the reported rate is a hair off, so snap it there;
	# other frames (vsync off, variable refresh) keep the exact remainder.
	var elapsed_refreshes: float = delta * _refresh_rate
	var nearest_refreshes: int = roundi(elapsed_refreshes)
	if nearest_refreshes >= 1 and absf(elapsed_refreshes - nearest_refreshes) < REFRESH_SNAP:
		elapsed_refreshes = nearest_refreshes
	_refresh_clock += elapsed_refreshes
	var refreshes: int = roundi(_refresh_clock)
	_refresh_clock -= refreshes
	# Advance each star layer's scroll offset and position both copies.
	for i: int in range(_star_pairs.size()):
		var step: float = lerpf(_full_speed_steps[i], _hold_steps[i], _hold_blend)
		# Wrap offset to stay within one texture width.
		_scroll_offsets[i] = fmod(_scroll_offsets[i] + step * refreshes, float(TEXTURE_WIDTH))
		# Snap to whole pixels so single-pixel stars don't vanish.
		var snapped_offset: float = floorf(_scroll_offsets[i] + PIXEL_SNAP_TOLERANCE)
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
	_start_scroll(effective_refresh_rate())
	_is_animating = true
	visible = true
	modulate.a = 0.0

	# Pick up the current HUDViewport dimensions (handles window resize and
	# different-resolution starts).
	_sync_layout_to_hud()

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
	tween.tween_property(self, "_hold_blend", 1.0, SLIDE_IN_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tween.set_parallel(false)

	# 3. Hold at center (slow-drifting stars, text stationary).
	tween.tween_interval(HOLD_DURATION)

	# 4. Slide text off to the right with acceleration.
	#    Simultaneously ramp star speed from 0.5 back to 1.0.
	tween.set_parallel(true)
	tween.tween_property(_phase_label, "position:x", TEXT_OFFSCREEN, SLIDE_OUT_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	tween.tween_property(self, "_hold_blend", 0.0, SLIDE_OUT_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	tween.set_parallel(false)

	# 5. Fade out.
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION)

	await tween.finished
	_is_animating = false
	visible = false


# =============================================================================
# EVEN STEPS
# =============================================================================

func _start_scroll(refresh_rate: float) -> void:
	assert(refresh_rate > 0.0, "a star scroll needs a refresh rate to step on")
	_refresh_rate = refresh_rate
	_full_speed_steps = even_layer_steps(STAR_PIXELS_PER_FRAME, 1.0, refresh_rate)
	_hold_steps = even_layer_steps(STAR_PIXELS_PER_FRAME, HOLD_SPEED_FACTOR, refresh_rate)
	_scroll_offsets = [0.0, 0.0, 0.0]
	_refresh_clock = 0.0
	_hold_blend = 0.0


## The rate frames reach the screen at: the monitor's refresh, or the FPS cap
## when that's lower. 60 when the platform can't say (headless, some drivers).
static func effective_refresh_rate() -> float:
	var refresh_rate: float = DisplayServer.screen_get_refresh_rate()
	if refresh_rate <= 0.0:
		refresh_rate = 60.0
	if Engine.max_fps > 0 and Engine.max_fps < refresh_rate:
		refresh_rate = Engine.max_fps
	return refresh_rate


## Each layer's scroll in pixels per refresh at `refresh_rate`, as close to
## `pixels_per_frame` × `speed_factor` at 60 fps as even steps allow. The layers
## are fitted together: picking each alone can squeeze the slower ones (75 Hz
## would hold at 2, 1, 0.5 where 3, 2, 1 keeps the parallax), and every layer
## stays slower than the one before so two never scroll as one.
static func even_layer_steps(pixels_per_frame: Array[float], speed_factor: float,
		refresh_rate: float) -> Array[float]:
	var targets: Array[float] = []
	var options: Array[Array] = []
	var combination_count: int = 1
	for pixels: float in pixels_per_frame:
		var target: float = pixels * speed_factor * 60.0 / refresh_rate
		targets.append(target)
		options.append(even_steps_near(target, refresh_rate))
		combination_count *= options[-1].size()
	# A handful of options per layer, so every combination is cheap to try.
	var best: Array[float] = []
	var best_error: float = INF
	for combination: int in range(combination_count):
		var steps: Array[float] = []
		var error: float = 0.0
		var remaining: int = combination
		for layer: int in range(targets.size()):
			var step: float = options[layer][remaining % options[layer].size()]
			@warning_ignore("integer_division")
			remaining /= options[layer].size()
			if layer > 0 and step >= steps[-1]:
				break
			steps.append(step)
			error += pow(log(step / targets[layer]), 2.0)
		if steps.size() == targets.size() and error < best_error:
			best = steps
			best_error = error
	assert(best.size() == targets.size(), "no fastest-first even steps at %s Hz" % refresh_rate)
	return best


## The steps within 2× of `target` pixels per refresh that scroll evenly at
## `refresh_rate`. Whole pixels every refresh, or one pixel every k refreshes,
## are always even. Any other fraction alternates (1.5 px goes 1, 2, 1, 2) and
## only passes when the pattern repeats within a 60 fps frame: no coarser than
## the 60 Hz screen the speeds were designed on.
static func even_steps_near(target: float, refresh_rate: float) -> Array[float]:
	assert(target > 0.0, "a layer that doesn't move has no even step")
	# The 0.05 lets 119.88 Hz count as 120.
	var max_denominator: int = maxi(1, floori(refresh_rate / 60.0 + 0.05))
	var candidates: Array[float] = []
	for denominator: int in range(1, max_denominator + 1):
		for numerator: int in range(1, ceili(target * 2.0 * denominator) + 1):
			candidates.append(float(numerator) / denominator)
	for every: int in range(2, 17):
		candidates.append(1.0 / every)
	var steps: Array[float] = []
	for candidate: float in candidates:
		if absf(log(candidate / target)) <= log(2.0) and not steps.has(candidate):
			steps.append(candidate)
	return steps


# =============================================================================
# BUILD CONTENT
# =============================================================================

var _clip_container: Control = null


func _build_content() -> void:
	var ui_manager: Node = UIManager

	# Clip container — full-width strip vertically centered. Size is updated
	# from HUDViewport on every show_transition() so it adapts to window
	# resizes / different monitors without depending on anchor-resolution
	# timing inside a CanvasLayer.
	_clip_container = Control.new()
	_clip_container.clip_contents = true
	_clip_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip_container)

	# Banner background — sized to clip container, tiled horizontally so it
	# fills wider HUDs without leaving gaps (the source texture is 640 wide).
	_banner = TextureRect.new()
	_banner.texture = BANNER_TEXTURE
	_banner.position = Vector2.ZERO
	_banner.stretch_mode = TextureRect.STRETCH_TILE
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip_container.add_child(_banner)

	# Star layers (back to front: star1 = farthest, star3 = nearest).
	# Each layer gets two TextureRects side by side for seamless pixel-snapped wrap.
	# Two tiles cover any HUD width up to 2 × TEXTURE_WIDTH (1280). Beyond that
	# (super-ultrawide), the rightmost portion would show banner without stars
	# — a polish edge case, not a blocker.
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
			_clip_container.add_child(star_rect)
			pair.append(star_rect)
		_star_pairs.append(pair)

	# Phase text label — position.x is tween-driven (slides offscreen left →
	# center → offscreen right). Size is set explicitly to span the banner
	# width so horizontal_alignment=CENTER produces a centered word.
	_phase_label = Label.new()
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phase_label.position = Vector2.ZERO
	if ui_manager != null:
		_phase_label.add_theme_font_override("font", ui_manager.font_11px)
		_phase_label.add_theme_font_size_override("font_size", 48)
	_phase_label.add_theme_color_override("font_color", Color.WHITE)
	_phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_label.uppercase = true
	var label_material: ShaderMaterial = GLOW_MATERIAL.duplicate()
	label_material.set_shader_parameter("double_glow", true)
	_phase_label.material = label_material
	_clip_container.add_child(_phase_label)


## Recomputes clip container / banner / label sizes from the current HUDViewport.
## Called at every show_transition() to pick up window resizes.
func _sync_layout_to_hud() -> void:
	var hud: SubViewport = SceneRouter.get_hud_viewport()
	if hud == null:
		return
	var w: float = hud.size.x
	var h: float = hud.size.y
	if _clip_container != null:
		_clip_container.position = Vector2(0, (h - BANNER_HEIGHT) / 2.0)
		_clip_container.size = Vector2(w, BANNER_HEIGHT)
	if _banner != null:
		_banner.size = Vector2(w, BANNER_HEIGHT)
	if _phase_label != null:
		_phase_label.size = Vector2(w, BANNER_HEIGHT)


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

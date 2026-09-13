## CombatPuppet — a unit's stand-in on the combat scene stage. Plays the
## same strips the map unit would (ClipPlayer, one per sprite), stands on
## the same pivot (SpriteSidecar), casts the same generated shadow
## (UnitShadow), and flashes on impact with the same numbers as the map's
## hit flash — but with a tween it owns, so a quick unmount never leaves a
## dangling capture.
##
## Facing (plan D2): clips are authored LEFT-facing. The puppet on the LEFT
## of the stage is `mirrored` and flips EVERYTHING it plays, idle included,
## so there is no facing pop between idle and swing; the right-side puppet
## flips nothing. No per-clip facing data exists, by decision.
##
## Procedural beats (the PROCEDURAL terminal of the resolver): lunge /
## return (the map's boop, scaled), dodge hop, stepped death fade. All honour
## `instant` (skip) and reduce-motion.
class_name CombatPuppet
extends Node2D


const LUNGE_PX: float = 8.0  # Same reach as the map boop, in art pixels
const LUNGE_OUT_SECONDS: float = 0.08
const LUNGE_RETURN_SECONDS: float = 0.12
const DODGE_HOP_PX: float = 6.0
const DODGE_SECONDS: float = 0.12
const DEATH_STEPS: int = 4
const DEATH_SECONDS: float = 0.5

var unit: Node2D = null
var character: CharacterData = null
## True for the left-side puppet: every frame it shows is flip_h.
var mirrored: bool = false
## Centre x inside the core (design px); the scene sets it from the map
## distance (CombatScene.puppet_x) and moves it on a shove (respace).
var stage_x: float = 0.0
var sprite: Sprite2D = null
var shadow: UnitShadow = null
var clip_player: ClipPlayer = null

## Pixels the visual feet hang below the origin (art px, unscaled) — the
## stage places the puppet so its feet meet the ground line.
var feet_drop: float = 0.0
## Top of the opaque art relative to the sprite's canvas top (art px).
var art_top: float = 0.0
## True while the sprite is displaced by a lunge (so release knows).
var _lunged: bool = false
var _idle_texture: Texture2D = null
var _idle_offset: Vector2 = Vector2.ZERO


func _init() -> void:
	sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	shadow = UnitShadow.new()
	shadow.name = "CastShadow"
	shadow.source_sprite = sprite
	add_child(shadow)
	clip_player = ClipPlayer.new(sprite, _restore_idle)


## Bind to a live unit. `mirror` = stands on the left. The puppet loads the
## unit's idle the way the unit did (atlas-less PNG + sidecar, or atlas
## frame) so it stands on the same pivot.
func setup(source_unit: Node2D, mirror: bool, puppet_scale: int) -> void:
	unit = source_unit
	character = source_unit.get("character_data")
	mirrored = mirror
	scale = Vector2(puppet_scale, puppet_scale)
	_load_idle()
	if character != null and character.shadow_blob_radius >= 0.0:
		shadow.blob_radius = character.shadow_blob_radius
	elif sprite.texture != null:
		shadow.blob_radius = UnitShadow.measure_stance_radius(sprite.texture)
	shadow.feet_drop = feet_drop


func _load_idle() -> void:
	_idle_texture = null
	_idle_offset = Vector2.ZERO
	feet_drop = 0.0
	art_top = 0.0
	if character == null or character.sprite_sheet_path == "":
		_restore_idle()
		return
	if character.sprite_atlas_path == "":
		var raw: Texture2D = load(character.sprite_sheet_path) as Texture2D
		if raw != null:
			var sidecar: Dictionary = SpriteSidecar.read(character.sprite_sheet_path, raw)
			_idle_texture = raw
			_idle_offset = sidecar["offset"]
			art_top = sidecar["art_top"]
			feet_drop = sidecar["feet_drop"]
	else:
		var frame: AtlasTexture = SpriteAtlasLoader.get_frame_texture(
				character.sprite_sheet_path, character.sprite_atlas_path,
				character.sprite_frame_index)
		if frame != null:
			var trim_offset: Vector2 = SpriteAtlasLoader.get_frame_offset(
					character.sprite_atlas_path, character.sprite_frame_index)
			_idle_texture = frame
			_idle_offset = trim_offset
			feet_drop = maxf(0.0, trim_offset.y + frame.get_height() / 2.0)
	_restore_idle()


## Idle frame back on the sprite — the ClipPlayer's restore callable and
## the end of every procedural beat.
func _restore_idle() -> void:
	sprite.region_enabled = false
	sprite.texture = _idle_texture
	sprite.offset = _idle_offset
	sprite.flip_h = mirrored
	sprite.position = Vector2.ZERO
	sprite.scale = Vector2.ONE
	_lunged = false


## The hit flash, owned by the puppet: the same numbers as
## VisualFeedbackManager.apply_hit_flash, but the tween is created on THIS
## node so it dies with the puppet when the scene unmounts mid-flash
## (a tween on the autoload would outlive its captured target and log a
## freed-capture error on every quick close).
func hit_flash(impact_weight: float, tint: Color = Color.TRANSPARENT) -> void:
	var flash_color: Color = GameColorPalette.get_color("Gray", 10) if tint.a <= 0.0 else tint
	sprite.modulate = flash_color * 3.0  # overbright for intensity
	if not is_inside_tree() or not _motion():
		sprite.modulate = Color.WHITE
		return
	var duration := lerpf(VisualFeedbackManager.HIT_FLASH_MIN_DURATION,
			VisualFeedbackManager.HIT_FLASH_MAX_DURATION, clampf(impact_weight, 0.0, 1.0))
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, duration).set_ease(Tween.EASE_OUT)


## +1 when the opponent is to the right (this puppet stands on the left).
func toward_opponent() -> int:
	return 1 if mirrored else -1


## Where popups float: above the art, in this node's parent coordinates.
func head_position() -> Vector2:
	var art_height: float = float(sprite.texture.get_height()) if sprite.texture != null else 32.0
	var top_local: float = sprite.offset.y - art_height / 2.0 + art_top
	return position + Vector2(0.0, top_local * scale.y - 6.0)


# =============================================================================
# BEATS
# =============================================================================

## Frames 0..hit_frame of `clip`. Returns false (nothing shown) when the clip
## is empty or its strip won't load — the caller lunges instead.
func strike_to_contact(clip: Dictionary, instant: bool) -> bool:
	if clip.is_empty() or not clip_player.begin(clip, mirrored):
		return false
	await clip_player.play_to_hit(instant)
	return true


## Tail of whatever the last contact was: the clip's remaining frames, or
## the lunge's return. Fire-and-forget.
func release(instant: bool) -> void:
	if clip_player.is_playing():
		await clip_player.play_after_hit(instant)
	elif _lunged:
		await _return_from_lunge(instant)


## The procedural approach: a short push toward the opponent.
func lunge(instant: bool) -> void:
	_lunged = true
	var offset := Vector2(LUNGE_PX * toward_opponent(), 0.0)
	if instant or not _motion() or not is_inside_tree():
		sprite.position = offset
		return
	var tween := create_tween()
	tween.tween_property(sprite, "position", offset, LUNGE_OUT_SECONDS).set_ease(Tween.EASE_OUT)
	await tween.finished


func _return_from_lunge(instant: bool) -> void:
	_lunged = false
	if instant or not _motion() or not is_inside_tree():
		sprite.position = Vector2.ZERO
		return
	var tween := create_tween()
	tween.tween_property(sprite, "position", Vector2.ZERO, LUNGE_RETURN_SECONDS).set_ease(Tween.EASE_IN)
	await tween.finished


## A miss: hop away from the opponent and back. Fire-and-forget.
func dodge_hop(instant: bool) -> void:
	if instant or not _motion() or not is_inside_tree():
		return
	var away := Vector2(-DODGE_HOP_PX * toward_opponent(), 0.0)
	var tween := create_tween()
	tween.tween_property(sprite, "position", away, DODGE_SECONDS).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position", Vector2.ZERO, DODGE_SECONDS).set_ease(Tween.EASE_IN)
	await tween.finished


## Stepped fade to nothing (the map's death fade, quantized). Awaitable.
func play_death(instant: bool) -> void:
	sprite.modulate = Color(0.4, 0.4, 0.4, 1.0)
	if instant or not _motion() or not is_inside_tree():
		modulate.a = 0.0
		return
	for step: int in range(1, DEATH_STEPS + 1):
		await get_tree().create_timer(DEATH_SECONDS / DEATH_STEPS).timeout
		modulate.a = 1.0 - float(step) / DEATH_STEPS


## Support flourish: a quick scale pulse. Awaitable.
func pulse(instant: bool) -> void:
	if instant or not _motion() or not is_inside_tree():
		return
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_IN)
	await tween.finished


static func _motion() -> bool:
	return Settings.ui_motion_enabled

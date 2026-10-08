## The map's hit flash: a struck unit's sprite flashes and eases back. The
## combat scene's puppets flash on the same clock (CombatPuppet.hit_flash).
class_name HitFlash
extends RefCounted


const MIN_DURATION: float = 0.08
const MAX_DURATION: float = 0.2


## How long a hit of this weight (0.0–1.0) flashes; heavier hits linger.
static func duration_for(impact_weight: float) -> float:
	return lerpf(MIN_DURATION, MAX_DURATION, clampf(impact_weight, 0.0, 1.0))


## Flash a unit's sprite white, duration scaled by impact weight (0.0–1.0).
## At the end, reapplies the unit's correct state look (acted/active) so the
## tween never overwrites state changes that happened mid-flash. A `tint` with
## alpha > 0 replaces the white — a Bellows-boosted fire hit flashes warm so
## the boost reads on the target too, not only in the attacker's callout.
## Returns the flash's tween, or null when there's no sprite to flash.
static func play(target: Node2D, impact_weight: float, tint: Color = Color.TRANSPARENT) -> Tween:
	if target == null:
		return null
	var sprite: Sprite2D = target.get_node_or_null("Sprite2D")
	if sprite == null:
		return null

	# Snap to palette white (or the tint), then ease back (the callback handles
	# final color)
	var flash_color := GameColorPalette.get_color("Gray", 10) if tint.a <= 0.0 else tint
	sprite.modulate = flash_color * 3.0  # Overbright for intensity
	# The acted desaturate would gray a tinted flash; the callback restores it.
	sprite.material = null
	# Bound to the sprite: a unit freed mid-flash (defeat, scene teardown,
	# tests) takes the tween with it, callback and all.
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "modulate", flash_color, duration_for(impact_weight)) \
			.set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		if target.has_method("_apply_acted_look") and not target.can_act:
			target._apply_acted_look()
		elif target.has_method("_apply_active_look"):
			target._apply_active_look()
	)
	return tween

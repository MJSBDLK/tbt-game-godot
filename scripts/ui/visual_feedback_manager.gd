## The map's hit flash: a struck unit's sprite flashes and eases back.
## Registered as Autoload "VisualFeedbackManager".
extends Node


const HIT_FLASH_MIN_DURATION: float = 0.08
const HIT_FLASH_MAX_DURATION: float = 0.2

## Flash a unit's sprite white, duration scaled by impact weight (0.0–1.0).
## At the end, reapplies the unit's correct state modulate (acted/active) so the
## tween never overwrites state changes that happened mid-flash. A `tint` with
## alpha > 0 replaces the white — a Bellows-boosted fire hit flashes warm so
## the boost reads on the target too, not only in the attacker's callout.
func apply_hit_flash(target: Node2D, impact_weight: float, tint: Color = Color.TRANSPARENT) -> void:
	if target == null:
		return
	var sprite: Sprite2D = target.get_node_or_null("Sprite2D")
	if sprite == null:
		return

	var duration := lerpf(HIT_FLASH_MIN_DURATION, HIT_FLASH_MAX_DURATION, impact_weight)

	# Snap to palette white (or the tint), then ease back (the callback handles
	# final color)
	var flash_color := GameColorPalette.get_color("Gray", 10) if tint.a <= 0.0 else tint
	sprite.modulate = flash_color * 3.0  # Overbright for intensity
	# The acted desaturate would gray a tinted flash; the callback restores it.
	sprite.material = null
	# Bound to the sprite, not this autoload: a unit freed mid-flash (defeat,
	# scene teardown, tests) takes the tween with it, callback and all.
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "modulate", flash_color, duration).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		if target.has_method("_apply_acted_look") and not target.can_act:
			target._apply_acted_look()
		elif target.has_method("_apply_active_look"):
			target._apply_active_look()
	)

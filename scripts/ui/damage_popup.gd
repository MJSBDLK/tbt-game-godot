## Floating damage number that pops up, rises, and fades out.
## Spawned by Unit._spawn_damage_popup() during combat.
class_name DamagePopup
extends Node2D


const LIFETIME: float = 1.2
const RISE_DISTANCE: float = 16.0
const POP_SCALE: float = 1.3
const POP_DURATION: float = 0.15

var _elapsed: float = 0.0
var _start_position: Vector2 = Vector2.ZERO
var _damage_label: Label = null
var _effectiveness_label: Label = null


func _ready() -> void:
	_damage_label = $DamageLabel as Label
	_effectiveness_label = $EffectivenessLabel as Label
	_start_position = position
	# Pop scale overshoot
	scale = Vector2(POP_SCALE, POP_SCALE)
	# Apply orthogonal glow shader as outline — Gray 1 @ 97.5% alpha
	var outline_color := Color(GameColorPalette.get_color("Gray", 1), 0.975)
	_apply_outline(_damage_label, outline_color)
	_apply_outline(_effectiveness_label, outline_color)


func initialize(damage: int, effectiveness_text: String, effectiveness_multiplier: float) -> void:
	if _damage_label != null:
		_damage_label.text = str(damage)
		_damage_label.modulate = _get_effectiveness_color(effectiveness_multiplier)

	if _effectiveness_label != null:
		if effectiveness_text != "":
			_effectiveness_label.text = effectiveness_text
			_effectiveness_label.modulate = _get_effectiveness_color(effectiveness_multiplier)
		else:
			_effectiveness_label.visible = false


func _process(delta: float) -> void:
	_elapsed += delta

	var progress := _elapsed / LIFETIME

	# Scale: pop down from overshoot to 1.0
	if _elapsed < POP_DURATION:
		var pop_progress := _elapsed / POP_DURATION
		var current_scale := lerpf(POP_SCALE, 1.0, pop_progress)
		scale = Vector2(current_scale, current_scale)
	else:
		scale = Vector2.ONE

	# Rise with ease-out
	var rise_progress := 1.0 - pow(1.0 - progress, 2.0)
	position = _start_position + Vector2(0, -RISE_DISTANCE * rise_progress)

	# Fade out at 65% lifetime
	if progress > 0.65:
		var fade_progress := (progress - 0.65) / 0.35
		modulate.a = 1.0 - fade_progress

	if _elapsed >= LIFETIME:
		queue_free()


func _get_effectiveness_color(multiplier: float) -> Color:
	if multiplier >= 4.0:
		return GameColors.MULTIPLIER_X4_LIGHT
	elif multiplier >= 2.0:
		return GameColors.MULTIPLIER_X2_LIGHT
	elif multiplier == 1.0:
		return GameColors.MULTIPLIER_X1_LIGHT
	elif multiplier >= 0.5:
		return GameColors.MULTIPLIER_HALF_LIGHT
	elif multiplier > 0.0:
		return GameColors.MULTIPLIER_QUARTER_LIGHT
	else:
		return GameColors.MULTIPLIER_X0_LIGHT


func _apply_outline(label: Label, color: Color) -> void:
	if label == null:
		return
	var material_instance: ShaderMaterial = preload("res://resources/hud_glow.tres").duplicate()
	material_instance.set_shader_parameter("glow_color", color)
	label.material = material_instance

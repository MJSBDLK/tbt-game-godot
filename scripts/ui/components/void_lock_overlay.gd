## Visual treatment for a VOID-locked move/passive chip — the programmatic port of
## Lawrence's void-lock mockup (art/sprites/ui/void_lock_effect.aseprite), whose
## three layers were: a grayscale copy, a ~50%-opacity shadow, and twinkling gold
## "void star" motes. We reproduce them as:
##   * desaturate  → move_chip_fill.gdshader's `lock_desaturate` on the chip body
##   * shadow      → this overlay's scrim (void_lock_overlay.gdshader)
##   * sparkles    → this overlay's animated motes
##
## Usage is via the static toggle — drop it onto any chip ColorRect that uses
## move_chip_fill (moves, passives, and statuses all do):
##     VoidLockOverlay.set_locked(chip, unit.is_passive_index_locked(i))
## It is idempotent and self-cleaning, so callers just push the current lock state
## every refresh. See .claude/todo.md "void FX shader / + desaturate + shadow @ 50%".
class_name VoidLockOverlay
extends ColorRect

const OVERLAY_SHADER: Shader = preload("res://resources/shaders/void_lock_overlay.gdshader")
const NODE_NAME: String = "VoidLockOverlay"


## Toggle the void-lock treatment on any chip/tablet Control. Idempotent — safe to
## call with the same value every refresh. Two layers, applied to whatever the
## widget supports:
##   * if the widget's material exposes `lock_desaturate` (move_chip_fill chips in
##     the preview panel + action menu) → grey the chip body via that uniform.
##   * always → the shadow scrim + gold motes overlay child, which works on ANY
##     Control (e.g. the detail panel's StyleBoxFlat PanelContainer tablets, which
##     have no chip shader to desaturate — they still read as locked from the
##     scrim + sparkles).
## The overlay is created once then shown/hidden — cheaper and race-free vs.
## add/free churn when a panel re-renders the same nodes for a new unit.
static func set_locked(chip: Control, locked: bool) -> void:
	if chip == null:
		return
	var mat := chip.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("lock_desaturate", 1.0 if locked else 0.0)

	var overlay: VoidLockOverlay = chip.get_node_or_null(NODE_NAME) as VoidLockOverlay
	if overlay == null:
		if not locked:
			return  # nothing to show and nothing to hide
		overlay = VoidLockOverlay.new()
		chip.add_child(overlay)
	overlay.visible = locked


func _init() -> void:
	name = NODE_NAME


func _ready() -> void:
	# Cover the chip exactly and stay out of the way of clicks/hover. Added last,
	# so it draws over the chip's label + icon (darkening them; motes on top).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = OVERLAY_SHADER
	material = mat
	_push_size()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_push_size()


## The scrim/mote shader works in chip-pixel space, so it needs the live size.
func _push_size() -> void:
	if material is ShaderMaterial:
		material.set_shader_parameter("rect_size", size)

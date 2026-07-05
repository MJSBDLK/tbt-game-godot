## Visual treatment for a VOID-locked move/passive chip — the programmatic port of
## Lawrence's void-lock mockup (art/sprites/ui/void_lock_effect.aseprite):
##   * desaturate  → move_chip_fill.gdshader's `lock_desaturate` on the chip body
##   * shadow      → this overlay's scrim (void_lock_overlay.gdshader)
##   * void energy → a VoidLockEffect child (smoke jets + bubbles + jagged star
##     sweeps) played over the chip's rect. This overlay is the single chokepoint all
##     three panels call, so hosting the effect here wires it into the preview panel,
##     detail panel, and action menu at once; it plays while the overlay is visible
##     (chip locked) and stops when hidden.
##
## Usage is via the static toggle — drop it onto any chip Control:
##     VoidLockOverlay.set_locked(chip, unit.is_passive_index_locked(i))
## It is idempotent and self-cleaning, so callers just push the current lock state
## every refresh. See .claude/todo.md "void FX shader / + desaturate + shadow @ 50%".
class_name VoidLockOverlay
extends ColorRect

const OVERLAY_SHADER: Shader = preload("res://resources/shaders/void_lock_overlay.gdshader")
const NODE_NAME: String = "VoidLockOverlay"

var _effect: VoidLockEffect = null
var _subdued: bool = false


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
## `subdued` = bubbles only (drop the smoke + star crackle) for tight surfaces like
## the action menu, where the full erupting effect would spill and overwhelm.
static func set_locked(chip: Control, locked: bool, subdued: bool = false) -> void:
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
		chip.add_child(overlay)   # runs _ready → creates the hosted effect
	overlay._apply_subdued(subdued)
	overlay.visible = locked


func _init() -> void:
	name = NODE_NAME


## Bubbles only vs. the full effect (see set_locked's `subdued`). Stored so it also
## takes effect when the hosted effect is created later (set_locked can run before
## this overlay's _ready — e.g. the action menu builds chips outside the tree).
func _apply_subdued(subdued: bool) -> void:
	_subdued = subdued
	_sync_subdued()


func _sync_subdued() -> void:
	if _effect == null:
		return
	_effect.emit_smoke = not _subdued
	_effect.emit_stars = not _subdued
	# bubbles stay on either way


func _ready() -> void:
	# Stay out of the way of clicks/hover. Added last, so it draws over the chip's
	# label + icon (darkening them; energy on top). We size ourselves to the chip
	# explicitly in _sync_effect rather than via full-rect anchors — those leave us
	# 0-height inside a plain ColorRect chip (and setting size fights the anchors).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = OVERLAY_SHADER
	material = mat
	# The animated void energy renders in this overlay's local space (reference px),
	# so it inherits the HUDViewport upscale like everything else.
	_effect = VoidLockEffect.new()
	add_child(_effect)
	_sync_subdued()   # apply subdued state set before this _ready ran
	# Drive off the CHIP's size, not our own: full-rect anchors size us to the chip,
	# but the chip's size often settles a frame or two AFTER we're added, and our own
	# RESIZED doesn't reliably fire for it. The chip's `resized` signal does.
	var chip := get_parent() as Control
	if chip != null and not chip.resized.is_connected(_sync_effect):
		chip.resized.connect(_sync_effect)
	_sync_effect()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_sync_effect()


## Shared material that greys + dims a Control's final pixels (icon texture OR label
## font color). Panels whose label/icon sit OUTSIDE the chip (so the scrim can't
## cover them — e.g. the action menu) apply this to those nodes on locked chips.
static var _icon_gray: ShaderMaterial

static func icon_gray_material() -> ShaderMaterial:
	if _icon_gray == null:
		_icon_gray = ShaderMaterial.new()
		_icon_gray.shader = load("res://resources/shaders/void_lock_grayscale.gdshader")
	return _icon_gray


## Size ourselves (and the scrim + effect) to the chip and play/stop with lock state.
## We set size explicitly rather than trusting full-rect anchors: in a plain
## ColorRect chip (preview panel, action menu) the anchors leave us 0-height, so the
## shadow scrim never renders. A Container chip (detail panel) sizes us itself; this
## just re-asserts the same rect, harmlessly.
func _sync_effect() -> void:
	if _effect == null:
		return
	var chip := get_parent() as Control
	var rect := chip.size if chip != null else size
	position = Vector2.ZERO
	size = rect
	if is_visible_in_tree() and rect.x > 0.0 and rect.y > 0.0:
		_effect.play(Rect2(Vector2.ZERO, rect))
	else:
		_effect.stop()

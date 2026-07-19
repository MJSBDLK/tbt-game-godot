## The press-for-why readout (ui-style-guide.md §14 "Disabled"): a styled
## tooltip floated just above the control that refused the press, saying WHY —
## "NO USES REMAINING", "SEALED BY VOID LOCK". Extracted from the F6 gallery's
## deny popup so the real action menu and the gallery share one recipe
## (game_theme TooltipPanel + GlowLabel, same family as TapTooltip).
##
## One deny on screen at a time: a new deny replaces the old. The popup
## parents to the refusing control, so a menu closing takes its deny with it.
class_name DenyTooltip
extends RefCounted


const GAME_THEME: Theme = preload("res://resources/game_theme.tres")
const FONT_8PX: FontFile = preload("res://fonts/UndeadPixelLight8.ttf")
const GLOW_MATERIAL: ShaderMaterial = preload("res://resources/hud_glow.tres")

const LINGER_SECONDS: float = 1.3

static var _active: PanelContainer = null


## Float `reason` just above `source`. Empty reasons fall back to a generic
## refusal so a press never dies silently.
static func show_above(source: Control, reason: String) -> void:
	if source == null or not source.is_inside_tree():
		return
	if _active != null and is_instance_valid(_active):
		_active.queue_free()
	if reason == "":
		reason = "NOT AVAILABLE"

	var popup := PanelContainer.new()
	popup.theme = GAME_THEME
	popup.theme_type_variation = "TooltipPanel"
	popup.top_level = true

	var label := GlowLabel.new()
	label.text = reason
	label.theme_type_variation = "TooltipLabel"
	label.add_theme_color_override("font_color", GameColors.TEXT_PRIMARY)
	label.material = GLOW_MATERIAL.duplicate()
	label.glow_color = GameColors.TEXT_PRIMARY_GLOW
	label.add_theme_font_override("font", FONT_8PX)
	label.add_theme_font_size_override("font_size", 8)
	popup.add_child(label)

	source.add_child(popup)
	_active = popup

	# Size lands a frame later; then center it above the refusing control.
	await source.get_tree().process_frame
	if not is_instance_valid(popup) or not is_instance_valid(source):
		return
	var rect := source.get_global_rect()
	popup.position = Vector2(
			rect.position.x + (rect.size.x - popup.size.x) / 2.0,
			rect.position.y - popup.size.y - 2.0)
	var timer := source.get_tree().create_timer(LINGER_SECONDS)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(popup):
			popup.queue_free())

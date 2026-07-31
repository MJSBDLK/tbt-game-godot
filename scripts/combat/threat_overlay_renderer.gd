## Swappable VIEW for the threat overlay. Consumes a danger map (Vector2i cell ->
## threat count, from ThreatCalculator) and paints it. THIS NODE IS THE
## PLACEHOLDER Lawrence replaces — all the art lives here, none of the logic. A
## re-skin only needs to touch _draw() (or replace the whole node); the controller
## talks to it through set_map() / clear() and nothing else.
##
## Renders on its OWN layer (a Node2D drawn over the floor) — deliberately NOT via
## Tile.set_color — so the danger zone coexists with the move/selection highlights
## and can be swapped wholesale. Everything visual is @export'd so layering and
## look can be tuned in the inspector without code.
class_name ThreatOverlayRenderer
extends Node2D


## Which zone is being painted — the army-wide sweep, individually-pinned
## enemies, or the move-range live-paint (a chip holding menu attention paints
## its reach — GridManager's preview instance uses the PREVIEW_* styles).
## Distinct palettes so the player can always tell which one they're looking
## at (design call 2026-07-06). The preview splits by the move's INTENT
## (RQD 2026-07-30, "the generally agreed upon color codes"): red = damaging,
## green = healing, blue = neither.
enum Style { ARMY, PINNED, PREVIEW_DAMAGE, PREVIEW_HEAL, PREVIEW_NEUTRAL }

# Army-wide zone: red. Pinned zones: amber — same "danger" family, clearly not
# the whole army. Preview palettes carry the move's intent: damaging = red
# (rosier than the army red so a pinned enemy zone and a hovered attack don't
# read identical), healing = green, neither = azure. All placeholder values
# for Lawrence's restyle.
@export var fill_color: Color = Color(0.85, 0.12, 0.12, 0.26)
@export var edge_color: Color = Color(0.95, 0.22, 0.22, 0.55)
@export var pinned_fill_color: Color = Color(1.0, 0.6, 0.08, 0.26)
@export var pinned_edge_color: Color = Color(1.0, 0.72, 0.18, 0.6)
@export var preview_damage_fill_color: Color = Color(0.92, 0.2, 0.28, 0.24)
@export var preview_damage_edge_color: Color = Color(1.0, 0.36, 0.44, 0.6)
@export var preview_heal_fill_color: Color = Color(0.16, 0.72, 0.34, 0.24)
@export var preview_heal_edge_color: Color = Color(0.3, 0.9, 0.5, 0.6)
@export var preview_neutral_fill_color: Color = Color(0.25, 0.62, 0.95, 0.24)
@export var preview_neutral_edge_color: Color = Color(0.42, 0.78, 1.0, 0.6)
@export var draw_edges: bool = true
## Ground-decal layer: above the floor, below units (unit sprites start at z 6).
## Exported so the danger tint vs the move-range highlight can be reordered freely.
@export var overlay_z_index: int = 1

# Projection-static trial (RQD/Lawrence 2026-07-30): the portraits' glass
# static, reformulated for tint decals, riding EVERY overlay style. SHARED
# material so Lawrence tunes once in the .tres and all instances follow.
const STATIC_MATERIAL: ShaderMaterial = preload("res://resources/overlay_static.tres")

# World-space centers of the threatened cells. We resolve tile -> position once at
# set_map() time (tiles don't move), so _draw stays a tight loop.
var _centers: PackedVector2Array = PackedVector2Array()
var _style: int = Style.ARMY


func _ready() -> void:
	z_index = overlay_z_index
	material = STATIC_MATERIAL
	_sync_static_motion()
	if Settings != null and not Settings.changed.is_connected(_sync_static_motion):
		Settings.changed.connect(_sync_static_motion)


## Reduce-motion contract: the static keeps its texture, loses its flicker —
## the shader freezes its time bucket when `animate` is 0.
func _sync_static_motion() -> void:
	var animate: bool = Settings == null or Settings.ui_motion_enabled
	STATIC_MATERIAL.set_shader_parameter("animate", 1.0 if animate else 0.0)


## Show this danger zone. `danger_map` is ThreatCalculator's output (Vector2i cell
## -> count); V1 paints a flat tint, so we keep only the cell centers. (Count is
## available for a future intensity ramp — deeper red where more enemies reach.)
## `style` picks the palette: ARMY for the whole-army sweep, PINNED for
## individually-pinned enemies.
func set_map(danger_map: Dictionary, style: int = Style.ARMY) -> void:
	_style = style
	_centers = PackedVector2Array()
	for cell: Vector2i in danger_map:
		var tile: Tile = GridManager.get_tile(cell.x, cell.y)
		if tile != null:
			_centers.append(tile.global_position)
	queue_redraw()


func clear() -> void:
	_centers = PackedVector2Array()
	queue_redraw()


func _draw() -> void:
	if _centers.is_empty():
		return
	var fill: Color = fill_color
	var edge: Color = edge_color
	match _style:
		Style.PINNED:
			fill = pinned_fill_color
			edge = pinned_edge_color
		Style.PREVIEW_DAMAGE:
			fill = preview_damage_fill_color
			edge = preview_damage_edge_color
		Style.PREVIEW_HEAL:
			fill = preview_heal_fill_color
			edge = preview_heal_edge_color
		Style.PREVIEW_NEUTRAL:
			fill = preview_neutral_fill_color
			edge = preview_neutral_edge_color
	var size: float = float(GridManager.tile_size)
	var half := Vector2(size, size) * 0.5
	for center: Vector2 in _centers:
		var rect := Rect2(to_local(center) - half, Vector2(size, size))
		draw_rect(rect, fill, true)
		if draw_edges:
			draw_rect(rect, edge, false, 1.0)

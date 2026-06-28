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


@export var fill_color: Color = Color(0.85, 0.12, 0.12, 0.26)
@export var edge_color: Color = Color(0.95, 0.22, 0.22, 0.55)
@export var draw_edges: bool = true
## Ground-decal layer: above the floor, below units (unit sprites start at z 6).
## Exported so the danger tint vs the move-range highlight can be reordered freely.
@export var overlay_z_index: int = 1

# World-space centers of the threatened cells. We resolve tile -> position once at
# set_map() time (tiles don't move), so _draw stays a tight loop.
var _centers: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	z_index = overlay_z_index


## Show this danger zone. `danger_map` is ThreatCalculator's output (Vector2i cell
## -> count); V1 paints a flat tint, so we keep only the cell centers. (Count is
## available for a future intensity ramp — deeper red where more enemies reach.)
func set_map(danger_map: Dictionary) -> void:
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
	var size: float = float(GridManager.tile_size)
	var half := Vector2(size, size) * 0.5
	for center: Vector2 in _centers:
		var rect := Rect2(to_local(center) - half, Vector2(size, size))
		draw_rect(rect, fill_color, true)
		if draw_edges:
			draw_rect(rect, edge_color, false, 1.0)

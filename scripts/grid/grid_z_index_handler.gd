## Manages z_index for grid-based objects using ZIndexCalculator.
## Attach to any Node2D that needs row-based sorting.
## For tiles, set layer and row_override during setup.
## For units, enable dynamic_updates so z_index follows movement.
class_name GridZIndexHandler
extends Node


@export var layer: ZIndexCalculator.ZIndexLayer = ZIndexCalculator.ZIndexLayer.FLOOR_TILES
@export var dynamic_updates: bool = false
@export var row_override: int = -1  # -1 = calculate from position
@export var layer_offset: int = 0

var _parent: Node2D = null
var _last_grid_position := Vector2i.ZERO
var _last_z_index: int = 0


func _ready() -> void:
	_parent = get_parent() as Node2D
	update_sorting_order()


func _process(_delta: float) -> void:
	if not dynamic_updates or _parent == null:
		return
	var current_grid_position := Vector2i(roundi(_parent.position.x), roundi(_parent.position.y))
	if current_grid_position != _last_grid_position:
		update_sorting_order()
		_last_grid_position = current_grid_position


func update_sorting_order() -> void:
	if _parent == null:
		return

	var row_y: int
	if row_override >= 0:
		row_y = row_override
	else:
		# Use GridManager bounds to convert world Y to row index
		var grid_manager: Node = get_node_or_null("/root/GridManager")
		if grid_manager != null:
			var world_y := roundi(_parent.position.y)
			var offset_y: int = grid_manager.grid_offset_y
			var height: int = grid_manager.grid_height
			# Bottom (low Y) = front row (low index)
			row_y = (offset_y + height - 1) - world_y
		else:
			row_y = roundi(_parent.position.y)

	var new_z_index := ZIndexCalculator.calculate_sorting_order(row_y, 100, layer) + layer_offset

	if new_z_index != _last_z_index:
		_parent.z_index = new_z_index
		_last_z_index = new_z_index
		DebugConfig.log_z_index("%s: row=%d, layer=%s, offset=%d -> z_index=%d" % [
			_parent.name, row_y, ZIndexCalculator.ZIndexLayer.keys()[layer], layer_offset, new_z_index])


func set_layer(new_layer: ZIndexCalculator.ZIndexLayer) -> void:
	layer = new_layer
	update_sorting_order()


func set_row_override(row: int) -> void:
	row_override = row
	update_sorting_order()


func set_dynamic_updates(enabled: bool) -> void:
	dynamic_updates = enabled


func set_layer_offset(offset: int) -> void:
	layer_offset = offset
	update_sorting_order()

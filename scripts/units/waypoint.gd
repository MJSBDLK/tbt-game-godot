## A planned movement stop with cumulative cost from the unit's start tile.
## GridManager reads waypoint.tile via .get("tile") — RefCounted vars support this.
class_name Waypoint
extends RefCounted


var tile: Tile = null
var movement_cost_to_reach: int = 0  # Cumulative cost, not segment cost


func _init(target_tile: Tile = null, cumulative_cost: int = 0) -> void:
	tile = target_tile
	movement_cost_to_reach = cumulative_cost

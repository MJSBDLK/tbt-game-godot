## A* pathfinding node wrapping a Tile reference.
## Used internally by GridManager for pathfinding calculations.
class_name PathNode


var tile: Node2D  # Tile reference
var parent: PathNode = null
var cost_from_start: int = 0
var estimated_cost_to_goal: int = 0

var total_path_score: int:
	get: return cost_from_start + estimated_cost_to_goal


func _init(target_tile: Node2D) -> void:
	tile = target_tile

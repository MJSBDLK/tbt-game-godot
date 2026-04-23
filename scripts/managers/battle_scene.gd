## Battle scene root script. Spawns units from SpawnTileLayer and kicks off the turn loop.
## Each map scene must have a TilemapGridBuilder with a painted SpawnTileLayer.
extends Node2D


@export var default_player_character: String = "res://data/characters/spaceman.json"
@export var default_enemy_character: String = "res://data/characters/grunt.json"

@export_group("Visuals")
@export var show_vignette: bool = true

## Random enemy pool. Each spawn picks from this list uniformly. Duplicates
## weight the odds (e.g. grunt appears twice → 2x chance). Placeholder until a
## per-map enemy composition system replaces this.
@export var enemy_spawn_pool: Array[String] = [
	"res://data/characters/grunt.json",
	"res://data/characters/grunt.json",
	"res://data/characters/napdawg.json",
	"res://data/characters/ogre.json",
	"res://data/characters/blood_mage.json",
]

var _unit_scene: PackedScene = preload("res://scenes/battle/unit.tscn")
var _vignette_shader: Shader = preload("res://shaders/vignette.gdshader")
var _units_container: Node2D = null


func _ready() -> void:
	_units_container = Node2D.new()
	_units_container.name = "Units"
	add_child(_units_container)

	if GridManager.is_grid_ready():
		_on_grid_ready()
	else:
		GridManager.grid_ready.connect(_on_grid_ready)


func _on_grid_ready() -> void:
	if show_vignette:
		_build_vignette()

	var spawn_points := _get_tile_spawn_points()
	var player_units := _spawn_units_from_tiles(spawn_points["Player"], Enums.UnitFaction.PLAYER, default_player_character)
	var enemy_units := _spawn_units_from_tiles(spawn_points["Enemy"], Enums.UnitFaction.ENEMY, default_enemy_character)

	if player_units.is_empty() and enemy_units.is_empty():
		push_warning("BattleScene: No spawn tiles found — paint Player/Enemy tiles on SpawnTileLayer")

	DebugConfig.log_unit_init("BattleScene: Spawned %d players + %d enemies from tile spawns" % [
		player_units.size(), enemy_units.size()])

	var turn_manager: Node = get_node_or_null("/root/TurnManager")
	if turn_manager != null:
		turn_manager.initialize_battle(player_units, enemy_units)
	else:
		push_warning("BattleScene: TurnManager not found — running without turn loop")


# =============================================================================
# TILE-BASED SPAWNING (SpawnTileLayer)
# =============================================================================

func _get_tile_spawn_points() -> Dictionary:
	var grid_builder := _find_grid_builder()
	if grid_builder == null:
		return {"Player": [], "Enemy": []}
	return grid_builder.get_spawn_points()


func _find_grid_builder() -> TilemapGridBuilder:
	for child: Node in get_children():
		if child is TilemapGridBuilder:
			return child as TilemapGridBuilder
	if get_parent() != null:
		for child: Node in get_parent().get_children():
			if child is TilemapGridBuilder:
				return child as TilemapGridBuilder
	return null


func _spawn_units_from_tiles(positions: Array, faction: Enums.UnitFaction, character_path: String) -> Array[Unit]:
	var units: Array[Unit] = []
	# For player units, walk the SquadManager roster instead of relying on the
	# default character_path (this lets the persistent roster determine who
	# spawns and how many slots are filled). For enemy units we still use the
	# tile spawn count + the per-faction default JSON path.
	if faction == Enums.UnitFaction.PLAYER:
		var roster: Array[CharacterData] = SquadManager.get_active_roster()
		var slot_count: int = mini(positions.size(), roster.size())
		for i: int in range(slot_count):
			var grid_pos := positions[i] as Vector2i
			var tile := GridManager.get_tile(grid_pos.x, grid_pos.y)
			if tile == null:
				push_warning("BattleScene: No tile at (%d, %d) for spawn" % [grid_pos.x, grid_pos.y])
				continue
			var unit := _create_unit_from_data(roster[i], faction, tile)
			if unit != null:
				units.append(unit)
		return units

	# Enemy spawns: pick a random JSON per tile from enemy_spawn_pool.
	# Falls back to character_path (default_enemy_character) if the pool is empty.
	for position: Variant in positions:
		var grid_pos := position as Vector2i
		var tile := GridManager.get_tile(grid_pos.x, grid_pos.y)
		if tile == null:
			push_warning("BattleScene: No tile at (%d, %d) for spawn" % [grid_pos.x, grid_pos.y])
			continue
		var json_path: String = character_path
		if not enemy_spawn_pool.is_empty():
			json_path = enemy_spawn_pool[randi() % enemy_spawn_pool.size()]
		var unit := _create_unit(json_path, faction, tile)
		if unit != null:
			units.append(unit)
	return units


# =============================================================================
# VIGNETTE
# =============================================================================

## Builds a world-space out-of-bounds fade around the map. The effect paints the
## territory outside the map rect: alpha ramps from 0 at the map edge to 1 over
## `fade_width` pixels, then stays fully opaque. Lawrence's long-term boundary
## treatment (impassable terrain, custom sprites, fog, decorations, sky) will
## layer on top of this.
func _build_vignette() -> void:
	var tile_size: int = GridManager.tile_size
	var origin_x: float = GridManager.grid_offset_x * tile_size
	var min_tilemap_y: int = -GridManager.grid_offset_y - GridManager.grid_height + 1
	var origin_y: float = min_tilemap_y * tile_size
	var map_min := Vector2(origin_x, origin_y)
	var map_size := Vector2(GridManager.grid_width * tile_size, GridManager.grid_height * tile_size)
	var map_max := map_min + map_size

	# Polygon must extend far enough past the map that the camera can never pan
	# its edge into view. 4096px of padding is effectively infinite at current
	# zoom levels.
	var pad := 4096.0
	var poly_min := map_min - Vector2(pad, pad)
	var poly_max := map_max + Vector2(pad, pad)

	# Live in the default world CanvasLayer so the vignette participates in the
	# same z_index ordering as tiles/units. z_index = 4 puts it above floor +
	# decoration tilemap layers (z=0 and z=3) but below every unit layer
	# (ZIndexLayer.UNITS = 5 and up). Tall unit sprites / HP bars / status
	# icons poking into OOB therefore render on top of the fade rather than
	# being darkened by it.
	var poly := Polygon2D.new()
	poly.name = "MapVignette"
	poly.polygon = PackedVector2Array([
		Vector2(poly_min.x, poly_min.y),
		Vector2(poly_max.x, poly_min.y),
		Vector2(poly_max.x, poly_max.y),
		Vector2(poly_min.x, poly_max.y),
	])
	poly.z_index = 4

	var mat := ShaderMaterial.new()
	mat.shader = _vignette_shader
	mat.set_shader_parameter("map_min", map_min)
	mat.set_shader_parameter("map_max", map_max)
	poly.material = mat
	add_child(poly)


# =============================================================================
# UNIT CREATION
# =============================================================================

## Spawn a unit from a JSON path. Used for enemies (and as a fallback for tests).
func _create_unit(json_path: String, faction: Enums.UnitFaction, tile: Tile,
		ai_behavior: Enums.AIBehaviorType = Enums.AIBehaviorType.AGGRESSIVE) -> Unit:
	var unit: Unit = _unit_scene.instantiate() as Unit
	unit.character_json_path = json_path
	unit.faction = faction
	_units_container.add_child(unit)
	unit.initialize(tile)
	unit.auto_assign_first_usable_move()

	if faction == Enums.UnitFaction.ENEMY:
		var enemy_ai := EnemyAI.new()
		enemy_ai.name = "EnemyAI"
		enemy_ai.behavior_type = ai_behavior
		unit.add_child(enemy_ai)

	return unit


## Spawn a unit from a pre-existing CharacterData (the SquadManager-persistent
## path used for player units). The CharacterData reference is shared with the
## roster so any mid-mission state mutations (XP gain, injury queue) persist.
func _create_unit_from_data(character_data: CharacterData, faction: Enums.UnitFaction, tile: Tile,
		ai_behavior: Enums.AIBehaviorType = Enums.AIBehaviorType.AGGRESSIVE) -> Unit:
	var unit: Unit = _unit_scene.instantiate() as Unit
	unit.character_data = character_data
	unit.faction = faction
	_units_container.add_child(unit)
	unit.initialize(tile)
	unit.auto_assign_first_usable_move()

	if faction == Enums.UnitFaction.ENEMY:
		var enemy_ai := EnemyAI.new()
		enemy_ai.name = "EnemyAI"
		enemy_ai.behavior_type = ai_behavior
		unit.add_child(enemy_ai)

	return unit

## Battle scene root script. Spawns units from SpawnTileLayer and kicks off the turn loop.
## Each map scene must have a TilemapGridBuilder with a painted SpawnTileLayer.
class_name BattleScene
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
	"res://data/characters/bandit.json",
	"res://data/characters/bandit.json",
	"res://data/characters/napdawg.json",
	"res://data/characters/ogre.json",
	"res://data/characters/berzerker.json",
	"res://data/characters/bugler_chivalric.json",
	"res://data/characters/bugler_gentry.json",
	"res://data/characters/flamethrower_phoenix.json",
	"res://data/characters/ice_archer.json",
	"res://data/characters/knight.json",
	"res://data/characters/pierre.json",
	"res://data/characters/plant_urchin.json",
	"res://data/characters/pyro.json",
	"res://data/characters/squash.json",
	"res://data/characters/thumps.json",
	"res://data/characters/traveller.json",
	"res://data/characters/keener.json",
]

var _unit_scene: PackedScene = preload("res://scenes/battle/unit.tscn")
var _vignette_shader: Shader = preload("res://shaders/vignette.gdshader")
var _units_container: Node2D = null
var _foot_track_renderer: FootTrackRenderer = null
var _threat_overlay: ThreatOverlayController = null


func _ready() -> void:
	_units_container = Node2D.new()
	_units_container.name = "Units"
	add_child(_units_container)

	# Foot-track overlay lives at the world root so its per-cell sprites sort by
	# the same row-based z as tiles/units. Units are registered after spawn.
	_foot_track_renderer = FootTrackRenderer.new()
	_foot_track_renderer.name = "FootTrackRenderer"
	add_child(_foot_track_renderer)

	# Threat overlay (enemy danger zone). Controller owns its swappable renderer;
	# lives at the world root so the renderer's tile-aligned draw matches tiles.
	_threat_overlay = ThreatOverlayController.new()
	_threat_overlay.name = "ThreatOverlayController"
	add_child(_threat_overlay)

	if GridManager.is_grid_ready():
		_on_grid_ready()
	else:
		GridManager.grid_ready.connect(_on_grid_ready)


func _exit_tree() -> void:
	# GridManager is an autoload — it outlives the battle scene. Without an
	# explicit clear, its internal _grid keeps refs to tiles that are about
	# to be freed; InputManager._process then polls those stale entries and
	# crashes on cast / freezes the engine.
	GridManager.clear_grid()


func _on_grid_ready() -> void:
	if show_vignette:
		_build_vignette()

	# A pending battle restore (SaveManager.load_save_and_continue stashed it)
	# rebuilds the saved board instead of rolling fresh spawns.
	var battle_restore: Dictionary = SaveManager.take_pending_battle_restore()
	if not battle_restore.is_empty():
		_resume_from_snapshot(battle_restore)
		return

	_spawn_fresh_battle()


## The normal (non-resume) battle start: spawn from painted spawn tiles and
## initialize the turn loop from turn 0.
func _spawn_fresh_battle() -> void:
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

	_register_battle_systems(player_units, enemy_units)


## Post-spawn wiring shared by fresh starts and save resumes: passive-effect
## recompute, threat overlay, and foot tracks all learn the unit lists here.
func _register_battle_systems(player_units: Array[Unit], enemy_units: Array[Unit]) -> void:
	# Wire passive effects after TurnManager owns the unit lists; the system
	# does an initial recompute so opening-turn passive bonuses are correct.
	var passive_effects: Node = get_node_or_null("/root/PassiveEffectsSystem")
	if passive_effects != null:
		passive_effects.register_battle_units(player_units, enemy_units)

	# Foot tracks: connect each unit's path_traversed signal so the overlay
	# draws a trail along the route it actually walks, then ingest any
	# designer-painted seed tracks (a "FootTrackTileLayer" in the map) as the
	# depth-1 base the runtime stacks onto.
	if _threat_overlay != null:
		_threat_overlay.register_battle_units(player_units, enemy_units)

	if _foot_track_renderer != null:
		_foot_track_renderer.register_battle_units(player_units, enemy_units)
		var seed_layer := find_child("FootTrackTileLayer", true, false) as TileMapLayer
		if seed_layer != null:
			_foot_track_renderer.ingest_seed_layer(seed_layer)


# =============================================================================
# SAVE RESUME
# =============================================================================

## Rebuilds the board from a save's battle section and re-enters the turn loop
## mid-fight via TurnManager.resume_battle (no battle_started, no upkeep —
## see that function's header for why). Player units come from the restored
## SquadManager roster; enemies reconstruct from their JSON + saved deltas
## through the same pipelines as a fresh spawn.
func _resume_from_snapshot(battle: Dictionary) -> void:
	var player_units: Array[Unit] = []
	var enemy_units: Array[Unit] = []

	for entry: Variant in battle.get("units", []):
		if not entry is Dictionary:
			continue
		var tile := GridManager.get_tile(int(entry.get("grid_x", 0)), int(entry.get("grid_y", 0)))
		if tile == null:
			push_warning("BattleScene: restore lost a unit — no tile at (%s, %s)" % [
				entry.get("grid_x"), entry.get("grid_y")])
			continue
		var faction: Enums.UnitFaction = int(entry.get("faction", Enums.UnitFaction.PLAYER)) as Enums.UnitFaction

		var unit: Unit = null
		if faction == Enums.UnitFaction.PLAYER:
			var character: CharacterData = SquadManager.get_character_by_id(str(entry.get("character_id", "")))
			if character == null:
				push_warning("BattleScene: restore lost player '%s' — not in restored roster" % [
					entry.get("character_id")])
				continue
			unit = _create_unit_from_data(character, faction, tile)
		else:
			var json_path: String = str(entry.get("json_path", ""))
			var character: CharacterData = CharacterDataLoader.load_character(json_path)
			if character == null:
				push_warning("BattleScene: restore lost enemy at '%s' — JSON failed to load" % json_path)
				continue
			character.apply_save_dict(entry.get("character", {}))
			var behavior: Enums.AIBehaviorType = int(entry.get("ai_behavior",
					Enums.AIBehaviorType.AGGRESSIVE)) as Enums.AIBehaviorType
			unit = _create_unit_from_data(character, faction, tile, behavior)
			unit.character_json_path = json_path

		SaveManager.apply_unit_state(unit, entry)
		if faction == Enums.UnitFaction.PLAYER:
			player_units.append(unit)
		else:
			enemy_units.append(unit)

	if player_units.is_empty() and enemy_units.is_empty():
		push_warning("BattleScene: battle restore produced an empty board — falling back to fresh spawns")
		_spawn_fresh_battle()
		return

	DebugConfig.log_unit_init("BattleScene: Resumed %d players + %d enemies from save" % [
		player_units.size(), enemy_units.size()])

	# Cross-unit status references (CHALLENGED's challenger) resolve only after
	# EVERY unit is back on its tile — per-unit apply_unit_state can't do it.
	SaveManager.resolve_status_sources(player_units)
	SaveManager.resolve_status_sources(enemy_units)

	SquadManager.restore_pre_battle_snapshots(battle.get("pre_battle_snapshots", {}))
	TurnManager.resume_battle(player_units, enemy_units, int(battle.get("turn_count", 1)))
	_register_battle_systems(player_units, enemy_units)


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
	# spawns and how many slots are filled). Player spawn tiles carry no
	# difficulty data — entries are bare Vector2i.
	if faction == Enums.UnitFaction.PLAYER:
		var roster: Array[CharacterData] = _get_deployed_roster()
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

	# Enemy spawns: each entry is a Dictionary {position, difficulty}. Random
	# JSON per tile from enemy_spawn_pool; difficulty drives auto-level bucket.
	for entry: Variant in positions:
		var grid_pos: Vector2i = entry["position"]
		var difficulty: Enums.EnemyDifficulty = entry.get("difficulty", Enums.EnemyDifficulty.DEFAULT)
		var tile := GridManager.get_tile(grid_pos.x, grid_pos.y)
		if tile == null:
			push_warning("BattleScene: No tile at (%d, %d) for spawn" % [grid_pos.x, grid_pos.y])
			continue
		var json_path: String = character_path
		if not enemy_spawn_pool.is_empty():
			json_path = enemy_spawn_pool[GameRng.randi() % enemy_spawn_pool.size()]
		var unit := _create_unit(json_path, faction, tile, Enums.AIBehaviorType.AGGRESSIVE, difficulty)
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
	var map_rect: Rect2 = GridManager.get_map_world_rect()
	var map_min := map_rect.position
	var map_max := map_rect.end

	# Polygon must extend far enough past the map that the camera can never pan
	# its edge into view. 4096px of padding is effectively infinite at current
	# zoom levels.
	var pad := 4096.0
	var poly_min := map_min - Vector2(pad, pad)
	var poly_max := map_max + Vector2(pad, pad)

	# Live in the default world CanvasLayer so the vignette participates in the
	# same z_index ordering as tiles/units. The PATH_INDICATORS band sits above
	# the floor / foot-track / modifier / decoration tilemap layers but below
	# every per-row unit (UNITS band and up), so tall unit sprites / HP bars /
	# status icons poking into OOB render on top of the fade rather than being
	# darkened by it. Enum ref (not a magic number) so it tracks the band.
	var poly := Polygon2D.new()
	poly.name = "MapVignette"
	poly.polygon = PackedVector2Array([
		Vector2(poly_min.x, poly_min.y),
		Vector2(poly_max.x, poly_min.y),
		Vector2(poly_max.x, poly_max.y),
		Vector2(poly_min.x, poly_max.y),
	])
	poly.z_index = int(ZIndexCalculator.ZIndexLayer.PATH_INDICATORS)

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
## When an active campaign is running, the spawned unit's CharacterData is
## auto-leveled. The `difficulty` arg comes from the spawn tile's bucket and
## controls which level band the enemy lands in. Without an active campaign
## (e.g. F6 directly on a map), the unit stays at level 1.
func _create_unit(json_path: String, faction: Enums.UnitFaction, tile: Tile,
		ai_behavior: Enums.AIBehaviorType = Enums.AIBehaviorType.AGGRESSIVE,
		difficulty: Enums.EnemyDifficulty = Enums.EnemyDifficulty.DEFAULT) -> Unit:
	var unit: Unit = _unit_scene.instantiate() as Unit
	unit.character_json_path = json_path
	unit.faction = faction
	_units_container.add_child(unit)
	unit.initialize(tile)
	_auto_level_unit(unit, difficulty)
	unit.auto_assign_first_usable_move()

	if faction == Enums.UnitFaction.ENEMY:
		var enemy_ai := EnemyAI.new()
		enemy_ai.name = "EnemyAI"
		enemy_ai.behavior_type = ai_behavior
		unit.add_child(enemy_ai)

	return unit


## Auto-levels an enemy unit when a campaign is active. Each enemy gets an
## independently-rolled level from CampaignManager.pick_enemy_level(difficulty),
## where `difficulty` came from the spawn tile's bucket (DEFAULT for legacy
## tiles, or one of VERY_LOW..BOSS for difficulty-tagged tiles). Player units
## come in pre-leveled from CampaignManager.start_campaign / _register_recruit.
## Returns the roster filtered by CampaignManager's deployment selection (the
## player's prep-screen choice of which units to bring). An UNSET selection
## (nobody ever wrote one — F6 on a map, an ad-hoc battle) means "deploy
## everyone"; a chosen selection is honored verbatim, empty included — the hub
## refuses to launch at 0/N, so an empty board here means a path skipped it.
## Falls back to the full roster if no campaign is active.
func _get_deployed_roster() -> Array[CharacterData]:
	var full_roster: Array[CharacterData] = SquadManager.get_active_roster()
	var campaign_manager: Node = get_node_or_null("/root/CampaignManager")
	if campaign_manager == null or not campaign_manager.is_active():
		return full_roster
	if not campaign_manager.has_deployment():
		return full_roster
	var selected_ids: Array[String] = campaign_manager.get_deployment()
	var filtered: Array[CharacterData] = []
	for character: CharacterData in full_roster:
		if selected_ids.has(character.character_id):
			filtered.append(character)
	return filtered


func _auto_level_unit(unit: Unit, difficulty: Enums.EnemyDifficulty = Enums.EnemyDifficulty.DEFAULT) -> void:
	if unit == null or unit.character_data == null:
		return
	var campaign_manager: Node = get_node_or_null("/root/CampaignManager")
	if campaign_manager == null or not campaign_manager.is_active():
		return
	if unit.faction != Enums.UnitFaction.ENEMY:
		return
	var target_level: int = campaign_manager.pick_enemy_level(difficulty)
	if unit.character_data.level >= target_level:
		return
	unit.character_data.simulate_levels_up_to(target_level)
	# Unit.initialize() captured current_hp before auto-leveling raised max_hp.
	# Top off so a freshly-spawned auto-leveled unit starts at full health.
	unit.current_hp = unit.character_data.max_hp
	# Initialize() also cached the level label at the pre-level-up value; the
	# label only refreshes on XP-driven level-ups otherwise.
	unit._update_level_label()


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

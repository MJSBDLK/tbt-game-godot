## Grid live-paint (RQD 2026-07-30): while a move chip holds menu attention,
## the board previews that move's reach — "the chip is a mnemonic, the board is
## the truth." Two seams pinned here:
##   - MoveTargeting.get_reach_tiles: the footprint TRUTH (Manhattan ball of
##     effective range, own tile only for self-targetable moves, Extendo's
##     bonus ring gated by the same forgiving reach can_target uses).
##   - GridManager's preview state: display/clear/query, rendered on its own
##     decal layer (ThreatOverlayRenderer, MOVE_PREVIEW style) — never
##     Tile.set_color, which the movement-range tint already owns while the
##     action menu is open.
## Grid harness mirrors test_extendo_passive.gd: real tiles IN the tree so the
## reach predicate can consult TerrainDataManager.
extends GutTest


func before_each() -> void:
	GridManager.clear_grid()


func after_each() -> void:
	GridManager.clear_move_range_preview()


func after_all() -> void:
	GridManager.clear_grid()


func _unit(faction: Enums.UnitFaction = Enums.UnitFaction.PLAYER, passives: Array = []) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.faction = faction
	unit.current_hp = 10
	var data := CharacterData.new()
	data.equipped_passives = passives.duplicate()
	unit.character_data = data
	return unit


func _move(attack_range: int = 1, target_type: Enums.TargetType = Enums.TargetType.SINGLE,
		damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL) -> Move:
	var move := Move.new()
	move.damage_type = damage_type
	move.base_power = 10
	move.attack_range = attack_range
	move.target_type = target_type
	return move


func _grid_tile(x: int, y: int, terrain: String) -> void:
	var tile := Tile.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	tile.add_child(sprite)
	add_child_autofree(tile)
	tile.grid_x = x
	tile.grid_y = y
	tile.terrain_type_name = terrain
	GridManager.register_tile(tile)


func _open_grid(min_x: int, max_x: int, min_y: int, max_y: int) -> void:
	for x: int in range(min_x, max_x + 1):
		for y: int in range(min_y, max_y + 1):
			_grid_tile(x, y, "Plains")


func _place(unit: Unit, x: int, y: int) -> void:
	var tile := GridManager.get_tile(x, y)
	unit.current_tile = tile
	tile.current_unit = unit


# =============================================================================
# get_reach_tiles — the footprint truth
# =============================================================================

func test_reach_is_the_manhattan_ball_without_own_tile() -> void:
	_open_grid(0, 4, 0, 4)
	var unit := _unit()
	_place(unit, 2, 2)
	var tiles := MoveTargeting.get_reach_tiles(unit, _move(2))
	# r=2 Manhattan ball on an open 5x5 = 12 cells; the attacker's own tile is
	# not part of an enemy-target move's footprint.
	assert_eq(tiles.size(), 12, "range-2 ball paints 12 cells")
	assert_false(tiles.has(GridManager.get_tile(2, 2)), "own tile excluded for SINGLE")
	assert_true(tiles.has(GridManager.get_tile(0, 2)), "straight edge of the ball included")
	assert_true(tiles.has(GridManager.get_tile(3, 3)), "diagonal at distance 2 included")


func test_footprint_ignores_occupancy() -> void:
	# The paint is the move's geometry, not a target list — an occupied cell
	# and an empty one render identically.
	_open_grid(0, 2, 0, 0)
	var unit := _unit()
	_place(unit, 0, 0)
	var bystander := _unit(Enums.UnitFaction.ENEMY)
	_place(bystander, 1, 0)
	var tiles := MoveTargeting.get_reach_tiles(unit, _move(2))
	assert_true(tiles.has(GridManager.get_tile(1, 0)), "occupied cell painted")
	assert_true(tiles.has(GridManager.get_tile(2, 0)), "empty cell painted")


func test_self_targetable_moves_include_own_tile() -> void:
	_open_grid(0, 2, 0, 2)
	var unit := _unit()
	_place(unit, 1, 1)
	var self_tiles := MoveTargeting.get_reach_tiles(unit, _move(0, Enums.TargetType.SELF))
	assert_eq(self_tiles.size(), 1, "SELF at range 0 paints exactly the own tile")
	assert_true(self_tiles.has(GridManager.get_tile(1, 1)))
	var ally_tiles := MoveTargeting.get_reach_tiles(unit, _move(1, Enums.TargetType.ALLY))
	assert_eq(ally_tiles.size(), 5, "ALLY range 1 = 4 neighbors + own tile")


func test_extendo_bonus_ring_respects_reach() -> void:
	# Corridor: unit at (0,0), bonus tile at (2,0). Extendo lifts a physical
	# range-1 move to 2, but the bonus ring only paints where the forgiving
	# reach is clear — a Wall at (1,0) blocks (2,0) for a grounded type, while
	# the wall tile itself stays painted (base range never needed reach; this
	# matches can_target exactly).
	_open_grid(0, 2, 0, 0)
	var unit := _unit(Enums.UnitFaction.PLAYER, ["Extendo"])
	_place(unit, 0, 0)
	var move := _move(1)
	var open_tiles := MoveTargeting.get_reach_tiles(unit, move)
	assert_true(open_tiles.has(GridManager.get_tile(2, 0)), "clear corridor: bonus tile painted")
	GridManager.get_tile(1, 0).terrain_type_name = "Wall"
	var walled_tiles := MoveTargeting.get_reach_tiles(unit, move)
	assert_false(walled_tiles.has(GridManager.get_tile(2, 0)), "walled corridor: bonus tile dropped")
	assert_true(walled_tiles.has(GridManager.get_tile(1, 0)), "base-range tile stays painted")


func test_reach_tiles_null_safety() -> void:
	var unit := _unit()  # no current_tile
	assert_eq(MoveTargeting.get_reach_tiles(unit, _move(1)).size(), 0, "off-grid unit paints nothing")
	assert_eq(MoveTargeting.get_reach_tiles(null, _move(1)).size(), 0)
	assert_eq(MoveTargeting.get_reach_tiles(unit, null).size(), 0)


# =============================================================================
# GridManager preview state + renderer
# =============================================================================

func test_display_preview_tracks_move_and_paints_cells() -> void:
	_open_grid(0, 2, 0, 2)
	var unit := _unit()
	_place(unit, 1, 1)
	var move := _move(1)
	GridManager.display_move_range_preview(unit, move)
	assert_eq(GridManager.move_range_preview_move(), move, "the previewed move is queryable")
	var renderer: ThreatOverlayRenderer = GridManager._move_range_preview_renderer
	assert_not_null(renderer, "renderer lazily created")
	assert_eq(renderer._centers.size(), 4, "one decal per footprint cell")
	assert_eq(renderer._style, ThreatOverlayRenderer.Style.PREVIEW_DAMAGE,
			"a damaging move paints in the damage palette, not a danger style")
	assert_true(renderer.material is ShaderMaterial,
			"projection-static trial rides the decal layer (RQD/Lawrence 2026-07-30)")


func test_preview_style_follows_move_intent() -> void:
	# RQD 2026-07-30, "the generally agreed upon color codes": red = damaging,
	# green = healing, blue = neither. `heals` wins over base_power — a heal's
	# base_power is its heal amount (First Aid), not damage.
	assert_eq(GridManager.move_range_preview_style(_move(1)),
			ThreatOverlayRenderer.Style.PREVIEW_DAMAGE)
	var heal := _move(1)
	heal.heals = true
	assert_eq(GridManager.move_range_preview_style(heal),
			ThreatOverlayRenderer.Style.PREVIEW_HEAL, "heals wins even with base_power set")
	var support := _move(1)
	support.base_power = 0
	assert_eq(GridManager.move_range_preview_style(support),
			ThreatOverlayRenderer.Style.PREVIEW_NEUTRAL)
	assert_eq(GridManager.move_range_preview_style(null),
			ThreatOverlayRenderer.Style.PREVIEW_NEUTRAL, "null-safe")


func test_clear_preview_resets_state_and_decals() -> void:
	_open_grid(0, 2, 0, 2)
	var unit := _unit()
	_place(unit, 1, 1)
	GridManager.display_move_range_preview(unit, _move(1))
	GridManager.clear_move_range_preview()
	assert_null(GridManager.move_range_preview_move())
	assert_eq(GridManager._move_range_preview_renderer._centers.size(), 0, "decals dropped")


func test_display_with_nulls_clears_instead_of_lingering() -> void:
	_open_grid(0, 2, 0, 2)
	var unit := _unit()
	_place(unit, 1, 1)
	GridManager.display_move_range_preview(unit, _move(1))
	GridManager.display_move_range_preview(unit, null)
	assert_null(GridManager.move_range_preview_move(), "null move = clear, never stale paint")


func test_clear_grid_drops_the_preview() -> void:
	_open_grid(0, 2, 0, 2)
	var unit := _unit()
	_place(unit, 1, 1)
	GridManager.display_move_range_preview(unit, _move(1))
	GridManager.clear_grid()
	assert_null(GridManager.move_range_preview_move(), "map teardown can't orphan the paint")

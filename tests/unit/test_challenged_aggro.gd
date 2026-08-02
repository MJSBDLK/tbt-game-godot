## Phase 4 arc, part 3: CHALLENGED finally has teeth. Source tracking on
## StatusEffect, the EnemyAI targeting lock, its release conditions, and the
## challenger's save round-trip (grid cell → live unit via
## SaveManager.resolve_status_sources).
extends GutTest


func before_each() -> void:
	GridManager.clear_grid()


func after_all() -> void:
	GridManager.clear_grid()


# =============================================================================
# HELPERS
# =============================================================================

func _grid_tile(x: int, y: int) -> void:
	var tile := Tile.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	tile.add_child(sprite)
	add_child_autofree(tile)
	tile.grid_x = x
	tile.grid_y = y
	tile.terrain_type_name = "Plains"
	GridManager.register_tile(tile)


func _open_grid(min_x: int, max_x: int, min_y: int, max_y: int) -> void:
	for x: int in range(min_x, max_x + 1):
		for y: int in range(min_y, max_y + 1):
			_grid_tile(x, y)


func _unit(label: String, faction: Enums.UnitFaction) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.unit_name = label
	unit.faction = faction
	unit.current_hp = 20
	var data := CharacterData.new()
	unit.character_data = data
	return unit


func _place(unit: Unit, x: int, y: int) -> void:
	var tile := GridManager.get_tile(x, y)
	unit.current_tile = tile
	tile.current_unit = unit


func _challenge(challenger: Unit, challenged: Unit) -> StatusEffect:
	StatusEffectSystem.apply_status_effect_by_name(challenger, challenged, "CHALLENGED")
	for effect: StatusEffect in challenged.active_status_effects:
		if effect.effect_type_name == "CHALLENGED":
			return effect
	return null


func _ai_for(unit: Unit) -> EnemyAI:
	# Out-of-tree units never fire the AI's _ready, so bind the unit directly.
	var ai := EnemyAI.new()
	autofree(ai)
	ai._unit = unit
	return ai


# =============================================================================
# SOURCE TRACKING
# =============================================================================

func test_challenged_remembers_who_roared() -> void:
	var challenger := _unit("roarer", Enums.UnitFaction.PLAYER)
	var challenged := _unit("knight", Enums.UnitFaction.ENEMY)
	var effect := _challenge(challenger, challenged)
	assert_not_null(effect)
	assert_eq(effect.source_unit, challenger, "the status carries its caster")


func test_restack_repoints_to_the_newest_challenger() -> void:
	var first := _unit("first roarer", Enums.UnitFaction.PLAYER)
	var second := _unit("second roarer", Enums.UnitFaction.PLAYER)
	var challenged := _unit("knight", Enums.UnitFaction.ENEMY)
	var effect := _challenge(first, challenged)
	StatusEffectSystem.apply_status_effect_by_name(second, challenged, "CHALLENGED")
	assert_eq(effect.source_unit, second, "last roar wins the knight's attention")


# =============================================================================
# THE AI LOCK
# =============================================================================

func test_challenged_ai_locks_onto_the_challenger() -> void:
	_open_grid(0, 5, 0, 0)
	var bait := _unit("bait", Enums.UnitFaction.PLAYER)
	var challenger := _unit("roarer", Enums.UnitFaction.PLAYER)
	var knight := _unit("knight", Enums.UnitFaction.ENEMY)
	_place(knight, 0, 0)
	_place(bait, 1, 0)        # adjacent AND wounded — the obvious pick
	bait.current_hp = 3
	_place(challenger, 5, 0)  # far and healthy
	_challenge(challenger, knight)
	var ai := _ai_for(knight)
	assert_eq(ai._find_best_target(), challenger,
		"the challenge overrides distance and blood-in-the-water scoring")


func test_the_lock_releases_when_the_challenger_falls() -> void:
	var challenger := _unit("roarer", Enums.UnitFaction.PLAYER)
	var knight := _unit("knight", Enums.UnitFaction.ENEMY)
	_challenge(challenger, knight)
	challenger.current_hp = 0
	var ai := _ai_for(knight)
	assert_null(ai._active_challenger(), "a fallen challenger compels nothing")


# =============================================================================
# SAVE ROUND-TRIP
# =============================================================================

func test_the_challenger_survives_the_save_round_trip() -> void:
	_open_grid(0, 3, 0, 0)
	var challenger := _unit("roarer", Enums.UnitFaction.PLAYER)
	var challenged := _unit("knight", Enums.UnitFaction.ENEMY)
	_place(challenger, 0, 0)
	_place(challenged, 2, 0)
	_challenge(challenger, challenged)

	var entry: Dictionary = SaveManager._unit_to_save_dict(challenged)
	var round_tripped: Dictionary = JSON.parse_string(JSON.stringify(entry))

	var restored := _unit("restored knight", Enums.UnitFaction.ENEMY)
	SaveManager.apply_unit_state(restored, round_tripped)
	var effect: StatusEffect = restored.active_status_effects[0]
	assert_null(effect.source_unit, "before resolution the reference is still cold")
	assert_eq(effect.pending_source_cell, [0, 0], "…but the cell rode the file")

	SaveManager.resolve_status_sources([restored] as Array[Unit])
	assert_eq(effect.source_unit, challenger,
		"resolution re-points the compulsion at whoever stands on the saved cell")
	assert_null(effect.pending_source_cell, "the intermediary is consumed")

## Panic: below half HP he moves a tile farther but can't use support moves.
## Read live from HP: Unit.max_movement_range asks extra_move_tiles, and
## Unit.is_move_index_locked asks locks_move.
extends GutTest


func _thumps(passives: Array = ["Panic"]) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	var data := CharacterData.new()
	data.base_max_hp = 20
	data.move_distance = 3
	data.equipped_passives = passives.duplicate()
	data.equipped_moves = [MoveData.get_move("Pound"), MoveData.get_move("Lighten")] as Array[Move]
	unit.character_data = data
	unit.current_hp = 20
	return unit


func test_hurt_he_moves_a_tile_farther() -> void:
	var thumps := _thumps()
	assert_eq(thumps.max_movement_range, 3 * Unit.MOVEMENT_SCALE)
	thumps.current_hp = 9
	assert_eq(thumps.max_movement_range, 4 * Unit.MOVEMENT_SCALE)


func test_half_hp_is_not_below_half() -> void:
	var thumps := _thumps()
	thumps.current_hp = 10
	assert_eq(thumps.max_movement_range, 3 * Unit.MOVEMENT_SCALE)
	assert_false(thumps.is_move_index_locked(1))


func test_hurt_he_drops_the_stones() -> void:
	var thumps := _thumps()
	assert_false(thumps.is_move_index_locked(1), "Lighten, while he's calm")
	thumps.current_hp = 9
	assert_true(thumps.is_move_index_locked(1), "Lighten, panicking")
	assert_false(thumps.is_move_index_locked(0), "Pound still swings")
	assert_eq(thumps.get_usable_moves(), [thumps.character_data.equipped_moves[0]] as Array[Move])


func test_rooted_is_still_rooted() -> void:
	var thumps := _thumps()
	thumps.current_hp = 9
	thumps.can_move = false
	assert_eq(thumps.max_movement_range, 0)


func test_without_the_passive_nothing_changes() -> void:
	var calm := _thumps([])
	calm.current_hp = 1
	assert_eq(calm.max_movement_range, 3 * Unit.MOVEMENT_SCALE)
	assert_false(calm.is_move_index_locked(1))

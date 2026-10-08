## Touch has no hover, so on touch the tap that picks an attack target can't
## also be the one that swings: the first tap arms the target and shows the
## forecast, a second tap on it attacks, a tap on another target re-arms, and
## a tap off the targets cancels (InputManager.target_tap). Mouse, pad and
## keyboard see the forecast before their press and still attack on it.
## Right click's `back` is here too: during targeting it steps back, as
## Escape does. Grid harness mirrors test_target_cursor.gd.
extends GutTest


func before_each() -> void:
	GridManager.clear_grid()
	InputSource.last_device = InputSource.Device.TOUCH
	InputSource.last_kind = InputSource.Kind.POINTER
	InputManager.cancel_attack_targeting()
	InputManager.deselect_unit()
	InputManager.enable_input()


func after_each() -> void:
	InputManager.cancel_attack_targeting()
	InputManager.deselect_unit()
	InputSource.last_device = InputSource.Device.MOUSE
	InputSource.last_kind = InputSource.Kind.POINTER
	GameStateManager.change_state(Enums.InputState.DEFAULT)


func after_all() -> void:
	GridManager.clear_grid()


func _unit(faction: Enums.UnitFaction = Enums.UnitFaction.PLAYER) -> Unit:
	var unit := Unit.new()
	autofree(unit)
	unit.faction = faction
	unit.current_hp = 10
	unit.character_data = CharacterData.new()
	return unit


func _place(unit: Unit, x: int) -> void:
	var tile := GridManager.get_tile(x, 0)
	unit.current_tile = tile
	tile.current_unit = unit


## Attacker at (0,0), enemies at (1,0) and (2,0), nothing at (3,0); a range-2
## move, so both enemies are targets.
func _start_targeting() -> void:
	for x: int in range(0, 4):
		var tile := Tile.new()
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		tile.add_child(sprite)
		add_child_autofree(tile)
		tile.grid_x = x
		tile.terrain_type_name = "Plains"
		GridManager.register_tile(tile)
	var attacker := _unit()
	_place(attacker, 0)
	_place(_unit(Enums.UnitFaction.ENEMY), 1)
	_place(_unit(Enums.UnitFaction.ENEMY), 2)
	var move := Move.new()
	move.damage_type = Enums.DamageType.PHYSICAL
	move.base_power = 10
	move.attack_range = 2
	move.target_type = Enums.TargetType.SINGLE
	InputManager.start_attack_targeting(attacker, move)


func test_the_tap_rules() -> void:
	var near: Tile = autofree(Tile.new())
	var far: Tile = autofree(Tile.new())
	assert_eq(InputManager.target_tap(null, near, true), InputManager.TargetTap.ARM,
			"the first tap on a target arms it")
	assert_eq(InputManager.target_tap(near, near, true), InputManager.TargetTap.ATTACK,
			"the second tap on it attacks")
	assert_eq(InputManager.target_tap(near, far, true), InputManager.TargetTap.ARM,
			"another target takes the arm")
	assert_eq(InputManager.target_tap(near, far, false), InputManager.TargetTap.CANCEL,
			"off the targets cancels, as a click does")
	assert_eq(InputManager.target_tap(near, near, false), InputManager.TargetTap.CANCEL,
			"an armed target that can no longer be hit cancels")


func test_a_tap_arms_and_another_target_rearms() -> void:
	_start_targeting()
	var near := GridManager.get_tile(1, 0)
	InputManager._tap_attack_tile(near)
	assert_eq(InputManager._armed_target_tile, near)
	assert_true(InputManager._is_selecting_attack_target, "armed, not swung: the forecast is up")
	InputManager._tap_attack_tile(GridManager.get_tile(2, 0))
	assert_eq(InputManager._armed_target_tile, GridManager.get_tile(2, 0))
	assert_true(InputManager._is_selecting_attack_target)


func test_a_tap_off_the_targets_cancels_and_disarms() -> void:
	_start_targeting()
	InputManager._tap_attack_tile(GridManager.get_tile(1, 0))
	InputManager._tap_attack_tile(GridManager.get_tile(3, 0))
	assert_false(InputManager._is_selecting_attack_target)
	assert_null(InputManager._armed_target_tile)


func test_back_steps_out_of_targeting() -> void:
	_start_targeting()
	var back := InputEventAction.new()
	back.action = &"back"
	back.pressed = true
	InputManager._unhandled_input(back)
	assert_false(InputManager._is_selecting_attack_target, "right click backs out, as Escape does")

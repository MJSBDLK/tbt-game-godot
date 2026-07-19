## MoveChipButton — the border vocabulary translated onto themed move chips.
## Pins the translation rules from the mockup's "Move chips" section: the
## body/border are skin (element colors, usage fill untouchable), assigned =
## parked brackets vs cursor = snapping, depleted/locked = disabled tier with
## a reason, and the backlight lifts both body colors together so the usage
## boundary keeps its contrast.
extends GutTest


func after_each() -> void:
	Settings.ui_motion_enabled = true


func _make_move(uses: int = 3, max_uses: int = 5) -> Move:
	var move := Move.new()
	move.move_name = "Ember"
	move.element_type = Enums.ElementalType.FIRE
	move.current_uses = uses
	move.max_uses = max_uses
	return move


func _make_chip_button(move: Move, is_assigned: bool = false, locked: bool = false) -> MoveChipButton:
	var chip_button := MoveChipButton.new()
	add_child_autofree(chip_button)
	chip_button.setup(move, is_assigned, locked)
	return chip_button


func test_setup_reads_the_move() -> void:
	var chip_button := _make_chip_button(_make_move(3, 5))
	assert_eq(chip_button._name_label.text, "Ember")
	assert_eq(chip_button._uses_label.text, "3/5")
	assert_almost_eq(chip_button._chip.fill_percent, 0.6, 0.001, "usage fill = uses/max")
	assert_false(chip_button.disabled)


func test_assigned_shows_parked_brackets_cursor_makes_them_snap() -> void:
	var chip_button := _make_chip_button(_make_move(), true)
	assert_true(chip_button._brackets_visible(), "assigned move carries brackets")
	assert_false(chip_button._brackets_snapping(), "parked — motion category says 'assigned'")
	chip_button.selected = true
	assert_true(chip_button._brackets_snapping(),
			"the cursor landing here resumes the snap: that IS 'you are here'")


func test_depleted_is_the_disabled_tier_with_a_reason() -> void:
	var chip_button := _make_chip_button(_make_move(0, 4))
	assert_true(chip_button.disabled, "0 uses = disabled tier")
	assert_eq(chip_button.disabled_reason, "NO USES REMAINING")
	assert_eq(chip_button._chip.border_color, GameColors.INTERACTIVE_BORDER_DISABLED,
			"the chip skin's border drops to the dark tier")
	watch_signals(chip_button)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	chip_button._gui_input(press)
	assert_signal_emitted(chip_button, "denied")


func test_void_locked_keeps_uses_but_seals_the_move() -> void:
	var chip_button := _make_chip_button(_make_move(2, 2), false, true)
	assert_true(chip_button.disabled)
	assert_eq(chip_button.disabled_reason, "SEALED BY VOID LOCK")
	assert_eq(chip_button._uses_label.text, "2/2",
			"the lock took the move, not the PP — uses stay visible")


func test_backlight_lifts_both_body_colors_together() -> void:
	var chip_button := _make_chip_button(_make_move())
	var base_fill: Color = chip_button._chip.fill_color
	var base_empty: Color = chip_button._chip.empty_color
	var fill_before: float = chip_button._chip.fill_percent
	chip_button._backlight_level = 1.0
	chip_button._redraw_chrome()
	assert_ne(chip_button._chip.fill_color, base_fill, "body lifts on focus")
	assert_ne(chip_button._chip.empty_color, base_empty,
			"empty lifts WITH fill — the usage boundary keeps its contrast")
	assert_eq(chip_button._chip.fill_percent, fill_before,
			"the vocabulary never touches the resource axis")


func test_type_icon_rides_the_right_side_and_follows_the_tier() -> void:
	var chip_button := _make_chip_button(_make_move())
	assert_not_null(chip_button._icon.texture, "FIRE loads its 10x10 icon")
	assert_null(chip_button._icon.material, "healthy chip: icon in full color")
	var depleted := _make_chip_button(_make_move(0, 4))
	assert_not_null(depleted._icon.material, "dark tier greys the icon too")
	var no_element := _make_chip_button(_make_move())
	var typeless := _make_move()
	typeless.element_type = Enums.ElementalType.NONE
	no_element.setup(typeless)
	assert_null(no_element._icon.texture, "NONE simply shows no icon")


func test_backlight_lift_stays_on_the_element_ramp() -> void:
	var chip_button := _make_chip_button(_make_move())
	chip_button._backlight_level = 1.0
	chip_button._redraw_chrome()
	assert_eq(chip_button._chip.fill_color, GameColorPalette.get_color("PoppyRed", 6),
			"full lift = exactly one step up the artist's ramp — lerp-toward-white read as 'off'")
	assert_eq(chip_button._chip.empty_color, GameColorPalette.get_color("PoppyRed", 3),
			"empty climbs its own step of the same ramp")


func test_ramp_table_refactor_preserved_the_shipped_colors() -> void:
	assert_eq(GameColors.get_move_chip_foreground(Enums.ElementalType.FIRE),
			GameColorPalette.get_color("PoppyRed", 5))
	assert_eq(GameColors.get_move_chip_background(Enums.ElementalType.COLD),
			GameColorPalette.get_color("Azure", 1))
	assert_eq(GameColors.get_move_chip_foreground(Enums.ElementalType.NONE),
			GameColorPalette.get_color("Gray", 5), "fallback row survived too")


func test_element_colors_come_from_the_palette_not_the_vocabulary() -> void:
	var chip_button := _make_chip_button(_make_move())
	assert_eq(chip_button._base_fill,
			GameColors.get_move_chip_foreground(Enums.ElementalType.FIRE),
			"body = element skin")
	assert_eq(chip_button.base_background, Color.TRANSPARENT,
			"no flat vocabulary background behind the chip")

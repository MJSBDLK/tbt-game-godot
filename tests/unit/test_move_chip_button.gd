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


func test_type_icon_leads_the_row_and_follows_the_tier() -> void:
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


func test_damage_type_icon_sits_beside_the_element_icon() -> void:
	var chip_button := _make_chip_button(_make_move())
	assert_not_null(chip_button._damage_icon.texture,
			"PHYSICAL loads the shared 10x10 move-type icon")
	assert_eq(chip_button._damage_icon.get_index(), chip_button._icon.get_index() + 1,
			"damage type sits immediately after the element — Lawrence trial 2026-07-19"
			+ " ('if it's ugly we'll move it back')")
	assert_null(chip_button._damage_icon.material, "healthy chip: full color")
	var depleted := _make_chip_button(_make_move(0, 4))
	assert_not_null(depleted._damage_icon.material,
			"dark tier greys the damage icon with the rest")


func test_scheme_and_digits_read_from_the_move() -> void:
	var move := _make_move()
	move.attack_range = 2
	var chip_button := _make_chip_button(move)
	assert_eq(chip_button._range_label.text, "1-2",
			"targeting is dist <= attack_range with implied min 1 — the band is honest")
	assert_false(chip_button._scheme_glyph.blast)
	assert_eq(chip_button._scheme_glyph.glyph_color, GameColors.SCHEME_HOSTILE,
			"single-enemy is the quiet bone default — mark the unusual, not the usual")
	var melee := _make_move()
	assert_eq(MoveChipButton.range_text(melee), "1")
	melee.attack_range = 0
	assert_eq(MoveChipButton.range_text(melee), "", "no reach, no digits")


func test_blast_and_friendly_schemes_are_the_loud_exceptions() -> void:
	var fireball := _make_move()
	fireball.attack_range = 3
	fireball.area_of_effect = 1
	var blast_chip := _make_chip_button(fireball)
	assert_true(blast_chip._scheme_glyph.blast, "AoE radius flips the footprint")
	assert_eq(blast_chip._range_label.text, "1-3")
	var heal := _make_move()
	heal.target_type = Enums.TargetType.ALLY
	var heal_chip := _make_chip_button(heal)
	assert_eq(heal_chip._scheme_glyph.glyph_color, GameColors.SCHEME_FRIENDLY,
			"ally/self targets recolor the glyph — faction is the color axis")


func test_range_never_sits_beside_uses() -> void:
	var chip_button := _make_chip_button(_make_move())
	# Labels ride margin seats, so row order is the seats' order.
	assert_true(chip_button._uses_label.get_parent().get_index()
			- chip_button._range_label.get_parent().get_index() >= 2,
			"the spacer between range and uses is a DECISION (Lawrence 2026-07-19):"
			+ " two number pairs side by side misread")


func test_labels_sit_on_the_prefab_optical_margin() -> void:
	var chip_button := _make_chip_button(_make_move())
	for label: Label in [chip_button._name_label, chip_button._range_label,
			chip_button._uses_label]:
		var seat := label.get_parent() as MarginContainer
		assert_not_null(seat, "every chip text label rides a margin seat")
		assert_eq(seat.get_theme_constant("margin_top"),
				MoveChipButton.TEXT_TOP_MARGIN,
				"same 2px optical top margin as the GlowLabel prefab (ui_text.tscn)")


func test_name_column_is_fixed_so_data_columns_align() -> void:
	var move := _make_move()
	move.move_name = "An Extremely Long Move Name"
	var chip_button := _make_chip_button(move)
	chip_button.custom_minimum_size = Vector2(120, 14)
	assert_eq(chip_button._name_label.text_overrun_behavior,
			TextServer.OVERRUN_TRIM_CHAR,
			"trim, not clip_text — scissor clipping also cut the glow halo")
	assert_eq(chip_button._name_label.custom_minimum_size.x,
			MoveChipButton.NAME_COLUMN_WIDTH)
	await wait_process_frames(2)
	assert_eq(chip_button._name_label.size.x, MoveChipButton.NAME_COLUMN_WIDTH,
			"long names must not push the scheme/range columns")


func test_numbers_wear_the_names_font_scheme() -> void:
	var chip_button := _make_chip_button(_make_move())
	var uses_glow := chip_button._uses_label.material as ShaderMaterial
	assert_not_null(uses_glow, "uses carries the glyph halo, same as the name")
	assert_not_null(chip_button._range_label.material as ShaderMaterial,
			"range carries it too — one font family across the chip")
	# Text wears the ELEMENT's designed pairing — default white was unreadable
	# on some bodies (RQD 2026-07-19); numbers take the same pair as the name.
	assert_eq(uses_glow.get_shader_parameter("glow_color"),
			GameColors.get_move_chip_glow_color(Enums.ElementalType.FIRE))
	assert_eq(chip_button._uses_label.get_theme_color("font_color"),
			GameColors.get_move_chip_font_color(Enums.ElementalType.FIRE))
	assert_eq(chip_button._name_label.get_theme_color("font_color"),
			GameColors.get_move_chip_font_color(Enums.ElementalType.FIRE),
			"name and numbers share one per-element scheme")
	var depleted := _make_chip_button(_make_move(0, 4))
	assert_null(depleted._uses_label.material, "the dark tier kills the halo")
	assert_eq(depleted._uses_label.get_theme_color("font_color"),
			GameColors.INTERACTIVE_TEXT_DISABLED)


func test_range_wears_the_mini_font() -> void:
	var chip_button := _make_chip_button(_make_move())
	assert_true(chip_button._range_label.has_theme_font_override("font"),
			"range digits in the 5px annotation font (trial 2026-07-19)")
	assert_eq(chip_button._range_label.get_theme_font_size("font_size"), 5)
	assert_eq(chip_button._range_label.vertical_alignment,
			VERTICAL_ALIGNMENT_BOTTOM,
			"5-in-8 centering lands on half-pixels — bottom edge is the integer seat")


func test_disabled_tier_greys_the_scheme_glyph() -> void:
	var chip_button := _make_chip_button(_make_move(0, 4))
	assert_eq(chip_button._scheme_glyph.glyph_color,
			GameColors.INTERACTIVE_TEXT_DISABLED,
			"the disabled tier owns ALL of the grey-out, scheme glyph included")


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


func test_setup_is_rerunnable_the_disabled_tier_resets() -> void:
	# Panels (unit preview) reuse chips across units/refreshes.
	var chip_button := _make_chip_button(_make_move(0, 4))
	assert_true(chip_button.disabled, "starts depleted")
	chip_button.setup(_make_move(3, 5))
	assert_false(chip_button.disabled, "healthy re-setup lifts the tier")
	assert_eq(chip_button.disabled_reason, "")
	assert_not_null(chip_button._name_label.material, "the name glow returns")
	assert_eq(chip_button._chip.fill_color,
			GameColors.get_move_chip_foreground(Enums.ElementalType.FIRE),
			"element skin restored from the grey pair")


func test_field_set_knobs_hide_data_columns() -> void:
	# "Field sets per venue" (RQD 2026-07-19): identity-only selectors for
	# the detail panel, identity + uses for the preview readout.
	var chip_button := MoveChipButton.new()
	chip_button.show_scheme_and_range = false
	chip_button.show_uses = false
	add_child_autofree(chip_button)
	# Outside a container, min size alone never sizes the chip — set it.
	chip_button.size = Vector2(120, 14)
	var long_named := _make_move()
	long_named.move_name = "Uppercut"
	chip_button.prefer_full_name = true
	chip_button.setup(long_named)
	assert_false(chip_button._scheme_glyph.visible)
	assert_false(chip_button._range_label.visible)
	assert_false(chip_button._uses_label.visible)
	assert_true(chip_button._name_label.visible, "identity always shows")
	await wait_process_frames(2)
	assert_gt(chip_button._name_label.size.x, MoveChipButton.NAME_COLUMN_WIDTH,
			"identity-only: the name takes the row instead of truncating"
			+ " (RQD 2026-07-19, 'Uppercut')")


func test_scheme_glyph_wears_the_orthogonal_glow() -> void:
	var chip_button := _make_chip_button(_make_move())
	var glyph_material := chip_button._scheme_glyph.material as ShaderMaterial
	assert_not_null(glyph_material,
			"same glow shader as every HUD glyph — 'why not just use the"
			+ " orthogonal glow?' (RQD 2026-07-19)")
	assert_eq(glyph_material.get_shader_parameter("glow_color"),
			TargetSchemeGlyph.OUTLINE_COLOR, "dark glow = the pixel-art outline")
	assert_eq(TargetSchemeGlyph._shape_texture(false).get_size(), Vector2(12, 12),
			"1px transparent pad gives the shader texels to paint into")


func test_display_only_mode_removes_all_interactivity() -> void:
	var chip_button := _make_chip_button(_make_move())
	chip_button.make_display_only()
	assert_eq(chip_button.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"an unpressable chip must not hover — the lit contract stays honest")
	assert_eq(chip_button.focus_mode, Control.FOCUS_NONE)


func test_element_colors_come_from_the_palette_not_the_vocabulary() -> void:
	var chip_button := _make_chip_button(_make_move())
	assert_eq(chip_button._base_fill,
			GameColors.get_move_chip_foreground(Enums.ElementalType.FIRE),
			"body = element skin")
	assert_eq(chip_button.base_background, Color.TRANSPARENT,
			"no flat vocabulary background behind the chip")

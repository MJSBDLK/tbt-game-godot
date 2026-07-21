## MoveTooltip — the hold-to-peek detail card (ui-style-guide.md §14 "Detail
## tooltips"). Pins the card's contract: viewport-rooted (chips clip their
## contents, and canvas clipping reaches top_level children — a chip-parented
## card would render 14px tall), one card at a time, cross-dismissal with
## DenyTooltip, detail-pane content, and canvas-edge clamping.
extends GutTest


func after_each() -> void:
	MoveTooltip.dismiss()
	DenyTooltip.dismiss()


func _make_move() -> Move:
	var move := Move.new()
	move.move_name = "Ember"
	move.description = "A small tongue of flame."
	move.element_type = Enums.ElementalType.FIRE
	move.damage_type = Enums.DamageType.SPECIAL
	move.base_power = 4
	move.accuracy = 90
	move.attack_range = 2
	move.max_uses = 20
	move.current_uses = 13
	move.status_effect_type = Enums.StatusEffectType.BLEED
	move.status_effect_chance = 0.3
	return move


func _make_source(at: Vector2 = Vector2(200, 200)) -> Control:
	var source := Control.new()
	add_child_autofree(source)
	source.position = at
	source.size = Vector2(120, 14)
	return source


func _collect_label_text(node: Node) -> Array[String]:
	var texts: Array[String] = []
	if node is Label:
		texts.append((node as Label).text)
	for child: Node in node.get_children():
		texts.append_array(_collect_label_text(child))
	return texts


func _card_says(needle: String) -> bool:
	for line: String in _collect_label_text(MoveTooltip._active):
		if needle in line:
			return true
	return false


func test_card_roots_at_the_viewport_and_seats_above_the_source() -> void:
	var source := _make_source()
	MoveTooltip.show_for(source, _make_move())
	assert_true(MoveTooltip.is_open_for(source))
	assert_eq(MoveTooltip._active.get_parent(), source.get_viewport(),
			"viewport-rooted: chips clip their contents, and canvas clipping"
			+ " reaches top_level children — a chip-parented card renders 14px tall")
	await wait_process_frames(2)
	assert_lt(MoveTooltip._active.position.y, source.position.y,
			"the card seats above its chip")
	assert_eq(MoveTooltip._active.position, MoveTooltip._active.position.floor(),
			"integer position — the card rides the pixel grid")


func test_card_is_the_detail_pane_in_tooltip_form() -> void:
	var source := _make_source()
	MoveTooltip.show_for(source, _make_move())
	assert_true(_card_says("EMBER"), "full name, uppercased like the pane header")
	assert_true(_card_says("PWR"), "stat labels present")
	assert_true(_card_says("90%"), "accuracy in the pane's format")
	assert_true(_card_says("1-2"), "range as the chip's band, not a bare number")
	assert_true(_card_says("13/20"), "uses in the pane's format")
	assert_true(_card_says("SINGLE TARGET - ENEMIES"),
			"the targeting scheme in words — the glyph spelled out")
	assert_true(_card_says("30% BLEED"), "secondary effect line")
	assert_true(_card_says("A small tongue of flame."), "description rides along")


func test_support_move_reads_as_dashes_and_allies() -> void:
	var heal := _make_move()
	heal.base_power = 0
	heal.attack_range = 0
	heal.status_effect_type = Enums.StatusEffectType.NONE
	heal.target_type = Enums.TargetType.ALLY
	MoveTooltip.show_for(_make_source(), heal)
	assert_true(_card_says("--"), "no power / no reach = the pane's dashes")
	assert_true(_card_says("SINGLE TARGET - ALLIES"))


func test_one_card_at_a_time() -> void:
	var first := _make_source()
	var second := _make_source(Vector2(400, 200))
	MoveTooltip.show_for(first, _make_move())
	MoveTooltip.show_for(second, _make_move())
	assert_false(MoveTooltip.is_open_for(first), "a new peek replaces the old")
	assert_true(MoveTooltip.is_open_for(second))


func test_dismiss_for_respects_ownership() -> void:
	var owner_chip := _make_source()
	var bystander := _make_source(Vector2(400, 200))
	MoveTooltip.show_for(owner_chip, _make_move())
	MoveTooltip.dismiss_for(bystander)
	assert_true(MoveTooltip.is_open_for(owner_chip),
			"a chip closing its own peek must not tear down another's card")
	MoveTooltip.dismiss_for(owner_chip)
	assert_false(MoveTooltip.is_open_for(owner_chip))


func test_peek_and_deny_never_stack() -> void:
	var source := _make_source()
	DenyTooltip.show_above(source, "NO USES REMAINING")
	MoveTooltip.show_for(source, _make_move())
	assert_null(DenyTooltip._active, "an opening card clears the lingering deny")
	DenyTooltip.show_above(source, "NO USES REMAINING")
	assert_null(MoveTooltip._active, "and a deny clears an open card")


func test_deny_popup_is_viewport_rooted_too() -> void:
	var source := _make_source()
	DenyTooltip.show_above(source, "NO USES REMAINING")
	assert_eq(DenyTooltip._active.get_parent(), source.get_viewport(),
			"same clip escape as the move card — denies over chips were"
			+ " rendering inside the chip's 14px scissor")


func test_card_clamps_into_the_canvas_and_flips_below_when_tight() -> void:
	var cramped := _make_source(Vector2(0, 4))
	MoveTooltip.show_for(cramped, _make_move())
	await wait_process_frames(2)
	var card: PanelContainer = MoveTooltip._active
	assert_gte(card.position.x, MoveTooltip.MARGIN_PIXELS,
			"clamped inside the left canvas edge")
	assert_gte(card.position.y, cramped.position.y + cramped.size.y,
			"no room above = the card seats below instead")


func test_source_leaving_the_tree_takes_the_card() -> void:
	var source := Control.new()
	add_child(source)
	source.size = Vector2(120, 14)
	MoveTooltip.show_for(source, _make_move())
	assert_true(MoveTooltip.is_open_for(source))
	source.free()
	assert_null(MoveTooltip._active_source,
			"tree_exiting dismisses — the card can't outlive its chip")


func test_touch_pointer_is_the_emulation_device() -> void:
	var touch := InputEventMouseButton.new()
	touch.device = InputEvent.DEVICE_ID_EMULATION
	assert_true(MoveTooltip.is_touch_pointer(touch),
			"touch reaches the HUD as the emulated mouse press (InputRouter"
			+ " remaps only mouse events into HUD coords)")
	var mouse := InputEventMouseButton.new()
	assert_false(MoveTooltip.is_touch_pointer(mouse),
			"a real mouse never long-press-peeks — right click is its verb")

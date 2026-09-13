## CombatScene — the FE7-style side-view stage where an exchange plays out.
## A full-rect Control in the HUD pipeline (mounted into UIManager's overlay
## layer by ScenePresenter): dims the map beneath, draws a placeholder
## backdrop, stands one CombatPuppet per combatant, floats popups over them,
## and shows a PLAYBACK HUD per side. Plan + decisions:
## .claude/todo-archive.md ("Battle animations plan") — D2 (player on the RIGHT, left puppet
## mirrored), D7 (HUD contents, LOCKED 2026-09-07, extended same day):
##   • portrait (HD line art via HDPortraitSlot when the character has it,
##     the pixel portrait otherwise), name, level, the unit's own types;
##   • HP bar with the projected loss of the UPCOMING strike as a pulsing band;
##   • the move with its element + damage-type icons, PP remaining, hit % and
##     the type-matchup multiplier — refreshed on every strike, counters
##     included; the defender's move row reads "—" until it swings;
##   • one buff chip + one debuff chip (the map's slot model), live: a status
##     landing mid-exchange (Bellows stacking off an air hit) updates the chip
##     and floats its name over the puppet, exactly as the map unit does.
## D8 (playback only; the whole-exchange forecast stays in the preview
## panel). Stock widgets until Lawrence's pass.
##
## NOT the map. `battle_scene.gd` is the mission root; this is the cutaway.
##
## Layout is computed in design pixels against the 640×360 core centred in
## whatever the HUD canvas is (phones are wider), so the stage sits at the
## same place on every screen. Every number in the LAYOUT block is an
## eyeball knob (plan §1 "not decisions").
##
## Skip: any press on the stage (mouse/touch via _gui_input, confirm/cancel
## via _unhandled_input) emits skip_requested; ScenePresenter fast-forwards.
## Except while wait_for_press() is parked (DebugConfig.combat_scene_step_pauses):
## then the press emits advance_requested instead and the hint says so.
## The Control stops mouse events, so the map never sees a press meant for
## the stage (InputRouter blocks the world when the HUD consumes).
class_name CombatScene
extends Control


signal skip_requested
## A press while the stage is parked at a debug step-pause (wait_for_press).
signal advance_requested

# --- LAYOUT (design px; eyeball knobs) --------------------------------------
const CORE := Vector2(640, 360)
const PUPPET_SCALE: int = 3          # LOCKED 2026-09-08 (RQD: "perfect"); integer, 2×/4× were the alternatives
# Multiples of PUPPET_SCALE so backdrop art authored at sprite density shares
# the puppets' pixel grid (anchored to the core origin, not the canvas edge).
# Backdrop brief for Lawrence: .claude/todo-archive.md ("Battle animations plan") §7 "Backdrop".
const GROUND_Y: float = 252.0        # feet line inside the core (84 sprite px)
const SKY_BOTTOM: float = 237.0      # horizon: sky ends, floor starts (79 sprite px)
# Puppet SPACING follows the MAP (RQD 2026-09-08): the clips were authored for
# tile spacing — Ernesto's thrust reaches exactly two tiles — so the centres
# sit TILE_SPRITE_PX × distance apart, symmetric about STAGE_CENTRE_X, capped
# at MAX_SPREAD_TILES (128 sprite px; panning/zoom is a later problem, if ever).
# A shove re-spaces the stage with the same rule (respace).
const STAGE_CENTRE_X: float = 321.0  # 107 sprite px — the core's centre rounded onto the 3-px grid
const TILE_SPRITE_PX: int = 32       # one map tile in sprite px: battle_tileset.tres is 32×32 (GridManager's 16 is only its unregistered default — tests, sandbox)
const MAX_SPREAD_TILES: int = 4      # 4 × 32 = 128 sprite px centre-to-centre (RQD's cap)
const PUPPET_SAFE_MARGIN: float = 63.0  # design px a centre keeps from the core's edge (21 sprite px ≈ the widest half-body)
const RESPACE_SECONDS: float = 0.12
# TILE STRIP — the reference the map gives for free: one flat tile per map
# tile from the left puppet's tile to the right's, under the feet line, so
# "two tiles apart" shows the empty tile between them (RQD's screenshot
# 2026-09-09; the stage has no tiles to read distance against). Stand-in
# for Lawrence's floor / the per-unit terrain strip.
const SHOW_TILE_STRIP: bool = true
const TILE_STRIP_HEIGHT: float = 9.0    # design px (3 sprite px) below the feet line
# Authored backdrop (Lawrence's test scene, brief in the plan §7): two PNGs at
# sprite density drawn at PUPPET_SCALE over the palette bands, anchored to the
# core origin so they share the puppets' pixel grid. Absent → bands only.
const BACKDROP_DIRECTORY: String = "res://art/backdrops/combat_test/"
const BACKDROP_SKY_FILE: String = "sky.png"
const BACKDROP_FLOOR_FILE: String = "floor.png"
const BACKDROP_CORE_OFFSET := Vector2(37, 7)  # sprite px from the art's top-left to the core's
const HUD_MARGIN: float = 12.0
const HUD_COLUMN_WIDTH: float = 200.0   # portrait + rows; ends well above the puppets
const HP_BAR_SIZE := Vector2(96, 4)
const HUD_ICON_SIZE := Vector2(10, 10)
const PORTRAIT_SIZE := Vector2(32, 32)  # the preview panel's portrait size
const STATUS_ICON_SIZE := Vector2(6, 6)  # style guide §4: status icons are 6×6
const STATUS_CALLOUT_LIFT: float = 20.0  # clears the damage number spawned in the same beat
const CHIP_FLASH_SECONDS: float = 0.18
const HP_LOSS_PULSE_SECONDS: float = 0.5
const TYPE_ICON_DIRECTORY: String = "res://art/sprites/ui/elemental_type_icons_10x10/"
const SKIP_HINT_TEXT: String = "any button: skip"
const ADVANCE_HINT_TEXT: String = "paused — any button: continue"
const DIM_ALPHA: float = 0.7
const WIPE_STEPS: int = 4
const WIPE_SECONDS: float = 0.25
const SHAKE_MAX_PX: float = 3.0
const SHAKE_PATTERN: Array[Vector2] = [Vector2(1, 0), Vector2(-1, 0.5), Vector2(0.5, -0.5), Vector2.ZERO]
const SHAKE_STEP_SECONDS: float = 0.03

var attacker_unit: Node2D = null
var defender_unit: Node2D = null
var _distance_tiles: int = 1  # the map distance the puppets currently stand for
var _puppets: Dictionary = {}  # unit instance id → CombatPuppet
var _hud_by_unit: Dictionary = {}  # unit instance id → widgets, see hud_for()
var _stage: Control = null
var _puppet_layer: Node2D = null
var _fx_layer: Node2D = null
var _tile_strip: Node2D = null
var _dim: ColorRect = null
var _skip_hint: Label = null
var _awaiting_advance: bool = false


## Can a scene be mounted right now? UIManager must be alive with its
## overlay layer built (it is, in any running game and in headless tests).
static func can_mount() -> bool:
	if not is_instance_valid(UIManager) or not UIManager.is_inside_tree():
		return false
	return UIManager.get_overlay_layer() != null


func _init() -> void:
	name = "CombatScene"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modulate.a = 0.0  # wipe_in reveals

	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0, 0, 0, DIM_ALPHA)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_stage)

	var sky := ColorRect.new()
	sky.name = "Sky"
	sky.color = GameColorPalette.get_color("Azure", 2)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(sky)
	var ground := ColorRect.new()
	ground.name = "Ground"
	ground.color = GameColorPalette.get_color("Gray", 3)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(ground)
	for file_name: String in [BACKDROP_SKY_FILE, BACKDROP_FLOOR_FILE]:
		var path: String = BACKDROP_DIRECTORY + file_name
		if not ResourceLoader.exists(path):
			continue
		var art := TextureRect.new()
		art.name = "Backdrop_" + file_name.get_basename()
		art.texture = load(path) as Texture2D
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(art)  # sky first, floor over it (floor may rise past the horizon)

	_tile_strip = Node2D.new()
	_tile_strip.name = "TileStrip"
	_stage.add_child(_tile_strip)
	_puppet_layer = Node2D.new()
	_puppet_layer.name = "Puppets"
	_stage.add_child(_puppet_layer)
	_fx_layer = Node2D.new()
	_fx_layer.name = "Fx"
	_fx_layer.z_index = 2
	_stage.add_child(_fx_layer)

	_skip_hint = _label(SKIP_HINT_TEXT, 8, GameColors.TEXT_SECONDARY)
	_skip_hint.name = "SkipHint"
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage.add_child(_skip_hint)


func _ready() -> void:
	resized.connect(_layout)
	# The chips are the scene-side twin of Unit._on_status_effect_applied:
	# statuses land deep in the effect pipeline, which knows nothing of
	# presenters, so the stage listens where the map unit listens.
	StatusEffectSystem.status_effect_applied.connect(_on_status_effect_applied)
	StatusEffectSystem.status_effect_removed.connect(_on_status_effect_removed)
	_layout()


func _exit_tree() -> void:
	if StatusEffectSystem.status_effect_applied.is_connected(_on_status_effect_applied):
		StatusEffectSystem.status_effect_applied.disconnect(_on_status_effect_applied)
	if StatusEffectSystem.status_effect_removed.is_connected(_on_status_effect_removed):
		StatusEffectSystem.status_effect_removed.disconnect(_on_status_effect_removed)


## Top-left of the 640×360 core inside this canvas.
func core_origin() -> Vector2:
	return ((size - CORE) / 2.0).floor()


## Centre-to-centre spread (design px) the puppets stand at for a map
## distance: one tile per tile, capped.
static func spread_for(distance_tiles: int) -> float:
	return float(TILE_SPRITE_PX * PUPPET_SCALE * clampi(distance_tiles, 1, MAX_SPREAD_TILES))


## A puppet's centre x inside the core for a map distance (symmetric pair).
static func puppet_x(mirrored: bool, distance_tiles: int) -> float:
	var half: float = spread_for(distance_tiles) / 2.0
	return STAGE_CENTRE_X - half if mirrored else STAGE_CENTRE_X + half


## Map distance between two units (Manhattan, the gameplay range metric);
## 1 for anything without tiles.
static func distance_between(a: Node2D, b: Node2D) -> int:
	if a != null and b != null and a.has_method("attack_delta_tiles"):
		return maxi(1, MapPresenter.attack_distance(a.attack_delta_tiles(b)))
	return 1


func distance_tiles() -> int:
	return _distance_tiles


## Where authored backdrop art sits: its core rectangle lands on the core.
static func backdrop_position(origin: Vector2) -> Vector2:
	return origin - BACKDROP_CORE_OFFSET * PUPPET_SCALE


func _layout() -> void:
	var origin := core_origin()
	var sky: ColorRect = _stage.get_node("Sky")
	var ground: ColorRect = _stage.get_node("Ground")
	sky.position = Vector2(0, 0)
	sky.size = Vector2(size.x, origin.y + SKY_BOTTOM)
	ground.position = Vector2(0, origin.y + SKY_BOTTOM)
	ground.size = Vector2(size.x, maxf(0.0, size.y - ground.position.y))
	for child: Node in _stage.get_children():
		if child is TextureRect and child.name.begins_with("Backdrop_") and child.texture != null:
			child.position = backdrop_position(origin)
			child.size = child.texture.get_size() * PUPPET_SCALE
	for key: Variant in _puppets.keys():
		_place_puppet(_puppets[key])
	_refresh_tile_strip()
	for key: Variant in _hud_by_unit.keys():
		var column: Control = _hud_by_unit[key]["column"]
		var on_right: bool = _hud_by_unit[key]["right"]
		column.position = origin + Vector2(
				CORE.x - HUD_MARGIN - HUD_COLUMN_WIDTH if on_right else HUD_MARGIN, HUD_MARGIN)
	if _skip_hint != null:
		_skip_hint.size = Vector2(CORE.x, 10)
		_skip_hint.position = origin + Vector2(0, CORE.y - HUD_MARGIN - 8)


# =============================================================================
# SETUP
# =============================================================================

## Stand the two combatants. Sides per D2: the PLAYER unit takes the right;
## with no player involved the attacker does. Left puppet is mirrored.
func setup(attacker: Node2D, defender: Node2D, move: Move) -> void:
	assert(is_inside_tree(), "CombatScene.setup before it was mounted")
	attacker_unit = attacker
	defender_unit = defender
	var right_unit: Node2D = attacker
	var left_unit: Node2D = defender
	if attacker.get("faction") != Enums.UnitFaction.PLAYER \
			and defender.get("faction") == Enums.UnitFaction.PLAYER:
		right_unit = defender
		left_unit = attacker
	_distance_tiles = distance_between(attacker, defender)
	_add_puppet(left_unit, true)
	_add_puppet(right_unit, false)
	_refresh_tile_strip()
	_add_hud(left_unit, false)
	_add_hud(right_unit, true)
	show_move(attacker, move)
	_layout()


func _add_puppet(unit: Node2D, mirror: bool) -> void:
	var puppet := CombatPuppet.new()
	puppet.name = "Puppet_%s" % str(unit.get("unit_name"))
	_puppet_layer.add_child(puppet)
	puppet.setup(unit, mirror, PUPPET_SCALE)
	puppet.stage_x = puppet_x(mirror, _distance_tiles)
	_puppets[unit.get_instance_id()] = puppet
	_place_puppet(puppet)


func _place_puppet(puppet: CombatPuppet) -> void:
	puppet.position = _placement(puppet)


func _placement(puppet: CombatPuppet) -> Vector2:
	return (core_origin() + Vector2(puppet.stage_x, GROUND_Y - puppet.feet_drop * PUPPET_SCALE)).round()


## The strip of map tiles the pair spans: tile 0 under the left puppet, the
## last under the right, one per 16 sprite px between (capped spread → capped
## count). Rebuilt on layout and before a re-space so the mover slides onto
## its new tile. Alternating palette shades, a darker seam between tiles.
func _refresh_tile_strip() -> void:
	if _tile_strip == null:
		return
	for child: Node in _tile_strip.get_children():
		_tile_strip.remove_child(child)
		child.queue_free()
	if not SHOW_TILE_STRIP:
		return
	var left: CombatPuppet = null
	var right: CombatPuppet = null
	for puppet: CombatPuppet in _puppets.values():
		if puppet.mirrored:
			left = puppet
		else:
			right = puppet
	if left == null or right == null:
		return
	var tile_px: float = float(TILE_SPRITE_PX * PUPPET_SCALE)
	var count: int = roundi((right.stage_x - left.stage_x) / tile_px) + 1
	var origin := core_origin()
	for index: int in count:
		var tile := ColorRect.new()
		tile.name = "Tile%d" % index
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.color = GameColorPalette.get_color("Gray", 5 if index % 2 == 0 else 4)
		tile.position = (origin + Vector2(left.stage_x - tile_px / 2.0 + index * tile_px, GROUND_Y)).round()
		tile.size = Vector2(tile_px - PUPPET_SCALE, TILE_STRIP_HEIGHT)  # one sprite px of seam
		_tile_strip.add_child(tile)


## Tiles in the strip (tests): distance + 1 while under the cap.
func tile_strip_count() -> int:
	return _tile_strip.get_child_count() if _tile_strip != null else 0


## A shove changed the map distance between the combatants: the stage takes
## the same spacing rule. `mover` (the shoved combatant) travels the whole
## difference; what would carry it past the safe margin goes to the other
## puppet in the opposite direction instead, so the pair never leaves the
## core. null mover (both moved, or neither on stage) → symmetric. Awaitable.
func respace(new_distance: int, mover: Node2D, instant: bool) -> void:
	var left: CombatPuppet = null
	var right: CombatPuppet = null
	for puppet: CombatPuppet in _puppets.values():
		if puppet.mirrored:
			left = puppet
		else:
			right = puppet
	if left == null or right == null:
		return
	var delta: float = spread_for(new_distance) - (right.stage_x - left.stage_x)
	_distance_tiles = new_distance
	if is_zero_approx(delta):
		return
	var mover_puppet: CombatPuppet = puppet_for(mover)
	if mover_puppet == null:
		left.stage_x -= delta / 2.0
		right.stage_x += delta / 2.0
	else:
		var other: CombatPuppet = right if mover_puppet == left else left
		var outward: float = -1.0 if mover_puppet.mirrored else 1.0
		var wanted: float = mover_puppet.stage_x + outward * delta
		var clamped: float = clampf(wanted, PUPPET_SAFE_MARGIN, CORE.x - PUPPET_SAFE_MARGIN)
		mover_puppet.stage_x = clamped
		other.stage_x -= wanted - clamped  # the part that didn't fit, the other way
	_refresh_tile_strip()  # the new tiles are there before anyone slides onto them
	if instant or not Settings.ui_motion_enabled or not is_inside_tree():
		for puppet: CombatPuppet in [left, right]:
			_place_puppet(puppet)
		return
	var tween := create_tween().set_parallel(true)
	for puppet: CombatPuppet in [left, right]:
		tween.tween_property(puppet, "position", _placement(puppet), RESPACE_SECONDS).set_ease(Tween.EASE_OUT)
	await tween.finished


func _add_hud(unit: Node2D, on_right: bool) -> void:
	var character: CharacterData = unit.get("character_data")
	var column := HBoxContainer.new()
	column.name = "HUD_%s" % str(unit.get("unit_name"))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.custom_minimum_size = Vector2(HUD_COLUMN_WIDTH, 0)
	column.add_theme_constant_override("separation", 3)
	_stage.add_child(column)
	var row_alignment: int = BoxContainer.ALIGNMENT_END if on_right else BoxContainer.ALIGNMENT_BEGIN

	# Portrait — on the outer edge. HD line art when the character has it
	# (CharacterPortrait adds an HDPortraitSlot that mirrors the frame into
	# HDLayer), the pixel portrait otherwise. The frame starts hidden: the HD
	# mirror can't follow this Control's modulate, so instead of fading with
	# the wipe it pops in once the stage is fully in and out before it goes.
	var portrait_frame := PanelContainer.new()
	portrait_frame.name = "PortraitFrame"
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	portrait_frame.add_theme_stylebox_override("panel", _frame_style())
	portrait_frame.visible = false
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(portrait)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 3)
	for node: Control in ([rows, portrait_frame] if on_right else [portrait_frame, rows]):
		column.add_child(node)
	# Bound after the frame is in the tree so the HD slot's _ready sees HDLayer.
	CharacterPortrait.bind_to_texture_rect(portrait, character)

	# Row A — name, level, this unit's elemental types.
	var name_row := _row(row_alignment)
	var name_label := _label(str(unit.get("unit_name")), 11, GameColors.TEXT_PRIMARY)
	var level_label := _label("Lv.%d" % (character.level if character != null else 0), 8,
			GameColors.TEXT_SECONDARY)
	var primary_icon := _icon()
	var secondary_icon := _icon()
	if character != null:
		_set_type_icon(primary_icon, character.primary_type)
		_set_type_icon(secondary_icon, character.secondary_type)
	for node: Control in ([secondary_icon, primary_icon, level_label, name_label] if on_right
			else [name_label, level_label, primary_icon, secondary_icon]):
		name_row.add_child(node)
	rows.add_child(name_row)

	# Row B — HP bar: faction fill, a pulsing band for the projected loss of
	# the upcoming strike, empty beyond.
	var bar := Control.new()
	bar.custom_minimum_size = HP_BAR_SIZE
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.size_flags_horizontal = Control.SIZE_SHRINK_END if on_right else Control.SIZE_SHRINK_BEGIN
	var bar_background := _rect(GameColorPalette.get_color("Gray", 1), HP_BAR_SIZE)
	bar.add_child(bar_background)
	var bar_loss := _rect(GameColorPalette.get_color("Gray", 5), Vector2(0, HP_BAR_SIZE.y))
	bar.add_child(bar_loss)
	var is_player: bool = unit.get("faction") == Enums.UnitFaction.PLAYER
	var bar_fill := _rect(GameColors.PLAYER_UNIT if is_player else GameColors.ENEMY_UNIT, HP_BAR_SIZE)
	bar.add_child(bar_fill)
	rows.add_child(bar)

	# Row C — the move being swung: element + damage-type icons, name, PP
	# remaining, hit %, type-matchup multiplier. "—" until this unit strikes.
	var move_row := _row(row_alignment)
	var element_icon := _icon()
	var type_icon := _icon()
	var move_label := _label("—", 8, GameColors.TEXT_SECONDARY)
	var uses_label := _label("", 8, GameColors.TEXT_SECONDARY)
	var hit_label := _label("", 8, GameColors.TEXT_SECONDARY)
	var multiplier_label := _label("", 8, GameColors.TEXT_SECONDARY)
	for node: Control in ([multiplier_label, hit_label, uses_label, move_label, type_icon, element_icon] if on_right
			else [element_icon, type_icon, move_label, uses_label, hit_label, multiplier_label]):
		move_row.add_child(node)
	rows.add_child(move_row)
	element_icon.visible = false
	type_icon.visible = false
	uses_label.visible = false
	multiplier_label.visible = false

	# Row D — status chips: one buff slot + one debuff slot, the map's model
	# (StatusEffectIndicator / unit preview panel). Hidden while empty.
	var status_row := _row(row_alignment)
	status_row.name = "StatusRow"
	status_row.visible = false
	var chips: Dictionary = {}
	for category: Enums.EffectCategory in [Enums.EffectCategory.BUFF, Enums.EffectCategory.DEBUFF]:
		chips[category] = _status_chip(category)
		status_row.add_child(chips[category]["root"])
	rows.add_child(status_row)

	_hud_by_unit[unit.get_instance_id()] = {
		"column": column, "right": on_right, "rows": rows,
		"portrait_frame": portrait_frame, "portrait": portrait,
		"name": name_label, "level": level_label,
		"primary_icon": primary_icon, "secondary_icon": secondary_icon,
		"hp_fill": bar_fill, "hp_loss": bar_loss, "pulse": null,
		"move": move_label, "uses": uses_label, "element_icon": element_icon, "type_icon": type_icon,
		"hit": hit_label, "multiplier": multiplier_label,
		"status_row": status_row, "chips": chips,
	}
	update_hp(unit)
	refresh_statuses(unit)


func _row(alignment: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = alignment
	row.add_theme_constant_override("separation", 3)
	return row


func _rect(color: Color, rect_size: Vector2) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.size = rect_size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _icon() -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = HUD_ICON_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## One status chip: bordered panel > [6×6 icon, abbreviated name in the
## category's semantic ink, stack count]. Filled by refresh_statuses.
func _status_chip(category: Enums.EffectCategory) -> Dictionary:
	var root := PanelContainer.new()
	root.name = "BuffChip" if category == Enums.EffectCategory.BUFF else "DebuffChip"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_stylebox_override("panel", _chip_style())
	root.visible = false
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	root.add_child(box)
	var icon := _icon()
	icon.custom_minimum_size = STATUS_ICON_SIZE
	var name_label := _label("", 8, status_chip_ink(category))
	var stacks_label := _label("", 8, GameColors.TEXT_PRIMARY)
	for node: Control in [icon, name_label, stacks_label]:
		box.add_child(node)
	return {"root": root, "icon": icon, "name": name_label, "stacks": stacks_label}


## Buffs in the success green, debuffs in the danger red — the same pairing
## the map's status callout uses (ui-style-guide §3), NOT element ink.
static func status_chip_ink(category: Enums.EffectCategory) -> Color:
	return GameColors.TEXT_SUCCESS if category == Enums.EffectCategory.BUFF else GameColors.TEXT_DANGER


## The preview panel's portrait frame: 1px border, rounded 2, translucent well.
static func _frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(GameColorPalette.get_color("Gray", 1), 0.6)
	style.border_color = GameColorPalette.get_color("Gray", 6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(1)
	return style


## Status chip well: style guide §4 — HUD chip borders are 1px, rounded 2.
static func _chip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = GameColorPalette.get_color("Gray", 1)
	style.border_color = GameColorPalette.get_color("Gray", 4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	return style


func _label(text: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	var font: FontFile = UIManager.font_11px if size_px >= 11 else UIManager.font_8px
	if font != null:
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", size_px)
	return label


static func _set_type_icon(icon: TextureRect, element_type: Enums.ElementalType) -> void:
	icon.visible = false
	if element_type == Enums.ElementalType.NONE:
		return
	var path: String = TYPE_ICON_DIRECTORY + Enums.elemental_type_to_string(element_type).to_lower() + ".png"
	if ResourceLoader.exists(path):
		icon.texture = load(path) as Texture2D
		icon.visible = true


static func _set_damage_type_icon(icon: TextureRect, damage_type: Enums.DamageType) -> void:
	icon.visible = false
	var path: String = Enums.get_damage_type_icon(damage_type)
	if path != "" and ResourceLoader.exists(path):
		icon.texture = load(path) as Texture2D
		icon.visible = true


## "×2" / "×½" style text for a type multiplier; "" for neutral.
static func format_multiplier(effectiveness: float) -> String:
	if is_equal_approx(effectiveness, 1.0):
		return ""
	if is_equal_approx(effectiveness, 0.5):
		return "×½"
	if is_equal_approx(effectiveness, 0.25):
		return "×¼"
	if is_equal_approx(effectiveness, roundf(effectiveness)):
		return "×%d" % int(roundf(effectiveness))
	return "×%.2f" % effectiveness


# =============================================================================
# QUERIES
# =============================================================================

func puppet_for(unit: Node2D) -> CombatPuppet:
	if unit == null:
		return null
	return _puppets.get(unit.get_instance_id(), null)


func puppets() -> Array:
	return _puppets.values()


## The HUD widgets for a unit (tests + presenter): column, right, rows,
## portrait_frame, portrait, name, level, primary_icon, secondary_icon,
## hp_fill, hp_loss, pulse, move, uses, element_icon, type_icon, hit,
## multiplier, status_row, chips (EffectCategory → {root, icon, name,
## stacks}). Empty when the unit isn't on stage.
func hud_for(unit: Node2D) -> Dictionary:
	if unit == null:
		return {}
	return _hud_by_unit.get(unit.get_instance_id(), {})


# =============================================================================
# HUD
# =============================================================================

## The move row without numbers (open: the attacker's move is known before
## anything is rolled).
func show_move(unit: Node2D, move: Move) -> void:
	var hud: Dictionary = hud_for(unit)
	if hud.is_empty() or move == null:
		return
	var label: Label = hud["move"]
	label.text = move.move_name
	var ink: Color = GameColors.get_move_chip_foreground(move.element_type) \
			if move.element_type != Enums.ElementalType.NONE else GameColors.TEXT_SECONDARY
	label.add_theme_color_override("font_color", ink)
	_set_type_icon(hud["element_icon"], move.element_type)
	_set_damage_type_icon(hud["type_icon"], move.damage_type)
	_refresh_uses(hud, move)


## "4/5" — the attacker pays PP before hit 1 and the defender right before its
## counter swings, so by the time show_strike runs the number is post-spend;
## at open (show_move) it is still the pre-spend count. Hidden for moves
## without a PP pool (max_uses 0: Move.EMPTY, struggle-style basics).
func _refresh_uses(hud: Dictionary, move: Move) -> void:
	var uses: Label = hud["uses"]
	uses.visible = move != null and move.max_uses > 0
	if uses.visible:
		uses.text = "%d/%d" % [move.current_uses, move.max_uses]


## A strike is about to happen: the actor's row shows the move, its hit %
## and the type multiplier against `target`; the target's bar shows the
## projected loss of THIS strike as a pulsing band (before the roll — a crit
## drains past it, a miss clears it).
func show_strike(actor: Node2D, target: Node2D, move: Move) -> void:
	show_move(actor, move)
	var hud: Dictionary = hud_for(actor)
	if hud.is_empty() or move == null:
		return
	var hit_label: Label = hud["hit"]
	hit_label.text = "%d%%" % DamageCalculator.hit_chance_pct(actor, target, move)
	var effectiveness: float = DamageCalculator.get_type_effectiveness(actor, target, move)
	var multiplier_label: Label = hud["multiplier"]
	multiplier_label.text = format_multiplier(effectiveness)
	multiplier_label.visible = multiplier_label.text != ""
	multiplier_label.add_theme_color_override("font_color", GameColors.get_effectiveness_color(effectiveness))
	if move.heals:
		clear_projection(target)
	else:
		set_projection(target, DamageCalculator.calculate_damage(actor, target, move))


## The pulsing band: from (current − projected) to current HP.
func set_projection(unit: Node2D, projected_damage: int) -> void:
	var hud: Dictionary = hud_for(unit)
	if hud.is_empty():
		return
	var max_hp: int = _max_hp(unit)
	var current: int = int(unit.get("current_hp"))
	var remaining: int = clampi(current - projected_damage, 0, max_hp)
	var fill: ColorRect = hud["hp_fill"]
	var loss: ColorRect = hud["hp_loss"]
	fill.size.x = roundf(HP_BAR_SIZE.x * float(remaining) / float(max_hp))
	loss.position.x = fill.size.x
	loss.size.x = roundf(HP_BAR_SIZE.x * float(current) / float(max_hp)) - fill.size.x
	loss.modulate.a = 1.0
	_stop_pulse(hud)
	if Settings.ui_motion_enabled and is_inside_tree() and loss.size.x > 0.0:
		var pulse := create_tween().set_loops()
		pulse.tween_property(loss, "modulate:a", 0.35, HP_LOSS_PULSE_SECONDS)
		pulse.tween_property(loss, "modulate:a", 1.0, HP_LOSS_PULSE_SECONDS)
		hud["pulse"] = pulse


func clear_projection(unit: Node2D) -> void:
	var hud: Dictionary = hud_for(unit)
	if hud.is_empty():
		return
	_stop_pulse(hud)
	var loss: ColorRect = hud["hp_loss"]
	loss.size.x = 0.0
	loss.modulate.a = 1.0


## The bar catches up with the unit's real HP; any projection is spent.
func update_hp(unit: Node2D) -> void:
	var hud: Dictionary = hud_for(unit)
	if hud.is_empty():
		return
	clear_projection(unit)
	var fraction: float = clampf(float(unit.get("current_hp")) / float(_max_hp(unit)), 0.0, 1.0)
	var fill: ColorRect = hud["hp_fill"]
	fill.size.x = roundf(HP_BAR_SIZE.x * fraction)


func _stop_pulse(hud: Dictionary) -> void:
	var pulse: Tween = hud.get("pulse", null)
	if pulse != null and pulse.is_valid():
		pulse.kill()
	hud["pulse"] = null


static func _max_hp(unit: Node2D) -> int:
	var character: CharacterData = unit.get("character_data")
	return maxi(1, character.max_hp if character != null else 1)


# =============================================================================
# STATUS CHIPS
# =============================================================================

## Repaint the chip row from the unit's live active_status_effects: first
## buff → buff chip, first debuff → debuff chip (the slot model the map's
## indicator and the preview panel share). Icon from the effect's config,
## abbreviated name, stack count.
func refresh_statuses(unit: Node2D) -> void:
	var hud: Dictionary = hud_for(unit)
	if hud.is_empty():
		return
	var effects: Variant = unit.get("active_status_effects")
	var configs: Dictionary = StatusEffectData.get_default_configs()
	var slotted: Dictionary = {Enums.EffectCategory.BUFF: null, Enums.EffectCategory.DEBUFF: null}
	if effects is Array:
		for entry: Variant in effects:
			if entry is StatusEffect and slotted.get(entry.category, null) == null:
				slotted[entry.category] = entry
	var any_visible := false
	for category: Enums.EffectCategory in slotted.keys():
		var chip: Dictionary = hud["chips"][category]
		var effect: StatusEffect = slotted[category]
		var root: Control = chip["root"]
		root.visible = effect != null
		if effect == null:
			continue
		any_visible = true
		var config: StatusEffectData = configs.get(effect.effect_type_name, null)
		var icon: TextureRect = chip["icon"]
		icon.visible = false
		if config != null and config.icon_path != "" and ResourceLoader.exists(config.icon_path):
			icon.texture = load(config.icon_path) as Texture2D
			icon.visible = true
		(chip["name"] as Label).text = config.abbrev_name if config != null and config.abbrev_name != "" \
				else effect.effect_type_name.capitalize()
		(chip["stacks"] as Label).text = str(effect.stacks)
	(hud["status_row"] as Control).visible = any_visible


## A status landed on someone on stage (new or restacked): repaint, flash the
## chip, and float its name over the puppet in the category's ink — "BURN" /
## "BELLOWS ×2", the same words the map unit floats underneath.
func _on_status_effect_applied(unit: Node2D, effect_type_name: String) -> void:
	var hud: Dictionary = hud_for(unit)
	if hud.is_empty():
		return
	refresh_statuses(unit)
	var config: StatusEffectData = StatusEffectData.get_default_configs().get(effect_type_name, null)
	var category: Enums.EffectCategory = config.category if config != null else Enums.EffectCategory.DEBUFF
	var label: String = config.abbrev_name if config != null and config.abbrev_name != "" \
			else effect_type_name.capitalize()
	var stacks: int = StatusEffectSystem.get_effect_stacks(unit, effect_type_name)
	var ink: Color = status_chip_ink(category)
	spawn_popup(unit, func(popup: Node) -> void:
		popup.call("initialize_callout", Unit.status_callout_text(label, stacks), ink), STATUS_CALLOUT_LIFT)
	_flash_chip(hud["chips"][category]["root"])


func _on_status_effect_removed(unit: Node2D, _effect_type_name: String) -> void:
	refresh_statuses(unit)


## "This one just changed" — a brief overbright on the chip, tween owned by
## the scene so a quick unmount takes it along.
func _flash_chip(chip: Control) -> void:
	if not Settings.ui_motion_enabled or not is_inside_tree() or not chip.visible:
		return
	chip.modulate = Color(2.0, 2.0, 2.0, 1.0)
	create_tween().tween_property(chip, "modulate", Color.WHITE, CHIP_FLASH_SECONDS)


# =============================================================================
# FX
# =============================================================================

## Host a DamagePopup over `unit`'s puppet. `configure` receives the popup
## (call initialize / initialize_heal / initialize_callout).
func spawn_popup(unit: Node2D, configure: Callable, lift: float = 0.0) -> void:
	var puppet := puppet_for(unit)
	if puppet == null:
		return
	var popup: Node2D = (preload("res://scenes/ui/damage_popup.tscn") as PackedScene).instantiate()
	# Position BEFORE add_child: DamagePopup._ready anchors its rise to it.
	popup.position = puppet.head_position() + Vector2(0.0, -lift)
	_fx_layer.add_child(popup)
	configure.call(popup)


## Stage shake in whole pixels, stepped. Nothing under reduce-motion.
func shake(impact_weight: float) -> void:
	if not Settings.ui_motion_enabled or not is_inside_tree():
		return
	var amplitude: float = maxf(1.0, roundf(SHAKE_MAX_PX * clampf(impact_weight, 0.0, 1.0)))
	for step: Vector2 in SHAKE_PATTERN:
		_stage.position = (step * amplitude).round()
		await get_tree().create_timer(SHAKE_STEP_SECONDS).timeout
	_stage.position = Vector2.ZERO


## Stepped reveal / conceal. Instant under skip or reduce-motion.
func wipe_in(instant: bool) -> void:
	await _wipe(0.0, 1.0, instant)


func wipe_out(instant: bool) -> void:
	await _wipe(1.0, 0.0, instant)


## The portrait frames pop out before a conceal and in after a reveal — the
## HD mirrors in HDLayer can't follow this Control's modulate.
func _wipe(from_alpha: float, to_alpha: float, instant: bool) -> void:
	var revealing: bool = to_alpha > from_alpha
	if not revealing:
		_set_portraits_visible(false)
	if instant or not Settings.ui_motion_enabled or not is_inside_tree():
		modulate.a = to_alpha
	else:
		for step: int in range(1, WIPE_STEPS + 1):
			modulate.a = lerpf(from_alpha, to_alpha, float(step) / WIPE_STEPS)
			await get_tree().create_timer(WIPE_SECONDS / WIPE_STEPS).timeout
	if revealing and is_inside_tree():
		_set_portraits_visible(true)


func _set_portraits_visible(shown: bool) -> void:
	for key: Variant in _hud_by_unit.keys():
		var frame: Control = _hud_by_unit[key]["portrait_frame"]
		if is_instance_valid(frame):
			frame.visible = shown


# =============================================================================
# INPUT — any press skips (or advances, at a debug step-pause)
# =============================================================================

## Debug step-pause (DebugConfig.combat_scene_step_pauses): park the stage
## until the player presses, so it can be examined indefinitely. While parked
## a press ADVANCES instead of skipping, and the hint reads accordingly.
func wait_for_press() -> void:
	_awaiting_advance = true
	if _skip_hint != null:
		_skip_hint.text = ADVANCE_HINT_TEXT
	await advance_requested
	_awaiting_advance = false
	if is_instance_valid(_skip_hint):
		_skip_hint.text = SKIP_HINT_TEXT


func is_waiting_for_press() -> bool:
	return _awaiting_advance


func _on_press() -> void:
	if _awaiting_advance:
		advance_requested.emit()
	else:
		skip_requested.emit()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		_on_press()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_on_press()
		get_viewport().set_input_as_handled()

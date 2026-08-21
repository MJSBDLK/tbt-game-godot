## THE HINT / COMMAND BAR — the battle HUD's "what can I do right now" strip.
##
## Renders HintBarCommands for the current InputState under the interaction
## model sampled at the last boundary: [glyph] verb pairs for controller and
## keyboard/mouse, REAL BUTTONS for touch (a phone has no key to hint about —
## the bar IS the way to End turn / open the Menu / toggle Threat zones).
## Plus a step line ("Select a unit") in the Info voice.
##
## BAREBONES SCAFFOLD (RQD's UI work order): stock Labels/Buttons, no sprite
## art, no border vocabulary yet. Contents + behavior first; Lawrence's visual
## pass comes after RQD eyeballs it. Mockup with the layout variants:
## data/design/mockups/battle-hud-mockup.html (RQD picked bottom corners with
## a corner inset — their phone drops touches in the far corners and the
## rounded screen clips there).
##
## Sampling doctrine (InputSource): the bar re-renders at BOUNDARIES —
## state change, phase change, battle start/end, settings change — and reads
## InputSource.last_device THEN. It never subscribes to raw input, so glyphs
## can't flicker mid-frame when someone nudges a mouse. Cost: pick up the
## controller mid-state and the glyphs swap at the next state change, not
## instantly. Deliberate.
##
## Touch buttons fire the SAME InputMap action the key would, via
## Input.parse_input_event(InputEventAction) — so InputManager, the threat
## controller, the menus all react exactly as to a keypress. Zero new code
## paths in the consumers. `action_requested` is emitted first so tests (and
## analytics later) can observe the press without the Input pipeline.
##
## Visibility: only in a live battle and only while Settings.show_control_hints.
## "Live battle" = any TurnManager phase signal since the last battle_ended /
## scene swap — NOT battle_started alone: a save resumes through
## TurnManager.resume_battle, which deliberately skips battle_started (it
## would re-run upkeep) and emits only player_phase_started. Found on F5
## 2026-08-20: bar invisible after Continue. Within a battle the
## bar HIDES ITSELF whenever it has nothing to say (no step, no items — the
## pause menu, the result screens).
##
## Lives under UIManager's MainLayout (HUDViewport design canvas), full-rect;
## positions its own row at the bottom. Mounted by UIManager._instantiate_panels.
class_name HintBar
extends Control


## Observed by tests; fired before the action is injected into Input.
signal action_requested(action: StringName)

## Mockup placements. Both put the step text bottom-left and the items
## bottom-right; CORNERS keeps them `corner_inset` px off the screen edges
## (rounded corners / touch-dead margins), FULL_WIDTH runs edge to edge.
## Visually one row either way in the scaffold — the glass boxes per cluster
## are Lawrence's pass.
enum Placement { CORNERS, FULL_WIDTH }

## Mockup defaults (round 2). Change here, not in the scene.
@export var placement: Placement = Placement.CORNERS:
	set(value):
		placement = value
		_apply_layout()
## Distance from the screen edges under CORNERS. The safe-area inset (notch,
## home indicator) is a SEPARATE, additive concern for the phone build.
@export var corner_inset: int = 12:
	set(value):
		corner_inset = value
		_apply_layout()
## Row height for [glyph] verb rendering (8 px text + 3 px padding top/bottom).
@export var bar_height: int = 14:
	set(value):
		bar_height = value
		_apply_layout()
## Touch button height — the mockup's middle option. The phone physical-size
## question (7 mm ≈ 40 canvas px at 3×) is still RQD's to settle; this is the
## one number to move when it is.
@export var touch_button_height: int = 24:
	set(value):
		touch_button_height = value
		_apply_layout()

## True from the first TurnManager phase/battle signal until battle_ended / a
## scene swap. Public so tests can set it directly.
var battle_active: bool = false
## True between enemy_phase_started and the next player_phase_started.
var enemy_phase: bool = false

## The model the last refresh rendered for — readable by tests and by the
## future visual pass (corner clusters look different under touch).
var last_model: HintBarCommands.Model = HintBarCommands.Model.KEYBOARD_MOUSE

var _row: HBoxContainer = null
var _step_label: GlowLabel = null
var _spacer: Control = null
var _items_box: HBoxContainer = null


func _ready() -> void:
	name = "HintBar" if name.is_empty() else name
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_connect_boundaries()
	refresh()


func _build() -> void:
	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 8)
	add_child(_row)

	var font: FontFile = UIManager.font_8px if UIManager != null else null
	_step_label = GlowLabel.styled("", font, 8, GameColors.TEXT_INFO, GameColors.TEXT_INFO_GLOW)
	_step_label.name = "Step"
	_step_label.uppercase = true
	_step_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_row.add_child(_step_label)

	_spacer = Control.new()
	_spacer.name = "Spacer"
	_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(_spacer)

	_items_box = HBoxContainer.new()
	_items_box.name = "Items"
	_items_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_items_box.add_theme_constant_override("separation", 8)
	_items_box.alignment = BoxContainer.ALIGNMENT_END
	_row.add_child(_items_box)

	assert(_row != null and _step_label != null and _items_box != null,
			"HintBar: scaffold failed to build")
	_apply_layout()


## Boundaries the bar re-samples at. Every hookup is guarded so the bar can
## be instanced in tests (autoloads present) or in isolation (absent).
func _connect_boundaries() -> void:
	var state_manager: Node = get_node_or_null("/root/GameStateManager")
	if state_manager != null:
		state_manager.state_changed.connect(_on_state_changed)
	var turn_manager: Node = get_node_or_null("/root/TurnManager")
	if turn_manager != null:
		turn_manager.battle_started.connect(_on_battle_started)
		turn_manager.battle_ended.connect(_on_battle_ended)
		turn_manager.player_phase_started.connect(_on_player_phase_started)
		turn_manager.enemy_phase_started.connect(_on_enemy_phase_started)
	var settings: Node = get_node_or_null("/root/Settings")
	if settings != null:
		settings.changed.connect(refresh)
	var scene_router: Node = get_node_or_null("/root/SceneRouter")
	if scene_router != null and scene_router.has_signal("scene_changed"):
		scene_router.scene_changed.connect(_on_scene_changed)


# =============================================================================
# RENDER
# =============================================================================

## Re-samples state + model and rebuilds the row. Safe to call any time; this
## IS the boundary (everything routes through here).
func refresh() -> void:
	if _row == null:
		return
	var model := _sample_model()
	last_model = model
	var state: Enums.InputState = Enums.InputState.DEFAULT
	var state_manager: Node = get_node_or_null("/root/GameStateManager")
	if state_manager != null:
		state = state_manager.current_state

	_step_label.text = HintBarCommands.step_text_for(state, model, enemy_phase)
	_step_label.visible = not _step_label.text.is_empty()

	_clear_items()
	var entries: Array[Dictionary] = HintBarCommands.resolve(state, model, enemy_phase)
	for entry: Dictionary in entries:
		_items_box.add_child(_make_item(entry, model))

	_apply_layout()
	visible = _should_show() and (_step_label.visible or not entries.is_empty())


func _should_show() -> bool:
	var settings: Node = get_node_or_null("/root/Settings")
	if settings != null and not settings.show_control_hints:
		return false
	return battle_active


## Which rendering to use — from InputSource's debounced last_device, or the
## dev override (DebugConfig.debug_force_touch_hints: eyeball the touch bar on
## a desktop without a phone).
func _sample_model() -> HintBarCommands.Model:
	var debug_config: Node = get_node_or_null("/root/DebugConfig")
	if debug_config != null and debug_config.get("debug_force_touch_hints") == true:
		return HintBarCommands.Model.TOUCH
	var input_source: Node = get_node_or_null("/root/InputSource")
	if input_source == null:
		return HintBarCommands.Model.KEYBOARD_MOUSE
	if input_source.last_device == input_source.Device.JOYPAD:
		return HintBarCommands.Model.CONTROLLER
	if input_source.last_device == input_source.Device.TOUCH:
		return HintBarCommands.Model.TOUCH
	return HintBarCommands.Model.KEYBOARD_MOUSE


func _clear_items() -> void:
	for child: Node in _items_box.get_children():
		_items_box.remove_child(child)
		child.queue_free()


## One item: a real Button under TOUCH, a [glyph] verb pair otherwise.
func _make_item(entry: Dictionary, model: HintBarCommands.Model) -> Control:
	if model == HintBarCommands.Model.TOUCH:
		var button := Button.new()
		button.name = "Touch_%s" % String(entry.action)
		button.text = String(entry.glyph)
		button.custom_minimum_size = Vector2(0, touch_button_height)
		# Taps must not move keyboard/controller focus (the menus own focus);
		# and the button must CONSUME the press so the world never also gets
		# the click underneath (InputRouter: HUD-handled → blocked at root).
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.pressed.connect(_on_touch_pressed.bind(entry.action))
		return button

	var pair := HBoxContainer.new()
	pair.name = "Item_%s" % String(entry.action)
	pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pair.add_theme_constant_override("separation", 3)
	var font: FontFile = UIManager.font_8px if UIManager != null else null
	# Glyph chip: bracketed text for the scaffold ("[A]", "[LMB]"). The visual
	# pass replaces this with a drawn chip / real button-glyph art.
	var glyph := GlowLabel.styled("[%s]" % String(entry.glyph), font, 8,
			GameColors.TEXT_PRIMARY, GameColors.TEXT_PRIMARY_GLOW)
	glyph.name = "Glyph"
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pair.add_child(glyph)
	var verb := GlowLabel.styled(String(entry.verb), font, 8,
			GameColors.TEXT_PRIMARY, GameColors.TEXT_PRIMARY_GLOW)
	verb.name = "Verb"
	verb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pair.add_child(verb)
	return pair


## Row geometry for the current placement / model. Anchored to the bottom of
## the canvas; CORNERS keeps `corner_inset` off every edge.
func _apply_layout() -> void:
	if _row == null:
		return
	var inset: int = corner_inset if placement == Placement.CORNERS else 0
	var row_height: int = bar_height
	if last_model == HintBarCommands.Model.TOUCH:
		row_height = touch_button_height + 4
	_row.anchor_left = 0.0
	_row.anchor_right = 1.0
	_row.anchor_top = 1.0
	_row.anchor_bottom = 1.0
	_row.offset_left = inset
	_row.offset_right = -inset
	_row.offset_top = -(row_height + inset)
	_row.offset_bottom = -inset
	_row.custom_minimum_size = Vector2(0, row_height)


# =============================================================================
# TOUCH → ACTION
# =============================================================================

## A touch button fires its action through the normal input pipeline: press +
## release, exactly what the bound key would produce. Consumers don't know
## the difference. The release keeps Input's action state clean.
func _on_touch_pressed(action: StringName) -> void:
	action_requested.emit(action)
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)


# =============================================================================
# BOUNDARIES
# =============================================================================

func _on_state_changed(_old_state: Enums.InputState, _new_state: Enums.InputState) -> void:
	refresh()


func _on_battle_started(_player_units: Array[Unit]) -> void:
	battle_active = true
	enemy_phase = false
	refresh()


func _on_battle_ended(_is_victory: bool) -> void:
	battle_active = false
	refresh()


## Phase signals also ARM the bar: a resumed save never emits battle_started
## (TurnManager.resume_battle), but every battle — fresh or resumed — starts a
## phase.
func _on_player_phase_started(_turn_count: int) -> void:
	battle_active = true
	enemy_phase = false
	refresh()


func _on_enemy_phase_started() -> void:
	battle_active = true
	enemy_phase = true
	refresh()


## Leaving for a non-battle scene (main menu, intermission) disarms the bar.
## A BATTLE scene must NOT: SceneRouter emits scene_changed AFTER add_child
## returns, and BattleScene._ready starts/resumes the battle synchronously in
## there — so TurnManager's arming signal has already fired by the time this
## runs. Disarming here hid the bar on every battle entry (F5 2026-08-20).
func _on_scene_changed(scene: Node) -> void:
	if scene is BattleScene:
		refresh()
		return
	battle_active = false
	enemy_phase = false
	refresh()

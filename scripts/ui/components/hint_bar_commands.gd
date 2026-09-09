## THE HINT / COMMAND BAR'S SINGLE SOURCE OF TRUTH.
##
## Which actions each InputState advertises, in what order, with what verb —
## and how to NAME the button that triggers each one under the interaction
## model the bar sampled. Pure data + lookups, no nodes: HintBar renders it,
## tests pin it, the mockup (data/design/mockups/battle-hud-mockup.html) is
## its picture.
##
## Why it exists (playtest ask + mobile, RQD 2026-08-16): playtesters wanted
## on-screen "what are the useful functions" hints. On a phone that isn't a
## hint — end_turn / unit_info / toggle_threat_zones / menu have no gesture,
## so under TOUCH the bar's items ARE the control surface (real buttons that
## fire the same actions the keys would). One table, three renderings.
##
## Rules baked in here:
##   - The bar never stores a glyph. Each item names an InputMap ACTION and the
##     glyph is resolved from that action's CURRENT bindings at sample time
##     (glyph_for). A rebind shows the new key; an unbound action drops out of
##     the bar. RQD: "I hate it when it's rebound and shows the default."
##   - At most MAX_ITEMS_PER_STATE items per state — the bar teaches, it
##     doesn't enumerate. Camera, tooltip peek, unit cycling are deliberately
##     absent.
##   - UNIT_SELECTED and MOVEMENT_PLANNING teach the waypoint mechanic ONE
##     CLICK AT A TIME (RQD 2026-08-21: "what I just said was overwhelming").
##     The first click in range doesn't move — it plots a path and flips the
##     state to MOVEMENT_PLANNING; the marker it leaves is the explanation, and
##     the next step line says what the marker is for ("select it again to
##     move"). No sentence ever describes the whole system.
##   - Enemy phase is not an InputState — the turn owner flips — so it's a
##     flag on the lookups: step text only, no items.
##   - Model is sampled at state boundaries (InputSource doctrine), never live.
##     HintBar picks the Model from InputSource.last_device.
##
## Controller "support" (RQD's question, 2026-08-20): Godot normalizes every
## pad through SDL's gamecontroller DB into one virtual Xbox-layout pad; Steam
## Input presents as XInput too. So bindings are ONE set and the only
## per-controller difference is glyph SKIN — which is a lookup on the joypad's
## reported name (joy_skin_for_name). No native Steam Input API in v1.
class_name HintBarCommands
extends RefCounted


## The interaction model the bar renders for. CONTROLLER and KEYBOARD_MOUSE
## show [glyph] verb pairs; TOUCH shows real buttons (items without a
## touch_label are map gestures — tap the map — and have no button).
enum Model { CONTROLLER, KEYBOARD_MOUSE, TOUCH }

## Glyph skin for controller labels. Picked from the joypad's reported name;
## XBOX is the fallback (and what Steam Input reports). Steam Deck's own
## buttons are Xbox layout but its shoulders are labeled L1/R1, not LB/RB.
enum JoySkin { XBOX, STEAM_DECK, PLAYSTATION, NINTENDO }

## Ceiling per state — mockup round 1 decision.
const MAX_ITEMS_PER_STATE: int = 5

## Step text when the enemy owns the turn (no InputState for it).
const ENEMY_PHASE_STEP: String = "Enemy phase"

## Test hook: force a skin instead of reading the connected joypad's name.
## -1 = read the real pad.
static var joy_skin_override: int = -1

## Per-state table — built once, lazily (enum keys aren't constant
## expressions a `const` dictionary will accept on every GDScript version).
##
## Entry keys:
##   step        String  — the instruction under controller/kb
##   step_touch  String  — the instruction under touch ("Tap a unit")
##   step_notice   bool   — OPTIONAL: the step line wears the §14 NOTICE border
##                          (violet, static: "the game is pointing at this, it
##                          is not a button") so a changed instruction registers.
##   confirm_label String — OPTIONAL: under Settings.move_confirm_mode BUTTON
##                          the step cluster is instead a pressable button with
##                          this label (parked-gold CTA) whose press confirms
##                          the plan (InputManager.confirm_planned_movement).
##   items       Array   — ordered item dictionaries:
##     action        StringName — InputMap action; glyph resolved at sample time
##     verb          String     — the per-button label ("Select", "End turn")
##     mouse_button  int        — OPTIONAL: under KEYBOARD_MOUSE this is a map
##                                gesture (a click), not a key — show the mouse
##                                glyph instead of resolving a key
##     touch_label   String     — OPTIONAL: under TOUCH the item is a real
##                                button with this label; absent = no button
static var _table: Dictionary = {}


static func _ensure_table() -> void:
	if not _table.is_empty():
		return
	_table = {
		Enums.InputState.DEFAULT: {
			step = "Select a unit", step_touch = "Tap a unit",
			items = [
				{action = &"ui_accept", verb = "Select", mouse_button = MOUSE_BUTTON_LEFT},
				{action = &"unit_info", verb = "Unit info"},
				{action = &"end_turn", verb = "End turn", touch_label = "End turn"},
				{action = &"toggle_threat_zones", verb = "Threat zones", touch_label = "Threat"},
				# Esc / B opens the system menu from DEFAULT (InputManager._handle_escape).
				{action = &"ui_cancel", verb = "Menu", touch_label = "Menu"},
			],
		},
		# No waypoint yet. The first press in range PLOTS a path (it does not
		# move) — see InputManager._handle_movement_planning_press.
		Enums.InputState.UNIT_SELECTED: {
			step = "Choose a destination", step_touch = "Tap a destination",
			items = [
				{action = &"ui_accept", verb = "Plot path", mouse_button = MOUSE_BUTTON_LEFT},
				{action = &"ui_cancel", verb = "Cancel", mouse_button = MOUSE_BUTTON_RIGHT, touch_label = "Cancel"},
				{action = &"unit_info", verb = "Unit info", touch_label = "Unit info"},
			],
		},
		# A marker is on the board. Pressing IT moves; pressing elsewhere in
		# range adds a stop. One button, so the step line carries the "go" half
		# — and wears the NOTICE border so the change from "Choose a
		# destination" registers (RQD 2026-08-21: "most players won't notice
		# the text has changed"). Not the traveling border (= selection, and
		# the unit already holds it), not the amber rings (= the only thing
		# left to do), not pressable (a lit border would promise a press).
		# Under Settings.move_confirm_mode BUTTON the cluster is a "Move here"
		# button instead — the playtest alternative.
		# Under Settings.move_commit_mode ACT_THEN_WALK the press doesn't walk
		# — it stages the plan (ghost holds the spot, the unit moves when the
		# action commits), so the copy must not promise movement (the *_act
		# keys; step_text_for/confirm_label_for pick them when the flag says).
		Enums.InputState.MOVEMENT_PLANNING: {
			step = "Select the marker again to move", step_touch = "Tap the marker again to move",
			step_act = "Select the marker again to confirm", step_touch_act = "Tap the marker again to confirm",
			step_notice = true, confirm_label = "Move here", confirm_label_act = "Confirm path",
			items = [
				{action = &"ui_accept", verb = "Add stop", mouse_button = MOUSE_BUTTON_LEFT},
				{action = &"ui_cancel", verb = "Cancel", mouse_button = MOUSE_BUTTON_RIGHT, touch_label = "Cancel"},
				{action = &"unit_info", verb = "Unit info", touch_label = "Unit info"},
			],
		},
		Enums.InputState.ACTION_MENU_OPEN: {
			step = "Choose an action", step_touch = "Tap an action",
			items = [
				{action = &"ui_accept", verb = "Confirm", mouse_button = MOUSE_BUTTON_LEFT},
				{action = &"ui_cancel", verb = "Back", mouse_button = MOUSE_BUTTON_RIGHT, touch_label = "Back"},
			],
		},
		Enums.InputState.ATTACK_TARGETING: {
			step = "Choose a target", step_touch = "Tap a target",
			items = [
				{action = &"ui_accept", verb = "Attack", mouse_button = MOUSE_BUTTON_LEFT},
				{action = &"ui_cancel", verb = "Back", mouse_button = MOUSE_BUTTON_RIGHT, touch_label = "Back"},
			],
		},
		Enums.InputState.UNIT_DETAIL: {
			step = "", step_touch = "",
			items = [
				{action = &"ui_cancel", verb = "Close", touch_label = "Close"},
			],
		},
		# The mid-battle level-up reveal (LevelUpStatPanel) holds until the
		# player presses — one verb, no step (the panel IS the step). It shows
		# in BOTH phases: an enemy's hit can level our defender, and the bar
		# must still say how to move on (phase_blind — see items_for).
		Enums.InputState.LEVEL_UP_CELEBRATION: {
			step = "", step_touch = "", phase_blind = true,
			items = [
				{action = &"ui_accept", verb = "Continue", mouse_button = MOUSE_BUTTON_LEFT, touch_label = "Continue"},
			],
		},
		# PAUSED / DIALOGUE / BATTLE_RESULT / POST_MISSION_REPORT / RECRUITING:
		# absent on purpose — those screens carry their own affordances and the
		# bar has nothing to say, so it hides (HintBar hides when step + items
		# are both empty).
	}


## The InputStates the bar has anything to say in.
static func states_with_entries() -> Array:
	_ensure_table()
	return _table.keys()


## Raw (unresolved) items for a state — the table row. Empty for states the
## bar doesn't speak in, and during the enemy phase.
static func items_for(state: Enums.InputState, enemy_phase: bool = false) -> Array:
	_ensure_table()
	if not _table.has(state):
		return []
	if enemy_phase and not _phase_blind(state):
		return []
	return _table[state].items


## True for rows that show regardless of whose phase it is — modal beats that
## can interrupt the enemy's turn and still need the player's press.
static func _phase_blind(state: Enums.InputState) -> bool:
	_ensure_table()
	return _table.has(state) and bool(_table[state].get("phase_blind", false))


## The instruction line ("Select a unit"). Empty when the bar has no step for
## this state; ENEMY_PHASE_STEP while the enemy owns the turn. act_then_walk
## (Settings.move_commit_mode, sampled by HintBar) swaps in the *_act copy
## where an entry carries it — the press stages instead of walking, and the
## step must not promise movement.
static func step_text_for(state: Enums.InputState, model: Model, enemy_phase: bool = false,
		act_then_walk: bool = false) -> String:
	_ensure_table()
	if enemy_phase and not _phase_blind(state):
		return ENEMY_PHASE_STEP
	if not _table.has(state):
		return ""
	var entry: Dictionary = _table[state]
	if model == Model.TOUCH:
		if act_then_walk and entry.has("step_touch_act"):
			return entry.step_touch_act
		return entry.step_touch
	if act_then_walk and entry.has("step_act"):
		return entry.step_act
	return entry.step


## True when the step line wears the NOTICE border (see step_notice). Never
## during the enemy phase — there is nothing to point at.
static func step_is_notice(state: Enums.InputState, enemy_phase: bool = false) -> bool:
	_ensure_table()
	if enemy_phase or not _table.has(state):
		return false
	return bool(_table[state].get("step_notice", false))


## The label of the pressable alternative to the step line (see
## confirm_label), or "" when the state has none. act_then_walk: see
## step_text_for.
static func confirm_label_for(state: Enums.InputState, enemy_phase: bool = false,
		act_then_walk: bool = false) -> String:
	_ensure_table()
	if enemy_phase or not _table.has(state):
		return ""
	var entry: Dictionary = _table[state]
	if act_then_walk and entry.has("confirm_label_act"):
		return String(entry.confirm_label_act)
	return String(entry.get("confirm_label", ""))


## The renderable list for a state under a model: each entry is
## {action, verb, glyph}. Items whose glyph resolves empty are DROPPED —
## unbound action, or (under TOUCH) no touch_label. Never longer than
## MAX_ITEMS_PER_STATE.
static func resolve(state: Enums.InputState, model: Model, enemy_phase: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Dictionary in items_for(state, enemy_phase):
		var glyph := glyph_for(item, model)
		if glyph.is_empty():
			continue
		out.append({action = item.action, verb = item.verb, glyph = glyph})
	assert(out.size() <= MAX_ITEMS_PER_STATE,
			"HintBarCommands: %s resolves to %d items — the bar teaches, it doesn't enumerate" % [
				Enums.InputState.keys()[state], out.size()])
	return out


## The label for one item under one model, from the action's CURRENT bindings.
## "" = nothing to show (drop the item).
static func glyph_for(item: Dictionary, model: Model) -> String:
	match model:
		Model.TOUCH:
			return String(item.get("touch_label", ""))
		Model.KEYBOARD_MOUSE:
			if item.has("mouse_button"):
				return mouse_button_label(int(item.mouse_button))
			return key_label_for_action(item.action)
		Model.CONTROLLER:
			return joy_label_for_action(item.action, current_joy_skin())
	return ""


# =============================================================================
# KEYBOARD / MOUSE
# =============================================================================

## First key (or mouse button) bound to the action, as a short label. "" if
## the action has no key/mouse binding (or doesn't exist).
static func key_label_for_action(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			return key_label(event as InputEventKey)
		if event is InputEventMouseButton:
			return mouse_button_label((event as InputEventMouseButton).button_index)
	return ""


## Display servers that implement keyboard_get_keycode_from_physical (layout
## translation). Elsewhere — headless, mobile — the call ERRORS rather than
## returning NONE, so it must not even be attempted.
const _LAYOUT_AWARE_DISPLAY_SERVERS: Array[String] = ["Windows", "macOS", "X11", "Wayland"]


## Short label for a key event. Resolves physical keycodes through the
## current layout where the DisplayServer can; elsewhere the physical code's
## own name is used — for letters that's the QWERTY label, which is what
## project.godot authors anyway.
static func key_label(event: InputEventKey) -> String:
	var keycode: Key = event.keycode
	if keycode == KEY_NONE and event.physical_keycode != KEY_NONE:
		if DisplayServer.get_name() in _LAYOUT_AWARE_DISPLAY_SERVERS:
			keycode = DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode)
		if keycode == KEY_NONE:
			keycode = event.physical_keycode
	match keycode:
		KEY_ESCAPE: return "Esc"
		KEY_ENTER, KEY_KP_ENTER: return "Enter"
		KEY_SPACE: return "Space"
		KEY_TAB: return "Tab"
		KEY_BACKSPACE: return "Bksp"
		KEY_SHIFT: return "Shift"
		KEY_CTRL: return "Ctrl"
		KEY_ALT: return "Alt"
		KEY_NONE: return ""
	return OS.get_keycode_string(keycode)


static func mouse_button_label(button: int) -> String:
	match button:
		MOUSE_BUTTON_LEFT: return "LMB"
		MOUSE_BUTTON_RIGHT: return "RMB"
		MOUSE_BUTTON_MIDDLE: return "MMB"
		MOUSE_BUTTON_WHEEL_UP: return "Wheel up"
		MOUSE_BUTTON_WHEEL_DOWN: return "Wheel down"
		# Side buttons: nothing binds them today, but the bar DROPS an item
		# whose glyph resolves empty — so if a future binding (or rebind UI)
		# lands on one, "[M4]" is the difference between a hint and a vanished
		# action. Text only; no art tier planned until something binds them.
		MOUSE_BUTTON_XBUTTON1: return "M4"
		MOUSE_BUTTON_XBUTTON2: return "M5"
	return ""


# =============================================================================
# CONTROLLER
# =============================================================================

## First joypad button bound to the action, labeled in the given skin. "" if
## the action has no joypad binding. Axis bindings (triggers as motion) are
## not labeled in v1.
static func joy_label_for_action(action: StringName, skin: JoySkin) -> String:
	if not InputMap.has_action(action):
		return ""
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			return joy_button_label((event as InputEventJoypadButton).button_index, skin)
	return ""


## The skin for the first connected joypad (XBOX when none is connected — the
## Steam Input / generic fallback), or joy_skin_override when a test set one.
static func current_joy_skin() -> JoySkin:
	if joy_skin_override >= 0:
		return joy_skin_override as JoySkin
	var pads: Array[int] = Input.get_connected_joypads()
	if pads.is_empty():
		return JoySkin.XBOX
	return joy_skin_for_name(Input.get_joy_name(pads[0]))


## Skin from a joypad's reported name. Substring match on the families
## whose physical labels differ from Xbox; everything else is Xbox.
static func joy_skin_for_name(joy_name: String) -> JoySkin:
	var lower := joy_name.to_lower()
	if lower.contains("steam"):
		return JoySkin.STEAM_DECK
	for needle: String in ["dualsense", "dualshock", "playstation", "ps4", "ps5", "sony"]:
		if lower.contains(needle):
			return JoySkin.PLAYSTATION
	for needle: String in ["nintendo", "switch", "joy-con", "pro controller"]:
		if lower.contains(needle):
			return JoySkin.NINTENDO
	return JoySkin.XBOX


## Physical label of a virtual-pad button under a skin. Nintendo swaps the
## face letters (same positions, different print); PlayStation names shapes.
static func joy_button_label(button: JoyButton, skin: JoySkin) -> String:
	match button:
		JOY_BUTTON_A:
			match skin:
				JoySkin.PLAYSTATION: return "Cross"
				JoySkin.NINTENDO: return "B"
			return "A"
		JOY_BUTTON_B:
			match skin:
				JoySkin.PLAYSTATION: return "Circle"
				JoySkin.NINTENDO: return "A"
			return "B"
		JOY_BUTTON_X:
			match skin:
				JoySkin.PLAYSTATION: return "Square"
				JoySkin.NINTENDO: return "Y"
			return "X"
		JOY_BUTTON_Y:
			match skin:
				JoySkin.PLAYSTATION: return "Triangle"
				JoySkin.NINTENDO: return "X"
			return "Y"
		JOY_BUTTON_LEFT_SHOULDER:
			match skin:
				JoySkin.XBOX: return "LB"
				JoySkin.NINTENDO: return "L"
			return "L1"
		JOY_BUTTON_RIGHT_SHOULDER:
			match skin:
				JoySkin.XBOX: return "RB"
				JoySkin.NINTENDO: return "R"
			return "R1"
		JOY_BUTTON_START:
			match skin:
				JoySkin.PLAYSTATION: return "Options"
				JoySkin.NINTENDO: return "+"
			return "Menu"
		JOY_BUTTON_BACK:
			match skin:
				JoySkin.PLAYSTATION: return "Share"
				JoySkin.NINTENDO: return "-"
			return "View"
		JOY_BUTTON_LEFT_STICK: return "L3"
		JOY_BUTTON_RIGHT_STICK: return "R3"
		JOY_BUTTON_DPAD_UP: return "D-Up"
		JOY_BUTTON_DPAD_DOWN: return "D-Down"
		JOY_BUTTON_DPAD_LEFT: return "D-Left"
		JOY_BUTTON_DPAD_RIGHT: return "D-Right"
		# Back grips (SDL "paddles"). Position mapping follows SDL's header
		# comments — PADDLE1 = upper-left facing the back / Elite P1, PADDLE2 =
		# upper-right / P3, PADDLE3 = lower-left / P2, PADDLE4 = lower-right /
		# P4 — which is UNVERIFIED on real Deck hardware. Before anything BINDS
		# a paddle, mash them in tools/diag/joypad_probe.gd on the Deck and fix
		# this mapping if the printed L4/R4/L5/R5 don't match the grip pressed.
		# PS (DualSense Edge) / Nintendo have no standard grip labels: "".
		JOY_BUTTON_PADDLE1:
			match skin:
				JoySkin.STEAM_DECK: return "L4"
				JoySkin.XBOX: return "P1"
			return ""
		JOY_BUTTON_PADDLE2:
			match skin:
				JoySkin.STEAM_DECK: return "R4"
				JoySkin.XBOX: return "P3"
			return ""
		JOY_BUTTON_PADDLE3:
			match skin:
				JoySkin.STEAM_DECK: return "L5"
				JoySkin.XBOX: return "P2"
			return ""
		JOY_BUTTON_PADDLE4:
			match skin:
				JoySkin.STEAM_DECK: return "R5"
				JoySkin.XBOX: return "P4"
			return ""
	return ""


# =============================================================================
# CONTROLLER GLYPH SPRITES
# =============================================================================
# The drawn-chip upgrade over the "[A]" text scaffold (brief + naming
# convention: data/design/art-requests/controller-glyphs.html). Sprites are
# 1-bit 10x10, generated by tools/godot/generate_controller_glyphs.gd, named
# by what they DEPICT — so Switch reuses the Xbox letter sprites in swapped
# positions for free, and this map keys on the LABEL joy_button_label emits
# (the one per-skin source of truth) instead of duplicating the skin logic.
# A label absent here renders as text — the safe fallback for anything new.
#
# System buttons speak RETRO-UNIVERSAL, not hardware-accurate (RQD
# 2026-09-02: the Xbox-era ☰/⧉ icons "have always made me look at the
# controller"): every pad's start-position button (Menu / Options) shows the
# START pill and the select-position button (View / Share) shows SELECT —
# the era this audience learned pads in printed the words, so the
# word-on-a-pill IS the universal glyph. Switch keeps its +/- (genuinely
# printed on the hardware). The hardware-accurate icon_menu / icon_view
# sprites stay on disk, unmapped, for a cheap re-audition.

const JOY_GLYPH_SPRITE_DIRECTORY: String = "res://art/sprites/ui/controller_glyphs/"

const JOY_GLYPH_SPRITES_BY_LABEL: Dictionary = {
	"A": "letter_a", "B": "letter_b", "X": "letter_x", "Y": "letter_y",
	"L": "letter_l", "R": "letter_r",
	"Cross": "shape_cross", "Circle": "shape_circle",
	"Square": "shape_square", "Triangle": "shape_triangle",
	"LB": "label_lb", "RB": "label_rb", "L1": "label_l1", "R1": "label_r1",
	"Menu": "label_start", "View": "label_select",
	"Options": "label_start", "Share": "label_select",
	"+": "label_plus", "-": "label_minus",
	"L3": "stick_l3", "R3": "stick_r3",
	"L4": "label_l4", "L5": "label_l5", "R4": "label_r4", "R5": "label_r5",
	"P1": "label_p1", "P2": "label_p2", "P3": "label_p3", "P4": "label_p4",
	"D-Up": "dpad_up", "D-Down": "dpad_down",
	"D-Left": "dpad_left", "D-Right": "dpad_right",
}

## Labels that deliberately stay text (no sprite, not an authoring gap).
## Empty since the START/SELECT pills absorbed Options/Share — kept as the
## declared home for any future exception, and the tests sweep against it.
const JOY_GLYPH_TEXT_ONLY_LABELS: Array[String] = []

## Loaded textures by label; null entries cache "no sprite for this label".
static var _joy_glyph_cache: Dictionary = {}


# ---- color identities (RQD 2026-09-02: "Y = yellow skittle") ---------------
# Face buttons carry their hardware color identity, rendered from SPLIT
# layers (face_form disc + <sprite>_char) so form and character tint
# independently, each with the house orthogonal glow (hud_glow shader).
# Colors resolve through GameColorPalette at call time — no hardcoded hex.
#
# TWO STYLINGS, switchable live (RQD 2026-09-04) — flip `joy_glyph_style`
# and the bar re-renders at the next state boundary:
#   HARDWARE — colors sit where the plastic puts them: Xbox/Steam Deck color
#     the SKITTLE with a dark letter (Deck shares Xbox — veto if its
#     monochrome hardware should win); PlayStation colors the MARK on gray
#     plastic (Square is RedViolet — pink, NOT the retired magenta).
#   INK — the identity moves into the text/glyph itself, glow and all, on a
#     semitransparent dark plate (the INK_PLATE_* knobs — Eggshell 1 @ 85%).
#     Letter bodies brighten a step where the skittle color was tuned for a
#     disc (B Red 5→6, X Azure 5→6): text on dark needs the lift.
#   Switch: no identities in either style (black buttons) — neutral outline.
enum JoyGlyphStyle { HARDWARE, INK }

## The audition knob. Flip the default here (or set it at runtime — the bar
## samples per refresh); tests pin their own value, so either default ships.
static var joy_glyph_style: JoyGlyphStyle = JoyGlyphStyle.INK

## INK-style plate under the colored glyph — the tweakables.
const INK_PLATE_RAMP: String = "Eggshell"
const INK_PLATE_INDEX: int = 1
const INK_PLATE_ALPHA: float = 0.85
## INK-style button outline (RQD 2026-09-04: "not subtle, not bright") —
## Gray 5 is the ramp's literal middle; nudge the index to taste.
const INK_OUTLINE_RAMP: String = "Gray"
const INK_OUTLINE_INDEX: int = 5

## label -> [ramp, body step, glow step]; glow = body − 3, the TEXT_* pairing.
const SKITTLE_RAMPS: Dictionary = {
	"A": ["Green", 6, 3], "B": ["Red", 5, 2],
	"X": ["Azure", 5, 2], "Y": ["YellowOrange", 7, 4],
}
const INK_LETTER_RAMPS: Dictionary = {
	"A": ["Green", 6, 3], "B": ["Red", 6, 3],
	"X": ["Azure", 6, 3], "Y": ["YellowOrange", 7, 4],
}
const MARK_RAMPS: Dictionary = {
	"Cross": ["Azure", 6, 3], "Circle": ["Red", 6, 3],
	"Square": ["RedViolet", 6, 3], "Triangle": ["Teal", 6, 3],
}


## The INK style's translucent plate color.
static func joy_glyph_ink_plate() -> Color:
	var plate: Color = GameColorPalette.get_color(INK_PLATE_RAMP, INK_PLATE_INDEX)
	plate.a = INK_PLATE_ALPHA
	return plate


## Identity recipe for a label under a skin: {form, char} Colors plus
## optional {form_glow, char_glow}. Empty when the button has no identity
## (every non-face button, and all of Switch). `style` -1 = the live
## joy_glyph_style; pass a JoyGlyphStyle to render a specific mode.
static func joy_glyph_identity(label: String, skin: JoySkin, style: int = -1) -> Dictionary:
	var active: JoyGlyphStyle = (style as JoyGlyphStyle) if style >= 0 else joy_glyph_style
	if skin == JoySkin.XBOX or skin == JoySkin.STEAM_DECK:
		if active == JoyGlyphStyle.HARDWARE and SKITTLE_RAMPS.has(label):
			var ramp: Array = SKITTLE_RAMPS[label]
			return {
				form = GameColorPalette.get_color(ramp[0], ramp[1]),
				form_glow = GameColorPalette.get_color(ramp[0], ramp[2]),
				char = GameColorPalette.get_color("Gray", 1),
			}
		if active == JoyGlyphStyle.INK and INK_LETTER_RAMPS.has(label):
			var ramp: Array = INK_LETTER_RAMPS[label]
			return {
				form = joy_glyph_ink_plate(),
				char = GameColorPalette.get_color(ramp[0], ramp[1]),
				char_glow = GameColorPalette.get_color(ramp[0], ramp[2]),
			}
	if skin == JoySkin.PLAYSTATION and MARK_RAMPS.has(label):
		var ramp: Array = MARK_RAMPS[label]
		var plate: Color = joy_glyph_ink_plate() if active == JoyGlyphStyle.INK \
				else GameColorPalette.get_color("Gray", 2)
		return {
			form = plate,
			char = GameColorPalette.get_color(ramp[0], ramp[1]),
			char_glow = GameColorPalette.get_color(ramp[0], ramp[2]),
		}
	return {}


## Which form/line family each sprite's char pairs with. Sprites absent here
## (d-pads, the unmapped view/menu icons) have no layers and always render
## their merged sprite.
const JOY_GLYPH_FORM_FAMILY_BY_SPRITE: Dictionary = {
	"letter_a": "face", "letter_b": "face", "letter_x": "face", "letter_y": "face",
	"shape_cross": "face", "shape_circle": "face",
	"shape_square": "face", "shape_triangle": "face",
	"label_plus": "face", "label_minus": "face",
	"letter_l": "bumper_left", "label_lb": "bumper_left", "label_l1": "bumper_left",
	"label_lt": "bumper_left", "label_l2": "bumper_left", "label_zl": "bumper_left",
	"letter_r": "bumper_right", "label_rb": "bumper_right", "label_r1": "bumper_right",
	"label_rt": "bumper_right", "label_r2": "bumper_right", "label_zr": "bumper_right",
	"stick_l3": "square", "stick_r3": "square",
	"label_l4": "square", "label_l5": "square", "label_r4": "square", "label_r5": "square",
	"label_p1": "square", "label_p2": "square", "label_p3": "square", "label_p4": "square",
	"label_start": "start", "label_select": "select",
}


## The split layers for a layered render: {form, line, char} Texture2Ds.
## Empty when the sprite has no family or any file is missing — the caller
## falls back to the merged outline sprite, so a gap degrades, never breaks.
static func joy_glyph_layer_textures(label: String) -> Dictionary:
	if not JOY_GLYPH_SPRITES_BY_LABEL.has(label):
		return {}
	var sprite_name: String = String(JOY_GLYPH_SPRITES_BY_LABEL[label])
	var family: String = String(JOY_GLYPH_FORM_FAMILY_BY_SPRITE.get(sprite_name, ""))
	if family.is_empty():
		return {}
	var char_path: String = JOY_GLYPH_SPRITE_DIRECTORY + sprite_name + "_char.png"
	var form_path: String = JOY_GLYPH_SPRITE_DIRECTORY + family + "_form.png"
	var line_path: String = JOY_GLYPH_SPRITE_DIRECTORY + family + "_line.png"
	for path: String in [char_path, form_path, line_path]:
		if not ResourceLoader.exists(path):
			return {}
	return {form = load(form_path), line = load(line_path), char = load(char_path)}


## What the bar paints for a label: {} = render the merged outline sprite in
## the text ink (HARDWARE's neutral buttons; anything without layers).
## Otherwise {form, char} plus optional {form_glow, line, char_glow} —
## HARDWARE returns the identity as-is (no outline layer); INK plates EVERY
## layered button: Eggshell plate + gray outline + the glyph in its identity
## color (or the bar's text voice when it has none), glow and all.
static func joy_glyph_recipe(label: String, skin: JoySkin, style: int = -1) -> Dictionary:
	var active: JoyGlyphStyle = (style as JoyGlyphStyle) if style >= 0 else joy_glyph_style
	var identity := joy_glyph_identity(label, skin, active)
	if active == JoyGlyphStyle.HARDWARE:
		return identity
	var recipe: Dictionary = {
		form = joy_glyph_ink_plate(),
		line = GameColorPalette.get_color(INK_OUTLINE_RAMP, INK_OUTLINE_INDEX),
	}
	if identity.is_empty():
		recipe.char = GameColors.TEXT_PRIMARY
		recipe.char_glow = GameColors.TEXT_PRIMARY_GLOW
	else:
		recipe.char = identity.char
		if identity.has("char_glow"):
			recipe.char_glow = identity.char_glow
	return recipe


## The drawn glyph for a controller label, or null when the label renders as
## text (unmapped label, or the sprite file is missing — warned once).
static func joy_glyph_texture(label: String) -> Texture2D:
	if _joy_glyph_cache.has(label):
		return _joy_glyph_cache[label]
	var texture: Texture2D = null
	if JOY_GLYPH_SPRITES_BY_LABEL.has(label):
		var path: String = JOY_GLYPH_SPRITE_DIRECTORY + String(JOY_GLYPH_SPRITES_BY_LABEL[label]) + ".png"
		if ResourceLoader.exists(path):
			texture = load(path)
		else:
			push_warning("HintBarCommands: no sprite for glyph label '%s' (%s) — text fallback" % [label, path])
	_joy_glyph_cache[label] = texture
	return texture

## UnitAnimationResolver — which clip does a unit play for a given moment?
## Pure, static, DIRECTION-FREE (Phase 1 of .claude/todo-archive.md ("Battle animations plan")).
## The combat scene has one facing, so a clip is never chosen by which WAY
## the target stands. HOW FAR it stands is a different matter: reach is the
## distance to the target (adjacent = melee, further = ranged) — the rule
## the `use_when` era used and the one the art is drawn for (Ernesto's jab
## vs his long thrust). A move's gameplay `animationStyle` tag forces the
## family either way (a Laser tagged ranged shoots point-blank); with no
## target known the move's own reach stands in. MapPresenter layers its
## in-place rule on top (side clips only for horizontal/diagonal attacks).
##
## INTENT — a string naming the moment:
##   melee_physical | melee_special | ranged_physical | ranged_special
##       reach from the distance to the target (or the `animationStyle`
##       tag, or Move.effective_animation_style() when no target is known),
##       kind from Move.damage_type
##   cast          support / self-buff flourish
##   dodge, hurt, death, idle
##
## VOCABULARY — clip keys in a character's `animations` table (= aseprite tag
## names): idle (required), melee, ranged, optional refinements
## melee_physical / melee_special / ranged_physical / ranged_special, cast,
## dodge, hurt, death, crit_melee, crit_ranged.
##
## RESOLUTION, most specific first; a named clip that doesn't exist falls
## through to the next level (logged once per character × intent under
## DebugConfig.battle_animations, never an error):
##   1. character × move   overrides["move:<move name>"]
##   2. move               Move.animation_clip (JSON `animationClip`) — the
##                         VISUAL-only override. Distinct from `animationStyle`,
##                         which also drives gameplay (Crater's melee/ranged
##                         defense split), so tagging a look never changes math.
##   3. character × intent overrides["melee_special"] = "ranged"
##   4. the chain for the intent (CHAINS below) — ANY_ATTACK expands to the
##      first attack clip present, in ATTACK_KEYS order.
##   5. PROCEDURAL ("") — a real terminal: the presenter's boop nudge /
##      pulse / flash / fade. Every character is playable with `idle` alone.
##
## The archer case falls out of the chain: a bow unit with only `ranged`,
## forced into melee by a passive, resolves melee_physical → ranged and shoots
## point-blank — what Fire Emblem does and what reads correctly.
class_name UnitAnimationResolver
extends RefCounted


## The resolver's "no clip — do it procedurally" answer.
const PROCEDURAL: String = ""

## Chain sentinel: "the first attack clip this character has at all".
const ANY_ATTACK: String = "*attack"

## Attack clips in the order ANY_ATTACK searches them.
const ATTACK_KEYS: Array[String] = [
	"melee_physical", "melee_special", "melee",
	"ranged_physical", "ranged_special", "ranged",
]

## Every key the vocabulary knows. The coverage test flags anything else.
const VOCABULARY: Array[String] = [
	"idle", "melee", "ranged",
	"melee_physical", "melee_special", "ranged_physical", "ranged_special",
	"cast", "dodge", "hurt", "death", "crit_melee", "crit_ranged",
]

## Explicit, ordered fallback per intent. Edit HERE, nowhere else. Reach
## before kind: the right reach with the other kind's clip beats the right
## kind at the wrong reach — the art is drawn per reach (Ernesto's Laser at
## range is his long thrust, not his jab); kind is a refinement.
const CHAINS: Dictionary = {
	"melee_physical": ["melee_physical", "melee", "melee_special", "ranged_physical", "ranged", "ranged_special", ANY_ATTACK],
	"melee_special": ["melee_special", "melee", "melee_physical", "ranged_special", "ranged", "ranged_physical", ANY_ATTACK],
	"ranged_physical": ["ranged_physical", "ranged", "ranged_special", "melee_physical", "melee", "melee_special", ANY_ATTACK],
	"ranged_special": ["ranged_special", "ranged", "ranged_physical", "melee_special", "melee", "melee_physical", ANY_ATTACK],
	"cast": ["cast", "melee", "ranged", ANY_ATTACK],
	"dodge": ["dodge"],
	"hurt": ["hurt"],
	"death": ["death"],
	"idle": ["idle"],
}

## (context|intent) → true once a fall-through has been logged, so a missing
## override is reported once per character, not once per swing.
static var _warned: Dictionary = {}


## The attack intent a move produces. Support-typed moves are casts.
## `distance_tiles` is the attacker→target ring distance when a target is
## known (MapPresenter.attack_distance); 0 = unknown → the move's own reach.
static func attack_intent(move: Move, distance_tiles: int = 0) -> String:
	if move == null:
		return "melee_physical" if distance_tiles <= 1 else "ranged_physical"
	if move.damage_type == Enums.DamageType.SUPPORT:
		return "cast"
	var kind: String = "special" if move.damage_type == Enums.DamageType.SPECIAL else "physical"
	return "%s_%s" % [attack_reach(move, distance_tiles), kind]


## "melee" | "ranged". The tag forces; else the distance decides when known
## (adjacent = melee, 2+ = ranged); else the move's own range.
static func attack_reach(move: Move, distance_tiles: int = 0) -> String:
	if move.animation_style == "melee" or move.animation_style == "ranged":
		return move.animation_style
	if distance_tiles > 0:
		return "ranged" if distance_tiles >= 2 else "melee"
	return move.effective_animation_style()


## The fallback list for an intent, ANY_ATTACK left as the sentinel.
## Unknown intents get an empty chain (→ PROCEDURAL).
static func chain_for(intent: String) -> Array[String]:
	var chain: Array[String] = []
	for key: Variant in CHAINS.get(intent, []):
		chain.append(str(key))
	return chain


## Resolve a clip KEY for `intent` from a character's clip table + overrides.
## `context` names the character in the once-per-character log lines.
## Returns PROCEDURAL when nothing applies.
static func resolve(clips: Dictionary, overrides: Dictionary, move: Move, intent: String,
		context: String = "") -> String:
	# 1. character × move
	if move != null and not move.move_name.is_empty():
		var by_move: String = _override(overrides, "move:" + move.move_name)
		if by_move != "":
			if clips.has(by_move):
				return by_move
			_warn_once(context, intent, "override for move '%s' names missing clip '%s'" % [
					move.move_name, by_move])
	# 2. the move's own visual override
	if move != null and not move.animation_clip.is_empty():
		var by_clip: String = move.animation_clip.to_lower()
		if clips.has(by_clip):
			return by_clip
		_warn_once(context, intent, "move '%s' asks for clip '%s' this character lacks" % [
				move.move_name, by_clip])
	# 3. character × intent
	var by_intent: String = _override(overrides, intent)
	if by_intent != "":
		if clips.has(by_intent):
			return by_intent
		_warn_once(context, intent, "override for intent '%s' names missing clip '%s'" % [
				intent, by_intent])
	# 4. the chain
	for key: String in chain_for(intent):
		if key == ANY_ATTACK:
			for attack_key: String in ATTACK_KEYS:
				if clips.has(attack_key):
					return attack_key
			continue
		if clips.has(key):
			return key
	return PROCEDURAL


## Convenience for live characters: table + overrides + character id context.
static func resolve_for(character: CharacterData, move: Move, intent: String) -> String:
	if character == null:
		return PROCEDURAL
	var key: String = resolve(character.attack_animations, character.animation_overrides,
			move, intent, character.character_id)
	DebugConfig.log_battle_animations("Resolve %s: %s → %s" % [
			character.character_id, intent, key if key != PROCEDURAL else "PROCEDURAL"])
	return key


## Case-insensitive override lookup; "" when absent. Values are clip keys.
static func _override(overrides: Dictionary, key: String) -> String:
	var wanted: String = key.to_lower()
	for existing: Variant in overrides.keys():
		if str(existing).to_lower() == wanted:
			return str(overrides[existing]).to_lower()
	return ""


static func _warn_once(context: String, intent: String, message: String) -> void:
	var stamp: String = "%s|%s" % [context, intent]
	if _warned.has(stamp):
		return
	_warned[stamp] = true
	DebugConfig.log_battle_animations("Resolve %s: %s — falling through" % [context, message])

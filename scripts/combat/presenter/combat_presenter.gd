## CombatPresenter — the seam between combat LOGIC and combat PRESENTATION.
## THIS HEADER IS THE LIVING MAP of the battle-animation system — start here.
## Plan + decisions: .claude/todo-archive.md ("Battle animations plan").
##
## WHY A SEAM: execute_combat_sequence / _execute_single_hit (unit.gd) own
## every roll, damage number, pipeline dispatch, live range re-check and XP
## grant. They used to also own every sprite tween, popup and screenshake.
## Now each visual moment is a BEAT on this interface, and the logic never
## touches a sprite. One exchange = one presenter instance, chosen once by
## for_exchange():
##
##   CombatPresenter (this file — no-op beats + skip + hitlag math)
##   ├── MapPresenter        today's in-place presentation: boop nudge or
##   │                       side clip on the map unit, camera shake, popups
##   │                       hosted on the map. What bare/off-grid units and
##   │                       every non-offensive cast get.
##   ├── ScenePresenter      drives the FE7-style CombatScene — puppets on a
##   │                       side-view stage mounted in the HUD overlay layer.
##   │                       scripts/combat/scene/{combat_scene,combat_puppet}.gd
##   └── RecordingPresenter  test double: records beat order, waits for
##                           nothing. tests/unit/test_combat_presenter.gd.
##
## THE BEATS, in the order an exchange uses them:
##   open(attacker, defender, move)     after combat_started fires; a scene
##                                      wipes in here, the map does nothing.
##   callout(unit, text, color)         BELLOWS ×1.5 / CRIT! / MISS / …
##   strike_to_contact(actor, target, move)   windup through the hit frame
##                                      (or the boop lunge). AWAITED — the
##                                      logic resolves damage while the
##                                      actor is frozen at contact.
##   nudge_to_contact(actor, target)    the friendly contact (heal, buff):
##                                      a lunge, never a swing. AWAITED.
##   hold(seconds)                      hitlag. Skip → returns at once.
##   release_contact(actor)             tail frames / snap back. Fire-and-
##                                      forget: popups + shake play over it.
##   impact(target, weight, tint)       hit flash + shake, presenter-owned.
##   show_damage / show_heal            the numbers.
##   miss(actor, target, move)          the whole swing-and-dodge beat.
##   out_of_range(unit)                 a follow-up the range re-check refused.
##   cast_flourish(actor, move)         self-cast whose payload is all AoE.
##   death(unit)                        the VISUAL half of defeat — Unit
##                                      still flips its own flags and clears
##                                      its tile around this call.
##   displace(plan)                     the VISUAL half of a shove. Occupancy
##                                      is already committed (counters read
##                                      the new range); the map slides now,
##                                      the scene echoes on the puppet and
##                                      slides the map unit after its
##                                      wipe-out. AWAITED.
##   close()                            before XP feedback; a scene wipes out
##                                      and then replays deferred shoves.
##
## RULES (the anti-spaghetti contract):
##   • Presenters never roll dice, never mutate HP, never consume PP. They
##     receive results. Logic never reads a sprite. `grep -n "_sprite\|tween"`
##     over the combat path of unit.gd should stay empty.
##   • Beats that the logic AWAITS are the ones whose timing gates damage
##     (strike_to_contact, hold, miss, out_of_range, death, open, close).
##     Everything else is fire-and-forget.
##   • Lifecycle is explicit calls, not signals. open/close must balance —
##     asserted here. XP feedback and the mid-battle level-up run AFTER close
##     so they play on the map, not under an overlay.
##   • Skip (request_skip) fast-forwards PRESENTATION only: every awaited
##     beat returns at once, the logic loop runs unchanged, beat ORDER is
##     preserved (RecordingPresenter proves it).
##   • Handlers reach the presenter through CombatHitContext.presenter
##     (DisplaceEffect → DisplacementSystem.resolve → displace / callout).
##     What still presents on its own — ScheduledEffects._strike, the map
##     unit's own status callout — keeps its map presentation regardless.
##
## Clip playback itself lives in ClipPlayer (scripts/units/clip_player.gd),
## one per sprite, so a map unit and a scene puppet share the same strip
## contract. Clip SELECTION is still Unit.pick_attack_clip (direction+range,
## use_when) until Phase 1's resolver replaces it.
class_name CombatPresenter
extends RefCounted


## Hitlag: both units freeze at the moment of contact, longer for heavier
## hits. Shared by every presenter so the scene and the map feel the same.
const HITLAG_MIN: float = 0.05  # Minimum freeze on any hit (seconds)
const HITLAG_MAX: float = 0.25  # Maximum freeze on a devastating hit (seconds)

## The exchange this presenter is showing. Set by open(); read by beats
## that need to know which side is which (the scene's HUD).
var attacker: Node2D = null
var defender: Node2D = null
var move: Move = null

var _is_open: bool = false
var _skip_requested: bool = false


# =============================================================================
# SELECTION
# =============================================================================

## The one place that decides how an exchange is shown: the CombatScene for
## an offensive single-target exchange when Settings.battle_animations
## allows it for the initiator (plan D3/D5) and both combatants are real,
## mounted units; the map presentation for everything else. Direct
## single-hit calls (tests, AoE victims) never come through here with a
## null presenter — they get MapPresenter from _execute_single_hit.
static func for_exchange(attacker: Node2D, defender: Node2D, move: Move) -> CombatPresenter:
	if scene_allowed(attacker, defender, move):
		return ScenePresenter.new()
	return MapPresenter.new()


## The scene's admission rules, pure enough to test: the setting × who
## initiates, the D3 fence (offensive, single-target, two different units),
## and the practical floor (both in the tree with a Sprite2D and character
## data, and somewhere to mount).
static func scene_allowed(attacker: Node2D, defender: Node2D, move: Move) -> bool:
	if attacker == null or defender == null or move == null or attacker == defender:
		return false
	if move.targets_allies() or move.target_type == Enums.TargetType.SELF:
		return false
	match Settings.battle_animations:
		Settings.BattleAnimations.MAP:
			return false
		Settings.BattleAnimations.PLAYER_PHASE_ONLY:
			if attacker.get("faction") != Enums.UnitFaction.PLAYER:
				return false
	for unit: Node2D in [attacker, defender]:
		if not unit.is_inside_tree() or unit.get("character_data") == null \
				or unit.get_node_or_null("Sprite2D") == null:
			return false
	return CombatScene.can_mount()


static func hitlag_seconds(impact_weight: float) -> float:
	return lerpf(HITLAG_MIN, HITLAG_MAX, clampf(impact_weight, 0.0, 1.0))


# =============================================================================
# LIFECYCLE
# =============================================================================

func open(exchange_attacker: Node2D, exchange_defender: Node2D, exchange_move: Move) -> void:
	assert(not _is_open, "CombatPresenter.open called twice without close")
	attacker = exchange_attacker
	defender = exchange_defender
	move = exchange_move
	_is_open = true


func close() -> void:
	assert(_is_open, "CombatPresenter.close without open")
	_is_open = false


func is_open() -> bool:
	return _is_open


## Fast-forward: every awaited beat returns immediately from here on. Logic
## is untouched — results still land in order.
func request_skip() -> void:
	_skip_requested = true


func is_skipping() -> bool:
	return _skip_requested


## A timed beat (hitlag, the pause between hits, a read-beat after a
## callout). Honors skip. Needs no node: the SceneTree comes from the main
## loop, so bare-unit tests and RefCounted presenters can wait too.
func hold(seconds: float) -> void:
	if _skip_requested or seconds <= 0.0:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	await tree.create_timer(seconds).timeout


# =============================================================================
# BEATS — no-ops here; MapPresenter / ScenePresenter override
# =============================================================================

func strike_to_contact(_actor: Node2D, _target: Node2D, _move: Move) -> void:
	pass


func nudge_to_contact(_actor: Node2D, _target: Node2D) -> void:
	pass


func release_contact(_actor: Node2D) -> void:
	pass


func impact(_target: Node2D, _impact_weight: float, _tint: Color = Color.TRANSPARENT) -> void:
	pass


func miss(_actor: Node2D, _target: Node2D, _move: Move) -> void:
	pass


func show_damage(_actor: Node2D, _target: Node2D, _damage: int, _effectiveness_text: String,
		_multiplier: float) -> void:
	pass


func show_heal(_actor: Node2D, _target: Node2D, _amount: int) -> void:
	pass


func callout(_unit: Node2D, _text: String, _color: Color) -> void:
	pass


func out_of_range(_unit: Node2D) -> void:
	pass


func cast_flourish(_actor: Node2D, _move: Move) -> void:
	pass


func death(_unit: Node2D) -> void:
	pass


## The visual half of a shove: `plan` is DisplacementSystem's DisplacePlan
## (movers with their start cell + tile path). Occupancy is ALREADY committed
## when this runs; the nodes still stand where they were. Whoever shows it
## ends by settling every mover onto its tile (MapPresenter.settle_movers).
func displace(_plan: DisplacementSystem.DisplacePlan) -> void:
	pass

## MapPresenter — the in-place presentation: the attacking unit nudges (boop)
## or plays its side clip on the map, the defender flashes, the camera
## shakes, popups float over the units. This is the code that lived inline
## in Unit's combat path before the CombatPresenter seam (Phase 0 of
## .claude/todo-archive.md ("Battle animations plan")) — moved, not changed. It is what every
## non-offensive cast gets forever (plan D3) and what the player gets under
## Settings.battle_animations = MAP (plan D4/D5).
##
## Clip rule of the in-place era, kept: WHICH clip is UnitAnimationResolver's
## call (by move intent, direction-free); WHETHER a side clip can play here
## is this presenter's — a horizontal or diagonal attack plays it mirrored
## by flip_h on the target's side, a due north/south attack has no side art
## and falls back to the boop nudge (side_clip_allowed).
##
## Z-order: the attacker is re-pinned to the end of its sibling list for the
## swing so it draws over the defender (Unit._raise_for_attack /
## _lower_after_attack — refcounted per unit, which is why those helpers
## stay on Unit rather than here: two presenters must never hold separate
## counts for one unit).
class_name MapPresenter
extends CombatPresenter


const BOOP_DISTANCE: float = 8.0  # Pixels the sprite bumps toward the target
const BOOP_OUT_SECONDS: float = 0.08
const BOOP_RETURN_SECONDS: float = 0.12
const NO_SPRITE_BEAT_SECONDS: float = 0.08  # Bare units still take a beat
const OUT_OF_RANGE_READ_SECONDS: float = 0.4

## When true, an attack that isn't due north/south uses the side clip (a
## diagonal shows the side-swing, mirrored by flip_h on delta.x's sign — NE
## flips east, NW stays west). False restores strict matching: side clips
## only for a due east/west delta, diagonals boop.
const DIAGONAL_USES_SIDE_ANIMATION: bool = true

## Clip in flight per actor (instance id → clip dict), so release_contact
## knows whether to run a clip tail or a boop return. Empty dict = boop.
var _clips_in_flight: Dictionary = {}


# =============================================================================
# STRIKE
# =============================================================================

## Approach through the hit frame: the resolver's clip if the attack
## direction allows a side clip, else the boop lunge. Awaitable — completes
## at the contact point.
func strike_to_contact(actor: Node2D, target: Node2D, strike_move: Move) -> void:
	var clip: Dictionary = {}
	if actor.has_method("attack_delta_tiles"):
		clip = pick_clip(actor.get("character_data"), actor.attack_delta_tiles(target), strike_move)
	_clips_in_flight[actor.get_instance_id()] = clip
	if clip.is_empty():
		await _boop_out(actor, target)
	else:
		await _play_clip_to_hit(actor, clip, target)


## Friendly contact — heals and buffs lunge but never swing, whatever clips
## the actor owns. release_contact brings it back like any boop.
func nudge_to_contact(actor: Node2D, target: Node2D) -> void:
	_clips_in_flight[actor.get_instance_id()] = {}
	await _boop_out(actor, target)


## Tail frames / snap back. Fire-and-forget (not awaited by the logic) —
## runs while popups and shake play. Balances the raise from
## strike_to_contact when it finishes.
func release_contact(actor: Node2D) -> void:
	var key: int = actor.get_instance_id()
	var clip: Dictionary = _clips_in_flight.get(key, {})
	_clips_in_flight.erase(key)
	if clip.is_empty():
		_boop_return(actor)
	else:
		_play_clip_tail(actor)


func impact(target: Node2D, impact_weight: float, tint: Color = Color.TRANSPARENT) -> void:
	VisualFeedbackManager.apply_hit_flash(target, impact_weight, tint)
	if target.is_inside_tree():
		var camera := target.get_viewport().get_camera_2d() as CameraController
		if camera != null:
			camera.screenshake(impact_weight)


## Miss: the attacker plays its approach, a minimum-hitlag hold so the MISS
## callout has time to land, then returns to idle. No damage, no flash, no
## shake — swing-and-dodge.
func miss(actor: Node2D, target: Node2D, strike_move: Move) -> void:
	await strike_to_contact(actor, target, strike_move)
	await hold(HITLAG_MIN)
	release_contact(actor)
	callout(target, "MISS", GameColorPalette.get_color("Gray", 5))


# =============================================================================
# NUMBERS + CALLOUTS — hosted by the unit that acts, exactly as before
# =============================================================================

func show_damage(actor: Node2D, target: Node2D, damage: int, effectiveness_text: String,
		multiplier: float) -> void:
	actor._spawn_damage_popup(target, damage, effectiveness_text, multiplier)


func show_heal(actor: Node2D, target: Node2D, amount: int) -> void:
	actor._spawn_heal_popup(target, amount)


func callout(unit: Node2D, text: String, color: Color) -> void:
	unit.spawn_text_callout(text, color)


## A follow-up (counter or bonus hit) the mid-combat range re-check refused —
## displacement moved someone out of reach. Muted MISS ink + a read-beat so
## cause-and-effect lands before combat moves on.
func out_of_range(unit: Node2D) -> void:
	callout(unit, "OUT OF RANGE", GameColorPalette.get_color("Gray", 5))
	await hold(OUT_OF_RANGE_READ_SECONDS)


## The visible beat for a self-cast whose payload is all AoE (Roar, Shriek):
## a quick sprite pulse, plus the move-name callout for PLAYER casters (the
## enemy AI already announces its move pre-swing).
func cast_flourish(actor: Node2D, cast_move: Move) -> void:
	if actor.get("faction") == Enums.UnitFaction.PLAYER:
		var callout_color: Color = GameColors.get_move_chip_foreground(cast_move.element_type) \
				if cast_move.element_type != Enums.ElementalType.NONE else GameColors.PLAYER_UNIT
		callout(actor, cast_move.move_name.to_upper(), callout_color)
	var sprite := actor.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or not actor.is_inside_tree():
		return
	if is_skipping():
		sprite.scale = Vector2.ONE
		return
	var tween := actor.create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_IN)
	await tween.finished


## Gray out, hide bars, fade — Unit.play_defeat_visuals is the map's death.
func death(unit: Node2D) -> void:
	if unit.has_method("play_defeat_visuals"):
		await unit.play_defeat_visuals()


# =============================================================================
# CLIP SELECTION — resolver × in-place direction rule
# =============================================================================

## Can a side-view clip play for an attack along `delta` (attacker → target,
## tiles)? Pure; see DIAGONAL_USES_SIDE_ANIMATION.
static func side_clip_allowed(delta: Vector2i) -> bool:
	if DIAGONAL_USES_SIDE_ANIMATION:
		return delta.x != 0  # pure east/west OR any diagonal
	return delta.y == 0 and delta.x != 0


## The clip dict to play on the map for `strike_move` along `delta`, or {}
## for the boop nudge: the resolver picks the KEY by intent; the direction
## rule decides whether side art is usable at all. Pure + static so it's
## testable without a scene tree.
static func pick_clip(character: CharacterData, delta: Vector2i, strike_move: Move) -> Dictionary:
	if character == null or character.attack_animations.is_empty():
		return {}
	if not side_clip_allowed(delta):
		return {}
	var key: String = UnitAnimationResolver.resolve_for(character, strike_move,
			UnitAnimationResolver.attack_intent(strike_move, attack_distance(delta)))
	if key == UnitAnimationResolver.PROCEDURAL:
		return {}
	var clip: Variant = character.attack_animations.get(key, {})
	return clip if clip is Dictionary else {}


## Map distance for REACH — Manhattan, the gameplay metric
## (DamageCalculator.get_manhattan_distance): a diagonal neighbour is TWO
## tiles away, only a range-2 move reaches it, so it is a ranged moment in
## the clip choice and on the stage. (The use_when era measured Chebyshev
## whenever diagonals showed side art; that drew a diagonal Compressed Air
## as an adjacent, overlapping pair — RQD's screenshot, 2026-09-08.) The
## DIRECTION rule (side_clip_allowed) is a separate question and unchanged.
## ScenePresenter and CombatScene read this too.
static func attack_distance(delta: Vector2i) -> int:
	return absi(delta.x) + absi(delta.y)


## The map's shove: slide now, in place.
func displace(plan: DisplacementSystem.DisplacePlan) -> void:
	await slide_along_plan(plan)


## All movers slide together: one parallel tween per global step, each active
## mover one tile (DisplacementSystem.PUSH_TWEEN_PER_TILE). A chain member
## with start_step 2 sits still for two beats, then rides the train. Ends by
## settling every mover onto its committed tile. Static so ScenePresenter can
## replay the same slide after its wipe-out.
static func slide_along_plan(plan: DisplacementSystem.DisplacePlan) -> void:
	var total_steps := 0
	for mover: Dictionary in plan.movers:
		total_steps = maxi(total_steps, int(mover.start_step) + (mover.path as Array[Tile]).size())
	var host: Node2D = plan.movers[0].unit if not plan.movers.is_empty() else null
	if host != null and host.is_inside_tree():
		for step: int in range(total_steps):
			var tween := host.create_tween().set_parallel(true)
			var stepped := false
			for mover: Dictionary in plan.movers:
				var index: int = step - int(mover.start_step)
				var path: Array[Tile] = mover.path
				if index < 0 or index >= path.size():
					continue
				tween.tween_property(mover.unit, "global_position",
						path[index].global_position, DisplacementSystem.PUSH_TWEEN_PER_TILE)
				stepped = true
			if stepped:
				await tween.finished
			else:
				tween.kill()
	settle_movers(plan)


## Every living mover snaps onto its committed tile — position AND z-order
## (move_to_tile onto the tile it already holds). The skip / reduce-motion
## path, and the last frame of the slide.
static func settle_movers(plan: DisplacementSystem.DisplacePlan) -> void:
	for mover: Dictionary in plan.movers:
		var unit: Node2D = mover.unit
		if not is_instance_valid(unit):
			continue
		if unit.has_method("is_defeated") and unit.is_defeated():
			continue
		var tile: Tile = unit.get("current_tile") as Tile
		if tile != null and unit.has_method("move_to_tile"):
			unit.move_to_tile(tile)


# =============================================================================
# BOOP — the no-clip fallback
# =============================================================================

func _boop_out(actor: Node2D, target: Node2D) -> void:
	var sprite := actor.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or target == null:
		await hold(NO_SPRITE_BEAT_SECONDS)
		return
	# Raise above same-row neighbors for the swing window. Paired with the
	# lower triggered when the return tween finishes.
	actor._raise_for_attack()
	var direction: Vector2 = (target.global_position - actor.global_position).normalized()
	var boop_offset: Vector2 = direction * BOOP_DISTANCE
	if is_skipping():
		sprite.position = boop_offset
		return
	var tween := actor.create_tween()
	tween.tween_property(sprite, "position", boop_offset, BOOP_OUT_SECONDS).set_ease(Tween.EASE_OUT)
	await tween.finished


## Snap back to center. Lowers the unit (refcount-aware) when the tween
## finishes, so the raise from _boop_out is balanced even when a chained
## hit starts before this tween completes.
func _boop_return(actor: Node2D) -> void:
	var sprite := actor.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		actor._lower_after_attack()
		return
	if is_skipping():
		sprite.position = Vector2.ZERO
		actor._lower_after_attack()
		return
	var tween := actor.create_tween()
	tween.tween_property(sprite, "position", Vector2.ZERO, BOOP_RETURN_SECONDS).set_ease(Tween.EASE_IN)
	tween.finished.connect(actor._lower_after_attack)


# =============================================================================
# CLIPS — via the unit's ClipPlayer
# =============================================================================

## Frames 0..hit_frame on the unit's own sprite, mirrored when the target is
## east (clips are authored left-facing). Raises the unit above its row for
## the duration of the swing.
func _play_clip_to_hit(actor: Node2D, clip: Dictionary, target: Node2D) -> void:
	var player: ClipPlayer = actor.get("clip_player")
	if player == null:
		await hold(NO_SPRITE_BEAT_SECONDS)
		return
	var delta: Vector2i = actor.attack_delta_tiles(target)
	if not player.begin(clip, delta.x > 0):
		await hold(NO_SPRITE_BEAT_SECONDS)
		return
	actor._raise_for_attack()
	await player.play_to_hit(is_skipping())


## The tail (hit_frame+1 .. last) then idle restore, then the z-order lower.
## Every exit of the tail — normal, bailed for a newer clip, or instant —
## lowers exactly once, keeping the raise refcount balanced.
func _play_clip_tail(actor: Node2D) -> void:
	var player: ClipPlayer = actor.get("clip_player")
	if player != null:
		await player.play_after_hit(is_skipping())
	actor._lower_after_attack()

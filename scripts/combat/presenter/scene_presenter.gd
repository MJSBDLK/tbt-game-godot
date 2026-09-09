## ScenePresenter — drives a CombatScene (the FE7-style cutaway) for one
## exchange. Every beat lands on the puppets and the scene's own popup
## layer; the map units underneath are untouched except through the logic
## the exchange already runs on them. Chosen by CombatPresenter.for_exchange
## when Settings.battle_animations allows it for the initiator and the
## exchange is an offensive single-target one (plan D3/D5).
##
## Clips: UnitAnimationResolver picks the KEY by move intent; the puppet
## plays it mirrored or not per its side. No clip → the procedural lunge.
##
## Skip: the scene's skip_requested feeds request_skip(); every timed beat
## returns at once, order untouched (the RecordingPresenter tests prove the
## order; this class just honours the flag).
class_name ScenePresenter
extends CombatPresenter


const OUT_OF_RANGE_READ_SECONDS: float = 0.4
## Settle beats: the stage sits still after the wipe-in before the first
## swing, and after the last beat before the wipe-out (RQD 2026-09-08: "it
## whips by before my brain can process it" — 250 ms each end to start).
## Eyeball knobs; skip removes both. Under DebugConfig.combat_scene_step_pauses
## each settle is instead an indefinite wait for a press (see _settle).
const OPEN_SETTLE_SECONDS: float = 0.25
const CLOSE_SETTLE_SECONDS: float = 0.25
var scene: CombatScene = null
## DisplacePlans whose MAP slide waits for close(): under the stage the units
## must not teleport (RQD's first eyeball, 2026-09-08) — occupancy is already
## committed, the nodes still stand where they were until the wipe-out.
var _deferred_plans: Array = []


# =============================================================================
# LIFECYCLE
# =============================================================================

func open(exchange_attacker: Node2D, exchange_defender: Node2D, exchange_move: Move) -> void:
	super.open(exchange_attacker, exchange_defender, exchange_move)
	scene = CombatScene.new()
	scene.skip_requested.connect(request_skip)
	UIManager.get_overlay_layer().add_child(scene)
	scene.setup(exchange_attacker, exchange_defender, exchange_move)
	DebugConfig.log_battle_animations("CombatScene open: %s vs %s (%s)" % [
			exchange_attacker.get("unit_name"), exchange_defender.get("unit_name"),
			exchange_move.move_name if exchange_move != null else ""])
	await scene.wipe_in(is_skipping())
	await _settle(OPEN_SETTLE_SECONDS)


func close() -> void:
	super.close()
	if scene != null:
		await _settle(CLOSE_SETTLE_SECONDS)  # the result sits on stage for a beat
		await scene.wipe_out(is_skipping())
		scene.queue_free()
		scene = null
	await _replay_displacements()


## A settle point: the timed hold — or, under DebugConfig.combat_scene_step_pauses,
## an indefinite park until a press, so the stage can be examined. The debug
## pause ignores skip on purpose (a skipped exchange's END state is exactly
## what you'd want to look at); the press at the pause advances, not skips.
func _settle(seconds: float) -> void:
	if DebugConfig.combat_scene_step_pauses and scene != null:
		await scene.wait_for_press()
		return
	await hold(seconds)


## The map half of every shove this exchange deferred, in order, now that the
## stage is gone: the slide MapPresenter would have played at the time. Skip
## or reduce-motion → everyone snaps onto their tiles.
func _replay_displacements() -> void:
	var plans: Array = _deferred_plans
	_deferred_plans = []
	for plan: DisplacementSystem.DisplacePlan in plans:
		if is_skipping() or not Settings.ui_motion_enabled:
			MapPresenter.settle_movers(plan)
		else:
			await MapPresenter.slide_along_plan(plan)


# =============================================================================
# BEATS
# =============================================================================

func strike_to_contact(actor: Node2D, target: Node2D, strike_move: Move) -> void:
	var puppet := _puppet(actor)
	if puppet == null:
		return
	# Move, hit %, multiplier on the actor's row; the projected loss of THIS
	# strike pulses on the target's bar. Refreshed every swing — a counter's
	# row fills in when it swings.
	scene.show_strike(actor, target, strike_move)
	var clip: Dictionary = _clip_for(actor, target, strike_move)
	var played: bool = await puppet.strike_to_contact(clip, is_skipping())
	if not played:
		await puppet.lunge(is_skipping())


func nudge_to_contact(actor: Node2D, _target: Node2D) -> void:
	var puppet := _puppet(actor)
	if puppet != null:
		await puppet.lunge(is_skipping())


func release_contact(actor: Node2D) -> void:
	var puppet := _puppet(actor)
	if puppet != null:
		puppet.release(is_skipping())


func impact(target: Node2D, impact_weight: float, tint: Color = Color.TRANSPARENT) -> void:
	var puppet := _puppet(target)
	if puppet == null:
		return
	puppet.hit_flash(impact_weight, tint)
	scene.shake(impact_weight)


func miss(actor: Node2D, target: Node2D, strike_move: Move) -> void:
	await strike_to_contact(actor, target, strike_move)
	var dodger := _puppet(target)
	if dodger != null:
		dodger.dodge_hop(is_skipping())
	await hold(HITLAG_MIN)
	release_contact(actor)
	callout(target, "MISS", GameColorPalette.get_color("Gray", 5))
	if scene != null:
		scene.clear_projection(target)  # the band was for a hit that never came


func show_damage(_actor: Node2D, target: Node2D, damage: int, effectiveness_text: String,
		multiplier: float) -> void:
	if scene == null:
		return
	scene.spawn_popup(target, func(popup: Node) -> void:
		popup.call("initialize", damage, effectiveness_text, multiplier))
	scene.update_hp(target)


func show_heal(_actor: Node2D, target: Node2D, amount: int) -> void:
	if scene == null:
		return
	scene.spawn_popup(target, func(popup: Node) -> void:
		popup.call("initialize_heal", amount))
	scene.update_hp(target)


## On stage over the puppet; a unit that is not on stage (a bystander hit by
## a SLAM, a RESIST off-stage) still gets its map callout.
func callout(unit: Node2D, text: String, color: Color) -> void:
	if scene == null or scene.puppet_for(unit) == null:
		if unit != null and unit.has_method("spawn_text_callout"):
			unit.spawn_text_callout(text, color)
		return
	scene.spawn_popup(unit, func(popup: Node) -> void:
		popup.call("initialize_callout", text, color), 12.0)


func out_of_range(unit: Node2D) -> void:
	callout(unit, "OUT OF RANGE", GameColorPalette.get_color("Gray", 5))
	await hold(OUT_OF_RANGE_READ_SECONDS)


func cast_flourish(actor: Node2D, cast_move: Move) -> void:
	if cast_move != null and actor.get("faction") == Enums.UnitFaction.PLAYER:
		var ink: Color = GameColors.get_move_chip_foreground(cast_move.element_type) \
				if cast_move.element_type != Enums.ElementalType.NONE else GameColors.PLAYER_UNIT
		callout(actor, cast_move.move_name.to_upper(), ink)
	var puppet := _puppet(actor)
	if puppet != null:
		await puppet.pulse(is_skipping())


## A shove under the stage: the map slide is deferred to close(); on stage
## the puppets re-space to the NEW map distance with the scene's own tile
## rule (CombatScene.respace) — the shoved combatant travels, the other
## holds unless the pair would leave the core. Bystanders echo nothing.
func displace(plan: DisplacementSystem.DisplacePlan) -> void:
	_deferred_plans.append(plan)
	if scene == null or attacker == null or defender == null:
		return
	var mover: Node2D = null
	var combatants_moved := 0
	for entry: Dictionary in plan.movers:
		if entry.unit == attacker or entry.unit == defender:
			combatants_moved += 1
			mover = entry.unit
	if combatants_moved == 0:
		return
	if combatants_moved > 1:
		mover = null  # both moved (a swap): symmetric re-spacing
	var new_distance: int = maxi(1, _manhattan(_cell_of_unit(attacker), _cell_of_unit(defender)))
	await scene.respace(new_distance, mover, is_skipping())


static func _cell_of_tile(tile: Tile) -> Vector2i:
	return Vector2i(tile.grid_x, tile.grid_y) if tile != null else Vector2i.ZERO


static func _cell_of_unit(unit: Node2D) -> Vector2i:
	return _cell_of_tile(unit.get("current_tile") as Tile)


## The gameplay range metric (MapPresenter.attack_distance).
static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## The puppet dies on stage; the map unit's own fade starts underneath (not
## awaited — the wipe-out covers it and the tile clears right after).
func death(unit: Node2D) -> void:
	var puppet := _puppet(unit)
	if puppet != null:
		await puppet.play_death(is_skipping())
	if unit.has_method("play_defeat_visuals"):
		unit.play_defeat_visuals()


# =============================================================================
# HELPERS
# =============================================================================

func _puppet(unit: Node2D) -> CombatPuppet:
	return scene.puppet_for(unit) if scene != null else null


## Reach comes from the MAP distance: the stage has one spacing, but the
## units still stand on their tiles underneath (Ernesto jabs adjacent and
## thrusts at range on the stage exactly as on the map).
func _clip_for(actor: Node2D, target: Node2D, strike_move: Move) -> Dictionary:
	var character: CharacterData = actor.get("character_data")
	if character == null or character.attack_animations.is_empty():
		return {}
	var delta: Vector2i = actor.attack_delta_tiles(target) if actor.has_method("attack_delta_tiles") \
			else Vector2i.ZERO
	var key: String = UnitAnimationResolver.resolve_for(character, strike_move,
			UnitAnimationResolver.attack_intent(strike_move, MapPresenter.attack_distance(delta)))
	if key == UnitAnimationResolver.PROCEDURAL:
		return {}
	var clip: Variant = character.attack_animations.get(key, {})
	return clip if clip is Dictionary else {}

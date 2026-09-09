## DisplacementSystem — grid-shove resolution for combat (Combat Pipeline
## Phase 3). Stateless static class, invoked per landed hit by
## DisplaceEffect.on_hit. THIS HEADER IS THE LIVING DOC for the displacement
## schema and its semantics.
##
## JSON schema (move JSON, under "onHit"):
##   "displace": {
##     "subject":  "target",             // target | self | others_in_shape
##     "shape":    "single",             // single | line(N) | row(N) | ring(N)
##     "vector":   "away_from_attacker", // see VECTORS below
##     "distance": 1,                    // tiles (perimeter steps for rotations)
##     "save":     {"contest": "constitution", "margin": 1},  // optional
##     "on_blocked": "stop"    // stop | swap | bonus_damage | fall_through | push_chain
##   }
##
## SUBJECTS — who gets moved:
##   target          the struck unit (default).
##   self            the caster (recoil, charges). Skips the contest — you don't
##                   resist your own momentum. Self-moves must use the
##                   away/toward_target vectors (away_from_attacker is a zero
##                   vector when you ARE the attacker).
##   others_in_shape every non-defeated unit standing on a shape cell around the
##                   EPICENTER, excluding the caster. The epicenter is the
##                   primary target's tile — when true AoE point-targeting lands,
##                   it becomes the targeted cell (one line in resolve()).
##
## SHAPES (others_in_shape only; sizes parse from "row(3)"-style strings):
##   single   the epicenter cell only.
##   line(N)  N cells starting AT the epicenter, extending away from the attacker.
##   row(N)   N cells centered on the epicenter, perpendicular to the attack
##            axis (an even N puts the extra cell on the positive side).
##   ring(N)  every cell at Chebyshev distance exactly N from the epicenter.
##
## VECTORS — where they go. All displacement is axis-aligned: a direction is the
## DOMINANT axis of the reference delta, ties break to X (the _away_from rule).
##   away_from_attacker / toward_attacker   reference = caster's tile → subject.
##   away_from_target  / toward_target      reference = target's tile → subject
##                                          (the self-recoil pair).
##   away_from_point   / toward_point       reference = epicenter → subject
##                                          (radial blast / vortex pull; a
##                                          subject ON the epicenter stays put).
##   rotate_cw / rotate_ccw                 each subject walks `distance` steps
##                                          along its own Chebyshev ring around
##                                          the epicenter (clockwise in the
##                                          game's Y-up grid: north edge heads
##                                          east). Blockers always use stop
##                                          semantics for rotations; trailing
##                                          units jam behind a stopped one.
##
## SAVE CONTEST: the subject is displaced when caster.<stat> − subject.<stat> >
## margin (strictly). No "save" key = always displaced. The contest stat
## defaults to constitution — the universal resist stat (it does NOT level up,
## so it's a stable balance lever). A subject that saves gets a "RESIST"
## callout. push_chain collateral (units shoved by the displaced unit) never
## contests — being in the way is physics, not resistance.
##
## ON_BLOCKED policies (next cell occupied or impassable):
##   stop          halt before the obstacle. Also the fallback for every policy
##                 when the obstacle is terrain/map-edge (except bonus_damage).
##   swap          trade places with the blocking unit and end there. The
##                 blocker lands on the subject's cell at the moment of contact
##                 (degrades to stop if that cell is impassable for the blocker).
##   bonus_damage  halt + collision damage: COLLISION_DAMAGE_PER_TILE ×
##                 remaining (untraveled) tiles, to the subject AND a blocking
##                 unit; a terrain/edge slam hurts only the subject.
##   fall_through  sail over occupied cells (each still costs a step) and land
##                 on the next open one; if distance expires mid-air, back up to
##                 the last open cell. Terrain/edge still stops.
##   push_chain    domino: the blocker — and the contiguous train beyond it —
##                 is shoved along with the subject while every member's next
##                 cell is enterable; a member that can't advance jams the
##                 whole train.
##
## RESOLUTION MODEL: build_plan() is PURE — it walks a virtual occupancy
## overlay and returns a DisplacePlan (per-unit step-aligned tile paths,
## collisions, resisted subjects) without touching the board; that's what the
## unit tests drive. resolve() then batch-commits OCCUPANCY (clear every
## mover's registration, THEN re-register at the destinations — ordering-safe
## for swaps and rotations, where sequential move_to_tile calls would clobber
## each other; the nodes stay where they stand), hands the SLIDE to the
## exchange's CombatPresenter as its `displace` beat (MapPresenter.
## slide_along_plan: one parallel tween per global step, PUSH_TWEEN_PER_TILE
## each, then a snap onto the committed tile; ScenePresenter echoes the shove
## on the puppet and replays the slide on the map after its wipe-out — RQD's
## first eyeball: units must not "teleport" while the stage hides them), and
## applies collision damage.
## Multi-subject ordering: a subject whose path hits a not-yet-resolved subject
## is deferred and retried, so a push wave propagates front-most-first no
## matter how the shape enumerated it; a genuine mutual block falls back to
## shape order.
##
## DEFEATS: collision damage can kill. The caster's and primary target's
## defeats are owned by the combat sequence (execute_combat_sequence already
## checks them); any OTHER unit killed here has its _handle_defeat awaited
## before resolve() returns. Collision kills award no XP for now — revisit
## with playtest.
class_name DisplacementSystem
extends RefCounted


const PUSH_TWEEN_PER_TILE: float = 0.08
const COLLISION_DAMAGE_PER_TILE: int = 2

const _RESOLVED := 0
const _DEFERRED := 1


## Pure output of build_plan(). Each mover is {unit: Node2D, path: Array[Tile],
## start_step: int, start: Vector2i}: path holds the tiles stepped through in
## order, start is the cell it left (presenters read direction from it after
## occupancy has moved on), start_step aligns simultaneous animation (a swap
## partner or chain member starts moving on the global step the subject
## reaches it). Collisions are {unit: Node2D, damage: int}.
class DisplacePlan:
	var movers: Array[Dictionary] = []
	var collisions: Array[Dictionary] = []
	var resisted: Array[Node2D] = []

	func mover_for(unit: Node2D) -> Dictionary:
		for mover: Dictionary in movers:
			if mover.unit == unit:
				return mover
		return {}


## Resolve any on-hit displacement on `move`: plan, commit occupancy, hand
## the slide to the presenter, collide. Awaitable — returns when the
## presenter's displace beat (and any collateral defeat) finishes. A null
## presenter means the map presentation (direct calls, tests).
static func resolve(caster: Node2D, target: Node2D, move: Move,
		presenter: CombatPresenter = null) -> void:
	var plan := build_plan(caster, target, move)
	if plan == null:
		return
	if presenter == null:
		presenter = MapPresenter.new()

	for unit: Node2D in plan.resisted:
		DebugConfig.log_combat("DisplacementSystem: %s resisted displacement" % unit.unit_name)
		presenter.callout(unit, "RESIST", GameColors.TEXT_PRIMARY)

	if not plan.movers.is_empty():
		_commit(plan)
		await presenter.displace(plan)
	await _apply_collisions(plan, caster, target, presenter)


# =============================================================================
# PLAN BUILDING (pure — no board mutation, no animation)
# =============================================================================

static func build_plan(caster: Node2D, target: Node2D, move: Move) -> DisplacePlan:
	if move == null or caster == null or target == null:
		return null
	if move.displace_distance <= 0:
		return null
	var caster_tile: Tile = caster.get("current_tile") as Tile
	var target_tile: Tile = target.get("current_tile") as Tile
	if caster_tile == null or target_tile == null:
		return null
	var epicenter := Vector2i(target_tile.grid_x, target_tile.grid_y)

	var plan := DisplacePlan.new()
	var subjects := _gather_subjects(caster, target, move, epicenter)
	if subjects.is_empty():
		return plan

	# Save contest. Self-displacement always goes through.
	var displaced: Array[Node2D] = []
	for subject: Node2D in subjects:
		if subject == caster or _contest_displaces(caster, subject, move):
			displaced.append(subject)
		else:
			plan.resisted.append(subject)

	# Virtual occupancy overlay: Vector2i -> occupant (Node2D or null). Cells a
	# resolved mover vacated/claimed live here; everything else reads the board.
	var overlay := {}

	if move.displace_vector.begins_with("rotate_"):
		_resolve_rotation(displaced, move, epicenter, overlay, plan)
	else:
		_resolve_linear_group(displaced, caster, target, move, epicenter, overlay, plan)
	return plan


static func _gather_subjects(caster: Node2D, target: Node2D, move: Move,
		epicenter: Vector2i) -> Array[Node2D]:
	var subjects: Array[Node2D] = []
	match move.displace_subject:
		"self":
			subjects.append(caster)
		"others_in_shape":
			var attack_direction := _dominant_axis_direction(_cell_of(caster), epicenter)
			for cell: Vector2i in _shape_cells(move.displace_shape, epicenter, attack_direction):
				var tile: Tile = GridManager.get_tile(cell.x, cell.y) as Tile
				if tile == null or tile.current_unit == null:
					continue
				var occupant: Node2D = tile.current_unit
				if occupant == caster or subjects.has(occupant):
					continue
				subjects.append(occupant)
		"target", "":
			subjects.append(target)
		_:
			push_warning("DisplacementSystem: unknown displace_subject '%s'" % move.displace_subject)

	var alive: Array[Node2D] = []
	for subject: Node2D in subjects:
		if subject.has_method("is_defeated") and subject.is_defeated():
			continue
		if (subject.get("current_tile") as Tile) == null:
			continue
		alive.append(subject)
	return alive


## Parse "row(3)"-style shape strings into {kind, size}. A bare kind gets size 1.
static func _parse_shape(shape: String) -> Dictionary:
	var kind := shape.strip_edges()
	var size := 1
	var open := kind.find("(")
	if open != -1 and kind.ends_with(")"):
		size = maxi(1, int(kind.substr(open + 1, kind.length() - open - 2)))
		kind = kind.substr(0, open)
	return {"kind": kind, "size": size}


static func _shape_cells(shape: String, epicenter: Vector2i,
		attack_direction: Vector2i) -> Array[Vector2i]:
	var parsed := _parse_shape(shape)
	var kind: String = parsed.kind
	var size: int = parsed.size
	# A zero attack axis (caster on the epicenter) defaults east so oriented
	# shapes still resolve deterministically.
	var axis := attack_direction if attack_direction != Vector2i.ZERO else Vector2i(1, 0)
	var cells: Array[Vector2i] = []
	match kind:
		"single", "":
			cells.append(epicenter)
		"line":
			for i: int in range(size):
				cells.append(epicenter + axis * i)
		"row":
			var perpendicular := Vector2i(-axis.y, axis.x)
			for offset: int in range(-((size - 1) / 2), size / 2 + 1):
				cells.append(epicenter + perpendicular * offset)
		"ring":
			cells = _ring_cells(epicenter, size)
		_:
			push_warning("DisplacementSystem: unknown displace_shape '%s'" % shape)
	return cells


## The Chebyshev ring of `radius` around `epicenter`, enumerated clockwise
## (grid Y-up) starting at north. 8 × radius cells.
static func _ring_cells(epicenter: Vector2i, radius: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var offset := Vector2i(0, radius)
	for i: int in range(8 * radius):
		cells.append(epicenter + offset)
		offset = _next_ring_offset(offset, radius, true)
	return cells


## One step along the Chebyshev-ring perimeter. Clockwise in the Y-up grid:
## the north edge heads east, the east edge heads south, and so on.
static func _next_ring_offset(offset: Vector2i, radius: int, clockwise: bool) -> Vector2i:
	var step: Vector2i
	if clockwise:
		if offset.y == radius and offset.x < radius:
			step = Vector2i(1, 0)
		elif offset.x == radius and offset.y > -radius:
			step = Vector2i(0, -1)
		elif offset.y == -radius and offset.x > -radius:
			step = Vector2i(-1, 0)
		else:
			step = Vector2i(0, 1)
	else:
		if offset.y == radius and offset.x > -radius:
			step = Vector2i(-1, 0)
		elif offset.x == -radius and offset.y > -radius:
			step = Vector2i(0, -1)
		elif offset.y == -radius and offset.x < radius:
			step = Vector2i(1, 0)
		else:
			step = Vector2i(0, 1)
	return offset + step


## Displaced when caster.stat − subject.stat > margin (strictly). No stat = no
## save. An unknown stat name refuses to displace — fail safe, warn loud.
static func _contest_displaces(caster: Node2D, subject: Node2D, move: Move) -> bool:
	if move.displace_contest_stat == "":
		return true
	var caster_data: Variant = caster.get("character_data")
	var subject_data: Variant = subject.get("character_data")
	if caster_data == null or subject_data == null:
		return true
	var caster_value: Variant = caster_data.get(move.displace_contest_stat)
	var subject_value: Variant = subject_data.get(move.displace_contest_stat)
	if caster_value == null or subject_value == null:
		push_warning("DisplacementSystem: unknown contest stat '%s'" % move.displace_contest_stat)
		return false
	return int(caster_value) - int(subject_value) > move.displace_contest_margin


# =============================================================================
# LINEAR RESOLUTION (every vector except the rotations)
# =============================================================================

## Resolve all linear subjects. A subject blocked by a not-yet-resolved subject
## defers to the back of the queue so push waves propagate front-most-first;
## if a full round makes no progress (mutual block), deferral is disabled and
## the leftovers resolve in shape order, colliding as they may.
static func _resolve_linear_group(subjects: Array[Node2D], caster: Node2D,
		target: Node2D, move: Move, epicenter: Vector2i, overlay: Dictionary,
		plan: DisplacePlan) -> void:
	var pending := subjects.duplicate()
	var allow_deferral := true
	while not pending.is_empty():
		var progressed := false
		var still_pending: Array[Node2D] = []
		for subject: Node2D in pending:
			var deferrable: Array[Node2D] = pending if allow_deferral else ([] as Array[Node2D])
			if _resolve_linear(subject, caster, target, move, epicenter, overlay, plan, deferrable) == _DEFERRED:
				still_pending.append(subject)
			else:
				progressed = true
		if still_pending.is_empty():
			return
		if not progressed:
			allow_deferral = false
		pending = still_pending


static func _resolve_linear(subject: Node2D, caster: Node2D, target: Node2D,
		move: Move, epicenter: Vector2i, overlay: Dictionary, plan: DisplacePlan,
		deferrable: Array[Node2D]) -> int:
	# Already moved as collateral (chain-shoved or swapped by an earlier
	# subject): its board tile is stale and it's had its ride. One move each.
	if not plan.mover_for(subject).is_empty():
		return _RESOLVED
	var direction := _linear_direction(move.displace_vector, caster, target, subject, epicenter)
	if direction == Vector2i.ZERO:
		return _RESOLVED

	var start := _cell_of(subject)
	var cell := start
	var path: Array[Tile] = []
	var distance := move.displace_distance
	var policy := move.displace_on_blocked

	var traveled := 0
	while traveled < distance:
		var next := cell + direction
		var next_tile: Tile = GridManager.get_tile(next.x, next.y) as Tile
		if next_tile == null or not next_tile.can_unit_move_to(GridManager.get_unit_type(subject)):
			# Wall or map edge. Every policy stops here; bonus_damage slams.
			if policy == "bonus_damage":
				_record_collision(plan, subject, distance - traveled, cell)
			break

		var occupant: Node2D = _occupant(overlay, next, next_tile)
		if occupant != null and occupant != subject:
			if deferrable.has(occupant):
				return _DEFERRED
			match policy:
				"swap":
					_resolve_swap(subject, occupant, path, next_tile, cell, overlay, plan, start)
					return _RESOLVED
				"bonus_damage":
					var remaining := distance - traveled
					_record_collision(plan, subject, remaining, cell)
					_record_collision(plan, occupant, remaining, next)
				"fall_through":
					# Sail over — the cell still costs a step; landing legality
					# is settled by the backtrack below.
					path.append(next_tile)
					cell = next
					traveled += 1
					continue
				"push_chain":
					return _resolve_push_chain(subject, direction, distance - traveled,
							path, cell, overlay, plan, start, deferrable)
			break  # stop, bonus_damage, unknown: halt before the obstacle

		path.append(next_tile)
		cell = next
		traveled += 1

	# fall_through can end mid-air over a unit: back up to the last open cell.
	while not path.is_empty():
		var landing: Tile = path.back()
		var landing_cell := Vector2i(landing.grid_x, landing.grid_y)
		var landing_occupant := _occupant(overlay, landing_cell, landing)
		if landing_occupant == null or landing_occupant == subject:
			break
		path.pop_back()

	if path.is_empty():
		DebugConfig.log_combat("DisplacementSystem: %s shoved but blocked immediately" % subject.unit_name)
		return _RESOLVED

	_add_mover(plan, subject, path, 0, overlay, start)
	return _RESOLVED


## Terminal trade of places: subject takes the blocker's tile, the blocker
## lands where the subject stood at contact. Degrades to stop when that cell
## is impassable for the blocker.
static func _resolve_swap(subject: Node2D, occupant: Node2D, path: Array[Tile],
		occupant_tile: Tile, contact_cell: Vector2i, overlay: Dictionary,
		plan: DisplacePlan, start: Vector2i) -> void:
	var contact_tile: Tile = GridManager.get_tile(contact_cell.x, contact_cell.y) as Tile
	if contact_tile == null or not contact_tile.can_unit_move_to(GridManager.get_unit_type(occupant)):
		if not path.is_empty():
			_add_mover(plan, subject, path, 0, overlay, start)
		return
	path.append(occupant_tile)
	var partner_path: Array[Tile] = [contact_tile]
	_add_mover(plan, subject, path, 0, overlay, start)
	_add_mover(plan, occupant, partner_path, path.size() - 1, overlay,
			Vector2i(occupant_tile.grid_x, occupant_tile.grid_y))


## Domino push: the contiguous train of units beyond the collision advances
## with the subject while every member's next cell is enterable (terrain per
## member; only the front needs vacancy — everyone else moves into a cell being
## vacated the same step). Chain members never contest the shove. Returns
## _DEFERRED when the train contains a not-yet-resolved subject — let it take
## its own ride first.
static func _resolve_push_chain(subject: Node2D, direction: Vector2i,
		remaining: int, path: Array[Tile], subject_cell: Vector2i,
		overlay: Dictionary, plan: DisplacePlan, start: Vector2i,
		deferrable: Array[Node2D]) -> int:
	var units: Array[Node2D] = [subject]
	var positions: Array[Vector2i] = [subject_cell]
	var scan := subject_cell + direction
	while true:
		var scan_tile: Tile = GridManager.get_tile(scan.x, scan.y) as Tile
		var member := _occupant(overlay, scan, scan_tile) if scan_tile != null else null
		if member == null:
			break
		if deferrable.has(member):
			return _DEFERRED
		units.append(member)
		positions.append(scan)
		scan += direction

	var train_paths: Array = []
	for i: int in range(units.size()):
		train_paths.append([] as Array[Tile])

	var advanced := 0
	for step: int in range(remaining):
		var front_next: Vector2i = positions[positions.size() - 1] + direction
		var front_tile: Tile = GridManager.get_tile(front_next.x, front_next.y) as Tile
		var front: Node2D = units[units.size() - 1]
		if front_tile == null or not front_tile.can_unit_move_to(GridManager.get_unit_type(front)):
			break
		if _occupant(overlay, front_next, front_tile) != null:
			break
		var jammed := false
		for i: int in range(units.size() - 1):
			var member_next: Vector2i = positions[i] + direction
			var member_tile: Tile = GridManager.get_tile(member_next.x, member_next.y) as Tile
			if member_tile == null or not member_tile.can_unit_move_to(GridManager.get_unit_type(units[i])):
				jammed = true
				break
		if jammed:
			break
		for i: int in range(units.size()):
			positions[i] += direction
			var stepped: Tile = GridManager.get_tile(positions[i].x, positions[i].y) as Tile
			(train_paths[i] as Array[Tile]).append(stepped)
		advanced += 1

	# The subject's full path = its solo walk + the chained advance; train
	# members start moving on the step the subject reached them.
	var solo_steps := path.size()
	var subject_path: Array[Tile] = path.duplicate()
	subject_path.append_array(train_paths[0] as Array[Tile])
	if not subject_path.is_empty():
		_add_mover(plan, subject, subject_path, 0, overlay, start)
	if advanced > 0:
		for i: int in range(1, units.size()):
			var member_start := Vector2i(
					(train_paths[i] as Array[Tile])[0].grid_x - direction.x,
					(train_paths[i] as Array[Tile])[0].grid_y - direction.y)
			_add_mover(plan, units[i], train_paths[i] as Array[Tile], solo_steps, overlay, member_start)
	return _RESOLVED


static func _linear_direction(vector_name: String, caster: Node2D, target: Node2D,
		subject: Node2D, epicenter: Vector2i) -> Vector2i:
	match vector_name:
		"away_from_attacker", "":
			return _dominant_axis_direction(_cell_of(caster), _cell_of(subject))
		"toward_attacker":
			return -_dominant_axis_direction(_cell_of(caster), _cell_of(subject))
		"away_from_target":
			return _dominant_axis_direction(_cell_of(target), _cell_of(subject))
		"toward_target":
			return -_dominant_axis_direction(_cell_of(target), _cell_of(subject))
		"away_from_point":
			return _dominant_axis_direction(epicenter, _cell_of(subject))
		"toward_point":
			return -_dominant_axis_direction(epicenter, _cell_of(subject))
		_:
			push_warning("DisplacementSystem: unknown displace_vector '%s'" % vector_name)
			return Vector2i.ZERO


## Unit vector from `from` to `to`, collapsed to the dominant axis; a diagonal
## tie breaks to X. Zero when the cells coincide.
static func _dominant_axis_direction(from: Vector2i, to: Vector2i) -> Vector2i:
	var dx := to.x - from.x
	var dy := to.y - from.y
	if dx == 0 and dy == 0:
		return Vector2i.ZERO
	if absi(dx) >= absi(dy):
		return Vector2i(signi(dx), 0)
	return Vector2i(0, signi(dy))


# =============================================================================
# ROTATION RESOLUTION (rotate_cw / rotate_ccw)
# =============================================================================

## Each subject walks `distance` steps along its own Chebyshev ring around the
## epicenter. Steps resolve simultaneously: a proposal is valid when its cell
## is walkable and either empty or being vacated the same step by another valid
## rotator (fixpoint). An invalid proposal stops that unit for good — trailing
## units jam behind it. on_blocked policies don't apply to rotations.
static func _resolve_rotation(subjects: Array[Node2D], move: Move,
		epicenter: Vector2i, overlay: Dictionary, plan: DisplacePlan) -> void:
	var clockwise := move.displace_vector == "rotate_cw"
	var positions := {}
	var paths := {}
	var stopped := {}
	for subject: Node2D in subjects:
		positions[subject] = _cell_of(subject)
		paths[subject] = [] as Array[Tile]

	for step: int in range(move.displace_distance):
		var proposals := {}
		for subject: Node2D in subjects:
			if stopped.get(subject, false):
				continue
			var offset: Vector2i = positions[subject] - epicenter
			var radius := maxi(absi(offset.x), absi(offset.y))
			if radius == 0:
				stopped[subject] = true
				continue
			proposals[subject] = epicenter + _next_ring_offset(offset, radius, clockwise)

		var valid := {}
		for subject: Node2D in proposals:
			var cell: Vector2i = proposals[subject]
			var tile: Tile = GridManager.get_tile(cell.x, cell.y) as Tile
			valid[subject] = tile != null and tile.can_unit_move_to(GridManager.get_unit_type(subject))

		var changed := true
		while changed:
			changed = false
			for subject: Node2D in proposals:
				if not valid[subject]:
					continue
				var blocker := _rotation_occupant(proposals[subject], subject, subjects, positions, overlay)
				if blocker == null:
					continue
				if not proposals.has(blocker) or not valid.get(blocker, false):
					valid[subject] = false
					changed = true

		var any_moved := false
		for subject: Node2D in proposals:
			if valid[subject]:
				positions[subject] = proposals[subject]
				var tile: Tile = GridManager.get_tile(positions[subject].x, positions[subject].y) as Tile
				(paths[subject] as Array[Tile]).append(tile)
				any_moved = true
			else:
				stopped[subject] = true
		if not any_moved:
			break

	for subject: Node2D in subjects:
		var path: Array[Tile] = paths.get(subject, [] as Array[Tile])
		if not path.is_empty():
			_add_mover(plan, subject, path, 0, overlay, _cell_of(subject))


## Occupant lookup during rotation: a rotating unit's VIRTUAL position wins;
## a rotating unit's stale board registration is ignored.
static func _rotation_occupant(cell: Vector2i, mover: Node2D,
		subjects: Array[Node2D], positions: Dictionary, overlay: Dictionary) -> Node2D:
	for subject: Node2D in subjects:
		if subject != mover and positions[subject] == cell:
			return subject
	var tile: Tile = GridManager.get_tile(cell.x, cell.y) as Tile
	var occupant := _occupant(overlay, cell, tile)
	if occupant != null and subjects.has(occupant):
		return null
	return occupant


# =============================================================================
# EXECUTION (animation, occupancy commit, collision damage)
# =============================================================================

## Batch occupancy commit, registration ONLY: clear EVERY mover's
## registration first, then re-register each at its destination (sequential
## move_to_tile alone would clobber on swaps/rotations — A registers onto B's
## tile while B still holds it; B's move then wipes A's registration). The
## nodes do not move here: the presenter's displace beat slides them and
## snaps each onto its tile when it is done (MapPresenter.settle_movers).
static func _commit(plan: DisplacePlan) -> void:
	for mover: Dictionary in plan.movers:
		var unit: Node2D = mover.unit
		var tile: Tile = unit.get("current_tile") as Tile
		if tile != null and tile.current_unit == unit:
			tile.clear_unit()
	for mover: Dictionary in plan.movers:
		var unit: Node2D = mover.unit
		var destination: Tile = (mover.path as Array[Tile]).back()
		if unit.has_method("_claim_tile_keep_position"):
			unit._claim_tile_keep_position(destination)
		elif unit.has_method("move_to_tile"):
			unit.move_to_tile(destination)
		DebugConfig.log_combat("DisplacementSystem: %s displaced to [%d,%d]" % [
				unit.unit_name, destination.grid_x, destination.grid_y])


static func _apply_collisions(plan: DisplacePlan, caster: Node2D, target: Node2D,
		presenter: CombatPresenter) -> void:
	for collision: Dictionary in plan.collisions:
		var unit: Node2D = collision.unit
		var damage: int = collision.damage
		if damage <= 0:
			continue
		if unit.has_method("is_defeated") and unit.is_defeated():
			continue
		DebugConfig.log_combat("DisplacementSystem: %s takes %d collision damage" % [
				unit.unit_name, damage])
		if unit.has_method("take_damage"):
			unit.take_damage(damage, {
				"element": Enums.ElementalType.NONE,
				"damage_type": Enums.DamageType.PHYSICAL,
				"name": "Collision",
			})
		# Labeled so collision damage can't read as a mystery attack — this can
		# hit bystanders the shoved unit was thrown into, with no swing animation
		# to explain it. Through the presenter: on stage when the unit is a
		# combatant, on the map for a bystander.
		presenter.callout(unit, "SLAM -%d" % damage, GameColors.TEXT_DANGER)
		# The combat sequence owns the caster's and primary target's defeats;
		# collateral (chain blockers, shape bystanders) is handled here.
		if unit != caster and unit != target \
				and unit.has_method("is_defeated") and unit.is_defeated() \
				and unit.has_method("_handle_defeat"):
			await unit._handle_defeat()


# =============================================================================
# SHARED HELPERS
# =============================================================================

static func _cell_of(unit: Node2D) -> Vector2i:
	var tile: Tile = unit.get("current_tile") as Tile
	if tile == null:
		return Vector2i.ZERO
	return Vector2i(tile.grid_x, tile.grid_y)


static func _occupant(overlay: Dictionary, cell: Vector2i, tile: Tile) -> Node2D:
	if overlay.has(cell):
		return overlay[cell]
	return tile.current_unit if tile != null else null


## Record a mover in the plan and update the virtual overlay: the start cell is
## vacated (if this unit held it) and the final cell claimed, so later subjects
## resolve against post-move truth.
static func _add_mover(plan: DisplacePlan, unit: Node2D, path: Array[Tile],
		start_step: int, overlay: Dictionary, start: Vector2i) -> void:
	if path.is_empty():
		return
	plan.movers.append({"unit": unit, "path": path, "start_step": start_step, "start": start})
	var start_tile: Tile = GridManager.get_tile(start.x, start.y) as Tile
	if _occupant(overlay, start, start_tile) == unit:
		overlay[start] = null
	var final_tile: Tile = path.back()
	overlay[Vector2i(final_tile.grid_x, final_tile.grid_y)] = unit


## `cell` = where the damaged unit sits when the impact lands (the subject's
## landing cell / the obstacle's own cell) — the preview draws its impact star
## there; execution ignores it.
static func _record_collision(plan: DisplacePlan, unit: Node2D, remaining_tiles: int,
		cell: Vector2i) -> void:
	plan.collisions.append({
		"unit": unit,
		"damage": COLLISION_DAMAGE_PER_TILE * remaining_tiles,
		"cell": cell,
	})


# =============================================================================
# PREVIEW QUERIES (pure — the board preview and combat preview panel read these)
# =============================================================================

## Would the defender's counter still reach after this move's displacement
## resolves? Distance-only approximation of the counter-time gate (skips the
## reach-clear check extended range needs — DamageCalculator's
## is_within_attack_range at execution time stays authoritative). True when
## nothing displaces, there's no counter move to deny, or the post-shove
## distance is within the counter move's effective range.
static func counter_survives_displacement(caster: Node2D, target: Node2D, move: Move) -> bool:
	if move == null or move.displace_distance <= 0:
		return true
	var counter_move: Move = target.get("assigned_move")
	if counter_move == null:
		return true
	var plan := build_plan(caster, target, move)
	if plan == null:
		return true
	return _plan_leaves_counter_in_range(plan, caster, target, counter_move)


## The mirror query: does this move's displacement PULL a currently-out-of-
## range defender into its counter range? Execution re-checks range before
## every counter, so a pulled-in defender really does retaliate (Grav Hook's
## honest price) — this lets the preview predict it instead of promising a
## free hit. False when nothing displaces, no counter move, or no legal plan
## (blocked pull = nobody moves = nothing granted). Same distance-only
## approximation as counter_survives_displacement.
static func counter_granted_by_displacement(caster: Node2D, target: Node2D, move: Move) -> bool:
	if move == null or move.displace_distance <= 0:
		return false
	var counter_move: Move = target.get("assigned_move")
	if counter_move == null:
		return false
	var plan := build_plan(caster, target, move)
	if plan == null:
		return false
	return _plan_leaves_counter_in_range(plan, caster, target, counter_move)


## Shared core of the two counter queries: post-plan Manhattan distance vs the
## counter move's effective range (Extendo included, reach-clear skipped).
static func _plan_leaves_counter_in_range(plan: DisplacePlan, caster: Node2D,
		target: Node2D, counter_move: Move) -> bool:
	var caster_cell := _plan_final_cell(plan, caster)
	var target_cell := _plan_final_cell(plan, target)
	var distance := absi(caster_cell.x - target_cell.x) + absi(caster_cell.y - target_cell.y)
	return distance <= MoveTargeting.effective_attack_range(target, counter_move)


## A unit's cell after the plan resolves: its mover's destination, or where it
## already stands if the plan doesn't move it.
static func _plan_final_cell(plan: DisplacePlan, unit: Node2D) -> Vector2i:
	var mover := plan.mover_for(unit)
	if mover.is_empty():
		return _cell_of(unit)
	var tile: Tile = (mover.path as Array[Tile]).back()
	return Vector2i(tile.grid_x, tile.grid_y)

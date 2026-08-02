## DisplacementPreviewRenderer — the "ghost of the future" board preview for
## displacing moves (RQD spec 2026-08-01). While the player aims a displacing
## move at a target, every unit the shove would move gets a silhouette ghost
## (the unit's live frame flattened to tint, wearing the projection static +
## tracking treatment — shaders/ghost_projection.gdshader) that travels from
## its tile to its projected destination, blinks twice, and resets, looping.
## Styled arrows trace each path; a plan collision draws an impact star + the
## SLAM damage it previews; a subject that RESISTS the contest gets a brace
## mark ("stands firm") instead of a ghost.
##
## Everything renders from the PURE DisplacementSystem.build_plan() — this
## class is rendering only, no game logic. Owned lazily by GridManager
## (preview_displacement / clear_displacement_preview), driven from
## InputManager._update_combat_preview — the same choke point as the combat
## preview panel, covering pointer hover AND the board cursor.
##
## ART STATUS: programmer art throughout (RQD 2026-08-01: least hand-drawn art
## — geometry is code, appeal comes from the shared projection material +
## palette + pixel alignment). Lawrence's optional upgrades: a tileable dash
## strip for Line2D (skins every arrow shape at once) and a 5px arrowhead tip.
##
## Arrow vocabulary (one point-generator per displacement family):
##   straight       push / pull (and each swap partner — their two straight
##                  arrows naturally oppose, offset apart so both read)
##   arc-over       fall_through — a parabolic hump over the overflown cells
##   chevron-chain  push_chain — repeated ticks instead of a solid shaft
##   path polyline  rotations — traced through the actual perimeter cells
##
## Reduce-motion (Settings.ui_motion_enabled false): ghosts park AT their
## destinations, no travel, no blink; the shader's animate uniform is the
## decals' existing contract and freezes the flicker separately.
class_name DisplacementPreviewRenderer
extends Node2D


const GHOST_SHADER: Shader = preload("res://shaders/ghost_projection.gdshader")
const OVERLAY_MATERIAL: ShaderMaterial = preload("res://resources/overlay_static.tres")
const LABEL_FONT: FontFile = preload("res://fonts/NotJamPixel5.ttf")

## One z-slot above the move-range live-paint (ThreatOverlayRenderer default 1),
## still under units.
const OVERLAY_Z_INDEX: int = 2

const TRAVEL_SECONDS_PER_TILE: float = 0.18  # slower than the real 0.08 shove — readable
const BLINK_SECONDS: float = 0.12
const LOOP_PAUSE_SECONDS: float = 0.35
const COLLATERAL_GHOST_ALPHA: float = 0.55  # non-primary movers render dimmer
const ARROW_WIDTH: float = 1.0              # world px — chunky under integer zoom
const CHEVRON_SPACING_PX: float = 6.0
const ARC_OVER_LIFT_PX: float = 8.0
const SWAP_ARROW_SPREAD_PX: float = 2.0
const STAR_RADIUS_PX: float = 5.0

var _ghost_material: ShaderMaterial = null
var _loop_tween: Tween = null
# Every spawned node, freed wholesale on clear().
var _spawned: Array[Node] = []
# Per-ghost animation plans: {ghost, start: Vector2, stops: Array[Vector2], start_step: int}
var _ghost_tracks: Array[Dictionary] = []


func _ready() -> void:
	z_index = OVERLAY_Z_INDEX
	_ghost_material = ShaderMaterial.new()
	_ghost_material.shader = GHOST_SHADER
	_ghost_material.set_shader_parameter("animate", 1.0 if Settings.ui_motion_enabled else 0.0)
	Settings.changed.connect(_on_settings_changed)


func _on_settings_changed() -> void:
	_ghost_material.set_shader_parameter("animate", 1.0 if Settings.ui_motion_enabled else 0.0)


## Render the future of `move` fired by `attacker` at `target`. Clears first;
## a move with no displacement (or an empty plan) leaves the board clean.
func show_preview(attacker: Unit, target: Unit, move: Move) -> void:
	clear()
	if move == null or move.displace_distance <= 0:
		return
	var plan := DisplacementSystem.build_plan(attacker, target, move)
	if plan == null:
		return

	for unit: Node2D in plan.resisted:
		_add_brace_mark(unit)

	var is_swap := move.displace_on_blocked == "swap"
	var swap_side := 1
	for mover: Dictionary in plan.movers:
		var path: Array[Tile] = mover.path
		var mover_unit: Node2D = mover.unit
		_add_ghost(mover_unit, path, int(mover.start_step), mover_unit == target)
		var offset := Vector2.ZERO
		if is_swap:
			# Swap partners travel opposing straight lines — spread them a
			# hair so both arrows read.
			offset = Vector2(0, SWAP_ARROW_SPREAD_PX * swap_side)
			swap_side = -swap_side
		_add_arrow(mover_unit, path, move, offset)

	for collision: Dictionary in plan.collisions:
		_add_slam_mark(collision)

	_start_loop()


func clear() -> void:
	if _loop_tween != null:
		_loop_tween.kill()
		_loop_tween = null
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	_spawned.clear()
	_ghost_tracks.clear()


func has_preview() -> bool:
	return not _spawned.is_empty()


# =============================================================================
# GHOSTS
# =============================================================================

func _add_ghost(unit: Node2D, path: Array[Tile], start_step: int, is_primary: bool) -> void:
	var source: Sprite2D = unit.get_node_or_null("Sprite2D") as Sprite2D
	if source == null or source.texture == null or path.is_empty():
		return
	var ghost := Sprite2D.new()
	ghost.texture = source.texture
	ghost.region_enabled = source.region_enabled
	ghost.region_rect = source.region_rect
	ghost.hframes = source.hframes
	ghost.vframes = source.vframes
	ghost.frame = source.frame
	ghost.offset = source.offset
	ghost.centered = source.centered
	ghost.flip_h = source.flip_h
	ghost.flip_v = source.flip_v
	ghost.scale = source.global_scale
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.material = _ghost_material
	if not is_primary:
		ghost.modulate.a = COLLATERAL_GHOST_ALPHA
	add_child(ghost)
	_spawned.append(ghost)

	# The ghost travels in "sprite space": each stop keeps the sprite's own
	# anchor offset relative to its unit, so mid-body-anchored casts project
	# correctly onto their destination cells.
	var anchor_offset: Vector2 = source.global_position - (unit.get("current_tile") as Tile).global_position
	var start: Vector2 = source.global_position
	var stops: Array[Vector2] = []
	for tile: Tile in path:
		stops.append(tile.global_position + anchor_offset)
	ghost.global_position = start
	_ghost_tracks.append({
		"ghost": ghost,
		"start": start,
		"stops": stops,
		"start_step": start_step,
		"rest_alpha": ghost.modulate.a,
	})


## The loop: all ghosts travel their step-aligned paths together (chain members
## wait for the shove to reach them), blink twice at their destinations, hold a
## beat, snap back, repeat. Reduce-motion parks every ghost at its destination.
func _start_loop() -> void:
	if _ghost_tracks.is_empty():
		return
	if not Settings.ui_motion_enabled:
		for track: Dictionary in _ghost_tracks:
			(track.ghost as Sprite2D).global_position = (track.stops as Array[Vector2]).back()
		return

	var total_steps := 0
	for track: Dictionary in _ghost_tracks:
		total_steps = maxi(total_steps, int(track.start_step) + (track.stops as Array[Vector2]).size())

	_loop_tween = create_tween().set_loops()
	for step: int in range(total_steps):
		var first_in_step := true
		for track: Dictionary in _ghost_tracks:
			var index: int = step - int(track.start_step)
			var stops: Array[Vector2] = track.stops
			if index < 0 or index >= stops.size():
				continue
			if first_in_step:
				_loop_tween.tween_property(track.ghost, "global_position",
						stops[index], TRAVEL_SECONDS_PER_TILE)
				first_in_step = false
			else:
				_loop_tween.parallel().tween_property(track.ghost, "global_position",
						stops[index], TRAVEL_SECONDS_PER_TILE)
	for blink: int in range(2):
		_set_all_ghost_alpha(0.0, true)
		_set_all_ghost_alpha(1.0, false)
	_loop_tween.tween_interval(LOOP_PAUSE_SECONDS)
	_loop_tween.tween_callback(_reset_ghosts)


func _set_all_ghost_alpha(fraction: float, sequential_first: bool) -> void:
	var first := sequential_first
	for track: Dictionary in _ghost_tracks:
		var target_alpha: float = float(track.rest_alpha) * fraction
		if first:
			_loop_tween.tween_property(track.ghost, "modulate:a", target_alpha, BLINK_SECONDS)
			first = false
		else:
			_loop_tween.parallel().tween_property(track.ghost, "modulate:a", target_alpha, BLINK_SECONDS)


func _reset_ghosts() -> void:
	for track: Dictionary in _ghost_tracks:
		var ghost := track.ghost as Sprite2D
		if not is_instance_valid(ghost):
			continue
		ghost.global_position = track.start
		ghost.modulate.a = float(track.rest_alpha)


# =============================================================================
# ARROWS (programmer art — geometry is code, appeal is the shared material)
# =============================================================================

func _add_arrow(unit: Node2D, path: Array[Tile], move: Move, offset: Vector2) -> void:
	if path.is_empty():
		return
	var start: Vector2 = (unit.get("current_tile") as Tile).global_position + offset
	var color := _arrow_color(move)

	if move.displace_vector.begins_with("rotate_"):
		var points: Array[Vector2] = [start]
		for tile: Tile in path:
			points.append(tile.global_position + offset)
		_spawn_polyline(points, color)
		_spawn_arrowhead(points[-1], points[-1] - points[-2], color)
		return

	var finish: Vector2 = path.back().global_position + offset
	match move.displace_on_blocked:
		"fall_through":
			var points: Array[Vector2] = []
			var samples := 8
			for i: int in range(samples + 1):
				var t := float(i) / float(samples)
				var point := start.lerp(finish, t)
				point.y -= sin(t * PI) * ARC_OVER_LIFT_PX
				points.append(point)
			_spawn_polyline(points, color)
			_spawn_arrowhead(finish, points[-1] - points[-2], color)
		"push_chain":
			var direction := (finish - start).normalized()
			var length := start.distance_to(finish)
			var travelled := CHEVRON_SPACING_PX
			while travelled < length:
				_spawn_arrowhead(start + direction * travelled, direction, color)
				travelled += CHEVRON_SPACING_PX
			_spawn_arrowhead(finish, direction, color)
		_:
			_spawn_polyline([start, finish] as Array[Vector2], color)
			_spawn_arrowhead(finish, finish - start, color)


## Arrows carry the move's INTENT, matching the live-paint color rule.
func _arrow_color(move: Move) -> Color:
	match GridManager.move_range_preview_style(move):
		ThreatOverlayRenderer.Style.PREVIEW_HEAL:
			return GameColorPalette.get_color("Green", 7)
		ThreatOverlayRenderer.Style.PREVIEW_DAMAGE:
			return GameColorPalette.get_color("Red", 7)
		_:
			return GameColorPalette.get_color("Azure", 7)


func _spawn_polyline(points: Array[Vector2], color: Color) -> void:
	var line := Line2D.new()
	for point: Vector2 in points:
		line.add_point(point)
	line.width = ARROW_WIDTH
	line.default_color = color
	line.material = OVERLAY_MATERIAL
	add_child(line)
	_spawned.append(line)


func _spawn_arrowhead(tip: Vector2, direction: Vector2, color: Color) -> void:
	if direction.length_squared() == 0.0:
		direction = Vector2.RIGHT
	var forward := direction.normalized()
	var side := forward.orthogonal()
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([
		tip,
		tip - forward * 3.0 + side * 2.0,
		tip - forward * 3.0 - side * 2.0,
	])
	head.color = color
	head.material = OVERLAY_MATERIAL
	add_child(head)
	_spawned.append(head)


# =============================================================================
# SLAM STARS + RESIST BRACES
# =============================================================================

func _add_slam_mark(collision: Dictionary) -> void:
	var cell: Vector2i = collision.get("cell", Vector2i(-9999, -9999))
	var tile: Tile = GridManager.get_tile(cell.x, cell.y) as Tile
	if tile == null:
		return
	var center: Vector2 = tile.global_position
	var star := Polygon2D.new()
	var points := PackedVector2Array()
	for i: int in range(8):
		var angle := TAU * float(i) / 8.0
		var radius := STAR_RADIUS_PX if i % 2 == 0 else STAR_RADIUS_PX * 0.45
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	star.polygon = points
	star.color = GameColorPalette.get_color("Red", 8)
	star.material = OVERLAY_MATERIAL
	add_child(star)
	_spawned.append(star)

	var label := Label.new()
	label.text = "-%d" % int(collision.damage)
	label.add_theme_font_override("font", LABEL_FONT)
	label.add_theme_font_size_override("font_size", 5)
	label.add_theme_color_override("font_color", GameColorPalette.get_color("Red", 8))
	label.position = center + Vector2(STAR_RADIUS_PX + 1.0, -STAR_RADIUS_PX)
	add_child(label)
	_spawned.append(label)


## "Stands firm": two short bars under a unit that resisted the contest —
## absence of a ghost alone is weak feedback.
func _add_brace_mark(unit: Node2D) -> void:
	var tile: Tile = unit.get("current_tile") as Tile
	if tile == null:
		return
	var center: Vector2 = tile.global_position
	for row: int in range(2):
		var bar := Line2D.new()
		var y := center.y + 7.0 + float(row) * 2.0
		bar.add_point(Vector2(center.x - 4.0, y))
		bar.add_point(Vector2(center.x + 4.0, y))
		bar.width = ARROW_WIDTH
		bar.default_color = GameColorPalette.get_color("Gray", 7)
		bar.material = OVERLAY_MATERIAL
		add_child(bar)
		_spawned.append(bar)

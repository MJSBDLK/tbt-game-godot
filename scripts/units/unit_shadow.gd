## Generated cast shadow for a unit — the dynamic half of the shadow system
## (RQD 2026-07-31: "saves Lawrence dozens of hours animating this stuff by
## hand"). Mirrors the unit's live Sprite2D frame and lays its silhouette on
## the ground, so every animation the unit plays — idle strips, attack clips,
## the boop lunge — casts for free.
##
## CURRENT ITERATION (RQD 2026-08-01): the WHOLE silhouette turned 90°
## clockwise on the feet pivot — a rigid tip-over, head pointing screen-right
## — then three distortion dials, all identity by default so the untouched
## baseline renders undistorted:
##   SHADOW_SMOOSH_X — length/reach scale (sun elevation). 1.0 = none.
##   SHADOW_SMOOSH_Y — vertical body scale about the feet line. 1.0 = none.
##   SHADOW_SHEAR    — lean (RQD's "parallelogramization"). 0.0 = none.
##   SHADOW_OFFSET_Y — flat vertical placement nudge. 0.0 = none.
##   SHADOW_BLOB_*   — contact-shadow disc unioned under the cast (see the
##                     blob consts below). Off = pure silhouette cast.
## Tinker in F5 loops; when values lock they become the sun parameters.
##
## The rendering is RASTERIZED, not transformed (first eyeball round: a
## transformed Node2D renders its diagonal/rotated edges at NATIVE
## resolution, breaking the world pixel grid — "they aren't output at
## reference res"). Every opaque source pixel is turned/distorted on the CPU
## into an integer world-pixel cell, unioned into a small image, cached per
## (frame, flip, knobs), and drawn as ONE axis-aligned, integer-positioned
## rect. The mask is flat white and the ink arrives as a draw modulate
## (GameColors.CAST_SHADOW_INK, 40% black decoded from Lawrence's decoration
## shadows), so the smear can never self-darken.
##
## Anchoring: the turn pivots at the VISUAL FEET — the node origin
## (canvas center, offset-corrected) plus `feet_drop`, because the cast is
## authored body-centered: the canvas-center pivot every sidecar carries is
## the WAIST, with the boots ~10-16px lower (RQD's diagnosis + full-cast
## survey 2026-07-31; an earlier build pivoted at the origin and every
## shadow swung around the character's shins). The WHOLE frame turns — no
## crop: content above the feet lands right of them, anything below (rare
## once the pivot is the boots) lands left. An even earlier pivot-line crop
## amputated below-origin art ("Are they being smooshed?"); if some content
## shouldn't cast, that's a knob decision, not a silent crop.
##
## What passes through the projection vs. around it:
##   THROUGH — the frame (texture/region/flip/offset): silhouette content.
##   AROUND  — source_sprite.position (the boop lunge): GROUND motion,
##             mirrored 1:1 as a draw offset.
##   NEVER   — source_sprite.modulate: the selection pulse brightens the
##             sprite; a shadow doesn't pulse. (Unit-level modulate — e.g. a
##             death fade — still reaches us via canvas inheritance.)
##
## flip_h mirrors the silhouette before turning; the cast direction is the
## global sun and never flips with facing.
##
## Z: relative child slot TERRAIN_EFFECTS − UNITS (−4) lands the shadow in
## the decoration-shadow band of the unit's OWN row, tracking _update_z_index
## with zero extra bookkeeping. Shadows of DIFFERENT units double-darken
## where they overlap; Lawrence eyeballed the decoration equivalent and
## shrugged (RQD 2026-07-31 — decorations even triple-cast fine).
##
## Future (deliberately not built until an asset exists): per-clip authored
## override — the tag exporter already emits <tag>_shadow.png strips when a
## clip's .aseprite has a shadow layer; when one exists, play it verbatim
## instead of generating.
class_name UnitShadow
extends Node2D


## RQD's three dials (2026-08-01), all at identity defaults.
##
## Horizontal scale of the smear — rightward reach per pixel of sprite
## height, about the feet point. 1.0 = full height lies down; the decoration
## shelltree ratio was 0.85. This is the sun-ELEVATION knob: lower sun =
## longer shadow.
const SHADOW_SMOOSH_X: float = 1.0

## Vertical scale of the smear about the feet line. 1.0 = the full rigid
## turn; ~0.2-0.35 approximates the decoration smears; 0.0 collapses to a
## 1px line.
const SHADOW_SMOOSH_Y: float = 0.25

## Shear — the standard term for RQD's "parallelogramization" (rows slide
## sideways proportionally to their distance from the feet line; rectangles
## become parallelograms). 0.0 = none. Positive shifts below-feet rows right
## and above-feet rows left; flip the sign to taste. NOTE: this is also the
## compass dial — any nonzero shear drags the cast off due-east toward a
## diagonal (see RQD's east-southeast question, 2026-08-01).
const SHADOW_SHEAR: float = 0

## Flat vertical nudge for the DRAWN smear, in pixels, on top of the
## per-character feet_drop. Positive = down-screen. Placement only — the
## projection shape is untouched.
const SHADOW_OFFSET_Y: float = -2

## Blob (contact) shadow — RQD's "COMPOSITE_DROP_SHADOW" (2026-08-01): a
## disc centered where the feet meet the ground, unioned UNDER the cast
## silhouette. Wide-stance sprites cast two disconnected leg-strips; the
## blob welds them into one grounded mass (Ma'am, feet together, never
## needed it). The disc goes through the SAME dial pipeline as body pixels
## — smoosh_x / smoosh_y / shear — so it renders as an ellipse matching the
## cast's distortion, and feet_drop + SHADOW_OFFSET_Y place it via the
## shared anchor. Flip off to return to the pure silhouette cast.
##
## Sizing: measured ONCE from the idle frame at spawn (measure_stance_radius,
## injected by Unit as blob_radius) — a feet-band percentile width, NOT the
## sprite's widest points, and constant across every animation frame so the
## blob never breathes mid-attack. Atlas-path placeholders (no readable
## measurement) get radius 0 → no blob. If a specific character's stance
## defies the heuristic, the escape hatch is a per-character radius in the
## character JSON — deliberately unbuilt until someone needs it.
const SHADOW_BLOB_ENABLED: bool = true

## Blob size: taste multiplier on the measured stance radius. 1.0 = the
## disc spans the measured stance.
const SHADOW_BLOB_WIDTH_FACTOR: float = 1.0

## Stance measurement (RQD 2026-08-01: "size the drop shadow to the unit's
## FEET rather than the widest points"): only pixels within this many rows
## of the art's lowest opaque row count — feet are, by definition, the
## pixels near the ground; arms and rifles are higher.
const SHADOW_BLOB_FEET_BAND_PIXELS: int = 4

## Robustness trim: this fraction of the band's opaque pixels is shed from
## each side of the x-distribution before measuring width, so a 1px cape or
## blade tip can't balloon the disc (percentile width, the standard trick —
## extremes lie, distributions don't).
const SHADOW_BLOB_STANCE_TRIM: float = 0.1

## Source pixels at or below this alpha don't cast (guards against stray
## semi-transparent edge texels; pixel art alpha is hard).
const ALPHA_SOLID_THRESHOLD: float = 0.5

## The unit's Sprite2D, injected by Unit._ready. We never tree-walk for it.
var source_sprite: Sprite2D = null

## How far the sprite's VISUAL FEET sit below the node origin, in pixels —
## injected by Unit from the idle sidecar's art_bounds.bottom. Lawrence
## authors the BODY centered on the canvas, so the runtime anchor (canvas
## center = cell center) is mid-body and the feet land ~10-16px lower —
## uniformly true across the whole cast (RQD's diagnosis 2026-07-31: "I was
## thinking of the pivot as they're imported"). The unit STANDS correctly on
## that mid-body anchor; the shadow alone pivots at the boots.
var feet_drop: float = 0.0

## Contact-disc radius in pre-distortion pixels, injected by Unit from
## measure_stance_radius on the idle frame — once per character, constant
## across all animation frames. 0 = no blob (atlas placeholders, bare test
## units).
var blob_radius: float = 0.0

# Snapshot of the mirrored frame — we only rebuild/redraw on change, so a
# unit standing in idle costs nothing per tick.
var _frame_texture: Texture2D = null
var _frame_region: Rect2
var _frame_flip_h: bool = false
var _frame_offset: Vector2
var _ground_offset: Vector2

# The rasterized shadow image and its top-left in node space (feet at origin).
var _projection: ImageTexture = null
var _projection_anchor: Vector2

# Shadow images are pure functions of (frame, flip, pivot, knobs) — cache
# across all units so each attack frame rasterizes once per session. Values
# are {"texture": ImageTexture, "anchor": Vector2}.
static var _projection_cache: Dictionary = {}
# Decompressed full-sheet images, keyed by texture RID.
static var _sheet_image_cache: Dictionary = {}
static var _warned_unreadable: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_as_relative = true
	z_index = ZIndexCalculator.ZIndexLayer.TERRAIN_EFFECTS \
			- ZIndexCalculator.ZIndexLayer.UNITS


func _process(_delta: float) -> void:
	sync_to_source()


## Mirror the source sprite's live frame; rebuild the shadow image only when
## the frame actually changed. Called every tick; also callable directly
## (tests, forced refresh).
func sync_to_source() -> void:
	if source_sprite == null or source_sprite.texture == null \
			or not source_sprite.visible \
			or not DebugConfig.unit_cast_shadows:
		visible = false
		return
	visible = true
	var region := source_sprite.region_rect if source_sprite.region_enabled \
			else Rect2(Vector2.ZERO, source_sprite.texture.get_size())
	if source_sprite.texture != _frame_texture or region != _frame_region \
			or source_sprite.flip_h != _frame_flip_h \
			or source_sprite.offset != _frame_offset:
		_frame_texture = source_sprite.texture
		_frame_region = region
		_frame_flip_h = source_sprite.flip_h
		_frame_offset = source_sprite.offset
		_rebuild_projection()
		queue_redraw()
	if source_sprite.position != _ground_offset:
		_ground_offset = source_sprite.position
		queue_redraw()


func _draw() -> void:
	if _projection == null or not visible:
		return
	var dst := Rect2(_projection_anchor + _ground_offset.round(),
			Vector2(_projection.get_size()))
	draw_texture_rect(_projection, dst, false, GameColors.CAST_SHADOW_INK)


## The ground projection, as a pure function so GUT can pin the geometry.
## Input: the FULL frame silhouette (already facing-flipped) and the pivot —
## the feet point — in its pixel coordinates. Each opaque pixel is turned 90°
## clockwise about the pivot (canvas-up becomes screen-right; the caster's
## left edge lands up-screen), smooshed on both axes about the feet, then
## sheared. With blob_width_factor > 0 a contact disc (radius = half the
## stance width × factor) centered on the feet joins the union, through the
## same dials. Output: {"image": flat-white union mask cropped to the ink,
## "anchor": Vector2 — the image's top-left in feet-origin node space}, or {}
## when nothing casts. Draw modulate supplies the shadow color.
static func project_silhouette(silhouette: Image, pivot: Vector2,
		smoosh_x: float = SHADOW_SMOOSH_X,
		smoosh_y: float = SHADOW_SMOOSH_Y,
		shear: float = SHADOW_SHEAR,
		blob_disc_radius: float = 0.0) -> Dictionary:
	if silhouette == null:
		return {}
	var pivot_x := roundi(pivot.x)
	var pivot_y := roundi(pivot.y)
	var cells: Array[Vector2i] = []
	for y in range(silhouette.get_height()):
		for x in range(silhouette.get_width()):
			if silhouette.get_pixel(x, y).a <= ALPHA_SOLID_THRESHOLD:
				continue
			# Rigid 90° CW turn about the pivot, in pixel-corner space —
			# then smoosh both axes about the feet, then lean what remains.
			var cell_x := floori(float(pivot_y - y - 1) * smoosh_x)
			var cell_y := floori(float(x - pivot_x) * smoosh_y)
			cell_x += roundi(cell_y * shear)
			cells.append(Vector2i(cell_x, cell_y))
	if cells.is_empty():
		return {}
	if blob_disc_radius > 0.0:
		# Blob (contact) disc centered on the feet point, run through the
		# SAME dial pipeline as body pixels so it lands as a matching
		# ellipse. The radius arrives pre-measured (idle stance).
		var reach := ceili(blob_disc_radius)
		for blob_dy in range(-reach, reach + 1):
			for blob_dx in range(-reach, reach + 1):
				if float(blob_dx * blob_dx + blob_dy * blob_dy) \
						> blob_disc_radius * blob_disc_radius:
					continue
				var blob_x := floori(blob_dx * smoosh_x)
				var blob_y := floori(blob_dy * smoosh_y)
				blob_x += roundi(blob_y * shear)
				cells.append(Vector2i(blob_x, blob_y))
	var low := cells[0]
	var high := cells[0]
	for cell in cells:
		low = low.min(cell)
		high = high.max(cell)
	var image := Image.create(high.x - low.x + 1, high.y - low.y + 1,
			false, Image.FORMAT_RGBA8)
	for cell in cells:
		image.set_pixel(cell.x - low.x, cell.y - low.y, Color.WHITE)
	return {"image": image, "anchor": Vector2(low)}


func _rebuild_projection() -> void:
	_projection = null
	var blob_disc_radius: float = \
			blob_radius * SHADOW_BLOB_WIDTH_FACTOR if SHADOW_BLOB_ENABLED else 0.0
	var cache_key := "%s|%s|%s|%s|%.1f|%.3f|%.3f|%.3f|%.2f" % [
			_frame_texture.get_rid(), _frame_region, _frame_flip_h,
			_frame_offset, feet_drop,
			SHADOW_SMOOSH_X, SHADOW_SMOOSH_Y, SHADOW_SHEAR, blob_disc_radius]
	if not _projection_cache.has(cache_key):
		var frame := _extract_frame()
		if frame == null:
			return
		# The turn pivots at the VISUAL FEET: node origin (canvas center,
		# offset-corrected) plus the body-centered cast's feet gap.
		var pivot := _frame_region.size / 2.0 - _frame_offset \
				+ Vector2(0.0, feet_drop)
		var projected := project_silhouette(frame, pivot,
				SHADOW_SMOOSH_X, SHADOW_SMOOSH_Y, SHADOW_SHEAR,
				blob_disc_radius)
		if projected.is_empty():
			return
		_projection_cache[cache_key] = {
			"texture": ImageTexture.create_from_image(projected["image"]),
			"anchor": projected["anchor"],
		}
	var cached: Dictionary = _projection_cache[cache_key]
	_projection = cached["texture"]
	# The cached anchor is FEET-relative (cells measure from the pivot).
	# The feet sit feet_drop below the node origin — translate, or the whole
	# shadow renders at the waist (RQD 2026-08-01: "originating from the
	# waist", measured the miss at −12 from tile center — this exact term).
	# SHADOW_OFFSET_Y rides on top as the global placement fudge.
	_projection_anchor = cached["anchor"] \
			+ Vector2(0.0, feet_drop + SHADOW_OFFSET_Y)


## Stance radius for the blob disc, measured from a character's idle
## texture: the percentile width of the opaque pixels in the FEET BAND (the
## lowest SHADOW_BLOB_FEET_BAND_PIXELS rows of the art), halved. Feet are
## the pixels near the ground — a rifle held high never widens the disc,
## and the trim sheds stray 1px tips (capes, blades). Unit calls this once
## at spawn and injects the result as blob_radius. Returns 0 when the
## texture has no readable image or no opaque pixels.
static func measure_stance_radius(texture: Texture2D,
		band_pixels: int = SHADOW_BLOB_FEET_BAND_PIXELS,
		trim_fraction: float = SHADOW_BLOB_STANCE_TRIM) -> float:
	var sheet := _readable_sheet(texture)
	if sheet == null:
		return 0.0
	var lowest_row := -1
	for y in range(sheet.get_height() - 1, -1, -1):
		for x in range(sheet.get_width()):
			if sheet.get_pixel(x, y).a > ALPHA_SOLID_THRESHOLD:
				lowest_row = y
				break
		if lowest_row != -1:
			break
	if lowest_row == -1:
		return 0.0
	var stance_columns: Array[int] = []
	for y in range(maxi(0, lowest_row - band_pixels + 1), lowest_row + 1):
		for x in range(sheet.get_width()):
			if sheet.get_pixel(x, y).a > ALPHA_SOLID_THRESHOLD:
				stance_columns.append(x)
	if stance_columns.is_empty():
		return 0.0
	stance_columns.sort()
	var trim_count := mini(int(stance_columns.size() * trim_fraction),
			(stance_columns.size() - 1) / 2)
	var low_x := stance_columns[trim_count]
	var high_x := stance_columns[stance_columns.size() - 1 - trim_count]
	return float(high_x - low_x + 1) * 0.5


## The frame's opaque content, facing-flipped, as an Image. Returns null
## for textures whose pixels can't be read back — the shadow simply doesn't
## render for those.
func _extract_frame() -> Image:
	var sheet_image := _readable_sheet(_frame_texture)
	if sheet_image == null:
		return null
	var frame := sheet_image.get_region(Rect2i(_frame_region))
	if _frame_flip_h:
		frame.flip_x()
	return frame


## Decompressed RGBA8 image for a texture, cached by RID; null (with a
## one-time warning) when the pixels can't be read back.
static func _readable_sheet(texture: Texture2D) -> Image:
	var rid_key := "%s" % texture.get_rid()
	if _sheet_image_cache.has(rid_key):
		return _sheet_image_cache[rid_key]
	var sheet := texture.get_image()
	if sheet == null:
		if not _warned_unreadable.has(rid_key):
			_warned_unreadable[rid_key] = true
			push_warning("UnitShadow: texture '%s' has no readable image — no cast shadow."
					% texture.resource_path)
		return null
	if sheet.is_compressed():
		sheet.decompress()
	sheet.convert(Image.FORMAT_RGBA8)
	_sheet_image_cache[rid_key] = sheet
	return sheet

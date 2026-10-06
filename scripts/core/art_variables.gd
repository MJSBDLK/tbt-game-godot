## ART KNOBS — Lawrence's file.
##
## Every number here changes how the game LOOKS, never how it plays. Change a
## value, save, press F5 in Godot, look at it. Nothing else needs touching:
## the rest of the code reads these.
##
## Or turn one WHILE THE GAME RUNS: press ` (the key under Esc) for the
## console, type `shadow_ink_alpha 0.3`, look. `list` shows every knob. When
## it looks right, `dump` copies what you changed to the clipboard as lines in
## this file's own words — paste them over the matching lines here. `help` has
## the rest. Nothing you type there touches this file by itself; the file is
## what sticks.
##
## Editing rules:
##   - Only change what comes after the `=`. Leave the rest of the line alone.
##   - Decimals need a leading zero: 0.4, never .4
##   - true / false are lowercase.
##   - If the game refuses to start after an edit, undo (Ctrl+Z) and save. It
##     will be the line you just touched. To throw away every change you made
##     here: `git checkout -- scripts/core/art_variables.gd`
##   - Nothing in this file can break the RULES of the game. These numbers
##     decide how it looks, never how it plays.
##
## COLORS ARE NOT HERE — they have their own homes, all of them yours:
##   - The palette itself: art/colors/SpacemanColorPalette_v1.42.gpl, the file
##     you edit in Aseprite. GameColorPalette loads it, so a ramp you change
##     there changes in the game.
##   - Which ramp each thing uses (health bars, warning text, shadows):
##     scripts/core/game_colors.gd, with data/design/ui-style-guide.md as the
##     rulebook for why. Those pairings are a shared call — change the palette
##     freely, but talk to RQD before re-pointing a role at a different ramp.
class_name ArtVariables


# =============================================================================
# SHADOWS
# =============================================================================
# One sun for the whole board: units, mountains, trees and buildings all cast
# the same way. These are the dials for that sun.

## How dark EVERY shadow on the board is — units, mountains, trees, buildings.
## 0.0 is invisible, 1.0 is solid black. 0.4 means the ground underneath shows
## through at 60%. Sane range: 0.1 to 0.7.
##
## ONE other copy exists: PREVIEW_SHADOW_ALPHA in
## tools/aseprite/webtyler/webtyler.lua, which is what your Aseprite tileset
## preview draws with (Lua can't read this file). It's this number × 255, so
## 0.4 → 102. Change both and they stay honest; change one and a test tells
## you which you missed.
static var SHADOW_INK_ALPHA: float = 0.4

## How far a shadow reaches, as a fraction of the caster's height. 1.0 lays
## the whole sprite flat on the ground; 0.5 is a shorter, higher-sun shadow.
## Sane range: 0.3 to 2.0.
static var SHADOW_LENGTH: float = 1.0

## How squat the shadow is. 1.0 is the full tip-over; 0.25 presses it down
## toward the ground so it reads as lying flat.
## Sane range: 0.1 to 1.0.
static var SHADOW_SQUASH: float = 0.25

## Leans the shadow sideways. 0.0 casts due east (right); positive numbers
## drag it toward the south-east.
## Sane range: -0.5 to 0.5.
static var SHADOW_LEAN: float = 0.0

## Moves the drawn shadow up or down by this many pixels without changing its
## shape. Negative lifts it toward the feet.
## Sane range: -8 to 8.
static var SHADOW_NUDGE_Y: float = -2.0

## The contact blob: a disc under a unit's feet that welds a wide stance into
## one grounded mass. false draws the bare silhouette instead.
static var SHADOW_BLOB: bool = true

## Blob size, as a multiple of the unit's measured stance width. 1.0 spans
## exactly as wide as the feet do. Sane range: 0.5 to 2.0.
static var SHADOW_BLOB_WIDTH: float = 1.0

## true lets a shadow fall ON the thing beside it — a mountain's shadow lands
## on the next mountain, a unit's lands on the tree it stands beside. false
## tucks every shadow under the sprites instead, so nothing is ever shaded by
## its neighbour.
static var SHADOWS_FALL_ON_NEIGHBORS: bool = true

## Moves the GENERATED terrain shadows (the ones the game invents for art that
## ships no shadow of its own) up or down by this many pixels. Units have
## their own nudge above, because their art hangs differently in the cell.
static var TERRAIN_SHADOW_NUDGE_Y: float = 0.0


# =============================================================================
# MAP EDGE
# =============================================================================

## How far in from the edge of the map the board fades out, in pixels, and
## what it fades to. Both the ground and anything overhanging it (a tree's
## canopy past the last tile) use these, so the edge darkens as one piece.
## Sane range for the width: 8 to 128.
static var MAP_EDGE_FADE_WIDTH: float = 32.0
static var MAP_EDGE_FADE_COLOR: Color = Color(0.0, 0.0, 0.0, 1.0)


# =============================================================================
# UNITS
# =============================================================================

## How grey a unit goes once it has acted this turn. 1.0 drains the colour
## completely; 0.0 leaves it untouched. It never darkens — a darkening tint
## sank the dark sprites into the ground. Sane range: 0.0 to 1.0.
static var ACTED_GREYSCALE: float = 1.0

## The outline flash when End Turn points at the units that can still act:
## amber rings closing in on each one's outline. It plays a few times in a
## row, rests, and repeats until the player answers.
##
## One flash, in seconds. Sane range: 0.2 to 2.0.
static var UNIT_CALL_TO_ACTION_SECONDS: float = 0.5

## How many flashes in a set before the rest. Whole numbers. Sane range: 1 to 5.
static var UNIT_CALL_TO_ACTION_PASSES: int = 3

## How far into one flash the next one starts, as a fraction of a flash.
## 1.0 waits for it to finish; 0.5 starts halfway, so two rings are closing
## in at once; 0.33 gets three. Sane range: 0.2 to 1.0.
static var UNIT_CALL_TO_ACTION_STAGGER: float = 0.5

## The quiet gap after a set's last flash ends and before the next set, in
## seconds. Sane range: 0.0 to 3.0.
static var UNIT_CALL_TO_ACTION_REST_SECONDS: float = 1.0


# =============================================================================
# NIGHT SKY
# =============================================================================
# Twinkling stars. Paint your stars on the sky the way they look at rest; a
# dot on your twinkle layer, right on top of one, makes it flash: red as an X,
# green as a +, red and green together take turns, blue says how often (0
# rarely, 255 nearly always), and how bright you paint the dot is how far its
# tails reach (up to 3 px). Between flashes your own star shows. The lab page
# (data/design/mockups/skybox_twinkle_lab.html) has these same dials as
# sliders; its "Send these numbers back" block prints them as lines for here.

## How long each frame of a flash lasts, in seconds. The tails grow a pixel
## per frame and pull back the same way (1, 2, 3, 2, 1), every frame this
## long. Sane range: 0.05 to 0.5.
static var STAR_STEP_SECONDS: float = 0.1

## Extra time on the full-stretch frame before the tails pull back, in
## seconds. 0.0 turns straight around. Sane range: 0.0 to 2.0.
static var STAR_HOLD_SECONDS: float = 0.0

## Extra time on the 1 px frames, the first and last of each flash, in
## seconds. A star whose tails only reach 1 px uses the hold above instead.
## Sane range: 0.0 to 2.0.
static var STAR_DIM_HOLD_SECONDS: float = 0.0

## Seconds between flashes for a star painted with NO blue …
static var STAR_PERIOD_SLOW_SECONDS: float = 8.0

## … and for one painted with FULL blue (255). Sane range: 0.5 to 30 for both.
static var STAR_PERIOD_FAST_SECONDS: float = 1.5

## How far each star's own timing strays from those two numbers, so neighbours
## never flash in step. 0.2 means up to 20% either way. Sane range: 0.0 to 0.5.
static var STAR_PERIOD_JITTER: float = 0.2

## How bright a tail's newest pixel is when it appears (1.0 = as bright as the
## star). The pixels behind it brighten a step each as the tail grows.
## Sane range: 0.1 to 1.0.
static var STAR_TAIL_TIP_ALPHA: float = 0.35

## Where there's no painted sky under the twinkle layer (the lab page, the
## menu's sky until it's painted), each dot draws its own star between
## flashes: bright dots at full, and this is how bright the DIMMEST one sits.
## Over your painted skies your own stars show instead. Sane range: 0.0 to 1.0.
static var STAR_REST_ALPHA_MIN: float = 0.1


# =============================================================================
# SMOKE
# =============================================================================
# Painted smoke, brought to life: any combat backdrop layer with "smoke" in its
# name. Your painting is the smoke at rest. Patches of thicker and thinner
# smoke drift through it: thin patches hide some of your pixels, thick ones
# fill the holes between them a step or two lighter. Your pixels keep their
# colours; the plume keeps its shape.

## How long each frame of the smoke lasts, in seconds. Sane range: 0.06 to 0.5.
static var SMOKE_STEP_SECONDS: float = 0.125

## How fast the patches rise, in pixels per second. Sane range: 0.0 to 30.0.
static var SMOKE_RISE_SPEED: float = 6.0

## How fast they drift sideways, in pixels per second; minus drifts left.
## Sane range: -30.0 to 30.0.
static var SMOKE_DRIFT_SPEED: float = 3.0

## How big one patch is, in pixels. Sane range: 2.0 to 24.0.
static var SMOKE_PATCH_SIZE: float = 4.0

## Roughly how much of your painted smoke is hidden at any moment.
## 0.0 hides none. Sane range: 0.0 to 0.6.
static var SMOKE_BREAKUP: float = 0.3

## Roughly how much of the gaps between your pixels fill in as thick smoke.
## 0.0 never fills them. Sane range: 0.0 to 0.6.
static var SMOKE_THICKNESS: float = 0.3

## How many steps up the ramp the thick smoke is from the pixels around it;
## minus makes it darker. Sane range: -2 to 2.
static var SMOKE_THICK_STEPS: int = 1

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

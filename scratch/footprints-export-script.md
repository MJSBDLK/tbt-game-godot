Lawrence wants to add a footprints system. We have a new footprints.aseprite file which contains the tileset for each biome/base terrain.

They're currently footprints on alpha, i.e. no background texture - these need to get layered on top of the terrain layer. It's important that they only get layered on matching terrains, e.g. if the tile is regolith, the reolith footprints can appear. But if the tile is sand-on-regolith, sand being the tile's main property, then the footprints would not appear.

In the aseprite file,each tag is one variation and needs its own set of imports. I think we want to import into:
sprites->footprints->{variant}->{variant}_e.png, {variant}_ns.png, etc.
No animations or shadows currently, but in the future, we may add both animation support (per-tag), and shadow layer support (would be its own layer, called "Shadow"). Let's make sure that we design the importer in such a way that adding these features later is not a giant pain.

On the maps: This means we'll need a new tile layer between the terrain tiles and the modifier tiles, with its own layer in the z-indexing system. We're also overlaying these X deep: more details on that below.

We need a new importer script. Within the footprints.aseprite file, the footprints are laid out as follows, 32x32 as usual, with some extra room in case we decide to add more later:
### From left to right, top to bottom:
+ E, S, W, N
+ SE, WE, WS
+ SN, <empty>, NS
+ EN, EW, NW

So if the footprints have a single value, e.g. E, that means the unit walked in from the East and stopped on the center of the tile, or started from the center of the tile and walked East.

It wouldn't make much sense for a unit to spawn in without any footprints leading to their position at the start of a level, but let the level designer worry about that. Footprints script doesn't need to worry about this, but it does mean that we need these available as stamp tiles.

If the tile has a value of e.g. SE or ES, that means the unit entered from the South and moved East, or the opposite - entered from the East and went South. The visual design is such that the sprites are direction-agnostic: whether the unit moved north-to-south or south-to-north, you can display the same sprite there. Which brings me to my next important point:
If a unit moves NS/SN or WE/EW for 2+ tiles in a row, he wants to either alternate or randomize the NS and SN tiles so that it doesn't get that repeating texture look. Let's make this an easy toggle [ alternate / randomize ] in the code.

If a unit moves over a tile, then later another unit moves over the same tile, Lawrence wants to simply overlay the tiles, up to a maxiumum depth of X. I want to start with X=4 and see how it looks. Lawrence mocked this up, and a depth of 4 looks really good. We'll playtest with other values as well.

Then we need to hook this thing up to the actual units walking. If the unit takes a weird path, it should overlay the multiple traversals to show the path actually walked.

Does all this make sense? Did I leave anything out?
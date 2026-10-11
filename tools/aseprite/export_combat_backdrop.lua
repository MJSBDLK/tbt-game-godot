-- Exports a combat backdrop as the files CombatBackdrop loads, next to it:
--   sky.png              ← the layer "sky", or every "skybox_*" layer
--   sky_twinkle.png      ← the "*twinkle*" layer (the star map: its colors are
--                          data, so it exports even while hidden)
--   floor/NN_<name>.png  ← every other visible layer, one file each, numbered
--                          bottom first so the game stacks them in order
-- Never exported: hidden layers, "reference ..." layers, and anything named
-- "do not export" or "GUIDES". A floor layer named after a map piece
-- ("crater_left", "shelltree") or a terrain ("sand_orange", "water") shows
-- only when that scenery is near the fight: see CombatBackdrop.
-- Floor files this export doesn't write (a layer renamed or deleted since)
-- are removed, which is why Aseprite asks once to trust this script.
--
-- CLI, from the project root:
--   aseprite --batch art/backdrops/combat_regolith/combat_regolith.aseprite \
--            --script tools/aseprite/export_combat_backdrop.lua
-- GUI: open the backdrop, File > Scripts > (copy this file into your scripts
--      folder first: File > Scripts > Open Scripts Folder).
local spr = app.activeSprite
if not spr then print("open the backdrop first"); return end
local dir = app.fs.filePath(spr.filename)

local function isTwinkle(name) return name:find("twinkle") ~= nil end
local function isSky(name)
  return (name == "sky" or name:sub(1, 7) == "skybox_") and not isTwinkle(name)
end
local function neverExported(name)
  local lower = name:lower()
  return lower:sub(1, 9) == "reference" or lower:find("do not export") ~= nil
      or lower:find("guides") ~= nil
end
local function isFloor(layer, visible)
  local name = layer.name
  return visible and not isSky(name) and not isTwinkle(name) and not neverExported(name)
end
-- "Piperoot Final" → "piperoot_final": the game reads the words between "_".
local function fileStem(name)
  local stem = name:lower():gsub("[^%w]+", "_")
  return (stem:gsub("^_+", ""):gsub("_+$", ""))
end

local wasVisible = {}
for i, layer in ipairs(spr.layers) do wasVisible[i] = layer.isVisible end

local function exportLayers(fileName, wanted)
  local found = false
  for i, layer in ipairs(spr.layers) do
    layer.isVisible = wanted(layer, wasVisible[i], i)
    if layer.isVisible then found = true end
  end
  if found then
    local out = app.fs.joinPath(dir, fileName)
    spr:saveCopyAs(out)
    print("exported " .. out)
  else
    print("nothing to export for " .. fileName)
  end
end

exportLayers("sky.png", function(layer, visible) return visible and isSky(layer.name) end)
exportLayers("sky_twinkle.png", function(layer) return isTwinkle(layer.name) end)

local floorDir = app.fs.joinPath(dir, "floor")
app.fs.makeDirectory(floorDir)
local written = {}
local order = 0
for i, layer in ipairs(spr.layers) do
  if isFloor(layer, wasVisible[i]) then
    local fileName = string.format("%02d_%s.png", order, fileStem(layer.name))
    exportLayers(app.fs.joinPath("floor", fileName), function(_, _, j) return j == i end)
    written[fileName] = true
    order = order + 1
  end
end
for _, fileName in ipairs(app.fs.listFiles(floorDir)) do
  local png = fileName:gsub("%.import$", "")
  if png:match("%.png$") and not written[png] then
    os.remove(app.fs.joinPath(floorDir, fileName))
    print("removed " .. fileName .. " (no layer by that name now)")
  end
end
for i, layer in ipairs(spr.layers) do layer.isVisible = wasVisible[i] end

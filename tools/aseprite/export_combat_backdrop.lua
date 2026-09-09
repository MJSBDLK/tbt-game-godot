-- Exports the combat backdrop's two layers as the PNGs CombatScene loads:
--   sky.png   ← layer "sky"
--   floor.png ← layer "floor"
-- next to the template (res://art/backdrops/combat_test/). Guides and the
-- reference puppets are never exported — only the named layer is visible
-- during each save.
--
-- CLI, from the project root:
--   aseprite --batch art/backdrops/combat_test/combat_backdrop_template.aseprite \
--            --script tools/aseprite/export_combat_backdrop.lua
-- GUI: open the template, File > Scripts > (copy this file into your scripts
--      folder first: File > Scripts > Open Scripts Folder).
local spr = app.activeSprite
if not spr then print("open the template first"); return end
local dir = app.fs.filePath(spr.filename)
local function exportLayer(layerName, fileName)
  local visible = {}
  local found = false
  for i, layer in ipairs(spr.layers) do
    visible[i] = layer.isVisible
    layer.isVisible = (layer.name == layerName)
    if layer.name == layerName then found = true end
  end
  if found then
    local out = app.fs.joinPath(dir, fileName)
    spr:saveCopyAs(out)
    print("exported " .. out)
  else
    print("no layer named '" .. layerName .. "'")
  end
  for i, layer in ipairs(spr.layers) do layer.isVisible = visible[i] end
end
exportLayer("sky", "sky.png")
exportLayer("floor", "floor.png")

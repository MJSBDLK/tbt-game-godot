-- Headless check for the rpgmaker shadow pipeline, run against Lawrence's real
-- mountain template: the `bg` layer never reaches the output, the `shadows`
-- layer becomes a two-color mask, and the sheet stacks three blocks — body,
-- the tile's own shadow, and the spill into the cell east of it. Nothing on
-- disk changes except the PNGs the params ask for. Run from the repo root:
--
--   ~/aseprite/build/bin/aseprite -b \
--     --script-param out=/tmp/preview.png \
--     --script-param tileset=/tmp/mountain_12x12.png \
--     --script tools/aseprite/webtyler/overflow_probe.lua

local params = app.params
local PLUGIN_PATH = params.plugin or "tools/aseprite/webtyler/webtyler.lua"
local TEMPLATE_PATH = params.template
    or "art/sprites/terrain_modifiers/mountain_autotile_with_shadow.aseprite"
local TAG = params.tag or "Mountains"
local TILE = 32
local SHADOW_ROWS, SPILL_ROWS = 4, 8

local pc = app.pixelColor

-- The 13 autotile positions open to the east, with whether the terrain
-- continues north (t) and south (b). From tileset_terrain_setup.gd's peering
-- table, which is independent of the Lua conversion under test.
local EAST_OPEN = {
    {x = 0, y = 3, t = 0, b = 0}, {x = 3, y = 3, t = 0, b = 0},
    {x = 0, y = 0, t = 0, b = 1}, {x = 3, y = 0, t = 0, b = 1}, {x = 11, y = 0, t = 0, b = 1},
    {x = 0, y = 2, t = 1, b = 0}, {x = 3, y = 2, t = 1, b = 0}, {x = 11, y = 3, t = 1, b = 0},
    {x = 0, y = 1, t = 1, b = 1}, {x = 3, y = 1, t = 1, b = 1}, {x = 7, y = 1, t = 1, b = 1},
    {x = 7, y = 2, t = 1, b = 1}, {x = 11, y = 2, t = 1, b = 1},
}

local checks, failures = 0, 0
local function check(ok, message)
    checks = checks + 1
    if not ok then
        failures = failures + 1
        print("FAIL: " .. message)
    end
end

-- The plugin keeps its functions local; append an export to its chunk.
local handle = assert(io.open(PLUGIN_PATH, "r"), "can't read " .. PLUGIN_PATH)
local pluginText = handle:read("a")
handle:close()
local plugin = assert(load(pluginText .. [[

return { updatePreviews = updatePreviews, settings = settings,
         previewData = preview_data, previewTileIndex = previewTileIndex,
         exportTileset = exportTileset, exportRows = exportRows,
         defaultExportPath = defaultExportPath,
         preview = function() return previewSprite end }
]]))()

-- Opened with its real palette, which is larger than the 256 a new Sprite
-- starts with: the plugin has to grow the preview's palette before copying.
local sprite = assert(app.open(TEMPLATE_PATH), "can't open " .. TEMPLATE_PATH)

local roles = {}
for _, layer in ipairs(sprite.layers) do
    roles[layer.name:lower()] = true
end
check(roles["bg"], "the template has a `bg` layer")
check(roles["shadows"], "the template has a `shadows` layer")

local frame
for _, tag in ipairs(sprite.tags) do
    if tag.name == TAG then frame = tag.fromFrame end
end
assert(frame, "no " .. TAG .. " tag in " .. TEMPLATE_PATH)
-- Batch mode ignores app.activeFrame, so the plugin renders frame 1: make the
-- tagged frame the only one.
local keep = frame.frameNumber
for i = #sprite.frames, 1, -1 do
    if i ~= keep then
        sprite:deleteFrame(i)
    end
end

app.activeSprite = sprite
plugin.settings.mode = "rpgmaker"
plugin.settings.tileW = TILE
plugin.settings.tileH = TILE
plugin.settings.lockToTag = true
plugin.settings.showPreviewScene = true
plugin.updatePreviews(false)
local preview = assert(plugin.preview(), "the plugin made no preview sprite")
local out = preview.layers[1]:cel(1).image

check(preview.height == (12 + 10) * TILE,
    "preview height makes room for three blocks (" .. preview.height .. ")")
check(preview.width >= 13 * TILE,
    "preview keeps a 13th scene column for spills (" .. preview.width .. ")")
check(plugin.exportRows() == 12, "export covers 12 rows (" .. plugin.exportRows() .. ")")
check(plugin.defaultExportPath():find("_12x12%.png$") ~= nil,
    "export name says 12x12 (" .. plugin.defaultExportPath() .. ")")

-- Block scans. The body is opaque pixel art; the shadow blocks are a two-color
-- mask — flat black where shadow falls, transparent elsewhere — because the
-- game draws them at the board's one shadow opacity (GameColors.CAST_SHADOW_INK).
local function scanBlock(rowOffset)
    local inked, mask, translucent = 0, 0, 0
    for y = rowOffset * TILE, (rowOffset + 4) * TILE - 1 do
        for x = 0, 12 * TILE - 1 do
            local px = out:getPixel(x, y)
            local a = pc.rgbaA(px)
            if a > 0 then
                inked = inked + 1
                if a < 255 then
                    translucent = translucent + 1
                elseif pc.rgbaR(px) == 0 and pc.rgbaG(px) == 0 and pc.rgbaB(px) == 0 then
                    mask = mask + 1
                end
            end
        end
    end
    return inked, mask, translucent
end

local bodyInked, _, bodyTranslucent = scanBlock(0)
check(bodyInked > 0, "the body block has art")
check(bodyTranslucent == 0,
    "the body block is opaque — no shadow bled in (" .. bodyTranslucent .. " translucent px)")

local shadowInked, shadowMask = scanBlock(SHADOW_ROWS)
check(shadowInked > 0, "the shadow block has shadow")
check(shadowInked == shadowMask,
    "the shadow block is a flat black mask (" .. shadowInked .. " inked, " .. shadowMask .. " mask)")

local spillInked, spillMask = scanBlock(SPILL_ROWS)
check(spillInked > 0, "the spill block has shadow")
check(spillInked == spillMask,
    "the spill block is a flat black mask (" .. spillInked .. " inked, " .. spillMask .. " mask)")

-- A tile's own shadow must never land on its own art: terrain shadows draw
-- ABOVE the bodies, so an unmasked pixel darkens the very rock that casts it
-- and leaves a seam at the tile edge. The spill block is exempt — landing on
-- the east neighbor is its job.
local selfShaded = 0
for ty = 0, 3 do
    for tx = 0, 11 do
        for ly = 0, TILE - 1 do
            for lx = 0, TILE - 1 do
                local body = out:getPixel(tx * TILE + lx, ty * TILE + ly)
                local shadow = out:getPixel(tx * TILE + lx, (ty + SHADOW_ROWS) * TILE + ly)
                if pc.rgbaA(body) > 0 and pc.rgbaA(shadow) > 0 then
                    selfShaded = selfShaded + 1
                end
            end
        end
    end
end
check(selfShaded == 0, "no tile shadows its own art (" .. selfShaded .. " px)")

local openAt = {}
for _, entry in ipairs(EAST_OPEN) do
    openAt[entry.x .. "," .. entry.y] = entry
end
local function tileInked(tx, ty)
    for ly = 0, TILE - 1 do
        for lx = 0, TILE - 1 do
            if pc.rgbaA(out:getPixel(tx * TILE + lx, ty * TILE + ly)) > 0 then return true end
        end
    end
    return false
end
for ty = 0, 3 do
    for tx = 0, 11 do
        local open = openAt[tx .. "," .. ty] ~= nil
        local inked = tileInked(tx, ty + SPILL_ROWS)
        check(inked == open, string.format(
            "spill (%d,%d) is %s", tx, ty, open and "present (east-open)" or "empty (closed east edge)"))
    end
end

-- Sample scene: a tile with no east neighbor is east-open by construction, so
-- every such tile must darken the cell beside it. The scene is 12 wide, so the
-- last-column tile needs the canvas's 13th column; that cell is the pin.
local sceneStartY = (12 + 1) * TILE
local spills, lastColumnSpilled = 0, false
for row = 1, #plugin.previewData do
    for col = 1, #plugin.previewData[row] do
        local index = plugin.previewTileIndex(row, col)
        if index >= 0 and plugin.previewTileIndex(row, col + 1) < 0 then
            local tx, ty = index % 12, math.floor(index / 12)
            local where = string.format("scene cell (%d,%d) east of atlas (%d,%d)", col, row - 1, tx, ty)
            check(openAt[tx .. "," .. ty] ~= nil, where .. " is east-open")
            local darkened = 0
            for ly = 0, TILE - 1 do
                for lx = 0, TILE - 1 do
                    local spill = out:getPixel(tx * TILE + lx, (ty + SPILL_ROWS) * TILE + ly)
                    if pc.rgbaA(spill) > 0 then
                        darkened = darkened + 1
                    end
                end
            end
            if darkened > 0 then
                spills = spills + 1
                if col == 12 then lastColumnSpilled = true end
            end
        end
    end
end
check(spills > 0, "the scene draws spills into east neighbors (" .. spills .. " cells)")
check(lastColumnSpilled, "a tile in the scene's last column spills into the 13th")

if params.out then
    preview:saveCopyAs(params.out)
    print("preview written to " .. params.out)
end
if params.tileset then
    plugin.exportTileset(params.tileset)
    print("tileset written to " .. params.tileset)
end
print(string.format("mask pixels: shadow %d, spill %d", shadowMask, spillMask))
print(string.format("shadow probe: %s (%d checks, %d failed)",
    failures == 0 and "PASS" or "FAIL", checks, failures))

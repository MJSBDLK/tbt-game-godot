-- Headless check for the rpgmaker overflow column. Builds a test template from
-- the real mountain frame (canvas widened to 3×3 tiles, the shadow rows clipped
-- at the 2×2 block's east edge extended a few pixels into column 2, a regolith
-- ground swatch at (2,0)), runs the plugin's conversion, and asserts the
-- overflow atlas against the autotile's own peering table. Nothing on disk
-- changes except the optional preview PNG. Run from the repo root:
--
--   ~/aseprite/build/bin/aseprite -b \
--     --script-param out=/tmp/overflow_preview.png \
--     --script tools/aseprite/webtyler/overflow_probe.lua

local params = app.params
local PLUGIN_PATH = params.plugin or "tools/aseprite/webtyler/webtyler.lua"
local TEMPLATE_PATH = params.template or "art/sprites/tilesets/2x3_source_tiles/2x3_source_tiles.aseprite"
local MOUNTAIN_TAG = "mountain__regolith"
local TILE = 32
local OVERFLOW_ROWS = 4
local SHADOW_EXTENSION = 8

local pc = app.pixelColor
local GROUND = pc.rgba(190, 181, 156, 255)
local SHADOW = pc.rgba(156, 148, 127, 255)
-- Tan over regolith is 18% black; allow rounding either side.
local SHADOW_ALPHA_MIN, SHADOW_ALPHA_MAX = 44, 48

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
         exportTileset = exportTileset, defaultExportPath = defaultExportPath,
         preview = function() return previewSprite end }
]]))()

local sprite = assert(app.open(TEMPLATE_PATH), "can't open " .. TEMPLATE_PATH)
-- A batch-mode Sprite starts with a 256-color palette and the plugin copies
-- the source palette into it index by index; the colors don't matter in RGB.
if #sprite.palettes[1] > 256 then
    sprite.palettes[1]:resize(256)
end
local frame
for _, tag in ipairs(sprite.tags) do
    if tag.name == MOUNTAIN_TAG then frame = tag.fromFrame end
end
assert(frame, "no " .. MOUNTAIN_TAG .. " tag in " .. TEMPLATE_PATH)
-- Batch mode ignores app.activeFrame, so the plugin renders frame 1: make the
-- mountain frame the only one.
local keep = frame.frameNumber
for i = #sprite.frames, 1, -1 do
    if i ~= keep then
        sprite:deleteFrame(i)
    end
end
frame = sprite.frames[1]

-- Test template: widen, flatten the mountain frame into one full-canvas cel,
-- fill column 2 with ground, extend each clipped shadow row into it.
sprite:crop(0, 0, 3 * TILE, 3 * TILE)
local cel = sprite.layers[1]:cel(frame)
local image = Image(sprite.width, sprite.height, sprite.colorMode)
image:clear()
image:drawImage(cel.image, cel.position)
for y = 0, 3 * TILE - 1 do
    for x = 2 * TILE, 3 * TILE - 1 do
        image:drawPixel(x, y, GROUND)
    end
end
local shadowRows, shadowRowCount = {}, 0
for y = TILE, 3 * TILE - 1 do
    if image:getPixel(2 * TILE - 1, y) == SHADOW then
        shadowRows[y] = true
        shadowRowCount = shadowRowCount + 1
        for x = 2 * TILE, 2 * TILE + SHADOW_EXTENSION - 1 do
            image:drawPixel(x, y, SHADOW)
        end
    end
end
check(shadowRowCount > 0, "the mountain frame has shadow rows clipped at the block's east edge")
cel.image = image
cel.position = Point(0, 0)

app.activeSprite = sprite
app.activeFrame = frame
plugin.settings.mode = "rpgmaker"
plugin.settings.tileW = TILE
plugin.settings.tileH = TILE
plugin.settings.lockToTag = true
plugin.settings.showPreviewScene = true
plugin.updatePreviews(false)
local preview = assert(plugin.preview(), "the plugin made no preview sprite")
local out = preview.layers[1]:cel(1).image

-- Which template row a pixel of an overflow tile was read from: the top half
-- follows the north neighbor, the bottom half the south one.
local function templateRow(entry, localY)
    if localY < TILE / 2 then
        return (entry.t == 0 and TILE or 2 * TILE) + localY
    end
    return (entry.b == 0 and 2 * TILE or TILE) + localY
end

local openAt = {}
for _, entry in ipairs(EAST_OPEN) do
    openAt[entry.x .. "," .. entry.y] = entry
end

for ty = 0, 3 do
    for tx = 0, 11 do
        local entry = openAt[tx .. "," .. ty]
        local originX, originY = tx * TILE, (ty + OVERFLOW_ROWS) * TILE
        local where = string.format("overflow (%d,%d)", tx, ty)
        local wrong = 0
        local badAlpha = 0
        for ly = 0, TILE - 1 do
            local inkRow = entry ~= nil and shadowRows[templateRow(entry, ly)] == true
            for lx = 0, TILE - 1 do
                local px = out:getPixel(originX + lx, originY + ly)
                local alpha = pc.rgbaA(px)
                local expectInk = inkRow and lx < SHADOW_EXTENSION
                if (alpha > 0) ~= expectInk then
                    wrong = wrong + 1
                elseif expectInk and (alpha < SHADOW_ALPHA_MIN or alpha > SHADOW_ALPHA_MAX
                        or pc.rgbaR(px) ~= 0 or pc.rgbaG(px) ~= 0 or pc.rgbaB(px) ~= 0) then
                    badAlpha = badAlpha + 1
                end
            end
        end
        if entry then
            check(wrong == 0, where .. " (east-open) matches its template rows; " .. wrong .. " pixels off")
            check(badAlpha == 0, where .. " ink is black at ~18%; " .. badAlpha .. " pixels off")
        else
            check(wrong == 0, where .. " (closed east edge) is empty; " .. wrong .. " pixels inked")
        end
    end
end

-- Sample scene: a tile with no east neighbor is east-open by construction, so
-- every such tile must spill its overflow over the swatch in the cell beside
-- it. The scene is 12 wide, so the last-column tile needs the canvas's 13th
-- column; that cell is the regression pin.
local sceneStartY = (4 + OVERFLOW_ROWS + 1) * TILE
check(preview.width >= 13 * TILE,
    "preview keeps a 13th scene column for spills (" .. preview.width .. ")")
local spills, lastColumnSpilled = 0, false
for row = 1, #plugin.previewData do
    for col = 1, #plugin.previewData[row] do
        local index = plugin.previewTileIndex(row, col)
        if index >= 0 and plugin.previewTileIndex(row, col + 1) < 0 then
            local tx, ty = index % 12, math.floor(index / 12)
            local where = string.format("scene cell (%d,%d) east of atlas (%d,%d)", col, row - 1, tx, ty)
            check(openAt[tx .. "," .. ty] ~= nil, where .. " is east-open")
            local cellX, cellY = col * TILE, sceneStartY + (row - 1) * TILE
            local wrong = 0
            for ly = 0, TILE - 1 do
                for lx = 0, TILE - 1 do
                    local inked = pc.rgbaA(out:getPixel(tx * TILE + lx, (ty + OVERFLOW_ROWS) * TILE + ly)) > 0
                    local px = out:getPixel(cellX + lx, cellY + ly)
                    if inked == (px == GROUND) then
                        wrong = wrong + 1
                    end
                end
            end
            check(wrong == 0, where .. " carries its overflow over the swatch; " .. wrong .. " pixels off")
            spills = spills + 1
            if col == 12 then lastColumnSpilled = true end
        end
    end
end
check(spills > 0, "the scene has tiles with an empty east neighbor")
check(lastColumnSpilled, "the scene's last-column tile spills into the 13th column")

-- Export: the plugin's own writer must hand Godot exactly the preview's
-- top-left 12×8 block, named after the tag.
local exportPath = app.fs.joinPath(app.fs.tempPath, "webtyler_probe_export.png")
plugin.exportTileset(exportPath)
local exported = Image{ fromFile = exportPath }
check(exported ~= nil and exported.width == 12 * TILE and exported.height == (4 + OVERFLOW_ROWS) * TILE,
    "export is 12×8 tiles (" .. (exported and (exported.width .. "x" .. exported.height) or "nil") .. ")")
local exportDiff = 0
if exported then
    for y = 0, exported.height - 1 do
        for x = 0, exported.width - 1 do
            if exported:getPixel(x, y) ~= out:getPixel(x, y) then exportDiff = exportDiff + 1 end
        end
    end
end
check(exportDiff == 0, "export matches the preview's top-left block; " .. exportDiff .. " pixels differ")
check(plugin.defaultExportPath():match("mountain__regolith_12x8%.png$") ~= nil,
    "default export name is <tag>_12x8.png (" .. plugin.defaultExportPath() .. ")")
os.remove(exportPath)

check(preview.height == (8 + 10) * TILE,
    "preview height makes room for the overflow block (" .. preview.height .. ")")

if params.out then
    preview:saveCopyAs(params.out)
    print("preview written to " .. params.out)
end
print(string.format("overflow probe: %s (%d checks, %d failed)",
    failures == 0 and "PASS" or "FAIL", checks, failures))

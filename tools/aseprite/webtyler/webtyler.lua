-- Webtyler Autotile Plugin for Aseprite/Libresprite
-- Ported from https://wareya.github.io/webtyler/
-- Press F10 to refresh preview (configurable)

----------------------------------------------------------------------
-- DATA TABLES (ported from JS)
----------------------------------------------------------------------

-- convert minitiles to godot (12x4 output)
local minitiles_data = {
    {{0,0}, {{0,0},{0,0},{0,0},{1,0},{1,0},{1,0},{1,0},{1,0},{1,0}}},
    {{1,0}, {{0,0},{0,0},{2,0},{0,0},{0,0},{2,0},{1,0},{1,0},{3,0}}},
    {{2,0}, {{2,0},{2,0},{2,0},{2,0},{2,0},{2,0},{3,0},{3,0},{3,0}}},
    {{3,0}, {{2,0},{0,0},{0,0},{2,0},{0,0},{0,0},{3,0},{1,0},{1,0}}},
    {{4,0}, {{4,0},{4,0},{3,0},{4,0},{4,0},{3,0},{3,0},{3,0},{3,0}}},
    {{5,0}, {{2,0},{2,0},{2,0},{2,0},{4,0},{4,0},{3,0},{4,0},{4,0}}},
    {{6,0}, {{2,0},{2,0},{2,0},{4,0},{4,0},{2,0},{4,0},{4,0},{3,0}}},
    {{7,0}, {{3,0},{4,0},{4,0},{3,0},{4,0},{4,0},{3,0},{3,0},{3,0}}},
    {{8,0}, {{0,0},{0,0},{2,0},{0,0},{4,0},{4,0},{1,0},{4,0},{4,0}}},
    {{9,0}, {{3,0},{3,0},{3,0},{4,0},{4,0},{4,0},{4,0},{4,0},{4,0}}},
    {{10,0}, {{2,0},{2,0},{2,0},{4,0},{4,0},{4,0},{4,0},{4,0},{4,0}}},
    {{11,0}, {{2,0},{0,0},{0,0},{4,0},{4,0},{0,0},{4,0},{4,0},{1,0}}},
    
    {{0,1}, {{1,0},{1,0},{1,0},{1,0},{1,0},{1,0},{1,0},{1,0},{1,0}}},
    {{1,1}, {{1,0},{1,0},{3,0},{1,0},{1,0},{3,0},{1,0},{1,0},{3,0}}},
    {{2,1}, {{3,0},{3,0},{3,0},{3,0},{3,0},{3,0},{3,0},{3,0},{3,0}}},
    {{3,1}, {{3,0},{1,0},{1,0},{3,0},{1,0},{1,0},{3,0},{1,0},{1,0}}},
    {{4,1}, {{1,0},{1,0},{3,0},{1,0},{4,0},{4,0},{1,0},{4,0},{4,0}}},
    {{5,1}, {{3,0},{4,0},{4,0},{4,0},{4,0},{4,0},{4,0},{4,0},{4,0}}},
    {{6,1}, {{4,0},{4,0},{3,0},{4,0},{4,0},{4,0},{4,0},{4,0},{4,0}}},
    {{7,1}, {{3,0},{1,0},{1,0},{4,0},{4,0},{1,0},{4,0},{4,0},{1,0}}},
    {{8,1}, {{1,0},{4,0},{4,0},{1,0},{4,0},{4,0},{1,0},{4,0},{4,0}}},
    {{9,1}, {{3,0},{4,0},{4,0},{4,0},{4,0},{4,0},{4,0},{4,0},{3,0}}},
    {{10,1}, {{-1,-1},{-1,-1},{-1,-1},{-1,-1},{-1,-1},{-1,-1},{-1,-1},{-1,-1},{-1,-1}}},
    
    {{11,1}, {{4,0},{4,0},{3,0},{4,0},{4,0},{3,0},{4,0},{4,0},{3,0}}},
    {{0,2}, {{1,0},{1,0},{1,0},{1,0},{1,0},{1,0},{0,0},{0,0},{0,0}}},
    {{1,2}, {{1,0},{1,0},{3,0},{0,0},{0,0},{2,0},{0,0},{0,0},{2,0}}},
    {{2,2}, {{3,0},{3,0},{3,0},{2,0},{2,0},{2,0},{2,0},{2,0},{2,0}}},
    {{3,2}, {{3,0},{1,0},{1,0},{2,0},{0,0},{0,0},{2,0},{0,0},{0,0}}},
    {{4,2}, {{1,0},{4,0},{4,0},{1,0},{4,0},{4,0},{1,0},{1,0},{3,0}}},
    {{5,2}, {{4,0},{4,0},{4,0},{4,0},{4,0},{4,0},{3,0},{4,0},{4,0}}},
    {{6,2}, {{4,0},{4,0},{4,0},{4,0},{4,0},{4,0},{4,0},{4,0},{3,0}}},
    {{7,2}, {{4,0},{4,0},{1,0},{4,0},{4,0},{1,0},{3,0},{1,0},{1,0}}},
    {{8,2}, {{3,0},{4,0},{4,0},{3,0},{4,0},{4,0},{3,0},{4,0},{4,0}}},
    {{9,2}, {{4,0},{4,0},{4,0},{4,0},{4,0},{4,0},{4,0},{4,0},{4,0}}},
    {{10,2}, {{4,0},{4,0},{3,0},{4,0},{4,0},{4,0},{3,0},{4,0},{4,0}}},
    {{11,2}, {{4,0},{4,0},{1,0},{4,0},{4,0},{1,0},{4,0},{4,0},{1,0}}},
    
    {{0,3}, {{0,0},{0,0},{0,0},{0,0},{0,0},{0,0},{0,0},{0,0},{0,0}}},
    {{1,3}, {{0,0},{2,0},{2,0},{0,0},{2,0},{2,0},{0,0},{2,0},{2,0}}},
    {{2,3}, {{2,0},{2,0},{2,0},{2,0},{2,0},{2,0},{2,0},{2,0},{2,0}}},
    {{3,3}, {{2,0},{2,0},{0,0},{2,0},{2,0},{0,0},{2,0},{2,0},{0,0}}},
    {{4,3}, {{3,0},{3,0},{3,0},{4,0},{4,0},{3,0},{4,0},{4,0},{3,0}}},
    {{5,3}, {{3,0},{4,0},{4,0},{2,0},{4,0},{4,0},{2,0},{2,0},{2,0}}},
    {{6,3}, {{4,0},{4,0},{3,0},{4,0},{4,0},{2,0},{2,0},{2,0},{2,0}}},
    {{7,3}, {{3,0},{3,0},{3,0},{3,0},{4,0},{4,0},{3,0},{4,0},{4,0}}},
    {{8,3}, {{1,0},{4,0},{4,0},{0,0},{4,0},{4,0},{0,0},{0,0},{2,0}}},
    {{9,3}, {{4,0},{4,0},{4,0},{4,0},{4,0},{4,0},{2,0},{2,0},{2,0}}},
    {{10,3}, {{4,0},{4,0},{4,0},{4,0},{4,0},{4,0},{3,0},{3,0},{3,0}}},
    {{11,3}, {{4,0},{4,0},{1,0},{4,0},{4,0},{0,0},{2,0},{0,0},{0,0}}},
}

-- convert 4x4 to godot
local fourxfour_data = {
    {{0,0},{0,0}}, {{1,0},{1,0}}, {{2,0},{2,0}}, {{3,0},{3,0}},
    {{0,1},{0,1}}, {{1,1},{1,1}}, {{2,1},{2,1}}, {{3,1},{3,1}},
    {{0,2},{0,2}}, {{1,2},{1,2}}, {{2,2},{2,2}}, {{3,2},{3,2}},
    {{0,3},{0,3}}, {{1,3},{1,3}}, {{2,3},{2,3}}, {{3,3},{3,3}},
    
    {{4,0},{2,1}}, {{5,0},{2,0}}, {{6,0},{2,0}}, {{7,0},{2,1}},
    {{4,1},{1,1}}, {{5,1},{2,1}}, {{6,1},{2,1}}, {{7,1},{3,1}},
    {{4,2},{1,1}}, {{5,2},{2,1}}, {{6,2},{2,1}}, {{7,2},{3,1}},
    {{4,3},{2,1}}, {{5,3},{2,2}}, {{6,3},{2,2}}, {{7,3},{2,1}},
    
    {{8,0},{1,0}}, {{9,0},{2,1}}, {{10,0},{2,0}}, {{11,0},{3,0}},
    {{8,1},{1,1}}, {{9,1},{2,1}}, {{10,1},{-1,-1}}, {{11,1},{2,1}},
    {{8,2},{2,1}}, {{9,2},{2,1}}, {{10,2},{2,1}}, {{11,2},{3,1}},
    {{8,3},{1,2}}, {{9,3},{2,2}}, {{10,3},{2,1}}, {{11,3},{3,2}},
}

-- convert 3x3 to 4x4
local threexthree_data = {
    {{0,0}, {{0,0},{2,0},{2,0},{0,1},{2,1},{2,1},{0,1},{2,1},{2,1}}},
    {{1,0}, {{0,0},{0,0},{0,0},{0,0},{0,0},{0,0},{0,0},{0,0},{0,0}}},
    {{2,0}, {{1,0},{1,0},{1,0},{1,0},{1,0},{1,0},{1,0},{1,0},{1,0}}},
    {{3,0}, {{2,0},{2,0},{2,0},{2,0},{2,0},{2,0},{2,0},{2,0},{2,0}}},

    {{0,1}, {{0,1},{2,1},{2,1},{0,1},{2,1},{2,1},{0,1},{2,1},{2,1}}},
    {{1,1}, {{0,1},{0,1},{0,1},{0,1},{0,1},{0,1},{0,1},{0,1},{0,1}}},
    {{2,1}, {{1,1},{1,1},{1,1},{1,1},{1,1},{1,1},{1,1},{1,1},{1,1}}},
    {{3,1}, {{2,1},{2,1},{2,1},{2,1},{2,1},{2,1},{2,1},{2,1},{2,1}}},

    {{0,2}, {{0,1},{2,1},{2,1},{0,2},{2,2},{2,2},{0,2},{2,2},{2,2}}},
    {{1,2}, {{0,2},{0,2},{0,2},{0,2},{0,2},{0,2},{0,2},{0,2},{0,2}}},
    {{2,2}, {{1,2},{1,2},{1,2},{1,2},{1,2},{1,2},{1,2},{1,2},{1,2}}},
    {{3,2}, {{2,2},{2,2},{2,2},{2,2},{2,2},{2,2},{2,2},{2,2},{2,2}}},

    {{0,3}, {{0,0},{2,0},{2,0},{0,2},{2,2},{2,2},{0,2},{2,2},{2,2}}},
    {{1,3}, {{0,0},{0,0},{0,0},{0,2},{0,2},{0,2},{0,2},{0,2},{0,2}}},
    {{2,3}, {{1,0},{1,0},{1,0},{1,2},{1,2},{1,2},{1,2},{1,2},{1,2}}},
    {{3,3}, {{2,0},{2,0},{2,0},{2,2},{2,2},{2,2},{2,2},{2,2},{2,2}}},
}

local inner_corners_data = {
    {{1,0}, {{1,1}}},
    {{2,0}, {{0,1}, {1,1}}},
    {{3,0}, {{0,1}}},
    
    {{1,1}, {{1,1},{1,0}}},
    {{2,1}, {{0,0},{0,1},{1,0},{1,1}}},
    {{3,1}, {{0,0},{0,1}}},
    
    {{1,2}, {{1,0}}},
    {{2,2}, {{0,0},{1,0}}},
    {{3,2}, {{0,0}}},
    
    {{4,0}, {{0,1},{1,0},{1,1}}},
    {{5,0}, {{0,1}}},
    {{6,0}, {{1,1}}},
    {{7,0}, {{0,1},{0,0},{1,1}}},
    
    {{4,1}, {{1,0}}},
    {{5,1}, {{0,0}}},
    {{6,1}, {{1,0}}},
    {{7,1}, {{0,0}}},
    
    {{4,2}, {{1,1}}},
    {{5,2}, {{0,1}}},
    {{6,2}, {{1,1}}},
    {{7,2}, {{0,1}}},
    
    {{4,3}, {{0,0},{1,0},{1,1}}},
    {{5,3}, {{0,0}}},
    {{6,3}, {{1,0}}},
    {{7,3}, {{0,1},{0,0},{1,0}}},
    
    {{9,0}, {{0,0},{1,0}}},
    {{11,1}, {{1,0},{1,1}}},
    {{8,2}, {{0,0},{0,1}}},
    {{10,3}, {{0,1},{1,1}}},
    
    {{9,1}, {{0,0},{1,1}}},
    {{10,2}, {{1,0},{0,1}}},
}

-- convert godot to preview (using -1 for empty)
local preview_data = {
    {-1,-1,0},
    {-1,36,14,38,-1,-1,-1,-1,-1,0},
    {-1,-1,23,-1,-1,-1,-1,-1,-1,16,11},
    {-1,-1,-1,-1,35,-1,36,37,5,17,22,38},
    {8,11,-1,-1,-1,-1,-1,-1,43,45,46},
    {20,34,-1,0,-1,-1,-1,-1,-1,23},
    {20,18,10,9,11,-1,8,11},
    {20,32,32,32,34,-1,43,33,11},
    {43,44,44,44,46,-1,-1,43,46}
}

local godot_to_gms = {
    43, 36, 24, 38, 15, 23, 22, 14, 35,  4, 21, 37,
    33, 20, 16, 28, 18,  2,  3, 27, 17,  6, -1,  7,
    45, 42, 32, 40, 19,  9,  5, 26, 10,  1, 11, 25,
    47, 44, 34, 46,  8, 30, 31, 12, 41, 29, 13, 39
}

----------------------------------------------------------------------
-- PLUGIN STATE
----------------------------------------------------------------------

local settings = {
    mode = "rpgmaker",
    tileW = 32,
    tileH = 32,
    leftOffset = 0,
    rightOffset = 0,
    topOffset = 0,
    bottomOffset = 0,
    liveUpdate = true,
    showPreviewScene = true,
    followFrame = true,
    showInput = true,
    lockToTag = true,
}

local previewSprite = nil
local sourceSprite = nil
local sourceChangeKey = nil
local appSiteChangeKey = nil
local updating = false
local dlg = nil

-- Frame-follow state (see onSiteChange)
local syncingFrame = false
local pendingPreviewFrame = 1
local lastActiveWasPreview = false
-- Range of SOURCE frames currently feeding the preview (1..N, or a tag's span
-- when "Lock to tag" is on). previewStartFrame is the source frame that maps to
-- preview frame 1, so frame-follow can offset correctly.
local previewStartFrame = 1
local previewEndFrame = 1

local function isSpriteValid(s)
    if not s then return false end
    return pcall(function() return s.width end)
end

-- Returns true if any operation against a tilemap layer/image is in play.
-- Editing tilemap cels (e.g. pasting into a tiled layer) fires sprite "change"
-- events whose active image is tile-index data, not pixel data. Touching it —
-- or doing the previewSprite focus swap mid-paste — crashes Aseprite.
local function isTilemapContext()
    local ok, result = pcall(function()
        local layer = app.activeLayer
        if layer and layer.isTilemap then return true end
        local img = app.activeImage
        if img and ColorMode and img.colorMode == ColorMode.TILEMAP then
            return true
        end
        return false
    end)
    return ok and result
end

----------------------------------------------------------------------
-- TILE COPY FUNCTIONS
----------------------------------------------------------------------

-- Safe pixel get (returns 0/transparent if out of bounds)
local function safeGetPixel(img, x, y)
    if x < 0 or y < 0 or x >= img.width or y >= img.height then
        return 0
    end
    return img:getPixel(x, y)
end

-- Safe pixel set
local function safeDrawPixel(img, x, y, color)
    if x >= 0 and y >= 0 and x < img.width and y < img.height then
        img:drawPixel(x, y, color)
    end
end

-- Copy entire tile from one position to another
local function copyTile(srcImg, dstImg, toX, toY, fromX, fromY, tileW, tileH)
    for y = 0, tileH - 1 do
        for x = 0, tileW - 1 do
            local px = safeGetPixel(srcImg, fromX * tileW + x, fromY * tileH + y)
            safeDrawPixel(dstImg, toX * tileW + x, toY * tileH + y, px)
        end
    end
end

-- Copy a 3x3 section of a tile (for subtile operations)
local function copyTileSectionRaw(srcImg, dstImg, target, section, source, tileW, tileH, offsets)
    local leftOffset = offsets.left or 0
    local rightOffset = offsets.right or 0
    local topOffset = offsets.top or 0
    local bottomOffset = offsets.bottom or 0
    
    local offx1 = math.floor(tileW/2) + leftOffset
    local offx2 = offx1 - leftOffset + rightOffset
    local offy1 = math.floor(tileH/2) + topOffset
    local offy2 = offy1 - topOffset + bottomOffset
    local midwx = rightOffset - leftOffset
    local midwy = bottomOffset - topOffset
    local endwx = tileW - offx2
    local endwy = tileH - offy2
    
    -- section is 0-indexed {0,1,2} for each axis
    local offset_x_arr = {[0]=0, [1]=offx1, [2]=offx2}
    local offset_y_arr = {[0]=0, [1]=offy1, [2]=offy2}
    local size_x_arr = {[0]=offx1, [1]=midwx, [2]=endwx}
    local size_y_arr = {[0]=offy1, [1]=midwy, [2]=endwy}
    
    local offset_x = offset_x_arr[section[1]]
    local offset_y = offset_y_arr[section[2]]
    local size_x = size_x_arr[section[1]]
    local size_y = size_y_arr[section[2]]
    
    for y = 0, size_y - 1 do
        for x = 0, size_x - 1 do
            local srcX = source[1] * tileW + offset_x + x
            local srcY = source[2] * tileH + offset_y + y
            local dstX = target[1] * tileW + offset_x + x
            local dstY = target[2] * tileH + offset_y + y
            local px = safeGetPixel(srcImg, srcX, srcY)
            safeDrawPixel(dstImg, dstX, dstY, px)
        end
    end
end

-- Copy pixel regions within tiles
local function copyTilePixels(srcImg, dstImg, target, source, from, to, size, tileW, tileH)
    local x = target[1] * tileW + to[1]
    local y = target[2] * tileH + to[2]
    local source_x = source[1] * tileW + from[1]
    local source_y = source[2] * tileH + from[2]
    
    for py = 0, size[2] - 1 do
        for px = 0, size[1] - 1 do
            local pixel = safeGetPixel(srcImg, source_x + px, source_y + py)
            safeDrawPixel(dstImg, x + px, y + py, pixel)
        end
    end
end

-- Copy quadrant of a tile (for 2x2 subdivision)
local function copyTileQuadRaw(srcImg, dstImg, target, section, source, tileW, tileH, offsets)
    local leftOffset = offsets.left or 0
    local rightOffset = offsets.right or 0
    local topOffset = offsets.top or 0
    local bottomOffset = offsets.bottom or 0
    
    local offx1 = math.floor(tileW/2) + leftOffset
    local offx2 = offx1 - leftOffset + rightOffset
    local offy1 = math.floor(tileH/2) + topOffset
    local offy2 = offy1 - topOffset + bottomOffset
    local offx = math.floor(offx1/2 + offx2/2)
    local offy = math.floor(offy1/2 + offy2/2)
    
    local offset_x_arr = {[0]=0, [1]=offx}
    local offset_y_arr = {[0]=0, [1]=offy}
    local size_x_arr = {[0]=offx, [1]=tileW - offx}
    local size_y_arr = {[0]=offy, [1]=tileH - offy}
    
    local offset_x = offset_x_arr[section[1]]
    local offset_y = offset_y_arr[section[2]]
    local size_x = size_x_arr[section[1]]
    local size_y = size_y_arr[section[2]]
    
    for y = 0, size_y - 1 do
        for x = 0, size_x - 1 do
            local srcX = source[1] * tileW + offset_x + x
            local srcY = source[2] * tileH + offset_y + y
            local dstX = target[1] * tileW + offset_x + x
            local dstY = target[2] * tileH + offset_y + y
            local px = safeGetPixel(srcImg, srcX, srcY)
            safeDrawPixel(dstImg, dstX, dstY, px)
        end
    end
end

----------------------------------------------------------------------
-- CONVERSION FUNCTIONS
----------------------------------------------------------------------

local function apply_subtile_data(srcImg, dstImg, data_array, tileW, tileH, offsets)
    for _, entry in ipairs(data_array) do
        local target_tile = entry[1]
        local data = entry[2]
        for sy = 0, 2 do
            for sx = 0, 2 do
                local section = {sx, sy}
                local srcTile = data[sy * 3 + sx + 1]
                if srcTile[1] >= 0 and srcTile[2] >= 0 then
                    copyTileSectionRaw(srcImg, dstImg, target_tile, section, srcTile, tileW, tileH, offsets)
                end
            end
        end
    end
end

local function apply_tile_data(srcImg, dstImg, data_array, tileW, tileH)
    for _, entry in ipairs(data_array) do
        local target_tile = entry[1]
        local source_tile = entry[2]
        if source_tile[1] >= 0 and source_tile[2] >= 0 then
            copyTile(srcImg, dstImg, target_tile[1], target_tile[2], source_tile[1], source_tile[2], tileW, tileH)
        end
    end
end

local function updateMinitiles(srcImg, dstImg, tileW, tileH, offsets)
    apply_subtile_data(srcImg, dstImg, minitiles_data, tileW, tileH, offsets)
end

local function update4x4(srcImg, dstImg, tileW, tileH)
    apply_tile_data(srcImg, dstImg, fourxfour_data, tileW, tileH)
end

local function update3x3(srcImg, dstImg, tileW, tileH, offsets)
    -- Create temp 4x4 canvas
    local tempImg = Image(tileW * 4, tileH * 4, srcImg.colorMode)
    tempImg:clear()
    
    -- Convert 3x3 to 4x4
    apply_subtile_data(srcImg, tempImg, threexthree_data, tileW, tileH, offsets)
    
    -- Convert 4x4 to godot
    apply_tile_data(tempImg, dstImg, fourxfour_data, tileW, tileH)
end

local function fix_inner_corners(srcImg, dstImg, source_tile, tileW, tileH, offsets)
    for _, entry in ipairs(inner_corners_data) do
        local target_tile = entry[1]
        local source_sections = entry[2]
        for _, section in ipairs(source_sections) do
            local doubled_section = {section[1] * 2, section[2] * 2}
            copyTileSectionRaw(srcImg, dstImg, target_tile, doubled_section, source_tile, tileW, tileH, offsets)
        end
    end
end

----------------------------------------------------------------------
-- MAIN UPDATE FUNCTION
----------------------------------------------------------------------

local function createTempImage(w, h, colorMode)
    local img = Image(w, h, colorMode)
    img:clear()
    return img
end

-- Erase shadow that lands on the caster's OWN art. Terrain shadows draw one
-- slot above the bodies so they fall onto the neighbors, which means an
-- unmasked shadow would darken the very rock that casts it — with a hard seam
-- at the tile edge. The spill block is deliberately NOT masked: falling on the
-- east neighbor is its whole job. (The tag exporter masks decoration shadows
-- the same way.)
local function maskShadowByBody(dstImg, tileW, tileH, shadowRowOffset)
    local pc = app.pixelColor
    local clear = pc.rgba(0, 0, 0, 0)
    for ty = 0, 3 do
        for tx = 0, 11 do
            for ly = 0, tileH - 1 do
                for lx = 0, tileW - 1 do
                    local bodyX, bodyY = tx * tileW + lx, ty * tileH + ly
                    if pc.rgbaA(safeGetPixel(dstImg, bodyX, bodyY)) > 0 then
                        safeDrawPixel(dstImg, bodyX, bodyY + shadowRowOffset * tileH, clear)
                    end
                end
            end
        end
    end
end


-- Any non-transparent pixel in the region (the whole image when none given).
local function imageHasInk(img, x0, y0, w, h)
    if not img then return false end
    x0, y0 = x0 or 0, y0 or 0
    w = w or (img.width - x0)
    h = h or (img.height - y0)
    for y = y0, y0 + h - 1 do
        for x = x0, x0 + w - 1 do
            if app.pixelColor.rgbaA(safeGetPixel(img, x, y)) > 0 then return true end
        end
    end
    return false
end

-- The rpgmaker 2×3 reference → one 12×4 autotile block. Run once for the art
-- and again for the shadow, which share the template's geometry.
local function convertRpgmakerBlock(srcImg, tileW, tileH, offsets)
    local minitiles = createTempImage(tileW * 5, tileH, srcImg.colorMode)
    copyTileQuadRaw(srcImg, minitiles, {0, 0}, {0, 0}, {0, 1}, tileW, tileH, offsets)
    copyTileQuadRaw(srcImg, minitiles, {0, 0}, {1, 0}, {1, 1}, tileW, tileH, offsets)
    copyTileQuadRaw(srcImg, minitiles, {0, 0}, {0, 1}, {0, 2}, tileW, tileH, offsets)
    copyTileQuadRaw(srcImg, minitiles, {0, 0}, {1, 1}, {1, 2}, tileW, tileH, offsets)

    copyTileQuadRaw(srcImg, minitiles, {1, 0}, {0, 1}, {0, 1}, tileW, tileH, offsets)
    copyTileQuadRaw(srcImg, minitiles, {1, 0}, {1, 1}, {1, 1}, tileW, tileH, offsets)
    copyTileQuadRaw(srcImg, minitiles, {1, 0}, {0, 0}, {0, 2}, tileW, tileH, offsets)
    copyTileQuadRaw(srcImg, minitiles, {1, 0}, {1, 0}, {1, 2}, tileW, tileH, offsets)

    copyTileQuadRaw(srcImg, minitiles, {2, 0}, {1, 0}, {0, 1}, tileW, tileH, offsets)
    copyTileQuadRaw(srcImg, minitiles, {2, 0}, {0, 0}, {1, 1}, tileW, tileH, offsets)
    copyTileQuadRaw(srcImg, minitiles, {2, 0}, {1, 1}, {0, 2}, tileW, tileH, offsets)
    copyTileQuadRaw(srcImg, minitiles, {2, 0}, {0, 1}, {1, 2}, tileW, tileH, offsets)

    copyTile(srcImg, minitiles, 3, 0, 1, 0, tileW, tileH)

    copyTileQuadRaw(srcImg, minitiles, {4, 0}, {1, 1}, {0, 1}, tileW, tileH, offsets)
    copyTileQuadRaw(srcImg, minitiles, {4, 0}, {0, 1}, {1, 1}, tileW, tileH, offsets)
    copyTileQuadRaw(srcImg, minitiles, {4, 0}, {1, 0}, {0, 2}, tileW, tileH, offsets)
    copyTileQuadRaw(srcImg, minitiles, {4, 0}, {0, 0}, {1, 2}, tileW, tileH, offsets)

    local block = createTempImage(tileW * 12, tileH * 4, srcImg.colorMode)
    updateMinitiles(minitiles, block, tileW, tileH, offsets)
    return block
end

----------------------------------------------------------------------
-- OVERFLOW (rpgmaker only)
----------------------------------------------------------------------

-- The template's third column holds whatever spills past the 2×2 block's right
-- edge into the east neighbor cell (a mountain's shadow). Only minitiles 0
-- (outer corners) and 1 (left/right edges) ever form an east edge, so only they
-- get an overflow; each half is read from column 2 beside the block row that
-- minitile's right half comes from in the rpgmaker conversion.
-- Entries: {minitile, source tile for the top half, source tile for the bottom half}
local overflow_minitile_sources = {
    {{0,0}, {2,1}, {2,2}},
    {{1,0}, {2,2}, {2,1}},
}
-- Output blocks, 4 rows each: the body at row 0, the tile's own shadow at
-- SHADOW_ROW_OFFSET, and the part of the shadow that falls into the east
-- neighbor at SPILL_ROW_OFFSET. No shadow layer → just the body block.
local SHADOW_ROW_OFFSET = 4
local SPILL_ROW_OFFSET = 8
-- Layer roles, matched on name (case-insensitive). `bg` is reference ground:
-- never exported, its flat color is what shadow opacity is measured against.
-- `shadows` becomes the shadow and spill blocks.
local BG_LAYER_NAME = "bg"
local SHADOW_LAYER_NAME = "shadows"
-- Darkening below this is ground texture, not shadow (5/255 ≈ 2%).
local SHADOW_MIN_DARKENING = 5
-- The game applies the real shadow opacity at draw time from one shared value
-- (GameColors.CAST_SHADOW_INK), so the sheet carries only the SHAPE. The
-- preview stands in that value purely so the sample scene reads true.
local PREVIEW_SHADOW_ALPHA = 102

-- Writes the overflow atlas into dstImg. Each output tile's rightmost section
-- decides its east edge per row, so the overflow copies that row from the same
-- minitile's overflow; rows whose edge is closed (minitiles 2-4) stay empty.
local function buildOverflowAtlas(srcImg, dstImg, tileW, tileH, offsets, rowOffset)
    local overflowMinitiles = createTempImage(tileW * 2, tileH, srcImg.colorMode)
    for _, entry in ipairs(overflow_minitile_sources) do
        for sx = 0, 1 do
            copyTileQuadRaw(srcImg, overflowMinitiles, entry[1], {sx, 0}, entry[2], tileW, tileH, offsets)
            copyTileQuadRaw(srcImg, overflowMinitiles, entry[1], {sx, 1}, entry[3], tileW, tileH, offsets)
        end
    end
    for _, entry in ipairs(minitiles_data) do
        local target = entry[1]
        local data = entry[2]
        for sy = 0, 2 do
            local edgeSource = data[sy * 3 + 3]
            if edgeSource[2] == 0 and (edgeSource[1] == 0 or edgeSource[1] == 1) then
                for sx = 0, 2 do
                    copyTileSectionRaw(overflowMinitiles, dstImg,
                        {target[1], target[2] + rowOffset}, {sx, sy},
                        edgeSource, tileW, tileH, offsets)
                end
            end
        end
    end
end

-- Most common opaque color in an image; nil when it has none or the sprite
-- isn't RGB (the shadow overlay needs real alpha).
local function dominantOpaqueColor(img)
    if not img or not ColorMode or img.colorMode ~= ColorMode.RGB then return nil end
    local counts, best, bestCount = {}, nil, 0
    for y = 0, img.height - 1 do
        for x = 0, img.width - 1 do
            local px = img:getPixel(x, y)
            if app.pixelColor.rgbaA(px) == 255 then
                local n = (counts[px] or 0) + 1
                counts[px] = n
                if n > bestCount then best, bestCount = px, n end
            end
        end
    end
    return best
end

local function luminance(px)
    local pc = app.pixelColor
    return 0.299 * pc.rgbaR(px) + 0.587 * pc.rgbaG(px) + 0.114 * pc.rgbaB(px)
end

-- Turns shadow painted in the shade color into a two-color MASK: flat black
-- where the paint darkens `ground`, transparent everywhere else. Only the
-- shape is exported — the game draws it at the board's one shadow opacity, the
-- same value unit shadows use — so Lawrence can paint in whatever shade reads
-- well in Aseprite.
local function convertToShadowMask(img, ground)
    local pc = app.pixelColor
    local groundLuminance = luminance(ground)
    if groundLuminance <= 0 then return end
    local ink = pc.rgba(0, 0, 0, 255)
    local clear = pc.rgba(0, 0, 0, 0)
    for y = 0, img.height - 1 do
        for x = 0, img.width - 1 do
            local px = img:getPixel(x, y)
            local darkening = 0
            if pc.rgbaA(px) > 0 then
                darkening = (1 - luminance(px) / groundLuminance) * 255
            end
            img:drawPixel(x, y, darkening >= SHADOW_MIN_DARKENING and ink or clear)
        end
    end
end

local function tileHasInk(img, tx, ty, tileW, tileH)
    for y = 0, tileH - 1 do
        for x = 0, tileW - 1 do
            if app.pixelColor.rgbaA(safeGetPixel(img, tx * tileW + x, ty * tileH + y)) > 0 then
                return true
            end
        end
    end
    return false
end

-- Composite one overlay pixel onto dstImg; drawPixel alone replaces.
local function blendOver(dstImg, x, y, overlay)
    local pc = app.pixelColor
    local alpha = pc.rgbaA(overlay)
    if alpha == 0 then return end
    local under = safeGetPixel(dstImg, x, y)
    if alpha == 255 or pc.rgbaA(under) == 0 then
        safeDrawPixel(dstImg, x, y, overlay)
        return
    end
    local t = alpha / 255
    local function mix(o, u) return math.floor(o * t + u * (1 - t) + 0.5) end
    safeDrawPixel(dstImg, x, y, pc.rgba(
        mix(pc.rgbaR(overlay), pc.rgbaR(under)),
        mix(pc.rgbaG(overlay), pc.rgbaG(under)),
        mix(pc.rgbaB(overlay), pc.rgbaB(under)),
        pc.rgbaA(under)))
end

-- Draw one mask tile at the board's shadow opacity — the preview's stand-in
-- for what the game does with GameColors.CAST_SHADOW_INK.
local function blendMaskTile(dstImg, tx, ty, destX, destY, tileW, tileH)
    local pc = app.pixelColor
    local ink = pc.rgba(0, 0, 0, PREVIEW_SHADOW_ALPHA)
    for py = 0, tileH - 1 do
        for px = 0, tileW - 1 do
            if pc.rgbaA(safeGetPixel(dstImg, tx * tileW + px, ty * tileH + py)) > 0 then
                blendOver(dstImg, destX + px, destY + py, ink)
            end
        end
    end
end


-- Godot atlas index of a sample-scene cell, or -1 when the cell is empty.
local function previewTileIndex(row, col)
    local rowData = preview_data[row]
    local tileIndex = rowData and rowData[col] or -1
    -- preview_data uses a compacted index space that skips
    -- godot position (10,1) = index 22 (the empty slot).
    if tileIndex >= 22 then
        tileIndex = tileIndex + 1
    end
    return tileIndex
end

-- Render the wareya sample scene from the freshly built blocks into a 12×9
-- region starting at sceneStartY, over a ground fill when the template has a
-- `bg` layer. With shadows, each tile's shadow goes over its own cell and its
-- spill into the empty cell east of it; the canvas keeps a 13th column so a
-- tile in the scene's last column spills too.
local function drawPreviewScene(dstImg, tileW, tileH, sceneStartY, withShadow, ground)
    if ground then
        for y = sceneStartY, sceneStartY + 9 * tileH - 1 do
            for x = 0, 13 * tileW - 1 do
                safeDrawPixel(dstImg, x, y, ground)
            end
        end
    end
    for row = 1, #preview_data do
        for col = 1, #preview_data[row] do
            local tileIndex = previewTileIndex(row, col)
            if tileIndex >= 0 then
                local tx, ty = tileIndex % 12, math.floor(tileIndex / 12)
                for py = 0, tileH - 1 do
                    for px = 0, tileW - 1 do
                        blendOver(dstImg, (col - 1) * tileW + px,
                            sceneStartY + (row - 1) * tileH + py,
                            safeGetPixel(dstImg, tx * tileW + px, ty * tileH + py))
                    end
                end
            end
        end
    end

    if not withShadow then return end
    for row = 1, #preview_data do
        for col = 1, #preview_data[row] do
            local tileIndex = previewTileIndex(row, col)
            if tileIndex >= 0 then
                local tx, ty = tileIndex % 12, math.floor(tileIndex / 12)
                local cellY = sceneStartY + (row - 1) * tileH
                blendMaskTile(dstImg, tx, ty + SHADOW_ROW_OFFSET,
                    (col - 1) * tileW, cellY, tileW, tileH)
                if previewTileIndex(row, col + 1) < 0 then
                    blendMaskTile(dstImg, tx, ty + SPILL_ROW_OFFSET,
                        col * tileW, cellY, tileW, tileH)
                end
            end
        end
    end
end

-- Crop the seamless interior tile (the "NESW full tile") from the 2×3 rpgmaker
-- reference and stamp it as a 3×3 grid so the artist can eyeball whether the
-- interior tiles cleanly. The crop is the square straddling the reference's
-- centre grid intersection: source pixels [tileW/2, 3·tileH/2], size tileW×tileH.
local function drawFillPreview(srcImg, dstImg, tileW, tileH, startX, startY)
    local cropX = math.floor(tileW / 2)
    local cropY = math.floor(3 * tileH / 2)
    for ty = 0, 2 do
        for tx = 0, 2 do
            for y = 0, tileH - 1 do
                for x = 0, tileW - 1 do
                    local px = safeGetPixel(srcImg, cropX + x, cropY + y)
                    safeDrawPixel(dstImg,
                        startX + tx * tileW + x,
                        startY + ty * tileH + y,
                        px)
                end
            end
        end
    end
end

-- Flatten one tilemap cel into dst at canvas coordinates (best-effort — tilemap
-- layers as autotile *input* are unusual, so any failure degrades to "skipped"
-- rather than crashing). Looks each tile index up in the layer's tileset.
local function drawTilemapCelInto(cel, layer, dst)
    local tileset = layer.tileset
    if not tileset then return end
    pcall(function()
        local tileSize = tileset.grid.tileSize
        local tmImg = cel.image
        for ty = 0, tmImg.height - 1 do
            for tx = 0, tmImg.width - 1 do
                local raw = tmImg:getPixel(tx, ty)
                local index = raw
                pcall(function() index = app.pixelColor.tileI(raw) end)
                if index and index > 0 then
                    local tileImg
                    if not pcall(function() tileImg = tileset:getTile(index) end)
                        or not tileImg then
                        pcall(function() tileImg = tileset:tile(index).image end)
                    end
                    if tileImg then
                        dst:drawImage(tileImg, Point(
                            cel.position.x + tx * tileSize.width,
                            cel.position.y + ty * tileSize.height))
                    end
                end
            end
        end
    end)
end

-- Composite a layer (recursing into groups, honouring visibility) into dst,
-- placing each cel at its TRUE canvas position so a transparent margin around
-- the art is preserved.
local function compositeLayerInto(layer, frameNumber, dst)
    if not layer.isVisible then return end
    if layer.isGroup then
        for _, child in ipairs(layer.layers) do
            compositeLayerInto(child, frameNumber, dst)
        end
        return
    end
    local cel = layer:cel(frameNumber)
    if not cel or not cel.image then return end
    local img = cel.image
    if ColorMode and img.colorMode == ColorMode.TILEMAP then
        drawTilemapCelInto(cel, layer, dst)
        return
    end
    local opacity = 255
    pcall(function() opacity = math.floor((cel.opacity * layer.opacity) / 255) end)
    -- Try the full opacity/blend placement, fall back to a plain placement.
    if not pcall(function()
            dst:drawImage(img, cel.position, opacity, layer.blendMode)
        end) then
        pcall(function() dst:drawImage(img, cel.position) end)
    end
end

-- Layer roles by name; see BG_LAYER_NAME / SHADOW_LAYER_NAME.
local function layerRole(layer)
    local name = (layer.name or ""):lower()
    if name == BG_LAYER_NAME then return "bg" end
    if name == SHADOW_LAYER_NAME then return "shadow" end
    return "art"
end

-- Does this file carry a shadow layer at all? Decides the preview's height; a
-- frame that leaves it empty simply exports the body block.
local function sourceHasShadowLayer(source)
    for _, layer in ipairs(source.layers) do
        if layerRole(layer) == "shadow" then return true end
    end
    return false
end

-- Build this frame's composites, each layer placed at its TRUE canvas position.
-- (Image:drawSprite flushes content to the origin, DROPPING a transparent
-- margin around the art and shifting every tile read, which seams every output
-- tile.) Roles split the result: `bg` never reaches the output — it is only the
-- reference the shadow's opacity is measured against — `shadows` becomes a
-- black overlay, and everything else is the art.
-- Returns art, shadow (nil when empty), ground color (nil without a bg layer).
local function renderSourceComposites(source, frame)
    local frameNumber = frame
    pcall(function() frameNumber = frame.frameNumber end)
    local art = Image(source.spec)
    art:clear()
    local shadow, ground = nil, nil
    for _, layer in ipairs(source.layers) do
        local role = layerRole(layer)
        if role == "bg" then
            local bg = Image(source.spec)
            bg:clear()
            compositeLayerInto(layer, frameNumber, bg)
            ground = dominantOpaqueColor(bg)
        elseif role == "shadow" then
            shadow = Image(source.spec)
            shadow:clear()
            compositeLayerInto(layer, frameNumber, shadow)
        else
            compositeLayerInto(layer, frameNumber, art)
        end
    end
    if shadow and not imageHasInk(shadow) then shadow = nil end
    if shadow and ground then convertToShadowMask(shadow, ground) end
    return art, shadow, ground
end

-- Stamp the raw source tileset (this frame's composite) into the preview canvas
-- so the single preview document shows input AND output animating together —
-- sidestepping Aseprite's one-active-frame-per-document limit. Optional.
local function drawSourceInput(srcImg, dstImg, startX, startY)
    pcall(function() dstImg:drawImage(srcImg, Point(startX, startY)) end)
end

local updatePreviews  -- forward declared so onSourceChange can reference it

local function onSourceChange()
    if not settings.liveUpdate then return end
    if updating then return end
    -- If the user closed the preview, pause auto-updates until manual refresh
    if not isSpriteValid(previewSprite) then return end
    -- Skip while the user is editing a tilemap layer (paste into a tiled layer
    -- mid-event would crash Aseprite). Manual refresh still works.
    if isTilemapContext() then return end
    updating = true
    -- Live edit: re-render only the active frame so drawing and frame add/delete
    -- stay responsive. The full animation rebuilds on a manual Refresh.
    pcall(function() updatePreviews(true) end)
    updating = false
end

-- Return the [from, to] source-frame span of the tag containing `frameNum`.
-- Falls back to the whole timeline (1..totalFrames) when the frame is untagged
-- or the build doesn't expose tags. Lets several tagged resources share a file.
local function tagRangeForFrame(sprite, frameNum, totalFrames)
    local ok, from, to = pcall(function()
        for _, tag in ipairs(sprite.tags) do
            local f = tag.fromFrame.frameNumber
            local t = tag.toFrame.frameNumber
            if frameNum >= f and frameNum <= t then
                return f, t
            end
        end
        return nil
    end)
    if ok and from then return from, to end
    return 1, totalFrames
end

-- Two jobs, both fired when the active frame/sprite changes:
--  • Frame-follow: snap the preview to the source's current frame the instant
--    you switch INTO the preview (only on switch-in, so you can still scrub/play
--    freely). The active frame is global in Aseprite, so live following without
--    flicker isn't possible — snap-on-switch is the clean compromise.
--  • Lock-to-tag: if the selected source frame moves into a DIFFERENT tag than
--    the one currently previewed, rebuild the preview for that tag.
local function onSiteChange()
    if updating then return end
    if syncingFrame then return end
    if not isSpriteValid(previewSprite) then return end

    local active = app.activeSprite
    local nowPreview = (active == previewSprite)

    if active == sourceSprite then
        local f = app.activeFrame
        local frameNum = f and f.frameNumber or 1
        pendingPreviewFrame = frameNum
        if settings.lockToTag
            and (frameNum < previewStartFrame or frameNum > previewEndFrame) then
            -- Selected frame left the previewed tag's span — rebuild for the new
            -- tag. (Range membership, not tag bounds, so merely adding or deleting
            -- frames inside the current tag no longer triggers a costly rebuild.)
            updating = true
            pcall(updatePreviews)
            updating = false
            lastActiveWasPreview = false
            return
        end
    elseif nowPreview and not lastActiveWasPreview and settings.followFrame then
        -- Map the source frame into the preview's range (offset by the tag start).
        local n = (pendingPreviewFrame - previewStartFrame) + 1
        if n > #previewSprite.frames then n = #previewSprite.frames end
        if n < 1 then n = 1 end
        local cur = app.activeFrame
        if cur and cur.frameNumber ~= n and previewSprite.frames[n] then
            syncingFrame = true
            pcall(function() app.activeFrame = previewSprite.frames[n] end)
            syncingFrame = false
        end
    end
    lastActiveWasPreview = nowPreview
end

updatePreviews = function(activeFrameOnly)
    -- Source = active sprite, unless active IS the preview (then use last-known source).
    local source = app.activeSprite
    if source == previewSprite or not source then
        if isSpriteValid(sourceSprite) and sourceSprite ~= previewSprite then
            source = sourceSprite
        else
            source = nil
        end
    end

    if not source then
        if not updating then
            app.alert("No source sprite! Open your tileset and run again.")
        end
        return
    end

    -- Each visible layer is composited at its TRUE canvas position (see
    -- renderSourceComposite): margins are preserved, coordinates map 1:1, and
    -- every timeline frame is rendered below so an animated source tileset
    -- yields an animated autotile preview.
    local mode = settings.mode
    local tileW = settings.tileW
    local tileH = settings.tileH
    local offsets = {
        left = settings.leftOffset,
        right = settings.rightOffset,
        top = settings.topOffset,
        bottom = settings.bottomOffset,
    }

    -- rpgmaker with a `shadows` layer stacks two more blocks under the autotile
    -- (the tile's own shadow, then its east spill), so everything below starts
    -- that much lower.
    local shadowActive = (mode == "rpgmaker") and sourceHasShadowLayer(source)
    local tileBlocksH = (shadowActive and SPILL_ROW_OFFSET + 4 or 4) * tileH
    local sceneStartY = tileBlocksH + tileH
    local sceneH = settings.showPreviewScene and (1 + 9) * tileH or 0
    -- 3×3 seamless-fill preview lives at output (5.5·tileW, tile blocks + ½·tileH)
    -- — for the 32px rpgmaker default that's the [176,272]–[271,367] block. Only
    -- the rpgmaker reference has a meaningful centre tile to sample, so gate on
    -- that mode and make sure the canvas is tall enough to contain the block.
    local fillActive = (mode == "rpgmaker")
    local fillStartX = math.floor(11 * tileW / 2)
    local fillStartY = tileBlocksH + math.floor(tileH / 2)
    -- rpgmaker keeps a 13th column so the scene's last-column tiles can spill.
    local outW = (shadowActive and 13 or 12) * tileW
    local outH = tileBlocksH + sceneH
    if fillActive then
        outH = math.max(outH, fillStartY + 3 * tileH)
    end

    -- Reserve a column to the right of the 12-wide output for the raw source
    -- tileset, so input and output sit in one document and animate in lockstep.
    local inputActive = settings.showInput
    local inputStartX, inputStartY = 0, 0
    if inputActive then
        inputStartX = outW + tileW            -- 1-tile gap right of the output
        inputStartY = 0
        outW = inputStartX + source.width
        outH = math.max(outH, source.height)
    end

    -- Create or resize preview sprite
    if not isSpriteValid(previewSprite) then
        previewSprite = Sprite(outW, outH, source.colorMode)
        previewSprite.filename = "Webtyler Preview"
        -- A new Sprite starts with a 256-color palette, so a bigger source
        -- palette walks setColor off its end ("index out of bounds 256" on the
        -- first run of every session, harmless on the retry because the preview
        -- sprite already exists by then). Grow it first, and never index past
        -- whichever is shorter.
        local sourcePalette = source.palettes[1]
        local previewPalette = previewSprite.palettes[1]
        pcall(function() previewPalette:resize(#sourcePalette) end)
        for i = 0, math.min(#sourcePalette, #previewPalette) - 1 do
            previewPalette:setColor(i, sourcePalette:getColor(i))
        end
    elseif previewSprite.width ~= outW or previewSprite.height ~= outH then
        previewSprite:resize(outW, outH)
    end

    -- Resolve the source's active frame number (drives which frame we touch).
    local sourceFrameNum = pendingPreviewFrame or 1
    if app.activeSprite == source and app.activeFrame then
        sourceFrameNum = app.activeFrame.frameNumber
    end
    sourceFrameNum = math.max(1, math.min(sourceFrameNum, #source.frames))

    local prevActive = app.activeSprite
    app.activeSprite = previewSprite
    local previewLayer = previewSprite.layers[1]
    local renderOk = true

    -- Build the list of {source frame, preview frame} render jobs.
    --  • Live edits (activeFrameOnly) touch ONLY the active frame — no frame-count
    --    sync, no duration copy — so drawing and adding/deleting frames stay
    --    responsive. The full animation is rebuilt on a manual Refresh.
    --  • A full rebuild recomputes the tag range (when "Lock to tag" is on),
    --    matches the preview's frame count to it, and renders every frame.
    local jobs = {}
    if activeFrameOnly and #previewSprite.frames >= 1 then
        local pIdx = sourceFrameNum - previewStartFrame + 1
        if pIdx < 1 then pIdx = 1 end
        if pIdx > #previewSprite.frames then pIdx = #previewSprite.frames end
        jobs[1] = { src = sourceFrameNum, dst = pIdx, dur = false }
    else
        local startFrame, endFrame = 1, #source.frames
        if settings.lockToTag then
            startFrame, endFrame =
                tagRangeForFrame(source, sourceFrameNum, #source.frames)
        end
        previewStartFrame = startFrame
        previewEndFrame = endFrame
        local frameCount = endFrame - startFrame + 1
        while #previewSprite.frames < frameCount do previewSprite:newFrame() end
        while #previewSprite.frames > frameCount do
            previewSprite:deleteFrame(#previewSprite.frames)
        end
        for i = 1, frameCount do
            jobs[i] = { src = startFrame + i - 1, dst = i, dur = true }
        end
    end

    for _, job in ipairs(jobs) do
        local srcFrame = source.frames[job.src]
        local srcImg, shadowImg, groundColor
        if not srcFrame or not pcall(function()
                srcImg, shadowImg, groundColor = renderSourceComposites(source, srcFrame)
            end) or not srcImg then
            renderOk = false
            break
        end

        local dstImg = Image(outW, outH, srcImg.colorMode)
        dstImg:clear()

    -- Process based on mode (writes 12×4 autotile into top of dstImg)
    if mode == "minitiles" then
        updateMinitiles(srcImg, dstImg, tileW, tileH, offsets)
        
    elseif mode == "basic" then
        -- Convert basic (2 tiles) to minitiles (5 tiles)
        local tempImg = createTempImage(tileW * 5, tileH, srcImg.colorMode)
        copyTile(srcImg, tempImg, 0, 0, 0, 0, tileW, tileH)
        copyTile(srcImg, tempImg, 1, 0, 1, 0, tileW, tileH)
        copyTile(srcImg, tempImg, 2, 0, 1, 0, tileW, tileH)
        copyTile(srcImg, tempImg, 3, 0, 1, 0, tileW, tileH)
        copyTile(srcImg, tempImg, 4, 0, 1, 0, tileW, tileH)
        updateMinitiles(tempImg, dstImg, tileW, tileH, offsets)
        
    elseif mode == "basicborder" or mode == "basicfullborder" then
        local tempImg = createTempImage(tileW * 5, tileH, srcImg.colorMode)
        copyTile(srcImg, tempImg, 0, 0, 0, 0, tileW, tileH)
        copyTile(srcImg, tempImg, 1, 0, 1, 0, tileW, tileH)
        copyTile(srcImg, tempImg, 2, 0, 1, 0, tileW, tileH)
        copyTile(srcImg, tempImg, 3, 0, 1, 0, tileW, tileH)
        copyTile(srcImg, tempImg, 4, 0, 1, 0, tileW, tileH)
        
        -- Copy borders (sides)
        local h = math.floor(tileH/2)
        local o = math.floor(offsets.top/2 + offsets.bottom/2)
        local a, b, c, d = 0, math.floor(tileH/4 + o), math.floor(tileH*3/4 + o), tileH
        local w1 = math.floor(tileW/2 + offsets.left)
        copyTilePixels(srcImg, tempImg, {1, 0}, {0, 0}, {0, b}, {0, b}, {w1, c-b}, tileW, tileH)
        copyTilePixels(srcImg, tempImg, {1, 0}, {0, 0}, {0, b}, {0, c}, {w1, d-c}, tileW, tileH)
        copyTilePixels(srcImg, tempImg, {1, 0}, {0, 0}, {0, b+d-c}, {0, 0}, {w1, b}, tileW, tileH)
        
        local w2 = math.floor(tileW/2 - offsets.right)
        local z = tileW - w2
        copyTilePixels(srcImg, tempImg, {1, 0}, {0, 0}, {z, b}, {z, b}, {w2, c-b}, tileW, tileH)
        copyTilePixels(srcImg, tempImg, {1, 0}, {0, 0}, {z, b}, {z, c}, {w2, d-c}, tileW, tileH)
        copyTilePixels(srcImg, tempImg, {1, 0}, {0, 0}, {z, b+d-c}, {z, 0}, {w2, b}, tileW, tileH)
        
        -- Top/bottom borders
        o = math.floor(offsets.left/2 + offsets.right/2)
        a, b, c, d = 0, math.floor(tileW/4 + o), math.floor(tileW*3/4 + o), tileW
        local h1 = math.floor(tileH/2 + offsets.top)
        copyTilePixels(srcImg, tempImg, {2, 0}, {0, 0}, {b, 0}, {b, 0}, {c-b, h1}, tileW, tileH)
        copyTilePixels(srcImg, tempImg, {2, 0}, {0, 0}, {b, 0}, {c, 0}, {d-c, h1}, tileW, tileH)
        copyTilePixels(srcImg, tempImg, {2, 0}, {0, 0}, {b+d-c, 0}, {0, 0}, {b, h1}, tileW, tileH)
        
        local h2 = math.floor(tileH/2 - offsets.bottom)
        z = tileH - h2
        copyTilePixels(srcImg, tempImg, {2, 0}, {0, 0}, {b, z}, {b, z}, {c-b, h2}, tileW, tileH)
        copyTilePixels(srcImg, tempImg, {2, 0}, {0, 0}, {b, z}, {c, z}, {d-c, h2}, tileW, tileH)
        copyTilePixels(srcImg, tempImg, {2, 0}, {0, 0}, {b+d-c, z}, {0, z}, {b, h2}, tileW, tileH)
        
        if mode == "basicfullborder" then
            copyTile(srcImg, tempImg, 3, 0, 2, 0, tileW, tileH)
        end
        
        updateMinitiles(tempImg, dstImg, tileW, tileH, offsets)
        
    elseif mode == "basiclongborder" then
        local tempImg = createTempImage(tileW * 5, tileH, srcImg.colorMode)
        copyTile(srcImg, tempImg, 0, 0, 0, 0, tileW, tileH)
        copyTile(srcImg, tempImg, 1, 0, 0, 0, tileW, tileH)
        copyTile(srcImg, tempImg, 2, 0, 0, 0, tileW, tileH)
        copyTile(srcImg, tempImg, 3, 0, 0, 0, tileW, tileH)
        copyTile(srcImg, tempImg, 4, 0, 1, 0, tileW, tileH)
        updateMinitiles(tempImg, dstImg, tileW, tileH, offsets)
        
    elseif mode == "4x4" then
        update4x4(srcImg, dstImg, tileW, tileH)
        
    elseif mode == "3x3" then
        update3x3(srcImg, dstImg, tileW, tileH, offsets)
        
    elseif mode == "4x4plus" then
        update4x4(srcImg, dstImg, tileW, tileH)
        fix_inner_corners(srcImg, dstImg, {4, 0}, tileW, tileH, offsets)
        
    elseif mode == "3x3plus" then
        update3x3(srcImg, dstImg, tileW, tileH, offsets)
        fix_inner_corners(srcImg, dstImg, {3, 0}, tileW, tileH, offsets)
        
    elseif mode == "5x3" then
        update3x3(srcImg, dstImg, tileW, tileH, offsets)
        fix_inner_corners(srcImg, dstImg, {4, 0}, tileW, tileH, offsets)
        copyTile(srcImg, dstImg, 0, 0, 3, 0, tileW, tileH)
        copyTile(srcImg, dstImg, 0, 2, 3, 1, tileW, tileH)
        copyTile(srcImg, dstImg, 0, 3, 4, 1, tileW, tileH)
        copyTile(srcImg, dstImg, 1, 3, 3, 2, tileW, tileH)
        copyTile(srcImg, dstImg, 3, 3, 4, 2, tileW, tileH)
        
    elseif mode == "rpgmaker" then
        dstImg:drawImage(convertRpgmakerBlock(srcImg, tileW, tileH, offsets), Point(0, 0))
        if shadowImg then
            dstImg:drawImage(convertRpgmakerBlock(shadowImg, tileW, tileH, offsets),
                Point(0, SHADOW_ROW_OFFSET * tileH))
            maskShadowByBody(dstImg, tileW, tileH, SHADOW_ROW_OFFSET)
            buildOverflowAtlas(shadowImg, dstImg, tileW, tileH, offsets, SPILL_ROW_OFFSET)
        end
    end

    -- Draw the sample-scene region from the freshly-generated autotile
    if settings.showPreviewScene then
        drawPreviewScene(dstImg, tileW, tileH, sceneStartY, shadowImg ~= nil, groundColor)
    end

    -- Stamp the 3×3 seamless-fill preview (rpgmaker only)
    if fillActive then
        drawFillPreview(srcImg, dstImg, tileW, tileH, fillStartX, fillStartY)
    end

        -- Stamp the raw source tileset alongside the output (optional).
        if inputActive then
            drawSourceInput(srcImg, dstImg, inputStartX, inputStartY)
            -- Shadow on top at the board's opacity, so the stamp shows what
            -- the game will draw rather than the bare mask.
            if shadowImg then
                pcall(function()
                    dstImg:drawImage(shadowImg, Point(inputStartX, inputStartY),
                        PREVIEW_SHADOW_ALPHA)
                end)
            end
        end

        -- Write this frame into the matching preview frame.
        local cel = previewLayer:cel(job.dst)
        if cel then
            cel.image = dstImg
            cel.position = Point(0, 0)
        else
            previewSprite:newCel(previewLayer, job.dst, dstImg, Point(0, 0))
        end
        if job.dur then
            pcall(function()
                previewSprite.frames[job.dst].duration = srcFrame.duration
            end)
        end
    end  -- for job

    -- Restore focus to whatever the user had active (usually the source).
    if isSpriteValid(prevActive) and prevActive ~= previewSprite then
        app.activeSprite = prevActive
    end
    if not renderOk then
        if not updating then
            app.alert("Webtyler: couldn't render the source sprite. " ..
                "Open your tileset and run again.")
        end
        return
    end
    app.refresh()

    -- Hook live updates onto the source sprite (re-attach if source changed)
    if sourceSprite ~= source then
        if isSpriteValid(sourceSprite) and sourceChangeKey then
            pcall(function() sourceSprite.events:off(sourceChangeKey) end)
        end
        sourceSprite = source
        sourceChangeKey = source.events:on("change", onSourceChange)
    end
end

----------------------------------------------------------------------
-- DIALOG
----------------------------------------------------------------------

local function showDialog()
    if dlg then
        dlg:close()
    end
    
    dlg = Dialog{ title = "Webtyler Autotile" }
    
    dlg:combobox{
        id = "mode",
        label = "Input Format:",
        option = settings.mode,
        options = {
            "minitiles",
            "basic",
            "basicborder",
            "basicfullborder",
            "basiclongborder",
            "4x4",
            "3x3",
            "4x4plus",
            "3x3plus",
            "5x3",
            "rpgmaker"
        },
        onchange = function()
            settings.mode = dlg.data.mode
        end
    }
    
    dlg:separator{ text = "Tile Size" }
    
    dlg:number{
        id = "tileW",
        label = "Width:",
        text = tostring(settings.tileW),
        decimals = 0,
        onchange = function()
            settings.tileW = math.max(1, dlg.data.tileW)
        end
    }
    
    dlg:number{
        id = "tileH",
        label = "Height:",
        text = tostring(settings.tileH),
        decimals = 0,
        onchange = function()
            settings.tileH = math.max(1, dlg.data.tileH)
        end
    }
    
    dlg:separator{ text = "Offsets (advanced)" }
    
    dlg:number{
        id = "leftOff",
        label = "Left:",
        text = tostring(settings.leftOffset),
        decimals = 0,
        onchange = function()
            settings.leftOffset = dlg.data.leftOff
        end
    }
    
    dlg:number{
        id = "rightOff",
        label = "Right:",
        text = tostring(settings.rightOffset),
        decimals = 0,
        onchange = function()
            settings.rightOffset = dlg.data.rightOff
        end
    }
    
    dlg:number{
        id = "topOff",
        label = "Top:",
        text = tostring(settings.topOffset),
        decimals = 0,
        onchange = function()
            settings.topOffset = dlg.data.topOff
        end
    }
    
    dlg:number{
        id = "bottomOff",
        label = "Bottom:",
        text = tostring(settings.bottomOffset),
        decimals = 0,
        onchange = function()
            settings.bottomOffset = dlg.data.bottomOff
        end
    }
    
    dlg:separator{ text = "Preview" }

    dlg:check{
        id = "liveUpdate",
        label = "Live update:",
        selected = settings.liveUpdate,
        onclick = function()
            settings.liveUpdate = dlg.data.liveUpdate
        end
    }

    dlg:check{
        id = "showPreviewScene",
        label = "Show sample scene:",
        selected = settings.showPreviewScene,
        onclick = function()
            settings.showPreviewScene = dlg.data.showPreviewScene
            updatePreviews()
        end
    }

    dlg:check{
        id = "followFrame",
        label = "Follow source frame:",
        selected = settings.followFrame,
        onclick = function()
            settings.followFrame = dlg.data.followFrame
        end
    }

    dlg:check{
        id = "showInput",
        label = "Show source:",
        selected = settings.showInput,
        onclick = function()
            settings.showInput = dlg.data.showInput
            updatePreviews()
        end
    }

    dlg:check{
        id = "lockToTag",
        label = "Lock to tag:",
        selected = settings.lockToTag,
        onclick = function()
            settings.lockToTag = dlg.data.lockToTag
            updatePreviews()
        end
    }

    dlg:separator()

    dlg:button{
        id = "update",
        text = "Refresh Preview",
        onclick = function()
            updatePreviews()
        end
    }
    
    dlg:newrow()
    
    dlg:button{
        id = "close",
        text = "Close",
        onclick = function()
            dlg:close()
        end
    }
    
    dlg:show{ wait = false }
end

----------------------------------------------------------------------
-- EXPORT
----------------------------------------------------------------------
-- The preview frame to export and the source frame it was rendered from.
local function exportFrames()
    local frame = (app.activeSprite == previewSprite and app.activeFrame)
        or previewSprite.frames[1]
    return frame, (previewStartFrame or 1) + frame.frameNumber - 1
end

-- The Godot-facing tileset is the preview's top-left 12×4 tiles, or 12×12 when
-- this frame carries shadow blocks. The rest of the canvas (sample scene, fill
-- stamp, input copy) is for eyes only.
local function exportRows()
    local frame = exportFrames()
    local cel = previewSprite.layers[1]:cel(frame)
    if cel and imageHasInk(cel.image, 0, SHADOW_ROW_OFFSET * settings.tileH,
            12 * settings.tileW, 8 * settings.tileH) then
        return SPILL_ROW_OFFSET + 4
    end
    return 4
end

local function tagNameForFrame(sprite, frameNumber)
    for _, tag in ipairs(sprite.tags) do
        if frameNumber >= tag.fromFrame.frameNumber
                and frameNumber <= tag.toFrame.frameNumber then
            return tag.name
        end
    end
    return nil
end

-- Beside the source file, named after the previewed tag — the shipped
-- convention is <tag>_12x4.png — or after the file when the frame has no tag.
local function defaultExportPath()
    local _, sourceFrameNumber = exportFrames()
    local stem, dir = "webtyler", ""
    if isSpriteValid(sourceSprite) then
        stem = tagNameForFrame(sourceSprite, sourceFrameNumber)
            or app.fs.fileTitle(sourceSprite.filename)
        dir = app.fs.filePath(sourceSprite.filename)
    end
    stem = stem:gsub("[^%w_%-]", "_")
    return app.fs.joinPath(dir, string.format("%s_12x%d.png", stem, exportRows()))
end

-- Writes the tileset block of the preview's current frame to `path`.
local function exportTileset(path)
    local frame = exportFrames()
    local cel = previewSprite.layers[1]:cel(frame)
    local out = Image(12 * settings.tileW, exportRows() * settings.tileH,
        previewSprite.colorMode)
    out:clear()
    if cel then
        out:drawImage(cel.image, cel.position)
    end
    out:saveAs{ filename = path, palette = previewSprite.palettes[1] }
    return path
end

local function showExportDialog()
    if not isSpriteValid(previewSprite) then
        app.alert("No Webtyler preview yet. Run Webtyler Refresh Preview first.")
        return
    end
    local d = Dialog{ title = "Webtyler Export Tileset" }
    d:label{ text = string.format("Writes the preview's top-left 12×%d tiles.", exportRows()) }
    d:file{ id = "path", label = "PNG", save = true, filename = defaultExportPath(),
            filetypes = { "png" } }
    d:button{ id = "ok", text = "Export", focus = true }
    d:button{ id = "cancel", text = "Cancel" }
    d:show()
    if d.data.ok and d.data.path and d.data.path ~= "" then
        local ok, err = pcall(exportTileset, d.data.path)
        app.alert(ok and ("Exported " .. d.data.path) or ("Export failed: " .. tostring(err)))
    end
end

----------------------------------------------------------------------
-- PLUGIN INIT
----------------------------------------------------------------------

function init(plugin)
    plugin:newCommand{
        id = "WebtylerDialog",
        title = "Webtyler Settings",
        group = "sprite_properties",
        onclick = showDialog
    }
    
    plugin:newCommand{
        id = "WebtylerRefresh",
        title = "Webtyler Refresh Preview",
        group = "sprite_properties",
        -- Wrapped so no command arg leaks in as activeFrameOnly — manual
        -- Refresh always does the full multi-frame rebuild.
        onclick = function() updatePreviews(false) end
    }

    plugin:newCommand{
        id = "WebtylerExport",
        title = "Webtyler Export Tileset",
        group = "sprite_properties",
        onclick = showExportDialog
    }

    -- Listen for active-frame/sprite changes so the preview can follow the
    -- source's current frame (see onSiteChange). Wrapped: if this Aseprite build
    -- doesn't expose app.events, frame-follow is simply inactive.
    pcall(function()
        appSiteChangeKey = app.events:on("sitechange", onSiteChange)
    end)
end

function exit(plugin)
    if dlg then
        dlg:close()
    end
    if isSpriteValid(sourceSprite) and sourceChangeKey then
        pcall(function() sourceSprite.events:off(sourceChangeKey) end)
    end
    if appSiteChangeKey then
        pcall(function() app.events:off(appSiteChangeKey) end)
    end
    sourceSprite = nil
    sourceChangeKey = nil
    appSiteChangeKey = nil
end

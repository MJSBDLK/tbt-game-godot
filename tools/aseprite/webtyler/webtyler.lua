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
    mode = "minitiles",
    tileW = 16,
    tileH = 16,
    leftOffset = 0,
    rightOffset = 0,
    topOffset = 0,
    bottomOffset = 0,
}

local previewSprite = nil
local dlg = nil

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

local function updatePreviews()
    local sprite = app.activeSprite
    if not sprite then
        app.alert("No active sprite!")
        return
    end
    
    local srcImg = app.activeImage
    if not srcImg then
        app.alert("No active image/cel!")
        return
    end
    
    local mode = settings.mode
    local tileW = settings.tileW
    local tileH = settings.tileH
    local offsets = {
        left = settings.leftOffset,
        right = settings.rightOffset,
        top = settings.topOffset,
        bottom = settings.bottomOffset,
    }
    
    local outW = 12 * tileW
    local outH = 4 * tileH
    
    -- Create or resize preview sprite
    if not previewSprite or not pcall(function() return previewSprite.width end) then
        previewSprite = Sprite(outW, outH, sprite.colorMode)
        previewSprite.filename = "Webtyler Preview"
        -- Copy palette
        for i = 0, #sprite.palettes[1] - 1 do
            previewSprite.palettes[1]:setColor(i, sprite.palettes[1]:getColor(i))
        end
    else
        if previewSprite.width ~= outW or previewSprite.height ~= outH then
            previewSprite:resize(outW, outH)
        end
    end
    
    local dstImg = Image(outW, outH, srcImg.colorMode)
    dstImg:clear()
    
    -- Process based on mode
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
        local tempImg = createTempImage(tileW * 5, tileH, srcImg.colorMode)
        -- RPGMaker MV format conversion
        copyTileQuadRaw(srcImg, tempImg, {0, 0}, {0, 0}, {0, 1}, tileW, tileH, offsets)
        copyTileQuadRaw(srcImg, tempImg, {0, 0}, {1, 0}, {1, 1}, tileW, tileH, offsets)
        copyTileQuadRaw(srcImg, tempImg, {0, 0}, {0, 1}, {0, 2}, tileW, tileH, offsets)
        copyTileQuadRaw(srcImg, tempImg, {0, 0}, {1, 1}, {1, 2}, tileW, tileH, offsets)
        
        copyTileQuadRaw(srcImg, tempImg, {1, 0}, {0, 1}, {0, 1}, tileW, tileH, offsets)
        copyTileQuadRaw(srcImg, tempImg, {1, 0}, {1, 1}, {1, 1}, tileW, tileH, offsets)
        copyTileQuadRaw(srcImg, tempImg, {1, 0}, {0, 0}, {0, 2}, tileW, tileH, offsets)
        copyTileQuadRaw(srcImg, tempImg, {1, 0}, {1, 0}, {1, 2}, tileW, tileH, offsets)
        
        copyTileQuadRaw(srcImg, tempImg, {2, 0}, {1, 0}, {0, 1}, tileW, tileH, offsets)
        copyTileQuadRaw(srcImg, tempImg, {2, 0}, {0, 0}, {1, 1}, tileW, tileH, offsets)
        copyTileQuadRaw(srcImg, tempImg, {2, 0}, {1, 1}, {0, 2}, tileW, tileH, offsets)
        copyTileQuadRaw(srcImg, tempImg, {2, 0}, {0, 1}, {1, 2}, tileW, tileH, offsets)
        
        copyTile(srcImg, tempImg, 3, 0, 1, 0, tileW, tileH)
        
        copyTileQuadRaw(srcImg, tempImg, {4, 0}, {1, 1}, {0, 1}, tileW, tileH, offsets)
        copyTileQuadRaw(srcImg, tempImg, {4, 0}, {0, 1}, {1, 1}, tileW, tileH, offsets)
        copyTileQuadRaw(srcImg, tempImg, {4, 0}, {1, 0}, {0, 2}, tileW, tileH, offsets)
        copyTileQuadRaw(srcImg, tempImg, {4, 0}, {0, 0}, {1, 2}, tileW, tileH, offsets)
        
        updateMinitiles(tempImg, dstImg, tileW, tileH, offsets)
    end
    
    -- Apply to preview sprite
    app.activeSprite = previewSprite
    previewSprite.cels[1].image = dstImg
    app.refresh()
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
    
    dlg:separator()
    
    dlg:button{
        id = "update",
        text = "Update Preview (F10)",
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
        onclick = updatePreviews
    }
end

function exit(plugin)
    if dlg then
        dlg:close()
    end
end

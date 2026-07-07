-- Adjacent Color Select
--
-- Builds a selection containing every pixel of a TARGET color, but only where
-- that pixel touches a NEIGHBOR color. Classic use: select the outline pixels of
-- one color that border another (e.g. the shading band where skin meets hair).
--
-- Fast picking workflow: click a color swatch in the dialog to arm the eyedropper
-- (the active tool switches to Eyedropper), then click a pixel on the canvas and
-- the swatch fills with that color. No color-popup detour. The "<- FG" buttons
-- still load the current foreground color if you prefer.
--
-- Matching is exact in RGBA space. Pixels are read from the active cel's image
-- (or a flattened render of all visible layers, if that option is checked).
-- Adjacency defaults to 4-way (orthogonal); enable diagonals for 8-way.

local pc = app.pixelColor

-- 4-way and 8-way neighbor offsets.
local ORTHOGONAL = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local DIAGONAL = {
    { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 },
    { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 },
}

local dlg

-- Picked colors live here (the canvas swatches have no stored value of their own).
local target_color = Color{ r = 0, g = 0, b = 0, a = 255 }
local neighbor_color = Color{ r = 0, g = 0, b = 0, a = 255 }

-- Eyedropper arming state.
local armed_slot = nil       -- "target" | "neighbor" | nil
local previous_tool_id = nil -- tool to restore after a pick
local fg_listener = nil

local function copy_color(color)
    return Color{ r = color.red, g = color.green, b = color.blue, a = color.alpha }
end

local function color_to_hex(color)
    if color.alpha < 255 then
        return string.format("#%02X%02X%02X%02X",
            color.red, color.green, color.blue, color.alpha)
    end
    return string.format("#%02X%02X%02X", color.red, color.green, color.blue)
end

-- A dialog Color -> normalized RGBA integer (matches the encoding getPixel uses
-- for RGB images and the normalization we apply for grayscale/indexed below).
local function color_to_rgba(color)
    return pc.rgba(color.red, color.green, color.blue, color.alpha)
end

-- Returns a function that maps a raw pixel value (whatever the image's color mode
-- stores) to a normalized RGBA integer, so all three color modes compare the same
-- way. For indexed sprites the palette is baked into a lookup table up front so the
-- neighbor scan stays cheap.
local function build_normalizer(sprite, image)
    local mode = image.colorMode
    if mode == ColorMode.RGB then
        return function(value) return value end
    elseif mode == ColorMode.GRAY then
        return function(value)
            local gray = pc.grayaV(value)
            return pc.rgba(gray, gray, gray, pc.grayaA(value))
        end
    else -- ColorMode.INDEXED
        local palette = sprite.palettes[1]
        local lookup = {}
        for index = 0, #palette - 1 do
            local c = palette:getColor(index)
            lookup[index] = pc.rgba(c.red, c.green, c.blue, c.alpha)
        end
        return function(value) return lookup[value] or 0 end
    end
end

-- Reads pixels once into a dense grid[y][x] = normalized-RGBA table so the
-- adjacency test does plain table lookups instead of repeated getPixel + convert.
local function read_grid(image, normalize)
    local width, height = image.width, image.height
    local grid = {}
    for y = 0, height - 1 do
        local row = {}
        for x = 0, width - 1 do
            row[x] = normalize(image:getPixel(x, y))
        end
        grid[y] = row
    end
    return grid, width, height
end

-- The active image plus its offset into sprite space. Selection coordinates are
-- sprite-space, but a cel's image is stored at cel.position, so we carry that
-- offset; a flattened render starts at (0, 0).
local function get_source_image(sprite, use_flattened)
    if use_flattened then
        local ok, image = pcall(function() return Image(sprite) end)
        if not ok or not image then
            return nil, nil, nil, "Could not flatten the sprite on this build."
        end
        return image, 0, 0
    end

    local cel = app.activeCel
    if not cel then
        return nil, nil, nil, "The active layer has no cel on this frame."
    end
    return cel.image, cel.position.x, cel.position.y
end

-- ---------------------------------------------------------------------------
-- Eyedropper arming
-- ---------------------------------------------------------------------------

local function set_status(text)
    if dlg then dlg:modify{ id = "status", text = text } end
end

local function update_hex_labels()
    if not dlg then return end
    dlg:modify{ id = "target_hex", text = color_to_hex(target_color) }
    dlg:modify{ id = "neighbor_hex", text = color_to_hex(neighbor_color) }
end

local function restore_tool()
    if previous_tool_id then
        pcall(function() app.tool = previous_tool_id end)
        previous_tool_id = nil
    end
end

-- Fires whenever the foreground color changes. Only captures when a slot is armed
-- (e.g. the user just clicked the canvas with the armed eyedropper).
local function on_fg_changed()
    if not armed_slot or not dlg then return end
    local picked = copy_color(app.fgColor)
    if armed_slot == "target" then
        target_color = picked
    else
        neighbor_color = picked
    end
    armed_slot = nil
    restore_tool()
    dlg:repaint()
    update_hex_labels()
    set_status(color_to_hex(picked) .. " picked. Click Select when both are set.")
end

local function ensure_listener()
    if not fg_listener then
        fg_listener = app.events:on("fgcolorchange", on_fg_changed)
    end
end

local function arm_eyedropper(slot)
    if not app.activeSprite then
        set_status("Open a sprite first.")
        return
    end
    armed_slot = slot
    ensure_listener()
    if not previous_tool_id then
        local ok, tool = pcall(function() return app.tool end)
        if ok and tool then previous_tool_id = tool.id end
    end
    local switched = pcall(function() app.tool = "eyedropper" end)
    if switched then
        set_status("Eyedropper armed for " .. slot .. " — click a pixel on the canvas.")
    else
        set_status("Alt+click a pixel on the canvas to set the " .. slot .. " color.")
    end
end

-- ---------------------------------------------------------------------------
-- Swatch drawing
-- ---------------------------------------------------------------------------

local function draw_swatch(context, color)
    local width, height = context.width, context.height
    -- Checkerboard so partially-transparent colors read correctly.
    local cell = 6
    local light = Color{ r = 200, g = 200, b = 200 }
    local dark = Color{ r = 150, g = 150, b = 150 }
    for cy = 0, height - 1, cell do
        for cx = 0, width - 1, cell do
            context.color = (((cx // cell) + (cy // cell)) % 2 == 0) and light or dark
            context:fillRect(Rectangle(cx, cy,
                math.min(cell, width - cx), math.min(cell, height - cy)))
        end
    end
    context.color = color
    context:fillRect(Rectangle(0, 0, width, height))
    context.color = Color{ r = 0, g = 0, b = 0, a = 255 }
    context:strokeRect(Rectangle(0, 0, width, height))
end

-- ---------------------------------------------------------------------------
-- Selection
-- ---------------------------------------------------------------------------

local function run_selection()
    local sprite = app.activeSprite
    if not sprite then
        set_status("No active sprite.")
        return
    end

    local data = dlg.data
    local target_rgba = color_to_rgba(target_color)
    local neighbor_rgba = color_to_rgba(neighbor_color)
    local offsets = data.diagonal and DIAGONAL or ORTHOGONAL

    local image, offset_x, offset_y, err = get_source_image(sprite, data.flattened)
    if not image then
        set_status(err)
        return
    end

    local normalize = build_normalizer(sprite, image)
    local grid, width, height = read_grid(image, normalize)

    -- Scan rows, merging runs of consecutive selected pixels into one rectangle
    -- each so the resulting Selection is built from far fewer regions.
    local rectangles = {}
    local selected_count = 0
    for y = 0, height - 1 do
        local row = grid[y]
        local run_start = nil
        for x = 0, width - 1 do
            local is_selected = false
            if row[x] == target_rgba then
                for _, offset in ipairs(offsets) do
                    local nx, ny = x + offset[1], y + offset[2]
                    if nx >= 0 and nx < width and ny >= 0 and ny < height
                        and grid[ny][nx] == neighbor_rgba then
                        is_selected = true
                        break
                    end
                end
            end

            if is_selected then
                if not run_start then run_start = x end
                selected_count = selected_count + 1
            elseif run_start then
                rectangles[#rectangles + 1] =
                    Rectangle(offset_x + run_start, offset_y + y, x - run_start, 1)
                run_start = nil
            end
        end
        if run_start then
            rectangles[#rectangles + 1] =
                Rectangle(offset_x + run_start, offset_y + y, width - run_start, 1)
        end
    end

    if selected_count == 0 then
        set_status("No matching pixels (selection unchanged).")
        return
    end

    local selection = Selection()
    for _, rectangle in ipairs(rectangles) do
        selection:add(rectangle)
    end

    app.transaction(function() sprite.selection = selection end)
    app.refresh()

    set_status("Selected " .. selected_count .. " pixel(s).")
end

-- ---------------------------------------------------------------------------
-- Dialog
-- ---------------------------------------------------------------------------

local function open_dialog(plugin)
    if dlg then
        dlg:close()
        dlg = nil
    end

    target_color = copy_color(app.fgColor)
    neighbor_color = copy_color(app.bgColor)

    dlg = Dialog{
        title = "Adjacent Color Select",
        onclose = function()
            if fg_listener then
                app.events:off(fg_listener)
                fg_listener = nil
            end
            restore_tool()
            armed_slot = nil
            dlg = nil
        end,
    }

    dlg:separator{ text = "Target (select these pixels)" }
    dlg:canvas{
        id = "target_swatch",
        width = 44,
        height = 22,
        onpaint = function(ev) draw_swatch(ev.context, target_color) end,
        onmousedown = function() arm_eyedropper("target") end,
    }
    dlg:label{ id = "target_hex", text = color_to_hex(target_color) }
    dlg:button{
        text = "<- FG",
        onclick = function()
            target_color = copy_color(app.fgColor)
            dlg:repaint()
            update_hex_labels()
        end,
    }

    dlg:separator{ text = "Neighbor (target must touch this)" }
    dlg:canvas{
        id = "neighbor_swatch",
        width = 44,
        height = 22,
        onpaint = function(ev) draw_swatch(ev.context, neighbor_color) end,
        onmousedown = function() arm_eyedropper("neighbor") end,
    }
    dlg:label{ id = "neighbor_hex", text = color_to_hex(neighbor_color) }
    dlg:button{
        text = "<- FG",
        onclick = function()
            neighbor_color = copy_color(app.fgColor)
            dlg:repaint()
            update_hex_labels()
        end,
    }

    dlg:separator{}
    dlg:check{
        id = "diagonal",
        text = "Include diagonals (8-way adjacency)",
        selected = plugin.preferences.diagonal,
        onclick = function() plugin.preferences.diagonal = dlg.data.diagonal end,
    }
    dlg:check{
        id = "flattened",
        text = "Use all visible layers (flattened)",
        selected = plugin.preferences.flattened,
        onclick = function() plugin.preferences.flattened = dlg.data.flattened end,
    }

    dlg:separator{}
    dlg:button{ text = "Select", onclick = run_selection }
    dlg:button{ text = "Close", onclick = function() dlg:close() end }
    dlg:label{ id = "status", text = "Click a swatch, then click a pixel to eyedrop." }

    dlg:show{ wait = false }
end

function init(plugin)
    if plugin.preferences.diagonal == nil then
        plugin.preferences.diagonal = false
    end
    if plugin.preferences.flattened == nil then
        plugin.preferences.flattened = false
    end

    plugin:newCommand{
        id = "AdjacentColorSelect",
        title = "Adjacent Color Select...",
        group = "edit_new",
        onclick = function() open_dialog(plugin) end,
    }
end

function exit(plugin)
    if dlg then
        dlg:close()
        dlg = nil
    end
end

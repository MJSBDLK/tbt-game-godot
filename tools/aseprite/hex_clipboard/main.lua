-- Hex Clipboard — copies the foreground color's hex value to the system
-- clipboard, either automatically whenever the fg color changes (e.g. after
-- using the Eyedropper) or on demand via a menu command / hotkey.

local plugin_path
local fg_listener
local last_copied_hex = ""
local dlg

local function color_to_hex(color)
    local r, g, b, a = color.red, color.green, color.blue, color.alpha
    if a < 255 then
        return string.format("#%02X%02X%02X%02X", r, g, b, a)
    end
    return string.format("#%02X%02X%02X", r, g, b)
end

local function shell_quote(s)
    return "'" .. string.gsub(s, "'", "'\\''") .. "'"
end

local function copy_to_clipboard(text)
    local ok = false

    if app.os.windows then
        local handle = io.popen("clip", "w")
        if handle then
            handle:write(text)
            handle:close()
            ok = true
        end
    elseif app.os.macos then
        local handle = io.popen("pbcopy", "w")
        if handle then
            handle:write(text)
            handle:close()
            ok = true
        end
    else
        -- Linux: spawn a bundled Python/GTK helper, detached, with LD_LIBRARY_PATH
        -- stripped so a snap-launched parent (e.g. VSCode terminal) can't poison it.
        local helper = app.fs.joinPath(plugin_path, "clip_linux.py")
        local cmd = table.concat({
            "env -u LD_LIBRARY_PATH -u LD_PRELOAD",
            "python3",
            shell_quote(helper),
            shell_quote(text),
            "</dev/null >/dev/null 2>&1 &",
        }, " ")
        local result = os.execute(cmd)
        ok = (result == true) or (result == 0)
    end

    if ok then
        last_copied_hex = text
        if dlg then
            dlg:modify{ id = "status", text = "Last copied: " .. text }
        end
    end
    return ok
end

local function start_listener()
    if fg_listener then return end
    fg_listener = app.events:on("fgcolorchange", function()
        copy_to_clipboard(color_to_hex(app.fgColor))
    end)
end

local function stop_listener()
    if fg_listener then
        app.events:off(fg_listener)
        fg_listener = nil
    end
end

local function open_dialog(plugin)
    if dlg then
        dlg:close()
        dlg = nil
    end
    dlg = Dialog{
        title = "Hex Clipboard",
        onclose = function() dlg = nil end,
    }
    dlg:check{
        id = "auto_copy",
        text = "Auto-copy FG hex on color change",
        selected = plugin.preferences.auto_copy,
        onclick = function()
            plugin.preferences.auto_copy = dlg.data.auto_copy
            if plugin.preferences.auto_copy then
                start_listener()
            else
                stop_listener()
            end
        end,
    }
    dlg:separator{}
    dlg:button{
        text = "Copy current FG",
        onclick = function()
            copy_to_clipboard(color_to_hex(app.fgColor))
        end,
    }
    local status_text = "Last copied: " .. (last_copied_hex ~= "" and last_copied_hex or "(none)")
    dlg:label{ id = "status", text = status_text }
    dlg:show{ wait = false }
end

function init(plugin)
    plugin_path = plugin.path
    if plugin.preferences.auto_copy == nil then
        plugin.preferences.auto_copy = false
    end

    plugin:newCommand{
        id = "HexClipboardPanel",
        title = "Hex Clipboard...",
        group = "edit_new",
        onclick = function() open_dialog(plugin) end,
    }

    plugin:newCommand{
        id = "HexClipboardCopyNow",
        title = "Copy FG Hex to Clipboard",
        group = "edit_new",
        onclick = function()
            copy_to_clipboard(color_to_hex(app.fgColor))
        end,
    }

    if plugin.preferences.auto_copy then
        start_listener()
    end
end

function exit(plugin)
    if dlg then
        dlg:close()
        dlg = nil
    end
    stop_listener()
end

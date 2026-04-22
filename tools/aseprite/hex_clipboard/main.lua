-- Hex Clipboard — copies the foreground color's hex value to the system
-- clipboard, either automatically whenever the fg color changes (e.g. after
-- using the Eyedropper) or on demand via a menu command / hotkey.

local plugin_path
local fg_listener
local last_copied_hex = ""
local dlg
local trigger_file
local clip_file

local function color_to_hex(color)
    local r, g, b, a = color.red, color.green, color.blue, color.alpha
    if a < 255 then
        return string.format("#%02X%02X%02X%02X", r, g, b, a)
    end
    return string.format("#%02X%02X%02X", r, g, b)
end

local function posix_quote(s)
    return "'" .. string.gsub(s, "'", "'\\''") .. "'"
end

local function win_quote(s)
    return '"' .. string.gsub(s, '"', '""') .. '"'
end

local function copy_to_clipboard(text)
    local ok = false

    if app.os.windows then
        -- Write to trigger file; the background daemon picks it up and calls clip.exe.
        -- This avoids spawning cmd.exe on every color change (which is slow due to
        -- Windows Defender scanning processes spawned from unsigned executables).
        local f = io.open(trigger_file, "w")
        if f then
            f:write(text)
            f:close()
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
        local helper = app.fs.joinPath(plugin_path, "clip_linux.py")
        local cmd = table.concat({
            "env -u LD_LIBRARY_PATH -u LD_PRELOAD",
            "python3",
            posix_quote(helper),
            posix_quote(text),
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

local function on_fg_color_change()
    copy_to_clipboard(color_to_hex(app.fgColor))
end

local function start_listener()
    if fg_listener then return end
    fg_listener = app.events:on("fgcolorchange", on_fg_color_change)
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

    if app.os.windows then
        local tmp = os.getenv("TEMP") or os.getenv("TMP") or "C:\\Temp"
        trigger_file = tmp .. "\\aseprite_hex_clipboard.txt"
        clip_file    = tmp .. "\\aseprite_hex_clipboard_data.txt"
        local daemon = app.fs.joinPath(plugin_path, "daemon_win.vbs")
        -- start "" (no /B) launches wscript detached; cmd.exe exits immediately.
        -- First call is slow (~5s, Windows Defender cold-start on cmd.exe) but
        -- only happens once at plugin init, not on every color change.
        os.execute(string.format(
            'start "" wscript //nologo //B %s %s %s',
            win_quote(daemon),
            win_quote(trigger_file),
            win_quote(clip_file)
        ))
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
    if app.os.windows and trigger_file then
        local f = io.open(trigger_file, "w")
        if f then
            f:write("STOP")
            f:close()
        end
    end
end

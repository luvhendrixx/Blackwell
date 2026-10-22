-- ~/.config/hypr/keybinds.lua
-- Migrated from keybinds.conf
-- Docs: https://wiki.hypr.land/Configuring/Basics/Binds/
--       https://wiki.hypr.land/Configuring/Basics/Dispatchers/

local home = os.getenv("HOME")
local menu = "rofi -show drun"

-- Omarchy-style universal clipboard via key state injection (not wtype: the
-- held SUPER would merge into the injected chord). Down/up split avoids
-- stuck synthetic key state in Hyprland's send_key_state.
local function send_shortcut_once(mods, key)
  return function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
  end
end

local function active_window_is_terminal()
  local window = hl.get_active_window()
  if not window then return false end
  for _, tag in ipairs(window.tags or {}) do
    if tag:gsub("%*$", "") == "terminal" then return true end
  end
  return false
end

local function universal_clipboard_shortcut(default_mods, default_key, terminal_mods, terminal_key)
  return function()
    if active_window_is_terminal() then
      send_shortcut_once(terminal_mods, terminal_key)()
    else
      send_shortcut_once(default_mods, default_key)()
    end
  end
end

hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal)) 
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal)) -- SUPER+Return: ghostty
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("scratchpad")) -- Scratchpad
hl.bind(mainMod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false })) -- Send to scratchpad
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())

hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("sh " .. home .. "/.config/quickshell/MacLock/lock-via-ipc.sh")) -- Lock screen (MacLock, PAM)
hl.bind(mainMod .. " + ALT + L", hl.dsp.exec_cmd("python3 " .. home .. "/.config/43pr/bin/theme.py toggle")) -- Light/dark toggle (moved off SUPER+L)

hl.bind(mainMod .. " + grave", hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/terminal-toggle.sh")) -- Toggle terminal scratchpad
hl.bind(mainMod .. " + SHIFT + GRAVE", hl.dsp.exec_cmd("qs ipc call powermenu toggle")) -- Power menu

hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("qs ipc call settings toggle")) -- Settings

hl.bind(mainMod .. " + W", hl.dsp.window.close()) -- Close focused window

hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = 0 })) -- Fullscreen

hl.bind(mainMod .. " + O", hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/opacity.sh")) -- Opacity



hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("qs ipc call notifications toggle")) -- Notifications

hl.bind("ALT + R", hl.dsp.exec_cmd("qs ipc call reminders toggle")) -- Reminders (add / view / snooze)

hl.bind(mainMod .. " + C", universal_clipboard_shortcut("CTRL", "C", "CTRL SHIFT", "C")) -- Universal copy

-- Mouse move/resize window
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("qs ipc call bar toggle")) -- Toggle bar

hl.bind(mainMod .. " + V", universal_clipboard_shortcut("CTRL", "V", "CTRL SHIFT", "V")) -- Universal paste

-- Screenshots via omasnap (toggles overlay; press again to dismiss)
hl.bind("PRINT", hl.dsp.exec_cmd(home .. "/.local/bin/omasnap"))

hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd("qs ipc call notifications dismissOne")) -- Dismiss last notification

hl.bind(mainMod .. " + SHIFT + X", hl.dsp.exec_cmd("qs ipc call wheel toggle")) -- Wheel launcher
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("qs -n -p ~/.config/quickshell/hyprquickpaper")) -- Wallpaper selector

-- Emoji picker: pick -> copy -> type into focused window
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("qs ipc call spotlight emoji"))

-- To-do (direct toggle without opening wheel)
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("qs ipc call todo toggle"))

-- App launcher
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("qs ipc call spotlight toggle"))
hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd("qs ipc call notification dismiss"))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.exec_cmd(fileManager)) -- Nautilus

-- Gpu screen recorder
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(
    "bash -c 'PIDFILE=/tmp/osu-gsr.pid; if [ -f \"$PIDFILE\" ] && kill -0 \"$(cat \"$PIDFILE\")\" 2>/dev/null; then kill -INT \"$(cat \"$PIDFILE\")\"; rm -f \"$PIDFILE\"; else mkdir -p ~/Videos; gpu-screen-recorder -w HDMI-A-1 -f 60 -a default_output -o ~/Videos/$(date +%Y-%m-%d_%H-%M-%S).mp4 & echo $! > \"$PIDFILE\"; fi'"
))

-- Zoom
local function zoomfunction(value)
    local zoomvalue = hl.get_config("cursor:zoom_factor")
    if (zoomvalue + value) > 1.5 then
        hl.config({ cursor = { zoom_factor = 1.5 } })
    elseif (zoomvalue + value) < 1.0 then
        hl.config({ cursor = { zoom_factor = 1.0 } })
    else
        hl.config({ cursor = { zoom_factor = zoomvalue + value } })
    end
end
hl.bind(mainMod .. " + mouse_down", function() zoomfunction(-0.5) end, { repeating = true })
hl.bind(mainMod .. " + mouse_up", function() zoomfunction(0.5) end, { repeating = true })
hl.bind(mainMod .. " + slash", function()
    local zoom = hl.get_config("cursor:zoom_factor") or 1
    hl.config({ cursor = { zoom_factor = zoom + 1 } })
end, { repeating = true })
hl.bind(mainMod .. " + ALT + slash", function()
    local zoom = hl.get_config("cursor:zoom_factor") or 1
    hl.config({ cursor = { zoom_factor = math.max(1, zoom - 1) } })
end, { repeating = true })

--# Zoom with keypad
hl.bind(mainMod .. " + code:82", function() zoomfunction(-0.3) end, { repeating = true })
hl.bind(mainMod .. " + code:86", function() zoomfunction(0.3) end, { repeating = true })

-- VERIFY: exit dispatcher. Docs explicitly say to double check the exit
-- dispatcher call when moving to Lua.
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exit())

-- Focus (H/J/K/L = left/down/up/right, vim-style, matching your original)
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))

-- VERIFY: move active window within layout (old `movewindow` dispatcher).
-- Confirmed pattern is hl.dsp.window.move({ workspace = N }) for sending to a
-- workspace (used below) - the direction-swap variant isn't shown in the
-- official example, so double check this fires like the old movewindow did.
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))

-- VERIFY: resize active window by pixel delta (old `resizeactive`, repeating
-- while held via `binde`). Param names guessed as x/y - confirm with hyprctl eval.
hl.bind(mainMod .. " + CTRL + H", hl.dsp.window.resize({ x = -40, y = 0 }), { repeating = true })
hl.bind(mainMod .. " + CTRL + L", hl.dsp.window.resize({ x = 40, y = 0 }), { repeating = true })
hl.bind(mainMod .. " + CTRL + K", hl.dsp.window.resize({ x = 0, y = -40 }), { repeating = true })
hl.bind(mainMod .. " + CTRL + J", hl.dsp.window.resize({ x = 0, y = 40 }), { repeating = true })

-- Workspaces 1-10, and move-to-workspace with SHIFT (confirmed pattern from
-- the official example config)
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Media keys (confirmed pattern from the official example config)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("sh -c 'brightnessctl set 5%+ && qs ipc call brightnessosd show'"), { repeating = true, locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("sh -c 'brightnessctl set 5%- && qs ipc call brightnessosd show'"), { repeating = true, locked = true })

hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
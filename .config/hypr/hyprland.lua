-- ~/.config/hypr/hyprland.lua
-- Docs: https://wiki.hypr.land/Configuring/Start/

---- MY PROGRAMS ----

local home = os.getenv("HOME")

mainMod = "SUPER"
terminal = "kitty"
menu = "rofi -show drun"
fileManager = "nautilus"
browser = "firefox"

---- AUTOSTART ----

hl.on("hyprland.start", function()
	-- hl.exec_cmd("dunst") replaced with quickshell notifications
	hl.exec_cmd("nm-applet")
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")
	hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")

	hl.exec_cmd("awww-daemon")
	-- awww-daemon alone draws nothing; a fresh machine would boot black.
	hl.exec_cmd(home .. "/.config/hypr/scripts/wallpaper-init.sh")
	hl.exec_cmd("qs")
	hl.exec_cmd(home .. "/.config/hypr/scripts/powerprofile-auto.sh")
end)

---- ENVIRONMENT VARIABLES ----

-- MacShell lives in a normal on-disk QML module so Qt can cache its compiled
-- bytecode. Quickshell's config root uses the qsintercept scheme, which Qt
-- refuses to cache. Without this the ~9k-line MacBar is recompiled on every
-- launch and the bar/dock appear seconds after login.
local qmlModules = home .. "/.config/quickshell-modules"
local qmlImportPaths = { qmlModules }
local inheritedQmlImportPath = os.getenv("QML_IMPORT_PATH")
if inheritedQmlImportPath and inheritedQmlImportPath ~= "" then
	for path in inheritedQmlImportPath:gmatch("[^:]+") do
		if path ~= qmlModules then
			table.insert(qmlImportPaths, path)
		end
	end
end
hl.env("QML_IMPORT_PATH", table.concat(qmlImportPaths, ":"))
hl.env("QML_DISK_CACHE", "qmlc")
hl.env("QML_DISK_CACHE_PATH", home .. "/.cache/quickshell/qml-engine-cache")

hl.env("XCURSOR_SIZE", "15")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")

---- INPUT ----

hl.config({
	input = {
		kb_layout = "us",
		follow_mouse = 1,
		sensitivity = 0.3,
		repeat_rate = 40,
		repeat_delay = 250,
		touchpad = {
			natural_scroll = false,
			tap_to_click = true,
			scroll_factor = 0.5,
		},
	},
})

-- LAYOUT
hl.config({
	dwindle = { preserve_split = true },
})
hl.config({
	master = { new_status = "master" },
})

-- MISC
hl.config({
	misc = {
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		-- If the session-lock client (MacLock) ever dies while locked, let a
		-- fresh instance take over the existing lock instead of stranding the
		-- session on Hyprland's "lockscreen app died" screen until reboot.
		allow_session_lock_restore = true,
	},
})

---- SPLIT-OUT FILES ----

require("monitors")
require("keybinds")
require("look")
require("rules")

-- HyprMod managed settings (disabled: it rebound keys to kitty/thunar,
-- which were removed; bindings now live in keybinds.lua)
-- require("hyprland-gui")

-- HyprMod managed settings
require("hyprland-gui")

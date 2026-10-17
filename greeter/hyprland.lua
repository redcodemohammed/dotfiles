-- Hyprland for the login screen only (owner's choice, 2026-10-15). greetd runs it as the greeter
-- user (/etc/greetd/quickshell-greeter.toml); it shows the Quickshell greeter and exits when the
-- greeter quits, so greetd can start the chosen session. Installed to /etc/greetd by
-- greeter/install.sh, with hypr_palette.lua beside it (the greeter user can't read ~).
-- Monitors: monitors.lua, the same file as the session's (install.sh copies it beside this one).

local palette = require("hypr_palette")
local screens = require("monitors")

if screens.laptop then
    local l = screens.laptop
    hl.monitor({ output = l.output, mode = l.mode, position = l.position, scale = l.scale })
end
for _, s in ipairs(screens.screens) do
    hl.monitor({ output = s.output, mode = s.mode, position = s.position, scale = s.scale })
end
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" }) -- catch-all, never remove

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
-- The session's mouse cursor (palette/cursors.py), built for the greeter by install.sh into
-- /usr/share/icons/hypr-cursors; missing, Hyprland falls back to its default cursor.
hl.env("HYPRCURSOR_THEME", "hypr-cursors")
hl.env("XCURSOR_THEME", "hypr-cursors")

hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        background_color = palette.bg,
    },
    animations = {
        enabled = false,
    },
    input = {
        kb_layout = "us,ara", -- the same layouts as the session; SUPER + Space switches
        kb_options = "grp:win_space_toggle",
        follow_mouse = 1,
    },
})

-- The greeter; when it quits (after starting a session, or a crash), leave so greetd moves on.
hl.on("hyprland.start", function()
    hl.exec_cmd([[qs -p /etc/greetd/quickshell-greeter; hyprctl dispatch 'hl.dsp.exit()']])
end)

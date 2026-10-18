-- Example screens (the owner's first laptop: Odyssey G5 main, LF24T35 right, panel left). Each
-- machine keeps its own monitors.lua (not in git, owner 2026-10-18): copy this file to it and
-- edit. Without one, hyprland.lua and the greeter use this file, and unlisted screens still
-- light up through the catch-all.
-- Names and descriptions come from
-- `hyprctl monitors` (name, description); mode, position and scale are as Hyprland takes them
-- (wiki.hypr.land/Configuring/Basics/Monitors). Positions are logical pixels (after scale).
-- Read by hyprland.lua and greeter/hyprland.lua (greeter/install.sh copies it beside the
-- greeter). The bar learns `main`, `laptop` and `workspace_order` from the environment, which
-- hyprland.lua sets from here. A screen not listed still lights up (hyprland.lua's catch-all).
return {
    -- The laptop's own panel, or nil on a desktop. Off while the lid is shut and another
    -- screen is attached.
    laptop = { output = "eDP-1", mode = "2560x1600@165.04", position = "0x101", scale = 4 / 3 },

    -- The other screens. Externals match by description ("desc:<make model>"), so a port change
    -- doesn't matter. One of them is `main`: it gets the full bar, and the laptop's workspaces
    -- when the lid shuts. `model` is the model part of its description (the bar matches it).
    screens = {
        { output = "desc:Samsung Electric Company Odyssey G5", model = "Odyssey G5", main = true,
          mode = "2560x1440@144", position = "1920x0", scale = 1 },
        { output = "desc:Samsung Electric Company LF24T35",
          mode = "1920x1080@74.97", position = "4480x161", scale = 1 },
    },

    -- Workspaces, five per screen (1-5, 6-10, 11-15, ...), by connector name (`hyprctl monitors`;
    -- hyprsplit matches the name exactly). The laptop's panel listed second here is 6-10.
    workspace_order = { "HDMI-A-1", "eDP-1", "DP-2" },
}

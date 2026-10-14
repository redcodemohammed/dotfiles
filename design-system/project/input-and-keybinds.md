# Input and keybinds

SUPER is the only desktop modifier. No Alt binds. tmux keeps `Ctrl+Space`, so nothing collides.

## Input

- Caps Lock: tap for Escape, hold for Ctrl. `keyd` is the pick (one overload line, runs as a root service and reads all keyboard input). Apply to laptop and external keyboards, tune the tap timing.
- Layout toggle: SUPER + Space, an XKB option (probably `grp:win_space_toggle`, verify).
- Letter and symbol binds use keycodes (`code:NN`, found with `wev`) so the Arabic layout never breaks them. Arrows work in any layout.

## Keybinds

| Action | Keys |
| --- | --- |
| Terminal | SUPER + Return |
| Launcher | SUPER + / |
| Notification inbox | SUPER + I |
| Layout toggle | SUPER + Space |
| Fullscreen, bar hidden | SUPER + N |
| Maximize, bar stays | SUPER + M |
| Close window | SUPER + Q |
| Toggle floating | SUPER + V |
| Focus | SUPER + arrows, or H, J, K, L |
| Move window | SUPER + Shift + arrows, or H, J, K, L |
| Resize | SUPER + Ctrl + arrows |
| Lock | SUPER + Escape |
| Screenshot: region, window, monitor | Print, SUPER + Print, SUPER + Shift + Print |
| Annotate last screenshot | SUPER + Ctrl + Print |
| Workspace 1 to 5 | SUPER + 1 to 5 |
| Send window to workspace | SUPER + Shift + 1 to 5 |
| Window to previous or next monitor | SUPER + Shift + comma, period |
| Record toggle | SUPER + R |

Both arrow and HJKL sets are bound: drop the unused set after two weeks. Laptop up and down arrows are often half-height: test them. Fullscreen hides the bar on that screen only.

## Screenshots, recording, clipboard

- Capture with `hyprshot`, annotate with `satty` on its own key. Modes: region, window, focused monitor, never all three screens at once. Every capture is saved, copied to the clipboard and confirmed by a Mako popup. Satty uses the shared palette, sharp corners, `accent` as the default color, arrow and rectangle tools only.
- Recording: OBS for real content and streaming, `gpu-screen-recorder` for quick capture. SUPER + R toggles, saves to a recordings folder, a Mako popup confirms. No replay buffer. Waybar shows a red glyph while recording.
- Clipboard: `wl-clipboard`, history in Vicinae. No `cliphist`.

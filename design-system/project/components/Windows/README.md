Window layout on every screen: `space-1` between windows and between window and bar, `edge-gap` (0) at the sides, bottom and bar-to-edge. Hyprland needs per-side gaps for a 4px top gap and 0 elsewhere: verify the syntax.

- Border `border-w` on every window. Active `accent`, inactive `border`. Never dim inactive windows.
- Windows sit on `surface`, the screen on `bg`, `radius-none`, no blur, no shadow.
- Fullscreen (SUPER + N) hides the bar on that screen only. Maximize (SUPER + M) keeps the bar.
- Workspaces are per monitor, 1 to 5 each, through `hyprsplit`.

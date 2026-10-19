Waybar, 32px tall (`bar-h`), on top of every screen, no vertical bars. Main screen gets the full bar, the others get slim bars, and a lone screen always gets the full bar.

Every item answers one question: workspaces (where am I), window title (what is focused), clock (what time), media (what is playing), tray (what is running), mic and camera (am I being captured), volume, network, Bluetooth, battery, notifications (anything unread). Anything that answers none of these is cut: no weather, CPU, RAM, temperature, disk, uptime, date. The date shows on clock hover.

- Workspace buttons are `ws-btn` squares with numbers. Active: `accent` fill, `on-accent` text. Occupied: `fg-muted`. Empty: `fg-dim`.
- Icons are 16px (`icon`) Phosphor Regular. Icon to value gap `space-1`, module gap `space-2`, bar edge padding `space-2`.
- Volume and battery: icon plus number. Network and Bluetooth: icon only. Mic and camera: icon only, `alert`, visible only while live. Clock and title: text only, no app icon.
- Cap the window title near 40 characters and truncate. Set Arabic titles in `arabic-body`.
- Default state is all `fg-muted`. `alert` appears only for live mic, recording, critical battery, network down. State changes the glyph, not the color: muted shows a speaker-slash in gray.
- The unread count is `fg-muted` at zero and `accent` when unread.

The consumer provides the module data (Waybar modules), the per-output config array, and the tray apps' own icons.

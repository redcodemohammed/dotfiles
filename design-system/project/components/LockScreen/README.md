hyprlock on solid `bg`, centered clock, password field on every screen. No avatar, username, wallpaper or blur. Shows no notification content and no media info. A small `fg-muted` battery indicator appears on the laptop only.

- Clock: `lock-clock`, `fg`, HH:MM. Date: `caption`-size, `fg-muted`, `space-2` under the clock.
- Field: `lock-field-w` by `search-h`, `space-6` below the date, `border-w` border, `radius-none`.
- Layout label under the field (EN or AR) so a wrong-layout password is obvious.
- States: idle `border`, typing `accent` border with `fg` dots, wrong `alert` border with a short message, Caps Lock a small `alert` label under the field.
- Idle chain (starting values): lock at 5 minutes, screens off at 6, suspend at 30 on battery only. Lock before any sleep. Lid close with externals attached must not suspend.
- Test with a second TTY or SSH session open: a broken config can lock you out.

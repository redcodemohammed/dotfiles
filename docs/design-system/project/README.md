Own Hyprland desktop on Arch. Omarchy's structure, not its install: sharp, flat, dark, one amber accent. Everything here is a design rule for configs (Hyprland, Waybar, Vicinae, Mako, hyprlock, Alacritty). Build the configs from these tokens, never from guesses.

## Content fundamentals

- Every bar item answers one question. If an item answers none, cut it. Cut on purpose: weather, CPU, RAM, temperature, disk, uptime, date.
- Labels are plain and short: numbers for workspaces, `HH:MM` for the clock, a number beside volume and battery. No emoji, no decorative text, no app icon next to a title.
- Window titles truncate near 40 characters. Notification bodies truncate at 2 lines.
- Messages are short and factual: "Wrong password", "CAPS LOCK", "Screenshot saved". Errors state what happened, no apology.
- Arabic is first class: set it in `arabic-body` (Vazirmatn) and test with real titles in the bar, popups, launcher and lock field.

## Visual foundations

- **Unit.** One 4px unit (`space-1`) drives every size and gap. Steps: `space-1` 4, `space-2` 8, `space-3` 12, `space-4` 16, `space-6` 24. `border-w` (2px) is the only half-unit exception.
- **Gaps.** `space-1` between any two things (window to window, window to bar). `edge-gap` (0) at screen edges.
- **Color.** Grayscale plus one amber. Screen, bar, terminal: `bg`. Windows, launcher, popups: `surface`. Edges: `border`. Text: `fg`, secondary `fg-muted`. Red is `alert`. Dark mode only.
- **Amber (`accent`) is rare.** Use it only for: active workspace, active window border, launcher selection marker, caret, typing border, unread count. It means focus, never caution: no amber warnings. Text on an amber fill is `on-accent`, never white.
- **State.** Status icons stay `fg-muted`. `alert` only for real failure: live mic or camera, recording, critical battery, network down, urgent popup, wrong password. State changes the glyph, not the color.
- **Borders.** 2px on every window. Active `accent`, inactive `border`. No dimming of inactive windows.
- **Shape.** `radius-none` everywhere. Solid surfaces: no transparency, no blur, no shadows.
- **Type.** JetBrains Mono Nerd Font for everything (`font-mono`), Vazirmatn as the Arabic fallback (`font-arabic`). Styles: `bar`, `body`, `caption`, `lock-clock`, `arabic-body`. Sizes are proposed starting values: tune on the real screens, laptop panel included.
- **Motion.** Minimal. Workspace switch is instant.
- **Wallpaper.** Solid `bg`, same as the lock screen. No pattern, no image.

## Iconography

- Phosphor Regular, 16px (`icon`) in the bar and search field. Use the Fill weight for active or alert state (`record-fill`, `microphone-fill`, `camera-fill`). Fallback: a Nerd Font glyph for the Arch logo only.
- Icon files live in the Icons asset group. They are single-ink SVGs drawn in `fg-muted` (`#8a8a8a`): inline the path data and set the color from a token when a state needs another ink (`alert` for live states).
- App icons are content, not chrome: they keep their own colors (Papirus-Dark) at 24px (`app-icon`) in the launcher and popups.

## Components

`Bar`, `Launcher`, `Notification`, `Osd`, `LockScreen`, `Terminal`, `Windows`. Each has a guideline and a live preview. `bundle.css` holds the shared preview styles as `.hy-*` classes. They are references for the real configs, not a shipping UI library.

## Where the rest lives

- Monitors, bars per screen, workspaces, hotplug: Desktop layout.
- Keys, input, screenshots, recording: Input and keybinds.
- Package list, build order, verify list: Stack and build.

Omarchy is reference only: its look differs (gaps 5 and 10, gradient border, theme packs). Use gaps 4 and 0, a flat amber border and this one palette.

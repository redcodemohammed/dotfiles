# Hyprland design spec

Oct 12, 2026 · @Mohammed Wisam

## Overview

Own Hyprland desktop on Arch. Omarchy's structure, not its install. Sharp, flat, dark, one amber accent. Brainstorm stage: no configs written yet. Update: Quickshell replaces Waybar, Mako, swayosd, and hyprlock. Where this doc names them, read Quickshell. hypridle, hyprsunset, and Vicinae stay. Open: lock-screen safety plan.

Principles:

- Sharp corners. Radius 0 everywhere.
- One 4px unit drives every size and gap.
- One accent. Amber. No second.
- Solid surfaces. No transparency, no blur.
- Chrome is grayscale plus amber. App icons keep their own colors.
- Every bar item answers one question. If not, cut it.

Omarchy is reference only. Clone `github.com/basecamp/omarchy` to read its configs and scripts. Its look differs from ours: gaps 5 and 10, gradient border, theme packs. We use gaps 4 and 0, a flat amber border, and one palette.

## Design tokens

Everything derives from a 4px unit. Dark mode only.

| Token | Value |
| --- | --- |
| Unit | 4px. Steps: 4, 8, 12, 16, 24 |
| Gap, between any two things | 4px (windows, window to bar) |
| Gap at screen edges | 0 (sides, bottom, bar to edge) |
| Border | 2px. Only half-unit exception |
| Radius | 0 everywhere |
| Bar height | 32px (8 units) |
| Font | JetBrains Mono Nerd Font |
| Arabic fallback | Vazirmatn. Test with real titles |
| Icons | Phosphor Regular. Fill weight for active or alert state |
| Icon fallback | Nerd Font, Arch logo only |
| Transparency | None |
| Motion | Minimal. Workspace switch instant |

### Palette

Starting values. Tune on the real screens, laptop panel included.

| Role | Hex |
| --- | --- |
| Background (screen, bar) | `#111111` |
| Surface (windows, launcher, popups) | `#1a1a1a` |
| Border, muted | `#333333` |
| Foreground | `#e6e6e6` |
| Muted text | `#8a8a8a` |
| Accent, amber | `#f5a524` |
| On accent | `#111111` |
| Alert, red | `#e5484d` |

### Color rules

- Amber is rare. Active workspace, active border, selection marker, caret, typing border.
- Text on amber fill is dark. Never white.
- No amber warnings. Amber means focus, not caution.
- Status icons stay gray. Red only on real failure.
- State changes the glyph, not the color. Muted shows a muted-speaker glyph.
- Active window: 2px amber border. Inactive: 2px muted border. No dimming.

## Monitors and bars

Three screens. Every bar sits on top. No vertical bars. Main gets the full bar. The others get slim bars. Bars are built with Quickshell, not Waybar. Wherever this doc says Waybar, read Quickshell. Tokens and layout stay the same.

| Screen | Position | Bar |
| --- | --- | --- |
| Main | Center | Full |
| Laptop | Left | Slim, plus battery and network |
| External right | Right | Slim, plus media |
| Laptop alone | Only screen | Full |
| Lid closed | Laptop gone | Its workspaces land on the survivor |

### Full bar

Each item answers one question.

| Zone | Item | Answers |
| --- | --- | --- |
| Left | Workspaces 1 to 5 | Where am I? |
| Left | Active window title | What is focused? |
| Center | Clock | What time? |
| Right | Media, only while playing | What is playing? |
| Right | Tray (main bar only) | What is running? |
| Right | Mic and camera indicator | Am I being captured? |
| Right | Volume | Sound on? |
| Right | Network | Online? |
| Right | Bluetooth | Connected? |
| Right | Battery, laptop only | Charged? |
| Right | Notification count and DND | Anything unread? |

Slim bars: workspaces, window title, clock. Laptop adds battery and network. Right screen adds media.

Cut on purpose: weather, uptime, date. Date shows on clock hover.

System block (owner, 2026-10-18, overriding the earlier cut): main bar only, CPU, RAM and root disk as glyph plus percent, gray. A click opens the system panel: CPU use and temperature with a one-minute graph, memory with a graph, every disk, the three busiest processes.

### Bar styling

- Workspace buttons: numbers, 24px squares. Active: amber fill, dark text. Occupied: gray text. Empty: dim.
- Icons 16px. Icon to value gap 4px. Module gap 8px. Bar edge padding 8px.
- Volume and battery: icon plus number. Network and Bluetooth: icon only. Mic and camera: icon only, red, visible only when live. Clock and window title: text only, no app icon.
- Window title capped near 40 characters, truncated.
- Default state all gray. Red only for live mic, recording, critical battery, network down.

### Hotplug

One rule: if only one screen exists, it gets the full bar. Hyprland alone cannot swap bar profiles. A tool like `kanshi` or `hyprdynamicmonitors` is needed. Verify which one works well on the current Hyprland. Test three states early: three screens, two screens, laptop alone.

## Launcher

Vicinae. Centered, compact, sharp. It replaces Walker. Bound to SUPER + /.

| Part | Spec |
| --- | --- |
| Width | 560px |
| Position | Horizontal center, slightly above vertical middle |
| Screen | Focused monitor (verify Vicinae does this) |
| Corners, border | 0 radius, 2px muted border |
| Background | Surface `#1a1a1a`. Solid. No blur, no shadow |
| Search field | 48px tall. Phosphor magnifier 16px, muted. Caret amber. 2px muted divider below |
| Result rows | 40px tall, 12px side padding, no gaps between rows |
| Visible rows | 8 max, then scroll |
| Row content | App icon left, title, muted type tag right |
| App icons | Colorful, 24px, 8px from the row edge, 12px gap to title |
| Selection | Lighter surface plus 2px amber marker on the left edge. No full amber fill |

### Rules

- Grayscale applies to system chrome. App icons are content, so they keep color.
- Amber marker stays on the row edge, away from orange and yellow icons.
- Icon theme for every app: Papirus-Dark. Verify it is current on Arch.
- Missing icons fall back to a generic glyph. Check how that looks.
- Clipboard history comes from Vicinae. No `cliphist`.
- File search uses Vicinae's built-in file search. Nothing extra to install.
- Test Arabic typing in the search field. Caret alignment can break in monospace.

## Notifications

Quickshell shows popups and owns the notification service on D-Bus. Mako is dropped. Inbox is a Quickshell panel. The Vicinae extension is dropped. Inbox opens with SUPER + I.

### Popups

| Part | Spec |
| --- | --- |
| Position | Top-right, flush with the right edge, 4px below the bar |
| Screen | Focused output (verify the option name) |
| Size | 360px wide. Padding 12px |
| Look | 0 radius, 2px muted border, surface `#1a1a1a`, solid |
| Stack | Gap 4px. Max 3 visible |
| Content | Colorful app icon 24px left. Title in foreground. Body muted, 2 lines max, truncated |
| Timeout | 5 seconds normal. Urgent stays until dismissed |
| Urgent | Red border. Nothing else changes |
| Amber | Not used. A notification is not focus |
| Excluded | Progress bars, sounds |

### Inbox panel

- Panel inside Quickshell. SUPER + I toggles it. No extension, no bridge.
- Look: same as popups. 360px wide, top-right, 4px below the bar, flush with the right edge. Rows scroll when the list is long.
- Row: colorful app icon 24px, title, body muted (2 lines), time muted on the right. Times in 24h.
- Keys: J and K or arrows to move, Enter invokes the default action, X dismisses, Escape closes.
- One notification list in the shell. A dismissed popup stays in the inbox until cleared. Clear all is available.
- Do Not Disturb silences popups. The inbox still collects.
- History persists to a file on disk and survives shell restarts. Cap near 200 entries. Starting value.
- Privacy: notification text is stored in plain text. Add a per-app no-store rule for sensitive apps.
- The bar shows the unread count. Gray at zero, amber when unread.
- Verify: notification server API and action support, keyboard focus on a layer-shell panel, and the file persistence approach.

### Later

- Per-app rules to quiet chat apps. Wanted. Write them with the Mako config.
- Test Arabic text wrapping inside popups.

### OSD and night light

`swayosd` shows volume, brightness, and Caps Lock changes.

- Same look as popups: 0 radius, 2px muted border, surface `#1a1a1a`, solid.
- Level bar: foreground fill on a muted track. Amber stays off.
- Position: bottom center, on the focused monitor (verify).
- Brightness keys work on the laptop panel. External monitors may need DDC tooling. Verify.
- Verify the server setup and the Caps Lock indicator on the installed version.

`hyprsunset` handles night light.

- Evening to morning schedule. Pick temperature and times when writing the config.
- A warm filter shifts every color, amber and grays included. Check the palette under it before finalizing.
- Verify the config format on the installed version.

## Lock screen and idle

`hyprlock` for the lock screen, `hypridle` for timing. Solid `#111111`, centered clock, password field on every screen.

### Layout

- Clock: large, foreground, HH:MM.
- Date: small, muted, 8px under the clock.
- Password field: 320px by 48px, 24px below the date. 0 radius, 2px border.
- Layout label under the field. Shows Arabic or English, so a wrong-layout password is obvious.
- No avatar. No username. No wallpaper. No blur.

### Field states

| State | Look |
| --- | --- |
| Idle | Muted border, empty |
| Typing | Amber border, dots in foreground |
| Wrong | Red border, short message. No shake |
| Caps Lock on | Small red label under the field |

### Privacy

- No notification content, no media info.
- Battery indicator on the laptop only. Small, muted.

### Idle chain

Starting values. Tune later.

1. 5 minutes: lock.
2. 6 minutes: screens off.
3. 30 minutes: suspend, on battery only.
4. Lock before any sleep. Lid close included.

Lid close with externals attached must not suspend. Write that rule explicitly.

### Safety

- Test the lock screen with a second TTY or SSH session open. A broken `hyprlock` config can lock you out.
- If the laptop panel is OLED, dim to near-black and turn screens off quickly.
- Verify how `hyprlock` shares typed input across several outputs.

## Wallpaper and terminal

### Wallpaper

Solid `#111111`. Same as the lock screen. Zero outer gaps and tiling hide it anyway.

- `swaybg` handles solid colors. `hyprpaper` is the Hyprland-native option, but solid-color support is unverified.
- No pattern, no image. Solid color is final.

### Terminal

Alacritty. tmux handles splits and sessions, so the terminal needs no tabs.

| Part | Spec |
| --- | --- |
| Background | `#111111`. No transparency |
| Cursor | Block, amber |
| Padding | 8px. No window decorations |
| Selection | Surface shade. Not amber |
| Font | JetBrains Mono. Size matched to the bar |
| Config | TOML. Palette in one shared file, imported (verify the import key) |

### ANSI palette

- Muted, desaturated red, green, blue, magenta, cyan.
- Amber takes the yellow slot. Check it against compiler warnings.
- Bright variants about 10% lighter. Not neon.
- Text contrast at least 4.5 to 1 on `#111111`.
- Neovim colors come from the same palette file. No separate scheme.

Arabic in terminals has no right-to-left shaping in most emulators. Test before relying on it.

## Screenshots, recording, clipboard

Capture goes straight to file and clipboard. Annotation is a separate key.

### Screenshots

- Capture: `hyprshot`. Annotate: `satty`.
- Modes: region, window, focused monitor. Never all three screens at once.
- Every capture is saved to a screenshots folder, copied to the clipboard, and confirmed by a Mako popup.
- No editor step by default. Annotate the last shot on its own key.
- Satty styling: shared palette, sharp corners, amber default color, arrow and rectangle tools only.
- Test region capture across mixed-scale monitors early.

### Recording

- Two tools. OBS for real content and streaming. `gpu-screen-recorder` for quick capture.
- Record toggle: SUPER + R. Saves to a recordings folder. A Mako popup confirms.
- No replay buffer. Nothing records until you toggle it.
- Waybar: red glyph while recording.
- Audio: desktop sound and mic, both optional. Verify PipeWire capture support.
- Verify: package name, three-monitor capture, focused-monitor mode, and Wayland capture permissions on the installed version.

### Clipboard

`wl-clipboard` underneath. History through Vicinae. No `cliphist`.

## Input, keybinds, workspaces

SUPER is the only desktop modifier. No Alt binds. tmux keeps `Ctrl+Space`, so nothing collides.

### Input

- Caps Lock: tap for Escape, hold for Ctrl. Needs a key remapper below Hyprland. `keyd` is the pick: one overload line. `kanata` is the heavier alternative.
- `keyd` runs as a root service and reads all keyboard input. Tune the tap timing. Apply to laptop and external keyboards.
- Layout toggle: SUPER + Space, an XKB option (probably `grp:win_space_toggle`, verify).
- Letter and symbol binds use keycodes (`code:NN`, found with `wev`) so Arabic layout never breaks them. Arrows work in any layout. Verify the syntax in the binds wiki.

### Keybinds

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

Notes:

- Both arrow and HJKL sets are bound. Drop the unused set after two weeks.
- Laptop up and down arrows are often half-height. Test them.
- Fullscreen hides the bar on that screen only.
- Verify the fullscreen and maximize dispatcher syntax on the current Hyprland.

### Workspaces

Per-monitor. Every screen has its own 1 to 5. SUPER + 1 to 5 acts on the focused screen.

- Plugin: `hyprsplit`, installed through `hyprpm`. Verify support for the installed Hyprland version.
- Fixes the laptop-alone case: it is simply 1 to 5.
- Risk: plugins can break on Hyprland updates. Pin versions. Run `hyprpm update` after each upgrade. Keep a native fallback.
- Risk: the Waybar workspace module may show offset IDs, not 1 to 5. Test early.
- Verify what happens to windows when a monitor disconnects.
- Test lid close on real hardware.

## Stack and build order

Packages are installed with `yay` on Arch. Names are the likely ones. Check each in the repos or AUR before installing.

| Layer | Choice |
| --- | --- |
| Compositor | `hyprland`, launched through `uwsm` |
| Portals | `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk` |
| Audio | `pipewire`, `pipewire-pulse`, `wireplumber` |
| Network, auth | `networkmanager`, `polkit-gnome` |
| Qt on Wayland | `qt5-wayland`, `qt6-wayland` |
| Bar | `quickshell` (bars written in QML) |
| Launcher | `vicinae-bin` (AUR) |
| Notifications | `quickshell` (notification server, popups, and inbox panel) |
| OSD | `quickshell` |
| Lock, idle | `quickshell` (lock screen), `hypridle` (timing). `hyprlock` stays installed as an emergency fallback |
| Night light | hyprsunset |
| Wallpaper | `swaybg` |
| Terminal | `alacritty`, with `tmux` and `fish` as before |
| Screenshots | `hyprshot`, `satty` |
| Recording | OBS for content. gpu-screen-recorder for quick capture |
| Clipboard | `wl-clipboard`, history in Vicinae |
| Key remap | `keyd` |
| Workspaces | `hyprsplit` through `hyprpm` |
| Fonts | JetBrains Mono Nerd Font, Vazirmatn, Phosphor icon font |

### Build order

1. Core packages: compositor, portals, audio, network, polkit, Qt.
2. Boot a Hyprland session. Run `hyprctl monitors` to get real output names.
3. Monitor layout and the three-state test.
4. One shared palette: Quickshell theme singleton, plus a generated terminal palette.
5. Alacritty, Vicinae, screenshots, recording.
6. Quickshell: scaffold, theme singleton, bars. Full on main, slim elsewhere.
7. Input: `keyd`, keybinds, layout toggle, `hyprsplit` workspaces.
8. Quickshell notifications: popups and inbox panel. Mako stands in until then.
9. Quickshell OSD. `swayosd` stands in until then.
10. Quickshell lock screen. Build last, with a second TTY open. `hyprlock` stands in until then.
11. `hypridle` and `hyprsunset`.
12. Hotplug tests: laptop alone, lid closed.
13. Clone Omarchy for reference and borrow scripts where useful.

### Safety rules, real machine

No VM. Everything is built on the real laptop and monitors. These rules keep it recoverable.

- Keep the current desktop installed and selectable at login. No autologin into Hyprland until stable.
- Configs live in `~/dotfiles`, symlinked into place. Commit after each working step.
- Before starting, record installed packages: `pacman -Qqe > pkglist-before.txt`.
- If root is btrfs, take a snapshot first. Verify.
- The monitor config always keeps a catch-all fallback line, so no screen goes black.
- Never edit existing files in `/etc/pam.d`. The lock screen gets its own new PAM file.
- `keyd`: install late. Know the stop command from a TTY: `sudo systemctl stop keyd`.
- Lock screen: a second TTY logged in before every test. Short timeout. Save work first. `hyprlock` stays until the Quickshell lock is proven.
- Plugins such as `hyprsplit`: pin versions. Run `hyprpm update` after each Hyprland upgrade.
- One change per step. Check syntax against current docs before writing it.
- Save work often. A compositor crash ends the session.

## Open items and verify list

Nothing here blocks the design. Each item needs a decision or a check before configs are written.

### Decisions

- [x] Arabic fallback font: Vazirmatn.
- [x] OSD: `swayosd`.
- [x] Night light: `hyprsunset`.
- [x] Icon theme: Papirus-Dark.
- [x] File search: Vicinae's built-in file search.
- [x] Per-app notification rules: yes.
- [x] Recording: OBS for content. gpu-screen-recorder for quick capture. No replay.
- [x] Wallpaper pattern: no.

hyprsunset

### Verify before writing configs

Names and syntax shift between releases. Check each against current docs.

- [ ] Quickshell: package source, per-screen bars over the screen list, hotplug behavior, workspace IDs under hyprsplit.
- [ ] Hyprland: per-side gaps for a 4px top gap and 0 elsewhere.
- [ ] Hyprland: fullscreen and maximize dispatcher syntax.
- [ ] Binds by keycode, and `wev` output on both keyboards.
- [ ] `hyprsplit` support for the installed Hyprland version.
- [ ] Vicinae: toggle flags, focused-monitor behavior, theming keys.
- [ ] Mako: D-Bus method names, `output` option, `max-history`.
- [ ] `hyprlock`: multi-output behavior. `hypridle`: lid rules with externals attached.
- [ ] Hotplug tool: `kanshi` or `hyprdynamicmonitors`.
- [ ] Phosphor font packaging on Arch.
- [ ] `swaybg` or `hyprpaper` for a solid color.
- [ ] Alacritty config import key.
- [ ] `keyd` package name and overload syntax.

### Hardware tests

- [ ] Glyph sizes on all three screens. The laptop panel scales differently.
- [ ] Panel type of the laptop screen. OLED changes lock and idle choices.
- [ ] Arabic window titles in the bar, popups, launcher, and lock field.

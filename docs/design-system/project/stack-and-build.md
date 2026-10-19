# Stack and build

Packages install with `yay` on Arch. Names are the likely ones: check each in the repos or AUR first.

| Layer | Choice |
| --- | --- |
| Compositor | `hyprland`, launched through `uwsm` |
| Portals | `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk` |
| Audio | `pipewire`, `pipewire-pulse`, `wireplumber` |
| Network, auth | `networkmanager`, `polkit-gnome` |
| Qt on Wayland | `qt5-wayland`, `qt6-wayland` |
| Bar | `waybar` |
| Launcher | `vicinae-bin` (AUR) |
| Notifications | `mako`, plus the Vicinae inbox extension |
| OSD | `swayosd` |
| Lock, idle | `hyprlock`, `hypridle` |
| Night light | `hyprsunset` |
| Wallpaper | `swaybg` |
| Terminal | `alacritty`, with `tmux` and `fish` |
| Screenshots | `hyprshot`, `satty` |
| Recording | OBS, `gpu-screen-recorder` |
| Clipboard | `wl-clipboard`, history in Vicinae |
| Key remap | `keyd` |
| Workspaces | `hyprsplit` through `hyprpm` |
| Fonts | JetBrains Mono Nerd Font, Vazirmatn, Phosphor icon font |

## Build order

1. Core packages: compositor, portals, audio, network, polkit, Qt.
2. Boot a Hyprland session. Run `hyprctl monitors` for real output names.
3. Monitor layout and the three-state test.
4. One shared palette file, generated from `tokens.json`.
5. Waybar: full bar on main, slim bars elsewhere.
6. Mako, Vicinae, inbox extension.
7. `hyprlock` and `hypridle`, with a spare TTY open.
8. Alacritty, screenshots, recording.
9. `keyd`, keybinds, layout toggle.
10. `hyprsplit` workspaces.
11. Hotplug profiles. Test laptop alone and lid closed.
12. Clone `github.com/basecamp/omarchy` for reference and borrow scripts where useful.

## Verify before writing configs

- [ ] Waybar: per-output bars through a config array, and how to target a bar from CSS.
- [ ] Hyprland: per-side gaps for a 4px top gap and 0 elsewhere; fullscreen and maximize dispatcher syntax.
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

## Hardware tests

- [ ] Glyph sizes on all three screens. The laptop panel scales differently.
- [ ] Panel type of the laptop screen. OLED changes lock and idle choices.
- [ ] Arabic window titles in the bar, popups, launcher, and lock field.

# Handoff: from the test VM to the real laptop

Read this together with `CLAUDE.md` (the owner's rules) and `spec/` before doing anything.
`CLAUDE.md` still applies in full: one change per step, verify names and syntax against current
docs, tell the owner exactly what to check, wait for "works", commit after each working step,
show every `sudo` command before it runs.

This repo was built and tested on an Arch VM (2026-10-14): one screen `Virtual-1` 1280x800,
no GPU acceleration, Hyprland 0.56.2, Quickshell 0.3.2. Everything below marked **done** was
tested there by the owner. Everything marked **real machine** could not be tested on the VM.

## 1. What this repo is

| Path | What |
| --- | --- |
| `hypr/hyprland.lua` | Hyprland config (0.56 uses **Lua**, not hyprland.conf) |
| `hypr/hyprsplit/` | git submodule, hyprsplit **Lua library** pinned at 6b00b67 |
| `hypr/hypridle.conf`, `hyprlock.conf`, `hyprsunset.conf` | idle chain, fallback locker, night light |
| `hypr/hypr_palette.lua` | generated colors for the Hyprland config |
| `quickshell/` | bar, island, notification server and inbox |
| `quickshell-lock/` | the lock screen, a separate Quickshell instance |
| `pam/quickshell-lock` | the lock's PAM service (loaded from here, `/etc/pam.d` untouched) |
| `palette/palette.toml` | **the one palette**; `palette/generate.py` writes every app's colors |
| `alacritty/ nvim/ tmux/ vicinae/ satty/ gtk-3.0/ gtk-4.0/` | app configs (colors generated) |
| `keyd/default.conf` | Caps Lock: tap Escape, hold Ctrl |
| `bin/island-build` | build hook: `island-build cargo build` reports to the island |
| `packages/` | what to install (`repo.txt`, `aur.txt`), VM versions, later packages |
| `setup/link-dotfiles.sh` | creates every symlink, backs up anything in the way |
| `setup/check.sh` | read-only health check (57 checks pass on the VM) |
| `spec/`, `design-system/` | the owner's specs (copied from hyprland-kit) |
| `pkglist-before.txt` | the **VM's** baseline package list, not the laptop's |

After editing `palette/palette.toml`, run `python3 palette/generate.py` and commit the outputs.
Never edit generated files by hand (they say so in their first line).

## 2. Decisions that differ from the spec (all agreed with the owner)

- Hyprland config is Lua (`hl.config`, `hl.bind`, `hl.dsp.*`). `hyprctl dispatch` takes Lua:
  `hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`.
- hyprsplit: the C++ plugin is deprecated and its hyprpm pins stop at Hyprland 0.54.3. Use the
  Lua library (submodule). Native fallback: swap `hs.dsp.*` back to `hl.dsp.*`, drop the require.
  No `hyprpm` at all.
- Wallpaper: Hyprland paints solid `bg` itself (`misc.background_color`). No swaybg.
- Lock screen: Quickshell `WlSessionLock` + `PamContext` in its own instance, run by SUPER+Escape
  through `flock`. PAM file lives in `pam/` and includes `/etc/pam.d/system-auth` by **absolute**
  path (a relative include fails: PAM looks inside the custom dir). hyprlock stays installed as
  the fallback with a minimal config. Test-mode failsafe is off (`failsafeSeconds: 0`).
- Volume OSD and notification popups were replaced by the island. The inbox (SUPER+I), bell,
  history and the no-store rule remain.
- Logout: SUPER+Shift+Escape. Kept non-spec extras: media/brightness keys, SUPER+mouse
  drag/resize, SUPER+scroll workspaces.
- Caps Lock OSD dropped (keyd removes the Caps Lock state). Do Not Disturb: click the bell.
- Clock: numeric `yyyy-MM-dd  HH:mm`, always shown, in the bar's right group between the tray
  and the status icons (the bar centre belongs to the island).
- Vicinae: telemetry off, input server off (paste falls back to copy). Settings live in
  `vicinae/hypr.jsonc`; `settings.json` only imports it because the Vicinae GUI rewrites it.
- Notification privacy: messaging apps and password managers are never written to disk
  (`noStoreApps` in `quickshell/Notifs.qml`). History: `~/.local/state/quickshell/by-shell/*/notifications.json`, cap 200.
- GTK: `adw-gtk3-dark` + generated `gtk.css` for GTK3 and GTK4 (palette, radius 0, no shadows).
  Warnings use `fg`, never amber.
- SUPER+V floats a window at 60% x 70% of its monitor, centred.
- Island next-event state dropped (owner won't use it). Omarchy reference clone dropped.

Island design canvas (source of truth for island layout): https://claude.ai/artifact/AqnmRsK6WT21D6CvnAF4Xt
("Hyprland Island"). Its interactive "Desktop test" artboard wins where it differs from the
static artboards or the spec text. Timers: notification 8 s, volume 2.5 s, battery 3 s,
build 6 s. Transient arriving while one is open: queue one. Paused media hides after 30 s.

## 3. Keybinds (letters and symbols by XKB keycode, so Arabic never breaks them)

| Keys | Action | Keycode |
| --- | --- | --- |
| SUPER+Return | Alacritty | |
| SUPER+/ | Vicinae | 61 |
| SUPER+I | notification inbox (`qs ipc call inbox toggle`) | 31 |
| SUPER+Space | layout toggle (XKB `grp:win_space_toggle`, `us,ara`) | |
| SUPER+Q | close window | 24 |
| SUPER+V | float toggle (sized, centred) | 55 |
| SUPER+N / SUPER+M | fullscreen / maximize | 57 / 58 |
| SUPER(+Shift)+H J K L or arrows | focus (move window) | 43 44 45 46 |
| SUPER+Ctrl+arrows | resize 40px, repeats | |
| SUPER(+Shift)+1-5 | workspace (send window), via hyprsplit | 10-14 |
| SUPER+Escape | lock | |
| SUPER+Shift+Escape | log out | |
| Print / SUPER+Print / SUPER+Shift+Print | region / window / monitor shot | |
| SUPER+Ctrl+Print | annotate newest shot in satty | |

Keycodes come from `/usr/share/X11/xkb/keycodes/evdev`. The spec asks to confirm them with
`wev` on **both** laptop and external keyboards.

## 4. Procedure on the laptop, in order

Follow `CLAUDE.md` safety rules. Before each step: tell the owner what changes and what to check.

1. **Safety first.**
   - `pacman -Qqe > ~/pkglist-laptop-before.txt` (do not overwrite the VM's `pkglist-before.txt`).
   - If root is btrfs, take a snapshot; verify the tool in use (snapper/timeshift/btrfs).
   - Keep the current desktop installed and selectable at login. No autologin into Hyprland.
   - Have a second TTY or SSH session for every risky step.
2. **Put the repo at `~/dotfiles`** (exactly there; the lock's PAM path and the island-build
   link expect it). If the zip was used, the submodule is included; otherwise
   `git clone --recursive`, or `git submodule update --init`.
3. **Packages.** Show the owner, then they run:
   - `grep -v -e "^#" -e "^$" packages/repo.txt | sudo pacman -S --needed -`
   - yay bootstrap (AUR-only, not in the repos):
     `git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin && cd /tmp/yay-bin && makepkg -si`
   - `yay -S --needed vicinae-bin ttf-phosphor-icons vazirmatn-fonts`
   - Review PKGBUILDs first. Known: `vicinae-bin` runs `setcap cap_dac_override` on its input
     server and loads `uinput` (we disable the input server in config). `gpu-screen-recorder`
     runs `setcap cap_sys_admin` on `gsr-kms-server`. Vicinae pulls `qtkeychain-qt6`, which needs
     a secrets provider: choose **gnome-keyring**.
4. **Links.** `setup/link-dotfiles.sh`. It backs up existing configs (the laptop may already have
   nvim, tmux, alacritty, fish configs). Tell the owner which folders were backed up; their own
   nvim/tmux settings may need merging into ours.
5. **keyd (sudo):**
   `sudo mkdir -p /etc/keyd && sudo ln -s /home/<user>/dotfiles/keyd/default.conf /etc/keyd/default.conf`,
   then `keyd check ~/dotfiles/keyd/default.conf`, then `sudo systemctl start keyd`; enable only
   after it is proven. Stop from a TTY: `sudo systemctl stop keyd`.
6. **Monitors (`hypr/hyprland.lua`, MONITORS).** Replace the `Virtual-1` rule with the real outputs
   from `hyprctl monitors`: main external centre, right external, laptop left (spec table).
   **Keep the catch-all `output = ""` rule.**
7. **Main screen for the island.** `quickshell/Island.qml` uses `Quickshell.screens[0]` as the main
   screen. Pin it to the main external by name, with laptop-alone as main.
8. **hyprsplit priority.** Decide `hs.monitor_priority({...})` so each screen's 1-5 map
   predictably. Then fix `quickshell/Workspaces.qml`: it matches `ws.id` 1-5 directly; on a second
   monitor hyprsplit IDs are 6-10, so map `id -> ((id - 1) % 5) + 1` per monitor.
9. **Log in to Hyprland** (through uwsm, from the display manager or TTY), then run
   `setup/check.sh`. All checks should pass.
10. **Re-run the VM tests quickly** (section 5) on the real hardware.
11. **Then the real-machine list** (section 6), one item per step.

## 5. Quick re-test list (passed on the VM)

- Bar: workspaces (amber active, gray occupied, dim empty), title, tray, clock, volume, network
  (red slash when down), bell (amber count; click = Do Not Disturb).
- `notify-send hi` -> island card; SUPER+I inbox (J/K, Enter, X, Clear all); history survives logout.
- Volume keys -> island volume; click to expand.
- `island-build sh -c 'echo "error: x"; exit 1'` -> red build pill that stays.
- `qs ipc call island test volume|build|buildfail|notify|media|record`, `expand`, `collapse`,
  `state`, `clear` (test hook).
- Lock: SUPER+Escape, unlock. Wrong password at most once (pam_faillock: 3 failures = 10 min lockout).
- Screenshots (Print variants) and SUPER+Ctrl+Print annotate.
- SUPER+V float sizing, SUPER+N/M, SUPER+Space Arabic (all SUPER binds must still work in Arabic).

## 6. Real machine: still to build or test

Build:
- Recording: SUPER+R toggle with gpu-screen-recorder (could not run on the VM: no GPU OpenGL).
  `-w focused` is NOT the focused monitor (it needs `-s WxH`); find the right mode.
  Bar red glyph while recording, island recording state (240x24 / 340x172, red border).
- OBS for real content (spec).
- Brightness: OSD now lives in the island volume panel (Brightness row, `hasBrightness` in
  `IslandState.qml`); brightness keys are already bound to `brightnessctl`. Externals may need DDC.
- Bar items: Bluetooth, battery (laptop only), media (only while playing), mic/camera indicator
  (red, only when live). Slim bars on non-main screens (spec table).
- Island: media (MPRIS; compact 280x24, expanded 440x256 per the design), recording, battery
  (critical stays, red border).
- New island events the owner asked for: Wi-Fi connected, Bluetooth device connected. Not in the
  spec or design yet: settle layout (likely compact like battery 260x24), timer, glyphs, and
  whether disconnects show, before building.
- SUPER+Shift+comma/period: window to previous/next monitor.
- Optional fish wrapper for island-build (e.g. `function b; island-build $argv; end`), and make
  sure `~/.local/bin` is on fish's PATH (`fish_add_path ~/.local/bin`).

Test (configured, untested on the VM):
- hypridle: 5 min lock (this fired correctly once on the VM), 6 min screens off/on, 30 min
  suspend on battery only, lock before sleep and lid close. Lid close with externals attached
  must not suspend: logind `HandleLidSwitchDocked` (check its value; do not edit other logind
  settings without asking).
- hyprsunset (21:00-06:30, 4500K): the VM GPU had no CTM. Preview with
  `hyprctl hyprsunset temperature 4500`, judge amber vs grays by eye (screenshots don't show it),
  then `hyprctl hyprsunset reset`.
- Lock screen on three monitors: typed input shared across surfaces.
- Island and bar on multiple screens; hotplug (three screens, two, laptop alone, lid closed);
  `hs.dsp.grab_rogue_windows()` after unplugging.
- Glyph sizes on all screens (laptop scale), laptop panel type (OLED changes idle choices),
  Arabic titles in bar, island, launcher, lock field.

## 7. Recovery

- Lock screen dies -> Hyprland shows "lockscreen died" (session stays locked). From SSH/TTY:
  `hyprctl dispatch 'hl.dsp.exec_cmd("hyprlock")'` (needs `WAYLAND_DISPLAY` and
  `HYPRLAND_INSTANCE_SIGNATURE`), unlock with hyprlock. Hyprland also offers
  `hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'`. Last resort:
  `loginctl terminate-session <id>` (loses unsaved work, ask first).
  Requires `misc.allow_session_lock_restore = true` (set).
- Before experimenting with `quickshell-lock/shell.qml`, set `failsafeSeconds` above 0.
- keyd breaks the keyboard -> from SSH: `sudo systemctl stop keyd`.
- Hyprland config error -> `hyprctl configerrors`; the config lives in git, `git diff` / revert.

## 8. Gotchas learned on the VM

- Quickshell live-reloads on save. A reload that fails keeps the old config running.
  Several files saved within a second can make the reload miss later edits: append a comment to
  `quickshell/Bar.qml` with `>>`, then remove it. Identical rewrites don't reload.
- New fonts need a real `qs` restart (Qt reads fonts once). So does the `//@ pragma IconTheme`.
- `qs log` without flags shows the newest instance (often a test one). With the lock running
  there are two `qs` processes: use `qs log --pid <bar pid>`.
- `qs ipc call ...` only finds instances on the caller's display: set `WAYLAND_DISPLAY`
  when calling from SSH.
- QML: `transient` is a reserved word; `data` is a built-in Item property. Property names
  starting with `on` + capital are signal handlers (Theme uses `textOnAccent`).
- `Hyprland.activeToplevel` stays null until the first focus change: the bar title uses the
  Wayland `ToplevelManager.activeToplevel`.
- `Quickshell.Networking` loads lazily: devices appear a moment after first access.
- RTL in QML: `LayoutMirroring` flips anchors, not plain `x`. Anchor things to the start edge.
- `hyprsunset` needs a GPU with CTM. `gpu-screen-recorder` refuses llvmpipe.
- The portal reported "no preference" until `color-scheme prefer-dark` was set; Vicinae maps
  both its light and dark themes to `hypr` anyway.
- `~/.local/share/vicinae/themes` is created by Vicinae on first run. If it exists as a real
  folder, `ln -s` puts the link **inside** it. `setup/link-dotfiles.sh` moves it aside first.
- `hyprlock` needs `~/.config/hypr/hyprlock.conf` (no fallback to the packaged example).
- Hyprland's autogenerated-config banner reserves 61px at the top (removed `autogenerated`).
- `hypridle` `inhibit_sleep = 3` waits for any session lock (auto mode looks for hyprlock).
- `pam_faillock` is in `system-auth`: never script repeated wrong-password tests.
- `notify-send --wait -A default=Open` is a good way to test the inbox/island Reply action.

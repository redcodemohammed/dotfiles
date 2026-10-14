# Handoff: from the test VM to the real laptop

Read this together with `CLAUDE.md` (the owner's rules) and `spec/` before doing anything.
`CLAUDE.md` still applies in full: one change per step, verify names and syntax against current
docs, tell the owner exactly what to check, wait for "works", commit after each working step,
show every `sudo` command before it runs.

This repo was built and tested on an Arch VM (2026-10-14): one screen `Virtual-1` 1280x800,
no GPU acceleration, Hyprland 0.56.2, Quickshell 0.3.2. Everything below marked **done** was
tested there by the owner. Everything marked **real machine** could not be tested on the VM.

## Laptop progress (read first, update after each step)

The laptop since 2026-10-14: Arch, **ext4** root (no btrfs snapshot possible), COSMIC desktop with
cosmic-greeter. COSMIC stays installed and is the working desktop. Hyprland is not installed yet.
Already installed: quickshell 0.3.2, yay-bin, JetBrainsMono Nerd Font.

Done (section 4):
- **Step 1.** `~/pkglist-laptop-before.txt` (318 packages). Instead of a snapshot:
  `~/pre-hyprland-2026-10-14.tgz` holds the old `~/dotfiles` (untracked files included) and every
  `~/.config` folder that was later moved or replaced.
- **Step 2.** This repo was merged, with its history, into the owner's existing GNU stow repo at
  `~/dotfiles` (branch `main`, origin `github.com/redcodemohammed/dotfiles`, nothing pushed yet):
  `ca1a1fd` snapshot of local changes, `0a9be36` reshape for stow, `8c83df1` old alacritty, tmux,
  nvim and hypr removed (new ones replace them), `43c1359` merge. The owner's other configs stay.
  The old tmux plugins went with the old tmux config; add any back only if the owner asks.
- **Step 3.** The local package database was a week old, so the repo list went in with a full
  upgrade, one transaction: `grep -v -e '^#' -e '^$' packages/repo.txt | sudo pacman -Syu --needed -`
  (single quotes: fish rejects `"^$"`), then `yay -S --needed ttf-phosphor-icons vazirmatn-fonts`.
  `vicinae-bin` (AUR, 2026-10-02) and `gnome-keyring` were already installed. `vazirmatn-fonts`
  comes prebuilt from the laptop's chaotic-aur repo. `gsr-kms-server` has `cap_sys_admin`. keyd is
  installed, not started. Rebooted, COSMIC fine, greeter lists Hyprland and Hyprland (uwsm-managed).
- **Step 4.** `stow -R .` done; `setup/check.sh` links all pass except `/etc/keyd` (step 5).
  Real folders that were in the way are in `~/.config/<name>.pre-dotfiles-20261014-220228`:
  hypr, cava, kitty, rofi, waybar (leftover KooL Hyprland dots; the owner's own repo versions are
  linked now), quickshell (an old shell config) and vicinae (the owner's old settings).
- **Step 5 prep.** Removed `xremap-cosmic-bin`, its user unit and `~/.config/xremap`. It grabbed
  every keyboard and the mouse only to make SUPER+scroll switch COSMIC workspaces; next to keyd,
  two grabbing remappers would chain in startup order. SUPER+scroll in COSMIC is gone (Hyprland
  binds it natively). The owner left the `input` group and deleted `/etc/udev/rules.d/99-input.rules`
  (both only for xremap). Verified after the reboot: no `input` group, `/dev/uinput` is
  `root:uinput`. The per-user ACL left on it comes from Steam's `60-steam-input.rules` (uaccess,
  can create virtual devices, cannot read keys). `60-weylus.rules` stays.
- **Step 5 skipped** (owner's choice). keyd is installed but not configured, started or enabled:
  Caps Lock stays a normal key. `keyd/default.conf` stays in the repo for later; the keyd checks
  were removed from `setup/check.sh`. If keyd comes back, copy the config
  (`sudo install -Dm644 ...`) rather than link it: keyd runs `command()` actions as root.
- **Step 6.** Monitor rules in `hyprland.lua` copied from the COSMIC layout: `eDP-1` 2560x1600@165.04
  scale 1.6 at 0x201 (1.5 is not a clean divisor), `desc:Samsung Electric Company Odyssey G5`
  2560x1440@144 at 1600x0 (main, HDMI-A-1 now), `desc:Samsung Electric Company LF24T35`
  1920x1080@74.97 at 4160x161 (right, DP-2 now). Catch-all kept. `--verify-config` ok; the desc
  strings come from COSMIC's EDID read: confirm with `hyprctl monitors` at step 9.
- **Step 7.** `Island.qml` picks the main screen by model: `Odyssey G5`, else `eDP-1`, else the
  first screen (laptop + LF24T35 without the G5: laptop). Qt lists DP-2 first, so `screens[0]` was
  wrong. Tested in COSMIC with a short `qs -p` instance: the island shows on the G5 only.
- **Step 8.** `hs.monitor_priority({ "HDMI-A-1", "eDP-1", "DP-2" })`: IDs main 1-5, laptop 6-10,
  right 11-15 (hyprsplit matches name or description **exactly**, unlike `hl.monitor`'s `desc:`
  prefix; port names chosen by the owner). `Workspaces.qml` shows each monitor's own workspaces
  as slots 1-5 (`((id - 1) % 5) + 1`). Untested until step 9: `hyprctl workspaces`, SUPER+1-5 per screen.
- **Before step 9 (cross-desktop check).** uwsm runs XDG autostart and `graphical-session.target`
  services in Hyprland too. Vicinae: `hyprland.lua` no longer runs `vicinae server`; the owner's
  `vicinae.service` (`--replace`, `PartOf=graphical-session.target`) starts it in both desktops.
  `~/.config/autostart` (not in the repo): `NotShowIn=Hyprland;` added to greenclip (second
  clipboard history next to Vicinae), localsend_app and xpad (not installed, dead entry); FDM starts
  in both. Checked with the systemd xdg-autostart generator: skipped in Hyprland, still started in
  COSMIC. Kept on purpose: `hyprland.lua` sets gsettings `icon-theme Papirus-Dark`; gsettings are
  per user, so COSMIC's GTK apps (had `Colloid-Pink-Catppuccin-Dark`) see it too.
- **Step 9.** First login through "Hyprland (uwsm-managed)", about a minute; the owner checked
  screens and bars by eye: works. From its log: no config errors; descriptions are
  `Samsung Electric Company Odyssey G5 HNAY600194 (HDMI-A-1)`,
  `Samsung Electric Company LF24T35 HK2TC00515 (DP-2)`, `AU Optronics 0xC1A5 0x0000C1A5 (eDP-1)`,
  so the `desc:` prefixes match; hyprsplit took the priority list. Inside Hyprland:
  `setup/check.sh` 52 ok, no FAIL; `hyprctl configerrors` empty; `hyprctl monitors` matches the
  step 6 rules (modes, scale 1.6, positions); workspaces 1 on HDMI-A-1, 6 on eDP-1, 11 on DP-2;
  every bar shows slot 1 amber and 2-5 dim (`#5c5c5c`, measured); test island opens on the G5.
- **Step 10 (section 5 re-tests).** Bar: works (per-screen workspaces, e.g. SUPER+3 on the laptop
  is ID 8; title, tray, clock, volume, network).

Notes:
- GTK is not stowed on purpose (see `.stow-local-ignore` and section 6).
- Vicinae runs as a systemd user service in both desktops: `systemctl --user restart vicinae`
  after a config change. Its window is 640 wide (section 2).
- Keep the tarball, the `.pre-dotfiles-*` folders and `~/Projects/hyprland-handoff` until
  Hyprland is stable.
- Claude Code may run as a background daemon started in COSMIC; `claude attach` from Hyprland
  reuses it, so its tools see COSMIC's environment (no `HYPRLAND_INSTANCE_SIGNATURE`). Copy
  `HYPRLAND_INSTANCE_SIGNATURE`, `WAYLAND_DISPLAY`, `XDG_CURRENT_DESKTOP` from the attached
  process's `/proc/<pid>/environ` before `hyprctl`, `qs ipc` or `grim`.
- The LocalSend autostart unit fails at every login since before this project (`localsend-bin`
  misses `libayatana-indicator3.so.7`). Not ours.

**Next: step 10** (section 5 re-tests, one item at a time): notifications next.

## 1. What this repo is

| Path | What |
| --- | --- |
| `.config/hypr/hyprland.lua` | Hyprland config (0.56 uses **Lua**, not hyprland.conf) |
| `.config/hypr/hyprsplit/` | git submodule, hyprsplit **Lua library** pinned at 6b00b67 |
| `.config/hypr/hypridle.conf`, `hyprlock.conf`, `hyprsunset.conf` | idle chain, fallback locker, night light |
| `.config/hypr/hypr_palette.lua` | generated colors for the Hyprland config |
| `.config/quickshell/` | bar, island, notification server and inbox |
| `.config/quickshell-lock/` | the lock screen, a separate Quickshell instance |
| `pam/quickshell-lock` | the lock's PAM service (loaded from here, `/etc/pam.d` untouched) |
| `palette/palette.toml` | **the one palette**; `palette/generate.py` writes every app's colors |
| `.config/{alacritty,nvim,tmux,vicinae,satty,gtk-3.0,gtk-4.0}/` | app configs (colors generated) |
| `.local/share/vicinae/themes/hypr.toml` | Vicinae theme (generated) |
| `keyd/default.conf` | Caps Lock: tap Escape, hold Ctrl |
| `.local/bin/island-build` | build hook: `island-build cargo build` reports to the island |
| `packages/` | what to install (`repo.txt`, `aur.txt`), VM versions, later packages |
| `.stow-local-ignore` | what stow must not link: the project folders, and GTK while COSMIC owns it |
| `setup/check.sh` | read-only health check (57 checks pass on the VM) |
| `spec/`, `design-system/` | the owner's specs (copied from hyprland-kit) |
| `pkglist-before.txt` | the **VM's** baseline package list, not the laptop's |

The repo is a GNU stow package (merged into the owner's existing stow dotfiles on 2026-10-14;
their other configs, such as fish, atuin and cava, live alongside). Everything under `.config/` and
`.local/` mirrors `$HOME`; the project folders at the root are never linked. Link with
`cd ~/dotfiles && stow -n -v -R .` (dry run), then `stow -v -R .`.

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
  `.config/vicinae/hypr.jsonc`; `settings.json` only imports it because the Vicinae GUI rewrites it.
  Window 640x416, not the spec's 560 wide: the owner asked for a bit bigger on the laptop (2026-10-14).
- Notification privacy: messaging apps and password managers are never written to disk
  (`noStoreApps` in `.config/quickshell/Notifs.qml`). History: `~/.local/state/quickshell/by-shell/*/notifications.json`, cap 200.
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
2. **The repo is `~/dotfiles`** (exactly there; the lock's PAM path and the keyd link expect it).
   On the laptop it was merged into the owner's stow repo. After a fresh clone:
   `git submodule update --init`.
3. **Packages.** Show the owner, then they run:
   - `grep -v -e "^#" -e "^$" packages/repo.txt | sudo pacman -S --needed -`
   - yay bootstrap (AUR-only, not in the repos):
     `git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin && cd /tmp/yay-bin && makepkg -si`
   - `yay -S --needed vicinae-bin ttf-phosphor-icons vazirmatn-fonts`
   - Review PKGBUILDs first. Known: `vicinae-bin` runs `setcap cap_dac_override` on its input
     server and loads `uinput` (we disable the input server in config). `gpu-screen-recorder`
     runs `setcap cap_sys_admin` on `gsr-kms-server`. Vicinae pulls `qtkeychain-qt6`, which needs
     a secrets provider: choose **gnome-keyring**.
4. **Links.** `cd ~/dotfiles && stow -n -v -R .` first (dry run). Stow refuses to replace real
   files: move each conflict aside to `<path>.pre-dotfiles-<date>`, then `stow -v -R .`. Never
   `--adopt` over our configs (it moves the existing file into the repo, replacing ours).
5. **keyd (sudo):**
   `sudo mkdir -p /etc/keyd && sudo ln -s /home/<user>/dotfiles/keyd/default.conf /etc/keyd/default.conf`,
   then `keyd check ~/dotfiles/keyd/default.conf`, then `sudo systemctl start keyd`; enable only
   after it is proven. Stop from a TTY: `sudo systemctl stop keyd`.
6. **Monitors (`.config/hypr/hyprland.lua`, MONITORS).** Replace the `Virtual-1` rule with the real outputs
   from `hyprctl monitors`: main external centre, right external, laptop left (spec table).
   **Keep the catch-all `output = ""` rule.**
7. **Main screen for the island.** `.config/quickshell/Island.qml` uses `Quickshell.screens[0]` as the main
   screen. Pin it to the main external by name, with laptop-alone as main.
8. **hyprsplit priority.** Decide `hs.monitor_priority({...})` so each screen's 1-5 map
   predictably. Then fix `.config/quickshell/Workspaces.qml`: it matches `ws.id` 1-5 directly; on a second
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
- GTK under Hyprland: COSMIC owns `~/.config/gtk-{3,4}.0/gtk.css` (links to its `cosmic/dark.css`,
  rewritten at login), so our GTK folders are in `.stow-local-ignore`. When Hyprland is the daily
  desktop: turn off COSMIC's GTK theming, delete the two gtk lines there, move the real folders
  aside, `stow -R .`.
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
- Before experimenting with `.config/quickshell-lock/shell.qml`, set `failsafeSeconds` above 0.
- keyd breaks the keyboard -> from SSH: `sudo systemctl stop keyd`.
- Hyprland config error -> `hyprctl configerrors`; the config lives in git, `git diff` / revert.

## 8. Gotchas learned on the VM

- Quickshell live-reloads on save. A reload that fails keeps the old config running.
  Several files saved within a second can make the reload miss later edits: append a comment to
  `.config/quickshell/Bar.qml` with `>>`, then remove it. Identical rewrites don't reload.
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
  folder, `ln -s` puts the link **inside** it. Stow handles this: it links only `hypr.toml` inside
  the real folder.
- `hyprlock` needs `~/.config/hypr/hyprlock.conf` (no fallback to the packaged example).
- Hyprland's autogenerated-config banner reserves 61px at the top (removed `autogenerated`).
- `hypridle` `inhibit_sleep = 3` waits for any session lock (auto mode looks for hyprlock).
- `pam_faillock` is in `system-auth`: never script repeated wrong-password tests.
- `notify-send --wait -A default=Open` is a good way to test the inbox/island Reply action.

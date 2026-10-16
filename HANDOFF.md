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
- **Step 6.** Monitor rules in `hyprland.lua` copied from the COSMIC layout. Since 2026-10-15 the
  laptop runs at scale 4/3 (1920x1200 logical; owner: 1.6 was big, 1 far too small), so `eDP-1` is
  at 0x101 (same middle height), the G5 at 1920x0, the LF24T35 at 4480x161. Originally: `eDP-1` 2560x1600@165.04
  scale 1.6 at 0x201 (1.5 is not a clean divisor), `desc:Samsung Electric Company Odyssey G5`
  2560x1440@144 at 1600x0 (main, HDMI-A-1 now), `desc:Samsung Electric Company LF24T35`
  1920x1080@74.97 at 4160x161 (right, DP-2 now). Catch-all kept. `--verify-config` ok; the desc
  strings come from COSMIC's EDID read: confirm with `hyprctl monitors` at step 9.
- **Step 7.** `Island.qml` picks the main screen by model: `Odyssey G5`, else `eDP-1`, else the
  first screen (laptop + LF24T35 without the G5: laptop). Qt lists DP-2 first, so `screens[0]` was
  wrong. Tested in COSMIC with a short `qs -p` instance: the island shows on the G5 only.
  Superseded 2026-10-15: the island follows the focused screen (owner).
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
  is ID 8; title, tray, clock, volume, network). Notifications: works (island card, urgent red
  border, inbox keys and Clear all, `--wait -A default` action, bell DND); `qs` owns
  `org.freedesktop.Notifications`; history file gets new entries. Still open: history across a logout.
  Island: works (volume compact/expanded, build pill red and staying, test hook). The owner's
  keyboard has no volume keys. Scroll on the bar's volume item was tried and dropped by the owner
  ("don't need it"): `WheelHandler` got no wheel events at all; in a test layer window only
  `MouseArea.onWheel` did, but a `MouseArea` version of `Volume.qml` still did nothing on the bar
  (cause not found). `Volume.qml` stays display-only. Lock (SUPER+Escape): works on the laptop
  with three screens (tested by the owner, failsafe left at 0); typed dots show on all three
  screens (section 6 item done). Screenshots: works (region, window 1274x1400, screen 2560x1440 one G5
  only, clipboard, satty annotate saves `-annotated.png` with amber default). Not tried: a region
  across the laptop/G5 border (mixed scale). Keybinds: works (SUPER+V sized float, N, M,
  SUPER+Space and SUPER binds in Arabic). Step 10 done.
- **Layout indicator** (owner's request, not in the spec). `KeyboardLayout.qml`: gray `EN`/`AR`
  after the clock on all bars. Reads the main keyboard from `hyprctl -j devices` once, then follows
  Hyprland's `activelayout` event (same as the lock). Works on both keyboards.
- **Spotifast theme** (owner's request). `generate.py` writes `spotifast/Hypr.json` (roles as in
  `gtk_roles`; warning = fg, no shadow) and copies it as a real file to
  `~/.config/spotifast/themes/Hypr.json`: Spotifast skips symlinked themes, so `spotifast/` is in
  `.stow-local-ignore`. Copies happen only when content differs. Pick "Hypr" in Settings >
  Appearance > Theme. Works.
- **Strata theme** (owner's request). Custom themes are flat TOML files in
  `~/.config/strata/themes/<name>.toml` (`name` plus 14 colors, learned from a theme Strata wrote
  itself). `generate.py` writes `strata/hypr.toml` (syntax colors as in `nvim/colors/hypr.lua`) and
  copies it there as a real file (symlinks unverified). Selected as "Hypr". Works.
- **Step 11.1 battery in the bar.** `Battery.qml` (UPower `displayDevice`; `percentage` is 0-1 and
  the device is `ready` only a moment after start): gray glyph plus number after the network
  item; charging glyph on AC, level glyphs on battery; critical (10% or less on battery) fill
  glyph and number red. On all bars until slim bars exist. Plug/unplug works; critical untested.
- **Tray right-click menus.** They failed silently: `item.display()` uses Qt platform menus, which
  need `//@ pragma UseQApplication` (now in `shell.qml`; pragmas need a real `qs` restart). Found by
  watching D-Bus: `Activate` and dbusmenu `AboutToShow`/`GetLayout` went out, no menu appeared.
  The menus use Qt's own style, not the design system; the owner is fine with that (a QML menu via
  `QsMenuOpener` is the alternative).
- **Step 11.3 brightness keys: work** on the laptop panel (backlight `nvidia_0`). No `video` group
  needed: `brightnessctl` 0.5 is linked to libsystemd and falls back to logind `SetBrightness`,
  which logind allows only from the foreground session (calls from a background session fail with
  "Operation not permitted" / "Session is not in foreground"). Externals (DDC): not wanted (owner, 2026-10-15).
- **Island brightness.** The kernel sends a udev `change` event per backlight write, so
  `IslandState.qml` runs `udevadm monitor --subsystem-match=backlight` and re-reads the level with
  `brightnessctl -m` (no polling). New transient kind `brightness` (owner's choice): the compact
  volume pill with a sun and the brightness level, 2.5 s; expanded is the volume panel, whose
  Brightness row is now live. Works.
- **Island battery** (`IslandBattery.qml`, design canvas layout): plug and unplug pills (3 s), a
  pill when dropping to 20% on battery (once), critical at 10% or less stays with a red border.
  "Plugged in" is shown for AC without charging (the laptop's charge limit; the design only has
  Charging/Unplugged). Expanded: percent, state and time, bar, power profile picker
  (`PowerProfiles.profile`, power-profiles-daemon). A profile switch from anywhere (Fn+Q, picker,
  `powerprofilesctl`) shows "Power profile · <mode>" (leaf/scales/lightning glyphs). It appears
  about 2 s after Fn+Q: measured, the firmware file changes at once and the daemon publishes 2.0 s
  later; the owner keeps the delay (a POLLPRI watcher on `/sys/firmware/acpi/platform_profile`
  would make it instant). Works. Low (20%) and critical untested.
- **Island media** (`IslandMedia.qml`, MPRIS): the playing player shows; paused stays 30 s; stop or
  quit ends it. Compact 440x24 (owner: wider for long titles; design 280): bars glyph, title, muted
  artist, elapsed. Expanded 440x172: 72px art, title, artist, album, source · output, progress,
  shuffle/repeat, prev/play/next, output volume. The design's "Up next" is left out: Spotifast
  publishes no TrackList. The position is refreshed once a second while playing and shown.
  Now 640 wide, compact and expanded (owner: longer titles and lyric lines; about the limit before
  it covers the G5's right-hand blocks).
- **Lyrics** (owner's addition): a mode toggled by the microphone button in the expanded media
  notch; it stays on when the notch collapses. On: expanded shows five synced lines (the sung one
  bright) instead of the player; compact shows the sung line with a microphone glyph instead of
  title and artist. Source: LRCLIB (`lrclib.net/api/search`, via `curl`, owner's choice): title and
  artist go to lrclib.net, once per track, only while the mode is on; the result closest to the
  track length (within 3 s) wins, synced over plain. Plain-only lyrics: drag to scroll; compact
  keeps the title. Position refresh is 250 ms while lyrics are on. Mode and lyrics live in the
  `Lyrics.qml` singleton, shared by every screen's island (one lookup, the mode follows focus).
- **Island as a notch** (owner): joined to the screen's top edge in the bar colour, compact reaching
  the bar's bottom edge (y 0-38), expanded growing down. Square, with a subtle 2px `#333333` border
  (red for alerts) whose top line sits off-screen. Rounded corners and concave "shoulders" were
  tried and removed by the owner (they clashed with the square bar blocks). Slides down on appear
  and up on hide (120ms linear), keeping its last content while it slides out. Shows on the
  **focused screen** (`monitor.focused`), no longer pinned to the G5; moving focus slides it over.
- **Bar widgets float**: the bar is transparent, each widget sits on a `BarBlock` (bar colour, 32px,
  8px padding, 6px apart, the notch's subtle 2px border). Block visibility is bound to the widget's condition, not its `visible`
  (a child of a hidden block reads as hidden, so it would never come back).
- **Audio devices** (owner): the expanded volume panel lists outputs and inputs under the sliders,
  always visible (`IslandDeviceList.qml`; PipeWire nodes that are not streams). The current one has
  the amber marker; a click sets `Pipewire.preferredDefaultAudioSink/Source`. The panel's height
  grows with the lists (`IslandState.volumeHeight`). Clicking the bar's volume block opens it
  (`BarBlock.clickable`, `IslandState.showVolume()`). Works.
- **Wallpaper picker with matching colours** (owner, 2026-10-15, built unattended overnight):
  "Wallpaper" in Vicinae's search (`wallpaper-pick.desktop`) lists `~/Pictures/Wallpapers` through
  `vicinae dmenu` (full paths, for Quick Look previews), plus "Default colours". `wallpaper-apply`
  sets hyprpaper on every screen and in `hyprpaper.conf`, runs `from-wallpaper.py` (Pillow, OKLCH):
  accent = the image's most vivid hue at the default amber's lightness (L 0.78, chroma 0.10-0.17,
  kept 22 degrees away from the alert red, amber kept for gray images); neutrals = the default
  grays' exact lightness with a faint tint (chroma <= 0.012) of the image's main hue; alert and
  ANSI colours as default except yellow/grays; WCAG floors (fg 7, fg_muted/accent 4.5, on_accent
  4.5). Then `generate.py`, and reloads: `hyprctl reload` (borders), touch `alacritty.toml`, tmux
  `source-file colors.conf`, every Neovim over `--server` (re-runs the colorscheme), `vicinae
  theme set hypr`, `systemctl --user try-restart openrgb-kb` (keyboard), `notify-send`. Quickshell,
  the lock (its `Theme.qml` links the bar's) and Spotifast reload on their own; Strata and satty
  on next open; GTK css is generated but not stowed while COSMIC owns `gtk.css`. Tested from the
  shell on the current wallpaper (accent #eda480, keyboard FFB08A) and `--default` (back to amber,
  outputs identical to the commit). The Vicinae list and its previews: work (owner, 2026-10-15).
- **Window to the left/right screen** (spec keybind): SUPER+Shift+comma / period (`code:59` / `60`),
  `hl.dsp.window.move({ monitor = "l" | "r", follow = true })`. Works.
- **Lock screen additions** (spec): a red "Caps Lock on" under the layout label (Caps Lock is a normal
  key since keyd was skipped; read from `hyprctl -j devices` at start and when Caps Lock is
  released; its line is always reserved so nothing moves), and a small muted battery at the bottom
  of each screen on laptops (red when critical; `quickshell-lock/Icons.qml` links the bar's). Works.
- **Screen recording** (spec; owner added settings). `~/.local/bin/screen-record start|stop|toggle|pause`
  runs gpu-screen-recorder 6.1.4 on the focused monitor (`-w <name>`), MP4 + AAC, into
  `~/Videos/Recordings/<date>_<time>.mp4`. SUPER+R (`code:27`) toggles. While it runs,
  `$XDG_RUNTIME_DIR/recording/state.json` holds pid, screen, settings and pause times; a watcher
  removes it when the recorder exits and notifies "Recording saved" (or "Recording failed" with
  the log tail). Pause/resume = SIGUSR2, stop and save = SIGINT. The script pings the bar with
  `qs ipc call recording refresh`. `set +m` keeps `$!` = the recorder's pid (with job control
  `setsid` forks and the pid is lost). Settings, saved in `~/.local/state/recording/settings.json`
  and used by SUPER+R too: Mic, Desktop sound (mixed into one track `-a "default_output|default_input"`,
  or Two tracks = two `-a`), frame rate 30/60/120/144, quality medium/high/very_high/ultra (`-q`).
  Bar: a record block before volume (muted ○, red filled ● while recording); click opens the island:
  setup panel (`recsetup`, 340x324: audio, fps, quality, Start recording) when idle, the recording
  panel when running. Island `record` state per the design (compact 240x24 dot, Recording/Paused,
  mm:ss, stop; expanded 340x172 screen/audio/size lines, Pause/Resume, Stop and save), red border.
  Files: `Recording.qml` (singleton), `IslandRecord.qml`, `IslandButton.qml`. A harmless
  `failed to write frame index` line can show at stop; files decode cleanly. Works.
- **Network panel, step 1 of 3** (owner's design "Network manager" in the Hyprland Island canvas,
  claude.ai/artifact/AqnmRsK6WT21D6CvnAF4Xt, board `Network.dc.html`; the spec's network item was
  icon only, the owner's design decides). The bar's network block draws the design's Wi-Fi arcs
  (QtQuick.Shapes, its SVG paths): lit grey by signal level, red slash when Wi-Fi is on but nothing
  connected, grey slash when Wi-Fi is off, the network glyph on a wire without Wi-Fi. Click: a
  `PopupWindow` (`grabFocus`: keyboard, closes on an outside click or Escape) 400 wide, 4px under the
  bar, flush right. Header Wi-Fi, rescan, on/off; tabs Networks / VPN / Settings. Networks: search,
  list (connected first, then signal level, then name), rows open to details, password, Connect,
  Disconnect, Forget; a failed new network's profile is forgotten; Join hidden network (nmcli,
  password via `passwd-file /dev/stdin`, profile removed on failure). Wi-Fi list and actions via
  `Quickshell.Networking`; band and bit rate via `nmcli device wifi list` (NetworkManager has no
  dBm: signal shows as %). Files: `Network.qml`, `NetworkPanel.qml`, `NetworkRow.qml`,
  `PanelButton.qml`, `PanelSwitch.qml`, `PanelInput.qml`. Owner's choices for the next steps:
  nmcli for Settings and VPN, kill switch left out for now, "Connect on open Wi-Fi" uses the last
  VPN used, Airplane mode = `rfkill block all`. QML gotcha: in a delegate, `panel: panel` binds the
  object's own `panel` property, not the id; pass it through another property. Works.
- **Network panel, step 2: Settings tab** (`NetworkSettings.qml`). For the Wi-Fi network in use: a
  card (signal %, band and rate, security, IP, gateway, DNS), Auto-connect and Metered (its
  profile, `nmcli connection modify` + `nmcli device reapply`, no reconnect), DNS Auto / 1.1.1.1 /
  8.8.8.8 (v4 and v6 servers, router DNS ignored; Auto restores it), Forget this network. Machine:
  Airplane mode = `rfkill block|unblock all` (Wi-Fi and Bluetooth; the login's uaccess ACL on
  `/dev/rfkill`, no sudo; off turns Wi-Fi back on), and one line per wired port (Connected / Not
  connected / No cable). Works.
- **Network panel, step 3: the design's update** (pulled 2026-10-15; owner said "go").
  `NetState.qml` (singleton): internet from NetworkManager's connectivity check
  (ping.archlinux.org; ok / portal / none / down; a portal is re-checked every 5 s), and traffic of
  the default-route device: speed (sampled each second only while the Networks tab shows) and bytes
  used since that device connected (counters noted on connect, kept in
  `$XDG_RUNTIME_DIR/network-usage.json` across shell reloads). Bar: a "!" top right, red for no
  internet, light for a sign-in page. Panel: a status box under the tabs (No internet: Retry; Sign-in
  required: Open login page = xdg-open the check page), the speed line, keyboard (search focused on
  open, Up/Down accent highlight, Enter opens or connects, Esc closes, hint line). Settings: Internet
  row (OK + ping to 1.1.1.1), click a row to copy (wl-copy, "Copied"), Share network (QR) via
  `~/.local/bin/wifi-qr` (password from `nmcli -s -g`, which escapes ':' and '\' even for one field;
  piped to qrencode; SVG in `$XDG_RUNTIME_DIR`, deleted when hidden). The canvas also has a new
  "Phone bridge" board: not built.
- **Network panel, step 4: Hotspot** (Settings; owner's choices: NetworkManager's own hotspot on
  wlan0, replacing the Wi-Fi network and sharing the wired one; SSID = hostname, password
  generated). Reuses the existing `Hotspot` profile (ap, shared, wpa-psk, autoconnect no), or makes
  it with `nmcli device wifi hotspot` (NetworkManager generates the password). On/off state from
  `WifiDevice.mode`; card: name, password (eye), clients (`iw dev wlan0 station dump`, every 3 s
  while shown). Needs `dnsmasq` (installed 2026-10-15, in `packages/repo.txt`; its own service
  stays disabled, NetworkManager runs a private instance). Works.
- **Network panel, step 5: VPN tab** (`NetworkVpn.qml`; kill switch left out, owner's choice).
  NetworkManager VPN profiles (WireGuard, OpenVPN, Fortinet, strongSwan plugin) via nmcli: shield
  row (filled while on), protocol or Connected; open: protocol, server (WireGuard
  `wireguard.peers` endpoint, else `vpn.data` remote/gateway/address), ping; Connect (one VPN at a
  time) / Disconnect; errors in red. Import profile: zenity picker, `nmcli connection import`
  (WireGuard if the file has `[Interface]`, else OpenVPN), autoconnect set to no, notification.
  `NetState`: active VPN re-read on every `nmcli monitor` line (300 ms debounce); bar glyph gets a
  light square while a VPN is on; Connect on open Wi-Fi (open or OWE) brings up the last VPN used
  (`~/.local/state/network/vpn.json`). No secret agent: VPNs that ask for a password at connect
  fail with NetworkManager's error. QML gotcha: a method named like a JS global (`unescape`) fails
  the whole load with "Illegal method name". Works.
- **swanctl in the VPN tab** (owner's request; strongSwan 6.1's own daemon, not NetworkManager).
  Access: group `vpn` (system group, owner added), `strongswan/charon-group.conf` in this repo
  (not stowed) installed to `/etc/strongswan.d/` sets `charon.group = vpn`, which makes the VICI
  socket `/run/charon.vici` root:vpn (verified on 6.1; the docs don't say it, a maintainer's list
  post does), so swanctl runs as the owner without sudo. `strongswan.service` stays disabled and is
  started by hand (owner's choice); the tab says so while it is down. `NetState`: connections from
  `swanctl --list-conns`, state from `--list-sas`, re-read on each `swanctl --log` event (restarted
  every 10 s while the daemon is down); ids `swan:<name>`, merged with NetworkManager's VPN in
  `combine()` (bar square, caption, one VPN at a time either way, Connect on open Wi-Fi). Connect
  initiates every child (`--initiate --child`), Disconnect terminates the IKE SA. Works.
- **Bar items** (spec). Bluetooth (`BluetoothStatus.qml`, not `Bluetooth.qml`, which would shadow
  Quickshell.Bluetooth's singleton): icon only, grey; slash off/blocked, plain on, connected glyph
  with a device; hidden without an adapter; click opens `alacritty --class bluetui -e bluetui`
  (owner's choice; `bluetui` in `packages/repo.txt`). Mic and camera (`CaptureIndicator.qml`): red
  Fill glyphs, block shown only while live, between record and volume. Mic = a PipeWire link group
  from an `AudioSource` to an `AudioInStream` (Quickshell types an app's capture stream
  Audio|Stream|Source with isSink false; monitor captures come from the sink node, not counted).
  Camera = `fuser -s /dev/video*` every 2 s (apps open V4L2 directly). Bar media item skipped:
  the island shows what plays (owner). Works.
- **Bar profiles, step 1 of hotplug** (spec "Monitors and bars"). No hotplug tool (owner's choice,
  overrides the spec's "a tool like kanshi or hyprdynamicmonitors is needed", which assumed Waybar):
  Quickshell makes and drops a bar per screen (`Variants` over `Quickshell.screens`), and each bar
  picks its profile in `Bar.qml`: full on the G5 (matched by model "Odyssey G5"), on a screen alone,
  or on the laptop when the G5 is away; slim elsewhere (workspaces, title, clock; the laptop's
  adds network and battery). Right screen's media item left out (the island shows it). Research:
  hyprdynamicmonitors writes hyprlang `monitors.conf` (deprecated since Hyprland 0.55, the config
  is Lua; README silent on Lua; AUR 1.4.0); kanshi 1.9.0 (extra) would work through the output
  protocol but was not needed: the owner's setups are all three screens or the laptop alone, and
  Hyprland's `desc:` rules place each monitor. Works.
- **Lid, step 2 of hotplug** (spec: lid closed, its workspaces land on the survivor; no suspend
  with externals). `hyprland.lua` decides on every config load: lid closed
  (`/proc/acpi/button/lid/LID0/state`, Lua `io`) and another screen present (`hl.get_monitors()`)
  → `eDP-1` rule gets `disabled = true`. `switch:on/off:Lid Switch` binds (`locked = true`, 0.56
  wiki) and `hl.on("monitor.added"/"monitor.removed")` just run `hyprctl reload` (a full reload
  applies monitor rules; auto-reload on save does not). When `eDP-1` goes, its workspaces (6-10)
  are moved to the G5 by description (owner: Hyprland had put them on the LF24); the G5 keeps its
  shown workspace. hyprsplit's ranges are fixed by priority, so visiting workspaces would vanish
  from the bar and SUPER+number: `Workspaces.qml` now shows only its own range in slots 1-5 and,
  after them, a laptop (or monitor) glyph and the visitors' squares (clickable,
  `Hyprland.dispatch("hl.dsp.focus({ workspace = N })")`, `WorkspaceSquare.qml`). Opening the lid:
  hyprsplit's `ensure_good_workspaces` (on `monitor.added` and `config.reloaded`) moves them home.
  `hyprctl repl/eval` run Lua inside Hyprland (handy for checks). Works.
- **Island Wi-Fi and Bluetooth events** (owner's request; owner chose all four events and the
  battery-pill look). Kind `connect`, compact only 260x24, 3 s (`IslandConnect.qml`): name, then
  a muted word (Connected / Lost / Disconnected, or a Bluetooth device's battery %) and the glyph;
  Wi-Fi lost is red only with no other link. A click runs `IslandState.click(screen)`: Wi-Fi opens
  the network panel on that screen's bar (`NetState.panelRequested`), Bluetooth opens bluetui; other
  states still expand. Rules: quiet for 5 s after start; "lost" waits 2 s (a new network in time
  shows only "connected") and is skipped while Wi-Fi is off, the hotspot runs, or within 15 s of
  the panel changing the connection (`NetState.userChange()`); Bluetooth events skipped while the
  adapter isn't Enabled. Test hooks: `qs ipc call island test wifi|wifilost|bt|btoff`. Works.
- **Phone bridge, step 1: bar block** (owner's design "Phone bridge", canvas board `Phone.dc.html`).
  Backend: **kcd** (AUR `kcd` 1.22.2, Go, MIT; in `packages/aur.txt`), a headless KDE Connect v8
  daemon, owner's choice over KDE Connect (44 packages) and our own Python bridge. Before install:
  its source was read: trust comes only from the post-TLS identity (cert CN = device ID, pinned
  fingerprint for paired devices), the pre-TLS identity decides nothing (CVE-2025-66270 pattern
  absent), unpaired devices only get identity/pair packets, pair requests wait for confirmation.
  `systemctl --user enable --now kcd.socket` (socket-activated; the bar's watch starts it). Paired
  with the owner's POCO M6 Pro by device ID (`kcd pair <id>`, not listen mode). Pairing first
  failed: the "Wired connection 2" profile had a leftover static route `192.168.0.0/24 via
  192.168.0.1` on the USB Ethernet (metric 100) that sent Wi-Fi LAN traffic out the dock; removed
  with the owner's OK (`nmcli connection modify ... -ipv4.routes ...`, reapply). `Phone.qml`
  (singleton) runs `kcd watch --json` (NDJSON `{type, deviceId, payload}`, `state.snapshot`
  first): name, connected, battery, notifications (id, app, title, text, replyId, time, unread;
  kept in `$XDG_RUNTIME_DIR/phone-notifications.json`). `PhoneStatus.qml`: the design's phone
  outline (Shapes), grey slash while disconnected, accent square for unread; block after the
  keyboard layout, full bar only, while paired. A phone leaving Wi-Fi shows after up to ~1 min
  (kcd keepalive 15 s x 3); a disconnect while still on Wi-Fi is redialled within 0.2 s. kcd also
  has reply, dismiss, call mute, findmyphone, share (progress events), clipboard. Its remote-input
  plugin is active (uinput): a paired phone can move the mouse and type. Works.
- **Phone bridge, step 2: panel, header and Inbox** (`PhonePanel.qml`, `PhoneNotification.qml`,
  `PhoneGlyph.qml`). A `PopupWindow` anchored to the bar's phone block (`anchor.item`), 420 wide,
  right edge on the block's. Header: name, "Connected · battery · Wi-Fi name" (Low + red battery
  at 15% or less); kcd has no disconnect, so only **Reconnect** while away = `timeout 20 kcd pair
  --advertise-only` (announces, never accepts a pairing). Tabs Inbox (unread count) / Actions /
  Settings. Inbox: newest first, opening marks read; Reply (`kcd reply <dev> <replyId> <text>`,
  only with a reply id), Copy code (4-8 digits next to code/OTP/verif/pin/رمز/كود, wl-copy),
  Dismiss (`kcd dismiss`, on the phone too); Clear all empties this list only. `PanelInput` got
  `action` (a small accent button inside the field). IPC: `qs ipc call phone open` (panel on the
  focused screen), `phone test` / `phone clearTest` (sample notifications). Works.
- **Phone bridge, step 3: Actions tab.** Ring phone (`kcd findmyphone`; no stop command, touch the
  phone), Send clipboard (`kcd clipboard`), Send file (zenity picker, then `kcd share`; panel
  closes for the picker), Transfers (last five; `share.progress` per file name, `share.complete`
  with success/error; received files in `~/Downloads/kcd`, kcd's default). Left out: Lock phone
  (owner), Link to open on phone (kcd sends files only; Send clipboard covers it), Last clipboard
  from phone (kcd writes it into the desktop clipboard without an event), Stop ringing. Works.
- **Phone bridge, step 4: Settings tab** (`PhoneSettings.qml`). Switches: Mirror notifications,
  Reply from desktop (panel-only), Sync clipboard, File sharing (the design's "Receive files"; kcd's
  share plugin does both directions), Battery alerts, Remote input (added: mousepad plugin); a
  switch per app seen (muted apps dropped from the Inbox); connection line; Unpair (press twice
  within 3 s). Settings in `~/.local/state/phone/settings.json`; `~/.local/bin/kcd-settings`
  edits `~/.config/kcd/kcd.toml` in place 1.5 s after the last change (kcd writes its full
  default config, so keys are set inside its `[plugins]`/`[battery]` tables and `[notifications]`
  is rebuilt; the result must parse with `tomllib` before replacing the file), then
  `systemctl --user try-restart kcd.service`. kcd matches per-app rules on the app's display
  name (code), not the package name its example says. Switched-off features hide their actions.
  Works.
- **Phone bridge, step 5: incoming-call card** (`PhoneCall.qml`). kcd `telephony.ringing`
  ({contactName, phoneNumber}) shows a 420 wide card under the phone block (right edge on the
  block's), panel or not; `canceled`/`missed`/disconnect hide it. A layer-shell `PanelWindow`
  (Top layer, no keyboard focus), not a popup. Mute ring = `kcd call mute` (card says Muted); Reject
  left out (owner; the Android app can't). An open panel drops below it (`PhonePanel.below`).
  Test hooks: `qs ipc call phone testCall` / `endCall`. kcd caches no battery after a restart and
  `kcd battery` only reads the cache: the header's % returns with the phone's next report. The
  phone bridge is complete. Works.
- **Owner's preference (2026-10-15): no phone notifications on the desktop.** Mirror notifications
  is off in the phone panel's Settings (`~/.local/state/phone/settings.json`, so kcd.toml has
  `notification = false` under `[plugins]`): nothing reaches the island, the inbox or the panel's
  Inbox. Both files live outside the repo; keep it off on a new setup.
- **Phone → laptop commands** (owner's choice; KDE Connect app → Run command). `kcd-settings`
  rebuilds kcd's `[commands]` with exactly: "Lock laptop" = `loginctl lock-session` (hypridle runs
  the Quickshell lock), "Suspend" = `systemctl suspend` (hypridle locks first), "Screenshot to
  phone" = `~/.local/bin/phone-screenshot` (grim of the focused screen into
  `~/Pictures/Screenshots/<date>_phone.png`, then `kcd share` to the paired phone; finds
  Hyprland's environment via `hyprctl instances` if kcd lacks it). Works.
- **Browse phone files** (Actions tab; `sshfs` installed 2026-10-15, in `packages/repo.txt`). `kcd sftp mount <id>` (asks the phone for SFTP, mounts with sshfs under
  `$XDG_RUNTIME_DIR/kcd/mnt`, writable by kcd's default, prints the mount point; repeat reuses it),
  then `xdg-open` on it: the default folder handler is Strata (`io.github.lgse.Strata.desktop`). The
  panel closes on success, shows kcd's message on failure. Android needs the KDE Connect app's file
  access. kcd's docs confirm the Android app ignores lock requests (Lock phone was rightly left
  out). Works.
- **OBS screen capture** (spec: OBS for real content, gpu-screen-recorder for quick capture).
  OBS 32.2 "Screen Capture (PipeWire)" → xdg-desktop-portal 1.22.1 → xdg-desktop-portal-hyprland
  1.4.1 (picker `hyprland-share-picker`: screen / window / region, optional restore token). The
  portals must be started under Hyprland (`XDG_CURRENT_DESKTOP=Hyprland`; COSMIC's backend stays
  idle) and `.config/xdg-desktop-portal/hyprland-portals.conf` (the owner's, stowed) sends
  everything to hyprland then gtk, file dialogs to Strata. Hyprland's `enforce_permissions` is off.
  ScreenCast offers source types 7, cursor modes 3, version 6. Works (owner, 2026-10-15).
  Side finding: on 2026-10-15 11:47 (logout for the vpn group) Hyprland segfaulted while exiting,
  in Aquamarine's DRM backend destructor (`exit` → `__cxa_finalize` → `CDRMBackend` →
  `flushAsyncCommitEvents`); the portal backend and hyprsunset died with the compositor. A
  shutdown-only crash, harmless; watch for it if logouts ever misbehave.
- **Login screen: Quickshell greeter on greetd** (owner's choice over cosmic-greeter, tuigreet,
  ReGreet; 2026-10-15). `greeter/` (stow-ignored): `shell.qml` + `GreeterContent.qml` (the lock
  screen's look: clock, date, user "mohammed", password field, layout / Wrong password, Caps Lock
  line, battery; session picker `‹ name ›` from `/usr/share/wayland-sessions`, Up/Down or click,
  Hyprland (uwsm) first, last one remembered in `/var/lib/quickshell-greeter/last-session`;
  Restart / Shut down bottom right; `WlSessionLock` surfaces cover every screen like the lock).
  Greetd API: `createSession(user)`, `respond()` to every `authMessage` (empty when no answer is
  needed), `readyToLaunch` → `launch(["/bin/sh","-c","exec <Exec>"], ["XDG_SESSION_TYPE=wayland"],
  true)` after unlocking the surfaces. It runs as the `greeter` user (can't read ~, home is 700) in
  a greeter-only Hyprland (`greeter/hyprland.lua`: monitors copied from the main config, keep in
  sync; palette; us,ara; no animations; runs `qs -p /etc/greetd/quickshell-greeter` and exits
  Hyprland when it quits). `sudo greeter/install.sh` copies everything to `/etc/greetd`
  (Theme.qml, Icons.qml and hypr_palette.lua as copies: re-run after a wallpaper change), creates
  `/var/lib/quickshell-greeter` (HOME for the greeter), and the drop-in
  `/etc/systemd/system/greetd.service.d/quickshell-greeter.conf`; it enables nothing. Test run
  beside the live session: `sudo greetd --vt 7 -s /run/greetd-test.sock -c
  /etc/greetd/quickshell-greeter-test.toml` (GREETER_TEST=1 runs `echo` through the same launch
  path; check `journalctl -t greeter-session` for "greeter test: the session command ran").
  **In use since 2026-10-15 23:22** (greetd enabled, cosmic-greeter disabled; a real login into
  Hyprland (uwsm) works). Switch: `sudo systemctl disable cosmic-greeter.service && sudo
  systemctl enable greetd.service`, then reboot; never `systemctl start greetd` next to a running
  session (both on VT1: logind refuses the login, `VirtualTerminalAlreadyTaken`). Rollback from a
  TTY (Ctrl+Alt+F2): `~/greeter-rollback.sh` (temporary, outside the repo) or `sudo systemctl
  disable greetd.service && sudo systemctl enable cosmic-greeter.service && sudo reboot`. COSMIC
  stays installed and selectable (spec).
  Bugs found on the way (the first real logins bounced back to the greeter): greetd joins the
  launch command list with spaces into ONE line for `sh -c "<profile>; exec <line>"`, so a list
  like `["/bin/sh","-c","exec uwsm ..."]` became `exec /bin/sh -c exec uwsm ...` (an empty exec,
  the session ended at once, uwsm never ran). The launch is now one string,
  `systemd-cat -t greeter-session <Exec>` (the session's output lands in the journal). The first
  test run hid this because `true` "succeeds" either way; test mode also saved the session it
  ended on as the last one (now it doesn't). The greeter's Hyprland segfaults when it exits
  (Aquamarine DRM teardown, as on logout): harmless, greetd moves on.
- **GRUB menu theme** (owner's choice, 2026-10-15; the spec doesn't cover boot). `grub/`
  (stow-ignored): `make-theme.py` builds it from `palette/palette.toml` (the lock screen's look:
  solid bg, centred square box with a 2px border on surface, the selected entry filled with the
  accent, JetBrains Mono via `grub-mkfont` at 20 and 16 px for the 2560x1600 panel, "Booting in
  %d s" countdown, key hint; styled-box PNGs per the GRUB manual's "Styled Boxes"); `sudo
  grub/install.sh` writes it to `/boot/grub/themes/hypr`, sets `GRUB_THEME` and
  `GRUB_DISABLE_BOOTNEXT=true` (GRUB 2.16's `31_efi_bootnext` added 7 "EFI BootNext" entries; the
  owner keeps the 4: Arch, Advanced, Windows, UEFI settings) and runs `grub-mkconfig`. Re-run it
  after a wallpaper change. First run keeps `/etc/default/grub.pre-hypr-theme` and
  `/boot/grub/grub.cfg.pre-hypr-theme`; undo: copy the first back, `grub-mkconfig -o
  /boot/grub/grub.cfg` (Catppuccin stays installed). Bug fixed on the way: the key setter also
  matched commented `#GRUB_THEME=` lines and activated them; it now changes only active lines.
  Timeout 5 s kept. Works (owner).
- **Plymouth boot splash** (owner's choice, 2026-10-16; the spec doesn't cover boot). `plymouth/`
  (stow-ignored): `make-theme.py` builds a `script` theme from `palette/palette.toml`: palette
  bg, the Arch logo (`/usr/share/pixmaps/archlinux-logo.svg`, first path only, the others are a
  ™ sign; recoloured to the accent, `rsvg-convert` 112 px), three 12 px accent squares pulsing in
  turn under it, boot messages muted at the bottom, a plain password prompt (none expected, no
  disk encryption); fonts JetBrains Mono. `sudo plymouth/install.sh` installs it to
  `/usr/share/plymouth/themes/hypr`, `plymouth-set-default-theme hypr`, puts the `plymouth` hook
  right after `systemd` in `/etc/mkinitcpio.conf`, adds `splash` to `GRUB_CMDLINE_LINUX_DEFAULT`,
  then `mkinitcpio -P` and `grub-mkconfig`. Re-run after a wallpaper change (rebuilds the
  initramfs, ~1 min). First run keeps `*.pre-plymouth` copies of `mkinitcpio.conf`,
  `/etc/default/grub` and `initramfs-linux-zen.img`. Skip once: `e` in GRUB, delete `splash`.
  Undo: copy the two config backups back, `mkinitcpio -P`, `grub-mkconfig -o /boot/grub/grub.cfg`.
  NVIDIA modules load early (MODULES) and `nvidia_drm.fbdev=1`, so the splash has a display;
  greetd starts after `plymouth-quit-wait`. Works (owner).
- **After a wallpaper change: `boot-colours`** (owner, 2026-10-16; `.local/bin/boot-colours`,
  asks for sudo itself): runs `greeter/install.sh`, `grub/install.sh`, `plymouth/install.sh` in
  order and, only if all succeed, records `sha256(palette/palette.toml)` in
  `/var/lib/boot-colours/palette.sha256`. `--check` compares it (before the first run: the
  greeter's Theme.qml copy stands in). `--remind`: if stale, a notification "Boot screens have
  the old colours" whose **default** action "Apply now" opens `alacritty --class boot-colours`
  running it (the island and inbox only know the `default` action: a named one like `apply`
  showed no button; the island's primary button now shows the default action's own text, falling
  back to "Reply"). `wallpaper-apply` calls `--remind` after a change, Hyprland 15 s after login
  (`hyprland.start`); one reminder at a time (flock). Works (owner used Apply now).
- **Safety net: `boot-restore`** (`.local/bin/boot-restore`, works from a TTY, only system
  tools, asks first and before rebooting; `--yes` asks nothing and doesn't reboot): cosmic-greeter
  back (greetd disabled, our drop-in and `/etc/greetd` files removed), `plymouth` hook and
  `splash` removed, `GRUB_THEME` back to the line in `/etc/default/grub.pre-hypr-theme`
  (Catppuccin), our theme dirs removed, `mkinitcpio -P` (rebuilt, not the old image: the kernel
  may be newer), `grub-mkconfig`; then `/var/lib/boot-colours/off` stops reminders until
  `boot-colours` runs again (which reinstalls all but leaves cosmic-greeter in use, and says how
  to switch). Only undoes what the installers added; `GRUB_DISABLE_BOOTNEXT=true` stays.
  Dry-run on copies: `mkinitcpio.conf` identical to the original. Not run for real.
  `~/greeter-rollback.sh` is superseded (the owner may delete it).
- **Claude desktop tray icon: works** (checked 2026-10-15). Chromium offers its icon two ways:
  pixels only (`IconPixmap`, normal start) or, when it thinks it runs on GNOME
  (`GNOME_DESKTOP_SESSION_ID`, set session-wide by `env-hyprland`), a named icon in a temp folder
  (`IconName status_icon_0` + `IconThemePath /tmp/org.chromium.Chromium.*`, no pixels). Both show
  in the bar. The one failure (`Could not load icon "status_icon_0"`) did not come back on
  restarts; most likely the bar asked before Chromium had written the file. If it recurs: restart
  the app, or teach `Tray.qml` to retry.
- **SUPER+E** runs `~/.local/scripts/vicinae-emulator.sh` (Android emulator picker; owner's request,
  not in the spec). Works. Note: `hyprctl binds` shows Lua keycode binds with an empty key.
- **tmux in Alacritty** (owner's choice, changed from one shared session): `[terminal] shell` runs
  `tmux new-session ; set-option destroy-unattached on`, so every window is its own session and it
  ends when the window closes (set per session, so hand-made sessions survive a detach). Works.
- **Old tmux setup, partly back** (owner picked from the 2026-10 config in git, `8c83df1^`): windows
  and panes from 1, renumber-windows, new windows/splits in the current directory, Alt+arrows panes
  and Shift+arrows windows without the prefix (tmux-only, no Hyprland clash). Palette status bar
  kept; tokyo-night theme, mouse, status-at-top, tmux-sensible and tmux-resurrect not wanted. Works.
- **tmux plugins back** via TPM (the existing `.tmux/plugins/tpm` submodule @99469c4, run last in
  `tmux.conf`), each a git submodule pinned to the old commits under `.config/tmux/plugins/`:
  tmux-yank @acfd36e (copy-mode `y` to the clipboard), tmux-fzf-url @09d4998 (`prefix x`),
  vim-tmux-navigator @c45243d (Ctrl+h/j/k/l). The navigator's Neovim half is the same repo @c45243d
  in `.config/nvim/pack/plugins/start/` (native packages, no plugin manager). Works.
- **Strata as file manager and file picker** (owner, 2026-10-15). Strata's installer (everything
  in `~/.local`, outside the repo) set `inode/directory` in `~/.config/mimeapps.list` (left
  untracked: apps rewrite that file), the `org.freedesktop.FileManager1` D-Bus service ("Show in
  folder") and a FileChooser portal backend (`strata --portal`; xdg-desktop-portal 1.22 does read
  `strata.portal` from `~/.local/share/xdg-desktop-portal/portals`). Now tracked:
  `.config/xdg-desktop-portal/hyprland-portals.conf` (FileChooser `strata;hyprland;gtk`).
  `env-hyprland` sets `GTK_USE_PORTAL=1` (GTK3; Firefox/Zen "auto" counts it too) and
  `GDK_DEBUG=portals` (GTK4), so native GTK dialogs use Strata. SUPER+F (code 41) opens Strata:
  owner asked for an invented bind, the spec has none. Telegram's picker works through Strata.

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

**Next: step 11** (section 6 real-machine list, one item per step).
Open from 2026-10-15:
- `env-hyprland` after a re-login: verified by the owner (keyring works, 2026-10-15).
- After a re-login: file dialogs in a GTK3 app (Mousepad), GTK4 (`zenity --file-selection`), Zen
  and Chrome should open Strata. If GTK apps start asking "Open with" for links or files, that is
  the portal's OpenURI side effect of the two GTK variables in `env-hyprland`.
- Wallpaper picker in Vicinae: Quick Look previews work (owner, 2026-10-15).
- Hyprland config is Lua (`hl.config`, `hl.bind`, `hl.dsp.*`). `hyprctl dispatch` takes Lua:
  `hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`.
- hyprsplit: the C++ plugin is deprecated and its hyprpm pins stop at Hyprland 0.54.3. Use the
  Lua library (submodule). Native fallback: swap `hs.dsp.*` back to `hl.dsp.*`, drop the require.
  No `hyprpm` at all.
- Wallpaper: an image now (owner, 2026-10-15, overriding the spec's "solid color is final"):
  hyprpaper 0.8 with `.config/hypr/hyprpaper.conf` (one `wallpaper {}` block, empty `monitor` =
  every screen, `fit_mode = cover`, `splash = false`), started from `hyprland.lua`. The image is
  `~/Pictures/Wallpapers/blue_arch_nowatermark.png` (4096x3072; blue accent #7ebcff, cool neutrals, bg #0e1116, from the picker
  2026-10-15), outside the repo; change it live with
  `hyprctl hyprpaper wallpaper '<monitor>,<path>,cover'`. Hyprland's solid `bg`
  (`misc.background_color`) stays underneath. The lock screen stays solid.
- Gaps: 6px everywhere (owner, 2026-10-15), screen edges and bar-to-window included:
  `gaps_in = 3` (per window edge), `gaps_out = 6`. The spec had 4 between and 0 at the edges.
  Hidden workspaces re-tile only when shown, so `hyprctl clients` shows their old geometry.
- The bar floats 6px from the top and sides too (`margins` in `Bar.qml`); Quickshell's automatic
  exclusive zone includes the margin (reserved top 38), so windows keep 6px below it. The island
  pill moved to y=10 to stay 4px inside the bar. The inbox sits 6px below the bar and 6px from the right edge.
- Lock screen: Quickshell `WlSessionLock` + `PamContext` in its own instance, run by SUPER+Escape
  through `flock`. PAM file lives in `pam/` and includes `/etc/pam.d/system-auth` by **absolute**
  path (a relative include fails: PAM looks inside the custom dir). hyprlock was removed by the
  owner (2026-10-15) once this lock worked on three monitors; its config went with it. Test-mode
  failsafe is off (`failsafeSeconds: 0`).
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
| SUPER+E | Android emulator picker (`~/.local/scripts/vicinae-emulator.sh`, owner's addition) | 26 |
| SUPER+F | Strata file manager (`~/.local/bin/strata`, owner's addition) | 41 |
| SUPER+Space | layout toggle (XKB `grp:win_space_toggle`, `us,ara`) | |
| SUPER+Q | close window | 24 |
| SUPER+V | float toggle (sized, centred) | 55 |
| SUPER+N / SUPER+M | fullscreen / maximize | 57 / 58 |
| SUPER(+Shift)+H J K L or arrows | focus (move window) | 43 44 45 46 |
| SUPER+Ctrl+arrows | resize 40px, repeats | |
| SUPER(+Shift)+1-5 | workspace (send window), via hyprsplit | 10-14 |
| SUPER+Shift+comma / period | window to the screen on the left / right | 59 / 60 |
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
- OBS for real content (spec): done, screen capture works (see progress).
- Brightness: OSD now lives in the island volume panel (Brightness row, `hasBrightness` in
  `IslandState.qml`); brightness keys are already bound to `brightnessctl`. External-monitor
  brightness (DDC): not wanted (owner, 2026-10-15).
- Per-app notification quiet rules for chat apps: not wanted (owner, 2026-10-15; overrides the
  spec's "Per-app notification rules: yes").
- Hotplug step 3, deferred by the owner (2026-10-15): test laptop alone (unplug both externals:
  laptop bar turns full, the externals' windows land on it behind a monitor glyph) and plugging
  back in (G5 full again, workspaces home, visitors gone; island follows focus; network panel from
  the laptop bar). Bar items, slim bars and the lid are done and tested.
- Island Wi-Fi and Bluetooth events: done (see progress).
- GTK under Hyprland: COSMIC owns `~/.config/gtk-{3,4}.0/gtk.css` (links to its `cosmic/dark.css`,
  rewritten at login), so our GTK folders are in `.stow-local-ignore`. When Hyprland is the daily
  desktop: turn off COSMIC's GTK theming, delete the two gtk lines there, move the real folders
  aside, `stow -R .`.
- Optional fish wrapper for island-build (e.g. `function b; island-build $argv; end`), and make
  sure `~/.local/bin` is on fish's PATH (`fish_add_path ~/.local/bin`).

Test (configured, untested on the VM):
- hypridle: tested by the owner on the laptop (2026-10-15): works. Lid close with externals
  attached doesn't suspend (`HandleLidSwitchDocked=ignore`), see the lid entry in progress.
- hyprsunset (21:00-06:30, 4500K): works on the laptop (owner, 2026-10-15; preview with
  `hyprctl hyprsunset temperature 4500`, then `hyprctl hyprsunset reset`).
- Lock screen on three monitors: works (owner, 2026-10-15), so hyprlock may go (safety rule 5).
- Island and bar on multiple screens: work. Lid closed: works. Laptop alone and plugging back
  in: deferred (see section 6). (`hs.dsp.grab_rogue_windows()` not needed: visitors show in the bar.)
- Glyph sizes on all screens (laptop scale; they look right in the 15:21 screenshot), laptop panel
  type (OLED changes idle choices). Arabic titles: work (owner, 2026-10-15).
- Mixed-scale region screenshot (laptop 4/3 + G5 1, owner's shot 2026-10-15): correct. grim renders
  the whole region at the highest scale (4/3), so the G5 part is upscaled by a third (slightly
  soft); screens join without gap or overlap; the area outside any screen is transparent.

## 7. Recovery

- Lock screen dies -> Hyprland shows "lockscreen died" (session stays locked). From SSH/TTY:
  start the Quickshell lock again, it takes over the session lock:
  `hyprctl dispatch 'hl.dsp.exec_cmd("qs -p ~/.config/quickshell-lock")'` (needs
  `WAYLAND_DISPLAY` and `HYPRLAND_INSTANCE_SIGNATURE`), then unlock with it. Untested: hyprlock was
  the tested fallback and is removed. Hyprland also offers
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
- New fonts need a real `qs` restart (Qt reads fonts once). So does the `//@ pragma IconTheme`,
  and so do icons of apps installed after `qs` started (Qt caches the icon folders): a tray icon
  shows as a pink and black checkerboard with `Could not load icon "<name>"` in `qs log`.
  Restart: `kill <bar pid>`, then `hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`.
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
- Hyprland's autogenerated-config banner reserves 61px at the top (removed `autogenerated`).
- `hypridle` `inhibit_sleep = 3` waits for any session lock (auto mode looks for hyprlock).
- `pam_faillock` is in `system-auth`: never script repeated wrong-password tests.
- `notify-send --wait -A default=Open` is a good way to test the inbox/island Reply action.
- (Laptop) Electron apps don't recognise `XDG_CURRENT_DESKTOP=Hyprland` and claim there is no OS
  keyring (gnome-keyring runs and is unlocked). Global fix, not per-app flags (owner's call):
  `.config/uwsm/env-hyprland` exports `GNOME_DESKTOP_SESSION_ID`, which Chromium checks after
  `XDG_CURRENT_DESKTOP` and `DESKTOP_SESSION`. Tested on Claude desktop by hand (warning gone);
  the uwsm file works after a re-login (owner, 2026-10-15). VS Code's `argv.json` is back to stock.
- (Laptop) `console.log` is debug level: a probe's output may not show. Use `console.warn`.
- (Laptop) `WheelHandler` received no wheel events on our layer-shell windows; `MouseArea.onWheel`
  did in a test window (but not in a `Volume.qml` attempt, cause unknown).
- (Laptop) Inline `component`s failed twice with "X is not a type" (`Ear` in `Island.qml`,
  `DeviceList` in `IslandVolume.qml`, where `Bar`/`LevelRow` work). Cause not found; put new parts
  in their own files (`IslandEar.qml`, `IslandDeviceList.qml`) instead.
- (Laptop) Hyprland's automatic reload on save applies most options (gaps did) but not monitor
  rules: after editing `hl.monitor`, run `hyprctl reload`.
- (Laptop) Renaming a QML property: rename its change handler too, which is capitalised
  (`lyricsOpen` -> `lyricsOn` also means `onLyricsOpenChanged` -> `onLyricsOnChanged`), or the
  reload fails with "Cannot assign to non-existent property".
- (Laptop) Adding a new QML file plus a `Bar.qml` edit: the reload can miss the edit. Check on
  screen; append a comment to `Bar.qml` to force a reload.

# dotfiles

A complete Hyprland desktop for Arch Linux, built around a hand-written
[Quickshell](https://quickshell.org) shell. The bar, notifications, lock screen, login screen,
settings and every panel are QML in this repo. Colours come from the wallpaper: set a new one
and the whole desktop, from the terminal to the boot splash, recolours itself.

## Features

- **Frame**: a rounded frame round every screen in the wallpaper's colours. Its top side is the
  bar, and the island and every panel grow out of it.
- **Bar**: coloured chips, each in its own hue from the wallpaper. The Arch logo is the
  notifications (a dot when unread, right click for Do Not Disturb). Then the island, the focused
  window's title, the workspaces as coloured pills with an icon for each open window, the tray
  behind an arrow, the clock, phone, Pomodoro and recording chips while they have something to
  show, tools, and quick settings. Every screen gets a bar; the main screen gets the full one.
- **Quick settings**: one chip and one panel for Wi-Fi, Bluetooth, Do Not Disturb, Keep awake,
  volume, mic and brightness, the battery and power profile, and the power buttons. Views one
  click deeper: sound (devices, per-app volume and output), Bluetooth (pair, forget) and Wi-Fi
  (VPN including strongSwan, hotspot, hidden networks, per-connection settings, airplane mode).
- **Island**: a notch in the bar that shows what's happening: volume and brightness,
  notifications, media with lyrics, recording, Pomodoro, build results, Wi-Fi and Bluetooth
  events.
- **Panels** that grow out of the bar under their chip, one open at a time, in the same look as
  quick settings. Some have views one click deeper (back or Escape returns):
  - **Notifications inbox** (Arch chip, SUPER + I): notifications as cards with their actions, a
    dismiss button and how long ago; Do Not Disturb and Clear all in the header. J/K to move,
    Enter to open, X to dismiss.
  - **Tools** (wrench, SUPER + X): pick a colour (recent ones as swatches) and read text from the
    screen; a clipboard card that recognises a JWT, JSON, base64 or URL-encoded text and offers
    the fitting transform (format JSON, decode a JWT into its own view with its expiry, base64
    and URL encode and decode); UUID, ISO and Unix time and lorem ipsum, a click copies them;
    your local dev servers, with a QR code to open one on the phone.
  - **Pomodoro**: the time left in a ring, the phase in its colour, this round's sessions, and
    the focus and break lengths.
  - **Screen recording**: desktop and mic audio, two tracks, frame rate and quality, then Start;
    while recording, the time, Pause and Stop and save.
  - **Phone** (KDE Connect through `kcd`): battery and network, ring it, send the clipboard or a
    file, browse its files, its notifications with Reply and Copy code, and its settings as a
    view.
- **Corner widget**: CPU, memory and disk rings in the frame's bottom-right corner, under the
  windows.
- **Settings panel** (SUPER + comma, or Settings in quick settings): four sections with a summary
  of each, Look (gaps, border, the frame and its corners, the corner widget's screen, terminal
  opacity, blur, animations), Input (keyboard repeat, pointer, touchpad), Bar & island (clock,
  bars on other screens, workspaces per screen, media in the island) and Power (idle lock,
  screens off and sleep times). Changes apply at once.
- **Shortcuts overlay** (SUPER + F1), read live from Hyprland, plus tmux and Neovim.
- **Wallpaper colours**: an image or a video wallpaper sets the palette for Hyprland,
  Quickshell, Alacritty, tmux, Neovim, fish, fzf, `ls` colours, cava, fastfetch, peaclock, GTK,
  Vicinae, satty, VS Code, Obsidian, Spotifast, Strata, the mouse cursor, the Legion keyboard
  RGB, the login screen, GRUB and Plymouth.
- **Video wallpapers** with mpvpaper, paused on battery, under fullscreen windows and while
  locked.
- **Lock and login screens** in Quickshell (greetd), with an entrance animation at login and
  after unlocking.
- **Per-screen workspaces** via [hyprsplit](https://github.com/shezdy/hyprsplit): SUPER + 1–N
  always means "this screen's workspace N".
- Binds use keycodes, so they keep working in any keyboard layout (it was built with
  US + Arabic).

## Requirements

- Arch Linux (the package lists are pacman and AUR names).
- Hyprland 0.56 or newer: the config is the Lua format (`hyprland.lua`), not `hyprland.conf`.
- Quickshell 0.3.
- The repo must be cloned to **`~/dotfiles`**. The lock screen's PAM file and a few scripts
  look for it there.

## Install

> Read the configs before installing them, and back up your own: `stow` links over your home
> folder.

1. **Clone with the submodules** (hyprsplit, tpm, tmux and Neovim plugins):

   ```sh
   sudo pacman -S --needed git base-devel
   git clone --recursive https://github.com/redcodemohammed/dotfiles ~/dotfiles
   cd ~/dotfiles
   ```

2. **Packages.** Repo packages first, then yay (if you don't have it), then the AUR ones. Read
   each PKGBUILD before installing: `vicinae-bin` sets a capability on its input server and
   loads `uinput`, and Vicinae needs a secrets provider (pick gnome-keyring).

   ```sh
   grep -v -e "^#" -e "^$" packages/repo.txt | sudo pacman -S --needed -
   git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin && (cd /tmp/yay-bin && makepkg -si)
   yay -S --needed $(grep -v -e "^#" -e "^$" packages/aur.txt)
   ```

3. **Your screens.** Copy the example and fill it in from `hyprctl monitors` (outputs, modes,
   positions, scale, which screen is the main one, and the workspace order). `monitors.lua` is
   gitignored, so each machine keeps its own. Without it, the example is used.

   ```sh
   cp .config/hypr/monitors_example.lua .config/hypr/monitors.lua
   ```

4. **Link the configs.** Do a dry run first. `stow` refuses to replace real files: move each
   conflict aside, then run it for real. Don't use `--adopt`: it moves your file into the repo
   in place of this one.

   ```sh
   stow -n -v -R .
   stow -v -R .
   ```

5. **Generate the colours** before the first login. The generated files aren't in git.

   ```sh
   python3 palette/generate.py
   ```

6. **Log in to Hyprland**, then run the health check. It changes nothing and says how to fix
   anything that fails.

   ```sh
   setup/check.sh
   ```

### Optional system parts

Each of these is a script run with sudo from `~/dotfiles`. Read it first: they write outside
your home folder.

| What | Command | Notes |
| --- | --- | --- |
| Login screen (greetd + Quickshell) | `sudo greeter/install.sh` | Installs only. Test it on terminal 7 with the command it prints, then `sudo systemctl enable greetd`. |
| GRUB theme | `sudo grub/install.sh` | Keeps `/etc/default/grub.pre-hypr-theme` and `/boot/grub/grub.cfg.pre-hypr-theme`. |
| Boot splash (Plymouth) | `sudo plymouth/install.sh` | Adds the `plymouth` hook and `splash`, rebuilds the initramfs. Keeps `*.pre-plymouth` copies. |
| VS Code theme | `vscode/install.sh` | No sudo. Installs into every profile; later wallpaper changes update it. |
| strongSwan without sudo | `sudo install -m644 strongswan/charon-group.conf /etc/strongswan.d/` | Then create a `vpn` group and add yourself to it. |
| Lenovo Legion keyboard RGB | `yay -S l5p-keyboard-rgb-bin`, then `systemctl --user enable --now legion-kb.service` | Legion laptops only. The keyboard follows the accent colour. |
| OpenRGB keyboard and mouse in the accent | `sudo install -m644 udev/90-rgb-*.rules /etc/udev/rules.d/ && sudo udevadm control --reload` | Written for an AULA F87 Pro and an Instant USB mouse (`openrgb-kb.service`, `openrgb-mouse.service`); change the IDs and names for yours. |
| Caps Lock as Escape / Ctrl (keyd) | `sudo install -Dm644 keyd/default.conf /etc/keyd/default.conf` | Copy it, don't link it: keyd runs as root. |

After a wallpaper change, `boot-colours` re-runs the greeter, GRUB and Plymouth scripts so the
boot screens match. You'll get a notification when they're out of date.

## Wallpaper and colours

- `wallpaper-pick` (or the Wallpaper entry in Vicinae) chooses an image or a video.
  `wallpaper-apply <file>` does the same from a terminal. `wallpaper-apply --default` goes back
  to the hand-made palette.
- `palette/from-wallpaper.py` picks the colours from the image (or one frame of a video) in
  OKLCH and writes `palette/palette.toml`.
- `palette/generate.py` fills the templates in `palette/templates/` (`{{role}}` and
  `{{rgb:role}}` placeholders) and writes every app's colour file. Without a `palette.toml`, it
  uses `palette/palette-default.toml`.
- Videos play through mpvpaper on every screen. `wallpaper-start` picks hyprpaper or mpvpaper at
  login.
- `vicinae-extensions/wallpaper-search` is a Vicinae extension that searches Wallhaven and sets
  the result. Build it with `npm install && npm run build` inside its folder.

## Keybinds

SUPER + F1 shows all of them, always up to date. The main ones:

| Keys | Action |
| --- | --- |
| SUPER + Return | Terminal (Alacritty with tmux) |
| SUPER + Shift + Return | Terminal without tmux |
| SUPER + / | Launcher (Vicinae) |
| SUPER + Q | Close the window |
| SUPER + V | Float the window |
| SUPER + N / M | Fullscreen / maximise |
| SUPER + H J K L or arrows | Focus (add Shift to move the window) |
| SUPER + Ctrl + arrows | Resize |
| SUPER + 1–N | This screen's workspace N (add Shift to send the window; 0 is the 10th) |
| SUPER + Shift + , / . | Window to the screen on the left / right |
| SUPER + I | Notifications |
| SUPER + X | Tools |
| SUPER + , | Settings |
| SUPER + F1 | Shortcuts |
| SUPER + P | Pomodoro start / pause |
| SUPER + R | Record the screen |
| SUPER + F | Files (Strata) |
| SUPER + E | Android emulator |
| Print / SUPER + Print / SUPER + Shift + Print | Screenshot a region / the window / the screen |
| SUPER + Ctrl + Print | Annotate the last screenshot |
| SUPER + Space | Switch keyboard layout |
| SUPER + Escape | Lock |
| SUPER + Shift + Escape | Log out |

tmux uses Ctrl + Space as its prefix.

## Recovery

- **Hyprland won't start**: Ctrl + Alt + F2, log in, and fix it (`hyprctl configerrors` shows
  config errors; the config is in git, so `git diff` and revert). `boot-restore` undoes the login
  screen, GRUB theme and Plymouth, and gives you a plain text login that starts Hyprland.
- **The lock screen crashed** (Hyprland says the lock screen died; the session stays locked):
  from another TTY or SSH, start it again and unlock with it:
  `hyprctl dispatch 'hl.dsp.exec_cmd("qs -p ~/.config/quickshell-lock")'`.
  Or: `hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'`.
  The lock uses your normal login checks, including `pam_faillock`: three wrong passwords lock
  you out for ten minutes.
- **The bar didn't pick up a change**: Quickshell's live reload sometimes keeps the old code.
  Restart it: `pkill -x qs`, then `hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`.
- **Undo the GRUB theme**: copy `/etc/default/grub.pre-hypr-theme` back to `/etc/default/grub`,
  then `sudo grub-mkconfig -o /boot/grub/grub.cfg`.
- **Undo Plymouth**: copy the `.pre-plymouth` backups of `/etc/mkinitcpio.conf` and
  `/etc/default/grub` back, then `sudo mkinitcpio -P` and
  `sudo grub-mkconfig -o /boot/grub/grub.cfg`. To skip the splash once, press `e` in GRUB and
  delete `splash`.

## Layout

| Path | What |
| --- | --- |
| `.config/hypr/` | Hyprland (`hyprland.lua`, `monitors_example.lua`), hypridle, hyprpaper, hyprsplit |
| `.config/quickshell/` | The shell: frame, bar, island, quick settings, panels, settings |
| `.config/quickshell-lock/` | The lock screen |
| `.local/bin/` | Helper scripts (wallpaper, screenshots, recording, boot colours…) |
| `palette/` | Colour extraction, generator and templates |
| `greeter/`, `grub/`, `plymouth/` | Login screen and boot themes (installed with sudo) |
| `pam/` | The lock screen's own PAM file (`/etc/pam.d` is never edited) |
| `packages/` | Package lists |
| `setup/check.sh` | Health check |
| `docs/` | The original design spec and design system |

`.stow-local-ignore` keeps the repo-only folders out of your home folder.

## License

MIT, see [LICENSE](LICENSE). The submodules (hyprsplit, tpm, the tmux and Neovim plugins) keep
their own licenses.

#!/usr/bin/env bash
# grub/install.sh (run with sudo from ~/dotfiles): the GRUB menu theme in the palette's colours
# (owner's choice, 2026-10-15). Builds it with make-theme.py into /boot/grub/themes/hypr, points
# GRUB_THEME at it in /etc/default/grub and regenerates /boot/grub/grub.cfg. Run it again after a
# wallpaper change. The first run keeps /etc/default/grub.pre-hypr-theme and
# /boot/grub/grub.cfg.pre-hypr-theme. Undo: copy the first back, then grub-mkconfig -o /boot/grub/grub.cfg (README).
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "grub/install.sh: run it with sudo" >&2; exit 1; }
src=$(cd "$(dirname "$0")" && pwd)
dots=$(dirname "$src")
dest=/boot/grub/themes/hypr

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
python3 -I "$src/make-theme.py" "$tmp" "$dots/palette/palette.toml"
rm -rf "$dest"
mkdir -p "$dest"
cp -r "$tmp"/* "$dest"/  # -r: icons/

[ -e /etc/default/grub.pre-hypr-theme ] || cp -p /etc/default/grub /etc/default/grub.pre-hypr-theme
[ -e /boot/grub/grub.cfg.pre-hypr-theme ] || cp -p /boot/grub/grub.cfg /boot/grub/grub.cfg.pre-hypr-theme
set_key() { # set_key KEY VALUE: replace the active KEY= line, or add one; commented lines stay
    if grep -qE "^$1=" /etc/default/grub; then
        sed -i -E "s|^$1=.*|$1=$2|" /etc/default/grub
    else
        printf '%s=%s\n' "$1" "$2" >> /etc/default/grub
    fi
}
set_key GRUB_THEME "\"$dest/theme.txt\""
# GRUB 2.16's 31_efi_bootnext adds 7 "EFI BootNext" entries (PXE, USB, DVD...); the owner keeps the
# four entries the box is sized for. USB or network boot: the firmware's own boot menu.
set_key GRUB_DISABLE_BOOTNEXT true
grub-mkconfig -o /boot/grub/grub.cfg
echo "Installed: $dest (reboot to see it)"

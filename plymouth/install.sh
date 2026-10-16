#!/usr/bin/env bash
# plymouth/install.sh (run with sudo from ~/dotfiles): the boot splash in the palette's colours
# (owner's choice, 2026-10-15). Builds it with make-theme.py into /usr/share/plymouth/themes/hypr,
# makes it the default, puts the plymouth hook after systemd in /etc/mkinitcpio.conf, adds
# `splash` to GRUB's kernel line, rebuilds the initramfs and grub.cfg. Run it again after a
# wallpaper change. The first run keeps *.pre-plymouth copies of /etc/mkinitcpio.conf,
# /etc/default/grub and the initramfs images; undo steps are in HANDOFF.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "plymouth/install.sh: run it with sudo" >&2; exit 1; }
src=$(cd "$(dirname "$0")" && pwd)
dots=$(dirname "$src")
dest=/usr/share/plymouth/themes/hypr

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
python3 -I "$src/make-theme.py" "$tmp" "$dots/palette/palette.toml"
rm -rf "$dest"
install -d -m 755 "$dest"
install -m 644 "$tmp"/* "$dest"/

backup() { [ -e "$1.pre-plymouth" ] || cp -p "$1" "$1.pre-plymouth"; }
backup /etc/mkinitcpio.conf
backup /etc/default/grub
for img in /boot/initramfs-*.img; do backup "$img"; done

# The hook, once, right after `systemd` (it brings plymouth's systemd units into the initramfs).
if ! grep -qE '^HOOKS=\(.*\bplymouth\b' /etc/mkinitcpio.conf; then
    sed -i -E 's/^(HOOKS=\(.*\bsystemd\b)/\1 plymouth/' /etc/mkinitcpio.conf
fi
grep -qE '^HOOKS=\(.*\bsystemd plymouth\b' /etc/mkinitcpio.conf || { echo "plymouth hook not placed, see /etc/mkinitcpio.conf" >&2; exit 1; }

# `splash` on the kernel line, once.
if ! grep -qE '^GRUB_CMDLINE_LINUX_DEFAULT=".*\bsplash\b' /etc/default/grub; then
    sed -i -E 's/^(GRUB_CMDLINE_LINUX_DEFAULT=".*)"$/\1 splash"/' /etc/default/grub
fi

plymouth-set-default-theme hypr
mkinitcpio -P
grub-mkconfig -o /boot/grub/grub.cfg
echo "Installed: $dest (reboot to see it)"

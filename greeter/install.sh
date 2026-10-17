#!/usr/bin/env bash
# greeter/install.sh: copy the Quickshell greeter into /etc/greetd (run with sudo from ~/dotfiles).
# The greeter user can't read ~, so everything is copied, Theme.qml and Icons.qml included: run it
# again after a wallpaper change to give the login screen the new colours (boot-colours does). The
# mouse cursor theme is built from the palette into /usr/share/icons/hypr-cursors. Enables nothing.
set -euo pipefail
src=$(cd "$(dirname "$0")" && pwd)
dots=$(dirname "$src")

install -d -m 755 /etc/greetd/quickshell-greeter
# The login user: whoever runs this with sudo (the greeter shows one user, no user list).
user=${SUDO_USER:-${GREETER_USER:-}}
[ -n "$user" ] && [ "$user" != root ] || { echo "run with sudo as the user who logs in (or set GREETER_USER)" >&2; exit 1; }
sed "s|@USER@|$user|" "$src/shell.qml" >/tmp/greeter-shell.qml.$$
install -m 644 /tmp/greeter-shell.qml.$$ /etc/greetd/quickshell-greeter/shell.qml
rm -f /tmp/greeter-shell.qml.$$
install -m 644 "$src/GreeterContent.qml" /etc/greetd/quickshell-greeter/
install -m 644 "$dots/.config/quickshell/Theme.qml" "$dots/.config/quickshell/Icons.qml" /etc/greetd/quickshell-greeter/
install -m 644 "$src/hyprland.lua" /etc/greetd/hyprland-greeter.lua
install -m 644 "$dots/.config/hypr/hypr_palette.lua" /etc/greetd/hypr_palette.lua
install -m 644 "$dots/.config/hypr/monitors.lua" /etc/greetd/monitors.lua
python3 -I "$dots/palette/cursors.py" --dest /usr/share/icons/hypr-cursors
install -m 644 "$src/greetd.toml" /etc/greetd/quickshell-greeter.toml
install -m 644 "$src/greetd-test.toml" /etc/greetd/quickshell-greeter-test.toml
install -d -m 700 -o greeter -g greeter /var/lib/quickshell-greeter
install -d -m 755 /etc/systemd/system/greetd.service.d
install -m 644 "$src/greetd-dropin.conf" /etc/systemd/system/greetd.service.d/quickshell-greeter.conf
systemctl daemon-reload
if systemctl is-enabled --quiet greetd.service; then
    echo "Installed: the login screen uses it from the next login."
else
    echo "Installed. Nothing enabled. Test on terminal 7:"
    echo "  sudo greetd --vt 7 -s /run/greetd-test.sock -c /etc/greetd/quickshell-greeter-test.toml"
fi

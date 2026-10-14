#!/usr/bin/env bash
# Read-only health check of the setup. Changes nothing. Run inside the Hyprland session.
D="$HOME/dotfiles"; fail=0
pass() { echo "ok    $*"; }
bad()  { echo "FAIL  $*"; fail=1; }

echo "== packages"
for p in $(grep -hv -e '^#' -e '^$' "$D/packages/repo.txt" "$D/packages/aur.txt"); do
    pacman -Q "$p" >/dev/null 2>&1 && pass "$p" || bad "$p not installed"
done

echo "== links (stow: the repo mirrors \$HOME, so ~/X must resolve to $D/X)"
# gtk-3.0 and gtk-4.0 are left out while COSMIC owns gtk.css (see .stow-local-ignore).
for p in .config/hypr .config/quickshell .config/quickshell-lock .config/alacritty .config/nvim \
         .config/tmux .config/vicinae .config/satty .local/share/vicinae/themes/hypr.toml .local/bin/island-build; do
    [ "$(readlink -f "$HOME/$p")" = "$D/$p" ] && pass "~/$p" || bad "~/$p should resolve to $D/$p (cd $D && stow -R .)"
done
[ "$(readlink /etc/keyd/default.conf)" = "$D/keyd/default.conf" ] && pass "/etc/keyd/default.conf" || bad "/etc/keyd/default.conf should link to $D/keyd/default.conf (sudo, see HANDOFF.md)"

echo "== submodule"
[ -f "$D/.config/hypr/hyprsplit/init.lua" ] && pass "hyprsplit present" || bad "hyprsplit missing: git -C $D submodule update --init"

echo "== generated files match palette.toml"
before=$(git -C "$D" status --porcelain)
python3 -I "$D/palette/generate.py" >/dev/null
after=$(git -C "$D" status --porcelain)
[ "$before" = "$after" ] && pass "generated files up to date" || bad "generate.py changed files: review git diff"

echo "== services"
systemctl is-enabled keyd >/dev/null 2>&1 && pass "keyd enabled" || bad "keyd not enabled"
systemctl is-active keyd >/dev/null 2>&1 && pass "keyd active" || bad "keyd not running"
pactl info >/dev/null 2>&1 && pass "pipewire-pulse answers" || bad "pactl cannot connect"

echo "== session (inside Hyprland only)"
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    [ -z "$(hyprctl configerrors)" ] && pass "hyprland config: no errors" || bad "hyprctl configerrors not empty"
    pgrep -x qs >/dev/null && pass "quickshell running" || bad "quickshell (qs) not running"
    pgrep -x hypridle >/dev/null && pass "hypridle running" || bad "hypridle not running"
    pgrep -f polkit-gnome-authentication-agent >/dev/null && pass "polkit agent running" || bad "polkit agent not running"
    pgrep -f vicinae-server >/dev/null && pass "vicinae server running" || bad "vicinae server not running"
    [ "$(gsettings get org.gnome.desktop.interface color-scheme)" = "'prefer-dark'" ] && pass "gsettings dark" || bad "gsettings color-scheme not prefer-dark"
else
    echo "skip  not inside a Hyprland session"
fi
exit $fail

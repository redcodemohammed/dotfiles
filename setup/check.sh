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
for p in .config/hypr .config/quickshell .config/quickshell-lock .config/alacritty .config/nvim \
         .config/tmux .config/vicinae/hypr.jsonc .config/satty .config/uwsm .local/share/vicinae/themes/hypr.toml .local/bin/island-build \
         .local/bin/wallpaper-apply .local/bin/wallpaper-pick .local/share/applications/wallpaper-pick.desktop \
         .config/gtk-3.0/gtk.css .config/gtk-4.0/gtk.css .local/share/applications/nvim-alacritty.desktop; do
    [ "$(readlink -f "$HOME/$p")" = "$D/$p" ] && pass "~/$p" || bad "~/$p should resolve to $D/$p (cd $D && stow -R .)"
done

# Vicinae's settings.json is copied, not linked (it rewrites it): it only has to import hypr.jsonc.
grep -q '"hypr.jsonc"' "$HOME/.config/vicinae/settings.json" 2>/dev/null && pass "vicinae settings.json imports hypr.jsonc" \
    || bad "vicinae settings.json doesn't import hypr.jsonc (cp $D/.config/vicinae/settings.json ~/.config/vicinae/)"

echo "== submodule"
[ -f "$D/.config/hypr/hyprsplit/init.lua" ] && pass "hyprsplit present" || bad "hyprsplit missing: git -C $D submodule update --init"

echo "== generated files match palette.toml (they are not in git: compared by hash)"
gen() { python3 -I -c 'import re,sys; t=open(sys.argv[1]).read(); s=t[t.index("OUTPUTS = {"):]; print("\n".join(re.findall(r"\"([^\"]+)\":", s[:s.index("}")])))' "$D/palette/generate.py"; }
before=$(cd "$D" && gen | xargs -r sha256sum 2>/dev/null)
python3 -I "$D/palette/generate.py" >/dev/null
after=$(cd "$D" && gen | xargs -r sha256sum 2>/dev/null)
[ "$before" = "$after" ] && pass "generated files up to date" || pass "generated files were stale: regenerated"

echo "== services"
pactl info >/dev/null 2>&1 && pass "pipewire-pulse answers" || bad "pactl cannot connect"

echo "== session (inside Hyprland only)"
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    [ -z "$(hyprctl configerrors)" ] && pass "hyprland config: no errors" || bad "hyprctl configerrors not empty"
    pgrep -x qs >/dev/null && pass "quickshell running" || bad "quickshell (qs) not running"
    pgrep -x hypridle >/dev/null && pass "hypridle running" || bad "hypridle not running"
    pgrep -x hyprpaper >/dev/null && pass "hyprpaper running" || bad "hyprpaper not running"
    pgrep -f polkit-gnome-authentication-agent >/dev/null && pass "polkit agent running" || bad "polkit agent not running"
    pgrep -f vicinae-server >/dev/null && pass "vicinae server running" || bad "vicinae server not running"
    [ "$(gsettings get org.gnome.desktop.interface color-scheme)" = "'prefer-dark'" ] && pass "gsettings dark" || bad "gsettings color-scheme not prefer-dark"
else
    echo "skip  not inside a Hyprland session"
fi
exit $fail

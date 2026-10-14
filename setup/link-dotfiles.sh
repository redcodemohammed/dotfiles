#!/usr/bin/env bash
# Link the dotfiles into place. Run from anywhere; dotfiles must live at ~/dotfiles
# (the lock screen's PAM path and island-build expect it).
# Never deletes: an existing file or folder is moved to <path>.pre-dotfiles-<date> first.
# Prints what it does. Safe to re-run: correct links are left alone.
# /etc/keyd is NOT handled here (needs sudo; see HANDOFF.md).
set -euo pipefail

D="$HOME/dotfiles"
[ -d "$D/hypr" ] || { echo "expected dotfiles at $D" >&2; exit 1; }
stamp=$(date +%Y%m%d-%H%M%S)

link() { # link <source in dotfiles> <target>
    local src="$D/$1" dst="$2"
    if [ "$(readlink "$dst" 2>/dev/null)" = "$src" ]; then
        echo "ok      $dst"
        return
    fi
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        mv "$dst" "$dst.pre-dotfiles-$stamp"
        echo "backup  $dst -> $dst.pre-dotfiles-$stamp"
    fi
    ln -s "$src" "$dst"
    echo "link    $dst -> $src"
}

link hypr              "$HOME/.config/hypr"
link quickshell        "$HOME/.config/quickshell"
link quickshell-lock   "$HOME/.config/quickshell-lock"
link alacritty         "$HOME/.config/alacritty"
link nvim              "$HOME/.config/nvim"
link tmux              "$HOME/.config/tmux"
link vicinae           "$HOME/.config/vicinae"
link vicinae/themes    "$HOME/.local/share/vicinae/themes"   # a real folder here hides the theme (VM gotcha)
link satty             "$HOME/.config/satty"
link gtk-3.0           "$HOME/.config/gtk-3.0"
link gtk-4.0           "$HOME/.config/gtk-4.0"
link bin/island-build  "$HOME/.local/bin/island-build"

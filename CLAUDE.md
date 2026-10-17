# CLAUDE.md: Hyprland desktop build (real machine)

Owner: Mohammed Wisam. Arch Linux, fish, tmux (prefix Ctrl+Space), Neovim. Three screens: main external, right external, laptop.

## Source of truth
`spec/hyprland-design-spec.md` wins over everything else. `spec/hyprland-island-state-spec.md` covers the bar-centre island (build it after the bars work). `design-system/` is visual reference only: its text is STALE on tooling (it still says Waybar, Mako, hyprlock). Quickshell replaces Waybar, Mako, swayosd and hyprlock. Tokens, geometry and colors in the design system are still right.

## How to work
- One change per step. Show the change, explain what to check, wait for "works" before the next step.
- Follow the build order in the spec ("Stack and build order"). Do not skip ahead.
- Before writing any config, verify syntax, option names and package names against current docs (Hyprland wiki, Quickshell docs, Arch repos/AUR). Names shift between releases. If you cannot verify, say so and mark it unverified.
- Configs live in `~/dotfiles`, symlinked into place. Commit after each working step.
- No Alt binds. SUPER only. Letter and symbol binds use keycodes (`code:NN`, find with `wev`), so the Arabic layout never breaks them.

## Safety rules (real machine)
1. First: `pacman -Qqe > pkglist-before.txt`. If root is btrfs, snapshot before starting.
2. COSMIC was removed (owner, 2026-10-17): Hyprland is the only desktop. If it won't start: Ctrl+Alt+F2, log in, fix, or run `boot-restore` (a plain text login that starts Hyprland). No autologin.
3. Monitor config always keeps a catch-all fallback line so no screen goes black. Get real names from `hyprctl monitors`.
4. Never edit existing files in `/etc/pam.d`. The Quickshell lock screen gets its own new PAM file.
5. Lock screen is built LAST. Before every test: a second TTY already logged in, short timeout, work saved. `hyprlock` stays installed until the Quickshell lock is proven.
6. `keyd` is installed late. Stop command from a TTY: `sudo systemctl stop keyd`.
7. Pin plugin versions (`hyprsplit` via `hyprpm`). Run `hyprpm update` after every Hyprland upgrade. Keep a native fallback.
8. Save work often. A compositor crash ends the session.

## Style rules (all UI)
- 4px unit. Gaps: 4px between any two things, 0 at screen edges. Border 2px. Radius 0. Bar height 32px.
- Colors: bg `#111111`, surface `#1a1a1a`, border `#333333`, fg `#e6e6e6`, muted `#8a8a8a`, amber `#f5a524`, on-accent `#111111`, alert `#e5484d`.
- Amber means focus or unread, never caution. Red means live or failed only. State changes the glyph, not the color.
- Fonts: JetBrains Mono Nerd Font, Vazirmatn for Arabic. Icons: Phosphor Regular (Fill for active/alert), Papirus-Dark for app icons.
- Dark only. No transparency, no blur, no shadow.
- Keybinds, idle chain and workspace rules: see the spec. Do not invent new ones.

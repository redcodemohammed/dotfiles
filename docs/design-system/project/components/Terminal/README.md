Alacritty with tmux for splits and sessions, so the terminal has no tabs. Config is TOML with the palette in one shared file, imported (verify the import key). Neovim colors come from the same palette: no separate scheme.

- Background `bg`, no transparency. Foreground `fg`. Block cursor in `accent`. Selection in `surface-selected`, never amber. Padding `space-2`, no window decorations.
- Font JetBrains Mono, size matched to the bar. Arabic has no right-to-left shaping in most terminal emulators: test before relying on it.
- ANSI colors are `ansi-*`: muted, desaturated red, green, blue, magenta, cyan. Amber (`ansi-yellow`) takes the yellow slot: check it against compiler warnings. Bright variants are about 10% lighter. All text colors are at least 4.5:1 on `bg`.
- The ANSI hex values are proposed: the spec gives the rules, not the values. Tune on real output.

Vicinae, bound to SUPER + /. Centered horizontally, slightly above the vertical middle, on the focused monitor (verify Vicinae does this). `launcher-w` wide, `surface` background, `border-w` `border` outline, `radius-none`, no blur, no shadow.

- Search field: `search-h` tall, 16px magnifier in `fg-muted`, `accent` caret, `border-w` `border` divider below.
- Result rows: `row-h` tall, `space-3` right padding, no gaps between rows, 8 rows visible, then scroll. Content: 24px app icon (`app-icon`), `space-3` gap, title in `fg`, type tag in `fg-muted` on the right. The icon sits `space-2` from the row edge.
- Selection: `surface-selected` plus a `border-w` `accent` marker on the left edge. Never a full amber fill.
- App icons keep their own colors (Papirus-Dark theme). They are content, not chrome. The amber marker stays on the row edge, away from orange and yellow icons.
- Clipboard history and file search come from Vicinae. Missing icons fall back to a generic glyph: check how it looks.

The consumer provides the icon theme and the Vicinae theme file mapping these tokens.

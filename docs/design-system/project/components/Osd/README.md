swayosd shows volume, brightness and Caps Lock changes at bottom center on the focused monitor (verify). Same look as popups: `surface`, `border-w` `border`, `radius-none`, solid.

- Level bar: `fg` fill on a `border` track. `accent` stays off.
- Muted volume shows a speaker-slash glyph at 0, in the same gray.
- Brightness keys work on the laptop panel. External monitors may need DDC tooling: verify.

The consumer provides the swayosd server and its CSS mapping these tokens.

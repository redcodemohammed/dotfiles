Mako popups top-right, flush with the right edge, `space-1` below the bar, on the focused output. `popup-w` wide, `space-3` padding, `surface` background, `border-w` `border` outline, `radius-none`, solid.

- Content: 24px colored app icon on the left, title in `fg`, body in `fg-muted` truncated at 2 lines.
- Stack with `space-1` gaps, 3 visible at most. Timeout 5 seconds. Urgent stays until dismissed.
- Urgent changes the border to `alert`. Nothing else changes.
- Amber is not used: a notification is not focus. No progress bars, no sounds.
- Per-app rules quiet the chat apps. Write them with the Mako config.
- The inbox is a Vicinae extension opened with SUPER + I. Mako history is in memory and resets on restart: raise `max-history` to about 100. The Waybar unread count is `fg-muted` at zero, `accent` when unread.

The consumer provides the notification data and the app icons.

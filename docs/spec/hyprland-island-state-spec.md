# Hyprland Island: State Spec

Oct 13, 2026 · @Mohammed Wisam

## Principles

The island answers one question: what needs me right now? Everything else stays out.

- One island, one state at a time. Never stacked.
- Compact sits in the bar centre, 24px tall. Expanded grows from the same spot.
- Follows the Hyprland Desktop system: radius 0, flat, no shadow, no blur, no transparency.
- Amber means focus or unread. Red means live or failed. Nothing else gets colour.
- No weather, CPU, RAM or date. The system cuts them on purpose.
- Transient states leave alone. Persistent states stay until the user ends them.

## Geometry and tokens

Sizes are outer size in px, border included. Position is top 4px, horizontally centred on the main screen.

| State | Compact (w×h) | Expanded (w×h) |
| --- | --- | --- |
| Media | 280×24 | 440×256 |
| Notification | none | 360×232 (Arabic 360×144) |
| Volume | 260×24 | 340×140 |
| Recording | 240×24 | 340×172 |
| Battery | 260×24 | 340×148 |
| Next event | 280×24 | 340×128 |
| Build | 320×24 | 440×192 |

- Surface `#1a1a1a`. Border 2px `#333333`. Recording and failed build use `#e5484d`.
- Text: 13/16 compact, 14/20 title, 12/16 caption, JetBrains Mono. Arabic uses Vazirmatn 14/22.
- Padding 8 compact, 12 expanded. Gap 4 or 8. Buttons 40px tall, 2px border.
- Motion: width, height and margin animate 120ms linear. Contents swap instantly. No fade, no bounce.

## Priority and state machine

Transient events beat recording, and recording beats media. Only one shows.

1. Transient: notification, volume, battery, next event, build. The newest replaces the current one.
2. Recording. Persistent until stopped.
3. Media. Persistent while a player is playing.
4. Nothing. The island is hidden, not an empty pill.

Rules:

- A transient ends on its own timer. Expanding it cancels the timer.
- Closing an expanded transient dismisses it. Closing expanded media or recording returns to compact.
- When a transient ends, the island falls back to the next state in the list.
- Expansion is the user's choice. Notification is the one exception: it opens expanded.

## State table

| State | Trigger | Compact | Expanded | Ends |
| --- | --- | --- | --- | --- |
| Media | A player starts playing | Bars glyph, title, artist, elapsed | Art, album, source and output, progress, shuffle, repeat, prev, play, next, volume, up next ×2 | Player stops or quits |
| Notification | New notification | none (opens expanded) | Sender, time, amber unread count, 2-line body, Reply, Dismiss, Earlier ×2 | 8 s, or Dismiss. Urgent stays, red border |
| Volume | Volume key or change | Speaker, level bar, number | Output device, volume, mic, brightness bars | 2.5 s. Pinned while expanded |
| Recording | Recorder starts | Red dot, Recording or Paused, mm:ss, stop | Source, mic and system audio, size, Pause, Stop and save | User stops it |
| Battery | Plug, unplug, low threshold | Unplugged or Charging, percent, glyph | Percent bar, time left or to full, power profile picker | 3 s. Critical stays, red border |
| Next event | Calendar event near | Glyph, title, countdown | Time range, attendees, Join, Dismiss | 6 s in mock. Real timing open |
| Build | Build command finishes | Check or cross, project, time or error count | Last 4 output lines, Open terminal, Dismiss | 6 s. Failure stays until dismissed |

## Interaction

The island never takes keyboard focus from the active window. Pointer works, keys go through Hyprland binds.

- Click a compact island to expand it. Click the chevron to collapse.
- SUPER + I opens the notification inbox, already in your keymap.
- Proposed: SUPER + Escape collapses or dismisses the island.
- Media keys drive transport without opening anything.
- Button hover uses `surface-selected`. No tooltips, no other hover effect.
- The island floats above windows. Windows never reflow around it.
- True fullscreen (SUPER + N) hides the island, same as the bar.

## Data sources

As far as I know, Quickshell ships services for most of these. Verify each against its docs before building.

| State | Source |
| --- | --- |
| Media | MPRIS over D-Bus |
| Volume, mic | PipeWire |
| Brightness | brightnessctl or sysfs backlight |
| Battery | UPower |
| Power profile | power-profiles-daemon |
| Notifications | Quickshell notification server, or mirror Mako over D-Bus |
| Recording | gpu-screen-recorder process plus a state file |
| Next event | Small poller on Google Calendar writing the next event |
| Build | Shell hook that calls the island over Quickshell IPC |

## Arabic and multi-monitor

- Island chrome stays centred and unmirrored. Only the content flips.
- Arabic notifications set `dir=rtl`, Vazirmatn, 22px line height. Times stay 24h.
- Track and window text uses `dir=auto`, so Arabic titles align correctly.
- The island shows on the main screen only, the one with the full bar.
- Slim-bar screens (right, laptop) show no island.
- Laptop alone becomes the main screen and gets the island, matching the full-bar rule.

## Open decisions and build order

Biggest call: the island overlaps Mako popups and SwayOSD in your current plan. Running both double-fires. I'd replace both, run notifications through the island's own server, and point the Vicinae history extension at its store.

Open:

- Arabic notification is 144px tall, English 232px. Give Arabic the same Earlier list.
- A transient arrives while you have another expanded. Options: replace it, queue it, or show nothing. I'd queue one.
- Paused media: hide after 30 s, or stay forever.
- Next event timing: show at 10 minutes before, again at 1 minute until you Join or Dismiss.
- Urgent notification and critical battery (10% or less): persistent, red border.
- Fullscreen: hide everything, or let urgent through.
- Pin to the main screen, or follow the active monitor.

Build order:

1. Shell: layer window, size animation, state priority.
2. Media.
3. Volume, replacing SwayOSD.
4. Notifications, replacing Mako.
5. Recording.
6. Battery.
7. Next event.
8. Build hook.

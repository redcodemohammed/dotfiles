# Desktop layout

## Monitors and bars

Three screens. Every bar sits on top. No vertical bars. Main gets the full bar. The others get slim bars.

| Screen | Position | Bar |
| --- | --- | --- |
| Main | Center | Full |
| Laptop | Left | Slim, plus battery and network |
| External right | Right | Slim, plus media |
| Laptop alone | Only screen | Full |
| Lid closed | Laptop gone | Its workspaces land on the survivor |

Full bar: workspaces 1 to 5, window title, clock (center), media while playing, tray (main bar only), mic and camera indicator, volume, network, Bluetooth, battery (laptop only), notification count and DND. Slim bars: workspaces, window title, clock, plus what the table adds.

## Hotplug

If only one screen exists, it gets the full bar. Hyprland alone cannot swap bar profiles: use `kanshi` or `hyprdynamicmonitors` (verify which works well on the current Hyprland). Test three states early: three screens, two screens, laptop alone.

## Workspaces

Per monitor: every screen has its own 1 to 5, and SUPER + 1 to 5 acts on the focused screen. Plugin: `hyprsplit` through `hyprpm` (verify support for the installed Hyprland). Pin versions, run `hyprpm update` after each upgrade, keep a native fallback. The Waybar workspace module may show offset IDs: test early. Verify what happens to windows when a monitor disconnects. Test lid close on real hardware.

## Lock and idle

`hyprlock` for the lock screen, `hypridle` for timing. Starting values: lock at 5 minutes, screens off at 6, suspend at 30 on battery only. Lock before any sleep, lid close included. Lid close with externals attached must not suspend. If the laptop panel is OLED, dim to near-black and turn screens off quickly.

## Night light and OSD

`hyprsunset` on an evening to morning schedule: a warm filter shifts every color, amber and grays included, so check the palette under it before finalizing. `swayosd` for volume, brightness and Caps Lock.

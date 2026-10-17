pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Pauses a video wallpaper (mpvpaper, .local/bin/wallpaper-start) on battery and while the
// screen is locked (owner, 2026-10-17), through mpv's socket. mpvpaper itself pauses it under a
// fullscreen window. Locked: Entrance.covered, set by the lock screen before it locks. Re-sent
// every 3 s while it should hold, since mpvpaper's own auto-pause can resume it (a fullscreen
// window closing). Nothing happens without a video: the socket isn't there.
Singleton {
    id: root
    readonly property bool hold: UPower.onBattery || Entrance.covered
    readonly property string socket: Quickshell.env("XDG_RUNTIME_DIR") + "/mpvpaper.sock"

    function send(paused) {
        Quickshell.execDetached(["sh", "-c",
            "[ -S \"$1\" ] && printf '{\"command\":[\"set_property\",\"pause\",%s]}\\n' \"$2\" | socat - \"$1\" >/dev/null 2>&1",
            "sh", socket, paused ? "true" : "false"])
    }

    onHoldChanged: send(hold)
    Timer {
        interval: 3000
        repeat: true
        running: root.hold
        triggeredOnStart: true
        onTriggered: root.send(true)
    }
}

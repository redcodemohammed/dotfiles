pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The desktop's entrance (owner, 2026-10-17): at login and after unlocking, the wallpaper fades up
// from the background colour (EntranceCover.qml) and the bar blocks drop in from above on the
// window spring, left to right (BarBlock.qml). A Quickshell reload doesn't play it: `played`
// lives in PersistentProperties, which keep their values across reloads but start fresh with a
// new process (a login). At login the sheet goes up first, then this starts hyprpaper under it
// and waits (up to 3 s) for its layer before playing: started by Hyprland next to Quickshell,
// hyprpaper won the race and the image showed, went black, then faded up (owner). hyprland.lua
// starts hyprpaper after 5 s if this never did. The lock screen calls `entrance cover` as soon as it locks (the sheet
// waits, opaque, under the lock: no race with the unlock, which once showed the wallpaper for a
// frame) and `entrance play` as it unlocks. While covered, a check every 2 s plays it anyway
// once the lock process is gone (a crash, an unlock by other means), so the wallpaper can never
// stay hidden.
// Off with Settings > Look > Animations.
Singleton {
    id: root
    property int run: 0 // goes up each time the entrance plays; the bars and covers watch it
    property bool covered: false // the sheet is up and waiting (the lock is on)

    function cover() {
        if (Settings.look.animations)
            covered = true
    }
    function play() {
        // The fade starts before `covered` drops: the other way round the sheet's window was
        // hidden for an instant and came back undrawn, which showed the wallpaper.
        if (Settings.look.animations)
            run++
        covered = false
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.covered
        onTriggered: lockCheck.running = true
    }
    Process {
        id: lockCheck
        // only real qs processes: `pgrep -f quickshell-lock` also matched editors and shells
        // with that path in their command line
        command: ["sh", "-c", "for p in $(pgrep -x qs); do tr '\\0' ' ' </proc/$p/cmdline | grep -q quickshell-lock && exit 0; done; exit 1"]
        onExited: (code) => { if (code !== 0 && root.covered) root.play() }
    }

    PersistentProperties {
        id: persist
        reloadableId: "entrance"
        property bool played: false
        onLoaded: {
            if (!played) {
                played = true
                root.covered = true // the sheet and the bars' hidden start, before anything is drawn
                wallpaperStart.start()
            }
        }
    }

    // Login: once the sheet is drawn, hyprpaper under it; play when its layer is there.
    Timer {
        id: wallpaperStart
        interval: 150
        onTriggered: {
            Quickshell.execDetached(["sh", "-c", "pgrep -x hyprpaper >/dev/null || exec setsid hyprpaper"])
            wallpaperWait.tries = 0
            wallpaperWait.start()
        }
    }
    Timer {
        id: wallpaperWait
        property int tries: 0
        interval: 100
        repeat: true
        onTriggered: {
            if (++tries > 30) { // 3 s: play anyway, the sheet must never stay
                stop()
                root.play()
            } else if (!layerCheck.running) {
                layerCheck.running = true
            }
        }
    }
    Process {
        id: layerCheck
        command: ["sh", "-c", "hyprctl layers | grep -q 'namespace: hyprpaper'"]
        onExited: (code) => {
            if (code === 0 && wallpaperWait.running) {
                wallpaperWait.stop()
                root.play()
            }
        }
    }

    IpcHandler {
        target: "entrance"
        function play(): void { root.play() }
        function cover(): void { root.cover() }
    }
}

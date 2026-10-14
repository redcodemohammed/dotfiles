import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pam

// Lock screen. Its own Quickshell instance, run by SUPER + Escape, so a crash here
// never takes the bar down and bar reloads never touch a running lock.
// PAM: ~/dotfiles/pam/quickshell-lock. Fallback: hyprlock (see hypr/hyprlock.conf).
ShellRoot {
    id: root

    // TEST MODE: unlocks by itself after this many seconds. Set to 0 once proven.
    readonly property int failsafeSeconds: 60

    property string password: ""
    property bool checking: false
    property bool wrong: false
    property string layout: ""
    property int failsafeLeft: failsafeSeconds

    function submit() {
        if (checking || password === "")
            return
        checking = true
        wrong = false
        pam.start()
    }

    function unlock() {
        lock.locked = false
        quitTimer.start() // let the compositor see the unlock before the process exits
    }

    WlSessionLock {
        id: lock
        locked: true

        WlSessionLockSurface {
            color: Theme.bg
            LockContent {
                anchors.fill: parent
                shell: root
            }
        }
    }

    PamContext {
        id: pam
        configDirectory: "/home/dev/dotfiles/pam"
        config: "quickshell-lock"
        onPamMessage: {
            if (responseRequired)
                respond(root.password)
        }
        onCompleted: result => {
            root.checking = false
            if (result === PamResult.Success) {
                root.unlock()
            } else {
                root.wrong = true
                root.password = ""
            }
        }
        onError: err => {
            console.warn("lock: PAM error:", PamError.toString(err))
            root.checking = false
            root.wrong = true
            root.password = ""
        }
    }

    // Layout label: read once, then follow Hyprland's activelayout events.
    Process {
        running: true
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                const main = JSON.parse(text).keyboards.find(k => k.main)
                if (main)
                    root.layout = main.active_keymap
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout")
                root.layout = event.data.split(",").slice(1).join(",")
        }
    }

    Timer {
        running: root.failsafeSeconds > 0
        interval: 1000
        repeat: true
        onTriggered: {
            root.failsafeLeft -= 1
            if (root.failsafeLeft <= 0) {
                console.warn("lock: test-mode failsafe unlock")
                root.unlock()
            }
        }
    }

    Timer {
        id: quitTimer
        interval: 200
        onTriggered: Qt.quit()
    }
}

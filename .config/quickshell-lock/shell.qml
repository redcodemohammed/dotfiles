import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pam

// Lock screen. Its own Quickshell instance, run by SUPER + Escape, so a crash here
// never takes the bar down and bar reloads never touch a running lock.
// PAM: ~/dotfiles/pam/quickshell-lock. If it crashes, start it again: it takes over the lock
// (Hyprland's allow_session_lock_restore; HANDOFF section 7). hyprlock was removed 2026-10-15.
ShellRoot {
    id: root

    // Test mode: unlocks by itself after this many seconds. 0 = off (proven 2026-10-14).
    // Set it back above 0 before experimenting with this file.
    readonly property int failsafeSeconds: 0

    property string password: ""
    property bool checking: false
    property bool wrong: false
    property string layout: ""
    property bool capsLock: false // any keyboard; read at start and when Caps Lock is released

    function readKeyboards() {
        if (!keyboards.running)
            keyboards.running = true
    }
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
        configDirectory: Quickshell.env("HOME") + "/dotfiles/pam" // dotfiles must live at ~/dotfiles
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

    // Layout label and Caps Lock: read at start (and on Caps Lock), then the layout follows
    // Hyprland's activelayout events.
    Process {
        id: keyboards
        running: true
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const all = JSON.parse(text).keyboards
                    root.capsLock = all.some(k => k.capsLock)
                    const main = all.find(k => k.main)
                    if (main)
                        root.layout = main.active_keymap
                } catch (err) {
                    // No layout label is better than a broken lock screen.
                }
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

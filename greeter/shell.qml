import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Greetd

// Login screen (owner's choice, 2026-10-15): the lock screen's look on greetd. Runs as the greeter
// user inside a greeter-only Hyprland (/etc/greetd/hyprland-greeter.lua); installed to
// /etc/greetd/quickshell-greeter by greeter/install.sh. One user (mohammed), a session picker
// (/usr/share/wayland-sessions; the last one used is kept in $HOME = /var/lib/quickshell-greeter),
// Restart and Shut down. Session-lock surfaces cover every screen and take the keyboard on the
// focused one, like the lock. GREETER_TEST=1 (the test config, terminal 7): after a correct
// password it launches `true`, so login is proven without starting a second desktop.
ShellRoot {
    id: root
    readonly property string user: "mohammed"
    readonly property bool test: Quickshell.env("GREETER_TEST") === "1"
    readonly property string lastPath: Quickshell.env("HOME") + "/last-session"

    property string password: ""
    property bool checking: false
    property bool wrong: false
    property string message: "" // anything greetd or PAM says besides the password prompt
    property string layout: ""
    property bool capsLock: false

    property var sessions: [] // { name, exec, file }, Hyprland (uwsm) first
    property int sessionIndex: 0
    readonly property var session: sessions.length > 0 ? sessions[sessionIndex] : null
    property string lastFile: "hyprland-uwsm.desktop"

    function nextSession(step) {
        if (sessions.length > 0)
            sessionIndex = (sessionIndex + step + sessions.length) % sessions.length
    }
    function submit() {
        if (checking || password === "" || session === null)
            return
        if (!Greetd.available) {
            message = "greetd is not running"
            return
        }
        checking = true
        wrong = false
        message = ""
        Greetd.createSession(user)
    }
    function readKeyboards() {
        if (!keyboards.running)
            keyboards.running = true
    }

    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                Greetd.respond(root.password)
                return
            }
            if (message !== "")
                root.message = message
            Greetd.respond("") // greetd wants an answer to every message
        }
        function onAuthFailure(message) {
            root.checking = false
            root.wrong = true
            root.password = ""
        }
        function onError(error) {
            root.checking = false
            root.message = error
            Greetd.cancelSession()
        }
        function onReadyToLaunch() {
            lastSaver.setText(root.session.file)
            const command = root.test ? ["true"] : ["/bin/sh", "-c", "exec " + root.session.exec]
            lock.locked = false // no "lockscreen died" flash in the greeter's Hyprland
            Greetd.launch(command, ["XDG_SESSION_TYPE=wayland"], true)
        }
    }

    WlSessionLock {
        id: lock
        locked: true
        WlSessionLockSurface {
            color: Theme.bg
            GreeterContent {
                anchors.fill: parent
                shell: root
            }
        }
    }

    // Sessions: Name and Exec of every visible /usr/share/wayland-sessions/*.desktop.
    Process {
        running: true
        command: ["sh", "-c", 'for f in /usr/share/wayland-sessions/*.desktop; do grep -qiE "^(NoDisplay|Hidden)=true" "$f" && continue; n=$(sed -n "s/^Name=//p" "$f" | head -n 1); e=$(sed -n "s/^Exec=//p" "$f" | head -n 1); printf "%s\\t%s\\t%s\\n" "${f##*/}" "$n" "$e"; done']
        stdout: StdioCollector {
            id: sessionsOut
            onStreamFinished: {
                const list = []
                for (const line of sessionsOut.text.split("\n")) {
                    const f = line.split("\t")
                    if (f.length === 3 && f[2] !== "")
                        list.push({ file: f[0], name: f[1] || f[0], exec: f[2] })
                }
                list.sort((a, b) => (b.file === "hyprland-uwsm.desktop") - (a.file === "hyprland-uwsm.desktop"))
                root.sessions = list
                root.pickLast()
            }
        }
    }
    function pickLast() {
        const i = sessions.findIndex(s => s.file === lastFile)
        sessionIndex = i >= 0 ? i : 0
    }
    FileView {
        path: root.lastPath
        printErrors: false
        onLoaded: {
            const f = text().trim()
            if (f !== "") {
                root.lastFile = f
                root.pickLast()
            }
        }
    }
    FileView {
        id: lastSaver
        path: root.lastPath
        printErrors: false
    }

    // Layout label and Caps Lock, as in the lock screen.
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
                } catch (err) {}
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
}

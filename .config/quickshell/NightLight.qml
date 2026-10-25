pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Night light (owner, 2026-10-25: real colours for colour work): hyprsunset's warm evenings,
// switched off till the next morning by .local/bin/night-light. Quick settings has its tile;
// `qs ipc call nightlight toggle` for scripts. `on` is the setting, read back from the script at
// start and once a minute while off, so the morning turns it on again by itself.
Singleton {
    id: root
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/night-light"
    property bool on: true

    function set(value) {
        on = value
        Quickshell.execDetached([bin, value ? "on" : "off"])
    }

    Process {
        id: status
        running: true
        command: [root.bin, "status"]
        stdout: StdioCollector {
            onStreamFinished: root.on = text.trim() !== "off"
        }
    }
    Timer { // while off: has the morning come?
        interval: 60000
        repeat: true
        running: !root.on
        onTriggered: status.running = true
    }

    IpcHandler {
        target: "nightlight"
        function toggle(): void { root.set(!root.on) }
    }
}

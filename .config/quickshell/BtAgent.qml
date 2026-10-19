pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

// Runs .local/bin/bt-agent, the pairing agent (owner, 2026-10-17), for as long as the shell runs
// (restarted 5 s after it exits). Its questions land in `request` for the Bluetooth panel; a code
// to type on the device lands in `shown`. Nothing pairs unseen: a question that comes while the
// panel is closed is answered no.
Singleton {
    id: root
    property bool panelOpen: false   // set by BluetoothView (quick settings) while it is open
    property var request: null       // { kind: confirm|authorize|passkey|pin, address, code }
    property var shown: null         // { address, code }: type this on the device

    function nameOf(address) {
        const d = Bluetooth.devices.values.find(d => d.address === address)
        return d ? (d.name || d.deviceName || address) : address
    }
    function answer(text) {
        if (request === null)
            return
        request = null
        agent.write(text + "\n")
    }

    Process {
        id: agent
        running: true
        command: [Quickshell.env("HOME") + "/.local/bin/bt-agent"]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                const w = line.split(" ")
                if (w[0] === "show") {
                    root.shown = { address: w[1], code: w[2] }
                } else if (w[0] === "cancel") {
                    root.request = null
                    root.shown = null
                } else if (["confirm", "authorize", "passkey", "pin"].includes(w[0])) {
                    if (!root.panelOpen) {
                        agent.write("no\n")
                        return
                    }
                    root.request = { kind: w[0], address: w[1], code: w[2] ?? "" }
                }
            }
        }
        onExited: {
            root.request = null
            restart.start()
        }
    }
    Timer {
        id: restart
        interval: 5000
        onTriggered: agent.running = true
    }
}

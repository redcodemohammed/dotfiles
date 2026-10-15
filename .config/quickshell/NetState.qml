pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Network state shared by the bar's network block and the network panel (owner's design
// "Network manager", 2026-10-15).
// Internet, from NetworkManager's connectivity check (ping.archlinux.org): "ok", "portal"
// (sign-in required), "none" (no internet) or "down" (no link). While a portal waits for the
// sign-in it asks again every 5 s instead of NetworkManager's 5 minutes.
// Traffic of the device carrying the internet (the default route with the lowest metric): speed,
// sampled each second only while `watching` (the panel's Networks tab), and bytes used since that
// device's connection came up (owner's choice). Each device's counters are noted when it connects
// and kept in $XDG_RUNTIME_DIR/network-usage.json, so a shell reload keeps counting.
Singleton {
    id: root

    readonly property bool linkUp: Networking.devices.values.some(d => d.connected)
    readonly property string internet: !linkUp ? "down"
        : Networking.connectivity === NetworkConnectivity.Portal ? "portal"
        : Networking.connectivity === NetworkConnectivity.None
            || Networking.connectivity === NetworkConnectivity.Limited ? "none"
        : "ok"
    property bool checking: false
    function check() {
        checking = true
        Networking.checkConnectivity()
        checkDone.restart()
    }
    Timer {
        id: checkDone
        interval: 3000
        onTriggered: root.checking = false
    }
    Timer {
        running: root.internet === "portal"
        interval: 5000
        repeat: true
        onTriggered: Networking.checkConnectivity()
    }

    // Traffic
    property bool watching: false
    property string device: "" // the default route's device, while watching
    property real down: 0 // bytes per second
    property real up: 0
    property real used: 0 // bytes since the connection came up
    property var last: null // the previous sample: { device, rx, tx, at }

    function rate(bytes) {
        return (bytes / 1048576).toFixed(1) + " MB/s"
    }
    function amount(bytes) {
        const mb = bytes / 1048576
        return mb >= 1024 ? (mb / 1024).toFixed(2) + " GB" : Math.round(mb) + " MB"
    }

    function sample(line) {
        const f = line.trim().split(" ")
        if (f.length < 3) {
            device = ""
            last = null
            return
        }
        const rx = Number(f[1])
        const tx = Number(f[2])
        const now = Date.now()
        if (last !== null && last.device === f[0] && now > last.at) {
            const dt = (now - last.at) / 1000
            down = Math.max(0, (rx - last.rx) / dt)
            up = Math.max(0, (tx - last.tx) / dt)
        } else {
            down = 0
            up = 0
        }
        device = f[0]
        last = { device: f[0], rx: rx, tx: tx, at: now }
        const base = bases[f[0]]
        if (base === undefined || base > rx + tx)
            setBase(f[0], rx + tx, false) // not noted yet, or the counters started over
        used = rx + tx - bases[f[0]]
    }

    Process {
        running: root.watching
        command: ["sh", "-c", '
            while :; do
                dev=; set -- $(ip route show default 2>/dev/null | head -n 1)
                while [ $# -gt 1 ]; do [ "$1" = dev ] && { dev=$2; break; }; shift; done
                s=/sys/class/net/$dev/statistics
                if [ -n "$dev" ] && [ -r "$s/rx_bytes" ]; then echo "$dev $(cat "$s/rx_bytes") $(cat "$s/tx_bytes")"; else echo -; fi
                sleep 1
            done']
        stdout: SplitParser {
            onRead: data => root.sample(data)
        }
        onRunningChanged: if (!running) root.last = null
    }

    // Each device's byte counters when its connection came up.
    property var bases: ({})
    property bool basesLoaded: false
    function setBase(name, bytes, keep) {
        if (keep && bases[name] !== undefined && bases[name] <= bytes)
            return // noted before a shell reload, still counting
        const b = Object.assign({}, bases)
        b[name] = bytes
        bases = b
        usageFile.setText(JSON.stringify(b))
    }
    FileView {
        id: usageFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/network-usage.json"
        printErrors: false
        onLoaded: {
            try {
                root.bases = JSON.parse(text())
            } catch (err) {}
            root.basesLoaded = true
        }
        onLoadFailed: root.basesLoaded = true
    }
    Instantiator {
        model: Networking.devices
        delegate: QtObject {
            id: tracker
            required property var modelData
            readonly property bool connected: modelData.connected
            readonly property bool armed: root.basesLoaded && connected
            property bool sawDown: false // seen disconnected by this shell: a connect is a new one
            property Process reader: Process {
                property bool keep: false
                command: ["sh", "-c", 'cat "/sys/class/net/$1/statistics/rx_bytes" "/sys/class/net/$1/statistics/tx_bytes"',
                    "sh", tracker.modelData.name]
                stdout: StdioCollector {
                    id: counters
                    onStreamFinished: {
                        const n = counters.text.trim().split("\n").map(Number)
                        if (n.length === 2 && !isNaN(n[0] + n[1]))
                            root.setBase(tracker.modelData.name, n[0] + n[1], tracker.reader.keep)
                    }
                }
            }
            function mark(keep) {
                reader.keep = keep
                reader.running = true
            }
            onConnectedChanged: if (!connected) sawDown = true
            onArmedChanged: if (armed) mark(!sawDown)
            Component.onCompleted: {
                sawDown = !connected
                if (armed)
                    mark(true)
            }
        }
    }
}

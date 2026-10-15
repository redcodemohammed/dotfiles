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
// VPN: the active VPN (NetworkManager VPN plugins or WireGuard), re-read on every change
// `nmcli monitor` reports; connect (one at a time) and disconnect for the panel. Connect on open
// Wi-Fi (owner's choice): when an open (or OWE) Wi-Fi network connects, bring up the last VPN
// used. Both kept in ~/.local/state/network/vpn.json.
Singleton {
    id: root

    // nmcli -t output: fields split by ':', a literal ':' or '\' escaped with '\'.
    function fields(line) {
        const out = [""]
        for (let i = 0; i < line.length; i++) {
            const c = line[i]
            if (c === "\\" && i + 1 < line.length)
                out[out.length - 1] += line[++i]
            else if (c === ":")
                out.push("")
            else
                out[out.length - 1] += c
        }
        return out
    }
    function unescaped(s) { // nmcli -g and one -t field
        return (s ?? "").replace(/\\(.)/g, "$1")
    }

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

    // VPN
    property string vpnUuid: "" // the active VPN, if any
    property string vpnName: ""
    property string vpnState: "" // activating, activated, deactivating
    readonly property bool vpnOn: vpnState === "activated"
    property bool vpnLoaded: false
    property string vpnBusy: "" // the VPN being connected from here
    property string vpnFailed: ""
    property string vpnFailText: ""
    function refreshVpn() {
        if (!vpnReader.running)
            vpnReader.running = true
    }
    function vpnUp(uuid) {
        vpnFailed = ""
        vpnBusy = uuid
        vpnSwitcher.target = uuid
        vpnSwitcher.command = ["sh", "-c", '
            [ -n "$2" ] && [ "$2" != "$1" ] && nmcli connection down uuid "$2" >/dev/null 2>&1
            out=$(nmcli --wait 30 connection up uuid "$1" 2>&1) || { printf "%s\n" "$out" | tail -n 1; exit 1; }
            echo ok', "sh", uuid, vpnUuid]
        vpnSwitcher.running = true
    }
    function vpnDown(uuid) {
        Quickshell.execDetached(["nmcli", "connection", "down", "uuid", uuid])
    }
    Process {
        id: vpnSwitcher
        property string target
        stdout: StdioCollector {
            id: vpnSwitchOut
            onStreamFinished: {
                const r = vpnSwitchOut.text.trim()
                root.vpnBusy = ""
                if (r === "ok") {
                    root.vpnLast = vpnSwitcher.target
                    root.saveVpnSettings()
                } else {
                    root.vpnFailed = vpnSwitcher.target
                    root.vpnFailText = r.replace(/^Error: /, "") || "Couldn't connect"
                }
                root.refreshVpn()
            }
        }
    }
    Process {
        id: vpnReader
        command: ["nmcli", "-t", "-f", "UUID,TYPE,STATE,NAME", "connection", "show", "--active"]
        stdout: StdioCollector {
            id: vpnOut
            onStreamFinished: {
                let found = null
                for (const line of vpnOut.text.split("\n")) {
                    const f = root.fields(line)
                    if (f.length >= 4 && (f[1] === "vpn" || f[1] === "wireguard")) {
                        found = f
                        break
                    }
                }
                root.vpnUuid = found ? found[0] : ""
                root.vpnState = found ? found[2] : ""
                root.vpnName = found ? found.slice(3).join(":") : ""
                if (!root.vpnLoaded) {
                    root.vpnLoaded = true
                    root.autoVpn()
                }
            }
        }
    }
    Process { // a line on every NetworkManager change
        id: monitor
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: _ => vpnDebounce.restart()
        }
        onExited: monitorRestart.start()
    }
    Timer {
        id: monitorRestart
        interval: 5000
        onTriggered: monitor.running = true
    }
    Timer {
        id: vpnDebounce
        interval: 300
        onTriggered: root.refreshVpn()
    }
    Component.onCompleted: refreshVpn()

    // Connect on open Wi-Fi
    readonly property string vpnSettingsPath: Quickshell.env("HOME") + "/.local/state/network/vpn.json"
    property bool vpnAuto: false
    property string vpnLast: ""
    property bool vpnSettingsLoaded: false
    function setVpnAuto(on) {
        vpnAuto = on
        saveVpnSettings()
        autoVpn()
    }
    function saveVpnSettings() {
        vpnSaver.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1"', "sh",
            vpnSettingsPath, JSON.stringify({ auto: vpnAuto, last: vpnLast })]
        vpnSaver.running = true
    }
    Process { id: vpnSaver }
    FileView {
        path: root.vpnSettingsPath
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text())
                root.vpnAuto = s.auto === true
                root.vpnLast = typeof s.last === "string" ? s.last : ""
            } catch (err) {}
            root.vpnSettingsLoaded = true
            root.autoVpn()
        }
        onLoadFailed: root.vpnSettingsLoaded = true
    }
    readonly property var wifiNet: {
        const w = Networking.devices.values.find(d => d.type === DeviceType.Wifi)
        return w ? (w.networks.values.find(n => n.connected) ?? null) : null
    }
    readonly property bool openWifi: wifiNet !== null
        && (wifiNet.security === WifiSecurityType.Open || wifiNet.security === WifiSecurityType.Owe)
    onOpenWifiChanged: autoVpn()
    function autoVpn() {
        if (openWifi && vpnAuto && vpnLast !== "" && vpnLoaded && vpnSettingsLoaded && vpnUuid === "" && vpnBusy === "")
            vpnUp(vpnLast)
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

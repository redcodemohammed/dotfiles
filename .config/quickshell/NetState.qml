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
// swanctl (owner's request): strongSwan's own daemon, not NetworkManager, reached through its VICI
// socket (root:vpn via charon.group in /etc/strongswan.d/charon-group.conf; the owner is in vpn).
// Connections and state from swanctl --list-conns / --list-sas, re-read on every event
// `swanctl --log` streams; their ids are "swan:<name>". The daemon is started by hand (owner's
// choice): while it is down, swanStatus says so and none show.
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
    readonly property bool hotspotOn: Networking.devices.values.some(d => d.type === DeviceType.Wifi
        && d.mode === WifiDeviceMode.AccessPoint)
    // The island's Wi-Fi pill: the panel notes when it changes the connection on purpose (so a drop
    // isn't "lost"), and a click on the pill asks the bar on that screen to open the panel.
    property double userChangeAt: 0
    function userChange() {
        userChangeAt = Date.now()
    }
    signal panelRequested(string screen)
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

    // VPN: NetworkManager's active VPN and swanctl's IKE SAs, combined
    property string vpnUuid: "" // the active VPN, if any: a NetworkManager uuid or "swan:<name>"
    property string vpnName: ""
    property string vpnState: "" // activating, activated, deactivating
    property string nmVpnUuid: ""
    property string nmVpnName: ""
    property string nmVpnState: ""
    function combine() {
        if (nmVpnUuid !== "") {
            vpnUuid = nmVpnUuid
            vpnName = nmVpnName
            vpnState = nmVpnState
            return
        }
        const names = Object.keys(swanSas)
        const name = names.find(n => swanSas[n] === "ESTABLISHED") ?? names[0]
        vpnUuid = name === undefined ? "" : "swan:" + name
        vpnName = name ?? ""
        const st = name === undefined ? "" : swanSas[name]
        vpnState = st === "" ? "" : st === "ESTABLISHED" ? "activated" : st === "DELETING" ? "deactivating" : "activating"
    }
    readonly property bool vpnOn: vpnState === "activated"
    property bool vpnLoaded: false
    property string vpnBusy: "" // the VPN being connected from here
    property string vpnFailed: ""
    property string vpnFailText: ""
    function refreshVpn() {
        if (!vpnReader.running)
            vpnReader.running = true
    }
    // One VPN at a time: the active one goes down first. A swanctl connection starts each of its
    // children (or the bare IKE SA if it has none).
    function vpnUp(id) {
        vpnFailed = ""
        vpnBusy = id
        vpnSwitcher.target = id
        const conn = swanConns.find(c => "swan:" + c.name === id)
        vpnSwitcher.command = ["sh", "-c", '
            down() {
                case $1 in
                    swan:*) swanctl --terminate --ike "${1#swan:}" --timeout 10 >/dev/null 2>&1 ;;
                    ?*) nmcli connection down uuid "$1" >/dev/null 2>&1 ;;
                esac
            }
            fail() { printf "%s\n" "$1" | tail -n 1; exit 1; }
            [ -n "$2" ] && [ "$2" != "$1" ] && down "$2"
            case $1 in
                swan:*)
                    if [ -z "$3" ]; then out=$(swanctl --initiate --ike "${1#swan:}" --timeout 30 2>&1) || fail "$out"; fi
                    for c in $3; do out=$(swanctl --initiate --child "$c" --timeout 30 2>&1) || fail "$out"; done ;;
                *) out=$(nmcli --wait 30 connection up uuid "$1" 2>&1) || fail "$out" ;;
            esac
            echo ok', "sh", id, vpnUuid, conn ? conn.children.join(" ") : ""]
        vpnSwitcher.running = true
    }
    function vpnDown(id) {
        if (id.startsWith("swan:"))
            Quickshell.execDetached(["swanctl", "--terminate", "--ike", id.slice(5), "--timeout", "10"])
        else
            Quickshell.execDetached(["nmcli", "connection", "down", "uuid", id])
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
                root.refreshSwan()
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
                root.nmVpnUuid = found ? found[0] : ""
                root.nmVpnState = found ? found[2] : ""
                root.nmVpnName = found ? found.slice(3).join(":") : ""
                root.combine()
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
    Component.onCompleted: {
        refreshVpn()
        refreshSwan()
    }

    // swanctl
    property var swanConns: [] // { name, remote, children }
    property var swanSas: ({}) // IKE SA name -> state (CONNECTING, ESTABLISHED, DELETING, ...)
    property string swanStatus: "" // "", "off" (daemon not running) or "denied" (not in the vpn group yet)
    property bool swanLoaded: false
    function refreshSwan() {
        if (!swanReader.running)
            swanReader.running = true
    }
    Process {
        id: swanReader
        command: ["sh", "-c", 'swanctl --list-conns 2>&1 && echo "--- sas" && swanctl --list-sas 2>&1']
        stdout: StdioCollector {
            id: swanOut
            onStreamFinished: root.parseSwan(swanOut.text)
        }
    }
    function parseSwan(text) {
        const parts = text.split("--- sas")
        const conns = []
        const sas = {}
        if (parts.length < 2) {
            swanStatus = /Permission denied/.test(text) ? "denied" : "off"
        } else {
            swanStatus = ""
            let cur = null
            for (const line of parts[0].split("\n")) {
                let m = line.match(/^(\S+): IKE/)
                if (m) {
                    cur = { name: m[1], remote: "", children: [] }
                    conns.push(cur)
                } else if (cur && (m = line.match(/^  remote: *(.*)$/))) {
                    const r = m[1].split(",")[0].trim()
                    if (cur.remote === "" && r !== "%any")
                        cur.remote = r
                } else if (cur && (m = line.match(/^  (\S+): (TUNNEL|TRANSPORT|PASS|DROP)/))) {
                    cur.children.push(m[1])
                }
            }
            for (const line of parts[1].split("\n")) {
                const m = line.match(/^(\S+): #\d+, (\w+),/)
                if (m)
                    sas[m[1]] = m[2]
            }
        }
        swanConns = conns
        swanSas = sas
        combine()
        if (!swanLoaded) {
            swanLoaded = true
            autoVpn()
        }
    }
    Process { // a line on every daemon event; exits while the daemon is down, so try again
        id: swanLog
        running: true
        command: ["swanctl", "--log"]
        stdout: SplitParser {
            onRead: _ => swanDebounce.restart()
        }
        onExited: swanLogRestart.start()
    }
    Timer {
        id: swanLogRestart
        interval: 10000
        onTriggered: {
            root.refreshSwan()
            swanLog.running = true
        }
    }
    Timer {
        id: swanDebounce
        interval: 500
        onTriggered: root.refreshSwan()
    }

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
        if (openWifi && vpnAuto && vpnLast !== "" && vpnLoaded && swanLoaded && vpnSettingsLoaded && vpnUuid === "" && vpnBusy === "")
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

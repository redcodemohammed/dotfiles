import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Network manager panel (owner's design "Network manager" in the Hyprland Island canvas,
// 2026-10-15; the spec's bar item was icon only). It drops from the bar's network block, 400 wide,
// 4px under the bar and flush with its right edge, grabs the keyboard and closes on a click outside
// or Escape. Header: Wi-Fi, rescan, on/off. Tabs: Networks (search, list, hidden network), VPN and
// Settings (next steps). The Wi-Fi list, connecting (with a password), disconnect, forget and
// Wi-Fi on/off use Quickshell.Networking, live from NetworkManager; band and bit rate, which it
// does not give, and hidden networks use nmcli.
PopupWindow {
    id: panel
    required property var bar

    anchor.window: bar
    anchor.rect.x: bar.width - implicitWidth
    anchor.rect.y: bar.height + 4
    implicitWidth: 400
    implicitHeight: body.height
    color: "transparent"
    grabFocus: true
    visible: false

    property double closedAt: 0
    function toggle() {
        if (visible)
            visible = false
        else if (Date.now() - closedAt > 300) // the click that closed it may also land on the block
            visible = true
    }
    onVisibleChanged: {
        if (visible) {
            scan(false)
            return
        }
        closedAt = Date.now()
        sel = ""
        pw = ""
        err = ""
        query = ""
        search.text = ""
        hiddenOpen = false
        joinError = ""
    }

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property bool wifiOn: Networking.wifiEnabled
    property string tab: "nets"
    property string query: ""

    // Connected first, then by signal level, then by name (levels, not raw strength, so rows
    // don't jump about under the pointer).
    readonly property var networks: {
        if (!wifi)
            return []
        const q = query.trim().toLowerCase()
        return wifi.networks.values
            .filter(n => n.name !== "" && (q === "" || n.name.toLowerCase().indexOf(q) >= 0))
            .sort((a, b) => (b.connected - a.connected)
                || (Icons.wifiLevel(b.signalStrength) - Icons.wifiLevel(a.signalStrength))
                || a.name.localeCompare(b.name))
    }

    // The open row, its password, and the attempt under way or the last one that failed.
    property string sel: ""
    property string pw: ""
    property string err: ""
    property string errText: ""
    property var attempt: null // { name, wasKnown }: a new profile is forgotten if it fails
    function pick(name) {
        sel = sel === name ? "" : name
        pw = ""
        err = ""
    }
    Timer { // NetworkManager normally answers well before this
        running: panel.attempt !== null
        interval: 45000
        onTriggered: {
            panel.err = panel.attempt.name
            panel.errText = "Couldn't connect"
            panel.attempt = null
        }
    }

    // Scans while open; nmcli adds band and bit rate per network.
    Binding {
        when: panel.wifi !== null
        target: panel.wifi
        property: "scannerEnabled"
        value: panel.visible
    }
    property bool scanning: false
    property var info: ({}) // SSID -> { freq: MHz, rate: "130 Mbps" }
    function scan(force) {
        if (scanner.running || !wifiOn)
            return
        scanning = true
        scanner.command = ["nmcli", "-t", "-f", "SSID,FREQ,RATE,ACTIVE", "device", "wifi", "list",
            "--rescan", force ? "yes" : "auto"]
        scanner.running = true
    }
    function fields(line) { // nmcli -t: fields split by ':', a literal ':' is '\:'
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
    Process {
        id: scanner
        stdout: StdioCollector {
            id: scanOut
            onStreamFinished: {
                const map = {}
                for (const line of scanOut.text.split("\n")) {
                    const f = panel.fields(line)
                    if (f.length < 4 || f[0] === "")
                        continue
                    const entry = { freq: parseInt(f[1]), rate: f[2].replace("Mbit/s", "Mbps"), active: f[3] === "yes" }
                    const old = map[f[0]]
                    if (!old || (entry.active && !old.active) || (!old.active && entry.freq > old.freq))
                        map[f[0]] = entry // the access point in use, else the highest band
                }
                panel.info = map
            }
        }
        onExited: panel.scanning = false
    }

    // Hidden network: a new profile, the password handed over on stdin (not on the command line),
    // removed again if joining fails. Prints "ok" or nmcli's last error line.
    property bool hiddenOpen: false
    property bool joining: false
    property string joinError: ""
    readonly property string joinScript: '
        ssid=$1; secured=$2
        set -- type wifi con-name "$ssid" ssid "$ssid" 802-11-wireless.hidden yes
        [ "$secured" = 1 ] && set -- "$@" wifi-sec.key-mgmt wpa-psk
        out=$(nmcli connection add "$@" 2>&1) || { printf "%s\\n" "$out" | tail -n 1; exit 1; }
        uuid=$(printf "%s" "$out" | sed -n "s/.*(\\([0-9a-f-]*\\)).*/\\1/p")
        if [ "$secured" = 1 ]; then out=$(nmcli --wait 30 connection up uuid "$uuid" passwd-file /dev/stdin 2>&1)
        else out=$(nmcli --wait 30 connection up uuid "$uuid" </dev/null 2>&1); fi && { echo ok; exit 0; }
        nmcli connection delete uuid "$uuid" >/dev/null 2>&1
        printf "%s\\n" "$out" | tail -n 1'
    function joinHidden(name, psk) {
        joinError = ""
        joining = true
        joiner.psk = psk
        joiner.stdinEnabled = true
        joiner.command = ["sh", "-c", joinScript, "sh", name, psk === "" ? "0" : "1"]
        joiner.running = true
    }
    Process {
        id: joiner
        property string psk
        onStarted: {
            write("802-11-wireless-security.psk:" + psk + "\n")
            stdinEnabled = false // closes stdin
            psk = ""
        }
        stdout: StdioCollector {
            id: joinOut
            onStreamFinished: {
                panel.joining = false
                const r = joinOut.text.trim()
                if (r === "ok") {
                    panel.hiddenOpen = false
                    hiddenName.text = ""
                    hiddenPw.text = ""
                } else {
                    panel.joinError = r.replace(/^Error: /, "") || "Couldn't join"
                }
            }
        }
    }

    Rectangle {
        id: body
        width: 400
        height: content.implicitHeight + 28
        color: Theme.bg
        border.width: 2
        border.color: Theme.border
        focus: true
        Keys.onEscapePressed: panel.visible = false

        Column {
            id: content
            x: 14
            y: 14
            width: parent.width - 28
            spacing: 8

            Item { // Wi-Fi, rescan, on/off
                width: parent.width
                height: 24
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Wi-Fi"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: Theme.fg
                }
                Row {
                    anchors.right: parent.right
                    spacing: 8
                    Item {
                        width: 24
                        height: 24
                        Text {
                            anchors.centerIn: parent
                            text: Icons.arrowClockwise
                            font.family: Icons.regular
                            font.pixelSize: 16
                            color: rescanArea.containsMouse ? Theme.fg : Theme.fgMuted
                        }
                        MouseArea {
                            id: rescanArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: panel.scan(true)
                        }
                    }
                    PanelSwitch {
                        on: panel.wifiOn
                        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                    }
                }
            }

            Row { // tabs
                width: parent.width
                spacing: 4
                Repeater {
                    model: [{ id: "nets", label: "Networks" }, { id: "vpn", label: "VPN" }, { id: "settings", label: "Settings" }]
                    Rectangle {
                        id: tabButton
                        required property var modelData
                        readonly property bool on: panel.tab === modelData.id
                        width: (parent.width - 8) / 3
                        height: 32
                        color: on ? Theme.accent : Theme.bg
                        border.width: 2
                        border.color: on ? Theme.accent : Theme.border
                        Text {
                            anchors.centerIn: parent
                            text: tabButton.modelData.label
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            color: tabButton.on ? Theme.textOnAccent : Theme.fgMuted
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: panel.tab = tabButton.modelData.id
                        }
                    }
                }
            }

            Item { // Wi-Fi off
                visible: !panel.wifiOn && panel.tab === "nets"
                width: parent.width
                height: 120
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Wi-Fi is off"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: Theme.fgMuted
                    }
                    PanelButton {
                        anchors.horizontalCenter: parent.horizontalCenter
                        label: "Turn on Wi-Fi"
                        onPressed: Networking.wifiEnabled = true
                    }
                }
            }

            Column { // Networks
                visible: panel.wifiOn && panel.tab === "nets"
                width: parent.width
                spacing: 8

                PanelInput {
                    id: search
                    width: parent.width
                    icon: Icons.magnifyingGlass
                    placeholder: "Search networks"
                    clearable: true
                    onEdited: panel.query = text
                }

                Text {
                    text: panel.scanning ? "Scanning"
                        : panel.networks.length + (panel.networks.length === 1 ? " network" : " networks")
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.fgMuted
                }

                Item {
                    visible: !panel.scanning && panel.networks.length === 0
                    width: parent.width
                    height: 80
                    Text {
                        anchors.centerIn: parent
                        text: panel.query !== "" ? "No networks match" : "No networks found"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: Theme.fgMuted
                    }
                }

                Flickable {
                    visible: panel.networks.length > 0
                    width: parent.width
                    height: Math.min(rows.implicitHeight, 352)
                    contentHeight: rows.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: rows
                        // The rows' own `panel` property would shadow the id in `panel: panel`.
                        readonly property var owner: panel
                        width: parent.width
                        spacing: 4
                        Repeater {
                            model: ScriptModel {
                                values: panel.networks
                            }
                            NetworkRow {
                                panel: rows.owner
                                width: rows.width
                            }
                        }
                    }
                }

                PanelButton {
                    width: parent.width
                    icon: Icons.plus
                    label: "Join hidden network"
                    onPressed: panel.hiddenOpen = !panel.hiddenOpen
                }

                Column {
                    visible: panel.hiddenOpen
                    width: parent.width
                    spacing: 4
                    PanelInput {
                        id: hiddenName
                        width: parent.width
                        placeholder: "Network name"
                    }
                    PanelInput {
                        id: hiddenPw
                        width: parent.width
                        password: true
                        placeholder: "Password"
                        error: panel.joinError !== ""
                        onEdited: panel.joinError = ""
                        onAccepted: if (hiddenName.text.trim() !== "") panel.joinHidden(hiddenName.text.trim(), hiddenPw.text)
                    }
                    Text {
                        visible: panel.joinError !== "" || panel.joining
                        width: parent.width
                        topPadding: 4
                        bottomPadding: 4
                        text: panel.joining ? "Connecting" : panel.joinError
                        wrapMode: Text.Wrap
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: panel.joining ? Theme.fgMuted : Theme.fg
                    }
                    PanelButton {
                        width: parent.width
                        primary: true
                        label: "Join"
                        available: !panel.joining && hiddenName.text.trim() !== ""
                        onPressed: panel.joinHidden(hiddenName.text.trim(), hiddenPw.text)
                    }
                }
            }

            Text { // the other tabs come in the next steps
                visible: panel.tab !== "nets"
                width: parent.width
                topPadding: 8
                bottomPadding: 8
                text: (panel.tab === "vpn" ? "VPN" : "Settings") + " is the next step."
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Theme.fgMuted
            }
        }
    }
}

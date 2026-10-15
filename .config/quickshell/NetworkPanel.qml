import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Network manager panel (owner's design "Network manager" in the Hyprland Island canvas,
// 2026-10-15; the spec's bar item was icon only). It drops from the bar's network block, 400 wide,
// 4px under the bar and flush with its right edge, grabs the keyboard and closes on a click outside
// or Escape. Header: Wi-Fi, rescan, on/off. Tabs: Networks (search, list, hidden network),
// Settings (NetworkSettings.qml) and VPN (NetworkVpn.qml). Under the tabs: a box when the internet
// fails (Retry, or Open login page for a sign-in page) and, on Networks, the speed line. Keyboard:
// search is focused on open, Up/Down move through the list, Enter opens (or connects), Esc closes. The Wi-Fi list, connecting (with a password),
// disconnect, forget and Wi-Fi on/off use Quickshell.Networking, live from NetworkManager; band and
// bit rate, which it does not give, hidden networks and profile settings use nmcli; Airplane mode
// is rfkill (all radios; the owner's login has an ACL on /dev/rfkill, no sudo).
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
            readRfkill()
            hi = 0
            if (tab === "nets")
                Qt.callLater(search.focusInput)
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
    onQueryChanged: hi = 0

    // Keyboard: the highlighted row while the search field has focus.
    property int hi: 0
    readonly property bool searchFocused: search.focused
    function move(step) {
        hi = Math.max(0, Math.min(networks.length - 1, hi + step))
        const row = netRepeater.itemAt(hi)
        if (row === null)
            return
        if (row.y < list.contentY)
            list.contentY = row.y
        else if (row.y + row.height > list.contentY + list.height)
            list.contentY = row.y + row.height - list.height
    }
    function enter() {
        const row = netRepeater.itemAt(hi)
        if (row === null)
            return
        if (row.expanded && row.canConnect && !row.needsPw)
            row.connect()
        else
            pick(row.net.name)
    }
    Binding { // the speed line samples only while someone looks at it
        when: panel.visible && panel.tab === "nets"
        target: NetState
        property: "watching"
        value: true
    }

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

    function securityLabel(net) {
        switch (net.security) {
        case WifiSecurityType.Open: return "Open"
        case WifiSecurityType.Owe: return "Open (encrypted)"
        case WifiSecurityType.WpaPsk: return "WPA"
        case WifiSecurityType.Wpa2Psk: return "WPA2"
        case WifiSecurityType.Sae: return "WPA3"
        case WifiSecurityType.StaticWep: return "WEP"
        case WifiSecurityType.Wpa2Eap:
        case WifiSecurityType.WpaEap:
        case WifiSecurityType.Wpa3SuiteB192:
        case WifiSecurityType.Leap:
        case WifiSecurityType.DynamicWep: return "Enterprise"
        default: return "Secured"
        }
    }
    function band(freq) {
        return freq >= 5925 ? "6 GHz" : freq >= 4900 ? "5 GHz" : "2.4 GHz"
    }

    // Airplane mode: every radio soft-blocked. Read when the panel opens and after a change.
    property bool airplane: false
    function readRfkill() {
        if (!rfkillReader.running)
            rfkillReader.running = true
    }
    function setAirplane(on) {
        airplane = on
        rfkillWriter.command = ["rfkill", on ? "block" : "unblock", "all"]
        rfkillWriter.running = true
    }
    Process {
        id: rfkillReader
        command: ["rfkill", "-J"]
        stdout: StdioCollector {
            id: rfkillOut
            onStreamFinished: {
                try {
                    const devs = Object.values(JSON.parse(rfkillOut.text))[0] ?? []
                    panel.airplane = devs.length > 0 && devs.every(d => d.soft === "blocked")
                } catch (e) {}
            }
        }
    }
    Process {
        id: rfkillWriter
        onExited: {
            if (!panel.airplane)
                Networking.wifiEnabled = true // airplane off brings Wi-Fi back, as in the design
            panel.readRfkill()
        }
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
    function fields(line) {
        return NetState.fields(line)
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
            // A child's own `panel` property would shadow the id in `panel: panel`.
            readonly property var owner: panel
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
                        on: panel.wifiOn && !panel.airplane
                        onToggled: {
                            if (panel.airplane)
                                panel.setAirplane(false)
                            else
                                Networking.wifiEnabled = !Networking.wifiEnabled
                        }
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

            Rectangle { // the internet fails: no internet (red) or a sign-in page
                id: statusBox
                readonly property bool bad: NetState.internet === "none"
                visible: bad || NetState.internet === "portal"
                width: parent.width
                height: 52
                color: "transparent"
                border.width: 2
                border.color: bad ? Theme.alert : Theme.border
                Text {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.warningCircle
                    font.family: Icons.regular
                    font.pixelSize: 16
                    color: statusBox.bad ? Theme.alert : Theme.fg
                }
                Text {
                    x: 34
                    anchors.verticalCenter: parent.verticalCenter
                    width: statusButton.x - x - 8
                    text: NetState.checking ? "Checking connection" : statusBox.bad ? "No internet" : "Sign-in required"
                    elide: Text.ElideRight
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: Theme.fg
                }
                PanelButton {
                    id: statusButton
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: 32
                    label: statusBox.bad ? "Retry" : "Open login page"
                    onPressed: {
                        if (!statusBox.bad) {
                            // NetworkManager's check page: a sign-in portal intercepts it and shows its login.
                            Quickshell.execDetached(["xdg-open", "http://ping.archlinux.org/nm-check.txt"])
                            panel.visible = false
                        }
                        NetState.check()
                    }
                }
            }

            Item { // speed and data used, for the device carrying the internet
                visible: panel.tab === "nets" && NetState.internet === "ok" && NetState.device !== ""
                width: parent.width
                height: 16
                Row {
                    spacing: 12
                    Text {
                        text: "↓ " + NetState.rate(NetState.down)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Theme.fgMuted
                    }
                    Text {
                        text: "↑ " + NetState.rate(NetState.up)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Theme.fgMuted
                    }
                }
                Text {
                    anchors.right: parent.right
                    text: NetState.amount(NetState.used) + " used"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.fgMuted
                }
            }

            Item { // Wi-Fi off, or airplane mode
                visible: (!panel.wifiOn || panel.airplane) && panel.tab === "nets"
                width: parent.width
                height: 120
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: panel.airplane ? "Airplane mode is on" : "Wi-Fi is off"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: Theme.fgMuted
                    }
                    PanelButton {
                        anchors.horizontalCenter: parent.horizontalCenter
                        label: panel.airplane ? "Turn off airplane mode" : "Turn on Wi-Fi"
                        onPressed: {
                            if (panel.airplane)
                                panel.setAirplane(false)
                            else
                                Networking.wifiEnabled = true
                        }
                    }
                }
            }

            Column { // Networks
                visible: panel.wifiOn && !panel.airplane && panel.tab === "nets"
                width: parent.width
                spacing: 8

                PanelInput {
                    id: search
                    width: parent.width
                    icon: Icons.magnifyingGlass
                    placeholder: "Search networks"
                    clearable: true
                    onEdited: panel.query = text
                    onUpPressed: panel.move(-1)
                    onDownPressed: panel.move(1)
                    onAccepted: panel.enter()
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
                    id: list
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
                            id: netRepeater
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

                Text {
                    text: "↑↓ move · Enter select · Esc close"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.fgMuted
                }
            }

            NetworkSettings {
                visible: panel.tab === "settings"
                width: parent.width
                panel: content.owner
            }

            NetworkVpn {
                visible: panel.tab === "vpn"
                width: parent.width
                panel: content.owner
            }
        }
    }
}

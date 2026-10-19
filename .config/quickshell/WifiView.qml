import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Quick settings' Wi-Fi view (owner, 2026-10-20; the network panel before, from the owner's
// "Network manager" design of 2026-10-15): opened by the Wi-Fi tile's ›, the island's Wi-Fi pill
// or `qs ipc call panel toggle network`. Header: rescan, ⋯ (more) and on/off. Then the no-internet
// card, the speed line, a small search (focused on open; Up/Down move through the list, Enter
// opens or connects) and the networks (NetworkRow.qml: a click opens one in place with its
// details, password, Connect, Disconnect, Forget and its settings). Above the list VPN and Hotspot,
// each pushing its page (NetworkVpn.qml, NetworkHotspot.qml). ⋯ pushes the more page: Airplane
// mode, Join hidden network, Network settings (NetworkSettings.qml). The rows and those parts
// take a `panel`: this view (the list) or a small Host per page, giving them what the network
// panel gave. The Wi-Fi list, connecting, disconnect, forget and Wi-Fi on/off use
// Quickshell.Networking, live from NetworkManager; band and bit rate, hidden networks and profile
// settings use nmcli; Airplane mode is rfkill (all radios; the owner's login has an ACL on
// /dev/rfkill, no sudo).
Item {
    id: view
    readonly property string viewName: "network"
    signal back
    signal push(var component, var properties)
    signal closeRequested
    signal hideRequested // the VPN import's file picker needs the keyboard now, no slide

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property bool wifiOn: Networking.wifiEnabled
    property string query: ""
    onQueryChanged: hi = 0

    Component.onCompleted: {
        scan(false)
        readRfkill()
        Qt.callLater(search.focusInput)
    }

    // What NetworkRow reads off its panel.
    property int hi: 0
    readonly property bool searchFocused: search.focused
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
        running: view.attempt !== null
        interval: 45000
        onTriggered: {
            view.err = view.attempt.name
            view.errText = "Couldn't connect"
            view.attempt = null
        }
    }

    // Keyboard: the highlighted row while the search field has focus; the page scrolls to it.
    function move(step) {
        hi = Math.max(0, Math.min(networks.length - 1, hi + step))
        const row = netRepeater.itemAt(hi)
        if (row === null)
            return
        const y = row.mapToItem(page.contentItem, 0, 0).y
        if (y < page.contentY)
            page.contentY = y
        else if (y + row.height > page.contentY + page.height)
            page.contentY = y + row.height - page.height
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
    Binding { // the speed line samples only while the list is shown
        when: view.StackView.status === StackView.Active
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
    function fields(line) {
        return NetState.fields(line)
    }

    // Airplane mode: every radio soft-blocked. Read when the view opens and after a change.
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
                    view.airplane = devs.length > 0 && devs.every(d => d.soft === "blocked")
                } catch (e) {}
            }
        }
    }
    Process {
        id: rfkillWriter
        onExited: {
            if (!view.airplane)
                Networking.wifiEnabled = true // airplane off brings Wi-Fi back, as in the design
            view.readRfkill()
        }
    }

    // Scans while the view is open; nmcli adds band and bit rate per network.
    Binding {
        when: view.wifi !== null
        target: view.wifi
        property: "scannerEnabled"
        value: true
    }
    Component.onDestruction: if (wifi) wifi.scannerEnabled = false
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
    Process {
        id: scanner
        stdout: StdioCollector {
            id: scanOut
            onStreamFinished: {
                const map = {}
                for (const line of scanOut.text.split("\n")) {
                    const f = view.fields(line)
                    if (f.length < 4 || f[0] === "")
                        continue
                    const entry = { freq: parseInt(f[1]), rate: f[2].replace("Mbit/s", "Mbps"), active: f[3] === "yes" }
                    const old = map[f[0]]
                    if (!old || (entry.active && !old.active) || (!old.active && entry.freq > old.freq))
                        map[f[0]] = entry // the access point in use, else the highest band
                }
                view.info = map
            }
        }
        onExited: view.scanning = false
    }

    // Hidden network: a new profile, the password handed over on stdin (not on the command line),
    // removed again if joining fails. Prints "ok" or nmcli's last error line.
    property bool joining: false
    property string joinError: ""
    signal joined
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
        NetState.userChange()
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
                view.joining = false
                const r = joinOut.text.trim()
                if (r === "ok")
                    view.joined()
                else
                    view.joinError = r.replace(/^Error: /, "") || "Couldn't join"
            }
        }
    }

    // What NetworkSettings, NetworkHotspot and NetworkVpn (and NetworkConnCard through the
    // settings) read off their panel: shown and on their tab while their page is up; setting
    // `visible` false (the VPN import) hides the quick panel at once.
    component Host: QtObject {
        property string tab
        property bool visible: true
        readonly property var wifi: view.wifi
        readonly property var info: view.info
        readonly property bool airplane: view.airplane
        function setAirplane(on) { view.setAirplane(on) }
        function fields(line) { return view.fields(line) }
        function band(freq) { return view.band(freq) }
        function securityLabel(net) { return view.securityLabel(net) }
        onVisibleChanged: if (!visible) view.hideRequested()
    }

    readonly property color hue: Theme.hue4

    component Caption: Text {
        leftPadding: 4
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Theme.fgMuted
    }
    component IconButton: Rectangle {
        id: iconButton
        property string glyph
        signal clicked
        width: 28
        height: 28
        radius: 8
        color: iconHover.containsMouse ? Edge.controlHover : Edge.control
        Text {
            anchors.centerIn: parent
            text: iconButton.glyph
            font.family: Icons.regular
            font.pixelSize: 15
            color: iconHover.containsMouse ? Theme.fg : Theme.fgMuted
        }
        MouseArea {
            id: iconHover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: iconButton.clicked()
        }
    }
    // A button pushing a page: its icon (filled and in the hue while `on`), label and state.
    component PageButton: Rectangle {
        id: pageButton
        property string glyph
        property string label
        property string status
        property bool on: false
        signal clicked
        height: 44
        radius: 8
        color: on ? Qt.tint(Edge.fill, Qt.rgba(view.hue.r, view.hue.g, view.hue.b, pageHover.containsMouse ? 0.25 : 0.15))
            : pageHover.containsMouse ? Edge.controlHover : Edge.control
        Text {
            id: pageIcon
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            text: pageButton.glyph
            font.family: pageButton.on ? Icons.fill : Icons.regular
            font.pixelSize: 16
            color: pageButton.on ? view.hue : Theme.fgMuted
        }
        Column {
            x: 38
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 28
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: pageButton.label
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Theme.fg
            }
            Text {
                visible: pageButton.status !== ""
                width: parent.width
                elide: Text.ElideRight
                text: pageButton.status
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: pageButton.on ? view.hue : Theme.fgMuted
            }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.caretRight
            font.family: Icons.regular
            font.pixelSize: 14
            color: Theme.fgMuted
        }
        MouseArea {
            id: pageHover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: pageButton.clicked()
        }
    }

    ViewHeader {
        id: header
        title: "Wi-Fi"
        onBack: view.back()
        IconButton {
            glyph: Icons.arrowClockwise
            onClicked: view.scan(true)
        }
        IconButton {
            glyph: Icons.dotsThree
            onClicked: view.push(morePage, {})
        }
        PanelSwitch {
            anchors.verticalCenter: parent.verticalCenter
            on: view.wifiOn && !view.airplane
            onToggled: {
                if (view.airplane)
                    view.setAirplane(false)
                else
                    Networking.wifiEnabled = !Networking.wifiEnabled
            }
        }
    }

    Flickable {
        id: page
        y: header.height + 8
        width: parent.width
        height: parent.height - y
        contentHeight: column.implicitHeight + 16
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            x: 16
            width: parent.width - 32
            spacing: 8

            NetStatusCard { onLoginOpened: view.closeRequested() }

            Item { // speed and data used, for the device carrying the internet
                visible: NetState.internet === "ok" && NetState.device !== ""
                width: parent.width
                height: 16
                Row {
                    x: 4
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
                    anchors.rightMargin: 4
                    text: NetState.amount(NetState.used) + " used"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.fgMuted
                }
            }

            Grid { // VPN and Hotspot, above the list (owner, 2026-10-20)
                width: parent.width
                columns: 2
                spacing: 8
                readonly property real cell: (width - spacing) / 2
                PageButton {
                    width: parent.cell
                    glyph: Icons.shield
                    label: "VPN"
                    status: NetState.vpnOn ? "On" : "Off"
                    on: NetState.vpnOn
                    onClicked: view.push(vpnPage, {})
                }
                PageButton {
                    width: parent.cell
                    glyph: Icons.broadcast
                    label: "Hotspot"
                    onClicked: view.push(hotspotPage, {})
                }
            }

            Item { // Wi-Fi off, or airplane mode
                visible: !view.wifiOn || view.airplane
                width: parent.width
                height: 100
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: view.airplane ? "Airplane mode is on" : "Wi-Fi is off"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: Theme.fgMuted
                    }
                    PanelButton {
                        anchors.horizontalCenter: parent.horizontalCenter
                        label: view.airplane ? "Turn off airplane mode" : "Turn on Wi-Fi"
                        onPressed: {
                            if (view.airplane)
                                view.setAirplane(false)
                            else
                                Networking.wifiEnabled = true
                        }
                    }
                }
            }

            Column { // the networks
                visible: view.wifiOn && !view.airplane
                width: parent.width
                spacing: 8

                PanelInput {
                    id: search
                    width: parent.width
                    icon: Icons.magnifyingGlass
                    placeholder: "Search networks"
                    clearable: true
                    onEdited: view.query = text
                    onUpPressed: view.move(-1)
                    onDownPressed: view.move(1)
                    onAccepted: view.enter()
                }

                Caption {
                    text: view.scanning ? "Scanning"
                        : view.networks.length === 0 ? (view.query !== "" ? "No networks match" : "No networks found")
                        : "Networks"
                }

                Column {
                    id: rows
                    // The rows' own `panel` property would shadow the id in `panel: view`.
                    readonly property var owner: view
                    width: parent.width
                    spacing: 4
                    Repeater {
                        id: netRepeater
                        model: ScriptModel {
                            values: view.networks
                        }
                        NetworkRow {
                            panel: rows.owner
                            width: rows.width
                        }
                    }
                }
            }

        }
    }

    // A page under the view: its header and one of the network parts, scrolling.
    component SubPage: Item {
        id: sub
        property string title
        readonly property string viewName: "network"
        default property alias content: subColumn.data
        ViewHeader {
            id: subHeader
            title: sub.title
            onBack: view.back()
        }
        Flickable {
            y: subHeader.height + 8
            width: parent.width
            height: parent.height - y
            contentHeight: subColumn.implicitHeight + 16
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: subColumn
                x: 16
                width: parent.width - 32
                spacing: 8
            }
        }
    }

    Component {
        id: vpnPage
        SubPage {
            title: "VPN"
            NetworkVpn { width: parent.width; panel: Host { tab: "vpn" } }
        }
    }
    Component {
        id: hotspotPage
        SubPage {
            title: "Hotspot"
            NetworkHotspot { width: parent.width; panel: Host { tab: "hotspot" } }
        }
    }
    Component {
        id: settingsPage
        SubPage {
            title: "Network settings"
            NetworkSettings { width: parent.width; panel: Host { tab: "settings" } }
        }
    }

    // ⋯: Airplane mode, Join hidden network, Network settings.
    Component {
        id: morePage
        SubPage {
            id: more
            title: "More"
            property bool hiddenOpen: false
            Connections {
                target: view
                function onJoined() {
                    more.hiddenOpen = false
                    hiddenName.text = ""
                    hiddenPw.text = ""
                }
            }

            Rectangle {
                width: parent.width
                height: 44
                radius: 8
                color: Edge.control
                Text {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Airplane mode"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: Theme.fg
                }
                PanelSwitch {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    on: view.airplane
                    onToggled: view.setAirplane(!view.airplane)
                }
            }
            PageButton {
                width: parent.width
                glyph: Icons.gear
                label: "Network settings"
                status: "Connections, IP and DNS"
                onClicked: view.push(settingsPage, {})
            }
            PanelButton {
                width: parent.width
                icon: Icons.plus
                label: "Join hidden network"
                onPressed: more.hiddenOpen = !more.hiddenOpen
            }
            Column {
                visible: more.hiddenOpen
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
                    error: view.joinError !== ""
                    onEdited: view.joinError = ""
                    onAccepted: if (hiddenName.text.trim() !== "") view.joinHidden(hiddenName.text.trim(), hiddenPw.text)
                }
                Text {
                    visible: view.joinError !== "" || view.joining
                    width: parent.width
                    topPadding: 4
                    bottomPadding: 4
                    text: view.joining ? "Connecting" : view.joinError
                    wrapMode: Text.Wrap
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: view.joining ? Theme.fgMuted : Theme.fg
                }
                PanelButton {
                    width: parent.width
                    primary: true
                    label: "Join"
                    available: !view.joining && hiddenName.text.trim() !== ""
                    onPressed: view.joinHidden(hiddenName.text.trim(), hiddenPw.text)
                }
            }
        }
    }
}

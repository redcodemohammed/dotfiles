import QtQuick
import Quickshell.Io
import Quickshell.Networking

// The network panel's Hotspot tab (moved out of Settings, owner 2026-10-17). Hotspot (owner's
// choice): NetworkManager's own on the Wi-Fi card, so it replaces the Wi-Fi network and shares the
// wired one; NetworkManager rejoins Wi-Fi when it stops. Profile "Hotspot" (SSID = hostname,
// password NetworkManager generated, kept in the profile), made by nmcli device wifi hotspot if
// missing. Sharing needs dnsmasq. While it runs: its name, password (shown on request) and the
// clients, from iw station dump every 3 s.
Column {
    id: root
    required property var panel
    readonly property string device: panel.wifi ? panel.wifi.name : ""
    readonly property bool live: panel.visible && panel.tab === "hotspot"
    spacing: 8

    readonly property bool hotspotOn: panel.wifi !== null && panel.wifi.mode === WifiDeviceMode.AccessPoint
    property string hotspotBusy: "" // "Starting hotspot" / "Stopping hotspot"
    property string hotspotError: ""
    property string hotspotName: ""
    property string hotspotPw: ""
    property bool showHotspotPw: false
    property int clients: 0
    readonly property bool hotspotLive: live && hotspotOn
    onHotspotLiveChanged: if (hotspotLive) hotspotReader.running = true
    function setHotspot(on) {
        NetState.userChange()
        hotspotError = ""
        hotspotBusy = on ? "Starting hotspot" : "Stopping hotspot"
        hotspotSwitcher.command = ["sh", "-c", on ? '
            if nmcli -g NAME connection | grep -qx Hotspot; then
                out=$(nmcli --wait 20 connection up id Hotspot ifname "$1" 2>&1)
            else
                out=$(nmcli --wait 20 device wifi hotspot ifname "$1" con-name Hotspot ssid "$(uname -n)" 2>&1)
            fi || { printf "%s\n" "$out" | tail -n 1; exit 1; }' : 'nmcli connection down id Hotspot 2>&1 | tail -n 1',
            "sh", device]
        hotspotSwitcher.running = true
    }
    Process {
        id: hotspotSwitcher
        stdout: StdioCollector { id: switchOut }
        onExited: code => {
            root.hotspotBusy = ""
            if (code !== 0)
                root.hotspotError = switchOut.text.trim().replace(/^Error: /, "") || "Couldn't start the hotspot"
        }
    }
    Process { // its name and password
        id: hotspotReader
        command: ["sh", "-c", '
            nmcli -g 802-11-wireless.ssid connection show id Hotspot
            nmcli -s -g 802-11-wireless-security.psk connection show id Hotspot']
        stdout: StdioCollector {
            id: hotspotOut
            onStreamFinished: {
                const lines = hotspotOut.text.split("\n")
                root.hotspotName = NetState.unescaped(lines[0])
                root.hotspotPw = NetState.unescaped(lines[1])
            }
        }
    }
    Timer { // clients, while the card shows
        running: root.hotspotLive
        interval: 3000
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!stations.running) stations.running = true
    }
    Process {
        id: stations
        command: ["sh", "-c", 'iw dev "$1" station dump | grep -c "^Station"', "sh", root.device]
        stdout: StdioCollector {
            id: stationsOut
            onStreamFinished: root.clients = Number(stationsOut.text.trim()) || 0
        }
    }

    Item { // Hotspot
        width: parent.width
        height: 40
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Hotspot"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: Theme.fg
        }
        PanelSwitch {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            available: root.hotspotBusy === "" && root.device !== ""
            on: root.hotspotBusy === "Starting hotspot" || (root.hotspotOn && root.hotspotBusy === "")
            onToggled: root.setHotspot(!root.hotspotOn)
        }
    }
    Text { // starting, stopping, or why it failed
        visible: root.hotspotBusy !== "" || root.hotspotError !== ""
        width: parent.width
        text: root.hotspotBusy || root.hotspotError
        wrapMode: Text.Wrap
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: root.hotspotBusy !== "" ? Theme.fgMuted : Theme.alert
    }
    Rectangle { // while it runs: name, password, clients
        visible: root.hotspotOn && root.hotspotBusy === ""
        width: parent.width
        height: hotspotCard.implicitHeight + 28
        radius: 12 // a card
        color: Edge.control
        Column {
            id: hotspotCard
            x: 14
            y: 14
            width: parent.width - 28
            spacing: 4
            Repeater {
                model: [
                    ["Name", root.hotspotName],
                    ["Password", root.showHotspotPw ? root.hotspotPw : "••••••••••••••"],
                    ["Clients", root.clients + " connected"],
                ]
                Item {
                    id: hotspotRow
                    required property var modelData
                    required property int index
                    width: hotspotCard.width
                    height: index === 1 ? 24 : 16
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 96
                        text: hotspotRow.modelData[0]
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Theme.fgMuted
                    }
                    Text {
                        x: 104
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - (hotspotRow.index === 1 ? 32 : 0)
                        text: hotspotRow.modelData[1]
                        elide: Text.ElideRight
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Theme.fg
                    }
                    Item { // show or hide the password
                        visible: hotspotRow.index === 1
                        anchors.right: parent.right
                        width: 24
                        height: 24
                        Text {
                            anchors.centerIn: parent
                            text: root.showHotspotPw ? Icons.eyeSlash : Icons.eye
                            font.family: Icons.regular
                            font.pixelSize: 16
                            color: Theme.fgMuted
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.showHotspotPw = !root.showHotspotPw
                        }
                    }
                }
            }
        }
    }
}
